`timescale 1ns/1ps

module itch_top (
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_in,
    input logic valid_in,
    
    // S decoder (5 outputs)
    output logic [15:0] s_stock_locate,
    output logic [15:0] s_tracking_number,
    output logic [47:0] s_timestamp,
    output logic [7:0]  s_event_code,
    output logic        s_decoded_valid,

    // A decoder (9 outputs)
    output logic [15:0] a_stock_locate,
    output logic [15:0] a_tracking_number,
    output logic [47:0] a_timestamp,
    output logic [63:0] a_order_ref_num,
    output logic [7:0]  a_buy_sell,
    output logic [31:0] a_shares,
    output logic [63:0] a_stock,
    output logic [31:0] a_price,
    output logic        a_decoded_valid,

    // F decoder (10 outputs)
    output logic [15:0] f_stock_locate,
    output logic [15:0] f_tracking_number,
    output logic [47:0] f_timestamp,
    output logic [63:0] f_order_ref_num,
    output logic [7:0]  f_buy_sell,
    output logic [31:0] f_shares,
    output logic [63:0] f_stock,
    output logic [31:0] f_price,
    output logic [31:0] f_attribution,
    output logic        f_decoded_valid,

    // E decoder (7 outputs)
    output logic [15:0] e_stock_locate,
    output logic [15:0] e_tracking_number,
    output logic [47:0] e_timestamp,
    output logic [63:0] e_order_ref_num,
    output logic [31:0] e_executed_shares,
    output logic [63:0] e_match_number,
    output logic        e_decoded_valid,

    // X decoder (6 outputs)
    output logic [15:0] x_stock_locate,
    output logic [15:0] x_tracking_number,
    output logic [47:0] x_timestamp,
    output logic [63:0] x_order_ref_num,
    output logic [31:0] x_cancelled_shares,
    output logic        x_decoded_valid,

    // D decoder (5 outputs)
    output logic [15:0] d_stock_locate,
    output logic [15:0] d_tracking_number,
    output logic [47:0] d_timestamp,
    output logic [63:0] d_order_ref_num,
    output logic        d_decoded_valid,

    // U decoder (8 outputs)
    output logic [15:0] u_stock_locate,
    output logic [15:0] u_tracking_number,
    output logic [47:0] u_timestamp,
    output logic [63:0] u_original_order_ref,
    output logic [63:0] u_new_order_ref,
    output logic [31:0] u_shares,
    output logic [31:0] u_price,
    output logic        u_decoded_valid,

    // P decoder (10 outputs)
    output logic [15:0] p_stock_locate,
    output logic [15:0] p_tracking_number,
    output logic [47:0] p_timestamp,
    output logic [63:0] p_order_ref_num,
    output logic [7:0]  p_buy_sell,
    output logic [31:0] p_shares,
    output logic [63:0] p_stock,
    output logic [31:0] p_price,
    output logic [63:0] p_match_number,
    output logic        p_decoded_valid 
    );

    //signals connecting Length Predictor and Head Parser:
    logic [7:0] lp_data_out;        //(byte stream from Length Pedictor(output) into Header Parser's data_in (input)
    logic lp_valid_out;             // Length Predictor's valid signal
    logic lp_body_valid;            // Length Predictor's body valid signal
    
    //signals connecting Head Parser to 8 decoders:
    logic [7:0] hp_data_dec;        //shared data bus to all 8 decoders: S,A,F,E,X,D,U,P
    //8 individual valid signals for each decoder
    logic hp_valid_S, hp_valid_A, hp_valid_F, hp_valid_E, hp_valid_X, hp_valid_D, hp_valid_U, hp_valid_P;
    
    
    //Instantiations
    itch_length_predictor u_lp (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (data_in),
    .valid_in   (valid_in),
    .data_out   (lp_data_out),
    .valid_out  (lp_valid_out),
    .body_valid (lp_body_valid)
    );
    
     /*
    HP's inputs:

    data_in ? gets data from LP's output ? connects to lp_data_out
    valid_in ? gets valid from LP ? connects to lp_valid_out
    body_valid_in ? gets body_valid from LP ? connects to lp_body_valid
    */

    itch_header_parser u_hp (
    .clk            (clk),
    .rst_n          (rst_n),
    .data_in        (lp_data_out),
    .valid_in       (lp_valid_out),
    .body_valid_in  (lp_body_valid),
    .data_dec       (hp_data_dec),
    .valid_S        (hp_valid_S),
    .valid_A        (hp_valid_A),
    .valid_F        (hp_valid_F),
    .valid_E        (hp_valid_E),
    .valid_X        (hp_valid_X),
    .valid_D        (hp_valid_D),
    .valid_U        (hp_valid_U),
    .valid_P        (hp_valid_P)
    );
    
    //decoder instantiations
    itch_decoder_s u_dec_s (              // For decoder_S
    .clk             (clk),
    .rst_n           (rst_n),
    .data_dec        (hp_data_dec),       // shared bus from HP
    .valid_S         (hp_valid_S),        // gate signal from HP
    .stock_locate    (s_stock_locate),    
    .tracking_number (s_tracking_number),
    .timestamp       (s_timestamp),
    .event_code      (s_event_code),
    .decoded_valid   (s_decoded_valid)    // top-level output
    );
    
    itch_decoder_a u_dec_a (              // For decoder_A
    .clk             (clk),
    .rst_n           (rst_n),
    .data_dec        (hp_data_dec),       // shared bus from HP
    .valid_A         (hp_valid_A),        // gate signal from HP
    .stock_locate    (a_stock_locate),    // top-level output
    .tracking_number (a_tracking_number),
    .timestamp       (a_timestamp),
    .order_ref_num   (a_order_ref_num),
    .buy_sell        (a_buy_sell),
    .shares          (a_shares),
    .stock           (a_stock),
    .price           (a_price),
    .decoded_valid   (a_decoded_valid)
    );
    
    itch_decoder_f u_dec_f (              // For decoder_F
    .clk             (clk),
    .rst_n           (rst_n),
    .data_dec        (hp_data_dec),       // shared bus from HP
    .valid_F         (hp_valid_F),        // gate signal from HP
    .stock_locate    (f_stock_locate),    
    .tracking_number (f_tracking_number),
    .timestamp       (f_timestamp),
    .order_ref_num   (f_order_ref_num),
    .buy_sell        (f_buy_sell),
    .shares          (f_shares),
    .stock           (f_stock),
    .price           (f_price),
    .attribution     (f_attribution),
    .decoded_valid   (f_decoded_valid)     // top-level output
    );

    itch_decoder_e u_dec_e (              // For decoder_E
    .clk             (clk),
    .rst_n           (rst_n),
    .data_dec        (hp_data_dec),       // shared bus from HP
    .valid_E         (hp_valid_E),        // gate signal from HP
    .stock_locate    (e_stock_locate),    
    .tracking_number (e_tracking_number),
    .timestamp       (e_timestamp),
    .order_ref_num   (e_order_ref_num),
    .executed_shares (e_executed_shares),
    .match_number    (e_match_number),
    .decoded_valid   (e_decoded_valid)     // top-level output
    );
    
    itch_decoder_x u_dec_x (              // For decoder_X
    .clk                (clk),
    .rst_n              (rst_n),
    .data_dec           (hp_data_dec),       // shared bus from HP
    .valid_X            (hp_valid_X),        // gate signal from HP
    .stock_locate       (x_stock_locate),    
    .tracking_number    (x_tracking_number),
    .timestamp          (x_timestamp),
    .order_ref_num      (x_order_ref_num),
    .cancelled_shares   (x_cancelled_shares),
    .decoded_valid      (x_decoded_valid)    // top-level output
    );

    
    itch_decoder_d u_dec_d (              // For decoder_D
    .clk             (clk),
    .rst_n           (rst_n),
    .data_dec        (hp_data_dec),       // shared bus from HP
    .valid_D         (hp_valid_D),        // gate signal from HP
    .stock_locate    (d_stock_locate),    
    .tracking_number (d_tracking_number),
    .timestamp       (d_timestamp),
    .order_ref_num   (d_order_ref_num),
    .decoded_valid   (d_decoded_valid)    // top-level output
    );
    
    /*
    output logic [15:0] stock_locate,
    output logic [15:0] tracking_number,
    output logic [47:0] timestamp,
    output logic [63:0] order_ref_num,
    output logic decoded_valid   //1-cycle pulse on last byte
    */
    
    itch_decoder_u u_dec_u (              // For decoder_U
    .clk                    (clk),
    .rst_n                  (rst_n),
    .data_dec               (hp_data_dec),       // shared bus from HP
    .valid_U                (hp_valid_U),        // gate signal from HP
    .stock_locate           (u_stock_locate),    
    .tracking_number        (u_tracking_number),
    .timestamp              (u_timestamp),
    .original_order_ref     (u_original_order_ref),
    .new_order_ref          (u_new_order_ref),
    .shares                 (u_shares),
    .price                  (u_price),
    .decoded_valid          (u_decoded_valid)    // top-level output
    );
    
    itch_decoder_p u_dec_p (                // For decoder_P
    .clk                (clk),
    .rst_n              (rst_n),
    .data_dec           (hp_data_dec),       // shared bus from HP
    .valid_P            (hp_valid_P),        // gate signal from HP
    .stock_locate       (p_stock_locate),    
    .tracking_number    (p_tracking_number),
    .timestamp          (p_timestamp),
    .order_ref_num      (p_order_ref_num),
    .buy_sell           (p_buy_sell),
    .shares             (p_shares),
    .stock              (p_stock),
    .price              (p_price),
    .match_number       (p_match_number),
    .decoded_valid      (p_decoded_valid)   // top-level output
    );

endmodule