DIR = xml
SRC = syntaxtursi.ml parsetursi.mly lextursi.mll interpret.ml Makefile README 

OCAMLC = ocamlc -I ./xml-light


# lextursi.cmo: parsetursi.cmi
# parsetursi.cmi : syntaxtursi.cmi
# parsetursi.cmi : parsetursi.mli

%.mli %.ml: %.mly
	ocamlyacc $< 

%.ml: %.mll
	ocamllex $< 

%cmi %.cmo: %.ml
	$(OCAMLC) -c $<

%.cmi: %.mli
	$(OCAMLC) $<


# interpret: syntaxtursi.ml parsetursi.mli parsetursi.ml lextursi.ml interpret.ml
# 	$(OCAMLC) xml-light.cma str.cma $^ -o interpret

interpret: syntaxtursi.cmo parsetursi.cmi parsetursi.cmo lextursi.cmo interpret.cmo
	$(OCAMLC) xml-light.cma str.cma syntaxtursi.cmo parsetursi.cmo lextursi.cmo interpret.cmo -o interpret



.PHONY: all clean

all: interpret

$(DIR).zip: $(SRC)
	pushd  .. ; ls $(DIR) ;	zip $@ $(addprefix $(DIR)/, $(SRC))

clean:
	-rm *.cmi *.cmo interpret parsetursi.ml parsetursi.mli lextursi.ml *~
