LIBRARY IEEE;
  USE IEEE.STD_LOGIC_1164.ALL;
  USE IEEE.NUMERIC_STD.ALL;
 
LIBRARY WORK;
  USE WORK.B2BLINK_PKG.ALL;
  USE WORK.B2BLINK_TX_PKG.ALL;
  USE WORK.B2BLINK_RX_PKG.ALL;

LIBRARY WORK;
  USE WORK.BASE_REGDEF_PKG.ALL;
  USE WORK.BASE_32B_REGDEF_PKG.ALL;
  USE WORK.BASE_32B_64B_REGDEF_PKG.ALL;
  USE WORK.AVS_COMMON_PKG.ALL;

LIBRARY WORK;
  USE WORK.REGDEF_B2B_PKG.ALL;
  USE WORK.B2BLINK_REC_PKG.ALL;
  USE WORK.AVS_B2BLINK_PKG.ALL;


ENTITY avs_b2blink IS
  PORT (
    clk_1x_i : IN std_logic;
    clk_5x_i : IN STD_LOGIC;
    rst_n_i : IN std_logic;
    -- Avalon slave interface
    avs_address_i : IN std_logic_vector(AVS_ADDR_WIDTH_C-1 DOWNTO 0);
    avs_write_i : IN std_logic;
    avs_writedata_i : IN std_logic_vector(AVS_DATA_WIDTH_C-1 DOWNTO 0);
    avs_read_i : IN std_logic;
    avs_readdata_o : OUT std_logic_vector(AVS_DATA_WIDTH_C-1 DOWNTO 0);
    -- Avalon input conduits
    rx_i : IN STD_LOGIC;
    -- Avalon output conduits
    tx_o : OUT STD_LOGIC
  );
END ENTITY avs_b2blink;

ARCHITECTURE struct OF avs_b2blink IS

  SIGNAL r, rin : avs_b2blink_reg_t;
  SIGNAL slave_i : avs_input_t;
  SIGNAL din : b2blink_rec_input_t;
  SIGNAL dout : b2blink_rec_output_t;
