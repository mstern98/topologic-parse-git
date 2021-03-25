/* SPDX-License-Identifier: MIT WITH bison-exception */
/* Copyright © 2020 Matthew Stern, Benjamin Michalowicz */

%{
#include <topologic/topologic.h>
void f(int id, struct graph *graph, struct vertex_result *args, void *glbl, void *edge_vars) {}
int edge_f(int id, void *args, void *glbl, const void *const edge_vars_a, const void *const edge_vars_b) {return 0;}
void yyerror(struct graph** graph, const char *s);
extern FILE *yyin;
int yylex(void);
%}

%union {
    struct graph *graph;
    int val;
};

%parse-param {struct graph** graph}
%token L_BRACKET 
%token R_BRACKET
%token GRAPH
%token COLON
%token VERTICES_
%token EDGE_
%token BI_EDGE_
%token L_SQUARE
%token R_SQUARE
%token COMMA
%token MAX_STATE
%token LVL_VERBOSE
%token LEX_CONTEXT
%token MEM_OPT
%token MAX_LOOP
%token <val> VALUE

%start json
%%
json: L_BRACKET GRAPH   {*graph = GRAPH_INIT(); if (!(*graph)){fprintf(stderr, "Can't create graph\n"); return -1;}}  
      COLON L_BRACKET content R_BRACKET
      R_BRACKET
      ;
content: params g
        | g
        | params
        |
        ;
params: verb COMMA params
        | state COMMA params
        | mem_opt COMMA params
        | context COMMA params
        | max_loop COMMA params
        | verb
        | mem_opt
        | context
        | state
        | max_loop
        |
        ;
state: MAX_STATE COLON VALUE {(*graph)->max_state_changes = $3;}
     ;
verb: LVL_VERBOSE COLON VALUE {(*graph)->lvl_verbose = $3;}
    ;
context: LEX_CONTEXT COLON VALUE {(*graph)->context = $3;}
       ;
mem_opt: MEM_OPT COLON VALUE {(*graph)->mem_option = $3;}
       ;
max_loop: MAX_LOOP COLON VALUE {(*graph)->max_loop = $3;}
       ;
g:  vs COMMA es COMMA bes
    | vs COMMA bes COMMA es
    | vs COMMA es
    | vs COMMA bes
    | vs
    ;
vs: VERTICES_ COLON L_SQUARE v R_SQUARE
    ;
v:  /* empty */
    | VALUE COMMA {if (create_vertex(*graph, f, $1, NULL) < 0) fprintf(stderr, "Failed To Create Vertex %d\n", $1);}
    v
    | VALUE {if (create_vertex(*graph, f, $1, NULL) < 0) fprintf(stderr, "Failed To Create Vertex %d\n", $1);}
    ;
es: EDGE_ COLON L_BRACKET e R_BRACKET
    ;
e:  /* empty */
    | VALUE COLON VALUE COMMA {struct vertex *a = find((*graph)->vertices, $1); struct vertex *b = find((*graph)->vertices, $3); if (a && b) {if (create_edge(a, b, edge_f, NULL) == NULL) fprintf(stderr, "Failed to create Edge Between %d and %d\n", a->id, b->id);} else fprintf(stderr, "Invalid Vertices a:%p b:%p\n", a, b);}
      e
    | VALUE COLON VALUE {struct vertex *a = find((*graph)->vertices, $1); struct vertex *b = find((*graph)->vertices, $3); if (a && b) {if (create_edge(a, b, edge_f, NULL) == NULL) fprintf(stderr, "Failed to create Edge Between %d and %d\n", a->id, b->id);} else fprintf(stderr, "Invalid Vertices a:%p b:%p\n", a, b);}
    ;
bes:BI_EDGE_ COLON L_BRACKET be R_BRACKET
    ;
be: /* empty */
    | VALUE COLON VALUE COMMA {int val = 0; struct vertex *a = find((*graph)->vertices, $1); struct vertex *b = find((*graph)->vertices, $3); if (a && b) { if((val = create_bi_edge(a, b, edge_f, NULL, NULL, NULL) < 0)) fprintf(stderr, "%d: Failed to bi create Edge Between %d and %d\n", val, a->id, b->id);} else fprintf(stderr, "Invalid Vertices a:%p(%d) b:%p(%d)\n", a, $1, b, $3);}
      be
    | VALUE COLON VALUE {int val = 0; struct vertex *a = find((*graph)->vertices, $1); struct vertex *b = find((*graph)->vertices, $3); if (a && b) { if((val = create_bi_edge(a, b, edge_f, NULL, NULL, NULL) < 0)) fprintf(stderr, "%d: Failed to bi create Edge Between %d and %d\n", val, a->id, b->id);} else fprintf(stderr, "Invalid Vertices a:%p(%d) b:%p(%d)\n", a, $1, b, $3);}
    ;
%%

void yyerror(struct graph** graph, const char *s) {
    fprintf(stderr, "yerror: %s\n", s);
    destroy_graph(*graph);
    *graph = NULL;
}

struct graph *parse_json(const char *path) {
    topologic_debug("%s;%s", "parse_json", path);
    FILE *file = fopen(path, "r");
    if (!file) {
        topologic_debug("%s;%s;%p", "parse_json", "invalid file", (void *) NULL);
        return NULL;
    }
    yyin = file;
    struct graph *graph = NULL;
    yyparse(&graph);
    yyin = NULL;
    fclose(file);
    topologic_debug("%s;%s;%p", "parse_json", "success", graph);
    return graph;
}
