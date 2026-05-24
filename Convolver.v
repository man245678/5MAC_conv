module Convolver
#(
    parameter ADDR_WIDTH    = 15,
    parameter IMAGE_WIDTH   = 98,
    parameter FILTER_WIDTH  = 5,
    parameter FEATURE_WIDTH = 32,
    parameter BITWIDTH      = 8
)(
    input wire clk,
    input wire resetn,
    input wire signed [BITWIDTH-1:0] IMAGE_RAM_DIN,
    input wire signed [BITWIDTH-1:0] FILTER_RAM_DIN,
    input wire signed [2*BITWIDTH-1:0] FEATURE_RAM_DIN,
    input wire IMAGE_RAM_DATA_VAL,
    input wire FILTER_RAM_DATA_VAL,
    input wire FEATURE_RAM_DATA_VAL,

    output wire IMAGE_RAM_EN,
    output wire FILTER_RAM_EN,
    output wire FEATURE_RAM_EN,
    output wire FEATURE_RAM_WEN,

    output wire [ADDR_WIDTH-1:0] IMAGE_RAM_ADDRESS,
    output wire [ADDR_WIDTH-1:0] FILTER_RAM_ADDRESS,
    output wire [ADDR_WIDTH-1:0] FEATURE_RAM_ADDRESS,

    output wire signed [2*BITWIDTH-1:0] FEATURE_RAM_DOUT,
    output wire eoc
);

    localparam IDLE             = 5'd0;
    localparam ISSUE_FILTER     = 5'd1;
    localparam WAIT_FILTER      = 5'd2;
    localparam STORE_FILTER     = 5'd3;
    localparam ISSUE_IMAGE      = 5'd4;
    localparam WAIT_IMAGE       = 5'd5;
    localparam PREP_OUTPUT      = 5'd6;
    localparam ISSUE_PSUM       = 5'd7;
    localparam WAIT_PSUM        = 5'd8;
    localparam LOAD_MAC         = 5'd9;
    localparam MUL_MAC          = 5'd10;
    localparam SUM_MAC          = 5'd11;
    localparam ACCUMULATE       = 5'd12;
    localparam WRITE_FEATURE    = 5'd13;
    localparam ADVANCE_PIXEL    = 5'd14;
    localparam DONE             = 5'd15;

    reg [4:0] cur_state, next_state;
    reg [6:0] cur_filter_idx, next_filter_idx;
    reg [1:0] cur_channel, next_channel;
    reg [6:0] cur_pixel_row, next_pixel_row;
    reg [6:0] cur_pixel_col, next_pixel_col;
    reg [1:0] cur_row_mod3, next_row_mod3;
    reg [1:0] cur_col_mod3, next_col_mod3;
    reg [4:0] cur_scan_x, next_scan_x;
    reg [4:0] cur_scan_y, next_scan_y;
    reg [4:0] cur_out_x, next_out_x;
    reg [4:0] cur_out_y, next_out_y;
    reg [1:0] cur_compute_channel, next_compute_channel;
    reg [2:0] cur_kernel_row, next_kernel_row;
    reg signed [2*BITWIDTH-1:0] cur_acc, next_acc;

    reg signed [BITWIDTH-1:0] filter_buf [0:3*FILTER_WIDTH*FILTER_WIDTH-1];

    reg signed [BITWIDTH-1:0] line0 [0:IMAGE_WIDTH-1];
    reg signed [BITWIDTH-1:0] line1 [0:IMAGE_WIDTH-1];
    reg signed [BITWIDTH-1:0] line2 [0:IMAGE_WIDTH-1];
    reg signed [BITWIDTH-1:0] line3 [0:IMAGE_WIDTH-1];

    reg signed [BITWIDTH-1:0] win00, win01, win02, win03, win04;
    reg signed [BITWIDTH-1:0] win10, win11, win12, win13, win14;
    reg signed [BITWIDTH-1:0] win20, win21, win22, win23, win24;
    reg signed [BITWIDTH-1:0] win30, win31, win32, win33, win34;
    reg signed [BITWIDTH-1:0] win40, win41, win42, win43, win44;

    reg signed [BITWIDTH-1:0] ifmap_pipe1;
    reg signed [BITWIDTH-1:0] ifmap_pipe2;
    reg signed [BITWIDTH-1:0] ifmap_pipe3;
    reg signed [BITWIDTH-1:0] ifmap_pipe4;
    reg signed [BITWIDTH-1:0] ifmap_pipe5;
    reg signed [BITWIDTH-1:0] filter_pipe1;
    reg signed [BITWIDTH-1:0] filter_pipe2;
    reg signed [BITWIDTH-1:0] filter_pipe3;
    reg signed [BITWIDTH-1:0] filter_pipe4;
    reg signed [BITWIDTH-1:0] filter_pipe5;

    integer i;

    wire valid_col = (cur_pixel_col >= 7'd4) && (cur_col_mod3 == 2'd1);
    wire valid_row = (cur_pixel_row >= 7'd4) && (cur_row_mod3 == 2'd1);
    wire valid_output_pixel = valid_col && valid_row;
    wire last_col = (cur_pixel_col == IMAGE_WIDTH-1);
    wire last_row = (cur_pixel_row == IMAGE_WIDTH-1);
    wire last_channel = (cur_channel == 2'd2);
    wire signed [2*BITWIDTH-1:0] mac_result;
    wire [6:0] filter_base = cur_compute_channel * FILTER_WIDTH * FILTER_WIDTH +
                             cur_kernel_row * FILTER_WIDTH;

    assign IMAGE_RAM_EN = (cur_state == ISSUE_IMAGE);
    assign FILTER_RAM_EN = (cur_state == ISSUE_FILTER);
    assign FEATURE_RAM_EN = (cur_state == ISSUE_PSUM) || (cur_state == WRITE_FEATURE);
    assign FEATURE_RAM_WEN = (cur_state == WRITE_FEATURE);

    assign IMAGE_RAM_ADDRESS = cur_channel * IMAGE_WIDTH * IMAGE_WIDTH +
                               cur_pixel_row * IMAGE_WIDTH + cur_pixel_col;
    assign FILTER_RAM_ADDRESS = cur_filter_idx;
    assign FEATURE_RAM_ADDRESS = cur_out_x + cur_out_y * FEATURE_WIDTH;
    assign FEATURE_RAM_DOUT = cur_acc;
    assign eoc = (cur_state == DONE);

    MAC #(
        .DATA_BW(BITWIDTH)
    ) u_MAC (
        .CLK(clk),
        .RSTN(resetn),
        .MUL(cur_state == MUL_MAC),
        .IFMAP_DATA_IN1(ifmap_pipe1),
        .IFMAP_DATA_IN2(ifmap_pipe2),
        .IFMAP_DATA_IN3(ifmap_pipe3),
        .IFMAP_DATA_IN4(ifmap_pipe4),
        .IFMAP_DATA_IN5(ifmap_pipe5),
        .FILTER_DATA_IN1(filter_pipe1),
        .FILTER_DATA_IN2(filter_pipe2),
        .FILTER_DATA_IN3(filter_pipe3),
        .FILTER_DATA_IN4(filter_pipe4),
        .FILTER_DATA_IN5(filter_pipe5),
        .MUL_DATA_OUT(mac_result)
    );

    always @ (posedge clk or negedge resetn) begin
        if(!resetn) begin
            cur_state <= IDLE;
            cur_filter_idx <= 0;
            cur_channel <= 0;
            cur_pixel_row <= 0;
            cur_pixel_col <= 0;
            cur_row_mod3 <= 0;
            cur_col_mod3 <= 0;
            cur_scan_x <= 0;
            cur_scan_y <= 0;
            cur_out_x <= 0;
            cur_out_y <= 0;
            cur_compute_channel <= 0;
            cur_kernel_row <= 0;
            cur_acc <= 0;
            win00 <= 0; win01 <= 0; win02 <= 0; win03 <= 0; win04 <= 0;
            win10 <= 0; win11 <= 0; win12 <= 0; win13 <= 0; win14 <= 0;
            win20 <= 0; win21 <= 0; win22 <= 0; win23 <= 0; win24 <= 0;
            win30 <= 0; win31 <= 0; win32 <= 0; win33 <= 0; win34 <= 0;
            win40 <= 0; win41 <= 0; win42 <= 0; win43 <= 0; win44 <= 0;
            ifmap_pipe1 <= 0;
            ifmap_pipe2 <= 0;
            ifmap_pipe3 <= 0;
            ifmap_pipe4 <= 0;
            ifmap_pipe5 <= 0;
            filter_pipe1 <= 0;
            filter_pipe2 <= 0;
            filter_pipe3 <= 0;
            filter_pipe4 <= 0;
            filter_pipe5 <= 0;
        end
        else begin
            cur_state <= next_state;
            cur_filter_idx <= next_filter_idx;
            cur_channel <= next_channel;
            cur_pixel_row <= next_pixel_row;
            cur_pixel_col <= next_pixel_col;
            cur_row_mod3 <= next_row_mod3;
            cur_col_mod3 <= next_col_mod3;
            cur_scan_x <= next_scan_x;
            cur_scan_y <= next_scan_y;
            cur_out_x <= next_out_x;
            cur_out_y <= next_out_y;
            cur_compute_channel <= next_compute_channel;
            cur_kernel_row <= next_kernel_row;
            cur_acc <= next_acc;

            if((cur_state == WAIT_FILTER) && FILTER_RAM_DATA_VAL) begin
                filter_buf[cur_filter_idx] <= FILTER_RAM_DIN;
            end

            if((cur_state == WAIT_IMAGE) && IMAGE_RAM_DATA_VAL) begin
                line0[0] <= IMAGE_RAM_DIN;
                line1[0] <= line0[IMAGE_WIDTH-1];
                line2[0] <= line1[IMAGE_WIDTH-1];
                line3[0] <= line2[IMAGE_WIDTH-1];
                for(i = 1; i < IMAGE_WIDTH; i = i + 1) begin
                    line0[i] <= line0[i-1];
                    line1[i] <= line1[i-1];
                    line2[i] <= line2[i-1];
                    line3[i] <= line3[i-1];
                end

                win00 <= win01; win01 <= win02; win02 <= win03; win03 <= win04; win04 <= line3[IMAGE_WIDTH-1];
                win10 <= win11; win11 <= win12; win12 <= win13; win13 <= win14; win14 <= line2[IMAGE_WIDTH-1];
                win20 <= win21; win21 <= win22; win22 <= win23; win23 <= win24; win24 <= line1[IMAGE_WIDTH-1];
                win30 <= win31; win31 <= win32; win32 <= win33; win33 <= win34; win34 <= line0[IMAGE_WIDTH-1];
                win40 <= win41; win41 <= win42; win42 <= win43; win43 <= win44; win44 <= IMAGE_RAM_DIN;
            end

            if(cur_state == LOAD_MAC) begin
                case(cur_kernel_row)
                    3'd0: begin
                        ifmap_pipe1 <= win00;
                        ifmap_pipe2 <= win01;
                        ifmap_pipe3 <= win02;
                        ifmap_pipe4 <= win03;
                        ifmap_pipe5 <= win04;
                    end
                    3'd1: begin
                        ifmap_pipe1 <= win10;
                        ifmap_pipe2 <= win11;
                        ifmap_pipe3 <= win12;
                        ifmap_pipe4 <= win13;
                        ifmap_pipe5 <= win14;
                    end
                    3'd2: begin
                        ifmap_pipe1 <= win20;
                        ifmap_pipe2 <= win21;
                        ifmap_pipe3 <= win22;
                        ifmap_pipe4 <= win23;
                        ifmap_pipe5 <= win24;
                    end
                    3'd3: begin
                        ifmap_pipe1 <= win30;
                        ifmap_pipe2 <= win31;
                        ifmap_pipe3 <= win32;
                        ifmap_pipe4 <= win33;
                        ifmap_pipe5 <= win34;
                    end
                    default: begin
                        ifmap_pipe1 <= win40;
                        ifmap_pipe2 <= win41;
                        ifmap_pipe3 <= win42;
                        ifmap_pipe4 <= win43;
                        ifmap_pipe5 <= win44;
                    end
                endcase
                filter_pipe1 <= filter_buf[filter_base];
                filter_pipe2 <= filter_buf[filter_base + 1];
                filter_pipe3 <= filter_buf[filter_base + 2];
                filter_pipe4 <= filter_buf[filter_base + 3];
                filter_pipe5 <= filter_buf[filter_base + 4];
            end
        end
    end

    always @ (*) begin
        next_state = cur_state;
        next_filter_idx = cur_filter_idx;
        next_channel = cur_channel;
        next_pixel_row = cur_pixel_row;
        next_pixel_col = cur_pixel_col;
        next_row_mod3 = cur_row_mod3;
        next_col_mod3 = cur_col_mod3;
        next_scan_x = cur_scan_x;
        next_scan_y = cur_scan_y;
        next_out_x = cur_out_x;
        next_out_y = cur_out_y;
        next_compute_channel = cur_compute_channel;
        next_kernel_row = cur_kernel_row;
        next_acc = cur_acc;

        case(cur_state)
            IDLE: begin
                next_state = ISSUE_FILTER;
                next_filter_idx = 0;
                next_channel = 0;
                next_pixel_row = 0;
                next_pixel_col = 0;
                next_row_mod3 = 0;
                next_col_mod3 = 0;
                next_scan_x = 0;
                next_scan_y = 0;
                next_out_x = 0;
                next_out_y = 0;
                next_compute_channel = 0;
                next_kernel_row = 0;
                next_acc = 0;
            end
            ISSUE_FILTER: begin
                next_state = WAIT_FILTER;
            end
            WAIT_FILTER: begin
                if(FILTER_RAM_DATA_VAL)
                    next_state = STORE_FILTER;
            end
            STORE_FILTER: begin
                if(cur_filter_idx == 7'd74) begin
                    next_state = ISSUE_IMAGE;
                    next_filter_idx = 0;
                end
                else begin
                    next_filter_idx = cur_filter_idx + 1;
                    next_state = ISSUE_FILTER;
                end
            end
            ISSUE_IMAGE: begin
                next_state = WAIT_IMAGE;
            end
            WAIT_IMAGE: begin
                if(IMAGE_RAM_DATA_VAL) begin
                    if(valid_output_pixel) begin
                        next_out_x = cur_scan_x;
                        next_out_y = cur_scan_y;
                        next_compute_channel = cur_channel;
                        next_kernel_row = 0;
                        next_state = PREP_OUTPUT;
                    end
                    else begin
                        next_state = ADVANCE_PIXEL;
                    end
                end
            end
            PREP_OUTPUT: begin
                if(cur_compute_channel == 0) begin
                    next_acc = 0;
                    next_state = LOAD_MAC;
                end
                else begin
                    next_state = ISSUE_PSUM;
                end
            end
            ISSUE_PSUM: begin
                next_state = WAIT_PSUM;
            end
            WAIT_PSUM: begin
                if(FEATURE_RAM_DATA_VAL) begin
                    next_acc = FEATURE_RAM_DIN;
                    next_state = LOAD_MAC;
                end
            end
            LOAD_MAC: begin
                next_state = MUL_MAC;
            end
            MUL_MAC: begin
                next_state = SUM_MAC;
            end
            SUM_MAC: begin
                next_state = ACCUMULATE;
            end
            ACCUMULATE: begin
                next_acc = cur_acc + mac_result;
                if(cur_kernel_row == 3'd4) begin
                    next_kernel_row = 0;
                    next_state = WRITE_FEATURE;
                end
                else begin
                    next_kernel_row = cur_kernel_row + 1;
                    next_state = LOAD_MAC;
                end
            end
            WRITE_FEATURE: begin
                next_state = ADVANCE_PIXEL;
            end
            ADVANCE_PIXEL: begin
                if(last_col && last_row && last_channel) begin
                    next_state = DONE;
                end
                else begin
                    next_state = ISSUE_IMAGE;
                end

                if(last_col) begin
                    next_pixel_col = 0;
                    next_col_mod3 = 0;
                    next_scan_x = 0;

                    if(last_row) begin
                        next_pixel_row = 0;
                        next_row_mod3 = 0;
                        next_scan_y = 0;
                        if(!last_channel)
                            next_channel = cur_channel + 1;
                    end
                    else begin
                        next_pixel_row = cur_pixel_row + 1;
                        next_row_mod3 = (cur_row_mod3 == 2'd2) ? 0 : cur_row_mod3 + 1;
                        if(valid_row)
                            next_scan_y = cur_scan_y + 1;
                    end
                end
                else begin
                    next_pixel_col = cur_pixel_col + 1;
                    next_col_mod3 = (cur_col_mod3 == 2'd2) ? 0 : cur_col_mod3 + 1;
                    if(valid_col)
                        next_scan_x = cur_scan_x + 1;
                end
            end
            DONE: begin
                next_state = DONE;
            end
        endcase
    end

endmodule
