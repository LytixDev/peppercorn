`timescale 1ns/1ps

// riscv-tests runner
// load the binary as hex via +HEX
// run until the program writes its exit code to tohost (or timeout)
module run_tb;

    logic clk;
    logic rst_n;

    core dut (.clk(clk), .rst_n(rst_n));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    localparam int unsigned TOHOST  = 32'h0000_2000;  // pinned in riscv_test.ld
    localparam int          TIMEOUT = 200_000;

    string hexfile;
    logic [31:0] exit_code;

    initial begin
        if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "build/add.hex";
        $readmemh(hexfile, dut.memory.words);

        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (int i = 0; i < TIMEOUT; i++) begin
            @(posedge clk); #1;
            exit_code = dut.memory.words[TOHOST >> 2];
            if (exit_code !== 32'd0) begin
                if (exit_code == 32'd1)
                    $display("PASS  %s", hexfile);
                else
                    $display("FAIL  %s : test %0d", hexfile, exit_code >> 1);
                $finish;
            end
        end

        $display("TIMEOUT  %s : tohost never written", hexfile);
        $finish;
    end

endmodule
