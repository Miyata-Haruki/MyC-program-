# MyC-program <img src="https://img.shields.io/badge/-Ocaml-FFFFFF.svg?logo=ocaml&style=flat-square">
## 1. 本プロジェクトの目的
本プロジェクトでは、関数型言語OCaml を用いたMyC 言語の処理系の部分的実装を行う。処理系は授業内で配布
されたサンプルを用いて拡張を進める。サンプル配布時の処理系では、MyC プログラムによる演算で、Int 型す
なわち整数型の変数のみを扱うことができた。そのため、Float 型の変数型を追加し、Float 型の変数ないし値同
士の演算、またはInt 型とFloat 型の変数ないし値同士の演算が可能になった。また、初期の加算演算子に加え、
減算、乗算、除算演算子を追加することにより、四則演算が可能になった。加えて、剰余演算子の追加も行った。
さらに、ユーザー定義関数（サブルーチン）の追加を行った。例えば、以下のような構文の追加により、MyC プ
ログラムの一部に名前をつけ、サブルーチンとして再利用できるようにした。これにより、MyC 言語を関数型言
語として扱えるようになった。
``` ocaml
図 1: ユーザー定義関数
1 {
2  define function getter(x) {
3    print x;
4  };
5  n = 10;
6  getter(n);
7 }
```
Float 型の実装に伴い、MyC プログラムにおける変数ないし値の変数型の判定が必要になった。実装当初は、MyC
プログラムを文として評価して変数型の判定を行っていた。加算演算における変数型判定のプログラムを以下に
図2に示す。簡単のため、パターンマッチにおける式部は省略する。
``` ocaml
図 2: Add 演算における変数型判定の処理部
1 | Add(x, y, z) ->
2     (match y, z with
3      | Int m, Int n ->
4      | Float m, Float n ->
5      | Int m, Float n ->
6      | Float m, Int n ->
7      | Var m, Int n ->
8      | Int m, Var n ->
9      | Var m, Float n ->
10     | Float m, Var n ->
11     | Var m, Var n ->
```
Float 型の実装による整数型の判定を行うプログラムでは、追加した減算、乗算、除算、剰余演算に対して図2 に
示した組み合わせのパターンマッチを行っていたが、プログラムが冗長になってしまい、可読性が損なわれてい
た。そこで、図3 に示すプログラムに変更し、整数型判定を式によって行った。
``` ocaml
図 3: Add 演算における変数型判定の処理部改良後
1 | Add(x, y, z) ->
2     let type_value v =
3       match v with
4         | Int n -> float_of_int n
5         | Float n -> n
6         | Var n ->
7           match Hashtbl.find table n with
8             | Int m -> float_of_int m
9             | Float m -> m
10            | _ -> failwith "Type error in Add"
11     in
12     let value_of_y = type_value y in
13     let value_of_z = type_value z in
14     let culc = value_of_y +. value_of_z in
15     if ( culc -. floor culc = 0.0 ) then
16       Hashtbl.replace table x (Int(int_of_float culc))
17     else
18       Hashtbl.replace table x (Float culc)
```

## 2. 動作環境
以下に動作環境を示す。
• コンピュータ: MacBook Air M1 チップモデル
• OS: macOS Sequoia バージョン15.2
• 使用言語: OCaml
– ocaml-base-compiler: バージョン4.14.1
– ocaml-system: バージョン4.14.1
MyC 言語の拡張に用いたソースコードは、lexer.mll, parser.mly, syntax.ml, interpret.ml である。こ
れらソースコードは本レポートと共に提出するため、そちらを参照されたい。

## 3 実装方針
実装方針を示す。まず最初に、MyC 言語におけるFloat 型の実装を行う。Float 型の実装による、演
算子の処理行うプログラムの変更を最小限するためである。次に、Float 型に対応する演算子の追加を
行う。追加する演算子は、減算、乗算、除算、剰余演算である。最後に、ユーザ定義関数の追加を行う。
ユーザー定義関数は、関数定義と関数呼び出しを実装することにより実現する

