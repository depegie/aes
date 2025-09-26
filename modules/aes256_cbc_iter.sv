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

logic [$clog2(BLOCK_SIZE/S_AXIS_WIDTH)-1 : 0] input_cnt;
logic [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] output_cnt;

logic [int'($ceil($clog2(NUMBER_OF_ROUNDS)))-1 : 0] key_expansion_cnt;
logic [int'($ceil($clog2(NUMBER_OF_ROUNDS)))-1 : 0] round_cnt;

logic [(NUMBER_OF_ROUNDS+1)*BLOCK_SIZE-1 : 0] key_expansion_reg;
logic                      [BLOCK_SIZE-1 : 0] iv_reg;
logic                      [BLOCK_SIZE-1 : 0] input_text_reg;
logic                      [BLOCK_SIZE-1 : 0] output_block_reg;

logic [BLOCK_SIZE-1 : 0] input_block;
logic [BLOCK_SIZE-1 : 0] output_text;

logic [KEY_LENGTH-1 : 0] key_expansion_key;
logic [BLOCK_SIZE-1 : 0] key_expansion_new_key;

logic                    round_last;
logic [BLOCK_SIZE-1 : 0] round_key;
logic [BLOCK_SIZE-1 : 0] round_input_block;
logic [BLOCK_SIZE-1 : 0] round_output_block;

logic encrypt_reg;
logic last_block_reg;
logic key_expansion_pending_reg;

enum logic [6:0] {
    ST_KEY_0         = 7'b1 << 0,
    ST_KEY_1         = 7'b1 << 1,
    ST_IV            = 7'b1 << 2,
    ST_TEXT_IN       = 7'b1 << 3,
    ST_KEY_EXPANSION = 7'b1 << 4,
    ST_CIPHER        = 7'b1 << 5,
    ST_TEXT_OUT      = 7'b1 << 6
} state_reg, next_state;

always_ff @(posedge Clk)
    if (Rst)
        state_reg <= ST_KEY_0;
    else
        state_reg <= next_state;

always_comb
    case (state_reg)
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
    case (state_reg)
        ST_KEY_0, ST_KEY_1, ST_IV, ST_TEXT_IN:
            S_axis.tready = 1'b1;
        
        default:
            S_axis.tready = 1'b0;
    endcase

always_comb
    case (state_reg)
        ST_TEXT_OUT: begin
            M_axis.tvalid = 1'b1;
            M_axis.tdata = output_text[output_cnt*M_AXIS_WIDTH +: M_AXIS_WIDTH];
            M_axis.tkeep = {(M_AXIS_WIDTH/8){1'b1}};
            M_axis.tlast = (&output_cnt) ? last_block_reg : 1'b0;
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
        case (state_reg)
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
        case (state_reg)
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
    else if (state_reg == ST_KEY_0) begin
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
    else if (state_reg == ST_KEY_0 & S_axis.tvalid & S_axis.tready) begin
        key_expansion_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state_reg == ST_KEY_1 & S_axis.tvalid & S_axis.tready) begin
        key_expansion_reg[input_cnt*S_AXIS_WIDTH+BLOCK_SIZE +: S_AXIS_WIDTH] <= S_axis.tdata;
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
    else if (state_reg == ST_IV & S_axis.tvalid & S_axis.tready) begin
        iv_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state_reg == ST_TEXT_OUT & M_axis.tvalid & M_axis.tready & (&output_cnt)) begin
        iv_reg <= encrypt_reg ? output_text : input_text_reg;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_text_reg <= 128'h0;
    end
    else if (state_reg == ST_TEXT_IN & S_axis.tvalid & S_axis.tready) begin
        input_text_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        output_block_reg <= 128'h0;
    end
    else if (state_reg == ST_CIPHER) begin
        output_block_reg <= round_output_block;
    end

always_comb
    if (round_cnt == 1)
        input_block = encrypt_reg ? input_text_reg ^ iv_reg : input_text_reg;
    else
        input_block = output_block_reg;

always_comb
    output_text = encrypt_reg ? output_block_reg : output_block_reg ^ iv_reg;

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
    round_last = (round_cnt == NUMBER_OF_ROUNDS) ? 1'b1 : 1'b0;

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

always_comb
    if (encrypt_reg)
        round_input_block = (round_cnt == 1) ? input_block ^ key_expansion_reg[ 127:   0] : input_block;
    else
        round_input_block = (round_cnt == 1) ? input_block ^ key_expansion_reg[1919:1792] : input_block;

always @(posedge Clk)
    if (Rst) begin
        encrypt_reg <= 1'b0;
        last_block_reg <= 1'b0;
    end
    else if (S_axis.tvalid & S_axis.tready) begin
        encrypt_reg <= S_axis.tuser;
        last_block_reg <= S_axis.tlast;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        key_expansion_pending_reg <= 1'b0;
    end
    else if (key_expansion_cnt == NUMBER_OF_ROUNDS) begin
        key_expansion_pending_reg <= 1'b0;
    end
    else if (state_reg == ST_KEY_1 & S_axis.tvalid & S_axis.tready & (&input_cnt)) begin
        key_expansion_pending_reg <= 1'b1;
    end

aes256_key_expansion_port key_expansion_inst (
    .Round_number ( key_expansion_cnt     ),
    .Input_key    ( key_expansion_key     ),
    .Output_key   ( key_expansion_new_key ) 
);

aes_inv_round_port round_inst (
    .Encrypt      ( encrypt_reg        ),
    .Last         ( round_last         ),
    .Key          ( round_key          ),
    .Input_block  ( round_input_block  ),
    .Output_block ( round_output_block )
);

endmodule
