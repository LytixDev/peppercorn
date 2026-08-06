module core
    import peppercorn_pkg::*;
#(
    parameter bit USE_RAS = 1
)
(
    input logic clk,
    input logic rst_n
);

    `define NOP_INSTR 32'h0000_0013 // addi x0, x0, 0

    /* IF stage */
    logic [31:0] if_pc;
    logic [31:0] if_instr;
    logic [31:0] if_bp_target;
    logic        if_bp_predict_taken;

    /* ID stage (decoder and register file outputs) */
    logic [31:0] id_imm; // sign extended
    logic [31:0] id_rs1;
    logic [31:0] id_rs2;
    logic [4:0]  id_reg_rs1;
    logic [4:0]  id_reg_rs2;
    logic [4:0]  id_reg_rd;
    alu_op_type  id_alu_op;
    logic        id_use_imm;
    logic        id_use_pc;
    logic        id_reg_write_en;
    logic        id_link;    // rd = pc + 4, else alu output
    logic        id_jump;    // next_pc = alu output, else pc + 4
    logic        id_branch;  // next_pc = pc + imm if branch is taken
    logic        id_jal;     // JAL in ID: target (pc + imm) known now
    logic        id_jal_redirect; // JAL the BTB didn't predict: redirect eagerly from ID
    logic        id_rd_link, id_rs1_link;
    logic        id_ras_push, id_ras_pop;
    logic        id_ras_redirect;
    logic        id_mem_read;
    logic        id_mem_write_en;
    logic        id_mem_sign_ext;
    logic [1:0]  id_mem_req_size_a;
    logic [1:0]  id_mem_req_size_b;
    logic [31:0] id_ras_popped_target;

    /* EX1 stage */
    logic [31:0] ex1_alu_out;
    logic        ex1_fwd_ex2_rs1, ex1_fwd_ex2_rs2;
    logic        ex1_fwd_ret_rs1, ex1_fwd_ret_rs2;
    logic [31:0] ex1_fwd_rs1, ex1_fwd_rs2;

    /* EX2 stage */
    logic [31:0] ex2_mem_read_out;
    logic [31:0] ex2_reg_write_data;

    if_id_barrier   if_id_reg;
    id_ex1_barrier  id_ex1_reg;
    ex1_ex2_barrier ex1_ex2_reg;
    ex2_ret_barrier ex2_ret_reg;


    /* Register file write data */
    always_comb begin
        logic [31:0] mem_data;
        if (ex1_ex2_reg.mem_sign_ext) begin
            case (ex1_ex2_reg.mem_req_size_b)
                2'b00:   mem_data = {{24{ex2_mem_read_out[7]}},  ex2_mem_read_out[7:0]};
                2'b01:   mem_data = {{16{ex2_mem_read_out[15]}}, ex2_mem_read_out[15:0]};
                default: mem_data = ex2_mem_read_out;
            endcase
        end else begin
            mem_data = ex2_mem_read_out;
        end

        if (ex1_ex2_reg.link) begin
            ex2_reg_write_data = ex1_ex2_reg.pc + 4;
        end else if (ex1_ex2_reg.mem_read) begin
            ex2_reg_write_data = mem_data;
        end else begin
            ex2_reg_write_data = ex1_ex2_reg.alu_result;
        end
    end


    // A trick here is to use the funct3's lsb to figure out if the alu output is supposed to be
    // 0 or 1 for a branch to be taken.
    logic [1:0] ex1_branch_kind;
    logic ex1_raw_branch_taken, ex1_branch_taken;
    logic ex1_alu_lsb;
    assign ex1_branch_kind = id_ex1_reg.instr[14:13];
    assign ex1_alu_lsb     = ex1_alu_out[0];
    always_comb case (ex1_branch_kind)
        2'b00:   ex1_raw_branch_taken = (ex1_alu_out == 0); // eq
        2'b10:   ex1_raw_branch_taken = ex1_alu_lsb;        // lt
        2'b11:   ex1_raw_branch_taken = ex1_alu_lsb;        // ltu
        default: ex1_raw_branch_taken = 1'b0;
    endcase
    assign ex1_branch_taken = ex1_raw_branch_taken ^ id_ex1_reg.instr[12];

    /* Next PC fetch selection */
    // Branches and JALR are resolved during EX1. 
    // JALR is unconditionally taken, but the RAS may supply the wrong target.
    // JAL are handled earlier during the ID stage.
    logic        ex1_actual_taken;
    logic [31:0] ex1_actual_target;
    assign ex1_actual_taken  = id_ex1_reg.jump || (id_ex1_reg.branch && ex1_branch_taken);
    assign ex1_actual_target = id_ex1_reg.jump ? (ex1_alu_out & ~32'b1)          // JALR: rs1 + imm, low bit cleared
                                               : id_ex1_reg.pc + id_ex1_reg.imm; // branch: pc + imm

    logic ex1_branch_mispredict;
    logic [31:0] ex1_redirect_pc;
    assign ex1_branch_mispredict = id_ex1_reg.predict_taken != ex1_actual_taken // wrong direction
                                || (id_ex1_reg.predict_taken && id_ex1_reg.predict_target != ex1_actual_target); // Wrong JALR target in the RAS
    assign ex1_redirect_pc       = ex1_actual_taken ? ex1_actual_target : id_ex1_reg.pc + 4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_pc <= 0;
        end else begin
            if (ex1_branch_mispredict) begin
                if_pc <= ex1_redirect_pc;
            end else if (id_jal_redirect) begin
                // Resolved during ID
                if_pc <= if_id_reg.pc + id_imm;
            end else if (id_ras_redirect) begin
                // Return in ID: fetch from the RAS prediction
                if_pc <= id_ras_popped_target;
            end else begin
                // Happy path
                if (if_bp_predict_taken) if_pc <= if_bp_target;
                else                     if_pc <= if_pc + 4;
            end
        end
    end


    /* Pipeline registers */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_reg <= '0;
        end else if (ex1_branch_mispredict || id_jal_redirect || id_ras_redirect) begin
            if_id_reg.pc             <= '0;
            if_id_reg.instr          <= `NOP_INSTR;
            if_id_reg.predict_taken  <= 1'b0;
            if_id_reg.predict_target <= '0;
            if_id_reg.valid          <= 1'b0;
        end else begin
            if_id_reg.pc             <= if_pc;
            if_id_reg.instr          <= if_instr;
            if_id_reg.predict_taken  <= if_bp_predict_taken;
            if_id_reg.predict_target <= if_bp_target;
            if_id_reg.valid          <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex1_reg <= '0;
        end else if (ex1_branch_mispredict) begin
            // Effictively a NOP: has no sideeffects
            id_ex1_reg <= '0;
        end else begin
            id_ex1_reg.pc             <= if_id_reg.pc;
            id_ex1_reg.instr          <= if_id_reg.instr;
            // ID-stage predictions take priority over the BP in the IF stage 
            // So, the RAS target for retrnrs and eagilerly evaluated JALs
            // where the BP missed. On a BTB-predicted JAL keep the BTB target so EX1 still verifies the fetched path.
            id_ex1_reg.predict_taken  <= if_id_reg.predict_taken || id_ras_pop || id_jal;
            id_ex1_reg.predict_target <= id_ras_pop      ? id_ras_popped_target
                                       : id_jal_redirect ? if_id_reg.pc + id_imm
                                       :                   if_id_reg.predict_target;
            id_ex1_reg.reg_rs1        <= id_reg_rs1;
            id_ex1_reg.reg_rs2        <= id_reg_rs2;
            id_ex1_reg.reg_rd         <= id_reg_rd;
            id_ex1_reg.rs1            <= id_rs1;
            id_ex1_reg.rs2            <= id_rs2;
            id_ex1_reg.imm            <= id_imm;
            id_ex1_reg.alu_op         <= id_alu_op;
            id_ex1_reg.use_imm        <= id_use_imm;
            id_ex1_reg.use_pc         <= id_use_pc;
            id_ex1_reg.reg_write_en   <= id_reg_write_en;
            id_ex1_reg.link           <= id_link;
            id_ex1_reg.jump           <= id_jump; // includes JAL, so the BTB learns JAL targets
            id_ex1_reg.branch         <= id_branch;
            id_ex1_reg.mem_read       <= id_mem_read;
            id_ex1_reg.mem_write_en   <= id_mem_write_en;
            id_ex1_reg.mem_req_size_b <= id_mem_req_size_b;
            id_ex1_reg.mem_sign_ext   <= id_mem_sign_ext;
            id_ex1_reg.valid          <= if_id_reg.valid;
        end
    end

    // Nothing older than EX1 redirects, so EX2 and RET are never flushed: the
    // branch/JALR that resolves in EX1 advances here to commit (JALR writes rd).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex1_ex2_reg <= '0;
        end else begin
            ex1_ex2_reg.pc              <= id_ex1_reg.pc;
            ex1_ex2_reg.imm             <= id_ex1_reg.imm;
            ex1_ex2_reg.instr           <= id_ex1_reg.instr;
            ex1_ex2_reg.reg_rd          <= id_ex1_reg.reg_rd;
            ex1_ex2_reg.rs2             <= ex1_fwd_rs2;
            ex1_ex2_reg.alu_result      <= ex1_alu_out;
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
            ex2_ret_reg.reg_write_data <= ex2_reg_write_data;
            ex2_ret_reg.valid          <= ex1_ex2_reg.valid;
        end
    end

    branch_predictor #(.BTB_ENTRIES(256), .BHT_ENTRIES(128)) bp (
        .clk           (clk),
        .rst_n         (rst_n),

        .pc            (if_pc),
        .target        (if_bp_target),
        .predict_taken (if_bp_predict_taken),

        .addr_update   (id_ex1_reg.pc),
        .target_update (ex1_actual_target),
        .actual_taken  (ex1_actual_taken),
        .update_en     (id_ex1_reg.branch || id_ex1_reg.jump)
    );

    ras #(.ENTRIES(16)) ras_ (
        .clk         (clk),
        .rst_n       (rst_n),
        .push_en     (id_ras_push),
        .push_target (if_id_reg.pc + 4),

        .pop_en        (id_ras_pop),
        .popped_target (id_ras_popped_target)
    );

    mem #(.NUM_WORDS(16384)) memory (
        .clk    (clk),

        .addr_a (if_pc),
        .size_a (2'b10),
        .out_a  (if_instr),

        .addr_b       (ex1_ex2_reg.alu_result),
        .size_b       (ex1_ex2_reg.mem_req_size_b),
        .write_data_b (ex1_ex2_reg.rs2),
        .write_en_b   (ex1_ex2_reg.mem_write_en),
        .out_b        (ex2_mem_read_out)
    );

    // Comb
    decoder decoder_ (
        .instr          (if_id_reg.instr),

        .reg_rs1        (id_reg_rs1),
        .reg_rs2        (id_reg_rs2),
        .reg_rd         (id_reg_rd),
        .imm            (id_imm),
        .alu_op         (id_alu_op),
        .use_imm        (id_use_imm),
        .use_pc         (id_use_pc),
        .reg_write_en   (id_reg_write_en),
        .link           (id_link),
        .jump           (id_jump),
        .branch         (id_branch),
        .mem_read       (id_mem_read),
        .mem_write_en   (id_mem_write_en),
        .mem_req_size_a (id_mem_req_size_a),
        .mem_req_size_b (id_mem_req_size_b),
        .mem_sign_ext   (id_mem_sign_ext)
    );

    // JAL is unconditional and its target is pc + imm, so it can be eagerly resolved in the ID stage.
    // Only redirect on a BP miss (cold or alias).
    assign id_jal          = id_jump && id_use_pc;
    assign id_jal_redirect = id_jal && !if_id_reg.predict_taken;

    // RAS: push on calls (rd = link), pop on returns (JALR with rs1 = link).
    assign id_rd_link  = id_reg_rd  == 5'd1 || id_reg_rd  == 5'd5;
    assign id_rs1_link = id_reg_rs1 == 5'd1 || id_reg_rs1 == 5'd5;
    assign id_ras_push = USE_RAS && id_jump && id_rd_link && !ex1_branch_mispredict;
    assign id_ras_pop  = USE_RAS && id_jump && !id_use_pc && id_rs1_link
                      && !(id_rd_link && id_reg_rd == id_reg_rs1) // rd == rs1 == link: push only
                      && !ex1_branch_mispredict;
    // Skip the redirect (and its bubble) when fetch already went where the RAS points
    assign id_ras_redirect = id_ras_pop
                          && !(if_id_reg.predict_taken && if_id_reg.predict_target == id_ras_popped_target);

    /* Forwarding unit */
    assign ex1_fwd_ex2_rs1 = ex1_ex2_reg.reg_write_en
                          && ex1_ex2_reg.reg_rd != 5'b0
                          && ex1_ex2_reg.reg_rd == id_ex1_reg.reg_rs1;
    assign ex1_fwd_ex2_rs2 = ex1_ex2_reg.reg_write_en
                          && ex1_ex2_reg.reg_rd != 5'b0
                          && ex1_ex2_reg.reg_rd == id_ex1_reg.reg_rs2;
    assign ex1_fwd_ret_rs1 = ex2_ret_reg.reg_write_en
                          && ex2_ret_reg.reg_rd != 5'b0
                          && ex2_ret_reg.reg_rd == id_ex1_reg.reg_rs1;
    assign ex1_fwd_ret_rs2 = ex2_ret_reg.reg_write_en
                          && ex2_ret_reg.reg_rd != 5'b0
                          && ex2_ret_reg.reg_rd == id_ex1_reg.reg_rs2;

    assign ex1_fwd_rs1 = ex1_fwd_ex2_rs1 ? ex2_reg_write_data
                       : ex1_fwd_ret_rs1 ? ex2_ret_reg.reg_write_data
                       :                   id_ex1_reg.rs1;
    assign ex1_fwd_rs2 = ex1_fwd_ex2_rs2 ? ex2_reg_write_data
                       : ex1_fwd_ret_rs2 ? ex2_ret_reg.reg_write_data
                       :                   id_ex1_reg.rs2;

    // Comb
    alu alu_ (
        .alu_op (id_ex1_reg.alu_op),
        .a      (id_ex1_reg.use_pc ? id_ex1_reg.pc : ex1_fwd_rs1),
        .b      (id_ex1_reg.use_imm ? id_ex1_reg.imm : ex1_fwd_rs2),

        .out    (ex1_alu_out)
    );

    // Seq
    register_file rf (
        .clk        (clk),
        .rst_n      (rst_n),
        .read_a     (id_reg_rs1),
        .read_b     (id_reg_rs2),
        .write      (ex2_ret_reg.reg_rd),
        .write_data (ex2_ret_reg.reg_write_data),
        .write_en   (ex2_ret_reg.reg_write_en),

        .out_a      (id_rs1),
        .out_b      (id_rs2)
    );

endmodule
