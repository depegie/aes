`include "aes_defines.svh"

module aes_inv_shift_rows (
    input                          Encrypt,
    input  [`AES_BLOCK_SIZE-1 : 0] Input_block,
    output [`AES_BLOCK_SIZE-1 : 0] Output_block
);

logic [`AES_BLOCK_SIZE-1 : 0] enc_block;
logic [`AES_BLOCK_SIZE-1 : 0] dec_block;

assign Output_block = Encrypt ? enc_block : dec_block;

assign enc_block = {
    Input_block[8*11 +: 8], Input_block[8* 6 +: 8], Input_block[8* 1 +: 8], Input_block[8*12 +: 8],
    Input_block[8* 7 +: 8], Input_block[8* 2 +: 8], Input_block[8*13 +: 8], Input_block[8* 8 +: 8],
    Input_block[8* 3 +: 8], Input_block[8*14 +: 8], Input_block[8* 9 +: 8], Input_block[8* 4 +: 8],
    Input_block[8*15 +: 8], Input_block[8*10 +: 8], Input_block[8* 5 +: 8], Input_block[8* 0 +: 8]
};
    
assign dec_block = {
    Input_block[8* 3 +: 8], Input_block[8* 6 +: 8], Input_block[8* 9 +: 8], Input_block[8*12 +: 8],
    Input_block[8*15 +: 8], Input_block[8* 2 +: 8], Input_block[8* 5 +: 8], Input_block[8* 8 +: 8],
    Input_block[8*11 +: 8], Input_block[8*14 +: 8], Input_block[8* 1 +: 8], Input_block[8* 4 +: 8],
    Input_block[8* 7 +: 8], Input_block[8*10 +: 8], Input_block[8*13 +: 8], Input_block[8* 0 +: 8]
};

endmodule
