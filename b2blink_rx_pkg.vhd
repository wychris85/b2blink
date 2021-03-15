LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;

PACKAGE b2blink_rx_pkg IS

  CONSTANT RX_BUFFER_WIDTH_C : NATURAL := DATA_WIDTH_C;
  CONSTANT RX_OSR_BUFFER_WIDTH_C : NATURAL := SOF_WIDTH_C*OSR_C;
  CONSTANT RX_STATES_WIDTH_C : NATURAL := 4;
                                                                                                         --"10101010"
  CONSTANT IDEAL_SOF_C : STD_LOGIC_VECTOR((SOF_WIDTH_C*OSR_C)-1 DOWNTO 0)  := x"F8" & x"3E0F" & x"83E0"; --"1111100000111110000011111000001111100000"
  
  CONSTANT SOF_MASK3_C : STD_LOGIC_VECTOR((SOF_WIDTH_C*OSR_C)-1 DOWNTO 0)  := x"21" & x"0842" & x"1084"; --"0111001110011100111001110011100111001110";
  CONSTANT SOF_CMP3_C : STD_LOGIC_VECTOR((SOF_WIDTH_C*OSR_C)-1 DOWNTO 0)   := x"20" & x"0802" & x"0080"; --"0111000000011100000001110000000111000000";
  
  
  CONSTANT SOF_MASK1_C : STD_LOGIC_VECTOR((SOF_WIDTH_C*OSR_C)-1 DOWNTO 0)  := x"21" & x"0842" & x"1084"; --"0010000100001000010000100001000010000100";
  CONSTANT SOF_CMP1_C : STD_LOGIC_VECTOR((SOF_WIDTH_C*OSR_C)-1 DOWNTO 0)   := x"20" & x"0802" & x"0080"; --"0010000000001000000000100000000010000000";
  

  -- RX-FSM
  TYPE RX_FSM_T IS (RX_RESET_ST, RX_IDLE_ST, RX_SOF_ST, RX_TRANS_ID_ST, RX_CMD_TYPE_ST, RX_PAYLOAD_LEN_ST, RX_DEST_ADDR_ST, RX_PAYLOAD_ST, RX_CRC_ST, RX_DONE_ST);

  TYPE b2blink_rx_input_t IS RECORD
    rx : STD_LOGIC;
    valid : STD_LOGIC;
  END RECORD;

  TYPE b2blink_rx_output_t IS RECORD
    sof_recv : STD_LOGIC_VECTOR(SOF_WIDTH_C-1 DOWNTO 0);
    payload_len : STD_LOGIC_VECTOR(PAYLOAD_LEN_WIDTH_C-1 DOWNTO 0);
    cmd_type : STD_LOGIC_VECTOR(CMD_TYPE_WIDTH_C-1 DOWNTO 0);
    dest_addr : STD_LOGIC_VECTOR(DEST_ADDR_WIDTH_C-1 DOWNTO 0);
    trans_id : STD_LOGIC_VECTOR(TRANSACTION_ID_WIDTH_C-1 DOWNTO 0);
    crc_recv : STD_LOGIC_VECTOR(CRC_WIDTH_C-1 DOWNTO 0);
    busy : STD_LOGIC;
    done : STD_LOGIC;
    crc_ok : STD_LOGIC;
    curr_crc_err_flag : STD_LOGIC;
    persist_crc_err_flag : STD_LOGIC;
  END RECORD;

  TYPE b2blink_rx_rec_t IS RECORD
    rx_oreg : b2blink_rx_output_t;
    rx_sof_detect : STD_LOGIC;
    rx_buffer_data : STD_LOGIC_VECTOR(RX_OSR_BUFFER_WIDTH_C-1 DOWNTO 0);
    rx_buffer_bcnt : natural RANGE 0 TO 40;
    rx_buffer_index : natural RANGE 0 TO 40;
    rx_crc_calc : UNSIGNED(CRC_WIDTH_C-1 DOWNTO 0);
    has_payload : STD_LOGIC;
    sync : STD_LOGIC;
    fifo_access : STD_LOGIC;
    payload : STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
    payload_valid : STD_LOGIC;
    rx_state : RX_FSM_T;
  END RECORD;

  TYPE osr_reg_t IS RECORD
    osr_bits : STD_LOGIC_VECTOR(OSR_C-1 DOWNTO 0);        
    sample_bit : STD_LOGIC;
    sample_bit_valid : STD_LOGIC;
    counter : NATURAL RANGE 0 TO OSR_C;
  END RECORD;

  FUNCTION init_osr_r_t RETURN osr_reg_t;

  FUNCTION encode_rx_states(state_v : STD_LOGIC_VECTOR) RETURN RX_FSM_T;
  FUNCTION decode_rx_states(state_t : RX_FSM_T) RETURN STD_LOGIC_VECTOR;
  FUNCTION init_b2blink_rx_input_t RETURN b2blink_rx_input_t;
  FUNCTION init_b2blink_rx_output_t RETURN b2blink_rx_output_t;
  FUNCTION init_b2blink_rx_rec_t RETURN b2blink_rx_rec_t;
  FUNCTION check_sync_word(sync_rx, sync_mask, sync_cmp : STD_LOGIC_VECTOR((SOF_WIDTH_C*OSR_C)-1 DOWNTO 0)) RETURN STD_LOGIC;
  FUNCTION osr_indexer(din : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR; 

END PACKAGE;

PACKAGE BODY b2blink_rx_pkg IS

  FUNCTION decode_rx_states(state_t : RX_FSM_T) RETURN STD_LOGIC_VECTOR IS
    VARIABLE res : STD_LOGIC_VECTOR(RX_STATES_WIDTH_C-1 DOWNTO 0);
  BEGIN
    CASE state_t IS
      WHEN RX_IDLE_ST         => res := STD_LOGIC_VECTOR(TO_UNSIGNED(01, RX_STATES_WIDTH_C));
      WHEN RX_SOF_ST          => res := STD_LOGIC_VECTOR(TO_UNSIGNED(02, RX_STATES_WIDTH_C));
      WHEN RX_PAYLOAD_LEN_ST  => res := STD_LOGIC_VECTOR(TO_UNSIGNED(03, RX_STATES_WIDTH_C));
      WHEN RX_CMD_TYPE_ST     => res := STD_LOGIC_VECTOR(TO_UNSIGNED(04, RX_STATES_WIDTH_C));
      WHEN RX_DEST_ADDR_ST    => res := STD_LOGIC_VECTOR(TO_UNSIGNED(05, RX_STATES_WIDTH_C));
      WHEN RX_TRANS_ID_ST     => res := STD_LOGIC_VECTOR(TO_UNSIGNED(06, RX_STATES_WIDTH_C));
      WHEN RX_PAYLOAD_ST      => res := STD_LOGIC_VECTOR(TO_UNSIGNED(07, RX_STATES_WIDTH_C));
      WHEN RX_CRC_ST          => res := STD_LOGIC_VECTOR(TO_UNSIGNED(08, RX_STATES_WIDTH_C));
      WHEN RX_DONE_ST         => res := STD_LOGIC_VECTOR(TO_UNSIGNED(09, RX_STATES_WIDTH_C));
      WHEN OTHERS             => res := STD_LOGIC_VECTOR(TO_UNSIGNED(00, RX_STATES_WIDTH_C));
    END CASE;
    RETURN res;
  END FUNCTION;

  FUNCTION encode_rx_states(state_v : STD_LOGIC_VECTOR) RETURN RX_FSM_T IS
    VARIABLE res : RX_FSM_T;
  BEGIN
    CASE to_integer(unsigned(state_v)) IS
      WHEN 01 => res := RX_IDLE_ST;
      WHEN 02 => res := RX_SOF_ST;
      WHEN 03 => res := RX_PAYLOAD_LEN_ST;
      WHEN 04 => res := RX_CMD_TYPE_ST;
      WHEN 05 => res := RX_DEST_ADDR_ST;
      WHEN 06 => res := RX_TRANS_ID_ST;
      WHEN 07 => res := RX_PAYLOAD_ST;
      WHEN 08 => res := RX_CRC_ST;
      WHEN 09 => res := RX_DONE_ST;
      WHEN OTHERS => res := RX_RESET_ST;
    END CASE;
    RETURN res;
  END FUNCTION;

  FUNCTION init_b2blink_rx_input_t RETURN b2blink_rx_input_t IS
    VARIABLE res : b2blink_rx_input_t;
  BEGIN
    res.rx := '0';
    res.valid := '0';
    RETURN res;
  END FUNCTION;

  FUNCTION init_b2blink_rx_output_t RETURN b2blink_rx_output_t IS
    VARIABLE res : b2blink_rx_output_t;
  BEGIN
    res.sof_recv := (OTHERS => '0');
    res.payload_len := (OTHERS => '0');
    res.cmd_type := (OTHERS => '0');
    res.dest_addr := (OTHERS => '0');
    res.trans_id := (OTHERS => '0');
    res.crc_recv := (OTHERS => '0');
    res.busy := '0';
    res.done := '0';
    res.crc_ok := '0';
    res.curr_crc_err_flag := '0';
    res.persist_crc_err_flag := '0';
    RETURN res;
  END FUNCTION;

  FUNCTION init_b2blink_rx_rec_t RETURN b2blink_rx_rec_t IS
    VARIABLE res : b2blink_rx_rec_t;
  BEGIN
    res.rx_oreg := init_b2blink_rx_output_t;
    res.rx_sof_detect := '0';
    res.rx_buffer_data := (OTHERS => '0');
    res.rx_buffer_bcnt := 0;
    res.rx_buffer_index := 0;
    res.rx_crc_calc := (OTHERS => '0');
    res.has_payload := '0';
    res.sync := '0';
    res.fifo_access := '0';
    res.payload := (OTHERS => '0');
    res.payload_valid := '0';
    res.rx_state := RX_RESET_ST;
    RETURN res;
  END FUNCTION;

  -- takes the center bit from a 5bit cluster "--1--"
  FUNCTION osr_indexer(din : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
    VARIABLE res : STD_LOGIC_VECTOR((din'LENGTH/OSR_C)-1 DOWNTO 0);
  BEGIN
    FOR i IN res'RANGE LOOP
      res(i) := din(2+(i*OSR_C));
    END LOOP;
    RETURN res;
  END FUNCTION;

  FUNCTION init_osr_r_t RETURN osr_reg_t IS
    VARIABLE res : osr_reg_t;
  BEGIN
    res.osr_bits := (OTHERS => '0');
    res.counter := 0;
    res.sample_bit := '0';
    res.sample_bit_valid := '0';
    RETURN res;
  END FUNCTION;

  FUNCTION check_sync_word(sync_rx, sync_mask, sync_cmp : STD_LOGIC_VECTOR((SOF_WIDTH_C*OSR_C)-1 DOWNTO 0)) RETURN STD_LOGIC IS
    VARIABLE sync_masked_v : STD_LOGIC_VECTOR((SOF_WIDTH_C*OSR_C)-1 DOWNTO 0);
  BEGIN
    sync_masked_v := sync_rx AND sync_mask;
    IF sync_masked_v = sync_cmp THEN
      RETURN '1';
    ELSE
      RETURN '0';
    END IF;
  END FUNCTION;

END PACKAGE BODY;