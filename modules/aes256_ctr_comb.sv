`include "aes_defines.svh"

module aes256_ctr_comb #(
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
logic                      [BLOCK_SIZE-1 : 0] counter_reg;
logic                      [BLOCK_SIZE-1 : 0] input_text_reg;
logic                    [BLOCK_SIZE/8-1 : 0] input_keep_reg;

logic                                         encrypt_reg;
logic                                         block_last_reg;

logic [KEY_LENGTH-1 : 0] key_expansion_key[NUMBER_OF_ROUNDS-1];
logic [BLOCK_SIZE-1 : 0] key_expansion_new_key[NUMBER_OF_ROUNDS-1];

logic [BLOCK_SIZE-1 : 0] round_block[NUMBER_OF_ROUNDS];
logic [BLOCK_SIZE-1 : 0] round_key[NUMBER_OF_ROUNDS+1];

logic [BLOCK_SIZE-1 : 0] input_block;
logic [BLOCK_SIZE-1 : 0] output_block;
logic [BLOCK_SIZE-1 : 0] output_text;
logic                    output_word_last;

assign input_block = invert_counter_bytes(counter_reg);
assign output_text = input_text_reg ^ output_block;

enum logic [4:0] {
    ST_KEY         = 5'b1 << 0,
    ST_COUNTER     = 5'b1 << 1,
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
                next_state = ST_COUNTER;
            else
                next_state = ST_KEY;
        end

        ST_COUNTER: begin
            if (S_axis.tvalid & S_axis.tready & input_word_cnt == LAST_INPUT_BLOCK_WORD)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_COUNTER;
        end

        ST_INPUT_TEXT: begin
            if (S_axis.tvalid & S_axis.tready & (S_axis.tlast | input_word_cnt == LAST_INPUT_BLOCK_WORD))
                next_state = ST_CIPHER;
            else
                next_state = ST_INPUT_TEXT;
        end

        ST_CIPHER: begin
            next_state = ST_OUTPUT_TEXT;
        end

        ST_OUTPUT_TEXT: begin
            if (M_axis.tvalid & M_axis.tready & M_axis.tlast & output_word_last)
                next_state = ST_KEY;
            else if (M_axis.tvalid & M_axis.tready & output_word_last)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_OUTPUT_TEXT;
        end
    endcase

always_comb
    case (state_reg)
        ST_KEY, ST_COUNTER, ST_INPUT_TEXT:
            S_axis.tready = 1'b1;
        
        default:
            S_axis.tready = 1'b0;
    endcase

always_comb
    case (state_reg)
        ST_OUTPUT_TEXT: begin
            M_axis.tvalid = 1'b1;
            M_axis.tdata = output_text[output_word_cnt*M_AXIS_WIDTH +: M_AXIS_WIDTH];
            M_axis.tkeep = input_keep_reg[output_word_cnt*M_AXIS_WIDTH/8 +: M_AXIS_WIDTH/8];
            M_axis.tlast = output_word_last ? block_last_reg : 1'b0;
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

            ST_COUNTER, ST_INPUT_TEXT:
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
        counter_reg <= 128'h0;
    end
    else if (state_reg == ST_COUNTER & S_axis.tvalid & S_axis.tready) begin
        counter_reg <= {counter_reg[BLOCK_SIZE-S_AXIS_WIDTH : 0], invert_tdata_bytes(S_axis.tdata)};
    end
    else if (state_reg == ST_OUTPUT_TEXT & M_axis.tvalid & M_axis.tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD) begin
        counter_reg <= counter_reg + 1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_text_reg <= 128'h0;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis.tvalid & S_axis.tready) begin
        input_text_reg[input_word_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_keep_reg <= 16'b0;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis.tvalid & S_axis.tready) begin
        input_keep_reg[input_word_cnt*S_AXIS_WIDTH/8 +: S_AXIS_WIDTH/8] <= S_axis.tkeep;
    end
    else if (state_reg == ST_OUTPUT_TEXT & M_axis.tvalid & M_axis.tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD) begin
        input_keep_reg <= 16'b0;
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
    round_key[ 0] = key_reg[127:  0];
    round_key[ 1] = key_reg[255:128];
    round_key[ 2] = key_expansion_new_key[ 0];
    round_key[ 3] = key_expansion_new_key[ 1];
    round_key[ 4] = key_expansion_new_key[ 2];
    round_key[ 5] = key_expansion_new_key[ 3];
    round_key[ 6] = key_expansion_new_key[ 4];
    round_key[ 7] = key_expansion_new_key[ 5];
    round_key[ 8] = key_expansion_new_key[ 6];
    round_key[ 9] = key_expansion_new_key[ 7];
    round_key[10] = key_expansion_new_key[ 8];
    round_key[11] = key_expansion_new_key[ 9];
    round_key[12] = key_expansion_new_key[10];
    round_key[13] = key_expansion_new_key[11];
    round_key[14] = key_expansion_new_key[12];
end

always_comb begin
    if (output_word_cnt == LAST_OUTPUT_BLOCK_WORD)
        output_word_last = 1'b1;
    else
        output_word_last = !input_keep_reg[(output_word_cnt+1)*(M_AXIS_WIDTH/8)];
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
            aes_round_param #(
                .LAST ( 1'b1 )
            ) round_inst (
                .Key          ( round_key[r]     ),
                .Input_block  ( round_block[r-1] ),
                .Output_block ( output_block     )
            );
        end
        else begin
            aes_round_param #(
                .LAST ( 1'b0 )
            ) round_inst (
                .Key          ( round_key[r]     ),
                .Input_block  ( round_block[r-1] ),
                .Output_block ( round_block[r]   )
            );
        end
    end
endgenerate

function automatic logic [S_AXIS_WIDTH-1 : 0] invert_tdata_bytes(logic [S_AXIS_WIDTH-1 : 0] tdata);
    int num_of_bytes = S_AXIS_WIDTH/8;
    logic [S_AXIS_WIDTH-1 : 0] inverted_tdata;

    for (int i=0; i<num_of_bytes; i++) begin
        inverted_tdata[8*i +: 8] = tdata[8*(num_of_bytes-1-i) +: 8];
    end

    return inverted_tdata;
endfunction

function automatic logic [BLOCK_SIZE-1 : 0] invert_counter_bytes(logic [BLOCK_SIZE-1 : 0] counter);
    int num_of_bytes = BLOCK_SIZE/8;
    logic [BLOCK_SIZE-1 : 0] inverted_counter;

    for (int i=0; i<num_of_bytes; i++) begin
        inverted_counter[8*i +: 8] = counter[8*(num_of_bytes-1-i) +: 8];
    end

    return inverted_counter;
endfunction

endmodule
