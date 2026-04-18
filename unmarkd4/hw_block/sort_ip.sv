import my_pkg::*;
module sort_ip #(parameter DATA_WIDTH = my_pkg::DATA_WIDTH, parameter DEPTH = 8, parameter ADDR_WIDTH=3)
    (
	input clk,
	input rst,
	input sort_dir,
	input ain_tvalid,
	output ain_tready,
	input ain_tlast,
	input[DATA_WIDTH-1:0] ain_tdata,
	output aout_tvalid,
	input aout_tready,
	output aout_tlast,
	output[DATA_WIDTH-1:0] aout_tdata,
	output [DATA_WIDTH/2-1:0] dup_nums);

typedef enum {IDLE,PROCESSING} states;
typedef enum {IDLE_SORT, FIND_LESS_SORT, SWAP_SORT, WRITE_SORT, END_J_SORT, DIAGONAL_SWAP, COUNT_DUPS} sort_states;

states state_s_reg,state_s_next,state_m_reg,state_m_next;
sort_states state_sort_reg, state_sort_next;

logic ain_tready_s;
logic [DATA_WIDTH-1:0] data_w_stream;
logic aout_tvalid_s, aout_tlast_s;
logic [DATA_WIDTH-1:0] aout_tdata_s;

logic [ADDR_WIDTH-1:0] addr_in_reg,addr_in_next;
logic [ADDR_WIDTH-1:0] addr_out_reg,addr_out_next;
logic [ADDR_WIDTH-1:0] i_next,i_reg,j_next,j_reg;

logic array_sorted_reg,array_sorted_next;
logic last_el_arrived_reg,last_el_arrived_next;
logic [ADDR_WIDTH-1:0] num_of_arrived_el_reg, num_of_arrived_el_next;

logic[DATA_WIDTH-1:0] data_in_mem_s, data_out_mem_s;
logic[ADDR_WIDTH-1:0] addr_w_mem_s, addr_r_mem_s;
logic we_mem_s;

logic[DATA_WIDTH/2-1:0] msb_data, lsb_data;
assign msb_data = data_out_mem_s[DATA_WIDTH-1:DATA_WIDTH/2];
assign lsb_data = data_out_mem_s[DATA_WIDTH/2-1:0];

logic [DATA_WIDTH/2-1:0] smallest_msb_data_reg, smallest_msb_data_next;
logic [DATA_WIDTH/2-1:0] smallest_lsb_data_reg, smallest_lsb_data_next;

mem #(.DATA_WIDTH(DATA_WIDTH),.DEPTH(DEPTH), .ADDR_WIDTH(ADDR_WIDTH)) mem_inst(
    .clk(clk), .rst(rst),
    .address_write(addr_w_mem_s), .address_read(addr_r_mem_s),
    .data_in(data_in_mem_s), .data_out(data_out_mem_s), .we(we_mem_s));

logic is_sorting;
logic reset_last_el;
logic [DATA_WIDTH-1:0] data_w_sort;
logic [ADDR_WIDTH-1:0] addr_w_sort;
logic [ADDR_WIDTH-1:0] addr_r_sort;
logic we_sort;

logic [DATA_WIDTH-1:0] swap_reg, swap_next;

logic [DATA_WIDTH/2-1:0] dup_nums_reg, dup_nums_next;
assign dup_nums = dup_nums_reg;

logic [ADDR_WIDTH-1:0] addr_w_stream, addr_r_stream;
logic clear_sorted_reg;
logic reset_num_fo_arrived_el_reg;

assign aout_tdata    = data_out_mem_s;
assign addr_w_stream = addr_in_reg;
assign addr_r_stream = addr_out_next;
assign addr_w_mem_s  = is_sorting ? addr_w_sort  : addr_w_stream;
assign addr_r_mem_s  = is_sorting ? addr_r_sort  : addr_r_stream;
assign data_in_mem_s = is_sorting ? data_w_sort  : data_w_stream;
assign we_mem_s      = (ain_tready_s & ain_tvalid) || we_sort;

