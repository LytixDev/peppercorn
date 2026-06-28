module core 
    import peppercorn_pkg::*;
(
    input logic clk,
    input logic rst_n
);

    logic [31:0] imm; // sign extended
    logic [31:0] rs1;
    logic [31:0] rs2;
    logic [4:0]  reg_rs1;
    logic [4:0]  reg_rs2;
    logic [4:0]  reg_rd;
    logic [31:0] alu_out;

    logic [31:0] instr;
    logic [31:0] pc;
    logic [31:0] next_pc;
    logic [31:0] instr_fetch_addr;
    logic [31:0] mem_read_out;

    alu_op_type alu_op;
    logic use_imm;
    logic use_pc;
    logic reg_write_en;
    logic link; // rd = pc + 4, else alu output
    logic jump; // next_pc = alu output, else pc + 4
    logic branch; // next_pc = pc + imm if branch is taken
    logic mem_read;
    logic mem_write_en;


    logic [31:0] reg_write_data;
    always_comb begin
        if (link) begin 
            reg_write_data = next_pc;
        end else if (mem_read) begin
            reg_write_data = mem_read_out;
        end else begin
            reg_write_data = alu_out;
        end
    end
    

    // A trick here is to use the funct3's lsb to figure out if the alu output is supposed to be 
    // 0 or 1 for a branch to be taken.
    logic [1:0] branch_kind;
    logic raw_branch_taken, branch_taken;
    logic alu_lsb;
    assign branch_kind = instr[14:13];
    assign alu_lsb     = alu_out[0];
    always_comb case (branch_kind)
        2'b00:   raw_branch_taken = (alu_out == 0); // eq
        2'b10:   raw_branch_taken = alu_lsb;        // lt
        2'b11:   raw_branch_taken = alu_lsb;        // ltu
        default: raw_branch_taken = 1'b0;
    endcase
    assign branch_taken = raw_branch_taken ^ instr[12];

    // Next pc selection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 0;
        end else begin
            if (branch && branch_taken) begin
                // TODO: Add a seperate datapath which always comptues pc + imm
                // Use this for the jump instructions as well.
                // Use this when we are speculating as well.
                pc <= pc + imm;
            end else begin
                // Clear least significant bit. This is in the spec for JALR and a noop for JAL.
                pc <= jump ? (alu_out & ~32'b1) : next_pc;
            end
        end
    end


    // Comb
    instr_fetch instr_fetch_ (
        .pc         (pc),
        .fetch_addr (instr_fetch_addr),
        .next_pc    (next_pc)
    );

    mem #(.NUM_WORDS(4096)) memory (
        .clk    (clk),

        .addr_a (instr_fetch_addr),
        .out_a  (instr),

        .addr_b       (alu_out),
        .write_data_b (rs2),
        .write_en_b   (mem_write_en),
        .out_b        (mem_read_out)
    );

    // Comb
    decoder decoder_ (
        .instr        (instr),

        .reg_rs1      (reg_rs1),
        .reg_rs2      (reg_rs2),
        .reg_rd       (reg_rd),
        .imm          (imm),
        .alu_op       (alu_op),
        .use_imm      (use_imm),
        .use_pc       (use_pc),
        .reg_write_en (reg_write_en),
        .link         (link),
        .jump         (jump),
        .branch       (branch),
        .mem_read     (mem_read),
        .mem_write_en (mem_write_en)
    );

    // Comb
    alu alu_ (
        .alu_op (alu_op),
        .a      (use_pc ? pc : rs1),
        .b      (use_imm ? imm : rs2),

        .out    (alu_out)
    );

    // Seq
    register_file rf (
        .clk        (clk),
        .rst_n      (rst_n),
        .read_a     (reg_rs1),
        .read_b     (reg_rs2),
        .write      (reg_rd),
        .write_data (reg_write_data),
        .write_en   (reg_write_en),
        
        .out_a      (rs1),
        .out_b      (rs2)
    );

endmodule
