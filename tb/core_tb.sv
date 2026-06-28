`timescale 1ns/1ps

module core_tb;

    import peppercorn_pkg::*;

    logic clk;
    logic rst_n;

    core dut (
        .clk   (clk),
        .rst_n (rst_n)
    );

    function automatic logic [31:0] rv_add(logic [4:0] rd, rs1, rs2);
        return {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
    endfunction

    function automatic logic [31:0] rv_sub(logic [4:0] rd, rs1, rs2);
        return {7'b0100000, rs2, rs1, 3'b000, rd, 7'b0110011};
    endfunction

    function automatic logic [31:0] rv_addi(logic [4:0] rd, rs1, logic [11:0] imm12);
        return {imm12, rs1, 3'b000, rd, 7'b0010011};
    endfunction

    function automatic logic [31:0] rv_branch(logic [2:0] funct3,
                                              logic [4:0] rs1, rs2,
                                              logic signed [12:0] imm);
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], 7'b1100011};
    endfunction

    function automatic logic [31:0] rv_bne(logic [4:0] rs1, rs2, logic signed [12:0] imm);
        return rv_branch(3'b001, rs1, rs2, imm);
    endfunction

    function automatic logic [31:0] rv_jal(logic [4:0] rd, logic signed [20:0] imm);
        return {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
    endfunction

    function automatic logic [31:0] rv_lw(logic [4:0] rd, rs1, logic signed [11:0] imm);
        return {imm, rs1, 3'b010, rd, 7'b0000011};
    endfunction

    function automatic logic [31:0] rv_sw(logic [4:0] rs2, rs1, logic signed [11:0] imm);
        return {imm[11:5], rs2, rs1, 3'b010, imm[4:0], 7'b0100011};
    endfunction

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/core_tb.vcd");
        $dumpvars(0, core_tb);
    end

    task automatic reset_core;
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
    endtask

    initial begin
        // Test 1: straight-line arithmetic
        dut.memory.words[0] = rv_addi(5'd1, 5'd0, 12'd8);
        dut.memory.words[1] = rv_addi(5'd2, 5'd1, 12'd4);
        dut.memory.words[2] = rv_add (5'd3, 5'd1, 5'd2);
        dut.memory.words[3] = rv_sub (5'd4, 5'd3, 5'd1);

        reset_core();
        repeat (4) @(posedge clk);
        #1;

        assert (dut.rf.registers[1] == 32'd8)
            else $error("T1: r1 = %0d, expected 8",  dut.rf.registers[1]);
        assert (dut.rf.registers[2] == 32'd12)
            else $error("T1: r2 = %0d, expected 12", dut.rf.registers[2]);
        assert (dut.rf.registers[3] == 32'd20)
            else $error("T1: r3 = %0d, expected 20", dut.rf.registers[3]);
        assert (dut.rf.registers[4] == 32'd12)
            else $error("T1: r4 = %0d, expected 12", dut.rf.registers[4]);

        // Test 2: loop
        //   0: addi r1, x0, 0
        //   1: addi r2, x0, 4
        //   2: addi r1, r1, 1      loop:
        //   3: bne  r1, r2, -4     -> loop
        //   4: addi r3, x0, 99
        //   5: jal  r5, +8         -> word 7
        //   6: addi r4, x0, 123    (skipped)
        //   7: addi r6, x0, 7
        //   8: jal  x0, 0          halt
        dut.memory.words[0] = rv_addi (5'd1, 5'd0, 12'd0);
        dut.memory.words[1] = rv_addi (5'd2, 5'd0, 12'd4);
        dut.memory.words[2] = rv_addi (5'd1, 5'd1, 12'd1);
        dut.memory.words[3] = rv_bne  (5'd1, 5'd2, -13'sd4);
        dut.memory.words[4] = rv_addi (5'd3, 5'd0, 12'd99);
        dut.memory.words[5] = rv_jal  (5'd5, 21'sd8);
        dut.memory.words[6] = rv_addi (5'd4, 5'd0, 12'd123);
        dut.memory.words[7] = rv_addi (5'd6, 5'd0, 12'd7);
        dut.memory.words[8] = rv_jal  (5'd0, 21'sd0);

        reset_core();
        repeat (20) @(posedge clk);
        #1;

        assert (dut.rf.registers[1] == 32'd4)
            else $error("T2: r1 = %0d, expected 4",  dut.rf.registers[1]);
        assert (dut.rf.registers[2] == 32'd4)
            else $error("T2: r2 = %0d, expected 4",  dut.rf.registers[2]);
        assert (dut.rf.registers[3] == 32'd99)
            else $error("T2: r3 = %0d, expected 99", dut.rf.registers[3]);
        assert (dut.rf.registers[4] == 32'd0)
            else $error("T2: r4 = %0d, expected 0",  dut.rf.registers[4]);
        assert (dut.rf.registers[5] == 32'd24)
            else $error("T2: r5 = %0d, expected 24", dut.rf.registers[5]);
        assert (dut.rf.registers[6] == 32'd7)
            else $error("T2: r6 = %0d, expected 7",  dut.rf.registers[6]);

        // Test 3: store -> load round-trip (data mem has 4096 words)
        //   0: addi r1, x0, 100    base byte address (word 25)
        //   1: addi r2, x0, 42
        //   2: sw   r2, 0(r1)      mem[100] = 42
        //   3: lw   r3, 0(r1)      r3 = 42   (write N, read N+1)
        //   4: addi r5, x0, 7
        //   5: sw   r5, 4(r1)      mem[104] = 7
        //   6: lw   r6, 4(r1)      r6 = 7
        //   7: lw   r4, 0(r1)      r4 = 42   (re-read)
        //   8: jal  x0, 0          halt
        dut.memory.words[0] = rv_addi(5'd1, 5'd0, 12'd100);
        dut.memory.words[1] = rv_addi(5'd2, 5'd0, 12'd42);
        dut.memory.words[2] = rv_sw  (5'd2, 5'd1, 12'sd0);
        dut.memory.words[3] = rv_lw  (5'd3, 5'd1, 12'sd0);
        dut.memory.words[4] = rv_addi(5'd5, 5'd0, 12'd7);
        dut.memory.words[5] = rv_sw  (5'd5, 5'd1, 12'sd4);
        dut.memory.words[6] = rv_lw  (5'd6, 5'd1, 12'sd4);
        dut.memory.words[7] = rv_lw  (5'd4, 5'd1, 12'sd0);
        dut.memory.words[8] = rv_jal (5'd0, 21'sd0);

        reset_core();
        repeat (15) @(posedge clk);
        #1;

        assert (dut.rf.registers[3] == 32'd42)
            else $error("T3: r3 = %0d, expected 42", dut.rf.registers[3]);
        assert (dut.rf.registers[6] == 32'd7)
            else $error("T3: r6 = %0d, expected 7",  dut.rf.registers[6]);
        assert (dut.rf.registers[4] == 32'd42)
            else $error("T3: r4 = %0d, expected 42", dut.rf.registers[4]);

        $display("All tests passed");
        $finish;
    end

endmodule
