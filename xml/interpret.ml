(* Tursi <=> JFLAP converter *)

open Syntaxtursi
open Xml


(* sets and maps of strings and integers *)

module StrM = struct
  type t = string
  let compare = Pervasives.compare
end

module Int = struct 
  type t = int
  let compare = Pervasives.compare
end

module SetofStr     = Set.Make(StrM)
module MapofStr     = Map.Make(StrM)
module SetofInt     = Set.Make(Int)
module MapofInt     = Map.Make(Int)

(* generic printer for lists *)
let pp_list (pp_a: Format.formatter -> 'a -> unit) (fmt:Format.formatter)
    (xs: 'a list)  =
  begin match xs with
    | [] -> ()
    | x::xs -> pp_a fmt x; List.iter (Format.fprintf fmt "%a" pp_a) xs end

(* printer for statements of Tursi *)
let pp_stat (fmt:Format.formatter) (s:statement) : unit =
  let es (s:word) : word =  (* escape '#' symbol *)
    match s with "#" -> "##" | _ -> s in
  let ess (s:word) : word = (* escape '#' symbols in strings *)
    let re = Str.regexp "#" in
      Str.global_replace re "##" s in
  match s with
  | Start(s) ->
      Format.fprintf fmt "#! start %s@\n" s
  | End(s) ->
      Format.fprintf fmt "#! end";
      List.iter (fun s -> (Format.fprintf fmt " %s" s)) s;
      Format.fprintf fmt "@\n"
  | Fill(s) ->
      Format.fprintf fmt "#! fill %s@\n" (es s)
  | Write(s) ->
      Format.fprintf fmt "#! write %s@\n" (ess s)
  | Wildcard(s) ->
      Format.fprintf fmt "#! wildcard %s@\n" (es s)
  | Transition(sCur,cRead,cWrite,cDir,sNext) ->
      Format.fprintf fmt "%s %s %s %s %s@\n" sCur (es cRead) (es cWrite) cDir sNext


(* Tursi info collected in preprocessing *)
type tinfo = {
  is : state list;      (* initial state *)
  fs : state list;      (* final states *)
  bs : word list;       (* blank symbol *)
  ws : word list;       (* wildcard symbol *)
  tm : ((word*word*state) MapofStr.t) MapofStr.t ; (* transition map *)
    (* state name to a map from read symbol to triple of written symbol, direction and next state *)
    (* it is used to expand wildcard symbol specified by #! wildcard command *)
  ms : int MapofStr.t;  (* map from state name to state id *)
  cnt : int;            (* counter for delivering unique state ids *)
  gamma : SetofStr.t;   (* set of symbols on the tape *)
}

(* Tursi statements to JFLAP XML conversion *)
let tm2jff (ast:statement list) : xml =
  let register_symbol (s:word) (t:tinfo) : tinfo =
    { t with
      gamma  = SetofStr.add s t.gamma; } in
  (* register new state and count up the counter *)
  let register_state (s:state) (t:tinfo) : tinfo =
    if MapofStr.mem s t.ms then t else
    { t with
      ms  = MapofStr.add s t.cnt t.ms;
      cnt = t.cnt+1 } in
  let register_transition ((sCur,cRead,cWrite,cDir,sNext):state*word*word*word*state) (t:tinfo) : tinfo =
    let t = register_state  sCur   t in
    let t = register_state  sNext  t in
    let t = register_symbol cRead  t in
    let t = register_symbol cWrite t in
    { t with tm = MapofStr.add sCur
	(let ent =
	  if   MapofStr.mem  sCur t.tm (* if the entry of current state already exists *)
	  then MapofStr.find sCur t.tm (* use existing map (from read symbol) to update *)
	  else MapofStr.empty in       (* prepare initial empty map (from read symbol) *)
	 MapofStr.add cRead (cWrite,cDir,sNext) ent) t.tm } in
  (* first pass: collect information (initial state, finall states, fill symbol wildcard 
     and transitions *)
  let tinfo =
    List.fold_right (fun x t -> match x with
      Start s    -> { t with is = s::(t.is) }
    | End ss     -> { t with fs = ss@(t.fs) }
    | Fill s     -> { t with bs = s::(t.bs) }
    | Wildcard s -> { t with ws = s::(t.ws) }
    | Transition (sCur,cRead,cWrite,cDir,sNext) 
      -> register_transition (sCur,cRead,cWrite,cDir,sNext) t
    | _             -> t) ast {
    is = [];
    fs = [];
    bs = [];
    ws = [];
    tm = MapofStr.empty;
    ms = MapofStr.empty;
    cnt = 0;
    gamma = SetofStr.empty;
  }  in
  (* second pass *)
  let istate = (* initial state name *)
    if List.length tinfo.is = 1
    then List.nth tinfo.is 0
    else failwith "No/two or more initial state(s)" in
  let fstates = (* list of final states *)
    if List.length tinfo.fs > 0
    then tinfo.fs
    else failwith "No final state" in
  let blank_opt = (* blank symbol by #!fill command *)
    match (List.length tinfo.bs) with
      0 -> None
    | 1 -> Some (List.nth tinfo.bs 0)
    | _ -> failwith "more than one blank symbol (fill)" in
  let wildcard_opt = (* wildcard symbol by #! wildcard command *)
    match (List.length tinfo.ws) with
      1 -> Some (List.nth tinfo.ws 0)
    | 0 -> None
    | _ -> failwith "more than one wildcard symbol(s)"  in
  (* remove wildcard symbol from \Gamma if any because it is not part of the set *)
  let tinfo = match wildcard_opt with
    None    -> tinfo
  | Some wc -> { tinfo with
              gamma = SetofStr.remove wc tinfo.gamma } in
 (* if the read/write symbol is identical to the one specified by #! fill command,
    then it is equivalent to JFLAP's blank symbol represented by empty content *)
 (* if '*' is used without #! fill command, then it is also considered as blank
    symbol in JFLAP *)
 let sym_or_blank : word -> xml list =
   match blank_opt with
     None       -> fun sym -> if sym = "*" then [] else [PCData sym]
   | Some blank -> fun sym ->
       if sym = blank then [] else [PCData sym] in
 let translate_dir (d:word) : word = (* translate direction symbol from Tursi to JFLAP *)
   match d with 
    "l" | "L" | "<"             -> "L" (* move head to the left *)
  | "n" | "N" | "s" | "S" | "=" -> "S" (* stay (don't move) *)
  | "r" | "R" | ">"             -> "R" (* move head to the right *)
  | _ -> failwith ("translate_dir: invalid direction symbol " ^ d ^ ".") in
 (* generate JFLAP <transition> elements from Tursi transitions *)
 let transitions =
   List.fold_right (fun x ts -> match x with
	Transition (sCur,cRead,cWrite,cDir,sNext) ->
        (* unique integral IDs is used for state identifiers *)
	 (let idCur  = MapofStr.find sCur  tinfo.ms in
	  let idNext = MapofStr.find sNext tinfo.ms in
	  let elem =
	    Element (
	   "transition",[],[
	    Element ("from", [],[PCData (string_of_int idCur)]);
            Element ("to"  , [],[PCData (string_of_int idNext)]);
	    Element ("read", [],sym_or_blank cRead);  (* use blank symbol when appropriate *)
	    Element ("write",[],sym_or_blank cWrite); (* use blank symbol when appropriate *)
	    Element ("move", [],[PCData (translate_dir cDir)]); (* normalize direction symbol *)
	 ]) in
	  (match wildcard_opt with
	    Some wc ->
	      if wc = cRead then
		(** expand label (read write move)  **)
                (* first, remove the wildcard rule from the map from input symbol *)
		let map = MapofStr.find sCur tinfo.tm in
		let map = MapofStr.remove wc map in
                (* disregard existing non-wildcard rules  *)
		let gamma = MapofStr.fold (fun k v gamma ->
		  SetofStr.remove k gamma)  map  tinfo.gamma in
                (* generate entries using the remaining symbols in \Gamma *)
		SetofStr.fold (fun sym ss ->
		 (Element (
		  "transition",[],[
		  Element ("from", [],[PCData (string_of_int idCur)]);
		  Element ("to"  , [],[PCData (string_of_int idNext)]);
		  Element ("read", [],sym_or_blank sym);
                  (* if the wildcard appears as the written symbol, then 
                     replace by the read symbol *)
		  Element ("write",[],if cWrite = wc then sym_or_blank sym else sym_or_blank cWrite);
		  Element ("move", [],[PCData (translate_dir cDir)]); (* normalize direction *)
		])
		 )::ss
		  ) gamma []
	      else [elem]  (* read symbol is not the wildcard: no expansion *)
	  | None -> [elem] (* no wildcard symbol is declared: no need to expand *)
          )
	  @ts)
	  | _ -> ts) ast [] in
    (* emit the <structure> element *)
    Element ("structure",[],[
	   Element ("type",[],[PCData "turing"]);
	   Element ("automaton",[],
                (* emit <state> (<block>) entries *)
		MapofStr.fold (fun k v ss ->
		  Element ("block",
			   [("id",string_of_int v); (* id : unique integral *)
			    ("name",k)],            (* name : name of the state *)
                           [Element ("tag",[],[PCData ("Machine" ^ string_of_int v)]);
			    Element ("x",[],[PCData "50.0"]); (* dummy *)
			    Element ("y",[],[PCData "50.0"]); (* dummy *)
			  ] @ if k = istate         
                              then [Element ("initial",[],[])] (* mark as the initial state *)
                              else []
			    @ if List.mem k fstates
                              then [Element ("final",[],[])] (* mark as a final state *)
                              else []) 
		  ::ss) tinfo.ms []
		    @ transitions
		  )
	 ])

(* information collected for JFLAP in preprocessing *)
type jinfo = {
  isJ : SetofInt.t; (* set of initial states *)
  fsJ : SetofInt.t; (* set of final states *)
  msJ : state MapofInt.t; (* map from state id to state name *)
 gammaJ : SetofStr.t; (* set of symbols *)
 useblank : bool ; (* true if blank symbol is used *)
}

(* generic XML accessors *)

(* list of children with specified name *)
let children_with_name (tag:string) (xml:xml) : xml list =
   Xml.fold (fun res x ->
   match x with
     Element (t,_,c) -> if t = tag then x::res  else res
   | _               -> res) [] xml

(* children of a child specified with name *)
let children_of_name (tag:string) (xml:xml) : xml list =
  let cwn = children_with_name tag xml in
  match (List.length cwn) with
    1 -> let c = List.nth cwn 0 in
    Xml.children c
  | 0 -> failwith ("children_of_name: no element named " ^ tag ^ ".")
  | _ -> failwith ("children_of_name: more than one child named " ^ tag ^ ".")

(* PCData with specified name *)
let pcdata_with_name (tag:string) (xml:xml) : string =
  let cwn = children_with_name tag xml in
  match (List.length cwn) with
    1 -> let c = List.nth cwn 0 in 
    let c = Xml.children c in
    (match (List.length c) with
      1 -> pcdata (List.nth c 0)
    | 0 -> failwith ("pcdata_with_name: element " ^ tag ^ " contains no children")
    | _ -> failwith ("pcdata_with_name: more than one child under tag " ^ tag ^ "."))
  | 0 -> failwith ("pcdata_with_name: no element named " ^ tag ^ ".")
  | _ -> failwith ("pcdata_with_name: more than one child named " ^ tag ^ ".")


(* JFLAP XML to Tursi statements conversion *)
let jff2tursi (jff:xml) : statement list =
 let blocks_transitions =
  match jff with
  Element ("structure",[],[
    Element ("type",[],[PCData "turing"]);
    Element ("automaton",[],x)]) -> x 
  | _ -> failwith "not a turing machine" in
 (* first pass: detect initial state and final states, empty symbol usage  *)
 (* <initial/> -> start command
    <final/>   -> end command
    <read/> <write/> -> fill xxx (unused character) *)
 (* whether the block is the initial state by searching <initial/> element *)
 let is_initial block = Xml.fold (fun flag x ->
   match x with
     Element ("initial",_,_) -> true
   | _ -> flag) false block in
 (* whether the block is a final state by searching <final/> element *)
 let is_final block = Xml.fold (fun flag x ->
   match x with
     Element ("final",_,_) -> true
   | _ -> flag) false block in
 (* whether the empty symbol is used in <read><write> elements (if they have no content) *)
 let use_emptysym transition = Xml.fold (fun flag x ->
   match x with
     Element ("read",_,   []) -> true
   | Element ("write",  _,[]) -> true
   | _ -> flag) false transition in
 let jinfo = List.fold_right (fun x js ->
   match x with
    Element ("block",id_name, _) | Element ("state",id_name, _) ->
      let id = try (int_of_string (Xml.attrib x "id")) with
	_ -> failwith "id attribute not found" in
      let name = try (attrib x "name") with
	_ -> failwith "name attribute not found" in
      { js with
	msJ = MapofInt.add id name js.msJ; (* register id to name association *)
	isJ = if is_initial x then SetofInt.add id js.isJ else js.isJ;
	fsJ = if is_final   x then SetofInt.add id js.fsJ else js.fsJ;
      }
   | Element ("transition",_,_) ->
       { js with
	 useblank = if use_emptysym x then true else js.useblank;
	 (* collect nonempty symbols *)
	 gammaJ = Xml.fold (fun g x ->
	   match x with
	     Element ("read",_, [PCData s]) -> SetofStr.add s g 
 	   | Element ("write",_,[PCData s]) -> SetofStr.add s g
	   | _ -> g ) js.gammaJ x; }
   | _ -> js) blocks_transitions
     { isJ   = SetofInt.empty; 
       fsJ   = SetofInt.empty; 
       msJ   = MapofInt.empty; 
      gammaJ = SetofStr.empty; 
      useblank = false ; 
  } in
  let (fills,sym_or_blank) =
   if jinfo.useblank then
   (** if blank symbol is used,
     allocate a symbol and replace empty symbol with the blank symbol **)
   let find_unused_sym () : word =
     let rec fs n =
       let sym = String.make 1 (char_of_int n) in
       (* if the symbol is already in \Gamma, try with the next alphabet *)
       if SetofStr.mem sym jinfo.gammaJ then fs (n+1) else sym in
     fs (int_of_char 'b') in (* try 'b', 'c', 'd', and so on *)
   let blank = find_unused_sym () in
   ([Fill blank],
    fun tag xml ->
      match children_of_name tag xml with
	[] -> blank (* if <read> or <write> element has no content, then use blank symbol *)
      | _  -> pcdata_with_name tag xml  (* use the symbol in the content *)  )
   else
     ([],pcdata_with_name) in
 (* second pass: emit commands and the transition table *)
 (* #! start command for the initial state *)
 Start (
   match SetofInt.cardinal jinfo.isJ with
     0 -> failwith "No initial state"
   | 1 -> MapofInt.find (SetofInt.choose jinfo.isJ) jinfo.msJ
   | _ -> failwith "more than one initial states"
 ) ::
 (* #! end command for the final states *)
 End (
   match SetofInt.cardinal jinfo.fsJ with
     0 -> failwith "No final state"
   | 1 -> List.map (fun id -> MapofInt.find id jinfo.msJ) (SetofInt.elements jinfo.fsJ)
   | _ -> failwith "more than one initial states"
 ) :: 
  (fills @
    (* emit the transition table using state names and symbols (possibly using blank symbol *)
    List.fold_right (fun x ss ->
      match x with
      Element ("transition",_,_) ->
	let sCur =
	  MapofInt.find (int_of_string (pcdata_with_name "from" x)) jinfo.msJ in
	let cRead  = sym_or_blank     "read"  x in
	let cWrite = sym_or_blank     "write" x in
	let cDir   = pcdata_with_name "move"  x in
        let sNext  =
	  MapofInt.find (int_of_string (pcdata_with_name "to" x)) jinfo.msJ in
	Transition(sCur,cRead,cWrite,cDir,sNext)::ss
      | _ -> ss
   ) blocks_transitions []
  )

type config = {
  mutable j2t : bool;     (* Tursi to JFLAP *)
  mutable write : string; (* Tursi write command: implies Tursi to Tursi mode *)
}
let cf = { j2t   = false; 
	   write = "";   }

let speclist =
  Arg.align
    [
     ("-write", Arg.String (fun s->cf.write  <-s)," #! write command for Tursi");
     ("-j2t",   Arg.Unit   (fun()->cf.j2t <-true)," JFLAP to Tursi mode");
   ]

let usage_msg =
  "Tursi to JFLAP converter (reverted by -j2t option)Usage: "^Sys.executable_name^" [-j2t] [-write (tape_content)] < input_file > output_file"

(* read and process command line arguments *)
let read_args () =
  let cf = cf in 
  Arg.parse speclist (fun s -> ()) usage_msg; cf

let failwith_msg msg =
  Format.fprintf Format.err_formatter "%s@." msg;
  Arg.usage speclist usage_msg; exit 1

(* parse Tursi file *)
let parse_tm () : statement list =
  let c = stdin in Parsetursi.entry Lextursi.token (Lexing.from_channel c)

(* parse JFLAP file *)
let parse_jff () : xml =
  let c = stdin in Xml.parse_in c

(* print Tursi file *)
let print_tm (ss:statement list) : unit =
  Format.fprintf Format.std_formatter "%a@." (pp_list pp_stat) ss

(* print JFLAP file *)
let print_jff (jff:xml) : unit =
  let xmldecl="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>" in
  Format.fprintf Format.std_formatter "%s\n%s@." xmldecl (Xml.to_string_fmt jff)

(* 実行可能形式ファイルを生成するocamlcコマンドラインに並べられた
   ファイルのトップレベル式は順番に評価される。最後の式以外は
   関数やデータ型などの定義に用い、実際に実行するコマンドは
   最後にunit 型の式として記述する。unit型の戻り値は利用しない
   ためパターン部分は '_' で良い *)
   
let _ =
  let cf = read_args () in
  (* check arguments *)
  if      cf.write <> "" then
    (* Tursi to Tursi *)
    let ss = parse_tm () in
    let ss = List.map (fun s -> match s with Write s -> Write cf.write | _ -> s) ss in
    print_tm ss
  else
    if cf.j2t then (* JFLAP to Tursi *)
      let jff = parse_jff () in
      let tm  = jff2tursi jff in
      print_tm tm
    else           (* Tursi to JFLAP *)
      let tm = parse_tm () in
      let jff = tm2jff tm in
      print_jff jff
