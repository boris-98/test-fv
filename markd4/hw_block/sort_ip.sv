`timescale 1ns/1ps
`default_nettype none

module sort_ip #(
  parameter int unsigned N = 1024
)(
  input  wire         clk,
  input  wire         rst,

  input  wire         sort_dir,
  output logic [15:0] dup_nums,

  input  wire         ain_tvalid,
  output logic        ain_tready,
  input  wire [31:0]  ain_tdata,
  input  wire         ain_tlast,

  output logic        aout_tvalid,
  input  wire         aout_tready,
  output wire [31:0]  aout_tdata,
  output wire         aout_tlast
);

  logic [15:0] mem [0:N-1];

  typedef enum logic [2:0] {S_IDLE, S_IN, S_SORT, S_DUPCNT, S_OUT} state_t;
  state_t st;

  int  in_idx;
  int  pass;
  int  sweep_pair;
  logic phase;

  int  dup_i;
  int  out_idx;

  logic sort_dir_frame;

  function automatic logic swap_needed(input logic [15:0] a, input logic [15:0] b, input logic dir);
    begin
      swap_needed = dir ? (a > b) : (a < b);
    end
  endfunction

  int i0, i1, j0, j1;
  int pairs_in_phase;

  always_comb begin
    pairs_in_phase = (phase ? ((N-1)/2) : (N/2));
    i0 = (phase ? 1 : 0) + (sweep_pair * 2);
    i1 = i0 + 1;
    j0 = i0 + 2;
    j1 = j0 + 1;
  end

  // output payload regs
  logic [31:0] out_word;
  logic        out_last;

  // AXI payload
  assign aout_tdata = out_word;
  assign aout_tlast = (st == S_OUT) ? out_last : 1'b0;

  always_ff @(posedge clk) begin
    if (rst) begin
      st             <= S_IDLE;
      ain_tready     <= 1'b0;

      aout_tvalid    <= 1'b0;

      dup_nums       <= 16'd0;

      in_idx         <= 0;
      pass           <= 0;
      sweep_pair     <= 0;
      phase          <= 1'b0;
      dup_i          <= 0;
      out_idx        <= 0;

      sort_dir_frame <= 1'b1;

      out_word       <= 32'd0;
      out_last       <= 1'b0;

    end else begin
      case (st)
        S_IDLE: begin
          ain_tready  <= 1'b1;
          aout_tvalid <= 1'b0;
          dup_nums    <= 16'd0;
          in_idx      <= 0;

          if (ain_tvalid && ain_tready) begin
            sort_dir_frame <= sort_dir;

            mem[0] <= ain_tdata[15:0];
            mem[1] <= ain_tdata[31:16];
            in_idx <= 2;

            if (N == 2) begin
              ain_tready <= 1'b0;
              dup_i      <= 1;
              dup_nums   <= 0;
              st         <= S_DUPCNT;
            end else begin
              st <= S_IN;
            end
          end
        end

        S_IN: begin
          ain_tready <= 1'b1;

          if (ain_tvalid && ain_tready) begin
            mem[in_idx+0] <= ain_tdata[15:0];
            mem[in_idx+1] <= ain_tdata[31:16];
            in_idx        <= in_idx + 2;

            if (in_idx + 2 >= N) begin
              ain_tready  <= 1'b0;
              pass        <= 0;
              phase       <= 1'b0;
              sweep_pair  <= 0;
              st          <= S_SORT;
            end
          end
        end

        S_SORT: begin
          if (i1 < N) begin
            if (swap_needed(mem[i0], mem[i1], sort_dir_frame)) begin
              logic [15:0] tmp;
              tmp     = mem[i0];
              mem[i0] <= mem[i1];
              mem[i1] <= tmp;
            end
          end

          if ((sweep_pair + 1) < pairs_in_phase) begin
            if (j1 < N) begin
              if (swap_needed(mem[j0], mem[j1], sort_dir_frame)) begin
                logic [15:0] tmp2;
                tmp2    = mem[j0];
                mem[j0] <= mem[j1];
                mem[j1] <= tmp2;
              end
            end
          end

          if (sweep_pair + 2 >= pairs_in_phase) begin
            sweep_pair <= 0;
            phase      <= ~phase;

            if (phase == 1'b1) begin
              pass <= pass + 1;
              if (pass + 1 >= N) begin
                dup_i    <= 1;
                dup_nums <= 0;
                st       <= S_DUPCNT;
              end
            end
          end else begin
            sweep_pair <= sweep_pair + 2;
          end
        end

        S_DUPCNT: begin
          if (dup_i < N) begin
            if (mem[dup_i] == mem[dup_i-1])
              dup_nums <= dup_nums + 1;
            dup_i <= dup_i + 1;
          end else begin
            out_idx     <= 0;
            out_word    <= {mem[1], mem[0]};
            out_last    <= (N == 2);
            aout_tvalid <= 1'b1;
            st          <= S_OUT;
          end
        end

        S_OUT: begin
          if (aout_tvalid && aout_tready) begin
            if (out_last) begin
              aout_tvalid <= 1'b0;
              st          <= S_IDLE;
            end else begin
              out_idx  <= out_idx + 2;
              out_word <= {mem[out_idx+3], mem[out_idx+2]};
              out_last <= (out_idx + 4 >= N);
            end
          end
        end

        default: st <= S_IDLE;
      endcase
    end
  end

endmodule

`default_nettype wire
