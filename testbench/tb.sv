`timescale 1ns/1ps

`include "generator.svh"
`include "driver.svh"
`include "monitor.svh"
`include "scoreboard.svh"

module tb;
    int CLK_PERIOD = 5;

    bit clk;
    bit rst;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    axis_if #(`S_AXIS_TDATA_WIDTH) s_axis(clk);
    axis_if #(`M_AXIS_TDATA_WIDTH) m_axis(clk);

    mailbox #(packet_t) gen2drv_mbx;
    mailbox #(packet_t) gen2scb_mbx;
    mailbox #(packet_t) mon2scb_mbx;

    event drv2gen_receive_ev;
    event gen2drv_finish_ev;
    event scb2gen_receive_ev;
    event gen2scb_finish_ev;
    event mon2scb_receive_ev;
    event scb2mon_finish_ev;

    dummy dut (
        .Clk    ( clk ),
        .Rst    ( rst ),
        .S_axis ( s_axis ),
        .M_axis ( m_axis )
    );

    always #(CLK_PERIOD/2) clk = !clk;

    initial begin
        gen2drv_mbx = new();
        gen2scb_mbx = new();
        mon2scb_mbx = new();

        gen = new();
        drv = new(gen2drv_mbx, drv2gen_receive_ev, gen2drv_finish_ev);
        mon = new(mon2scb_mbx, mon2scb_receive_ev, scb2mon_finish_ev);
        scb = new(gen2scb_mbx, mon2scb_mbx,
                  scb2gen_receive_ev, mon2scb_receive_ev,
                  gen2scb_finish_ev, scb2mon_finish_ev);

        drv.axis = s_axis;
        mon.axis = m_axis;

        drv.init();
        mon.init();

        clk = 0;
        rst = 1;
        
        #(16*CLK_PERIOD) rst = 0;

        fork
            gen.run("pkts_in.txt",  gen2drv_mbx, drv2gen_receive_ev, gen2drv_finish_ev);
            gen.run("pkts_out.txt", gen2scb_mbx, scb2gen_receive_ev, gen2scb_finish_ev);
            drv.run();
            mon.run();
            scb.run();
        join

        @(posedge clk) $display("Test completed");
        $finish();
    end

endmodule
