// fifo_reader_tb.v
// ---------------------------------------------------------------------------
// Testbench for fifo_reader.v
//
// Simulates an 8-byte behavioral FIFO pre-loaded with a test pattern.
// The testbench lets the fifo_reader drain all 8 bytes, then checks that
// every pixel arrived in the correct order.
// ---------------------------------------------------------------------------

`timescale 1ns / 1ps

module fifo_reader_tb;

    // -----------------------------------------------------------------------
    // DUT signal declarations
    // -----------------------------------------------------------------------
    reg        rclk;         // FPGA read clock
    reg        rst_n;        // active-low reset
    wire       fifo_empty_wire; // driven by behavioral FIFO
    wire [7:0] fifo_data_wire;  // driven by behavioral FIFO
    wire       fifo_rd_en;   // driven by DUT
    wire [7:0] pixel_out;    // DUT output
    wire       pixel_valid;  // DUT output

    // -----------------------------------------------------------------------
    // Instantiate the DUT
    // -----------------------------------------------------------------------
    fifo_reader uut (
        .rclk        (rclk),
        .rst_n       (rst_n),
        .fifo_empty  (fifo_empty_wire),
        .fifo_data   (fifo_data_wire),
        .fifo_rd_en  (fifo_rd_en),
        .pixel_out   (pixel_out),
        .pixel_valid (pixel_valid)
    );

    // -----------------------------------------------------------------------
    // Behavioral FIFO model
    // 8-byte memory pre-loaded with a known test pattern.
    //
    // This models a registered-output FIFO (like the AL422B):
    //   - fifo_data_wire is a REGISTERED output, not a combinatorial read.
    //   - When rd_en is asserted, the CURRENT byte (at the current pointer)
    //     is captured into fifo_data_reg on that clock edge, and the pointer
    //     advances so the next rd_en reads the next byte.
    //   - One cycle later, fifo_data_reg holds the correct byte — this lines
    //     up exactly with data_latched in the DUT.
    // -----------------------------------------------------------------------
    reg [7:0] fifo_mem [0:7]; // 8-byte FIFO storage
    reg [3:0] fifo_rd_ptr;    // points to the next byte to be read
    integer   fifo_count;     // number of bytes remaining in FIFO
    reg [7:0] fifo_data_reg;  // registered output: holds byte captured on last rd_en

    // Data bus is the registered output (valid one cycle after rd_en)
    assign fifo_data_wire  = fifo_data_reg;
    // Empty flag goes HIGH when no bytes remain
    assign fifo_empty_wire = (fifo_count == 0);

    // Load test pattern and initialise pointers
    initial begin
        fifo_mem[0] = 8'hC0; fifo_mem[1] = 8'hC1;
        fifo_mem[2] = 8'hC2; fifo_mem[3] = 8'hC3;
        fifo_mem[4] = 8'hD0; fifo_mem[5] = 8'hD1;
        fifo_mem[6] = 8'hD2; fifo_mem[7] = 8'hD3;
        fifo_rd_ptr  = 0;
        fifo_count   = 8;
        fifo_data_reg = 8'hXX; // undefined until first read
    end

    // On rd_en: capture current byte into output register, then advance pointer.
    // This is the key: fifo_data_reg gets fifo_mem[current_ptr] BEFORE the
    // pointer increments, so the DUT sees the correct byte one cycle later.
    always @(posedge rclk) begin
        if (fifo_rd_en && fifo_count > 0) begin
            fifo_data_reg <= fifo_mem[fifo_rd_ptr]; // capture byte for output
            fifo_rd_ptr   <= fifo_rd_ptr + 1;       // advance to next byte
            fifo_count    <= fifo_count  - 1;       // one fewer byte available
        end
    end

    // -----------------------------------------------------------------------
    // Clock generator: 10 ns period (100 MHz)
    // -----------------------------------------------------------------------
    initial rclk = 0;
    always #5 rclk = ~rclk;

    // -----------------------------------------------------------------------
    // Checker state
    // -----------------------------------------------------------------------
    // Expected byte sequence matches the FIFO load order
    reg [7:0] expected [0:7];
    integer pixel_count; // counts pixel_valid pulses received
    integer errors;      // counts value mismatches
    reg     all_ok;      // set to 0 if any mismatch is detected

    initial begin
        expected[0] = 8'hC0; expected[1] = 8'hC1;
        expected[2] = 8'hC2; expected[3] = 8'hC3;
        expected[4] = 8'hD0; expected[5] = 8'hD1;
        expected[6] = 8'hD2; expected[7] = 8'hD3;
        pixel_count = 0;
        errors      = 0;
        all_ok      = 1;
    end

    // On every rising edge, check pixel_valid and compare to expected value
    always @(posedge rclk) begin
        if (pixel_valid) begin
            $display("[%0t ns] pixel_valid=1  pixel_out=0x%02X  (expected 0x%02X)",
                     $time, pixel_out, expected[pixel_count]);

            if (pixel_out !== expected[pixel_count]) begin
                $display("  *** MISMATCH at index %0d: got 0x%02X, expected 0x%02X ***",
                         pixel_count, pixel_out, expected[pixel_count]);
                errors  = errors + 1;
                all_ok  = 0;
            end
            pixel_count = pixel_count + 1;
        end
    end

    // -----------------------------------------------------------------------
    // Main stimulus
    // -----------------------------------------------------------------------
    initial begin
        // Set up waveform dump
        $dumpfile("sim/fifo_reader.vcd");
        $dumpvars(0, fifo_reader_tb);

        // 1. Assert reset
        rst_n = 0;
        #20;           // hold reset for 2 clock cycles

        // 2. Release reset and let the reader drain the FIFO
        rst_n = 1;

        // Wait long enough for all 8 bytes to be read and their pixel_valid
        // pulses to arrive.  Each byte takes ~2 cycles (rd_en + latch), so
        // 8 bytes * 2 cycles * 10 ns/cycle = 160 ns, plus reset + margin.
        // 300 ns gives plenty of headroom.
        #300;

        // 3. Report results
        $display("--------------------------------------------------");
        $display("Simulation complete.");
        $display("  Bytes received : %0d  (expected 8)", pixel_count);
        $display("  Value errors   : %0d", errors);

        // 4. PASS / FAIL
        if (pixel_count == 8 && all_ok) begin
            $display("  CHECK count==8 : PASS");
            $display("  CHECK values   : PASS");
            $display("OVERALL: PASS");
        end else begin
            if (pixel_count != 8)
                $display("  CHECK count==8 : FAIL  (got %0d)", pixel_count);
            else
                $display("  CHECK count==8 : PASS");
            if (!all_ok)
                $display("  CHECK values   : FAIL  (%0d mismatch(es))", errors);
            else
                $display("  CHECK values   : PASS");
            $display("OVERALL: FAIL");
        end
        $display("--------------------------------------------------");

        $finish;
    end

endmodule
