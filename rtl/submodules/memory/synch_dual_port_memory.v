module synch_dual_port_memory#(
    parameter ADDRESS_WIDTH = 10,
    parameter DATA_WIDTH    = 32
)
(
    //clk
    input clk, 

    // Port A
    input       [ADDRESS_WIDTH-1 : 0 ] a_read_address, a_write_address,
    input       [DATA_WIDTH-1    : 0]  a_write_data,
    input       a_write_enable,
    output reg  [DATA_WIDTH-1    : 0]  a_read_data,

    //Port B
    input       [ADDRESS_WIDTH-1 : 0 ] b_read_address, b_write_address,
    input       [DATA_WIDTH-1    : 0]  b_write_data,
    input       b_write_enable,
    output reg  [DATA_WIDTH-1    : 0]  b_read_data
);

    //Memory body
    reg [DATA_WIDTH - 1 : 0] memory [(2**ADDRESS_WIDTH) - 1 : 0];

    //inital value
    initial begin
        $readmemh("memory.hex", memory);
    end
    //Port A
    always @(posedge clk) begin
        if (a_write_enable)
            memory [a_write_address] <= a_write_data;
        a_read_data <= memory [a_read_address];
    end

    //Port B
    always @(posedge clk) begin
        if (b_write_enable)
            memory [b_write_address] <= b_write_data;
        b_read_data <= memory [b_read_address];
    end

endmodule