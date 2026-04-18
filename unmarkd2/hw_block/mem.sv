module mem #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 1024,
    parameter ADDR_WIDTH = 10
) (
    input  logic                        clk,
    input  logic                        rst,

    input  logic [ADDR_WIDTH-1:0]       address_read,
    input  logic [ADDR_WIDTH-1:0]       address_write,
    input  logic [DATA_WIDTH-1:0]       data_in,
    output logic [DATA_WIDTH-1:0]       data_out,
    input  logic                        we
);

    logic [DEPTH-1:0][DATA_WIDTH-1:0] mem;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < DEPTH; i++)
                mem[i] <= '0;
        end
        else begin
            data_out <= mem[address_read];
            if (we)
                mem[address_write] <= data_in;
        end
    end

endmodule

