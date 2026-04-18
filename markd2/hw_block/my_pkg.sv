package my_pkg;


typedef enum {IDLE,PROCESSING} states;
typedef enum { SORT_IDLE,
	       SORT_COMPARE_ELEMENTS,
	       SORT_SWAP_ELEMENTS,
	       SORT_WRITE_BACK,
	       SORT_LOOP_J_DONE,
	       SORT_DIAGONAL_COMPARE} sort_states;
parameter DATA_WIDTH = 8;

endpackage
