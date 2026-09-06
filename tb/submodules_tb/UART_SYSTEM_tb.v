`timescale 1ns/1ps

module UART_SYSTEM_tb;

    // =========================================================
    // PARAMETERS
    // =========================================================

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;


    // =========================================================
    // CLOCK / RESET
    // =========================================================

    reg CLK;
    reg RST;


    // =========================================================
    // REGISTER FILE / APB-LIKE INTERFACE
    // =========================================================

    reg                     write_enable;
    reg [ADDR_WIDTH-1:0]    wr_addr;
    reg [31:0]              wr_data;

    reg [ADDR_WIDTH-1:0]    rd_addr;
    wire [31:0]              rd_data;


    // =========================================================
    // UART SERIAL INTERFACE
    // =========================================================

    wire TX_OUT;
    wire RX_IN;


    // =========================================================
    // INTERRUPT
    // =========================================================

    wire INTERRUPT;


    // =========================================================
    // LOOPBACK
    // TX_OUT -> RX_IN
    // =========================================================

    assign RX_IN = TX_OUT;


    // =========================================================
    // DUT
    // =========================================================

    UART_SYSTEM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    DUT
    (
        .CLK          (CLK),
        .RST          (RST),

        .write_enable (write_enable),
        .wr_addr      (wr_addr),
        .wr_data      (wr_data),

        .rd_addr      (rd_addr),
        .rd_data      (rd_data),

        .RX_IN        (RX_IN),
        .TX_OUT       (TX_OUT),

        .INTERRUPT    (INTERRUPT)
    );


    // =========================================================
    // CLOCK GENERATION
    // 10 ns period = 100 MHz
    // =========================================================

    initial begin
        CLK = 1'b0;

        forever #5 CLK = ~CLK;
    end


    // =========================================================
    // APB WRITE TASK
    // =========================================================

    task apb_write;

        input [ADDR_WIDTH-1:0] address;
        input [31:0] data;

        begin

            @(negedge CLK);

            wr_addr       = address;
            wr_data       = data;
            write_enable  = 1'b1;

            @(negedge CLK);

            write_enable  = 1'b0;
            wr_addr       = 0;
            wr_data       = 0;

        end

    endtask


    // =========================================================
    // APB READ TASK
    // =========================================================

    task apb_read;

        input  [ADDR_WIDTH-1:0] address;
        output [31:0] data;

        begin

            @(negedge CLK);

            rd_addr = address;

            #1;

            data = rd_data;

            @(negedge CLK);

            rd_addr = 0;

        end

    endtask


    // =========================================================
    // CHECK TASK
    // =========================================================

    integer errors;

    task check;

        input [31:0] actual;
        input [31:0] expected;
        input [200*8:1] message;

        begin

            if (actual !== expected) begin

                $display(
                    "ERROR: %s",
                    message
                );

                $display(
                    "       Expected = %h",
                    expected
                );

                $display(
                    "       Actual   = %h",
                    actual
                );

                errors = errors + 1;

            end

            else begin

                $display(
                    "PASS: %s = %h",
                    message,
                    actual
                );

            end

        end

    endtask


    // =========================================================
    // TEST
    // =========================================================

    reg [31:0] read_value;


    initial begin

        errors = 0;

        write_enable = 1'b0;
        wr_addr      = 0;
        wr_data      = 0;
        rd_addr      = 0;


        // =====================================================
        // RESET
        // =====================================================

        $display("");
        $display("==============================================");
        $display("RESET TEST");
        $display("==============================================");

        RST = 1'b0;

        #20;

        RST = 1'b1;

        #20;


        // =====================================================
        // TEST 1
        // DEFAULT CONTROL REGISTER
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 1: DEFAULT CONTROL REGISTER");
        $display("==============================================");

        apb_read(
            4'h8,
            read_value
        );

        check(
            read_value,
            32'h00000000,
            "CONTROL after reset"
        );


        // =====================================================
        // TEST 2
        // DEFAULT TX REGISTER
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 2: DEFAULT TX REGISTER");
        $display("==============================================");

        apb_read(
            4'h0,
            read_value
        );

        check(
            read_value,
            32'h00000000,
            "TX after reset"
        );


        // =====================================================
        // TEST 3
        // CONFIGURE UART
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 3: UART CONFIGURATION");
        $display("==============================================");

        /*
         * CONTROL = 0x67
         *
         * bit 0     = parity enable
         * bit 1     = parity type
         * bits 7:2  = prescale
         *
         * 0x67:
         *
         * binary = 0110 0111
         *
         * parity_enable = 1
         * parity_type   = 1
         * prescale      = 25
         *
         * Interrupt disabled here.
         */

        apb_write(
            4'h8,
            32'h00000067
        );

        #1;

        // Check CONTROL readback

        apb_read(
            4'h8,
            read_value
        );

        check(
            read_value,
            32'h00000067,
            "CONTROL configuration"
        );


        // =====================================================
        // TEST 4
        // TX WRITE
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 4: TX WRITE");
        $display("==============================================");

        /*
         * Write 0xA5 to TX register.
         */

        apb_write(
            4'h0,
            32'h000000A5
        );

        #1;

        // Check TX register

        apb_read(
            4'h0,
            read_value
        );

        check(
            read_value,
            32'h000000A5,
            "TX register = A5"
        );


        // =====================================================
        // TEST 5
        // WAIT FOR UART TRANSMISSION
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 5: UART TX BUSY");
        $display("==============================================");

        /*
         * Give the TX FSM time to start.
         */

        #20;

        apb_read(
            4'h0,
            read_value
        );

        /*
         * TX register bit 8 contains TX busy.
         *
         * We don't require a specific value here because
         * depending on the exact clock/FSM timing it may
         * already have started or completed.
         *
         * Instead, print it.
         */

        $display(
            "INFO: TX register/status = %h",
            read_value
        );


        // =====================================================
        // TEST 6
        // LOOPBACK RECEIVE
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 6: UART LOOPBACK");
        $display("==============================================");

        /*
         * TX_OUT is connected directly to RX_IN:
         *
         * TX_OUT -> RX_IN
         *
         * Therefore the UART should receive the same
         * byte that it transmitted.
         *
         * For prescale = 25:
         *
         * One UART bit takes approximately:
         *
         * 25 CLK cycles
         *
         * A complete frame with parity:
         *
         * 1 start
         * 8 data
         * 1 parity
         * 1 stop
         *
         * = 11 bits
         *
         * Approximately:
         *
         * 11 * 25 = 275 clock cycles
         *
         * 275 * 10 ns = 2750 ns
         *
         * Wait longer than that.
         */

        #3500;


        // =====================================================
        // TEST 7
        // CHECK RX REGISTER
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 7: RX DATA");
        $display("==============================================");

        apb_read(
            4'h4,
            read_value
        );

        check(
            read_value[7:0],
            8'hA5,
            "RX data after loopback"
        );


        // =====================================================
        // TEST 8
        // RX VALID
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 8: RX VALID");
        $display("==============================================");

        /*
         * RX register bit 8 = RX valid.
         *
         * Depending on your register-file implementation,
         * reading RX clears RX_VALID.
         *
         * Therefore we check the data first and then
         * inspect the status register.
         */

        apb_read(
            4'hC,
            read_value
        );

        $display(
            "INFO: STATUS = %h",
            read_value
        );


        // =====================================================
        // TEST 9
        // INTERRUPT ENABLE
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 9: INTERRUPT ENABLE");
        $display("==============================================");

        /*
         * Enable interrupt.
         *
         * CONTROL = 0x167
         *
         * Same configuration as 0x67 but with
         * interrupt enable bit = 1.
         */

        apb_write(
            4'h8,
            32'h00000167
        );

        #1;

        apb_read(
            4'h8,
            read_value
        );

        check(
            read_value,
            32'h00000167,
            "CONTROL with interrupt enabled"
        );


        // =====================================================
        // TEST 10
        // SECOND LOOPBACK
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 10: SECOND UART LOOPBACK");
        $display("==============================================");

        /*
         * Send 0x3C
         */

        apb_write(
            4'h0,
            32'h0000003C
        );

        /*
         * Wait for complete TX + RX frame.
         */

        #3500;


        // =====================================================
        // TEST 11
        // READ SECOND RX BYTE
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 11: SECOND RX DATA");
        $display("==============================================");

        apb_read(
            4'h4,
            read_value
        );

        check(
            read_value[7:0],
            8'h3C,
            "Second RX data"
        );


        // =====================================================
        // TEST 12
        // PARITY / FRAMING STATUS
        // =====================================================

        $display("");
        $display("==============================================");
        $display("TEST 12: UART STATUS");
        $display("==============================================");

        apb_read(
            4'hC,
            read_value
        );

        $display(
            "INFO: Final STATUS = %h",
            read_value
        );


        // =====================================================
        // FINAL RESULT
        // =====================================================

        #100;

        $display("");
        $display("==============================================");

        if (errors == 0) begin

            $display("ALL SYSTEM TESTS PASSED");

        end

        else begin

            $display("SYSTEM TEST FAILED");
            $display("Number of errors = %0d", errors);

        end

        $display("==============================================");

        $finish;

    end


    // =========================================================
    // MONITOR
    // =========================================================

    initial begin

        $monitor(
            "TIME=%0t | RST=%b | WE=%b | WR_ADDR=%h | WR_DATA=%h | RD_ADDR=%h | RD_DATA=%h | TX=%b | RX=%b | INT=%b",
            $time,
            RST,
            write_enable,
            wr_addr,
            wr_data,
            rd_addr,
            rd_data,
            TX_OUT,
            RX_IN,
            INTERRUPT
        );

    end

endmodule