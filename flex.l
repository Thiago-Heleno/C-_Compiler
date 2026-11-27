%option noyywrap

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define YY_DECL int yylex()

#include "bison.tab.h"

int linha = 1;
%}

%%

    /* Consumir comentarios */

\/\*([^*]|\*+[^*/])*\*+\/ {
    for (int i = 0; yytext[i] != '\0'; i++) {
        if (yytext[i] == '\n') linha++;
    }
}

\/\/[^\n]* ;

    /* Palavras Chave */

(if) {
    return T_IF;
}

(else) {
    return T_ELSE;
}

(int) {
    return T_KW_INT;
}

(void) {
    return T_VOID;
}

(return) {
    return T_RETURN;
}

(while) {
    return T_WHILE;
}

    /* Identificadores e Numeros */

[_a-zA-Z][_a-zA-Z0-9]* {
    yylval.id = strdup(yytext);
    return T_ID;
}

[0-9]+ {
    yylval.ival = atoi(yytext);
    return T_INT;
}

    /* Operadores */

"<=" {
    return T_LE;
}

"<" {
    return T_LT;
}

>= {
    return T_GE;
}

> {
    return T_GT;
}

== {
    return T_EQ;
}

!= {
    return T_NE;
}

= {
    return T_ASSIGN;
}

\+ {
    return T_MAIS;
}

\- {
    return T_MENOS;
}

\* {
    return T_MULT;
}

\/ {
    return T_DIV;
}

    /* Delimitadores */

\( {
    return T_LPAR;
}

\) {
    return T_RPAR;
}

\[ {
    return T_LBRACK;
}

\] {
    return T_RBRACK;
}

\{ {
    return T_LBRACE;
}

\} {
    return T_RBRACE;
}

; {
    return T_SEMI;
}

, {
    return T_COMMA;
}

    /* Quebra de linha e espacos em branco */

\n {
    linha++;
}

[ \t\r]+ ;

    /* Erro lexico */

. {
    fprintf(stderr, "ERRO LEXICO: \"%s\" - LINHA: %d\n", yytext, linha);
    exit(1);
}
%%
