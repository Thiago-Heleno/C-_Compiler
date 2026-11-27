%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "utils.h"

extern int yylex(void);
extern int yyparse(void);
extern int linha;

extern FILE *yyin;

void yyerror(const char *s);

Simbolo *tabela = NULL;
char escopo_atual[128] = "global";
Tipo tipo_funcao_atual = TIPO_VOID;

typedef enum {
    AST_NUMERO,
    AST_OPERADOR,
    AST_CHAMADA,
    AST_EXPRESSAO_PENDENTE
} TipoNoAST;

struct NoAST {
    TipoNoAST tipo;
    const char *operador;
    int numero;
    NoAST *esquerda;
    NoAST *direita;
    char *nome_funcao;
    NoAST *argumentos;
    NoAST *proximo_argumento;
    NoAST *proximo_alocado;
};

/* A lista guarda os nos ate o fim da analise, inclusive em caso de erro. */
static NoAST *nos_alocados = NULL;

static NoAST *novo_no(TipoNoAST tipo)
{
    NoAST *no = malloc(sizeof *no);
    if (no == NULL) {
        fprintf(stderr, "Erro ao alocar memoria para a AST.\n");
        exit(EXIT_FAILURE);
    }

    *no = (NoAST){.tipo = tipo, .proximo_alocado = nos_alocados};
    nos_alocados = no;
    return no;
}

static NoAST *novo_no_binario(const char *operador, NoAST *esquerda, NoAST *direita)
{
    if (esquerda == NULL || direita == NULL) {
        return NULL;
    }
    NoAST *no = novo_no(AST_OPERADOR);
    no->operador = operador;
    no->esquerda = esquerda;
    no->direita = direita;
    return no;
}

static ListaAST anexa_argumento(ListaAST lista, Valor valor)
{
    if (valor.tipo == TIPO_ERRO) {
        lista.tem_erro = 1;
        return lista;
    }

    NoAST *expressao = valor.ast;
    if (expressao == NULL) {
        /* shortcut: preserva a posicao ate a expressao ganhar um no proprio. */
        expressao = novo_no(AST_EXPRESSAO_PENDENTE);
    }
    if (lista.ultimo == NULL) {
        lista.primeiro = expressao;
    } else {
        lista.ultimo->proximo_argumento = expressao;
    }
    lista.ultimo = expressao;
    return lista;
}

static NoAST *novo_no_chamada(const char *nome, NoAST *argumentos)
{
    NoAST *no = novo_no(AST_CHAMADA);
    no->nome_funcao = strdup(nome);
    if (no->nome_funcao == NULL) {
        fprintf(stderr, "Erro ao copiar o nome da funcao para a AST.\n");
        exit(EXIT_FAILURE);
    }
    no->argumentos = argumentos;
    return no;
}

static void imprime_ast(const NoAST *no, int indentacao)
{
    if (no == NULL) {
        return;
    }

    switch (no->tipo) {
    case AST_NUMERO:
        printf("%*s%d\n", indentacao, "", no->numero);
        break;
    case AST_OPERADOR:
        printf("%*s%s\n", indentacao, "", no->operador);
        imprime_ast(no->esquerda, indentacao + 2);
        imprime_ast(no->direita, indentacao + 2);
        break;
    case AST_CHAMADA:
        printf("%*schamada %s\n", indentacao, "", no->nome_funcao);
        for (const NoAST *arg = no->argumentos; arg != NULL; arg = arg->proximo_argumento) {
            imprime_ast(arg, indentacao + 2);
        }
        break;
    case AST_EXPRESSAO_PENDENTE:
        printf("%*s<expressao ainda sem AST>\n", indentacao, "");
        break;
    }
}

static void libera_ast(void)
{
    while (nos_alocados != NULL) {
        NoAST *no = nos_alocados;
        nos_alocados = no->proximo_alocado;
        free(no->nome_funcao);
        free(no);
    }
}
%}


%code requires {
    #include "utils.h"
}

%union {
    int ival;
    char *id;
    Tipo tipo;
    Valor val;
    ListaAST lista;
    const char *op;
}

/* ---- TOKENS ---- */

%token<id> T_ID
%token<ival> T_INT

/* Palavras Chave */
%token T_IF T_ELSE T_KW_INT T_VOID T_RETURN T_WHILE

/* Operadores */
%token T_LE T_LT T_GE T_GT T_EQ T_NE T_ASSIGN
%token T_MAIS T_MENOS T_MULT T_DIV

