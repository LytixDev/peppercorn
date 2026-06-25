`timescale 1ns/1ps

module alu_tb;

    import peppercorn_pkg::*;

    alu_op_type  alu_op;
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] out;

    alu dut (
        .alu_op (alu_op),
        .a      (a),
        .b      (b),
        .out    (out)
    );

    initial begin
        $dumpfile("build/alu_tb.vcd");
        $dumpvars(0, alu_tb);
    end

    int errors = 0;
    int total  = 0;

    task automatic check(input alu_op_type op, input logic [31:0] ia, ib, iexp);
        alu_op = op;
        a      = ia;
        b      = ib;
        #1;  // settle
        total++;
        if (out !== iexp) begin
            errors++;
            $error("%s a=%h b=%h: got %h, expected %h", op.name(), ia, ib, out, iexp);
        end
    endtask

    // NOTE: These cases are LLM generated.
    initial begin
        // ADD
        check(ALU_ADD,  32'd5,        32'd7,         32'd12);
        check(ALU_ADD,  32'hFFFF_FFFF,32'd1,         32'd0);          // -1 + 1 wraps
        check(ALU_ADD,  32'hFFFF_FFFF,32'hFFFF_FFFF, 32'hFFFF_FFFE);  // -1 + -1

        // SUB
        check(ALU_SUB,  32'd20,       32'd8,         32'd12);
        check(ALU_SUB,  32'd0,        32'd1,         32'hFFFF_FFFF);  // 0 - 1 = -1
        check(ALU_SUB,  32'd8,        32'd20,        32'hFFFF_FFF4);  // = -12

        // SLL
        check(ALU_SLL,  32'd1,        32'd4,         32'd16);
        check(ALU_SLL,  32'hDEAD_BEEF,32'd0,         32'hDEAD_BEEF);
        check(ALU_SLL,  32'd1,        32'd31,        32'h8000_0000);
        check(ALU_SLL,  32'd1,        32'd32,        32'd1);          // 32 & 31 = 0

        // SLT (signed)
        check(ALU_SLT,  32'hFFFF_FFFF,32'd1,         32'd1);          // -1 < 1
        check(ALU_SLT,  32'd1,        32'hFFFF_FFFF, 32'd0);          // 1 < -1 false
        check(ALU_SLT,  32'd5,        32'd5,         32'd0);
        check(ALU_SLT,  32'h8000_0000,32'h7FFF_FFFF, 32'd1);          // INT_MIN < INT_MAX

        // SLTU (unsigned) -- same bits as SLT, opposite answers
        check(ALU_SLTU, 32'hFFFF_FFFF,32'd1,         32'd0);          // huge < 1 false
        check(ALU_SLTU, 32'd1,        32'hFFFF_FFFF, 32'd1);
        check(ALU_SLTU, 32'd5,        32'd5,         32'd0);

        // XOR
        check(ALU_XOR,  32'hF0F0_F0F0,32'h0F0F_0F0F, 32'hFFFF_FFFF);
        check(ALU_XOR,  32'hDEAD_BEEF,32'hDEAD_BEEF, 32'd0);          // a ^ a = 0
        check(ALU_XOR,  32'hAAAA_AAAA,32'h5555_5555, 32'hFFFF_FFFF);

        // SRL (logical)
        check(ALU_SRL,  32'h8000_0000,32'd4,         32'h0800_0000);  // fills 0
        check(ALU_SRL,  32'hDEAD_BEEF,32'd0,         32'hDEAD_BEEF);
        check(ALU_SRL,  32'hFFFF_FFFF,32'd31,        32'd1);

        // SRA (arithmetic)
        check(ALU_SRA,  32'h8000_0000,32'd4,         32'hF800_0000);  // sign-extends
        check(ALU_SRA,  32'h4000_0000,32'd4,         32'h0400_0000);  // positive: like SRL
        check(ALU_SRA,  32'hFFFF_FFFF,32'd1,         32'hFFFF_FFFF);  // -1 >>> 1 = -1

        // OR
        check(ALU_OR,   32'hF0F0_F0F0,32'h0F0F_0F0F, 32'hFFFF_FFFF);
        check(ALU_OR,   32'hDEAD_BEEF,32'd0,         32'hDEAD_BEEF);

        // AND
        check(ALU_AND,  32'hFF00_FF00,32'h0FF0_0FF0, 32'h0F00_0F00);
        check(ALU_AND,  32'hDEAD_BEEF,32'd0,         32'd0);
        check(ALU_AND,  32'hDEAD_BEEF,32'hFFFF_FFFF, 32'hDEAD_BEEF);

        if (errors == 0) $display("ALU: all %0d vectors passed", total);
        else             $display("ALU: %0d / %0d vectors FAILED", errors, total);
        $finish;
    end

endmodule
