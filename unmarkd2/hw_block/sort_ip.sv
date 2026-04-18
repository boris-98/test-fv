import sort_pkg::*;

module sort_ip #(
    parameter DATA_WIDTH = sort_pkg::DATA_WIDTH,
    parameter DEPTH      = 8,
    parameter ADDR_WIDTH = 3
) (
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    sort_dir,       // 1 = ascending, 0 = descending

    // AXI Stream Slave
    input  logic                    ain_tvalid,
    output logic                    ain_tready,
    input  logic                    ain_tlast,
    input  logic [DATA_WIDTH-1:0]   ain_tdata,

    // AXI Stream Master
    output logic                    aout_tvalid,
    input  logic                    aout_tready,
    output logic                    aout_tlast,
    output logic [DATA_WIDTH-1:0]   aout_tdata,

    // Broj duplikata pronadjenih tokom sortiranja
    output logic [DATA_WIDTH/2-1:0] dup_nums
);

    // -------------------------------------------------------------------------
    // Enumeracije stanja
    // -------------------------------------------------------------------------
    typedef enum logic { IDLE, PROCESSING } states_t;
    typedef enum logic [2:0] {
        IDLE_SORT,
        FIND_LESS_SORT,
        SWAP_SORT,
        WRITE_SORT,
        END_J_SORT,
        DIAGONAL_SWAP
    } sort_states_t;

    states_t      state_s_reg,    state_s_next;
    states_t      state_m_reg,    state_m_next;
    sort_states_t state_sort_reg, state_sort_next;

    // -------------------------------------------------------------------------
    // AXI Slave signali
    // -------------------------------------------------------------------------
    logic                  ain_tready_s;
    logic [DATA_WIDTH-1:0] data_w_stream;

    // -------------------------------------------------------------------------
    // AXI Master signali
    // -------------------------------------------------------------------------
    logic                  aout_tvalid_s;
    logic                  aout_tlast_s;
    logic [DATA_WIDTH-1:0] aout_tdata_s;

    // -------------------------------------------------------------------------
    // Adresni brojaci
    // -------------------------------------------------------------------------
    logic [ADDR_WIDTH-1:0] addr_in_reg,  addr_in_next;   // upis u memoriju
    logic [ADDR_WIDTH-1:0] addr_out_reg, addr_out_next;  // citanje iz memorije
    logic [ADDR_WIDTH-1:0] i_reg, i_next;                // outer sort petlja
    logic [ADDR_WIDTH-1:0] j_reg, j_next;                // inner sort petlja

    // -------------------------------------------------------------------------
    // Status registri
    // -------------------------------------------------------------------------
    logic                  array_sorted_reg,       array_sorted_next;
    logic                  last_el_arrived_reg,    last_el_arrived_next;
    logic [ADDR_WIDTH-1:0] num_of_arrived_el_reg,  num_of_arrived_el_next;

    // -------------------------------------------------------------------------
    // Memorijski interfejs
    // -------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] data_in_mem_s, data_out_mem_s;
    logic [ADDR_WIDTH-1:0] addr_w_mem_s,  addr_r_mem_s;
    logic                  we_mem_s;

    // Razdvajanje gornje/donje polovine rijeci
    logic [DATA_WIDTH/2-1:0] msb_data, lsb_data;
    assign msb_data = data_out_mem_s[DATA_WIDTH-1 : DATA_WIDTH/2];
    assign lsb_data = data_out_mem_s[DATA_WIDTH/2-1 : 0];

    // Najmanji element (tekuci minimum tokom prolaza)
    logic [DATA_WIDTH/2-1:0] smallest_msb_data_reg, smallest_msb_data_next;
    logic [DATA_WIDTH/2-1:0] smallest_lsb_data_reg, smallest_lsb_data_next;

    // -------------------------------------------------------------------------
    // Logika sortiranja
    // -------------------------------------------------------------------------
    logic                  is_sorting;
    logic                  reset_last_el;
    logic [DATA_WIDTH-1:0] data_w_sort;
    logic [ADDR_WIDTH-1:0] addr_w_sort;
    logic [ADDR_WIDTH-1:0] addr_r_sort;
    logic                  we_sort;
    logic [DATA_WIDTH-1:0] swap_reg, swap_next;

    // -------------------------------------------------------------------------
    // Duplikati
    // -------------------------------------------------------------------------
    logic [DATA_WIDTH/2-1:0] dup_nums_reg, dup_nums_next;
    assign dup_nums = dup_nums_reg;

    // -------------------------------------------------------------------------
    // Stream adresni signali
    // -------------------------------------------------------------------------
    logic [ADDR_WIDTH-1:0] addr_w_stream, addr_r_stream;
    logic                  clear_sorted_reg;
    logic                  reset_num_fo_arrived_el_reg;

    // -------------------------------------------------------------------------
    // Kombinacijska logika za memoriju
    // -------------------------------------------------------------------------
    assign aout_tdata  = data_out_mem_s;
    assign addr_w_stream = addr_in_reg;
    assign addr_r_stream = addr_out_next;

    assign addr_w_mem_s  = is_sorting ? addr_w_sort  : addr_w_stream;
    assign addr_r_mem_s  = is_sorting ? addr_r_sort  : addr_r_stream;
    assign data_in_mem_s = is_sorting ? data_w_sort  : data_w_stream;
    assign we_mem_s      = (ain_tready_s & ain_tvalid) || we_sort;

    // -------------------------------------------------------------------------
    // Instanca memorije
    // -------------------------------------------------------------------------
    mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) mem_inst (
        .clk           (clk),
        .rst           (rst),
        .address_write (addr_w_mem_s),
        .address_read  (addr_r_mem_s),
        .data_in       (data_in_mem_s),
        .data_out      (data_out_mem_s),
        .we            (we_mem_s)
    );

    // -------------------------------------------------------------------------
    // Inicijalno sortiranje para pri upisu:
    //   sort_dir=1 (rastuce):   manji u MSB[31:16], veci u LSB[15:0]
    //   sort_dir=0 (opadajuce): veci u MSB[31:16], manji u LSB[15:0]
    // -------------------------------------------------------------------------
    assign data_w_stream = sort_dir
        ? ( (ain_tdata[DATA_WIDTH-1 : DATA_WIDTH/2] > ain_tdata[DATA_WIDTH/2-1 : 0])
                ? {ain_tdata[DATA_WIDTH/2-1 : 0], ain_tdata[DATA_WIDTH-1 : DATA_WIDTH/2]}
                : ain_tdata )
        : ( (ain_tdata[DATA_WIDTH-1 : DATA_WIDTH/2] < ain_tdata[DATA_WIDTH/2-1 : 0])
                ? {ain_tdata[DATA_WIDTH/2-1 : 0], ain_tdata[DATA_WIDTH-1 : DATA_WIDTH/2]}
                : ain_tdata );

    // =========================================================================
    // Sekvencijalna logika
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            state_s_reg            <= IDLE;
            state_m_reg            <= IDLE;
            state_sort_reg         <= IDLE_SORT;
            addr_in_reg            <= '0;
            addr_out_reg           <= '0;
            array_sorted_reg       <= '0;
            last_el_arrived_reg    <= '0;
            i_reg                  <= '0;
            j_reg                  <= '0;
            smallest_lsb_data_reg  <= '0;
            smallest_msb_data_reg  <= '0;
            num_of_arrived_el_reg  <= '0;
            swap_reg               <= '0;
            dup_nums_reg           <= '0;
        end
        else begin
            state_s_reg    <= state_s_next;
            state_m_reg    <= state_m_next;
            state_sort_reg <= state_sort_next;

            addr_in_reg    <= addr_in_next;
            addr_out_reg   <= addr_out_next;

            if (clear_sorted_reg) begin
                array_sorted_reg <= 1'b0;
                dup_nums_reg     <= '0;
            end
            else begin
                array_sorted_reg <= array_sorted_next;
                dup_nums_reg     <= dup_nums_next;
            end

            if (reset_last_el)
                last_el_arrived_reg <= 1'b0;
            else
                last_el_arrived_reg <= last_el_arrived_next;

            i_reg                 <= i_next;
            j_reg                 <= j_next;
            smallest_lsb_data_reg <= smallest_lsb_data_next;
            smallest_msb_data_reg <= smallest_msb_data_next;

            if (reset_num_fo_arrived_el_reg)
                num_of_arrived_el_reg <= '0;
            else
                num_of_arrived_el_reg <= num_of_arrived_el_next;

            swap_reg <= swap_next;
        end
    end

    // =========================================================================
    // AXI SLAVE FSM
    // =========================================================================
    always_comb begin
        num_of_arrived_el_next = num_of_arrived_el_reg;

        case (state_s_reg)
            IDLE: begin
                addr_in_next = '0;
                ain_tready_s = 1'b0;
                state_s_next = (ain_tvalid && !is_sorting && !array_sorted_reg)
                               ? PROCESSING : IDLE;
            end

            default: begin
                state_s_next = PROCESSING;
                addr_in_next = addr_in_reg;
                ain_tready_s = 1'b1;

                if (ain_tvalid) begin
                    addr_in_next = addr_in_reg + 1'b1;
                    if (ain_tlast) begin
                        state_s_next          = IDLE;
                        num_of_arrived_el_next = addr_in_reg;
                    end
                end
            end
        endcase
    end

    assign ain_tready = ain_tready_s;

    // =========================================================================
    // AXI MASTER FSM
    // =========================================================================
    always_comb begin
        case (state_m_reg)
            IDLE: begin
                clear_sorted_reg           = 1'b0;
                addr_out_next              = '0;
                aout_tvalid_s              = 1'b0;
                aout_tlast_s               = 1'b0;
                reset_num_fo_arrived_el_reg = 1'b0;
                state_m_next               = array_sorted_reg ? PROCESSING : IDLE;
            end

            default: begin
                aout_tlast_s               = 1'b0;
                aout_tvalid_s              = 1'b1;
                addr_out_next              = addr_out_reg;
                state_m_next               = PROCESSING;
                clear_sorted_reg           = 1'b0;
                reset_num_fo_arrived_el_reg = 1'b0;

                if (aout_tready) begin
                    addr_out_next = addr_out_reg + 1'b1;
                    if (addr_out_reg == num_of_arrived_el_reg) begin
                        state_m_next               = IDLE;
                        aout_tlast_s               = 1'b1;
                        clear_sorted_reg           = 1'b1;
                        reset_num_fo_arrived_el_reg = 1'b1;
                    end
                end
            end
        endcase
    end

    assign aout_tvalid = aout_tvalid_s;
    assign aout_tlast  = aout_tlast_s;

    // =========================================================================
    // SORT FSM
    // =========================================================================
    always_comb begin
        // Defaultne vrijednosti
        data_w_sort            = '0;
        addr_w_sort            = '0;
        addr_r_sort            = j_next;
        is_sorting             = 1'b1;
        reset_last_el          = 1'b0;
        we_sort                = 1'b0;
        smallest_lsb_data_next = smallest_lsb_data_reg;
        smallest_msb_data_next = smallest_msb_data_reg;
        array_sorted_next      = array_sorted_reg;
        swap_next              = swap_reg;
        dup_nums_next          = dup_nums_reg;

        case (state_sort_reg)

            // -----------------------------------------------------------------
            IDLE_SORT: begin
                is_sorting             = 1'b0;
                i_next                 = '0;
                j_next                 = '0;
                we_sort                = 1'b0;
                smallest_lsb_data_next = lsb_data;
                smallest_msb_data_next = msb_data;

                if (last_el_arrived_reg) begin
                    is_sorting      = 1'b1;
                    j_next          = j_reg + 1'b1;
                    state_sort_next = FIND_LESS_SORT;
                end
                else begin
                    state_sort_next = IDLE_SORT;
                end

                addr_r_sort = j_next;
            end

            // -----------------------------------------------------------------
            FIND_LESS_SORT: begin
                if (i_reg <= num_of_arrived_el_reg - 1) begin
                    if (j_reg <= num_of_arrived_el_reg) begin

                        // Duplikat: oba polja identicna referentnoj lokaciji
                        if ((msb_data == smallest_msb_data_reg) &&
                            (lsb_data == smallest_lsb_data_reg))
                            dup_nums_next = dup_nums_reg + 1'b1;

                        // Uslov za zamenu
                        if ( sort_dir
                            ? ( (msb_data < smallest_msb_data_reg) ||
                                (lsb_data < smallest_lsb_data_reg) ||
                                (msb_data < smallest_lsb_data_reg) )
                            : ( (msb_data > smallest_msb_data_reg) ||
                                (lsb_data > smallest_lsb_data_reg) ||
                                (lsb_data > smallest_msb_data_reg) ) )
                        begin
                            state_sort_next = SWAP_SORT;
                            j_next          = j_reg;
                            i_next          = i_reg;
                        end
                        else begin
                            state_sort_next = FIND_LESS_SORT;
                            j_next          = j_reg + 1'b1;
                            i_next          = i_reg;
                        end

                    end
                    else begin
                        // Kraj unutrasnje petlje
                        i_next          = i_reg + 1'b1;
                        j_next          = i_next;
                        state_sort_next = END_J_SORT;
                    end
                end
                else begin
                    // Kraj sortiranja
                    i_next             = '0;
                    j_next             = '0;
                    state_sort_next    = IDLE_SORT;
                    reset_last_el      = 1'b1;
                    array_sorted_next  = 1'b1;
                end
            end

            // -----------------------------------------------------------------
            END_J_SORT: begin
                i_next                 = i_reg;
                j_next                 = j_reg + 1'b1;
                smallest_msb_data_next = msb_data;
                smallest_lsb_data_next = lsb_data;
                state_sort_next        = FIND_LESS_SORT;
            end

            // -----------------------------------------------------------------
            SWAP_SORT: begin
                state_sort_next = DIAGONAL_SWAP;
                j_next          = j_reg;
                i_next          = i_reg;
                data_w_sort     = {smallest_msb_data_reg, smallest_lsb_data_reg};
                swap_next       = {msb_data, lsb_data};

                // Zamjena MSB polovine
                if ( sort_dir
                     ? (msb_data < smallest_msb_data_reg)
                     : (msb_data > smallest_msb_data_reg) )
                begin
                    swap_next[DATA_WIDTH-1 : DATA_WIDTH/2]  = smallest_msb_data_reg;
                    data_w_sort[DATA_WIDTH-1 : DATA_WIDTH/2] = msb_data;
                    smallest_msb_data_next                   = msb_data;
                    we_sort                                  = 1'b1;
                end

                // Zamjena LSB polovine
                if ( sort_dir
                     ? (lsb_data < smallest_lsb_data_reg)
                     : (lsb_data > smallest_lsb_data_reg) )
                begin
                    swap_next[DATA_WIDTH/2-1 : 0]  = smallest_lsb_data_reg;
                    data_w_sort[DATA_WIDTH/2-1 : 0] = lsb_data;
                    smallest_lsb_data_next          = lsb_data;
                    we_sort                         = 1'b1;
                end

                addr_w_sort = i_reg;
            end

            // -----------------------------------------------------------------
            DIAGONAL_SWAP: begin
                state_sort_next = WRITE_SORT;
                j_next          = j_reg;
                i_next          = i_reg;
                data_w_sort     = {smallest_msb_data_reg, smallest_lsb_data_reg};
                addr_w_sort     = i_reg;

                // Dijagonalna zamjena: MSB swap_reg vs LSB smallest
                if ( sort_dir
                     ? (swap_reg[DATA_WIDTH-1 : DATA_WIDTH/2] < smallest_lsb_data_reg)
                     : (swap_reg[DATA_WIDTH-1 : DATA_WIDTH/2] > smallest_lsb_data_reg) )
                begin
                    swap_next              = {smallest_lsb_data_reg,
                                              swap_reg[DATA_WIDTH/2-1 : 0]};
                    smallest_lsb_data_next = swap_reg[DATA_WIDTH-1 : DATA_WIDTH/2];
                    data_w_sort            = {smallest_msb_data_reg,
                                              swap_reg[DATA_WIDTH-1 : DATA_WIDTH/2]};
                    we_sort                = 1'b1;
                end
            end

            // -----------------------------------------------------------------
            // WRITE_SORT (default)
            default: begin
                addr_w_sort     = j_reg;
                data_w_sort     = swap_reg;
                we_sort         = 1'b1;
                state_sort_next = FIND_LESS_SORT;
                j_next          = j_reg + 1'b1;
                i_next          = i_reg;
            end

        endcase
    end

    // =========================================================================
    // Detekcija dolaska zadnjeg elementa
    // =========================================================================
    always_comb begin
        last_el_arrived_next = (ain_tlast && !is_sorting)
                               ? 1'b1
                               : last_el_arrived_reg;
    end

endmodule

