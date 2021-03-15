LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;

ENTITY cmd_memory IS
  PORT (
    clk_1x_i: IN  std_logic;
    rst_n_i: IN  std_logic;

    enable_i : IN STD_LOGIC;
    cmd_mem_wren_i : IN STD_LOGIC;
    cmd_mem_wraddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

    cmd_mem_rden_i : IN STD_LOGIC;
    cmd_mem_rdaddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

    cmd_mem_tx_src_addr_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_dst_addr_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_length_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_cmd_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_tx_trans_id_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);

    cmd_mem_tx_src_addr_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_dst_addr_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    cmd_mem_tx_length_o : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    cmd_mem_tx_cmd_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    cmd_mem_tx_trans_id_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);

    max_size_command_mem_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END ENTITY;

ARCHITECTURE rtl OF cmd_memory IS
  SIGNAL cmd_mem_aclr : STD_LOGIC;

  SIGNAL cmd_bram_data_i_s : STD_LOGIC_VECTOR(107 DOWNTO 0);    
  ALIAS cmd_mem_i_tx_src_addr_a : STD_LOGIC_VECTOR(31 DOWNTO 0) IS cmd_bram_data_i_s(107 DOWNTO 76);
  ALIAS cmd_mem_i_tx_dst_addr_a : STD_LOGIC_VECTOR(31 DOWNTO 0) IS cmd_bram_data_i_s(75 DOWNTO 44);
  ALIAS cmd_mem_i_tx_length_a : STD_LOGIC_VECTOR(9 DOWNTO 0) IS cmd_bram_data_i_s(43 DOWNTO 34);
  ALIAS cmd_mem_i_tx_cmd_a : STD_LOGIC_VECTOR(2 DOWNTO 0) IS cmd_bram_data_i_s(33 DOWNTO 31);
  ALIAS cmd_mem_i_tx_tid_a : STD_LOGIC_VECTOR(2 DOWNTO 0) IS cmd_bram_data_i_s(30 DOWNTO 28);
  ALIAS cmd_mem_i_reserved_a : STD_LOGIC_VECTOR(27 DOWNTO 0) IS cmd_bram_data_i_s(27 DOWNTO 0);

  SIGNAL cmd_bram_data_o_s : STD_LOGIC_VECTOR(107 DOWNTO 0);
  ALIAS cmd_mem_o_tx_src_addr_a : STD_LOGIC_VECTOR(31 DOWNTO 0) IS cmd_bram_data_o_s(107 DOWNTO 76);
  ALIAS cmd_mem_o_tx_dst_addr_a : STD_LOGIC_VECTOR(31 DOWNTO 0) IS cmd_bram_data_o_s(75 DOWNTO 44);
  ALIAS cmd_mem_o_tx_length_a : STD_LOGIC_VECTOR(9 DOWNTO 0) IS cmd_bram_data_o_s(43 DOWNTO 34);
  ALIAS cmd_mem_o_tx_cmd_a : STD_LOGIC_VECTOR(2 DOWNTO 0) IS cmd_bram_data_o_s(33 DOWNTO 31);
  ALIAS cmd_mem_o_tx_tid_a : STD_LOGIC_VECTOR(2 DOWNTO 0) IS cmd_bram_data_o_s(30 DOWNTO 28);
  ALIAS cmd_mem_o_reserved_a : STD_LOGIC_VECTOR(27 DOWNTO 0) IS cmd_bram_data_o_s(27 DOWNTO 0);

  SIGNAL rdena_s : STD_LOGIC;
  SIGNAL wrena_s : STD_LOGIC;
BEGIN

  cmd_mem_aclr <= NOT rst_n_i;

  cmd_mem_i_tx_src_addr_a <= cmd_mem_tx_src_addr_i;
  cmd_mem_i_tx_dst_addr_a <= cmd_mem_tx_dst_addr_i;
  cmd_mem_i_tx_length_a <= cmd_mem_tx_length_i;
  cmd_mem_i_tx_cmd_a <= cmd_mem_tx_cmd_i;
  cmd_mem_i_tx_tid_a <= cmd_mem_tx_trans_id_i;
  cmd_mem_i_reserved_a <= (OTHERS => '0');

  rdena_s <= '1' WHEN (cmd_mem_rden_i = '1' AND enable_i = '1') ELSE '0';
  wrena_s <= '1' WHEN (cmd_mem_wren_i = '1' AND enable_i = '1') ELSE '0';

  tx_cmd_bram_inst: ENTITY work.tx_cmd_bram
    PORT MAP (
      aclr      => cmd_mem_aclr,
      clock     => clk_1x_i,
      data      => cmd_bram_data_i_s,
      rdaddress => cmd_mem_rdaddr_i,
      rden      => rdena_s,
      wraddress => cmd_mem_wraddr_i,
      wren      => wrena_s,
      q         => cmd_bram_data_o_s
    );

  cmd_mem_tx_src_addr_o <= cmd_mem_o_tx_src_addr_a;
  cmd_mem_tx_dst_addr_o <= cmd_mem_o_tx_dst_addr_a;
  cmd_mem_tx_length_o <= cmd_mem_o_tx_length_a;
  cmd_mem_tx_cmd_o <= cmd_mem_o_tx_cmd_a;
  cmd_mem_tx_trans_id_o <= cmd_mem_o_tx_tid_a;

  max_size_command_mem_o <= STD_LOGIC_VECTOR(TO_UNSIGNED(MAX_SIZE_COMMAND_MEM_C, max_size_command_mem_o'LENGTH));

END ARCHITECTURE;
