LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;
  USE WORK.b2blink_tx_pkg.ALL;
  USE WORK.b2blink_rx_pkg.ALL;

ENTITY b2blink_rx_top IS
  PORT (
    clk_1x_i: IN  std_logic;
    clk_5x_i: IN  std_logic;

    rst_n_i: IN  std_logic;

    -- GLOBAL RX-ENABLE
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

ARCHITECTURE rtl OF b2blink_rx_top IS
  SIGNAL rx_cmd_fifo_do_read_i_r : STD_LOGIC;
  SIGNAL rx_cmd_fifo_do_read_i_r_d : STD_LOGIC;
  SIGNAL rx_cmd_fifo_do_read_i_edge : STD_LOGIC;
  SIGNAL rx_cmd_fifo_do_read_i_edge_r : STD_LOGIC;

  SIGNAL rx_payload_fifo_do_read_i_r : STD_LOGIC;
  SIGNAL rx_payload_fifo_do_read_i_r_d : STD_LOGIC;
  SIGNAL rx_payload_fifo_do_read_i_edge : STD_LOGIC;
  SIGNAL rx_payload_fifo_do_read_i_edge_r : STD_LOGIC;
  
  CONSTANT SYNCED_FLAGS_WIDTH_C : INTEGER := 4;
  SIGNAL rx_unsynced_i_cdc_flags : STD_LOGIC_VECTOR(SYNCED_FLAGS_WIDTH_C-1 DOWNTO 0);
  ALIAS rx_unsynced_busy_i_a : STD_LOGIC IS rx_unsynced_i_cdc_flags(0);
  ALIAS rx_unsynced_done_i_a : STD_LOGIC IS rx_unsynced_i_cdc_flags(1);
  ALIAS rx_unsynced_curr_crc_err_flag_i_a : STD_LOGIC IS rx_unsynced_i_cdc_flags(2);
  ALIAS rx_unsynced_persist_crc_err_flag_i_a : STD_LOGIC IS rx_unsynced_i_cdc_flags(3);

  SIGNAL rx_synced_o_cdc_flags : STD_LOGIC_VECTOR(SYNCED_FLAGS_WIDTH_C-1 DOWNTO 0);
  ALIAS rx_synced_busy_o_a : STD_LOGIC IS rx_synced_o_cdc_flags(0);
  ALIAS rx_synced_done_o_a : STD_LOGIC IS rx_synced_o_cdc_flags(1);
  ALIAS rx_synced_curr_crc_error_flag_o_a : STD_LOGIC IS rx_synced_o_cdc_flags(2);
  ALIAS rx_synced_persist_crc_error_flag_o_a : STD_LOGIC IS rx_synced_o_cdc_flags(3);

  SIGNAL rx_synced_o_cdc_flags_r : STD_LOGIC_VECTOR(SYNCED_FLAGS_WIDTH_C-1 DOWNTO 0);
  ALIAS rx_synced_busy_o_a_r : STD_LOGIC IS rx_synced_o_cdc_flags_r(0);
  ALIAS rx_synced_done_o_a_r : STD_LOGIC IS rx_synced_o_cdc_flags_r(1);
  ALIAS rx_synced_curr_crc_err_flag_o_a_r : STD_LOGIC IS rx_synced_o_cdc_flags_r(2);
  ALIAS rx_synced_persist_crc_err_flag_o_a_r : STD_LOGIC IS rx_synced_o_cdc_flags_r(3);
  
  SIGNAL rx_enable_synced : STD_LOGIC;
  SIGNAL rx_frame_cnt_r, rx_frame_cnt_ns : UNSIGNED(31 DOWNTO 0);
  SIGNAL rx_crc_err_cnt_r, rx_crc_err_cnt_ns : UNSIGNED(31 DOWNTO 0);
  
  SIGNAL rx_cmd_fifo_full_o_s : STD_LOGIC;
  SIGNAL rx_cmd_fifo_wren_i_s : STD_LOGIC;
  SIGNAL rx_cmd_fifo_data_i_s : STD_LOGIC_VECTOR(47 DOWNTO 0);

  SIGNAL rx_payload_fifo_full_o_s : STD_LOGIC;
  SIGNAL rx_payload_fifo_wren_i_s : STD_LOGIC;
  SIGNAL rx_payload_fifo_data_i_s : STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
  
  SIGNAL rx_cmd_fifo_data_o_s : STD_LOGIC_VECTOR(47 DOWNTO 0);
  ALIAS rx_payload_len_o_a : STD_LOGIC_VECTOR(9 DOWNTO 0) IS rx_cmd_fifo_data_o_s(47 DOWNTO 38);
  ALIAS rx_cmd_type_o_a : STD_LOGIC_VECTOR(2 DOWNTO 0) IS rx_cmd_fifo_data_o_s(37 DOWNTO 35);
  ALIAS rx_dest_addr_o_a : STD_LOGIC_VECTOR(23 DOWNTO 0) IS rx_cmd_fifo_data_o_s(34 DOWNTO 11);
  ALIAS rx_trans_id_o_a : STD_LOGIC_VECTOR(2 DOWNTO 0) IS rx_cmd_fifo_data_o_s(10 DOWNTO 8);
  ALIAS rx_crc_ok_o_a : STD_LOGIC_VECTOR(7 DOWNTO 0) IS rx_cmd_fifo_data_o_s(7 DOWNTO 0);
  
  SIGNAL rx_done_r, rx_done_rr : STD_LOGIC;
  SIGNAL curr_crc_err_flag_r, curr_crc_err_flag_rr : STD_LOGIC;
  
BEGIN
  
  cmd_do_read: PROCESS (clk_1x_i) IS
  BEGIN
    IF RISING_EDGE(clk_1x_i) THEN
      IF (rst_n_i = '0') THEN
        rx_cmd_fifo_do_read_i_r <= '0';
        rx_cmd_fifo_do_read_i_r_d <= '0';
        rx_cmd_fifo_do_read_i_edge_r <= '0';
      ELSE
        rx_cmd_fifo_do_read_i_r <= rx_cmd_fifo_do_read_i;
        rx_cmd_fifo_do_read_i_r_d <= rx_cmd_fifo_do_read_i_r;
        rx_cmd_fifo_do_read_i_edge_r <= rx_cmd_fifo_do_read_i_edge;
      END IF;
    END IF;
  END PROCESS;

  payload_do_read: PROCESS (clk_1x_i) IS
  BEGIN
    IF RISING_EDGE(clk_1x_i) THEN
      IF (rst_n_i = '0') THEN
        rx_payload_fifo_do_read_i_r <= '0';
        rx_payload_fifo_do_read_i_r_d <= '0';
        rx_payload_fifo_do_read_i_edge_r <= '0';
      ELSE
        rx_payload_fifo_do_read_i_r <= rx_payload_fifo_do_read_i;
        rx_payload_fifo_do_read_i_r_d <= rx_payload_fifo_do_read_i_r;
        rx_payload_fifo_do_read_i_edge_r <= rx_payload_fifo_do_read_i_edge;
      END IF;
    END IF;
  END PROCESS;
  
  counter_reg: PROCESS (clk_1x_i) IS
  BEGIN
    IF RISING_EDGE(clk_1x_i) THEN
      IF (rst_n_i = '0') THEN
        rx_frame_cnt_r <= (OTHERS => '0');
        rx_crc_err_cnt_r <= (OTHERS => '0');
      ELSE
        rx_frame_cnt_r <= rx_frame_cnt_ns;
        rx_crc_err_cnt_r <= rx_crc_err_cnt_ns;
      END IF;
    END IF;
  END PROCESS;

  
  rx_flags_cdc_syncer: FOR flag_idx IN 0 TO SYNCED_FLAGS_WIDTH_C-1 GENERATE
    busy_flag_cdc: ENTITY work.synchronizer_2d
      GENERIC MAP (
        NBR_OF_SRC_FF  => 1,
        NBR_OF_DST_FF  => 2
      )
      PORT MAP (
        clk_src_i      => clk_5x_i,
        rst_src_n_i    => rst_n_i,
        clk_dst_i      => clk_1x_i,
        rst_dst_n_i    => rst_n_i,
        unsynced_src_i => rx_unsynced_i_cdc_flags(flag_idx),
        synced_dst_o   => rx_synced_o_cdc_flags(flag_idx)
      );
  END GENERATE;
  
  rx_enable_flag_syncer: ENTITY work.synchronizer_2d
    GENERIC MAP (
      NBR_OF_SRC_FF  => 1,
      NBR_OF_DST_FF  => 2
    )
    PORT MAP (
      clk_src_i      => clk_1x_i,
      rst_src_n_i    => rst_n_i,
      clk_dst_i      => clk_5x_i,
      rst_dst_n_i    => rst_n_i,
      unsynced_src_i => rx_enable_i,
      synced_dst_o   => rx_enable_synced
    );
  
  clk_1x_p: PROCESS (clk_1x_i) IS
  BEGIN
    IF RISING_EDGE(clk_1x_i) THEN
      IF (rst_n_i = '0') THEN
        rx_synced_o_cdc_flags_r <= (OTHERS => '0');
      ELSE
        rx_synced_o_cdc_flags_r <= rx_synced_o_cdc_flags;
      END IF;
    END IF;
  END PROCESS;

  rx_cmd_fifo_do_read_i_edge <= '1' WHEN ((rx_cmd_fifo_do_read_i_r_d = '0') AND (rx_cmd_fifo_do_read_i_r = '1')) ELSE '0';
  rx_payload_fifo_do_read_i_edge <= '1' WHEN ((rx_payload_fifo_do_read_i_r_d = '0') AND (rx_payload_fifo_do_read_i_r = '1')) ELSE '0';
  
  rx_fsm_inst: entity work.rx_fsm
    PORT MAP (
      clk_5x_i                    => clk_5x_i,
      rst_n_i                     => rst_n_i,
      rx_enable_i                 => rx_enable_synced,
      rx_i                        => rx_i,
      rx_sample_index_i           => rx_sample_index_i,
                                  
      rx_cmd_fifo_full_i          => rx_cmd_fifo_full_o_s,
      rx_cmd_fifo_wren_o          => rx_cmd_fifo_wren_i_s,
      rx_cmd_fifo_data_o          => rx_cmd_fifo_data_i_s,
                                  
      rx_payload_fifo_full_i      => rx_payload_fifo_full_o_s,
      rx_payload_fifo_wren_o      => rx_payload_fifo_wren_i_s,
      rx_payload_fifo_data_o      => rx_payload_fifo_data_i_s,
                                  
      rx_busy_o                   => rx_unsynced_busy_i_a,
      rx_done_o                   => rx_unsynced_done_i_a,
      rx_curr_crc_err_flag_o      => rx_unsynced_curr_crc_err_flag_i_a,
      rx_persist_crc_err_flag_o   => rx_unsynced_persist_crc_err_flag_i_a
    );

  rx_cmd_fifo_inst: entity work.rx_cmd_fifo
    PORT MAP (
      data    => rx_cmd_fifo_data_i_s,
      rdclk   => clk_1x_i,
      rdreq   => rx_cmd_fifo_do_read_i_edge_r,
      wrclk   => clk_5x_i,
      wrreq   => rx_cmd_fifo_wren_i_s,
      q       => rx_cmd_fifo_data_o_s,
      rdempty => rx_cmd_fifo_empty_o,
      wrfull  => rx_cmd_fifo_full_o_s
    );
  
  rx_payload_fifo_inst: entity work.rx_payload_fifo
    PORT MAP (
      data    => rx_payload_fifo_data_i_s,
      rdclk   => clk_1x_i,
      rdreq   => rx_payload_fifo_do_read_i_edge_r,
      wrclk   => clk_5x_i,
      wrreq   => rx_payload_fifo_wren_i_s,
      q       => rx_payload_fifo_data_o,
      rdempty => rx_payload_fifo_empty_o,
      wrfull  => rx_payload_fifo_full_o_s
    );

  rx_payload_len_o <= rx_payload_len_o_a;
  rx_cmd_type_o <= rx_cmd_type_o_a;
  rx_dest_addr_o <= rx_dest_addr_o_a;
  rx_trans_id_o <= rx_trans_id_o_a;
  rx_crc_ok_o <= rx_crc_ok_o_a;
  
  rx_done_regs: PROCESS (clk_1x_i) IS
  BEGIN
    IF RISING_EDGE(clk_1x_i) THEN
      IF (rst_n_i = '0') THEN
        rx_done_r <= '0';
        rx_done_rr <= '0';
      ELSE
        rx_done_r <= rx_synced_done_o_a_r;
        rx_done_rr <= rx_done_r;
      END IF;
    END IF;
  END PROCESS;
  
  rx_crc_ok_regs: PROCESS (clk_1x_i) IS
  BEGIN
    IF RISING_EDGE(clk_1x_i) THEN
      IF (rst_n_i = '0') THEN
        curr_crc_err_flag_r <= '0';
        curr_crc_err_flag_rr <= '0';
      ELSE
        curr_crc_err_flag_r <= rx_synced_curr_crc_err_flag_o_a_r;
        curr_crc_err_flag_rr <= curr_crc_err_flag_r;
      END IF;
    END IF;
  END PROCESS;
  
  rx_frame_cnt_ns <= rx_frame_cnt_r + 1 WHEN ((rx_done_rr = '0') AND (rx_done_r = '1')) ELSE rx_frame_cnt_r;
  rx_crc_err_cnt_ns <= rx_crc_err_cnt_r + 1 WHEN ((curr_crc_err_flag_rr = '0') AND (curr_crc_err_flag_r = '1')) ELSE rx_crc_err_cnt_r;

  rx_busy_o <= rx_synced_busy_o_a_r;
  rx_done_o <= rx_synced_done_o_a_r;
  rx_curr_crc_err_flag_o <= rx_synced_curr_crc_err_flag_o_a_r;
  rx_persist_crc_err_flag_o <= rx_synced_persist_crc_err_flag_o_a_r;
  
  rx_frame_count_o <= STD_LOGIC_VECTOR(rx_frame_cnt_r);
  rx_crc_err_count_o <= STD_LOGIC_VECTOR(rx_crc_err_cnt_r);

END ARCHITECTURE;
