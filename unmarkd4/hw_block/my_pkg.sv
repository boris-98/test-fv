package my_pkg;
typedef enum {IDLE, PROCESSING} states;
typedef enum {IDLE_SORT, FIND_LESS_SORT, SWAP_SORT, WRITE_SORT,
              END_J_SORT, DIAGONAL_SWAP, COUNT_DUPS} sort_states; 
localparam DATA_WIDTH = 8;
endpackage
