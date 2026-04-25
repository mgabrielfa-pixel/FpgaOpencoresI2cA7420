# FPGA OpenCores I2C ADT7420 Temperature Monitor

Este proyecto implementa y valida el funcionamiento del núcleo **OpenCores I2C Master** en una FPGA **Nexys 4 DDR**, usando comunicación I2C con el sensor de temperatura **ADT7420** integrado en la tarjeta.

El sistema lee la temperatura por I2C, convierte el dato crudo a formato decimal BCD y muestra el resultado en el display de 7 segmentos. Además, se agregaron salidas de depuración por **PMOD JA** para observar señales internas con un osciloscopio.

---

## Objetivo del proyecto

Comprobar el funcionamiento del núcleo **OpenCores I2C Master** mediante una aplicación real: la comunicación con el sensor ADT7420 por I2C y la visualización de la temperatura en el display de la FPGA.

El proyecto permite validar:

- Configuración del core I2C mediante interfaz tipo Wishbone.
- Comunicación I2C con el sensor ADT7420.
- Lectura del registro de temperatura.
- Conversión de temperatura cruda a BCD.
- Visualización en display de 7 segmentos.
- Depuración de señales internas mediante PMOD y osciloscopio.
- Uso correcto de líneas I2C tipo open-drain mediante `IOBUF`.

---

## Plataforma utilizada

| Elemento | Descripción |
|---|---|
| Tarjeta FPGA | Digilent Nexys 4 DDR |
| FPGA | Xilinx Artix-7 |
| Sensor | ADT7420 integrado |
| Interfaz | I2C |
| Reloj del sistema | 100 MHz |
| Frecuencia I2C | 100 kHz |
| Lenguaje | Verilog HDL |
| Herramienta | Xilinx Vivado |

---

## Estructura del repositorio

```text
FpgaOpencoresI2cA7420/
│
├── README.md
├── .gitignore
│
├── rtl/
│   ├── nexys4_adt7420_top.v
│   ├── adt7420_controller.v
│   ├── temp_to_bcd.v
│   ├── seven_seg_driver.v
│   ├── debug_not2_buffer.v
│   ├── i2c_master_top.v
│   ├── i2c_master_bit_ctrl.v
│   ├── i2c_master_byte_ctrl.v
│   ├── i2c_master_defines.v
│   └── timescale.v
│
├── constraints/
│   └── nexys4_adt7420.xdc
│
├── sim/
│   └── tb_sistema_final.v
│
└── docs/