`include "aes_defines.svh"

module aes256_cbc_comb (
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

logic                      [KEY_LENGTH-1 : 0] key_reg;
logic                      [BLOCK_SIZE-1 : 0] iv_reg;
logic                      [BLOCK_SIZE-1 : 0] input_text_reg;
logic                      [BLOCK_SIZE-1 : 0] output_block_reg;

logic                                         encrypt_reg;
logic                                         block_last_reg;
logic                                         most_sig_halfkey_reg;

logic [KEY_LENGTH-1 : 0] key_expansion_key[NUMBER_OF_ROUNDS-1];
logic [BLOCK_SIZE-1 : 0] key_expansion_new_key[NUMBER_OF_ROUNDS-1];

logic [BLOCK_SIZE-1 : 0] eic_key_before_mc[NUMBER_OF_ROUNDS-1];
logic [BLOCK_SIZE-1 : 0] eic_key_after_mc [NUMBER_OF_ROUNDS-1];

logic [BLOCK_SIZE-1 : 0] round_block[NUMBER_OF_ROUNDS];
logic [BLOCK_SIZE-1 : 0] round_key[NUMBER_OF_ROUNDS+1];

logic [BLOCK_SIZE-1 : 0] input_block;
logic [BLOCK_SIZE-1 : 0] output_block;
logic [BLOCK_SIZE-1 : 0] output_text;

assign input_block = encrypt_reg ? input_text_reg ^ iv_reg : input_text_reg;
assign output_text = encrypt_reg ? output_block_reg : output_block_reg ^ iv_reg;

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
            if (S_axis_tvalid & S_axis_tready & most_sig_halfkey_reg)
                next_state = ST_IV;
            else
                next_state = ST_KEY;
        end

        ST_IV: begin
            if (S_axis_tvalid & S_axis_tready)
                next_state = ST_INPUT_TEXT;
            else
                next_state = ST_IV;
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
        ST_KEY, ST_IV, ST_INPUT_TEXT:
            S_axis_tready = 1'b1;
        
        default:
            S_axis_tready = 1'b0;
    endcase

always_comb
    case (state_reg)
        ST_OUTPUT_TEXT: begin
            M_axis_tvalid = 1'b1;
            M_axis_tdata = output_text;
            M_axis_tkeep = {(BLOCK_SIZE/8){1'b1}};
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
        iv_reg <= 128'h0;
    end
    else if (state_reg == ST_IV & S_axis_tvalid & S_axis_tready) begin
        iv_reg <= S_axis_tdata;
    end
    else if (state_reg == ST_OUTPUT_TEXT & M_axis_tvalid & M_axis_tready) begin
        iv_reg <= encrypt_reg ? output_text : input_text_reg;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        input_text_reg <= 128'h0;
    end
    else if (state_reg == ST_INPUT_TEXT & S_axis_tvalid & S_axis_tready) begin
        input_text_reg <= S_axis_tdata;
    end

always_ff @(posedge Clk)
    if (Rst)
        output_block_reg <= 128'h0;
    else if (state_reg == ST_CIPHER)
        output_block_reg <= output_block;

always @(posedge Clk)
    if (S_axis_tvalid & S_axis_tready)
        encrypt_reg <= S_axis_tuser;

always_ff @(posedge Clk)
    if (Rst)
        block_last_reg <= 128'b0;
    else if (S_axis_tvalid & S_axis_tready)
        block_last_reg <= S_axis_tlast;

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
    eic_key_before_mc[ 0] = key_expansion_new_key[11]   ;
    eic_key_before_mc[ 1] = key_expansion_new_key[10]   ;
    eic_key_before_mc[ 2] = key_expansion_new_key[ 9]   ;
    eic_key_before_mc[ 3] = key_expansion_new_key[ 8]   ;
    eic_key_before_mc[ 4] = key_expansion_new_key[ 7]   ;
    eic_key_before_mc[ 5] = key_expansion_new_key[ 6]   ;
    eic_key_before_mc[ 6] = key_expansion_new_key[ 5]   ;
    eic_key_before_mc[ 7] = key_expansion_new_key[ 4]   ;
    eic_key_before_mc[ 8] = key_expansion_new_key[ 3]   ;
    eic_key_before_mc[ 9] = key_expansion_new_key[ 2]   ;
    eic_key_before_mc[10] = key_expansion_new_key[ 1]   ;
    eic_key_before_mc[11] = key_expansion_new_key[ 0]   ;
    eic_key_before_mc[12] = key_reg[255:128] ;
end


always_comb begin
    round_key[ 0] = encrypt_reg ? key_reg[127:  0]          : key_expansion_new_key[12] ;
    round_key[ 1] = encrypt_reg ? key_reg[255:128]          : eic_key_after_mc[ 0]      ;
    round_key[ 2] = encrypt_reg ? key_expansion_new_key[ 0] : eic_key_after_mc[ 1]      ;
    round_key[ 3] = encrypt_reg ? key_expansion_new_key[ 1] : eic_key_after_mc[ 2]      ;
    round_key[ 4] = encrypt_reg ? key_expansion_new_key[ 2] : eic_key_after_mc[ 3]      ;
    round_key[ 5] = encrypt_reg ? key_expansion_new_key[ 3] : eic_key_after_mc[ 4]      ;
    round_key[ 6] = encrypt_reg ? key_expansion_new_key[ 4] : eic_key_after_mc[ 5]      ;
    round_key[ 7] = encrypt_reg ? key_expansion_new_key[ 5] : eic_key_after_mc[ 6]      ;
    round_key[ 8] = encrypt_reg ? key_expansion_new_key[ 6] : eic_key_after_mc[ 7]      ;
    round_key[ 9] = encrypt_reg ? key_expansion_new_key[ 7] : eic_key_after_mc[ 8]      ;
    round_key[10] = encrypt_reg ? key_expansion_new_key[ 8] : eic_key_after_mc[ 9]      ;
    round_key[11] = encrypt_reg ? key_expansion_new_key[ 9] : eic_key_after_mc[10]      ;
    round_key[12] = encrypt_reg ? key_expansion_new_key[10] : eic_key_after_mc[11]      ;
    round_key[13] = encrypt_reg ? key_expansion_new_key[11] : eic_key_after_mc[12]      ;
    round_key[14] = encrypt_reg ? key_expansion_new_key[12] : key_reg[127:  0]          ;
end

generate
    for (genvar k=2; k<=NUMBER_OF_ROUNDS; k++) begin
        aes_key_expander key_expansion_inst (
            .Round_number ( k                          ),
            .Input_key    ( key_expansion_key[k-2]     ),
            .Output_key   ( key_expansion_new_key[k-2] ) 
        );
    end

    for (genvar i=0; i<NUMBER_OF_ROUNDS-1; i++) begin
        aes_columns_mixer mc_inst (
            .Encrypt      ( 1'b0                 ),
            .Input_block  ( eic_key_before_mc[i] ),
            .Output_block ( eic_key_after_mc[i]  )
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
                .Encrypt      ( encrypt_reg      ),
                .Last         ( 1'b1             ),
                .Key          ( round_key[r]     ),
                .Input_block  ( round_block[r-1] ),
                .Output_block ( output_block     )
            );
        end
        else begin
            aes_round round_inst (
                .Encrypt      ( encrypt_reg      ),
                .Last         ( 1'b0             ),
                .Key          ( round_key[r]     ),
                .Input_block  ( round_block[r-1] ),
                .Output_block ( round_block[r]   )
            );
        end
    end
endgenerate

endmodule
