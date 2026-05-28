`timescale 1ns / 1ps

module itch_decoder_s(
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_dec, //from header parser's data bus
    input logic valid_S,        //from header parser's gate signal
    
    output logic [15:0] stock_locate,
    output logic [15:0] tracking_number,
    output logic [47:0] timestamp,
    output logic [7:0] event_code,
    output logic decoded_valid   //1-cycle pulse on last byte
);

logic [3:0] byte_count;

assign decoded_valid = valid_S && (byte_count == 4'd11);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        byte_count <= 4'd0;
        stock_locate     <= 16'd0;
        tracking_number  <= 16'd0;
        timestamp        <= 48'd0;
        event_code       <= 8'd0;
    end else if (valid_S) begin
        byte_count <= byte_count + 4'd1;
        case (byte_count)
            4'd0:    $display("[%0t] decoder_s: type byte 0x%h ignored", $time, data_dec); // byte 0 is the type byte 'S' - IGNORE, no field to update
            4'd1, 4'd2:            
                stock_locate    <= {stock_locate[7:0],    data_dec};
            4'd3, 4'd4:            
                tracking_number <= {tracking_number[7:0], data_dec};
            4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10:     
                timestamp       <= {timestamp[39:0],      data_dec};
            4'd11:                 
                event_code      <= data_dec;
            default: $display("[%0t] decoder_s: unexpected byte_count=%0d", $time, byte_count); // no-op
        endcase
    end else begin
        byte_count <= 4'd0;
    end
end
endmodule