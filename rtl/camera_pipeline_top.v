// camera_pipeline_top.v
//
// Camera Pipeline:
//   OV7670 camera signals (pclk domain)
//       -> ov7670_capture: generates pixel_data/pixel_valid/frame_valid/line_valid
//       -> pixel coordinate counter: tracks x/y position in frame
//       -> bayer_to_rgb ISP: converts raw Bayer bytes to RGB
//
// All logic runs on pclk (the camera's own pixel clock, ~24 MHz on hardware).
// This is a simulation-architecture stub — no CDC (clock domain crossing)
// logic is needed because there is only one clock domain here.

module camera_pipeline_top (
    input  wire       pclk,      // camera pixel clock (everything runs on this)
    input  wire       rst_n,     // active-low asynchronous reset
    input  wire       vsync,     // from camera: HIGH = vertical blanking between frames
    input  wire       href,      // from camera: HIGH = active pixel row
    input  wire [7:0] cam_data,  // raw Bayer bytes from OV7670 sensor
    output wire [7:0] r,         // red channel out from ISP
    output wire [7:0] g,         // green channel out from ISP
    output wire [7:0] b,         // blue channel out from ISP
    output wire       isp_valid  // HIGH when r/g/b hold a valid decoded pixel
);

    // -----------------------------------------------------------------------
    // Stage 1 — OV7670 capture
    // Converts the raw camera handshake signals (vsync/href/cam_data) into
    // a clean synchronous pixel stream with validity flags.
    // -----------------------------------------------------------------------

    wire [7:0] pixel_data;   // latched raw Bayer byte from capture block
    wire       pixel_valid;  // pulses HIGH for exactly one pclk per captured byte
    wire       frame_valid;  // HIGH while a frame is being transmitted
    wire       line_valid;   // HIGH while a row of pixels is being transmitted

    ov7670_capture u_capture (
        .pclk        (pclk),
        .rst_n       (rst_n),
        .vsync       (vsync),
        .href        (href),
        .cam_data    (cam_data),
        .pixel_data  (pixel_data),
        .pixel_valid (pixel_valid),
        .frame_valid (frame_valid),
        .line_valid  (line_valid)
    );

    // -----------------------------------------------------------------------
    // Stage 2 — Pixel coordinate counter
    // Tracks the (x, y) address of every pixel within the current frame.
    //
    // Reset / frame boundary: when rst_n goes low OR frame_valid falls
    //   low, reset both counters to 0.
    // End of row: when line_valid falls low (prev=1, now=0), increment y
    //   and reset x.
    // Each pixel: when pixel_valid is high, increment x.
    //
    // NOTE: ov7670_capture registers its outputs, so we use the registered
    // values of frame_valid and line_valid for edge detection.
    // -----------------------------------------------------------------------

    reg [9:0] pixel_x;          // current column (0-based)
    reg [9:0] pixel_y;          // current row    (0-based)

    reg prev_frame_valid;       // previous cycle's frame_valid (for negedge detect)
    reg prev_line_valid;        // previous cycle's line_valid  (for negedge detect)

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset — put counters and shadow regs to known state
            pixel_x          <= 10'd0;
            pixel_y          <= 10'd0;
            prev_frame_valid <= 1'b0;
            prev_line_valid  <= 1'b0;
        end else begin
            // Update shadow registers every cycle so we can detect falling edges
            prev_frame_valid <= frame_valid;
            prev_line_valid  <= line_valid;

            // --- Frame boundary ---
            // frame_valid just fell (1->0): a frame ended, reset to origin
            if (prev_frame_valid && !frame_valid) begin
                pixel_x <= 10'd0;
                pixel_y <= 10'd0;

            // --- Row boundary ---
            // line_valid just fell (1->0): a row ended, move to next row
            end else if (prev_line_valid && !line_valid) begin
                pixel_y <= pixel_y + 10'd1;
                pixel_x <= 10'd0;

            // --- Pixel advance ---
            // pixel_valid pulses once per captured byte
            end else if (pixel_valid) begin
                pixel_x <= pixel_x + 10'd1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // Stage 3 — Bayer-to-RGB ISP
    // Decodes each raw Bayer byte into an (R, G, B) triple using the RGGB
    // Bayer pattern.  The clock port in bayer_to_rgb is named "clk" — we
    // connect our pclk to it because everything runs in the same domain.
    // -----------------------------------------------------------------------

    bayer_to_rgb u_isp (
        .clk      (pclk),        // bayer_to_rgb's port is named "clk"; driven by pclk
        .rst_n    (rst_n),
        .valid_in (pixel_valid), // assert when a fresh pixel byte has arrived
        .pixel_in (pixel_data),  // raw Bayer byte from capture stage
        .x        (pixel_x),     // column address tracked above
        .y        (pixel_y),     // row address tracked above
        .r        (r),
        .g        (g),
        .b        (b)
    );

    // -----------------------------------------------------------------------
    // isp_valid: pass pixel_valid straight through.
    // The ISP registers its outputs, so r/g/b will be valid on the NEXT
    // cycle after pixel_valid.  For a simulation stub this is a useful
    // "a pixel was processed this cycle" indicator.
    // -----------------------------------------------------------------------
    assign isp_valid = pixel_valid;

endmodule
