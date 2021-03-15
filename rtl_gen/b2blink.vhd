LIBRARY IEEE;
  USE IEEE.STD_LOGIC_1164.ALL;
  USE IEEE.NUMERIC_STD.ALL;
 
LIBRARY WORK;
  USE WORK.B2BLINK_PKG.ALL;
  USE WORK.B2BLINK_TX_PKG.ALL;
  USE WORK.B2BLINK_RX_PKG.ALL;

LIBRARY WORK;
  USE WORK.B2BLINK_REC_PKG.ALL;

ENTITY b2blink IS
  PORT (
    clk_1x_i : IN std_logic;
    clk_5x_i : IN STD_LOGIC;
    rst_n_i : IN std_logic;
    loopback_en_i : IN STD_LOGIC;
    tx_enable_i : IN STD_LOGIC;
    tx_frame_gen_start_i : IN STD_LOGIC;
    tx_pattern_gen_i : IN STD_LOGIC;
    cmd_mem_base_addr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_wren_i : IN STD_LOGIC;
    cmd_mem_wraddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_src_addr_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_dst_addr_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_length_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_cmd_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_tx_trans_id_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_rden_i : IN STD_LOGIC;
    cmd_mem_rdaddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_wren_i : IN STD_LOGIC;
    payload_mem_wraddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_data_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    payload_mem_rden_i : IN STD_LOGIC;
    payload_mem_rdaddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    rx_enable_i : IN STD_LOGIC;
    rx_i : IN STD_LOGIC;
    rx_cmd_fifo_do_read_i : IN STD_LOGIC;
    rx_sample_index_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    rx_payload_fifo_do_read_i : IN STD_LOGIC;
    tx_o : OUT STD_LOGIC;
    tx_done_o : OUT STD_LOGIC;
    tx_busy_o : OUT STD_LOGIC;
    tx_frame_count_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    tx_frame_gen_busy_o : OUT STD_LOGIC;
    tx_frame_gen_done_o : OUT STD_LOGIC;
    cmd_mem_tx_src_addr_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_dst_addr_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_length_o : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_cmd_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_tx_trans_id_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    max_size_command_mem_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    payload_mem_data_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    max_size_payload_mem_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    rx_cmd_fifo_empty_o : OUT STD_LOGIC;
    rx_payload_len_o : OUT STD_LOGIC_VECTOR(PAYLOAD_LEN_WIDTH_C-1 DOWNTO 0);
    rx_cmd_type_o : OUT STD_LOGIC_VECTOR(CMD_TYPE_WIDTH_C-1 DOWNTO 0);
    rx_dest_addr_o : OUT STD_LOGIC_VECTOR(DEST_ADDR_WIDTH_C-1 DOWNTO 0);
    rx_trans_id_o : OUT STD_LOGIC_VECTOR(TRANSACTION_ID_WIDTH_C-1 DOWNTO 0);
    rx_crc_ok_o : OUT STD_LOGIC_VECTOR(CRC_WIDTH_C-1 DOWNTO 0);
    rx_payload_fifo_empty_o : OUT STD_LOGIC;
    rx_payload_fifo_data_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    rx_busy_o : OUT STD_LOGIC;
    rx_done_o : OUT STD_LOGIC;
    rx_curr_crc_err_flag_o : OUT STD_LOGIC;
    rx_persist_crc_err_flag_o : OUT STD_LOGIC;
    rx_frame_count_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
    rx_crc_err_count_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0)
  );
END ENTITY b2blink;

ARCHITECTURE struct OF b2blink  IS
  SIGNAL din : b2blink_rec_input_t;
  SIGNAL dout : b2blink_rec_output_t;
