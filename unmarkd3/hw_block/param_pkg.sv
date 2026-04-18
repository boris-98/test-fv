package param_pkg;

  `ifdef ADDR_WIDTH
    parameter int ADDR_WIDTH = `ADDR_WIDTH;
  `else
    parameter int ADDR_WIDTH = 64;
  `endif

  `ifdef DATA_WIDTH
    parameter int DATA_WIDTH = `DATA_WIDTH;
  `else
    parameter int DATA_WIDTH = 1024;
  `endif

endpackage
