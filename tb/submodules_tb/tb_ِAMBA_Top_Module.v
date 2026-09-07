module Top_module_tb ();

/////////////////////////////////////////////////////////////////
// Signal Decleration
/////////////////////////////////////////////////////////////////

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter MEM_SIZE   = 256;

    // System Signals
    reg                  clk;
    reg                  rst_n;

    //internal signal between the master and the slave
    wire PSELx_from_M_to_S;
    wire penable_from_M_to_S;
    wire [ADDR_WIDTH-1 :0] paddr_from_M_to_S; 
    wire [DATA_WIDTH-1 :0] pwdata_from_M_to_S;
    wire pwrite_from_M_to_S;
    wire [DATA_WIDTH-1 :0] prdata_from_S_to_M;
    wire PSLVERR_from_S_to_M;
    wire pready_from_S_to_M;

    // APB Bus Standard Interface for Master
/*     
    wire PSELx;
    wire penable;
    wire [ADDR_WIDTH-1 :0] paddr; 
    wire [DATA_WIDTH-1 :0] pwdata;
    wire pwrite;
    wire [DATA_WIDTH-1 :0] prdata;
    wire PSLVERR;
    reg pready; 
*/
    // Controller interface (testbench signals)
    reg transfer;
    reg [ADDR_WIDTH -1:0] addr;
    reg [DATA_WIDTH -1:0] wdata;
    reg write;

    wire [DATA_WIDTH-1:0] o_rdata;
    wire o_ready, o_slverr;
/////////////////////////////////////////////////////////////////
// Master Inst
/////////////////////////////////////////////////////////////////

APB_Master #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH) // can be 8 bits, 16 bits, or 32 bits wide.
) APB_Master_inst (
    // System Signals
    .PCLK(clk),
    .rst_n(rst_n),

    // Core Interface (User Request or testbench)
    .i_req(transfer),      // Start transaction request
    .i_write(write),    // 1 = Write, 0 = Read
    .i_addr(addr),     // Target address
    .i_wdata(wdata),    // Write data    
    
    .o_rdata(o_rdata),    // Read data response
    .o_ready(o_ready),    // Transaction completed indicator
    .o_slverr(o_slverr),   // Transaction error response

 
    // APB Bus Interface
    .PADDR(paddr_from_M_to_S), // address bus.
    .PWRITE(pwrite_from_M_to_S), //Low is Read, High is write
    .PSEL_MEM(PSELx_from_M_to_S), //PSELx signal for each Completer
    .PENABLE(penable_from_M_to_S), //High during data phase, Low during address phase
    .PWDATA(pwdata_from_M_to_S), //Write data.The PWDATA write data bus is driven by the APB bridge Requester during write cycles when PWRITE is HIGH. 
    .PRDATA(prdata_from_S_to_M), //master read data if High
    .PREADY(pready_from_S_to_M), //Signal from the Completer , High then ready for the transfer.
    .PSLVERR(PSLVERR_from_S_to_M) //optional signal: Optional for output ports, mandatory for inputs, High is an ERROR!
);

/////////////////////////////////////////////////////////////////
// Slave inst
/////////////////////////////////////////////////////////////////
APB_slave #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .MEM_SIZE(MEM_SIZE)
) APB_slave_inst(
    // System Signals
    .PCLK(clk),
    .rst_n(rst_n),

    // APB Bus Interface
    .PADDR(paddr_from_M_to_S),
    .PWRITE(pwrite_from_M_to_S),
    .PSEL_MEM(PSELx_from_M_to_S),
    .PENABLE(penable_from_M_to_S),
    .PWDATA(pwdata_from_M_to_S),
    .PRDATA(prdata_from_S_to_M),
    .PREADY(pready_from_S_to_M),
    .PSLVERR(PSLVERR_from_S_to_M)
);
/////////////////////////////////////////////////////////////////
// clock generation
/////////////////////////////////////////////////////////////////
initial begin 
    clk = 0;
    forever #1 clk = ~clk;
end 

/////////////////////////////////////////////////////////////////
// Memory inst
/////////////////////////////////////////////////////////////////
/* 
initial begin
    $readmemh ("mem_data.hex", APB_slave.mem);
end 
*/

integer i;
initial begin 
    for (i = 0; i < MEM_SIZE; i = i+1) begin
        APB_slave_inst.mem[i] = 32'b0; //{{DATA_WIDTH}1'b0}
    end

end
/////////////////////////////////////////////////////////////////
// Test Body
/////////////////////////////////////////////////////////////////
initial begin 

    ///////
    // the transfer will be controled over these four signals
    //                  transfer;
    //[ADDR_WIDTH -1:0] addr;
    //[DATA_WIDTH -1:0] wdata;
    //                  write;
    //////

// 1- reset test
    rst_n =0;
    @(negedge clk);   
    //@(negedge clk);

    rst_n = 1;

//-------------------
// 2- Write transfers With no wait states
    transfer =1;
    addr = 32'h0000_0009;
    wdata = 32'hface_aaaa;
    write = 1;
    repeat (1)    @(negedge clk);

    transfer =0;
    repeat (3)    @(negedge clk);

//-------------------
// 3- Write transfers With wait states -> should be done with different slave
    transfer =1;
    addr = 32'h0000_0033;
    wdata = 32'hface_bbbb;
    write = 1;
    repeat (1)    @(negedge clk);

    transfer =0;
    repeat (2)    @(negedge clk);
    transfer =1;
    addr = 32'h0000_0004;
    wdata = 32'hface_cccc;
    write = 1;
    repeat (1)    @(negedge clk);


    addr = 32'h0000_0002;
    wdata = 32'hface_2222;
    write = 1;
    repeat (2)    @(negedge clk);

    transfer =0;
    repeat (2)    @(negedge clk);
    transfer =1;
    addr = 32'h0000_0011;
    wdata = 32'hface_5555;
    write = 1;
    repeat (1)    @(negedge clk);


//-------------------
// 4- Read transfers With no wait states
    transfer =0;
    repeat (6)    @(negedge clk);
    transfer =1;
    write = 0;   
    addr = 32'h0000_0009;
    repeat (4)    @(negedge clk);

//-------------------
// 5- Read transfers With wait states -> should be done with different slave
    transfer =0;
    repeat (1)    @(negedge clk);
    transfer =1;
    write = 0;   
    addr = 32'h0000_0033;
    repeat (1)    @(negedge clk);
    transfer =1;


//-------------------
// 6- out of boundary read
    transfer =0;
    repeat (1)    @(negedge clk);
    transfer =1;
    write = 0;   
    addr = 32'hffff_ffff;
    repeat (1)    @(negedge clk);
    transfer =1;


//-------------------


//finish simulation
    repeat (6)    @(negedge clk);
    $stop;

end


/////////////////////////////////////////////////////////////////
// Monitor Data
/////////////////////////////////////////////////////////////////
initial begin
    $Monitor("o_rdata %d, o_ready %d, o_slverr %d",o_rdata, o_ready, o_slverr);
end

/////////////////////////////////////////////////////////////////
// 
/////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////










endmodule
