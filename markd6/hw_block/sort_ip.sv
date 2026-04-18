// =============================================================================
// Sort IP — SystemVerilog RTL implementacija
// =============================================================================
//
// Hardverski blok za sortiranje brojeva sa AXI Stream interfejsima.
//
// Funkcionalnost:
//   - Prima N 16-bitnih brojeva preko ulaznog AXI Stream interfejsa (2 po taktu)
//   - Sortira brojeve u rastucem ili opadajucem redosledu
//   - Salje sortirane brojeve preko izlaznog AXI Stream interfejsa (2 po taktu)
//   - Broji duplikate (iste vrednosti) u sortiranom nizu
//
// Algoritam sortiranja: Odd-Even Transposition Sort
//   - N prolaza (naizmenicno parni i neparni)
//   - Svaki prolaz uporedo poredi/zamenjuje susedne parove
//   - Garantovano sortiran niz nakon N prolaza
//
// Parametri:
//   - N:  broj elemenata za sortiranje (podrazumevano 8 za FV; 1024 za sintezu)
//   - DW: sirina podatka po elementu u bitovima (podrazumevano 16)
//
// AXI Stream format:
//   - tdata[DW-1:0]:     nizi element para
//   - tdata[2*DW-1:DW]:  visi element para
//   - tvalid/tready:     handshake protokol
//   - tlast:             indikacija poslednjeg transfera
// =============================================================================

