`timescale 1ns/1ps
`default_nettype none

module top (
  input  wire clk,
  input  wire rst
);

  localparam int unsigned N     = 8;
  localparam int unsigned BEATS = N/2;

  // Environment (anyseq)
  (* anyseq *) logic        sort_dir_in;
  (* anyseq *) logic [31:0] next_in_data;

  logic aout_tready;
  always_comb aout_tready = 1'b1;

  // Drive AXI-stream IN
  logic        ain_tvalid;
  wire         ain_tready;
  logic [31:0] ain_tdata;
  logic        ain_tlast;

  int unsigned send_beats;
  logic [31:0] ain_tdata_reg;

  always_comb begin
    ain_tvalid = (send_beats < BEATS);
    ain_tlast  = (send_beats == (BEATS-1)) && (send_beats < BEATS);
    ain_tdata  = ain_tdata_reg;
  end

  // DUT
  wire         aout_tvalid;
  wire [31:0]  aout_tdata;
  wire         aout_tlast;
  wire [15:0]  dup_nums;

  sort_ip #(.N(N)) dut (
    .clk        (clk),
    .rst        (rst),
    .sort_dir   (sort_dir_in),
    .dup_nums   (dup_nums),

    .ain_tvalid (ain_tvalid),
    .ain_tready (ain_tready),
    .ain_tdata  (ain_tdata),
    .ain_tlast  (ain_tlast),

    .aout_tvalid(aout_tvalid),
    .aout_tready(aout_tready),
    .aout_tdata (aout_tdata),
    .aout_tlast (aout_tlast)
  );

  // Scoreboards capture IN and OUT
  logic [15:0] in_vals  [0:N-1];
  logic [15:0] out_vals [0:N-1];

  int unsigned in_cnt;
  int unsigned out_cnt;

  logic sort_dir_cap;
  logic sort_dir_cap_valid;

  wire in_hs  = ain_tvalid  && ain_tready;
  wire out_hs = aout_tvalid && aout_tready;

  wire [31:0] out_cnt_next = out_cnt + (out_hs ? 2 : 0);

  integer jj;
  always_ff @(posedge clk) begin
    if (rst) begin
      send_beats         <= 0;
      ain_tdata_reg      <= 32'd0;
      in_cnt             <= 0;
      out_cnt            <= 0;
      sort_dir_cap       <= 1'b1;
      sort_dir_cap_valid <= 1'b0;

      // init arrays to avoid "ffff" confusion in traces
      for (jj = 0; jj < N; jj++) begin
        in_vals[jj]  <= '0;
        out_vals[jj] <= '0;
      end
    end else begin
      if (in_hs) begin
        if (!sort_dir_cap_valid) begin
          sort_dir_cap       <= sort_dir_in;
          sort_dir_cap_valid <= 1'b1;
        end

        in_vals[in_cnt+0] <= ain_tdata[15:0];
        in_vals[in_cnt+1] <= ain_tdata[31:16];
        in_cnt            <= in_cnt + 2;

        send_beats    <= send_beats + 1;
        ain_tdata_reg <= next_in_data; 
      end

      if (out_hs) begin
        out_vals[out_cnt+0] <= aout_tdata[15:0];
        out_vals[out_cnt+1] <= aout_tdata[31:16];
        out_cnt             <= out_cnt + 2;
      end
    end
  end

logic [15:0] dup_latched;

always_ff @(posedge clk) begin
  if (rst) begin
    dup_latched <= 16'd0;
  end else if (out_hs && (out_cnt_next == N)) begin
    dup_latched <= dup_nums;
  end
end

  // Done flags
  logic out_done;
  logic out_done_d;
  logic out_done_dd;

  always_ff @(posedge clk) begin
    if (rst) begin
      out_done    <= 1'b0;
      out_done_d  <= 1'b0;
      out_done_dd <= 1'b0;
    end else begin
      if (out_hs && (out_cnt_next == N))
        out_done <= 1'b1;

      out_done_d  <= out_done;
      out_done_dd <= out_done_d;
    end
  end

  // fastchecks 
  logic [31:0] sum_in, sum_out;
  logic [15:0] xor_in, xor_out;
  logic [31:0] sumsq_in, sumsq_out;
  logic [15:0] dup_out_calc;

  integer ii;

  always_comb begin
    sum_in    = 0;
    sum_out   = 0;
    xor_in    = 0;
    xor_out   = 0;
    sumsq_in  = 0;
    sumsq_out = 0;

    for (ii = 0; ii < N; ii++) begin
      sum_in    = sum_in + in_vals[ii];
      sum_out   = sum_out + out_vals[ii];
      xor_in    = xor_in ^ in_vals[ii];
      xor_out   = xor_out ^ out_vals[ii];
      sumsq_in  = sumsq_in + (in_vals[ii]  * in_vals[ii]);
      sumsq_out = sumsq_out + (out_vals[ii] * out_vals[ii]);
    end

    dup_out_calc = 0;
    for (ii = 1; ii < N; ii++) begin
      if (out_vals[ii] == out_vals[ii-1])
        dup_out_calc = dup_out_calc + 1;
    end
  end

  // ASSUMPTIONS / COVER
  assume property (@(posedge clk) disable iff (rst)
    ain_tvalid |-> ##[0:5] ain_tready
  );

  cover property (@(posedge clk) disable iff (rst)
    (in_cnt == N) ##[1:2000] out_done
  );

  // ASSERTIONS

  // A) Input tlast only on last beat
  assert property (@(posedge clk) disable iff (rst)
    ain_tvalid |-> (ain_tlast == (send_beats == (BEATS-1)))
  );

  // B) Output tlast exactly on last output beat
  assert property (@(posedge clk) disable iff (rst)
    out_hs |-> (aout_tlast == (out_cnt_next == N))
  );

  // C) Output is sorted (check after completion)
  genvar k;
  generate
    for (k = 0; k < N-1; k++) begin : GEN_SORTED
      assert property (@(posedge clk) disable iff (rst)
        out_done_d |-> (sort_dir_cap ? (out_vals[k] <= out_vals[k+1])
                                    : (out_vals[k] >= out_vals[k+1]))
      );
    end
  endgenerate

  // D) dup_nums equals adjacent-equal count on output (delay 2 cycles)
  assert property (@(posedge clk) disable iff (rst)
  out_done_d |-> (dup_latched == dup_out_calc)
);

  // F) Single-frame harness: after done, no more valid
  assert property (@(posedge clk) disable iff (rst)
    out_done_d |-> (!aout_tvalid)
  );

endmodule

`default_nettype wire