always @(posedge clk) begin
	if (rst) begin
		state_s_reg           <= IDLE;
		state_m_reg           <= IDLE;
		state_sort_reg        <= IDLE_SORT;
		addr_in_reg           <= 'b0;
		addr_out_reg          <= 'b0;
		array_sorted_reg      <= 'b0;
		last_el_arrived_reg   <= 'b0;
		i_reg                 <= 'b0;
		j_reg                 <= 'b0;
		smallest_lsb_data_reg <= 'b0;
		smallest_msb_data_reg <= 'b0;
		num_of_arrived_el_reg <= 'b0;
		swap_reg              <= 'b0;
		dup_nums_reg          <= 'b0;
	end
	else begin
		state_s_reg   <= state_s_next;
		state_m_reg   <= state_m_next;
		state_sort_reg<= state_sort_next;
		addr_in_reg   <= addr_in_next;
		addr_out_reg  <= addr_out_next;

		if (clear_sorted_reg == 1'b1) begin
			array_sorted_reg <= 1'b0;
			dup_nums_reg     <= 'b0;
		end
		else begin
			array_sorted_reg  <= array_sorted_next;
			dup_nums_reg     <= dup_nums_next;
		end

		if (reset_last_el == 1'b1)
			last_el_arrived_reg <= 1'b0;
		else
			last_el_arrived_reg <= last_el_arrived_next;

		i_reg                 <= i_next;
		j_reg                 <= j_next;
		smallest_lsb_data_reg <= smallest_lsb_data_next;
		smallest_msb_data_reg <= smallest_msb_data_next;

		if (reset_num_fo_arrived_el_reg == 1'b1)
			num_of_arrived_el_reg <= 'b0;
		else
			num_of_arrived_el_reg <= num_of_arrived_el_next;

		swap_reg <= swap_next;
	end
end

wire [DATA_WIDTH-1:0] ain_hi = {{16'b0}, ain_tdata[DATA_WIDTH-1 : DATA_WIDTH/2]};
wire [DATA_WIDTH-1:0] ain_lo = {{16'b0}, ain_tdata[DATA_WIDTH/2-1 : 0]};

assign data_w_stream = sort_dir
    ? ((ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2] > ain_tdata[DATA_WIDTH/2-1:0])
       ? {ain_tdata[DATA_WIDTH/2-1:0], ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2]}
       : ain_tdata)
    : ((ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2] < ain_tdata[DATA_WIDTH/2-1:0])
       ? {ain_tdata[DATA_WIDTH/2-1:0], ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2]}
       : ain_tdata);

// SLAVE LOGIC
always @* begin
	num_of_arrived_el_next <= num_of_arrived_el_reg;
	case (state_s_reg)
		IDLE: begin
			addr_in_next <= 'b0;
			ain_tready_s <= 1'b0;
			if (ain_tvalid == 1'b1 && is_sorting == 1'b0 && array_sorted_reg == 1'b0)
				state_s_next <= PROCESSING;
			else
				state_s_next <= IDLE;
		end
		default: begin
			state_s_next <= PROCESSING;
			addr_in_next <= addr_in_reg;
			ain_tready_s <= 1'b1;
			if (ain_tvalid == 1'b1) begin
				addr_in_next <= addr_in_reg + 1;
				if (ain_tlast == 1'b1) begin
					state_s_next           <= IDLE;
					num_of_arrived_el_next <= addr_in_reg;
				end
			end
		end
	endcase
end

assign ain_tready = ain_tready_s;

// MASTER LOGIC 
always @* begin
	case (state_m_reg)
		IDLE: begin
			clear_sorted_reg            <= 'b0;
			addr_out_next               <= 'b0;
			aout_tvalid_s               <= 'b0;
			aout_tlast_s                <= 'b0;
			reset_num_fo_arrived_el_reg <= 1'b0;
			if (array_sorted_reg == 1'b1)
				state_m_next <= PROCESSING;
			else
				state_m_next <= IDLE;
		end
		default: begin
			aout_tlast_s                <= 'b0;
			aout_tvalid_s               <= 'b1;
			addr_out_next               <= addr_out_reg;
			state_m_next                <= PROCESSING;
			clear_sorted_reg            <= 'b0;
			reset_num_fo_arrived_el_reg <= 1'b0;
			if (aout_tready == 1'b1) begin
				addr_out_next <= addr_out_reg + 1;
				if (addr_out_reg == num_of_arrived_el_reg) begin
					state_m_next                <= IDLE;
					aout_tlast_s                <= 'b1;
					clear_sorted_reg            <= 'b1;
					reset_num_fo_arrived_el_reg <= 1'b1;
				end
			end
		end
	endcase
end

assign aout_tvalid = aout_tvalid_s;
assign aout_tlast  = aout_tlast_s;

// SORTING PROCESS
always @* begin
	data_w_sort            <= '0;
	addr_w_sort            <= '0;
	addr_r_sort            <= j_next;
	is_sorting             <= 1'b1;
	reset_last_el          <= 1'b0;
	we_sort                <= 1'b0;
	smallest_lsb_data_next <= smallest_lsb_data_reg;
	smallest_msb_data_next <= smallest_msb_data_reg;
	array_sorted_next      <= array_sorted_reg;
	swap_next              <= swap_reg;
	dup_nums_next          <= dup_nums_reg;

	case (state_sort_reg)
		IDLE_SORT: begin
			is_sorting             <= 1'b0;
			i_next                 <= 'b0;
			j_next                 <= 'b0;
			we_sort                <= 1'b0;
			smallest_lsb_data_next <= lsb_data;
			smallest_msb_data_next <= msb_data;
			if (last_el_arrived_reg == 1'b1) begin
				is_sorting      <= 1'b1;
				j_next          <= j_reg + 1;
				state_sort_next <= FIND_LESS_SORT;
			end
			else
				state_sort_next <= IDLE_SORT;
			addr_r_sort <= j_next;
		end

		FIND_LESS_SORT: begin
			if (i_reg <= num_of_arrived_el_reg - 1) begin
				if (j_reg <= num_of_arrived_el_reg) begin
					if (sort_dir
					    ? ((msb_data < smallest_msb_data_reg) || (lsb_data < smallest_lsb_data_reg) || (msb_data < smallest_lsb_data_reg))
					    : ((msb_data > smallest_msb_data_reg) || (lsb_data > smallest_lsb_data_reg) || (lsb_data > smallest_msb_data_reg)))
					begin
						state_sort_next <= SWAP_SORT;
						j_next          <= j_reg;
						i_next          <= i_reg;
					end
					else begin
						state_sort_next <= FIND_LESS_SORT;
						j_next          <= j_reg + 1;
						i_next          <= i_reg;
					end
				end
				else begin
					i_next          <= i_reg + 1;
					j_next          <= i_next;
					state_sort_next <= END_J_SORT;
				end
			end
			else begin
				// nakon sortiranja idi u COUNT_DUPS
				// resetuj j za prolaz kroz memoriju i ocisti swap_reg
				i_next          <= 'b0;
				j_next          <= 'b0;
				reset_last_el   <= 1'b1;
				dup_nums_next   <= 'b0;
				swap_next       <= 'b0;
				addr_r_sort     <= 'b0;
				state_sort_next <= COUNT_DUPS;
			end
		end

		END_J_SORT: begin
			i_next                 <= i_reg;
			j_next                 <= j_reg + 1;
			smallest_msb_data_next <= msb_data;
			smallest_lsb_data_next <= lsb_data;
			state_sort_next        <= FIND_LESS_SORT;
		end

		SWAP_SORT: begin
			state_sort_next <= DIAGONAL_SWAP;
			j_next          <= j_reg;
			i_next          <= i_reg;
			data_w_sort     <= {smallest_msb_data_reg, smallest_lsb_data_reg};
			swap_next       <= {msb_data, lsb_data};
			if (sort_dir ? (msb_data < smallest_msb_data_reg) : (msb_data > smallest_msb_data_reg)) begin
				swap_next[DATA_WIDTH-1:DATA_WIDTH/2]   <= smallest_msb_data_reg;
				data_w_sort[DATA_WIDTH-1:DATA_WIDTH/2] <= msb_data;
				smallest_msb_data_next                 <= msb_data;
				we_sort                                <= 1'b1;
			end
			if (sort_dir ? (lsb_data < smallest_lsb_data_reg) : (lsb_data > smallest_lsb_data_reg)) begin
				swap_next[DATA_WIDTH/2-1:0]   <= smallest_lsb_data_reg;
				data_w_sort[DATA_WIDTH/2-1:0] <= lsb_data;
				smallest_lsb_data_next        <= lsb_data;
				we_sort                       <= 1'b1;
			end
			addr_w_sort <= i_reg;
		end

		DIAGONAL_SWAP: begin
			state_sort_next <= WRITE_SORT;
			j_next          <= j_reg;
			i_next          <= i_reg;
			data_w_sort     <= {smallest_msb_data_reg, smallest_lsb_data_reg};
			addr_w_sort     <= i_reg;
			if (sort_dir
			    ? (swap_reg[DATA_WIDTH-1:DATA_WIDTH/2] < smallest_lsb_data_reg)
			    : (swap_reg[DATA_WIDTH-1:DATA_WIDTH/2] > smallest_lsb_data_reg))
			begin
				swap_next              <= {smallest_lsb_data_reg, swap_reg[DATA_WIDTH/2-1:0]};
				smallest_lsb_data_next <= swap_reg[DATA_WIDTH-1:DATA_WIDTH/2];
				data_w_sort            <= {smallest_msb_data_reg, swap_reg[DATA_WIDTH-1:DATA_WIDTH/2]};
				we_sort                <= 1'b1;
			end
		end

		// COUNT_DUPS state
		// prolazi kroz sortiranu memoriju i broji susedne jednake parov
		// j_reg==0 podatak jos nije validan
		// j_reg==1 ucitava mem[0] u swap_reg 
		// j_reg>=2 poredi mem[j-1] sa swap_reg, ako su jednaki inkrement dup_nums
		
		COUNT_DUPS: begin
		    is_sorting  <= 1'b1;
		    we_sort     <= 1'b0;
		    i_next      <= i_reg;
		    addr_r_sort <= j_next;

		    if (j_reg <= num_of_arrived_el_reg) begin
			j_next          <= j_reg + 1;
			state_sort_next <= COUNT_DUPS;

			if (j_reg == 0) begin
			    // ucitaj prvi element u swap_reg
			    swap_next <= data_out_mem_s;
			end
			else begin
			    // poredi trenutni element sa prethodnim (swap_reg)
			    if (data_out_mem_s == swap_reg)
				dup_nums_next <= dup_nums_reg + 1;
			    else
				dup_nums_next <= dup_nums_reg;
			    swap_next <= data_out_mem_s;
			end
		    end
		    else begin
			// zavrsio prolazak kroz memoriju
			j_next            <= 'b0;
			array_sorted_next <= 1'b1;
			state_sort_next   <= IDLE_SORT;
			is_sorting        <= 1'b0;
			// dup_nums ostaje stabilan dok ne stigne novi niz
			dup_nums_next     <= dup_nums_reg;
		    end
		end

		default: begin  // write sort
			addr_w_sort     <= j_reg;
			data_w_sort     <= swap_reg;
			we_sort         <= 1'b1;
			state_sort_next <= FIND_LESS_SORT;
			j_next          <= j_reg + 1;
			i_next          <= i_reg;
		end
	endcase
end

always @* begin
	if (ain_tlast == 1'b1 && is_sorting == 1'b0)
		last_el_arrived_next <= 1'b1;
	else
		last_el_arrived_next <= last_el_arrived_reg;
end

endmodule
