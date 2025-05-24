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
1 {
2 define function getter(x) {
3 print x;
4 };
5 n = 10;
6 getter(n);
7 }
```
Float 型の実装に伴い、MyC プログラムにおける変数ないし値の変数型の判定が必要になった。実装当初は、MyC
プログラムを文として評価して変数型の判定を行っていた。加算演算における変数型判定のプログラムを以下に
示す。簡単のため、パターンマッチにおける式部は省略する。
``` ocaml
1 | Add(x, y, z) ->
2 (match y, z with
3 | Int m, Int n ->
4 | Float m, Float n ->
5 | Int m, Float n ->
6 | Float m, Int n ->
7 | Var m, Int n ->
8 | Int m, Var n ->
9 | Var m, Float n ->
10 | Float m, Var n ->
11 | Var m, Var n ->
```
Float 型の実装による整数型の判定を行うプログラムでは、追加した減算、乗算、除算、剰余演算に対して図2 に
示した組み合わせのパターンマッチを行っていたが、プログラムが冗長になってしまい、可読性が損なわれてい
た。そこで、図3 に示すプログラムに変更し、整数型判定を式によって行った。
``` ocaml
Listing 3: Add 演算における変数型判定の処理部改良後
1 | Add(x, y, z) ->
2 let type_value v =
3 match v with
4 | Int n -> float_of_int n
5 | Float n -> n
6 | Var n ->
7 match Hashtbl.find table n with
8 | Int m -> float_of_int m
9 | Float m -> m
10 | _ -> failwith "Type error in Add"
11 in
12 let value_of_y = type_value y in
13 let value_of_z = type_value z in
14 let culc = value_of_y +. value_of_z in
15 if ( culc -. floor culc = 0.0 ) then
16 Hashtbl.replace table x (Int(int_of_float culc))
17 else
18 Hashtbl.replace table x (Float culc)
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
