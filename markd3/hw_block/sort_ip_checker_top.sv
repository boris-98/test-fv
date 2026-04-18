module top #(
  parameter int N_NUM = 16
) (
  input  logic        clk,
  input  logic        rst,
  input  logic        sort_dir,
  input  logic [31:0] ain_tdata //jasper bira na ciklusima gdje je ain_xfer=1
);

  // 2 broja (16b+16b) po taktu
  localparam int N_BEATS   = (N_NUM < 2) ? 1 : (N_NUM/2);
  localparam int LAST_BEAT = (N_BEATS > 0) ? (N_BEATS-1) : 0;
  localparam int BTW_W     = (N_BEATS <= 1) ? 1 : $clog2(N_BEATS);
  localparam logic [BTW_W-1:0] LAST_BEAT_V = LAST_BEAT;

  // dut ulazi/izlazi
  logic        ain_tvalid, ain_tready, ain_tlast;
  logic        aout_tvalid, aout_tready, aout_tlast;
  logic [31:0] aout_tdata;
  logic [9:0]  dup_nums;

  sort_ip #(.N_NUM(N_NUM)) dut (
    .clk        (clk),
    .rst        (rst),
    .sort_dir   (sort_dir),

    .ain_tvalid (ain_tvalid),
    .ain_tready (ain_tready),
    .ain_tdata  (ain_tdata),
    .ain_tlast  (ain_tlast),

    .aout_tvalid(aout_tvalid),
    .aout_tready(aout_tready),
    .aout_tdata (aout_tdata),
    .aout_tlast (aout_tlast),

    .dup_nums   (dup_nums)
  );

  assign aout_tready = 1'b1;

  // jedan po jedan paket
  logic sending, sent;
  logic [BTW_W-1:0] in_beat_cnt; // koji paket smo poslali

  assign ain_tvalid = sending && !sent && ain_tready;
  assign ain_tlast  = (sending && !sent && ain_tready && (in_beat_cnt == LAST_BEAT_V));

  wire ain_xfer = ain_tvalid && ain_tready; // bit stvarno poslat
  wire pkt_end  = ain_xfer && ain_tlast;

  // salje samo jedan paket
  always_ff @(posedge clk) begin
    if (rst) begin
      sending     <= 1'b0;
      sent        <= 1'b0;
      in_beat_cnt <= '0;
    end else begin
      if (!sent) begin
        if (!sending) begin
          sending     <= 1'b1;
          in_beat_cnt <= '0;
        end else if (ain_xfer) begin
          if (in_beat_cnt == LAST_BEAT_V) begin
            sending <= 1'b0;
            sent    <= 1'b1;
          end else begin
            in_beat_cnt <= in_beat_cnt + 1'b1;
          end
        end
      end
    end
  end

  // latch smjer na prvom transferu (isto kao dut)
  logic sort_dir_lat;
  always_ff @(posedge clk) begin
    if (rst) sort_dir_lat <= 1'b1;
    else if (ain_xfer && (in_beat_cnt == '0)) sort_dir_lat <= sort_dir;
  end



  // praćenje izlaza (sortiranost i dup)
  logic seen_end, out_done;
  logic [BTW_W-1:0] out_beat_cnt; // koji izlazni beat smo vidjeli

  logic [15:0] out0, out1;
  assign out0 = aout_tdata[15:0];   // prvi broj u beatu
  assign out1 = aout_tdata[31:16];  // drugi broj u beatu

  wire aout_xfer      = aout_tvalid && aout_tready;
  wire out_last_xfer  = aout_xfer && aout_tlast;

  logic prev_valid;
  logic [15:0] prev_val;

  logic [9:0] dup_out;
  logic [9:0] dup_out_n;

  // racunanje next state vr
  always_comb begin
    dup_out_n = dup_out;
    if (seen_end && !out_done && aout_xfer) begin
      if (prev_valid && (prev_val == out0)) dup_out_n = dup_out_n + 10'd1;
      if (out0 == out1)                     dup_out_n = dup_out_n + 10'd1;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin  // reset
      seen_end     <= 1'b0;
      out_done     <= 1'b0;
      out_beat_cnt <= '0;

      prev_valid <= 1'b0;
      prev_val   <= 16'd0;

      dup_out <= 10'd0;
    end else begin
      if (pkt_end) begin  // kraj ulaznog paketa
        seen_end     <= 1'b1;
        out_done     <= 1'b0;
        out_beat_cnt <= '0;

        prev_valid <= 1'b0;
        prev_val   <= 16'd0;

        dup_out <= 10'd0;
      end else if (seen_end && !out_done && aout_xfer) begin  // slanje izlaza
	// upis
        dup_out <= dup_out_n;

	// azur
        prev_valid <= 1'b1;
        prev_val   <= out1;
        
        // brojanje bitova i det kraj
        if (out_beat_cnt == LAST_BEAT_V) begin
          out_done <= 1'b1;
        end else begin
          out_beat_cnt <= out_beat_cnt + 1'b1;
        end
      end
    end
  end



  // propertiji
  default clocking cb @(posedge clk); endclocking
  default disable iff (rst);

  localparam int MAX_START = 4;
  localparam int MAX_DONE  = MAX_START + N_BEATS + 2;

  // abstrakcija - ograniči vrijednosti ulaznih brojeva tokom transfera
  // (svaki 16b broj na 4b vrijednost 0 - 15)
  a_in_range: assume property (
    ain_xfer |-> (ain_tdata[15:4]  == 12'h000) && (ain_tdata[31:20] == 12'h000)
  );

  // nema izlaza prije kraja ulaznog paketa
  a_no_out_before_end: assert property (!seen_end |-> !aout_tvalid);

  // izlaz mora krenuti i završiti bounded
  a_out_starts_bounded: assert property (pkt_end |-> ##[1:MAX_START] aout_xfer);
  a_out_done_bounded:   assert property (pkt_end |-> ##[1:MAX_DONE]  out_last_xfer);

  // tlast tačno na poslednjem beatu
  a_last_position: assert property (
    aout_xfer |-> (aout_tlast == (out_beat_cnt == LAST_BEAT_V))
  );

  // posle done nema više valid
  a_no_out_after_done: assert property (out_done |-> !aout_tvalid);

  // sortiranost - prev <= out0 <= out1 (rast) ili prev >= out0 >= out1 (opad)
  a_sorted: assert property (
    (seen_end && !out_done && aout_xfer) |-> (  // svaki izlazni transfer dok se salje paket
      sort_dir_lat ?
        ( (!prev_valid || (prev_val <= out0)) && (out0 <= out1) )  //  prev <= out0 i out0 <= out1 (ako nema prev, preskoci)

      :
        ( (!prev_valid || (prev_val >= out0)) && (out0 >= out1) )  // prev >= out0 i out0 >= out1 (ako nema prev, preskoci)

    )
  );

  // dup count
  a_dup_match:          assert property (out_last_xfer |=> (dup_nums == dup_out));

  // coveri
  c_pkt:  cover property (pkt_end);
  c_done: cover property (out_last_xfer);

endmodule

