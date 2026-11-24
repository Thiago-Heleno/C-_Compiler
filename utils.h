#ifndef UTILS_H
#define UTILS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---- TIPOS DA LINGUAGEM C- ---- */

typedef enum {
    TIPO_INT,
    TIPO_VOID,
    TIPO_INT_ARRAY,
    TIPO_ERRO
} Tipo;

typedef struct {
    Tipo tipo;
    int ival;
    int eh_const;
    int linha;
} Valor;

/* ---- TABELA DE SIMBOLOS (LISTA ENCADEADA COM CABECA) ---- */

typedef struct Simbolo {
    char *nome;
    Tipo tipo;
    char *escopo;
    int linha;
    int eh_funcao;
    struct Simbolo *prox;
} Simbolo;

static inline const char *tipo_para_str(Tipo t) {
    switch (t) {
        case TIPO_INT:       return "int";
        case TIPO_VOID:      return "void";
        case TIPO_INT_ARRAY: return "int[]";
        default:             return "erro";
    }
}

static inline Simbolo *cria_lista(void) {
    Simbolo *cabeca = (Simbolo *)malloc(sizeof(Simbolo));
    if (cabeca == NULL) {
        fprintf(stderr, "Erro ao alocar memoria para a lista.\n");
        exit(1);
    }
    cabeca->nome = NULL;
    cabeca->tipo = TIPO_VOID;
    cabeca->escopo = NULL;
    cabeca->linha = 0;
    cabeca->eh_funcao = 0;
    cabeca->prox = NULL;
    return cabeca;
}

static inline Simbolo *busca_simbolo(Simbolo *cabeca, const char *nome, const char *escopo) {
    if (cabeca == NULL) return NULL;

    Simbolo *p = cabeca->prox;
    while (p != NULL) {
        if (strcmp(p->nome, nome) == 0 && strcmp(p->escopo, escopo) == 0)
            return p;
        p = p->prox;
    }
    return NULL;
}

static inline Simbolo *busca_simbolo_visivel(Simbolo *cabeca, const char *nome, const char *escopo) {
    Simbolo *s = busca_simbolo(cabeca, nome, escopo);
    if (s != NULL) return s;

    return busca_simbolo(cabeca, nome, "global");
}

static inline int insere_simbolo(Simbolo *cabeca, const char *nome, Tipo tipo, const char *escopo, int linha, int eh_funcao) {
    if (cabeca == NULL) return 0;

    if (busca_simbolo(cabeca, nome, escopo) != NULL) {
        return 0; /* Simbolo ja declarado no mesmo escopo */
    }

    Simbolo *novo = (Simbolo *)malloc(sizeof(Simbolo));
    if (novo == NULL) {
        fprintf(stderr, "Erro ao alocar memoria para simbolo '%s'.\n", nome);
        exit(1);
    }

    novo->nome = strdup(nome);
    novo->tipo = tipo;
    novo->escopo = strdup(escopo);
    novo->linha = linha;
    novo->eh_funcao = eh_funcao;
    novo->prox = NULL;

    Simbolo *p = cabeca;
    while (p->prox != NULL) {
        p = p->prox;
    }
    p->prox = novo;

    return 1;
}

static inline int remove_simbolo(Simbolo *cabeca, const char *nome, const char *escopo) {
    if (cabeca == NULL) return 0;

    Simbolo *ant = cabeca;
    Simbolo *p = cabeca->prox;
    while (p != NULL) {
        if (strcmp(p->nome, nome) == 0 && strcmp(p->escopo, escopo) == 0) {
            ant->prox = p->prox;
            free(p->nome);
            free(p->escopo);
            free(p);
            return 1;
        }
        ant = p;
        p = p->prox;
    }
    return 0;
}

static inline void imprime_lista(Simbolo *cabeca) {
    if (cabeca == NULL) return;

    printf("\n---- TABELA DE SIMBOLOS ----\n");
    printf("%-20s %-10s %-10s %-20s %-6s\n", "Nome", "Tipo", "Categoria", "Escopo", "Linha");

    Simbolo *p = cabeca->prox;
    while (p != NULL) {
        printf("%-20s %-10s %-10s %-20s %-6d\n",
               p->nome,
               tipo_para_str(p->tipo),
               p->eh_funcao ? "funcao" : "var",
               p->escopo,
               p->linha);
        p = p->prox;
    }
    printf("----------------------------\n");
}

static inline void libera_lista(Simbolo *cabeca) {
    if (cabeca == NULL) return;

    Simbolo *p = cabeca->prox;
    while (p != NULL) {
        Simbolo *prox = p->prox;
        free(p->nome);
        free(p->escopo);
        free(p);
        p = prox;
    }
    free(cabeca);
}

/* ---- IMPLEMENTACAO DOS TIPOS E OPERACOES SEMANTICAS ---- */

static inline Valor make_inteiro(int x, int linha) {
    Valor v;
    v.tipo = TIPO_INT;
    v.ival = x;
    v.eh_const = 1;
    v.linha = linha;
    return v;
}

static inline Valor make_tipo(Tipo tipo, int linha) {
    Valor v;
    v.tipo = tipo;
    v.ival = 0;
    v.eh_const = 0;
    v.linha = linha;
    return v;
}

