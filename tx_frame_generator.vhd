LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;
  USE WORK.b2blink_tx_pkg.ALL;
  USE WORK.b2blink_rx_pkg.ALL;

ENTITY tx_frame_generator IS
  PORT (
    clk_1x_i: IN  std_logic;
    rst_n_i: IN  std_logic;

    ctrl_enable_i : IN STD_LOGIC;
    ctrl_trigger_i : IN STD_LOGIC;
    ctrl_pattern_gen_i : IN STD_LOGIC;
    ctrl_cmd_start_addr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    curr_cmd_type_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    curr_length_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

    tx_done_i : IN STD_LOGIC;
    tx_busy_i : IN STD_LOGIC;
    tx_fifo_full_i : IN STD_LOGIC;
    resp_fifo_empty_i : IN STD_LOGIC;

    tx_start_o : OUT STD_LOGIC;
    pending_resp_cmd_o : OUT STD_LOGIC;
    cmd_mem_rden_o : OUT STD_LOGIC;
    cmd_mem_rdaddr_o : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    resp_fifo_rden_o : OUT STD_LOGIC;
    frame_gen_busy_o : OUT STD_LOGIC;
    frame_gen_done_o : OUT STD_LOGIC
  );
END ENTITY;

ARCHITECTURE rtl OF tx_frame_generator IS

  TYPE FRAME_GEN_FSM_T IS (FG_IDLE_ST, FG_INIT_ST, CMD_START_ST, CMD_FETCH_ST, CMD_DECODE_ST, TX_START_ST, CHECK_TX_DONE_ST, CHECK_CMD_LIST_DONE_ST, FG_DONE_ST);

  TYPE fr_gen_input_t IS RECORD
    enable : STD_LOGIC;
    trigger : STD_LOGIC;
    pattern_gen : STD_LOGIC;
    cmd_start_addr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    --curr_payloads_base_addr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    curr_cmd_type : STD_LOGIC_VECTOR(2 DOWNTO 0);
    --curr_length : STD_LOGIC_VECTOR(9 DOWNTO 0);
    tx_done : STD_LOGIC;
    tx_busy : STD_LOGIC;
    tx_fifo_full : STD_LOGIC;
    resp_fifo_empty : STD_LOGIC;
  END RECORD;

  TYPE fr_gen_output_t IS RECORD
    tx_start : STD_LOGIC;
    pending_resp_cmd : STD_LOGIC;
    avm_buffer_rden : STD_LOGIC;
    cmd_mem_rden : STD_LOGIC;
    cmd_mem_rdaddr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_rden : STD_LOGIC;
    payload_rdaddr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    resp_fifo_rden : STD_LOGIC;
    frame_gen_busy : STD_LOGIC;
    frame_gen_done : STD_LOGIC;
  END RECORD;

  TYPE fr_gen_reg_t IS RECORD
    qout : fr_gen_output_t;
    counter : NATURAL;
    pattern_gen : STD_LOGIC;
    curr_cmd_mem_addr : STD_LOGIC_VECTOR(9 DOWNTO 0);
    fg_trig : STD_LOGIC;
    fg_busy : STD_LOGIC;
    fg_done : STD_LOGIC;
    cnt : integer;
    curr_cmd_type : STD_LOGIC_VECTOR(2 DOWNTO 0);
    state : FRAME_GEN_FSM_T;
  END RECORD;

  SIGNAL input_s : fr_gen_input_t;
  SIGNAL r, rin : fr_gen_reg_t;

  FUNCTION init_fr_gen_output_t RETURN fr_gen_output_t IS
    VARIABLE res : fr_gen_output_t;
  BEGIN
    res.cmd_mem_rdaddr := (OTHERS => '0');
    res.cmd_mem_rden := '0';
    res.tx_start := '0';
    res.pending_resp_cmd := '0';
    res.payload_rden := '0';
    res.payload_rdaddr := (OTHERS => '0');
    res.resp_fifo_rden := '0';
    res.frame_gen_busy := '0';
    res.frame_gen_done := '0';
    res.avm_buffer_rden := '0';
    RETURN res;
  END FUNCTION;

  FUNCTION init_fr_gen_reg_t RETURN fr_gen_reg_t IS
    VARIABLE res : fr_gen_reg_t;
  BEGIN
    res.qout := init_fr_gen_output_t;
    res.counter := 0;
    res.pattern_gen := '0';
    res.curr_cmd_mem_addr := (OTHERS => '0');
    res.fg_trig := '0';
    res.fg_busy := '0';
    res.fg_done := '0';
    res.cnt := 0;
    res.curr_cmd_type := (OTHERS => '0');
    res.state := FG_IDLE_ST;
    RETURN res;
  END FUNCTION;
