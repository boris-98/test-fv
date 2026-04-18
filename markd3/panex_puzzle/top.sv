module top(
    input        clk,
    input        rst,
    input  [1:0] fr,
    input  [1:0] to
);

    // DUT
    panex #(.S(4)) dut (
        .clk(clk),
        .rst(rst),
        .fr(fr),
        .to(to)
    );

    default clocking @(posedge clk); endclocking
    default disable iff (rst);

    // start pulse poslije puštanja rsta
    reg rst_d;
    always @(posedge clk) rst_d <= rst;
    wire start_after_reset = rst_d && !rst;

    // ogranicenja igrice
    // fr/to smiju biti samo 0,1,2
    a_valid_vals: assume property (fr < 2'd3 && to < 2'd3);

    // nema besmislenog poteza na isti štap
    a_diff:       assume property (fr != to);

    // svaki takt biraj okej potez za trenutno stanje
    a_legal:      assume property (dut.can_move);

    p_goal_stable: assert property (dut.goal |-> dut.goal);

    // cover: postoji rješenje u (2^S - 1) poteza
    // Za S=4 -> 15 poteza (minimalno)
    localparam integer GOAL_BOUND = (1 << 4) - 1; // 15

    c_solve: cover property (
        start_after_reset |=> ##[0:GOAL_BOUND] dut.goal
    );

endmodule

