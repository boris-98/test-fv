
module hw_block #(parameter S = 1024)
(
  input logic clk,
  input logic rst,

  input logic sort_dir,
  // AXI slave - DUT receive this signals
  input  logic       tvalid,
  output logic       tready,
  input logic [31:0] tdata,
  input logic        tlast,
  // AXI Master - DUT sends this signals
  output  logic       out_tvalid,
  input logic         out_tready,
  output logic [31:0] out_tdata,
  output logic        out_tlast
  );

  const logic[$clog2(S)-1:0] one = 1;

  const logic[$clog2(S)-1:0] s_converted = S;

  typedef enum logic [1:0] {IDLE = 2'b00, GET_DATA = 2'b01, SORT_DATA = 2'b10, SEND_DATA = 2'b11} state_t;
  state_t curr_state;
  state_t next_state;

  logic array_sorted;

  // memorija za smestanje podataka
  logic[15:0] memory[S];
  logic[15:0] memory_next[S];

  logic[15:0] a_reg, a_next;
  logic[15:0] b_reg, b_next;
  logic[15:0] c_reg, c_next;
  logic[15:0] d_reg, d_next;

  logic[7:0] counter, counter_next, addr1, addr2, cnt;
  logic start_sorting, tvalid_set, tlast_set;

  // ---------------------------------
  // Sequential logic
  // ---------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
        curr_state <= IDLE;
    end
    else begin
        curr_state <= next_state;
    end
  end 

  // Next state logic
  always_comb begin
	next_state = curr_state;

	case(curr_state)
		IDLE: next_state = GET_DATA;

		GET_DATA: begin
			if (tlast) begin
				next_state   = SORT_DATA;
			end else begin
				next_state   = GET_DATA;
			end
		end
		SORT_DATA: begin
			// when data is sorted then send them
			if(array_sorted) begin
				next_state   = SEND_DATA;
			end else begin
				next_state   = SORT_DATA;
			end
		end
		SEND_DATA: begin
			if(counter == 1022) begin
				next_state   = IDLE;
			end else begin
				next_state   = SEND_DATA;
			end
		end

		default: next_state   = IDLE;
	endcase

  end
  // tready output 
  always_comb begin
    tready = 0;
    if (curr_state == GET_DATA) 
	tready = 1;
  end

  // FSM states and
  always_ff@(posedge clk) begin

     case (curr_state)

	IDLE: begin
		counter <= 0;
	end

        // Get data from AXI stream
        GET_DATA: begin

		if (tvalid) begin
			// increasing order
			if (sort_dir) begin
				if (tdata[31:16] > tdata[15:0]) begin
					memory[counter]      <= tdata[15:0];
					memory[counter+1]    <= tdata[31:16];
				end else begin
					memory[counter]      <= tdata[31:16];
					memory[counter+1]    <= tdata[15:0];
				end
			// decreasing order
			end else begin
				if (tdata[31:16] > tdata[15:0]) begin
					memory[counter]      <= tdata[31:16];
					memory[counter+1]    <= tdata[15:0];
				end else begin
					memory[counter]      <= tdata[15:0];
					memory[counter+1]    <= tdata[31:16];
				end
			end
			// increase counter by 2
			if (tlast) counter <= 0;
			else counter <= counter + 2;
		end 

	end

	SORT_DATA: begin
		if (array_sorted) begin
			start_sorting <= 0;
		end else begin
			start_sorting <= 1;
		end
		// should implement sorting module here , pipelined with 55 stages

/*
			// 1. Stage - Get data from mem
			a_reg <= memory[counter];
			b_reg <= memory[counter+1];

			c_reg <= memory[counter+2];
			d_reg <= memory[counter+3];

			// 2. Stage - Compare data
			if (a_reg > b_reg) begin
				memory[counter] <= b_reg;
				memory[counter+1] <= a_reg;
			end else begin
				memory[counter] <= a_reg;
				memory[counter+1] <= b_reg;
			end

			// 2. Stage - Compare data
			if (c_reg > d_reg) begin
				memory[counter+2] <= d_reg;
				memory[counter+3] <= c_reg;
			end else begin
				memory[counter+2] <= c_reg;
				memory[counter+3] <= d_reg;
			end
			counter <= counter + 8'd2;
*/
	end

	SEND_DATA: begin

		if (out_tready) begin

			out_tdata[31:16] <= memory[counter];
			out_tdata[15:0]  <= memory[counter+1];
			
			counter <= counter + 2;

		end

	end

      endcase

  end


   // out_tlast logic
  always_comb begin
    tlast_set = 1'b0;
    
    if (curr_state == SEND_DATA && counter == 1022) begin
	tlast_set = 1;
    end
  end 

  assign out_tlast = tlast_set;

  // out_tvalid logic
  always_comb begin
    tvalid_set = 1'b0;
    
    if (curr_state == SEND_DATA) begin
	tvalid_set = 1;
    end
  end

  assign out_tvalid = tvalid_set;

  // Logic when array is sorted
  always_comb begin
    array_sorted = 1'b0;
    for (int i=0; i<1023; i++) begin
      if (memory[i] > memory[i+1]) begin
	array_sorted = 1;
      end
    end
  end

  // Assumptions and cover points

	default clocking
		 @(posedge clk);
	endclocking
		
	default disable iff (rst);

  	// AXI Slave
	tlast_one_cycle:assume property ( $fell(rst) |-> (tlast == 0) [*511] ##1 (tlast == 1) ##1 (tlast == 0) [*] );
	tvalid_go_to_zero: assume property ( tlast |=> !tvalid);
	tvalid_stable: assume property ( tvalid |=> $stable(tvalid) until tlast);

	out_tready_stable: assume property ( out_tready |=> $stable(out_tready) until out_tlast);

	array_sorted_coverage: cover property (curr_state == SORT_DATA && array_sorted);
	sort_dir_stable: assume property ( tvalid |=> $stable(sort_dir) until out_tlast);


endmodule 
