LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;
  USE WORK.b2blink_tx_pkg.ALL;
  USE WORK.b2blink_rx_pkg.ALL;

ENTITY b2blink_top IS
  PORT (
    clk_1x_i: IN  std_logic;
    rst_n_i: IN  std_logic;

    loopback_en_i : IN STD_LOGIC;

    -- External Tx-IF
    tx_o : OUT STD_LOGIC;

    --TX-FRAME-GEN-REGISTER
    -- r/w ctrl registers
    tx_enable_i : IN STD_LOGIC;
    tx_frame_gen_start_i : IN STD_LOGIC;
    tx_pattern_gen_i : IN STD_LOGIC;
    cmd_mem_base_addr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    -- read-only status registers
    tx_done_o : OUT STD_LOGIC;
    tx_busy_o : OUT STD_LOGIC;
    tx_frame_count_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    tx_frame_gen_busy_o : OUT STD_LOGIC;
    tx_frame_gen_done_o : OUT STD_LOGIC;

    --CMD-MEMORY WRITE-IF
    cmd_mem_wren_i : IN STD_LOGIC;
    cmd_mem_wraddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_src_addr_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_dst_addr_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_length_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_cmd_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_tx_trans_id_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);

    --CMD-MEMORY READ-IF (Read only possible when Frame Generator not busy (csr_frame_gen_busy_o==0) otherwise returns 0)
    cmd_mem_rden_i : IN STD_LOGIC;
    cmd_mem_rdaddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_src_addr_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_dst_addr_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_length_o : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_cmd_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_tx_trans_id_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    max_size_command_mem_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

    --CMD-MEMORY WRITE-IF
    payload_mem_wren_i : IN STD_LOGIC;
    payload_mem_wraddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_data_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

    --CMD-MEMORY READ-IF (Only possible to read when Frame Generator not busy (csr_frame_gen_busy_o==0) otherwise returns 0)
    payload_mem_rden_i : IN STD_LOGIC;
    payload_mem_rdaddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_data_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    max_size_payload_mem_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- RX-Side Ports
    clk_5x_i : IN STD_LOGIC;

    -- Global RX-Enable
    rx_enable_i : IN STD_LOGIC;
    -- rx-input port
    rx_i : IN STD_LOGIC;

    -- rx-cmd-fifo if
    rx_cmd_fifo_empty_o : OUT STD_LOGIC;
    rx_cmd_fifo_do_read_i : IN STD_LOGIC;
    rx_payload_len_o : OUT STD_LOGIC_VECTOR(PAYLOAD_LEN_WIDTH_C-1 DOWNTO 0);
    rx_cmd_type_o : OUT STD_LOGIC_VECTOR(CMD_TYPE_WIDTH_C-1 DOWNTO 0);
    rx_dest_addr_o : OUT STD_LOGIC_VECTOR(DEST_ADDR_WIDTH_C-1 DOWNTO 0);
    rx_trans_id_o : OUT STD_LOGIC_VECTOR(TRANSACTION_ID_WIDTH_C-1 DOWNTO 0);
    rx_crc_ok_o : OUT STD_LOGIC_VECTOR(CRC_WIDTH_C-1 DOWNTO 0);
    rx_sample_index_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    
    -- rx-payload fifo if
    rx_payload_fifo_empty_o : OUT STD_LOGIC;
    rx_payload_fifo_do_read_i : IN STD_LOGIC;
    rx_payload_fifo_data_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- rx-status
    rx_busy_o : OUT STD_LOGIC;
    rx_done_o : OUT STD_LOGIC;
    rx_curr_crc_err_flag_o : OUT STD_LOGIC;
    rx_persist_crc_err_flag_o : OUT STD_LOGIC;
    rx_frame_count_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
    rx_crc_err_count_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0)
  );
END ENTITY;

ARCHITECTURE rtl OF b2blink_top IS
  SIGNAL tx_o_s : STD_LOGIC;
  SIGNAL rx_i_s : STD_LOGIC;
