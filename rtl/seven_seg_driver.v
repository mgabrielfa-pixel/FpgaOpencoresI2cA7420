module seven_seg_driver (
    input  wire       clk,
    input  wire       rst_n,

    input  wire       sign,
    input  wire [3:0] dig_hundreds,
    input  wire [3:0] dig_tens,
    input  wire [3:0] dig_units,
    input  wire [3:0] dig_tenths,
    input  wire [3:0] dig_hundredths,
    input  wire [3:0] error_code,

    output reg  [6:0] seg,
    output reg        dp,
    output reg  [7:0] an
);

    // ============================================================
    // IMPORTANTE:
    // Este driver ya está en el mismo orden que el XDC:
    //
    // seg[0] = CA
    // seg[1] = CB
    // seg[2] = CC
    // seg[3] = CD
    // seg[4] = CE
    // seg[5] = CF
    // seg[6] = CG
    //
    // Display de la Nexys 4 DDR: activo en bajo.
    // Segmento encendido = 0
    // Segmento apagado   = 1
    // ============================================================

    // ============================================================
    // Refresco del display
    // ============================================================
    reg [18:0] refresh_cnt;
    wire [2:0] digit_sel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            refresh_cnt <= 19'd0;
        else
            refresh_cnt <= refresh_cnt + 19'd1;
    end

    assign digit_sel = refresh_cnt[18:16];

    // ============================================================
    // Señales internas
    // ============================================================
    reg [3:0] digit_val;
    reg       show_dp;
    reg       blank_digit;

    // ============================================================
    // Decodificador 7 segmentos
    //
    // Orden físico del vector:
    // seg[6:0] = {CG, CF, CE, CD, CC, CB, CA}
    //
    // Equivalente:
    // bit 0 = a
    // bit 1 = b
    // bit 2 = c
    // bit 3 = d
    // bit 4 = e
    // bit 5 = f
    // bit 6 = g
    // ============================================================
    function [6:0] decode7seg;
        input [3:0] val;
        begin
            case (val)
                4'd0: decode7seg = 7'b1000000; // 0
                4'd1: decode7seg = 7'b1111001; // 1
                4'd2: decode7seg = 7'b0100100; // 2
                4'd3: decode7seg = 7'b0110000; // 3
                4'd4: decode7seg = 7'b0011001; // 4
                4'd5: decode7seg = 7'b0010010; // 5
                4'd6: decode7seg = 7'b0000010; // 6
                4'd7: decode7seg = 7'b1111000; // 7
                4'd8: decode7seg = 7'b0000000; // 8
                4'd9: decode7seg = 7'b0010000; // 9

                4'hA: decode7seg = 7'b0111111; // '-'
                4'hB: decode7seg = 7'b1111111; // blank
                4'hC: decode7seg = 7'b0000110; // E
                4'hD: decode7seg = 7'b0101111; // r aproximada

                default: decode7seg = 7'b1111111;
            endcase
        end
    endfunction

    // ============================================================
    // Selección del contenido de cada dígito
    //
    // Nexys 4 DDR:
    // AN[7] = dígito más izquierdo
    // AN[0] = dígito más derecho
    //
    // Se muestra:
    //
    //        centenas decenas unidades . décimas centésimas
    //
    // Ejemplo:
    //        2 5 . 1 2
    //
    // ============================================================
    always @(*) begin
        digit_val   = 4'hB;
        show_dp     = 1'b0;
        blank_digit = 1'b1;

        if (error_code != 4'd0) begin
            case (digit_sel)
                3'd0: begin digit_val = 4'hB; blank_digit = 1'b1; end
                3'd1: begin digit_val = 4'hB; blank_digit = 1'b1; end
                3'd2: begin digit_val = 4'hC; blank_digit = 1'b0; end // E
                3'd3: begin digit_val = 4'hD; blank_digit = 1'b0; end // r
                3'd4: begin digit_val = 4'hD; blank_digit = 1'b0; end // r
                3'd5: begin digit_val = error_code; blank_digit = 1'b0; end
                3'd6: begin digit_val = 4'hB; blank_digit = 1'b1; end
                3'd7: begin digit_val = 4'hB; blank_digit = 1'b1; end
                default: begin digit_val = 4'hB; blank_digit = 1'b1; end
            endcase
        end else begin
            case (digit_sel)

                // AN[7] = signo o apagado
                3'd0: begin
                    if (sign) begin
                        digit_val   = 4'hA; // '-'
                        blank_digit = 1'b0;
                    end else begin
                        digit_val   = 4'hB;
                        blank_digit = 1'b1;
                    end
                end

                // AN[6] = centenas
                3'd1: begin
                    if ((dig_hundreds == 4'd0) && !sign) begin
                        digit_val   = 4'hB;
                        blank_digit = 1'b1;
                    end else begin
                        digit_val   = dig_hundreds;
                        blank_digit = 1'b0;
                    end
                end

                // AN[5] = decenas
                3'd2: begin
                    if ((dig_hundreds == 4'd0) && 
                        (dig_tens == 4'd0) && 
                        !sign) begin
                        digit_val   = 4'hB;
                        blank_digit = 1'b1;
                    end else begin
                        digit_val   = dig_tens;
                        blank_digit = 1'b0;
                    end
                end

                // AN[4] = unidades con punto decimal
                3'd3: begin
                    digit_val   = dig_units;
                    show_dp     = 1'b1;
                    blank_digit = 1'b0;
                end

                // AN[3] = décimas
                3'd4: begin
                    digit_val   = dig_tenths;
                    blank_digit = 1'b0;
                end

                // AN[2] = centésimas
                3'd5: begin
                    digit_val   = dig_hundredths;
                    blank_digit = 1'b0;
                end

                // AN[1] apagado
                3'd6: begin
                    digit_val   = 4'hB;
                    blank_digit = 1'b1;
                end

                // AN[0] apagado
                3'd7: begin
                    digit_val   = 4'hB;
                    blank_digit = 1'b1;
                end

                default: begin
                    digit_val   = 4'hB;
                    blank_digit = 1'b1;
                end
            endcase
        end
    end

    // ============================================================
    // Salidas al display
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seg <= 7'b1111111;
            dp  <= 1'b1;
            an  <= 8'b11111111;
        end else begin

            if (blank_digit) begin
                seg <= 7'b1111111;
                dp  <= 1'b1;
            end else begin
                seg <= decode7seg(digit_val);
                dp  <= ~show_dp; // DP activo en bajo
            end

            case (digit_sel)
                3'd0: an <= 8'b01111111; // AN[7], izquierda
                3'd1: an <= 8'b10111111; // AN[6]
                3'd2: an <= 8'b11011111; // AN[5]
                3'd3: an <= 8'b11101111; // AN[4]
                3'd4: an <= 8'b11110111; // AN[3]
                3'd5: an <= 8'b11111011; // AN[2]
                3'd6: an <= 8'b11111101; // AN[1]
                3'd7: an <= 8'b11111110; // AN[0], derecha
                default: an <= 8'b11111111;
            endcase
        end
    end

endmodule