`include "aes_defines.svh"

module aes256_cbc_iter #(
    parameter int S_AXIS_WIDTH = 64,
    parameter int M_AXIS_WIDTH = 64
)(
    input  logic                        Clk,
    input  logic                        Rst,

    input  logic                        S_axis_tvalid,
    output logic                        S_axis_tready,
    input  logic   [S_AXIS_WIDTH-1 : 0] S_axis_tdata,
    input  logic [S_AXIS_WIDTH/8-1 : 0] S_axis_tkeep,
    input  logic                        S_axis_tlast,
    input  logic                        S_axis_tuser,
    
    output logic                        M_axis_tvalid,
    input  logic                        M_axis_tready,
    output logic   [M_AXIS_WIDTH-1 : 0] M_axis_tdata,
    output logic [M_AXIS_WIDTH/8-1 : 0] M_axis_tkeep,
    output logic                        M_axis_tlast
);

localparam int KEY_LENGTH             = `AES256_KEY_LENGTH;
localparam int BLOCK_SIZE             = `AES_BLOCK_SIZE;
localparam int NUMBER_OF_ROUNDS       = `AES256_NUMBER_OF_ROUNDS;
localparam int LAST_KEY_WORD          = KEY_LENGTH/S_AXIS_WIDTH-1;
localparam int LAST_INPUT_BLOCK_WORD  = BLOCK_SIZE/S_AXIS_WIDTH-1;
localparam int LAST_OUTPUT_BLOCK_WORD = BLOCK_SIZE/M_AXIS_WIDTH-1;

logic       [$clog2(KEY_LENGTH/S_AXIS_WIDTH)-1 : 0] input_word_cnt;
logic       [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] output_word_cnt;

