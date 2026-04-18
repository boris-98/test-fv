// IP koji checker instancira kao dut

module sort_ip #(
  parameter int N_NUM = 1024
) (
  input  logic        clk,
  input  logic        rst,

  input  logic        sort_dir,

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

  // dut - isti kao model
  sort_ip_model #(.N_NUM(N_NUM)) u_ref_as_dut (
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

endmodule

