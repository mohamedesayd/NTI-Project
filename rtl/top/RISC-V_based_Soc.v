module risc_v_based_soc #(
    parameter boot_addr_i         = 32'h0000_0000,
    parameter mtvec_addr_i        = 32'h0000_0080,
    parameter dm_halt_addr_i      = 32'h1A11_0800,
    parameter dm_exception_addr_i = 32'h1A11_0808,
    parameter hart_id_i           = 32'h0000_0000
) (
    input wire clk,
    input wire rst_n,

    // UART External Serial Lines
    input  wire RX_IN,
    output wire TX_OUT
);

    // ============================================================
    // 1. SIGNAL DECLARATIONS (Widths & Internal Wires)
    // ============================================================

    // CPU Instruction Interface
    wire        instr_req_o;
    wire        instr_gnt_i;
    wire        instr_rvalid_i;
    wire [31:0] instr_addr_o;
    wire [31:0] instr_rdata_i;

    // CPU Data Interface
    wire        data_req_o;
    wire        data_gnt_i;
    wire        data_rvalid_i;
    wire        data_we_o;
    wire [ 3:0] data_be_o;
    wire [31:0] data_addr_o;
    wire [31:0] data_wdata_o;
    wire [31:0] data_rdata_i;

    // CPU Interrupt & Control Signals
    wire [31:0] irq_i;
    wire        irq_ack_o;
    wire [ 4:0] irq_id_o;

    // CPU Arbiter to APB Master Signals
    wire        i_req;
    wire        i_write;
    wire [ 9:0] i_addr;
    wire [31:0] i_wdata;
    wire [31:0] o_rdata;
    wire        o_ready;
    wire        o_slverr;
    wire        o_gnt;

    // APB Bus Signals (Master Outputs)
    wire [ 9:0] PADDR;
    wire        PWRITE;
    wire        PSEL_MASTER_UNUSED;
    wire        PENABLE;
    wire [31:0] PWDATA;
    wire [31:0] PRDATA;
    wire        PREADY;
    wire        PSLVERR;

    // APB Decoder Signals
    wire [ 2:0] PSELx;
    wire        PSEL_MEM  = PSELx[0];
    wire        PSEL_MULT = PSELx[1];
    wire        PSEL_UART = PSELx[2];

    wire [31:0] PRDATA_MEM,  PRDATA_MULT,  PRDATA_UART;
    wire        PREADY_MEM,  PREADY_MULT,  PREADY_UART;
    wire        PSLVERR_MEM, PSLVERR_MULT, PSLVERR_UART;

    // Dual-Port RAM Port B Signals (CPU side via APB slave)
    wire        b_write_enable;
    wire [ 9:0] b_read_address;
    wire [31:0] b_write_data;
    wire [31:0] b_read_data;

    // MAC Accelerator Config APB Signals
    wire        mac_wr_en;
    wire [ 9:0] mac_read_addr;
    wire [31:0] mac_write_data;
    wire [31:0] mac_read_data;
    wire        done_interrupt;
    wire        overflow_interrupt;

    // Dual-Port RAM Port A Signals (MAC Accelerator side)
    wire [31:0] mac_mem_data;
    wire [31:0] mac_mem_result;
    wire [ 9:0] a_b_address;
    wire [ 9:0] result_address;
    wire        result_write_enable;

    // UART APB Signals & Interrupt
    wire        uart_wr_en;
    wire [ 9:0] uart_read_addr;
    wire [31:0] uart_write_data;
    wire [31:0] uart_read_data;
    wire        uart_interrupt;

    // Clear interrupt line (driven by software/control register)
    wire        clear_interrupt = 1'b0;


    // ============================================================
    // 2. INTERRUPT MAPPING
    // ============================================================
    // irq_i[16] : UART RX Interrupt
    // irq_i[17] : MAC Done Interrupt
    // irq_i[18] : MAC Overflow Interrupt
    assign irq_i = {13'b0, overflow_interrupt, done_interrupt, uart_interrupt, 16'b0};


    // ============================================================
    // 3. MODULE INSTANTIATIONS
    // ============================================================

    // --- CV32E40P RISC-V CPU Core ---
    cv32e40p_top #(
        .COREV_PULP      (0),
        .COREV_CLUSTER   (0),
        .FPU             (0),
        .FPU_ADDMUL_LAT  (0),
        .FPU_OTHERS_LAT  (0),
        .ZFINX           (0),
        .NUM_MHPMCOUNTERS(1)
    ) cpu_core (
        .clk_i               (clk),
        .rst_ni              (rst_n),
        .pulp_clock_en_i     (1'b1),
        .scan_cg_en_i        (1'b1),

        .boot_addr_i         (boot_addr_i),
        .mtvec_addr_i        (mtvec_addr_i),
        .dm_halt_addr_i      (dm_halt_addr_i),
        .hart_id_i           (hart_id_i),
        .dm_exception_addr_i(dm_exception_addr_i),

        .instr_req_o         (instr_req_o),
        .instr_gnt_i         (instr_gnt_i),
        .instr_rvalid_i      (instr_rvalid_i),
        .instr_addr_o        (instr_addr_o),
        .instr_rdata_i       (instr_rdata_i),

        .data_req_o          (data_req_o),
        .data_gnt_i          (data_gnt_i),
        .data_rvalid_i       (data_rvalid_i),
        .data_we_o           (data_we_o),
        .data_be_o           (data_be_o),
        .data_addr_o         (data_addr_o),
        .data_wdata_o        (data_wdata_o),
        .data_rdata_i        (data_rdata_i),

        .irq_i               (irq_i),
        .irq_ack_o           (irq_ack_o),
        .irq_id_o            (irq_id_o),

        .debug_req_i         (1'b0),
        .debug_havereset_o   (),
        .debug_running_o     (),
        .debug_halted_o      (),

        .fetch_enable_i      (1'b1),
        .core_sleep_o        ()
    );


    // --- CPU Arbiter (Instruction/Data Multiplexer) ---
    cpu_arbiter u_cpu_arbiter (
        .clk_i          (clk),
        .rst_ni         (rst_n),

        .instr_req_i    (instr_req_o),
        .instr_gnt_o    (instr_gnt_i),
        .instr_rvalid_o (instr_rvalid_i),
        .instr_addr_i   (instr_addr_o),
        .instr_rdata_o  (instr_rdata_i),

        .data_req_i     (data_req_o),
        .data_gnt_o     (data_gnt_i),
        .data_rvalid_o  (data_rvalid_i),
        .data_we_i      (data_we_o),
        .data_be_i      (data_be_o),
        .data_addr_i    (data_addr_o),
        .data_wdata_i   (data_wdata_o),
        .data_rdata_o   (data_rdata_i),

        .i_req          (i_req),
        .i_write        (i_write),
        .i_addr         (i_addr),
        .i_wdata        (i_wdata),

        .o_rdata        (o_rdata),
        .o_ready        (o_ready),
        .o_slverr       (o_slverr),
        .o_gnt          (o_gnt)
    );


    // --- APB Master ---
    APB_Master #(
        .ADDR_WIDTH(10),
        .DATA_WIDTH(32)
    ) apb_master (
        .PCLK       (clk),
        .rst_n      (rst_n),

        .i_req      (i_req),
        .i_write    (i_write),
        .i_addr     (i_addr),
        .i_wdata    (i_wdata),

        .o_rdata    (o_rdata),
        .o_ready    (o_ready),
        .o_slverr   (o_slverr),
        .o_gnt      (o_gnt),

        .PADDR      (PADDR),
        .PWRITE     (PWRITE),
        .PSEL_MEM   (PSEL_MASTER_UNUSED),
        .PENABLE    (PENABLE),
        .PWDATA     (PWDATA),
        .PRDATA     (PRDATA),
        .PREADY     (PREADY),
        .PSLVERR    (PSLVERR)
    );


    // --- APB Address Bus Decoder ---
    Comp_Decoder bus_decoder (
        .addr         (PADDR),
        .PSELx        (PSELx),
        .PRDATA       (PRDATA),
        .PREADY       (PREADY),
        .PSLVERR      (PSLVERR),

        .PRDATA_MEM   (PRDATA_MEM),
        .PREADY_MEM   (PREADY_MEM),
        .PSLVERR_MEM  (PSLVERR_MEM),

        .PRDATA_MULT  (PRDATA_MULT),
        .PREADY_MULT  (PREADY_MULT),
        .PSLVERR_MULT (PSLVERR_MULT),

        .PRDATA_UART  (PRDATA_UART),
        .PREADY_UART  (PREADY_UART),
        .PSLVERR_UART (PSLVERR_UART)
    );


    // --- Slave 1: Dual-Port RAM APB Slave ---
    APB_slave memory_apb_slave (
        .PCLK           (clk),
        .rst_n          (rst_n),

        .o_write_slave  (b_write_enable),
        .o_addr_slave   (b_read_address),
        .o_wdata_slave  (b_write_data),
        .i_rdata_slave  (b_read_data),

        .PADDR          (PADDR),
        .PWRITE         (PWRITE),
        .PSEL_MEM       (PSEL_MEM),
        .PENABLE        (PENABLE),
        .PWDATA         (PWDATA),
        .PRDATA         (PRDATA_MEM),
        .PREADY         (PREADY_MEM),
        .PSLVERR        (PSLVERR_MEM)
    );

    // --- Shared Synchronous Dual-Port Memory ---
    synch_dual_port_memory #(
        .ADDRESS_WIDTH(10),
        .DATA_WIDTH   (32)
    ) shared_memory (
        .clk            (clk),

        // Port A (Hardware MAC Accelerator Access)
        .a_read_address (a_b_address),
        .a_write_address(result_address),
        .a_write_data   (mac_mem_result),
        .a_write_enable (result_write_enable),
        .a_read_data    (mac_mem_data),

        // Port B (CPU Access via APB)
        .b_read_address (b_read_address),
        .b_write_address(b_read_address),
        .b_write_data   (b_write_data),
        .b_write_enable (b_write_enable),
        .b_read_data    (b_read_data)
    );


    // --- Slave 2: MAC Accelerator APB Slave ---
    APB_slave mac_accelerator_apb_slave (
        .PCLK           (clk),
        .rst_n          (rst_n),

        .o_write_slave  (mac_wr_en),
        .o_addr_slave   (mac_read_addr),
        .o_wdata_slave  (mac_write_data),
        .i_rdata_slave  (mac_read_data),

        .PADDR          (PADDR),
        .PWRITE         (PWRITE),
        .PSEL_MEM       (PSEL_MULT),
        .PENABLE        (PENABLE),
        .PWDATA         (PWDATA),
        .PRDATA         (PRDATA_MULT),
        .PREADY         (PREADY_MULT),
        .PSLVERR        (PSLVERR_MULT)
    );

    // --- MAC Accelerator Unit ---
    mac_accelerator mac_accel (
        .clk                 (clk),
        .rst_n               (rst_n),

        .clear_interrupt     (clear_interrupt),
        .overflow_interrupt  (overflow_interrupt),
        .done_interrupt      (done_interrupt),

        .wr_en               (mac_wr_en),
        .wirte_data          (mac_write_data),
        .read_addr           (mac_read_addr),
        .wirte_addr          (mac_read_addr),
        .read_data           (mac_read_data),

        .data                (mac_mem_data),
        .result              (mac_mem_result),
        .a_b_address         (a_b_address),
        .result_address      (result_address),
        .resutl_write_enable (result_write_enable)
    );


    // --- Slave 3: UART System APB Slave ---
    APB_slave uart_apb_slave (
        .PCLK           (clk),
        .rst_n          (rst_n),

        .o_write_slave  (uart_wr_en),
        .o_addr_slave   (uart_read_addr),
        .o_wdata_slave  (uart_write_data),
        .i_rdata_slave  (uart_read_data),

        .PADDR          (PADDR),
        .PWRITE         (PWRITE),
        .PSEL_MEM       (PSEL_UART),
        .PENABLE        (PENABLE),
        .PWDATA         (PWDATA),
        .PRDATA         (PRDATA_UART),
        .PREADY         (PREADY_UART),
        .PSLVERR        (PSLVERR_UART)
    );

    // --- UART System Module ---
    UART_SYSTEM #(
        .DATA_WIDTH(8)
    ) uart_system (
        .CLK          (clk),
        .RST          (rst_n),

        .write_enable (uart_wr_en),
        .wr_addr      (uart_read_addr[7:0]),
        .wr_data      (uart_write_data),
        .rd_addr      (uart_read_addr[7:0]),
        .rd_data      (uart_read_data),

        .RX_IN        (RX_IN),
        .TX_OUT       (TX_OUT),
        .INTERRUPT    (uart_interrupt)
    );

endmodule