BEGIN

  input_s.enable <= ctrl_enable_i;
  input_s.trigger <= ctrl_trigger_i;
  input_s.pattern_gen <= ctrl_pattern_gen_i;
  input_s.cmd_start_addr <= ctrl_cmd_start_addr_i;
  --input_s.curr_payloads_base_addr <= curr_payloads_base_addr_i;
  input_s.curr_cmd_type <= curr_cmd_type_i;
  --input_s.curr_length <= curr_length_i;
  input_s.tx_busy <= tx_busy_i;
  input_s.tx_done <= tx_done_i;
  input_s.tx_fifo_full <= tx_fifo_full_i;
  input_s.resp_fifo_empty <= resp_fifo_empty_i;

  reg_p: PROCESS (clk_1x_i) IS
  BEGIN
    IF rising_edge(clk_1x_i) THEN
      IF (rst_n_i = '0') THEN
        r <= init_fr_gen_reg_t;
      ELSE
        r <= rin;
      END IF;
    END IF;
  END PROCESS;

  com_p: PROCESS (r, input_s) IS
    VARIABLE v: fr_gen_reg_t;
  BEGIN
    v := r;

    IF (input_s.enable = '1') THEN
      v.fg_trig := input_s.trigger;
      v.qout.frame_gen_done := '0';

      CASE r.state IS
        WHEN FG_IDLE_ST =>
          IF ((r.fg_trig = '0') AND (v.fg_trig = '1')) THEN
            v.curr_cmd_mem_addr := input_s.cmd_start_addr;
            v.pattern_gen := input_s.pattern_gen;
            v.state := FG_INIT_ST;
          END IF;

        WHEN FG_INIT_ST =>
          v.qout.frame_gen_busy := '1';
          v.cnt := 0;
          v.state := CMD_START_ST;

        WHEN CMD_START_ST =>
          IF (r.cnt > 0) THEN
            v.cnt := r.cnt - 1;
          ELSE
            v.cnt := 2;
            v.qout.cmd_mem_rdaddr := r.curr_cmd_mem_addr;
            v.curr_cmd_mem_addr := STD_LOGIC_VECTOR(UNSIGNED(r.curr_cmd_mem_addr) + 1);
            v.qout.cmd_mem_rden := '1';
            v.state := CMD_FETCH_ST;
          END IF;

        WHEN CMD_FETCH_ST =>
          v.qout.cmd_mem_rden := '0';
          IF (r.cnt > 0) THEN
            v.cnt := r.cnt - 1;
          ELSE
            v.curr_cmd_type := input_s.curr_cmd_type;
            v.state := CMD_DECODE_ST;
          END IF;

        WHEN CMD_DECODE_ST =>
          IF (r.cnt > 0) THEN
            v.cnt := r.cnt - 1;
          ELSE
            v.cnt := 5;
            IF (cmd_encode(r.curr_cmd_type) = CMD_STOP) THEN
              v.state := FG_DONE_ST;
            ELSE
              v.state := TX_START_ST;
            END IF;
          END IF;

        WHEN TX_START_ST =>
          v.qout.tx_start := '1';
          IF (r.cnt > 0) THEN
            v.cnt := r.cnt - 1;
          ELSE
            v.cnt := 5;
            v.qout.tx_start := '0';
            IF (input_s.tx_busy = '1') THEN
              v.state := CHECK_TX_DONE_ST;
            END IF;
          END IF;

        WHEN CHECK_TX_DONE_ST =>
          IF (r.cnt > 0) THEN
            v.cnt := r.cnt - 1;
          ELSE
            v.cnt := 5;
            v.qout.tx_start := '0';
            IF (input_s.tx_busy = '0') THEN
              v.state := CHECK_CMD_LIST_DONE_ST;
            END IF;
          END IF;

        WHEN CHECK_CMD_LIST_DONE_ST =>
          IF (r.cnt > 0) THEN
            v.cnt := r.cnt - 1;
          ELSE
            v.cnt := 5;
            IF ((cmd_encode(r.curr_cmd_type) = CMD_STOP) OR (UNSIGNED(r.curr_cmd_mem_addr)-1 = MAX_SIZE_PAYLOAD_MEM_C-1)) THEN
              v.state := FG_DONE_ST;
            ELSE
              v.state := CMD_START_ST;
            END IF;
          END IF;

        WHEN FG_DONE_ST =>
          v.qout.frame_gen_busy := '0';
          v.qout.frame_gen_done := '1';
          IF (r.cnt > 0) THEN
            v.cnt := r.cnt - 1;
          ELSE
            v.state := FG_IDLE_ST;
          END IF;

      END CASE;
    END IF;

    rin <= v;
  END PROCESS;

  cmd_mem_rdaddr_o <= r.qout.cmd_mem_rdaddr;
  cmd_mem_rden_o <= r.qout.cmd_mem_rden;

  tx_start_o <= r.qout.tx_start;
  pending_resp_cmd_o <= r.qout.pending_resp_cmd;
  resp_fifo_rden_o <= r.qout.resp_fifo_rden;
  frame_gen_busy_o <= r.qout.frame_gen_busy;
  frame_gen_done_o <= r.qout.frame_gen_done;
END ARCHITECTURE;