%left T_MAIS T_MENOS
%left T_MULT T_DIV

/* Delimitadores */
%token T_LPAR T_RPAR T_LBRACK T_RBRACK T_LBRACE T_RBRACE T_SEMI T_COMMA

%type<tipo> tipo_especificador
%type<val> expressao simples_expressao soma_expressao termo fator var ativacao
%type<lista> args arg_lista
%type<op> relacional

/* Resolucao do conflito dangling-else */
%nonassoc T_LOWER_THAN_ELSE
%nonassoc T_ELSE

%start programa

%%

    programa
    : declaracao_lista
    ;

    declaracao_lista
    : declaracao_lista declaracao
    | declaracao
    ;

    declaracao
    : var_declaracao
    | fun_declaracao
    ;

    var_declaracao
    : tipo_especificador T_ID T_SEMI
        {
    if ($1 == TIPO_VOID) {
    fprintf(stderr, "ERRO SEMANTICO: variavel '%s' nao pode ser void - LINHA: %d\n", $2, linha);
    } else if (!insere_simbolo(tabela, $2, $1, escopo_atual, linha, 0)) {
    fprintf(stderr, "ERRO SEMANTICO: identificador '%s' - LINHA: %d\n", $2, linha);
    }
    free($2);
    }
    | tipo_especificador T_ID T_LBRACK T_INT T_RBRACK T_SEMI
        {
    if ($1 == TIPO_VOID) {
    fprintf(stderr, "ERRO SEMANTICO: vetor '%s' nao pode ser void - LINHA: %d\n", $2, linha);
    } else if (!insere_simbolo(tabela, $2, TIPO_INT_ARRAY, escopo_atual, linha, 0)) {
    fprintf(stderr, "ERRO SEMANTICO: identificador '%s' - LINHA: %d\n", $2, linha);
    }
    free($2);
    }
    ;

    tipo_especificador
    : T_KW_INT { $$ = TIPO_INT; }
    | T_VOID { $$ = TIPO_VOID; }
    ;

    fun_declaracao
    : tipo_especificador T_ID T_LPAR
        {
    if (!insere_simbolo(tabela, $2, $1, "global", linha, 1)) {
    fprintf(stderr, "ERRO SEMANTICO: identificador '%s' - LINHA: %d\n", $2, linha);
    }
    snprintf(escopo_atual, sizeof(escopo_atual), "%s", $2);
    tipo_funcao_atual = $1;
    }
    params T_RPAR composto_decl
        {
    strcpy(escopo_atual, "global");
    tipo_funcao_atual = TIPO_VOID;
    free($2);
    }
    ;

    params
    : param_lista
    | T_VOID
    ;

    param_lista
    : param_lista T_COMMA param
    | param
    ;

    param
    : tipo_especificador T_ID
        {
    if ($1 == TIPO_VOID) {
    fprintf(stderr, "ERRO SEMANTICO: parametro '%s' nao pode ser void - LINHA: %d\n", $2, linha);
    } else if (!insere_simbolo(tabela, $2, $1, escopo_atual, linha, 0)) {
    fprintf(stderr, "ERRO SEMANTICO: identificador '%s' - LINHA: %d\n", $2, linha);
    }
    free($2);
    }
    | tipo_especificador T_ID T_LBRACK T_RBRACK
        {
    if ($1 == TIPO_VOID) {
    fprintf(stderr, "ERRO SEMANTICO: parametro '%s' nao pode ser void - LINHA: %d\n", $2, linha);
    } else if (!insere_simbolo(tabela, $2, TIPO_INT_ARRAY, escopo_atual, linha, 0)) {
    fprintf(stderr, "ERRO SEMANTICO: identificador '%s' - LINHA: %d\n", $2, linha);
    }
    free($2);
    }
    ;

    composto_decl
    : T_LBRACE local_declaracoes statement_lista T_RBRACE
    ;

    local_declaracoes
    : local_declaracoes var_declaracao
    | /* vazio */
    ;

    statement_lista
    : statement_lista statement
    | /* vazio */
    ;

    statement
    : expressao_decl
    | composto_decl
    | selecao_decl
    | iteracao_decl
    | retorno_decl
    ;

    expressao_decl
    : expressao T_SEMI
        {
            /* shortcut: imprime arvores de expressoes isoladas ate existir uma raiz de programa. */
            if ($1.ast != NULL) {
                puts("\n---- AST DA EXPRESSAO ----");
                imprime_ast($1.ast, 0);
            }
        }
    | T_SEMI
    ;

    selecao_decl
    : T_IF T_LPAR expressao T_RPAR statement %prec T_LOWER_THAN_ELSE
        {
    verifica_condicao($3, "if");
    }
    | T_IF T_LPAR expressao T_RPAR statement T_ELSE statement
        {
    verifica_condicao($3, "if");
    }
    ;

    iteracao_decl
    : T_WHILE T_LPAR expressao T_RPAR statement
        {
    verifica_condicao($3, "while");
    }
    ;

    retorno_decl
    : T_RETURN T_SEMI
        {
    verifica_retorno(make_tipo(TIPO_VOID, linha), tipo_funcao_atual, linha);
    }
    | T_RETURN expressao T_SEMI
        {
    verifica_retorno($2, tipo_funcao_atual, linha);
    }
    ;

    expressao
    : var T_ASSIGN expressao
        {
    $$ = op_atrib($1, $3);
    }
    | simples_expressao
        {
    $$ = $1;
    }
    ;

    var
    : T_ID
        {
    Simbolo *s = busca_simbolo_visivel(tabela, $1, escopo_atual);
    $$ = verifica_var(s, $1, linha);
    free($1);
    }
    | T_ID T_LBRACK expressao T_RBRACK
        {
    Simbolo *s = busca_simbolo_visivel(tabela, $1, escopo_atual);
    $$ = verifica_indexacao(s, $1, $3, linha);
    free($1);
    }
    ;

    simples_expressao
    : soma_expressao relacional soma_expressao
        {
    $$ = op_relacional($1, $3, $2);
    }
    | soma_expressao
        {
    $$ = $1;
    }
    ;

    relacional
    : T_LE { $$ = "<="; }
    | T_LT { $$ = "<"; }
    | T_GT { $$ = ">"; }
    | T_GE { $$ = ">="; }
    | T_EQ { $$ = "=="; }
    | T_NE { $$ = "!="; }
    ;

    soma_expressao
    : soma_expressao T_MAIS termo
        {
            $$ = op_soma($1, $3);
            if ($$.tipo == TIPO_INT) {
                $$.ast = novo_no_binario("+", $1.ast, $3.ast);
            }
        }
    | soma_expressao T_MENOS termo { $$ = op_sub($1, $3); }
    | termo { $$ = $1; }
    ;

    termo
    : termo T_MULT fator
        {
            $$ = op_mult($1, $3);
            if ($$.tipo == TIPO_INT) {
                $$.ast = novo_no_binario("*", $1.ast, $3.ast);
            }
        }
    | termo T_DIV fator { $$ = op_div($1, $3); }
    | fator { $$ = $1; }
    ;

    fator
    : T_LPAR expressao T_RPAR
        {
    $$ = $2;
    }
    | var
        {
    $$ = $1;
    }
    | ativacao
        {
    $$ = $1;
    }
    | T_INT
        {
            $$ = make_inteiro($1, linha);
            $$.ast = novo_no(AST_NUMERO);
            $$.ast->numero = $1;
        }
    ;

    ativacao
    : T_ID T_LPAR args T_RPAR
        {
            Simbolo *s = busca_simbolo_visivel(tabela, $1, escopo_atual);
            $$ = verifica_chamada(s, $1, linha);
            if ($3.tem_erro) {
                $$ = make_tipo(TIPO_ERRO, linha);
            }
            if ($$.tipo != TIPO_ERRO) {
                $$.ast = novo_no_chamada($1, $3.primeiro);
            }
            free($1);
        }
    ;

    args
    : arg_lista   { $$ = $1; }
    | /* vazio */ { $$ = (ListaAST){0}; }
    ;

    arg_lista
    : arg_lista T_COMMA expressao { $$ = anexa_argumento($1, $3); }
    | expressao                   { $$ = anexa_argumento((ListaAST){0}, $1); }
    ;

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

    tabela = cria_lista();
    insere_simbolo(tabela, "input", TIPO_INT, "global", 0, 1);
    insere_simbolo(tabela, "output", TIPO_VOID, "global", 0, 1);

    yyparse();

    if (busca_simbolo(tabela, "main", "global") == NULL) {
        fprintf(stderr, "ERRO SEMANTICO: funcao 'main' nao declarada.\n");
    }

    imprime_lista(tabela);
    libera_ast();
    libera_lista(tabela);
    fclose(yyin);

    return 0;
}

void yyerror(const char *s){
    fprintf(stderr, "Erro sintatico/semantico: %s\n", s);
}
