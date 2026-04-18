// =============================================================================
// Panex Puzzle — SystemVerilog RTL Model (Floating Model)
// =============================================================================
//
// Implementacija prema unapredjenoj specifikaciji (improved_spec.md):
//   - Dve boje diskova: BLUE (1..S), ORANGE (S+1..2*S)
//   - Floating (lebdeci) model pozicioniranja
//   - Kapacitet S+1 po stapu (S pozicija + 1 bafer slot)
//   - Rollback mehanizam za nelegalne poteze
//   - Unified 2D niz poles[0:2][0:S]
//
// Interfejs: panex #(S)(clk, rst, fr, to)
//   - S:   broj diskova po boji (podrazumevano 4)
//   - fr:  izvorni stap (0=LEFT, 1=MID, 2=RIGHT)
//   - to:  odredisni stap (0=LEFT, 1=MID, 2=RIGHT)
//
// Ovaj fajl sadrzi ISKLJUCIVO RTL model — bez assertions/cover.
// =============================================================================

module panex #(parameter S = 4) (
    input  logic        clk,
    input  logic        rst,
    input  logic [1:0]  fr,
    input  logic [1:0]  to
);

    // Sirina elementa: dovoljno bita za vrednosti 0..2*S
    localparam W = $clog2(2*S + 1);

    // =========================================================================
    // Glavna struktura podataka
    // poles[p][l] = enkodirana vrednost diska na stapu p, nivou l
    //   p: 0=LEFT, 1=MID, 2=RIGHT
    //   l: 0=dno, S-1=vrh, S=bafer slot
    //   Vrednost 0 = prazno, 1..S = BLUE, S+1..2*S = ORANGE
    // =========================================================================
    logic [W-1:0] poles [0:2][0:S];

    // =========================================================================
    // Interne pomocne promenljive (blocking assignments u okviru always_ff)
    // =========================================================================
    logic [W-1:0] disk_val;     // vrednost diska koji se pomera
    logic         found_src;    // flag: pronadjen izvorni disk
    int           src_idx;      // nivo izvornog diska
    int           dst_idx;      // nivo odredista
    int           min_h;        // minimalna dozvoljena visina za disk
    int           top_dest;     // nivo najviseg diska na odredisnom stapu

    // =========================================================================
    // Sekvencijalna logika
    // =========================================================================
    always_ff @(posedge clk) begin

        if (rst) begin
            // =================================================================
            // RESET: Inicijalizacija pocetnog stanja
            //   LEFT:  BLUE kula  (1, 2, ..., S) na nivoima 0..S-1
            //   MID:   prazan
            //   RIGHT: ORANGE kula (S+1, S+2, ..., 2*S) na nivoima 0..S-1
            //   Bafer slotovi [S] = 0 na svim stapovima
            // =================================================================
            for (int k = 0; k <= S; k++) begin
                if (k < S) begin
                    poles[0][k] <= k + 1;           // LEFT:  BLUE-1..BLUE-S
                    poles[1][k] <= '0;              // MID:   prazno
                    poles[2][k] <= k + S + 1;       // RIGHT: ORANGE-1..ORANGE-S
                end else begin
                    poles[0][k] <= '0;              // Bafer slotovi prazni
                    poles[1][k] <= '0;
                    poles[2][k] <= '0;
                end
            end

        end
        else if (fr != to && fr <= 2 && to <= 2) begin
            // =================================================================
            // POTEZ: Pokusaj pomeranja gornjeg diska sa fr na to
            // =================================================================

            // --- Korak 1: Pronadji gornji disk na izvoru (skeniranje odozgo) ---
            disk_val  = '0;
            found_src = 1'b0;
            src_idx   = -1;

            for (int i = S; i >= 0; i--) begin
                if (!found_src && poles[fr][i] != '0) begin
                    disk_val  = poles[fr][i];
                    src_idx   = i;
                    found_src = 1'b1;
                end
            end

            if (found_src) begin
                // --- Korak 2: Izracunaj minimalnu dozvoljenu visinu ---
                // BLUE disk  (val 1..S):     min_h = val - 1
                // ORANGE disk (val S+1..2S): min_h = val - S - 1
                if (int'(disk_val) <= S)
                    min_h = int'(disk_val) - 1;
                else
                    min_h = int'(disk_val) - S - 1;

                // --- Korak 3: Pronadji nivo odredista ---
                // Skeniranje odozgo: prva ne-nula pozicija = vrh steka
                top_dest = -1;
                for (int j = S; j >= 0; j--) begin
                    if (top_dest == -1 && poles[to][j] != '0)
                        top_dest = j;
                end

                // Ako je stap prazan: disk lebdi na svom min nivou
                // Ako nije prazan: disk ide direktno iznad vrha
                if (top_dest == -1)
                    dst_idx = min_h;
                else
                    dst_idx = top_dest + 1;

                // --- Korak 4: Postavi disk ako je potez validan ---
                // Potez je validan samo ako:
                //   - dst_idx je u opsegu [0, S]
                //   - dst_idx >= min_h (Panex pravilo lebdenja)
                if (dst_idx >= 0 && dst_idx <= S && dst_idx >= min_h) begin
                    poles[to][dst_idx] <= disk_val;
                    poles[fr][src_idx] <= '0;
                end

            end // if (found_src)

        end // else if (fr != to ...)

    end // always_ff

endmodule
