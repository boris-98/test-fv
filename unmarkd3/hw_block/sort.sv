//STEPS:
  //1. sort local input
  //2. store into memory
  //3. sort globally
  //4. send result to output (+ copies calculation)

module sort #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH
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
  );

  logic [DATA_WIDTH/2-1:0] data_in1_s, data_in2_s;

  logic [ADDR_WIDTH-1:0] i_cnt; 
  logic [ADDR_WIDTH-1:0] j_cnt;
  logic merge_done;
  logic captured_sort_dir;

  //State of sort
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    STORE = 2'b01,
    MERGE = 2'b10,
    SEND  = 2'b11
  } state_t;

  state_t state;

  //Store and send result memory signals
  logic we_store;
  logic [ADDR_WIDTH-1:0] addr_send_s, addr_store_s;
  logic [DATA_WIDTH-1:0] data_store_s;

  //Duplicates calculation signals 
  logic cross_duplicate_s, duplicate_s;
  logic [ADDR_WIDTH-1:0] addr_send_compare_s;

  //Merge memory signals
  logic we_a_merge_write;
  logic [ADDR_WIDTH-1:0] addr_merge_read_a_s, addr_merge_write_a_s;

  logic we_b_merge_write;
  logic [ADDR_WIDTH-1:0] addr_merge_read_b_s, addr_merge_write_b_s;
  logic [DATA_WIDTH-1:0] data_merge_write_a_s, data_merge_write_b_s;

  //Memory signals 
  logic we_a_s, we_b_s;
  logic [ADDR_WIDTH-1:0] addr_read_a_s, addr_read_b_s;
  logic [ADDR_WIDTH-1:0] addr_write_a_s, addr_write_b_s;
  logic [DATA_WIDTH-1:0] data_in_a_s, data_in_b_s; 
  logic [DATA_WIDTH-1:0] data_out_a_s, data_out_b_s;

  memory #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) mem_inst (
    .clk(clk),
    .rst(rst),
    .we_a(we_a_s),
    .we_b(we_b_s),
    .addr_read_a(addr_read_a_s),
    .addr_read_b(addr_read_b_s),
    .addr_write_a(addr_write_a_s),
    .addr_write_b(addr_write_b_s),
    .data_in_a(data_in_a_s),
    .data_in_b(data_in_b_s),
    .data_out_a(data_out_a_s),
    .data_out_b(data_out_b_s));

/* ============================================================
   0. FSM
   ============================================================ */
always @(posedge clk) begin
    if(rst) begin
        state <= IDLE;
    end
    else begin
	    case (state)
		IDLE: begin //idle state
		    if(ain_tvalid) begin
			captured_sort_dir = sort_dir;
		        state <= STORE;
		    end
		end
		STORE: begin //locally sort and store input
		    if(ain_tlast && ain_tvalid && ain_tready)
		        state <= MERGE;
		end
		MERGE: begin //sort input
		  if (merge_done)
		    state <= SEND;
		end
		SEND: begin //send sorted array to output
		    if(aout_tlast && aout_tvalid && aout_tready)
		        state <= IDLE;
		end
		default: begin
		end
    		endcase
   end
end

/* ============================================================
   0. driving our AXI signals
   ============================================================ */
assign ain_tready = state == STORE;  
assign aout_tlast = (state == SEND) && (addr_send_s == addr_store_s);
assign aout_tvalid = state == SEND;

/* ============================================================
   0. connect memory pins with memory signals
   ============================================================ */
assign we_a_s = (state == MERGE) ? we_a_merge_write : we_store;
assign addr_read_a_s = (state == MERGE) ? addr_merge_read_a_s : addr_send_s;
assign addr_write_a_s = (state == MERGE) ? addr_merge_write_a_s : addr_store_s;
assign data_in_a_s = (state == MERGE) ? data_merge_write_a_s : data_store_s;

assign we_b_s = we_b_merge_write;
assign addr_read_b_s = (state == MERGE) ? addr_merge_read_b_s : addr_send_compare_s;
assign addr_write_b_s = addr_merge_write_b_s;
assign data_in_b_s = data_merge_write_b_s;

/* ============================================================
   1. sort local input and 2. store into memory
   ============================================================ */

