`include "aes_defines.svh"

module aes_round (
    input                                Encrypt,
    input                                Last,
    input        [`AES_BLOCK_SIZE-1 : 0] Key,
    input        [`AES_BLOCK_SIZE-1 : 0] Input_block,
    output logic [`AES_BLOCK_SIZE-1 : 0] Output_block
);

logic [`AES_BLOCK_SIZE-1 : 0] sb_to_sr_block;
logic [`AES_BLOCK_SIZE-1 : 0] sr_output_block;
logic [`AES_BLOCK_SIZE-1 : 0] mc_output_block;
logic [`AES_BLOCK_SIZE-1 : 0] ark_input_block;

assign ark_input_block = Last ? sr_output_block : mc_output_block;

aes_bytes_substitutor sb_inst (
    .Encrypt      ( Encrypt        ),
    .Input_block  ( Input_block    ),
    .Output_block ( sb_to_sr_block )
);

aes_rows_shifter sr_inst (
    .Encrypt      ( Encrypt         ),
    .Input_block  ( sb_to_sr_block  ),
    .Output_block ( sr_output_block )
);

aes_columns_mixer mc_inst (
    .Encrypt      ( Encrypt         ),
    .Input_block  ( sr_output_block ),
    .Output_block ( mc_output_block )
);

aes_round_key_adder ark_inst (
    .Input_block  ( ark_input_block  ),
    .Round_key    ( Key    ),
    .Output_block ( Output_block )
);

endmodule
