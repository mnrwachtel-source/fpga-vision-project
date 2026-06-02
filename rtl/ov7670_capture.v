// ov7670_capture.v
// Captures raw 8-bit Bayer pixels from the OV7670 camera sensor.
// All logic runs in the pclk (pixel clock) domain (~24 MHz on hardware).
//
// OV7670 Signal Reference:
//   pclk      - Pixel clock from camera. Every rising edge delivers one byte of data.
//   vsync     - Vertical sync. HIGH during the blanking gap BETWEEN frames.
//               LOW while a frame is actively being transmitted.
//   href      - Horizontal reference. HIGH while a row of pixels is being sent.
//               LOW during horizontal blanking between rows.
//   cam_data  - Raw 8-bit Bayer byte from the camera. Valid on each pclk when href is HIGH.

module ov7670_capture (
    input  wire       pclk,        // Pixel clock from OV7670 (~24 MHz)
    input  wire       rst_n,       // Active-low asynchronous reset
    input  wire       vsync,       // Vertical sync (HIGH = blanking, LOW = active frame)
    input  wire       href,        // Horizontal reference (HIGH = active row)
    input  wire [7:0] cam_data,    // Raw Bayer pixel byte from camera
    output reg  [7:0] pixel_data,  // Captured pixel byte (holds last value when invalid)
    output reg        pixel_valid, // HIGH for one pclk cycle per valid pixel byte
    output reg        frame_valid, // HIGH while a frame is actively being sent
    output reg        line_valid   // HIGH while a row of pixels is being sent
);

    // All outputs are registered on posedge pclk.
    // Registering outputs removes glitches and ensures clean, synchronous
    // transitions that downstream modules can safely sample.
    //
    // Async reset (negedge rst_n) brings all outputs to a known safe state
    // without waiting for a clock edge — useful during power-up.

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs to 0 (safe/inactive state)
            pixel_data  <= 8'h00;
            pixel_valid <= 1'b0;
            frame_valid <= 1'b0;
            line_valid  <= 1'b0;
        end else begin
            // vsync is HIGH during blanking (no frame), LOW during active frame.
            // We invert it so frame_valid=1 means "a frame is in progress" —
            // a more intuitive polarity for downstream logic.
            frame_valid <= ~vsync;

            // line_valid directly follows href: HIGH when a row is being sent.
            line_valid  <= href;

            if (href) begin
                // Camera is sending valid pixel data this clock cycle.
                // Latch the byte and assert pixel_valid for exactly one cycle.
                pixel_data  <= cam_data;
                pixel_valid <= 1'b1;
            end else begin
                // No active row — deassert pixel_valid.
                // pixel_data retains its last value (don't-care but harmless).
                pixel_valid <= 1'b0;
            end
        end
    end

endmodule