### 3.1 Float 型の実装
まず、字句解析器生成系 (lexer.mll) に Float 型の定義である、正規表現を記述する。
```ocaml
let float = digit+ ’.’ digit+
```
”digit+”は 0∼9 の 1 つ以上の自然数、’.’ は小数点、”digit+”は小数点以下の 1 つ以上の自然数を表す。
すなわち、次の実数にマッチする。
• 正の浮動小数点数：1.234, 10.0
• 負の浮動小数点数：-1.234, -10.0
構文解析規則が s 記述されている rule 構文に次の規則を追加する。
```ocaml
| ’-’? float
{ CONST_FLOAT(float_of_string (Lexing.lexeme lexbuf)) }
```
-’ ? は負号（−）が任意でつくことを表している。また、’ ?’ は 0 または 1 回の繰り返しを意味する。  
構文木 (syntax.ml) に以下のデータ型を追加することにより、value 型に Int 型、Float 型、Var 型（変数）を格納する。  
```ocaml
(* 「変数名」を表す型 *)
type var = string
(* データ型を表す *)
type value =
  | Int of int
  | Float of float
  | Var of var
```
さらに、構文生成器 (parser.mly) に以下のトークンを記述する。  
```ocamlx
%token <string> VAR /* 変数名 */
%token <int> CONST_INT /* 整数定数 */
%token <float> CONST_FLOAT
 ```
トークンの説明を以下に示す。
```ocaml
%token <string> VAR
```
VAR は変数名を表すトークンで、このトークンの値は string 型として扱われる。  
```ocmal
%token <int> CONST_INT
```
CONST INT は整数定数を表すトークンで、このトークンの値は Int 型として扱われる。   
%token <float> CONST_FLOAT
CONST FLOAT は浮動小数点数定数を表すトークンで、このトークンは FLoat 型として扱われる。  
value ルールの追加も行う。以下に示す。  
```ocmal
value:
| CONST_INT { Int($1) }
| CONST_FLOAT { Float($1) }
| VAR { Var($1) }
```
value ルールによって、整数定数、浮動小数点定数、変数を処理する非終端記号として定義する。文の構文解析規則’statement’ において、Float 型の値を変数に代入する式を解析する規則を記述する。
```ocmal
statement:
| VAR EQUAL CONST_FLOAT
    { Const($1, Float($3)) }
```
変数への値の代入文における右辺の変数部:’VAR’ を’value’ に置き換える。また、while 文内の変数部についても同様に置き換える。も MyC プログラム内で Float 型の変数を扱うことができる。以下に ADD演算の場合の変更例を示す。”Old”は変更前、”New”は変更後を表す。
```ocmal
/*Old*/
    | VAR EQUAL VAR PLUS VAR
/*New*/
    | VAR EQUAL value PLUS value
```
ここで、現段階では Float 型の変数を用いた演算は行うことができない。そこで、次章の”1.2 演算子の追加”では、追加した演算子の説明とともに、演算における Float 型の実装の説明を行う。  
## 3.2 演算子の追加
Float 型の実装とデータ型 value の追加により、MyC プログラムの解釈実行を行う解釈器 interpret に
おいて、Int 型、Float 型、VAR 型の場合分けが必要になった。加算、減算、乗算、除算、剰余演算にお
いてデータ型による場合分けを行う。
### 3.1.1 加算
以下に、加算 (Add 文) における変数型判定を行うプログラムを以下に示す。
```ocaml
図 4: Add 演算における変数型判定の処理部
1 | Add(x, y, z) ->
2     let type_value v =
3       match v with
4         | Int n -> float_of_int n
5         | Float n -> n
6         | Var n ->
7           match Hashtbl.find table n with
8             | Int m -> float_of_int m
9             | Float m -> m
10            | _ -> failwith "Type error in Add"
11     in
12     let value_of_y = type_value y in
13     let value_of_z = type_value z in
14     let culc = value_of_y +. value_of_z in
15     if ( culc -. floor culc = 0.0 ) then
16       Hashtbl.replace table x (Int(int_of_float culc))
17     else
18       Hashtbl.replace table x (Float culc)
```
Add 文におけるパターンマッチ式では、引数を value 型の変数 v とする関数 type value を宣言する。関数内では、仮引数 v に対してパターンマッチを行い、value 型の変数のデータ型を全て Float 型に変換している。例えば、Add(x, y, z) は x = y + z という形の式を表しており、まず右辺の項 y と項 z を Float型に変換する。Float 型に変換された値はそれぞれ、変数 value of y,value of z に格納される。次に、変数 culc に ﬂoat 型の変数 value of y と value of z の加算結果を格納し、次式 culc -. ﬂoor culc = 0.0 により、演算結果の Int 型または Float 型の判定を行っている。

