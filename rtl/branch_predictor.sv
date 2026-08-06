// Queried during the IF stage. Prediction ready in the same cycle.
// If target address is unavailable predict_taken is always false.
// Updated during the EX1 stage.
module branch_predictor
    import peppercorn_pkg::*;
#(
    parameter int BTB_ENTRIES = 256,
    parameter int BHT_ENTRIES = 128
)
(
    input logic clk,
    input logic rst_n,

    // Query
    input  logic [31:0] pc,
    output logic [31:0] target,
    output logic        predict_taken,

    // Update
    input logic [31:0] addr_update,
    input logic [31:0] target_update,
    input logic        actual_taken,
    input logic        update_en
);

    localparam int BTB_IDX_BITS = $clog2(BTB_ENTRIES);
    localparam int BHT_IDX_BITS = $clog2(BHT_ENTRIES);
    localparam int BTB_TAG_BITS = 32 - BTB_IDX_BITS;

    // 2-bit saturating counters
    // 00: not taken
    // 01: not taken
    // 10: taken
    // 11: taken
    logic [1:0] bht [BHT_ENTRIES];

    // Direct-mapped BTB
    logic [31:0]             btb   [BTB_ENTRIES];
    logic [BTB_TAG_BITS-1:0] tag   [BTB_ENTRIES];
    logic                    valid [BTB_ENTRIES];

    logic [BTB_IDX_BITS-1:0] btb_idx, btb_idx_update;
    logic [BHT_IDX_BITS-1:0] bht_idx, bht_idx_update;
    assign btb_idx        = pc[BTB_IDX_BITS-1:0];
    assign bht_idx        = pc[BHT_IDX_BITS-1:0];
    assign btb_idx_update = addr_update[BTB_IDX_BITS-1:0];
    assign bht_idx_update = addr_update[BHT_IDX_BITS-1:0];

    logic btb_hit;
    assign btb_hit       = valid[btb_idx] && tag[btb_idx] == pc[31:BTB_IDX_BITS];
    // Outputs
    assign predict_taken = bht[bht_idx][1] && btb_hit;
    assign target        = btb[btb_idx];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < BHT_ENTRIES; i++) bht[i]   <= 2'b0;
            for (int i = 0; i < BTB_ENTRIES; i++) btb[i]   <= 32'b0;
            for (int i = 0; i < BTB_ENTRIES; i++) valid[i] <= 0;
        end else if (update_en) begin
            // Update path
            if (actual_taken) begin
                btb[btb_idx_update]   <= target_update;
                tag[btb_idx_update]   <= addr_update[31:BTB_IDX_BITS];
                valid[btb_idx_update] <= 1'b1;
                if (bht[bht_idx_update] != 2'b11) bht[bht_idx_update] <= bht[bht_idx_update] + 1;
            end else begin
                if (bht[bht_idx_update] != 2'b00) bht[bht_idx_update] <= bht[bht_idx_update] - 1;
            end
        end
    end

endmodule
