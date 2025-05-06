//-----------------------------------------------------------------------------
// Testbench do Multiplicador de Ponto Flutuante 32 bits
// IEEE 754 Single Precision com Round Toward Zero
// Data: 28/02/2025
// Aluna: Jaqueline Ferreira de Brito
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module multiplier32FP_tb;
    // Parâmetros de configuração do testbench
    localparam CLOCK_PERIOD = 10;                       // Período do clock em ns (100MHz)
    localparam SETUP_TIME = 2;                          // Tempo de setup requerido
    localparam HOLD_TIME = 1;                           // Tempo de hold requerido
    localparam INITIAL_WAIT = 10;                       // Ciclos de espera inicial
    localparam MAX_LATENCY = 100;                       // Latência máxima permitida em ns

    // Sinais para interface com o DUT
    logic        clk;                                   // Clock do sistema
    logic        rst_n;                                 // Reset ativo baixo
    logic        start_i;                               // Sinal de início
    logic [31:0] a_i;                                   // Primeiro operando
    logic [31:0] b_i;                                   // Segundo operando
    logic [31:0] product_o;                             // Resultado da multiplicação
    logic        done_o;                                // Sinalização de conclusão
    logic        nan_o;                                 // Flag Not-a-Number
    logic        infinit_o;                             // Flag infinito
    logic        overflow_o;                            // Flag overflow
    logic        underflow_o;                           // Flag underflow
    logic        zero_sujo;                             // Flag zero sujo
    logic        round_toward_zero;                     // Flag arredondamento

    // Variáveis de controle e monitoramento
    int arquivo;                                        // Handle do arquivo de vetores
    logic [31:0] valor_esperado;                        // Resultado esperado
    int contador;                                       // Contador de testes
    int erros;                                          // Contador de erros
    int erros_timing;                                   // Erros de temporização
    int setup_violations;                               // Violações de setup
    int hold_violations;                                // Violações de hold
    int glitch_count;                                   // Contador de glitches
    int invalid_state_count;                            // Estados inválidos
    int latency_violations;                             // Violações de latência
    int reset_violations;                               // Violações de reset
    int state_violations;                               // Violações de estado
    string linha;                                       // Linha do arquivo de teste
    time inicio_teste;                                  // Timestamp início do teste
    time ultimo_done;                                   // Último done registrado
    logic primeiro_teste;                               // Flag primeiro teste

    // Instanciação do DUT (Device Under Test)
    multiplier32FP dut (.*);

    // Gerador de clock
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end

    // Coverage group para casos especiais
    covergroup special_cases @(posedge clk);
        nan_op: coverpoint nan_o;                        // Cobertura de NaN
        inf_op: coverpoint infinit_o;                    // Cobertura de infinito
        overflow_op: coverpoint overflow_o;              // Cobertura de overflow
        underflow_op: coverpoint underflow_o;            // Cobertura de underflow
        zero_op: coverpoint zero_sujo;                   // Cobertura de zero sujo
        round_op: coverpoint round_toward_zero;          // Cobertura de arredondamento
    endgroup

    // Instância do coverage group
    special_cases coverage = new();

    // Monitor de flags e timing
    task automatic monitor_signals;
        int done_counter = 0;
        int flag_counter = 0;
        logic [3:0] active_flags;
        logic last_done = 0;
        time last_done_time = 0;

        forever @(posedge clk) begin
            // Monitora persistência de done_o
            if (done_o) begin
                done_counter++;
                last_done_time = $time;
                if (done_counter > 1) begin
                    $display("ERRO NO TEMPO %0t: done_o permaneceu ativo por mais de 1 ciclo", $time);
                    erros_timing++;
                end
            end else begin
                done_counter = 0;
            end

            // Verifica intervalo mínimo entre done_o e próximo start_i
            if (!primeiro_teste && start_i) begin
                if (($time - last_done_time) < (2 * CLOCK_PERIOD)) begin
                    $display("ERRO NO TEMPO %0t: start_i ativado antes dos 2 ciclos após done_o", $time);
                    erros_timing++;
                end
            end

            // Monitora persistência de flags
            active_flags = {nan_o, infinit_o, overflow_o, underflow_o};
            if (|active_flags) begin
                flag_counter++;
                if (flag_counter > 2) begin
                    $display("ERRO NO TEMPO %0t: Flags permaneceram ativas por mais de 2 ciclos", $time);
                    erros_timing++;
                end
            end else begin
                flag_counter = 0;
            end
        end
    endtask

    // Monitor de setup e hold
    task automatic monitor_timing;
        logic [31:0] last_a, last_b;
        logic last_start;
        time last_change_time;

        forever begin
            @(a_i, b_i, start_i);
            
            // Verifica mudanças nas entradas
            if (a_i !== last_a || b_i !== last_b || start_i !== last_start) begin
                last_change_time = $time;
                last_a = a_i;
                last_b = b_i;
                last_start = start_i;

                // Verifica violações de setup
                if ($time % CLOCK_PERIOD > (CLOCK_PERIOD - SETUP_TIME)) begin
                    $display("ERRO DE SETUP no tempo %0t", $time);
                    setup_violations++;
                end
            end

            // Verifica violações de hold
            @(posedge clk);
            if (($time - last_change_time) < HOLD_TIME) begin
                $display("ERRO DE HOLD no tempo %0t", $time);
                hold_violations++;
            end
        end
    endtask

    // Monitor de glitches
    task automatic monitor_glitches;
        logic last_done;
        time last_change;
        
        forever begin
            @(done_o);
            if (done_o !== last_done) begin
                if (($time - last_change) < CLOCK_PERIOD) begin
                    $display("GLITCH detectado em done_o no tempo %0t", $time);
                    glitch_count++;
                end
                last_change = $time;
                last_done = done_o;
            end
        end
    endtask

    // Verificador de estados inválidos
    task automatic check_invalid_states;
        forever @(posedge clk) begin
            // Verifica combinações inválidas de flags
            if (nan_o && infinit_o) begin
                $display("ERRO: NaN e Infinito ativos simultaneamente em %0t", $time);
                invalid_state_count++;
            end
            if (overflow_o && underflow_o) begin
                $display("ERRO: Overflow e Underflow ativos simultaneamente em %0t", $time);
                invalid_state_count++;
            end
        end
    endtask

    // Verificador de latência máxima
    task automatic check_max_latency;
        time start_time;
        
        forever @(posedge clk) begin
            if (start_i) begin
                start_time = $time;
            end
            if (done_o) begin
                if (($time - start_time) > MAX_LATENCY) begin
                    $display("ERRO: Latência máxima excedida em %0t", $time);
                    latency_violations++;
                end
            end
        end
    endtask

    // Verificador de reset
    task automatic check_reset;
        forever @(negedge rst_n) begin
            // Verifica se todas as saídas são zeradas no reset
            if (product_o !== '0 || done_o !== '0 || 
                nan_o !== '0 || infinit_o !== '0 || 
                overflow_o !== '0 || underflow_o !== '0) begin
                $display("ERRO: Sinais não zerados durante reset em %0t", $time);
                reset_violations++;
            end
        end
    endtask

    // Verificador de transições de estado
    task automatic check_state_transitions;
        logic last_start, last_done;
        logic start_seen;
        
        forever @(posedge clk) begin
            if (start_i) begin
                start_seen = 1;
            end
            
            // Verifica start durante done
            if (start_i && done_o) begin
                $display("ERRO: start_i ativo durante done_o em %0t", $time);
                state_violations++;
            end
            
            // Verifica done sem start prévio
            if (done_o && !last_done && !start_seen) begin
                $display("ERRO: done_o ativo sem start_i prévio em %0t", $time);
                state_violations++;
            end
            
            // Reset do flag quando done desativa
            if (last_done && !done_o) begin
                start_seen = 0;
            end
            
            last_start = start_i;
            last_done = done_o;
        end
    endtask

    // Formatador de números em ponto flutuante
    function automatic string format_fp(input logic [31:0] fp);
        if (fp == 32'h7FFFFFFF) return "overflow";
        if (fp == 32'hFFFFFFFF) return "-overflow";
        if ({fp[30:0]} == 31'h7F800000) return fp[31] ? "-inf" : "inf";
        if ({fp[30:0]} == 0) return fp[31] ? "-0" : "0";
        if (fp[30:23] == 8'hFF && fp[22:0] != 0) return fp[31] ? "-nan" : "nan";
        return $sformatf("%g", $bitstoshortreal(fp));
    endfunction

    // Executor de teste individual
    task automatic run_test(
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [31:0] expected,
        input int test_num
    );
        inicio_teste = $time;

        // Espera entre testes
        if (!primeiro_teste) begin
            while (done_o) @(posedge clk);
            repeat(2) @(posedge clk);
        end

        // Aplicação das entradas
        @(posedge clk);
        #(CLOCK_PERIOD - SETUP_TIME);
        start_i = 1;
        a_i = a;
        b_i = b;

        // Hold time
        @(posedge clk);
        #HOLD_TIME;
        start_i = 0;

        // Espera pelo resultado
        fork : wait_block
            begin : timeout_block 
                repeat(20) @(posedge clk);
                disable wait_for_done;
                $display("ERRO: Timeout no teste %0d", test_num);
                erros++;
            end : timeout_block

            begin : wait_for_done
                logic [31:0] result;
                logic n, i, o, u, z, r;

                while (!done_o) @(posedge clk);
                disable timeout_block;
                
                // Captura do resultado
                result = product_o;
                n = nan_o;
                i = infinit_o;
                o = overflow_o;
                u = underflow_o;
                z = zero_sujo;
                r = round_toward_zero;

                // Exibição dos resultados
                $display("\nDetalhes do Teste %0d:", test_num);
                $display("Tempo de execução: %0d ns", ($time - inicio_teste));
                $display("Entrada A    : %h (%s)", a, format_fp(a));
                $display("Entrada B    : %h (%s)", b, format_fp(b));
                $display("Resultado    : %h (%s)", result, format_fp(result));
                $display("Esperado     : %h (%s)", expected, format_fp(expected));
                $display("Flags - NaN: %0d, Inf: %0d, OF: %0d, UF: %0d, Zero_Sujo: %0d, Round: %0d",
                        n, i, o, u, z, r);

                // Verificação do resultado
                if (result !== expected) begin
                    $display("FALHOU");
                    erros++;
                end else begin
                    $display("PASSOU");
                end
                $display("----------------------------------------");

                ultimo_done = $time;
            end : wait_for_done
        join_any
        disable wait_block;

        primeiro_teste = 0;
    endtask

    // Teste principal
    initial begin
        // Configuração inicial
        $timeformat(-9, 2, " ns", 16);
        
        // Cabeçalho
        $display("\nIniciando testes do multiplicador de ponto flutuante");
        $display("Multiplicação IEEE 754 com Round Toward Zero");
        $display("Data: 28/02/2025");
        $display("Aluna: Jaqueline Ferreira de Brito\n");
        
        // Inicialização de variáveis
        rst_n = 0;
        start_i = 0;
        a_i = 0;
        b_i = 0;
        contador = 0;
        erros = 0;
        erros_timing = 0;
        setup_violations = 0;
        hold_violations = 0;
        glitch_count = 0;
        invalid_state_count = 0;
        latency_violations = 0;
        reset_violations = 0;
        state_violations = 0;
        primeiro_teste = 1;
        ultimo_done = 0;

        // Sequência de reset
        repeat(4) @(posedge clk);
        rst_n = 1;

        // Espera inicial
        repeat(INITIAL_WAIT) @(posedge clk);

        // Início dos monitores
        fork
            monitor_signals();
            monitor_timing();
            monitor_glitches();
            check_invalid_states();
            check_max_latency();
            check_reset();
            check_state_transitions();
        join_none

        // Leitura do arquivo de teste
        arquivo = $fopen("vetor.txt", "r");
        if (arquivo == 0) begin
            $display("Erro ao abrir arquivo vetor.txt");
            $finish;
        end

        // Execução dos testes
        while (!$feof(arquivo)) begin
            logic [31:0] a, b, expected;
            if ($fscanf(arquivo, "%h %h %h", a, b, expected) == 3) begin
                contador++;
                run_test(a, b, expected, contador);
            end
        end

        $fclose(arquivo);

        // Relatório final
        $display("\n----------------------------------------");
        $display("Relatório Final dos Testes:");
        $display("Total de testes executados: %0d", contador);
        $display("Erros de resultado: %0d", erros);
        $display("Erros de timing: %0d", erros_timing);
        $display("Violações de setup: %0d", setup_violations);
        $display("Violações de hold: %0d", hold_violations);
        $display("Glitches detectados: %0d", glitch_count);
        $display("Estados inválidos: %0d", invalid_state_count);
        $display("Violações de latência: %0d", latency_violations);
        $display("Violações de reset: %0d", reset_violations);
        $display("Violações de estado: %0d", state_violations);
        $display("Taxa de sucesso (resultado): %0.2f%%", 100.0 * (contador - erros) / contador);
        $display("Coverage: %0.2f%%", $get_coverage());
        $display("Data: 28/02/2025");
        $display("Aluna: Jaqueline Ferreira de Brito");
        $display("----------------------------------------\n");

        // Detalhes de cobertura
        $display("\nDetalhes de Cobertura:");
        $display("NaN operações: %0.2f%%", coverage.nan_op.get_coverage());
        $display("Infinito operações: %0.2f%%", coverage.inf_op.get_coverage());
        $display("Overflow operações: %0.2f%%", coverage.overflow_op.get_coverage());
        $display("Underflow operações: %0.2f%%", coverage.underflow_op.get_coverage());
        $display("Zero sujo operações: %0.2f%%", coverage.zero_op.get_coverage());
        $display("Round toward zero: %0.2f%%", coverage.round_op.get_coverage());
        
        // Finalização dos testes
        $display("\nFim dos testes: 28/02/2025");
        $display("Duração total: %0.2f ns", $time);
        //#8865;    // (110 MHz)
        #8765;      // (10MHz)
        $finish;
    end

    // Watchdog para timeout da simulação
    initial begin
        #100000; // Timeout de 100us
        $display("ERRO: Simulação excedeu tempo máximo!");
        $finish;
    end

endmodule