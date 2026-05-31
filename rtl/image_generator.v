module image_generator (

    input  wire        clk,
    input  wire        rst_n,

    input  wire [9:0]  x,
    input  wire [9:0]  y,

    output reg [7:0]   pixel_out

);

always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        pixel_out <= 0;
    end

    else begin

        // Simple checkerboard pattern

        if ((x[5] ^ y[5]) == 1'b1)
            pixel_out <= 8'hFF;

        else
            pixel_out <= 8'h00;

    end

end

endmodule
