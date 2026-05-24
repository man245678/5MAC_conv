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

    localparam IDLE          = 4'd0;
    localparam ISSUE_FILTER  = 4'd1;
    localparam WAIT_FILTER   = 4'd2;
    localparam STORE_FILTER  = 4'd3;
    localparam ISSUE_IMAGE   = 4'd4;
    localparam WAIT_IMAGE    = 4'd5;
    localparam STORE_IMAGE   = 4'd6;
    localparam CLEAR_PSUM    = 4'd7;
    localparam COMPUTE       = 4'd8;
    localparam WRITE_FEATURE = 4'd9;
    localparam DONE          = 4'd10;

    reg [3:0] cur_state, next_state;

    reg [6:0] cur_filter_idx, next_filter_idx;
    reg [6:0] cur_load_row, next_load_row;
    reg [8:0] cur_load_idx, next_load_idx;
    reg [4:0] cur_feature_y, next_feature_y;
    reg [4:0] cur_compute_x, next_compute_x;
    reg [2:0] cur_kernel_row, next_kernel_row;
    reg [1:0] cur_channel, next_channel;
    reg [4:0] cur_clear_idx, next_clear_idx;
    reg [4:0] cur_write_idx, next_write_idx;

    reg signed [BITWIDTH-1:0] row_buf0 [0:3*IMAGE_WIDTH-1];
    reg signed [BITWIDTH-1:0] row_buf1 [0:3*IMAGE_WIDTH-1];
    reg signed [BITWIDTH-1:0] row_buf2 [0:3*IMAGE_WIDTH-1];
    reg signed [BITWIDTH-1:0] row_buf3 [0:3*IMAGE_WIDTH-1];
    reg signed [BITWIDTH-1:0] row_buf4 [0:3*IMAGE_WIDTH-1];
    reg signed [BITWIDTH-1:0] filter_buf [0:3*FILTER_WIDTH*FILTER_WIDTH-1];
    reg signed [2*BITWIDTH-1:0] psum [0:FEATURE_WIDTH-1];

    wire [1:0] load_channel = (cur_load_idx < IMAGE_WIDTH) ? 0 :
                              ((cur_load_idx < 2*IMAGE_WIDTH) ? 1 : 2);
    wire [6:0] load_col = (cur_load_idx < IMAGE_WIDTH) ? cur_load_idx[6:0] :
                          ((cur_load_idx < 2*IMAGE_WIDTH) ?
                           (cur_load_idx - IMAGE_WIDTH) :
                           (cur_load_idx - 2*IMAGE_WIDTH));
    wire [2:0] load_slot = cur_load_row % 5;

    wire [6:0] active_abs_row = cur_feature_y * 3 + cur_kernel_row;
    wire [2:0] active_slot = active_abs_row % 5;
    wire [6:0] base_col = cur_compute_x * 3;
    wire [8:0] active_base_col = cur_channel * IMAGE_WIDTH + base_col;

    wire [8:0] idx_col0 = active_base_col + 0;
    wire [8:0] idx_col1 = active_base_col + 1;
    wire [8:0] idx_col2 = active_base_col + 2;
    wire [8:0] idx_col3 = active_base_col + 3;
    wire [8:0] idx_col4 = active_base_col + 4;

    wire signed [BITWIDTH-1:0] ifmap1 = (active_slot == 0) ? row_buf0[idx_col0] : (active_slot == 1) ? row_buf1[idx_col0] : (active_slot == 2) ? row_buf2[idx_col0] : (active_slot == 3) ? row_buf3[idx_col0] : row_buf4[idx_col0];
    wire signed [BITWIDTH-1:0] ifmap2 = (active_slot == 0) ? row_buf0[idx_col1] : (active_slot == 1) ? row_buf1[idx_col1] : (active_slot == 2) ? row_buf2[idx_col1] : (active_slot == 3) ? row_buf3[idx_col1] : row_buf4[idx_col1];
    wire signed [BITWIDTH-1:0] ifmap3 = (active_slot == 0) ? row_buf0[idx_col2] : (active_slot == 1) ? row_buf1[idx_col2] : (active_slot == 2) ? row_buf2[idx_col2] : (active_slot == 3) ? row_buf3[idx_col2] : row_buf4[idx_col2];
    wire signed [BITWIDTH-1:0] ifmap4 = (active_slot == 0) ? row_buf0[idx_col3] : (active_slot == 1) ? row_buf1[idx_col3] : (active_slot == 2) ? row_buf2[idx_col3] : (active_slot == 3) ? row_buf3[idx_col3] : row_buf4[idx_col3];
    wire signed [BITWIDTH-1:0] ifmap5 = (active_slot == 0) ? row_buf0[idx_col4] : (active_slot == 1) ? row_buf1[idx_col4] : (active_slot == 2) ? row_buf2[idx_col4] : (active_slot == 3) ? row_buf3[idx_col4] : row_buf4[idx_col4];

    wire [6:0] filter_base = cur_channel * FILTER_WIDTH * FILTER_WIDTH +
                             cur_kernel_row * FILTER_WIDTH;
    wire signed [BITWIDTH-1:0] filter1  = filter_buf[filter_base + 0];
    wire signed [BITWIDTH-1:0] filter2  = filter_buf[filter_base + 1];
    wire signed [BITWIDTH-1:0] filter3  = filter_buf[filter_base + 2];
    wire signed [BITWIDTH-1:0] filter4  = filter_buf[filter_base + 3];
    wire signed [BITWIDTH-1:0] filter5  = filter_buf[filter_base + 4];

    wire signed [2*BITWIDTH-1:0] mac_result;

    assign IMAGE_RAM_EN = (cur_state == ISSUE_IMAGE);
    assign FILTER_RAM_EN = (cur_state == ISSUE_FILTER);
    assign FEATURE_RAM_EN = (cur_state == WRITE_FEATURE);
    assign FEATURE_RAM_WEN = (cur_state == WRITE_FEATURE);
    assign IMAGE_RAM_ADDRESS = load_channel * IMAGE_WIDTH * IMAGE_WIDTH +
                               cur_load_row * IMAGE_WIDTH + load_col;
    assign FILTER_RAM_ADDRESS = cur_filter_idx;
    assign FEATURE_RAM_ADDRESS = cur_write_idx + cur_feature_y * FEATURE_WIDTH;
    assign FEATURE_RAM_DOUT = psum[cur_write_idx];
    assign eoc = (cur_state == DONE);

    MAC #(
        .DATA_BW(BITWIDTH)
    ) u_MAC (
        .CLK(clk),
        .RSTN(resetn),
        .EN(cur_state == COMPUTE),
        .IFMAP_DATA_IN1(ifmap1),
        .IFMAP_DATA_IN2(ifmap2),
        .IFMAP_DATA_IN3(ifmap3),
        .IFMAP_DATA_IN4(ifmap4),
        .IFMAP_DATA_IN5(ifmap5),
        .FILTER_DATA_IN1(filter1),
        .FILTER_DATA_IN2(filter2),
        .FILTER_DATA_IN3(filter3),
        .FILTER_DATA_IN4(filter4),
        .FILTER_DATA_IN5(filter5),
        .MUL_DATA_OUT(mac_result)
    );

    always @ (posedge clk or negedge resetn) begin
        if(!resetn) begin
            cur_state <= IDLE;
            cur_filter_idx <= 0;
            cur_load_row <= 0;
            cur_load_idx <= 0;
            cur_feature_y <= 0;
            cur_compute_x <= 0;
            cur_kernel_row <= 0;
            cur_channel <= 0;
            cur_clear_idx <= 0;
            cur_write_idx <= 0;
        end
        else begin
            cur_state <= next_state;
            cur_filter_idx <= next_filter_idx;
            cur_load_row <= next_load_row;
            cur_load_idx <= next_load_idx;
            cur_feature_y <= next_feature_y;
            cur_compute_x <= next_compute_x;
            cur_kernel_row <= next_kernel_row;
            cur_channel <= next_channel;
            cur_clear_idx <= next_clear_idx;
            cur_write_idx <= next_write_idx;
        end
    end

    always @ (negedge clk or negedge resetn) begin
        if(!resetn) begin
        end
        else if((cur_state == WAIT_FILTER || cur_state == STORE_FILTER) && FILTER_RAM_DATA_VAL) begin
            filter_buf[cur_filter_idx] <= FILTER_RAM_DIN;
        end
        else if((cur_state == WAIT_IMAGE || cur_state == STORE_IMAGE) && IMAGE_RAM_DATA_VAL) begin
            case(load_slot)
                3'd0: row_buf0[cur_load_idx] <= IMAGE_RAM_DIN;
                3'd1: row_buf1[cur_load_idx] <= IMAGE_RAM_DIN;
                3'd2: row_buf2[cur_load_idx] <= IMAGE_RAM_DIN;
                3'd3: row_buf3[cur_load_idx] <= IMAGE_RAM_DIN;
                3'd4: row_buf4[cur_load_idx] <= IMAGE_RAM_DIN;
            endcase
        end
    end

    always @ (posedge clk or negedge resetn) begin
        if(!resetn) begin
        end
        else begin
            if(cur_state == CLEAR_PSUM)
                psum[cur_clear_idx] <= 0;
            else if(cur_state == COMPUTE)
                psum[cur_compute_x] <= psum[cur_compute_x] + mac_result;
        end
    end

    always @ (*) begin
        next_state = cur_state;
        next_filter_idx = cur_filter_idx;
        next_load_row = cur_load_row;
        next_load_idx = cur_load_idx;
        next_feature_y = cur_feature_y;
        next_compute_x = cur_compute_x;
        next_kernel_row = cur_kernel_row;
        next_channel = cur_channel;
        next_clear_idx = cur_clear_idx;
        next_write_idx = cur_write_idx;

        case(cur_state)
            IDLE: begin
                next_state = ISSUE_FILTER;
                next_filter_idx = 0;
                next_load_row = 0;
                next_load_idx = 0;
                next_feature_y = 0;
                next_compute_x = 0;
                next_kernel_row = 0;
                next_channel = 0;
                next_clear_idx = 0;
                next_write_idx = 0;
            end
            ISSUE_FILTER: begin
                next_state = WAIT_FILTER;
            end
            WAIT_FILTER: begin
                if(FILTER_RAM_DATA_VAL)
                    next_state = STORE_FILTER;
            end
            STORE_FILTER: begin
                if(cur_filter_idx == 74) begin
                    next_state = ISSUE_IMAGE;
                    next_load_row = 0;
                    next_load_idx = 0;
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
                if(IMAGE_RAM_DATA_VAL)
                    next_state = STORE_IMAGE;
            end
            STORE_IMAGE: begin
                if(cur_load_idx == 3*IMAGE_WIDTH-1) begin
                    next_load_idx = 0;
                    if((cur_feature_y == 0 && cur_load_row == 4) ||
                       (cur_feature_y != 0 && cur_load_row == cur_feature_y*3 + 4)) begin
                        next_state = CLEAR_PSUM;
                        next_clear_idx = 0;
                    end
                    else begin
                        next_load_row = cur_load_row + 1;
                        next_state = ISSUE_IMAGE;
                    end
                end
                else begin
                    next_load_idx = cur_load_idx + 1;
                    next_state = ISSUE_IMAGE;
                end
            end
            CLEAR_PSUM: begin
                if(cur_clear_idx == FEATURE_WIDTH-1) begin
                    next_state = COMPUTE;
                    next_compute_x = 0;
                    next_kernel_row = 0;
                    next_channel = 0;
                end
                else begin
                    next_clear_idx = cur_clear_idx + 1;
                end
            end
            COMPUTE: begin
                if(cur_channel != 2) begin
                    next_channel = cur_channel + 1;
                end
                else if(cur_kernel_row != 4) begin
                    next_channel = 0;
                    next_kernel_row = cur_kernel_row + 1;
                end
                else if(cur_compute_x == FEATURE_WIDTH-1) begin
                    next_channel = 0;
                    next_kernel_row = 0;
                    next_compute_x = 0;
                    next_state = WRITE_FEATURE;
                    next_write_idx = 0;
                end
                else begin
                    next_channel = 0;
                    next_kernel_row = 0;
                    next_compute_x = cur_compute_x + 1;
                end
            end
            WRITE_FEATURE: begin
                if(cur_write_idx == FEATURE_WIDTH-1) begin
                    if(cur_feature_y == FEATURE_WIDTH-1) begin
                        next_state = DONE;
                    end
                    else begin
                        next_feature_y = cur_feature_y + 1;
                        next_load_row = (cur_feature_y + 1) * 3 + 2;
                        next_load_idx = 0;
                        next_state = ISSUE_IMAGE;
                    end
                end
                else begin
                    next_write_idx = cur_write_idx + 1;
                end
            end
            DONE: begin
                next_state = DONE;
            end
        endcase
    end

endmodule
