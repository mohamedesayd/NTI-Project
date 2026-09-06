module multiplier(
    input signed [31:0] row_element0,
                 col_element0,
    output signed [31:0] result,
    output overflow 
);
    wire [63:0]mul;
    assign mul = row_element0 * col_element0;
    assign result = mul [31:0];
    assign overflow = ({32{mul[31]}} != mul[63:32]);
endmodule