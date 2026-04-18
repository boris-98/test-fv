module bram #(
  parameter DATA_WIDTH = 32,
  parameter DEPTH = 8,
  parameter ADDR_WIDTH = 3
)(
  input  logic clk,
  input  logic rst,
  input  logic we,
  input  logic [ADDR_WIDTH-1:0] addr_read,
  input  logic [ADDR_WIDTH-1:0] addr_write,
  input  logic [DATA_WIDTH-1:0] data_in,
  output logic [DATA_WIDTH-1:0] data_out
);

  logic [DATA_WIDTH-1:0] mem[0:DEPTH-1];

  integer i;
  always_ff @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < DEPTH; i++) mem[i] <= '0;
    end else if (we) begin
      mem[addr_write] <= data_in;
    end
  end

  always_comb begin
    data_out = mem[addr_read];
  end

endmodule