### 3.2.2 減算
減算は加算と同様であるため、最初に変更点を示す。
let culc = value_of_y -. value_of_z
4 の 14 行目、変数 culc について、変数 value of y と変数 value of z 同士の演算子’+.’ を’-.’ に変更する。
以下に、減算における変数型判定を行うプログラムを図 5 に示す。
図 5: Add 演算における変数型判定の処理部
```ocaml
1 | Sub(x, y, z) ->
2     let type_value v =
3       match v with
4         | Int n -> float_of_int n
5         | Float n -> n
6         | Var n ->
7           match Hashtbl.find table n with
8             | Int m -> float_of_int m
9             | Float m -> m
10            | _ -> failwith "Type error in Sub"
11     in
12     let value_of_y = type_value y in
13     let value_of_z = type_value z in
14     let culc = value_of_y -. value_of_z in
15     if ( culc -. floor culc = 0.0 ) then
16       Hashtbl.replace table x (Int(int_of_float culc))
17     else
18       Hashtbl.replace table x (Float culc)
```
### 3.2.3 除算
除算を処理するプログラムを図 6 に示す。
図 6: Sub 演算における変数型判定の処理部
```ocmal
1 | Div(x, y, z) ->
2     let type_value v =
3       match v with
4         | Int n -> float_of_int n
5         | Float n -> n
6         | Var n ->
7           match Hashtbl.find table n with
8             | Int m -> float_of_int m
9             | Float m -> m
10            | _ -> failwith "Type error in Div"
11     in
12     let value_of_y = type_value y in
13     let value_of_z = type_value z in
14     if value_of_z = 0.0 then
15       failwith "Division by zero"
16     else
17       let culc = value_of_y /. value_of_z in
18       if ( culc -. floor culc = 0.0 ) then
19         Hashtbl.replace table x (Int(int_of_float culc))
20       else
21         Hashtbl.replace table x (Float culc)
```
除算についても同様に処理部を記述するが、非除数に対して除数が 0 の場合は不定形のため、図 6 の14∼15 行目に示す、エラー文を追加する。
```ocmal
if value_of_z = 0.0 then
  failwith "Division by zero"
```

### 3.2.4 乗算
乗算も加算・減算と同様であるため、最初に変更点を示す。同様に、変数 culc について、変数 value of y
と変数 value of z 同士の演算子を’*.’ に変更する。
```ocaml
let culc = value_of_y *. value_of_z
```
以下図 7 に、乗算における変数型判定を行うプログラムを示す。
図 7: Mul 演算における変数型判定の処理部
```ocmal
1 | Mul(x, y, z) ->
2     let type_value v =
3       match v with
4         | Int n -> float_of_int n
5         | Float n -> n
6         | Var n ->
7           match Hashtbl.find table n with
8             | Int m -> float_of_int m
9             | Float m -> m
10            | _ -> failwith "Type error in Mul"
11    in
12    let value_of_y = type_value y in
13    let value_of_z = type_value z in
14    let culc = value_of_y *. value_of_z in
15    if ( culc -. floor culc = 0.0 ) then
16      Hashtbl.replace table x (Int(int_of_float culc))
17    else
18      Hashtbl.replace table x (Float culc)
```

### 3.2.5 剰余演算
以下の図 8 に剰余演算の変数型判定を行うプログラムを示す。エラー文は簡単のため、”エラー文”で
示す。
図 8: Div 演算における変数型判定の処理部
1 let type_value v =
2     match v with
3       | Int n -> n
4       | Float n -> エラー文
5       | Var n ->
6         match Hashtbl.find table n with
7           | Int m -> m
8           | Float m -> エラー文
9           | _ -> failwith "Type error in Mod"
10    in
11    let value_of_y = type_value y in
12    let value_of_z = type_value z in
13    let culc = value_of_y mod value_of_z in
14      Hashtbl.replace table x (Int(culc))
図 8 より、剰余演算において Float 型は定義できないため、エラーを発生させている。

