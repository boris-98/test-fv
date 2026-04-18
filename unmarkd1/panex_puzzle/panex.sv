module panex #( parameter int S = 4)
(
    input  logic        clk,
    input  logic        rst,

    input  logic [1:0]  fr,
    input  logic [1:0]  to
);


    // Tile :

    localparam W = $clog2(S); // num of bits to code index/tile weight

    typedef struct packed {
        logic [1:0]    color; //color of the tile
        logic [W-1:0]  index; //initial index - tile weight
    } tile_t;

    // tile colors
    localparam logic [1:0] EMPTY = 2'b00;
    localparam logic [1:0] BLUE  = 2'b01;
    localparam logic [1:0] RED   = 2'b10;

    localparam tile_t EMPTY_TILE = '{color:EMPTY, index:'0};

    // tower sides
    localparam logic [1:0] S_LEFT  = 2'b00;
    localparam logic [1:0] S_MIDDLE   = 2'b01;
    localparam logic [1:0] S_RIGHT = 2'b10;



    // towers 
    tile_t left  [S:0];
    tile_t mid   [S:0];
    tile_t right [S:0];

    int pos = S+1;

   //Always block
   
    always @(posedge clk) begin

        if (rst) begin
        
	  for (int i = 0; i <= S; i++)begin
  	    left[i] <= '{color:BLUE, index:i};
	    right[i] <= '{color:RED, index:i};
	    mid[i] <= EMPTY_TILE;
	  end
	  left[S] <= EMPTY_TILE;
	  right[S] <= EMPTY_TILE;
	  mid[S] <= EMPTY_TILE;

        end
        else begin
     //Here comes the logic:     
     
     //--------LEFT -> MIDDLE-------------------------
	if (fr == S_LEFT && to == S_MIDDLE) begin

	    for (int i = S; i >= 0; i--) begin
		if (left[i].color != EMPTY) begin //find first non-empty on the 'from' side

		    pos = S+1;	// pos init, value out of range in case there's no space to move a tile

		    for (int j = S; j >= 0; j--) begin
		        if (mid[j] == EMPTY_TILE && j >= left[i].index)
		            pos = j;               // deepest valid empty so far
		        else if (j < left[i].index)
		            break;                 // cannot go deeper than initial tile index

		    end

		    if (pos != S+1) begin //there's a place to move a tile, value in range
		        mid[pos]  <= left[i];
		        left[i]   <= EMPTY_TILE;
		    end

		    break;
		end
	    end
	end//l->m
//--------LEFT -> RIGHT--------------------------
	if (fr == S_LEFT && to == S_RIGHT) begin


	    for (int i = S; i >= 0; i--) begin
		if (left[i].color != EMPTY) begin

		    pos = S+1;

		    for (int j = S; j >= 0; j--) begin
		        if (right[j] == EMPTY_TILE && j >= left[i].index)
		            pos = j;
		        else if (j < left[i].index)
		            break;
		    end

		    if (pos != S+1) begin
		        right[pos] <= left[i];
		        left[i]    <= EMPTY_TILE;
		    end

		    break;
		end
	    end
	end//l->r

//--------MIDDLE -> LEFT-------------------------
	if (fr == S_MIDDLE && to == S_LEFT) begin


	    for (int i = S; i >= 0; i--) begin
		if (mid[i].color != EMPTY) begin

		    pos = S+1;

		    for (int j = S; j >= 0; j--) begin
		        if (left[j] == EMPTY_TILE && j >= mid[i].index)
		            pos = j;
		        else if (j < mid[i].index)
		            break;
		    end

		    if (pos != S+1) begin
		        left[pos] <= mid[i];
		        mid[i]    <= EMPTY_TILE;
		    end

		    break;
		end
	    end
	end//m->l
//--------MIDDLE -> RIGHT------------------------
	if (fr == S_MIDDLE && to == S_RIGHT) begin


	    for (int i = S; i >= 0; i--) begin
		if (mid[i].color != EMPTY) begin

		    pos = S+1;

		    for (int j = S; j >= 0; j--) begin
		        if (right[j] == EMPTY_TILE && j >= mid[i].index)
		            pos = j;
		        else if (j < mid[i].index)
		            break;
		    end

		    if (pos != S+1) begin
		        right[pos] <= mid[i];
		        mid[i]     <= EMPTY_TILE;
		    end

		    break;
		end
	    end
	end//m->r
//--------RIGHT -> LEFT--------------------------
	if (fr == S_RIGHT && to == S_LEFT) begin


	    for (int i = S; i >= 0; i--) begin
		if (right[i].color != EMPTY) begin

		    pos = S+1;

		    for (int j = S; j >= 0; j--) begin
		        if (left[j] == EMPTY_TILE && j >= right[i].index)
		            pos = j;
		        else if (j < right[i].index)
		            break;
		    end

		    if (pos != S+1) begin
		        left[pos]  <= right[i];
		        right[i]   <= EMPTY_TILE;
		    end

		    break;
		end
	    end
	end//r->l

//--------RIGHT -> MIDDLE------------------------
	if (fr == S_RIGHT && to == S_MIDDLE) begin


	    for (int i = S; i >= 0; i--) begin
		if (right[i].color != EMPTY) begin

		    pos = S+1;

		    for (int j = S; j >= 0; j--) begin
		        if (mid[j] == EMPTY_TILE && j >= right[i].index)
		            pos = j;
		        else if (j < right[i].index)
		            break;
		    end

		    if (pos != S+1) begin
		        mid[pos]   <= right[i];
		        right[i]   <= EMPTY_TILE;
		    end

		    break;
		end
	    end
	end//r->m


        end//else 	    		    		
	//end
    end//of always block	


// CLK & RST:

    
    default clocking
        @(posedge clk);
    endclocking

    default disable iff (rst);

//Formal statements

//1) valid tile colors
    generate
        for (genvar i = 0; i <= S; i++) begin : VALID_TILE_COLOR
            valid_left_val  : assume property ( left[i].color  != 2'b11);
            valid_mid_val   : assume property ( mid[i].color   != 2'b11);
            valid_right_val : assume property ( right[i].color != 2'b11);
        end
    endgenerate

// ok


//2) valid input values, inputs must have different values
    valid_inputs : assume property ( (fr != 2'b11 && to != 2'b11));
    diff_inputs  : assume property ( (fr != to));

//ok


function automatic logic side_empty(input tile_t s [S:0]);
 logic flag = 1'b1;

	for(int i = 0; i<= S; i++)begin
	        flag &= (s[i]==EMPTY_TILE);//only one non-empty on the side makes flag 0 
	end//end of for loop
 return flag;
 endfunction


//3) can't move tile from empty tower

        assume property(fr == S_LEFT  |-> !side_empty(left));
        assume property(fr == S_MIDDLE   |-> !side_empty(mid));
        assume property(fr == S_RIGHT |-> !side_empty(right));

assert property(fr == S_LEFT  |-> !side_empty(left));

//4) can't move tile to non-empty tower

        assume property(to == S_LEFT  |-> left[S]==EMPTY_TILE);
        assume property(to == S_MIDDLE   |-> mid[S]==EMPTY_TILE);
        assume property(to == S_RIGHT |-> right[S]==EMPTY_TILE);


//Test covers
//test_cover1: cover property(to == S_LEFT [*2]);//seems ok
//test_cover2: cover property(left[2] == EMPTY_TILE);//ok
//test_cover3: cover property(right[2].color == BLUE);//ok
//test_cover4: cover property(right[1].color == BLUE);//ok


function automatic logic tower(input tile_t s [S:0], input logic [1:0] color_in);
 logic flag = 1'b1;

	for(int i = 0; i< S; i++)begin
	        flag &= (s[i].color == color_in);
	end//end of for loop

 return flag;
 endfunction

fin:cover property(tower(left,RED) and  tower(right,BLUE));

endmodule







