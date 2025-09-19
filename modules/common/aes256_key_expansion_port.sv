`include "aes_defines.svh"

module aes256_key_expansion_port (
    input      [int'($ceil($clog2(`AES_256_ROUNDS_NUMBER)))-1 : 0] round_num,
    input                              [`AES_256_KEY_LENGTH-1 : 0] key,
    output reg                             [`AES_BLOCK_SIZE-1 : 0] new_key
);

reg  [`AES_WORD_SIZE-1 : 0] rcon;

reg [`AES_WORD_SIZE-1 : 0] before_rotword;
reg [`AES_WORD_SIZE-1 : 0] before_subword;
reg [`AES_WORD_SIZE-1 : 0] before_rcon;

wire [`AES_WORD_SIZE-1 : 0] after_rotword;
wire [`AES_WORD_SIZE-1 : 0] after_subword;
wire [`AES_WORD_SIZE-1 : 0] after_rcon;

always_comb begin
    if (round_num % 2 == 0) begin
        before_rotword = key[`AES_8TH_WORD];
        before_subword = after_rotword;
        before_rcon    = after_subword;

        new_key[`AES_1ST_WORD] = key[`AES_1ST_WORD] ^ after_rcon;
        new_key[`AES_2ND_WORD] = key[`AES_2ND_WORD] ^ new_key[`AES_1ST_WORD];
        new_key[`AES_3RD_WORD] = key[`AES_3RD_WORD] ^ new_key[`AES_2ND_WORD];
        new_key[`AES_4TH_WORD] = key[`AES_4TH_WORD] ^ new_key[`AES_3RD_WORD];
    end
    else begin
        before_rotword = 0;
        before_subword = key[`AES_8TH_WORD];
        before_rcon = 0;

        new_key[`AES_1ST_WORD] = key[`AES_1ST_WORD] ^ after_subword;
        new_key[`AES_2ND_WORD] = key[`AES_2ND_WORD] ^ new_key[`AES_1ST_WORD];
        new_key[`AES_3RD_WORD] = key[`AES_3RD_WORD] ^ new_key[`AES_2ND_WORD];
        new_key[`AES_4TH_WORD] = key[`AES_4TH_WORD] ^ new_key[`AES_3RD_WORD];
    end
end

always_comb
    case (round_num)
        2:       rcon = `AES_RCON_01;
        4:       rcon = `AES_RCON_02;
        6:       rcon = `AES_RCON_03;
        8:       rcon = `AES_RCON_04;
        10:      rcon = `AES_RCON_05;
        12:      rcon = `AES_RCON_06;
        14:      rcon = `AES_RCON_07;
        default: rcon = 32'h0;
    endcase

assign after_rotword = (before_rotword >> 8) | (before_rotword << `AES_WORD_SIZE-8);

generate
    for (genvar i=0; i<`AES_WORD_SIZE/8; i++)
        aes_sbox aes_sbox_inst(before_subword[8*i +: 8], after_subword[8*i +: 8]);
endgenerate

assign after_rcon = before_rcon ^ rcon;

endmodule
