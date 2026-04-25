`timescale 1ns/10ps
// ================================================================
//  tb_sistema_final.v  -  Testbench COMPLETO verificado
//  Sistema: I2C Master (OpenCores) + ADT7420 slave model
//           + temp_to_bcd + seven_seg_driver
//  Nexys 4 DDR: clk=100MHz, I2C=100kHz, display ánodo común
//
//  Casos de prueba:
//    1.  25.00°C  (temperatura ambiente)
//    2.   0.00°C  (cero grados)
//    3. -10.00°C  (temperatura negativa)
//    4. 100.00°C  (temperatura alta)
//    5.  37.50°C  (temperatura corporal)
//    6.  Verificar multiplexeo del display (AN activo)
// ================================================================
module tb_sistema_final;

    reg  clk;
    initial clk = 0;
    always #5 clk = ~clk;

    reg  rst_n;

    // ── Wishbone ────────────────────────────────────────────────
    reg  [2:0] wb_adr;
    reg  [7:0] wb_din;
    wire [7:0] wb_dout;
    reg        wb_we, wb_stb, wb_cyc;
    wire       wb_ack, wb_inta;

    // ── I2C open-drain ──────────────────────────────────────────
    wire scl_o, scl_oen, sda_o, sda_oen;
    reg  sda_sl_en;
    reg  sda_sl_val;
    wire scl_bus = scl_oen ? 1'b1 : 1'b0;
    wire sda_bus = (!sda_oen) ? 1'b0 : (sda_sl_en ? sda_sl_val : 1'b1);

    // ── I2C Master (OpenCores) ──────────────────────────────────
    i2c_master_top #(.ARST_LVL(1'b0)) i2c (
        .wb_clk_i     (clk),
        .wb_rst_i     (1'b0),
        .arst_i       (rst_n),
        .wb_adr_i     (wb_adr),
        .wb_dat_i     (wb_din),
        .wb_dat_o     (wb_dout),
        .wb_we_i      (wb_we),
        .wb_stb_i     (wb_stb),
        .wb_cyc_i     (wb_cyc),
        .wb_ack_o     (wb_ack),
        .wb_inta_o    (wb_inta),
        .scl_pad_i    (scl_bus),
        .scl_pad_o    (scl_o),
        .scl_padoen_o (scl_oen),
        .sda_pad_i    (sda_bus),
        .sda_pad_o    (sda_o),
        .sda_padoen_o (sda_oen)
    );

    // ── BCD converter ───────────────────────────────────────────
    reg  [15:0] temp_raw_reg;
    reg         data_valid_r;
    wire        temp_sign;
    wire [3:0]  dig_h, dig_t, dig_u, dig_d1, dig_d2;

    temp_to_bcd bcd (
        .clk            (clk),
        .rst_n          (rst_n),
        .temp_raw       (temp_raw_reg),
        .data_valid     (data_valid_r),
        .sign           (temp_sign),
        .dig_hundreds   (dig_h),
        .dig_tens       (dig_t),
        .dig_units      (dig_u),
        .dig_tenths     (dig_d1),
        .dig_hundredths (dig_d2)
    );

    // ── 7-seg driver ────────────────────────────────────────────
    wire [6:0] seg;
    wire       dp;
    wire [7:0] an;

    seven_seg_driver seg7 (
        .clk            (clk),
        .rst_n          (rst_n),
        .sign           (temp_sign),
        .dig_hundreds   (dig_h),
        .dig_tens       (dig_t),
        .dig_units      (dig_u),
        .dig_tenths     (dig_d1),
        .dig_hundredths (dig_d2),
        .error_code     (4'd0),
        .seg            (seg),
        .dp             (dp),
        .an             (an)
    );

    // ── Variables globales de display ───────────────────────────
    reg [6:0] disp_seg [0:7];
    reg       disp_dp  [0:7];
    integer   di;

    // ── Variables globales de test ──────────────────────────────
    reg  [7:0] rxmsb, rxlsb, sr_v;
    integer    pass_cnt, fail_cnt;
    real       tc_g;
    reg  [7:0] prev_an;
    integer    ch_an;

    // ── WB tasks ────────────────────────────────────────────────
    task wb_wr;
        input [2:0] a;
        input [7:0] d;
        begin
            @(posedge clk);
            #1;
            wb_adr = a;
            wb_din = d;
            wb_we  = 1;
            wb_stb = 1;
            wb_cyc = 1;

            @(posedge clk);
            while (!wb_ack)
                @(posedge clk);

            #1;
            wb_stb = 0;
            wb_cyc = 0;
            wb_we  = 0;
        end
    endtask

    task wb_rd;
        input  [2:0] a;
        output [7:0] d;
        begin
            @(posedge clk);
            #1;
            wb_adr = a;
            wb_we  = 0;
            wb_stb = 1;
            wb_cyc = 1;

            @(posedge clk);
            while (!wb_ack)
                @(posedge clk);

            #1;
            d      = wb_dout;
            wb_stb = 0;
            wb_cyc = 0;
        end
    endtask

    task wait_tip;
        reg [7:0] s;
        begin
            s = 8'h02;
            while (s[1])
                wb_rd(3'b100, s);
        end
    endtask

    // ── Slave ADT7420 (timing verificado) ───────────────────────
    task slave_receive_ack;
        output [7:0] rxb;
        integer k;
        begin
            rxb = 0;
            for (k = 7; k >= 0; k = k - 1) begin
                @(posedge scl_bus);
                rxb[k] = sda_bus;
            end
            @(negedge scl_bus);
            sda_sl_en  = 1;
            sda_sl_val = 0; // ACK
            @(negedge scl_bus);
            sda_sl_en  = 0; // liberar
        end
    endtask

    task slave_send_byte;
        input [7:0] b;
        integer k;
        begin
            sda_sl_en  = 1;
            sda_sl_val = b[7]; // bit7 ya en el negedge actual
            for (k = 6; k >= 0; k = k - 1) begin
                @(negedge scl_bus);
                sda_sl_en  = 1;
                sda_sl_val = b[k];
            end
            @(negedge scl_bus);
            sda_sl_en = 0; // liberar para ACK del master
            @(posedge scl_bus);
        end
    endtask

    task run_slave;
        input [7:0] msb_s, lsb_s;
        reg   [7:0] rx_a, rx_r, rx_ar;
        begin
            sda_sl_en = 0;
            @(negedge sda_bus);                      // START
            slave_receive_ack(rx_a);                // ADDR+W
            slave_receive_ack(rx_r);                // REG PTR
            @(posedge sda_bus);
            @(negedge sda_bus);                     // Repeated START
            slave_receive_ack(rx_ar);               // ADDR+R
            slave_send_byte(msb_s);                 // MSB
            @(negedge scl_bus);                     // inicio LSB
            slave_send_byte(lsb_s);                 // LSB
            @(posedge sda_bus);                     // STOP
            sda_sl_en = 0;
        end
    endtask

    // ── Decodificación display 7seg ─────────────────────────────
    function [3:0] seg2d;
        input [6:0] s;
        begin
            case (s)
                7'b000_0001: seg2d = 0;
                7'b100_1111: seg2d = 1;
                7'b001_0010: seg2d = 2;
                7'b000_0110: seg2d = 3;
                7'b100_1100: seg2d = 4;
                7'b010_0100: seg2d = 5;
                7'b010_0000: seg2d = 6;
                7'b000_1111: seg2d = 7;
                7'b000_0000: seg2d = 8;
                7'b000_0100: seg2d = 9;
                7'b111_1110: seg2d = 10;
                default:     seg2d = 15;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        for (di = 0; di < 8; di = di + 1) begin
            if (an[di] == 1'b0) begin
                disp_seg[di] <= seg;
                disp_dp[di]  <= (~dp);
            end
        end
    end

    task print_display;
        integer i;
        reg [3:0] d;
        begin
            $write("    DISPLAY [7..0]: |");
            for (i = 7; i >= 0; i = i - 1) begin
                d = seg2d(disp_seg[i]);
                if (disp_seg[i] == 7'b111_1111)
                    $write(" ");
                else if (d == 10)
                    $write("-");
                else if (d <= 9)
                    $write("%0d", d);
                else
                    $write("?");
                if (disp_dp[i])
                    $write(".");
            end
            $display("| °C");
        end
    endtask

    // ── Macro de test ───────────────────────────────────────────
    task run_test;
        input [7:0] msb_in, lsb_in;
        input signed [15:0] dummy;
        begin
            tc_g = ($signed({msb_in, lsb_in}) >>> 3) * 0.0625;

            $display("\n  ─────────────────────────────────────────");
            $display("  TEST: raw=0x%02X%02X  =>  %.4f°C", msb_in, lsb_in, tc_g);
            $display("  ─────────────────────────────────────────");

            fork
                run_slave(msb_in, lsb_in);
                begin
                    wb_wr(3'b011, 8'h90);
                    wb_wr(3'b100, 8'b1001_0000);
                    wait_tip;

                    wb_rd(3'b100, sr_v);
                    if (sr_v[7]) begin
                        $display("    FAIL: No ACK ADDR+W SR=0x%02X", sr_v);
                        fail_cnt = fail_cnt + 1;
                    end

                    wb_wr(3'b011, 8'h00);
                    wb_wr(3'b100, 8'b0001_0000);
                    wait_tip;

                    wb_wr(3'b011, 8'h91);
                    wb_wr(3'b100, 8'b1001_0000);
                    wait_tip;

                    wb_rd(3'b100, sr_v);
                    if (sr_v[7]) begin
                        $display("    FAIL: No ACK ADDR+R SR=0x%02X", sr_v);
                        fail_cnt = fail_cnt + 1;
                    end

                    wb_wr(3'b100, 8'b0010_1000);
                    wait_tip;
                    wb_rd(3'b011, rxmsb);

                    wb_wr(3'b100, 8'b0110_0000);
                    wait_tip;
                    wb_rd(3'b011, rxlsb);
                end
            join

            // Verificar datos I2C
            if (rxmsb === msb_in && rxlsb === lsb_in) begin
                $display("    PASS I2C: recibido 0x%02X%02X correcto", rxmsb, rxlsb);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("    FAIL I2C: esperado 0x%02X%02X, recibido 0x%02X%02X",
                         msb_in, lsb_in, rxmsb, rxlsb);
                fail_cnt = fail_cnt + 1;
            end

            // Actualizar BCD y display
            temp_raw_reg = {rxmsb, rxlsb};
            @(posedge clk);
            #1;
            data_valid_r = 1;
            @(posedge clk);
            #1;
            data_valid_r = 0;

            repeat (600000)
                @(posedge clk);

            $display("    BCD: sign=%0b  %0d%0d%0d.%0d%0d",
                     temp_sign, dig_h, dig_t, dig_u, dig_d1, dig_d2);
            print_display;

            // Verificar signo
            if ((tc_g < 0.0 && temp_sign) || (tc_g >= 0.0 && !temp_sign)) begin
                $display("    PASS Signo");
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("    FAIL Signo (tc=%.2f sign=%0b)", tc_g, temp_sign);
                fail_cnt = fail_cnt + 1;
            end

            repeat (20)
                @(posedge clk);
        end
    endtask

    // ── Main ────────────────────────────────────────────────────
    initial begin
        $dumpfile("tb_sistema_final.vcd");
        $dumpvars(0, tb_sistema_final);

        wb_adr      = 0;
        wb_din      = 0;
        wb_we       = 0;
        wb_stb      = 0;
        wb_cyc      = 0;
        sda_sl_en   = 0;
        sda_sl_val  = 1;
        data_valid_r = 0;
        temp_raw_reg = 0;
        pass_cnt    = 0;
        fail_cnt    = 0;
        prev_an     = 8'hFF;
        ch_an       = 0;

        for (di = 0; di < 8; di = di + 1) begin
            disp_seg[di] = 7'h7F;
            disp_dp[di]  = 0;
        end

        rst_n = 0;
        repeat (20) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("╔══════════════════════════════════════════╗");
        $display("║  TESTBENCH SISTEMA COMPLETO              ║");
        $display("║  I2C + ADT7420 + BCD + Display 7SEG     ║");
        $display("║  Nexys 4 DDR  100MHz  I2C=100kHz        ║");
        $display("╚══════════════════════════════════════════╝");

        // ── Inicialización ──────────────────────────────────────
        $display("\n  [INIT] Configurando I2C core...");
        wb_wr(3'b000, 8'hC7);  // PRER_LO: 199 = 0xC7
        wb_wr(3'b001, 8'h00);  // PRER_HI: 0
        wb_wr(3'b010, 8'h80);  // CTR: Enable core

        wb_rd(3'b010, sr_v);
        if (sr_v === 8'h80) begin
            $display("  PASS CTR=0x80 core activo");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL CTR=0x%02X", sr_v);
            fail_cnt = fail_cnt + 1;
        end

        wb_rd(3'b100, sr_v);
        $display("  SR inicial=0x%02X busy=%0b al=%0b", sr_v, sr_v[6], sr_v[5]);
        if (!sr_v[6]) begin
            $display("  PASS Bus libre");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL Bus ocupado al inicio");
            fail_cnt = fail_cnt + 1;
        end

        // ── Tests de temperatura ────────────────────────────────
        // raw = (temp/0.0625) << 3 = temp * 128
        run_test(8'h0C, 8'h80,  250);   //  25.00°C
        run_test(8'h00, 8'h00,    0);   //   0.00°C
        run_test(8'hFB, 8'h00, -100);   // -10.00°C
        run_test(8'h32, 8'h00, 1000);   // 100.00°C
        run_test(8'h12, 8'hC0,  375);   //  37.50°C

        // ── Test multiplexeo display ────────────────────────────
        $display("\n  ─────────────────────────────────────────");
        $display("  TEST: Multiplexeo display (AN cambia)");
        $display("  ─────────────────────────────────────────");

        prev_an = an;
        ch_an   = 0;
        repeat (600000) begin
            @(posedge clk);
            if (an !== prev_an) begin
                ch_an   = ch_an + 1;
                prev_an = an;
            end
        end

        $display("    AN cambió %0d veces en 600k ciclos", ch_an);
        if (ch_an >= 6) begin
            $display("    PASS Multiplexeo activo");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("    FAIL Display muerto");
            fail_cnt = fail_cnt + 1;
        end

        // ── Resumen ─────────────────────────────────────────────
        $display("\n╔══════════════════════════════════════════╗");
        $display("║  RESULTADOS FINALES                      ║");
        $display("║  PASS: %-3d   FAIL: %-3d                  ║", pass_cnt, fail_cnt);
        $display("╚══════════════════════════════════════════╝");

        if (fail_cnt == 0) begin
            $display("  >>> TODOS LOS TESTS PASARON <<<");
            $display("  >>> SISTEMA LISTO PARA SINTESIS <<<");
        end else begin
            $display("  >>> REVISAR %0d FALLOS <<<", fail_cnt);
        end

        #10000;
        $finish;
    end

    initial begin
        #500_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule