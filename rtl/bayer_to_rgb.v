module bayer_to_rgb (
    input  wire        clk,
    input  wire        rst_n,
    input wire valid_in,
    input  wire [7:0]  pixel_in,
    input  wire [9:0]  x,
    input  wire [9:0]  y,

    output reg [7:0]   r,
    output reg [7:0]   g,
    output reg [7:0]   b
);

always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        r <= 0;
        g <= 0;
        b <= 0;
    end

    else begin

        r <= 0;
        g <= 0;
        b <= 0;

        // RGGB Bayer pattern
        if (valid_in) begin
            if ((y % 2 == 0) && (x % 2 == 0)) begin
            // Red pixel
                 r <= pixel_in;
            end

            else if ((y % 2 == 0) && (x % 2 == 1)) begin
                 // Green pixel
                   g <= pixel_in;
            end

             else if ((y % 2 == 1) && (x % 2 == 0)) begin
                  // Green pixel
                  g <= pixel_in;
            end

             else begin
                 // Blue pixel
                  b <= pixel_in;
             end

         end

    end
end

endmodule
