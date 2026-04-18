import my_pkg::*;
checker sort_checker
	(clk, rst, dup_nums, sort_dir, ain_tvalid, ain_tready, ain_tlast, ain_tdata, aout_tvalid, aout_tready, aout_tlast, aout_tdata);

default
clocking @(posedge clk);
endclocking

default disable iff rst; 

logic last_arrived_reg;
logic [my_pkg::DATA_WIDTH/2-1:0] prev_data_out;
logic prev_data_out_vld_reg;
logic [my_pkg::DATA_WIDTH/2-1:0] first_out, second_out;
logic [my_pkg::DATA_WIDTH/2-1:0] lsb, msb;
localparam int MAX_LAT = 80;
logic ain_hs, aout_hs;
logic in_done, out_done;
logic start_in;

assign first_out = aout_tdata[my_pkg::DATA_WIDTH/2-1:0];
assign second_out = aout_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2];

assign lsb = ain_tdata[my_pkg::DATA_WIDTH/2-1:0];
assign msb = ain_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2];

assign ain_hs = ain_tvalid  && ain_tready;
assign aout_hs = aout_tvalid && aout_tready;

assign in_done = ain_hs  && ain_tlast;
assign out_done = aout_hs && aout_tlast;

assign start_in = ain_hs && (sort.write_addr_reg == '0);

logic [3:0] exp_dup_reg;
logic [my_pkg::DATA_WIDTH/2-1:0] prev_elem;
logic prev_elem_vld;

always @(posedge clk) begin
  if (rst || start_in) begin
    exp_dup_reg <= '0;
    prev_elem <= '0;
    prev_elem_vld <= 1'b0;
  end else if (aout_hs) begin
    exp_dup_reg <= exp_dup_reg + (prev_elem_vld && (prev_elem == first_out)) + (first_out == second_out);
    prev_elem <= second_out;
    prev_elem_vld <= 1'b1;
  end
end

always @(posedge clk) begin
  if (rst || !sort.sorted_flag_reg) begin
    prev_data_out_vld_reg <= 1'b0;
  end else if (aout_tvalid && aout_tready) begin
    prev_data_out <= second_out;
    prev_data_out_vld_reg <= 1'b1;
  end
end

always @(posedge clk) begin
  if(rst == 1'b1) 
    begin
      last_arrived_reg <= 1'b0;
  end
  else if (ain_tvalid && ain_tready)
  begin
    if(ain_tlast == 1'b1)
      last_arrived_reg <= 1'b1;
    else
      last_arrived_reg <= last_arrived_reg; 
    end
  end

// Covers
c_wa5: cover property(sort.write_addr_reg == 10'd5);
c_15c: cover property(1[*15]);
c_j2i: cover property( (sort.j_reg > sort.num_elements_reg) |=> (sort.j_reg == sort.i_reg)); 
c_ifin: cover property(sort.sort_active == 1'b1 && sort.i_reg == sort.num_elements_reg);
c_swap2tl: cover property(sort.sort_state_reg == SORT_SWAP_ELEMENTS ##[0:$] aout_tlast);

c_inAsc: cover property(ain_tvalid && ain_tready && (sort.write_addr_reg=='0) &&  sort_dir);
c_outAsc:  cover property(aout_hs && sort.sort_dir_reg);
c_tlAsc: cover property(aout_hs && aout_tlast &&  sort.sort_dir_reg);
c_swapAsc: cover property(sort.sort_active && sort.sort_dir_reg && ((sort.upper_half_data < sort.min_upper_reg) || (sort.lower_half_data < sort.min_lower_reg)));

c_inDesc: cover property(ain_tvalid && ain_tready && (sort.write_addr_reg=='0) && !sort_dir);
c_outDesc: cover property(aout_hs && !sort.sort_dir_reg);
c_tlDesc: cover property(aout_hs && aout_tlast && !sort.sort_dir_reg);
c_swapDesc: cover property(sort.sort_active && !sort.sort_dir_reg && ((sort.upper_half_data > sort.min_upper_reg) || (sort.lower_half_data > sort.min_lower_reg)));

//Restrictions
/*r_dirAsc:restrict property (sort_dir == 1'b1);
r_inPairAsc: restrict property (ain_hs && sort_dir |-> (lsb <= msb));*/

/*r_dirDesc: restrict property (sort_dir == 1'b0);
r_inPairDesc: restrict property (ain_hs && !sort_dir |-> (lsb >= msb));*/
r_inPair: restrict property (ain_hs |-> (sort_dir ? (lsb <= msb) : (lsb >= msb)));

r_len: restrict property((sort.write_addr_reg < 4'd4) |-> !ain_tlast);
r_tlAt: restrict property((sort.write_addr_reg == 4'd4) |-> ain_tlast);
r_noTlAfter: restrict property(last_arrived_reg |-> !ain_tlast);
r_NoVAfter: restrict property(last_arrived_reg |-> !ain_tvalid);
r_rdyLo: restrict property(last_arrived_reg |-> ain_tdata == 'b0);
r_rdyHi: restrict property(!last_arrived_reg |-> aout_tready == 'b0);
r_force_out_ready_high_after_input_done: restrict property(last_arrived_reg |-> aout_tready == 'b1);

// Assertions
a_awb:assert property (aout_hs && sort.sort_dir_reg |-> (first_out <= second_out));
a_aab:assert property (aout_hs && sort.sort_dir_reg && prev_data_out_vld_reg |-> (prev_data_out <= first_out));

a_dwb: assert property (aout_hs && !sort.sort_dir_reg |-> (first_out >= second_out));
a_dab: assert property (aout_hs && !sort.sort_dir_reg && prev_data_out_vld_reg |-> (prev_data_out >= first_out));

a_noWrColl: assert property(!(sort.we_sort && (sort.ain_tready_s && ain_tvalid)));
a_prog: assert property (in_done |-> ##[1:MAX_LAT] out_done);
a_dup: assert property (out_done |=> (dup_nums == exp_dup_reg));
a_idleOD:assert property(out_done |-> ##[1:4](sort.write_addr_reg =='0 && sort.read_addr_reg =='0 && sort.sorted_flag_reg=='0 && sort.input_complete_reg=='0 && sort.num_elements_reg=='0));

endchecker

