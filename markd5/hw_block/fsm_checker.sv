checker fsm_checker(
  clk, rst,
  ain_tvalid, ain_tlast, ain_tready,
  aout_tready, aout_tvalid, aout_tlast,
  pair_idx, pair_valid, compare_and_swap_done,
  io_addr, io_wr,
  state_idle, state_receive, state_process, state_send
);

  default clocking @(posedge clk);
  endclocking
  default disable iff (rst);

  // Reset - IDLE
  a0: assert property (
    $fell(rst) |-> state_idle
  );

  a1: assert property (
    state_idle |=> (state_idle || state_receive));

  a2: assert property (state_receive |=> (state_receive || state_process));

  a3: assert property (state_process |=> (state_process || state_send));

  a4: assert property (state_send |=> (state_send || state_idle));

  a5: assert property (ain_tready == (state_idle || state_receive) );

  a6: assert property (aout_tvalid == state_send );

  a7: assert property( pair_valid |-> state_process );

  a8: assert property(io_wr |-> (state_idle || state_receive) );

  a9: assert property ( (state_idle && !ain_tvalid) |=> state_idle );

  a10: assert property ( (state_receive && !(ain_tvalid && ain_tlast)) |=> state_receive);

  a11: assert property((state_process && pair_valid && !compare_and_swap_done) |=> (state_process && $stable(pair_idx)) );

  a12: assert property ((state_process && !aout_tready) |=> state_process);

  a13: cover property(state_idle ##[1:$] state_receive ##[1:$] state_process ##[1:$] state_send ##[1:$] state_idle);

endchecker
