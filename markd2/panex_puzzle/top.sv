module top #(
  parameter int S = 3
)(
  input  logic clk,
  input  logic rst,
  input  logic [1:0] fr,
  input  logic [1:0] to
);

  localparam int NUM_RODS = 3;
  localparam int MAX_LVL = S;
  localparam int NUM_TILES = 2*S;
  localparam int LEVEL_W = (MAX_LVL + 1 <= 2) ? 1 : $clog2(MAX_LVL + 1);

  `include "panex_s3_oracle.svh"

  localparam int PHASE_W = (NUM_CP <= 2) ? 1 : $clog2(NUM_CP);
  localparam int DIST_W = (CP_STRIDE + 1 <= 2) ? 1 : $clog2(CP_STRIDE + 1);
  localparam int LAST_CP = NUM_CP - 1;

  panex #(.S(S)) dut(
    .clk(clk),
    .rst(rst),
    .fr(fr),
    .to(to)
  );

  default clocking @(posedge clk); endclocking
  default disable iff (rst);

  logic rst_d;

  logic [PHASE_W-1:0] phase_q; // Index of current checkpoint index
  logic [DIST_W-1:0] dist_q; // Number of cycles already spent in the current cp

  logic alive_q; // This search branch is still valid

  wire seed_cycle = rst_d && !rst;

  // Check wheather the current DUT state matches cp
  function automatic logic checkpoint_match(input int cp_idx);
    int t;
    begin
      checkpoint_match = 1'b1;
      for (t = 0; t < NUM_TILES; t++) begin
        if (dut.tile_rod[t] != CP_ROD[cp_idx][t]) // Check every rod
          checkpoint_match = 1'b0;
        if (dut.tile_lvl[t] != CP_LVL[cp_idx][t]) //Check every level
          checkpoint_match = 1'b0;
      end
    end
  endfunction

  logic next_cp_hit;

  // Check wheather the DUT has reached the next cp
  always_comb begin 
    if (int'(phase_q) < LAST_CP)
      next_cp_hit = checkpoint_match(int'(phase_q) + 1);
    else
      next_cp_hit = 1'b0;
  end

  always_ff @(posedge clk) begin
    rst_d <= rst;

    if (rst) begin
      phase_q <= '0;
      dist_q <= '0;
      alive_q <= 1'b1;
    end
    else if (rst_d) begin
      phase_q <= '0;
      dist_q  <= '0;
      alive_q <= 1'b1;
    end
    else if (alive_q && (int'(phase_q) < LAST_CP)) begin
      if (next_cp_hit) begin
        phase_q <= phase_q + 1'b1;
        dist_q <= '0;
      end
      else if (dist_q < (CP_STRIDE - 1)) begin
        dist_q <= dist_q + 1'b1;
      end
      else begin
        alive_q <= 1'b0;
      end
    end
  end

  restrict property(fr < NUM_RODS);
  restrict property(to < NUM_RODS);
  restrict property(fr != to);
  restrict property(dut.move_valid);

  genvar g;
  // Force the DUT state on a first cycle after rst to be equal to cp 0
  generate
    for (g = 0; g < NUM_TILES; g++) begin : g_seed
      restrict property(seed_cycle |-> (dut.tile_rod[g] == CP_ROD[0][g]));
      restrict property(seed_cycle |-> (dut.tile_lvl[g] == CP_LVL[0][g]));
    end
  endgenerate

  genvar k;
  // For each cp, find a path from the initial seed state to cp k 
  generate
    for (k = 1; k < NUM_CP; k++) begin : g_cp_cov
      localparam int MAX_CYCLES_TO_K = ((k * CP_STRIDE) < ORACLE_NUM_MOVES) ? (k * CP_STRIDE) : ORACLE_NUM_MOVES;
      cover property(seed_cycle ##[1:MAX_CYCLES_TO_K] (alive_q && (int'(phase_q) == (k-1)) && checkpoint_match(k)));
    end
  endgenerate

  // Final cover: Starting from cp 0, reach the last cp and satisfy dut.goal
  cover property(seed_cycle ##[1:ORACLE_NUM_MOVES] (alive_q && (int'(phase_q) == (LAST_CP - 1)) && checkpoint_match(LAST_CP) && dut.goal));

endmodule
