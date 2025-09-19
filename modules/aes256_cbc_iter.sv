`include "aes_defines.svh"

module aes256_cbc_iter #(
    parameter int S_AXIS_WIDTH = 8,
    parameter int M_AXIS_WIDTH = 8
)(
    input          Clk,
    input          Rst,
    axis_if.slave  S_axis,
    axis_if.master M_axis
);

localparam int KEY_LENGTH    = `AES_256_KEY_LENGTH;
localparam int BLOCK_SIZE    = `AES_BLOCK_SIZE;
localparam int ROUNDS_NUMBER = `AES_256_ROUNDS_NUMBER;

reg [$clog2(BLOCK_SIZE/S_AXIS_WIDTH)-1 : 0] input_cnt;
reg [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] output_cnt;

reg [int'($ceil($clog2(ROUNDS_NUMBER)))-1 : 0] ke_cnt;
reg [int'($ceil($clog2(ROUNDS_NUMBER)))-1 : 0] c_cnt;

reg [BLOCK_SIZE-1 : 0] key_reg[ROUNDS_NUMBER+1];
reg [BLOCK_SIZE-1 : 0] iv_reg;
reg [BLOCK_SIZE-1 : 0] input_text_reg;
reg [BLOCK_SIZE-1 : 0] output_block_reg;

reg [BLOCK_SIZE-1 : 0] input_block_areg;
reg [BLOCK_SIZE-1 : 0] output_text_areg;

reg  [KEY_LENGTH-1 : 0] ke_key_areg;
wire [BLOCK_SIZE-1 : 0] ke_new_key;

reg                     round_last_areg;
reg  [BLOCK_SIZE-1 : 0] round_key_areg;
reg  [BLOCK_SIZE-1 : 0] round_input_block_areg;
wire [BLOCK_SIZE-1 : 0] round_output_block;

reg enc_reg;
reg last_reg;
reg ke_pending_reg;

enum reg [6:0] {
    ST_KEY_0         = 7'b1 << 0,
    ST_KEY_1         = 7'b1 << 1,
    ST_IV            = 7'b1 << 2,
    ST_TEXT_IN       = 7'b1 << 3,
    ST_KEY_EXPANSION = 7'b1 << 4,
    ST_CIPHER        = 7'b1 << 5,
    ST_TEXT_OUT      = 7'b1 << 6
} state, next_state;

always_ff @(posedge Clk)
    if (Rst)
        state <= ST_KEY_0;
    else
        state <= next_state;

always_comb
    case (state)
        ST_KEY_0: begin
            if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_KEY_1;
            else
                next_state = ST_KEY_0;
        end

        ST_KEY_1: begin
            if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_IV;
            else
                next_state = ST_KEY_1;
        end

        ST_IV: begin
            if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_TEXT_IN;
            else
                next_state = ST_IV;
        end

        ST_TEXT_IN: begin
            if (S_axis.tvalid & S_axis.tready & (&input_cnt) & ke_cnt == ROUNDS_NUMBER)
                next_state = ST_CIPHER;
            else if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_KEY_EXPANSION;
            else
                next_state = ST_TEXT_IN;
        end

        ST_KEY_EXPANSION: begin
            if (ke_cnt == ROUNDS_NUMBER)
                next_state = ST_CIPHER;
            else
                next_state = ST_KEY_EXPANSION;
        end

        ST_CIPHER: begin
            if (c_cnt == ROUNDS_NUMBER)
                next_state = ST_TEXT_OUT;
            else
                next_state = ST_CIPHER;
        end

        ST_TEXT_OUT: begin
            if (M_axis.tvalid & M_axis.tready & M_axis.tlast & (&output_cnt))
                next_state = ST_KEY_0;
            else if (M_axis.tvalid & M_axis.tready & (&output_cnt))
                next_state = ST_TEXT_IN;
            else
                next_state = ST_TEXT_OUT;
        end
    endcase

always_comb
    case (state)
        ST_KEY_0, ST_KEY_1, ST_IV, ST_TEXT_IN:
            S_axis.tready = 1'b1;
        
        default:
            S_axis.tready = 1'b0;
    endcase

always_comb
    case (state)
        ST_TEXT_OUT: begin
            M_axis.tvalid = 1'b1;
            M_axis.tdata = output_text_areg[output_cnt*M_AXIS_WIDTH +: M_AXIS_WIDTH];
            M_axis.tkeep = {(M_AXIS_WIDTH/8){1'b1}};
            M_axis.tlast = ((&output_cnt)) ? last_reg : 1'b0;
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
        input_cnt <= 0;
    else
        case (state)
            ST_KEY_0, ST_KEY_1, ST_IV, ST_TEXT_IN:
                if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                    input_cnt <= 0;
                else if (S_axis.tvalid & S_axis.tready)
                    input_cnt <= input_cnt + 'd1;
            
            default:
                input_cnt <= 0;
        endcase

always_ff @(posedge Clk)
    if (Rst)
        output_cnt <= 0;
    else
        case (state)
            ST_TEXT_OUT:
                if (M_axis.tvalid & M_axis.tready)
                    output_cnt <= output_cnt + 'd1;
            
            default:
                output_cnt <= 0;
        endcase

always_ff @(posedge Clk)
    if (Rst) begin
        ke_cnt <= 2;
    end
    else if (state == ST_KEY_0) begin
        ke_cnt <= 2;
    end
    else if (ke_pending_reg & ke_cnt < ROUNDS_NUMBER) begin
        ke_cnt <= ke_cnt + 1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        c_cnt <= 1;
    end
    else if (state == ST_CIPHER) begin
        c_cnt <= c_cnt + 1;
    end
    else begin
        c_cnt <= 1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        for (int b=0; b<=ROUNDS_NUMBER; b++) key_reg[b] <= 128'h0;
    end
    else if (state == ST_KEY_0 & S_axis.tvalid & S_axis.tready) begin
        key_reg[0][input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state == ST_KEY_1 & S_axis.tvalid & S_axis.tready) begin
        key_reg[1][input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (ke_pending_reg) begin
        key_reg[ke_cnt] <= ke_new_key;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        iv_reg <= 128'h0;
    end
    else if (state == ST_IV & S_axis.tvalid & S_axis.tready) begin
        iv_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state == ST_TEXT_OUT & M_axis.tvalid & M_axis.tready & (&output_cnt)) begin
        iv_reg <= enc_reg ? output_text_areg : input_text_reg;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_text_reg <= 128'h0;
    end
    else if (state == ST_TEXT_IN & S_axis.tvalid & S_axis.tready) begin
        input_text_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        output_block_reg <= 128'h0;
    end
    else if (state == ST_CIPHER) begin
        output_block_reg <= round_output_block;
    end

always_comb
    if (c_cnt == 1)
        input_block_areg = (enc_reg) ? input_text_reg ^ iv_reg : input_text_reg;
    else
        input_block_areg = output_block_reg;

always_comb
    output_text_areg = (enc_reg) ? output_block_reg : output_block_reg ^ iv_reg;

always_comb
    case (ke_cnt)
        2:       ke_key_areg = { key_reg[ 1], key_reg[ 0] };
        3:       ke_key_areg = { key_reg[ 2], key_reg[ 1] };
        4:       ke_key_areg = { key_reg[ 3], key_reg[ 2] };
        5:       ke_key_areg = { key_reg[ 4], key_reg[ 3] };
        6:       ke_key_areg = { key_reg[ 5], key_reg[ 4] };
        7:       ke_key_areg = { key_reg[ 6], key_reg[ 5] };
        8:       ke_key_areg = { key_reg[ 7], key_reg[ 6] };
        9:       ke_key_areg = { key_reg[ 8], key_reg[ 7] };
        10:      ke_key_areg = { key_reg[ 9], key_reg[ 8] };
        11:      ke_key_areg = { key_reg[10], key_reg[ 9] };
        12:      ke_key_areg = { key_reg[11], key_reg[10] };
        13:      ke_key_areg = { key_reg[12], key_reg[11] };
        14:      ke_key_areg = { key_reg[13], key_reg[12] };
        default: ke_key_areg = 256'h0;
    endcase

always_comb
    round_last_areg = (c_cnt == ROUNDS_NUMBER) ? 1'b1 : 1'b0;

always_comb
    case (c_cnt)
        1:       round_key_areg = (enc_reg) ? key_reg[ 1] : key_reg[13];
        2:       round_key_areg = (enc_reg) ? key_reg[ 2] : key_reg[12];
        3:       round_key_areg = (enc_reg) ? key_reg[ 3] : key_reg[11];
        4:       round_key_areg = (enc_reg) ? key_reg[ 4] : key_reg[10];
        5:       round_key_areg = (enc_reg) ? key_reg[ 5] : key_reg[ 9];
        6:       round_key_areg = (enc_reg) ? key_reg[ 6] : key_reg[ 8];
        7:       round_key_areg = (enc_reg) ? key_reg[ 7] : key_reg[ 7];
        8:       round_key_areg = (enc_reg) ? key_reg[ 8] : key_reg[ 6];
        9:       round_key_areg = (enc_reg) ? key_reg[ 9] : key_reg[ 5];
        10:      round_key_areg = (enc_reg) ? key_reg[10] : key_reg[ 4];
        11:      round_key_areg = (enc_reg) ? key_reg[11] : key_reg[ 3];
        12:      round_key_areg = (enc_reg) ? key_reg[12] : key_reg[ 2];
        13:      round_key_areg = (enc_reg) ? key_reg[13] : key_reg[ 1];
        14:      round_key_areg = (enc_reg) ? key_reg[14] : key_reg[ 0];
        default: round_key_areg = 128'h0;
    endcase

always_comb
    if (enc_reg) round_input_block_areg = (c_cnt == 1) ? input_block_areg ^ key_reg[ 0] : input_block_areg;
    else         round_input_block_areg = (c_cnt == 1) ? input_block_areg ^ key_reg[14] : input_block_areg;

always @(posedge Clk)
    if (Rst) begin
        enc_reg <= 1'b0;
        last_reg <= 1'b0;
    end
    else if (S_axis.tvalid & S_axis.tready) begin
        enc_reg <= S_axis.tuser;
        last_reg <= S_axis.tlast;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        ke_pending_reg <= 1'b0;
    end
    else if (ke_cnt == ROUNDS_NUMBER) begin
        ke_pending_reg <= 1'b0;
    end
    else if (state == ST_KEY_1 & S_axis.tvalid & S_axis.tready & (&input_cnt)) begin
        ke_pending_reg <= 1'b1;
    end

aes256_key_expansion_port key_expansion_inst (
    .round_num ( ke_cnt      ),
    .key       ( ke_key_areg ),
    .new_key   ( ke_new_key  ) 
);

aes_inv_round_port round_inst (
    .Enc          ( enc_reg                ),
    .Last         ( round_last_areg        ),
    .Key          ( round_key_areg         ),
    .Input_block  ( round_input_block_areg ),
    .Output_block ( round_output_block     )
);

endmodule
