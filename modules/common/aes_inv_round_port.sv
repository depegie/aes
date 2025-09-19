`include "aes_defines.svh"

module aes_inv_round_port (
    input                              Enc,
    input                              Last,
    input      [`AES_BLOCK_SIZE-1 : 0] Key,
    input      [`AES_BLOCK_SIZE-1 : 0] Input_block,
    output reg [`AES_BLOCK_SIZE-1 : 0] Output_block
);

reg [`AES_BLOCK_SIZE-1 : 0] sb_input_block;
reg [`AES_BLOCK_SIZE-1 : 0] sr_input_block;
reg [`AES_BLOCK_SIZE-1 : 0] mc_input_block;
reg [`AES_BLOCK_SIZE-1 : 0] ark_input_block;
reg [`AES_BLOCK_SIZE-1 : 0] ark_key;

wire [`AES_BLOCK_SIZE-1 : 0] sb_output_block;
wire [`AES_BLOCK_SIZE-1 : 0] sr_output_block;
wire [`AES_BLOCK_SIZE-1 : 0] mc_output_block;
wire [`AES_BLOCK_SIZE-1 : 0] ark_output_block;

always_comb begin
    if (Enc) begin
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
    sb_input_block = Enc ? Input_block : sr_output_block;
    sr_input_block = Enc ? sb_output_block : Input_block;

    if (Last) begin
        mc_input_block = 0;
        ark_input_block = Enc ? sr_output_block : sb_output_block;
    end
    else begin
        mc_input_block = Enc ? sr_output_block : ark_output_block;
        ark_input_block = Enc ? mc_output_block : sb_output_block;
    end

    ark_key = Key;
end

aes_inv_sub_bytes sb_inst (
    .enc       ( Enc             ),
    .block     ( sb_input_block  ),
    .new_block ( sb_output_block )
);

aes_inv_shift_rows sr_inst (
    .enc       ( Enc             ),
    .block     ( sr_input_block  ),
    .new_block ( sr_output_block )
);

aes_inv_mix_columns mc_inst (
    .enc       ( Enc             ),
    .block     ( mc_input_block  ),
    .new_block ( mc_output_block )
);

aes_add_round_key ark_inst (
    .block     ( ark_input_block  ),
    .key       ( ark_key          ),
    .new_block ( ark_output_block )
);

endmodule
