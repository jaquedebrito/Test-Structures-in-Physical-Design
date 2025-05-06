//-----------------------------------------------------------------------------
// Módulo: Multiplicador de Ponto Flutuante 32 bits
// Formato: IEEE 754 Single Precision com Round Toward Zero
// Autora: Jaqueline Ferreira de Brito
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module multiplier32FP (

    // Entradas do sistema
    input  logic        clk,                                            // Clock do sistema
    input  logic        rst_n,                                          // Reset assíncrono ativo baixo
    input  logic        start_i,                                        // Sinal para iniciar multiplicação
    input  logic [31:0] a_i,                                            // Primeiro operando (IEEE 754)
    input  logic [31:0] b_i,                                            // Segundo operando (IEEE 754)
    
    // Saídas principais
    output logic [31:0] product_o,                                      // Resultado da multiplicação (IEEE 754)
    output logic        done_o,                                         // Indica operação concluída
    
    // Flags de status
    output logic        nan_o,                                          // Indica resultado Not-a-Number
    output logic        infinit_o,                                      // Indica resultado infinito
    output logic        overflow_o,                                     // Indica overflow na operação
    output logic        underflow_o,                                    // Indica underflow na operação
    output logic        zero_sujo,                                      // Indica zero resultante de underflow
    output logic        round_toward_zero                               // Indica arredondamento para zero
);

    // Definição dos estados da máquina (codificação one-hot)
    typedef enum logic [4:0] {
        IDLE          = 5'b00001,   // Estado de espera
        CHECK_SPECIAL = 5'b00010,   // Verifica casos especiais
        MULTIPLY      = 5'b00100,   // Realiza multiplicação
        NORMALIZE     = 5'b01000,   // Normaliza resultado
        DONE          = 5'b10000    // Finaliza operação
    } state_t;

    // Registradores principais com atributos de síntese
    (* keep = "true" *) state_t state_r, next_state;                    // Estado atual e próximo
    (* keep = "true" *) logic [31:0] product_r, next_product;           // Produto
    (* keep = "true" *) logic [47:0] mant_prod_r, next_mant_prod;       // Mantissa do produto
    (* keep = "true" *) logic [9:0]  exp_sum_r, next_exp_sum;           // Soma dos expoentes
    (* keep = "true" *) logic [3:0] initial_counter;                    // Contador inicial
    (* keep = "true" *) logic [1:0] done_delay_counter;                 // Contador de delay após done

    // Registradores para flags
    logic done_r, next_done;                                            // Flag de conclusão
    logic nan_r, next_nan;                                              // Flag de NaN
    logic infinit_r, next_infinit;                                      // Flag de infinito
    logic overflow_r, next_overflow;                                    // Flag de overflow
    logic underflow_r, next_underflow;                                  // Flag de underflow
    logic zero_sujo_r, next_zero_sujo;                                  // Flag de zero sujo
    logic round_toward_zero_r, next_round_toward_zero;                  // Flag de arredondamento
    
    // Sinais de controle
    logic start_allowed;                                                // Controle de início permitido

    // Sinais combinacionais para cálculos intermediários
    logic sign_a, sign_b, sign_res;                                     // Sinais de sinal
    logic [7:0] exp_a, exp_b;                                           // Expoentes
    logic [22:0] mant_a, mant_b;                                        // Mantissas
    logic is_zero_a, is_zero_b;                                         // Flags de zero
    logic is_inf_a, is_inf_b;                                           // Flags de infinito
    logic is_nan_a, is_nan_b;                                           // Flags de NaN
    logic [47:0] temp_mant;                                             // Mantissa temporária
    logic [7:0] temp_exp;                                               // Expoente temporário
    logic has_bits;                                                     // Indica bits significativos
    logic overflow_condition;                                           // Condição de overflow

    // Extração dos campos dos operandos
    always_comb begin
        // Extrai campos dos operandos
        sign_a = a_i[31];                                               // Sinal do operando A
        sign_b = b_i[31];                                               // Sinal do operando B
        exp_a = a_i[30:23];                                             // Expoente do operando A
        exp_b = b_i[30:23];                                             // Expoente do operando B
        mant_a = a_i[22:0];                                             // Mantissa do operando A
        mant_b = b_i[22:0];                                             // Mantissa do operando B
        sign_res = sign_a ^ sign_b;                                     // Sinal do resultado
        
        // Detecção de casos especiais
        is_zero_a = (exp_a == 8'h00) && (mant_a == 23'h0);
        is_zero_b = (exp_b == 8'h00) && (mant_b == 23'h0);
        is_inf_a = (exp_a == 8'hFF) && (mant_a == 23'h0);
        is_inf_b = (exp_b == 8'hFF) && (mant_b == 23'h0);
        is_nan_a = (exp_a == 8'hFF) && (mant_a != 23'h0);
        is_nan_b = (exp_b == 8'hFF) && (mant_b != 23'h0);
        
        // Verifica condição de overflow
        overflow_condition = ({2'b0, exp_a} + {2'b0, exp_b} >= 10'd381);
        
        // Controle de início da operação
        start_allowed = (initial_counter == 0) && (done_delay_counter == 0);
    end

    // Lógica combinacional para próximo estado e flags
    always_comb begin
        // Valores default para evitar latches
        next_state = state_r;
        next_product = product_r;
        next_mant_prod = mant_prod_r;
        next_exp_sum = exp_sum_r;
        next_done = 1'b0;
        next_nan = nan_r;
        next_infinit = infinit_r;
        next_overflow = overflow_r;
        next_underflow = underflow_r;
        next_zero_sujo = zero_sujo_r;
        next_round_toward_zero = round_toward_zero_r;
        
        // Máquina de estados
        case (state_r)
            // Estado de espera
            IDLE: begin
                if (start_i && start_allowed) begin
                    next_state = CHECK_SPECIAL;
                    // Reset de todas as flags
                    next_nan = 1'b0;
                    next_infinit = 1'b0;
                    next_overflow = 1'b0;
                    next_underflow = 1'b0;
                    next_zero_sujo = 1'b0;
                    next_round_toward_zero = 1'b0;
                end else begin
                    // Mantém flags limpas quando inativo
                    next_nan = 1'b0;
                    next_infinit = 1'b0;
                    next_overflow = 1'b0;
                    next_underflow = 1'b0;
                end
            end

            // Verifica casos especiais
            CHECK_SPECIAL: begin
                if (is_nan_a || is_nan_b) begin
                    next_product = 32'h00000000;
                    next_nan = 1'b1;
                    next_done = 1'b1;
                    next_state = IDLE;
                end
                else if (is_zero_a || is_zero_b) begin
                    next_product = {sign_res, 31'b0};
                    next_done = 1'b1;
                    next_state = IDLE;
                end
                else if (is_inf_a || is_inf_b) begin
                    next_product = {sign_res, 8'hFF, 23'h7FFFFF};
                    next_infinit = 1'b1;
                    next_overflow = 1'b1;
                    next_done = 1'b1;
                    next_state = IDLE;
                end
                else if (overflow_condition) begin
                    next_product = {sign_res, 8'hFF, 23'h7FFFFF};
                    next_overflow = 1'b1;
                    next_done = 1'b1;
                    next_state = IDLE;
                end
                else begin
                    next_state = MULTIPLY;
                end
            end

            // Realiza a multiplicação
            MULTIPLY: begin
                // Calcula soma dos expoentes
                next_exp_sum = {2'b0, exp_a} + {2'b0, exp_b} - 10'd127;
                // Multiplicação das mantissas
                if (exp_a == 8'h00 || exp_b == 8'h00) begin
                    next_mant_prod = {1'b0, mant_a} * {1'b0, mant_b};
                    next_zero_sujo = 1'b1;
                end else begin
                    next_mant_prod = {1'b1, mant_a} * {1'b1, mant_b};
                end
                next_state = NORMALIZE;
            end

            // Normaliza o resultado
            NORMALIZE: begin
                // Ajusta mantissa e expoente
                temp_mant = mant_prod_r[47] ? (mant_prod_r >> 1) : mant_prod_r;
                next_exp_sum = mant_prod_r[47] ? (exp_sum_r + 1) : exp_sum_r;
                has_bits = (temp_mant != 0);

                // Verifica condições especiais
                if ($signed(next_exp_sum) >= 255) begin
                    next_overflow = 1'b1;
                    next_product = {sign_res, 8'hFF, 23'h7FFFFF};
                end
                else if ($signed(next_exp_sum) <= 0) begin
                    next_underflow = 1'b1;
                    if ($signed(next_exp_sum) < -24 || !has_bits) begin
                        next_product = {sign_res, 31'b0};
                    end else begin
                        temp_mant = temp_mant >> (-next_exp_sum);
                        next_product = {sign_res, 8'h00, temp_mant[46:24]};
                        next_zero_sujo = 1'b1;
                    end
                end
                else begin
                    temp_exp = next_exp_sum[7:0];
                    next_product = {sign_res, temp_exp, temp_mant[45:23]};
                    next_round_toward_zero = 1'b1;
                end
                next_done = 1'b1;
                next_state = IDLE;
            end

            // Estado default
            default: next_state = IDLE;
        endcase
    end

    // Registradores síncronos
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset assíncrono
            state_r <= IDLE;
            product_r <= '0;
            mant_prod_r <= '0;
            exp_sum_r <= '0;
            done_r <= 1'b0;
            nan_r <= 1'b0;
            infinit_r <= 1'b0;
            overflow_r <= 1'b0;
            underflow_r <= 1'b0;
            zero_sujo_r <= 1'b0;
            round_toward_zero_r <= 1'b0;
            initial_counter <= 4'd10;  // 10 ciclos iniciais
            done_delay_counter <= 2'b00;
        end else begin
            // Atualização síncrona
            state_r <= next_state;
            product_r <= next_product;
            mant_prod_r <= next_mant_prod;
            exp_sum_r <= next_exp_sum;
            done_r <= next_done;
            nan_r <= next_nan;
            infinit_r <= next_infinit;
            overflow_r <= next_overflow;
            underflow_r <= next_underflow;
            zero_sujo_r <= next_zero_sujo;
            round_toward_zero_r <= next_round_toward_zero;

            // Atualização dos contadores
            if (initial_counter > 0)
                initial_counter <= initial_counter - 1;

            if (done_r)
                done_delay_counter <= 2'b10;
            else if (done_delay_counter > 0)
                done_delay_counter <= done_delay_counter - 1;
        end
    end

    // Atribuições das saídas
    assign product_o = product_r;                   // Resultado da multiplicação
    assign done_o = done_r;                         // Sinalização de conclusão
    assign nan_o = nan_r;                           // Flag de NaN
    assign infinit_o = infinit_r;                   // Flag de infinito
    assign overflow_o = overflow_r;                 // Flag de overflow
    assign underflow_o = underflow_r;               // Flag de underflow
    assign zero_sujo = zero_sujo_r;                 // Flag de zero sujo
    assign round_toward_zero = round_toward_zero_r; // Flag de arredondamento

endmodule