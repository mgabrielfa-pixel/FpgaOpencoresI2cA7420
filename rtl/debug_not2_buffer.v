// ================================================================
// debug_not2_buffer.v
// Buffer de depuración usando dos inversores reales.
//
// Uso:
//   Señal interna -> NOT -> NOT -> salida PMOD
//
// Dos NOT equivalen lógicamente a un buffer.
// Se usan LUT1 + DONT_TOUCH para evitar que Vivado elimine
// los inversores durante síntesis.
// ================================================================

module debug_not2_buffer (
    input  wire sig_in,
    output wire sig_out
);

    (* KEEP = "TRUE" *) wire sig_inv;

    // Primer inversor
    (* DONT_TOUCH = "TRUE" *)
    LUT1 #(
        .INIT(2'b01)
    ) u_not_1 (
        .I0(sig_in),
        .O(sig_inv)
    );

    // Segundo inversor
    (* DONT_TOUCH = "TRUE" *)
    LUT1 #(
        .INIT(2'b01)
    ) u_not_2 (
        .I0(sig_inv),
        .O(sig_out)
    );

endmodule