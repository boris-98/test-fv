module sort_ip_model #(
  parameter int N_NUM = 1024
) (
  input  logic        clk,
  input  logic        rst,

  input  logic        sort_dir, // 1 rastuce, 0 opadajuce

  input  logic        ain_tvalid,
  output logic        ain_tready,
  input  logic [31:0] ain_tdata,
  input  logic        ain_tlast,

  output logic        aout_tvalid,
  input  logic        aout_tready,
  output logic [31:0] aout_tdata,
  output logic        aout_tlast,

  output logic [9:0]  dup_nums
);

  localparam int CNT_W = (N_NUM <= 1) ? 1 : $clog2(N_NUM+1); // sirina brojaca, ide do N_NUM
  localparam int ARR_W = (N_NUM <= 1) ? 1 : $clog2(N_NUM); // sirina indeksa za niz

  typedef logic [CNT_W-1:0] cnt_t;
  typedef logic [ARR_W-1:0] idx_t;

  logic [15:0] in_buf [0:N_NUM-1]; 

  cnt_t in_idx; // koliko brojeva je upisano (po 2)
  cnt_t out_idx; 
  logic in_done;
  logic out_done;
  logic sort_dir_lat; // latch verzija sort_dir, da se ne promjeni smjer 

  cnt_t in_idx_p1;
  idx_t in_i0, in_i1;

  cnt_t out_idx_p1;
  idx_t out_i0, out_i1;

  wire ain_xfer  = ain_tvalid  && ain_tready;
  wire aout_xfer = aout_tvalid && aout_tready;

  // indeksi za brojeve
  always @* begin
    in_idx_p1 = in_idx + cnt_t'(1);
    in_i0     = in_idx[ARR_W-1:0];
    in_i1     = in_idx_p1[ARR_W-1:0];

    out_idx_p1 = out_idx + cnt_t'(1);
    out_i0     = out_idx[ARR_W-1:0];
    out_i1     = out_idx_p1[ARR_W-1:0];
  end

  // ready je 1 dok se prima
  // i ima mjesta za jos jedan par brojeva (N_NUM-2 je poslednji start indeks za par)
  always @* begin
    ain_tready = (!in_done) && (in_idx <= cnt_t'(N_NUM-2));
  end

  // izlaz krece tek kad se zavrsi prijem paketa
  always @* begin
    aout_tvalid = (in_done && !out_done);

    if (aout_tvalid) begin
      aout_tdata = { sorted_val(out_i1), sorted_val(out_i0) };
      aout_tlast = (out_idx == cnt_t'(N_NUM-2));
    end else begin
      aout_tdata = 32'd0;
      aout_tlast = 1'b0;
    end
  end

  // dup nums se izracuna kad je paket primljen
  always @* begin
    if (in_done) dup_nums = dup_count();
    else         dup_nums = 10'd0;
  end

  // prijem i slanje paketa
  always @(posedge clk) begin
    if (rst) begin
      in_idx       <= '0;
      out_idx      <= '0;
      in_done      <= 1'b0;
      out_done     <= 1'b0;
      sort_dir_lat <= 1'b1;
    end else begin
      // prijem
      if (!in_done) begin
        if (ain_xfer) begin
          if (in_idx == '0) sort_dir_lat <= sort_dir;

          in_buf[in_i0] <= ain_tdata[15:0];
          in_buf[in_i1] <= ain_tdata[31:16];
          in_idx        <= in_idx + cnt_t'(2);

          if (ain_tlast) begin
            in_done  <= 1'b1;
            out_idx  <= '0;
            out_done <= 1'b0;
          end
        end
      end
      // slanje
      else if (!out_done) begin
        if (aout_xfer) begin
          if (out_idx == cnt_t'(N_NUM-2)) out_done <= 1'b1;
          else                            out_idx  <= out_idx + cnt_t'(2);
        end
      end
    end
  end

  // selection sort na kopiji ulaza
  function automatic logic [15:0] sorted_val(input idx_t idx);
    logic [15:0] a [0:N_NUM-1];
    logic [15:0] tmp;
    int unsigned i, j;
    idx_t ii, jj, best;
    begin
      for (i = 0; i < N_NUM; i = i + 1) begin
        ii   = i;
        a[ii]= in_buf[ii];
      end

      for (i = 0; i < (N_NUM-1); i = i + 1) begin
        ii   = i;
        best = ii;

        for (j = i + 1; j < N_NUM; j = j + 1) begin
          jj = j;
          if (sort_dir_lat) begin
            if (a[jj] < a[best]) best = jj;
          end else begin
            if (a[jj] > a[best]) best = jj;
          end
        end

        if (best != ii) begin
          tmp    = a[ii];
          a[ii]  = a[best];
          a[best]= tmp;
        end
      end

      sorted_val = a[idx];
    end
  endfunction

  function automatic logic [9:0] dup_count();
    logic [15:0] a [0:N_NUM-1];
    logic [15:0] tmp;
    int unsigned i, j;
    idx_t ii, jj, best;
    logic [9:0] d;
    begin
      for (i = 0; i < N_NUM; i = i + 1) begin
        ii   = i;
        a[ii]= in_buf[ii];
      end

      for (i = 0; i < (N_NUM-1); i = i + 1) begin
        ii   = i;
        best = ii;

        for (j = i + 1; j < N_NUM; j = j + 1) begin
          jj = j;
          if (sort_dir_lat) begin
            if (a[jj] < a[best]) best = jj;
          end else begin
            if (a[jj] > a[best]) best = jj;
          end
        end

        if (best != ii) begin
          tmp    = a[ii];
          a[ii]  = a[best];
          a[best]= tmp;
        end
      end

      d = 10'd0;
      for (i = 1; i < N_NUM; i = i + 1) begin
        ii = i;
        jj = (i-1);
        if (a[ii] == a[jj]) d = d + 1'b1;
      end

      dup_count = d;
    end
  endfunction

endmodule

