`timescale 1ns / 1ps

module itch_decoder_e(
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_dec,
    input logic valid_E,
    
    output logic [15:0] stock_locate,
    output logic [15:0] tracking_number,
    output logic [47:0] timestamp,
    output logic [63:0] order_ref_num,
    output logic [31:0] executed_shares,
    output logic [63:0] match_number,
    output logic decoded_valid
);

logic [4:0] byte_count;
logic decoded_valid_reg;

// BUG: assign decoded_valid = valid_E && (byte_count == 5'd30);
// WHY IT WAS WRONG: decoded_valid fired combinationally in the same cycle the last
// match_number byte arrived. Non-blocking assignments (<=) don't update until END of
// that clock edge, so the TB monitor sampled OLD match_number - missing final byte (0x88).
// FIX: Use a registered decoded_valid_reg inside always_ff. It gets set when byte_count==30,
// and pulses HIGH on the NEXT cycle - by which time match_number is fully latched.
assign decoded_valid = decoded_valid_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        byte_count        <= 5'd0;
        decoded_valid_reg <= 1'b0;
        stock_locate      <= 16'd0;
        tracking_number   <= 16'd0;
        timestamp         <= 48'd0;
        order_ref_num     <= 64'd0;
        executed_shares   <= 32'd0;
        match_number      <= 64'd0;
    end else if (valid_E) begin
        byte_count        <= byte_count + 5'd1;
        decoded_valid_reg <= (byte_count == 5'd30); // pulses cycle AFTER last byte is latched
        case (byte_count)
            5'd0: $display("[%0t] decoder_e: type byte 0x%h ignored", $time, data_dec);
            5'd1, 5'd2:   stock_locate    <= {stock_locate[7:0], data_dec};
            5'd3, 5'd4:   tracking_number <= {tracking_number[7:0], data_dec};
            5'd5, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10: timestamp <= {timestamp[39:0], data_dec};
            5'd11, 5'd12, 5'd13, 5'd14, 5'd15, 5'd16, 5'd17, 5'd18: order_ref_num <= {order_ref_num[55:0], data_dec};
            5'd19, 5'd20, 5'd21, 5'd22: executed_shares <= {executed_shares[23:0], data_dec};
            5'd23, 5'd24, 5'd25, 5'd26, 5'd27, 5'd28, 5'd29, 5'd30: match_number <= {match_number[55:0], data_dec};
            default: $display("[%0t] decoder_e: unexpected byte_count=%0d", $time, byte_count);
        endcase
    end else begin
        byte_count        <= 5'd0;
        decoded_valid_reg <= 1'b0; // clear when no longer routing E bytes
    end
end
endmodule