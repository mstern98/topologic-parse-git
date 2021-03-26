/* SPDX-License-Identifier: MIT WITH bison-exception */
/* Copyright © 2020 Matthew Stern, Benjamin Michalowicz */

%{
#include <topologic/topologic.h>
void f(int id, struct graph *graph, struct vertex_result *args, void *glbl, void *edge_vars) {}
int edge_f(int id, void *args, void *glbl, const void *const edge_vars_a, const void *const edge_vars_b) {return 0;}
void yyerror(struct graph** graph, const char *s);
extern FILE *yyin;
int yylex(void);

int max_state_changes = -1;
int snapshot_timestamp = START_STOP;
int max_loop = MAX_LOOPS;
unsigned int lvl_verbose = VERTICES | EDGES | FUNCTIONS | GLOBALS;
enum CONTEXT context = SINGLE;
enum MEM_OPTION mem_option = CONTINUE;
enum REQUEST_FLAG request_flag = IGNORE_FAIL_REQUEST;

void parse_create_edge(struct graph *graph, int id_a, int id_b)
{
    struct vertex *a = (struct vertex *) find(graph->vertices, id_a); 
    struct vertex *b = (struct vertex *) find(graph->vertices, id_b); 
    if (a && b) 
    {
        if (create_edge(a, b, edge_f, NULL) == NULL) 
            fprintf(stderr, "Failed to create Edge Between %d and %d\n", a->id, b->id);
    } 
    else 
        fprintf(stderr, "Invalid Vertices a:%p b:%p\n", a, b);
}

void parse_create_bi_edge(struct graph *graph, int id_a, int id_b)
{
    int val = 0; 
    struct vertex *a = (struct vertex *) find(graph->vertices, id_a); 
    struct vertex *b = (struct vertex *) find(graph->vertices, id_b); 
    if (a && b) 
    { 
        if((val = create_bi_edge(a, b, edge_f, NULL, NULL, NULL) < 0)) 
            fprintf(stderr, "%d: Failed to bi create Edge Between %d and %d\n", val, a->id, b->id);
    } 
    else 
        fprintf(stderr, "Invalid Vertices a:%p(%d) b:%p(%d)\n", a, id_a, b, id_b);
}

void parse_create_vertex(struct graph *graph, int id)
{
    if (create_vertex(graph, f, id, NULL) < 0) 
        fprintf(stderr, "Failed To Create Vertex %d\n", id);
}
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
%token REQ_FLAG
%token <val> VALUE

%start json
%%
json: L_BRACKET GRAPH   
      COLON L_BRACKET params g R_BRACKET
      R_BRACKET   
      ;
params: verb COMMA params
        | state COMMA params
        | mem_opt COMMA params
        | context COMMA params
        | max_loop COMMA params
        | req_flag COMMA params
        | verb
        | mem_opt
        | context
        | state
        | max_loop
        | req_flag
        | {
             *graph = graph_init(max_state_changes, snapshot_timestamp, max_loop, lvl_verbose, context, mem_option, request_flag); 
             if (!(*graph))
             {
                fprintf(stderr, "Can't create graph\n"); 
                return -1;
             }
          }
        ;
state: MAX_STATE COLON VALUE {max_state_changes = $3;}
     ;
verb: LVL_VERBOSE COLON VALUE {lvl_verbose = $3;}
    ;
context: LEX_CONTEXT COLON VALUE {context = (enum CONTEXT) $3;}
       ;
mem_opt: MEM_OPT COLON VALUE {mem_option = (enum MEM_OPTION) $3;}
       ;
max_loop: MAX_LOOP COLON VALUE {max_loop = $3;}
       ;
req_flag: REQ_FLAG COLON VALUE {request_flag = (enum REQUEST_FLAG) $3;}
        ;
g:  vs COMMA es COMMA bes
    | vs COMMA bes COMMA es
    | vs COMMA es
    | vs COMMA bes
    | vs
    |
    ;
vs: VERTICES_ COLON L_SQUARE v R_SQUARE
    ;
v:  /* empty */
    | VALUE COMMA {parse_create_vertex(*graph, $1);}
    v
    | VALUE {parse_create_vertex(*graph, $1);}
    ;
es: EDGE_ COLON L_BRACKET e R_BRACKET
    ;
e:  /* empty */
    | VALUE COLON VALUE COMMA {parse_create_edge(*graph, $1, $3);}
      e
    | VALUE COLON VALUE {parse_create_edge(*graph, $1, $3);}
    ;
bes:BI_EDGE_ COLON L_BRACKET be R_BRACKET
    ;
be: /* empty */
    | VALUE COLON VALUE COMMA {parse_create_bi_edge(*graph, $1, $3);}
      be
    | VALUE COLON VALUE {parse_create_bi_edge(*graph, $1, $3);}
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
    file = NULL;
    topologic_debug("%s;%s;%p", "parse_json", "success", graph);
    return graph;
}
