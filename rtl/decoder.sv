// https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html#base_instr
//
module decoder
    import peppercorn_pkg::*;
(
    input  logic [31:0] instr,

    output logic [4:0]  reg_rs1,
    output logic [4:0]  reg_rs2,
    output logic [4:0]  reg_rd,
    output logic [31:0] imm,

    output alu_op_type  alu_op,
    output logic        use_imm,
    output logic        use_pc,
    output logic        reg_write_en,
    output logic        link,   // rd = pc + 4, else alu output
    output logic        jump,   // next_pc = alu output, else pc + 4
    output logic        branch, // next_pc = pc + imm if branch is taken
    output logic        mem_read,
    output logic        mem_write_en
);

    opcode_type opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = opcode_type'(instr[6:0]);
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    // funct7[5], the "alternate op" bit
    logic is_alt_op;
    assign is_alt_op = funct7[5];

    assign reg_rs2 = instr[24:20];
    assign reg_rd  = instr[11:7];

    logic [4:0]  rs1;
    logic [31:0] imm_i;
    logic [31:0] imm_u;
    logic [31:0] imm_j;
    logic [31:0] imm_b;
    logic [31:0] imm_s;
    assign rs1   = instr[19:15];
    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_u = {instr[31:12], 12'b0};
    assign imm_j = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    assign imm_b = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    always_comb begin
        // Defaults to a noop
        alu_op       = ALU_ADD;
        use_imm      = 1'b0;
        use_pc       = 1'b0;
        reg_write_en = 1'b0;
        link         = 1'b0;
        jump         = 1'b0;
        branch       = 1'b0;
        mem_read     = 1'b0;
        mem_write_en = 1'b0;
        reg_rs1      = rs1;
        imm          = imm_i;

        case (opcode)
            OPC_OP: begin // R-type: rd = rs1 (op) rs2
                reg_write_en = 1'b1;
                case (funct3_op_type'(funct3))
                    F3_ADD_SUB: alu_op = alu_op_type'(is_alt_op ? ALU_SUB : ALU_ADD);
                    F3_SLL:     alu_op = ALU_SLL;
                    F3_SLT:     alu_op = ALU_SLT;
                    F3_SLTU:    alu_op = ALU_SLTU;
                    F3_XOR:     alu_op = ALU_XOR;
                    F3_SR:      alu_op = alu_op_type'(is_alt_op ? ALU_SRA : ALU_SRL);
                    F3_OR:      alu_op = ALU_OR;
                    F3_AND:     alu_op = ALU_AND;
                endcase
            end

            OPC_OP_IMM: begin // I-type: rd = rs1 (op) imm
                use_imm      = 1'b1;
                reg_write_en = 1'b1;
                case (funct3_op_type'(funct3))
                    F3_ADD_SUB: alu_op = ALU_ADD;
                    F3_SLL:     alu_op = ALU_SLL;
                    F3_SLT:     alu_op = ALU_SLT;
                    F3_SLTU:    alu_op = ALU_SLTU;
                    F3_XOR:     alu_op = ALU_XOR;
                    F3_SR:      alu_op = alu_op_type'(is_alt_op ? ALU_SRA : ALU_SRL);
                    F3_OR:      alu_op = ALU_OR;
                    F3_AND:     alu_op = ALU_AND;
                endcase
            end

            OPC_LUI: begin // rd = imm
                reg_write_en = 1'b1;
                use_imm      = 1'b1;
                imm          = imm_u;
                reg_rs1      = 5'd0; // x0
            end

            OPC_AUIPC: begin // rd = pc + imm
                reg_write_en = 1'b1;
                use_imm      = 1'b1;
                use_pc       = 1'b1;
                imm          = imm_u;
            end

            // TODO: The next pc for unconditional jumps should probably be computed eagerly
            OPC_JAL: begin // rd = pc + 4, next_pc = pc + imm
                reg_write_en = 1'b1;
                use_imm      = 1'b1;
                use_pc       = 1'b1;
                link         = 1'b1;
                jump         = 1'b1;
                imm          = imm_j;
            end

            OPC_JALR: begin // rd = pc + 4, next_pc = (rs1 + imm) & ~1
                reg_write_en = 1'b1;
                use_imm      = 1'b1;
                link         = 1'b1;
                jump         = 1'b1;
                imm          = imm_i;
            end

            OPC_BRANCH: begin
                branch = 1'b1;
                imm    = imm_b;
                case (funct3_branch_type'(funct3))
                    F3_BEQ:  alu_op = ALU_SUB;  // taken if out == 0
                    F3_BNE:  alu_op = ALU_SUB;  // taken if out != 0
                    F3_BLT:  alu_op = ALU_SLT;  // taken if out == 1
                    F3_BGE:  alu_op = ALU_SLT;  // taken if out == 0
                    F3_BLTU: alu_op = ALU_SLTU; // taken if out == 1
                    F3_BGEU: alu_op = ALU_SLTU; // taken if out == 0
                endcase
            end

            // TODO: Currently we only support aligned 4-byte loads and stores (LW, SW)
            OPC_LOAD: begin
                reg_write_en = 1'b1;
                use_imm      = 1'b1;
                mem_read     = 1'b1;
                imm          = imm_i;
            end
            OPC_STORE: begin
                use_imm      = 1'b1;
                mem_write_en = 1'b1;
                imm          = imm_s;
            end

            OPC_MISC_MEM: ;
            OPC_SYSTEM:   ;

            default: ;
        endcase
    end

endmodule
