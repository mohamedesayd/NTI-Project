module Comp_Decoder (
    addr, PSELx, PRDATA, PREADY, PSLVERR, PRDATA_MEM, PREADY_MEM, PSLVERR_MEM,
    PRDATA_MULT, PREADY_MULT, PSLVERR_MULT, PRDATA_UART, PREADY_UART, PSLVERR_UART
);

parameter ADDR_WIDTH = 10;
parameter DATA_WIDTH = 32; // can be 8 bits, 16 bits, or 32 bits wide.


localparam MEM_BASE_ADDR  = 10'h000;   // word addr 0x000 = byte 0x000
localparam MULT_BASE_ADDR = 10'h100;   // word addr 0x100 = byte 0x400
localparam UART_BASE_ADDR = 10'h200;   // word addr 0x200 = byte 0x800
localparam MAX_ADDR       = 10'h2FF;   // word addr 0x2FF = byte 0xBFC

input wire [ADDR_WIDTH - 1 :0] addr;
output reg [2:0] PSELx;

output reg  [DATA_WIDTH-1:0] PRDATA;
output reg                   PREADY;
output reg                   PSLVERR;

input wire  [DATA_WIDTH-1:0] PRDATA_MEM;
input wire                   PREADY_MEM;
input wire                   PSLVERR_MEM;


input wire  [DATA_WIDTH-1:0] PRDATA_MULT;
input wire                   PREADY_MULT;
input wire                   PSLVERR_MULT;


input wire  [DATA_WIDTH-1:0] PRDATA_UART;
input wire                   PREADY_UART;
input wire                   PSLVERR_UART;




always @(*) begin

    if ((addr >= MEM_BASE_ADDR)&&( addr < MULT_BASE_ADDR)) begin
        PSELx = 3'b001;
        PRDATA = PRDATA_MEM;
        PREADY = PREADY_MEM;
        PSLVERR = PSLVERR_MEM;

    end else if ((addr >= MULT_BASE_ADDR)&&( addr < UART_BASE_ADDR)) begin
        PSELx = 3'b010;
        PRDATA = PRDATA_MULT;
        PREADY = PREADY_MULT;
        PSLVERR = PSLVERR_MULT;

    end else if ((addr >= UART_BASE_ADDR)&&( addr < MAX_ADDR)) begin
        PSELx = 3'b100;
        PRDATA = PRDATA_UART;
        PREADY = PREADY_UART;
        PSLVERR = PSLVERR_UART;

    end else begin
        PSELx = 3'b000;       
    end

end


endmodule