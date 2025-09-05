`include "aes_defines.svh"

module aes128_ecb_pipe_behav #(
    parameter int S_AXIS_WIDTH = 32,
    parameter int M_AXIS_WIDTH = 32
)(
    input          Clk,
    input          Rst,
    axis_if.slave  S_axis,
    axis_if.master M_axis
);
    localparam int ROUNDS_NUM = `AES128_ROUNDS_NUM;
    localparam int KEY_SIZE   = `AES128_KEY_SIZE;
    localparam int BLOCK_SIZE = `AES_BLOCK_SIZE;

    reg   [$clog2(KEY_SIZE/S_AXIS_WIDTH)-1 : 0] in_counter  = KEY_SIZE/S_AXIS_WIDTH-1;
    reg [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] out_counter = BLOCK_SIZE/M_AXIS_WIDTH-1;

    reg   [KEY_SIZE-1 : 0] key_reg       = 128'h0;
    reg [BLOCK_SIZE-1 : 0] plaintext_reg = 128'h0;
    reg                    tlast_reg     = 1'b0;

    reg  plaintext_valid;
    wire plaintext_ready;

    reg [BLOCK_SIZE-1 : 0] block_reg   [ROUNDS_NUM+1];
    reg   [KEY_SIZE-1 : 0] ke_key_reg  [ROUNDS_NUM];
    reg                    block_valid [ROUNDS_NUM+1];
    wire                   block_ready [ROUNDS_NUM+1];
    reg                    block_last  [ROUNDS_NUM+1];

    wire   [KEY_SIZE-1 : 0] ke_output_key    [ROUNDS_NUM];
    wire [BLOCK_SIZE-1 : 0] sb_output_block  [ROUNDS_NUM];
    wire [BLOCK_SIZE-1 : 0] sr_output_block  [ROUNDS_NUM];
    wire [BLOCK_SIZE-1 : 0] mc_output_block  [ROUNDS_NUM-1];
    wire [BLOCK_SIZE-1 : 0] ark_output_block [ROUNDS_NUM+1];

    enum reg [1:0] {
        ST_KEY_IN         = 2'b1 << 0,
        ST_PLAINTEXT_IN   = 2'b1 << 1
    } state=ST_KEY_IN, next_state;

    always_ff @(posedge Clk)
        if (Rst)
            state <= ST_KEY_IN;
        else
            state <= next_state;

    always_comb
        case (state)
            ST_KEY_IN: begin
                if (S_axis.tvalid & S_axis.tready & ~|in_counter)
                    next_state = ST_PLAINTEXT_IN;
                else
                    next_state = ST_KEY_IN;
            end

            ST_PLAINTEXT_IN: begin
                if (S_axis.tvalid & S_axis.tready & S_axis.tlast)
                    next_state = ST_KEY_IN;
                else
                    next_state = ST_PLAINTEXT_IN;
            end
        endcase

    always_comb
        case (state)
            ST_KEY_IN, ST_PLAINTEXT_IN:
                S_axis.tready = plaintext_ready;
            
            default:
                S_axis.tready = 1'b0;
        endcase
    
    always_comb begin
        M_axis.tvalid = block_valid[ROUNDS_NUM];
        M_axis.tdata = block_reg[ROUNDS_NUM][M_AXIS_WIDTH-1 : 0];
        M_axis.tkeep = {(M_AXIS_WIDTH/8){1'b1}};
        M_axis.tlast = (~|out_counter) ? block_last[ROUNDS_NUM] : 1'b0;
    end

    always @(posedge Clk)
        if (S_axis.tvalid & S_axis.tready)
            tlast_reg <= S_axis.tlast;

    always_ff @(posedge Clk)
        if (Rst)
            out_counter <= BLOCK_SIZE/M_AXIS_WIDTH-1;
        else if (M_axis.tvalid & M_axis.tready & ~|out_counter)
            out_counter <= BLOCK_SIZE/M_AXIS_WIDTH-1;
        else if (M_axis.tvalid & M_axis.tready & M_AXIS_WIDTH != BLOCK_SIZE)
            out_counter <= out_counter - 'd1;

    always_ff @(posedge Clk)
        if (Rst)
            key_reg <= 128'h0;
        else
            case (state)
                ST_KEY_IN:
                    if (S_axis.tvalid & S_axis.tready & S_AXIS_WIDTH == BLOCK_SIZE)
                        key_reg <= S_axis.tdata;
                    else if (S_axis.tvalid & S_axis.tready)
                        key_reg <= {S_axis.tdata, key_reg[S_AXIS_WIDTH +: KEY_SIZE-S_AXIS_WIDTH]};
            endcase

    always_ff @(posedge Clk)
        if (Rst)
            plaintext_reg <= 128'h0;
        else
            case (state)
                ST_PLAINTEXT_IN:
                    if (S_axis.tvalid & S_axis.tready & S_AXIS_WIDTH == BLOCK_SIZE)
                        plaintext_reg <= S_axis.tdata;
                    else if (S_axis.tvalid & S_axis.tready)
                        plaintext_reg <= {S_axis.tdata, plaintext_reg[S_AXIS_WIDTH +: BLOCK_SIZE-S_AXIS_WIDTH]};
            endcase

    always_ff @(posedge Clk)
        if (Rst)
            in_counter <= KEY_SIZE/S_AXIS_WIDTH-1;
        else if (S_AXIS_WIDTH != BLOCK_SIZE)
            case (state)
                ST_KEY_IN:
                    if (S_axis.tvalid & S_axis.tready & ~|in_counter)
                        in_counter <= KEY_SIZE/S_AXIS_WIDTH-1;
                    else if (S_axis.tvalid & S_axis.tready)
                        in_counter <= in_counter - 'd1;

                ST_PLAINTEXT_IN:
                    if (S_axis.tvalid & S_axis.tready & S_axis.tlast)
                        in_counter <= BLOCK_SIZE/S_AXIS_WIDTH-1;
                    else if (S_axis.tvalid & S_axis.tready)
                        in_counter <= in_counter - 'd1;
            endcase
    
    always_ff @(posedge Clk)
        if (Rst) begin
            block_valid[0] <= 1'b0;
            block_reg[0] <= 128'h0;
            ke_key_reg[0] <= 128'h0;
            block_last[0] <= 1'b0;
        end
        else if (plaintext_valid & plaintext_ready) begin
            block_valid[0] <= 1'b1;
            block_reg[0] <= ark_output_block[0];
            ke_key_reg[0] <= key_reg;
            block_last[0] <= tlast_reg;
        end
        else if (block_valid[0] & block_ready[0]) begin
            block_valid[0] <= 1'b0;
            block_reg[0] <= 128'h0;
            ke_key_reg[0] <= 128'h0;
            block_last[0] <= 1'b0;
        end
    
    generate
        for (genvar r=1; r<ROUNDS_NUM; r++) begin
            assign block_ready[r-1] = ~block_valid[r] | (block_valid[r] & block_ready[r]);

            always_ff @(posedge Clk)
                if (Rst) begin
                    block_valid[r] <= 1'b0;
                    block_reg[r] <= 128'h0;
                    ke_key_reg[r] <= 128'h0;
                    block_last[r] <= 1'b0;
                end
                else if (block_valid[r-1] & block_ready[r-1]) begin
                    block_valid[r] <= block_valid[r-1];
                    block_reg[r] <= ark_output_block[r];
                    ke_key_reg[r] <= ke_output_key[r-1];
                    block_last[r] <= block_last[r-1];
                end
                else if (block_valid[r] & block_ready[r]) begin
                    block_valid[r] <= 1'b0;
                    block_reg[r] <= 128'h0;
                    ke_key_reg[r] <= 128'h0;
                    block_last[r] <= 1'b0;
                end
        end
    endgenerate

    assign block_ready[ROUNDS_NUM-1] = ~block_valid[ROUNDS_NUM] | (block_valid[ROUNDS_NUM] & block_ready[ROUNDS_NUM]);

    always_ff @(posedge Clk)
        if (Rst) begin
            block_valid[ROUNDS_NUM] <= 1'b0;
            block_reg[ROUNDS_NUM] <= 128'h0;
            block_last[ROUNDS_NUM] <= 1'b0;
        end
        else if (block_valid[ROUNDS_NUM-1] & block_ready[ROUNDS_NUM-1]) begin
            block_valid[ROUNDS_NUM] <= block_valid[ROUNDS_NUM-1];
            block_reg[ROUNDS_NUM] <= ark_output_block[ROUNDS_NUM];
            block_last[ROUNDS_NUM] <= block_last[ROUNDS_NUM-1];
        end
        else if (block_valid[ROUNDS_NUM] & block_ready[ROUNDS_NUM]) begin
            block_valid[ROUNDS_NUM] <= 1'b0;
            block_reg[ROUNDS_NUM] <= 128'h0;
            block_last[ROUNDS_NUM] <= 1'b0;
        end
        else if (M_axis.tvalid & M_axis.tready) begin
            block_valid[ROUNDS_NUM] <= block_valid[ROUNDS_NUM];
            block_reg[ROUNDS_NUM] <= block_reg[ROUNDS_NUM] >> M_AXIS_WIDTH;
            block_last[ROUNDS_NUM] <= block_last[ROUNDS_NUM];
        end

    assign block_ready[ROUNDS_NUM] = M_axis.tvalid & M_axis.tready & ~|out_counter;

    always_ff @(posedge Clk) begin
        if (Rst)
            plaintext_valid <= 1'b0;
        else if (state == ST_PLAINTEXT_IN & S_axis.tvalid & S_axis.tready & ~|in_counter)
            plaintext_valid <= 1'b1;
        else if (plaintext_valid & plaintext_ready)
            plaintext_valid <= 1'b0;
    end

    assign plaintext_ready = ~block_valid[0] | (block_valid[0] & block_ready[0]);

    generate
        for (genvar r=0; r<=ROUNDS_NUM; r++) begin
            // zero round
            if (r == 0) begin
                aes_add_round_key ark_inst (
                    .block     ( plaintext_reg ),
                    .key       ( key_reg ),
                    .new_block ( ark_output_block[r] )
                );
            end
            // final round
            else if (r == ROUNDS_NUM) begin
                aes128_key_expansion_param #(
                    .ROUND_NUM(r)
                ) ke_inst (
                    .key     ( ke_key_reg[r-1] ),
                    .new_key ( ke_output_key[r-1] )
                );

                aes_sub_bytes sb_inst (
                    .block     ( block_reg[r-1] ),
                    .new_block ( sb_output_block[r-1] )
                );

                aes_shift_rows sr_inst (
                    .block     ( sb_output_block[r-1] ),
                    .new_block ( sr_output_block[r-1] )
                );

                aes_add_round_key ark_inst (
                    .block     ( sr_output_block[r-1] ),
                    .key       ( ke_output_key[r-1] ),
                    .new_block ( ark_output_block[r] )
                );
            end
            // middle round
            else begin
                aes128_key_expansion_param #(
                    .ROUND_NUM(r)
                ) ke_inst (
                    .key     ( ke_key_reg[r-1] ),
                    .new_key ( ke_output_key[r-1] )
                );

                aes_sub_bytes sb_inst (
                    .block     ( block_reg[r-1] ),
                    .new_block ( sb_output_block[r-1] )
                );

                aes_shift_rows sr_inst (
                    .block     ( sb_output_block[r-1] ),
                    .new_block ( sr_output_block[r-1] )
                );

                aes_mix_columns mc_inst (
                    .block     ( sr_output_block[r-1] ),
                    .new_block ( mc_output_block[r-1] )
                );

                aes_add_round_key ark_inst (
                    .block     ( mc_output_block[r-1] ),
                    .key       ( ke_output_key[r-1] ),
                    .new_block ( ark_output_block[r] )
                );
            end
        end
    endgenerate

endmodule
