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

%token NL         /* ���� */
%token EOF        /* End of File */

%type <Syntaxtursi.statement list> entry  /* type of the abstract syntax tree */
%start entry  /* start symbol of the grammar */

%%

statement: /* ��Ĥ�ʸ��ʸ���Ϥ���롼�� */
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
| error /* �ʾ�˥ޥå����ʤ����ϥ��顼�Ȥ����㳰��ȯ�� */
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

statement_list: /* ʸ�����ʸ���Ϥ���롼�� */
| statement NL statement_list /* newline may separate statements */
    /* ���Ԥ򶴤����Ĥ�ʸ��ʸ�Υꥹ�Ȥ���Ƭ���ɲ� */
    { $1 :: $3 }
| statement statement_list
    /* ��Ĥ�ʸ��ʸ�Υꥹ�Ȥ���Ƭ���ɲ� */
    { $1 :: $2 }
| NL statement_list  /* empty line is also allowed */
    /* ��Ĥ�ʸ��ʸ�Υꥹ�Ȥ���Ƭ���ɲ� */
    { $2 }
| /* ���� */
    { [] } /* ���ꥹ�Ȥ��֤� */
word_list: /* ʸ�����ʸ���Ϥ���롼�� */
| WORD word_list
    /* ��Ĥ�ʸ��ʸ�Υꥹ�Ȥ���Ƭ���ɲ� */
    { $1 :: $2 }
| /* ���� */
    { [] } /* ���ꥹ�Ȥ��֤� */
