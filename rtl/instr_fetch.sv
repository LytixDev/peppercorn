module instr_fetch
    import peppercorn_pkg::*;
(
    input  logic [31:0] pc,

    output logic [31:0] fetch_addr,
    output logic [31:0] next_pc
);

    // NOTE: This module looks stupid now, but later when we we add branch
    // prediction etc it will make more sense.
    assign fetch_addr = pc;
    assign next_pc = pc + 4;

endmodule
