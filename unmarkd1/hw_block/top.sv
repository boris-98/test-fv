module top #(
    parameter int EL_NUM     = 8,
    parameter int DATA_WIDTH = 4,
    parameter int ADDR_WIDTH = 3
 )
(
    
    input  logic                   clk,
    input  logic                   reset,

    input  logic [2*DATA_WIDTH-1:0]  ain_tdata_i,
    input  logic                   ain_tvalid_i,
    output  logic                   ain_tready_o,
    input  logic                   ain_tlast_i,

    input  logic                   sort_dir_i,

    output  logic [2*DATA_WIDTH-1:0]  aout_tdata_o,
    output  logic                   aout_tvalid_o,
    input  logic                   aout_tready_i,
    output  logic                   aout_tlast_o,

    output  logic [ADDR_WIDTH-1:0]  dup_cnt_o

);
default clocking @(posedge clk);
endclocking

default disable iff (reset);

sort_hw #(
    .EL_NUM(EL_NUM),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) uufv(
	.clk(clk),
	.reset(reset),
	.ain_tdata_i(ain_tdata_i), .ain_tvalid_i(ain_tvalid_i), .ain_tready_o(ain_tready_o), .ain_tlast_i(ain_tlast_i),
	.sort_dir_i(sort_dir_i), 
	.aout_tdata_o(aout_tdata_o), .aout_tvalid_o(aout_tvalid_o), .aout_tready_i(aout_tready_i), .aout_tlast_o(aout_tlast_o),
	.dup_cnt_o(dup_cnt_o));

logic in_last = 1'b0;
int in_cnt;
localparam int PAIR_NUM = EL_NUM/2;
int dup_cnt_ref;

always @(posedge clk) begin
  if (reset)begin
	in_cnt <= 0;
	in_last <= 1'b0;
	dup_cnt_ref = 0;
  end
  else if (ain_tvalid_i && ain_tready_o)begin // <--- input
    in_cnt <= in_cnt + 1;
    if(in_cnt == PAIR_NUM-1)
	in_last <= 1'b1;
  end
  else if (aout_tvalid_o && aout_tready_i) begin // ---> output
       
        if (aout_tdata_o[DATA_WIDTH-1 : 0] == aout_tdata_o[2*DATA_WIDTH-1 : DATA_WIDTH])
            dup_cnt_ref = dup_cnt_ref + 1;

        // previous?
        if ($past(aout_tvalid_o && aout_tready_i) &&
            !$past(aout_tlast_o) &&
            aout_tdata_o[DATA_WIDTH-1 : 0] == $past(aout_tdata_o[2*DATA_WIDTH-1 : DATA_WIDTH]))
            dup_cnt_ref = dup_cnt_ref + 1;
    end
end




// Restrict input signals
	elem_pair_num: assume property(in_cnt <= PAIR_NUM);
//AXI in
	axi_in_valid_data:assume property (ain_tvalid_i |-> $stable(ain_tdata_i));
	axi_in_tlast1:assume property((in_cnt==PAIR_NUM-1) |-> ((ain_tvalid_i && ain_tlast_i)));
	axi_in_tlast2:assume property((in_cnt<PAIR_NUM-1) |-> (~ain_tlast_i));
	test_c1: cover property(in_last);
	axi_in_end: assume property(in_last |-> (~ain_tvalid_i && ~ain_tlast_i));
//AXI out
	axi_out_ready1: assume property(aout_tvalid_o |=> $stable(aout_tready_i));

// sort dir should not change from cycle to cycle when sorting begins
	sort_dir: assume property ((in_cnt > 0) |-> $stable(sort_dir_i));

/*------------------------------------------------------------------------------------------------------------*/
//Assertions:	

	//ain_tlast_check: assert property((ain_tlast_i && ain_tvalid_i && ain_tready_o) |=> (~ain_tlast_i && ~ain_tready_o ));	
	aout_tlast_check: assert property( aout_tvalid_o |-> uufv.sort_fin_reg);//output array sorted
	
	// sorting check:
	// same clk cycle
	sort_check_asc: assert property ((sort_dir_i && (aout_tvalid_o && aout_tready_i)) |-> (aout_tdata_o[2*DATA_WIDTH-1 : DATA_WIDTH] >= aout_tdata_o[DATA_WIDTH-1 : 0]));
	sort_check_des: assert property ((~sort_dir_i && (aout_tvalid_o && aout_tready_i)) |-> (aout_tdata_o[2*DATA_WIDTH-1 : DATA_WIDTH] <= aout_tdata_o[DATA_WIDTH-1 : 0]));
	// this and previous clk cycle	
	sort_prev_check_asc:assert property( ((sort_dir_i && (aout_tvalid_o && aout_tready_i)) ##1 (sort_dir_i && (aout_tvalid_o && aout_tready_i)) ) |-> 
		(aout_tdata_o >= $past(aout_tdata_o)));
	sort_prev_check_des:assert property( ((~sort_dir_i && (aout_tvalid_o && aout_tready_i)) ##1 (~sort_dir_i && (aout_tvalid_o && aout_tready_i)) ) |-> 
		(aout_tdata_o <= $past(aout_tdata_o)));

	// duplicate counter
	dup_check: assert property($fell(aout_tlast_o)|-> (dup_cnt_ref == $past(dup_cnt_o)));

// Covers:
c1: cover property(ain_tlast_i && uufv.idx_reg==(PAIR_NUM+2));//input ok

c2: cover property(uufv.sort_fin_reg ##(PAIR_NUM + 1) ~uufv.sort_fin_reg); //  -> read array -> dup count[N*clk] -> idle

c3:cover property (sort_dir_i && aout_tvalid_o && aout_tready_i && aout_tlast_o && aout_tdata_o); // array out

c4: cover property(aout_tlast_o ##1 (~aout_tlast_o && (dup_cnt_ref == $past(dup_cnt_o)))); // ok


// Specification - waveforms

c_input: cover property(sort_dir_i && ain_tvalid_i && ain_tready_o && ain_tdata_i ##[1:$] ain_tlast_i);
c_output: cover property (aout_tvalid_o && aout_tready_i && aout_tdata_o ##[1:$] aout_tlast_o ); // array out

endmodule
