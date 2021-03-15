LIBRARY IEEE;
  USE IEEE.STD_LOGIC_1164.ALL;
  USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
  USE work.base_regdef_pkg.ALL;
  USE work.base_32b_regdef_pkg.ALL;
  USE work.base_32b_64b_regdef_pkg.ALL;
  USE work.avs_common_pkg.ALL;
  USE work.regdef_b2b_pkg.ALL;
  USE work.avs_b2blink_pkg.ALL;
  USE work.b2blink_pkg.ALL;


ENTITY avs_b2blink IS
  PORT (
    clk_1x_i : IN std_logic;
    clk_5x_i : IN std_logic;
    rst_n_i : IN std_logic;
    -- Avalon slave interface
    avs_address_i : IN std_logic_vector(AVS_ADDR_WIDTH_C-1 DOWNTO 0);
    avs_write_i : IN std_logic;
    avs_writedata_i : IN std_logic_vector(AVS_DATA_WIDTH_C-1 DOWNTO 0);
    avs_read_i : IN std_logic;
    avs_readdata_o : OUT std_logic_vector(AVS_DATA_WIDTH_C-1 DOWNTO 0);
    -- Avalon input conduits
    rx_i : IN std_logic;
    -- Avalon output conduits
    tx_o : OUT std_logic
  );
END ENTITY avs_b2blink;

