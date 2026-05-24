module MAC
#(
    parameter DATA_BW = 8
)(
    input CLK,
    input RSTN,
    input EN,

    input signed [DATA_BW-1:0] IFMAP_DATA_IN1,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN2,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN3,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN4,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN5,

    input signed [DATA_BW-1:0] FILTER_DATA_IN1,
    input signed [DATA_BW-1:0] FILTER_DATA_IN2,
    input signed [DATA_BW-1:0] FILTER_DATA_IN3,
    input signed [DATA_BW-1:0] FILTER_DATA_IN4,
    input signed [DATA_BW-1:0] FILTER_DATA_IN5,

    output signed [2*DATA_BW-1:0] MUL_DATA_OUT
);

wire signed [2*DATA_BW-1:0] mul1 = IFMAP_DATA_IN1 * FILTER_DATA_IN1;
wire signed [2*DATA_BW-1:0] mul2 = IFMAP_DATA_IN2 * FILTER_DATA_IN2;
wire signed [2*DATA_BW-1:0] mul3 = IFMAP_DATA_IN3 * FILTER_DATA_IN3;
wire signed [2*DATA_BW-1:0] mul4 = IFMAP_DATA_IN4 * FILTER_DATA_IN4;
wire signed [2*DATA_BW-1:0] mul5 = IFMAP_DATA_IN5 * FILTER_DATA_IN5;

assign MUL_DATA_OUT = EN ? (mul1 + mul2 + mul3 + mul4 + mul5) : 0;

endmodule