assign data_in2_s = ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2]; //31:16
assign data_in1_s = ain_tdata[DATA_WIDTH/2-1:0]; //15:0

assign we_store = (state == STORE) && ain_tvalid && ain_tready;

//generate address
always @(posedge clk) begin
    if (rst || state == IDLE) begin
        addr_store_s <= 0;
    end 
    else if (we_store && !ain_tlast) begin
        addr_store_s <= (addr_store_s < ((1 << ADDR_WIDTH) - 1))? (addr_store_s + 1'd1) : ((1 << ADDR_WIDTH) - 1);
    end
end

//sort [upper_halfword, lower_halfword]
always_comb begin
    if(captured_sort_dir == 1'd1)
        if(data_in1_s <= data_in2_s)
			  //31.....16,15........0
            data_store_s = {data_in2_s, data_in1_s};
        else 
            data_store_s = {data_in1_s, data_in2_s};
    else
        if(data_in1_s <= data_in2_s)
            data_store_s = {data_in1_s, data_in2_s};
        else 
            data_store_s = {data_in2_s, data_in1_s};
end

/* ============================================================
   3. sort globally
   ============================================================ */
assign merge_done = !(state != MERGE || rst) && (i_cnt == addr_store_s);

// Iterator logic
always @(posedge clk) begin
    if (rst || state != MERGE) begin
        i_cnt <= 0;
        j_cnt <= 0;

	we_a_merge_write <= 0;
	we_b_merge_write <= 0;
    end
    else begin
        we_a_merge_write <= (state == MERGE && !merge_done);
        we_b_merge_write <= (state == MERGE && !merge_done);

        if (j_cnt < (addr_store_s-i_cnt)) begin
            j_cnt <= j_cnt + 1'd1;

	    if (j_cnt == (addr_store_s-1-i_cnt)) begin
		j_cnt <= 0;
		i_cnt <= i_cnt + 1'd1;
	    end
        end
    end
end

// Read current adjacent pair
assign addr_merge_read_a_s = j_cnt;
assign addr_merge_read_b_s = j_cnt + 1'd1;

// Write back to same address in next clk
always @(posedge clk) begin
  addr_merge_write_a_s <= j_cnt;
  addr_merge_write_b_s <= j_cnt + 1'd1;
end

// Temporary registers for comparison
logic [DATA_WIDTH-1:0] in0, in1;
logic [DATA_WIDTH-1:0] out0, out1;

// Perform compare and swap
always_comb begin
    //use data forwarding via out0 and out1 when one of the inputs was sorted in the previous clk cycle
    //else use normal memory outputs
    in0 = (j_cnt != 0)? out1 : data_out_a_s; // mem[j]
    in1 = ((addr_store_s > 1) && (j_cnt == 0 && i_cnt == (addr_store_s-1)))? out0 : data_out_b_s; // mem[j+1]

    //[out0, out1] = sort(in0, in1, sort_dir)
    if (state == MERGE) begin
        coreSort(in0, in1, captured_sort_dir, out0, out1);
    end
end

always @(posedge clk) begin        
  data_merge_write_a_s <= out0;
  data_merge_write_b_s <= out1;
end

/* ============================================================
   4. send result to output (+ copies calculate)
   ============================================================ */

//generate address
always @(posedge clk) begin
    if (rst || state == MERGE)
        addr_send_s <= 0;
    else if ((state == SEND) && aout_tvalid && aout_tready)
        addr_send_s <= addr_send_s + 1'd1;
end

//calculate num of copies
assign addr_send_compare_s = addr_send_s - 1'd1;                      				      //read adjacent memory block
assign duplicate_s = data_out_a_s[DATA_WIDTH-1:DATA_WIDTH/2] == data_out_a_s[DATA_WIDTH/2-1:0];       //duplicate is inside single memory block
assign cross_duplicate_s = data_out_b_s[DATA_WIDTH-1:DATA_WIDTH/2] == data_out_a_s[DATA_WIDTH/2-1:0]; //duplicate is adjacent to current mem block

always @(posedge clk) begin
    if (rst || state == IDLE) begin
        dup_nums <= 0;
    end
    else if (aout_tready && aout_tvalid) begin
	if (addr_send_s >= 1'd1) begin //do both compare and cross compare
		if (duplicate_s && cross_duplicate_s) 
			dup_nums <= dup_nums + 2'd2;
		else if (duplicate_s || cross_duplicate_s)
			dup_nums <= dup_nums + 1'd1;
	end
	else if (addr_send_s == 1'd0) begin //compare only within mem block
		if (duplicate_s) 
			dup_nums <= dup_nums + 1'd1;
	end
    end
end

assign aout_tdata = data_out_a_s;

/* ============================================================
   0. helper
   ============================================================ */

task automatic coreSort(
    input logic [DATA_WIDTH-1:0] data0,
    input logic [DATA_WIDTH-1:0] data1,
    input logic sort_dir, //1 -> ascending 0 -> descending
    output logic [DATA_WIDTH-1:0] result0,
    output logic [DATA_WIDTH-1:0] result1
);

  logic [DATA_WIDTH/2-1:0] min0, max0;
  logic [DATA_WIDTH/2-1:0] min1, max1;

  logic [DATA_WIDTH/2-1:0] out_min0, out_max0;
  logic [DATA_WIDTH/2-1:0] out_min1, out_max1;

  // Extract fields
  if (sort_dir == 1) begin
    min0 = data0[DATA_WIDTH/2-1:0];
    max0 = data0[DATA_WIDTH-1:DATA_WIDTH/2];

    min1 = data1[DATA_WIDTH/2-1:0];
    max1 = data1[DATA_WIDTH-1:DATA_WIDTH/2];
  end
  else if (sort_dir == 0) begin
    min0 = data0[DATA_WIDTH-1:DATA_WIDTH/2];
    max0 = data0[DATA_WIDTH/2-1:0];

    min1 = data1[DATA_WIDTH-1:DATA_WIDTH/2];
    max1 = data1[DATA_WIDTH/2-1:0];
  end

  // Default (no change)
  //(max0 <= min1 && sort_dir == 1) || (max1 <= min0 && sort_dir == 0)
  out_min0 = min0;
  out_max0 = max0;
  out_min1 = min1;
  out_max1 = max1;

  //No overlap - swap pair
  if ((max1 <= min0 && sort_dir == 1) || (max0 <= min1 && sort_dir == 0)) begin
      out_min0 = min1;
      out_max0 = max1;
      out_min1 = min0;
      out_max1 = max0;
  end
  //Overlapping ranges
  else if (min0 <= min1 && (max0 >= min1 && max0 <= max1)) begin
      if (sort_dir == 1) begin
        out_min0 = min0;
        out_max0 = min1;
        out_min1 = max0;
        out_max1 = max1;
      end
      else if (sort_dir == 0) begin
        out_min0 = max0;
        out_max0 = max1;
        out_min1 = min0;
        out_max1 = min1;
      end
  end
  else if (min1 <= min0 && (max1 >= min0 && max1 <= max0)) begin
      if (sort_dir == 1) begin
        out_min0 = min1;
        out_max0 = min0;
        out_min1 = max1;
        out_max1 = max0;
      end
      else if (sort_dir == 0) begin
        out_min0 = max1;
        out_max0 = max0;
        out_min1 = min1;
        out_max1 = min0;
      end
  end
  //Subsets
  else if (min0 <= min1 && max1 <= max0) begin
      if (sort_dir == 1) begin
        out_min0 = min0;
        out_max0 = min1;
        out_min1 = max1;
        out_max1 = max0;
      end
      else if (sort_dir == 0) begin
        out_min0 = max1;
        out_max0 = max0;
        out_min1 = min0;
        out_max1 = min1;
      end
  end
  else if (min1 <= min0 && max0 <= max1) begin
    if (sort_dir == 1) begin
      out_min0 = min1;
      out_max0 = min0;
      out_min1 = max0;
      out_max1 = max1;
    end
    else if (sort_dir == 0) begin
      out_min0 = max0;
      out_max0 = max1;
      out_min1 = min1;
      out_max1 = min0;
    end
  end

  if (sort_dir == 1) begin
           //31....16, 15.....0
    result0 = {out_max0, out_min0};
    result1 = {out_max1, out_min1};
  end
  else if (sort_dir == 0) begin
           //31....16, 15.....0
    result0 = {out_min0, out_max0};
    result1 = {out_min1, out_max1};
  end
   
endtask

endmodule
