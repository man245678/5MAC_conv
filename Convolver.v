`define DECL_WIN(A0,A1,A2,A3,A4) \
    reg signed [BITWIDTH-1:0] A0 [0:3][0:7]; \
    reg signed [BITWIDTH-1:0] A1 [0:3][0:7]; \
    reg signed [BITWIDTH-1:0] A2 [0:3][0:7]; \
    reg signed [BITWIDTH-1:0] A3 [0:3][0:7]; \
    reg signed [BITWIDTH-1:0] A4 [0:3][0:7]

`define CAPTURE_SLOT(A00,A01,A02,A03,A04,A10,A11,A12,A13,A14,A20,A21,A22,A23,A24,BANK,IDX) begin \
    slot_ch0_1 <= A00[BANK][IDX]; \
    slot_ch0_2 <= A01[BANK][IDX]; \
    slot_ch0_3 <= A02[BANK][IDX]; \
    slot_ch0_4 <= A03[BANK][IDX]; \
    slot_ch0_5 <= A04[BANK][IDX]; \
    slot_ch1_1 <= A10[BANK][IDX]; \
    slot_ch1_2 <= A11[BANK][IDX]; \
    slot_ch1_3 <= A12[BANK][IDX]; \
    slot_ch1_4 <= A13[BANK][IDX]; \
    slot_ch1_5 <= A14[BANK][IDX]; \
    slot_ch2_1 <= A20[BANK][IDX]; \
    slot_ch2_2 <= A21[BANK][IDX]; \
    slot_ch2_3 <= A22[BANK][IDX]; \
    slot_ch2_4 <= A23[BANK][IDX]; \
    slot_ch2_5 <= A24[BANK][IDX]; \
end

`define CAPTURE_ACTIVE(BANK,IDX) begin \
    case(active_slot) \
        3'd0: `CAPTURE_SLOT(win0_ch0_0, win0_ch0_1, win0_ch0_2, win0_ch0_3, win0_ch0_4, win0_ch1_0, win0_ch1_1, win0_ch1_2, win0_ch1_3, win0_ch1_4, win0_ch2_0, win0_ch2_1, win0_ch2_2, win0_ch2_3, win0_ch2_4, BANK, IDX) \
        3'd1: `CAPTURE_SLOT(win1_ch0_0, win1_ch0_1, win1_ch0_2, win1_ch0_3, win1_ch0_4, win1_ch1_0, win1_ch1_1, win1_ch1_2, win1_ch1_3, win1_ch1_4, win1_ch2_0, win1_ch2_1, win1_ch2_2, win1_ch2_3, win1_ch2_4, BANK, IDX) \
        3'd2: `CAPTURE_SLOT(win2_ch0_0, win2_ch0_1, win2_ch0_2, win2_ch0_3, win2_ch0_4, win2_ch1_0, win2_ch1_1, win2_ch1_2, win2_ch1_3, win2_ch1_4, win2_ch2_0, win2_ch2_1, win2_ch2_2, win2_ch2_3, win2_ch2_4, BANK, IDX) \
        3'd3: `CAPTURE_SLOT(win3_ch0_0, win3_ch0_1, win3_ch0_2, win3_ch0_3, win3_ch0_4, win3_ch1_0, win3_ch1_1, win3_ch1_2, win3_ch1_3, win3_ch1_4, win3_ch2_0, win3_ch2_1, win3_ch2_2, win3_ch2_3, win3_ch2_4, BANK, IDX) \
        3'd4: `CAPTURE_SLOT(win4_ch0_0, win4_ch0_1, win4_ch0_2, win4_ch0_3, win4_ch0_4, win4_ch1_0, win4_ch1_1, win4_ch1_2, win4_ch1_3, win4_ch1_4, win4_ch2_0, win4_ch2_1, win4_ch2_2, win4_ch2_3, win4_ch2_4, BANK, IDX) \
    endcase \
end

