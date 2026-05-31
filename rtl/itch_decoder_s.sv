`timescale 1ns / 1ps

module itch_decoder_s(
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_dec,
    input logic valid_S,
    
    output logic [15:0] stock_locate,
    output logic [15:0] tracking_number,
    output logic [47:0] timestamp,
    output logic [7:0]  event_code,
    output logic decoded_valid
);

logic [3:0] byte_count;
logic decoded_valid_reg;

// BUG: assign decoded_valid = valid_S && (byte_count == 4'd11);
// WHY IT WAS WRONG: decoded_valid fired combinationally in the same cycle the last byte
// (event_code) arrived. Non-blocking assignments (<=) don't update until END of that clock
// edge, so the TB monitor sampled the OLD value of event_code - missing the final byte.
// FIX: Use a registered decoded_valid_reg inside always_ff. It gets set when byte_count==11,
// and pulses HIGH on the NEXT cycle - by which time event_code is fully latched.
assign decoded_valid = decoded_valid_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        byte_count        <= 4'd0;
        decoded_valid_reg <= 1'b0;
        stock_locate      <= 16'd0;
        tracking_number   <= 16'd0;
        timestamp         <= 48'd0;
        event_code        <= 8'd0;
    end else if (valid_S) begin
        byte_count        <= byte_count + 4'd1;
        decoded_valid_reg <= (byte_count == 4'd11); // pulses cycle AFTER last byte is latched
        case (byte_count)
            4'd0: $display("[%0t] decoder_s: type byte 0x%h ignored", $time, data_dec);
            4'd1, 4'd2:   stock_locate    <= {stock_locate[7:0], data_dec};
            4'd3, 4'd4:   tracking_number <= {tracking_number[7:0], data_dec};
            4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10: timestamp <= {timestamp[39:0], data_dec};
            4'd11:        event_code      <= data_dec;
            default: $display("[%0t] decoder_s: unexpected byte_count=%0d", $time, byte_count);
        endcase
    end else begin
        byte_count        <= 4'd0;
        decoded_valid_reg <= 1'b0; // clear when no longer routing S bytes
    end
end
endmodule