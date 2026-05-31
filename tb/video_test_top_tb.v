`timescale 1ns / 1ps

module video_test_top_tb;

    reg clk;
    reg rst_n;

    wire hsync;
    wire vsync;
    wire active_video;
    wire [7:0] pixel_out;

    video_test_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .active_video(active_video),
        .pixel_out(pixel_out)
    );

    always #20 clk = ~clk;

    initial begin
        $dumpfile("sim/video_test_top.vcd");
        $dumpvars(0, video_test_top_tb);

        clk = 0;
        rst_n = 0;

        #100;
        rst_n = 1;

        #100000;

        $finish;
    end

endmodule