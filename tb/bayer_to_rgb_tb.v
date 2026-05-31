`timescale 1ns / 1ps

module bayer_to_rgb_tb;

    reg clk;
    reg rst_n;

    reg [7:0] pixel_in;
    reg [9:0] x;
    reg [9:0] y;

    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;

    bayer_to_rgb uut (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_in(pixel_in),
        .x(x),
        .y(y),
        .r(r),
        .g(g),
        .b(b)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/bayer_to_rgb.vcd");
        $dumpvars(0, bayer_to_rgb_tb);
        
        clk = 0;
        rst_n = 0;

        pixel_in = 0;
        x = 0;
        y = 0;

        #20;
        rst_n = 1;

        // Red pixel
        #10;
        x = 0;
        y = 0;
        pixel_in = 8'hFF;

        // Green pixel
        #10;
        x = 1;
        y = 0;
        pixel_in = 8'hAA;

        // Green pixel
        #10;
        x = 0;
        y = 1;
        pixel_in = 8'h55;

        // Blue pixel
        #10;
        x = 1;
        y = 1;
        pixel_in = 8'h11;

        #50;

        $finish;

    end

endmodule
