clear -all

analyze -sv sort_ip.sv
analyze -sv sort_ip_model.sv
analyze -sv sort_ip_checker_top.sv

elaborate -top top -parameter N_NUM 4

clock clk
reset rst

prove -all

