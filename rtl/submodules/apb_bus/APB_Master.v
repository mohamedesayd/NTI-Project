/*
//////////////////////////////////////////////////////////////////////////////// 
// Author: Hatem Essam 
// Course: NTI HireReady Digital IC 
// 
// Description: AMBA BUS -> APB Master (The Requester)  
// Referance : ARM AMBA APB Protocol Specification-> https://support.arm.com/architectures/amba
//
//////////////////////////////////////////////////////////////////////////////// 

This is a Master APB with "core interface" which is connected to controller like Bridge, 
and Standard Interface which connect to the Slave (The Completer)

we can use "address phase" exchangeably with "SETUP" state, and "data phase" with "ACCESS" in the comments.
*/



module APB_Master #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32 // can be 8 bits, 16 bits, or 32 bits wide.
)(
    // System Signals
    input  wire                  PCLK,
    input  wire                  rst_n,

    // Core Interface (User Request or testbench)
    input  wire                  i_req,      // Start transaction request
    input  wire                  i_write,    // 1 = Write, 0 = Read
    input  wire [ADDR_WIDTH-1:0] i_addr,     // Target address
    input  wire [DATA_WIDTH-1:0] i_wdata,    // Write data    
    
    output reg  [DATA_WIDTH-1:0] o_rdata,    // Read data response
    output reg                   o_ready,    // Transaction completed indicator
    output reg                   o_slverr,   // Transaction error response
    output wire                  o_gnt,      // Transaction request granted indicator

 
    // APB Bus Interface
    output reg  [ADDR_WIDTH-1:0] PADDR, // address bus.
    output reg                   PWRITE, //Low is Read, High is write
    output reg                   PSEL_MEM, //PSELx signal for each Completer
    output reg                   PENABLE, //High during data phase, Low during address phase
    output reg  [DATA_WIDTH-1:0] PWDATA, //Write data.The PWDATA write data bus is driven by the APB bridge Requester during write cycles when PWRITE is HIGH. 
    input  wire [DATA_WIDTH-1:0] PRDATA, //master read data if High
    input  wire                  PREADY, //Signal from the Completer , High then ready for the transfer.
    input  wire                  PSLVERR //optional signal: Optional for output ports, mandatory for inputs, High is an ERROR!
);

    // State Encoding
    localparam IDLE   = 2'b00;
    localparam SETUP  = 2'b01;
    localparam ACCESS = 2'b10;
    localparam INVALID = 2'b11;

    reg [1:0] current_state, next_state;

    // Registers to latch inputs during transaction
    reg [ADDR_WIDTH-1:0] addr_reg;
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg                  write_reg;


    // Latch inputs on request
    always @(posedge PCLK or negedge rst_n) begin
        if (~rst_n) begin
            addr_reg  <= {ADDR_WIDTH{1'b0}};
            wdata_reg <= {DATA_WIDTH{1'b0}};
            write_reg <= 1'b0;
        end else if (i_req) begin
            addr_reg  <= i_addr;
            wdata_reg <= i_wdata;
            write_reg <= i_write;
        end
    end

  
    // -------------------------------------------------------------
    // Block 1: State Register (Sequential Logic)
    // -------------------------------------------------------------
    always @(posedge PCLK or negedge rst_n) begin
        if (~rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // -------------------------------------------------------------
    // Block 2: Next State Logic (Combinational Logic)
    // -------------------------------------------------------------
    always @(*) begin
        //next_state = current_state;
        case (current_state)
            IDLE: begin
                if (i_req)
                    next_state = SETUP;
                else
                    next_state = IDLE;
            end

            SETUP: begin
                // SETUP always transfers directly to ACCESS in APB protocol
                //The interface only remains in the SETUP state for one clock cycle and 
                //always moves to the ACCESS state on the next rising edge of the clock.
                next_state = ACCESS;
            end

            ACCESS: begin
                if (PREADY) begin
                    next_state = IDLE;
                end else begin
                    next_state = ACCESS;   // Wait state
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------
    // Block 3: Output Logic (Combinational Logic)
    // -------------------------------------------------------------
    always @(*) begin
        // Safe defaults to prevent inferred latches
        PSEL_MEM = 1'b0;
        PENABLE  = 1'b0;
        PADDR    = addr_reg;
        PWDATA   = wdata_reg;
        PWRITE   = write_reg;
        o_rdata  = {DATA_WIDTH{1'b0}};
        o_ready  = 1'b0;
        o_slverr = 1'b0;

        case (current_state)
            IDLE: begin
                PSEL_MEM = 1'b0;
                PENABLE  = 1'b0;
            end

            SETUP: begin
                PSEL_MEM = 1'b1;
                PENABLE  = 1'b0;
                PADDR    = addr_reg;
                PWDATA   = wdata_reg;
                PWRITE   = write_reg;
            end

            ACCESS: begin
                PSEL_MEM = 1'b1;
                PENABLE  = 1'b1;
                PADDR    = addr_reg;
                PWDATA   = wdata_reg;
                PWRITE   = write_reg;
                if (PREADY && !write_reg)
                    o_rdata = PRDATA;
            end

            default: begin
                PSEL_MEM = 1'b0;
                PENABLE  = 1'b0;
            end
        endcase

        // Only signal completion when in the true ACCESS phase
        o_ready  = (current_state == ACCESS) && PREADY;
        o_slverr = PSLVERR;
    end

    // Grant: ready to accept a new request when IDLE, or
    // at the end of ACCESS (last cycle before returning to IDLE)
    assign o_gnt = (current_state == IDLE) || (current_state == ACCESS && PREADY);

endmodule