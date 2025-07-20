`ifndef DRIVER_SVH
`define DRIVER_SVH

import tb_pkg::*;

class driver #(int TDATA_WIDTH=`S_AXIS_TDATA_WIDTH, int DELAY=`S_AXIS_DELAY);
    virtual axis_if #(TDATA_WIDTH) axis;
    mailbox #(packet_t)            mbx;
    event                          receive_ev;
    event                          finish_ev;

    function new(ref mailbox #(packet_t) mbx, ref event receive_ev, ref event finish_ev);
        this.mbx        = mbx;
        this.receive_ev = receive_ev;
        this.finish_ev  = finish_ev;
    endfunction

    function void init();
        this.axis.tvalid = 1'b0;
        this.axis.tdata  = 128'h0;
        this.axis.tkeep  = 16'b0;
        this.axis.tlast  = 1'b0;
    endfunction

    task run();
        bit         stimulus_done = 1'b0;
        int         bytes_in_trans_num = 0;
        logic [7:0] pkt_byte = 8'h0;
        packet_t    packet;

        @(this.axis.cb);
        fork
            forever begin
                if (stimulus_done) begin
                    break;
                end

                ->this.receive_ev;
                this.mbx.get(packet);

                while (packet.data.size() > 0) begin
                    bytes_in_trans_num = (packet.data.size() >= TDATA_WIDTH/8) ? TDATA_WIDTH/8 : packet.data.size();

                    repeat(DELAY) @(this.axis.cb);
                    this.axis.tlast = (packet.data.size() <= TDATA_WIDTH/8) ? 1'b1 : 1'b0;

                    for (int i=0; i<bytes_in_trans_num; i++) begin
                        this.axis.tkeep[i] = 1'b1;
                        this.axis.tdata[8*i +: 8] = packet.data.pop_front();
                    end

                    this.axis.tvalid = 1'b1;
                    @(this.axis.cb);
                    // $display("[Driver] (%0dns) S_axis_tready=%b", unsigned'($time), this.axis.cb.tready);
                    while (!this.axis.cb.tready) begin
                        @(this.axis.cb);
                        // $display("[Driver] (%0dns) S_axis_tready=%b", unsigned'($time), this.axis.cb.tready);
                    end

                    this.init();
                end
            end
            begin
                wait(this.finish_ev.triggered);
                stimulus_done = 1'b1;
            end
        join
    endtask
endclass

`endif
