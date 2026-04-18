module panex
    #(parameter S = 4)
    (
     input clk,
     input rst,
     input [1:0] fr,
     input [1:0] to
    );

    // a[i], b[i] - prisutnost diskova 
    reg [S-1:0] a[3];
    reg [S-1:0] b[3];
    logic [S-1:0] mask_from;
    logic [S-1:0] mask_to;

    // ukupno dostupni diskovi na svim stapovima, svih boja (1 nam bude na svim pozicijama koje su zauzete)
    //na svim pozicijama na kojima je 1 ne smem da prebacim disk
    logic [S-1:0] available_from, available_to;
    assign available_from = a[fr] | b[fr];
    assign available_to = a[to] | b[to];

    always_comb begin
        mask_from = 4'b0000; 

        //trazimo najmanji disk na vrhu stapa 
        if (available_from[0] == 1'b1) begin
            mask_from = 4'b0001; 
        end 
        else if (available_from[1] == 1'b1) begin
            mask_from = 4'b0010; //nema 1, udje ovde
        end 
        else if (available_from[2] == 1'b1) begin
            mask_from = 4'b0100; // nema ni 1 ni 2 udje ovde
        end 
        else if (available_from[3] == 1'b1) begin
            mask_from = 4'b1000; // nema 1, 2 ni 4 udje ovde
        end
    end

    always_comb begin
        mask_to = 4'b0000; 

        //trazimo najmanji disk na vrhu stapa
        if (available_to[0] == 1'b1) begin
            mask_to = 4'b0001; 
        end 
        else if (available_to[1] == 1'b1) begin
            mask_to = 4'b0010; //nema 1, udje ovde
        end 
        else if (available_to[2] == 1'b1) begin
            mask_to = 4'b0100; // nema ni 1 ni 2 udje ovde
        end 
        else if (available_to[3] == 1'b1) begin
            mask_to = 4'b1000; // nema 1, 2 ni 4 udje ovde
        end
    end

    logic disk_to_move; //bude setovan samo onaj bit koji je iz mask_from
    assign disk_to_move = (a[fr] & mask_from) != '0;

    logic invalid_move;
    always_comb begin
       invalid_move = 1'b0;
       if(available_from == '0)
	 invalid_move = 1'b1;  //ne moze da se uzme sa praznog stapa
       if(available_to != '0 && mask_from > mask_to)  //ako stap na koji prebacujemo ima neki disk na sebi, mora biti from > to da bi moglo da se izvrsi ok prebacivanje
         invalid_move = 1'b1;
    end

    always_ff @(posedge clk)
    begin
	if(rst) begin
            a[0] <= {S{1'b1}};
            a[1] <= '0;   
            a[2] <= '0;

            b[0] <= '0;
            b[1] <= '0;
            b[2] <= {S{1'b1}};  
        end else if(!invalid_move) begin
            if(disk_to_move) begin
        	a[fr] <= a[fr] & ~mask_from; //reset bita diska koji se pomera
                a[to] <= a[to] | mask_from; //set bita koji dolazi sa from 
            end else begin
                b[fr] <= b[fr] & ~mask_from;
                b[to] <= b[to] | mask_from;
            end
        end
    end

endmodule

