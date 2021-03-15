LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;

ENTITY payload_memory IS
  PORT (
    clk_1x_i: IN  std_logic;
    rst_n_i: IN  std_logic;

    enable_i : IN STD_LOGIC;

    payload_mem_wren_i : IN STD_LOGIC;
    payload_mem_wraddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_data_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

    payload_mem_rden_i : IN STD_LOGIC;
    payload_mem_rdaddr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_data_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

    max_size_payload_mem_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END ENTITY;

ARCHITECTURE rtl OF payload_memory IS

  SIGNAL payload_mem_aclr : STD_LOGIC;
  SIGNAL payload_mem_data_i_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL payload_mem_data_o_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

  SIGNAL rdena_s : STD_LOGIC;
  SIGNAL wrena_s : STD_LOGIC;
BEGIN

  payload_mem_aclr <= NOT rst_n_i;

  rdena_s <= '1' WHEN (payload_mem_rden_i = '1' AND enable_i = '1') ELSE '0';
  wrena_s <= '1' WHEN (payload_mem_wren_i = '1' AND enable_i = '1') ELSE '0';

  tx_payload_bram_inst: ENTITY work.tx_payload_bram
    PORT MAP (
      aclr      => payload_mem_aclr,
      clock     => clk_1x_i,
      data      => payload_mem_data_i_s,
      rdaddress => payload_mem_rdaddr_i,
      rden      => rdena_s,
      wraddress => payload_mem_wraddr_i,
      wren      => wrena_s,
      q         => payload_mem_data_o_s
    );

  payload_mem_data_i_s <= payload_mem_data_i;
  payload_mem_data_o <= payload_mem_data_o_s;

  max_size_payload_mem_o <= STD_LOGIC_VECTOR(TO_UNSIGNED(MAX_SIZE_PAYLOAD_MEM_C, max_size_payload_mem_o'LENGTH));

END ARCHITECTURE;
