// Two ports, A and B.
// Port A is read only.
// Port B is read or write.
module mem #(
    parameter int NUM_WORDS = 1024,
    parameter int WORD_SIZE = 32,
    parameter bit READ_ONLY = 0
) (
    input  logic                 clk,
    input  logic [WORD_SIZE-1:0] addr_a,
    output logic [WORD_SIZE-1:0] out_a,

    input  logic [WORD_SIZE-1:0] addr_b,
    input  logic [WORD_SIZE-1:0] write_data_b,
    input  logic                 write_en_b,
    output logic [WORD_SIZE-1:0] out_b // only valid when write_en_b is false
);
    // TODO: Currently we only support 4-byte aligned loads and stores

    logic [WORD_SIZE-1:0] words [0:NUM_WORDS-1];

    logic [$clog2(NUM_WORDS)+1 : 0] addr_index_a;
    logic [$clog2(NUM_WORDS)+1 : 0] addr_index_b;
    assign addr_index_a = addr_a[$clog2(NUM_WORDS)+1 : 2];
    assign addr_index_b = addr_b[$clog2(NUM_WORDS)+1 : 2];

    assign out_a = words[addr_index_a];
    assign out_b = words[addr_index_b];

    if (!READ_ONLY) begin : g_write
        always_ff @(posedge clk) begin
            if (write_en_b) begin
                words[addr_index_b] <= write_data_b;
            end
        end
    end

endmodule
