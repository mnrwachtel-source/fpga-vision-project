`timescale 1ns / 1ps
// camera_pipeline_top_tb.v
//
// Testbench for camera_pipeline_top.
// Simulates a tiny 4x4 Bayer frame being delivered by the OV7670 interface,
// then checks that isp_valid fires and RGB output is produced.

module camera_pipeline_top_tb;

    // -----------------------------------------------------------------------
    // DUT signal declarations
    // -----------------------------------------------------------------------
    reg        pclk;
    reg        rst_n;
    reg        vsync;
    reg        href;
    reg  [7:0] cam_data;

    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;
    wire       isp_valid;

    // -----------------------------------------------------------------------
    // Instantiate the design under test
    // -----------------------------------------------------------------------
    camera_pipeline_top uut (
        .pclk     (pclk),
        .rst_n    (rst_n),
        .vsync    (vsync),
        .href     (href),
        .cam_data (cam_data),
        .r        (r),
        .g        (g),
        .b        (b),
        .isp_valid(isp_valid)
    );

    // -----------------------------------------------------------------------
    // Clock: 10 ns period (100 MHz — fast enough to stress the logic cleanly)
    // -----------------------------------------------------------------------
    initial pclk = 0;
    always #5 pclk = ~pclk;

    // -----------------------------------------------------------------------
    // VCD waveform dump for GTKWave inspection
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("sim/camera_pipeline_top.vcd");
        $dumpvars(0, camera_pipeline_top_tb);
    end

    // -----------------------------------------------------------------------
    // Observation latches
    // Record whether isp_valid ever fired, and the last RGB value seen.
    // -----------------------------------------------------------------------
    reg        isp_valid_seen;
    reg  [7:0] last_r, last_g, last_b;

    initial begin
        isp_valid_seen = 0;
        last_r = 0;
        last_g = 0;
        last_b = 0;
    end

    always @(posedge pclk) begin
        if (isp_valid) begin
            isp_valid_seen <= 1;
            last_r <= r;
            last_g <= g;
            last_b <= b;
            $display("[%0t] isp_valid: r=%0d g=%0d b=%0d", $time, r, g, b);
        end
    end

    // -----------------------------------------------------------------------
    // Loop variables (must be declared at module scope for Verilog-2001)
    // -----------------------------------------------------------------------
    integer row;
    integer col;

    // -----------------------------------------------------------------------
    // Main stimulus
    // -----------------------------------------------------------------------
    initial begin

        // --- 1. Initialise and hold in reset ---
        rst_n    = 0;
        vsync    = 1;   // HIGH = blanking (no frame in progress)
        href     = 0;
        cam_data = 8'h00;
        #20;            // hold reset for 2 clock periods

        // --- 2. Release reset ---
        rst_n = 1;
        #30;            // a few cycles of blanking while the camera "warms up"

        // --- 3. Start a frame: pull vsync LOW ---
        vsync = 0;      // LOW = active frame
        #10;

        // --- 4. Drive a 4-row x 4-column Bayer frame ---
        // cam_data value = row*16 + col  (gives easy-to-spot patterns in waveform)
        for (row = 0; row < 4; row = row + 1) begin
            href = 1;                           // row active
            for (col = 0; col < 4; col = col + 1) begin
                cam_data = (row * 16 + col);    // unique value per pixel
                #10;                            // one clock period per byte
            end
            href = 0;                           // end of row (horizontal blanking)
            #20;                                // brief inter-row gap
        end

        // --- 5. End of frame: pull vsync HIGH again ---
        vsync = 1;
        #40;

        // -----------------------------------------------------------------------
        // PASS / FAIL report
        // -----------------------------------------------------------------------
        if (isp_valid_seen)
            $display("PASS: isp_valid was asserted during the frame (isp_valid_seen=1)");
        else
            $display("FAIL: isp_valid was never asserted (isp_valid_seen=0)");

        $display("Last RGB output: r=%0d g=%0d b=%0d", last_r, last_g, last_b);

        $finish;
    end

endmodule
