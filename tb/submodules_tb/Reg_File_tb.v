`timescale 1ns/1ps

module uart_reg_file_tb;


    parameter ADDR_WIDTH = 4;


    reg                     clk;
    reg                     rst_n;

    reg  [ADDR_WIDTH-1:0]   wr_addr;
    reg  [31:0]             wr_data;
    reg                     write_enable;

    reg  [ADDR_WIDTH-1:0]   rd_addr;
    wire [31:0]             rd_data;

    reg                     clear_int;
    wire                    interrupt;

    wire [7:0]              tx_data;
    wire                    valid_tx;
    reg                     tx_busy;

    reg  [7:0]              rx_data;
    reg                     valid_rx;
    reg                     parity_error;
    reg                     framing_error;

    wire                    parity_enable;
    wire                    parity_type;
    wire [5:0]              prescale;



    uart_reg_file #(
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    dut (
        .clk            (clk),
        .rst_n          (rst_n),

        .wr_addr        (wr_addr),
        .wr_data        (wr_data),
        .write_enable   (write_enable),

        .rd_addr        (rd_addr),
        .rd_data        (rd_data),

        .clear_int      (clear_int),
        .interrupt      (interrupt),

        .tx_data        (tx_data),
        .valid_tx       (valid_tx),
        .tx_busy        (tx_busy),

        .rx_data        (rx_data),
        .valid_rx       (valid_rx),
        .parity_error   (parity_error),
        .framing_error  (framing_error),

        .parity_enable  (parity_enable),
        .parity_type    (parity_type),
        .prescale       (prescale)
    );



    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;

    end



    integer errors;



    task apb_write;

        input [ADDR_WIDTH-1:0] address;
        input [31:0] data;

        begin

            @(negedge clk);

            wr_addr      = address;
            wr_data      = data;
            write_enable = 1'b1;

            @(posedge clk);

            #1;

            write_enable = 1'b0;
            wr_addr      = 4'b0;
            wr_data      = 32'b0;

        end

    endtask



    task apb_read;

        input [ADDR_WIDTH-1:0] address;
        output [31:0] data;

        begin

            @(negedge clk);

            rd_addr = address;

            #1;

            data = rd_data;

            @(posedge clk);

            rd_addr = 4'b0;

        end

    endtask


    task check;

        input [31:0] actual;
        input [31:0] expected;
        input [255:0] message;

        begin

            if (actual !== expected) begin

                $display("ERROR: %s", message);
                $display("       Expected = %h", expected);
                $display("       Actual   = %h", actual);

                errors = errors + 1;

            end

            else begin

                $display("PASS: %s = %h",
                         message,
                         actual);

            end

        end

    endtask



    reg [31:0] read_value;


    initial begin


        errors = 0;

        rst_n          = 1'b0;

        wr_addr        = 4'b0;
        wr_data        = 32'b0;
        write_enable   = 1'b0;

        rd_addr        = 4'b0;

        clear_int      = 1'b0;

        tx_busy        = 1'b0;

        rx_data        = 8'b0;
        valid_rx       = 1'b0;

        parity_error   = 1'b0;
        framing_error  = 1'b0;


        $display("");
        $display("==============================================");
        $display("RESET TEST");
        $display("==============================================");

        #20;

        rst_n = 1'b1;

        #10;


        //==============================================
        // TEST 1
        // DEFAULT TX REGISTER
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 1: DEFAULT TX REGISTER");
        $display("==============================================");

        apb_read(4'h0, read_value);

        check(
            read_value,
            32'h00000000,
            "TX register after reset"
        );


        //==============================================
        // TEST 2
        // DEFAULT CONTROL REGISTER
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 2: DEFAULT CONTROL REGISTER");
        $display("==============================================");

        apb_read(4'h8, read_value);

        check(
            read_value,
            32'h00000000,
            "CONTROL register after reset"
        );


        //==============================================
        // TEST 3
        // WRITE TX
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 3: TX WRITE");
        $display("==============================================");

        apb_write(
            4'h0,
            32'h000000A5
        );

        #1;

        check(
            tx_data,
            8'hA5,
            "TX data after write"
        );


        //==============================================
        // TEST 4
        // TX VALID
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 4: TX VALID");
        $display("==============================================");

        @(negedge clk);

        wr_addr      = 4'h0;
        wr_data      = 32'h0000005A;
        write_enable = 1'b1;

        #1;

        if (valid_tx !== 1'b1) begin

            $display("ERROR: valid_tx should be HIGH during TX write");

            errors = errors + 1;

        end

        else begin

            $display("PASS: valid_tx is HIGH during TX write");

        end

        @(posedge clk);

        #1;

        write_enable = 1'b0;


        //==============================================
        // TEST 5
        // TX DATA AFTER SECOND WRITE
        //==============================================

        check(
            tx_data,
            8'h5A,
            "TX data after second write"
        );


        //==============================================
        // TEST 6
        // TX BUSY STATUS
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 6: TX BUSY");
        $display("==============================================");

        tx_busy = 1'b1;

        #1;

        apb_read(4'h0, read_value);

        check(
            read_value[8],
            1'b1,
            "TX busy bit"
        );

        tx_busy = 1'b0;


       //==============================================
// TEST 7: CONTROL REGISTER
//==============================================

$display("");
$display("==============================================");
$display("TEST 7: CONTROL REGISTER");
$display("==============================================");



apb_write(
    4'h8,
    32'h00000167
);

#1;

check(
    parity_enable,
    1'b1,
    "Parity enable"
);

check(
    parity_type,
    1'b1,
    "Parity type"
);

check(
    prescale,
    6'd25,
    "Prescale"
);

apb_read(4'h8, read_value);

check(
    read_value,
    32'h00000167,
    "CONTROL register readback"
);


        //==============================================
        // TEST 8
        // CONTROL READ
        //==============================================

        apb_read(4'h8, read_value);

        check(
            read_value,
            32'h00000167,
            "CONTROL register readback"
        );


        //==============================================
        // TEST 9
        // RX EVENT
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 9: RX EVENT");
        $display("==============================================");

        @(negedge clk);

        rx_data  = 8'h3C;
        valid_rx = 1'b1;

        @(posedge clk);

        #1;

        valid_rx = 1'b0;

        check(
            dut.rx_reg,
            8'h3C,
            "RX data stored"
        );

        check(
            dut.rx_valid_reg,
            1'b1,
            "RX valid flag set"
        );


        //==============================================
        // TEST 10
        // RX REGISTER READ
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 10: RX REGISTER READ");
        $display("==============================================");

        apb_read(4'h4, read_value);

        check(
            read_value[7:0],
            8'h3C,
            "RX data read"
        );

        check(
            read_value[8],
            1'b1,
            "RX valid during read"
        );


        // Allow read-to-clear to happen
        @(posedge clk);

        #1;

        check(
            dut.rx_valid_reg,
            1'b0,
            "RX valid cleared after RX read"
        );


//==============================================
// TEST 11: RX INTERRUPT
//==============================================

$display("");
$display("==============================================");
$display("TEST 11: RX INTERRUPT");
$display("==============================================");

@(negedge clk);

rx_data  = 8'h55;
valid_rx = 1'b1;

@(posedge clk);

#1;

valid_rx = 1'b0;

check(
    interrupt,
    1'b1,
    "RX interrupt generated"
);


// Consume RX data.
// This also clears RX_VALID.

apb_read(
    4'h4,
    read_value
);

check(
    read_value[7:0],
    8'h55,
    "RX data consumed"
);


        //==============================================
        // TEST 12
        // INTERRUPT IS STICKY
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 12: STICKY INTERRUPT");
        $display("==============================================");

        repeat (3) @(posedge clk);

        check(
            interrupt,
            1'b1,
            "Interrupt remains HIGH"
        );


        //==============================================
        // TEST 13
        // CLEAR INTERRUPT
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 13: CLEAR INTERRUPT");
        $display("==============================================");

        @(negedge clk);

        clear_int = 1'b1;

        @(posedge clk);

        #1;

        clear_int = 1'b0;

        check(
            interrupt,
            1'b0,
            "Interrupt cleared"
        );


        //==============================================
        // TEST 14
        // PARITY ERROR
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 14: PARITY ERROR");
        $display("==============================================");

        parity_error = 1'b1;

        #1;

        apb_read(4'hC, read_value);

        check(
            read_value[2],
            1'b1,
            "Parity error status"
        );

        parity_error = 1'b0;


        //==============================================
        // TEST 15
        // FRAMING ERROR
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 15: FRAMING ERROR");
        $display("==============================================");

        framing_error = 1'b1;

        #1;

        apb_read(4'hC, read_value);

        check(
            read_value[3],
            1'b1,
            "Framing error status"
        );

        framing_error = 1'b0;


        //==============================================
        // TEST 16
        // STATUS REGISTER
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 16: STATUS REGISTER");
        $display("==============================================");

        tx_busy       = 1'b1;
        parity_error  = 1'b1;
        framing_error = 1'b1;

        // RX valid should currently be 0

        #1;

        apb_read(4'hC, read_value);

        check(
            read_value[3:0],
            4'b1101,
            "STATUS register"
        );

        tx_busy       = 1'b0;
        parity_error  = 1'b0;
        framing_error = 1'b0;


        //==============================================
        // TEST 17
        // RX INTERRUPT DISABLED
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 17: INTERRUPT DISABLED");
        $display("==============================================");

        // Disable RX interrupt
        apb_write(
            4'h8,
            32'h00000067
        );

        // Clear any previous interrupt
        @(negedge clk);

        clear_int = 1'b1;

        @(posedge clk);

        #1;

        clear_int = 1'b0;


        // Receive byte

        @(negedge clk);

        rx_data  = 8'hAA;
        valid_rx = 1'b1;

        @(posedge clk);

        #1;

        valid_rx = 1'b0;

        check(
            interrupt,
            1'b0,
            "No interrupt when interrupt enable is disabled"
        );


        //==============================================
        // TEST 18
        // RX INTERRUPT ENABLED
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 18: INTERRUPT ENABLED");
        $display("==============================================");

        // Enable RX interrupt
        apb_write(
            4'h8,
            32'h00000167
        );

        // Read RX to clear RX valid
        apb_read(4'h4, read_value);

        // Receive another byte

        @(negedge clk);

        rx_data  = 8'hBB;
        valid_rx = 1'b1;

        @(posedge clk);

        #1;

        valid_rx = 1'b0;

        check(
            interrupt,
            1'b1,
            "Interrupt generated when enabled"
        );


        //==============================================
        // TEST 19
        // INVALID ADDRESS
        //==============================================

        $display("");
        $display("==============================================");
        $display("TEST 19: INVALID ADDRESS");
        $display("==============================================");

        apb_read(
            4'h2,
            read_value
        );

        check(
            read_value,
            32'h00000000,
            "Invalid address returns zero"
        );


        //==============================================
        // FINAL RESULT
        //==============================================

        $display("");
        $display("==============================================");

        if (errors == 0) begin

            $display("ALL TESTS PASSED");

        end

        else begin

            $display("TEST FAILED");
            $display("Number of errors = %0d", errors);

        end

        $display("==============================================");
        $display("");

        #20;

        $finish;

    end


    //==================================================
    // MONITOR
    //==================================================

initial begin

    $monitor(
        "TIME=%0t | WE=%b | WR_ADDR=%h | WR_DATA=%h | RD_ADDR=%h | RD_DATA=%h | TX_DATA=%h | VALID_TX=%b | TX_BUSY=%b | RX_DATA=%h | VALID_RX=%b | INT=%b",
        $time,
        write_enable,
        wr_addr,
        wr_data,
        rd_addr,
        rd_data,
        tx_data,
        valid_tx,
        tx_busy,
        rx_data,
        valid_rx,
        interrupt
    );

end

endmodule