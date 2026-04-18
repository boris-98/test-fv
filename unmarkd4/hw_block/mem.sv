module mem #(
    parameter DATA_WIDTH  = 32,
    parameter DEPTH       = 1024,
    parameter ADDR_WIDTH  = 10
)(
    input  clk,
    input  rst,
    input  [ADDR_WIDTH-1:0]  address_read,
    input  [ADDR_WIDTH-1:0]  address_write,
    input  [DATA_WIDTH-1:0]  data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    input  we
);

    logic [DEPTH-1:0][DATA_WIDTH-1:0] mem;

    always @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < DEPTH; i++)
                mem[i] <= '0;
            //data_out <= '0;       
        end
        else begin
            data_out <= mem[address_read];    
            if (we == 1'b1)
                mem[address_write] <= data_in; 
        end
    end

endmodule
