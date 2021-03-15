LIBRARY IEEE;
  USE IEEE.STD_LOGIC_1164.ALL;
  USE IEEE.NUMERIC_STD.ALL;
 
LIBRARY WORK;
  USE WORK.B2BLINK_PKG.ALL;
  USE WORK.B2BLINK_TX_PKG.ALL;
  USE WORK.B2BLINK_RX_PKG.ALL;

PACKAGE b2blink_rec_pkg IS

  TYPE b2blink_rec_input_t IS RECORD
    loopback_en : STD_LOGIC;
    tx_enable : STD_LOGIC;
    tx_frame_gen_start : STD_LOGIC;
    tx_pattern_gen : STD_LOGIC;
    cmd_mem_base_addr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_wren : STD_LOGIC;
    cmd_mem_wraddr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_src_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_dst_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_length : STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_cmd : STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_tx_trans_id : STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_rden : STD_LOGIC;
    cmd_mem_rdaddr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_wren : STD_LOGIC;
    payload_mem_wraddr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    payload_mem_rden : STD_LOGIC;
    payload_mem_rdaddr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    rx_enable : STD_LOGIC;
    rx : STD_LOGIC;
    rx_cmd_fifo_do_read : STD_LOGIC;
    rx_sample_index : STD_LOGIC_VECTOR(2 DOWNTO 0);
    rx_payload_fifo_do_read : STD_LOGIC;
  END RECORD;

  TYPE b2blink_rec_output_t IS RECORD
    tx : STD_LOGIC;
    tx_done : STD_LOGIC;
    tx_busy : STD_LOGIC;
    tx_frame_count : STD_LOGIC_VECTOR(31 DOWNTO 0);
    tx_frame_gen_busy : STD_LOGIC;
    tx_frame_gen_done : STD_LOGIC;
    cmd_mem_tx_src_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_dst_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_length : STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_cmd : STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_tx_trans_id : STD_LOGIC_VECTOR(2 DOWNTO 0);
    max_size_command_mem : STD_LOGIC_VECTOR(31 DOWNTO 0);
    payload_mem_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    max_size_payload_mem : STD_LOGIC_VECTOR(31 DOWNTO 0);
    rx_cmd_fifo_empty : STD_LOGIC;
    rx_payload_len : STD_LOGIC_VECTOR(PAYLOAD_LEN_WIDTH_C-1 DOWNTO 0);
    rx_cmd_type : STD_LOGIC_VECTOR(CMD_TYPE_WIDTH_C-1 DOWNTO 0);
    rx_dest_addr : STD_LOGIC_VECTOR(DEST_ADDR_WIDTH_C-1 DOWNTO 0);
    rx_trans_id : STD_LOGIC_VECTOR(TRANSACTION_ID_WIDTH_C-1 DOWNTO 0);
    rx_crc_ok : STD_LOGIC_VECTOR(CRC_WIDTH_C-1 DOWNTO 0);
    rx_payload_fifo_empty : STD_LOGIC;
    rx_payload_fifo_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    rx_busy : STD_LOGIC;
    rx_done : STD_LOGIC;
    rx_curr_crc_err_flag : STD_LOGIC;
    rx_persist_crc_err_flag : STD_LOGIC;
    rx_frame_count : STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
    rx_crc_err_count : STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
  END RECORD;

  TYPE b2blink_rec_reg_t IS RECORD
    rec_out : b2blink_rec_output_t;
    --xxx : xxx;
  END RECORD;

  FUNCTION init_b2blink_rec_input_t RETURN b2blink_rec_input_t;
  FUNCTION init_b2blink_rec_output_t RETURN b2blink_rec_output_t;
  FUNCTION init_b2blink_rec_reg_t RETURN b2blink_rec_reg_t;

END PACKAGE b2blink_rec_pkg;

PACKAGE BODY b2blink_rec_pkg IS

  FUNCTION init_b2blink_rec_input_t RETURN b2blink_rec_input_t IS
    VARIABLE v : b2blink_rec_input_t;
  BEGIN
    v.loopback_en := '0';
    v.tx_enable := '0';
    v.tx_frame_gen_start := '0';
    v.tx_pattern_gen := '0';
    v.cmd_mem_base_addr := (OTHERS => '0');
    v.cmd_mem_wren := '0';
    v.cmd_mem_wraddr := (OTHERS => '0');
    v.cmd_mem_tx_src_addr := (OTHERS => '0');
    v.cmd_mem_tx_dst_addr := (OTHERS => '0');
    v.cmd_mem_tx_length := (OTHERS => '0');
    v.cmd_mem_tx_cmd := (OTHERS => '0');
    v.cmd_mem_tx_trans_id := (OTHERS => '0');
    v.cmd_mem_rden := '0';
    v.cmd_mem_rdaddr := (OTHERS => '0');
    v.payload_mem_wren := '0';
    v.payload_mem_wraddr := (OTHERS => '0');
    v.payload_mem_data := (OTHERS => '0');
    v.payload_mem_rden := '0';
    v.payload_mem_rdaddr := (OTHERS => '0');
    v.rx_enable := '0';
    v.rx := '0';
    v.rx_cmd_fifo_do_read := '0';
    v.rx_sample_index := (OTHERS => '0');
    v.rx_payload_fifo_do_read := '0';
    RETURN v;
  END FUNCTION;

  FUNCTION init_b2blink_rec_output_t RETURN b2blink_rec_output_t IS
    VARIABLE v : b2blink_rec_output_t;
  BEGIN
    v.tx := '0';
    v.tx_done := '0';
    v.tx_busy := '0';
    v.tx_frame_count := (OTHERS => '0');
    v.tx_frame_gen_busy := '0';
    v.tx_frame_gen_done := '0';
    v.cmd_mem_tx_src_addr := (OTHERS => '0');
    v.cmd_mem_tx_dst_addr := (OTHERS => '0');
    v.cmd_mem_tx_length := (OTHERS => '0');
    v.cmd_mem_tx_cmd := (OTHERS => '0');
    v.cmd_mem_tx_trans_id := (OTHERS => '0');
    v.max_size_command_mem := (OTHERS => '0');
    v.payload_mem_data := (OTHERS => '0');
    v.max_size_payload_mem := (OTHERS => '0');
    v.rx_cmd_fifo_empty := '0';
    v.rx_payload_len := (OTHERS => '0');
    v.rx_cmd_type := (OTHERS => '0');
    v.rx_dest_addr := (OTHERS => '0');
    v.rx_trans_id := (OTHERS => '0');
    v.rx_crc_ok := (OTHERS => '0');
    v.rx_payload_fifo_empty := '0';
    v.rx_payload_fifo_data := (OTHERS => '0');
    v.rx_busy := '0';
    v.rx_done := '0';
    v.rx_curr_crc_err_flag := '0';
    v.rx_persist_crc_err_flag := '0';
    v.rx_frame_count := (OTHERS => '0');
    v.rx_crc_err_count := (OTHERS => '0');
    RETURN v;
  END FUNCTION;

  FUNCTION init_b2blink_rec_reg_t RETURN b2blink_rec_reg_t IS
    VARIABLE v : b2blink_rec_reg_t;
  BEGIN
    v.rec_out := init_b2blink_rec_output_t;
    --v.xxx := xxx;
    RETURN v;
  END FUNCTION;

END PACKAGE BODY b2blink_rec_pkg;
