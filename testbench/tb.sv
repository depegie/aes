`timescale 1ns/1ps

`include "generator.svh"
`include "driver.svh"

import tb_pkg::*;

module tb;
    bit clk;
    bit rst;

    generator gen;
    driver drv;

    axis_if #(`S_AXIS_TDATA_WIDTH) s_axis(clk);

    mailbox #(packet_t) gen2drv_mbx;
    mailbox #(packet_t) gen2scb_mbx;

    event drv2gen_receive_ev;
    event gen2drv_finish_ev;
    event scb2gen_receive_ev;
    event gen2scb_finish_ev;

    packet_t packet;

    always #(`CLK_PERIOD/2) clk = !clk;

    dummy dut (
        .Clk    ( clk ),
        .Rst    ( rst ),
        .S_axis ( s_axis ),
        .Out    ( )
    );

    initial begin
        gen2drv_mbx = new();
        gen2scb_mbx = new();

        gen = new();
        drv = new(gen2drv_mbx, drv2gen_receive_ev, gen2drv_finish_ev);

        drv.axis = s_axis;

        drv.init();

        clk = 0;
        rst = 1;
        
        #(16*`CLK_PERIOD) rst = 0;

        fork
            gen.run("pkts_in.txt",  gen2drv_mbx, drv2gen_receive_ev, gen2drv_finish_ev);
            // gen.run("pkts_out.txt", gen2scb_mbx, scb2gen_receive_ev, gen2scb_finish_ev);
            drv.run();
        join

        @(posedge clk) $display("Test completed");
        $finish();
    end

endmodule
