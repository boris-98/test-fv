module panex #(
    parameter integer S = 4
) (
    input logic clk,
    input logic rst,
    input logic [1:0] fr,
    input logic [1:0] to
);

    localparam integer NUM_RODS = 3;
    localparam integer NUM_TILES = 2*S;
    localparam integer MAX_LVL = S; 
    
    localparam integer LEVEL_W = $clog2(MAX_LVL+1);
    localparam integer ID_W = $clog2(NUM_TILES);
    
    typedef logic [1:0] rod_t;
    typedef logic [LEVEL_W-1:0] lvl_t;
    typedef logic [ID_W-1:0] id_t;
    
    // State
    rod_t tile_rod [0:NUM_TILES-1];
    lvl_t tile_lvl [0:NUM_TILES-1];
    logic move_valid;
    logic goal;
    
    // Home level
    function automatic int unsigned home_level(input int unsigned id);
        begin
            if (id < S)
                home_level = id;
            else
                home_level = id - S;
        end
    endfunction
    
    // Top tile per rod
    integer top_id [0:NUM_RODS-1];
    integer top_lvl [0:NUM_RODS-1]; 
    logic rod_full[0:NUM_RODS-1];
    
    always_comb begin : comb_top
        integer r_idx;
        integer id_idx;
        integer lv;
        
        for (r_idx = 0; r_idx < NUM_RODS; r_idx++) begin
            top_id[r_idx] = -1; // Assume every rod is empty
            top_lvl[r_idx] = -1; // No level is occupied
        end
        
        for (id_idx = 0; id_idx < NUM_TILES; id_idx++) begin
            if (tile_rod[id_idx] < NUM_RODS) begin // Ignore invalid rod encodings
                lv = integer'(tile_lvl[id_idx]);
                if (lv > top_lvl[tile_rod[id_idx]]) begin // Compare levels
                    top_lvl[tile_rod[id_idx]] = lv; 
                    top_id [tile_rod[id_idx]] = id_idx; 
                end
            end
        end
        
        for (r_idx = 0; r_idx < NUM_RODS; r_idx++) begin
            rod_full[r_idx] = (top_lvl[r_idx] >= MAX_LVL);
        end
    end
    
    // Next state
    rod_t tile_rod_n [0:NUM_TILES-1]; 
    lvl_t tile_lvl_n [0:NUM_TILES-1];
    
    // Move logic 
    always_comb begin : comb_move
        integer id_idx;
        integer mv_id_i;
        logic path_ok;
        id_t mv_id;
        int unsigned base_lvl; 
        int unsigned hl; // Home level of a tile
        int unsigned final_lvl; 

        move_valid = 1'b0;
        
        for (id_idx = 0; id_idx < NUM_TILES; id_idx = id_idx + 1) begin
            tile_rod_n[id_idx] = tile_rod[id_idx];
            tile_lvl_n[id_idx] = tile_lvl[id_idx];
        end
        
        // Basic checks
        if ((fr < NUM_RODS) && (to < NUM_RODS) && (fr != to)) begin
            if (top_id[fr] != -1) begin
                if (top_lvl[to] < MAX_LVL) begin
                    // Rule for moves between 0<->2
                    path_ok = 1'b1;
                    if (((fr == 2'd0) && (to == 2'd2)) || ((fr == 2'd2) && (to == 2'd0))) begin
                        path_ok = !rod_full[1];
                    end
                    
                    if (path_ok) begin
                        mv_id_i = top_id[fr]; // Only the top tile of the source rod can move
                        if ((mv_id_i >= 0) && (mv_id_i < NUM_TILES)) begin
                            mv_id = id_t'(mv_id_i);
			    // Base level is the first free level below current top level
                            base_lvl = int'(top_lvl[to] + 1);
                            // Home level - no belowe it
                            hl = home_level(int'(mv_id_i));
                            final_lvl = (hl > base_lvl) ? hl : base_lvl;
                            // Capacity -> 0:MAX_LVL
                            if (final_lvl <= MAX_LVL) begin
                                move_valid = 1'b1;
                                tile_rod_n[mv_id] = rod_t'(to);
                                tile_lvl_n[mv_id] = lvl_t'(final_lvl);
                            end
                        end
                    end
                end
            end
        end
    end
    
    // Reset/init + update
    always_ff @(posedge clk) begin : ff_state
        integer id_idx;
        integer hl;
        
        if (rst) begin
            for (id_idx = 0; id_idx < NUM_TILES; id_idx = id_idx + 1) begin
                hl = home_level(id_idx);
                tile_lvl[id_idx] <= lvl_t'(hl);
                if (id_idx < S)
                    tile_rod[id_idx] <= rod_t'(2'd0);
                else
                    tile_rod[id_idx] <= rod_t'(2'd2);
            end
        end
        else begin
            for (id_idx = 0; id_idx < NUM_TILES; id_idx = id_idx + 1) begin
                tile_rod[id_idx] <= tile_rod_n[id_idx];
                tile_lvl[id_idx] <= tile_lvl_n[id_idx];
            end
        end
    end
    
    // Goal: swapped towers
    always_comb begin : comb_goal
        integer id_idx;
        int unsigned exp_lvl;
        rod_t exp_rod;
        
        goal = 1'b1;
        for (id_idx = 0; id_idx < NUM_TILES; id_idx = id_idx + 1) begin
            exp_rod = (id_idx < S) ? rod_t'(2'd2) : rod_t'(2'd0); // The expected rod
            exp_lvl = (id_idx < S) ? int'(id_idx) : int'(id_idx - S); // The expected level
            
            if (tile_rod[id_idx] != exp_rod)
                goal = 1'b0;
            if (tile_lvl[id_idx] != lvl_t'(exp_lvl))
                goal = 1'b0;
        end
    end

endmodule
