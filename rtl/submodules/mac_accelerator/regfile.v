module regfile(
    input clk, rst_n, a_en, b_en, 
    input [31:0] data,

    output reg [31:0] data_a, data_b
);
    

    always @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            data_a <=0;
            data_b <=0;
        end
        else if (a_en) begin
            data_a <= data;
        end
        else if (b_en) begin
            data_b <= data;
        end
    end
endmodule