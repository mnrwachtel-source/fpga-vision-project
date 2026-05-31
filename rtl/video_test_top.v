module video_test_top (
    input  wire       clk,
    input  wire       rst_n,

    output wire       hsync,
    output wire       vsync,
    output wire       active_video,
    output wire [7:0] pixel_out
);

    wire [9:0] x;
    wire [9:0] y;

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
        .pixel_out(pixel_out)
    );

endmodule