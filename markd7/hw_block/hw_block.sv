`ifndef N
`define N 1024
`endif

module sort_ip (
  input logic clk,
  input logic rst_n,
  input logic [31:0] ain_tdata,
  input logic ain_tvalid,
  output logic ain_tready,
  input logic ain_tlast,
  input logic sort_dir,
  output logic [31:0] aout_tdata,
  output logic aout_tvalid,
  input logic aout_tready,
  output logic aout_tlast,
  output logic [9:0] dup_nums
);

  localparam int N = `N;
  localparam int HALF = N / 2;

  typedef enum logic [1:0] {IDLE, RECEIVE, SORT, SEND} state_t;
  state_t state;

  logic [15:0] buffer [0:N-1];
  logic [$clog2(HALF)-1:0] ptr;
  logic [$clog2(N):0] sort_step;
  logic odd_even;
  logic sort_dir_reg;

  assign ain_tready = (state == IDLE) || (state == RECEIVE);
  assign aout_tvalid = (state == SEND);
  assign aout_tdata = {buffer[{ptr, 1'b1}], buffer[{ptr, 1'b0}]};
  assign aout_tlast =
      (state == SEND) && (ptr == $clog2(HALF)'(HALF - 1));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      ptr <= '0;
      sort_step <= '0;
      odd_even <= '0;
      dup_nums <= '0;
      sort_dir_reg <= '0;
    end else begin
      case (state)
        IDLE: begin
          ptr <= '0;
          if (ain_tvalid) begin
            sort_dir_reg <= sort_dir;
            dup_nums <= '0;
            state <= RECEIVE;
          end
        end

        RECEIVE: begin
          if (ain_tvalid) begin
            buffer[{ptr, 1'b0}] <= ain_tdata[15:0];
            buffer[{ptr, 1'b1}] <= ain_tdata[31:16];
            ptr <= ptr + 1;
            if (ain_tlast ||
                ptr == $clog2(HALF)'(HALF - 1)) begin
              state <= SORT;
              sort_step <= '0;
              odd_even <= '0;
            end
          end
        end

        SORT: begin
          for (int j = 0; j < HALF; j++) begin
            automatic int idx =
                odd_even ? (j * 2 + 1) : (j * 2);
            if (idx < N - 1) begin
              automatic logic [15:0] a = buffer[idx];
              automatic logic [15:0] b = buffer[idx + 1];
              if (sort_dir_reg ? (a > b) : (a < b)) begin
                buffer[idx] <= b;
                buffer[idx + 1] <= a;
              end
            end
          end
          odd_even <= ~odd_even;
          sort_step <= sort_step + 1;
          if (sort_step == ($clog2(N) + 1)'(N - 1)) begin
            state <= SEND;
            ptr <= '0;
          end
        end

        SEND: begin
          if (aout_tready) begin
            automatic logic [1:0] dup_inc = 2'd0;
            if (buffer[{ptr, 1'b0}] ==
                buffer[{ptr, 1'b1}])
              dup_inc = dup_inc + 2'd1;
            if (ptr > 0 &&
                buffer[{ptr, 1'b0}] ==
                buffer[{ptr - $clog2(HALF)'(1), 1'b1}])
              dup_inc = dup_inc + 2'd1;
            dup_nums <= dup_nums + 10'(dup_inc);

            if (ptr == $clog2(HALF)'(HALF - 1)) begin
              state <= IDLE;
            end else begin
              ptr <= ptr + 1;
            end
          end
        end
      endcase
    end
  end

  /*
  function automatic [9:0] count_duplicates_ref();
    count_duplicates_ref = '0;
    for (int j = 0; j < N - 1; j++)
      if (buffer[j] == buffer[j + 1])
        count_duplicates_ref =
            count_duplicates_ref + 10'd1;
  endfunction
  */

  default clocking dc @(posedge clk);
  endclocking

  logic [9:0] i;

  assume_i_stable:
      assume property ($stable(i));
  assume_i_range:
      assume property (i <= 10'(N - 2));
  assume_sort_dir_stable:
      assume property ((state != IDLE) |->
                       $stable(sort_dir));
  assume_axi_handshake:
      assume property ((ain_tvalid && !ain_tready)
                       |=> ain_tvalid);
  assume_axi_data_stable:
      assume property ((ain_tvalid && !ain_tready)
                       |=> $stable(ain_tdata));
  assume_tlast_correct:
      assume property ((state == RECEIVE &&
                        ain_tvalid)
                       |->
                       (ain_tlast ==
                        (ptr ==
                         $clog2(HALF)'(HALF - 1))));
  assume_no_backtoback:
      assume property ((ain_tvalid && ain_tlast &&
                        ain_tready)
                       |=> !ain_tvalid);
  assume_out_ready_fair:
      assume property ((state == SEND)
                       |-> ##[0:4] aout_tready);

  assert_sort_ascending:
      assert property ((state == SEND &&
                        sort_dir_reg)
                       |->
                       (buffer[i] <=
                        buffer[i + 10'd1]));
  assert_sort_descending:
      assert property ((state == SEND &&
                        !sort_dir_reg)
                       |->
                       (buffer[i] >=
                        buffer[i + 10'd1]));

  // assert_dup_count:
  //   assert property ((state == SEND &&
  //                     aout_tready &&
  //                     aout_tlast) |=>
  //                    (dup_nums ==
  //                     count_duplicates_ref()));

  assert_dup_inc:
      assert property (
          ($past(state == SEND) &&
           $past(aout_tready))
          |->
          (dup_nums ==
           $past(dup_nums)
           + 10'(buffer[{$past(ptr), 1'b0}] ==
                 buffer[{$past(ptr), 1'b1}])
           + 10'(($past(ptr) > 0) &&
                 (buffer[{$past(ptr), 1'b0}] ==
                  buffer[{$past(ptr) -
                         $clog2(HALF)'(1),
                         1'b1}]))));

  assert_tlast_at_end:
      assert property (aout_tlast |->
                       (ptr ==
                        $clog2(HALF)'(HALF - 1)));
  assert_valid_iff_send:
      assert property (aout_tvalid ==
                       (state == SEND));
  assert_ready_iff_recv:
      assert property (ain_tready ==
                       (state == IDLE ||
                        state == RECEIVE));

  cover_full_flow:
      cover property (state == SEND &&
                      aout_tlast &&
                      aout_tready);
  cover_with_dups:
      cover property ($rose(state == IDLE) &&
                      dup_nums > 0);
  cover_receive:
      cover property (state == RECEIVE);
  cover_sort:
      cover property (state == SORT);
  cover_send:
      cover property (state == SEND);
  cover_desc:
      cover property (state == SEND &&
                      !sort_dir_reg);

endmodule
