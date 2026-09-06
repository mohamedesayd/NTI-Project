`timescale 1ns/1ps

module uart_reg_file #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [31:0]           wr_data,
    input  wire                  write_enable,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [31:0]           rd_data,
    input  wire                  clear_int,
    output wire                  interrupt,
    output wire [7:0]            tx_data,
    output wire                  valid_tx,
    input  wire                  tx_busy,
    input  wire [7:0]             rx_data,
    input  wire                   valid_rx,
    input  wire                   parity_error,
    input  wire                   framing_error,
    output wire                  parity_enable,
    output wire                  parity_type,
    output wire [5:0]            prescale
);


    localparam [ADDR_WIDTH-1:0] TX_ADDR     = 4'h0;
    localparam [ADDR_WIDTH-1:0] RX_ADDR     = 4'h4;
    localparam [ADDR_WIDTH-1:0] CTRL_ADDR   = 4'h8;
    localparam [ADDR_WIDTH-1:0] STATUS_ADDR = 4'hC;

    reg [31:0] tx_reg;
    reg [31:0] ctrl_reg;
    reg [7:0]  rx_reg;
    reg        rx_valid_reg;
    reg        interrupt_reg;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            tx_reg <= 32'b0;
        end

        else if (write_enable && (wr_addr == TX_ADDR)) begin
            tx_reg[7:0] <= wr_data[7:0];
        end

    end


    assign tx_data = tx_reg[7:0];


    assign valid_tx =
            write_enable &&
            (wr_addr == TX_ADDR);



    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            rx_reg       <= 8'b0;
            rx_valid_reg <= 1'b0;
        end

        else begin

            // New received byte
            if (valid_rx) begin
                rx_reg       <= rx_data;
                rx_valid_reg <= 1'b1;
            end

            // CPU reads RX register
            else if (rd_addr == RX_ADDR) begin
                rx_valid_reg <= 1'b0;
            end

        end

    end



    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            ctrl_reg <= 32'b0;
        end

        else if (write_enable && (wr_addr == CTRL_ADDR)) begin
            ctrl_reg <= wr_data;
        end

    end


    assign parity_enable = ctrl_reg[0];

    assign parity_type   = ctrl_reg[1];

    assign prescale      = ctrl_reg[7:2];


    wire rx_interrupt_enable;

    assign rx_interrupt_enable = ctrl_reg[8];



    wire [31:0] status_reg;

    assign status_reg = {
        28'b0,
        framing_error,
        parity_error,
        rx_valid_reg,
        tx_busy
    };


    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            interrupt_reg <= 1'b0;
        end

        else if (clear_int) begin
            interrupt_reg <= 1'b0;
        end

        else if (valid_rx && rx_interrupt_enable) begin
            interrupt_reg <= 1'b1;
        end

    end


    assign interrupt = interrupt_reg;

    always @(*) begin

        case (rd_addr)

            TX_ADDR: begin

                rd_data = {
                    23'b0,
                    tx_busy,
                    tx_reg[7:0]
                };

            end


            RX_ADDR: begin

                rd_data = {
                    23'b0,
                    rx_valid_reg,
                    rx_reg
                };

            end

            CTRL_ADDR: begin

                rd_data = ctrl_reg;

            end


            STATUS_ADDR: begin

                rd_data = status_reg;

            end

            default: begin

                rd_data = 32'b0;

            end

        endcase

    end

endmodule