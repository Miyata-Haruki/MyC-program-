%{
open Syntaxtursi
%}

%token <string> WORD /* word */
%token <int> POS  /* pos */

%token COMMAND    /* #! */

/* keywrods */
%token FILL       /* "fill" */
%token WRITE      /* "write" */
%token START      /* "start" */
%token END        /* "end" */
%token WILDCARD   /* "wildcard" */

%token NL         /* 改行 */
%token EOF        /* End of File */

%type <Syntaxtursi.statement list> entry  /* type of the abstract syntax tree */
%start entry  /* start symbol of the grammar */

%%

statement: /* 一つの文を構文解析するルール */
| COMMAND START WORD      /* #! start state */
    { Start($3) }        
| COMMAND END word_list   /* #! end states */
    { End($3) }
| COMMAND FILL  WORD      /* #! fill word */
    { Fill($3) }
| COMMAND WRITE WORD      /* #! write word */
    { Write($3) }
| COMMAND WILDCARD WORD   /* #! wildcard word */
    { Wildcard($3) }
| WORD WORD WORD WORD WORD /* transition */
    { Transition ($1,$2,$3,$4,$5)}
| error /* 以上にマッチしない場合はエラーとして例外を発生 */
    { (* print line and column numbers as well *)
      let start_pos = Parsing.symbol_start_pos () in
      let end_pos   = Parsing.symbol_end_pos () in
      failwith
        (Printf.sprintf
           "parse error near position (line %d, col %d)-(line %d, col %d)"
           (start_pos.Lexing.pos_lnum)
           (start_pos.Lexing.pos_cnum - start_pos.Lexing.pos_bol)
           (end_pos.Lexing.pos_lnum)
           (end_pos.Lexing.pos_cnum - start_pos.Lexing.pos_bol)) }

entry:
|  statement_list EOF
{ $1 }

statement_list: /* 文の列を構文解析するルール */
| statement NL statement_list /* newline may separate statements */
    /* 改行を挟んだ一つの文を，文のリストの先頭に追加 */
    { $1 :: $3 }
| statement statement_list
    /* 一つの文を，文のリストの先頭に追加 */
    { $1 :: $2 }
| NL statement_list  /* empty line is also allowed */
    /* 一つの文を，文のリストの先頭に追加 */
    { $2 }
| /* 空列 */
    { [] } /* 空リストを返す */
word_list: /* 文の列を構文解析するルール */
| WORD word_list
    /* 一つの文を，文のリストの先頭に追加 */
    { $1 :: $2 }
| /* 空列 */
    { [] } /* 空リストを返す */
