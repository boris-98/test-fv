module panex
    #(parameter S = 4)
    (
     input clk,
     input rst,
     input [1:0] fr,
     input [1:0] to
    );

    // A i B su nazivi grupa diskova (boja), a0 predstavlja prisutnost diskova tipa A na stapu 0 ...
    reg [S-1:0] a0, a1, a2; 
    reg [S-1:0] b0, b1, b2;  

    logic [S-1:0] available_sizes_fr, available_sizes_to;

    always_comb begin
        case(fr)
            0: available_sizes_fr = a0 | b0;
            1: available_sizes_fr = a1 | b1;
            2: available_sizes_fr = a2 | b2;
            default: available_sizes_fr = '0;
        endcase
    end

    always_comb begin
        case(to)
            0: available_sizes_to = a0 | b0;
            1: available_sizes_to = a1 | b1;
            2: available_sizes_to = a2 | b2;
            default: available_sizes_to = '0;
        endcase
    end

    logic [S-1:0] top_mask_fr;
    logic [S-1:0] top_mask_to;
    // najmanji disk koji je na vrhu source/destination stapa
    assign top_mask_fr = available_sizes_fr & (-available_sizes_fr);
    assign top_mask_to = available_sizes_to & (-available_sizes_to);

    // odlucivanje koji disk pomeriti, ako je prisutan samo disk tipa A ili A i B, onda pomeramo A
    // suprotno ako je tipa B, pomeramo njega
    // disc_to_move = 1 - tip A, 0 - tip B
    logic disc_to_move;

    always_comb begin
        case(fr)
            0: disc_to_move = (a0 & top_mask_fr) != 0;
            1: disc_to_move = (a1 & top_mask_fr) != 0;
            2: disc_to_move = (a2 & top_mask_fr) != 0;
            default: disc_to_move = 0;
        endcase
    end

    // neispravni potezi - sredjivanje pravila radi jednostavnosti pre ubacivanja u assume i uslovi za zavrsetak
    logic illegal;
    logic game_end;

    always_comb begin
        illegal = 1'b0;
        game_end = 1'b0;

        if(fr > 2 || to > 2)
            illegal = 1'b1;

        if(fr == to)
            illegal = 1'b1;

        // ne moze direktno sa levog na krajnji desni i obrnuto
        if(fr == 0 && to == 2) 
            illegal = 1'b1;
        if(fr == 2 && to == 0) 
            illegal = 1'b1;

        if(available_sizes_fr == 0)
            illegal = 1'b1;

        // provera prebacivanja veceg diska na manji
        if(available_sizes_to != 0 && top_mask_fr > top_mask_to)
            illegal = 1'b1;

        // svi diskovi iz grupe A su na stapu 2, svi grupe B na stapu 0
        if(a2 == {S{1'b1}} && b0 == {S{1'b1}} && a0 == '0 && b2 == '0)
            game_end = 1'b1;
    end

    always_ff @(posedge clk)
	begin
	    if(rst)begin
            a0 <= {S{1'b1}};   // svi A diskovi na stubu 0
            a1 <= '0;
            a2 <= '0;
            b0 <= '0;
            b1 <= '0;
            b2 <= {S{1'b1}};   // svi B diskovi na stubu 2
		end
	    else if(!illegal)
		begin

            // brisanje diska koji pomeramo sa stuba gde se nalazi
            if(disc_to_move) begin
                case(fr)
                0: a0 <= a0 & ~top_mask_fr;
                1: a1 <= a1 & ~top_mask_fr;
                2: a2 <= a2 & ~top_mask_fr;
                endcase
            end else begin
                case(fr)
                0: b0 <= b0 & ~top_mask_fr;
                1: b1 <= b1 & ~top_mask_fr;
                2: b2 <= b2 & ~top_mask_fr;
                endcase
            end

            // setovanje pomerenom diska u masci stapa gde se prebacuje
            if(disc_to_move) begin
                case(to)
                0: a0 <= a0 | top_mask_fr;
                1: a1 <= a1 | top_mask_fr;
                2: a2 <= a2 | top_mask_fr;
                endcase
            end else begin
                case(to)
                0: b0 <= b0 | top_mask_fr;
                1: b1 <= b1 | top_mask_fr;
                2: b2 <= b2 | top_mask_fr;
                endcase
            end

	end
    end

default clocking
	@(posedge clk);
endclocking

assume property(illegal == 1'b0);
cover property(game_end == 1'b1);

endmodule
