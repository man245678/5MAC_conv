module cntImage (
        input resetn,
        input enable,
        input carryIN,
        output carryOUT,
        output reg [14:0] countVal
);

        assign carryOUT = ((countVal == 28811) && (carryIN == 1)) ? 1 : 0;

        always @ (posedge carryIN or negedge resetn) begin
                if(!resetn) begin
                        countVal <= 0;
                end
                else if(enable) begin
                        if(countVal == 28811)
                                countVal <= 0;
                        else
                                countVal <= countVal + 1;
                end
        end
endmodule

module cntFilter (
        input resetn,
        input enable,
        input carryIN,
        output carryOUT,
        output reg [14:0] countVal
);

        assign carryOUT = ((countVal == 74) && (carryIN == 1)) ? 1 : 0;

        always @ (posedge carryIN or negedge resetn) begin
                if(!resetn) begin
                        countVal <= 0;
                end
                else if(enable) begin
                        if(countVal == 74)
                                countVal <= 0;
                        else
                                countVal <= countVal + 1;
                end
        end
endmodule
