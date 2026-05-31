`timescale 1ns / 1ps

module image_generator_tb;

    reg clk;
    reg rst_n;

    reg [9:0] x;
    reg [9:0] y;

    wire [7:0] pixel_out;

    image_generator uut (
        .clk(clk),
        .rst_n(rst_n),
        .x(x),
        .y(y),
        .pixel_out(pixel_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/image_generator.vcd");
        $dumpvars(0, image_generator_tb);
        
        clk = 0;
        rst_n = 0;
        x = 0;
        y = 0;

        #20;
        rst_n = 1;

        #10; x = 0;  y = 0;
        #10; x = 32; y = 0;
        #10; x = 0;  y = 32;
        #10; x = 32; y = 32;
        #10; x = 64; y = 32;

        #50;

        $finish;
    end

endmodule
