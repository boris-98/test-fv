`timescale 1ns/1ps
`default_nettype none

module panex #(parameter integer S = 4) (
  clk,
  rst,
  fr,
  to
);

  input  wire       clk;
  input  wire       rst;
  input  wire [1:0] fr;
  input  wire [1:0] to;

  // disks on pegs
  logic [S-1:0] pegs [0:2];

  // move control
  logic found;
  logic [$clog2(S)-1:0] level;
  logic can_move;

  // choose disk and check move
  always_comb begin
    found     = 1'b0;
    level     = '0;
    can_move  = 1'b0;

    if ((fr < 3) && (to < 3) && (fr != to)) begin

      // find top disk on source
      for (int i = 0; i < S; i++) begin
        if (!found) begin
          logic free_above;
          free_above = 1'b1;

          for (int j = 0; j < i; j++)
            if (pegs[fr][j]) free_above = 1'b0;

          if (pegs[fr][i] && free_above) begin
            found = 1'b1;
            level = i[$clog2(S)-1:0];
          end
        end
      end

      // check destination
      if (found) begin
        logic free_dest;
        free_dest = 1'b1;

        for (int k = 0; k < level; k++)
          if (pegs[to][k]) free_dest = 1'b0;

        if (!pegs[to][level] && free_dest)
          can_move = 1'b1;
      end
    end
  end

  // reset and update
  always_ff @(posedge clk) begin
    if (rst) begin
      pegs[0] <= {S{1'b1}};
      pegs[1] <= {S{1'b0}};
      pegs[2] <= {S{1'b0}};
    end else begin
      if (can_move) begin
        pegs[fr][level] <= 1'b0;
        pegs[to][level] <= 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
