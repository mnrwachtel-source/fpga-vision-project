module main_fsm (
    input  wire clk,
    input  wire rst_n,

    input  wire trigger,
    input  wire capture_done,
    input  wire fifo_read_done,
    input  wire isp_done,
    input  wire display_done,
    input  wire error_flag,

    output reg  camera_enable,
    output reg  fifo_read_enable,
    output reg  isp_enable,
    output reg  display_enable
);

    localparam IDLE           = 3'd0;
    localparam WAIT_TRIGGER   = 3'd1;
    localparam CAMERA_CAPTURE = 3'd2;
    localparam READ_FIFO      = 3'd3;
    localparam ISP_PROCESS    = 3'd4;
    localparam DISPLAY        = 3'd5;
    localparam ERROR          = 3'd6;

    reg [2:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;

        case (state)
            IDLE:
                next_state = WAIT_TRIGGER;

            WAIT_TRIGGER:
                if (trigger)
                    next_state = CAMERA_CAPTURE;

            CAMERA_CAPTURE:
                if (error_flag)
                    next_state = ERROR;
                else if (capture_done)
                    next_state = READ_FIFO;

            READ_FIFO:
                if (error_flag)
                    next_state = ERROR;
                else if (fifo_read_done)
                    next_state = ISP_PROCESS;

            ISP_PROCESS:
                if (error_flag)
                    next_state = ERROR;
                else if (isp_done)
                    next_state = DISPLAY;

            DISPLAY:
                if (display_done)
                    next_state = WAIT_TRIGGER;

            ERROR:
                next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    always @(*) begin
        camera_enable    = 1'b0;
        fifo_read_enable = 1'b0;
        isp_enable       = 1'b0;
        display_enable   = 1'b0;

        case (state)
            CAMERA_CAPTURE:
                camera_enable = 1'b1;

            READ_FIFO:
                fifo_read_enable = 1'b1;

            ISP_PROCESS:
                isp_enable = 1'b1;

            DISPLAY:
                display_enable = 1'b1;
        endcase
    end

endmodule
