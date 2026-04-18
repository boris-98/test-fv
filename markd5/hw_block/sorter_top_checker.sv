checker sorter_top_checker(
  clk, rst,
  ain_tvalid, ain_tready, ain_tdata, ain_tlast,
  aout_tvalid, aout_tready, aout_tdata, aout_tlast,
  sort_dir, dup_nums
);

  let state_idle    = (sorter_top.u_control_path.state == sorter_top.u_control_path.IDLE);
  let state_receive = (sorter_top.u_control_path.state == sorter_top.u_control_path.RECEIVE);
  let state_process = (sorter_top.u_control_path.state == sorter_top.u_control_path.SORTING);
  let state_send    = (sorter_top.u_control_path.state == sorter_top.u_control_path.SEND);

  default clocking @(posedge clk);
  endclocking
  default disable iff (rst);

    // slave moze da primi
  asm0: assume property( ain_tvalid && !ain_tready|=> ain_tvalid);

  a0: assert property( $fell(rst) |-> state_idle);
  
  a1: assert property(ain_tready == (state_idle || state_receive));

  a2: assert property(aout_tvalid == state_send);
  
  c0: cover property(state_idle ##[1:$] state_receive ##[1:$] state_process ##[1:$] state_send ##[1:$] state_idle);

  c1: cover property( state_send && dup_nums > 0);

  a3: assert property(state_send && $past(state_send) |-> $stable(dup_nums));

  a4: assert property(!state_send |-> dup_nums == 0);


  // slicno kao iz pdfa, samo pojednostavljeno zbog alata
  asm1: assume property(sort_dir == 1);
  
  // slave mora biti spreman
  asm2: assume property(aout_tready);

    // sledeca 3 assume imaju smisla za broj parova = 4 
  asm3: assume property(!ain_tready |-> !ain_tlast);
  
  asm4: assume property(
    (ain_tvalid && ain_tready && !ain_tlast)[*3] ##1 (ain_tvalid && ain_tready) |-> ain_tlast
  );
  
  asm5: assume property(ain_tlast && ain_tvalid && ain_tready |=> !ain_tlast until ain_tready);


  sequence pdf_input_seq;
    (ain_tvalid && ain_tready && !ain_tlast && ain_tdata == {4'd12, 4'd6})
    ##1 (ain_tvalid && ain_tready && !ain_tlast && ain_tdata == {4'd9, 4'd3})
    ##1 (ain_tvalid && ain_tready && !ain_tlast && ain_tdata == {4'd15, 4'd2})
    ##1 (ain_tvalid && ain_tready && ain_tdata == {4'd7, 4'd3} && ain_tlast);
  endsequence

  sequence pdf_output_seq;
    (aout_tvalid && aout_tready && aout_tdata == {4'd3, 4'd2})
    ##1 (aout_tvalid && aout_tready && aout_tdata == {4'd6, 4'd3})
    ##1 (aout_tvalid && aout_tready && aout_tdata == {4'd9, 4'd7})
    ##1 (aout_tvalid && aout_tready && aout_tdata == {4'd15, 4'd12} && aout_tlast);
  endsequence

  c2: cover property(pdf_input_seq ##[1:$] pdf_output_seq);

  a5: assert property(!rst && aout_tvalid && sort_dir == 1 |-> aout_tdata[3:0] <= aout_tdata[7:4] );

  a6: assert property(aout_tlast |-> aout_tvalid);

  a7: assert property(ain_tlast && ain_tvalid && ain_tready |=> !state_idle);

  a8: assert property(aout_tlast && aout_tvalid && aout_tready |=> state_idle);

  a9: assert property(state_idle && !ain_tvalid |=> state_idle);

  a10: assert property(state_process |-> !ain_tready);

  c4: cover property(state_send && dup_nums == 0);

  c5: cover property(aout_tlast && aout_tready);

  c6: cover property($rose(state_process) ##[1:$] $rose(state_send));

/*
  sequence input_seq;
    (ain_tvalid && ain_tready && !ain_tlast && ain_tdata == {4'd3, 4'd2})
    ##1 (ain_tvalid && ain_tready && !ain_tlast && ain_tdata == {4'd4, 4'd3})
    ##1 (ain_tvalid && ain_tready && ain_tdata == {4'd5, 4'd3} && ain_tlast);
  endsequence

  sequence output_seq;
    (aout_tvalid && aout_tready && aout_tdata == {4'd3, 4'd2})
    ##1 (aout_tvalid && aout_tready && aout_tdata == {4'd3, 4'd3})
    ##1 (aout_tvalid && aout_tready && aout_tdata == {4'd5, 4'd4} && aout_tlast);
  endsequence

  c3: cover property(input_seq ##[1:$] output_seq);
*/

endchecker
