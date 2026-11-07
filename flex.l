%option noyywrap
 
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
%}

%%
[_a-zA-Z][_a-zA-Z0-9]* {
    return T_ID;
}

[0-9]+\.[0-9]+ {
    return T_FLOAT;
}

[0-9]+ {
    return T_INT;
}
%%