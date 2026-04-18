clear -all
analyze -sv09 sort_ip.sv
analyze -sv09 assertions.sv
analyze -sv09 bind.sv
elaborate -top sort_ip
clock clk
reset ~rst_n
set_prove_time_limit 300s
prove -bg -all
