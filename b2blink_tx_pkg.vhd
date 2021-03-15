LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;

PACKAGE b2blink_tx_pkg IS

  CONSTANT TX_BUFFER_WIDTH_C : NATURAL := DATA_WIDTH_C;
  CONSTANT TX_STATES_WIDTH_C : NATURAL := 4;

  -- TX-FSM
  TYPE TX_FSM_T IS (TX_RESET_ST, TX_IDLE_ST, TX_SOF_ST, TX_TRANS_ID_ST, TX_CMD_TYPE_ST, TX_PAYLOAD_LEN_ST, TX_DEST_ADDR_ST, TX_PAYLOAD_ST, TX_CRC_ST, TX_DONE_ST);

  TYPE b2blink_tx_input_t IS RECORD
    enable : STD_LOGIC;
    start : std_logic;
    payload_base_mem_addr : UNSIGNED(9 DOWNTO 0);
    payload_len : STD_LOGIC_VECTOR(PAYLOAD_LEN_WIDTH_C-1 DOWNTO 0);
    cmd_type : STD_LOGIC_VECTOR(CMD_TYPE_WIDTH_C-1 DOWNTO 0);
    dest_addr : STD_LOGIC_VECTOR(DEST_ADDR_WIDTH_C-1 DOWNTO 0);
    trans_id : STD_LOGIC_VECTOR(TRANSACTION_ID_WIDTH_C-1 DOWNTO 0);
    payload_mem_data : STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
    pattern_gen : STD_LOGIC;
  END RECORD;

  TYPE b2blink_tx_output_t IS RECORD
    tx : STD_LOGIC;
    busy : STD_LOGIC;
    done : STD_LOGIC;
    frame_count : unsigned(DATA_WIDTH_C-1 DOWNTO 0);
  END RECORD;

  TYPE b2blink_tx_rec_t IS RECORD
    tx_ibuf : b2blink_tx_input_t;
    tx_oreg : b2blink_tx_output_t;
    tx_buffer_data : STD_LOGIC_VECTOR(TX_BUFFER_WIDTH_C-1 DOWNTO 0);
    tx_buffer_bcnt : natural RANGE 0 TO 40;
    tx_buffer_index : natural RANGE 0 TO 40;
    tx_crc_calc : UNSIGNED(CRC_WIDTH_C-1 DOWNTO 0);
    has_payload : STD_LOGIC;
    start : STD_LOGIC;
    grant_payload_mem_access : STD_LOGIC;
    pattern_data : UNSIGNED(DATA_WIDTH_C-1 DOWNTO 0);
    payload_mem_rdaddr : UNSIGNED(9 DOWNTO 0);
    payload_mem_rden : STD_LOGIC;
    tx_state : TX_FSM_T;
  END RECORD;

  FUNCTION encode_tx_states(state_v : STD_LOGIC_VECTOR) RETURN TX_FSM_T;
  FUNCTION decode_tx_states(state_t : TX_FSM_T) RETURN STD_LOGIC_VECTOR;
  FUNCTION init_b2blink_tx_input_t RETURN b2blink_tx_input_t;
  FUNCTION init_b2blink_tx_output_t RETURN b2blink_tx_output_t;
  FUNCTION init_b2blink_tx_rec_t RETURN b2blink_tx_rec_t;

END PACKAGE;

