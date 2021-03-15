LIBRARY IEEE;
  USE IEEE.STD_LOGIC_1164.ALL;
  USE IEEE.NUMERIC_STD.ALL;
 
LIBRARY WORK;
  USE WORK.B2BLINK_PKG.ALL;
  USE WORK.B2BLINK_TX_PKG.ALL;
  USE WORK.B2BLINK_RX_PKG.ALL;

LIBRARY WORK;
  USE WORK.B2BLINK_REC_PKG.ALL;


ENTITY b2blink_rec IS
  PORT (
    clk_1x_i : IN std_logic;
    clk_5x_i : IN STD_LOGIC;
    rst_n_i : IN std_logic;
    b2blink_rec_i : IN b2blink_rec_input_t;
    b2blink_rec_o : OUT b2blink_rec_output_t
  );
END ENTITY b2blink_rec;

ARCHITECTURE rtl OF b2blink_rec IS
  SIGNAL r, rin : b2blink_rec_reg_t;
BEGIN

  clk_proc: PROCESS(clk_1x_i) IS
  BEGIN
    IF (rising_edge(clk_1x_i)) THEN
      IF (rst_n_i = '0') THEN
        r <= init_b2blink_rec_reg_t;
      ELSE
        r <= rin;
      END IF;
    END IF;
  END PROCESS;

  comb_proc: PROCESS(r, b2blink_rec_i) IS
    VARIABLE v : b2blink_rec_reg_t;
  BEGIN

    -- Default assignment
    v := r;

    -- ********** MODULE LOGIC START **********
    -- ... Write your sequential logic here...
    -- ********** MODULE LOGIC END **********

    -- Update register
    rin <= v;

    -- Registered output assignment
    b2blink_rec_o <= r.rec_out;

    -- Uncomment this for a combinational output assignment
    --b2blink_rec_o <= v.rec_out;

  END PROCESS;

END ARCHITECTURE;
