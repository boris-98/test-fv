module top #(parameter S = 4) (
	input logic clk,
	input logic rst,
	input logic [1:0] fr,
	input logic [1:0] to,

	input logic [S-1:0] a[3],
        input logic [S-1:0] b[3],
        input logic invalid_move
        
);


    default
	clocking @(posedge clk);
    endclocking

    trans_valid: assume property(fr < 2'd3 && to < 2'd3);
    trans_2: assume property (fr == 2'd1 |-> (to == 2'd0) || (to == 2'd2));
    trans_1: assume property (fr == 2'd0 |-> to == 2'd1);
    trans_3: assume property (fr == 2'd2 |-> to == 2'd1);
    trans_no: assume property(fr != to);
    //no_pingpong: assume property ( !(fr == $past(to) && to == $past(fr)) );
    legal_moves: assume property (invalid_move == 1'b0);

    c_solved: cover property(a[2] == {S{1'b1}} && a[1] == '0 && a[0] == '0 && 
                             
                             b[2] == '0 && b[1] == '0 && b[0] == {S{1'b1}});


endmodule
