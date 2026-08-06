module ras #(
    parameter int ENTRIES = 16
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 push_en,
    input  logic [31:0]          push_target,

    input   logic                pop_en,
    output  logic [31:0]         popped_target // available same-cycle
);
    localparam int IDX_BITS = $clog2(ENTRIES);
    // Circular buffer
    logic [31:0]         entries [0:ENTRIES-1];
    logic [IDX_BITS-1:0] idx;

    assign popped_target = entries[IDX_BITS'(idx - 1)];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ENTRIES; i++) entries[i] <= 32'b0;
            idx <= 0;
        end else begin
            if (push_en && pop_en) begin
                entries[IDX_BITS'(idx - 1)] <= push_target;
            end else if (push_en) begin
                entries[idx] <= push_target;
                if (idx == ENTRIES - 1) begin
                    idx <= 0;
                end else begin
                    idx <= idx + 1;
                end
            end else if (pop_en) begin
                if (idx == 0) begin
                    idx <= ENTRIES - 1;
                end else begin
                    idx <= idx - 1;
                end
            end
        end
    end

endmodule
