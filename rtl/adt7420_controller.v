`include "i2c_master_defines.v"

module adt7420_controller (
    input        clk,
    input        rst_n,          // reset activo en bajo

    // Salidas de temperatura
    output reg [15:0] temp_raw,  // dato crudo del sensor
    output            temp_sign, // signo de temperatura
    output reg        data_valid,
    output reg [ 3:0] error_code,

    // Interfaz Wishbone hacia i2c_master_top
    output reg [ 2:0] wb_adr,
    output reg [ 7:0] wb_dat_o,
    input      [ 7:0] wb_dat_i,
    output reg        wb_we,
    output reg        wb_stb,
    output reg        wb_cyc,
    input             wb_ack,

    // Estado para debug
    output reg [ 5:0] fsm_state
);

    // ============================================================
    // Dirección I2C del ADT7420 en Nexys 4 DDR
    // A1 = 1, A0 = 1  -> dirección 7 bits = 0x4B
    // ============================================================
    localparam ADT_ADDR_W = 8'h96;   // 0x4B << 1 | 0
    localparam ADT_ADDR_R = 8'h97;   // 0x4B << 1 | 1
    localparam ADT_REG_TMP = 8'h00;  // registro temperatura

    // ============================================================
    // Prescaler I2C para 100 kHz con clk = 100 MHz
    // PRER = (100e6 / (5*100e3)) - 1 = 199 = 0x00C7
    // ============================================================
    localparam PRER_LO_VAL = 8'hC7;
    localparam PRER_HI_VAL = 8'h00;

    // ============================================================
    // Registros Wishbone del core i2c_master_top
    // ============================================================
    localparam WB_PRER_LO = 3'b000;
    localparam WB_PRER_HI = 3'b001;
    localparam WB_CTR     = 3'b010;
    localparam WB_TXR_RXR = 3'b011;
    localparam WB_CR_SR   = 3'b100;

    // ============================================================
    // Bits de comando
    // ============================================================
    localparam CR_STA = 8'b1000_0000;
    localparam CR_STO = 8'b0100_0000;
    localparam CR_RD  = 8'b0010_0000;
    localparam CR_WR  = 8'b0001_0000;
    localparam CR_ACK = 8'b0000_1000;

    // ============================================================
    // Delay entre lecturas: 240 ms @ 100 MHz
    // ============================================================
    localparam DELAY_240MS = 25'd24_000_000;

    // ============================================================
    // FSM
    // ============================================================
    localparam [5:0]
        S_RESET        = 6'd0,
        S_INIT_PRER_LO = 6'd1,
        S_INIT_PRER_HI = 6'd2,
        S_INIT_CTR     = 6'd3,
        S_CHECK_BUSY   = 6'd4,
        S_WAIT_DELAY   = 6'd5,

        S_TX_ADDRW     = 6'd10,
        S_CMD_ADDRW    = 6'd11,
        S_WAIT_ADDRW   = 6'd12,
        S_CHK_ADDRW    = 6'd13,

        S_TX_REG       = 6'd14,
        S_CMD_REG      = 6'd15,
        S_WAIT_REG     = 6'd16,
        S_CHK_REG      = 6'd17,

        S_TX_ADDRR     = 6'd18,
        S_CMD_ADDRR    = 6'd19,
        S_WAIT_ADDRR   = 6'd20,
        S_CHK_ADDRR    = 6'd21,

        S_CMD_RDMSB    = 6'd22,
        S_WAIT_RDMSB   = 6'd23,
        S_GET_MSB      = 6'd24,

        S_CMD_RDLSB    = 6'd25,
        S_WAIT_RDLSB   = 6'd26,
        S_GET_LSB      = 6'd27,

        S_DONE         = 6'd28,
        S_ERROR        = 6'd29,
        S_WB_WAIT      = 6'd30;

    reg [5:0]  state, state_ret;
    reg [7:0]  msb_buf;
    reg [24:0] delay_cnt;   // FIX #1: 25 bits para alcanzar 24_000_000
    reg [7:0]  wb_rd_buf;

    assign temp_sign = temp_raw[15];

    // ============================================================
    // Lógica principal
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_RESET;
            state_ret  <= S_RESET;
            fsm_state  <= S_RESET;

            wb_adr     <= 3'b000;
            wb_dat_o   <= 8'h00;
            wb_we      <= 1'b0;
            wb_stb     <= 1'b0;
            wb_cyc     <= 1'b0;

            temp_raw   <= 16'h0000;
            data_valid <= 1'b0;
            error_code <= 4'd0;

            msb_buf    <= 8'h00;
            delay_cnt  <= 25'd0;   // FIX #1: 25 bits
            wb_rd_buf  <= 8'h00;
        end else begin
            data_valid <= 1'b0;

            case (state)

                // ------------------------------------------------
                // Reset / init
                // ------------------------------------------------
                S_RESET: begin
                    wb_stb <= 1'b0;
                    wb_cyc <= 1'b0;
                    wb_we  <= 1'b0;
                    state  <= S_INIT_PRER_LO;
                end

                S_INIT_PRER_LO: begin
                    wb_adr    <= WB_PRER_LO;
                    wb_dat_o  <= PRER_LO_VAL;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_INIT_PRER_HI;
                    state     <= S_WB_WAIT;
                end

                S_INIT_PRER_HI: begin
                    wb_adr    <= WB_PRER_HI;
                    wb_dat_o  <= PRER_HI_VAL;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_INIT_CTR;
                    state     <= S_WB_WAIT;
                end

                S_INIT_CTR: begin
                    wb_adr    <= WB_CTR;
                    wb_dat_o  <= 8'h80; // enable core
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_CHECK_BUSY;
                    state     <= S_WB_WAIT;
                end

                S_CHECK_BUSY: begin
                    wb_adr    <= WB_CR_SR;
                    wb_we     <= 1'b0;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_WAIT_DELAY;
                    state     <= S_WB_WAIT;
                end

                // ------------------------------------------------
                // Espera entre conversiones
                // ------------------------------------------------
                S_WAIT_DELAY: begin
                    delay_cnt <= delay_cnt + 25'd1;   // FIX #1: 25 bits
                    if (delay_cnt >= DELAY_240MS) begin
                        delay_cnt <= 25'd0;
                        state <= S_TX_ADDRW;
                    end
                end

                // ------------------------------------------------
                // START + dirección escritura
                // ------------------------------------------------
                S_TX_ADDRW: begin
                    wb_adr    <= WB_TXR_RXR;
                    wb_dat_o  <= ADT_ADDR_W;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_CMD_ADDRW;
                    state     <= S_WB_WAIT;
                end

                S_CMD_ADDRW: begin
                    wb_adr    <= WB_CR_SR;
                    wb_dat_o  <= CR_STA | CR_WR;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_WAIT_ADDRW;
                    state     <= S_WB_WAIT;
                end

                S_WAIT_ADDRW: begin
                    wb_adr    <= WB_CR_SR;
                    wb_we     <= 1'b0;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_CHK_ADDRW;
                    state     <= S_WB_WAIT;
                end

                S_CHK_ADDRW: begin
                    if (wb_rd_buf[1]) begin
                        state <= S_WAIT_ADDRW;   // TIP=1
                    end else if (wb_rd_buf[7]) begin
                        error_code <= 4'd1;      // RXACK=1
                        state <= S_ERROR;
                    end else begin
                        error_code <= 4'd0;
                        state <= S_TX_REG;
                    end
                end

                // ------------------------------------------------
                // Enviar puntero de registro 0x00
                // ------------------------------------------------
                S_TX_REG: begin
                    wb_adr    <= WB_TXR_RXR;
                    wb_dat_o  <= ADT_REG_TMP;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_CMD_REG;
                    state     <= S_WB_WAIT;
                end

                S_CMD_REG: begin
                    wb_adr    <= WB_CR_SR;
                    wb_dat_o  <= CR_WR;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_WAIT_REG;
                    state     <= S_WB_WAIT;
                end

                S_WAIT_REG: begin
                    wb_adr    <= WB_CR_SR;
                    wb_we     <= 1'b0;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_CHK_REG;
                    state     <= S_WB_WAIT;
                end

                S_CHK_REG: begin
                    if (wb_rd_buf[1]) begin
                        state <= S_WAIT_REG;
                    end else if (wb_rd_buf[7]) begin
                        error_code <= 4'd2;
                        state <= S_ERROR;
                    end else begin
                        state <= S_TX_ADDRR;
                    end
                end

                // ------------------------------------------------
                // Repeated START + dirección lectura
                // ------------------------------------------------
                S_TX_ADDRR: begin
                    wb_adr    <= WB_TXR_RXR;
                    wb_dat_o  <= ADT_ADDR_R;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_CMD_ADDRR;
                    state     <= S_WB_WAIT;
                end

                S_CMD_ADDRR: begin
                    wb_adr    <= WB_CR_SR;
                    wb_dat_o  <= CR_STA | CR_WR;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_WAIT_ADDRR;
                    state     <= S_WB_WAIT;
                end

                S_WAIT_ADDRR: begin
                    wb_adr    <= WB_CR_SR;
                    wb_we     <= 1'b0;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_CHK_ADDRR;
                    state     <= S_WB_WAIT;
                end

                S_CHK_ADDRR: begin
                    if (wb_rd_buf[1]) begin
                        state <= S_WAIT_ADDRR;
                    end else if (wb_rd_buf[7]) begin
                        error_code <= 4'd3;
                        state <= S_ERROR;
                    end else begin
                        state <= S_CMD_RDMSB;
                    end
                end

                // ------------------------------------------------
                // Leer MSB
                // ------------------------------------------------
                S_CMD_RDMSB: begin
                    wb_adr    <= WB_CR_SR;
                    wb_dat_o  <= CR_RD | CR_ACK;   // ACK después del primer byte
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_WAIT_RDMSB;
                    state     <= S_WB_WAIT;
                end

                S_WAIT_RDMSB: begin
                    wb_adr    <= WB_CR_SR;
                    wb_we     <= 1'b0;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_GET_MSB;
                    state     <= S_WB_WAIT;
                end

                S_GET_MSB: begin
                    if (wb_rd_buf[1]) begin
                        state <= S_WAIT_RDMSB;
                    end else begin
                        wb_adr    <= WB_TXR_RXR;
                        wb_we     <= 1'b0;
                        wb_stb    <= 1'b1;
                        wb_cyc    <= 1'b1;
                        state_ret <= S_CMD_RDLSB;
                        state     <= S_WB_WAIT;
                    end
                end

                // ------------------------------------------------
                // Leer LSB
                // ------------------------------------------------
                S_CMD_RDLSB: begin
                    msb_buf   <= wb_rd_buf;
                    wb_adr    <= WB_CR_SR;
                    wb_dat_o  <= CR_RD | CR_ACK | CR_STO;   // FIX #2: NACK + STOP (último byte)
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_WAIT_RDLSB;
                    state     <= S_WB_WAIT;
                end

                S_WAIT_RDLSB: begin
                    wb_adr    <= WB_CR_SR;
                    wb_we     <= 1'b0;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_GET_LSB;
                    state     <= S_WB_WAIT;
                end

                S_GET_LSB: begin
                    if (wb_rd_buf[1]) begin
                        state <= S_WAIT_RDLSB;
                    end else begin
                        wb_adr    <= WB_TXR_RXR;
                        wb_we     <= 1'b0;
                        wb_stb    <= 1'b1;
                        wb_cyc    <= 1'b1;
                        state_ret <= S_DONE;
                        state     <= S_WB_WAIT;
                    end
                end

                // ------------------------------------------------
                // Dato listo
                // ------------------------------------------------
                S_DONE: begin
                    temp_raw   <= {msb_buf, wb_rd_buf};
                    data_valid <= 1'b1;
                    error_code <= 4'd0;
                    delay_cnt  <= 25'd0;   // FIX #1: 25 bits
                    state      <= S_WAIT_DELAY;
                end

                // ------------------------------------------------
                // Error -> mandar STOP
                // ------------------------------------------------
                S_ERROR: begin
                    wb_adr    <= WB_CR_SR;
                    wb_dat_o  <= CR_STO;
                    wb_we     <= 1'b1;
                    wb_stb    <= 1'b1;
                    wb_cyc    <= 1'b1;
                    state_ret <= S_WAIT_DELAY;
                    state     <= S_WB_WAIT;
                end

                // ------------------------------------------------
                // Espera de ACK Wishbone
                // ------------------------------------------------
                S_WB_WAIT: begin
                    if (wb_ack) begin
                        wb_rd_buf <= wb_dat_i;
                        wb_stb    <= 1'b0;
                        wb_cyc    <= 1'b0;
                        wb_we     <= 1'b0;
                        state     <= state_ret;
                    end
                end

                default: begin
                    state <= S_RESET;
                end
            endcase

            fsm_state <= state;
        end
    end

endmodule