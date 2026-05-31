module vga_controller (
    input  wire       clk,
    input  wire       rst_n,

    output reg [9:0]  x,
    output reg [9:0]  y,
    output reg        hsync,
    output reg        vsync,
    output reg        active_video
);

    // 640x480 @ 60Hz VGA timing
    localparam H_ACTIVE = 640;
    localparam H_FRONT  = 16;
    localparam H_SYNC   = 96;
    localparam H_BACK   = 48;
    localparam H_TOTAL  = 800;

    localparam V_ACTIVE = 480;
    localparam V_FRONT  = 10;
    localparam V_SYNC   = 2;
    localparam V_BACK   = 33;
    localparam V_TOTAL  = 525;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;

                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    always @(*) begin
        active_video = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);

        x = active_video ? h_count : 10'd0;
        y = active_video ? v_count : 10'd0;

        hsync = ~((h_count >= H_ACTIVE + H_FRONT) &&
                  (h_count <  H_ACTIVE + H_FRONT + H_SYNC));

        vsync = ~((v_count >= V_ACTIVE + V_FRONT) &&
                  (v_count <  V_ACTIVE + V_FRONT + V_SYNC));
    end

endmodule
