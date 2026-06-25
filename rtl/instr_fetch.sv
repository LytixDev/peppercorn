module instr_fetch
    import peppercorn_pkg::*;
(
    input  logic [31:0] pc,

    output logic [31:0] next_pc,
    output logic [31:0] instr
);

    mem #(.READ_ONLY(1)) instr_mem (
        .clk        (1'b0),
        .addr       (pc),
        .write_data ('0),
        .write_en   (1'b0),
        .out_word   (instr)
    );

    assign next_pc = pc + 4;

endmodule
