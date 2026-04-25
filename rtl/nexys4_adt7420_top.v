// ================================================================
//  nexys4_adt7420_top.v
//  Top-level del sistema I2C + ADT7420 para Nexys 4 DDR
//
//  Correcciones importantes:
//    1. El display ya NO invierte los bits SEG en el top.
//       Ahora seven_seg_driver usa el mismo orden que el XDC:
//       SEG[0]=CA, SEG[1]=CB, ..., SEG[6]=CG.
//
//    2. Se separa temp_sign_raw de bcd_sign.
//       Antes había riesgo de dos drivers sobre la misma señal.
// ================================================================

module nexys4_adt7420_top (
    input  wire        CLK100MHZ,
    input  wire        BTNC,

    // I2C ADT7420 integrado
    inout  wire        I2C_SCL,
    inout  wire        I2C_SDA,

    // Display 7 segmentos
    output wire [6:0]  SEG,
    output wire        DP,
    output wire [7:0]  AN,

    // LEDs de debug
    output wire [7:0]  LED
);

    // ============================================================
    // Reset
    // BTNC es activo alto físicamente.
    // El sistema interno usa rst_n activo bajo.
    // ============================================================
    wire rst_n = ~BTNC;

    // ============================================================
    // Wishbone entre controlador ADT7420 e i2c_master_top
    // ============================================================
    wire [2:0] wb_adr;
    wire [7:0] wb_dat_to_i2c;
    wire [7:0] wb_dat_from_i2c;
    wire       wb_we;
    wire       wb_stb;
    wire       wb_cyc;
    wire       wb_ack;
    wire       wb_inta;

    // ============================================================
    // Señales I2C internas
    // ============================================================
    wire scl_pad_i;
    wire scl_pad_o;
    wire scl_padoen_o;

    wire sda_pad_i;
    wire sda_pad_o;
    wire sda_padoen_o;

    // ============================================================
    // Temperatura
    // ============================================================
    wire [15:0] temp_raw;
    wire        temp_sign_raw;
    wire        data_valid;
    wire [3:0]  error_code;
    wire [5:0]  fsm_state;

    // ============================================================
    // BCD
    // ============================================================
    wire        bcd_sign;
    wire [3:0] dig_hundreds;
    wire [3:0] dig_tens;
    wire [3:0] dig_units;
    wire [3:0] dig_tenths;
    wire [3:0] dig_hundredths;

    // ============================================================
    // IOBUF para I2C open-drain
    //
    // T = 1 -> alta impedancia
    // T = 0 -> manejar línea
    //
    // El core OpenCores maneja open-drain usando padoen_o.
    // ============================================================
    IOBUF scl_iobuf (
        .IO (I2C_SCL),
        .I  (scl_pad_o),
        .O  (scl_pad_i),
        .T  (scl_padoen_o)
    );

    IOBUF sda_iobuf (
        .IO (I2C_SDA),
        .I  (sda_pad_o),
        .O  (sda_pad_i),
        .T  (sda_padoen_o)
    );

    // ============================================================
    // I2C Master OpenCores
    // ============================================================
    i2c_master_top #(
        .ARST_LVL (1'b0)
    ) i2c_master (
        .wb_clk_i     (CLK100MHZ),
        .wb_rst_i     (1'b0),
        .arst_i       (rst_n),

        .wb_adr_i     (wb_adr),
        .wb_dat_i     (wb_dat_to_i2c),
        .wb_dat_o     (wb_dat_from_i2c),
        .wb_we_i      (wb_we),
        .wb_stb_i     (wb_stb),
        .wb_cyc_i     (wb_cyc),
        .wb_ack_o     (wb_ack),
        .wb_inta_o    (wb_inta),

        .scl_pad_i    (scl_pad_i),
        .scl_pad_o    (scl_pad_o),
        .scl_padoen_o (scl_padoen_o),

        .sda_pad_i    (sda_pad_i),
        .sda_pad_o    (sda_pad_o),
        .sda_padoen_o (sda_padoen_o)
    );

    // ============================================================
    // Controlador del ADT7420
    // ============================================================
    adt7420_controller fsm_ctrl (
        .clk        (CLK100MHZ),
        .rst_n      (rst_n),

        .temp_raw   (temp_raw),
        .temp_sign  (temp_sign_raw),
        .data_valid (data_valid),
        .error_code (error_code),

        .wb_adr     (wb_adr),
        .wb_dat_o   (wb_dat_to_i2c),
        .wb_dat_i   (wb_dat_from_i2c),
        .wb_we      (wb_we),
        .wb_stb     (wb_stb),
        .wb_cyc     (wb_cyc),
        .wb_ack     (wb_ack),

        .fsm_state  (fsm_state)
    );

    // ============================================================
    // Conversión de temperatura cruda ADT7420 a BCD
    // ============================================================
    temp_to_bcd bcd_conv (
        .clk            (CLK100MHZ),
        .rst_n          (rst_n),
        .temp_raw       (temp_raw),
        .data_valid     (data_valid),

        .sign           (bcd_sign),
        .dig_hundreds   (dig_hundreds),
        .dig_tens       (dig_tens),
        .dig_units      (dig_units),
        .dig_tenths     (dig_tenths),
        .dig_hundredths (dig_hundredths)
    );

    // ============================================================
    // Display 7 segmentos
    //
    // IMPORTANTE:
    // Aquí ya NO se invierte SEG.
    // El seven_seg_driver corregido ya entrega:
    //
    // SEG[0] = CA
    // SEG[1] = CB
    // SEG[2] = CC
    // SEG[3] = CD
    // SEG[4] = CE
    // SEG[5] = CF
    // SEG[6] = CG
    // ============================================================
    seven_seg_driver seg_drv (
        .clk            (CLK100MHZ),
        .rst_n          (rst_n),

        .sign           (bcd_sign),
        .dig_hundreds   (dig_hundreds),
        .dig_tens       (dig_tens),
        .dig_units      (dig_units),
        .dig_tenths     (dig_tenths),
        .dig_hundredths (dig_hundredths),
        .error_code     (error_code),

        .seg            (SEG),
        .dp             (DP),
        .an             (AN)
    );

    // ============================================================
    // LEDs de debug
    // ============================================================
    assign LED[3:0] = error_code;
    assign LED[4]   = data_valid;
    assign LED[5]   = wb_inta;
    assign LED[6]   = temp_sign_raw;
    assign LED[7]   = |fsm_state;

endmodule