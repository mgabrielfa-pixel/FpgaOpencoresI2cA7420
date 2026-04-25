// ================================================================
//  temp_to_bcd.v  v4 - CORREGIDO (sin autoasignación de registros)
// ================================================================
module temp_to_bcd (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] temp_raw,
    input  wire        data_valid,
    output reg         sign,
    output reg  [3:0]  dig_hundreds,
    output reg  [3:0]  dig_tens,
    output reg  [3:0]  dig_units,
    output reg  [3:0]  dig_tenths,
    output reg  [3:0]  dig_hundredths
);
    function [7:0] frac_lut; input [3:0] n; case(n)
        4'd0: frac_lut=8'h00; 4'd1: frac_lut=8'h06; 4'd2: frac_lut=8'h12;
        4'd3: frac_lut=8'h18; 4'd4: frac_lut=8'h25; 4'd5: frac_lut=8'h31;
        4'd6: frac_lut=8'h37; 4'd7: frac_lut=8'h43; 4'd8: frac_lut=8'h50;
        4'd9: frac_lut=8'h56; 4'd10:frac_lut=8'h62; 4'd11:frac_lut=8'h68;
        4'd12:frac_lut=8'h75; 4'd13:frac_lut=8'h81; 4'd14:frac_lut=8'h87;
        default:frac_lut=8'h93;
    endcase endfunction

    // Variables locales (bloqueantes dentro de always)
    reg        l_sign;
    reg [3:0]  l_hh, l_tt, l_uu;
    reg [9:0]  l_int;
    reg [3:0]  l_frac;
    reg [9:0]  l_rem;
    reg [7:0]  l_flut;
    reg [12:0] l_abs;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sign<=0; dig_hundreds<=0; dig_tens<=0;
            dig_units<=0; dig_tenths<=0; dig_hundredths<=0;
        end else if (data_valid) begin
            // 1. Signo: usar bit15 del raw directamente
            l_sign = temp_raw[15];

            // 2. Valor absoluto de bits[15:3] en 13 bits
            if (l_sign) begin
                // Complemento a 2: (~val)+1 de 13 bits
                l_abs = (~temp_raw[15:3]) + 13'd1;
            end else begin
                l_abs = temp_raw[15:3];
            end

            // 3. Parte entera = l_abs / 16 (LSB=1/16°C)
            l_int  = l_abs[12:4];   // >> 4
            l_frac = l_abs[3:0];    // & 0xF

            // 4. BCD de parte entera
            if      (l_int >= 10'd200) l_hh = 4'd2;
            else if (l_int >= 10'd100) l_hh = 4'd1;
            else                       l_hh = 4'd0;

            l_rem = l_int - ({6'd0,l_hh} * 10'd100);

            if      (l_rem >= 10'd90) l_tt = 4'd9;
            else if (l_rem >= 10'd80) l_tt = 4'd8;
            else if (l_rem >= 10'd70) l_tt = 4'd7;
            else if (l_rem >= 10'd60) l_tt = 4'd6;
            else if (l_rem >= 10'd50) l_tt = 4'd5;
            else if (l_rem >= 10'd40) l_tt = 4'd4;
            else if (l_rem >= 10'd30) l_tt = 4'd3;
            else if (l_rem >= 10'd20) l_tt = 4'd2;
            else if (l_rem >= 10'd10) l_tt = 4'd1;
            else                      l_tt = 4'd0;

            l_uu  = l_rem[3:0] - (l_tt * 4'd10);
            l_flut = frac_lut(l_frac);

            // 5. Asignar salidas (non-blocking, todos desde variables locales)
            sign           <= l_sign;
            dig_hundreds   <= l_hh;
            dig_tens       <= l_tt;
            dig_units      <= l_uu;
            dig_tenths     <= l_flut[7:4];
            dig_hundredths <= l_flut[3:0];
        end
    end
endmodule
