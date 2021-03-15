LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;

LIBRARY IEEE;
  USE WORK.base_regdef_pkg.ALL;

PACKAGE b2blink_pkg IS

  -- FRAME DEFINITION
  -- -----------------------------------------------------------------------------------------------------------------------------------
  -- |    SOF     || PAYLOAD_LEN | CMD_TYPE | DEST_ADDR | TRANSACTION_ID ||                   PAYLOAD                     ||   CRC     |
  -- -----------------------------------------------------------------------------------------------------------------------------------
  -- |    8b      ||     10b     |    3b    |    24b    |       3b       ||           32 * (0 - MAX_PAYLOAD_LEN)          ||   8b      |
  -- -----------------------------------------------------------------------------------------------------------------------------------

  -- Oversampling ratio
  CONSTANT OSR_C : NATURAL := 5;
  CONSTANT BYTE_WIDTH_C : NATURAL := 8;

  -- FRAME CONSTANTS
  CONSTANT IDLE_MESSAGE_WIDTH_C : NATURAL := 16*BYTE_WIDTH_C;             -- Field 0
  CONSTANT SOF_WIDTH_C : NATURAL := 1*BYTE_WIDTH_C;                       -- Field 1
  CONSTANT PAYLOAD_LEN_WIDTH_C : NATURAL := 10;                           -- Field 2.1
  CONSTANT CMD_TYPE_WIDTH_C : NATURAL := 3;                               -- Field 2.2
  CONSTANT DEST_ADDR_WIDTH_C : NATURAL := 3*BYTE_WIDTH_C;                 -- Field 2.3
  CONSTANT TRANSACTION_ID_WIDTH_C : NATURAL := 3;                         -- Field 2.4
  CONSTANT DATA_WIDTH_C : NATURAL := 4*BYTE_WIDTH_C;                      -- Field 3
  CONSTANT CRC_WIDTH_C : NATURAL := 1*BYTE_WIDTH_C;                       -- Field 4

  CONSTANT MAX_TRANSACTION_ID_C : STD_LOGIC_VECTOR(TRANSACTION_ID_WIDTH_C-1 DOWNTO 0) := (OTHERS => '1');
  CONSTANT MAX_PAYLOAD_LEN_C : NATURAL := 2**PAYLOAD_LEN_WIDTH_C;

  CONSTANT MIN_PAYLOAD_WIDTH_C : NATURAL := 0;
  CONSTANT MAX_PAYLOAD_WIDTH_C : NATURAL := MAX_PAYLOAD_LEN_C * DATA_WIDTH_C;

  CONSTANT MIN_FRAME_WIDTH_C : NATURAL := PAYLOAD_LEN_WIDTH_C + CMD_TYPE_WIDTH_C + DEST_ADDR_WIDTH_C + TRANSACTION_ID_WIDTH_C + MIN_PAYLOAD_WIDTH_C + CRC_WIDTH_C;
  CONSTANT MAX_FRAME_WIDTH_C : NATURAL := PAYLOAD_LEN_WIDTH_C + CMD_TYPE_WIDTH_C + DEST_ADDR_WIDTH_C + TRANSACTION_ID_WIDTH_C + MAX_PAYLOAD_WIDTH_C + CRC_WIDTH_C;

  CONSTANT MAX_BITS_COUNT_WIDTH_C : NATURAL := 32; 

  CONSTANT SOF_TX_RX_SYNC_WORD_C : STD_LOGIC_VECTOR(SOF_WIDTH_C-1 DOWNTO 0) := "10101010";
  CONSTANT SOF_TX_RX_SYNC_WORD_OSR_C : STD_LOGIC_VECTOR((SOF_WIDTH_C * OSR_C)-1 DOWNTO 0) := "1111100000111110000011111000001111100000";
  CONSTANT SOF_TX_RX_MASK_OSR_C : STD_LOGIC_VECTOR((SOF_WIDTH_C * OSR_C)-1 DOWNTO 0)      := "0010000100001000010000100001000010000100";
  CONSTANT SOF_TX_RX_COMP_OSR_C : STD_LOGIC_VECTOR((SOF_WIDTH_C * OSR_C)-1 DOWNTO 0)      := "0010000000001000000000100000000010000000";

  CONSTANT MAX_SIZE_COMMAND_MEM_C : NATURAL := 1024;
  CONSTANT MAX_SIZE_PAYLOAD_MEM_C : NATURAL := 1024;

  -- COMMAND TYPES
  TYPE CMD_TYPES_T IS (CMD_NOP, CMD_WR_DATA, CMD_WR_CFG, CMD_WR_ACK, CMD_RD_DATA, CMD_RD_CFG, CMD_RD_ACK, CMD_STOP);
  -- CMD_NOP      :   NATURAL := 0;   no operation
  -- CMD_WR_DATA  :   NATURAL := 1;   master writes data to slave
  -- CMD_WR_CFG   :   NATURAL := 2;   master write into slave's configuration registers
  -- CMD_WR_ACK   :   NATURAL := 3;   slaves acknowledges the reception of data sent by the master
  -- CMD_RD_DATA  :   NATURAL := 4;   master reads data from slave
  -- CMD_RD_CFG   :   NATURAL := 5;   master reads slave's configuration registers
  -- CMD_RD_ACK   :   NATURAL := 6;   master acknowledges the reception of data sent by the slave

  -- FIFO CONSTANTS
  CONSTANT FIFO_BUFFER_DEPTH_C : NATURAL := MAX_PAYLOAD_LEN_C;

  FUNCTION cmd_encode(cmd_type : STD_LOGIC_VECTOR) RETURN CMD_TYPES_T;
  FUNCTION cmd_decode(cmd_type : CMD_TYPES_T) RETURN STD_LOGIC_VECTOR;
  FUNCTION crc8_fct(din : STD_LOGIC; crc : UNSIGNED) RETURN UNSIGNED;
  FUNCTION crc8_of_word(word : STD_LOGIC_VECTOR; init_crc8 : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;
END PACKAGE;

PACKAGE BODY b2blink_pkg IS

  FUNCTION cmd_encode(cmd_type : STD_LOGIC_VECTOR) RETURN CMD_TYPES_T IS
    VARIABLE res : CMD_TYPES_T := CMD_NOP;
  BEGIN
    CASE to_integer(unsigned(cmd_type)) IS
      WHEN 01     => res := CMD_WR_DATA;
      WHEN 02     => res := CMD_WR_CFG;
      WHEN 03     => res := CMD_WR_ACK;
      WHEN 04     => res := CMD_RD_DATA;
      WHEN 05     => res := CMD_RD_CFG;
      WHEN 06     => res := CMD_RD_ACK;
      WHEN 07     => res := CMD_STOP;
      WHEN OTHERS => res := CMD_NOP;            
    END CASE;
    RETURN res;
  END FUNCTION;

  FUNCTION cmd_decode(cmd_type : CMD_TYPES_T) RETURN STD_LOGIC_VECTOR IS
    VARIABLE res : STD_LOGIC_VECTOR(CMD_TYPE_WIDTH_C-1 DOWNTO 0);
  BEGIN
    CASE cmd_type IS
      WHEN CMD_WR_DATA    => res := STD_LOGIC_VECTOR(TO_UNSIGNED(01, CMD_TYPE_WIDTH_C));
      WHEN CMD_WR_CFG     => res := STD_LOGIC_VECTOR(TO_UNSIGNED(02, CMD_TYPE_WIDTH_C));
      WHEN CMD_WR_ACK     => res := STD_LOGIC_VECTOR(TO_UNSIGNED(03, CMD_TYPE_WIDTH_C));
      WHEN CMD_RD_DATA    => res := STD_LOGIC_VECTOR(TO_UNSIGNED(04, CMD_TYPE_WIDTH_C));
      WHEN CMD_RD_CFG     => res := STD_LOGIC_VECTOR(TO_UNSIGNED(05, CMD_TYPE_WIDTH_C));
      WHEN CMD_RD_ACK     => res := STD_LOGIC_VECTOR(TO_UNSIGNED(06, CMD_TYPE_WIDTH_C));
      WHEN CMD_STOP       => res := STD_LOGIC_VECTOR(TO_UNSIGNED(07, CMD_TYPE_WIDTH_C));
      WHEN OTHERS         => res := STD_LOGIC_VECTOR(TO_UNSIGNED(00, CMD_TYPE_WIDTH_C));
    END CASE;
    RETURN res;
  END FUNCTION;

  -- polynomial: x^8 + x^5 + x^4 + 1
  -- data width: 1
  -- convention: the first serial bit is D[0]
  FUNCTION crc8_fct(din : STD_LOGIC; crc : UNSIGNED) RETURN UNSIGNED IS
    VARIABLE dv:     STD_LOGIC_VECTOR(0 DOWNTO 0);
    VARIABLE d:      UNSIGNED(0 DOWNTO 0);
    VARIABLE c:      UNSIGNED(7 DOWNTO 0);
    VARIABLE newcrc: UNSIGNED(7 DOWNTO 0);
  BEGIN

    dv(0) := din;

    d := UNSIGNED(dv);
    c := crc;

    newcrc(0) := c(7) XOR d(0);
    newcrc(1) := c(0);
    newcrc(2) := c(1);
    newcrc(3) := c(2);
    newcrc(4) := c(7) XOR d(0) XOR c(3);
    newcrc(5) := c(7) XOR d(0) XOR c(4);
    newcrc(6) := c(5);
    newcrc(7) := c(6);

    RETURN newcrc;
  END FUNCTION;

  FUNCTION crc8_of_word(word : STD_LOGIC_VECTOR; init_crc8 : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
    VARIABLE tmp_crc8 : UNSIGNED(7 DOWNTO 0);
    VARIABLE bit_in : STD_LOGIC;
  BEGIN
    tmp_crc8 := UNSIGNED(init_crc8);
    FOR idx IN word'RANGE LOOP
      bit_in := word(idx);
      tmp_crc8 := crc8_fct(bit_in, tmp_crc8);
    END LOOP;
    RETURN STD_LOGIC_VECTOR(tmp_crc8);
  END FUNCTION;

END PACKAGE BODY;