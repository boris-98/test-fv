module panex #(parameter S = 4)
(
    input        clk,
    input        rst,
    input  [1:0] fr,
    input  [1:0] to
);

    // 3 štapa: 0,1,2
    // disk 0 je najmanji, disk S-1 je najveći
    logic [1:0] pos [0:S-1];   // na kom štapu je koji disk

    integer i;

    // top disk na svakom štapu (indeks najmanjeg diska na tom štapu), -1 ako je prazan
    integer top0, top1, top2;
    integer top_fr, top_to;

    logic [1:0] top_fr_idx;

    logic can_move;
    logic goal;

    // top diskovi
    always @* begin
        top0 = -1;
        top1 = -1;
        top2 = -1;

        // od najmanjeg ka vecem - prvi pronađeni je top
        for (i = 0; i < S; i = i + 1) begin
            if ((pos[i] == 2'd0) && (top0 == -1)) top0 = i;
            if ((pos[i] == 2'd1) && (top1 == -1)) top1 = i;
            if ((pos[i] == 2'd2) && (top2 == -1)) top2 = i;
        end
    end

    // top_fr i top_to na osnovu fr/to
    always @* begin
        top_fr = -1;
        top_to = -1;

        case (fr)
            2'd0: top_fr = top0;
            2'd1: top_fr = top1;
            2'd2: top_fr = top2;
            default: top_fr = -1;
        endcase

        case (to)
            2'd0: top_to = top0;
            2'd1: top_to = top1;
            2'd2: top_to = top2;
            default: top_to = -1;
        endcase

        // indeks 
        top_fr_idx = 2'd0;
        if (top_fr >= 0 && top_fr < S)
            top_fr_idx = top_fr[1:0];
    end

    // legalnost poteza
    always @* begin
        can_move = 1'b0;

        // validnost fr/to i različiti štapovi
        if ((fr < 2'd3) && (to < 2'd3) && (fr != to)) begin
            // fr mora imati disk
            if (top_fr != -1) begin
                // to je prazan ili top_fr manji od top_to - manji disk na veći
                if ((top_to == -1) || (top_fr < top_to))
                    can_move = 1'b1;
            end
        end
    end

    // cilj: svi diskovi na štapu 2
    always @* begin
        goal = 1'b1;
        for (i = 0; i < S; i = i + 1) begin
            if (pos[i] != 2'd2)
                goal = 1'b0;
        end
    end

    // stanje
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < S; i = i + 1)
                pos[i] <= 2'd0;     // sve diskove na štap 0
        end else begin
            if (can_move) begin
                if (top_fr >= 0 && top_fr < S)
                    pos[top_fr_idx] <= to;  // prebaci top disk sa fr na to
            end
        end
    end

endmodule