BEGIN

  -- Connect avs input ports to internal signal
  slave_i.iaddress <= avs_address_i;
  slave_i.iwrite <= avs_write_i;
  slave_i.iwritedata <= avs_writedata_i;
  slave_i.iread <= avs_read_i;

   -- RTL Top component instantiation
   b2blink_inst: WORK.b2blink_top
     PORT MAP (
       clk_1x_i => clk_1x_i,
       clk_5x_i => clk_5x_i,
       rst_n_i => rst_n_i,
       loopback_en_i => din.loopback_en,
       tx_enable_i => din.tx_enable,
       tx_frame_gen_start_i => din.tx_frame_gen_start,
       tx_pattern_gen_i => din.tx_pattern_gen,
       cmd_mem_base_addr_i => din.cmd_mem_base_addr,
       cmd_mem_wren_i => din.cmd_mem_wren,
       cmd_mem_wraddr_i => din.cmd_mem_wraddr,
       cmd_mem_tx_src_addr_i => din.cmd_mem_tx_src_addr,
       cmd_mem_tx_dst_addr_i => din.cmd_mem_tx_dst_addr,
       cmd_mem_tx_length_i => din.cmd_mem_tx_length,
       cmd_mem_tx_cmd_i => din.cmd_mem_tx_cmd,
       cmd_mem_tx_trans_id_i => din.cmd_mem_tx_trans_id,
       cmd_mem_rden_i => din.cmd_mem_rden,
       cmd_mem_rdaddr_i => din.cmd_mem_rdaddr,
       payload_mem_wren_i => din.payload_mem_wren,
       payload_mem_wraddr_i => din.payload_mem_wraddr,
       payload_mem_data_i => din.payload_mem_data,
       payload_mem_rden_i => din.payload_mem_rden,
       payload_mem_rdaddr_i => din.payload_mem_rdaddr,
       rx_enable_i => din.rx_enable,
       rx_i => din.rx,
       rx_cmd_fifo_do_read_i => din.rx_cmd_fifo_do_read,
       rx_sample_index_i => din.rx_sample_index,
       rx_payload_fifo_do_read_i => din.rx_payload_fifo_do_read,
       tx_o => dout.tx,
       tx_done_o => dout.tx_done,
       tx_busy_o => dout.tx_busy,
       tx_frame_count_o => dout.tx_frame_count,
       tx_frame_gen_busy_o => dout.tx_frame_gen_busy,
       tx_frame_gen_done_o => dout.tx_frame_gen_done,
       cmd_mem_tx_src_addr_o => dout.cmd_mem_tx_src_addr,
       cmd_mem_tx_dst_addr_o => dout.cmd_mem_tx_dst_addr,
       cmd_mem_tx_length_o => dout.cmd_mem_tx_length,
       cmd_mem_tx_cmd_o => dout.cmd_mem_tx_cmd,
       cmd_mem_tx_trans_id_o => dout.cmd_mem_tx_trans_id,
       max_size_command_mem_o => dout.max_size_command_mem,
       payload_mem_data_o => dout.payload_mem_data,
       max_size_payload_mem_o => dout.max_size_payload_mem,
       rx_cmd_fifo_empty_o => dout.rx_cmd_fifo_empty,
       rx_payload_len_o => dout.rx_payload_len,
       rx_cmd_type_o => dout.rx_cmd_type,
       rx_dest_addr_o => dout.rx_dest_addr,
       rx_trans_id_o => dout.rx_trans_id,
       rx_crc_ok_o => dout.rx_crc_ok,
       rx_payload_fifo_empty_o => dout.rx_payload_fifo_empty,
       rx_payload_fifo_data_o => dout.rx_payload_fifo_data,
       rx_busy_o => dout.rx_busy,
       rx_done_o => dout.rx_done,
       rx_curr_crc_err_flag_o => dout.rx_curr_crc_err_flag,
       rx_persist_crc_err_flag_o => dout.rx_persist_crc_err_flag,
       rx_frame_count_o => dout.rx_frame_count,
       rx_crc_err_count_o => dout.rx_crc_err_count
     );

  -- ********** START CONNECT REGISTERS TO MODULE INPUT PORTS **********
  -- Update component input ports with content from register block
  din.loopback_en <= r.regs.LOOPBACK.cval(get_field_lwb(C_B2BLINK_BLOCK.LOOPBACK.reg_fd_info.EN));
  din.tx_enable <= r.regs.ENABLE.cval(get_field_lwb(C_B2BLINK_BLOCK.ENABLE.reg_fd_info.TX_EN));
  din.tx_frame_gen_start <= r.regs.DMA_TRANSMIT.cval(get_field_lwb(C_B2BLINK_BLOCK.DMA_TRANSMIT.reg_fd_info.START));
  din.tx_pattern_gen <= r.regs.TEST_PATTERN.cval(get_field_lwb(C_B2BLINK_BLOCK.TEST_PATTERN.reg_fd_info.ENABLE));
  din.cmd_mem_wren <= r.regs.CMD_WEN.cval(get_field_lwb(C_B2BLINK_BLOCK.CMD_WEN.reg_fd_info.EN));
  din.cmd_mem_rden <= r.regs.CMD_REN.cval(get_field_lwb(C_B2BLINK_BLOCK.CMD_REN.reg_fd_info.EN));
  din.payload_mem_wren <= r.regs.PAYLOAD_WEN.cval(get_field_lwb(C_B2BLINK_BLOCK.PAYLOAD_WEN.reg_fd_info.EN));
  din.payload_mem_rden <= r.regs.PAYLOAD_REN.cval(get_field_lwb(C_B2BLINK_BLOCK.PAYLOAD_REN.reg_fd_info.EN));
  din.rx_enable <= r.regs.ENABLE.cval(get_field_lwb(C_B2BLINK_BLOCK.ENABLE.reg_fd_info.RX_EN));
  --din.rx <= r.regs.<RX_REG>.cval(din.rx'range);
  din.rx_cmd_fifo_do_read <= r.regs.RX_CMD_FIFO_REN.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_CMD_FIFO_REN.reg_fd_info.READ1));
  din.rx_payload_fifo_do_read <= r.regs.RX_PAYLOAD_FIFO_REN.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_PAYLOAD_FIFO_REN.reg_fd_info.READ1));
  din.cmd_mem_base_addr <= r.regs.CMD_LIST_START_INDEX.cval(din.cmd_mem_base_addr'range);
  din.cmd_mem_wraddr <= r.regs.CMD_INDEX.cval(din.cmd_mem_wraddr'range);
  din.cmd_mem_tx_src_addr <= r.regs.DMA_SRC_ADDR.cval(din.cmd_mem_tx_src_addr'range);
  din.cmd_mem_tx_dst_addr <= r.regs.DMA_DST_ADDR.cval(din.cmd_mem_tx_dst_addr'range);
  din.cmd_mem_tx_length <= r.regs.DMA_PAYLOAD_NUM_WORDS.cval(din.cmd_mem_tx_length'range);
  din.cmd_mem_tx_cmd <= r.regs.DMA_CMD_TYPE.cval(din.cmd_mem_tx_cmd'range);
  din.cmd_mem_tx_trans_id <= r.regs.DMA_CMD_TRANSACTION_ID.cval(din.cmd_mem_tx_trans_id'range);
  din.cmd_mem_rdaddr <= r.regs.CMD_RINDEX.cval(din.cmd_mem_rdaddr'range);
  din.payload_mem_wraddr <= r.regs.PAYLOAD_INDEX.cval(din.payload_mem_wraddr'range);
  din.payload_mem_data <= r.regs.PAYLOAD.cval(din.payload_mem_data'range);
  din.payload_mem_rdaddr <= r.regs.PAYLOAD_RINDEX.cval(din.payload_mem_rdaddr'range);
  din.rx_sample_index <= r.regs.RX_SAMPLE_INDEX.cval(din.rx_sample_index'range);
  -- ********** END CONNECT REGISTERS TO MODULE INPUT PORTS **********

  clk_proc: PROCESS(clk_1x_i) IS
  BEGIN
    IF (rising_edge(clk_1x_i)) THEN
      IF (rst_n_i = '0') THEN
        r <= init_avs_b2blink_reg_t;
      ELSE
        r <= rin;
      END IF;
    END IF;
  END PROCESS;

  comb_proc: PROCESS(r, slave_i, dout) IS
    VARIABLE v : avs_b2blink_reg_t;
    VARIABLE addr_offset : reg_offset_32_t := (OTHERS => '0');
  BEGIN

    -- Default assignment
    v := r;
    v.rdout.oreaddata := (OTHERS => '0');

    -- Address offset calculation
    addr_offset := reg_offset_32_t(resize(unsigned(slave_i.iaddress), DWORD_SIZE_C)); -- return this : "00000" & slave_i.iaddress
    addr_offset := addr_offset(31 DOWNTO 2) & "00"; -- this is a hack to avoid a warning in vivado 2018

    -- Avalon Slave write
    -- Slave register offset calculation - 32-bit (word) aligned
    IF (slave_i.iwrite = '1') THEN
      v.regs := write_b2blink_reg_block(addr_offset, slave_i.iwritedata, r.regs);
    END IF;

    -- Avalon Slave read
    IF (slave_i.iread = '1') THEN
      v.rdout.oreaddata := read_b2blink_reg_block(addr_offset, r.regs);
    END IF;

    -- ********** START CONNECT REGISTERS TO MODULE OUTPUT PORTS **********
    -- Update register block with component outputs
    --v.regs.<TX_REG>.cval(dout.tx'range) := dout.tx;
    v.regs.TX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.TX_STATUS.reg_fd_info.DONE)) := dout.tx_done;
    v.regs.TX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.TX_STATUS.reg_fd_info.BUSY)) := dout.tx_busy;
    v.regs.TX_FRAME_CNT.cval(dout.tx_frame_count'range) := dout.tx_frame_count;
    v.regs.FRAME_GEN_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.FRAME_GEN_STATUS.reg_fd_info.BUSY)) := dout.tx_frame_gen_busy;
    v.regs.FRAME_GEN_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.FRAME_GEN_STATUS.reg_fd_info.DONE)) := dout.tx_frame_gen_done;
    v.regs.DMA_CURRENT_SRC_ADDR.cval(dout.cmd_mem_tx_src_addr'range) := dout.cmd_mem_tx_src_addr;
    v.regs.DMA_CURRENT_DST_ADDR.cval(dout.cmd_mem_tx_dst_addr'range) := dout.cmd_mem_tx_dst_addr;
    v.regs.DMA_CURRENT_PAYLOAD_NUM_WORDS.cval(dout.cmd_mem_tx_length'range) := dout.cmd_mem_tx_length;
    v.regs.DMA_CURRENT_CMD_TYPE.cval(dout.cmd_mem_tx_cmd'range) := dout.cmd_mem_tx_cmd;
    v.regs.DMA_CURRENT_CMD_TRANSACTION_ID.cval(dout.cmd_mem_tx_trans_id'range) := dout.cmd_mem_tx_trans_id;
    v.regs.MAX_SIZE_COMMAND_MEM.cval(dout.max_size_command_mem'range) := dout.max_size_command_mem;
    v.regs.CURRENT_PAYLOAD.cval(dout.payload_mem_data'range) := dout.payload_mem_data;
    v.regs.MAX_SIZE_PAYLOAD_MEM.cval(dout.max_size_payload_mem'range) := dout.max_size_payload_mem;
    v.regs.RX_CMD_FIFO_EMPTY.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_CMD_FIFO_EMPTY.reg_fd_info.EMPTY)) := dout.rx_cmd_fifo_empty;
    v.regs.RX_PAYLOAD_LEN.cval(dout.rx_payload_len'range) := dout.rx_payload_len;
    v.regs.RX_CMD_TYPE.cval(dout.rx_cmd_type'range) := dout.rx_cmd_type;
    v.regs.RX_DST_ADDR.cval(dout.rx_dest_addr'range) := dout.rx_dest_addr;
    v.regs.RX_TRANSACTION_ID.cval(dout.rx_trans_id'range) := dout.rx_trans_id;
    v.regs.RX_CRC_OK.cval(dout.rx_crc_ok'range) := dout.rx_crc_ok;
    v.regs.RX_PAYLOAD_FIFO_EMPTY.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_PAYLOAD_FIFO_EMPTY.reg_fd_info.EMPTY)) := dout.rx_payload_fifo_empty;
    v.regs.RX_PAYLOAD_WORD.cval(dout.rx_payload_fifo_data'range) := dout.rx_payload_fifo_data;
    v.regs.RX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_STATUS.reg_fd_info.BUSY)) := dout.rx_busy;
    v.regs.RX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_STATUS.reg_fd_info.DONE)) := dout.rx_done;
    v.regs.RX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_STATUS.reg_fd_info.CURR_CRC_ERROR_FLAG)) := dout.rx_curr_crc_err_flag;
    v.regs.RX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_STATUS.reg_fd_info.PERSIST_CRC_ERROR_FLAG)) := dout.rx_persist_crc_err_flag;
    v.regs.RX_FRAME_CNT.cval(dout.rx_frame_count'range) := dout.rx_frame_count;
    v.regs.RX_CRC_ERR_CNT.cval(dout.rx_crc_err_count'range) := dout.rx_crc_err_count;
    -- ********** END CONNECT REGISTERS TO MODULE OUTPUT PORTS **********

    -- Update register
    rin <= v;

    -- Registered output assignment
    avs_readdata_o <= r.rdout.oreaddata;

    -- Combinational output assignment
    --avs_readdata_o <= v.rdout.oreaddata;

  END PROCESS;

END ARCHITECTURE;
