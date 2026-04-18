import my_pkg::*;
checker top_checkers (clk, rst, ain_tvalid, ain_tready, ain_tlast, ain_tdata,
                      aout_tvalid, aout_tready, aout_tlast, aout_tdata,
                      sort_dir, dup_nums);

    default clocking @(posedge clk);
    endclocking
    default disable iff rst;

    logic last_reg, last_next;
    logic [my_pkg::DATA_WIDTH-1:0]   last_datain_reg, last_datain_next;
    logic [my_pkg::DATA_WIDTH/2-1:0] prev_data_out;
    logic end_sorting;
    logic first_out_seen;

    always @(posedge clk) begin
        if (rst == 1'b1) begin
            last_reg        <= 1'b0;
            last_datain_reg <= sort_dir ? '1 : '0;
            end_sorting     <= 'b0;
            first_out_seen  <= 1'b0;
            prev_data_out   <= sort_dir ? '0 : '1;
        end
        else begin
            last_datain_reg = last_datain_next;

            if (ain_tlast == 1'b1)
                last_reg <= 1'b1;
            else
                last_reg <= last_reg;

            if (aout_tvalid && aout_tready) begin
                prev_data_out  <= aout_tdata[DATA_WIDTH/2-1:0];
                first_out_seen <= 1'b1;
            end
        end
    end

    assign last_datain_next = ain_tdata;

    
    see_inlast_signal:               cover property(sort_ip.addr_in_reg == 10'd5);
    see_11_cycles:                   cover property(1[*15]);
    see_end_output_data:             cover property(aout_tlast);
    cover_j_reset:                   cover property((sort_ip.j_reg > sort_ip.num_of_arrived_el_reg) |=> (sort_ip.j_reg == sort_ip.i_reg));
    cover_end_of_sort:               cover property(sort_ip.is_sorting == 1'b1 && sort_ip.i_reg == sort_ip.num_of_arrived_el_reg);
    check_if_sorted_reg_is_asserted: cover property(sort_ip.array_sorted_reg == 1'b1);
    cover_output_sequence:           cover property(sort_ip.state_sort_reg == SWAP_SORT ##[0:$] aout_tlast);

    see_swap_sort_state_asc: cover property(
        sort_dir == 1'b1
        && ((sort_ip.msb_data < sort_ip.smallest_msb_data_reg)
            || (sort_ip.lsb_data < sort_ip.smallest_lsb_data_reg))
        && sort_ip.is_sorting == 1'b1);

    see_swap_sort_state_desc: cover property(
        sort_dir == 1'b0
        && ((sort_ip.msb_data > sort_ip.smallest_msb_data_reg)
            || (sort_ip.lsb_data > sort_ip.smallest_lsb_data_reg))
        && sort_ip.is_sorting == 1'b1);

    see_end_output_desc: cover property(sort_dir == 1'b0 && aout_tlast);

    cover_output_sequence_desc: cover property(
        sort_dir == 1'b0
        && sort_ip.state_sort_reg == SWAP_SORT ##[0:$] aout_tlast);

    see_count_dups_state: cover property(
        sort_ip.state_sort_reg == COUNT_DUPS);

    see_count_done_with_dups: cover property(
        $rose(sort_ip.array_sorted_reg) && dup_nums > '0);

    
    sort_dir_stable: restrict property($stable(sort_dir));

    generate_12_data:     restrict property((sort_ip.addr_in_reg < 4'd4) |-> !ain_tlast);
    generate_last_signal: restrict property((sort_ip.addr_in_reg == 4'd4) |-> ain_tlast);
    inlast_only_once:     restrict property(last_reg |-> !ain_tlast);
    invalid_only_once:    restrict property(last_reg |-> !ain_tvalid);

    diff_input_data: restrict property(!last_reg |->
        ( sort_dir
          ? ( ain_tdata[my_pkg::DATA_WIDTH/2-1:0]
                < ain_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2]
              & ain_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2]
                < last_datain_reg[my_pkg::DATA_WIDTH/2-1:0] )
          : ( ain_tdata[my_pkg::DATA_WIDTH/2-1:0]
                > ain_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2]
              & ain_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2]
                > last_datain_reg[my_pkg::DATA_WIDTH/2-1:0] )
        ));

    same_input_data: restrict property(last_reg |-> ain_tdata == 'b0);
    aout_tready0:    restrict property(last_reg  |-> aout_tready == 'b1);
    aout_tready1:    restrict property(!last_reg |-> aout_tready == 'b0);

    
    END_TO_END_check: assert property (
        aout_tvalid && aout_tready && sort_ip.array_sorted_reg |->
        ( sort_dir
          ? ( (!first_out_seen || prev_data_out <= aout_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2])
              && aout_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2]
                 <= aout_tdata[my_pkg::DATA_WIDTH/2-1:0] )
          : ( (!first_out_seen || prev_data_out >= aout_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2])
              && aout_tdata[my_pkg::DATA_WIDTH-1:my_pkg::DATA_WIDTH/2]
                 >= aout_tdata[my_pkg::DATA_WIDTH/2-1:0] )
        ));

    no_2_we_mem_asserted: assert property(
        !(sort_ip.we_sort == 1'b1
          && (sort_ip.ain_tready_s & ain_tvalid == 1'b1)));

    is_ready_for_next_transaction: assert property(
        aout_tlast |-> ##[1:4](
            sort_ip.addr_in_reg              == 'b0
            && sort_ip.array_sorted_reg      == 'b0
            && sort_ip.last_el_arrived_reg   == 'b0
            && sort_ip.num_of_arrived_el_reg == 'b0));

   
    // kada je sortiranje gotovo, dup_nums mora ostati stabilan do sledeceg reseta
    dup_nums_correct: assert property(sort_ip.array_sorted_reg == 1'b1 |-> $stable(dup_nums));

    // nakon sto master poslje sve podatke, dup_nums se resetuje na 0
    dup_nums_reset_after_transaction: assert property($fell(sort_ip.array_sorted_reg) |-> (dup_nums == 'b0));

    // dup_nums ne moze biti veci od broja pristiglih elemenata
    dup_nums_no_overflow: assert property(dup_nums <= sort_ip.num_of_arrived_el_reg);

endchecker
