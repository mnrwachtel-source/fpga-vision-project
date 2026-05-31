`timescale 1ns / 1ps

module main_fsm_tb;

    reg clk;
    reg rst_n;

    reg trigger;
    reg capture_done;
    reg fifo_read_done;
    reg isp_done;
    reg display_done;
    reg error_flag;

    wire camera_enable;
    wire fifo_read_enable;
    wire isp_enable;
    wire display_enable;

    main_fsm uut (
        .clk(clk),
        .rst_n(rst_n),

        .trigger(trigger),
        .capture_done(capture_done),
        .fifo_read_done(fifo_read_done),
        .isp_done(isp_done),
        .display_done(display_done),
        .error_flag(error_flag),

        .camera_enable(camera_enable),
        .fifo_read_enable(fifo_read_enable),
        .isp_enable(isp_enable),
        .display_enable(display_enable)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 0;
        rst_n = 0;

        trigger = 0;
        capture_done = 0;
        fifo_read_done = 0;
        isp_done = 0;
        display_done = 0;
        error_flag = 0;

        #20;
        rst_n = 1;

        #20;
        trigger = 1;

        #20;
        trigger = 0;

        #40;
        capture_done = 1;

        #20;
        capture_done = 0;

        #40;
        fifo_read_done = 1;

        #20;
        fifo_read_done = 0;

        #40;
        isp_done = 1;

        #20;
        isp_done = 0;

        #40;
        display_done = 1;

        #20;
        display_done = 0;

        #100;

        $finish;
    end

endmodule
