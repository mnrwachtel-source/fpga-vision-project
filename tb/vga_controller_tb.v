`timescale 1ns / 1ps

module vga_controller_tb;

    reg clk;
    reg rst_n;

    wire [9:0] x;
    wire [9:0] y;
    wire hsync;
    wire vsync;
    wire active_video;

    vga_controller uut (
        .clk(clk),
        .rst_n(rst_n),
        .x(x),
        .y(y),
        .hsync(hsync),
        .vsync(vsync),
        .active_video(active_video)
    );

    always #20 clk = ~clk; // 25 MHz pixel clock approximation

    initial begin
        $dumpfile("sim/vga_controller.vcd");
        $dumpvars(0, vga_controller_tb);

        clk = 0;
        rst_n = 0;

        #100;
        rst_n = 1;

        // Run long enough to cover several VGA lines
        #100000;

        $finish;
    end

endmodule