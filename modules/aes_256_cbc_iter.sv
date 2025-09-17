`include "aes_defines.svh"

module aes_256_cbc_iter #(
    parameter int S_AXIS_WIDTH = 8,
    parameter int M_AXIS_WIDTH = 8
)(
    input          Clk,
    input          Rst,
    axis_if.slave  S_axis,
    axis_if.master M_axis
);

localparam int ROUNDS_NUMBER = `AES_256_ROUNDS_NUMBER;
localparam int KEY_LENGTH    = `AES_256_KEY_LENGTH;
localparam int BLOCK_SIZE    = `AES_BLOCK_SIZE;

reg                    ke_pending_reg;
reg                    last_reg;
reg                    enc_reg;

reg [$clog2(BLOCK_SIZE/S_AXIS_WIDTH)-1 : 0] in_counter;
reg [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] out_counter;

reg [int'($ceil($clog2(ROUNDS_NUMBER)))-1 : 0] ke_counter;
reg [int'($ceil($clog2(ROUNDS_NUMBER)))-1 : 0] c_counter;

reg [BLOCK_SIZE-1 : 0] key_reg[ROUNDS_NUMBER+1];
reg [BLOCK_SIZE-1 : 0] iv_reg;
reg [BLOCK_SIZE-1 : 0] text_in_reg;
reg [BLOCK_SIZE-1 : 0] text_out_reg;
reg [BLOCK_SIZE-1 : 0] block_reg;
reg [BLOCK_SIZE-1 : 0] new_block_reg;

reg   [KEY_LENGTH-1 : 0] ke_key_reg;
reg   [BLOCK_SIZE-1 : 0] sb_block_reg;
reg   [BLOCK_SIZE-1 : 0] sr_block_reg;
reg   [BLOCK_SIZE-1 : 0] mc_block_reg;
reg   [BLOCK_SIZE-1 : 0] ark_block_reg;
reg [KEY_LENGTH/2-1 : 0] ark_key_reg;

wire [KEY_LENGTH/2-1 : 0] ke_new_key;
wire   [BLOCK_SIZE-1 : 0] sb_new_block;
wire   [BLOCK_SIZE-1 : 0] sr_new_block;
wire   [BLOCK_SIZE-1 : 0] mc_new_block;
wire   [BLOCK_SIZE-1 : 0] ark_new_block;

enum reg [6:0] {
    ST_KEY_0         = 7'b1 << 0,
    ST_KEY_1         = 7'b1 << 1,
    ST_IV            = 7'b1 << 2,
    ST_TEXT_IN       = 7'b1 << 3,
    ST_KEY_EXPANSION = 7'b1 << 4,
    ST_CIPHER        = 7'b1 << 5,
    ST_TEXT_OUT      = 7'b1 << 6
} state, next_state;

always_ff @(posedge Clk)
    if (Rst)
        state <= ST_KEY_0;
    else
        state <= next_state;

always_comb begin
    case (state)
        ST_KEY_0: begin
            if (S_axis.tvalid & S_axis.tready & |in_counter)
                next_state = ST_KEY_1;
            else
                next_state = ST_KEY_0;
        end

        ST_KEY_1: begin
            if (S_axis.tvalid & S_axis.tready & |in_counter)
                next_state = ST_IV;
            else
                next_state = ST_KEY_1;
        end

        ST_IV: begin
            if (S_axis.tvalid & S_axis.tready & |in_counter)
                next_state = ST_TEXT_IN;
            else
                next_state = ST_IV;
        end

        ST_TEXT_IN: begin
            if (S_axis.tvalid & S_axis.tready & |in_counter & ke_counter == ROUNDS_NUMBER)
                next_state = ST_CIPHER;
            else if (S_axis.tvalid & S_axis.tready & |in_counter)
                next_state = ST_KEY_EXPANSION;
            else
                next_state = ST_TEXT_IN;
        end

        ST_KEY_EXPANSION: begin
            if (ke_counter == ROUNDS_NUMBER)
                next_state = ST_CIPHER;
            else
                next_state = ST_KEY_EXPANSION;
        end

        ST_CIPHER: begin
            if (c_counter == ROUNDS_NUMBER)
                next_state = ST_TEXT_OUT;
            else
                next_state = ST_CIPHER;
        end

        ST_TEXT_OUT: begin
            if (M_axis.tvalid & M_axis.tready & M_axis.tlast & |out_counter)
                next_state = ST_KEY_0;
            else if (M_axis.tvalid & M_axis.tready & |out_counter)
                next_state = ST_TEXT_IN;
            else
                next_state = ST_TEXT_OUT;
        end
    endcase
end

always_comb begin
    case (state)
        ST_KEY_0, ST_KEY_1, ST_IV, ST_TEXT_IN:
            S_axis.tready = 1'b1;
        
        default:
            S_axis.tready = 1'b0;
    endcase
end

always_comb begin
    case (state)
        ST_TEXT_OUT: begin
            M_axis.tvalid = 1'b1;
            M_axis.tdata = text_out_reg[out_counter*M_AXIS_WIDTH +: M_AXIS_WIDTH];
            M_axis.tkeep = {(M_AXIS_WIDTH/8){1'b1}};
            M_axis.tlast = (|out_counter) ? last_reg : 1'b0;
        end

        default: begin
            M_axis.tvalid = 1'b0;
            M_axis.tdata = 128'h0;
            M_axis.tkeep = 16'b0;
            M_axis.tlast = 1'b0;
        end
    endcase
end

always_ff @(posedge Clk) begin
    if (Rst) begin
        for (int b=0; b<=ROUNDS_NUMBER; b++) key_reg[b] <= 128'h0;
    end
    else if (state == ST_KEY_0 & S_axis.tvalid & S_axis.tready) begin
        key_reg[0][in_counter*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state == ST_KEY_1 & S_axis.tvalid & S_axis.tready) begin
        key_reg[1][in_counter*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (ke_pending_reg) begin
        key_reg[ke_counter] <= ke_new_key;
    end
end

always_ff @(posedge Clk) begin
    if (Rst) begin
        iv_reg <= 128'h0;
    end
    else if (state == ST_IV & S_axis.tvalid & S_axis.tready) begin
        iv_reg[in_counter*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state == ST_TEXT_OUT & M_axis.tvalid & M_axis.tready & |out_counter) begin
        iv_reg <= enc_reg ? text_out_reg : text_in_reg;
    end
end

always_ff @(posedge Clk) begin
    if (Rst) begin
        text_in_reg <= 128'h0;
    end
    else if (state == ST_TEXT_IN & S_axis.tvalid & S_axis.tready) begin
        text_in_reg[in_counter*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
end

always_ff @(posedge Clk)
    if (Rst)
        in_counter <= 0;
    else
        case (state)
            ST_KEY_0, ST_KEY_1, ST_IV, ST_TEXT_IN:
                if (S_axis.tvalid & S_axis.tready & |in_counter)
                    in_counter <= 0;
                else if (S_axis.tvalid & S_axis.tready)
                    in_counter <= in_counter + 'd1;
            
            default:
                in_counter <= 0;
        endcase

always_ff @(posedge Clk)
    if (Rst)
        out_counter <= 0;
    else
        case (state)
            ST_TEXT_OUT:
                if (M_axis.tvalid & M_axis.tready)
                    out_counter <= out_counter + 'd1;
            
            default:
                out_counter <= 0;
        endcase

always_ff @(posedge Clk) begin
    if (Rst) begin
        ke_counter <= 2;
    end
    else if (state == ST_KEY_0) begin
        ke_counter <= 2;
    end
    else if (ke_pending_reg & ke_counter < ROUNDS_NUMBER) begin
        ke_counter <= ke_counter + 1;
    end
end

always_ff @(posedge Clk) begin
    if (Rst) begin
        ke_pending_reg <= 1'b0;
    end
    else if (ke_counter == ROUNDS_NUMBER) begin
        ke_pending_reg <= 1'b0;
    end
    else if (state == ST_KEY_1 & S_axis.tvalid & S_axis.tready & |in_counter) begin
        ke_pending_reg <= 1'b1;
    end
end

always @(posedge Clk)
    if (Rst) begin
        last_reg <= 1'b0;
        enc_reg <= 1'b0;
    end
    else if (S_axis.tvalid & S_axis.tready) begin
        last_reg <= S_axis.tlast;
        enc_reg <= S_axis.tuser;
    end

always_ff @(posedge Clk) begin
    if (Rst) begin
        c_counter <= 1;
    end
    else if (state == ST_CIPHER) begin
        c_counter <= c_counter + 1;
    end
    else begin
        c_counter <= 1;
    end
end

always_comb begin
    if (c_counter == 1) begin
        block_reg = (enc_reg) ? text_in_reg ^ iv_reg : text_in_reg;
    end
    else begin
        block_reg = new_block_reg;
    end
end

always_comb begin
    text_out_reg = (enc_reg) ? new_block_reg : new_block_reg ^ iv_reg;
end

always_ff @(posedge Clk) begin
    if (Rst) begin
        new_block_reg <= 128'h0;
    end
    else if (enc_reg & state == ST_CIPHER) begin
        new_block_reg <= ark_new_block;
    end
    else if (~enc_reg & state == ST_CIPHER & c_counter == ROUNDS_NUMBER) begin
        new_block_reg <= ark_new_block;
    end
    else if (~enc_reg & state == ST_CIPHER) begin
        new_block_reg <= mc_new_block;
    end
end

always_comb begin
    ke_key_reg = {key_reg[ke_counter-1], key_reg[ke_counter-2]};
end

always_comb begin
    if (enc_reg) begin
        sb_block_reg = (c_counter == 1) ? block_reg ^ key_reg[0] : block_reg;
    end
    else begin
        sb_block_reg = sr_new_block;
    end
end

always_comb begin
    if (enc_reg) begin
        sr_block_reg = sb_new_block;
    end
    else begin
        sr_block_reg = (c_counter == 1) ? block_reg ^ key_reg[ROUNDS_NUMBER] : block_reg;
    end
end

always_comb begin
    if (enc_reg) begin
        mc_block_reg = (c_counter == ROUNDS_NUMBER) ? 0 : sr_new_block;
    end
    else begin
        mc_block_reg = (c_counter == ROUNDS_NUMBER) ? 0 : ark_new_block;
    end
end

always_comb begin
    if (enc_reg) begin
        ark_block_reg = (c_counter == ROUNDS_NUMBER) ? sr_new_block : mc_new_block;
    end
    else begin
        ark_block_reg = sb_new_block;
    end
end

always_comb begin
    if (enc_reg) begin
        ark_key_reg = key_reg[c_counter];
    end
    else begin
        ark_key_reg = key_reg[ROUNDS_NUMBER-c_counter];
    end
end

aes256_key_expansion_port ke_inst (
    .round_num ( ke_counter ),
    .key       ( ke_key_reg ),
    .new_key   ( ke_new_key ) 
);

aes_inv_sub_bytes sb_inst (
    .enc       ( enc_reg      ),
    .block     ( sb_block_reg ),
    .new_block ( sb_new_block )
);

aes_inv_shift_rows sr_inst (
    .enc       ( enc_reg      ),
    .block     ( sr_block_reg ),
    .new_block ( sr_new_block )
);

aes_inv_mix_columns mc_inst (
    .enc       ( enc_reg      ),
    .block     ( mc_block_reg ),
    .new_block ( mc_new_block )
);

aes_add_round_key ark_inst (
    .block     ( ark_block_reg ),
    .key       ( ark_key_reg   ),
    .new_block ( ark_new_block )
);

endmodule