## 3.3 ユーザ定義関数の追加
ユーザー定義関数（サブルーチン）の追加を行った。MyC 言語でユーザー定義関数を実現するには、処理系において、関数の定義と関数の呼び出しが必要になった。まず、字句解析生成系 (lexer.mll) において、rule 構文に以下の予約語を追加する。
```ocaml
| "define"
    { DEFINE }
| "function"
    { FUNCTION }
```
構文解析器 (perser.mly) に関数の仮引数、関数呼び出し時の実引数を解析する規則を追加する。以下にx示す。
```ocaml
1 /* 仮引数 (formal argment) */
2 formal_arg:
3   | VAR { [$1] }
4   | VAR COMMA formal_arg { $1 :: $3 }
5   | { [] }関数呼び出し時の引数リスト
6
7 /**/実引数
8 /*(actual argment)*/
9 actual_arg:
10  | VAR { [$1] }
11  | VAR COMMA actual_arg { $1 :: $3 }
12  | { [] }
```
formal arg は仮引数、actual arg は関数呼び出し時の実引数を解析する規則である。
```ocaml
1 | DEFINE FUNCTION VAR LPAREN formal_arg RPAREN LBRACE statement_list RBRACE
2     { Define($3, $5, $8) }
3 | VAR LPAREN actual_arg RPAREN
4     /* 関数呼び出し */
5     { Call($1,$3) }
```
関数定義では、「def f() 文 1; 文 2; … ;」という形の文を解析する。構文木 (syntax.ml) に、関数定義及び関数呼び出しの木構造を表すため、文を表すデータ型 statement に
```ocmal
1 | Define of var * var list * statement list
2 | Call of var * var list
```
を追加する。関数定義において、関数名は VAR 型、仮引数は VAR 型のリスト、関数本体は statementlist 型にする。MyC プログラムを解釈実行する解釈器 (interpret.ml) に図 9 に示す。

```ocaml
図 9: ユーザー定義関数を解釈するプログラム
1 (* 関数名をキーにして、引数と関数本体を格納 *)
2 let table:(var, value) Hashtbl.t = Hashtbl.create 10
3 let function_table:(var,(var list * statement list)) Hashtbl.t = Hashtbl.create 50
4
5 let rec interpret (s:statement) = match s with
6     (* 関数定義 *)
7     | Define(name,args,body) ->
8     Hashtbl.add function_table name (args, body)
9     (* 関数呼び出し *)
10     | Call(name, params) ->
11         let (args, body) = Hashtbl.find function_table name in
12         let local_table = Hashtbl.copy table in
13         List.iter2 (fun arg param ->
14             Hashtbl.replace local_table arg (Hashtbl.find table param)) args params;
15         let statements = body in
16         List.iter (fun stat -> update stat local_table table) statements;
17     | _ -> ()
18 (* ハッシュテーブルの更新と実行 *)
19 and update stat env_table table =
20     let old_table = Hashtbl.copy table in
21     Hashtbl.clear table;
22     Hashtbl.iter (fun name formal -> Hashtbl.replace table name formal) env_table;
23     interpret stat;
24     Hashtbl.clear table;
25     Hashtbl.iter (fun name formal -> Hashtbl.replace table name formal) old_table
```

