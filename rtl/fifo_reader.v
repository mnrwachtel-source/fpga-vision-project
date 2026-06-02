// fifo_reader.v
// ---------------------------------------------------------------------------
// Models the FPGA-side logic for reading pixels from an external FIFO chip
// (e.g. AL422B used on OV7670+FIFO camera modules).
//
// HOW IT WORKS:
//   The camera continuously writes pixels into the FIFO.  This module reads
//   them out at the FPGA's own pace using a separate read clock (rclk).
//
// TIMING (1-cycle data latency):
//   Cycle N  : fifo_empty=0 → fifo_rd_en asserted HIGH
//   Cycle N+1: FIFO chip places the byte on fifo_data; data_latched=1
//              → pixel_out captures fifo_data, pixel_valid pulses HIGH
//   Cycle N+2: next byte is in flight (or fifo_rd_en de-asserts if empty)
// ---------------------------------------------------------------------------

module fifo_reader (
    input  wire       rclk,        // FPGA-side read clock (independent of camera pclk)
    input  wire       rst_n,       // Active-low asynchronous reset
    input  wire       fifo_empty,  // HIGH when FIFO contains no more bytes
    input  wire [7:0] fifo_data,   // Byte output from FIFO (valid ONE cycle after rd_en)
    output reg        fifo_rd_en,  // Assert HIGH to advance FIFO read pointer by one byte
    output reg  [7:0] pixel_out,   // Captured pixel byte (valid when pixel_valid=1)
    output reg        pixel_valid  // HIGH for exactly one rclk cycle when pixel_out is ready
);

    // data_latched: delayed copy of fifo_rd_en.
    // Because the FIFO chip needs one clock cycle to place data on fifo_data
    // after rd_en is asserted, we use this register to know when fifo_data
    // actually holds a valid byte.
    reg data_latched;

    always @(posedge rclk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs and internal state to known values
            fifo_rd_en   <= 1'b0;
            pixel_out    <= 8'h00;
            pixel_valid  <= 1'b0;
            data_latched <= 1'b0;
        end else begin

            // ----------------------------------------------------------------
            // Step 1: Drive the FIFO read-enable.
            //   Assert rd_en whenever the FIFO is not empty so we keep reading
            //   back-to-back bytes.  De-assert as soon as fifo_empty goes HIGH
            //   to stop advancing the pointer.
            // ----------------------------------------------------------------
            fifo_rd_en <= ~fifo_empty;

            // ----------------------------------------------------------------
            // Step 2: Track when data will be ready.
            //   data_latched captures whether rd_en was asserted AND the FIFO
            //   was not empty this cycle — meaning a byte was actually sent out
            //   by the FIFO chip and will appear on fifo_data next cycle.
            //
            //   We AND with ~fifo_empty so that if the FIFO becomes empty on
            //   the same cycle rd_en is high (last byte just consumed), we do
            //   NOT set data_latched — preventing a spurious pixel_valid pulse
            //   one cycle after the FIFO runs out.
            // ----------------------------------------------------------------
            data_latched <= fifo_rd_en & ~fifo_empty;

            // ----------------------------------------------------------------
            // Step 3: Capture the byte and signal the downstream logic.
            //   Only latch fifo_data and assert pixel_valid when data_latched
            //   tells us the FIFO output is stable.
            // ----------------------------------------------------------------
            if (data_latched) begin
                pixel_out   <= fifo_data;   // capture the valid byte
                pixel_valid <= 1'b1;        // tell downstream: data is ready
            end else begin
                pixel_valid <= 1'b0;        // no valid data this cycle
                // pixel_out retains its last value (don't care when valid=0)
            end

        end
    end

endmodule
