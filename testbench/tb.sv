`include "generator.svh"

import tb_pkg::*;

module tb;
    generator gen;

    mailbox #(packet_t) gen2drv_mbx;
    mailbox #(packet_t) gen2scb_mbx;

    event gen2drv_finish_ev;
    event gen2scb_finish_ev;

    packet_t packet;

    initial begin
        gen = new();
        gen2drv_mbx = new();
        gen2scb_mbx = new();

        gen.send_pkts("pkts_in.txt",  gen2drv_mbx, gen2drv_finish_ev);
        gen.send_pkts("pkts_out.txt", gen2scb_mbx, gen2scb_finish_ev);
    end

endmodule
