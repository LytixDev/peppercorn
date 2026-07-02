// Memory is stored in chunks of WORD_SIZE.
// All memory requests must be aligned to its byte size.
// For reads where the requested size is less than the WORD_SIZE, the most significant 
// bytes will be zeroed. 
//
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
    input  logic [1:0]           size_a, // funct3[1:0] encoding: 0b00 = 1 byte, 0b01 = 2 bytes, 0b10 = 4 bytes
    output logic [WORD_SIZE-1:0] out_a,

    input  logic [WORD_SIZE-1:0] addr_b,
    input  logic [1:0]           size_b, // funct3[1:0] encoding: 0b00 = 1 byte, 0b01 = 2 bytes, 0b10 = 4 bytes
    input  logic [WORD_SIZE-1:0] write_data_b, 
    input  logic                 write_en_b,
    output logic [WORD_SIZE-1:0] out_b // only valid when write_en_b is false
);
    logic [WORD_SIZE-1:0] words [0:NUM_WORDS-1];

    logic [$clog2(NUM_WORDS)+1 : 0] addr_index_a;
    logic [$clog2(NUM_WORDS)+1 : 0] addr_index_b;
    assign addr_index_a = addr_a[$clog2(NUM_WORDS)+1 : 2];
    assign addr_index_b = addr_b[$clog2(NUM_WORDS)+1 : 2];

    always_comb begin
        logic [4:0] shamt_a, shamt_b;
        logic [31:0] mask_a, mask_b;

        // First 3 bits represent the offset into the word, adding 3 zero bits
        // gives the shift amount (i.e. multiplying by 8).
        shamt_a = {addr_a[1:0], 3'b000};
        shamt_b = {addr_b[1:0], 3'b000};

        case (size_a)
            2'b00:   mask_a = 32'h000000FF;
            2'b01:   mask_a = 32'h0000FFFF;
            default: mask_a = 32'hFFFFFFFF;
        endcase
        case (size_b)
            2'b00:   mask_b = 32'h000000FF;
            2'b01:   mask_b = 32'h0000FFFF;
            default: mask_b = 32'hFFFFFFFF;
        endcase

        out_a = (words[addr_index_a] >> shamt_a) & mask_a;
        out_b = (words[addr_index_b] >> shamt_b) & mask_b;
    end

    if (!READ_ONLY) begin : g_write
        always_ff @(posedge clk) begin
            if (write_en_b) begin
                logic [4:0]  shamt;
                logic [31:0] wmask;
                shamt = {addr_b[1:0], 3'b000};
                case (size_b)
                    2'b00:   wmask = 32'h000000FF << shamt;
                    2'b01:   wmask = 32'h0000FFFF << shamt;
                    default: wmask = 32'hFFFFFFFF;
                endcase
                words[addr_index_b] <= (words[addr_index_b] & ~wmask) | ((write_data_b << shamt) & wmask);
            end
        end
    end

endmodule
