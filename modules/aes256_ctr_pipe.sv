`include "aes_defines.svh"

module aes256_ctr_pipe #(
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

logic [$clog2(KEY_LENGTH/S_AXIS_WIDTH)-1 : 0] input_word_cnt;
logic [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] output_word_cnt;

logic                      encrypt_reg;
logic   [KEY_LENGTH-1 : 0] key_reg;
logic   [BLOCK_SIZE-1 : 0] counter_reg;
logic   [BLOCK_SIZE-1 : 0] input_text_reg;
logic [BLOCK_SIZE/8-1 : 0] input_text_keep_reg;
logic                      input_text_last_reg;

logic [BLOCK_SIZE-1 : 0] input_block;
logic                    input_block_valid_reg;
logic                    input_block_ready_reg;

logic [BLOCK_SIZE-1 : 0] key_expansion_reg[NUMBER_OF_ROUNDS-1];
logic [BLOCK_SIZE-1 : 0] key_expansion_new_key[NUMBER_OF_ROUNDS-1];

logic [NUMBER_OF_ROUNDS-1 : 0] stage_valid_reg;
logic [NUMBER_OF_ROUNDS-1 : 0] stage_ready;
logic       [BLOCK_SIZE-1 : 0] stage_text_reg[NUMBER_OF_ROUNDS];
logic       [BLOCK_SIZE-1 : 0] stage_block_reg[NUMBER_OF_ROUNDS];
logic     [BLOCK_SIZE/8-1 : 0] stage_keep_reg[NUMBER_OF_ROUNDS];
logic [NUMBER_OF_ROUNDS-1 : 0] stage_last_reg;

logic [BLOCK_SIZE-1 : 0] round_output_block[NUMBER_OF_ROUNDS];
logic [BLOCK_SIZE-1 : 0] output_text;

assign input_block                     = invert_counter_bytes(counter_reg);
assign input_block_ready_reg           = (M_axis_tvalid & M_axis_tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD) | ~&stage_valid_reg;
assign stage_ready[NUMBER_OF_ROUNDS-1] = (M_axis_tvalid & M_axis_tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD);
assign output_text                     = stage_text_reg[NUMBER_OF_ROUNDS-1] ^ stage_block_reg[NUMBER_OF_ROUNDS-1];

enum logic [3:0] {
    ST_KEY        = 4'b1 << 0,
    ST_COUNTER    = 4'b1 << 1,
    ST_INPUT_TEXT = 4'b1 << 2,
    ST_WAIT       = 4'b1 << 3
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
                next_state = ST_COUNTER;
            else
                next_state = ST_KEY;
        end

        ST_COUNTER: begin
            if (S_axis_tvalid & S_axis_tready & input_word_cnt == LAST_INPUT_BLOCK_WORD)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_COUNTER;
        end

        ST_INPUT_TEXT: begin
            if (S_axis_tvalid & S_axis_tready & S_axis_tlast)
                next_state = ST_WAIT;
            else
                next_state = ST_INPUT_TEXT;
        end

        ST_WAIT: begin
            if (M_axis_tvalid & M_axis_tready & M_axis_tlast)
                next_state = ST_KEY;
            else
                next_state = ST_WAIT;
        end

        default: begin
            next_state = state_reg;
        end
    endcase

always_comb
    case (state_reg)
        ST_KEY, ST_COUNTER:
            S_axis_tready = 1'b1;
        
        ST_INPUT_TEXT:
            S_axis_tready = input_block_ready_reg;

        ST_WAIT:
            S_axis_tready = 1'b0;

        default:
            S_axis_tready = 1'b0;
    endcase


always_ff @(posedge Clk)
    if (Rst) begin
        stage_valid_reg[0] <= 1'b0;
        stage_text_reg[0]  <= 128'h0;
        stage_block_reg[0] <= 128'h0;
        stage_keep_reg[0]  <= 16'b0;
        stage_last_reg[0]  <= 1'b0;
    end
    else if (input_block_valid_reg & input_block_ready_reg) begin
        stage_valid_reg[0] <= 1'b1;
        stage_text_reg[0]  <= input_text_reg;
        stage_block_reg[0] <= round_output_block[0];
        stage_keep_reg[0]  <= input_text_keep_reg;
        stage_last_reg[0]  <= input_text_last_reg;
    end
    else if (stage_valid_reg[0] & stage_ready[0]) begin
        stage_valid_reg[0] <= 1'b0;
    end

generate
    for (genvar i=1; i<NUMBER_OF_ROUNDS; i++) begin
        always_ff @(posedge Clk)
            if (Rst) begin
                stage_valid_reg[i] <= 1'b0;
                stage_text_reg[i]  <= 128'h0;
                stage_block_reg[i] <= 128'h0;
                stage_keep_reg[i]  <= 16'b0;
                stage_last_reg[i]  <= 1'b0;
            end
            else if (stage_valid_reg[i-1] & stage_ready[i-1]) begin
                stage_valid_reg[i] <= 1'b1;
                stage_text_reg[i]  <= stage_text_reg[i-1];
                stage_block_reg[i] <= round_output_block[i];
                stage_keep_reg[i]  <= stage_keep_reg[i-1];
                stage_last_reg[i]  <= stage_last_reg[i-1];
            end
            else if (stage_valid_reg[i] & stage_ready[i]) begin
                stage_valid_reg[i] <= 1'b0;
            end
    end
endgenerate

always_comb begin
    M_axis_tvalid = stage_valid_reg[NUMBER_OF_ROUNDS-1];
    M_axis_tdata  = output_text[output_word_cnt*M_AXIS_WIDTH +: M_AXIS_WIDTH];
    M_axis_tkeep  = stage_keep_reg[NUMBER_OF_ROUNDS-1][output_word_cnt*M_AXIS_WIDTH/8 +: M_AXIS_WIDTH/8];
    M_axis_tlast  = (output_word_cnt == LAST_OUTPUT_BLOCK_WORD) ? stage_last_reg[NUMBER_OF_ROUNDS-1] : 1'b0;
end

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

            ST_COUNTER, ST_INPUT_TEXT:
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
    else if (M_axis_tvalid & M_axis_tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD)
        output_word_cnt <= 0;
    else if (M_axis_tvalid & M_axis_tready)
        output_word_cnt <= output_word_cnt + 'd1;
            

always_ff @(posedge Clk)
    if (Rst) begin
        key_reg <= 256'h0;
    end
    else if (state_reg == ST_KEY & S_axis_tvalid & S_axis_tready) begin
        key_reg[input_word_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis_tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        counter_reg <= 128'h0;
    end
    else if (state_reg == ST_COUNTER & S_axis_tvalid & S_axis_tready) begin
        counter_reg <= {counter_reg[BLOCK_SIZE-S_AXIS_WIDTH : 0], invert_tdata_bytes(S_axis_tdata)};
    end
    else if (input_block_valid_reg & input_block_ready_reg) begin
        counter_reg <= counter_reg + 1;
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
        input_text_keep_reg <= 16'b0;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis_tvalid & S_axis_tready & input_word_cnt) begin
        input_text_keep_reg[input_word_cnt*S_AXIS_WIDTH/8 +: S_AXIS_WIDTH/8] <= S_axis_tkeep;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis_tvalid & S_axis_tready) begin
        input_text_keep_reg <= {8'b00000000, S_axis_tkeep};
    end
    else if (input_block_valid_reg & input_block_ready_reg) begin
        input_text_keep_reg <= 16'b0;
    end

always_ff @(posedge Clk) begin
    if (Rst)
        input_block_valid_reg <= 1'b0;
    else if (state_reg == ST_INPUT_TEXT & S_axis_tvalid & S_axis_tready & (S_axis_tlast | input_word_cnt == LAST_INPUT_BLOCK_WORD))
        input_block_valid_reg <= 1'b1;
    else if (input_block_valid_reg & input_block_ready_reg)
        input_block_valid_reg <= 1'b0;
end

always @(posedge Clk)
    if (Rst) begin
        encrypt_reg         <= 1'b0;
        input_text_last_reg <= 1'b0;
    end
    else if (S_axis_tvalid & S_axis_tready) begin
        encrypt_reg         <= S_axis_tuser;
        input_text_last_reg <= S_axis_tlast;
    end

generate
    for (genvar i=0; i<NUMBER_OF_ROUNDS-1; i++) begin
        assign stage_ready[i] = (M_axis_tvalid & M_axis_tready & output_word_cnt == LAST_OUTPUT_BLOCK_WORD) | ~&stage_valid_reg[i+1 +: NUMBER_OF_ROUNDS-1-i];
    end
endgenerate

generate
    for (genvar i=0; i<NUMBER_OF_ROUNDS-1; i++) begin
        always_ff @(posedge Clk)
            if (Rst)
                key_expansion_reg[i] <= 128'h0;
            else
                key_expansion_reg[i] <= key_expansion_new_key[i];
    end
endgenerate

aes256_key_expansion_port key_expansion_inst_0 (
    .Round_number ( 2 ),
    .Input_key    ( key_reg ),
    .Output_key   ( key_expansion_new_key[0] ) 
);

aes256_key_expansion_port key_expansion_inst_1 (
    .Round_number ( 3 ),
    .Input_key    ( {key_expansion_reg[0], key_reg[255:128]} ),
    .Output_key   ( key_expansion_new_key[1] ) 
);

aes256_key_expansion_port key_expansion_inst_2 (
    .Round_number ( 4 ),
    .Input_key    ( {key_expansion_reg[1], key_expansion_reg[0]} ),
    .Output_key   ( key_expansion_new_key[2] ) 
);

aes256_key_expansion_port key_expansion_inst_3 (
    .Round_number ( 5 ),
    .Input_key    ( {key_expansion_reg[2], key_expansion_reg[1]} ),
    .Output_key   ( key_expansion_new_key[3] ) 
);

aes256_key_expansion_port key_expansion_inst_4 (
    .Round_number ( 6 ),
    .Input_key    ( {key_expansion_reg[3], key_expansion_reg[2]} ),
    .Output_key   ( key_expansion_new_key[4] ) 
);

aes256_key_expansion_port key_expansion_inst_5 (
    .Round_number ( 7 ),
    .Input_key    ( {key_expansion_reg[4], key_expansion_reg[3]} ),
    .Output_key   ( key_expansion_new_key[5] ) 
);

aes256_key_expansion_port key_expansion_inst_6 (
    .Round_number ( 8 ),
    .Input_key    ( {key_expansion_reg[5], key_expansion_reg[4]} ),
    .Output_key   ( key_expansion_new_key[6] ) 
);

aes256_key_expansion_port key_expansion_inst_7 (
    .Round_number ( 9 ),
    .Input_key    ( {key_expansion_reg[6], key_expansion_reg[5]} ),
    .Output_key   ( key_expansion_new_key[7] ) 
);

aes256_key_expansion_port key_expansion_inst_8 (
    .Round_number ( 10 ),
    .Input_key    ( {key_expansion_reg[7], key_expansion_reg[6]} ),
    .Output_key   ( key_expansion_new_key[8] ) 
);

aes256_key_expansion_port key_expansion_inst_9 (
    .Round_number ( 11 ),
    .Input_key    ( {key_expansion_reg[8], key_expansion_reg[7]} ),
    .Output_key   ( key_expansion_new_key[9] ) 
);

aes256_key_expansion_port key_expansion_inst_10 (
    .Round_number ( 12 ),
    .Input_key    ( {key_expansion_reg[9], key_expansion_reg[8]} ),
    .Output_key   ( key_expansion_new_key[10] ) 
);

aes256_key_expansion_port key_expansion_inst_11 (
    .Round_number ( 13 ),
    .Input_key    ( {key_expansion_reg[10], key_expansion_reg[9]} ),
    .Output_key   ( key_expansion_new_key[11] ) 
);

aes256_key_expansion_port key_expansion_inst_12 (
    .Round_number ( 14 ),
    .Input_key    ( {key_expansion_reg[11], key_expansion_reg[10]} ),
    .Output_key   ( key_expansion_new_key[12] ) 
);

aes_round round_inst_1 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_reg[255:128] ),
    .Input_block  ( input_block ^ key_reg[127:0] ),
    .Output_block ( round_output_block[0] )
);

aes_round round_inst_2 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[0] ),
    .Input_block  ( stage_block_reg[0] ),
    .Output_block ( round_output_block[1] )
);

aes_round round_inst_3 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[1] ),
    .Input_block  ( stage_block_reg[1] ),
    .Output_block ( round_output_block[2] )
);

aes_round round_inst_4 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[2] ),
    .Input_block  ( stage_block_reg[2] ),
    .Output_block ( round_output_block[3] )
);

aes_round round_inst_5 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[3] ),
    .Input_block  ( stage_block_reg[3] ),
    .Output_block ( round_output_block[4] )
);

aes_round round_inst_6 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[4] ),
    .Input_block  ( stage_block_reg[4] ),
    .Output_block ( round_output_block[5] )
);

aes_round round_inst_7 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[5] ),
    .Input_block  ( stage_block_reg[5] ),
    .Output_block ( round_output_block[6] )
);

aes_round round_inst_8 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[6] ),
    .Input_block  ( stage_block_reg[6] ),
    .Output_block ( round_output_block[7] )
);

aes_round round_inst_9 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[7] ),
    .Input_block  ( stage_block_reg[7] ),
    .Output_block ( round_output_block[8] )
);

aes_round round_inst_10 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[8] ),
    .Input_block  ( stage_block_reg[8] ),
    .Output_block ( round_output_block[9] )
);

aes_round round_inst_11 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[9] ),
    .Input_block  ( stage_block_reg[9] ),
    .Output_block ( round_output_block[10] )
);

aes_round round_inst_12 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[10] ),
    .Input_block  ( stage_block_reg[10] ),
    .Output_block ( round_output_block[11] )
);

aes_round round_inst_13 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b0 ),
    .Key          ( key_expansion_reg[11] ),
    .Input_block  ( stage_block_reg[11] ),
    .Output_block ( round_output_block[12] )
);

aes_round round_inst_14 (
    .Encrypt      ( 1'b1 ),
    .Last         ( 1'b1 ),
    .Key          ( key_expansion_reg[12] ),
    .Input_block  ( stage_block_reg[12] ),
    .Output_block ( round_output_block[13] )
);

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