static inline void erro_tipo(const char *op, int linha) {
    fprintf(stderr, "ERRO SEMANTICO: tipos incompativeis em '%s' - LINHA: %d\n", op, linha);
}

static inline Valor op_binaria_int(Valor a, Valor b, const char *op) {
    if (a.tipo == TIPO_ERRO || b.tipo == TIPO_ERRO) {
        return make_tipo(TIPO_ERRO, a.linha);
    }
    if (a.tipo != TIPO_INT || b.tipo != TIPO_INT) {
        erro_tipo(op, a.linha);
        return make_tipo(TIPO_ERRO, a.linha);
    }
    return make_tipo(TIPO_INT, a.linha);
}

static inline Valor op_soma(Valor a, Valor b) {
    return op_binaria_int(a, b, "+");
}

static inline Valor op_sub(Valor a, Valor b) {
    return op_binaria_int(a, b, "-");
}

static inline Valor op_mult(Valor a, Valor b) {
    return op_binaria_int(a, b, "*");
}

static inline Valor op_div(Valor a, Valor b) {
    Valor res = op_binaria_int(a, b, "/");
    if (res.tipo == TIPO_ERRO) return res;

    if (b.eh_const && b.ival == 0) {
        fprintf(stderr, "ERRO SEMANTICO: divisao por 0 nao esta definida - LINHA: %d\n", b.linha);
        return make_tipo(TIPO_ERRO, a.linha);
    }
    return res;
}

static inline Valor op_relacional(Valor a, Valor b, const char *op) {
    return op_binaria_int(a, b, op);
}

static inline Valor op_atrib(Valor var_val, Valor exp_val) {
    if (var_val.tipo == TIPO_ERRO || exp_val.tipo == TIPO_ERRO) {
        return make_tipo(TIPO_ERRO, var_val.linha);
    }
    if (var_val.tipo != TIPO_INT || exp_val.tipo != TIPO_INT) {
        erro_tipo("=", var_val.linha);
        return make_tipo(TIPO_ERRO, var_val.linha);
    }
    return make_tipo(TIPO_INT, var_val.linha);
}

static inline Valor verifica_var(Simbolo *s, const char *nome, int linha) {
    if (s == NULL) {
        fprintf(stderr, "ERRO SEMANTICO: identificador '%s' - LINHA: %d\n", nome, linha);
        return make_tipo(TIPO_ERRO, linha);
    }
    if (s->eh_funcao) {
        fprintf(stderr, "ERRO SEMANTICO: funcao '%s' usada como variavel - LINHA: %d\n", nome, linha);
        return make_tipo(TIPO_ERRO, linha);
    }
    return make_tipo(s->tipo, linha);
}

static inline Valor verifica_indexacao(Simbolo *s, const char *nome, Valor indice, int linha) {
    if (s == NULL) {
        fprintf(stderr, "ERRO SEMANTICO: identificador '%s' - LINHA: %d\n", nome, linha);
        return make_tipo(TIPO_ERRO, linha);
    }
    if (s->eh_funcao || s->tipo != TIPO_INT_ARRAY) {
        fprintf(stderr, "ERRO SEMANTICO: identificador '%s' nao e um vetor - LINHA: %d\n", nome, linha);
        return make_tipo(TIPO_ERRO, linha);
    }
    if (indice.tipo != TIPO_ERRO && indice.tipo != TIPO_INT) {
        fprintf(stderr, "ERRO SEMANTICO: indice do vetor '%s' deve ser inteiro - LINHA: %d\n", nome, linha);
        return make_tipo(TIPO_ERRO, linha);
    }
    return make_tipo(TIPO_INT, linha);
}

static inline Valor verifica_chamada(Simbolo *s, const char *nome, int linha) {
    if (s == NULL) {
        fprintf(stderr, "ERRO SEMANTICO: identificador '%s' - LINHA: %d\n", nome, linha);
        return make_tipo(TIPO_ERRO, linha);
    }
    if (!s->eh_funcao) {
        fprintf(stderr, "ERRO SEMANTICO: identificador '%s' nao e uma funcao - LINHA: %d\n", nome, linha);
        return make_tipo(TIPO_ERRO, linha);
    }
    return make_tipo(s->tipo, linha);
}

static inline void verifica_condicao(Valor cond, const char *comando) {
    if (cond.tipo != TIPO_ERRO && cond.tipo != TIPO_INT) {
        fprintf(stderr, "ERRO SEMANTICO: condicao invalida em '%s' - LINHA: %d\n", comando, cond.linha);
    }
}

static inline void verifica_retorno(Valor ret, Tipo tipo_funcao, int linha) {
    if (ret.tipo == TIPO_ERRO) return;

    if (tipo_funcao == TIPO_VOID && ret.tipo != TIPO_VOID) {
        fprintf(stderr, "ERRO SEMANTICO: funcao void nao pode retornar valor - LINHA: %d\n", linha);
    } else if (tipo_funcao != TIPO_VOID && ret.tipo != tipo_funcao) {
        fprintf(stderr, "ERRO SEMANTICO: tipo de retorno incompativel - LINHA: %d\n", linha);
    }
}

#endif
