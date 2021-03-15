LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;

ENTITY b2blink_tx_top IS
  PORT (
    clk_1x_i: IN  std_logic;
    rst_n_i: IN  std_logic;

    -- External Tx-IF
    tx_o : OUT STD_LOGIC;

    --TX-FRAME-GEN-REGISTER
    -- r/w ctrl registers
    tx_enable_i : STD_LOGIC;
    tx_frame_gen_start_i : STD_LOGIC;
    tx_pattern_gen_i : STD_LOGIC;
    cmd_mem_base_addr_i : STD_LOGIC_VECTOR(9 DOWNTO 0);
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

    --CMD-MEMORY READ-IF (Only possible to read when Frame Generator not busy (csr_frame_gen_busy_o==0) otherwise returns 0)
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
    max_size_payload_mem_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)

    ---- Internal Response FIFO-IF
    --resp_fifo_wren_i : IN STD_LOGIC;
    --resp_fifo_cmd_i : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    --pending_resp_cmd_o : OUT STD_LOGIC;
    --resp_fifo_full_o : OUT STD_LOGIC
	);
END ENTITY;

ARCHITECTURE rtl OF b2blink_tx_top IS
	SIGNAL frame_gen_cmd_rdaddr_o_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL frame_gen_cmd_rden_o_s : STD_LOGIC;

	SIGNAL cmd_mem_tx_src_addr_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL cmd_mem_tx_dst_addr_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL cmd_mem_tx_length_o_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL cmd_mem_tx_cmd_o_s : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL cmd_mem_tx_trans_id_o_s : STD_LOGIC_VECTOR(2 DOWNTO 0);

  SIGNAL tx_payload_mem_base_addr_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);

	SIGNAL tx_dst_addr_i_s : STD_LOGIC_VECTOR(DEST_ADDR_WIDTH_C-1 DOWNTO 0);
	SIGNAL tx_length_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL tx_cmd_i_s : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL tx_trans_id_i_s : STD_LOGIC_VECTOR(2 DOWNTO 0);

	SIGNAL curr_payloads_base_addr_s : STD_LOGIC_VECTOR(9 DOWNTO 0);

	SIGNAL tx_start_i_s : STD_LOGIC;
	SIGNAL tx_busy_o_s : STD_LOGIC;
	SIGNAL tx_done_o_s : STD_LOGIC;

	SIGNAL tx_frame_count_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
	--SIGNAL pending_resp_cmd_s : STD_LOGIC;

	--SIGNAL avm_buffer_rden_s : STD_LOGIC;
	--SIGNAL avm_buffer_empty_s : STD_LOGIC;
	--SIGNAL tx_buffer_wrfull_s : STD_LOGIC;
	--SIGNAL user_data_available_o_s : STD_LOGIC;
	--SIGNAL user_buffer_data_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

	--SIGNAL fifo_rd_empty_s : STD_LOGIC;
	--SIGNAL fifo_rd_req_o_s : STD_LOGIC;
	--SIGNAL fifo_rd_data_i_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
	--SIGNAL tx_fifo_wrreq_r : STD_LOGIC;
	--SIGNAL tx_fifo_wrreq_s : STD_LOGIC;

	--SIGNAL resp_fifo_aclr : STD_LOGIC;
	--SIGNAL resp_fifo_cmd_i_s : STD_LOGIC_VECTOR(79 DOWNTO 0);
	--SIGNAL resp_fifo_rden_s : STD_LOGIC;
	--SIGNAL resp_fifo_empty_s : STD_LOGIC;
	--SIGNAL resp_fifo_cmd_o_s : STD_LOGIC_VECTOR(79 DOWNTO 0);

	SIGNAL frame_gen_busy_s : STD_LOGIC;
	SIGNAL frame_gen_done_s : STD_LOGIC;
	SIGNAL cmd_mem_rden_s : STD_LOGIC;
	SIGNAL cmd_mem_rdaddr_s : STD_LOGIC_VECTOR(9 DOWNTO 0);

  SIGNAL tx_payload_mem_rden_o_s : STD_LOGIC;
	SIGNAL tx_payload_mem_rdaddr_o_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL tx_payload_mem_data_i_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

  SIGNAL payload_mem_rden_i_s : STD_LOGIC;
  SIGNAL payload_mem_rdaddr_i_s : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL payload_mem_data_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

