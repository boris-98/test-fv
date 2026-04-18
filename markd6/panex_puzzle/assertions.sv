// =============================================================================
// Panex Puzzle — SVA Assertions, Assumptions, and Cover Properties
// =============================================================================
//
// Ovaj modul se binduje na panex RTL model i sadrzi:
//   - ASSUME osobine za ogranicenje inputa
//   - ASSERT osobine za invarijante sistema
//   - COVER osobine za ciljno i pocetno stanje
//
// Sve osobine su parametrizovane za proizvoljno S.
// =============================================================================

module panex_assertions #(parameter S = 4) (
    input logic                        clk,
    input logic                        rst,
    input logic [1:0]                  fr,
    input logic [1:0]                  to,
    input logic [$clog2(2*S+1)-1:0]   poles [0:2][0:S]
);

    localparam W = $clog2(2*S + 1);

    default clocking cb @(posedge clk); endclocking
    default disable iff (rst);

    // =========================================================================
    //  POMOCNI SIGNALI (kombinaciona logika)
    // =========================================================================

    // --- Provera da li je stap prazan (svi nivoi == 0) ---
    logic pole0_empty, pole1_empty, pole2_empty;
    always_comb begin
        pole0_empty = 1'b1;
        pole1_empty = 1'b1;
        pole2_empty = 1'b1;
        for (int l = 0; l <= S; l++) begin
            if (poles[0][l] != '0) pole0_empty = 1'b0;
            if (poles[1][l] != '0) pole1_empty = 1'b0;
            if (poles[2][l] != '0) pole2_empty = 1'b0;
        end
    end

    // --- Provera da li je stap pun (bafer slot [S] zauzet) ---
    logic pole0_full, pole1_full, pole2_full;
    assign pole0_full = (poles[0][S] != '0);
    assign pole1_full = (poles[1][S] != '0);
    assign pole2_full = (poles[2][S] != '0);

    // --- Ukupan broj diskova u sistemu ---
    int total_disks;
    always_comb begin
        total_disks = 0;
        for (int p = 0; p < 3; p++)
            for (int l = 0; l <= S; l++)
                if (poles[p][l] != '0)
                    total_disks = total_disks + 1;
    end

    // --- Jedinstvenost diskova: nijedna dva polozaja nemaju istu ne-nultu vrednost ---
    logic no_duplicate;
    always_comb begin
        no_duplicate = 1'b1;
        for (int p1 = 0; p1 < 3; p1++)
            for (int l1 = 0; l1 <= S; l1++)
                if (poles[p1][l1] != '0)
                    for (int p2 = 0; p2 < 3; p2++)
                        for (int l2 = 0; l2 <= S; l2++)
                            if ((p2 > p1 || (p2 == p1 && l2 > l1)) &&
                                poles[p1][l1] == poles[p2][l2])
                                no_duplicate = 1'b0;
    end

    // --- Sve vrednosti diskova su u validnom opsegu [1, 2*S] ---
    logic values_in_range;
    always_comb begin
        values_in_range = 1'b1;
        for (int p = 0; p < 3; p++)
            for (int l = 0; l <= S; l++)
                if (poles[p][l] != '0)
                    if (int'(poles[p][l]) < 1 || int'(poles[p][l]) > 2*S)
                        values_in_range = 1'b0;
    end

    // --- Minimalna visina: disk velicine k ne sme biti ispod nivoa k-1 ---
    // BLUE   (val 1..S):    min_h = val - 1
    // ORANGE (val S+1..2S): min_h = val - S - 1 = get_size(val) - 1
    logic min_height_ok;
    always_comb begin
        min_height_ok = 1'b1;
        for (int p = 0; p < 3; p++)
            for (int l = 0; l <= S; l++)
                if (poles[p][l] != '0) begin
                    if (int'(poles[p][l]) <= S) begin
                        // BLUE disk: val in [1,S], min_h = val - 1, need l >= val - 1
                        if (l < int'(poles[p][l]) - 1)
                            min_height_ok = 1'b0;
                    end else begin
                        // ORANGE disk: val in [S+1,2S], min_h = val - S - 1, need l >= val - S - 1
                        if (l < int'(poles[p][l]) - S - 1)
                            min_height_ok = 1'b0;
                    end
                end
    end

    // --- Ciljno stanje: kule su zamenjene ---
    // LEFT = ORANGE kula (S+1, S+2, ..., 2*S), MID = prazan, RIGHT = BLUE kula (1, 2, ..., S)
    logic solved;
    always_comb begin
        solved = 1'b1;
        for (int i = 0; i < S; i++) begin
            if (int'(poles[0][i]) != i + S + 1) solved = 1'b0;  // LEFT = ORANGE
            if (int'(poles[2][i]) != i + 1)     solved = 1'b0;  // RIGHT = BLUE
        end
        if (poles[0][S] != '0) solved = 1'b0;  // LEFT bafer prazan
        if (poles[2][S] != '0) solved = 1'b0;  // RIGHT bafer prazan
        for (int i = 0; i <= S; i++)
            if (poles[1][i] != '0) solved = 1'b0;  // MID kompletno prazan
    end

    // --- Pocetno stanje (verifikacija ispravnog reseta) ---
    logic init_ok;
    always_comb begin
        init_ok = 1'b1;
        for (int i = 0; i < S; i++) begin
            if (int'(poles[0][i]) != i + 1)     init_ok = 1'b0;  // LEFT = BLUE
            if (int'(poles[2][i]) != i + S + 1) init_ok = 1'b0;  // RIGHT = ORANGE
            if (poles[1][i] != '0)              init_ok = 1'b0;  // MID prazan
        end
        if (poles[0][S] != '0 || poles[1][S] != '0 || poles[2][S] != '0)
            init_ok = 1'b0;
    end

    // =========================================================================
    //  ASSUME properties (ogranicenja na inpute)
    // =========================================================================

    // Validni indeksi stapova (samo 0, 1, 2)
    asm_valid_poles: assume property (fr <= 2 && to <= 2);

    // Razliciti stapovi (fr != to)
    asm_diff_poles: assume property (fr != to);

    // Susedni stapovi — fundamentalno Panex pravilo: |fr - to| == 1
    // LEFT <-> MID (0<->1) i MID <-> RIGHT (1<->2), ali NE LEFT <-> RIGHT
    asm_adjacent: assume property (
        (fr > to ? fr - to : to - fr) == 1
    );

    // Ne uzimaj sa praznog stapa
    asm_not_empty_0: assume property (fr == 0 |-> !pole0_empty);
    asm_not_empty_1: assume property (fr == 1 |-> !pole1_empty);
    asm_not_empty_2: assume property (fr == 2 |-> !pole2_empty);

    // Ne stavljaj na pun stap (bafer slot zauzet)
    asm_not_full_0: assume property (to == 0 |-> !pole0_full);
    asm_not_full_1: assume property (to == 1 |-> !pole1_full);
    asm_not_full_2: assume property (to == 2 |-> !pole2_full);

    // Anti-oscilacija: ne ponavljaj odmah obrnuti potez
    // Sprecava beskonacno fr->to, to->fr oscilovanje formal solvera
    asm_no_repeat: assume property (!(fr == $past(to) && to == $past(fr)));

    // =========================================================================
    //  ASSERT properties (invarijante sistema)
    // =========================================================================

    // Minimalna visina: nijedan disk nije ispod svog kucnog nivoa
    ast_min_height: assert property (min_height_ok);

    // Ukupan broj diskova je uvek 2*S
    ast_total_disks: assert property (total_disks == 2 * S);

    // Jedinstvenost: nijedna dva polozaja nemaju isti disk
    ast_no_duplicate: assert property (no_duplicate);

    // Validnost vrednosti: svi diskovi su u opsegu [1, 2*S]
    ast_values_in_range: assert property (values_in_range);

    // =========================================================================
    //  COVER properties
    // =========================================================================

    // Ciljno stanje: kule su zamenjene (resenje puzzle)
    cov_solved: cover property (solved);

    // Pocetno stanje: verifikacija ispravnog reseta
    cov_init: cover property (init_ok);

endmodule
