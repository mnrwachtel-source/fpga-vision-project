`timescale 1ns / 1ps

module isp_test_top_tb;

    reg clk;
    reg rst_n;

    wire hsync;
    wire vsync;
    wire active_video;

    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;

    isp_test_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .active_video(active_video),
        .r(r),
        .g(g),
        .b(b)
    );

    always #20 clk = ~clk;

    initial begin
        $dumpfile("sim/isp_test_top.vcd");
        $dumpvars(0, isp_test_top_tb);

        clk = 0;
        rst_n = 0;

        #100;
        rst_n = 1;

        #100000;

        $finish;
    end

endmodule