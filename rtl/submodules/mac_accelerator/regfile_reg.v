module regfile_reg(
    input clk, rst_n, en, clear_in, 
    input [31:0] c_address_in,
    input wr_c_en_in_reg,

    output reg clear,wr_c_en_out_reg,
    output reg [31:0] c_address
);

    reg clear_temp, clear_temp2;
    always @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            wr_c_en_out_reg <= 0;
            c_address <=0;
            clear <=0;
            clear_temp <= 0;
            clear_temp2<= 0;
        end
        else begin 
            clear_temp <= clear_in;
            clear_temp2 <= clear_temp;
            clear <= clear_temp2;
            if (en) begin
            wr_c_en_out_reg <= wr_c_en_in_reg;
            c_address <= c_address_in;
        end
         
            else begin
                wr_c_en_out_reg<= wr_c_en_out_reg;
                c_address <= c_address;
                //clear <= clear;
            end 
        end
    end
endmodule