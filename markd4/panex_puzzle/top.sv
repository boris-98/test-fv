`timescale 1ns/1ps
`default_nettype none

module top (clk, rst);
  input wire clk;
  input wire rst;

  localparam int unsigned S = 4;

  (* anyseq *) logic [1:0] fr;
  (* anyseq *) logic [1:0] to;

  panex #(.S(S)) dut (
    .clk(clk), .rst(rst),
    .fr(fr), .to(to)
  );

  default clocking cb @(posedge clk); endclocking
  default disable iff (rst);

  // Assumptions
  a_fr_ok   : assume property (fr < 3);
  a_to_ok   : assume property (to < 3);
  a_no_same : assume property (fr != to);

  // keep inputs defined
  a_no_x    : assume property (!$isunknown({fr,to}));

  // if move not allowed -> state stays same
  generate
    genvar p1, h1;
    for (p1 = 0; p1 < 3; p1++) begin : hold_p
      for (h1 = 0; h1 < S; h1++) begin : hold_h
        hold_check: assert property(
          (!dut.can_move) |=> (dut.pegs[p1][h1] == $past(dut.pegs[p1][h1]))
        );
      end
    end
  endgenerate

  // Correct update when move happens
  generate
    genvar p2, h2;
    for (p2 = 0; p2 < 3; p2++) begin : upd_p
      for (h2 = 0; h2 < S; h2++) begin : upd_h
        update_check: assert property(
          dut.can_move |=> (
            ((p2 == $past(fr)) && (h2 == $past(dut.level))) ? (dut.pegs[p2][h2] == 1'b0) :
            ((p2 == $past(to)) && (h2 == $past(dut.level))) ? (dut.pegs[p2][h2] == 1'b1) :
                                           (dut.pegs[p2][h2] == $past(dut.pegs[p2][h2]))
          )
        );
      end
    end
  endgenerate

  // each disk is on exactly one peg
  generate
    genvar d;
    for (d = 0; d < S; d++) begin : one_place
      one_place_check: assert property(
        (dut.pegs[0][d] | dut.pegs[1][d] | dut.pegs[2][d]) &&
        !(dut.pegs[0][d] & dut.pegs[1][d]) &&
        !(dut.pegs[0][d] & dut.pegs[2][d]) &&
        !(dut.pegs[1][d] & dut.pegs[2][d])
      );
    end
  endgenerate

  // Move legality checks
  move_src_check:  assert property(dut.can_move |->  dut.pegs[fr][dut.level]);
  move_dst_check:  assert property(dut.can_move |-> !dut.pegs[to][dut.level]);

  // For all k < level: nothing smaller on source/dest
  generate
    genvar k;
    for (k = 0; k < S; k++) begin : clear_check
      src_clear_check: assert property(
        dut.can_move && (dut.level > k) |-> !dut.pegs[fr][k]
      );
      dst_clear_check: assert property(
        dut.can_move && (dut.level > k) |-> !dut.pegs[to][k]
      );
    end
  endgenerate

  // Rseet correctness
  reset_check: assert property(
    rst |-> (dut.pegs[0] == {S{1'b1}} &&
             dut.pegs[1] == {S{1'b0}} &&
             dut.pegs[2] == {S{1'b0}})
  );

  // Cover goal: all disks on peg 2
  solved_cover: cover property (dut.pegs[2] == {S{1'b1}});

endmodule

`default_nettype wire
