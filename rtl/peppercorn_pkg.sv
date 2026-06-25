package peppercorn_pkg;

    typedef enum logic [6:0] {
        OPC_LUI      = 7'b0110111, // U-type: LUI
        OPC_AUIPC    = 7'b0010111, // U-type: AUIPC
        OPC_JAL      = 7'b1101111, // J-type: JAL
        OPC_JALR     = 7'b1100111, // I-type: JALR
        OPC_BRANCH   = 7'b1100011, // B-type: BEQ BNE BLT BGE BLTU BGEU
        OPC_LOAD     = 7'b0000011, // I-type: LB LH LW LBU LHU
        OPC_STORE    = 7'b0100011, // S-type: SB SH SW
        OPC_OP_IMM   = 7'b0010011, // I-type: ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI
        OPC_OP       = 7'b0110011, // R-type: ADD SUB SLL SLT SLTU XOR SRL SRA OR AND
        OPC_MISC_MEM = 7'b0001111, // FENCE
        OPC_SYSTEM   = 7'b1110011  // ECALL EBREAK
    } opcode_type;

    // funct3 for the OP and (|) OP-IMM instructions
    typedef enum logic [2:0] {
        F3_ADD_SUB = 3'b000, // ADD/SUB | ADDI
        F3_SLL     = 3'b001, // SLL     | SLLI
        F3_SLT     = 3'b010, // SLT     | SLTI
        F3_SLTU    = 3'b011, // SLTU    | SLTIU
        F3_XOR     = 3'b100, // XOR     | XORI
        F3_SR      = 3'b101, // SRL/SRA | SRLI/SRAI
        F3_OR      = 3'b110, // OR      | ORI
        F3_AND     = 3'b111  // AND     | ANDI
    } funct3_op_type;

    // funct3 for the BRANCH instructions
    typedef enum logic [2:0] {
        F3_BEQ  = 3'b000,
        F3_BNE  = 3'b001,
        F3_BLT  = 3'b100,
        F3_BGE  = 3'b101,
        F3_BLTU = 3'b110,
        F3_BGEU = 3'b111
    } funct3_branch_type;


    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_SLL,   // a << b[4:0]
        ALU_SLT,   // signed(a) < signed(b)
        ALU_SLTU,  // (a < b) ? 1 : 0
        ALU_XOR,
        ALU_SRL,   // a >> b[4:0]
        ALU_SRA,   // a >>> b[4:0]
        ALU_OR,
        ALU_AND
    } alu_op_type;


endpackage
