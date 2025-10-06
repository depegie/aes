`timescale 1ns/1ps

`include "tb_conf.svh"
`include "generator.svh"
`include "driver.svh"
`include "monitor.svh"
`include "scoreboard.svh"

import tb_pkg::*;

module tb;
    bit clk;
    bit rst;

    generator gen;
    driver #(`S_AXIS_WIDTH, `S_AXIS_DELAY) drv;
    monitor #(`M_AXIS_WIDTH, `M_AXIS_DELAY) mon;
    scoreboard scb;

    axis_if #(`S_AXIS_WIDTH) s_axis(clk);
    axis_if #(`M_AXIS_WIDTH) m_axis(clk);

    mailbox #(packet_t) gen2drv_mbx;
    mailbox #(packet_t) gen2scb_mbx;
    mailbox #(packet_t) mon2scb_mbx;

    event drv2gen_receive_ev;
    event gen2drv_finish_ev;
    event scb2gen_receive_ev;
    event gen2scb_finish_ev;
    event mon2scb_receive_ev;
    event scb2mon_finish_ev;

`ifdef AES256_CBC_ITER
    aes256_cbc_iter
`elsif AES256_CBC_COMB
    aes256_cbc_comb
`elsif AES256_CTR_ITER
    aes256_ctr_iter
`elsif AES256_CTR_COMB
    aes256_ctr_comb
`elsif AES256_CTR_PIPE
    aes256_ctr_pipe
`endif
    #(
        .S_AXIS_WIDTH ( `S_AXIS_WIDTH ),
        .M_AXIS_WIDTH ( `M_AXIS_WIDTH )
    ) dut (
        .Clk           ( clk           ),
        .Rst           ( rst           ),
        .S_axis_tvalid ( s_axis.tvalid ),
        .S_axis_tready ( s_axis.tready ),
        .S_axis_tdata  ( s_axis.tdata  ),
        .S_axis_tkeep  ( s_axis.tkeep  ),
        .S_axis_tlast  ( s_axis.tlast  ),
        .S_axis_tuser  ( s_axis.tuser  ),
        .M_axis_tvalid ( m_axis.tvalid ),
        .M_axis_tready ( m_axis.tready ),
        .M_axis_tdata  ( m_axis.tdata  ),
        .M_axis_tkeep  ( m_axis.tkeep  ),
        .M_axis_tlast  ( m_axis.tlast  )
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
        
        #(256*CLK_PERIOD) rst = 0;
        #(256*CLK_PERIOD);

        fork
            gen.run("pkts_in.txt",  gen2drv_mbx, drv2gen_receive_ev, gen2drv_finish_ev);
            gen.run("pkts_out.txt", gen2scb_mbx, scb2gen_receive_ev, gen2scb_finish_ev);
            drv.run();
            mon.run();
            scb.run();
        join

        @(posedge clk) $display("\nTEST COMPLETED.");
        $finish();
    end

endmodule
