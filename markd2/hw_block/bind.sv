bind sort sort_checker c0(
  .clk(clk),
  .rst(rst),

  .sort_dir(sort_dir),
  .dup_nums(dup_nums),

  .ain_tvalid(ain_tvalid),
  .ain_tready(ain_tready),
  .ain_tlast(ain_tlast),
  .ain_tdata(ain_tdata),

  .aout_tvalid(aout_tvalid),
  .aout_tready(aout_tready),
  .aout_tlast(aout_tlast),
  .aout_tdata(aout_tdata)
);

