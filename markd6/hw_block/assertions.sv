// =============================================================================
// Sort IP — SVA Assertions, Assumptions i Cover Properties
// =============================================================================
//
// Formalno verifikaciono okruzenje za sort_ip blok.
//
// Struktura:
//   1. Pomocni signali   (shadow kopija ulaza, provere sortiranosti, permutacije)
//   2. ASSUME properties (ogranicenja na ulaze za formalni solver)
//   3. ASSERT properties (invarijante i funkcionalna korektnost)
//   4. COVER properties  (dostiznost zeljenih stanja)
//
// Kljucne verifikacione tacke:
//   - Sortiranost:  izlazni niz je sortiran u zadatom smeru
//   - Permutacija:  izlaz sadrzi iste elemente kao ulaz (sum + XOR provera)
//   - Duplikati:    dup_nums tacno odrazava broj duplikata
//   - AXI protokol: tvalid/tready/tlast ponasanje
//   - Stabilnost:   podaci se ne menjaju dok cekamo na tready
// =============================================================================

module sort_ip_assertions #(
    parameter N  = 8,
    parameter DW = 16
) (
    input logic                         clk,
    input logic                         rst_n,

    // AXI Stream ulaz
    input logic                         ain_tvalid,
    input logic                         ain_tready,
    input logic [2*DW-1:0]              ain_tdata,
    input logic                         ain_tlast,

    // AXI Stream izlaz
    input logic                         aout_tvalid,
    input logic                         aout_tready,
    input logic [2*DW-1:0]              aout_tdata,
    input logic                         aout_tlast,

    // Kontrola i status
    input logic                         sort_dir,
    input logic [$clog2(N):0]           dup_nums,

    // Interni signali iz DUT-a
    input logic [2:0]                   state,
    input logic [DW-1:0]                mem [0:N-1],
    input logic [$clog2(N/2)-1:0]       load_cnt,
    input logic [$clog2(N/2)-1:0]       out_cnt,
    input logic [$clog2(N)-1:0]         sort_pass,
    input logic                         sort_dir_r
);

    // =========================================================================
    // Lokalni parametri (moraju odgovarati DUT-u)
    // =========================================================================
    localparam HALF     = N / 2;
    localparam PAIR_W   = $clog2(HALF);
    localparam PASS_W   = $clog2(N);
    localparam PAIR_MAX = HALF - 1;
    localparam PASS_MAX = N - 1;
    localparam SUM_W    = DW + $clog2(N) + 1;   // Sirina za sumu svih elemenata

    // Konstante stanja (odgovaraju DUT-ovom enum-u)
    localparam [2:0] S_IDLE   = 3'd0;
    localparam [2:0] S_LOAD   = 3'd1;
    localparam [2:0] S_SORT   = 3'd2;
    localparam [2:0] S_CALC   = 3'd3;
    localparam [2:0] S_OUTPUT = 3'd4;

    // =========================================================================
    // Default clocking i disable
    // =========================================================================
    default clocking cb @(posedge clk); endclocking
    default disable iff (!rst_n);

    // =========================================================================
    // POMOCNI SIGNALI: Shadow niz za proveru permutacije
    // =========================================================================
    // Kopiramo ulazne podatke u shadow niz tokom IDLE i LOAD faze.
    // U OUTPUT fazi poredimo shadow sa mem za proveru permutacije.
    // =========================================================================
    logic [DW-1:0] input_shadow [0:N-1];
    wire ain_handshake = ain_tvalid && ain_tready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < N; i++)
                input_shadow[i] <= '0;
        end else begin
            if (state == S_IDLE && ain_handshake) begin
                input_shadow[0] <= ain_tdata[DW-1:0];
                input_shadow[1] <= ain_tdata[2*DW-1:DW];
            end else if (state == S_LOAD && ain_handshake) begin
                input_shadow[{load_cnt, 1'b0}] <= ain_tdata[DW-1:0];
                input_shadow[{load_cnt, 1'b1}] <= ain_tdata[2*DW-1:DW];
            end
        end
    end

    // =========================================================================
    // POMOCNI SIGNALI: Provera permutacije (suma i XOR)
    // =========================================================================
    // Ako je izlaz permutacija ulaza, tada:
    //   sum(ulaz) == sum(izlaz)  i  xor(ulaz) == xor(izlaz)
    // Ove dve provere zajedno daju visok stepen pouzdanosti.
    // =========================================================================
    logic [SUM_W-1:0] shadow_sum, mem_sum;
    logic [DW-1:0]    shadow_xor, mem_xor;

    always_comb begin
        shadow_sum = '0;
        mem_sum    = '0;
        shadow_xor = '0;
        mem_xor    = '0;
        for (int i = 0; i < N; i++) begin
            shadow_sum = shadow_sum + SUM_W'(input_shadow[i]);
            mem_sum    = mem_sum    + SUM_W'(mem[i]);
            shadow_xor = shadow_xor ^ input_shadow[i];
            mem_xor    = mem_xor    ^ mem[i];
        end
    end

    // =========================================================================
    // POMOCNI SIGNALI: Provera sortiranosti
    // =========================================================================
    logic is_sorted;

    always_comb begin
        is_sorted = 1'b1;
        for (int i = 0; i < N-1; i++) begin
            if (sort_dir_r) begin
                // Rastuci: mem[i] <= mem[i+1]
                if (mem[i] > mem[i+1]) is_sorted = 1'b0;
            end else begin
                // Opadajuci: mem[i] >= mem[i+1]
                if (mem[i] < mem[i+1]) is_sorted = 1'b0;
            end
        end
    end

    // =========================================================================
    // POMOCNI SIGNALI: Ocekivani broj duplikata
    // =========================================================================
    logic [$clog2(N):0] expected_dups;

    always_comb begin
        expected_dups = '0;
        for (int i = 1; i < N; i++) begin
            if (mem[i] == mem[i-1])
                expected_dups = expected_dups + 1;
        end
    end

    // =========================================================================
    //  ASSUME properties (ogranicenja na ulaze)
    // =========================================================================

    // U LOAD stanju, ain_tvalid mora biti aktivan (kontinuirano ucitavanje)
    asm_load_continuous: assume property (
        (state == S_LOAD) |-> ain_tvalid
    );

    // ain_tlast ne sme biti aktivan u IDLE (potrebna su bar 2 para za N >= 4)
    asm_no_tlast_idle: assume property (
        (state == S_IDLE) |-> !ain_tlast
    );

    // ain_tlast se aktivira tacno na poslednjem paru u LOAD fazi
    asm_tlast_at_end: assume property (
        (state == S_LOAD && ain_tvalid) |->
            (ain_tlast == (load_cnt == PAIR_W'(PAIR_MAX)))
    );

    // Tokom IDLE, ain_tvalid mora da se aktivira (liveness)
    asm_eventual_valid: assume property (
        (state == S_IDLE) |-> ##[0:10] ain_tvalid
    );

    // =========================================================================
    //  ASSERT properties — funkcionalna korektnost
    // =========================================================================

    // Sortiranost: u OUTPUT stanju, memorija mora biti sortirana
    ast_sorted: assert property (
        (state == S_OUTPUT) |-> is_sorted
    );

    // Permutacija (suma): suma ulaza == suma izlaza
    ast_perm_sum: assert property (
        (state == S_OUTPUT) |-> (shadow_sum == mem_sum)
    );

    // Permutacija (XOR): XOR ulaza == XOR izlaza
    ast_perm_xor: assert property (
        (state == S_OUTPUT) |-> (shadow_xor == mem_xor)
    );

    // Broj duplikata: dup_nums odgovara stvarnom broju
    ast_dup_count: assert property (
        (state == S_OUTPUT) |-> (dup_nums == expected_dups)
    );

    // =========================================================================
    //  ASSERT properties — AXI Stream protokol
    // =========================================================================

    // aout_tvalid je aktivan samo u OUTPUT stanju
    ast_aout_valid_only_output: assert property (
        aout_tvalid |-> (state == S_OUTPUT)
    );

    // ain_tready je aktivan samo u IDLE ili LOAD stanju
    ast_ain_ready_only_idle_load: assert property (
        ain_tready |-> (state == S_IDLE || state == S_LOAD)
    );

    // aout_tlast je aktivan samo na poslednjem izlaznom taktu
    ast_aout_tlast_correct: assert property (
        aout_tlast |-> (state == S_OUTPUT && out_cnt == PAIR_W'(PAIR_MAX))
    );

    // Stabilnost izlaznih podataka: kada je tvalid aktivan a tready nije,
    // podaci i tvalid moraju ostati stabilni do sledeceg takta
    ast_out_data_stable: assert property (
        (aout_tvalid && !aout_tready) |=>
            ($stable(aout_tdata) && aout_tvalid)
    );

    // aout_tlast je stabilan dok cekamo na handshake
    ast_out_tlast_stable: assert property (
        (aout_tvalid && !aout_tready) |=> $stable(aout_tlast)
    );

    // =========================================================================
    //  ASSERT properties — invarijante masine stanja
    // =========================================================================

    // Stanje je uvek validno
    ast_state_valid: assert property (
        state <= S_OUTPUT
    );

    // =========================================================================
    //  COVER properties — dostiznost zeljenih scenarija
    // =========================================================================

    // Kompletna transakcija sa rastucim sortiranjem
    cov_ascending: cover property (
        (state == S_OUTPUT && sort_dir_r == 1'b1)
    );

    // Kompletna transakcija sa opadajucim sortiranjem
    cov_descending: cover property (
        (state == S_OUTPUT && sort_dir_r == 1'b0)
    );

    // Transakcija sa duplikatima
    cov_has_dups: cover property (
        (state == S_OUTPUT && dup_nums > 0)
    );

    // Transakcija bez duplikata
    cov_no_dups: cover property (
        (state == S_OUTPUT && dup_nums == 0)
    );

    // Zavrsetak slanja (poslednji izlazni takt)
    cov_output_complete: cover property (
        (aout_tvalid && aout_tready && aout_tlast)
    );

    // Povratak u IDLE nakon kompletne transakcije
    cov_back_to_idle: cover property (
        (state == S_OUTPUT) ##[1:$] (state == S_IDLE)
    );

endmodule
