`include "aes_defines.svh"

module aes256_cbc_comb #(
    parameter int S_AXIS_WIDTH = 8,
    parameter int M_AXIS_WIDTH = 8
)(
    input          Clk,
    input          Rst,
    axis_if.slave  S_axis,
    axis_if.master M_axis
);

localparam int KEY_LENGTH       = `AES_256_KEY_LENGTH;
localparam int BLOCK_SIZE       = `AES_BLOCK_SIZE;
localparam int NUMBER_OF_ROUNDS = `AES_256_NUMBER_OF_ROUNDS;

reg [$clog2(BLOCK_SIZE/S_AXIS_WIDTH)-1 : 0] input_cnt;
reg [$clog2(BLOCK_SIZE/M_AXIS_WIDTH)-1 : 0] output_cnt;

reg [KEY_LENGTH-1 : 0] key_reg;
reg [BLOCK_SIZE-1 : 0] iv_reg;
reg [BLOCK_SIZE-1 : 0] input_text_reg;

reg  [KEY_LENGTH-1 : 0] ke_key_areg[NUMBER_OF_ROUNDS-1];
wire [BLOCK_SIZE-1 : 0] ke_new_key[NUMBER_OF_ROUNDS-1];

reg enc_reg;
reg last_reg;

enum reg [5:0] {
    ST_KEY_0    = 6'b1 << 0,
    ST_KEY_1    = 6'b1 << 1,
    ST_IV       = 6'b1 << 2,
    ST_TEXT_IN  = 6'b1 << 3,
    ST_CIPHER   = 6'b1 << 4,
    ST_TEXT_OUT = 6'b1 << 5
} state, next_state;

always_ff @(posedge Clk)
    if (Rst)
        state <= ST_KEY_0;
    else
        state <= next_state;

always_comb
    case (state)
        ST_KEY_0: begin
            if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_KEY_1;
            else
                next_state = ST_KEY_0;
        end

        ST_KEY_1: begin
            if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_IV;
            else
                next_state = ST_KEY_1;
        end

        ST_IV: begin
            if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_TEXT_IN;
            else
                next_state = ST_IV;
        end

        ST_TEXT_IN: begin
            if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                next_state = ST_CIPHER;
            else
                next_state = ST_TEXT_IN;
        end

        ST_CIPHER: begin
            next_state = ST_TEXT_OUT;
        end

        ST_TEXT_OUT: begin
            if (M_axis.tvalid & M_axis.tready & M_axis.tlast & (&output_cnt))
                next_state = ST_KEY_0;
            else if (M_axis.tvalid & M_axis.tready & (&output_cnt))
                next_state = ST_TEXT_IN;
            else
                next_state = ST_TEXT_OUT;
        end
    endcase

always_comb
    case (state)
        ST_KEY_0, ST_KEY_1, ST_IV, ST_TEXT_IN:
            S_axis.tready = 1'b1;
        
        default:
            S_axis.tready = 1'b0;
    endcase

always_ff @(posedge Clk)
    if (Rst)
        input_cnt <= 0;
    else
        case (state)
            ST_KEY_0, ST_KEY_1, ST_IV, ST_TEXT_IN:
                if (S_axis.tvalid & S_axis.tready & (&input_cnt))
                    input_cnt <= 0;
                else if (S_axis.tvalid & S_axis.tready)
                    input_cnt <= input_cnt + 'd1;
            
            default:
                input_cnt <= 0;
        endcase

always_ff @(posedge Clk)
    if (Rst)
        output_cnt <= 0;
    else
        case (state)
            ST_TEXT_OUT:
                if (M_axis.tvalid & M_axis.tready)
                    output_cnt <= output_cnt + 'd1;
            
            default:
                output_cnt <= 0;
        endcase

always_ff @(posedge Clk)
    if (Rst) begin
        key_reg <= 256'h0;
    end
    else if (state == ST_KEY_0 & S_axis.tvalid & S_axis.tready) begin
        key_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    else if (state == ST_KEY_1 & S_axis.tvalid & S_axis.tready) begin
        key_reg[input_cnt*S_AXIS_WIDTH+BLOCK_SIZE +: S_AXIS_WIDTH] <= S_axis.tdata;
    end

always_ff @(posedge Clk)
    if (Rst) begin
        iv_reg <= 128'h0;
    end
    else if (state == ST_IV & S_axis.tvalid & S_axis.tready) begin
        iv_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end
    // else if (state == ST_TEXT_OUT & M_axis.tvalid & M_axis.tready & (&output_cnt)) begin
    //     iv_reg <= enc_reg ? output_text_areg : input_text_reg;
    // end

always_ff @(posedge Clk)
    if (Rst) begin
        input_text_reg <= 128'h0;
    end
    else if (state == ST_TEXT_IN & S_axis.tvalid & S_axis.tready) begin
        input_text_reg[input_cnt*S_AXIS_WIDTH +: S_AXIS_WIDTH] <= S_axis.tdata;
    end

always @(posedge Clk)
    if (Rst) begin
        enc_reg <= 1'b0;
        last_reg <= 1'b0;
    end
    else if (S_axis.tvalid & S_axis.tready) begin
        enc_reg <= S_axis.tuser;
        last_reg <= S_axis.tlast;
    end

always_comb begin
    ke_key_areg[ 0] = key_reg;
    ke_key_areg[ 1] = { ke_new_key[ 0], key_reg[255:128] };
    ke_key_areg[ 2] = { ke_new_key[ 1], ke_new_key[ 0]   };
    ke_key_areg[ 3] = { ke_new_key[ 2], ke_new_key[ 1]   };
    ke_key_areg[ 4] = { ke_new_key[ 3], ke_new_key[ 2]   };
    ke_key_areg[ 5] = { ke_new_key[ 4], ke_new_key[ 3]   };
    ke_key_areg[ 6] = { ke_new_key[ 5], ke_new_key[ 4]   };
    ke_key_areg[ 7] = { ke_new_key[ 6], ke_new_key[ 5]   };
    ke_key_areg[ 8] = { ke_new_key[ 7], ke_new_key[ 6]   };
    ke_key_areg[ 9] = { ke_new_key[ 8], ke_new_key[ 7]   };
    ke_key_areg[10] = { ke_new_key[ 9], ke_new_key[ 8]   };
    ke_key_areg[11] = { ke_new_key[10], ke_new_key[ 9]   };
    ke_key_areg[12] = { ke_new_key[11], ke_new_key[10]   };
end

generate // 2-14 == 0-12 == 13 == NUMBER_OF_ROUNDS-1
    for (genvar k=2; k<NUMBER_OF_ROUNDS+1; k++) begin
        aes256_key_expansion_param #(
            .ROUND_NUMBER ( k )
        ) key_expansion_inst (
            .Input_key  ( ke_key_areg[k-2] ),
            .Output_key ( ke_new_key[k-2]  )
        );
    end
endgenerate

endmodule
