LIBRARY IEEE;
  USE IEEE.STD_LOGIC_1164.ALL;
  USE IEEE.NUMERIC_STD.ALL;
 
LIBRARY WORK;
  USE WORK.B2BLINK_PKG.ALL;
  USE WORK.B2BLINK_TX_PKG.ALL;
  USE WORK.B2BLINK_RX_PKG.ALL;

LIBRARY WORK;
  USE WORK.AVS_COMMON_PKG.ALL;
  USE WORK.B2BLINK_REC_PKG.ALL;
  USE WORK.REGDEF_B2B_PKG.ALL;

PACKAGE avs_b2blink_pkg IS

  TYPE avs_b2blink_reg_t IS RECORD
    regs : b2blink_reg_block_inst_t;
    rdout : avs_output_t;
    --xxx : xxx;
  END RECORD;

  COMPONENT avs_b2blink IS
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
  END COMPONENT avs_b2blink;
  FUNCTION init_avs_b2blink_reg_t RETURN avs_b2blink_reg_t;

END PACKAGE avs_b2blink_pkg;

PACKAGE BODY avs_b2blink_pkg IS

  FUNCTION init_avs_b2blink_reg_t RETURN avs_b2blink_reg_t IS
    VARIABLE v : avs_b2blink_reg_t;
  BEGIN
    v.regs := init_b2blink_reg_block;
    v.rdout := init_avs_output_t;
    --v.xxx := xxx;
    RETURN v;
  END FUNCTION;

END PACKAGE BODY avs_b2blink_pkg;
