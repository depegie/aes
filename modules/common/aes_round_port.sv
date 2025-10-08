`include "aes_defines.svh"

module aes_round_port (
    input                                Encrypt,
    input                                Last,
    input        [`AES_BLOCK_SIZE-1 : 0] Key,
    input        [`AES_BLOCK_SIZE-1 : 0] Input_block,
    output logic [`AES_BLOCK_SIZE-1 : 0] Output_block
);

logic [`AES_BLOCK_SIZE-1 : 0] sb_input_block;
logic [`AES_BLOCK_SIZE-1 : 0] sr_input_block;
logic [`AES_BLOCK_SIZE-1 : 0] mc_input_block;
logic [`AES_BLOCK_SIZE-1 : 0] ark_input_block;
logic [`AES_BLOCK_SIZE-1 : 0] ark_round_key;

logic [`AES_BLOCK_SIZE-1 : 0] sb_output_block;
logic [`AES_BLOCK_SIZE-1 : 0] sr_output_block;
logic [`AES_BLOCK_SIZE-1 : 0] mc_output_block;
logic [`AES_BLOCK_SIZE-1 : 0] ark_output_block;

assign sb_input_block = Encrypt ? Input_block     : sr_output_block;
assign sr_input_block = Encrypt ? sb_output_block : Input_block;
assign mc_input_block = Encrypt ? sr_output_block : ark_output_block;
assign ark_round_key  = Key;

always_comb begin
    if (Encrypt) begin
        Output_block = ark_output_block;
    end
    else if (Last) begin
        Output_block = ark_output_block;
    end
    else begin
        Output_block = mc_output_block;
    end
end

always_comb begin
    if (Last) begin
        ark_input_block = Encrypt ? sr_output_block : sb_output_block;
    end
    else begin
        ark_input_block = Encrypt ? mc_output_block : sb_output_block;
    end
end

aes_inv_sub_bytes sb_inst (
    .Encrypt      ( Encrypt         ),
    .Input_block  ( sb_input_block  ),
    .Output_block ( sb_output_block )
);

aes_inv_shift_rows sr_inst (
    .Encrypt      ( Encrypt         ),
    .Input_block  ( sr_input_block  ),
    .Output_block ( sr_output_block )
);

aes_inv_mix_columns mc_inst (
    .Encrypt      ( Encrypt         ),
    .Input_block  ( mc_input_block  ),
    .Output_block ( mc_output_block )
);

aes_add_round_key ark_inst (
    .Input_block  ( ark_input_block  ),
    .Round_key    ( ark_round_key    ),
    .Output_block ( ark_output_block )
);

endmodule