logic [int'($ceil($clog2(NUMBER_OF_ROUNDS)))-1 : 0] key_expansion_cnt;
logic [int'($ceil($clog2(NUMBER_OF_ROUNDS)))-1 : 0] round_cnt;

logic       [(NUMBER_OF_ROUNDS+1)*BLOCK_SIZE-1 : 0] key_expansion_reg;
logic                            [BLOCK_SIZE-1 : 0] iv_reg;
logic                            [BLOCK_SIZE-1 : 0] input_text_reg;
logic                            [BLOCK_SIZE-1 : 0] output_block_reg;

logic                                               encrypt_reg;
logic                                               block_last_reg;
logic                                               key_expansion_pending_reg;

logic [BLOCK_SIZE-1 : 0] input_block;
logic [BLOCK_SIZE-1 : 0] output_text;

logic [KEY_LENGTH-1 : 0] key_expansion_key;
logic [BLOCK_SIZE-1 : 0] key_expansion_new_key;

logic [BLOCK_SIZE-1 : 0] ark_round_key;
logic [BLOCK_SIZE-1 : 0] ark_output_block;

logic                    round_last;
logic [BLOCK_SIZE-1 : 0] round_key;
logic [BLOCK_SIZE-1 : 0] round_input_block;
logic [BLOCK_SIZE-1 : 0] round_output_block;

assign input_block       = encrypt_reg ? input_text_reg ^ iv_reg : input_text_reg;
assign output_text       = encrypt_reg ? output_block_reg : output_block_reg ^ iv_reg;
assign ark_round_key     = encrypt_reg ? key_expansion_reg[127:0] : key_expansion_reg[1919:1792];
assign round_last        = (round_cnt == NUMBER_OF_ROUNDS);
assign round_input_block = (round_cnt == 1) ? ark_output_block : output_block_reg;

enum logic [5:0] {
    ST_KEY           = 6'b1 << 0,
    ST_IV            = 6'b1 << 1,
    ST_INPUT_TEXT    = 6'b1 << 2,
    ST_KEY_EXPANSION = 6'b1 << 3,
    ST_CIPHER        = 6'b1 << 4,
    ST_OUTPUT_TEXT   = 6'b1 << 5
} state_reg, next_state;

always_ff @(posedge Clk)
    if (Rst)
        state_reg <= ST_KEY;
    else
        state_reg <= next_state;

always_comb
    case (state_reg)
        ST_KEY: begin
            if (S_axis_tvalid & S_axis_tready & input_word_cnt == LAST_KEY_WORD)
                next_state = ST_IV;
            else
                next_state = ST_KEY;
        end

        ST_IV: begin
            if (S_axis_tvalid & S_axis_tready & input_word_cnt == LAST_INPUT_BLOCK_WORD)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_IV;
        end

        ST_INPUT_TEXT: begin
            if (S_axis_tvalid & S_axis_tready & input_word_cnt == LAST_INPUT_BLOCK_WORD & key_expansion_cnt == NUMBER_OF_ROUNDS)
                next_state = ST_CIPHER;
            else if (S_axis_tvalid & S_axis_tready & input_word_cnt == LAST_INPUT_BLOCK_WORD)
                next_state = ST_KEY_EXPANSION;
            else
                next_state = ST_INPUT_TEXT;
        end

        ST_KEY_EXPANSION: begin
            if (key_expansion_cnt == NUMBER_OF_ROUNDS)
                next_state = ST_CIPHER;
            else
                next_state = ST_KEY_EXPANSION;
        end

        ST_CIPHER: begin
            if (round_cnt == NUMBER_OF_ROUNDS)
                next_state = ST_OUTPUT_TEXT;
            else
                next_state = ST_CIPHER;
        end

        ST_OUTPUT_TEXT: begin
            if (M_axis_tvalid & M_axis_tready & M_axis_tlast & output_word_cnt == LAST_OUTPUT_BLOCK_WORD)
                next_state = ST_KEY;
            else if (M_axis_tvalid & M_axis_tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_OUTPUT_TEXT;
        end

        default: begin
            next_state = state_reg;
        end
    endcase

always_comb
    case (state_reg)
        ST_KEY, ST_IV, ST_INPUT_TEXT:
            S_axis_tready = 1'b1;
        
        default:
            S_axis_tready = 1'b0;
    endcase

always_comb
    case (state_reg)
        ST_OUTPUT_TEXT: begin
            M_axis_tvalid = 1'b1;
            M_axis_tdata = output_text[output_word_cnt*M_AXIS_WIDTH +: M_AXIS_WIDTH];
            M_axis_tkeep = {(M_AXIS_WIDTH/8){1'b1}};
            M_axis_tlast = (output_word_cnt == LAST_OUTPUT_BLOCK_WORD) ? block_last_reg : 1'b0;
        end

        default: begin
            M_axis_tvalid = 1'b0;
            M_axis_tdata = 128'h0;
            M_axis_tkeep = 16'b0;
            M_axis_tlast = 1'b0;
        end
    endcase

always_ff @(posedge Clk)
    if (Rst)
        input_word_cnt <= 0;
    else
        case (state_reg)
            ST_KEY:
                if (S_axis_tvalid & S_axis_tready & input_word_cnt == LAST_KEY_WORD)
                    input_word_cnt <= 0;
                else if (S_axis_tvalid & S_axis_tready)
                    input_word_cnt <= input_word_cnt + 'd1;

            ST_IV, ST_INPUT_TEXT:
                if (S_axis_tvalid & S_axis_tready & input_word_cnt == LAST_INPUT_BLOCK_WORD)
                    input_word_cnt <= 0;
                else if (S_axis_tvalid & S_axis_tready)
                    input_word_cnt <= input_word_cnt + 'd1;
            
            default:
                input_word_cnt <= 0;
        endcase

always_ff @(posedge Clk)
    if (Rst)
        output_word_cnt <= 0;
    else
        case (state_reg)
            ST_OUTPUT_TEXT:
                if (M_axis_tvalid & M_axis_tready)
                    output_word_cnt <= output_word_cnt + 'd1;
            
            default:
                output_word_cnt <= 0;
        endcase

always_ff @(posedge Clk)
    if (Rst) begin
        key_expansion_cnt <= 2;
    end
    else if (state_reg == ST_KEY) begin
        key_expansion_cnt <= 2;
    end
    else if (key_expansion_pending_reg & key_expansion_cnt < NUMBER_OF_ROUNDS) begin
        key_expansion_cnt <= key_expansion_cnt + 1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        round_cnt <= 1;
    end
    else if (state_reg == ST_CIPHER) begin
        round_cnt <= round_cnt + 1;
    end
    else begin
        round_cnt <= 1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        key_expansion_reg <= 1920'h0;
    end
    else if (state_reg == ST_KEY & S_axis_tvalid & S_axis_tready) begin
        key_expansion_reg[input_word_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis_tdata;
    end
    else if (key_expansion_pending_reg) begin
        case (key_expansion_cnt)
            2:  key_expansion_reg[ 383: 256] <= key_expansion_new_key;
            3:  key_expansion_reg[ 511: 384] <= key_expansion_new_key;
            4:  key_expansion_reg[ 639: 512] <= key_expansion_new_key;
            5:  key_expansion_reg[ 767: 640] <= key_expansion_new_key;
            6:  key_expansion_reg[ 895: 768] <= key_expansion_new_key;
            7:  key_expansion_reg[1023: 896] <= key_expansion_new_key;
            8:  key_expansion_reg[1151:1024] <= key_expansion_new_key;
            9:  key_expansion_reg[1279:1152] <= key_expansion_new_key;
            10: key_expansion_reg[1407:1280] <= key_expansion_new_key;
            11: key_expansion_reg[1535:1408] <= key_expansion_new_key;
            12: key_expansion_reg[1663:1536] <= key_expansion_new_key;
            13: key_expansion_reg[1791:1664] <= key_expansion_new_key;
            14: key_expansion_reg[1919:1792] <= key_expansion_new_key;
        endcase
    end

always_ff @(posedge Clk)
    if (Rst) begin
        iv_reg <= 128'h0;
    end
    else if (state_reg == ST_IV & S_axis_tvalid & S_axis_tready) begin
        iv_reg[input_word_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis_tdata;
    end
    else if (state_reg == ST_OUTPUT_TEXT & M_axis_tvalid & M_axis_tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD) begin
        iv_reg <= encrypt_reg ? output_text : input_text_reg;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_text_reg <= 128'h0;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis_tvalid & S_axis_tready) begin
        input_text_reg[input_word_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis_tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        output_block_reg <= 128'h0;
    end
    else if (state_reg == ST_CIPHER) begin
        output_block_reg <= round_output_block;
    end

always_comb
    case (key_expansion_cnt)
        2:       key_expansion_key = key_expansion_reg[ 255:   0];
        3:       key_expansion_key = key_expansion_reg[ 383: 128];
        4:       key_expansion_key = key_expansion_reg[ 511: 256];
        5:       key_expansion_key = key_expansion_reg[ 639: 384];
        6:       key_expansion_key = key_expansion_reg[ 767: 512];
        7:       key_expansion_key = key_expansion_reg[ 895: 640];
        8:       key_expansion_key = key_expansion_reg[1023: 768];
        9:       key_expansion_key = key_expansion_reg[1151: 896];
        10:      key_expansion_key = key_expansion_reg[1279:1024];
        11:      key_expansion_key = key_expansion_reg[1407:1152];
        12:      key_expansion_key = key_expansion_reg[1535:1280];
        13:      key_expansion_key = key_expansion_reg[1663:1408];
        14:      key_expansion_key = key_expansion_reg[1791:1536];
        default: key_expansion_key = 256'h0;
    endcase

always_comb
    case (round_cnt)
        1:       round_key = encrypt_reg ? key_expansion_reg[ 255: 128] : key_expansion_reg[1791:1664];
        2:       round_key = encrypt_reg ? key_expansion_reg[ 383: 256] : key_expansion_reg[1663:1536];
        3:       round_key = encrypt_reg ? key_expansion_reg[ 511: 384] : key_expansion_reg[1535:1408];
        4:       round_key = encrypt_reg ? key_expansion_reg[ 639: 512] : key_expansion_reg[1407:1280];
        5:       round_key = encrypt_reg ? key_expansion_reg[ 767: 640] : key_expansion_reg[1279:1152];
        6:       round_key = encrypt_reg ? key_expansion_reg[ 895: 768] : key_expansion_reg[1151:1024];
        7:       round_key = encrypt_reg ? key_expansion_reg[1023: 896] : key_expansion_reg[1023: 896];
        8:       round_key = encrypt_reg ? key_expansion_reg[1151:1024] : key_expansion_reg[ 895: 768];
        9:       round_key = encrypt_reg ? key_expansion_reg[1279:1152] : key_expansion_reg[ 767: 640];
        10:      round_key = encrypt_reg ? key_expansion_reg[1407:1280] : key_expansion_reg[ 639: 512];
        11:      round_key = encrypt_reg ? key_expansion_reg[1535:1408] : key_expansion_reg[ 511: 384];
        12:      round_key = encrypt_reg ? key_expansion_reg[1663:1536] : key_expansion_reg[ 383: 256];
        13:      round_key = encrypt_reg ? key_expansion_reg[1791:1664] : key_expansion_reg[ 255: 128];
        14:      round_key = encrypt_reg ? key_expansion_reg[1919:1792] : key_expansion_reg[ 127:   0];
        default: round_key = 128'h0;
    endcase

always @(posedge Clk)
    if (Rst) begin
        encrypt_reg <= 1'b0;
        block_last_reg <= 1'b0;
    end
    else if (S_axis_tvalid & S_axis_tready) begin
        encrypt_reg <= S_axis_tuser;
        block_last_reg <= S_axis_tlast;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        key_expansion_pending_reg <= 1'b0;
    end
    else if (key_expansion_cnt == NUMBER_OF_ROUNDS) begin
        key_expansion_pending_reg <= 1'b0;
    end
    else if (state_reg == ST_KEY & S_axis_tvalid & S_axis_tready & input_word_cnt == LAST_KEY_WORD) begin
        key_expansion_pending_reg <= 1'b1;
    end

aes256_key_expansion_port key_expansion_inst (
    .Round_number ( key_expansion_cnt     ),
    .Input_key    ( key_expansion_key     ),
    .Output_key   ( key_expansion_new_key ) 
);

aes_add_round_key ark_inst (
    .Input_block  ( input_block      ),
    .Round_key    ( ark_round_key    ),
    .Output_block ( ark_output_block )
);

aes_inv_round_port round_inst (
    .Encrypt      ( encrypt_reg        ),
    .Last         ( round_last         ),
    .Key          ( round_key          ),
    .Input_block  ( round_input_block  ),
    .Output_block ( round_output_block )
);

endmodule
