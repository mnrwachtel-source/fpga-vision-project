# FPGA Vision Project

Real-time FPGA-based image processing system using:

- Tang Nano 20K FPGA
- OV7670 FIFO Camera
- Arduino motion/light trigger
- Bayer-to-RGB ISP pipeline
- VGA/HDMI video output

---

# System Architecture

```mermaid
graph LR

A[Motion Sensor] --> C[Arduino Trigger FSM]
B[Light Sensor] --> C

C --> D[Tang Nano 20K FPGA]

D --> E[FIFO Reader]
E --> F[Bayer to RGB ISP]
F --> G[VGA/HDMI Output]
G --> H[PC Monitor]
```

---

# Main FSM

```mermaid
stateDiagram-v2

[*] --> IDLE

IDLE --> WAIT_TRIGGER
WAIT_TRIGGER --> CAMERA_CAPTURE
CAMERA_CAPTURE --> READ_FIFO
READ_FIFO --> ISP_PROCESS
ISP_PROCESS --> DISPLAY
DISPLAY --> IDLE

READ_FIFO --> ERROR
ISP_PROCESS --> ERROR
ERROR --> IDLE
```

---

# Planned Modules

## RTL
- main_fsm.v
- bayer_to_rgb.v
- image_generator.v
- vga_controller.v

## Testbenches
- main_fsm_tb.v
- bayer_to_rgb_tb.v

---

# Project Goals

- Real-time image streaming
- FPGA ISP pipeline
- Bayer RAW processing
- HDMI/VGA timing generation
- Sensor-triggered image capture
- Modular FPGA architecture