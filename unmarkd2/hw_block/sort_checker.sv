import sort_pkg::*;

checker sort_checker (
    clk,
    rst,
    ain_tvalid,
    ain_tready,
    ain_tlast,
    ain_tdata,
    aout_tvalid,
    aout_tready,
    aout_tlast,
    aout_tdata,
    sort_dir,
    dup_nums
);

    default clocking @(posedge clk); endclocking
    default disable iff rst;

    // -------------------------------------------------------------------------
    // Interni registri checkera
    //
    // last_reg        — pamti da je ain_tlast vec vidjen (transakcija je gotova)
    // last_datain_reg — pamti prethodni ulazni podatak (koristi se u diff_input_data)
    // prev_data_out   — pamti LSB prethodnog izlaznog podatka (koristi se u END_TO_END_check)
    // end_sorting     — rezervisano, trenutno se ne koristi
    // first_out_seen  — oznacava da je bar jedan izlazni podatak vec vidjjen,
    //                   cime se preskace medjuparna provjera za prvi element
    // -------------------------------------------------------------------------
    logic                              last_reg,        last_next;
    logic [sort_pkg::DATA_WIDTH-1:0]   last_datain_reg, last_datain_next;
    logic [sort_pkg::DATA_WIDTH/2-1:0] prev_data_out;
    logic                              end_sorting;
    logic                              first_out_seen;

    always @(posedge clk) begin
        if (rst == 1'b1) begin
            last_reg        <= 1'b0;
            // Neutralna pocetna vrijednost zavisi od smjera sortiranja:
            // rastuce  → prethodni ulaz inicijalizujemo na max ('1) da prvi element uvijek prodje
            // opadajuce → prethodni ulaz inicijalizujemo na min ('0) iz istog razloga
            last_datain_reg <= sort_dir ? '1 : '0;
            end_sorting     <= 'b0;
            first_out_seen  <= 1'b0;
            // Neutralna pocetna vrijednost za pracenje izlaznog redosljeda:
            // rastuce  → krece od 0 (najmanji moguci), svaki sledeci mora biti veci
            // opadajuce → krece od max, svaki sledeci mora biti manji
            prev_data_out   <= sort_dir ? '0 : '1;
        end
        else begin
            last_datain_reg = last_datain_next;

            // Zakljucaj last_reg cim ain_tlast bude vidjjen — ostaje visok do reseta
            if (ain_tlast == 1'b1)
                last_reg <= 1'b1;
            else
                last_reg <= last_reg;

            // Azuriraj prev_data_out i first_out_seen pri svakom validnom izlaznom handshakeu
            if (aout_tvalid && aout_tready) begin
                prev_data_out  <= aout_tdata[DATA_WIDTH/2-1:0];
                first_out_seen <= 1'b1;
            end
        end
    end

    assign last_datain_next = ain_tdata;

    // =========================================================================
    // COVER — pokrivanje interesantnih scenarija
    // =========================================================================

    // Pokriva da je barem 5 elemenata upisano u memoriju
    see_inlast_signal               : cover property (sort_ip.addr_in_reg == 10'd5);

    // Pokriva da simulacija moze trajati barem 15 ciklusa
    see_11_cycles                   : cover property (1[*15]);

    // Pokriva da izlazni stream moze biti kompletiran (aout_tlast vidjjen)
    see_end_output_data             : cover property (aout_tlast);

    // Pokriva da se j_reg resetuje na vrijednost i_reg nakon kraja unutrasnje petlje
    cover_j_reset                   : cover property (
        (sort_ip.j_reg > sort_ip.num_of_arrived_el_reg)
        |=> (sort_ip.j_reg == sort_ip.i_reg)
    );

    // Pokriva trenutak kada spoljna petlja dostigne kraj niza (kraj sortiranja)
    cover_end_of_sort               : cover property (
        sort_ip.is_sorting == 1'b1 &&
        sort_ip.i_reg      == sort_ip.num_of_arrived_el_reg
    );

    // Pokriva da array_sorted_reg moze biti postavljen (sortiranje zavrseno)
    check_if_sorted_reg_is_asserted : cover property (sort_ip.array_sorted_reg == 1'b1);

    // Pokriva kompletan scenarij: zamjena se desila i izlaz je kompletiran
    cover_output_sequence           : cover property (
        sort_ip.state_sort_reg == SWAP_SORT ##[0:$] aout_tlast
    );

    // Pokriva da se zamjena desava tokom rastuceg sortiranja
    see_swap_sort_state_asc         : cover property (
        sort_dir == 1'b1 &&
        ((sort_ip.msb_data < sort_ip.smallest_msb_data_reg) ||
         (sort_ip.lsb_data < sort_ip.smallest_lsb_data_reg)) &&
        sort_ip.is_sorting == 1'b1
    );

    // Pokriva da se zamjena desava tokom opadajuceg sortiranja
    see_swap_sort_state_desc        : cover property (
        sort_dir == 1'b0 &&
        ((sort_ip.msb_data > sort_ip.smallest_msb_data_reg) ||
         (sort_ip.lsb_data > sort_ip.smallest_lsb_data_reg)) &&
        sort_ip.is_sorting == 1'b1
    );

    // Pokriva da opadajuce sortiranje moze biti kompletiran do kraja
    see_end_output_desc             : cover property (sort_dir == 1'b0 && aout_tlast);

    // Pokriva kompletan scenarij opadajuceg sortiranja: zamjena + kompletiran izlaz
    cover_output_sequence_desc      : cover property (
        sort_dir == 1'b0 &&
        sort_ip.state_sort_reg == SWAP_SORT ##[0:$] aout_tlast
    );

    // =========================================================================
    // RESTRICT — ogranicavanje prostora pretrage
    // =========================================================================

    // sort_dir mora ostati stabilan tokom cijele transakcije —
    // nije dozvoljeno mijenjati smjer sortiranja usred rada
    sort_dir_stable      : restrict property ($stable(sort_dir));

    // ain_tlast ne smije biti postavljen dok nije primljeno barem 4 elementa —
    // ogranicava minimalnu duzinu niza na 5 elemenata
    generate_12_data     : restrict property (
        (sort_ip.addr_in_reg < 4'd4) |-> !ain_tlast
    );

    // ain_tlast mora biti postavljen tacno kad je primljeno 4 elemenata (indeks 4) —
    // ogranicava maksimalnu duzinu niza na 5 elemenata radi ubrzavanja pretrage
    generate_last_signal : restrict property (
        (sort_ip.addr_in_reg == 4'd4) |-> ain_tlast
    );

    // Nakon sto je ain_tlast vidjjen, nije dozvoljeno ponovo postaviti ain_tlast —
    // svaka transakcija ima tacno jedan tlast
    inlast_only_once     : restrict property (last_reg |-> !ain_tlast);

    // Nakon sto je ain_tlast vidjjen, ain_tvalid mora ostati nizak —
    // nema novih podataka nakon kraja transakcije
    invalid_only_once    : restrict property (last_reg |-> !ain_tvalid);

    // Svaki ulazni par mora biti interno sortiran u ispravnom smjeru,
    // i svaki novi par mora biti strogo manji/veci od prethodnog —
    // ovo garantuje da ulaz nije vec sortiran i da nema duplikata unutar parova
    diff_input_data      : restrict property (
        !last_reg |-> (
            sort_dir
            ? ( ain_tdata[sort_pkg::DATA_WIDTH/2-1:0]
                    < ain_tdata[sort_pkg::DATA_WIDTH-1:sort_pkg::DATA_WIDTH/2]
                &   ain_tdata[sort_pkg::DATA_WIDTH-1:sort_pkg::DATA_WIDTH/2]
                    < last_datain_reg[sort_pkg::DATA_WIDTH/2-1:0] )
            : ( ain_tdata[sort_pkg::DATA_WIDTH/2-1:0]
                    > ain_tdata[sort_pkg::DATA_WIDTH-1:sort_pkg::DATA_WIDTH/2]
                &   ain_tdata[sort_pkg::DATA_WIDTH-1:sort_pkg::DATA_WIDTH/2]
                    > last_datain_reg[sort_pkg::DATA_WIDTH/2-1:0] )
        )
    );

    // Nakon kraja transakcije, ain_tdata mora biti 0 (nema smislenih podataka)
    same_input_data : restrict property (last_reg |-> ain_tdata   == 'b0);

    // aout_tready se postavlja tek nakon sto je transakcija primljena (last_reg=1) —
    // master ne smije citati dok sortiranje nije zavrseno
    aout_tready0    : restrict property (last_reg  |-> aout_tready == 'b1);
    aout_tready1    : restrict property (!last_reg |-> aout_tready == 'b0);

    // =========================================================================
    // ASSERT — dokaz ispravnosti implementacije
    // =========================================================================

    // Glavna assertion: svaki izlazni podatak mora biti sortiran
    //   - MSB mora biti <= LSB unutar iste rijeci (za rastuce) ili >= (za opadajuce)
    //   - MSB tekuceg para mora biti >= MSB prethodnog para (za rastuce) ili <= (za opadajuce)
    //   - first_out_seen preskace medjuparnu provjeru za prvi izlazni element
    END_TO_END_check : assert property (
        aout_tvalid && aout_tready && sort_ip.array_sorted_reg
        |-> (
            sort_dir
            ? ( (!first_out_seen ||
                  prev_data_out <= aout_tdata[sort_pkg::DATA_WIDTH-1:sort_pkg::DATA_WIDTH/2])
                &&  aout_tdata[sort_pkg::DATA_WIDTH-1:sort_pkg::DATA_WIDTH/2]
                    <= aout_tdata[sort_pkg::DATA_WIDTH/2-1:0] )
            : ( (!first_out_seen ||
                  prev_data_out >= aout_tdata[sort_pkg::DATA_WIDTH-1:sort_pkg::DATA_WIDTH/2])
                &&  aout_tdata[sort_pkg::DATA_WIDTH-1:sort_pkg::DATA_WIDTH/2]
                    >= aout_tdata[sort_pkg::DATA_WIDTH/2-1:0] )
        )
    );

    // Dokazuje da upis u memoriju od strane stream-a i sort FSM-a
    // ne mogu biti aktivni istovremeno — sprecava korupciju memorije
    no_2_we_mem_asserted : assert property (
        !(sort_ip.we_sort == 1'b1 &&
         ((sort_ip.ain_tready_s & ain_tvalid) == 1'b1))
    );

    // Dokazuje da se modul ispravno resetuje nakon slanja zadnjeg elementa —
    // svi relevantni registri moraju biti ocisceni unutar 4 ciklusa od aout_tlast
    is_ready_for_next_transaction : assert property (
        aout_tlast |-> ##[1:4] (
            sort_ip.addr_in_reg           == 'b0 &&
            sort_ip.array_sorted_reg      == 'b0 &&
            sort_ip.last_el_arrived_reg   == 'b0 &&
            sort_ip.num_of_arrived_el_reg == 'b0
        )
    );

    // Dokazuje da su svi primljeni elementi poslati prije aout_tlast —
    // addr_out_reg mora biti jednak broju primljenih elemenata
    assert_all_elements_sent : assert property (
        aout_tlast |->
        sort_ip.addr_out_reg == sort_ip.num_of_arrived_el_reg
    );

    // Dokazuje da dup_nums ne moze biti veci od ukupnog broja primljenih elemenata —
    // gornja granica za broj duplikata
    assert_dup_bound : assert property (
        sort_ip.array_sorted_reg |->
        dup_nums <= sort_ip.num_of_arrived_el_reg
    );

    // Dokazuje da se dup_nums resetuje nakon svake transakcije —
    // brojac duplikata ne smije akumulirati vrijednosti iz prethodnih transakcija
    assert_dup_reset : assert property (
        aout_tlast |-> ##[1:4] dup_nums == '0
    );

    // =========================================================================
    // COVER — dup_nums
    // =========================================================================

    // Pokriva ekstremni slucaj gdje su svi elementi u nizu duplikati —
    // dup_nums mora moci dostici vrijednost jednaku broju primljenih elemenata
    cover_dup_max : cover property (
        dup_nums == sort_ip.num_of_arrived_el_reg
    );

endchecker

