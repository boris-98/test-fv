module sort #(
  parameter DATA_WIDTH = my_pkg::DATA_WIDTH,
  parameter DEPTH = 8,
  parameter ADDR_WIDTH = 3
)(
  input  logic clk,
  input  logic rst,

  input  logic sort_dir,
  output logic [ADDR_WIDTH:0] dup_nums,

  // AXI Slave interface
  input  logic ain_tvalid,
  output logic ain_tready,
  input  logic ain_tlast,
  input  logic [DATA_WIDTH-1:0] ain_tdata,

  // AXI Master interface
  output logic aout_tvalid,
  input  logic aout_tready,
  output logic aout_tlast,
  output logic [DATA_WIDTH-1:0] aout_tdata);

  typedef enum{ 
    IDLE, 
    PROCESSING 
  }state_t;

  typedef enum{
    SORT_IDLE,
    SORT_COMPARE_ELEMENTS,
    SORT_SWAP_ELEMENTS,
    SORT_WRITE_BACK,
    SORT_LOOP_J_DONE,
    SORT_DIAGONAL_COMPARE
  }sort_state_t;

  // Control FSM
  state_t s_state_reg, s_state_next, m_state_reg, m_state_next;
  sort_state_t sort_state_reg, sort_state_next;

  // Addressing counters
  logic [ADDR_WIDTH-1:0] write_addr_reg, write_addr_next;
  logic [ADDR_WIDTH-1:0] read_addr_reg, read_addr_next;
  logic [ADDR_WIDTH-1:0] num_elements_reg, num_elements_next;
  logic [ADDR_WIDTH-1:0] i_reg, i_next, j_reg, j_next;

  // AXI handshake/status
  logic ain_tready_s, aout_tvalid_s, aout_tlast_s;
  logic input_complete_reg, input_complete_next;
  logic sorted_flag_reg, sorted_flag_next;
  logic array_sorted;

  // Sort engine control signals
  logic sort_active;
  logic reset_element_count;
  logic reset_last_el;

  // BRAM port mux
  logic we_sort;
  logic [ADDR_WIDTH-1:0] addr_read_sort, addr_read_stream, addr_write_sort, addr_write_stream;
  logic [DATA_WIDTH-1:0] data_sort, data_stream;

  // Shared BRAM signals after muxing
  logic we_s;
  logic [ADDR_WIDTH-1:0] addr_read_b_s, addr_write_b_s;
  logic [DATA_WIDTH-1:0] data_in_b_s, data_out_b_s;

  // Sort datapath
  logic [DATA_WIDTH-1:0] swap_buf_reg, swap_buf_next;
  logic [DATA_WIDTH/2-1:0] upper_half_data, lower_half_data;
  logic [DATA_WIDTH/2-1:0] min_upper_reg, min_upper_next, min_lower_reg, min_lower_next;

  logic sort_dir_reg;
  logic cur_sort_dir;

  // Comparator results used by sorting FSM
  logic upper_better_than_min;
  logic lower_better_than_min;
  logic upper_better_than_minLower;
  logic diag_better;

  // Duplicate counting
  logic [ADDR_WIDTH:0] dup_cnt_reg;
  logic [ADDR_WIDTH:0] dup_inc;
  logic [DATA_WIDTH/2-1:0] prev_last_reg; 
  logic prev_last_vld_reg;
  logic [ADDR_WIDTH:0] dup_cnt_plus;

  logic [DATA_WIDTH/2-1:0] out_first, out_second;

  // BRAM
  bram #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) bram_inst (
    .clk(clk),
    .rst(rst),
    .we(we_s),
    .addr_read(addr_read_b_s),
    .addr_write(addr_write_b_s),
    .data_in(data_in_b_s),
    .data_out(data_out_b_s));

  // BRAM word unpacking
  assign upper_half_data = data_out_b_s[DATA_WIDTH-1:DATA_WIDTH/2];
  assign lower_half_data = data_out_b_s[DATA_WIDTH/2-1:0];

  // Output packing
  assign aout_tdata = {
    data_out_b_s[DATA_WIDTH/2-1:0],
    data_out_b_s[DATA_WIDTH-1:DATA_WIDTH/2]
  };

  // Used by duplicated logic
  assign out_first  = aout_tdata[DATA_WIDTH/2-1:0];
  assign out_second = aout_tdata[DATA_WIDTH-1:DATA_WIDTH/2];

  // Stream addressing
  assign addr_write_stream = write_addr_reg;
  assign addr_read_stream = read_addr_reg;

  // BRAM port muxing between stream logic and sort engine
  assign we_s = ((ain_tready_s && ain_tvalid) || we_sort);
  assign addr_read_b_s = sort_active ? addr_read_sort : addr_read_stream;
  assign addr_write_b_s = sort_active ? addr_write_sort : addr_write_stream;
  assign data_in_b_s = sort_active ? data_sort : data_stream;

  // Transaction sort direction
  assign cur_sort_dir = (write_addr_reg == '0) ? sort_dir : sort_dir_reg;

  // Normalize data
  assign data_stream =
    (cur_sort_dir == 1'b1) ? //ascending
      ((ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2] > ain_tdata[DATA_WIDTH/2-1:0]) ?
        {ain_tdata[DATA_WIDTH/2-1:0], ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2]} :
        ain_tdata)
    : //descending
      ((ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2] < ain_tdata[DATA_WIDTH/2-1:0]) ?
        {ain_tdata[DATA_WIDTH/2-1:0], ain_tdata[DATA_WIDTH-1:DATA_WIDTH/2]} :
        ain_tdata);

  // Sort comparator flags
  assign upper_better_than_min = sort_dir_reg ? (upper_half_data < min_upper_reg) : (upper_half_data > min_upper_reg);
  assign lower_better_than_min = sort_dir_reg ? (lower_half_data < min_lower_reg) : (lower_half_data > min_lower_reg);
  assign upper_better_than_minLower = sort_dir_reg ? (upper_half_data < min_lower_reg) : (upper_half_data > min_lower_reg);

  // Diagonal compare 
  assign diag_better = sort_dir_reg
    ? (swap_buf_reg[DATA_WIDTH-1:DATA_WIDTH/2] < min_lower_reg)
    : (swap_buf_reg[DATA_WIDTH-1:DATA_WIDTH/2] > min_lower_reg);

  assign dup_cnt_plus = dup_cnt_reg + dup_inc;

  // Sequential
  always @(posedge clk) begin
    if (rst) begin
      s_state_reg <= IDLE;
      m_state_reg <= IDLE;
      sort_state_reg <= SORT_IDLE;

      write_addr_reg <= '0;
      read_addr_reg <= '0;

      num_elements_reg <= '0;
      input_complete_reg <= 1'b0;
      sorted_flag_reg <= 1'b0;
      i_reg <= '0;
      j_reg <= '0;
 
      swap_buf_reg <= '0;
      min_upper_reg <= '0;
      min_lower_reg <= '0;

      sort_dir_reg <= 1'b1;

      dup_nums <= '0;
      dup_cnt_reg <= '0;
      prev_last_reg <= '0;
      prev_last_vld_reg <= 1'b0;
    end else begin
      s_state_reg <= s_state_next;
      m_state_reg <= m_state_next;
      sort_state_reg <= sort_state_next;

      write_addr_reg <= write_addr_next;
      read_addr_reg <= read_addr_next;

      i_reg <= i_next;
      j_reg <= j_next;

      swap_buf_reg <= swap_buf_next;
      min_upper_reg <= min_upper_next;
      min_lower_reg <= min_lower_next;

      // Clear after output done
      if (array_sorted)
        sorted_flag_reg <= 1'b0;
      else
        sorted_flag_reg <= sorted_flag_next;

      // Clear after sort done
      if (reset_last_el)
        input_complete_reg <= 1'b0;
      else
        input_complete_reg <= input_complete_next;

      // Clear frame length
      if (reset_element_count)
        num_elements_reg <= '0;
      else
        num_elements_reg <= num_elements_next;

      // Catch direction on first input beat
      if (ain_tready_s && ain_tvalid && (write_addr_reg == '0))
        sort_dir_reg <= sort_dir;

      // Duplicate count logic 
      if (aout_tvalid_s && aout_tready) begin
        prev_last_reg <= out_second;

	if (aout_tlast_s) begin
    	  dup_nums <= dup_cnt_plus; 
    	  dup_cnt_reg <= '0; 
    	  prev_last_vld_reg <= 1'b0;
  	end else begin
          dup_cnt_reg <= dup_cnt_plus;
          prev_last_vld_reg <= 1'b1;
  	end
      end
    end
  end

  // AXI-Stream slave control
  always @* begin
    num_elements_next = num_elements_reg;

    case (s_state_reg)
      IDLE: begin
        write_addr_next = '0;
        ain_tready_s = 1'b0;
        if (ain_tvalid && (sort_active == 1'b0) && (sorted_flag_reg == 1'b0))
          s_state_next = PROCESSING;
      end

      default: begin
        s_state_next = PROCESSING;
        ain_tready_s = 1'b1;
        write_addr_next = write_addr_reg;
        if (ain_tvalid) begin
          write_addr_next = write_addr_reg + 1'b1;
          if (ain_tlast) begin
            s_state_next = IDLE;
            num_elements_next = write_addr_reg;
          end
        end
      end
    endcase
  end

  assign ain_tready = ain_tready_s;

  // AXI-Stream master control
  always @* begin
    m_state_next = m_state_reg;
    array_sorted = 1'b0;
    aout_tvalid_s = 1'b0;
    aout_tlast_s = 1'b0;
    read_addr_next = read_addr_reg;
    reset_element_count = 1'b0;

    case (m_state_reg)
      IDLE: begin
        read_addr_next = '0;
        if (sorted_flag_reg)
          m_state_next = PROCESSING;
      end

      default: begin
        aout_tvalid_s = 1'b1;
        if (aout_tready && aout_tvalid_s) begin
          read_addr_next = read_addr_reg + 1'b1;
          if (read_addr_reg == num_elements_reg) begin
            m_state_next = IDLE;
            aout_tlast_s = 1'b1;
            reset_element_count = 1'b1;
            array_sorted = 1'b1;
          end
        end
      end
    endcase
  end

  assign aout_tvalid = aout_tvalid_s;
  assign aout_tlast = aout_tlast_s;

  // Sort block 
  always @* begin
    sort_active = 1'b1;

    data_sort = '0;
    addr_write_sort = '0;
    we_sort = 1'b0;

    sorted_flag_next = sorted_flag_reg;

    min_upper_next = min_upper_reg;
    min_lower_next = min_lower_reg;

    swap_buf_next = swap_buf_reg;

    reset_last_el = 1'b0;

    i_next = i_reg;
    j_next = j_reg;
    sort_state_next = sort_state_reg;

    addr_read_sort = j_reg;

    case (sort_state_reg)
      // Wait for full input frame
      SORT_IDLE: begin
        i_next = '0;
        j_next = '0;
        min_upper_next = upper_half_data;
        min_lower_next = lower_half_data;

        sort_active = 1'b0;
        we_sort = 1'b0;

        if (input_complete_reg) begin
          sort_active = 1'b1;
          j_next = j_reg + 1'b1;
          sort_state_next = SORT_COMPARE_ELEMENTS;
        end else begin
          sort_state_next = SORT_IDLE;
        end

        addr_read_sort = j_reg;
      end

      // Compare elements
      SORT_COMPARE_ELEMENTS: begin
        if (i_reg <= (num_elements_reg - 1'b1)) begin
          if (j_reg <= num_elements_reg) begin
            if (upper_better_than_min || lower_better_than_min || upper_better_than_minLower) begin
              sort_state_next = SORT_SWAP_ELEMENTS;
              i_next = i_reg;
              j_next = j_reg;
            end else begin
              sort_state_next = SORT_COMPARE_ELEMENTS;
              i_next = i_reg;
              j_next = j_reg + 1'b1;
            end
          end else begin
            i_next = i_reg + 1'b1;
            j_next = i_next;
            sort_state_next = SORT_LOOP_J_DONE;
          end
        end else begin
          i_next = '0;
          j_next = '0;
          sort_state_next = SORT_IDLE;
          reset_last_el = 1'b1;
          sorted_flag_next= 1'b1;
        end
      end

      SORT_LOOP_J_DONE: begin
        i_next = i_reg;
        j_next = j_reg + 1'b1;
        min_upper_next = upper_half_data;
        min_lower_next = lower_half_data;
        sort_state_next= SORT_COMPARE_ELEMENTS;
      end

      // Swapping elements
      SORT_SWAP_ELEMENTS: begin
        sort_state_next = SORT_DIAGONAL_COMPARE; // diagonal adjustment
        i_next = i_reg;
        j_next = j_reg;

        data_sort = {min_upper_reg, min_lower_reg};
        swap_buf_next = {upper_half_data, lower_half_data};

        if (upper_better_than_min) begin
          swap_buf_next[DATA_WIDTH-1:DATA_WIDTH/2] = min_upper_reg;
          data_sort[DATA_WIDTH-1:DATA_WIDTH/2] = upper_half_data;
          min_upper_next = upper_half_data;
          we_sort = 1'b1;
        end

        if (lower_better_than_min) begin
          swap_buf_next[DATA_WIDTH/2-1:0] = min_lower_reg;
          data_sort[DATA_WIDTH/2-1:0] = lower_half_data;
          min_lower_next = lower_half_data;
          we_sort = 1'b1;
        end

        addr_write_sort = i_reg;
      end

      SORT_DIAGONAL_COMPARE: begin
        sort_state_next = SORT_WRITE_BACK;
        i_next = i_reg;
        j_next = j_reg;

        data_sort = {min_upper_reg, min_lower_reg};
        addr_write_sort = i_reg;

        if (diag_better) begin
          swap_buf_next = {min_lower_reg, swap_buf_reg[DATA_WIDTH/2-1:0]};
          min_lower_next = swap_buf_reg[DATA_WIDTH-1:DATA_WIDTH/2];
          data_sort = {min_upper_reg, swap_buf_reg[DATA_WIDTH-1:DATA_WIDTH/2]};
          we_sort = 1'b1;
        end
      end

      default: begin
        // SORT_WRITE_BACK
        sort_state_next = SORT_COMPARE_ELEMENTS;
        we_sort = 1'b1;
        addr_write_sort = j_reg;
        data_sort = swap_buf_reg;
        i_next = i_reg;
        j_next = j_reg + 1'b1;
      end
    endcase
  end

  always @* begin
    dup_inc = '0;
    if (prev_last_vld_reg && (out_first == prev_last_reg))
      dup_inc = dup_inc + 1'b1;

    if (out_first == out_second)
      dup_inc = dup_inc + 1'b1;
  end

  // Input_complete
  always @* begin
    if (ain_tlast && ain_tvalid && ain_tready_s)
      input_complete_next = 1'b1;
    else
      input_complete_next = input_complete_reg;
  end

endmodule