### 3.3.1 関数定義
図 9 より、説明を以下に示す。  
関数本体を格納するハッシュテーブル function table を定義する。ここではソースプログラムの可読性
のため、ハッシュテーブルのキーと値の型を明示的に宣言する。MyC プログラム本体を格納するハッ
シュテーブル table も同様に明示的に宣言する。
```ocaml
let table:(var, value) Hashtbl.t = Hashtbl.create 10
let function_table:(var,(var list * statement list)) Hashtbl.t = Hashtbl.create 50
```
関数呼び出しでは、関数を保存するハッシュテーブル”function table” に、関数名をキーとし引数と関
数本体を追加する。
```ocmal
| Define(name,args,body) ->
    Hashtbl.add function_table name (args, body)
```
### 3.3.2 関数呼び出し
関数呼び出しでは、まず変数 args と変数 body に、関数名 name をキーとして fuction table から値で
ある、関数の引数のリストと関数本体を格納する。
```ocaml
let (args, body) = Hashtbl.find function_table name in
```
ここで、MyC プログラム本体の書き換えを防ぐため、table を関数内のローカル変数 local table にコ
ピーする。
```ocaml
let local_table = Hashtbl.copy table in
```
List.iter2 を用いて、仮引数の変数と実引数が格納する値の対応をローカルテーブルに反映する。ここ
で、変数 params には関数の実引数がリストとして格納されている。
```ocaml
List.iter2 (fun arg param ->
  Hashtbl.replace local_table arg (Hashtbl.find table param)) args params;
```
関数本体 body を変数 statements に格納する。ここで、関数本体 statements、local table、table を引数
として、ハッシュテーブルの更新と関数本体の実行を行う関数 update を実行する。
```ocaml
let statements = body in
List.iter (fun stat -> update stat local_table table) statements;
```
以下の図 10 より、関数 update では、現在のハッシュテーブル table を old table としてコピーし、table
を空にする。関数内は table を用いて実行するため、table を env table の内容に置き換える。これによ
り、interpret 内で関数の引数情報を格納した table を扱うことができる。関数本体の解釈後、再び table
を空にし、old table を用いて元の状態に復元する。

```ocaml
図 10: 関数 update
1 and update stat env_table table =
2     let old_table = Hashtbl.copy table in (* 現在のハッシュテーブルをコピー *)
3     Hashtbl.clear table; (* テーブルを新しい環境に切り替え *)
4     Hashtbl.iter (fun name formal -> Hashtbl.replace table name formal) env_table;
5     interpret stat; (* 関数の本体を解釈 *)
6     Hashtbl.clear table; (* 処理後に元の状態を復元 *)
7     Hashtbl.iter (fun name formal -> Hashtbl.replace table name formal) old_table
```

## 4 評価
節 1.1 に示した動作環境のもと、MyC 言語に追加した演算子と機能の動作を確認する。
まず、演算子の検証を行う。加算・減算・乗算・除算・剰余演算を検証するプログラムは、operator.myc
に示す。以下にプログラムの内容を演算子ごとに示し、出力結果も示す。
### 4.1 加算演算子の検証
以下、図 11 に加算演算子の検証を行う Myc プログラムを示す。
```ocaml
図 11: 加算演算子の検証プログラム
1 int = 1;
2 float = 1.0;
3
4 add = int + float;
5 print add; -> 2
6 float = float + 0.1;
7 add = float + int;
8 print add; -> 2.100000
```
出力結果より、int 型変数と ﬂoat 型変数の加算・ﬂoat 型変数と ﬂoat 型の値の計算ができていることが
わかる。1 + 1.0 の計算結果は、有効数字 2 桁で”2.0”であるが、interpret.ml に定義した整数型判定に
より、小数点以下の位を含まないため、”2”に変換されていることがわかる。一方、ﬂoat = ﬂoat + 0.1
により ﬂoat の値を更新後の変数 add の値は 1.1 + 1 = 2.1 となり、その出力結果は ﬂoat 型すなわち、
2.100000 となっていることがわかる。

### 4.2 減算演算子の検証
以下、図 12 に減算演算子の検証を行う Myc プログラムを示す。
```ocaml
図 12: 減算演算子の検証プログラム
1 int = 10;
2 float = 10.0;
3 sub = int - float;
4 print sub; -> 0
5 float = float - 0.1;
6 sub = int - float;
7 print sub; -> 0.100000
```
図 12 より、加算演算子と同様、int 型変数と ﬂoat 型変数・ﬂoat 型変数と ﬂoat 型の値の計算ができてい
ることがわかる。sub = 10 - 10.0 の計算結果は”0.0”であるが、小数点以下の値が 0 であるため、”0”に
変換されていることがわかる。一方、ﬂoat = ﬂoat - 0.1 により、変数 ﬂoat の値が 9.9 に更新後の変数
sub の値は、10 - 9.9 の計算により、ﬂoat 型の値 ”0.100000” と出力されていることがわかる。

