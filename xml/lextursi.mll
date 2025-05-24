{
open Parsetursi
let new_line_is_read lexbuf =
  Lexing.new_line lexbuf;
  lexbuf (* 行番号情報を更新 *)
}

let space = [' ' '\t']
let digit = ['0'-'9']
let alpha = ['A'-'Z' 'a'-'z' '_' '$' '*']
let new_line = '\r' '\n' | [ '\r' '\n' ] (* 改行 *)

rule token = parse
new_line 
    { (ignore (new_line_is_read lexbuf)); NL } (* new line is not just space but used to 
         separate commands *)
| "#!"
    { COMMAND }
| "#"
    { line_comment lexbuf }
| "fill"
    { FILL }
| "write"
    { WRITE }
| "start"
    { START }
| "end"
    { END }
| "wildcard"
    { WILDCARD }
| (digit|alpha|"##")+
    (* state or word *)
    { let re = Str.regexp "##" in
      let ss2s s = Str.global_replace re "#" s in
      WORD(ss2s (Lexing.lexeme lexbuf)) }
| digit+ (* pos (currently unused) *)
    { POS(int_of_string (Lexing.lexeme lexbuf)) }
| space+
    (* 空白をスキップして字句解析を続行 *)
    { token lexbuf }
| eof			{ EOF }
| _
    (* 以上にマッチしない場合はエラーとして例外を発生 (メッセージに発生位置も含める) *)
    { failwith
        (Printf.sprintf
           "lexical analysis error: unknown token '%s' near line %d characters %d-%d"
           (Lexing.lexeme lexbuf)
	   (Lexing.lexeme_start_p lexbuf).Lexing.pos_lnum
           (Lexing.lexeme_start lexbuf)
           (Lexing.lexeme_end lexbuf)) }
and line_comment = parse
| new_line		{ token (new_line_is_read lexbuf) }
| _			{ line_comment lexbuf }
