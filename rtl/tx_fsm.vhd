LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY WORK;
  USE WORK.b2blink_pkg.ALL;
  USE WORK.b2blink_tx_pkg.ALL;
  USE WORK.base_regdef_pkg.ALL;

ENTITY tx_fsm IS
  PORT (
    clk_1x_i: IN  STD_LOGIC;
    rst_n_i: IN  STD_LOGIC;

    enable_i : IN STD_LOGIC;

    -- tx-logic interface
    start_i : IN STD_LOGIC;
    pattern_gen_i : IN STD_LOGIC;

    payload_len_i : IN STD_LOGIC_VECTOR(PAYLOAD_LEN_WIDTH_C-1 DOWNTO 0);
    cmd_type_i : IN STD_LOGIC_VECTOR(CMD_TYPE_WIDTH_C-1 DOWNTO 0);
    dest_addr_i : IN STD_LOGIC_VECTOR(DEST_ADDR_WIDTH_C-1 DOWNTO 0);
    trans_id_i : IN STD_LOGIC_VECTOR(TRANSACTION_ID_WIDTH_C-1 DOWNTO 0);

    tx_o : OUT STD_LOGIC;
    tx_busy_o : OUT STD_LOGIC;
    tx_done_o : OUT STD_LOGIC;
    tx_frame_count_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);

    ---- fifo buffer interface (read port)
    payload_mem_base_addr_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_rdaddr_o : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    payload_mem_rden_o : OUT STD_LOGIC;
    payload_mem_data_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- debug interface
    tx_bitcnt_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH_C-1 DOWNTO 0);
    tx_data_o : OUT STD_LOGIC_VECTOR(TX_BUFFER_WIDTH_C-1 DOWNTO 0);
    tx_state_o : OUT STD_LOGIC_VECTOR(TX_STATES_WIDTH_C-1 DOWNTO 0)
  );
END ENTITY;

ARCHITECTURE rtl OF tx_fsm IS

  SIGNAL r, rin : b2blink_tx_rec_t;
  SIGNAL input_s : b2blink_tx_input_t;

