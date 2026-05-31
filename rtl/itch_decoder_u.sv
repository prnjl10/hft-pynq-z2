`timescale 1ns / 1ps

module itch_decoder_u(
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_dec,
    input logic valid_U,
    
    output logic [15:0] stock_locate,
    output logic [15:0] tracking_number,
    output logic [47:0] timestamp,
    output logic [63:0] original_order_ref,
    output logic [63:0] new_order_ref,
    output logic [31:0] shares,
    output logic [31:0] price,
    output logic decoded_valid
);

logic [5:0] byte_count;
logic decoded_valid_reg;

// BUG: assign decoded_valid = valid_U && (byte_count == 5'd18); [also wrong width 5'd vs 6'd]
// WHY IT WAS WRONG: decoded_valid fired combinationally in the same cycle the last price
// byte arrived. Non-blocking assignments (<=) don't update until END of that clock edge,
// so TB sampled OLD price - missing the final byte (0xA0). Also byte_count was 5-bit
// which can't hold values > 31, causing wrong comparisons for a 35-byte message.
// FIX: Use a registered decoded_valid_reg inside always_ff. It gets set when byte_count==34,
// and pulses HIGH on the NEXT cycle - by which time price is fully latched.
assign decoded_valid = decoded_valid_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        byte_count         <= 6'd0;
        decoded_valid_reg  <= 1'b0;
        stock_locate       <= 16'd0;
        tracking_number    <= 16'd0;
        timestamp          <= 48'd0;
        original_order_ref <= 64'd0;
        new_order_ref      <= 64'd0;
        shares             <= 32'd0;
        price              <= 32'd0;
    end else if (valid_U) begin
        byte_count        <= byte_count + 6'd1;
        decoded_valid_reg <= (byte_count == 6'd34); // pulses cycle AFTER last byte is latched
        case (byte_count)
            6'd0: $display("[%0t] decoder_u: type byte 0x%h ignored", $time, data_dec);
            6'd1, 6'd2:   stock_locate       <= {stock_locate[7:0], data_dec};
            6'd3, 6'd4:   tracking_number    <= {tracking_number[7:0], data_dec};
            6'd5, 6'd6, 6'd7, 6'd8, 6'd9, 6'd10: timestamp <= {timestamp[39:0], data_dec};
            6'd11, 6'd12, 6'd13, 6'd14, 6'd15, 6'd16, 6'd17, 6'd18: original_order_ref <= {original_order_ref[55:0], data_dec};
            6'd19, 6'd20, 6'd21, 6'd22, 6'd23, 6'd24, 6'd25, 6'd26: new_order_ref <= {new_order_ref[55:0], data_dec};
            6'd27, 6'd28, 6'd29, 6'd30: shares <= {shares[23:0], data_dec};
            6'd31, 6'd32, 6'd33, 6'd34: price  <= {price[23:0], data_dec};
            default: $display("[%0t] decoder_u: unexpected byte_count=%0d", $time, byte_count);
        endcase
    end else begin
        byte_count        <= 6'd0;
        decoded_valid_reg <= 1'b0; // clear when no longer routing U bytes
    end
end
endmodule