`define STORE_WIN(A0,A1,A2,A3,A4) begin \
    case(load_col_mod) \
        2'd0: begin \
            if(load_fx < FEATURE_WIDTH) A0[load_bank][load_low] <= IMAGE_RAM_DIN; \
            if(load_fx != 0) A3[load_prev_bank][load_prev_low] <= IMAGE_RAM_DIN; \
        end \
        2'd1: begin \
            if(load_fx < FEATURE_WIDTH) A1[load_bank][load_low] <= IMAGE_RAM_DIN; \
            if(load_fx != 0) A4[load_prev_bank][load_prev_low] <= IMAGE_RAM_DIN; \
        end \
        default: begin \
            if(load_fx < FEATURE_WIDTH) A2[load_bank][load_low] <= IMAGE_RAM_DIN; \
        end \
    endcase \
end

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
    localparam CLEAR_ACC     = 4'd7;
    localparam READ_BANK0    = 5'd8;
    localparam READ_BANK1    = 5'd9;
    localparam READ_BANK2    = 5'd10;
    localparam READ_BANK3    = 5'd11;
    localparam READ_OPERAND  = 5'd12;
    localparam MUL_MAC       = 5'd13;
    localparam SUM_MAC       = 5'd14;
    localparam ACCUMULATE    = 5'd15;
    localparam WRITE_FEATURE = 5'd16;
    localparam DONE          = 5'd17;

    reg [4:0] cur_state, next_state;
    reg [6:0] cur_filter_idx, next_filter_idx;
    reg [6:0] cur_load_row, next_load_row;
    reg [8:0] cur_load_idx, next_load_idx;
    reg [5:0] cur_load_fx, next_load_fx;
    reg [1:0] cur_load_col_mod, next_load_col_mod;
    reg [4:0] cur_feature_x, next_feature_x;
    reg [4:0] cur_feature_y, next_feature_y;
    reg [2:0] cur_kernel_row, next_kernel_row;
    reg [1:0] cur_channel, next_channel;
    reg signed [2*BITWIDTH-1:0] cur_acc, next_acc;
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
    reg signed [BITWIDTH-1:0] slot_ch0_1;
    reg signed [BITWIDTH-1:0] slot_ch0_2;
    reg signed [BITWIDTH-1:0] slot_ch0_3;
    reg signed [BITWIDTH-1:0] slot_ch0_4;
    reg signed [BITWIDTH-1:0] slot_ch0_5;
    reg signed [BITWIDTH-1:0] slot_ch1_1;
    reg signed [BITWIDTH-1:0] slot_ch1_2;
    reg signed [BITWIDTH-1:0] slot_ch1_3;
    reg signed [BITWIDTH-1:0] slot_ch1_4;
    reg signed [BITWIDTH-1:0] slot_ch1_5;
    reg signed [BITWIDTH-1:0] slot_ch2_1;
    reg signed [BITWIDTH-1:0] slot_ch2_2;
    reg signed [BITWIDTH-1:0] slot_ch2_3;
    reg signed [BITWIDTH-1:0] slot_ch2_4;
    reg signed [BITWIDTH-1:0] slot_ch2_5;

    `DECL_WIN(win0_ch0_0, win0_ch0_1, win0_ch0_2, win0_ch0_3, win0_ch0_4);
    `DECL_WIN(win0_ch1_0, win0_ch1_1, win0_ch1_2, win0_ch1_3, win0_ch1_4);
    `DECL_WIN(win0_ch2_0, win0_ch2_1, win0_ch2_2, win0_ch2_3, win0_ch2_4);
    `DECL_WIN(win1_ch0_0, win1_ch0_1, win1_ch0_2, win1_ch0_3, win1_ch0_4);
    `DECL_WIN(win1_ch1_0, win1_ch1_1, win1_ch1_2, win1_ch1_3, win1_ch1_4);
    `DECL_WIN(win1_ch2_0, win1_ch2_1, win1_ch2_2, win1_ch2_3, win1_ch2_4);
    `DECL_WIN(win2_ch0_0, win2_ch0_1, win2_ch0_2, win2_ch0_3, win2_ch0_4);
    `DECL_WIN(win2_ch1_0, win2_ch1_1, win2_ch1_2, win2_ch1_3, win2_ch1_4);
    `DECL_WIN(win2_ch2_0, win2_ch2_1, win2_ch2_2, win2_ch2_3, win2_ch2_4);
    `DECL_WIN(win3_ch0_0, win3_ch0_1, win3_ch0_2, win3_ch0_3, win3_ch0_4);
    `DECL_WIN(win3_ch1_0, win3_ch1_1, win3_ch1_2, win3_ch1_3, win3_ch1_4);
    `DECL_WIN(win3_ch2_0, win3_ch2_1, win3_ch2_2, win3_ch2_3, win3_ch2_4);
    `DECL_WIN(win4_ch0_0, win4_ch0_1, win4_ch0_2, win4_ch0_3, win4_ch0_4);
    `DECL_WIN(win4_ch1_0, win4_ch1_1, win4_ch1_2, win4_ch1_3, win4_ch1_4);
    `DECL_WIN(win4_ch2_0, win4_ch2_1, win4_ch2_2, win4_ch2_3, win4_ch2_4);
    reg signed [BITWIDTH-1:0] filter_buf [0:3*FILTER_WIDTH*FILTER_WIDTH-1];

    wire [1:0] load_channel = (cur_load_idx < IMAGE_WIDTH) ? 0 :
                              ((cur_load_idx < 2*IMAGE_WIDTH) ? 1 : 2);
    wire [6:0] load_col = (cur_load_idx < IMAGE_WIDTH) ? cur_load_idx[6:0] :
                          ((cur_load_idx < 2*IMAGE_WIDTH) ?
                           (cur_load_idx - IMAGE_WIDTH) :
                           (cur_load_idx - 2*IMAGE_WIDTH));
    wire [5:0] load_fx = cur_load_fx;
    wire [1:0] load_col_mod = cur_load_col_mod;
    wire [1:0] load_bank = cur_load_fx[4:3];
    wire [2:0] load_low = cur_load_fx[2:0];
    wire [5:0] load_prev_fx = cur_load_fx - 1;
    wire [1:0] load_prev_bank = load_prev_fx[4:3];
    wire [2:0] load_prev_low = load_prev_fx[2:0];
    wire [2:0] load_slot = cur_load_row % 5;

    wire [6:0] active_abs_row = cur_feature_y * 3 + cur_kernel_row;
    wire [2:0] active_slot = active_abs_row % 5;
    wire [1:0] feature_bank = cur_feature_x[4:3];
    wire [2:0] feature_low = cur_feature_x[2:0];
    wire [4:0] read_state = (feature_bank == 0) ? READ_BANK0 :
                            (feature_bank == 1) ? READ_BANK1 :
                            (feature_bank == 2) ? READ_BANK2 : READ_BANK3;

    wire [6:0] filter_base = cur_channel * FILTER_WIDTH * FILTER_WIDTH +
                             cur_kernel_row * FILTER_WIDTH;

    wire signed [2*BITWIDTH-1:0] mac_result;

    assign IMAGE_RAM_EN = (cur_state == ISSUE_IMAGE);
    assign FILTER_RAM_EN = (cur_state == ISSUE_FILTER);
    assign FEATURE_RAM_EN = (cur_state == WRITE_FEATURE);
    assign FEATURE_RAM_WEN = (cur_state == WRITE_FEATURE);
    assign IMAGE_RAM_ADDRESS = load_channel * IMAGE_WIDTH * IMAGE_WIDTH +
                               cur_load_row * IMAGE_WIDTH + load_col;
    assign FILTER_RAM_ADDRESS = cur_filter_idx;
    assign FEATURE_RAM_ADDRESS = cur_feature_x + cur_feature_y * FEATURE_WIDTH;
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
            cur_load_row <= 0;
            cur_load_idx <= 0;
            cur_load_fx <= 0;
            cur_load_col_mod <= 0;
            cur_feature_x <= 0;
            cur_feature_y <= 0;
            cur_kernel_row <= 0;
            cur_channel <= 0;
            cur_acc <= 0;
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
            slot_ch0_1 <= 0;
            slot_ch0_2 <= 0;
            slot_ch0_3 <= 0;
            slot_ch0_4 <= 0;
            slot_ch0_5 <= 0;
            slot_ch1_1 <= 0;
            slot_ch1_2 <= 0;
            slot_ch1_3 <= 0;
            slot_ch1_4 <= 0;
            slot_ch1_5 <= 0;
            slot_ch2_1 <= 0;
            slot_ch2_2 <= 0;
            slot_ch2_3 <= 0;
            slot_ch2_4 <= 0;
            slot_ch2_5 <= 0;
        end
        else begin
            cur_state <= next_state;
            cur_filter_idx <= next_filter_idx;
            cur_load_row <= next_load_row;
            cur_load_idx <= next_load_idx;
            cur_load_fx <= next_load_fx;
            cur_load_col_mod <= next_load_col_mod;
            cur_feature_x <= next_feature_x;
            cur_feature_y <= next_feature_y;
            cur_kernel_row <= next_kernel_row;
            cur_channel <= next_channel;
            cur_acc <= next_acc;

            if(cur_state == READ_BANK0) begin
                `CAPTURE_ACTIVE(2'd0, feature_low)
            end
            else if(cur_state == READ_BANK1) begin
                `CAPTURE_ACTIVE(2'd1, feature_low)
            end
            else if(cur_state == READ_BANK2) begin
                `CAPTURE_ACTIVE(2'd2, feature_low)
            end
            else if(cur_state == READ_BANK3) begin
                `CAPTURE_ACTIVE(2'd3, feature_low)
            end
            else if(cur_state == READ_OPERAND) begin
                case(cur_channel)
                    2'd0: begin
                        ifmap_pipe1 <= slot_ch0_1;
                        ifmap_pipe2 <= slot_ch0_2;
                        ifmap_pipe3 <= slot_ch0_3;
                        ifmap_pipe4 <= slot_ch0_4;
                        ifmap_pipe5 <= slot_ch0_5;
                    end
                    2'd1: begin
                        ifmap_pipe1 <= slot_ch1_1;
                        ifmap_pipe2 <= slot_ch1_2;
                        ifmap_pipe3 <= slot_ch1_3;
                        ifmap_pipe4 <= slot_ch1_4;
                        ifmap_pipe5 <= slot_ch1_5;
                    end
                    default: begin
                        ifmap_pipe1 <= slot_ch2_1;
                        ifmap_pipe2 <= slot_ch2_2;
                        ifmap_pipe3 <= slot_ch2_3;
                        ifmap_pipe4 <= slot_ch2_4;
                        ifmap_pipe5 <= slot_ch2_5;
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

    always @ (posedge clk or negedge resetn) begin
        if(!resetn) begin
        end
        else if((cur_state == WAIT_FILTER) && FILTER_RAM_DATA_VAL) begin
            filter_buf[cur_filter_idx] <= FILTER_RAM_DIN;
        end
        else if((cur_state == WAIT_IMAGE) && IMAGE_RAM_DATA_VAL) begin
            case({load_slot, load_channel})
                5'b00000: `STORE_WIN(win0_ch0_0, win0_ch0_1, win0_ch0_2, win0_ch0_3, win0_ch0_4)
                5'b00001: `STORE_WIN(win0_ch1_0, win0_ch1_1, win0_ch1_2, win0_ch1_3, win0_ch1_4)
                5'b00010: `STORE_WIN(win0_ch2_0, win0_ch2_1, win0_ch2_2, win0_ch2_3, win0_ch2_4)
                5'b00100: `STORE_WIN(win1_ch0_0, win1_ch0_1, win1_ch0_2, win1_ch0_3, win1_ch0_4)
                5'b00101: `STORE_WIN(win1_ch1_0, win1_ch1_1, win1_ch1_2, win1_ch1_3, win1_ch1_4)
                5'b00110: `STORE_WIN(win1_ch2_0, win1_ch2_1, win1_ch2_2, win1_ch2_3, win1_ch2_4)
                5'b01000: `STORE_WIN(win2_ch0_0, win2_ch0_1, win2_ch0_2, win2_ch0_3, win2_ch0_4)
                5'b01001: `STORE_WIN(win2_ch1_0, win2_ch1_1, win2_ch1_2, win2_ch1_3, win2_ch1_4)
                5'b01010: `STORE_WIN(win2_ch2_0, win2_ch2_1, win2_ch2_2, win2_ch2_3, win2_ch2_4)
                5'b01100: `STORE_WIN(win3_ch0_0, win3_ch0_1, win3_ch0_2, win3_ch0_3, win3_ch0_4)
                5'b01101: `STORE_WIN(win3_ch1_0, win3_ch1_1, win3_ch1_2, win3_ch1_3, win3_ch1_4)
                5'b01110: `STORE_WIN(win3_ch2_0, win3_ch2_1, win3_ch2_2, win3_ch2_3, win3_ch2_4)
                5'b10000: `STORE_WIN(win4_ch0_0, win4_ch0_1, win4_ch0_2, win4_ch0_3, win4_ch0_4)
                5'b10001: `STORE_WIN(win4_ch1_0, win4_ch1_1, win4_ch1_2, win4_ch1_3, win4_ch1_4)
                5'b10010: `STORE_WIN(win4_ch2_0, win4_ch2_1, win4_ch2_2, win4_ch2_3, win4_ch2_4)
            endcase
        end
    end

    always @ (*) begin
        next_state = cur_state;
        next_filter_idx = cur_filter_idx;
        next_load_row = cur_load_row;
        next_load_idx = cur_load_idx;
        next_load_fx = cur_load_fx;
        next_load_col_mod = cur_load_col_mod;
        next_feature_x = cur_feature_x;
        next_feature_y = cur_feature_y;
        next_kernel_row = cur_kernel_row;
        next_channel = cur_channel;
        next_acc = cur_acc;

        case(cur_state)
            IDLE: begin
                next_state = ISSUE_FILTER;
                next_filter_idx = 0;
                next_load_row = 0;
                next_load_idx = 0;
                next_load_fx = 0;
                next_load_col_mod = 0;
                next_feature_x = 0;
                next_feature_y = 0;
                next_kernel_row = 0;
                next_channel = 0;
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
                    next_load_fx = 0;
                    next_load_col_mod = 0;
                    if((cur_feature_y == 0 && cur_load_row == 4) ||
                       (cur_feature_y != 0 && cur_load_row == cur_feature_y*3 + 4)) begin
                        next_state = CLEAR_ACC;
                    end
                    else begin
                        next_load_row = cur_load_row + 1;
                        next_state = ISSUE_IMAGE;
                    end
                end
                else begin
                    next_load_idx = cur_load_idx + 1;
                    if(load_col == IMAGE_WIDTH-1) begin
                        next_load_fx = 0;
                        next_load_col_mod = 0;
                    end
                    else if(cur_load_col_mod == 2) begin
                        next_load_fx = cur_load_fx + 1;
                        next_load_col_mod = 0;
                    end
                    else begin
                        next_load_col_mod = cur_load_col_mod + 1;
                    end
                    next_state = ISSUE_IMAGE;
                end
            end
            CLEAR_ACC: begin
                next_acc = 0;
                next_kernel_row = 0;
                next_channel = 0;
                next_state = read_state;
            end
            READ_BANK0: begin
                next_state = READ_OPERAND;
            end
            READ_BANK1: begin
                next_state = READ_OPERAND;
            end
            READ_BANK2: begin
                next_state = READ_OPERAND;
            end
            READ_BANK3: begin
                next_state = READ_OPERAND;
            end
            READ_OPERAND: begin
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

                if(cur_channel != 2) begin
                    next_channel = cur_channel + 1;
                    next_state = READ_OPERAND;
                end
                else if(cur_kernel_row != 4) begin
                    next_channel = 0;
                    next_kernel_row = cur_kernel_row + 1;
                    next_state = read_state;
                end
                else begin
                    next_channel = 0;
                    next_kernel_row = 0;
                    next_state = WRITE_FEATURE;
                end
            end
            WRITE_FEATURE: begin
                if((cur_feature_x == FEATURE_WIDTH-1) &&
                   (cur_feature_y == FEATURE_WIDTH-1)) begin
                    next_state = DONE;
                end
                else if(cur_feature_x == FEATURE_WIDTH-1) begin
                    next_feature_x = 0;
                    next_feature_y = cur_feature_y + 1;
                    next_load_row = (cur_feature_y + 1) * 3 + 2;
                    next_load_idx = 0;
                    next_load_fx = 0;
                    next_load_col_mod = 0;
                    next_state = ISSUE_IMAGE;
                end
                else begin
                    next_feature_x = cur_feature_x + 1;
                    next_state = CLEAR_ACC;
                end
            end
            DONE: begin
                next_state = DONE;
            end
        endcase
    end

endmodule
