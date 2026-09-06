module mac_accelerator(
    input clk, rst_n,
    
    //Interrupt Handling Interface
    input clear_interrupt, 
    output overflow_interrupt, done_interrupt,

    //APB Slave Interface
    input wr_en,
    input [31:0] wirte_data,
    input [9:0] read_addr, wirte_addr,
    output [31:0] read_data,

    //Dual Port Memory Interface
    input [31:0] data,
    output [31:0] result,
    output [9:0] a_b_address, result_address,
    output resutl_write_enable
);

    wire [31:0] c_address, base_a, base_b, base_c, c_address_in, 
               in, data_a, data_b;
    wire [3:0] k, m, n;
    wire [31:0] full_a_b_address, full_result_address;

    assign a_b_address    = full_a_b_address[9:0];
    assign result_address = full_result_address[9:0];

    cfg_reg cfg_reg (
        .clk(clk), 
        .rst_n(rst_n), 
        .wr_en(wr_en),
        .wirte_addr(wirte_addr), 
        .read_addr(read_addr),
        .data_write(wirte_data),
        .data_read(read_data),

        //MAC face
        .busy(busy),
        .done_interrupt(done_interrupt),
        .start(start), 
        .a_base(base_a), 
        .b_base(base_b), 
        .c_base(base_c),
        .M(m), 
        .K(k), 
        .N(n));

    accumulator accumulator (
        .clk            (clk),
        .rst_n          (rst_n), 
        .en             (en), 
        .clear          (clear), 
        .wr_c_en_in     (wr_en_c),
        .in             (in), 
        .c_address_in   (c_address), 
        .result         (result),
        .c_address_out  (full_result_address),
        .overflow       (overflow_acc), 
        .wr_c_en_out    (resutl_write_enable));

    multiplier multiplier (
        .row_element0   (data_b),
        .col_element0   (data_a),
        .result         (in),
        .overflow       (overflow_mul) );

    regfile regfile (
        .clk            (clk), 
        .rst_n          (rst_n), 
        .a_en           (a_en), 
        .b_en           (b_en), 
        .data           (data),
        .data_a         (data_a), 
        .data_b         (data_b));

    regfile_reg regfile_reg (
        .clk(clk), 
        .rst_n(rst_n), 
        .en(en), 
        .clear_in(clear_in), 
        .c_address_in(c_address_in),
        .wr_c_en_in_reg(wr_c_en_in_reg),
        .clear(clear),
        .wr_c_en_out_reg(wr_en_c),
        .c_address(c_address));

    controller controller (
        .clk            (clk), 
        .rst_n          (rst_n), 
        .start          (start), 
        .overflow_in    (overflow_acc | overflow_mul), 
        .clear_interrupt(clear_interrupt),
        .m              (m[2:0]), 
        .k              (k[2:0]), 
        .n              (n[2:0]),//MxK * KxN
        .base_a         (base_a), 
        .base_b         (base_b), 
        .base_c         (base_c),
        .c_address      (c_address_in), 
        .a_b_address    (full_a_b_address),
        .en             (en), 
        .clear          (clear_in), 
        .wr_en_c        (wr_c_en_in_reg), 
        .wr_en_a        (a_en), 
        .wr_en_b        (b_en),
        .overflow_interrupt (overflow_interrupt), 
        .done_interrupt (done_interrupt),
        .busy(busy));
endmodule