ARCHITECTURE struct OF avs_b2blink IS

  SIGNAL r, rin : avs_b2blink_reg_t;
  SIGNAL slave_i : avs_input_t;


  SIGNAL loopback_en_i_s : STD_LOGIC;

  --TX-FRAME-GEN-REGISTER
  -- r/w ctrl registers
  SIGNAL tx_enable_i_s : STD_LOGIC;
  SIGNAL tx_frame_gen_start_i_s : STD_LOGIC;
  SIGNAL tx_pattern_gen_i_s : STD_LOGIC;
  SIGNAL cmd_mem_base_addr_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  -- read-only status registers
  SIGNAL tx_done_o_s : STD_LOGIC;
  SIGNAL tx_busy_o_s : STD_LOGIC;
  SIGNAL tx_frame_count_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL tx_frame_gen_busy_o_s : STD_LOGIC;
  SIGNAL tx_frame_gen_done_o_s : STD_LOGIC;

  --CMD-MEMORY WRITE-IF
  SIGNAL cmd_mem_wren_i_s : STD_LOGIC;
  SIGNAL cmd_mem_wraddr_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL cmd_mem_tx_src_addr_i_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL cmd_mem_tx_dst_addr_i_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL cmd_mem_tx_length_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL cmd_mem_tx_cmd_i_s : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL cmd_mem_tx_trans_id_i_s : STD_LOGIC_VECTOR(2 DOWNTO 0);

  --CMD-MEMORY READ-IF (Read only possible when Frame Generator not 
  SIGNAL cmd_mem_rden_i_s : STD_LOGIC;
  SIGNAL cmd_mem_rdaddr_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL cmd_mem_tx_src_addr_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL cmd_mem_tx_dst_addr_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL cmd_mem_tx_length_o_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL cmd_mem_tx_cmd_o_s : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL cmd_mem_tx_trans_id_o_s : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL max_size_command_mem_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

  --CMD-MEMORY WRITE-IF
  SIGNAL payload_mem_wren_i_s : STD_LOGIC;
  SIGNAL payload_mem_wraddr_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL payload_mem_data_i_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

  --CMD-MEMORY READ-IF (Only possible to read when Frame Generator n
  SIGNAL payload_mem_rden_i_s : STD_LOGIC;
  SIGNAL payload_mem_rdaddr_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL payload_mem_data_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL max_size_payload_mem_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

  -- RX-Side Ports
  -- Global RX-Enable
  SIGNAL rx_enable_i_s : STD_LOGIC;
  -- rx-input port

  -- rx-cmd-fifo if
  SIGNAL rx_cmd_fifo_empty_o_s : STD_LOGIC;
  SIGNAL rx_cmd_fifo_do_read_i_s : STD_LOGIC;
  SIGNAL rx_payload_len_o_s : STD_LOGIC_VECTOR(PAYLOAD_LEN_WIDTH_C-1 DOWNTO 0);
  SIGNAL rx_cmd_type_o_s : STD_LOGIC_VECTOR(CMD_TYPE_WIDTH_C-1 DOWNTO 0);
  SIGNAL rx_dest_addr_o_s : STD_LOGIC_VECTOR(DEST_ADDR_WIDTH_C-1 DOWNTO 0);
  SIGNAL rx_trans_id_o_s : STD_LOGIC_VECTOR(TRANSACTION_ID_WIDTH_C-1 DOWNTO 0);
  SIGNAL rx_crc_ok_o_s : STD_LOGIC_VECTOR(CRC_WIDTH_C-1 DOWNTO 0);

  -- rx-payload fifo if
  SIGNAL rx_payload_fifo_empty_o_s : STD_LOGIC;
  SIGNAL rx_payload_fifo_do_read_i_s : STD_LOGIC;
  SIGNAL rx_payload_fifo_data_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

  -- rx-status
  SIGNAL rx_busy_o_s : STD_LOGIC;
  SIGNAL rx_done_o_s : STD_LOGIC;
  SIGNAL rx_curr_crc_err_flag_o_s : STD_LOGIC;
  SIGNAL rx_persist_crc_err_flag_o_s : STD_LOGIC;
  SIGNAL rx_frame_count_o_s : STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
  SIGNAL rx_crc_err_count_o_s : STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);

BEGIN

  -- Connect external avalon input conduits to internal signal

  -- Connect avs input ports to internal signal
  slave_i.iaddress <= avs_address_i;
  slave_i.iwrite <= avs_write_i;
  slave_i.iwritedata <= avs_writedata_i;
  slave_i.iread <= avs_read_i;


  -- Record component instantiation
  b2blink_top_inst: ENTITY work.b2blink_top
    PORT MAP (
      clk_1x_i                  => clk_1x_i,
      clk_5x_i                  => clk_5x_i,
      rst_n_i                   => rst_n_i,
      rx_i                      => rx_i,
      tx_o                      => tx_o,
      loopback_en_i             => loopback_en_i_s,
      tx_enable_i               => tx_enable_i_s,
      tx_frame_gen_start_i      => tx_frame_gen_start_i_s,
      tx_pattern_gen_i          => tx_pattern_gen_i_s,
      cmd_mem_base_addr_i       => cmd_mem_base_addr_i_s,
      tx_done_o                 => tx_done_o_s,
      tx_busy_o                 => tx_busy_o_s,
      tx_frame_count_o          => tx_frame_count_o_s,
      tx_frame_gen_busy_o       => tx_frame_gen_busy_o_s,
      tx_frame_gen_done_o       => tx_frame_gen_done_o_s,
      cmd_mem_wren_i            => cmd_mem_wren_i_s,
      cmd_mem_wraddr_i          => cmd_mem_wraddr_i_s,
      cmd_mem_tx_src_addr_i     => cmd_mem_tx_src_addr_i_s,
      cmd_mem_tx_dst_addr_i     => cmd_mem_tx_dst_addr_i_s,
      cmd_mem_tx_length_i       => cmd_mem_tx_length_i_s,
      cmd_mem_tx_cmd_i          => cmd_mem_tx_cmd_i_s,
      cmd_mem_tx_trans_id_i     => cmd_mem_tx_trans_id_i_s,
      cmd_mem_rden_i            => cmd_mem_rden_i_s,
      cmd_mem_rdaddr_i          => cmd_mem_rdaddr_i_s,
      cmd_mem_tx_src_addr_o     => cmd_mem_tx_src_addr_o_s,
      cmd_mem_tx_dst_addr_o     => cmd_mem_tx_dst_addr_o_s,
      cmd_mem_tx_length_o       => cmd_mem_tx_length_o_s,
      cmd_mem_tx_cmd_o          => cmd_mem_tx_cmd_o_s,
      cmd_mem_tx_trans_id_o     => cmd_mem_tx_trans_id_o_s,
      max_size_command_mem_o    => max_size_command_mem_o_s,
      payload_mem_wren_i        => payload_mem_wren_i_s,
      payload_mem_wraddr_i      => payload_mem_wraddr_i_s,
      payload_mem_data_i        => payload_mem_data_i_s,
      payload_mem_rden_i        => payload_mem_rden_i_s,
      payload_mem_rdaddr_i      => payload_mem_rdaddr_i_s,
      payload_mem_data_o        => payload_mem_data_o_s,
      max_size_payload_mem_o    => max_size_payload_mem_o_s,
      rx_enable_i               => rx_enable_i_s,
      rx_cmd_fifo_empty_o       => rx_cmd_fifo_empty_o_s,
      rx_cmd_fifo_do_read_i     => rx_cmd_fifo_do_read_i_s,
      rx_payload_len_o          => rx_payload_len_o_s,
      rx_cmd_type_o             => rx_cmd_type_o_s,
      rx_dest_addr_o            => rx_dest_addr_o_s,
      rx_trans_id_o             => rx_trans_id_o_s,
      rx_crc_ok_o               => rx_crc_ok_o_s,
      rx_payload_fifo_empty_o   => rx_payload_fifo_empty_o_s,
      rx_payload_fifo_do_read_i => rx_payload_fifo_do_read_i_s,
      rx_payload_fifo_data_o    => rx_payload_fifo_data_o_s,
      rx_busy_o                 => rx_busy_o_s,
      rx_done_o                 => rx_done_o_s,
      rx_curr_crc_err_flag_o    => rx_curr_crc_err_flag_o_s,
      rx_persist_crc_err_flag_o => rx_persist_crc_err_flag_o_s,
      rx_frame_count_o          => rx_frame_count_o_s,
      rx_crc_err_count_o        => rx_crc_err_count_o_s
    );


  -- Update component input ports with content from register block
  -- ********** START CONNECT REGISTERS TO MODULE INPUT PORTS **********
  loopback_en_i_s             <= r.regs.LOOPBACK.cval(get_field_lwb(C_B2BLINK_BLOCK.LOOPBACK.reg_fd_info.EN));
  tx_enable_i_s               <= r.regs.ENABLE.cval(get_field_lwb(C_B2BLINK_BLOCK.ENABLE.reg_fd_info.TX_EN));
  tx_frame_gen_start_i_s      <= r.regs.DMA_TRANSMIT.cval(get_field_lwb(C_B2BLINK_BLOCK.DMA_TRANSMIT.reg_fd_info.START));
  tx_pattern_gen_i_s          <= r.regs.TEST_PATTERN.cval(get_field_lwb(C_B2BLINK_BLOCK.TEST_PATTERN.reg_fd_info.ENABLE));
  cmd_mem_wren_i_s            <= r.regs.CMD_WEN.cval(get_field_lwb(C_B2BLINK_BLOCK.CMD_WEN.reg_fd_info.EN));
  cmd_mem_rden_i_s            <= r.regs.CMD_REN.cval(get_field_lwb(C_B2BLINK_BLOCK.CMD_REN.reg_fd_info.EN));
  payload_mem_wren_i_s        <= r.regs.PAYLOAD_WEN.cval(get_field_lwb(C_B2BLINK_BLOCK.PAYLOAD_WEN.reg_fd_info.EN));
  payload_mem_rden_i_s        <= r.regs.PAYLOAD_REN.cval(get_field_lwb(C_B2BLINK_BLOCK.PAYLOAD_REN.reg_fd_info.EN));
  rx_enable_i_s               <= r.regs.ENABLE.cval(get_field_lwb(C_B2BLINK_BLOCK.ENABLE.reg_fd_info.RX_EN));
  rx_cmd_fifo_do_read_i_s     <= r.regs.RX_CMD_FIFO_REN.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_CMD_FIFO_REN.reg_fd_info.READ1));
  rx_payload_fifo_do_read_i_s <= r.regs.RX_PAYLOAD_FIFO_REN.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_PAYLOAD_FIFO_REN.reg_fd_info.READ1));
  cmd_mem_base_addr_i_s       <= r.regs.CMD_LIST_START_INDEX.cval(cmd_mem_base_addr_i_s'range);
  cmd_mem_wraddr_i_s          <= r.regs.CMD_INDEX.cval(cmd_mem_wraddr_i_s'range);
  cmd_mem_tx_src_addr_i_s     <= r.regs.DMA_SRC_ADDR.cval(cmd_mem_tx_src_addr_i_s'range);
  cmd_mem_tx_dst_addr_i_s     <= r.regs.DMA_DST_ADDR.cval(cmd_mem_tx_dst_addr_i_s'range);
  cmd_mem_tx_length_i_s       <= r.regs.DMA_PAYLOAD_NUM_WORDS.cval(cmd_mem_tx_length_i_s'range);
  cmd_mem_tx_cmd_i_s          <= r.regs.DMA_CMD_TYPE.cval(cmd_mem_tx_cmd_i_s'range);
  cmd_mem_tx_trans_id_i_s     <= r.regs.DMA_CMD_TRANSITION_ID.cval(cmd_mem_tx_trans_id_i_s'range);
  cmd_mem_rdaddr_i_s          <= r.regs.CMD_RINDEX.cval(cmd_mem_rdaddr_i_s'range);
  payload_mem_wraddr_i_s      <= r.regs.PAYLOAD_INDEX.cval(payload_mem_wraddr_i_s'range);
  payload_mem_data_i_s        <= r.regs.PAYLOAD.cval(payload_mem_data_i_s'range);
  payload_mem_rdaddr_i_s      <= r.regs.PAYLOAD_RINDEX.cval(payload_mem_rdaddr_i_s'range);
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

  comb_proc: PROCESS(r, slave_i, tx_done_o_s, tx_busy_o_s, tx_frame_count_o_s, tx_frame_gen_busy_o_s, tx_frame_gen_done_o_s, cmd_mem_tx_src_addr_o_s, cmd_mem_tx_dst_addr_o_s,
                     cmd_mem_tx_length_o_s, cmd_mem_tx_cmd_o_s, cmd_mem_tx_trans_id_o_s, max_size_command_mem_o_s, payload_mem_data_o_s, max_size_payload_mem_o_s, rx_cmd_fifo_empty_o_s, 
                     rx_payload_len_o_s, rx_cmd_type_o_s, rx_dest_addr_o_s, rx_trans_id_o_s, rx_crc_ok_o_s, rx_payload_fifo_empty_o_s, rx_payload_fifo_data_o_s, rx_busy_o_s, rx_done_o_s,
                     rx_curr_crc_err_flag_o_s, rx_persist_crc_err_flag_o_s, rx_frame_count_o_s, rx_crc_err_count_o_s) IS
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
    v.regs.TX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.TX_STATUS.reg_fd_info.DONE)) := tx_done_o_s;
    v.regs.TX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.TX_STATUS.reg_fd_info.BUSY)) := tx_busy_o_s;
    v.regs.TX_FRAME_CNT.cval(tx_frame_count_o_s'range) := tx_frame_count_o_s;
    v.regs.FRAME_GEN_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.FRAME_GEN_STATUS.reg_fd_info.BUSY)) := tx_frame_gen_busy_o_s;
    v.regs.FRAME_GEN_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.FRAME_GEN_STATUS.reg_fd_info.DONE)) := tx_frame_gen_done_o_s;
    v.regs.DMA_CURRENT_SRC_ADDR.cval(cmd_mem_tx_src_addr_o_s'range) := cmd_mem_tx_src_addr_o_s;
    v.regs.DMA_CURRENT_DST_ADDR.cval(cmd_mem_tx_dst_addr_o_s'range) := cmd_mem_tx_dst_addr_o_s;
    v.regs.DMA_CURRENT_PAYLOAD_NUM_WORDS.cval(cmd_mem_tx_length_o_s'range) := cmd_mem_tx_length_o_s;
    v.regs.DMA_CURRENT_CMD_TYPE.cval(cmd_mem_tx_cmd_o_s'range) := cmd_mem_tx_cmd_o_s;
    v.regs.DMA_CURRENT_CMD_TRANSITION_ID.cval(cmd_mem_tx_trans_id_o_s'range) := cmd_mem_tx_trans_id_o_s;
    v.regs.MAX_SIZE_COMMAND_MEM.cval(max_size_command_mem_o_s'range) := max_size_command_mem_o_s;
    v.regs.CURRENT_PAYLOAD.cval(payload_mem_data_o_s'range) := payload_mem_data_o_s;
    v.regs.MAX_SIZE_PAYLOAD_MEM.cval(max_size_payload_mem_o_s'range) := max_size_payload_mem_o_s;
    v.regs.RX_CMD_FIFO_EMPTY.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_CMD_FIFO_EMPTY.reg_fd_info.EMPTY)) := rx_cmd_fifo_empty_o_s;
    v.regs.RX_PAYLOAD_LEN.cval(rx_payload_len_o_s'range) := rx_payload_len_o_s;
    v.regs.RX_CMD_TYPE.cval(rx_cmd_type_o_s'range) := rx_cmd_type_o_s;
    v.regs.RX_DST_ADDR.cval(rx_dest_addr_o_s'range) := rx_dest_addr_o_s;
    v.regs.RX_TRANSITION_ID.cval(rx_trans_id_o_s'range) := rx_trans_id_o_s;
    v.regs.RX_CRC_OK.cval(rx_crc_ok_o_s'range) := rx_crc_ok_o_s;
    v.regs.RX_PAYLOAD_FIFO_EMPTY.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_PAYLOAD_FIFO_EMPTY.reg_fd_info.EMPTY)) := rx_payload_fifo_empty_o_s;
    v.regs.RX_PAYLOAD_WORD.cval(rx_payload_fifo_data_o_s'range) := rx_payload_fifo_data_o_s;
    v.regs.RX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_STATUS.reg_fd_info.BUSY)) := rx_busy_o_s;
    v.regs.RX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_STATUS.reg_fd_info.DONE)) := rx_done_o_s;
    v.regs.RX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_STATUS.reg_fd_info.CURR_CRC_ERROR_FLAG)) := rx_curr_crc_err_flag_o_s;
    v.regs.RX_STATUS.cval(get_field_lwb(C_B2BLINK_BLOCK.RX_STATUS.reg_fd_info.PERSIST_CRC_ERROR_FLAG)) := rx_persist_crc_err_flag_o_s;
    v.regs.RX_FRAME_CNT.cval(rx_frame_count_o_s'range) := rx_frame_count_o_s;
    v.regs.RX_CRC_ERR_CNT.cval(rx_crc_err_count_o_s'range) := rx_crc_err_count_o_s;
    -- ********** END CONNECT REGISTERS TO MODULE OUTPUT PORTS **********

    -- Update slave data output 
    rin <= v;

    -- Registered output assignment
    avs_readdata_o <= r.rdout.oreaddata;

  END PROCESS;

END ARCHITECTURE;
