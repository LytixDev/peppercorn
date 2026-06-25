module mem #(
    parameter int NUM_WORDS = 1024,
    parameter int WORD_SIZE = 32,
    parameter bit READ_ONLY = 0
) (
    input  logic                 clk,
    input  logic [WORD_SIZE-1:0] addr,
    input  logic [WORD_SIZE-1:0] write_data,
    input  logic                 write_en,

    output logic [WORD_SIZE-1:0] out_word
);
    // TODO: Currently we only support 4-byte aligned loads and stores

    logic [WORD_SIZE-1:0] words [0:NUM_WORDS-1];

    logic [$clog2(NUM_WORDS)+1 : 0] addr_index;
    assign addr_index = addr[$clog2(NUM_WORDS)+1 : 2];

    if (!READ_ONLY) begin : g_write
        always_ff @(posedge clk) begin
            if (write_en) begin
                words[addr_index] <= write_data;
            end
        end
    end

    assign out_word = words[addr_index];

endmodule
