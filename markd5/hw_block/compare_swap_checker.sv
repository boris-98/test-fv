checker compare_swap_checker(
  clk, rst,
  sort_dir,
  pair_idx, pair_valid,
  mem_dout_a, mem_dout_b,
  mem_wr_a, mem_addr_a, mem_din_a,
  mem_wr_b, mem_addr_b, mem_din_b,
  compare_and_swap_done,
  dup_found
);
  default clocking @(posedge clk);
  endclocking
  default disable iff (rst);

  //asm0: assume property(mem_dout_a > mem_dout_b && sort_dir == 0);
   //asm0: assume property(mem_dout_a < mem_dout_b && sort_dir == 1);

  a0: assert property(pair_valid |=> compare_and_swap_done);

  a1: assert property((pair_valid && mem_dout_a == mem_dout_b) |=> dup_found);

  c0: cover property(pair_valid && ((sort_dir && mem_dout_a > mem_dout_b) || (!sort_dir && mem_dout_a < mem_dout_b)));
endchecker
