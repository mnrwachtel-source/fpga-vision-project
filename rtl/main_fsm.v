module main_fsm #(
    parameter TIMEOUT_LIMIT = 8'd200,  // cycles before timeout fires; override in TB
    parameter MAX_RETRIES   = 2'd3     // error retries before fatal lock
) (
    input  wire clk,
    input  wire rst_n,

    input  wire trigger,
    input  wire capture_done,
    input  wire fifo_read_done,
    input  wire isp_done,
    input  wire display_done,
    input  wire error_flag,

    // Stage-ready handshake inputs
    input  wire capture_ready,
    input  wire isp_ready,
    input  wire display_ready,

    output reg        camera_enable,
    output reg        fifo_read_enable,
    output reg        isp_enable,
    output reg        display_enable,

    // Debug / status outputs
    output wire [2:0] state_out,
    output wire [2:0] error_code_out,
    output wire [1:0] retry_count_out,
    output wire       timeout_flag
);

    localparam IDLE           = 3'd0;
    localparam WAIT_TRIGGER   = 3'd1;
    localparam CAMERA_CAPTURE = 3'd2;
    localparam READ_FIFO      = 3'd3;
    localparam ISP_PROCESS    = 3'd4;
    localparam DISPLAY        = 3'd5;
    localparam ERROR          = 3'd6;

    // error_code values — record which stage failed
    localparam ERR_NONE    = 3'd0;
    localparam ERR_CAPTURE = 3'd1;
    localparam ERR_FIFO    = 3'd2;
    localparam ERR_ISP     = 3'd3;
    localparam ERR_DISPLAY = 3'd4;
    localparam ERR_TIMEOUT = 3'd5;

    reg [2:0] state, next_state;

    reg [2:0] error_code;
    reg [1:0] retry_count;

    // Timeout tracking
    reg [7:0] timeout_counter;
    wire      timeout_hit = (timeout_counter >= TIMEOUT_LIMIT);

    assign state_out       = state;
    assign error_code_out  = error_code;
    assign retry_count_out = retry_count;
    assign timeout_flag    = timeout_hit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            error_code      <= 3'd0;
            retry_count     <= 2'd0;
            timeout_counter <= 8'd0;
        end else begin
            state <= next_state;

            // Record which state caused the ERROR transition, and whether it was a timeout
            if (next_state == ERROR && state != ERROR) begin
                if (timeout_hit) begin
                    error_code <= ERR_TIMEOUT;
                end else begin
                    case (state)
                        CAMERA_CAPTURE: error_code <= ERR_CAPTURE;
                        READ_FIFO:      error_code <= ERR_FIFO;
                        ISP_PROCESS:    error_code <= ERR_ISP;
                        DISPLAY:        error_code <= ERR_DISPLAY;
                        default:        error_code <= ERR_NONE;
                    endcase
                end
            end

            // Increment retry count on each ERROR->WAIT_TRIGGER (a retry attempt)
            // Reset it on a successful DISPLAY->WAIT_TRIGGER (pipeline completed cleanly)
            if (state == DISPLAY && next_state == WAIT_TRIGGER)
                retry_count <= 2'd0;
            else if (state == ERROR && next_state == WAIT_TRIGGER)
                retry_count <= retry_count + 2'd1;
        end
    end

    // Timeout counter — resets whenever the FSM is about to change state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timeout_counter <= 8'd0;
        end else begin
            if (state != next_state)
                // A transition is happening this clock cycle — reset counter for the new state
                timeout_counter <= 8'd0;
            else if (timeout_counter < TIMEOUT_LIMIT)
                timeout_counter <= timeout_counter + 8'd1;
            // If counter == TIMEOUT_LIMIT, hold — next_state logic drives ERROR
        end
    end

    always @(*) begin
        next_state = state;

        case (state)
            IDLE:
                next_state = WAIT_TRIGGER;

            WAIT_TRIGGER:
                if (trigger && capture_ready)
                    next_state = CAMERA_CAPTURE;

            CAMERA_CAPTURE:
                if (error_flag || timeout_hit)
                    next_state = ERROR;
                else if (capture_done)
                    next_state = READ_FIFO;

            READ_FIFO:
                if (error_flag || timeout_hit)
                    next_state = ERROR;
                else if (fifo_read_done)
                    next_state = ISP_PROCESS;

            ISP_PROCESS:
                if (error_flag || timeout_hit)
                    next_state = ERROR;
                else if (isp_done && display_ready)
                    next_state = DISPLAY;

            DISPLAY:
                if (timeout_hit)
                    next_state = ERROR;
                else if (display_done)
                    next_state = WAIT_TRIGGER;

            ERROR:
                // If retries are exhausted, stay in ERROR (fatal lock — only rst_n escapes)
                // Otherwise return to WAIT_TRIGGER for another attempt
                if (retry_count >= MAX_RETRIES)
                    next_state = ERROR;
                else
                    next_state = WAIT_TRIGGER;

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
                isp_enable = isp_ready;

            DISPLAY:
                display_enable = display_ready;
        endcase
    end

endmodule
