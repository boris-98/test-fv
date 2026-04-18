checker memory_checker(
  clk, rst, wr_a, addr_a, din_a, dout_a,
  wr_b, addr_b, din_b, dout_b
);

  default clocking @(posedge clk);
  endclocking
  default disable iff (rst);


  asm0: assume property (!wr_b);

  memory_c0: cover property (
    !wr_a ##1 wr_a && din_a == '1 ##1 (!wr_a && $stable(addr_a) && dout_a == $past(din_a))
  );

endchecker
