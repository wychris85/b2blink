LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;
  USE WORK.b2blink_rx_pkg.ALL;

ENTITY rx_fsm IS
  PORT (
    clk_5x_i : IN STD_LOGIC;
    rst_n_i : IN  STD_LOGIC;

    rx_enable_i : IN STD_LOGIC;
    rx_sample_index_i : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    
    -- rx-logic interface
    rx_i : IN STD_LOGIC;

    -- cmd fifo interface
    rx_cmd_fifo_full_i : IN STD_LOGIC;
    rx_cmd_fifo_wren_o : OUT STD_LOGIC;
    rx_cmd_fifo_data_o : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);

    -- payload fifo interface
    rx_payload_fifo_full_i : IN STD_LOGIC;
    rx_payload_fifo_wren_o : OUT STD_LOGIC;
    rx_payload_fifo_data_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
    
    -- rx-status
    rx_busy_o : OUT STD_LOGIC;
    rx_done_o : OUT STD_LOGIC;
    rx_curr_crc_err_flag_o : OUT STD_LOGIC;
    rx_persist_crc_err_flag_o : OUT STD_LOGIC
  );
END ENTITY;

ARCHITECTURE rtl OF rx_fsm IS

  TYPE rx_fifo_input_rec_t IS RECORD
    cmd_full_flag : STD_LOGIC;
    payload_full_flag : STD_LOGIC;
  END RECORD;

  TYPE rx_fifo_output_rec_t IS RECORD
    cmd_wren : STD_LOGIC;
    cmd_data : STD_LOGIC_VECTOR(47 DOWNTO 0);
    
    payload_wren : STD_LOGIC;
    payload_data : STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
  END RECORD;

  SIGNAL r, rin : b2blink_rx_rec_t;
  SIGNAL osr_r, osr_rin : osr_reg_t;

  SIGNAL fifo_input_sig : rx_fifo_input_rec_t;
  SIGNAL fifo_r, fifo_rin : rx_fifo_output_rec_t;
  
  CONSTANT SAMPLE_INDEX : NATURAL := (OSR_C/2);
