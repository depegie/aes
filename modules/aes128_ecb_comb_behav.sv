`include "aes_defines.svh"

module aes128_ecb_comb_behav #(
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

    reg   [KEY_SIZE-1 : 0] key_reg        = 'h0;
    reg [BLOCK_SIZE-1 : 0] plaintext_reg  = 'h0;
    reg [BLOCK_SIZE-1 : 0] ciphertext_reg = 'h0;
    reg                    tlast_reg      = 1'b0;

    reg   [$clog2(KEY_SIZE/S_AXIS_WIDTH)-1 : 0] in_counter  = KEY_SIZE/S_AXIS_WIDTH-1;
    reg [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] out_counter = BLOCK_SIZE/M_AXIS_WIDTH-1;

    wire   [KEY_SIZE-1 : 0] ke_output_key    [ROUNDS_NUM];
    wire [BLOCK_SIZE-1 : 0] sb_output_block  [ROUNDS_NUM];
    wire [BLOCK_SIZE-1 : 0] sr_output_block  [ROUNDS_NUM];
    wire [BLOCK_SIZE-1 : 0] mc_output_block  [ROUNDS_NUM-1];
    wire [BLOCK_SIZE-1 : 0] ark_output_block [ROUNDS_NUM+1];

    enum reg [3:0] {
        ST_KEY_IN         = 4'b1 << 0,
        ST_PLAINTEXT_IN   = 4'b1 << 1,
        ST_CIPHER         = 4'b1 << 2,
        ST_CIPHERTEXT_OUT = 4'b1 << 3
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
                if (S_axis.tvalid & S_axis.tready & ~|in_counter)
                    next_state = ST_CIPHER;
                else
                    next_state = ST_PLAINTEXT_IN;
            end
            ST_CIPHER: begin
                next_state = ST_CIPHERTEXT_OUT;
            end
            ST_CIPHERTEXT_OUT: begin
                if (M_axis.tvalid & M_axis.tready & M_axis.tlast & ~|out_counter)
                    next_state = ST_KEY_IN;
                else if (M_axis.tvalid & M_axis.tready & ~|out_counter)
                    next_state = ST_PLAINTEXT_IN;
                else
                    next_state = ST_CIPHERTEXT_OUT;
            end
            default: begin
                next_state = ST_KEY_IN;
            end
        endcase

    always_comb
        case (state)
            ST_KEY_IN, ST_PLAINTEXT_IN:
                S_axis.tready = 1'b1;
            
            default:
                S_axis.tready = 1'b0;
        endcase

    always_comb
        case (state)
            ST_CIPHERTEXT_OUT: begin
                M_axis.tvalid = 1'b1;
                M_axis.tdata = ciphertext_reg[M_AXIS_WIDTH-1 : 0];
                M_axis.tkeep = {(M_AXIS_WIDTH/8){1'b1}};
                M_axis.tlast = (~|out_counter) ? tlast_reg : 1'b0;
            end

            default: begin
                M_axis.tvalid = 1'b0;
                M_axis.tdata = 128'h0;
                M_axis.tkeep = 16'b0;
                M_axis.tlast = 1'b0;
            end
        endcase

    always_ff @(posedge Clk)
        if (Rst)
            key_reg <= 128'h0;
        else
            case (state)
                ST_KEY_IN:
                    if (S_axis.tvalid & S_axis.tready && S_AXIS_WIDTH == BLOCK_SIZE)
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
                    if (S_axis.tvalid & S_axis.tready && S_AXIS_WIDTH == BLOCK_SIZE)
                        plaintext_reg <= S_axis.tdata;
                    else if (S_axis.tvalid & S_axis.tready)
                        plaintext_reg <= {S_axis.tdata, plaintext_reg[S_AXIS_WIDTH +: BLOCK_SIZE-S_AXIS_WIDTH]};
            endcase

    always_ff @(posedge Clk)
        if (Rst)
            ciphertext_reg <= 128'h0;
        else
            case (state)
                ST_CIPHER:
                    ciphertext_reg <= ark_output_block[ROUNDS_NUM];
                
                ST_CIPHERTEXT_OUT:
                    if (M_axis.tvalid & M_axis.tready)
                        ciphertext_reg <= ciphertext_reg >> M_AXIS_WIDTH;
            endcase

    always @(posedge Clk)
        if (S_axis.tvalid & S_axis.tready)
            tlast_reg <= S_axis.tlast;

    always_ff @(posedge Clk)
        if (Rst)
            in_counter <= KEY_SIZE/S_AXIS_WIDTH-1;
        else
            case (state)
                ST_KEY_IN:
                    if (S_axis.tvalid & S_axis.tready & ~|in_counter)
                        in_counter <= KEY_SIZE/S_AXIS_WIDTH-1;
                    else if (S_axis.tvalid & S_axis.tready)
                        in_counter <= in_counter - 'd1;

                ST_PLAINTEXT_IN:
                    if (S_axis.tvalid & S_axis.tready & ~|in_counter)
                        in_counter <= BLOCK_SIZE/S_AXIS_WIDTH-1;
                    else if (S_axis.tvalid & S_axis.tready)
                        in_counter <= in_counter - 'd1;
                
                default:
                    if (tlast_reg)
                        in_counter <= KEY_SIZE/S_AXIS_WIDTH-1;
                    else
                        in_counter <= BLOCK_SIZE/S_AXIS_WIDTH-1;
            endcase

    always_ff @(posedge Clk)
        if (Rst)
            out_counter <= BLOCK_SIZE/M_AXIS_WIDTH-1;
        else
            case (state)
                ST_CIPHERTEXT_OUT:
                    if (M_axis.tvalid & M_axis.tready)
                        out_counter <= out_counter - 'd1;
                
                default:
                    out_counter <= BLOCK_SIZE/M_AXIS_WIDTH-1;
            endcase

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
                    .key     ( ke_output_key[r-2] ),
                    .new_key ( ke_output_key[r-1] )
                );

                aes_sub_bytes sb_inst (
                    .block     ( ark_output_block[r-1] ),
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
                    .key     ( r == 1 ? key_reg : ke_output_key[r-2] ),
                    .new_key ( ke_output_key[r-1] )
                );

                aes_sub_bytes sb_inst (
                    .block     ( ark_output_block[r-1] ),
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
