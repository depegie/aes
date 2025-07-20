`ifndef GENERATOR_SVH
`define GENERATOR_SVH

import tb_pkg::*;

class generator;
    task run(string filename, ref mailbox #(packet_t) mbx, ref event receive_ev, ref event finish_ev);
        int         file     = $fopen(filename, "r");
        string      line     = "";
        logic [7:0] pkt_byte = 8'h0;
        packet_t    packet;

        packet.id   = 0;
        packet.data = '{};

        while ($fgets(line, file)) begin
            for (int b=0; b<line.len()/2; b++) begin
                $sscanf(line.substr(2*b, 2*b+1), "%h", pkt_byte);
                packet.data.push_back(pkt_byte);
            end

            @(receive_ev);
            mbx.put(packet);
            
            packet.id++;
            packet.data = '{};
        end

        ->finish_ev;
    endtask
endclass

`endif
