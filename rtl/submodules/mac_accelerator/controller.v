module controller(
    input clk, rst_n, start, overflow_in, clear_interrupt,
    input [2:0] m, k, n,//MxK * KxN
    input [31:0] base_a, base_b, base_c,
    output [31:0] c_address, a_b_address,
    output reg  wr_en_c, wr_en_a, wr_en_b,
    output clear, en, overflow_interrupt, done_interrupt, busy
);
    parameter idle      = 3'b000,
              load_a    = 3'b001,
              load_b    = 3'b010,   
              clear_s   = 3'b011,
              done      = 3'b100,
              overflow  = 3'b101,
              padding   = 4'b110;

    reg [2:0] current_state, next_state;
    reg [3:0] k_index_a, k_index_b, m_index, n_index;
    reg [1:0] padding_counter;
    //state register
    always @(posedge clk, negedge rst_n) begin
        if (~rst_n)
            current_state <= idle;
        else
            current_state <= next_state;
    end

    
    //next_state_logic
    always @(*) begin
        case (current_state)
            idle    : begin 
                if (start)
                    next_state = load_a;
                else
                    next_state = idle;
            end
            load_a  : begin
                if (overflow_in)
                    next_state = overflow; 
                else
                    next_state = load_b;
            end
            load_b  : begin
                if (overflow_in)
                    next_state = overflow;
                else if (k_index_b == (k-1))
                    next_state = clear_s;
                else
                    next_state = load_a;
            end
            clear_s:begin
                    if ((n_index   == 0) && 
                        (m_index   == 0) && 
                        (k_index_b == 0))
                        next_state = padding;
                    else
                        next_state = load_a;
            end
            padding : begin
                if (padding_counter == k)
                    next_state = done;
                else
                    next_state = padding; 
            end
            done    : begin 
                if (~start && clear_interrupt)
                    next_state = idle;
                else
                    next_state = done;
            end 
            overflow: begin 
                if(~start && clear_interrupt)
                    next_state = idle;
                else
                    next_state = overflow;
            end 
        endcase
    end

    //output
    always @(posedge clk, negedge rst_n) begin
        case (current_state)
            idle,
            done,
            overflow:begin
                padding_counter <=0;
                k_index_a<= 4'b0000;
                k_index_b<= 4'b0000; 
                m_index  <= 4'b0000;
                n_index  <= 4'b0000;
                wr_en_a  <=0;
                wr_en_b  <=0;
                wr_en_c <=0;
                //en <=0;
            end
            clear_s:begin
                wr_en_b <=0;
            end
            load_a:begin
                wr_en_a <=1;
                wr_en_b <=0;
                //en <=1;
                if (k_index_a == (k-1)) begin
                    k_index_a <=0;
                    wr_en_c <=1;
                end
                else begin
                    k_index_a = k_index_a +1;
                    wr_en_c <=0;
                end
            end
            load_b:begin
                //en <=0;
                wr_en_c <=0;
                wr_en_a <=0;  
                wr_en_b <=1;
                if (k_index_b == (k-1)) begin
                    k_index_b <=0;
                    if (n_index == (n-1))begin 
                        n_index <= 0;
                        if (m_index == (m-1))
                            m_index <= 0;
                        else 
                            m_index <= m_index +1;
                    end
                    else 
                        n_index <= n_index +1;
                end
                else
                    k_index_b <= k_index_b +1;           
            end
            padding : begin
                padding_counter <= padding_counter +1;
            end
        endcase
    end

    assign en = (current_state == padding)? padding_counter[0]:(current_state == load_b);

    assign clear = (current_state == clear_s);

    assign c_address = (m_index*n+n_index) + base_c;

    assign a_b_address = (current_state==load_a)?
                                (m_index*k+k_index_a)+base_a: (current_state==load_b)?
                                                              (k_index_b*k+n_index)+base_b:0;

    assign overflow_interrupt = (current_state == overflow);
    assign done_interrupt = (current_state == done);
    assign busy = (current_state != idle);    
endmodule