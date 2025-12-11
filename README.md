# 8051 Programmable Stopwatch & Smart Alarm

## Project Overview
This project is a precision digital stopwatch developed in **8051 Assembly Language**. It runs on the DSM-51 architecture and features a custom-built, interrupt-driven architecture that handles real-time counting, display multiplexing, and user input simultaneously.

## Features
*   **Real-Time Precision:** Uses **Timer0 Interrupts** (50ms interval) for accurate timekeeping.
*   **Programmable Alarm:** Users can set a target alarm minute using a **Cursor Menu (UP/DOWN)** logic.
*   **Smart Buzzing:** Non-blocking sound generation using frequency toggling inside the ISR.
*   **Multiplexed Display:** Drives a 6-digit 7-segment display using dynamic scanning (`RL` instruction logic).
*   **Input Handling:** Features a robust **software debouncing** algorithm and "One-Shot" state machine to prevent button bouncing.

## Technical Details
*   **Language:** Assembly (ASM51)
*   **Hardware Target:** 8051 Microcontroller (DSM-51 Kit)
*   **Memory Management:** Uses Bit-Addressable RAM (`20H`) for status flags and DPTR for memory-mapped I/O.

## Controls
*   **Key 1:** Start / Pause (Auto-clears menu selection on Start)
*   **Key 2:** Reset System (Clears time and silences alarm)
*   **Key 3:** Cursor UP (Increases Alarm Minute)
*   **Key 4:** Cursor DOWN (Decreases Alarm Minute)

## How it Works
The system utilizes a dual-layer architecture:
1.  **Main Loop:** Handles the UI, including scanning the 7-segment display and processing user button inputs.
2.  **Timer Interrupt (ISR):** Runs in the background to count time and toggle the buzzer pin, ensuring the display never flickers even while the alarm is ringing.
