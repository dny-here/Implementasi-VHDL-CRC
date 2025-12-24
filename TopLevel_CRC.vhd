library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TopLevel_CRC is
    Port ( 
        clk         : in  std_logic; -- System 50MHz Clock
        reset       : in  std_logic; 
        btn_tick    : in  std_logic; -- Single pulse from button
        input_data  : in  std_logic_vector (7 downto 0);
        data_valid  : in  std_logic;
        data_crc    : out std_logic_vector(31 downto 0);
        is_corrupt  : out std_logic
    );
end TopLevel_CRC;

architecture Behavioral of TopLevel_CRC is

    -- State Machine Definition
    type state_type is (CRC_Transmitter, CRC_Receiver);
    signal current_state, next_state : state_type;

    -- Internal signals for the Gated Clocks
    signal clk_tx : std_logic;
    signal clk_rx : std_logic;
    
    -- Failsafe signals to prevent clock glitches
    signal tx_gate_enable : std_logic;
    signal rx_gate_enable : std_logic;

    -- Component Declarations
    component CRCtransmitter
        port (
            clk        : in  std_logic;
            input_data : in  std_logic_vector (7 downto 0);
            data_crc   : out std_logic_vector(31 downto 0);
            data_valid : in  std_logic
        );
    end component;

    component CRCreceiver
        port (
            clk        : in  std_logic;
            input_data : in  std_logic_vector (7 downto 0);
            is_corrupt : out std_logic;
            data_valid : in  std_logic
        );
    end component;

begin

    ------------------------------------------------------------------
    -- 1. FAILSAFE CLOCK GATING LOGIC
    ------------------------------------------------------------------
    -- We update the gate enable only on the falling edge of the clock.
    -- This ensures the AND gate doesn't "clip" a clock pulse halfway through.
    process(clk)
    begin
        if falling_edge(clk) then
            if current_state = CRC_Transmitter then
                tx_gate_enable <= '1';
                rx_gate_enable <= '0';
            else
                tx_gate_enable <= '0';
                rx_gate_enable <= '1';
            end if;
        end if;
    end process;

    -- The actual Gated Clocks
    clk_tx <= clk and tx_gate_enable;
    clk_rx <= clk and rx_gate_enable;


    ------------------------------------------------------------------
    -- 2. COMPONENT INSTANTIATIONS
    ------------------------------------------------------------------
    TX_INST : CRCtransmitter
    port map(
        clk        => clk_tx, -- Only toggles in Transmitter state
        input_data => input_data,
        data_crc   => data_crc,
        data_valid => data_valid
    );

    RX_INST : CRCreceiver
    port map(
        clk        => clk_rx, -- Only toggles in Receiver state
        input_data => input_data,
        is_corrupt => is_corrupt,
        data_valid => data_valid
    );


    ------------------------------------------------------------------
    -- 3. FINITE STATE MACHINE (Main Clock)
    ------------------------------------------------------------------
    -- Sequential Process
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= CRC_Transmitter;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Combinational Process
    process(current_state, btn_tick)
    begin
        next_state <= current_state; -- Default stay
        case current_state is
            when CRC_Transmitter =>
                if btn_tick = '1' then
                    next_state <= CRC_Receiver;
                end if;
            when CRC_Receiver =>
                if btn_tick = '1' then
                    next_state <= CRC_Transmitter;
                end if;
        end case;
    end process;

end Behavioral;