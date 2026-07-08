module instr_fetch
    import peppercorn_pkg::*;
(
    input  logic [31:0] pc,

    output logic [31:0] fetch_addr,
    output logic [31:0] next_pc,
    output logic        predict_taken
);

    // NOTE: This module looks stupid now, but later when we we add branch
    // prediction etc it will make more sense.
    assign fetch_addr = pc;
    // In lieu of a bp we always predict taken
    assign next_pc = pc + 4;
    assign predict_taken = 1;

endmodule
