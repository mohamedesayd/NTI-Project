// RISC-V SoC Simulation Filelist (QuestaSim / ModelSim / VCS)

// 1. Core RISC-V Include Directories
+incdir+rtl/cv32e40p-cv32e40p_v1.8.3/rtl/include
+incdir+rtl/cv32e40p-cv32e40p_v1.8.3/bhv
+incdir+rtl/cv32e40p-cv32e40p_v1.8.3/bhv/include
+incdir+rtl/cv32e40p-cv32e40p_v1.8.3/sva

// 2. Core RISC-V RTL Files
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/include/cv32e40p_apu_core_pkg.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/include/cv32e40p_fpu_pkg.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/include/cv32e40p_pkg.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_if_stage.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_cs_registers.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_register_file_ff.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_load_store_unit.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_id_stage.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_aligner.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_decoder.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_compressed_decoder.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_fifo.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_prefetch_buffer.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_hwloop_regs.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_mult.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_int_controller.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_ex_stage.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_alu_div.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_alu.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_ff_one.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_popcnt.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_apu_disp.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_controller.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_obi_interface.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_prefetch_controller.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_sleep_unit.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_core.sv
rtl/cv32e40p-cv32e40p_v1.8.3/bhv/cv32e40p_sim_clock_gate.sv
rtl/cv32e40p-cv32e40p_v1.8.3/rtl/cv32e40p_top.sv

// 3. SoC Submodules
rtl/submodules/cpu_arbiter/cpu_ram_arbiter.v
rtl/submodules/apb_bus/APB_Master.v
rtl/submodules/apb_bus/APB_Slave.v
rtl/submodules/apb_bus/Comp_Decoder.v
rtl/submodules/memory/synch_dual_port_memory.v
rtl/submodules/mac_accelerator/accumulator.v
rtl/submodules/mac_accelerator/cfg_reg.v
rtl/submodules/mac_accelerator/controller.v
rtl/submodules/mac_accelerator/mac_accelerator.v
rtl/submodules/mac_accelerator/multiplier.v
rtl/submodules/mac_accelerator/regfile.v
rtl/submodules/mac_accelerator/regfile_reg.v
rtl/submodules/uart/data_sampling.v
rtl/submodules/uart/deserializer.v
rtl/submodules/uart/edge_bit_counter.v
rtl/submodules/uart/mux.v
rtl/submodules/uart/par_chk.v
rtl/submodules/uart/parity_calc.v
rtl/submodules/uart/Register_file.v
rtl/submodules/uart/Serializer.v
rtl/submodules/uart/stp_chk.v
rtl/submodules/uart/strt_chk.v
rtl/submodules/uart/UART.v
rtl/submodules/uart/UART_RX.v
rtl/submodules/uart/uart_rx_fsm.v
rtl/submodules/uart/UART_SYSTEM.V
rtl/submodules/uart/UART_TX.v
rtl/submodules/uart/uart_tx_fsm.v

// 4. Top SoC & Testbench
rtl/top/RISC-V_based_Soc.v
tb/top_tb/risc_v_based_soc_tb.v
