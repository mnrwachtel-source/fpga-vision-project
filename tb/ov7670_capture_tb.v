`timescale 1ns / 1ps
// ov7670_capture_tb.v
// Testbench for ov7670_capture module.
// Simulates a mini two-row camera frame to verify pixel capture behavior.

module ov7670_capture_tb;

    // ---------------------------------------------------------------------------
    // DUT signals
    // ---------------------------------------------------------------------------
    reg        pclk;
    reg        rst_n;
    reg        vsync;
    reg        href;
    reg  [7:0] cam_data;

    wire [7:0] pixel_data;
    wire       pixel_valid;
    wire       frame_valid;
    wire       line_valid;

    // ---------------------------------------------------------------------------
    // Instantiate the Device Under Test
    // ---------------------------------------------------------------------------
    ov7670_capture dut (
        .pclk       (pclk),
        .rst_n      (rst_n),
        .vsync      (vsync),
        .href       (href),
        .cam_data   (cam_data),
        .pixel_data (pixel_data),
        .pixel_valid(pixel_valid),
        .frame_valid(frame_valid),
        .line_valid (line_valid)
    );

    // ---------------------------------------------------------------------------
    // Clock: 10 ns period (~100 MHz in sim; real camera uses ~24 MHz pclk)
    // ---------------------------------------------------------------------------
    initial pclk = 0;
    always #5 pclk = ~pclk;

    // ---------------------------------------------------------------------------
    // VCD waveform dump (viewed in GTKWave)
    // ---------------------------------------------------------------------------
    initial begin
        $dumpfile("sim/ov7670_capture.vcd");
        $dumpvars(0, ov7670_capture_tb);
    end

    // ---------------------------------------------------------------------------
    // Event latches — because outputs are registered, transitions appear ONE
    // clock cycle after the input changes.  We use latching always-blocks so
    // we don't miss a transient assertion during the sequential stimulus.
    // ---------------------------------------------------------------------------
    reg pixel_valid_seen;  // Goes 1 the first time pixel_valid is observed HIGH
    reg frame_went_high;   // Goes 1 the first time frame_valid is observed HIGH

    initial begin
        pixel_valid_seen = 0;
        frame_went_high  = 0;
    end

    always @(posedge pclk) begin
        if (pixel_valid)  pixel_valid_seen <= 1;
        if (frame_valid)  frame_went_high  <= 1;
    end

    // ---------------------------------------------------------------------------
    // Display every captured pixel as it appears
    // ---------------------------------------------------------------------------
    always @(posedge pclk) begin
        if (pixel_valid)
            $display("  [pclk] pixel_valid=1  pixel_data=0x%02h  frame_valid=%b  line_valid=%b",
                     pixel_data, frame_valid, line_valid);
    end

    // ---------------------------------------------------------------------------
    // Main stimulus
    // ---------------------------------------------------------------------------
    integer pixel_count;

    initial begin
        // 1. Initialize all inputs to safe/inactive state
        pclk        = 0;
        rst_n       = 0;   // Hold in reset
        vsync       = 1;   // Camera in vertical blanking
        href        = 0;   // No active row
        cam_data    = 8'h00;
        pixel_count = 0;

        $display("=== OV7670 Capture Testbench Start ===");

        // 2. Release reset after 20 ns
        #20;
        rst_n = 1;
        $display("[%0t ns] Reset released (rst_n=1)", $time);

        // 3. Stay in vertical blanking for 40 ns
        #40;
        vsync = 1;
        $display("[%0t ns] vsync=1 (vertical blanking)", $time);

        // 4. Begin active frame (vsync LOW)
        vsync = 0;
        #10;
        $display("[%0t ns] vsync=0  -> frame_valid should go HIGH next cycle", $time);

        // ------------------------------------------------------------------
        // 5. Row 1: 4 Bayer bytes  0xA0 0xA1 0xA2 0xA3
        // ------------------------------------------------------------------
        $display("[%0t ns] --- Row 1 start (href=1) ---", $time);
        href = 1;

        cam_data = 8'hA0; #10;
        cam_data = 8'hA1; #10;
        cam_data = 8'hA2; #10;
        cam_data = 8'hA3; #10;

        href = 0;
        $display("[%0t ns] --- Row 1 end   (href=0) ---", $time);
        #20;

        // ------------------------------------------------------------------
        // 6. Row 2: 4 Bayer bytes  0xB0 0xB1 0xB2 0xB3
        // ------------------------------------------------------------------
        $display("[%0t ns] --- Row 2 start (href=1) ---", $time);
        href = 1;

        cam_data = 8'hB0; #10;
        cam_data = 8'hB1; #10;
        cam_data = 8'hB2; #10;
        cam_data = 8'hB3; #10;

        href = 0;
        $display("[%0t ns] --- Row 2 end   (href=0) ---", $time);
        #20;

        // 7. End of frame — vsync goes HIGH again (vertical blanking)
        vsync = 1;
        $display("[%0t ns] vsync=1  -> frame_valid should go LOW next cycle", $time);
        #40;

        // ------------------------------------------------------------------
        // 8. Results — wait one extra cycle so registered outputs have settled
        // ------------------------------------------------------------------
        @(posedge pclk); // let the last vsync=1 propagate through registers
        #1;              // tiny delta to read stable wire values

        $display("");
        $display("=== Simulation Results ===");

        // Check: frame_valid went HIGH during the active frame
        if (frame_went_high)
            $display("PASS: frame_valid went HIGH (frame was detected)");
        else
            $display("FAIL: frame_valid never went HIGH");

        // Check: pixel_valid went HIGH during href rows
        if (pixel_valid_seen)
            $display("PASS: pixel_valid went HIGH (pixels were captured)");
        else
            $display("FAIL: pixel_valid never went HIGH");

        // Check: frame_valid is LOW now that vsync=1 again
        if (!frame_valid)
            $display("PASS: frame_valid is LOW at end of frame (vsync=1)");
        else
            $display("FAIL: frame_valid is still HIGH at end of frame");

        $display("=== Testbench Complete ===");
        $finish;
    end

endmodule
