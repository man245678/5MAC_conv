module FSM (
        input CLK,
        input RSTN,
        input IMAGE_READ_FIN,
        input FILTER_READ_FIN,
        input KERNEL_ROW_FIN,
        input FEATURE_INDEX_FIN,

        output reg MAC_ACC_CLEAR,
        output reg CALC_START,
        output reg KERNEL_ROW_EN,
        output reg FEATURE_INDEX_EN,
        output reg IMAGE_RAM_EN,
        output reg FILTER_RAM_EN,
        output reg FEATURE_RAM_EN,
        output reg FEATURE_RAM_WEN,
        output reg EOC
);

        localparam IDLE       = 3'd0;
        localparam READ1      = 3'd1;
        localparam READ2      = 3'd2;
        localparam CALC_CLEAR = 3'd3;
        localparam CALC       = 3'd4;
        localparam WRITE      = 3'd5;
        localparam DONE       = 3'd6;

        reg [2:0] state;
        reg [2:0] next_state;

        always @ (posedge CLK or negedge RSTN) begin
                if(!RSTN)
                        state <= IDLE;
                else
                        state <= next_state;
        end

        always @ (*) begin
                case(state)
                        IDLE:
                                next_state = READ1;
                        READ1:
                                next_state = FILTER_READ_FIN ? READ2 : READ1;
                        READ2:
                                next_state = IMAGE_READ_FIN ? CALC_CLEAR : READ2;
                        CALC_CLEAR:
                                next_state = CALC;
                        CALC:
                                next_state = KERNEL_ROW_FIN ? WRITE : CALC;
                        WRITE:
                                next_state = FEATURE_INDEX_FIN ? DONE : CALC_CLEAR;
                        DONE:
                                next_state = DONE;
                        default:
                                next_state = IDLE;
                endcase
        end

        always @ (*) begin
                MAC_ACC_CLEAR   = 0;
                CALC_START      = 0;
                KERNEL_ROW_EN   = 0;
                FEATURE_INDEX_EN = 0;
                IMAGE_RAM_EN    = 0;
                FILTER_RAM_EN   = 0;
                FEATURE_RAM_EN  = 0;
                FEATURE_RAM_WEN = 0;
                EOC             = 0;

                case(state)
                        READ1: begin
                                IMAGE_RAM_EN  = 1;
                                FILTER_RAM_EN = 1;
                        end
                        READ2: begin
                                IMAGE_RAM_EN  = 1;
                        end
                        CALC_CLEAR: begin
                                MAC_ACC_CLEAR = 1;
                        end
                        CALC: begin
                                CALC_START    = 1;
                                KERNEL_ROW_EN = 1;
                        end
                        WRITE: begin
                                FEATURE_INDEX_EN = 1;
                                FEATURE_RAM_EN   = 1;
                                FEATURE_RAM_WEN  = 1;
                        end
                        DONE: begin
                                EOC = 1;
                        end
                endcase
        end

endmodule
