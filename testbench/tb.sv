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

    axis_if #(`S_AXIS_WIDTH) drv_axis(clk);
    axis_if #(`M_AXIS_WIDTH) mon_axis(clk);

    mailbox #(packet_t) gen2drv_mbx;
    mailbox #(packet_t) gen2scb_mbx;
    mailbox #(packet_t) mon2scb_mbx;

    event drv2gen_receive_ev;
    event gen2drv_finish_ev;
    event scb2gen_receive_ev;
    event gen2scb_finish_ev;
    event mon2scb_receive_ev;
    event scb2mon_finish_ev;

// `ifdef AES128_ECB_ITER_BEHAV
//     aes128_ecb_iter_behav
// `elsif AES128_ECB_COMB_BEHAV
//     aes128_ecb_comb_behav
// `elsif AES128_ECB_PIPE_BEHAV
//     aes128_ecb_pipe_behav
// `elsif AES256_ECB_PIPE_BEHAV
//     aes256_ecb_pipe_behav
// `elsif AES256_CTR_PIPE_BEHAV
//     aes256_ctr_pipe_behav
// `elsif AES256_CTR_PIPE_GATE
//     aes256_ctr_pipe_gate
// `endif
    aes256_cbc_iter
    #(
        .S_AXIS_WIDTH ( `S_AXIS_WIDTH ),
        .M_AXIS_WIDTH ( `M_AXIS_WIDTH )
    ) dut (
        .Clk    ( clk      ),
        .Rst    ( rst      ),
        .S_axis ( drv_axis ),
        .M_axis ( mon_axis )
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

        drv.axis = drv_axis;
        mon.axis = mon_axis;

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

        @(posedge clk) $display("\nTEST COMPLETED.");
        $finish();
    end

endmodule
