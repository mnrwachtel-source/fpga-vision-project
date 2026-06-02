module isp_test_top (
    input  wire       clk,
    input  wire       rst_n,

    output wire       hsync,
    output wire       vsync,
    output wire       active_video,

    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    wire [9:0] x;
    wire [9:0] y;
    wire [7:0] raw_pixel;

    vga_controller vga_inst (
        .clk(clk),
        .rst_n(rst_n),
        .x(x),
        .y(y),
        .hsync(hsync),
        .vsync(vsync),
        .active_video(active_video)
    );

    image_generator img_gen_inst (
        .clk(clk),
        .rst_n(rst_n),
        .x(x),
        .y(y),
        .pixel_out(raw_pixel)
    );

    bayer_to_rgb isp_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(active_video),
        .pixel_in(raw_pixel),
        .x(x),
        .y(y),
        .r(r),
        .g(g),
        .b(b)
    );

endmodule