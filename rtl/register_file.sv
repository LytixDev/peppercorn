/*
 * Register file containing 32 registers that are 32-bit wide each.
 * Register 0 can not be written to and always stores 0.
 * Two read ports.
 * One write port.
 * Write happens on the first part of the rising edge, read happens on the second part.
 */

module register_file
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [4:0]  read_a,
    input  logic [4:0]  read_b,
    input  logic [4:0]  write,
    input  logic [31:0] write_data,
    input  logic        write_en,

    output logic [31:0] out_a,
    output logic [31:0] out_b
);

    logic [31:0] registers [0:31];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) registers[i] <= 32'b0;
        end else begin
            if (write_en && write != 5'b0) registers[write] <= write_data;
        end
    end

    assign out_a = registers[read_a];
    assign out_b = registers[read_b];

endmodule
