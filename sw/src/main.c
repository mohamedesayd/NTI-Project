/*
 * ============================================================================
 * RISC-V System-on-Chip Matrix Multiplication Test Firmware
 * ============================================================================
 * 1. Receives Matrix A and Matrix B elements over UART RX (Interrupt-driven).
 * 2. Computes Matrix C_SW = A * B using CPU Software loops.
 * 3. Configures MAC Accelerator via APB bus to compute C_HW.
 * 4. Waits for MAC Done Interrupt.
 * 5. Compares C_SW with C_HW.
 * 6. Transmits "Test Pass" or "Test Fail" over UART TX.
 * ============================================================================
 */

#include <stdint.h>

// ------------------------------------------------------------
// Peripheral & Memory Addresses
// ------------------------------------------------------------
#define RAM_BASE_A       ((volatile uint32_t *) 0x00000040)
#define RAM_BASE_B       ((volatile uint32_t *) 0x00000050)
#define RAM_BASE_C_SW    ((volatile uint32_t *) 0x00000060)
#define RAM_BASE_C_HW    ((volatile uint32_t *) 0x00000070)

// MAC Accelerator APB Register Map
#define MAC_REG_A_BASE   (*(volatile uint32_t *) 0x00000100)
#define MAC_REG_B_BASE   (*(volatile uint32_t *) 0x00000104)
#define MAC_REG_C_BASE   (*(volatile uint32_t *) 0x00000108)
#define MAC_REG_M_K_N    (*(volatile uint32_t *) 0x0000010C)
#define MAC_REG_CTRL     (*(volatile uint32_t *) 0x00000110)
#define MAC_REG_STATUS   (*(volatile uint32_t *) 0x00000114)

// UART Peripheral APB Register Map
#define UART_REG_DATA    (*(volatile uint32_t *) 0x00000200)
#define UART_REG_STATUS  (*(volatile uint32_t *) 0x00000204)
#define UART_REG_CTRL    (*(volatile uint32_t *) 0x00000208)

// Matrix Dimensions (2x2 matrices for demonstration)
#define MATRIX_M 2
#define MATRIX_K 2
#define MATRIX_N 2

// Global volatile flags updated inside ISR
volatile uint32_t g_mac_done_flag = 0;
volatile uint32_t g_uart_rx_count = 0;

// Function Prototypes
void uart_send_char(char c);
void uart_print_str(const char *str);
void isr_handler(void);

// ------------------------------------------------------------
// UART Helper Functions
// ------------------------------------------------------------
void uart_send_char(char c) {
    // Wait until UART TX is ready (bit 1 of status = 0)
    while (UART_REG_STATUS & 0x02);
    UART_REG_DATA = (uint32_t)c;
}

void uart_print_str(const char *str) {
    while (*str) {
        uart_send_char(*str++);
    }
}

// ------------------------------------------------------------
// Interrupt Service Routine (ISR)
// ------------------------------------------------------------
void isr_handler(void) {
    uint32_t mcause;
    
    // Read RISC-V Machine Cause Register
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));

    uint32_t irq_id = mcause & 0x1F;

    if (irq_id == 16) {
        // --- UART RX Interrupt ---
        uint32_t rx_val = UART_REG_DATA;
        
        // Store incoming matrix data into RAM
        if (g_uart_rx_count < (MATRIX_M * MATRIX_K)) {
            RAM_BASE_A[g_uart_rx_count] = rx_val;
        } else if (g_uart_rx_count < (MATRIX_M * MATRIX_K + MATRIX_K * MATRIX_N)) {
            uint32_t b_idx = g_uart_rx_count - (MATRIX_M * MATRIX_K);
            RAM_BASE_B[b_idx] = rx_val;
        }
        g_uart_rx_count++;

    } else if (irq_id == 17) {
        // --- MAC Done Interrupt ---
        g_mac_done_flag = 1;
    }
}

// ------------------------------------------------------------
// Main Application Entry Point
// ------------------------------------------------------------
int main(void) {
    uint32_t i, j, k;

    // 1. Enable UART RX Interrupts & CPU Global Interrupts
    UART_REG_CTRL = 0x01; // Enable RX IRQ
    __asm__ volatile ("csrs mstatus, 0x8"); // Set MIE bit in mstatus
    __asm__ volatile ("csrs mie, 0x70000"); // Enable IRQ bits 16, 17, 18 in mie

    // 2. Wait until all matrix elements (4 for A, 4 for B) are received over UART
    uint32_t total_expected = (MATRIX_M * MATRIX_K) + (MATRIX_K * MATRIX_N);
    while (g_uart_rx_count < total_expected) {
        // Waiting for UART RX Interrupts...
    }

    // 3. Software Matrix Multiplication: C_SW = A * B
    for (i = 0; i < MATRIX_M; i++) {
        for (j = 0; j < MATRIX_N; j++) {
            uint32_t sum = 0;
            for (k = 0; k < MATRIX_K; k++) {
                sum += RAM_BASE_A[i * MATRIX_K + k] * RAM_BASE_B[k * MATRIX_N + j];
            }
            RAM_BASE_C_SW[i * MATRIX_N + j] = sum;
        }
    }

    // 4. Configure Hardware MAC Accelerator via APB
    MAC_REG_A_BASE = 0x40; // RAM offset for A
    MAC_REG_B_BASE = 0x50; // RAM offset for B
    MAC_REG_C_BASE = 0x70; // RAM offset for HW result C
    MAC_REG_M_K_N  = (MATRIX_N << 8) | (MATRIX_K << 4) | (MATRIX_M);

    // Reset MAC Done Flag and trigger Start bit
    g_mac_done_flag = 0;
    MAC_REG_CTRL = 0x01; // START = 1

    // 5. Wait for MAC Done Interrupt
    while (!g_mac_done_flag) {
        // Waiting for irq_i[17]...
    }

    // 6. Compare C_SW vs C_HW Results
    uint32_t pass = 1;
    for (i = 0; i < (MATRIX_M * MATRIX_N); i++) {
        if (RAM_BASE_C_SW[i] != RAM_BASE_C_HW[i]) {
            pass = 0;
            break;
        }
    }

    // 7. Transmit Result String over UART TX
    if (pass) {
        uart_print_str("Test Pass\r\n");
    } else {
        uart_print_str("Test Fail\r\n");
    }

    // End of Execution Loop
    while (1);
    return 0;
}