BEGIN

  -- tx-logic interface
  input_s.enable <= enable_i;
  input_s.start <= start_i;
  input_s.trans_id <= trans_id_i;
  input_s.cmd_type <= cmd_type_i;
  input_s.payload_len <= payload_len_i;
  input_s.dest_addr <= dest_addr_i;
  input_s.pattern_gen <= pattern_gen_i;
  input_s.payload_base_mem_addr <= UNSIGNED(payload_mem_base_addr_i);
  input_s.payload_mem_data <= payload_mem_data_i;

  clock_p: PROCESS (clk_1x_i) IS
  BEGIN
    IF (RISING_EDGE(clk_1x_i)) THEN
      IF (rst_n_i = '0') THEN
        r <= init_b2blink_tx_rec_t;
      ELSE
        r <= rin;
      END IF;
    END IF;
  END PROCESS;

  comb_p: PROCESS (r, input_s) IS
    VARIABLE v : b2blink_tx_rec_t;
  BEGIN

    v := r;

    -- default values
    v.tx_oreg.tx := '0';
    v.start := input_s.start;

    IF (input_s.enable = '1') THEN

      CASE r.tx_state IS
        WHEN TX_RESET_ST =>          
          v.tx_state := TX_IDLE_ST;

        WHEN TX_IDLE_ST =>
          v.tx_oreg.busy := '0';
          v.tx_oreg.done := '0';
          v.tx_buffer_data := STD_LOGIC_VECTOR(TO_UNSIGNED(0, TX_BUFFER_WIDTH_C - SOF_WIDTH_C)) & SOF_TX_RX_SYNC_WORD_C;
          v.tx_buffer_bcnt := SOF_WIDTH_C - 1;

          IF (r.tx_buffer_index > 0) THEN
            v.tx_buffer_index := r.tx_buffer_index - 1;
          ELSE
            IF (r.start = '0' AND v.start = '1') THEN
              -- sample new frame input
              v.tx_oreg.busy := '1';
              v.tx_ibuf := input_s;
              v.tx_crc_calc := (OTHERS => '0');
              v.tx_state := TX_SOF_ST;
            END IF;
          END IF;

        WHEN TX_SOF_ST =>
          v.tx_oreg.tx := r.tx_buffer_data(r.tx_buffer_bcnt);
          IF (r.tx_buffer_bcnt > 0) THEN
            v.tx_buffer_bcnt := r.tx_buffer_bcnt - 1;
          ELSE
            IF (r.tx_buffer_index > 0) THEN
              v.tx_buffer_index := r.tx_buffer_index - 1;
            ELSE
              v.tx_buffer_data := STD_LOGIC_VECTOR(TO_UNSIGNED(0, TX_BUFFER_WIDTH_C - PAYLOAD_LEN_WIDTH_C)) & r.tx_ibuf.payload_len;
              v.tx_buffer_bcnt := PAYLOAD_LEN_WIDTH_C - 1;
              v.tx_buffer_index := 0;
              v.tx_state := TX_PAYLOAD_LEN_ST;
            END IF;
          END IF;

        WHEN TX_PAYLOAD_LEN_ST =>
          v.tx_oreg.tx := r.tx_buffer_data(r.tx_buffer_bcnt);
          v.tx_crc_calc := crc8_fct(v.tx_oreg.tx, r.tx_crc_calc);
          IF (r.tx_buffer_bcnt > 0) THEN
            v.tx_buffer_bcnt := r.tx_buffer_bcnt - 1;
          ELSE
            IF (r.tx_buffer_index > 0) THEN
              v.tx_buffer_index := r.tx_buffer_index - 1;
            ELSE
              v.tx_buffer_data := STD_LOGIC_VECTOR(TO_UNSIGNED(0, TX_BUFFER_WIDTH_C - CMD_TYPE_WIDTH_C)) & r.tx_ibuf.cmd_type;
              v.tx_buffer_bcnt := CMD_TYPE_WIDTH_C - 1;
              v.tx_buffer_index := 0;
              v.tx_state := TX_CMD_TYPE_ST;
            END IF;
          END IF;

        WHEN TX_CMD_TYPE_ST =>
          v.tx_oreg.tx := r.tx_buffer_data(r.tx_buffer_bcnt);
          v.tx_crc_calc := crc8_fct(v.tx_oreg.tx, r.tx_crc_calc);
          IF (r.tx_buffer_bcnt > 0) THEN
            v.tx_buffer_bcnt := r.tx_buffer_bcnt - 1;
          ELSE
            IF (r.tx_buffer_index > 0) THEN
              v.tx_buffer_index := r.tx_buffer_index - 1;
            ELSE
              v.tx_buffer_data := STD_LOGIC_VECTOR(TO_UNSIGNED(0, TX_BUFFER_WIDTH_C - DEST_ADDR_WIDTH_C)) & r.tx_ibuf.dest_addr;
              v.tx_buffer_bcnt := DEST_ADDR_WIDTH_C - 1;
              v.tx_buffer_index := 0;
              v.tx_state := TX_DEST_ADDR_ST;
            END IF;
          END IF;

        WHEN TX_DEST_ADDR_ST =>
          v.tx_oreg.tx := r.tx_buffer_data(r.tx_buffer_bcnt);
          v.tx_crc_calc := crc8_fct(v.tx_oreg.tx, r.tx_crc_calc);
          IF (r.tx_buffer_bcnt > 0) THEN
            v.tx_buffer_bcnt := r.tx_buffer_bcnt - 1;
          ELSE
            IF (r.tx_buffer_index > 0) THEN
              v.tx_buffer_index := r.tx_buffer_index - 1;
            ELSE
              v.tx_buffer_data := STD_LOGIC_VECTOR(TO_UNSIGNED(0, TX_BUFFER_WIDTH_C - TRANSACTION_ID_WIDTH_C)) & r.tx_ibuf.trans_id;
              v.tx_buffer_bcnt := TRANSACTION_ID_WIDTH_C - 1;
              v.tx_buffer_index := 0;
              v.tx_state := TX_TRANS_ID_ST;
              IF (cmd_encode(r.tx_ibuf.cmd_type) = CMD_NOP) THEN
                v.has_payload := '0';
                v.grant_payload_mem_access := '0';
              ELSE
                IF ((cmd_encode(r.tx_ibuf.cmd_type) = CMD_WR_DATA) OR (cmd_encode(r.tx_ibuf.cmd_type) = CMD_WR_CFG)) THEN
                  v.grant_payload_mem_access := '1';
                ELSE
                  v.grant_payload_mem_access := '0';
                END IF;
                IF (UNSIGNED(r.tx_ibuf.payload_len) > 0) THEN
                  v.has_payload := '1';
                ELSE
                  v.has_payload := '0';
                END IF;
              END IF;
            END IF;
          END IF;

        WHEN TX_TRANS_ID_ST =>
          v.tx_oreg.tx := r.tx_buffer_data(r.tx_buffer_bcnt);
          v.tx_crc_calc := crc8_fct(v.tx_oreg.tx, r.tx_crc_calc);
          v.payload_mem_rden := '0';
          IF (r.tx_buffer_bcnt > 0) THEN
            v.tx_buffer_bcnt := r.tx_buffer_bcnt - 1;
            IF ((r.has_payload = '1') AND (r.grant_payload_mem_access = '1')) THEN
              IF (r.tx_buffer_bcnt = 2) THEN
                IF (r.tx_ibuf.pattern_gen = '0') THEN
                  v.payload_mem_rden := '1';
                  v.payload_mem_rdaddr := r.tx_ibuf.payload_base_mem_addr;
                END IF;
              END IF;
            END IF;
          ELSE
            IF (r.tx_buffer_index > 0) THEN
              v.tx_buffer_index := r.tx_buffer_index - 1;
            ELSE
              v.tx_buffer_data := (OTHERS => '0');
              v.tx_buffer_bcnt := CRC_WIDTH_C - 1;
              v.tx_buffer_index := 0;
              v.tx_state := TX_CRC_ST;
              IF ((r.has_payload = '1') AND (r.grant_payload_mem_access = '1')) THEN
                v.tx_buffer_data := (OTHERS => '0');
                v.tx_buffer_bcnt := DATA_WIDTH_C - 1;
                v.tx_buffer_index := TO_INTEGER(UNSIGNED(r.tx_ibuf.payload_len) - 1);
                v.tx_state := TX_PAYLOAD_ST;
                IF (r.tx_ibuf.pattern_gen = '1') THEN
                  v.pattern_data := (0 => '1', OTHERS => '0');
                END IF;
              END IF;
            END IF;
          END IF;

        WHEN TX_PAYLOAD_ST =>
          IF (r.tx_ibuf.pattern_gen = '1') THEN
            v.tx_oreg.tx := r.pattern_data(r.tx_buffer_bcnt);
            v.tx_crc_calc := crc8_fct(v.tx_oreg.tx, r.tx_crc_calc);
          ELSE
            v.tx_oreg.tx := input_s.payload_mem_data(r.tx_buffer_bcnt);
            v.tx_crc_calc := crc8_fct(v.tx_oreg.tx, r.tx_crc_calc);
          END IF;
          v.payload_mem_rden := '0';
          IF (r.tx_buffer_bcnt > 0) THEN
            v.tx_buffer_bcnt := r.tx_buffer_bcnt - 1;
            IF ((r.has_payload = '1') AND (r.grant_payload_mem_access = '1')) THEN
              IF ((r.tx_buffer_bcnt = 2)) THEN
                IF ((r.tx_ibuf.pattern_gen = '0') AND (r.tx_buffer_index > 0)) THEN
                  v.payload_mem_rden := '1';
                  v.payload_mem_rdaddr := r.payload_mem_rdaddr + 1;
                END IF;
              END IF;
            END IF;
          ELSE
            IF (r.tx_buffer_index > 0) THEN
              v.tx_buffer_index := r.tx_buffer_index - 1;
              v.tx_buffer_bcnt := DATA_WIDTH_C - 1;
              IF (r.tx_ibuf.pattern_gen = '1') THEN
                v.pattern_data := r.pattern_data + 1;
              END IF;
            ELSE
              v.tx_buffer_data := (OTHERS => '0');
              v.tx_buffer_bcnt := CRC_WIDTH_C - 1;
              v.tx_buffer_index := 0;
              v.tx_state := TX_CRC_ST;
            END IF;
          END IF;

        WHEN TX_CRC_ST =>
          v.tx_oreg.tx := r.tx_crc_calc(r.tx_buffer_bcnt);
          IF (r.tx_buffer_bcnt > 0) THEN
            v.tx_buffer_bcnt := r.tx_buffer_bcnt - 1;
          ELSE
            IF (r.tx_buffer_index > 0) THEN
              v.tx_buffer_index := r.tx_buffer_index - 1;
            ELSE
              v.tx_buffer_index := OSR_C;
              v.tx_state := TX_DONE_ST;
            END IF;
          END IF;

        WHEN TX_DONE_ST =>
          IF (r.tx_buffer_index = OSR_C) THEN
            v.grant_payload_mem_access := '0';
            v.has_payload := '0';
            v.tx_oreg.busy := '0';
            v.tx_oreg.done := '1';
            v.tx_oreg.frame_count := r.tx_oreg.frame_count + 1;
          END IF;

          IF (r.tx_buffer_index > 0) THEN
            v.tx_buffer_index := r.tx_buffer_index - 1;
          ELSE
            v.tx_buffer_index := OSR_C;
            v.tx_state := TX_IDLE_ST;
          END IF;
      END CASE;
    END IF;

    rin <= v;

    -- output assignment
    tx_o <= r.tx_oreg.tx;
    tx_busy_o <= r.tx_oreg.busy;
    tx_done_o <= r.tx_oreg.done;
    tx_frame_count_o <= STD_LOGIC_VECTOR(r.tx_oreg.frame_count);

    --bram interface
    payload_mem_rdaddr_o <= STD_LOGIC_VECTOR(r.payload_mem_rdaddr);
    payload_mem_rden_o <= r.payload_mem_rden;
    
    -- debug interface
    tx_bitcnt_o <= STD_LOGIC_VECTOR(TO_UNSIGNED(r.tx_buffer_bcnt, tx_bitcnt_o'LENGTH));
    tx_data_o <= r.tx_buffer_data(TX_BUFFER_WIDTH_C-1 DOWNTO 0);
    tx_state_o <= decode_tx_states(r.tx_state);

  END PROCESS;

END ARCHITECTURE;
