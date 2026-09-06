`timescale 1ns / 1ps

module risc_v_based_soc_tb;

    reg clk;
    reg rst_n;
    reg RX_IN;
    wire TX_OUT;

    // ── DUT ───────────────────────────────────────────────────────────────────
    risc_v_based_soc #(
        .boot_addr_i(32'h0000_0000),
        .mtvec_addr_i(32'h0000_0080)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .RX_IN (RX_IN),
        .TX_OUT(TX_OUT)
    );

    // ── Clock (10 MHz → 100 ns period) ────────────────────────────────────────
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ── Reset ─────────────────────────────────────────────────────────────────
    initial begin
        $display("");
        $display("==================================================");
        $display("   RISC-V SoC Matrix Multiply Simulation");
        $display("==================================================");
        rst_n = 0;
        RX_IN = 1;          // UART RX idle high
        #100;
        rst_n = 1;
        $display("[TB] Reset released at %0t ns", $time);
        $display("[TB] CPU fetching instructions…");

        // Safety timeout
        #5000000;
        $display("[TB] TIMEOUT at %0t ns — simulation did not complete.", $time);
        $finish;
    end

    // ── UART character monitor ─────────────────────────────────────────────────
    // Monitor APB writes to the UART slave (PSEL_UART & PENABLE & PWRITE & PREADY)
    string uart_msg = "";

    always @(posedge clk) begin
        if (dut.PENABLE && dut.PWRITE && dut.PREADY && dut.PSEL_UART) begin
            automatic reg [7:0] ch = dut.PWDATA[7:0];

            if (ch == 8'h0A) begin    // LF → end of message
                $display("");
                $display("==================================================");
                $display("   [UART OUTPUT]  \"%s\"", uart_msg);
                if (uart_msg == "Test Pass") begin
                    $display("   RESULT  >>> TEST PASSED <<<");
                    $display("   SW and HW matrix multiply results MATCH.");
                end else begin
                    $display("   RESULT  >>> TEST FAILED <<<");
                    $display("   SW and HW matrix multiply results DO NOT MATCH.");
                end
                $display("==================================================");
                $display("");
                #50;
                $finish;
            end else if (ch != 8'h0D) begin   // ignore CR
                uart_msg = {uart_msg, string'(ch)};
            end
        end
    end

endmodule
