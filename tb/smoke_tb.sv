`timescale 1ns/1ps

module smoke_tb;

    logic clk;
    logic rst_n;

    core dut (.clk(clk), .rst_n(rst_n));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $readmemh("build/smoke.hex", dut.instr_fetch_.instr_mem.words);

        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        repeat (8) @(posedge clk);
        #1;

        assert (dut.rf.registers[3] == 32'd42)
            else $error("smoke: x3 = %0d, expected 42", dut.rf.registers[3]);

        $display("smoke passed: x3 = %0d", dut.rf.registers[3]);
        $finish;
    end

endmodule