BEGIN

  fifo_input_sig.cmd_full_flag <= rx_cmd_fifo_full_i;
  fifo_input_sig.payload_full_flag <= rx_payload_fifo_full_i;

  clock_1x_p: PROCESS (clk_5x_i) IS
  BEGIN
    IF (RISING_EDGE(clk_5x_i)) THEN
      IF (rst_n_i = '0') THEN
        r <= init_b2blink_rx_rec_t;
        osr_r <= init_osr_r_t;
        fifo_r <= (cmd_wren => '0', cmd_data => (OTHERS => '0'),
                   payload_wren => '0', payload_data => (OTHERS => '0'));
      ELSE
        r <= rin;
        osr_r <= osr_rin;
        fifo_r <= fifo_rin;
      END IF;
    END IF;
  END PROCESS;

  comb_p: PROCESS (osr_r, r, fifo_r, fifo_input_sig, rx_enable_i, rx_i) IS
    VARIABLE v : b2blink_rx_rec_t;
    VARIABLE fifo_v : rx_fifo_output_rec_t;
    VARIABLE rx_cmd_data_v : STD_LOGIC_VECTOR(47 DOWNTO 0);
    ALIAS rx_payload_len_a : STD_LOGIC_VECTOR(9 DOWNTO 0) IS rx_cmd_data_v(47 DOWNTO 38);
    ALIAS rx_cmd_type_a : STD_LOGIC_VECTOR(2 DOWNTO 0) IS rx_cmd_data_v(37 DOWNTO 35);
    ALIAS rx_dest_addr_a : STD_LOGIC_VECTOR(23 DOWNTO 0) IS rx_cmd_data_v(34 DOWNTO 11);
    ALIAS rx_trans_id_a : STD_LOGIC_VECTOR(2 DOWNTO 0) IS rx_cmd_data_v(10 DOWNTO 8);
    ALIAS rx_crc_ok_a : STD_LOGIC_VECTOR(7 DOWNTO 0) IS rx_cmd_data_v(7 DOWNTO 0);
    VARIABLE osr_v : osr_reg_t;
  BEGIN

    v := r;
    osr_v := osr_r;
    fifo_v := fifo_r;

    -- oversampling counter
    osr_v.osr_bits(0) := rx_i;
    osr_v.osr_bits(OSR_C-1 DOWNTO 1) := osr_r.osr_bits(OSR_C-2 DOWNTO 0);

    IF (osr_r.counter = OSR_C-1) THEN
      osr_v.counter := 0;
    ELSE
      osr_v.counter := osr_r.counter + 1;
    END IF;

    osr_v.sample_bit := osr_v.osr_bits(SAMPLE_INDEX);
    IF (osr_r.counter = SAMPLE_INDEX) THEN
      osr_v.sample_bit_valid := '1';
    ELSE
      osr_v.sample_bit_valid := '0';
    END IF;

    v.payload_valid := '0';
    
    fifo_v.cmd_wren := '0';
    fifo_v.payload_wren := '0';

    -- default values
    IF (rx_enable_i = '1') THEN
      CASE r.rx_state IS
        WHEN RX_RESET_ST =>
          v.rx_state := RX_IDLE_ST;

        WHEN RX_IDLE_ST =>
          v.rx_oreg.busy := '0';
          v.rx_oreg.done := '0';
          v.rx_oreg.crc_ok := '0';
          v.rx_oreg.curr_crc_err_flag := '0';
          v.rx_oreg.sof_recv := (OTHERS => '0');
          v.rx_buffer_bcnt := SOF_WIDTH_C - 1;
          -- stay in this state during at least OSR_C*rx_clk because rx_clk ist faster than system clk
          -- this is to be able to register the changes of the flags (busy, done) in the slower clock domain
          IF (r.rx_buffer_index > 0) THEN
            v.rx_buffer_index := r.rx_buffer_index - 1;
          ELSE
            v.rx_state := RX_SOF_ST;
          END IF;

        WHEN RX_SOF_ST =>
          v.rx_buffer_data(0) := osr_r.osr_bits(OSR_C-1);
          v.rx_buffer_data(RX_OSR_BUFFER_WIDTH_C-1 DOWNTO 1) := r.rx_buffer_data(RX_OSR_BUFFER_WIDTH_C-2 DOWNTO 0);
          v.rx_oreg.sof_recv := osr_indexer(r.rx_buffer_data);
          --v.rx_sof_detect := check_sync_word(r.rx_buffer_data, SOF_MASK1_C, SOF_CMP1_C);
          v.rx_sof_detect := check_sync_word(r.rx_buffer_data, SOF_MASK3_C, SOF_CMP3_C);
          IF (v.rx_sof_detect = '1') THEN
            osr_v.counter := TO_INTEGER(UNSIGNED(rx_sample_index_i));--SAMPLE_INDEX+2;
            osr_v.sample_bit_valid := '1';
            v.sync := '1';
            v.rx_oreg.payload_len := (OTHERS => '0');
            v.rx_oreg.cmd_type := (OTHERS => '0');
            v.rx_oreg.dest_addr := (OTHERS => '0');
            v.rx_oreg.trans_id := (OTHERS => '0');
            v.payload := (OTHERS => '0');
            v.rx_oreg.crc_recv := (OTHERS => '0');
            v.rx_oreg.busy := '1';
            v.rx_crc_calc := (OTHERS => '0');
            v.rx_buffer_data := (OTHERS => '0');
            v.rx_buffer_bcnt := PAYLOAD_LEN_WIDTH_C - 1;
            v.rx_buffer_index := 0;
            v.rx_state := RX_PAYLOAD_LEN_ST;
          ELSE
            v.sync := '0';
          END IF;

        WHEN RX_PAYLOAD_LEN_ST =>
          IF (osr_r.sample_bit_valid = '1') THEN
            v.rx_buffer_data(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_oreg.payload_len(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_crc_calc := crc8_fct(osr_r.sample_bit, r.rx_crc_calc);
            IF (r.rx_buffer_bcnt > 0) THEN
              v.rx_buffer_bcnt := r.rx_buffer_bcnt - 1;
            ELSE
              IF (r.rx_buffer_index > 0) THEN
                v.rx_buffer_index := r.rx_buffer_index - 1;
              ELSE
                v.rx_buffer_data := (OTHERS => '0');
                v.rx_buffer_bcnt := CMD_TYPE_WIDTH_C - 1;
                v.rx_buffer_index := 0;
                v.rx_state := RX_CMD_TYPE_ST;
              END IF;
            END IF;
          END IF;

        WHEN RX_CMD_TYPE_ST =>
          IF (osr_r.sample_bit_valid = '1') THEN
            v.rx_buffer_data(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_oreg.cmd_type(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_crc_calc := crc8_fct(osr_r.sample_bit, r.rx_crc_calc);
            IF (r.rx_buffer_bcnt > 0) THEN
              v.rx_buffer_bcnt := r.rx_buffer_bcnt - 1;
            ELSE
              IF (r.rx_buffer_index > 0) THEN
                v.rx_buffer_index := r.rx_buffer_index - 1;
              ELSE
                v.rx_buffer_data := (OTHERS => '0');
                v.rx_buffer_bcnt := DEST_ADDR_WIDTH_C - 1;
                v.rx_buffer_index := 0;
                v.rx_state := RX_DEST_ADDR_ST;
              END IF;
            END IF;
          END IF;

        WHEN RX_DEST_ADDR_ST =>
          IF (osr_r.sample_bit_valid = '1') THEN
            v.rx_buffer_data(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_oreg.dest_addr(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_crc_calc := crc8_fct(osr_r.sample_bit, r.rx_crc_calc);
            IF (r.rx_buffer_bcnt > 0) THEN
              v.rx_buffer_bcnt := r.rx_buffer_bcnt - 1;
            ELSE
              IF (r.rx_buffer_index > 0) THEN
                v.rx_buffer_index := r.rx_buffer_index - 1;
              ELSE
                v.rx_buffer_data := (OTHERS => '0');
                v.rx_buffer_bcnt := TRANSACTION_ID_WIDTH_C - 1;
                v.rx_buffer_index := 0;
                v.rx_state := RX_TRANS_ID_ST;
                IF (cmd_encode(r.rx_oreg.cmd_type) = CMD_NOP) THEN
                  v.fifo_access := '0';
                  v.has_payload := '0';
                ELSE
                  IF ((cmd_encode(r.rx_oreg.cmd_type) = CMD_WR_DATA) OR (cmd_encode(r.rx_oreg.cmd_type) = CMD_WR_CFG)) THEN
                    v.fifo_access := '1';
                  ELSE
                    v.fifo_access := '0';
                  END IF;
                END IF;
              END IF;
            END IF;
          END IF;

        WHEN RX_TRANS_ID_ST =>
          IF (osr_r.sample_bit_valid = '1') THEN
            v.rx_buffer_data(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_oreg.trans_id(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_crc_calc := crc8_fct(osr_r.sample_bit, r.rx_crc_calc);
            IF (r.rx_buffer_bcnt > 0) THEN
              v.rx_buffer_bcnt := r.rx_buffer_bcnt - 1;
            ELSE
              IF (r.rx_buffer_index > 0) THEN
                v.rx_buffer_index := r.rx_buffer_index - 1;
              ELSE
                v.has_payload := '0';
                v.rx_buffer_data := (OTHERS => '0');
                v.rx_buffer_bcnt := CRC_WIDTH_C - 1;
                v.rx_buffer_index := 0;
                v.rx_state := RX_CRC_ST;
                IF ((UNSIGNED(r.rx_oreg.payload_len) > 0) AND (r.fifo_access = '1')) THEN
                  v.has_payload := '1';
                  v.rx_buffer_bcnt := DATA_WIDTH_C - 1;
                  v.rx_buffer_index := TO_INTEGER(UNSIGNED(r.rx_oreg.payload_len) - 1);
                  v.rx_state := RX_PAYLOAD_ST;
                END IF;
              END IF;
            END IF;
          END IF;

        WHEN RX_PAYLOAD_ST =>
          IF (osr_r.sample_bit_valid = '1') THEN
            v.rx_buffer_data(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.payload(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_crc_calc := crc8_fct(osr_r.sample_bit, r.rx_crc_calc);
            fifo_v.payload_wren := '0';

            IF (r.rx_buffer_bcnt > 0) THEN
              v.rx_buffer_bcnt := r.rx_buffer_bcnt - 1;
            ELSE
              IF (r.rx_buffer_index > 0) THEN
                v.rx_buffer_index := r.rx_buffer_index - 1;
                v.rx_buffer_bcnt := DATA_WIDTH_C - 1;
              ELSE
                v.rx_buffer_data := (OTHERS => '0');
                v.rx_buffer_bcnt := CRC_WIDTH_C - 1;
                v.rx_buffer_index := 0;
                v.rx_state := RX_CRC_ST;
              END IF;

              -- write valid payload into fifo
              v.payload_valid := '1';
              IF (fifo_input_sig.payload_full_flag = '0') THEN
                fifo_v.payload_data := v.payload;
                fifo_v.payload_wren := '1';
              END IF;
            END IF;
          END IF;

        WHEN RX_CRC_ST =>
          IF (osr_r.sample_bit_valid = '1') THEN
            v.rx_buffer_data(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_oreg.crc_recv(r.rx_buffer_bcnt) := osr_r.sample_bit;
            v.rx_crc_calc := crc8_fct(osr_r.sample_bit, r.rx_crc_calc);
            IF (r.rx_buffer_bcnt > 0) THEN
              v.rx_buffer_bcnt := r.rx_buffer_bcnt - 1;
            ELSE
              IF (r.rx_buffer_index > 0) THEN
                v.rx_buffer_index := r.rx_buffer_index - 1;
              ELSE
                v.rx_buffer_index := OSR_C;
                v.rx_state := RX_DONE_ST;
              END IF;
            END IF;
          END IF;

        WHEN RX_DONE_ST =>
          IF (r.rx_buffer_index = OSR_C) THEN
            v.rx_buffer_data := (OTHERS => '0');
            v.rx_oreg.busy := '0';
            v.rx_oreg.done := '1';
            v.fifo_access := '0';
            v.has_payload := '0';
            v.rx_buffer_bcnt := 0;
            fifo_v.payload_data := (OTHERS => '0');
            IF (r.rx_crc_calc = 0) THEN
              v.rx_oreg.crc_ok := '1';
            ELSE
              v.rx_oreg.crc_ok := '0';
              v.rx_oreg.curr_crc_err_flag := '1';
              v.rx_oreg.persist_crc_err_flag := '1';
            END IF;
          END IF;

          -- stay in this state during at least OSR_C*rx_clk because rx_clk ist faster than system clk
          -- this is to be able to register the changes of the flags (busy, done) in the slower clock domain
          IF (r.rx_buffer_index > 0) THEN
            v.rx_buffer_index := r.rx_buffer_index - 1;
          ELSE
            IF (fifo_input_sig.cmd_full_flag = '0') THEN
              fifo_v.cmd_wren := '1';
            END IF;
            v.rx_buffer_index := OSR_C;
            v.rx_state := RX_IDLE_ST;
          END IF;
      END CASE;
    END IF;
    
    rx_payload_len_a := r.rx_oreg.payload_len;
    rx_cmd_type_a := r.rx_oreg.cmd_type;
    rx_dest_addr_a := r.rx_oreg.dest_addr;
    rx_trans_id_a := r.rx_oreg.trans_id;
    rx_crc_ok_a := x"0" & "000" & r.rx_oreg.crc_ok;
    fifo_v.cmd_data := rx_cmd_data_v;

    rin <= v;
    osr_rin <= osr_v;
    fifo_rin <= fifo_v;
  END PROCESS;

  -- cmd fifo output interface
  rx_cmd_fifo_data_o <= fifo_r.cmd_data;
  rx_cmd_fifo_wren_o <= fifo_r.cmd_wren;

  -- payload fifo output interface
  rx_payload_fifo_wren_o <= fifo_r.payload_wren;
  rx_payload_fifo_data_o <= fifo_r.payload_data;
  
  -- rx-status
  rx_busy_o <= r.rx_oreg.busy;
  rx_done_o <= r.rx_oreg.done;
  rx_curr_crc_err_flag_o <= r.rx_oreg.curr_crc_err_flag;
  rx_persist_crc_err_flag_o <= r.rx_oreg.persist_crc_err_flag;

END ARCHITECTURE;
