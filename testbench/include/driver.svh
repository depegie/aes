`ifndef DRIVER_SVH
`define DRIVER_SVH

import tb_pkg::*;

class driver #(int TDATA_WIDTH, int TRANS_DELAY);
    virtual axis_if #(TDATA_WIDTH) axis;
    mailbox #(packet_t)            mbx;
    event                          receive_ev;
    event                          finish_ev;

    function new(ref mailbox #(packet_t) mbx,
                 ref event receive_ev,
                 ref event finish_ev);

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
        packet_t    packet_copy;

        @(this.axis.cb);
        fork
            forever begin
                if (stimulus_done) begin
                    break;
                end

                ->this.receive_ev;
                this.mbx.get(packet);
                packet_copy = packet;

                while (packet.data.size() > 0) begin
                    repeat(TRANS_DELAY) @(this.axis.cb);
                    
                    bytes_in_trans_num = (packet.data.size() >= TDATA_WIDTH/8) ? TDATA_WIDTH/8 : packet.data.size();

                    this.axis.tlast = (packet.data.size() <= TDATA_WIDTH/8) ? 1'b1 : 1'b0;

                    for (int b=0; b<bytes_in_trans_num; b++) begin
                        this.axis.tdata[8*b +: 8] = packet.data.pop_front();
                        this.axis.tkeep[b] = 1'b1;
                    end

                    this.axis.tvalid = 1'b1;
                    @(this.axis.cb);
                    while (!this.axis.cb.tready) begin
                        @(this.axis.cb);
                    end

                    this.init();
                end

                $write("[Driver]     Time: %8dns, id: %3d, data: ", unsigned'($time), packet_copy.id);
                foreach (packet_copy.data[i]) $write("%2h", packet_copy.data[i]);
                $write("\n");
            end
            begin
                wait(this.finish_ev.triggered);
                stimulus_done = 1'b1;
            end
        join
    endtask
endclass

`endif
