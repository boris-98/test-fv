analyze -sv09 sort_pkg.sv mem.sv sort_ip.sv  sort_checker.sv bind.sv 
elaborate -disable_auto_bbox -top {sort_ip}
clock clk -factor 1 -phase 1
reset -expression {rst}
prove -bg -all

