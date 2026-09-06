module accumulator(
    input clk, rst_n, en, clear, wr_c_en_in,
    input [31:0] in, c_address_in, 
    output reg [31:0] result, c_address_out,
    output reg overflow, wr_c_en_out
);
    wire [32:0] temp;

    assign temp = in + result;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            result        <= 32'd0;
            overflow      <= 1'b0;
            c_address_out <= 32'd0;
            wr_c_en_out   <= 1'b0;
        end
        else if (clear) begin
            result        <= 32'd0;
            overflow      <= 1'b0;
            c_address_out <= 32'd0;
            wr_c_en_out   <= 1'b0;
        end
        else if (en) begin
            result        <= temp[31:0];
            overflow      <= temp[32];
            c_address_out <= c_address_in;
            wr_c_en_out   <= wr_c_en_in;
        end
    end
endmodule