PACKAGE BODY b2blink_tx_pkg IS

  FUNCTION decode_tx_states(state_t : TX_FSM_T) RETURN STD_LOGIC_VECTOR IS
    VARIABLE res : STD_LOGIC_VECTOR(TX_STATES_WIDTH_C-1 DOWNTO 0);
  BEGIN
    CASE state_t IS
      WHEN TX_IDLE_ST         => res := STD_LOGIC_VECTOR(TO_UNSIGNED(01, TX_STATES_WIDTH_C));
      WHEN TX_SOF_ST          => res := STD_LOGIC_VECTOR(TO_UNSIGNED(02, TX_STATES_WIDTH_C));
      WHEN TX_PAYLOAD_LEN_ST  => res := STD_LOGIC_VECTOR(TO_UNSIGNED(03, TX_STATES_WIDTH_C));
      WHEN TX_CMD_TYPE_ST     => res := STD_LOGIC_VECTOR(TO_UNSIGNED(04, TX_STATES_WIDTH_C));
      WHEN TX_DEST_ADDR_ST    => res := STD_LOGIC_VECTOR(TO_UNSIGNED(05, TX_STATES_WIDTH_C));
      WHEN TX_TRANS_ID_ST     => res := STD_LOGIC_VECTOR(TO_UNSIGNED(06, TX_STATES_WIDTH_C));
      WHEN TX_PAYLOAD_ST      => res := STD_LOGIC_VECTOR(TO_UNSIGNED(07, TX_STATES_WIDTH_C));
      WHEN TX_CRC_ST          => res := STD_LOGIC_VECTOR(TO_UNSIGNED(08, TX_STATES_WIDTH_C));
      WHEN TX_DONE_ST         => res := STD_LOGIC_VECTOR(TO_UNSIGNED(09, TX_STATES_WIDTH_C));
      WHEN OTHERS             => res := STD_LOGIC_VECTOR(TO_UNSIGNED(00, TX_STATES_WIDTH_C));
    END CASE;
    RETURN res;
  END FUNCTION;

  FUNCTION encode_tx_states(state_v : STD_LOGIC_VECTOR) RETURN TX_FSM_T IS
    VARIABLE res : TX_FSM_T;
  BEGIN
    CASE to_integer(unsigned(state_v)) IS
      WHEN 01 => res := TX_IDLE_ST;
      WHEN 02 => res := TX_SOF_ST;
      WHEN 03 => res := TX_PAYLOAD_LEN_ST;
      WHEN 04 => res := TX_CMD_TYPE_ST;
      WHEN 05 => res := TX_DEST_ADDR_ST;
      WHEN 06 => res := TX_TRANS_ID_ST;
      WHEN 07 => res := TX_PAYLOAD_ST;
      WHEN 08 => res := TX_CRC_ST;
      WHEN 09 => res := TX_DONE_ST;
      WHEN OTHERS => res := TX_RESET_ST;
    END CASE;
    RETURN res;
  END FUNCTION;

  FUNCTION init_b2blink_tx_input_t RETURN b2blink_tx_input_t IS
    VARIABLE res : b2blink_tx_input_t;
  BEGIN
    res.enable := '0';
    res.start := '0';
    res.payload_base_mem_addr := (OTHERS => '0');
    res.payload_len := (OTHERS => '0');
    res.cmd_type := cmd_decode(CMD_NOP);
    res.dest_addr := (OTHERS => '0');
    res.trans_id := (OTHERS => '0');
    res.payload_mem_data := (OTHERS => '0');
    res.pattern_gen := '0';
    RETURN res;
  END FUNCTION;

  FUNCTION init_b2blink_tx_output_t RETURN b2blink_tx_output_t IS
    VARIABLE res : b2blink_tx_output_t;
  BEGIN
    res.tx := '0';
    res.busy := '0';
    res.done := '0';
    res.frame_count := (OTHERS => '0');
    RETURN res;
  END FUNCTION;

  FUNCTION init_b2blink_tx_rec_t RETURN b2blink_tx_rec_t IS
    VARIABLE res : b2blink_tx_rec_t;
  BEGIN
    res.tx_ibuf := init_b2blink_tx_input_t;
    res.tx_oreg := init_b2blink_tx_output_t;
    res.tx_buffer_data := (OTHERS => '0');
    res.tx_buffer_bcnt := 0;
    res.tx_buffer_index := 0;
    res.tx_crc_calc := (OTHERS => '0');
    res.has_payload := '0';
    res.start := '0';
    res.grant_payload_mem_access := '0';
    res.pattern_data := (OTHERS => '0');
    res.payload_mem_rdaddr := (OTHERS => '0');
    res.payload_mem_rden := '0';
    res.tx_state := TX_RESET_ST;
    RETURN res;
  END FUNCTION;

END PACKAGE BODY;