module sort_ip #(
    parameter N  = 8,       // Broj elemenata (N >= 4, mora biti paran)
    parameter DW = 16       // Sirina podatka po elementu
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // Ulazni AXI Stream interfejs (ain)
    input  logic                    ain_tvalid,
    output logic                    ain_tready,
    input  logic [2*DW-1:0]         ain_tdata,
    input  logic                    ain_tlast,

    // Izlazni AXI Stream interfejs (aout)
    output logic                    aout_tvalid,
    input  logic                    aout_tready,
    output logic [2*DW-1:0]         aout_tdata,
    output logic                    aout_tlast,

    // Kontrola
    input  logic                    sort_dir,       // 1 = rastuci, 0 = opadajuci

    // Status
    output logic [$clog2(N):0]      dup_nums        // Broj duplikata
);

    // =========================================================================
    // Lokalni parametri
    // =========================================================================
    localparam HALF     = N / 2;                        // Broj parova
    localparam PAIR_W   = $clog2(HALF);                 // Sirina brojaca parova
    localparam PASS_W   = $clog2(N);                    // Sirina brojaca prolaza
    localparam PAIR_MAX = HALF - 1;                     // Maksimalni indeks para
    localparam PASS_MAX = N - 1;                        // Maksimalni broj prolaza

    // =========================================================================
    // Masina stanja
    // =========================================================================
    typedef enum logic [2:0] {
        S_IDLE   = 3'd0,       // Cekanje na ulazne podatke
        S_LOAD   = 3'd1,       // Prijem podataka sa AXI Stream
        S_SORT   = 3'd2,       // Sortiranje (odd-even transposition)
        S_CALC   = 3'd3,       // Izracunavanje broja duplikata
        S_OUTPUT = 3'd4        // Slanje sortiranih podataka
    } state_t;

    state_t state;

    // =========================================================================
    // Interni registri
    // =========================================================================
    logic [DW-1:0]      mem [0:N-1];            // Memorija za podatke
    logic [PAIR_W-1:0]  load_cnt;               // Brojac pri ucitavanju
    logic [PAIR_W-1:0]  out_cnt;                // Brojac pri slanju
    logic [PASS_W-1:0]  sort_pass;              // Trenutni prolaz sortiranja
    logic               sort_dir_r;             // Zahtevani smer sortiranja

    // =========================================================================
    // Odd-Even Transposition Sort — kombinaciona logika
    // =========================================================================
    // Parni prolaz (sort_pass[0]==0): poredi parove (0,1), (2,3), (4,5), ...
    // Neparni prolaz (sort_pass[0]==1): poredi parove (1,2), (3,4), (5,6), ...
    // =========================================================================
    logic [DW-1:0] mem_next [0:N-1];

    always_comb begin
        // Podrazumevano: nema zamene
        for (int i = 0; i < N; i++)
            mem_next[i] = mem[i];

        if (sort_pass[0] == 1'b0) begin
            // Parni prolaz: parovi (0,1), (2,3), (4,5), ...
            for (int i = 0; i < N-1; i += 2) begin
                if (sort_dir_r ? (mem[i] > mem[i+1]) : (mem[i] < mem[i+1])) begin
                    mem_next[i]   = mem[i+1];
                    mem_next[i+1] = mem[i];
                end
            end
        end else begin
            // Neparni prolaz: parovi (1,2), (3,4), (5,6), ...
            for (int i = 1; i < N-1; i += 2) begin
                if (sort_dir_r ? (mem[i] > mem[i+1]) : (mem[i] < mem[i+1])) begin
                    mem_next[i]   = mem[i+1];
                    mem_next[i+1] = mem[i];
                end
            end
        end
    end

    // =========================================================================
    // Brojanje duplikata — kombinaciona logika
    // =========================================================================
    logic [$clog2(N):0] dup_count;

    always_comb begin
        dup_count = '0;
        for (int i = 1; i < N; i++) begin
            if (mem[i] == mem[i-1])
                dup_count = dup_count + 1;
        end
    end

    // =========================================================================
    // AXI handshake signali
    // =========================================================================
    wire ain_handshake  = ain_tvalid && ain_tready;
    wire aout_handshake = aout_tvalid && aout_tready;

    // =========================================================================
    // Glavna masina stanja — sekvencijalna logika
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            load_cnt   <= '0;
            out_cnt    <= '0;
            sort_pass  <= '0;
            sort_dir_r <= 1'b1;
            dup_nums   <= '0;
            for (int i = 0; i < N; i++)
                mem[i] <= '0;
        end else begin
            case (state)
                // ---------------------------------------------------------
                // IDLE: Cekanje na prvi validan ulazni podatak
                // ---------------------------------------------------------
                S_IDLE: begin
                    if (ain_handshake) begin
                        // Upis prvog para u memoriju
                        mem[0]     <= ain_tdata[DW-1:0];
                        mem[1]     <= ain_tdata[2*DW-1:DW];
                        sort_dir_r <= sort_dir;
                        sort_pass  <= '0;
                        if (ain_tlast) begin
                            // Samo jedan par — odmah na sortiranje
                            state <= S_SORT;
                        end else begin
                            state    <= S_LOAD;
                            load_cnt <= 1;
                        end
                    end
                end

                // ---------------------------------------------------------
                // LOAD: Prijem preostalih parova podataka
                // ---------------------------------------------------------
                S_LOAD: begin
                    if (ain_handshake) begin
                        mem[{load_cnt, 1'b0}]  <= ain_tdata[DW-1:0];
                        mem[{load_cnt, 1'b1}]  <= ain_tdata[2*DW-1:DW];
                        if (ain_tlast || load_cnt == PAIR_W'(PAIR_MAX)) begin
                            state <= S_SORT;
                        end else begin
                            load_cnt <= load_cnt + 1;
                        end
                    end
                end

                // ---------------------------------------------------------
                // SORT: Odd-even transposition sort (N prolaza)
                // ---------------------------------------------------------
                S_SORT: begin
                    for (int i = 0; i < N; i++)
                        mem[i] <= mem_next[i];

                    if (sort_pass == PASS_W'(PASS_MAX)) begin
                        state <= S_CALC;
                    end else begin
                        sort_pass <= sort_pass + 1;
                    end
                end

                // ---------------------------------------------------------
                // CALC: Hvatanje broja duplikata iz sortiranog niza
                // ---------------------------------------------------------
                S_CALC: begin
                    dup_nums <= dup_count;
                    state    <= S_OUTPUT;
                    out_cnt  <= '0;
                end

                // ---------------------------------------------------------
                // OUTPUT: Slanje sortiranih podataka preko AXI Stream
                // ---------------------------------------------------------
                S_OUTPUT: begin
                    if (aout_handshake) begin
                        if (out_cnt == PAIR_W'(PAIR_MAX)) begin
                            state <= S_IDLE;
                        end else begin
                            out_cnt <= out_cnt + 1;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Izlazna logika
    // =========================================================================
    assign ain_tready  = (state == S_IDLE) || (state == S_LOAD);
    assign aout_tvalid = (state == S_OUTPUT);
    assign aout_tdata  = {mem[{out_cnt, 1'b1}], mem[{out_cnt, 1'b0}]};
    assign aout_tlast  = (state == S_OUTPUT) && (out_cnt == PAIR_W'(PAIR_MAX));

endmodule
