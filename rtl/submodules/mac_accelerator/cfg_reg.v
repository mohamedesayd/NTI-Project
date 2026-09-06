module cfg_reg(
    
    //APB face
    input clk, rst_n, wr_en,
    input [9:0] wirte_addr, read_addr,
    input [31:0] data_write,
    output [31:0] data_read,

    //MAC face
    input  busy, done_interrupt,
    output start, 
    output [31:0] a_base, b_base, c_base,
    output [3:0] M, K, N
);
    integer i;
    reg [31:0] cfg_register [5:0];// 0:A base addr, 1: B base addr,
                                  // 2: C base addr, 3: M,K,N,
                                  // 4: control reg (start bit at reg [4][0]),
                                  // 5: status reg  

    always @(posedge clk, rst_n) begin
        if (~rst_n)
            for (i=0; i<6; i = i +1) begin
               cfg_register[i] <= 0; 
            end
        else if (wr_en)
            cfg_register [wirte_addr[2:0]] <= data_write;
        else
        cfg_register [5][0] <= busy; 
        if (done_interrupt)
            cfg_register [4][0] <=0;
    end
    assign data_read = cfg_register [read_addr[2:0]];
    assign a_base    = cfg_register [0];
    assign b_base    = cfg_register [1];
    assign c_base    = cfg_register [2];
    assign M         = cfg_register [3][3:0];
    assign K         = cfg_register [3][7:4];
    assign N         = cfg_register [3][11:8];
    assign start     = cfg_register [4][0];
    
endmodule