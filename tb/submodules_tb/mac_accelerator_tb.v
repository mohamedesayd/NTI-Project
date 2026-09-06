module mac_accelerator_tb(
);
    reg clk, rst_n, wr_en, clear_interrupt;
    reg [9:0] wirte_addr, read_addr;
    reg [31:0] wirte_data;

    wire [31:0] read_data, data, result;
    wire [9:0] a_b_address, result_address;
    mac_accelerator dut0 (
                          clk, 
                          rst_n,
                          clear_interrupt,
                          overflow_interrupt, 
                          done_interrupt,
                          wr_en,
                          wirte_data,
                          read_addr, 
                          wirte_addr,
                          read_data,

    //Dual Port Memory Interface
                          data, 
                          result,
                          a_b_address, 
                          result_address,
                          resutl_write_enable);

    synch_dual_port_memory dut1 (
    //clk
        clk, 

    // Port A
        a_b_address, 
        result_address,
        result,
        resutl_write_enable,
        data,

    //Port B
        b_read_address, 
        b_write_address,
        b_write_data,
        b_write_enable,
        b_read_data
);

    initial begin
        clk =0;
        forever #5 clk = ~ clk;
    end

    initial begin 
        rst_n =0;
        wr_en =0;
        clear_interrupt =0;
        wirte_addr=0;
        wirte_data=0;
        read_addr =0;

        #15 rst_n =1;
            wr_en =1;
            wirte_addr =0;
            wirte_data =0;
        #15 wirte_addr =1;
            wirte_data =16;
        #15 wirte_addr =2;
            wirte_data =32;
        #15 wirte_addr =3;
            wirte_data =32'b00000000000000000000001100110011;
        #15 wirte_addr =4;
            wirte_data =1;
        #15 wr_en=0;
        # 800 $stop;
    end

//     initial begin
//     $fsdbDumpfile("matmul.fsdb");
//     $fsdbDumpvars(0, matmul);
// end
endmodule