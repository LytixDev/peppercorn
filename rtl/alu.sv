module alu 
    import peppercorn_pkg::*;
(
    input  alu_op_type  alu_op,
    input  logic [31:0] a,
    input  logic [31:0] b,

    output logic [31:0] out
);

    logic [4:0] shamt;
    assign shamt = b[4:0];

    always_comb begin
        case (alu_op)
            ALU_ADD:  out = a + b;
            ALU_SUB:  out = a - b;
            ALU_SLL:  out = a << shamt;
            ALU_SLT:  out = $signed(a) < $signed(b) ? 1 : 0;
            ALU_SLTU: out = a < b ? 1 : 0;
            ALU_XOR:  out = a ^ b;
            ALU_SRL:  out = a >> shamt;
            ALU_SRA:  out = $signed(a) >>> shamt;
            ALU_OR:   out = a | b;
            ALU_AND:  out = a & b;
            default:  out = '0;
        endcase
    end

endmodule
