/*
////////////////////////////////////////////////////////////////////////////////
// Author: Hatem Essam
// Course: NTI HireReady Digital IC
//
// Description: AMBA APB Slave (The Completer)
// Reference  : ARM AMBA APB Protocol Specification
//
////////////////////////////////////////////////////////////////////////////////

APB Slave for a 1-cycle-latency synchronous RAM.

Protocol timing (3-state FSM):

  ST_IDLE   -- sees PSEL=1, PENABLE=0 (SETUP phase)  --> ST_WAIT
  ST_WAIT   -- master now drives PENABLE=1 (ACCESS)   --> ST_ACCESS
              RAM address was presented during SETUP;
              the synchronous RAM registered it on the
              posedge that ended SETUP, so read data is
              valid when we enter ST_WAIT.  One extra
              cycle (ST_WAIT) lets the data settle.
  ST_ACCESS -- PREADY=1, PRDATA=valid data            --> ST_IDLE

For WRITE transactions no wait state is needed; write data is
stable throughout SETUP+ACCESS and the RAM write-enable fires on
the ST_ACCESS cycle (when PENABLE=1).
*/

module APB_slave #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    // System Signals
    input  wire                  PCLK,
    input  wire                  rst_n,

    // Core Interface (forwarded to peripheral)
    output wire                  o_write_slave,
    output wire [ADDR_WIDTH-1:0] o_addr_slave,
    output wire [DATA_WIDTH-1:0] o_wdata_slave,
    input  wire [DATA_WIDTH-1:0] i_rdata_slave,

    // APB Bus Interface
    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire                  PWRITE,
    input  wire                  PSEL_MEM,
    input  wire                  PENABLE,
    input  wire [DATA_WIDTH-1:0] PWDATA,
    output reg  [DATA_WIDTH-1:0] PRDATA,
    output reg                   PREADY,
    output reg                   PSLVERR
);

    // State encoding
    localparam ST_IDLE   = 2'b00;
    localparam ST_WAIT   = 2'b01;   // 1 wait cycle for sync-RAM read
    localparam ST_ACCESS = 2'b10;   // PREADY=1, data valid

    reg [1:0] current_state, next_state;

    // Forward address and write data combinationally so the RAM
    // sees the address as early as possible (during SETUP).
    // Write strobe only fires when PENABLE=1 (ACCESS phase).
    assign o_addr_slave  = PADDR;
    assign o_wdata_slave = PWDATA;
    assign o_write_slave = PWRITE && PSEL_MEM && PENABLE;

    // ── State Register ────────────────────────────────────────────────────────
    always @(posedge PCLK or negedge rst_n) begin
        if (!rst_n)
            current_state <= ST_IDLE;
        else
            current_state <= next_state;
    end

    // ── Next-State Logic ──────────────────────────────────────────────────────
    always @(*) begin
        case (current_state)
            ST_IDLE: begin
                // Enter WAIT when master starts the SETUP phase
                if (PSEL_MEM && !PENABLE)
                    next_state = ST_WAIT;
                else
                    next_state = ST_IDLE;
            end

            ST_WAIT: begin
                // For reads: wait one cycle for the synchronous RAM output.
                // For writes: can skip to ACCESS directly (but one extra cycle
                //             is harmless and keeps the FSM uniform).
                next_state = ST_ACCESS;
            end

            ST_ACCESS: begin
                // PREADY=1 this cycle.
                // Check for back-to-back transactions.
                if (PSEL_MEM && !PENABLE)
                    next_state = ST_WAIT;   // new SETUP started
                else
                    next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // ── Output Logic ─────────────────────────────────────────────────────────
    always @(*) begin
        PREADY  = 1'b0;
        PRDATA  = {DATA_WIDTH{1'b0}};
        PSLVERR = 1'b0;

        case (current_state)
            ST_IDLE: begin
                PREADY = 1'b0;
            end

            ST_WAIT: begin
                // Hold PREADY low; RAM is stabilising read data.
                PREADY = 1'b0;
            end

            ST_ACCESS: begin
                // Transaction complete.
                PREADY  = 1'b1;
                PSLVERR = 1'b0;
                if (!PWRITE)
                    PRDATA = i_rdata_slave;   // RAM data now valid
            end

            default: begin
                PREADY  = 1'b0;
            end
        endcase
    end

endmodule