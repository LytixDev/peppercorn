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

`ifdef HEARTBEAT
    // Memory-mapped console: print bytes the core stores to 0x9000.
    always @(posedge clk) begin
        if (rst_n && dut.ex1_ex2_reg.mem_write_en
                  && dut.ex1_ex2_reg.alu_result == 32'h0000_9000)
            $write("%c", dut.ex1_ex2_reg.rs2[7:0]);
    end
`endif

    // Branch prediction accuracy data
    int unsigned bp_resolved;
    int unsigned bp_mispredicts;
    always @(posedge clk) begin
        if (!rst_n) begin
            bp_resolved    = 0;
            bp_mispredicts = 0;
        end else if (dut.id_ex1_reg.valid && (dut.id_ex1_reg.branch || dut.id_ex1_reg.jump)) begin
            bp_resolved++;
            if (dut.ex1_branch_mispredict) bp_mispredicts++;
        end
    end

    string hexfile;
    logic [31:0] exit_code;
    integer timeout;
    integer tohost;  // byte address, pinned per program (riscv-tests: 0x2000)

`ifdef BENCHMARK
    int unsigned bench_cycles;
    int unsigned bench_instrs;
`endif

    initial begin
        if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "build/add.hex";
        if (!$value$plusargs("TIMEOUT=%d", timeout)) timeout = 200_000;
        if (!$value$plusargs("TOHOST=%d", tohost)) tohost = 32'h0000_2000;
        $readmemh(hexfile, dut.memory.words);
        dut.memory.words[tohost >> 2] = 32'd0;  // clean start (may be past image)

        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

`ifdef BENCHMARK
        bench_cycles = 0;
        bench_instrs = 0;
`endif

        for (integer i = 0; i < timeout; i++) begin
            @(posedge clk); #1;
`ifdef BENCHMARK
            bench_cycles++;
            if (dut.ex2_ret_reg.valid)
                bench_instrs++;
`endif
`ifdef HEARTBEAT
            if (bench_cycles % 50000 == 0)
                $fdisplay(32'h8000_0002, "  hb: cyc=%0d instrs=%0d pc=%08h",
                          bench_cycles, bench_instrs, dut.if_pc);
`endif
            exit_code = dut.memory.words[tohost >> 2];
            if (exit_code !== 32'd0) begin
                if (exit_code == 32'd1)
`ifdef BENCHMARK
                    $display("PASS  %s cycles=%0d instrs=%0d bp_resolved=%0d bp_mispredicts=%0d",
                             hexfile, bench_cycles, bench_instrs, bp_resolved, bp_mispredicts);
`else
                    $display("PASS  %s", hexfile);
`endif
                else
`ifdef BENCHMARK
                    $display("FAIL  %s : test %0d cycles=%0d instrs=%0d bp_resolved=%0d bp_mispredicts=%0d",
                             hexfile, exit_code >> 1, bench_cycles, bench_instrs, bp_resolved, bp_mispredicts);
`else
                    $display("FAIL  %s : test %0d", hexfile, exit_code >> 1);
`endif
                if (bp_resolved > 0)
                    $display("BP    %0d/%0d correct (%.1f%%)",
                             bp_resolved - bp_mispredicts, bp_resolved,
                             100.0 * (bp_resolved - bp_mispredicts) / bp_resolved);
                $finish;
            end
        end

        $display("TIMEOUT  %s : tohost never written", hexfile);
        $finish;
    end

endmodule
