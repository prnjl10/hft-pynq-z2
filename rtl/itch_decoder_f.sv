`timescale 1ns / 1ps

module itch_decoder_f(

    input logic clk,
    input logic rst_n,
    input logic [7:0] data_dec, //from header parser's data bus
    input logic valid_F,        //from header parser's gate signal
    
    
    output logic [15:0] stock_locate,
    output logic [15:0] tracking_number,
    output logic [47:0] timestamp,
    output logic [63:0] order_ref_num,
    output logic [7:0]  buy_sell,
    output logic [31:0] shares,
    output logic [63:0] stock,
    output logic [31:0] price,
    output logic [31:0] attribution,
    output logic decoded_valid
);

logic [5:0] byte_count;

assign decoded_valid = valid_F && (byte_count == 6'd39);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        byte_count       <= 6'd0;
        stock_locate     <= 16'd0;
        tracking_number  <= 16'd0;
        timestamp        <= 48'd0;
        order_ref_num    <= 64'd0;
        buy_sell         <= 8'd0;
        shares           <= 32'd0;
        stock            <= 64'd0;
        price            <= 32'd0; 
        attribution      <= 32'd0;
    end else if (valid_F) begin
        byte_count <= byte_count + 6'd1;
        case (byte_count)
            6'd0:    $display("[%0t] decoder_f: type byte 0x%h ignored", $time, data_dec);
            6'd1, 6'd2:
                stock_locate <= {stock_locate[7:0], data_dec};
            6'd3, 6'd4:
                tracking_number <= {tracking_number[7:0], data_dec};
            6'd5, 6'd6, 6'd7, 6'd8, 6'd9, 6'd10:
                timestamp <= {timestamp[39:0], data_dec};
            6'd11, 6'd12, 6'd13, 6'd14, 6'd15, 6'd16, 6'd17, 6'd18:
                order_ref_num <= {order_ref_num [55:0], data_dec};
            6'd19:
                buy_sell <= data_dec;
            6'd20, 6'd21, 6'd22, 6'd23:
                shares <= {shares [23:0], data_dec};
            6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29, 6'd30, 6'd31:
                stock <= {stock [55:0], data_dec};
            6'd32, 6'd33, 6'd34, 6'd35:
                price <= {price [23:0], data_dec};
            6'd36, 6'd37, 6'd38, 6'd39:
                attribution <= {attribution [23:0], data_dec};
            default: $display("[%0t] decoder_f: unexpected byte_count=%0d", $time, byte_count);    
        endcase
        end else begin
            byte_count <= 6'd0;
    end
end

endmodule