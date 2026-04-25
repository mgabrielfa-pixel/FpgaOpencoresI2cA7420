// ================================================================
//  nexys4_adt7420_top.v
//  Top-level del sistema I2C + ADT7420 para Nexys 4 DDR
//
//  Función:
//    - Controla el core OpenCores I2C mediante Wishbone.
//    - Lee la temperatura del ADT7420 integrado.
//    - Convierte el dato crudo a BCD.
//    - Muestra la temperatura en display de 7 segmentos.
//    - Saca señales internas por PMOD_DBG[7:0] para osciloscopio.
//
//  Señales PMOD_DBG:
//    PMOD_DBG[0] = SCL leído desde el pin I2C
//    PMOD_DBG[1] = SDA leído desde el pin I2C
//    PMOD_DBG[2] = core intentando manejar SCL en bajo
//    PMOD_DBG[3] = core intentando manejar SDA en bajo
//    PMOD_DBG[4] = transacción I2C activa
//    PMOD_DBG[5] = data_valid estirado
//    PMOD_DBG[6] = wb_ack
//    PMOD_DBG[7] = error_code != 0
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
    output wire [7:0]  LED,

    // Salidas de depuración hacia PMOD JA
    output wire [7:0]  PMOD_DBG
);

    // ============================================================
    // Reset
    // BTNC es activo alto físicamente.
    // Internamente usamos rst_n activo bajo.
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
    // Driver display 7 segmentos
    //
    // IMPORTANTE:
    // Este top asume que seven_seg_driver ya entrega:
    //
    // SEG[0] = CA
    // SEG[1] = CB
    // SEG[2] = CC
    // SEG[3] = CD
    // SEG[4] = CE
    // SEG[5] = CF
    // SEG[6] = CG
    //
    // Por eso aquí NO se invierte el bus SEG.
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

    // ============================================================
    // Señal data_valid estirada para osciloscopio
    //
    // data_valid original dura 1 ciclo de reloj:
    // 1 ciclo @ 100 MHz = 10 ns
    //
    // Eso es muy estrecho para verlo cómodamente en osciloscopio.
    // Aquí se estira a ~5 ms.
    // ============================================================
    reg [19:0] data_valid_cnt;

    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            data_valid_cnt <= 20'd0;
        end else begin
            if (data_valid)
                data_valid_cnt <= 20'd500_000;   // ~5 ms @ 100 MHz
            else if (data_valid_cnt != 20'd0)
                data_valid_cnt <= data_valid_cnt - 20'd1;
        end
    end

    wire data_valid_dbg = (data_valid_cnt != 20'd0);

    // FSM en transacción I2C.
    // En tu controlador, los estados de transacción van aprox. de 10 a 28.
    wire i2c_active_dbg = (fsm_state >= 6'd10) && (fsm_state <= 6'd28);

    // ============================================================
    // Bus de depuración
    // ============================================================
    wire [7:0] debug_bus;

    assign debug_bus[0] = scl_pad_i;              // SCL real leído desde el pin
    assign debug_bus[1] = sda_pad_i;              // SDA real leído desde el pin

    assign debug_bus[2] = ~scl_padoen_o;          // 1 = core maneja SCL en bajo
    assign debug_bus[3] = ~sda_padoen_o;          // 1 = core maneja SDA en bajo

    assign debug_bus[4] = i2c_active_dbg;         // transacción I2C activa
    assign debug_bus[5] = data_valid_dbg;         // data_valid estirado
    assign debug_bus[6] = wb_ack;                 // ACK Wishbone
    assign debug_bus[7] = (error_code != 4'd0);   // error I2C

    // ============================================================
    // Dos NOT por cada señal antes de salir al PMOD
    // ============================================================
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : GEN_DEBUG_BUFFERS
            debug_not2_buffer u_debug_buf (
                .sig_in  (debug_bus[i]),
                .sig_out (PMOD_DBG[i])
            );
        end
    endgenerate

endmodule