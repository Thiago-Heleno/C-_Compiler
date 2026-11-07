%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex(void);
extern int yyparse(void);
extern FILE *yyin;

void yyerror(const char *s);
%}


%%

%%

int main(int argc, char **argv){
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Erro ao abrir arquivo '%s'\n", argv[1]);
            return 1;
        }
    }else {
        yyin = fopen("exemplo.txt", "r");
        if(!yyin){
            fprintf(stderr, "Erro ao abrir arquivo exemplo.txt \n");
            return 1;
        }
    }

    yyparse();

    return 0;
}

void yyerror(const char *s){
    fprintf(stderr, "Erro sintatico/semantico: %s\n", s);
}