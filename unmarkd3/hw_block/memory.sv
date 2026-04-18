module memory #(
  parameter DATA_WIDTH,
  parameter ADDR_WIDTH
)(
  input  logic clk,
  input  logic rst,
  input  logic we_a,
  input  logic we_b,
  input  logic [ADDR_WIDTH-1:0] addr_read_a,
  input  logic [ADDR_WIDTH-1:0] addr_read_b,
  input  logic [ADDR_WIDTH-1:0] addr_write_a,
  input  logic [ADDR_WIDTH-1:0] addr_write_b,
  input  logic [DATA_WIDTH-1:0] data_in_a,
  input  logic [DATA_WIDTH-1:0] data_in_b,
  output logic [DATA_WIDTH-1:0] data_out_a,
  output logic [DATA_WIDTH-1:0] data_out_b
);

  logic [DATA_WIDTH-1:0] memory[0:2**ADDR_WIDTH-1];

  integer i;
  always_ff @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < 2**ADDR_WIDTH; i++) 
        memory[i] <= '0;
    end else begin
      if (we_a) 
        memory[addr_write_a] <= data_in_a;

      if (we_b)
        memory[addr_write_b] <= data_in_b;
    end
  end

  always_comb begin
    data_out_a = memory[addr_read_a];
    data_out_b = memory[addr_read_b];
  end

endmodule
