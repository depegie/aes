`ifndef SCOREBOARD_SVH
`define SCOREBOARD_SVH

import tb_pkg::*;

class scoreboard;
    mailbox #(packet_t) gen_mbx;
    mailbox #(packet_t) mon_mbx;
    event gen_receive_ev;
    event gen_finish_ev;
    event mon_receive_ev;
    event mon_finish_ev;

    function new(ref mailbox #(packet_t) gen_mbx,
                 ref mailbox #(packet_t) mon_mbx,
                 ref event gen_receive_ev,
                 ref event mon_receive_ev,
                 ref event gen_finish_ev,
                 ref event mon_finish_ev);

        this.gen_mbx        = gen_mbx;
        this.mon_mbx        = mon_mbx;
        this.gen_receive_ev = gen_receive_ev;
        this.mon_receive_ev = mon_receive_ev;
        this.gen_finish_ev  = gen_finish_ev;
        this.mon_finish_ev  = mon_finish_ev;
    endfunction

    task run();
        bit      done = 1'b0;
        packet_t exp_packet;
        packet_t recv_packet;

        fork
            forever begin
                if (done) break;

                ->this.gen_receive_ev;
                this.gen_mbx.get(exp_packet);

                @(mon_receive_ev);
                this.mon_mbx.get(recv_packet);

                if (recv_packet.data != exp_packet.data) begin
                    $write("[Scoreboard] ERROR! time: %8dns, id: %3d, received data: ", unsigned'($time), recv_packet.id);
                    foreach (recv_packet.data[i]) $write("%2h", recv_packet.data[i]);
                    $write("\n                                               expected data: ");
                    foreach (exp_packet.data[i]) $write("%2h", exp_packet.data[i]);
                    $write("\n");
                    $finish;
                end
            end
            begin
                wait(this.gen_finish_ev.triggered);
                done = 1'b1;
            end
        join

        ->this.mon_finish_ev;
    endtask

endclass

`endif
