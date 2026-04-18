clear -all
analyze -vhdl memory.vhd
analyze -vhdl control_path.vhd
analyze -vhdl compare_swap.vhd
analyze -vhdl sorter_top.vhd
analyze -sv09 memory_checker.sv
analyze -sv09 fsm_checker.sv
analyze -sv09 compare_swap_checker.sv
analyze -sv09 sorter_top_checker.sv
analyze -sv09 bind.sv
elaborate -vhdl -top sorter_top 
clock clk
reset rst
prove -bg -all