### 4.3 除算演算子の検証
以下、図 13 に除算演算子の検証を行う Myc プログラムを示す。
```ocaml
図 13: 除算演算子の検証プログラム
1 int = 1;
2 float = 1.0;
3 div = float / 2;
4 print div; -> 0.500000
5 div = int / 2;
6 print div; -> 0.500000
```
図 13 は、変数 int と変数 ﬂoat それぞれを 2 で割った商を出力するプログラムである。その出力結果は
どちらも”0.5”であり、Myc 言語の ﬂoat 型に変換され”0.500000” となっていることがわかる。

### 4.4 乗算演算子の検証
以下、図 14 に乗算演算子の検証を行う Myc プログラムを示す。
```ocaml
図 14: 乗算演算子の検証プログラム
1 int = 1;
2 float = 1.0;
3 mul = int * float;
4 print mul; -> 1
5 mul = 0.1 * float;
6 print mul; -> 0.100000
```
図 13 より、int 型変数と ﬂoat 型変数・ﬂoat 型の値と ﬂoat 型変数の乗算ができていることがわかる。す
なわち、interpret.ml に記述した整数型判定により、小数点以下の値が 0 である場合は int 型に変換し、
小数点以下の値が存在する場合は ﬂoat 型に変換されていることがわかる。

### 4.5 剰余演算子の検証
以下、図 15 に剰余演算子の検証を行う Myc プログラムを示す。
```ocaml
図 15: 剰余演算子の検証プログラム
1 a = 5;
2 b = 3;
3 mod = a % b;
4 print mod; -> 2
5 b = b + 0.1;
6 mod = a % b;
7 print mod; -> Fatal error: exception Failure("This expression has
type float but an expression was expected of type int")
```
図 15 は、変数 a(=5) を変数 b(=3) で割った余りを求めるプログラムである。まず、mod = a % b によ
り、計算結果は正しく”3”と出力されていることがわかる。次に、変数 b の値を 3.1 に更新して同様の計
算を行う。すると、エラー文: ”This expression has type ﬂoat but an expression was expected of type
int” が出力されていることがわかる。これは、Myc 言語のコンパイラは int 型を期待しているが、式中
に ﬂoat 型を含んでしまっているという内容のエラー文である。これは、剰余演算で定義できない ﬂoat
型の変数を検出できていること示している。
### 4.6 ユーザ定義関数の検証
ユーザ定義関数の検証を行う。検証するプログラムは、function.myc に示す。以下、図 16 はユーザ
定義関数の検証を行う Myc プログラムであり、10 から 0 までのカウントダウンを行うプログラムであ
る。myprint 関数は、引数 x を組み込み関数 print により出力する関数である。図 17 に出力結果も示す。
```ocmal
図 16: ユーザ定義関数の検証プログラム
1 {
2   define function myprint(x){
3     print x;
4   };
5   fin = -1;
6   minus_one = -1;
7   sum = 0;
8   n = 10;
9   while (n > fin) {
10    myprint(n);
11    n = n + minus_one;
12  };
13 }
```
```ocaml
図 17: 図 16 の出力結果
10
9
8
7
6
5
4
3
2
1
0
```
図 17 より、ユーザー定義関数 myprint() によって、10 から 0 までの値を出力できていることがわかる。
## 5 まとめと今後の課題
MyC 言語の拡張をテーマに、ﬂoat 型の追加・算術演算子の追加・ユーザ定義関数の追加を行った。さ
らに、ﬂoat 型の追加に伴う変数ないし値型の判定法の改良を行い、interpret.ml における可読性の向上
を図った。その結果、プログラムの中の演算結果において、小数点以下の値の有無によって int 型また
は ﬂoat 型を判定する仕様に変更した。  
現在の Myc 言語処理系では 2 項演算子のみを扱うことができる。今後の課題として、そのため定数の畳
み込みを行い、3 項以上の演算を可能にしたい。さらに、ユーザー定義関数内での変数宣言の機能を追
加することにより、関数型プログラミング言語としての機能を向上させたい。


