`include "aes_defines.svh"

module aes256_cbc_comb #(
    parameter int S_AXIS_WIDTH = 8,
    parameter int M_AXIS_WIDTH = 8
)(
    input          Clk,
    input          Rst,
    axis_if.slave  S_axis,
    axis_if.master M_axis
);

localparam int KEY_LENGTH             = `AES256_KEY_LENGTH;
localparam int BLOCK_SIZE             = `AES_BLOCK_SIZE;
localparam int NUMBER_OF_ROUNDS       = `AES256_NUMBER_OF_ROUNDS;
localparam int LAST_KEY_WORD          = KEY_LENGTH/S_AXIS_WIDTH-1;
localparam int LAST_INPUT_BLOCK_WORD  = BLOCK_SIZE/S_AXIS_WIDTH-1;
localparam int LAST_OUTPUT_BLOCK_WORD = BLOCK_SIZE/M_AXIS_WIDTH-1;

logic [$clog2(KEY_LENGTH/S_AXIS_WIDTH)-1 : 0] input_word_cnt;
logic [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] output_word_cnt;

logic                      [KEY_LENGTH-1 : 0] key_reg;
logic                      [BLOCK_SIZE-1 : 0] iv_reg;
logic                      [BLOCK_SIZE-1 : 0] input_text_reg;

logic                                         encrypt_reg;
logic                                         block_last_reg;

logic [KEY_LENGTH-1 : 0] key_expansion_key[NUMBER_OF_ROUNDS-1];
logic [BLOCK_SIZE-1 : 0] key_expansion_new_key[NUMBER_OF_ROUNDS-1];

logic [BLOCK_SIZE-1 : 0] round_block[NUMBER_OF_ROUNDS];
logic [BLOCK_SIZE-1 : 0] round_key[NUMBER_OF_ROUNDS+1];

logic [BLOCK_SIZE-1 : 0] input_block;
logic [BLOCK_SIZE-1 : 0] output_block;
logic [BLOCK_SIZE-1 : 0] output_text;

assign input_block = encrypt_reg ? input_text_reg ^ iv_reg : input_text_reg;
assign output_text = encrypt_reg ? output_block : output_block ^ iv_reg;

enum logic [4:0] {
    ST_KEY         = 5'b1 << 0,
    ST_IV          = 5'b1 << 1,
    ST_INPUT_TEXT  = 5'b1 << 2,
    ST_CIPHER      = 5'b1 << 3,
    ST_OUTPUT_TEXT = 5'b1 << 4
} state_reg, next_state;

always_ff @(posedge Clk)
    if (Rst)
        state_reg <= ST_KEY;
    else
        state_reg <= next_state;

