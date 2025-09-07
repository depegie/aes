`ifndef GENERATOR_SVH
`define GENERATOR_SVH

import tb_pkg::*;

class generator;
    task run(string filename,
             ref mailbox #(packet_t) mbx,
             ref event receive_ev,
             ref event finish_ev);
             
        int         file     = $fopen(filename, "r");
        string      line     = "";
        logic       user     = 1'b0;
        string      data     = "";
        logic [7:0] data_byte = 8'h0;
        packet_t    packet;

        packet.id   = 0;
        packet.data = '{};

        while ($fgets(line, file)) begin
            $sscanf(line.getc(0), "%b", user);
            packet.user = user;

            data = line.substr(2, line.len()-1);

            for (int b=0; b<data.len()/2; b++) begin
                $sscanf(data.substr(2*b, 2*b+1), "%h", data_byte);
                packet.data.push_back(data_byte);
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
