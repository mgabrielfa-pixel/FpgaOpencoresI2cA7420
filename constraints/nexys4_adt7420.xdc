# ================================================================
# nexys4_adt7420.xdc
# Nexys 4 DDR + ADT7420 interno + display 7 segmentos + PMOD debug
# ================================================================

# ================================================================
# Reloj principal 100 MHz
# ================================================================
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports { CLK100MHZ }]

# ================================================================
# Reset - BTNC
# ================================================================
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { BTNC }]

# ================================================================
# I2C ADT7420 interno
# SCL = C14
# SDA = C15
# ================================================================
set_property -dict { PACKAGE_PIN C14 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 4 PULLUP TRUE } [get_ports { I2C_SCL }]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 4 PULLUP TRUE } [get_ports { I2C_SDA }]

# ================================================================
# Display 7 segmentos
#
# SEG[0] = CA
# SEG[1] = CB
# SEG[2] = CC
# SEG[3] = CD
# SEG[4] = CE
# SEG[5] = CF
# SEG[6] = CG
# ================================================================
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { SEG[0] }]
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports { SEG[1] }]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports { SEG[2] }]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports { SEG[3] }]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { SEG[4] }]
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { SEG[5] }]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports { SEG[6] }]

# Punto decimal
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports { DP }]

# ================================================================
# Ánodos del display
# AN[7] = izquierda
# AN[0] = derecha
# ================================================================
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { AN[0] }]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { AN[1] }]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { AN[2] }]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports { AN[3] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { AN[4] }]
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { AN[5] }]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { AN[6] }]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports { AN[7] }]

# ================================================================
# LEDs de debug
# ================================================================
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { LED[0] }]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { LED[1] }]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports { LED[2] }]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { LED[3] }]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { LED[4] }]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { LED[5] }]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { LED[6] }]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { LED[7] }]

# ================================================================
# PMOD JA - señales de depuración para osciloscopio
#
# PMOD_DBG[0] = SCL leído desde el pin I2C
# PMOD_DBG[1] = SDA leído desde el pin I2C
# PMOD_DBG[2] = core intentando manejar SCL en bajo
# PMOD_DBG[3] = core intentando manejar SDA en bajo
# PMOD_DBG[4] = transacción I2C activa
# PMOD_DBG[5] = data_valid estirado
# PMOD_DBG[6] = wb_ack
# PMOD_DBG[7] = error_code != 0
#
# Pines del PMOD JA:
# JA1  = C17 -> PMOD_DBG[0]
# JA2  = D18 -> PMOD_DBG[1]
# JA3  = E18 -> PMOD_DBG[2]
# JA4  = G17 -> PMOD_DBG[3]
# JA7  = D17 -> PMOD_DBG[4]
# JA8  = E17 -> PMOD_DBG[5]
# JA9  = F18 -> PMOD_DBG[6]
# JA10 = G18 -> PMOD_DBG[7]
# ================================================================
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports { PMOD_DBG[0] }]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports { PMOD_DBG[1] }]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports { PMOD_DBG[2] }]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports { PMOD_DBG[3] }]

set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports { PMOD_DBG[4] }]
set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports { PMOD_DBG[5] }]
set_property -dict { PACKAGE_PIN F18 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports { PMOD_DBG[6] }]
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports { PMOD_DBG[7] }]

# ================================================================
# Timing I2C
# Las líneas SCL/SDA no se analizan como rutas síncronas internas.
# ================================================================
set_false_path -from [get_ports { I2C_SCL I2C_SDA }]
set_false_path -to   [get_ports { I2C_SCL I2C_SDA }]