always_comb
    case (state_reg)
        ST_KEY: begin
            if (S_axis.tvalid & S_axis.tready & input_word_cnt == LAST_KEY_WORD)
                next_state = ST_IV;
            else
                next_state = ST_KEY;
        end

        ST_IV: begin
            if (S_axis.tvalid & S_axis.tready & input_word_cnt == LAST_INPUT_BLOCK_WORD)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_IV;
        end

        ST_INPUT_TEXT: begin
            if (S_axis.tvalid & S_axis.tready & input_word_cnt == LAST_INPUT_BLOCK_WORD)
                next_state = ST_CIPHER;
            else
                next_state = ST_INPUT_TEXT;
        end

        ST_CIPHER: begin
            next_state = ST_OUTPUT_TEXT;
        end

        ST_OUTPUT_TEXT: begin
            if (M_axis.tvalid & M_axis.tready & M_axis.tlast & output_word_cnt == LAST_OUTPUT_BLOCK_WORD)
                next_state = ST_KEY;
            else if (M_axis.tvalid & M_axis.tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_OUTPUT_TEXT;
        end
    endcase

always_comb
    case (state_reg)
        ST_KEY, ST_IV, ST_INPUT_TEXT:
            S_axis.tready = 1'b1;
        
        default:
            S_axis.tready = 1'b0;
    endcase

always_comb
    case (state_reg)
        ST_OUTPUT_TEXT: begin
            M_axis.tvalid = 1'b1;
            M_axis.tdata = output_text[output_word_cnt*M_AXIS_WIDTH +: M_AXIS_WIDTH];
            M_axis.tkeep = {(M_AXIS_WIDTH/8){1'b1}};
            M_axis.tlast = (output_word_cnt == LAST_OUTPUT_BLOCK_WORD) ? block_last_reg : 1'b0;
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
        input_word_cnt <= 0;
    else
        case (state_reg)
            ST_KEY:
                if (S_axis.tvalid & S_axis.tready & input_word_cnt == LAST_KEY_WORD)
                    input_word_cnt <= 0;
                else if (S_axis.tvalid & S_axis.tready)
                    input_word_cnt <= input_word_cnt + 'd1;

            ST_IV, ST_INPUT_TEXT:
                if (S_axis.tvalid & S_axis.tready & input_word_cnt == LAST_INPUT_BLOCK_WORD)
                    input_word_cnt <= 0;
                else if (S_axis.tvalid & S_axis.tready)
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
                if (M_axis.tvalid & M_axis.tready)
                    output_word_cnt <= output_word_cnt + 'd1;
            
            default:
                output_word_cnt <= 0;
        endcase

always_ff @(posedge Clk)
    if (Rst) begin
        key_reg <= 256'h0;
    end
    else if (state_reg == ST_KEY & S_axis.tvalid & S_axis.tready) begin
        key_reg[input_word_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        iv_reg <= 128'h0;
    end
    else if (state_reg == ST_IV & S_axis.tvalid & S_axis.tready) begin
        iv_reg[input_word_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state_reg == ST_OUTPUT_TEXT & M_axis.tvalid & M_axis.tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD) begin
        iv_reg <= encrypt_reg ? output_text : input_text_reg;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_text_reg <= 128'h0;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis.tvalid & S_axis.tready) begin
        input_text_reg[input_word_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end

always @(posedge Clk)
    if (Rst) begin
        encrypt_reg <= 1'b0;
        block_last_reg <= 1'b0;
    end
    else if (S_axis.tvalid & S_axis.tready) begin
        encrypt_reg <= S_axis.tuser;
        block_last_reg <= S_axis.tlast;
    end

always_comb begin
    key_expansion_key[ 0] = key_reg;
    key_expansion_key[ 1] = { key_expansion_new_key[ 0], key_reg[255:128]            };
    key_expansion_key[ 2] = { key_expansion_new_key[ 1], key_expansion_new_key[ 0]   };
    key_expansion_key[ 3] = { key_expansion_new_key[ 2], key_expansion_new_key[ 1]   };
    key_expansion_key[ 4] = { key_expansion_new_key[ 3], key_expansion_new_key[ 2]   };
    key_expansion_key[ 5] = { key_expansion_new_key[ 4], key_expansion_new_key[ 3]   };
    key_expansion_key[ 6] = { key_expansion_new_key[ 5], key_expansion_new_key[ 4]   };
    key_expansion_key[ 7] = { key_expansion_new_key[ 6], key_expansion_new_key[ 5]   };
    key_expansion_key[ 8] = { key_expansion_new_key[ 7], key_expansion_new_key[ 6]   };
    key_expansion_key[ 9] = { key_expansion_new_key[ 8], key_expansion_new_key[ 7]   };
    key_expansion_key[10] = { key_expansion_new_key[ 9], key_expansion_new_key[ 8]   };
    key_expansion_key[11] = { key_expansion_new_key[10], key_expansion_new_key[ 9]   };
    key_expansion_key[12] = { key_expansion_new_key[11], key_expansion_new_key[10]   };
end


always_comb begin
    round_key[ 0] = encrypt_reg ? key_reg[127:  0]            : key_expansion_new_key[12]   ;
    round_key[ 1] = encrypt_reg ? key_reg[255:128]            : key_expansion_new_key[11]   ;
    round_key[ 2] = encrypt_reg ? key_expansion_new_key[ 0]   : key_expansion_new_key[10]   ;
    round_key[ 3] = encrypt_reg ? key_expansion_new_key[ 1]   : key_expansion_new_key[ 9]   ;
    round_key[ 4] = encrypt_reg ? key_expansion_new_key[ 2]   : key_expansion_new_key[ 8]   ;
    round_key[ 5] = encrypt_reg ? key_expansion_new_key[ 3]   : key_expansion_new_key[ 7]   ;
    round_key[ 6] = encrypt_reg ? key_expansion_new_key[ 4]   : key_expansion_new_key[ 6]   ;
    round_key[ 7] = encrypt_reg ? key_expansion_new_key[ 5]   : key_expansion_new_key[ 5]   ;
    round_key[ 8] = encrypt_reg ? key_expansion_new_key[ 6]   : key_expansion_new_key[ 4]   ;
    round_key[ 9] = encrypt_reg ? key_expansion_new_key[ 7]   : key_expansion_new_key[ 3]   ;
    round_key[10] = encrypt_reg ? key_expansion_new_key[ 8]   : key_expansion_new_key[ 2]   ;
    round_key[11] = encrypt_reg ? key_expansion_new_key[ 9]   : key_expansion_new_key[ 1]   ;
    round_key[12] = encrypt_reg ? key_expansion_new_key[10]   : key_expansion_new_key[ 0]   ;
    round_key[13] = encrypt_reg ? key_expansion_new_key[11]   : key_reg[255:128] ;
    round_key[14] = encrypt_reg ? key_expansion_new_key[12]   : key_reg[127:  0] ;
end

generate
    for (genvar k=2; k<=NUMBER_OF_ROUNDS; k++) begin
        aes256_key_expansion_param #(
            .ROUND_NUMBER ( k )
        ) key_expansion_inst (
            .Input_key  ( key_expansion_key[k-2]     ),
            .Output_key ( key_expansion_new_key[k-2] )
        );
    end
endgenerate

aes_add_round_key add_round_key_inst (
    .Input_block  ( input_block    ),
    .Round_key    ( round_key[0]   ),
    .Output_block ( round_block[0] )
);

generate
    for (genvar r=1; r<=NUMBER_OF_ROUNDS; r++) begin
        if (r == NUMBER_OF_ROUNDS) begin
            aes_inv_round_param #(
                .LAST ( 1'b1 )
            ) round_inst (
                .Encrypt      ( encrypt_reg      ),
                .Key          ( round_key[r]     ),
                .Input_block  ( round_block[r-1] ),
                .Output_block ( output_block     )
            );
        end
        else begin
            aes_inv_round_param #(
                .LAST ( 1'b0 )
            ) round_inst (
                .Encrypt      ( encrypt_reg      ),
                .Key          ( round_key[r]     ),
                .Input_block  ( round_block[r-1] ),
                .Output_block ( round_block[r]   )
            );
        end
    end
endgenerate

endmodule