BEGIN
  
  rx_i_s <= tx_o_s WHEN loopback_en_i = '1' ELSE rx_i;
  tx_o <= tx_o_s;

  b2blink_tx_top_inst: entity work.b2blink_tx_top
    PORT MAP (
      clk_1x_i               => clk_1x_i,
      rst_n_i                => rst_n_i,
      tx_o                   => tx_o_s,
      tx_enable_i            => tx_enable_i,
      tx_frame_gen_start_i   => tx_frame_gen_start_i,
      tx_pattern_gen_i       => tx_pattern_gen_i,
      cmd_mem_base_addr_i    => cmd_mem_base_addr_i,
      tx_done_o              => tx_done_o,
      tx_busy_o              => tx_busy_o,
      tx_frame_count_o       => tx_frame_count_o,
      tx_frame_gen_busy_o    => tx_frame_gen_busy_o,
      tx_frame_gen_done_o    => tx_frame_gen_done_o,
      cmd_mem_wren_i         => cmd_mem_wren_i,
      cmd_mem_wraddr_i       => cmd_mem_wraddr_i,
      cmd_mem_tx_src_addr_i  => cmd_mem_tx_src_addr_i,
      cmd_mem_tx_dst_addr_i  => cmd_mem_tx_dst_addr_i,
      cmd_mem_tx_length_i    => cmd_mem_tx_length_i,
      cmd_mem_tx_cmd_i       => cmd_mem_tx_cmd_i,
      cmd_mem_tx_trans_id_i  => cmd_mem_tx_trans_id_i,
      cmd_mem_rden_i         => cmd_mem_rden_i,
      cmd_mem_rdaddr_i       => cmd_mem_rdaddr_i,
      cmd_mem_tx_src_addr_o  => cmd_mem_tx_src_addr_o,
      cmd_mem_tx_dst_addr_o  => cmd_mem_tx_dst_addr_o,
      cmd_mem_tx_length_o    => cmd_mem_tx_length_o,
      cmd_mem_tx_cmd_o       => cmd_mem_tx_cmd_o,
      cmd_mem_tx_trans_id_o  => cmd_mem_tx_trans_id_o,
      max_size_command_mem_o => max_size_command_mem_o,
      payload_mem_wren_i     => payload_mem_wren_i,
      payload_mem_wraddr_i   => payload_mem_wraddr_i,
      payload_mem_data_i     => payload_mem_data_i,
      payload_mem_rden_i     => payload_mem_rden_i,
      payload_mem_rdaddr_i   => payload_mem_rdaddr_i,
      payload_mem_data_o     => payload_mem_data_o,
      max_size_payload_mem_o => max_size_payload_mem_o
    );
  
  b2blink_rx_top_inst: entity work.b2blink_rx_top
    PORT MAP (
      clk_1x_i                  => clk_1x_i,
      clk_5x_i                  => clk_5x_i,
      rst_n_i                   => rst_n_i,
      rx_enable_i               => rx_enable_i,
      rx_i                      => rx_i_s,
      rx_cmd_fifo_empty_o       => rx_cmd_fifo_empty_o,
      rx_cmd_fifo_do_read_i     => rx_cmd_fifo_do_read_i,
      rx_payload_len_o          => rx_payload_len_o,
      rx_cmd_type_o             => rx_cmd_type_o,
      rx_dest_addr_o            => rx_dest_addr_o,
      rx_trans_id_o             => rx_trans_id_o,
      rx_crc_ok_o               => rx_crc_ok_o,
      rx_sample_index_i         => rx_sample_index_i,
      rx_payload_fifo_empty_o   => rx_payload_fifo_empty_o,
      rx_payload_fifo_do_read_i => rx_payload_fifo_do_read_i,
      rx_payload_fifo_data_o    => rx_payload_fifo_data_o,
      rx_busy_o                 => rx_busy_o,
      rx_done_o                 => rx_done_o,
      rx_curr_crc_err_flag_o    => rx_curr_crc_err_flag_o,
      rx_persist_crc_err_flag_o => rx_persist_crc_err_flag_o,
      rx_frame_count_o          => rx_frame_count_o,
      rx_crc_err_count_o        => rx_crc_err_count_o
    );
  
END ARCHITECTURE;
