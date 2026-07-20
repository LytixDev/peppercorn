module core 
    import peppercorn_pkg::*;
(
    input logic clk,
    input logic rst_n
);

    `define NOP_INSTR 32'h0000_0013 // addi x0, x0, 0

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

    logic predict_taken;
    alu_op_type alu_op;
    logic use_imm;
    logic use_pc;
    logic reg_write_en;
    logic link; // rd = pc + 4, else alu output
    logic jump; // next_pc = alu output, else pc + 4
    logic branch; // next_pc = pc + imm if branch is taken
    logic mem_read;
    logic mem_write_en;
    logic mem_sign_ext;

    logic [1:0] mem_req_size_a;
    logic [1:0] mem_req_size_b;

    if_id_barrier   if_id_reg;
    id_ex1_barrier  id_ex1_reg;
    ex1_ex2_barrier ex1_ex2_reg;
    ex2_ret_barrier ex2_ret_reg;

    logic           fwd_ex2_rs1, fwd_ex2_rs2;
    logic           fwd_ret_rs1, fwd_ret_rs2;
    logic [31:0]    fwd_rs1, fwd_rs2;


    /* Register file write data */
    logic [31:0] reg_write_data;
    always_comb begin
        logic [31:0] mem_data;
        if (ex1_ex2_reg.mem_sign_ext) begin
            case (ex1_ex2_reg.mem_req_size_b)
                2'b00:   mem_data = {{24{mem_read_out[7]}},  mem_read_out[7:0]};
                2'b01:   mem_data = {{16{mem_read_out[15]}}, mem_read_out[15:0]};
                default: mem_data = mem_read_out;
            endcase
        end else begin
            mem_data = mem_read_out;
        end

        if (ex1_ex2_reg.link) begin
            reg_write_data = ex1_ex2_reg.pc + 4;
        end else if (ex1_ex2_reg.mem_read) begin
            reg_write_data = mem_data;
        end else begin
            reg_write_data = ex1_ex2_reg.alu_result;
        end
    end
    

    // A trick here is to use the funct3's lsb to figure out if the alu output is supposed to be 
    // 0 or 1 for a branch to be taken.
    logic [1:0] branch_kind;
    logic raw_branch_taken, branch_taken;
    logic alu_lsb;
    assign branch_kind = ex1_ex2_reg.instr[14:13];
    assign alu_lsb     = ex1_ex2_reg.alu_result[0];
    always_comb case (branch_kind)
        2'b00:   raw_branch_taken = (ex1_ex2_reg.alu_result == 0); // eq
        2'b10:   raw_branch_taken = alu_lsb;                       // lt
        2'b11:   raw_branch_taken = alu_lsb;                       // ltu
        default: raw_branch_taken = 1'b0;
    endcase
    assign branch_taken = raw_branch_taken ^ ex1_ex2_reg.instr[12];

    // Since we always predict not taken, we must flush mispredicted branches
    logic flush;
    assign flush = ex1_ex2_reg.jump || (ex1_ex2_reg.branch && branch_taken);
    // Next pc selection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 0;
        end else begin
            if (ex1_ex2_reg.jump) begin
                pc <= ex1_ex2_reg.alu_result & ~32'b1;
            end else if (ex1_ex2_reg.branch && branch_taken) begin
                pc <= ex1_ex2_reg.pc + ex1_ex2_reg.imm;
            end else begin
                pc <= next_pc;
            end
        end
    end


    /* Pipeline registers */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_reg <= '0;
        end else if (flush) begin
            if_id_reg.pc            <= '0;
            if_id_reg.instr         <= `NOP_INSTR;
            if_id_reg.predict_taken <= 1'b0;
            if_id_reg.valid         <= 1'b0;
        end else begin
            if_id_reg.pc            <= pc;
            if_id_reg.instr         <= instr;
            if_id_reg.predict_taken <= predict_taken;
            if_id_reg.valid         <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex1_reg <= '0;
        end else if (flush) begin
            // Effictively a NOP: has no sideeffects
            id_ex1_reg <= '0;
        end else begin
            id_ex1_reg.pc             <= if_id_reg.pc;
            id_ex1_reg.instr          <= if_id_reg.instr;
            id_ex1_reg.predict_taken  <= if_id_reg.predict_taken;
            id_ex1_reg.reg_rs1        <= reg_rs1;
            id_ex1_reg.reg_rs2        <= reg_rs2;
            id_ex1_reg.reg_rd         <= reg_rd;
            id_ex1_reg.rs1            <= rs1;
            id_ex1_reg.rs2            <= rs2;
            id_ex1_reg.imm            <= imm;
            id_ex1_reg.alu_op         <= alu_op;
            id_ex1_reg.use_imm        <= use_imm;
            id_ex1_reg.use_pc         <= use_pc;
            id_ex1_reg.reg_write_en   <= reg_write_en;
            id_ex1_reg.link           <= link;
            id_ex1_reg.jump           <= jump;
            id_ex1_reg.branch         <= branch;
            id_ex1_reg.mem_read       <= mem_read;
            id_ex1_reg.mem_write_en   <= mem_write_en;
            id_ex1_reg.mem_req_size_b <= mem_req_size_b;
            id_ex1_reg.mem_sign_ext   <= mem_sign_ext;
            id_ex1_reg.valid          <= if_id_reg.valid;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex1_ex2_reg <= '0;
        end else if (flush) begin
            // Effictively a NOP: has no sideeffects
            ex1_ex2_reg <= '0;
        end else begin
            ex1_ex2_reg.pc              <= id_ex1_reg.pc;
            ex1_ex2_reg.imm             <= id_ex1_reg.imm;
            ex1_ex2_reg.instr           <= id_ex1_reg.instr;
            ex1_ex2_reg.reg_rd          <= id_ex1_reg.reg_rd;
            ex1_ex2_reg.rs2             <= fwd_rs2;
            ex1_ex2_reg.alu_result      <= alu_out;
            ex1_ex2_reg.reg_write_en    <= id_ex1_reg.reg_write_en;
            ex1_ex2_reg.link            <= id_ex1_reg.link;
            ex1_ex2_reg.jump            <= id_ex1_reg.jump;
            ex1_ex2_reg.branch          <= id_ex1_reg.branch;
            ex1_ex2_reg.mem_read        <= id_ex1_reg.mem_read;
            ex1_ex2_reg.mem_write_en    <= id_ex1_reg.mem_write_en;
            ex1_ex2_reg.mem_req_size_b  <= id_ex1_reg.mem_req_size_b;
            ex1_ex2_reg.mem_sign_ext    <= id_ex1_reg.mem_sign_ext;
            ex1_ex2_reg.valid           <= id_ex1_reg.valid;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex2_ret_reg <= '0;
        end else begin
            ex2_ret_reg.reg_rd         <= ex1_ex2_reg.reg_rd;
            ex2_ret_reg.reg_write_en   <= ex1_ex2_reg.reg_write_en;
            ex2_ret_reg.reg_write_data <= reg_write_data;
            ex2_ret_reg.valid          <= ex1_ex2_reg.valid;
        end
    end


    // Comb
    instr_fetch instr_fetch_ (
        .pc            (pc),
        .fetch_addr    (instr_fetch_addr),
        .next_pc       (next_pc),
        .predict_taken (predict_taken)
    );

    mem #(.NUM_WORDS(16384)) memory (
        .clk    (clk),

        .addr_a (instr_fetch_addr),
        .size_a (2'b10),
        .out_a  (instr),

        .addr_b       (ex1_ex2_reg.alu_result),
        .size_b       (ex1_ex2_reg.mem_req_size_b),
        .write_data_b (ex1_ex2_reg.rs2),
        .write_en_b   (ex1_ex2_reg.mem_write_en),
        .out_b        (mem_read_out)
    );

    // Comb
    decoder decoder_ (
        .instr          (if_id_reg.instr),

        .reg_rs1        (reg_rs1),
        .reg_rs2        (reg_rs2),
        .reg_rd         (reg_rd),
        .imm            (imm),
        .alu_op         (alu_op),
        .use_imm        (use_imm),
        .use_pc         (use_pc),
        .reg_write_en   (reg_write_en),
        .link           (link),
        .jump           (jump),
        .branch         (branch),
        .mem_read       (mem_read),
        .mem_write_en   (mem_write_en),
        .mem_req_size_a (mem_req_size_a),
        .mem_req_size_b (mem_req_size_b),
        .mem_sign_ext   (mem_sign_ext)
    );

    /* Forwarding unit */
    assign fwd_ex2_rs1 = ex1_ex2_reg.reg_write_en
                      && ex1_ex2_reg.reg_rd != 5'b0
                      && ex1_ex2_reg.reg_rd == id_ex1_reg.reg_rs1;
    assign fwd_ex2_rs2 = ex1_ex2_reg.reg_write_en
                      && ex1_ex2_reg.reg_rd != 5'b0
                      && ex1_ex2_reg.reg_rd == id_ex1_reg.reg_rs2;
    assign fwd_ret_rs1 = ex2_ret_reg.reg_write_en
                      && ex2_ret_reg.reg_rd != 5'b0
                      && ex2_ret_reg.reg_rd == id_ex1_reg.reg_rs1;
    assign fwd_ret_rs2 = ex2_ret_reg.reg_write_en
                      && ex2_ret_reg.reg_rd != 5'b0
                      && ex2_ret_reg.reg_rd == id_ex1_reg.reg_rs2;

    assign fwd_rs1 = fwd_ex2_rs1 ? reg_write_data
                   : fwd_ret_rs1 ? ex2_ret_reg.reg_write_data
                   :               id_ex1_reg.rs1;
    assign fwd_rs2 = fwd_ex2_rs2 ? reg_write_data
                   : fwd_ret_rs2 ? ex2_ret_reg.reg_write_data
                   :               id_ex1_reg.rs2;

    // Comb
    alu alu_ (
        .alu_op (id_ex1_reg.alu_op),
        .a      (id_ex1_reg.use_pc ? id_ex1_reg.pc : fwd_rs1),
        .b      (id_ex1_reg.use_imm ? id_ex1_reg.imm : fwd_rs2),

        .out    (alu_out)
    );

    // Seq
    register_file rf (
        .clk        (clk),
        .rst_n      (rst_n),
        .read_a     (reg_rs1),
        .read_b     (reg_rs2),
        .write      (ex2_ret_reg.reg_rd),
        .write_data (ex2_ret_reg.reg_write_data),
        .write_en   (ex2_ret_reg.reg_write_en),
        
        .out_a      (rs1),
        .out_b      (rs2)
    );

endmodule