BEGIN

  tx_payload_mem_base_addr_i_s <= curr_payloads_base_addr_s WHEN frame_gen_busy_s = '1' ELSE (OTHERS => '0');
	tx_dst_addr_i_s <= cmd_mem_tx_dst_addr_o_s(DEST_ADDR_WIDTH_C-1 DOWNTO 0) WHEN frame_gen_busy_s = '1' ELSE (OTHERS => '0');
	tx_length_i_s <= cmd_mem_tx_length_o_s WHEN frame_gen_busy_s = '1' ELSE (OTHERS => '0');
	tx_cmd_i_s <= cmd_mem_tx_cmd_o_s WHEN frame_gen_busy_s = '1' ELSE (OTHERS => '0');
	tx_trans_id_i_s <= cmd_mem_tx_trans_id_o_s WHEN frame_gen_busy_s = '1' ELSE (OTHERS => '0');

	tx_fsm_inst: ENTITY work.tx_fsm
		PORT MAP (
			clk_1x_i                => clk_1x_i,
			rst_n_i                 => rst_n_i,
			enable_i                => tx_enable_i,
			start_i                 => tx_start_i_s,
			pattern_gen_i           => tx_pattern_gen_i,
			payload_len_i           => tx_length_i_s,
			cmd_type_i              => tx_cmd_i_s,
			dest_addr_i             => tx_dst_addr_i_s,
			trans_id_i              => tx_trans_id_i_s,
			tx_o                    => tx_o,
			tx_busy_o               => tx_busy_o_s,
			tx_done_o               => tx_done_o_s,
			tx_frame_count_o        => tx_frame_count_o_s,

      payload_mem_base_addr_i => tx_payload_mem_base_addr_i_s,
      payload_mem_rden_o      => tx_payload_mem_rden_o_s,
      payload_mem_rdaddr_o    => tx_payload_mem_rdaddr_o_s,
      payload_mem_data_i      => tx_payload_mem_data_i_s,

			tx_bitcnt_o             => OPEN,
			tx_data_o               => OPEN,
			tx_state_o              => OPEN
		);

  cmd_mem_rden_s <= frame_gen_cmd_rden_o_s                WHEN frame_gen_busy_s = '1' ELSE cmd_mem_rden_i;
	cmd_mem_rdaddr_s <= frame_gen_cmd_rdaddr_o_s            WHEN frame_gen_busy_s = '1' ELSE cmd_mem_rdaddr_i;
  
  tx_cmd_bram_memory_inst: ENTITY work.cmd_memory
    PORT MAP (
      clk_1x_i                  => clk_1x_i,
      rst_n_i                   => rst_n_i,
      enable_i                  => tx_enable_i,
      cmd_mem_wren_i            => cmd_mem_wren_i,
      cmd_mem_wraddr_i          => cmd_mem_wraddr_i,
      cmd_mem_rden_i            => cmd_mem_rden_s,
      cmd_mem_rdaddr_i          => cmd_mem_rdaddr_s,
      cmd_mem_tx_src_addr_i     => cmd_mem_tx_src_addr_i,
      cmd_mem_tx_dst_addr_i     => cmd_mem_tx_dst_addr_i,
      cmd_mem_tx_length_i       => cmd_mem_tx_length_i,
      cmd_mem_tx_cmd_i          => cmd_mem_tx_cmd_i,
      cmd_mem_tx_trans_id_i     => cmd_mem_tx_trans_id_i,
      cmd_mem_tx_src_addr_o     => cmd_mem_tx_src_addr_o_s,
      cmd_mem_tx_dst_addr_o     => cmd_mem_tx_dst_addr_o_s,
      cmd_mem_tx_length_o       => cmd_mem_tx_length_o_s,
      cmd_mem_tx_cmd_o          => cmd_mem_tx_cmd_o_s,
      cmd_mem_tx_trans_id_o     => cmd_mem_tx_trans_id_o_s,
      max_size_command_mem_o    => max_size_command_mem_o
    );

  payload_mem_rden_i_s <= tx_payload_mem_rden_o_s         WHEN frame_gen_busy_s = '1' ELSE payload_mem_rden_i;
	payload_mem_rdaddr_i_s <= tx_payload_mem_rdaddr_o_s     WHEN frame_gen_busy_s = '1' ELSE payload_mem_rdaddr_i;
  tx_payload_mem_data_i_s <= payload_mem_data_o_s         WHEN frame_gen_busy_s = '1' ELSE (OTHERS => '0');

  tx_payload_bram_memory_inst: ENTITY work.payload_memory
    PORT MAP (
      clk_1x_i                => clk_1x_i,
      rst_n_i                 => rst_n_i,
      enable_i                => tx_enable_i,
      payload_mem_wren_i      => payload_mem_wren_i,
      payload_mem_wraddr_i    => payload_mem_wraddr_i,
      payload_mem_data_i      => payload_mem_data_i,
      payload_mem_rden_i      => payload_mem_rden_i_s,
      payload_mem_rdaddr_i    => payload_mem_rdaddr_i_s,
      payload_mem_data_o      => payload_mem_data_o_s,
      max_size_payload_mem_o  => max_size_payload_mem_o
    );	

  tx_frame_generator_inst: ENTITY work.tx_frame_generator
    PORT MAP (
      clk_1x_i                  => clk_1x_i,
      rst_n_i                   => rst_n_i,
      ctrl_enable_i             => tx_enable_i,
      ctrl_trigger_i            => tx_frame_gen_start_i,
      ctrl_pattern_gen_i        => tx_pattern_gen_i,
      ctrl_cmd_start_addr_i     => cmd_mem_base_addr_i,
      tx_done_i                 => tx_done_o_s,
      tx_busy_i                 => tx_busy_o_s,
      tx_fifo_full_i            => '0',--tx_buffer_wrfull_s,
      resp_fifo_empty_i         => '0',--resp_fifo_empty_s,
      curr_cmd_type_i           => cmd_mem_tx_cmd_o_s,
      curr_length_i             => cmd_mem_tx_length_o_s,
      tx_start_o                => tx_start_i_s,
      pending_resp_cmd_o        => open,--pending_resp_cmd_s,
      cmd_mem_rden_o            => frame_gen_cmd_rden_o_s,
      cmd_mem_rdaddr_o          => frame_gen_cmd_rdaddr_o_s,
      resp_fifo_rden_o          => open,--resp_fifo_rden_s,
      frame_gen_busy_o          => frame_gen_busy_s,
      frame_gen_done_o          => frame_gen_done_s
    );


  curr_payloads_base_addr_s <= cmd_mem_tx_src_addr_o_s(9 DOWNTO 0);

  --resp_fifo_aclr <= NOT rst_n_i;
  --resp_fifo_cmd_i_s <=  cmd_mem_tx_src_addr_o_s & resp_fifo_cmd_i WHEN ((resp_fifo_wren_i = '1') AND (pending_resp_cmd_s = '1')) ELSE (OTHERS => '0');
  --resp_cmd_fifo_inst: ENTITY work.resp_cmd_fifo
  --  PORT MAP (
  --    aclr  => resp_fifo_aclr,
  --    clock => clk_1x_i,
  --    data  => resp_fifo_cmd_i_s,
  --    rdreq => resp_fifo_rden_s,
  --    wrreq => resp_fifo_wren_i,
  --    empty => resp_fifo_empty_s,
  --    full  => resp_fifo_full_o,
  --    q     => resp_fifo_cmd_o_s
  --  );

  tx_done_o <= tx_busy_o_s;
  tx_busy_o <= tx_busy_o_s; 
  tx_frame_count_o <= tx_frame_count_o_s;
  --pending_resp_cmd_o <= pending_resp_cmd_s;

  cmd_mem_tx_src_addr_o   <= cmd_mem_tx_src_addr_o_s  WHEN frame_gen_busy_s = '0' ELSE (OTHERS => '0');
  cmd_mem_tx_dst_addr_o   <= cmd_mem_tx_dst_addr_o_s  WHEN frame_gen_busy_s = '0' ELSE (OTHERS => '0');
  cmd_mem_tx_length_o     <= cmd_mem_tx_length_o_s    WHEN frame_gen_busy_s = '0' ELSE (OTHERS => '0');
  cmd_mem_tx_cmd_o        <= cmd_mem_tx_cmd_o_s       WHEN frame_gen_busy_s = '0' ELSE (OTHERS => '0');
  cmd_mem_tx_trans_id_o   <= cmd_mem_tx_trans_id_o_s  WHEN frame_gen_busy_s = '0' ELSE (OTHERS => '0');
  payload_mem_data_o      <= payload_mem_data_o_s     WHEN frame_gen_busy_s = '0' ELSE (OTHERS => '0');

  tx_frame_gen_busy_o <= frame_gen_busy_s;
  tx_frame_gen_done_o <= frame_gen_done_s;
END ARCHITECTURE;