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

    // Stage-ready handshake inputs
    reg capture_ready;
    reg isp_ready;
    reg display_ready;

    wire camera_enable;
    wire fifo_read_enable;
    wire isp_enable;
    wire display_enable;

    // Debug / status outputs
    wire [2:0] state_out;
    wire [2:0] error_code_out;
    wire [1:0] retry_count_out;
    wire       timeout_flag;

    // Latch registers — capture transient events so checks work after the fact
    reg error_seen;      // set the moment state_out becomes ERROR
    reg timeout_seen;    // set the moment timeout_flag goes high

    initial begin error_seen = 0; timeout_seen = 0; end

    always @(posedge clk) begin
        if (state_out == 3'd6) error_seen   <= 1'b1;
        if (timeout_flag)      timeout_seen <= 1'b1;
    end

    // Short TIMEOUT_LIMIT for fast simulation; MAX_RETRIES=2 to test exhaustion quickly
    main_fsm #(.TIMEOUT_LIMIT(8'd10), .MAX_RETRIES(2'd2)) uut (
        .clk(clk),
        .rst_n(rst_n),

        .trigger(trigger),
        .capture_done(capture_done),
        .fifo_read_done(fifo_read_done),
        .isp_done(isp_done),
        .display_done(display_done),
        .error_flag(error_flag),

        .capture_ready(capture_ready),
        .isp_ready(isp_ready),
        .display_ready(display_ready),

        .camera_enable(camera_enable),
        .fifo_read_enable(fifo_read_enable),
        .isp_enable(isp_enable),
        .display_enable(display_enable),

        .state_out(state_out),
        .error_code_out(error_code_out),
        .retry_count_out(retry_count_out),
        .timeout_flag(timeout_flag)
    );

    always #5 clk = ~clk;

    initial begin
       $dumpfile("sim/main_fsm.vcd");
       $dumpvars(0, main_fsm_tb);
       
        clk = 0;
        rst_n = 0;

        trigger = 0;
        capture_done = 0;
        fifo_read_done = 0;
        isp_done = 0;
        display_done = 0;
        error_flag = 0;

        // All stages ready by default for happy-path test
        capture_ready = 1;
        isp_ready     = 1;
        display_ready = 1;

        #20;
        rst_n = 1;
        $display("[%0t] Reset released. state=%0d error_code=%0d retry_count=%0d timeout_flag=%0d",
                 $time, state_out, error_code_out, retry_count_out, timeout_flag);

        #20;
        trigger = 1;

        #20;
        trigger = 0;
        $display("[%0t] Trigger fired.  state=%0d (expect CAMERA_CAPTURE=2)",
                 $time, state_out);

        #40;
        capture_done = 1;

        #20;
        capture_done = 0;
        $display("[%0t] Capture done.   state=%0d (expect READ_FIFO=3)",
                 $time, state_out);

        #40;
        fifo_read_done = 1;

        #20;
        fifo_read_done = 0;
        $display("[%0t] FIFO read done. state=%0d (expect ISP_PROCESS=4)",
                 $time, state_out);

        #40;
        isp_done = 1;

        #20;
        isp_done = 0;
        $display("[%0t] ISP done.       state=%0d (expect DISPLAY=5)",
                 $time, state_out);

        #40;
        display_done = 1;

        #20;
        display_done = 0;
        $display("[%0t] Display done.   state=%0d (expect WAIT_TRIGGER=1)",
                 $time, state_out);

        #20;
        $display("[%0t] END happy path: error_code=%0d retry_count=%0d timeout_flag=%0d",
                 $time, error_code_out, retry_count_out, timeout_flag);

        // -------------------------------------------------------
        // TEST: Handshake — trigger ignored when capture_ready=0
        // -------------------------------------------------------
        $display("[%0t] --- Handshake test: trigger with capture_ready=0 ---", $time);
        #20;
        rst_n = 0; #20; rst_n = 1;  // Reset back to IDLE -> WAIT_TRIGGER
        #20;

        capture_ready = 0;  // camera not ready
        trigger = 1;
        #40;                // give it several cycles
        if (state_out !== 3'd1)
            $display("FAIL handshake: expected WAIT_TRIGGER(1), got state=%0d", state_out);
        else
            $display("PASS handshake: FSM held in WAIT_TRIGGER while capture_ready=0");

        capture_ready = 1;  // now camera is ready
        #20;
        trigger = 0;
        #10;
        if (state_out !== 3'd2)
            $display("FAIL handshake: expected CAMERA_CAPTURE(2) after capture_ready=1, got state=%0d", state_out);
        else
            $display("PASS handshake: FSM advanced to CAMERA_CAPTURE once capture_ready=1");

        // -------------------------------------------------------
        // TEST: Timeout in CAMERA_CAPTURE
        // capture_done never arrives — FSM should timeout to ERROR
        // -------------------------------------------------------
        $display("[%0t] --- Timeout test: no capture_done, wait for timeout ---", $time);
        #20;
        rst_n = 0; #20; rst_n = 1;  // reset
        // Clear latches for this test (non-blocking so they sync on next clock)
        error_seen   = 0;
        timeout_seen = 0;
        capture_ready = 1;
        #20;
        trigger = 1; #10; trigger = 0;  // advance to CAMERA_CAPTURE

        // Wait well past TIMEOUT_LIMIT (10 cycles x 10ns/cycle = 100ns) plus recovery
        #200;

        if (!error_seen)
            $display("FAIL timeout: FSM never reached ERROR state");
        else
            $display("PASS timeout: FSM entered ERROR state after timeout");

        if (!timeout_seen)
            $display("FAIL timeout: timeout_flag never went high");
        else
            $display("PASS timeout: timeout_flag went high");

        if (error_code_out !== 3'd5)
            $display("FAIL timeout: expected error_code=ERR_TIMEOUT(5), got %0d", error_code_out);
        else
            $display("PASS timeout: error_code correctly shows ERR_TIMEOUT(5)");

        // -------------------------------------------------------
        // TEST: error_flag in READ_FIFO — check error_code=ERR_FIFO
        // -------------------------------------------------------
        $display("[%0t] --- Error code test: error_flag in READ_FIFO ---", $time);
        #20;
        rst_n = 0; #20; rst_n = 1;
        error_seen   = 0;
        timeout_seen = 0;
        capture_ready = 1; isp_ready = 1; display_ready = 1;
        #20;
        trigger = 1; #10; trigger = 0;   // -> CAMERA_CAPTURE
        #10;
        capture_done = 1; #10; capture_done = 0;  // -> READ_FIFO
        #10;
        error_flag = 1; #10; error_flag = 0;      // trigger error in READ_FIFO
        #30;

        if (!error_seen)
            $display("FAIL error_code: FSM never reached ERROR");
        else
            $display("PASS error_code: FSM entered ERROR");

        if (error_code_out !== 3'd2)
            $display("FAIL error_code: expected ERR_FIFO(2), got %0d", error_code_out);
        else
            $display("PASS error_code: error_code correctly shows ERR_FIFO(2)");

        // -------------------------------------------------------
        // TEST: Retry exhaustion — MAX_RETRIES=2, so 3rd error should lock
        // -------------------------------------------------------
        $display("[%0t] --- Retry exhaustion test: MAX_RETRIES=2 ---", $time);
        #20;
        rst_n = 0; #20; rst_n = 1;
        error_seen   = 0;
        timeout_seen = 0;
        capture_ready = 1;

        // Hold trigger high so every time the FSM returns to WAIT_TRIGGER it immediately
        // fires the next attempt without needing a new trigger pulse.
        // With TIMEOUT_LIMIT=10: each attempt takes ~13 cycles = 130ns
        // 3 attempts = ~390ns. Wait 600ns to be safe.
        #20;
        trigger = 1;   // keep high; FSM auto-retriggers on each WAIT_TRIGGER entry
        #600;          // wait for 3 full timeout+retry cycles
        trigger = 0;

        if (retry_count_out !== 2'd2)
            $display("INFO retry: retry_count=%0d (may still be cycling)", retry_count_out);

        if (state_out !== 3'd6)
            $display("FAIL retry: expected fatal ERROR(6), got state=%0d", state_out);
        else
            $display("PASS retry: FSM locked in ERROR after exhausting retries");

        #80;

        $finish;
    end

endmodule
