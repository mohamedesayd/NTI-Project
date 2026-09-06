module UART_SYSTEM #(
    parameter DATA_WIDTH = 8
)
(
    input  wire                     CLK,
    input  wire                     RST,

    // Register File / APB side
    input  wire                     write_enable,
    input  wire [DATA_WIDTH-1:0]    wr_addr,
    input  wire [31:0]              wr_data,

    input  wire [DATA_WIDTH-1:0]    rd_addr,
    output wire [31:0]              rd_data,

    // UART serial interface
    input  wire                     RX_IN,
    output wire                     TX_OUT,

    // Interrupt
    output wire                     INTERRUPT
);

wire [DATA_WIDTH-1:0] tx_data;
wire                  tx_valid;
wire                  tx_busy;

wire [DATA_WIDTH-1:0] rx_data;
wire                  rx_valid;

wire                  parity_enable;
wire                  parity_type;
wire [5:0]            prescale;

wire                  parity_error;
wire                  framing_error;

wire                  interrupt;


// ============================================================
// REGISTER FILE
// ============================================================

uart_reg_file #(
    .ADDR_WIDTH(4)
)
U0_REG_FILE
(
    .clk            (CLK),
    .rst_n          (RST),

    .write_enable   (write_enable),

    .wr_addr        (wr_addr[3:0]),
    .wr_data        (wr_data),

    .rd_addr        (rd_addr[3:0]),
    .rd_data        (rd_data),

    .clear_int      (1'b0),
    .tx_data        (tx_data),
    .valid_tx       (tx_valid),
    .tx_busy        (tx_busy),

    .rx_data        (rx_data),
    .valid_rx       (rx_valid),

    .parity_enable  (parity_enable),
    .parity_type    (parity_type),
    .prescale       (prescale),

    .parity_error   (parity_error),
    .framing_error  (framing_error),

    .interrupt      (interrupt)
);


// ============================================================
// UART
// ============================================================

UART #(
    .DATA_WIDTH(DATA_WIDTH)
)
U0_UART
(
    .RST            (RST),

    .TX_CLK         (CLK),
    .RX_CLK         (CLK),

    .RX_IN_S        (RX_IN),

    .RX_OUT_P       (rx_data),
    .RX_OUT_V       (rx_valid),

    .TX_IN_P        (tx_data),
    .TX_IN_V        (tx_valid),

    .TX_OUT_S       (TX_OUT),
    .TX_OUT_V       (tx_busy),

    .Prescale       (prescale),
    .parity_enable  (parity_enable),
    .parity_type    (parity_type),

    .parity_error   (parity_error),
    .framing_error  (framing_error)
);


// ============================================================
// INTERRUPT
// ============================================================

assign INTERRUPT = interrupt;

endmodule