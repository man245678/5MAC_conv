`timescale 1ns / 1ps

module tb_Convolver();
    parameter WIDTH          = 8;
    parameter input_width    = 98;
    parameter input_height   = 98;
    parameter input_channel  = 3;
    parameter output_channel = 1;
    parameter kernel_size    = 5; 
    parameter stride         = 3;
    parameter padding        = 0;
    parameter output_width   = (input_width-kernel_size + 2*padding)/stride + 1;
    parameter output_height  = (input_height-kernel_size + 2*padding)/stride +1;
    parameter ADDR_WIDTH     = 15;

    parameter IFMAP_DEPTH    = input_width*input_height*input_channel; 
    parameter WEIGHT_DEPTH   = kernel_size*kernel_size*input_channel*output_channel;
    parameter OFMAP_DEPTH    = output_width*output_height*output_channel;
    
    parameter half_clock     = 5; // operating frequency f = 100MHz

    // from convolver 
    wire       [WIDTH*2-1:0]       dout;
    wire                           eoc;
    wire                           w_ena, i_ena, o_ena; 
    wire                           o_wea;  
    wire       [ADDR_WIDTH-1:0]    w_addra, i_addra, o_addra; 
    // internal address buffer
    reg        [ADDR_WIDTH-1:0]    w_addra_buf, i_addra_buf, o_addra_buf;
    // to convolver 
    reg                            clk;
    reg                            rst;
    reg                            i_data_val, w_data_val, o_data_val;
    reg        [WIDTH-1:0]         din;
    reg        [WIDTH-1:0]         win;
    reg        [WIDTH*2-1:0]       psum;
    reg        [WIDTH*2-1:0]       dout_dbg;
    
    // internal memory 
    reg        [WIDTH-1:0]         din_memory      [0:IFMAP_DEPTH-1]; 
    reg        [WIDTH-1:0]         win_memory      [0:WEIGHT_DEPTH-1];
    reg        [WIDTH*2-1:0]       dout_memory     [0:OFMAP_DEPTH-1];
    reg signed [WIDTH*2-1:0]       ref_out         [0:OFMAP_DEPTH-1];
    


    integer counter;
    integer idx;
    integer file_out=0;
    integer file_in=0;
    integer file_weight=0;
    integer temp1=0;
    integer temp2=0;
    integer temp3=0;

    initial begin
        clk     = 0;
        counter = 0;
        rst = 0;
        #(4*half_clock)
        rst = 1;
    end

    always #(half_clock)  clk = ~clk;
    always @ (posedge clk) begin
        counter = counter + 1;
    end
   
    initial begin
        #(100*100*100*100*half_clock*2)
        $display("#############################################################################");
        $display("Failed Your convolver doesn't finish within 1*10^8 cycles");
        $display("#############################################################################");
        $finish;
    end

    always @ (posedge eoc) begin
        // Read golden data 
        file_out=$fopen("./golden/golden_1.bin","rb");
        temp1=$fread(ref_out,file_out);

        for (idx = 0; idx < OFMAP_DEPTH; idx = idx+1) begin
            if (dout_memory[idx] === 8'dx) begin
                $display("#############################################################################");
                $display("Write failure, idx : %d, Golden : %d, Calculated : %d", idx, ref_out[idx], dout_memory[idx]);
                $display("#############################################################################");
                $finish;
            end

            if (dout_memory[idx] !== ref_out[idx]) begin
                $display("#############################################################################");
                $display("Wrong data, idx : %d, Golden : %d, Calculated : %d", idx, ref_out[idx], dout_memory[idx]);
                $display("#############################################################################");
                $finish;
            end
             if (dout_memory[idx] == ref_out[idx]) begin
                 $display("#############################################################################");
                 $display("Correct data, idx : %d, Golden : %d, Calculated : %d", idx, ref_out[idx], dout_memory[idx]);
             end
        end
        $display("#############################################################################");
        $display("Conglaturation. Your convolver works well.");
        $display("The total cycle is %d", counter);
        $display("#############################################################################");
        $finish;
    end

    //input, weight memory
    initial begin
        file_in=$fopen("./image/image_0.bin","rb");
        temp2=$fread(din_memory,file_in);
        file_weight=$fopen("./filter/filter_1.bin","rb");
        temp3=$fread(win_memory,file_weight);
        for (idx = 0; idx < OFMAP_DEPTH; idx = idx+1) begin
            dout_memory[idx] = 0;
        end
    end
    // delay value / don't touch this value! 
    localparam DELAY_VALUE = 10;
    integer idx_ir, idx_wr, idx_or;
    // read input feature map data 
    always @ (posedge clk) begin
        if (i_ena) begin 
            i_addra_buf = i_addra;
            for (idx_ir = 0; idx_ir < DELAY_VALUE; idx_ir = idx_ir + 1) begin
                @(posedge clk)
                if (idx_ir == DELAY_VALUE-1) begin
                    din = din_memory[i_addra_buf];
                    i_data_val = 1'b1;
                end
                else begin
                    din = 8'bxxxx_xxxx;
                    i_data_val = 1'b0; 
                end
            end 
        end
        else begin
            din = 8'bxxxx_xxxx;
            i_data_val = 1'b0;
        end 
    end
    // read weight data 
    always @ (posedge clk) begin
        if (w_ena) begin
            w_addra_buf = w_addra;
            for (idx_wr = 0; idx_wr < DELAY_VALUE; idx_wr = idx_wr + 1) begin
                @(posedge clk)
                if (idx_wr == DELAY_VALUE-1) begin
                    win = win_memory[w_addra_buf];
                    w_data_val = 1'b1;
                end
                else begin
                    win = 8'bxxxx_xxxx;
                    w_data_val = 1'b0;
                end
            end
        end
        else begin  
            win = 8'bxxxx_xxxx;
            w_data_val = 1'b0;
        end
    end
    // read partial feature map data 
    always @ (posedge clk) begin
        if (o_ena) begin
            o_addra_buf = o_addra;
            for (idx_or = 0; idx_or < DELAY_VALUE; idx_or = idx_or + 1) begin
                @(posedge clk)
                if (idx_or == DELAY_VALUE-1) begin
                    psum = dout_memory[o_addra_buf];
                    o_data_val = 1'b1;
                end
                else begin
                    psum = 16'bxxxx_xxxx_xxxx_xxxx;
                    o_data_val = 1'b0;
                end
            end
        end
        else begin
            psum = 16'bxxxx_xxxx_xxxx_xxxx;
            o_data_val = 1'b0;
        end
    end

    //write to output memory
    always @ (posedge clk) begin
        if (!eoc) begin
            if (o_wea & o_ena) begin
                dout_memory[o_addra] = dout;
                dout_dbg = dout;
            end
        end
    end
    

    //Insert your Convolver here!
    Convolver Convolver (
        .clk                 (clk),
        .resetn              (rst),
        .IMAGE_RAM_EN        (i_ena),
        .IMAGE_RAM_ADDRESS   (i_addra),
        .IMAGE_RAM_DIN       (din),
        .FILTER_RAM_EN       (w_ena),
        .FILTER_RAM_ADDRESS  (w_addra),
        .FILTER_RAM_DIN      (win),
        .FEATURE_RAM_EN      (o_ena),
        .FEATURE_RAM_WEN     (o_wea),
        .FEATURE_RAM_ADDRESS (o_addra),
        .FEATURE_RAM_DIN     (psum),
        .FEATURE_RAM_DOUT    (dout),
        .eoc                 (eoc),
        .IMAGE_RAM_DATA_VAL  (i_data_val),
        .FILTER_RAM_DATA_VAL (w_data_val),
        .FEATURE_RAM_DATA_VAL(o_data_val)
    );
    //////////////////////////////


    //this is for dump variables
    
    initial begin
        $recordfile("Con0.trn");
        $recordvars();
    end
endmodule
