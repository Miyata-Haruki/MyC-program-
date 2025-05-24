(* simple definition of syntax tree of Tursi *)
type word = string  (* words for input/output symbol and head move *)
type state = string (* words for state names *)

(* commands and transitions *)
type statement = 
  | Start of state        (* #! start state    = initial state *)
  | End   of state list   (* #! end   state+   = set of final states *)
  | Fill  of word         (* #! fill word      = blank symbol *)
  | Write of word         (* #! write word     = symbols written on the tape *)
  | Wildcard of word      (* #! wildcard word  = wildcard symbol *)
  | Transition of state * word * word * word * state
   (* current state, input symbol, output symbol, direction, next state *)
  