BEGIN

  -- Record component instantiation
  b2blink_rec_inst: WORK.b2blink_rec
    PORT MAP (
      clk_1x_i => clk_1x_i,
      clk_5x_i => clk_5x_i,
      rst_n_i => rst_n_i,
      b2blink_rec_i => din,
      b2blink_rec_o => dout
    );

  -- Connect module inputs ports to input interface record type
  din.loopback_en <= loopback_en_i;
  din.tx_enable <= tx_enable_i;
  din.tx_frame_gen_start <= tx_frame_gen_start_i;
  din.tx_pattern_gen <= tx_pattern_gen_i;
  din.cmd_mem_base_addr <= cmd_mem_base_addr_i;
  din.cmd_mem_wren <= cmd_mem_wren_i;
  din.cmd_mem_wraddr <= cmd_mem_wraddr_i;
  din.cmd_mem_tx_src_addr <= cmd_mem_tx_src_addr_i;
  din.cmd_mem_tx_dst_addr <= cmd_mem_tx_dst_addr_i;
  din.cmd_mem_tx_length <= cmd_mem_tx_length_i;
  din.cmd_mem_tx_cmd <= cmd_mem_tx_cmd_i;
  din.cmd_mem_tx_trans_id <= cmd_mem_tx_trans_id_i;
  din.cmd_mem_rden <= cmd_mem_rden_i;
  din.cmd_mem_rdaddr <= cmd_mem_rdaddr_i;
  din.payload_mem_wren <= payload_mem_wren_i;
  din.payload_mem_wraddr <= payload_mem_wraddr_i;
  din.payload_mem_data <= payload_mem_data_i;
  din.payload_mem_rden <= payload_mem_rden_i;
  din.payload_mem_rdaddr <= payload_mem_rdaddr_i;
  din.rx_enable <= rx_enable_i;
  din.rx <= rx_i;
  din.rx_cmd_fifo_do_read <= rx_cmd_fifo_do_read_i;
  din.rx_sample_index <= rx_sample_index_i;
  din.rx_payload_fifo_do_read <= rx_payload_fifo_do_read_i;

  -- Connect output interface record type to module output ports
  tx_o <= dout.tx;
  tx_done_o <= dout.tx_done;
  tx_busy_o <= dout.tx_busy;
  tx_frame_count_o <= dout.tx_frame_count;
  tx_frame_gen_busy_o <= dout.tx_frame_gen_busy;
  tx_frame_gen_done_o <= dout.tx_frame_gen_done;
  cmd_mem_tx_src_addr_o <= dout.cmd_mem_tx_src_addr;
  cmd_mem_tx_dst_addr_o <= dout.cmd_mem_tx_dst_addr;
  cmd_mem_tx_length_o <= dout.cmd_mem_tx_length;
  cmd_mem_tx_cmd_o <= dout.cmd_mem_tx_cmd;
  cmd_mem_tx_trans_id_o <= dout.cmd_mem_tx_trans_id;
  max_size_command_mem_o <= dout.max_size_command_mem;
  payload_mem_data_o <= dout.payload_mem_data;
  max_size_payload_mem_o <= dout.max_size_payload_mem;
  rx_cmd_fifo_empty_o <= dout.rx_cmd_fifo_empty;
  rx_payload_len_o <= dout.rx_payload_len;
  rx_cmd_type_o <= dout.rx_cmd_type;
  rx_dest_addr_o <= dout.rx_dest_addr;
  rx_trans_id_o <= dout.rx_trans_id;
  rx_crc_ok_o <= dout.rx_crc_ok;
  rx_payload_fifo_empty_o <= dout.rx_payload_fifo_empty;
  rx_payload_fifo_data_o <= dout.rx_payload_fifo_data;
  rx_busy_o <= dout.rx_busy;
  rx_done_o <= dout.rx_done;
  rx_curr_crc_err_flag_o <= dout.rx_curr_crc_err_flag;
  rx_persist_crc_err_flag_o <= dout.rx_persist_crc_err_flag;
  rx_frame_count_o <= dout.rx_frame_count;
  rx_crc_err_count_o <= dout.rx_crc_err_count;

END ARCHITECTURE;

