// ============================================================
// CPU Arbiter - OBI to APB Bridge
//
// Arbitrates between the CV32E40P instruction and data buses.
// Data bus has priority over instruction bus.
//
// Key protocol requirements (OBI):
//   - A request is accepted when both req and gnt are high.
//   - rvalid arrives some cycles after gnt (non-zero latency).
//   - The CPU may have at most one outstanding request per bus.
//
// Since the APB path is non-pipelined (one request at a time),
// we track one in-flight transaction and stall new grants until
// o_ready (PREADY) fires for the pending transaction.
// ============================================================
module cpu_arbiter (
    input        clk_i,
    input        rst_ni,

    // CPU Instruction Interface (OBI)
    input             instr_req_i,
    output reg        instr_gnt_o,
    output reg        instr_rvalid_o,
    input      [31:0] instr_addr_i,
    output reg [31:0] instr_rdata_o,

    // CPU Data Interface (OBI)
    input             data_req_i,
    output reg        data_gnt_o,
    output reg        data_rvalid_o,
    input             data_we_i,
    input   [3:0]     data_be_i,
    input   [31:0]    data_addr_i,
    input   [31:0]    data_wdata_i,
    output reg [31:0] data_rdata_o,

    // APB Master Core Interface
    output  reg        i_req,
    output  reg        i_write,
    output  reg [9:0]  i_addr,
    output  reg [31:0] i_wdata,

    input wire [31:0]  o_rdata,
    input wire         o_ready,
    input wire         o_slverr,
    input wire         o_gnt
);

    // -------------------------------------------------------
    // State: which bus is currently in-flight?
    // -------------------------------------------------------
    localparam BUS_NONE  = 2'b00;
    localparam BUS_INSTR = 2'b01;
    localparam BUS_DATA  = 2'b10;

    reg [1:0] in_flight;   // which bus has a pending transaction

    // -------------------------------------------------------
    // Combinational arbitration / APB request mux
    // -------------------------------------------------------
    always @(*) begin
        // Safe defaults
        i_req        = 1'b0;
        i_write      = 1'b0;
        i_addr       = 10'b0;
        i_wdata      = 32'b0;
        instr_gnt_o  = 1'b0;
        data_gnt_o   = 1'b0;

        if (in_flight == BUS_NONE) begin
            // APB bus is free — can accept a new request
            if (data_req_i) begin
                // Data has priority
                i_req   = 1'b1;
                i_write = data_we_i;
                i_addr  = data_addr_i[11:2];
                i_wdata = data_wdata_i;
                data_gnt_o = o_gnt;   // granted when APB master accepts
            end else if (instr_req_i) begin
                i_req   = 1'b1;
                i_write = 1'b0;
                i_addr  = instr_addr_i[11:2];
                i_wdata = 32'b0;
                instr_gnt_o = o_gnt;  // granted when APB master accepts
            end
        end
        // While in_flight != NONE, stall both buses (gnt=0)
    end

    // -------------------------------------------------------
    // Sequential: track in-flight bus, route rvalid/rdata
    // -------------------------------------------------------
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            in_flight      <= BUS_NONE;
            instr_rvalid_o <= 1'b0;
            data_rvalid_o  <= 1'b0;
            instr_rdata_o  <= 32'b0;
            data_rdata_o   <= 32'b0;
        end else begin
            // Clear rvalid pulses every cycle (one-cycle pulses only)
            instr_rvalid_o <= 1'b0;
            data_rvalid_o  <= 1'b0;

            if (in_flight == BUS_NONE) begin
                // Latch which bus got granted this cycle
                if (data_req_i && o_gnt) begin
                    in_flight <= BUS_DATA;
                end else if (instr_req_i && o_gnt) begin
                    in_flight <= BUS_INSTR;
                end
            end else if (o_ready) begin
                // Transaction complete — deliver result and free the bus
                if (in_flight == BUS_INSTR) begin
                    instr_rvalid_o <= 1'b1;
                    instr_rdata_o  <= o_rdata;
                end else if (in_flight == BUS_DATA) begin
                    data_rvalid_o <= 1'b1;
                    data_rdata_o  <= o_rdata;
                end
                in_flight <= BUS_NONE;
            end
        end
    end

endmodule
