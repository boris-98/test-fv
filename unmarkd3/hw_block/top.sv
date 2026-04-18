import param_pkg::*;

module top #(
    parameter DATA_WIDTH = param_pkg::DATA_WIDTH,
    parameter ADDR_WIDTH = param_pkg::ADDR_WIDTH
)
(
  input  logic clk,
  input  logic rst,

  input  logic sort_dir,
  output logic [ADDR_WIDTH:0] dup_nums,

  // AXI interface input
  input  logic ain_tvalid,
  output logic ain_tready,
  input  logic ain_tlast,
  input  logic [DATA_WIDTH-1:0] ain_tdata,

  // AXI interface output
  output logic aout_tvalid,
  input  logic aout_tready,
  output logic aout_tlast,
  output logic [DATA_WIDTH-1:0] aout_tdata
	
) ;
	sort #(
	    .DATA_WIDTH(DATA_WIDTH),
	    .ADDR_WIDTH(ADDR_WIDTH)
	  ) uufv (
	   .clk(clk),
	   .rst(rst),
	   .sort_dir(sort_dir),
	   .dup_nums(dup_nums),
	   .ain_tvalid(ain_tvalid),
	   .ain_tready(ain_tready),
	   .ain_tlast(ain_tlast),
	   .ain_tdata(ain_tdata),
	   .aout_tvalid(aout_tvalid),
	   .aout_tready(aout_tready),
	   .aout_tlast(aout_tlast),
	   .aout_tdata(aout_tdata));

	//variables for calculating duplicates on input
	localparam MAX_SEEN = 1 << DATA_WIDTH;
	logic [DATA_WIDTH/2-1:0] seen_values[0:((1 << DATA_WIDTH) - 1)];
	int seen_count;
        int count_duplicates;
	int expected_duplicates;

	logic seen_before_upper;
	logic seen_before_lower;

	//count duplicates helper
	logic [ADDR_WIDTH-1:0] cnt_input;
	//sort_direction helper
	logic stable_dir_flag;

	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			seen_count = 0;
			count_duplicates = 0;
			expected_duplicates = 0;

			seen_before_upper = 0;
			seen_before_lower = 0;

			cnt_input = 0;
		end
		else if (ain_tvalid && ain_tready) begin

			cnt_input +=1;

			seen_before_upper = 0;
			seen_before_lower = 0;

			for (int i = 0; i < MAX_SEEN; i++) begin
				if (i < seen_count) begin
					if (seen_values[i] == ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2])
						seen_before_upper = 1;

					if (seen_values[i] == ain_tdata[DATA_WIDTH/2-1:0])
						seen_before_lower = 1;
				end
			end

			if (seen_before_upper && seen_before_lower) begin
				count_duplicates += 2;
			end
			else if (seen_before_upper) begin
				count_duplicates++;
				seen_values[seen_count] = ain_tdata[DATA_WIDTH/2-1:0];
				seen_count++;
			end
			else if (seen_before_lower) begin
				count_duplicates++;
				seen_values[seen_count] = ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2];
				seen_count++;
			end
			else begin
				if (ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2] == ain_tdata[DATA_WIDTH/2-1:0]) begin
					seen_values[seen_count] = ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2];
					seen_count++;
					count_duplicates++;
				end
				else begin
					seen_values[seen_count] = ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2];
					seen_count++;
					seen_values[seen_count] = ain_tdata[DATA_WIDTH/2-1:0];
					seen_count++;
				end
			end 
			

			if(ain_tlast) begin
				expected_duplicates = count_duplicates;
			end
		end

		if (aout_tlast) begin
			count_duplicates = 0;
			seen_count = 0;

			cnt_input = 0;
		end

		if (rst) begin
			stable_dir_flag = 0;
		end
		else begin
			if ($fell(aout_tlast))
				stable_dir_flag = 0;

			if (ain_tvalid)
				stable_dir_flag = 1;
		end

    	end

	default clocking @ (posedge clk); endclocking
	default disable iff (rst); 

	//sort_dir must be the same during one full sort cycle
	//restrict property ((ain_tvalid || uufv.state == 2'b01 || uufv.state == 2'b10 || uufv.state == 2'b11) |-> $stable(sort_dir));
	restrict property (stable_dir_flag |-> $stable(sort_dir));
	//restriction for counting duplicates in formal tool - don't send more inputs 
	//than can be placed within the memory of the sort component
	restrict property (((cnt_input == ((1 << ADDR_WIDTH) - 1)) && ain_tvalid && ain_tready) |-> ain_tlast);	

	//1. Check AXI input interface
	// if we have valid input the sort component must at some point start processing it
	assert property (ain_tvalid |-> ##[0:$] ain_tready);

	//2. Check AXI output interface 
        //last can only be active if valid is active
	assert property (aout_tlast |-> aout_tvalid);
        //last can only be active for one cycle if ready and valid are active + after last is asserted valid becomes inactive
	assert property ((aout_tlast && aout_tready && aout_tvalid) |=> (!aout_tlast && !aout_tvalid)); 
	//if data on output is valid but the component receiving is not ready data on output should not change
	assert property ((!aout_tready && aout_tvalid && ($past(aout_tvalid) && $past(!aout_tready))) |-> (aout_tdata == $past(aout_tdata)));

	//3. Check that array is sorted on output
        //compare 32bit values in the 64bit output - sort_dir ascending
	assert property (((aout_tvalid && aout_tready) && sort_dir) |-> (aout_tdata[DATA_WIDTH-1:DATA_WIDTH/2] >= aout_tdata[DATA_WIDTH/2-1:0]));
        //cross compare adjacent 32bit value with current one  - sort_dir ascending
	assert property ((($past(aout_tvalid) && $past(aout_tready)) && (aout_tvalid && aout_tready) && sort_dir) |-> (aout_tdata[DATA_WIDTH/2-1:0] >= $past(aout_tdata[DATA_WIDTH-1:DATA_WIDTH/2])));

	//compare 32bit values in the 64bit output - sort_dir descending
	assert property (((aout_tvalid && aout_tready) && !sort_dir) |-> (aout_tdata[DATA_WIDTH-1:DATA_WIDTH/2] <= aout_tdata[DATA_WIDTH/2-1:0]));
        //cross compare adjacent 32bit value with current one  - sort_dir descending
	assert property ((($past(aout_tvalid) && $past(aout_tready)) && (aout_tvalid && aout_tready) && !sort_dir) |-> (aout_tdata[DATA_WIDTH/2-1:0] <= $past(aout_tdata[DATA_WIDTH-1:DATA_WIDTH/2])));

	//4. Check that duplicates are calculated correctly
	assert property ($fell(aout_tlast) |-> (expected_duplicates == dup_nums));
	

	//WHITEBOX APPROACH -> check FSM of sort algo is working properly
	//cover property ((uufv.state == 2'b00) ##1 (uufv.state == 2'b01));
	//cover property ((uufv.state == 2'b01) ##1 (uufv.state == 2'b10));
	//cover property ((uufv.state == 2'b10) ##1 (uufv.state == 2'b11));
	//cover property ((uufv.state == 2'b11) ##1 (uufv.state == 2'b00));

endmodule
