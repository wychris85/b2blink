LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

ENTITY synchronizer_2d IS
  GENERIC (
    NBR_OF_SRC_FF : natural := 1;
    NBR_OF_DST_FF : natural := 2
  );
  PORT (
    clk_src_i: IN  std_logic;
    rst_src_n_i : IN std_logic;
    clk_dst_i: IN  std_logic;
    rst_dst_n_i : IN std_logic;
    unsynced_src_i : IN std_logic;
    synced_dst_o : OUT std_logic
  );
END ENTITY;

ARCHITECTURE rtl OF synchronizer_2d IS
  SIGNAL src_ff : std_logic_vector(NBR_OF_SRC_FF-1 DOWNTO 0);
  SIGNAL dst_ff : std_logic_vector(NBR_OF_DST_FF-1 DOWNTO 0);

  --ATTRIBUTE ASYNC_REG : string;
  --ATTRIBUTE ASYNC_REG OF dst_ff: SIGNAL IS "TRUE";

BEGIN

  src_reg0: PROCESS (clk_src_i) IS
  BEGIN
    IF rising_edge(clk_src_i) THEN
      IF (rst_src_n_i = '0') THEN
        src_ff(0) <= '0';
      ELSE
        src_ff(0) <= unsynced_src_i;
      END IF;
    END IF;
  END PROCESS;


  if_gen_src: IF NBR_OF_SRC_FF > 1 GENERATE
    src_sync_ff_i: FOR i IN 1 TO NBR_OF_SRC_FF-1 GENERATE
      src_reg_i: PROCESS (clk_src_i) IS
      BEGIN
        IF rising_edge(clk_src_i) THEN
          IF (rst_src_n_i = '0') THEN
            src_ff(i) <= '0';
          ELSE
            src_ff(i) <= src_ff(i-1);
          END IF;
        END IF;
      END PROCESS;
    END GENERATE;
  END GENERATE;

  dst_reg0: PROCESS (clk_dst_i) IS
  BEGIN
    IF rising_edge(clk_dst_i) THEN
      IF (rst_dst_n_i = '0') THEN
        dst_ff(0) <= '0';
      ELSE
        dst_ff(0) <= src_ff(NBR_OF_SRC_FF-1);
      END IF;
    END IF;
  END PROCESS;

  if_gen_dst: IF NBR_OF_DST_FF > 1 GENERATE
    dst_sync_ff_i: FOR i IN 1 TO NBR_OF_DST_FF-1 GENERATE
      dst_reg_i: PROCESS (clk_dst_i) IS
      BEGIN
        IF rising_edge(clk_dst_i) THEN
          IF (rst_dst_n_i = '0') THEN
            dst_ff(i) <= '0';
          ELSE
            dst_ff(i) <= dst_ff(i-1);
          END IF;
        END IF;
      END PROCESS;
    END GENERATE;
  END GENERATE;

  synced_dst_o <= dst_ff(NBR_OF_DST_FF-1);

END ARCHITECTURE;
