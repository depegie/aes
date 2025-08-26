`include "aes_defines.svh"

module aes128_ecb_iter_behav #(
    parameter int S_AXIS_WIDTH = 32,
    parameter int M_AXIS_WIDTH = 32
)(
    input          Clk,
    input          Rst,
    axis_if.slave  S_axis,
    axis_if.master M_axis
);

localparam int AES128_KEY_SIZE   = `AES128_KEY_SIZE;
localparam int AES_BLOCK_SIZE    = `AES_BLOCK_SIZE;
localparam int AES128_ROUNDS_NUM = `AES128_ROUNDS_NUM;

reg [AES128_KEY_SIZE-1 : 0] key_reg   = 'h0;
reg [AES128_KEY_SIZE-1 : 0] ke_key    = 'h0;
reg  [AES_BLOCK_SIZE-1 : 0] text_reg  = 'h0;
reg                         tlast_reg = 1'b0;

reg   [$clog2(AES128_KEY_SIZE/S_AXIS_WIDTH)-1 : 0] in_counter    = AES128_KEY_SIZE/S_AXIS_WIDTH-1;
reg    [$clog2(AES_BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] out_counter   = AES_BLOCK_SIZE/M_AXIS_WIDTH-1;
reg [int'($ceil($clog2(AES128_ROUNDS_NUM)))-1 : 0] round_counter = 'd0;

reg  [AES_BLOCK_SIZE-1 : 0] sb_state;
reg  [AES_BLOCK_SIZE-1 : 0] sr_state;
reg  [AES_BLOCK_SIZE-1 : 0] mc_state;
reg  [AES_BLOCK_SIZE-1 : 0] ark_state;
reg [AES128_KEY_SIZE-1 : 0] ark_key;

wire [AES128_KEY_SIZE-1 : 0] ke_new_key;
wire  [AES_BLOCK_SIZE-1 : 0] sb_new_state;
wire  [AES_BLOCK_SIZE-1 : 0] sr_new_state;
wire  [AES_BLOCK_SIZE-1 : 0] mc_new_state;
wire  [AES_BLOCK_SIZE-1 : 0] ark_new_state;

enum reg [5:0] {
    ST_KEY_IN         = 6'b1 << 0,
    ST_PLAINTEXT_IN   = 6'b1 << 1,
    ST_ZERO_ROUND     = 6'b1 << 2,
    ST_MIDDLE_ROUND   = 6'b1 << 3,
    ST_FINAL_ROUND    = 6'b1 << 4,
    ST_CIPHERTEXT_OUT = 6'b1 << 5
} state=ST_KEY_IN, next_state;

always_ff @(posedge Clk)
    if (Rst)
        state <= ST_KEY_IN;
    else
        state <= next_state;

always_comb begin
    case (state)
        ST_KEY_IN: begin
            if (S_axis.tvalid & S_axis.tready & ~|in_counter)
                next_state = ST_PLAINTEXT_IN;
            else
                next_state = ST_KEY_IN;
        end
        ST_PLAINTEXT_IN: begin
            if (S_axis.tvalid & S_axis.tready & ~|in_counter)
                next_state = ST_ZERO_ROUND;
            else
                next_state = ST_PLAINTEXT_IN;
        end
        ST_ZERO_ROUND: begin
            next_state = ST_MIDDLE_ROUND;
        end
        ST_MIDDLE_ROUND: begin
            if (round_counter == AES128_ROUNDS_NUM-1)
                next_state = ST_FINAL_ROUND;
            else
                next_state = ST_MIDDLE_ROUND;
        end
        ST_FINAL_ROUND: begin
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
end

always_comb begin
    case (state)
        ST_KEY_IN, ST_PLAINTEXT_IN:
            S_axis.tready = 1'b1;
        
        default:
            S_axis.tready = 1'b0;
    endcase
end

always_comb begin
    case (state)
        ST_CIPHERTEXT_OUT: begin
            M_axis.tvalid = 1'b1;
            M_axis.tdata = text_reg[M_AXIS_WIDTH-1 : 0];
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
end

always_ff @(posedge Clk) begin
    if (Rst)
        key_reg <= 128'h0;
    else if (state == ST_KEY_IN)
        key_reg <= {S_axis.tdata, key_reg[S_AXIS_WIDTH +: AES128_KEY_SIZE-S_AXIS_WIDTH]};
end

always_ff @(posedge Clk) begin
    if (Rst)
        ke_key <= 128'h0;
    else
        case (state)
            ST_PLAINTEXT_IN:
                ke_key <= key_reg;
            
            ST_MIDDLE_ROUND:
                ke_key <= ke_new_key;
        endcase
end

always_ff @(posedge Clk) begin
    if (Rst)
        text_reg <= 128'h0;
    else
        case(state)
            ST_PLAINTEXT_IN:
                text_reg <= {S_axis.tdata, text_reg[S_AXIS_WIDTH +: AES_BLOCK_SIZE-S_AXIS_WIDTH]};

            ST_ZERO_ROUND, ST_MIDDLE_ROUND, ST_FINAL_ROUND:
                text_reg <= ark_new_state;
            
            ST_CIPHERTEXT_OUT:
                text_reg <= text_reg >> M_AXIS_WIDTH;
        endcase
end

always @(posedge Clk)
    if (Rst)                                tlast_reg <= 1'b0;
    else if (S_axis.tvalid & S_axis.tready) tlast_reg <= S_axis.tlast;

always_ff @(posedge Clk)
    if (Rst)
        in_counter <= AES128_KEY_SIZE/S_AXIS_WIDTH-1;
    else
        case (state)
            ST_KEY_IN, ST_PLAINTEXT_IN:
                if (S_axis.tvalid & S_axis.tready & ~|in_counter)
                    in_counter <= AES128_KEY_SIZE/S_AXIS_WIDTH-1;
                else if (S_axis.tvalid & S_axis.tready)
                    in_counter <= in_counter - 'd1;
        endcase

always_ff @(posedge Clk)
    if (Rst)
        out_counter <= AES_BLOCK_SIZE/M_AXIS_WIDTH-1;
    else
        case (state)
            ST_CIPHERTEXT_OUT:
                out_counter <= out_counter - 'd1;
            
            default:
                out_counter <= AES_BLOCK_SIZE/M_AXIS_WIDTH-1;
        endcase

always_ff @(posedge Clk) begin
    if (Rst)
        round_counter <= 'd0;
    else
        case (state)
            ST_ZERO_ROUND, ST_MIDDLE_ROUND:
                round_counter <= round_counter + 'd1;
            
            default:
                round_counter <= 'd0;
        endcase
end

always_comb begin
    case (state)
        ST_ZERO_ROUND: begin
            ark_state = text_reg;
            ark_key = key_reg;
        end
        ST_MIDDLE_ROUND: begin
            sb_state = text_reg;
            sr_state = sb_new_state;
            mc_state = sr_new_state;
            ark_state = mc_new_state;
            ark_key = ke_new_key;
        end
        ST_FINAL_ROUND: begin
            sb_state = text_reg;
            sr_state = sb_new_state;
            ark_state = sr_new_state;
            ark_key = ke_new_key;
        end
        default: begin
            sb_state = 128'h0;
            sr_state = 128'h0;
            mc_state = 128'h0;
            ark_state = 128'h0;
            ark_key = 128'h0;
        end
    endcase
end

aes128_key_expansion_port ke_inst (
    .round_num ( round_counter ),
    .key       ( ke_key        ),
    .new_key   ( ke_new_key    )
);

aes_sub_bytes sb_inst (
    .state     ( sb_state     ),
    .new_state ( sb_new_state )
);

aes_shift_rows sr_inst (
    .state     ( sr_state     ),
    .new_state ( sr_new_state )
);

aes_mix_columns mc_inst (
    .state     ( mc_state     ),
    .new_state ( mc_new_state )
);

aes_add_round_key ark_inst (
    .state     ( ark_state     ),
    .key       ( ark_key       ),
    .new_state ( ark_new_state )
);

endmodule
