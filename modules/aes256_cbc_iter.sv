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

localparam int KEY_LENGTH       = `AES_256_KEY_LENGTH;
localparam int BLOCK_SIZE       = `AES_BLOCK_SIZE;
localparam int NUMBER_OF_ROUNDS = `AES_256_NUMBER_OF_ROUNDS;

reg [$clog2(BLOCK_SIZE/S_AXIS_WIDTH)-1 : 0] input_cnt;
reg [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] output_cnt;

reg [int'($ceil($clog2(NUMBER_OF_ROUNDS)))-1 : 0] key_expansion_cnt;
reg [int'($ceil($clog2(NUMBER_OF_ROUNDS)))-1 : 0] round_cnt;

reg [(NUMBER_OF_ROUNDS+1)*BLOCK_SIZE-1 : 0] key_expansion_reg;
reg                      [BLOCK_SIZE-1 : 0] iv_reg;
reg                      [BLOCK_SIZE-1 : 0] input_text_reg;
reg                      [BLOCK_SIZE-1 : 0] output_block_reg;

reg [BLOCK_SIZE-1 : 0] input_block_areg;
reg [BLOCK_SIZE-1 : 0] output_text_areg;

reg  [KEY_LENGTH-1 : 0] ke_key_areg;
wire [BLOCK_SIZE-1 : 0] ke_new_key;

reg                     r_last_areg;
reg  [BLOCK_SIZE-1 : 0] r_key_areg;
reg  [BLOCK_SIZE-1 : 0] r_input_block_areg;
wire [BLOCK_SIZE-1 : 0] r_output_block;

reg enc_reg;
reg last_reg;
reg key_expansion_pending_reg;

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
            if (S_axis.tvalid & S_axis.tready & (&input_cnt) & key_expansion_cnt == NUMBER_OF_ROUNDS)
                next_state = ST_CIPHER;
            else if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_KEY_EXPANSION;
            else
                next_state = ST_TEXT_IN;
        end

        ST_KEY_EXPANSION: begin
            if (key_expansion_cnt == NUMBER_OF_ROUNDS)
                next_state = ST_CIPHER;
            else
                next_state = ST_KEY_EXPANSION;
        end

        ST_CIPHER: begin
            if (round_cnt == NUMBER_OF_ROUNDS)
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
        key_expansion_cnt <= 2;
    end
    else if (state == ST_KEY_0) begin
        key_expansion_cnt <= 2;
    end
    else if (key_expansion_pending_reg & key_expansion_cnt < NUMBER_OF_ROUNDS) begin
        key_expansion_cnt <= key_expansion_cnt + 1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        round_cnt <= 1;
    end
    else if (state == ST_CIPHER) begin
        round_cnt <= round_cnt + 1;
    end
    else begin
        round_cnt <= 1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        key_expansion_reg <= 1920'h0;
    end
    else if (state == ST_KEY_0 & S_axis.tvalid & S_axis.tready) begin
        key_expansion_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state == ST_KEY_1 & S_axis.tvalid & S_axis.tready) begin
        key_expansion_reg[input_cnt*S_AXIS_WIDTH+BLOCK_SIZE +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (key_expansion_pending_reg) begin
        case (key_expansion_cnt)
            2:  key_expansion_reg[ 383: 256] <= ke_new_key;
            3:  key_expansion_reg[ 511: 384] <= ke_new_key;
            4:  key_expansion_reg[ 639: 512] <= ke_new_key;
            5:  key_expansion_reg[ 767: 640] <= ke_new_key;
            6:  key_expansion_reg[ 895: 768] <= ke_new_key;
            7:  key_expansion_reg[1023: 896] <= ke_new_key;
            8:  key_expansion_reg[1151:1024] <= ke_new_key;
            9:  key_expansion_reg[1279:1152] <= ke_new_key;
            10: key_expansion_reg[1407:1280] <= ke_new_key;
            11: key_expansion_reg[1535:1408] <= ke_new_key;
            12: key_expansion_reg[1663:1536] <= ke_new_key;
            13: key_expansion_reg[1791:1664] <= ke_new_key;
            14: key_expansion_reg[1919:1792] <= ke_new_key;
        endcase
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
        output_block_reg <= r_output_block;
    end

always_comb
    if (round_cnt == 1)
        input_block_areg = (enc_reg) ? input_text_reg ^ iv_reg : input_text_reg;
    else
        input_block_areg = output_block_reg;

always_comb
    output_text_areg = (enc_reg) ? output_block_reg : output_block_reg ^ iv_reg;

always_comb
    case (key_expansion_cnt)
        2:       ke_key_areg = key_expansion_reg[ 255:   0];
        3:       ke_key_areg = key_expansion_reg[ 383: 128];
        4:       ke_key_areg = key_expansion_reg[ 511: 256];
        5:       ke_key_areg = key_expansion_reg[ 639: 384];
        6:       ke_key_areg = key_expansion_reg[ 767: 512];
        7:       ke_key_areg = key_expansion_reg[ 895: 640];
        8:       ke_key_areg = key_expansion_reg[1023: 768];
        9:       ke_key_areg = key_expansion_reg[1151: 896];
        10:      ke_key_areg = key_expansion_reg[1279:1024];
        11:      ke_key_areg = key_expansion_reg[1407:1152];
        12:      ke_key_areg = key_expansion_reg[1535:1280];
        13:      ke_key_areg = key_expansion_reg[1663:1408];
        14:      ke_key_areg = key_expansion_reg[1791:1536];
        default: ke_key_areg = 256'h0;
    endcase

always_comb
    r_last_areg = (round_cnt == NUMBER_OF_ROUNDS) ? 1'b1 : 1'b0;

always_comb
    case (round_cnt)
        1:       r_key_areg = (enc_reg) ? key_expansion_reg[ 255: 128] : key_expansion_reg[1791:1664];
        2:       r_key_areg = (enc_reg) ? key_expansion_reg[ 383: 256] : key_expansion_reg[1663:1536];
        3:       r_key_areg = (enc_reg) ? key_expansion_reg[ 511: 384] : key_expansion_reg[1535:1408];
        4:       r_key_areg = (enc_reg) ? key_expansion_reg[ 639: 512] : key_expansion_reg[1407:1280];
        5:       r_key_areg = (enc_reg) ? key_expansion_reg[ 767: 640] : key_expansion_reg[1279:1152];
        6:       r_key_areg = (enc_reg) ? key_expansion_reg[ 895: 768] : key_expansion_reg[1151:1024];
        7:       r_key_areg = (enc_reg) ? key_expansion_reg[1023: 896] : key_expansion_reg[1023: 896];
        8:       r_key_areg = (enc_reg) ? key_expansion_reg[1151:1024] : key_expansion_reg[ 895: 768];
        9:       r_key_areg = (enc_reg) ? key_expansion_reg[1279:1152] : key_expansion_reg[ 767: 640];
        10:      r_key_areg = (enc_reg) ? key_expansion_reg[1407:1280] : key_expansion_reg[ 639: 512];
        11:      r_key_areg = (enc_reg) ? key_expansion_reg[1535:1408] : key_expansion_reg[ 511: 384];
        12:      r_key_areg = (enc_reg) ? key_expansion_reg[1663:1536] : key_expansion_reg[ 383: 256];
        13:      r_key_areg = (enc_reg) ? key_expansion_reg[1791:1664] : key_expansion_reg[ 255: 128];
        14:      r_key_areg = (enc_reg) ? key_expansion_reg[1919:1792] : key_expansion_reg[ 127:   0];
        default: r_key_areg = 128'h0;
    endcase

always_comb
    if (enc_reg)
        r_input_block_areg = (round_cnt == 1) ? input_block_areg ^ key_expansion_reg[ 127:   0] : input_block_areg;
    else
        r_input_block_areg = (round_cnt == 1) ? input_block_areg ^ key_expansion_reg[1919:1792] : input_block_areg;

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
        key_expansion_pending_reg <= 1'b0;
    end
    else if (key_expansion_cnt == NUMBER_OF_ROUNDS) begin
        key_expansion_pending_reg <= 1'b0;
    end
    else if (state == ST_KEY_1 & S_axis.tvalid & S_axis.tready & (&input_cnt)) begin
        key_expansion_pending_reg <= 1'b1;
    end

aes256_key_expansion_port key_expansion_inst (
    .round_num ( key_expansion_cnt ),
    .key       ( ke_key_areg       ),
    .new_key   ( ke_new_key        ) 
);

aes_inv_round_port round_inst (
    .Enc          ( enc_reg            ),
    .Last         ( r_last_areg        ),
    .Key          ( r_key_areg         ),
    .Input_block  ( r_input_block_areg ),
    .Output_block ( r_output_block     )
);

endmodule
