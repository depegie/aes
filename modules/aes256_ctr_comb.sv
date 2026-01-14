`include "aes_defines.svh"

module aes256_ctr_comb (
    input  logic                           Clk,
    input  logic                           Rst,

    input  logic                           S_axis_tvalid,
    output logic                           S_axis_tready,
    input  logic   [`AES_BLOCK_SIZE-1 : 0] S_axis_tdata,
    input  logic [`AES_BLOCK_SIZE/8-1 : 0] S_axis_tkeep,
    input  logic                           S_axis_tlast,
    input  logic                           S_axis_tuser,
    
    output logic                           M_axis_tvalid,
    input  logic                           M_axis_tready,
    output logic   [`AES_BLOCK_SIZE-1 : 0] M_axis_tdata,
    output logic [`AES_BLOCK_SIZE/8-1 : 0] M_axis_tkeep,
    output logic                           M_axis_tlast
);

localparam int KEY_LENGTH       = `AES_KEY_LENGTH;
localparam int BLOCK_SIZE       = `AES_BLOCK_SIZE;
localparam int NUMBER_OF_ROUNDS = `AES_NUMBER_OF_ROUNDS;

logic   [KEY_LENGTH-1 : 0] key_reg;
logic   [BLOCK_SIZE-1 : 0] counter_reg;
logic   [BLOCK_SIZE-1 : 0] input_text_reg;
logic [BLOCK_SIZE/8-1 : 0] input_keep_reg;
logic   [BLOCK_SIZE-1 : 0] output_block_reg;

logic encrypt_reg;
logic block_last_reg;
logic most_sig_halfkey_reg;

logic [KEY_LENGTH-1 : 0] key_expansion_key[NUMBER_OF_ROUNDS-1];
logic [BLOCK_SIZE-1 : 0] key_expansion_new_key[NUMBER_OF_ROUNDS-1];

logic [BLOCK_SIZE-1 : 0] round_block[NUMBER_OF_ROUNDS];
logic [BLOCK_SIZE-1 : 0] round_key[NUMBER_OF_ROUNDS+1];

logic [BLOCK_SIZE-1 : 0] input_block;
logic [BLOCK_SIZE-1 : 0] output_block;
logic [BLOCK_SIZE-1 : 0] output_text;

assign input_block = invert_bytes(counter_reg);
assign output_text = input_text_reg ^ output_block_reg;

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
            if (S_axis_tvalid & S_axis_tready & most_sig_halfkey_reg)
                next_state = ST_COUNTER;
            else
                next_state = ST_KEY;
        end

        ST_COUNTER: begin
            if (S_axis_tvalid & S_axis_tready)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_COUNTER;
        end

        ST_INPUT_TEXT: begin
            if (S_axis_tvalid & S_axis_tready)
                next_state = ST_CIPHER;
            else
                next_state = ST_INPUT_TEXT;
        end

        ST_CIPHER: begin
            next_state = ST_OUTPUT_TEXT;
        end

        ST_OUTPUT_TEXT: begin
            if (M_axis_tvalid & M_axis_tready & M_axis_tlast)
                next_state = ST_KEY;
            else if (M_axis_tvalid & M_axis_tready)
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
        ST_KEY, ST_COUNTER, ST_INPUT_TEXT:
            S_axis_tready = 1'b1;
        
        default:
            S_axis_tready = 1'b0;
    endcase

always_comb
    case (state_reg)
        ST_OUTPUT_TEXT: begin
            M_axis_tvalid = 1'b1;
            M_axis_tdata = output_text;
            M_axis_tkeep = input_keep_reg;
            M_axis_tlast = block_last_reg;
        end

        default: begin
            M_axis_tvalid = 1'b0;
            M_axis_tdata = 128'h0;
            M_axis_tkeep = 16'b0;
            M_axis_tlast = 1'b0;
        end
    endcase

always_ff @(posedge Clk)
    if (Rst) begin
        most_sig_halfkey_reg <= 1'b0;
    end
    else if (state_reg == ST_KEY & S_axis_tvalid & S_axis_tready & most_sig_halfkey_reg) begin
        most_sig_halfkey_reg <= 1'b0;
    end
    else if (state_reg == ST_KEY & S_axis_tvalid & S_axis_tready) begin
        most_sig_halfkey_reg <= 1'b1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        key_reg <= 256'h0;
    end
    else if (state_reg == ST_KEY & S_axis_tvalid & S_axis_tready & most_sig_halfkey_reg) begin
        key_reg[255:128] <= S_axis_tdata;
    end
    else if (state_reg == ST_KEY & S_axis_tvalid & S_axis_tready) begin
        key_reg[127:0] <= S_axis_tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        counter_reg <= 128'h0;
    end
    else if (state_reg == ST_COUNTER & S_axis_tvalid & S_axis_tready) begin
        counter_reg <= invert_bytes(S_axis_tdata);
    end
    else if (state_reg == ST_OUTPUT_TEXT & M_axis_tvalid & M_axis_tready) begin
        counter_reg <= counter_reg + 1;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_text_reg <= 128'h0;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis_tvalid & S_axis_tready) begin
        input_text_reg <= S_axis_tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_keep_reg <= 16'b0;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis_tvalid & S_axis_tready) begin
        input_keep_reg <= S_axis_tkeep;
    end
    else if (state_reg == ST_OUTPUT_TEXT & M_axis_tvalid & M_axis_tready) begin
        input_keep_reg <= 16'b0;
    end

always_ff @(posedge Clk)
    if (Rst)
        output_block_reg <= 128'h0;
    else if (state_reg == ST_CIPHER)
        output_block_reg <= output_block;

always @(posedge Clk)
    if (Rst) begin
        encrypt_reg <= 1'b0;
        block_last_reg <= 1'b0;
    end
    else if (S_axis_tvalid & S_axis_tready) begin
        encrypt_reg <= S_axis_tuser;
        block_last_reg <= S_axis_tlast;
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

generate
    for (genvar k=2; k<=NUMBER_OF_ROUNDS; k++) begin
        aes_key_expander key_expansion_inst_11 (
            .Round_number ( k                          ),
            .Input_key    ( key_expansion_key[k-2]     ),
            .Output_key   ( key_expansion_new_key[k-2] ) 
        );
    end
endgenerate

aes_round_key_adder add_round_key_inst (
    .Input_block  ( input_block    ),
    .Round_key    ( round_key[0]   ),
    .Output_block ( round_block[0] )
);

generate
    for (genvar r=1; r<=NUMBER_OF_ROUNDS; r++) begin
        if (r == NUMBER_OF_ROUNDS) begin
            aes_round round_inst (
                .Encrypt      ( 1'b1             ),
                .Last         ( 1'b1             ),
                .Key          ( round_key[r]     ),
                .Input_block  ( round_block[r-1] ),
                .Output_block ( output_block     )
            );
        end
        else begin
            aes_round round_inst (
                .Encrypt      ( 1'b1             ),
                .Last         ( 1'b0             ),
                .Key          ( round_key[r]     ),
                .Input_block  ( round_block[r-1] ),
                .Output_block ( round_block[r]   )
            );
        end
    end
endgenerate

function automatic logic [BLOCK_SIZE-1 : 0] invert_bytes(logic [BLOCK_SIZE-1 : 0] counter);
    int num_of_bytes = BLOCK_SIZE/8;
    logic [BLOCK_SIZE-1 : 0] inverted_counter;

    for (int i=0; i<num_of_bytes; i++) begin
        inverted_counter[8*i +: 8] = counter[8*(num_of_bytes-1-i) +: 8];
    end

    return inverted_counter;
endfunction

endmodule
