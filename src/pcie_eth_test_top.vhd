----------------------------------------------------------------------------------
-- PCIe + Ethernet Clock Test Top
-- Purpose: Test if adding Ethernet clock domain breaks PCIe detection
--
-- This is Project 22 (working Gen2 PCIe) with ONLY:
--   - Differential 200 MHz clock input (from Ethernet oscillator)
--   - RGMII RX clock buffer
--   - PHY reset logic
--   - NO data path connection - just clock domains coexisting
--
-- If PCIe still detects: Clocks are fine, issue is in data path
-- If PCIe breaks: Clock interaction or reset sequencing issue
--
-- Target: AX7203 (XC7A200T-2FBG484I)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity pcie_eth_test_top is
    Port (
        -- System Clock (200 MHz differential from Ethernet oscillator)
        -- COMMENTED OUT: Testing if 200MHz clock causes Gen2 issues
        -- sys_clk_p         : in  STD_LOGIC;
        -- sys_clk_n         : in  STD_LOGIC;

        -- System Reset (active LOW)
        reset_n           : in  STD_LOGIC;

        -- RGMII Ethernet Port 1 (just clock, no data)
        rgmii1_rxc        : in  STD_LOGIC;
        -- TX outputs (directly drive idle)
        rgmii1_txc        : out STD_LOGIC;
        rgmii1_txctl      : out STD_LOGIC;
        rgmii1_txd        : out STD_LOGIC_VECTOR(3 downto 0);

        -- PHY Reset
        e1_reset          : out STD_LOGIC;

        -- PCIe Interface (from Project 22)
        pcie_mgt_rxn      : in  STD_LOGIC_VECTOR(3 downto 0);
        pcie_mgt_rxp      : in  STD_LOGIC_VECTOR(3 downto 0);
        pcie_mgt_txn      : out STD_LOGIC_VECTOR(3 downto 0);
        pcie_mgt_txp      : out STD_LOGIC_VECTOR(3 downto 0);
        pcie_refclk_clk_n : in  STD_LOGIC_VECTOR(0 downto 0);
        pcie_refclk_clk_p : in  STD_LOGIC_VECTOR(0 downto 0);
        pcie_perst_n      : in  STD_LOGIC;

        -- Status LEDs
        led               : out STD_LOGIC_VECTOR(3 downto 0)
    );
end pcie_eth_test_top;

architecture Behavioral of pcie_eth_test_top is

    ---------------------------------------------------------------------------
    -- Clock Signals
    ---------------------------------------------------------------------------
   -- signal sys_clk_200mhz   : STD_LOGIC;
    signal rgmii_rxc_buf    : STD_LOGIC;
    signal axi_aclk         : STD_LOGIC;
    signal axi_aresetn      : STD_LOGIC;

    ---------------------------------------------------------------------------
    -- Reset / PHY Control
    ---------------------------------------------------------------------------
    signal reset            : STD_LOGIC;
    signal phy_reset_counter : unsigned(23 downto 0) := (others => '0');
    signal phy_reset_done   : STD_LOGIC := '0';

    ---------------------------------------------------------------------------
    -- PCIe Signals
    ---------------------------------------------------------------------------
    signal c2h_tdata        : STD_LOGIC_VECTOR(63 downto 0);
    signal c2h_tkeep        : STD_LOGIC_VECTOR(7 downto 0);
    signal c2h_tvalid       : STD_LOGIC;
    signal c2h_tready       : STD_LOGIC;
    signal c2h_tlast        : STD_LOGIC;
    signal pcie_link_up     : STD_LOGIC;

    ---------------------------------------------------------------------------
    -- Test Pattern Generator (same as working Project 22)
    ---------------------------------------------------------------------------
    signal test_state       : integer range 0 to 6 := 0;
    signal test_pkt_cnt     : unsigned(31 downto 0) := (others => '0');
    signal test_timer       : unsigned(19 downto 0) := (others => '0');

    ---------------------------------------------------------------------------
    -- Heartbeat
    ---------------------------------------------------------------------------
    signal heartbeat_counter : unsigned(26 downto 0) := (others => '0');

begin

    ---------------------------------------------------------------------------
    -- Differential Clock Buffer (200 MHz from Ethernet oscillator)
    ---------------------------------------------------------------------------
--    IBUFDS_inst : IBUFDS
--        generic map (
--            DIFF_TERM => FALSE,
--            IBUF_LOW_PWR => TRUE,
--            IOSTANDARD => "DEFAULT"
--        )
--        port map (
--            O  => sys_clk_200mhz,
--            I  => sys_clk_p,
--            IB => sys_clk_n
--        );

    ---------------------------------------------------------------------------
    -- RGMII RX Clock Buffer (125 MHz from PHY)
    ---------------------------------------------------------------------------
    BUFG_rxc : BUFG
        port map (
            I => rgmii1_rxc,
            O => rgmii_rxc_buf
        );

    ---------------------------------------------------------------------------
    -- Reset Logic
    ---------------------------------------------------------------------------
    reset <= not reset_n;

    ---------------------------------------------------------------------------
    -- PHY Reset Logic (hold for ~100ms at 200MHz)
    ---------------------------------------------------------------------------
--    process(sys_clk_200mhz)
--    begin
--        if rising_edge(sys_clk_200mhz) then
--            if reset = '1' then
--                phy_reset_counter <= (others => '0');
--                phy_reset_done <= '0';
--            elsif phy_reset_done = '0' then
--                if phy_reset_counter = x"FFFFFF" then
--                    phy_reset_done <= '1';
--                else
--                    phy_reset_counter <= phy_reset_counter + 1;
--                end if;
--            end if;
--        end if;
--    end process;

-- Use axi_aclk for PHY reset counter instead
process(axi_aclk)
begin
    if rising_edge(axi_aclk) then
        if axi_aresetn = '0' then
            phy_reset_counter <= (others => '0');
            phy_reset_done <= '0';
        elsif phy_reset_done = '0' then
            if phy_reset_counter = x"FFFFFF" then
                phy_reset_done <= '1';
            else
                phy_reset_counter <= phy_reset_counter + 1;
            end if;
        end if;
    end if;
end process;
    -- PHY reset active LOW
    e1_reset <= phy_reset_done;

    ---------------------------------------------------------------------------
    -- Ethernet TX (drive idle - not used)
    ---------------------------------------------------------------------------
    rgmii1_txc   <= '0';
    rgmii1_txctl <= '0';
    rgmii1_txd   <= (others => '0');

    ---------------------------------------------------------------------------
    -- PCIe System Instance (from Project 22 - proven working)
    ---------------------------------------------------------------------------
    pcie_system_inst : entity work.pcie_system_wrapper
        port map (
            pcie_mgt_rxn      => pcie_mgt_rxn,
            pcie_mgt_rxp      => pcie_mgt_rxp,
            pcie_mgt_txn      => pcie_mgt_txn,
            pcie_mgt_txp      => pcie_mgt_txp,
            pcie_refclk_clk_n => pcie_refclk_clk_n,
            pcie_refclk_clk_p => pcie_refclk_clk_p,
            reset_rtl_0       => pcie_perst_n,
            axi_aclk          => axi_aclk,
            axi_aresetn       => axi_aresetn,
            s_axis_c2h_tdata  => c2h_tdata,
            s_axis_c2h_tkeep  => c2h_tkeep,
            s_axis_c2h_tlast  => c2h_tlast,
            s_axis_c2h_tready => c2h_tready,
            s_axis_c2h_tvalid => c2h_tvalid,
            user_lnk_up       => pcie_link_up
        );

    ---------------------------------------------------------------------------
    -- Test Pattern Generator (exact copy from Project 22 TEST_MODE=2)
    -- This is the KNOWN WORKING pattern
    ---------------------------------------------------------------------------
    process(axi_aclk)
    begin
        if rising_edge(axi_aclk) then
            if axi_aresetn = '0' then
                test_state <= 0;
                test_pkt_cnt <= (others => '0');
                test_timer <= (others => '0');
            else
                test_timer <= test_timer + 1;

                case test_state is
                    when 0 =>  -- IDLE
                        if test_timer = 0 then
                            test_state <= 1;
                        end if;

                    when 1 =>  -- BEAT1
                        if c2h_tready = '1' then
                            test_state <= 2;
                        end if;

                    when 2 =>  -- BEAT2
                        if c2h_tready = '1' then
                            test_state <= 3;
                        end if;

                    when 3 =>  -- BEAT3
                        if c2h_tready = '1' then
                            test_state <= 4;
                        end if;

                    when 4 =>  -- BEAT4
                        if c2h_tready = '1' then
                            test_state <= 5;
                        end if;

                    when 5 =>  -- BEAT5
                        if c2h_tready = '1' then
                            test_state <= 6;
                        end if;

                    when 6 =>  -- BEAT6 (TLAST)
                        if c2h_tready = '1' then
                            test_pkt_cnt <= test_pkt_cnt + 1;
                            test_state <= 0;
                        end if;

                    when others =>
                        test_state <= 0;
                end case;
            end if;
        end if;
    end process;

    -- Combinatorial outputs
    c2h_tvalid <= '1' when (test_state >= 1 and test_state <= 6) else '0';
    c2h_tlast  <= '1' when test_state = 6 else '0';
    c2h_tkeep  <= (others => '1');

    with test_state select c2h_tdata <=
        x"4C50414154534554"                                  when 1,  -- Symbol
        x"00000064" & x"00003A98"                            when 2,  -- BidPrice + BidSize
        x"000000C8" & x"00003AFC"                            when 3,  -- AskPrice + AskSize
        std_logic_vector(test_pkt_cnt) & x"00000064"        when 4,  -- T1 + Spread
        std_logic_vector(test_pkt_cnt) & std_logic_vector(test_pkt_cnt) when 5,  -- T3 + T2
        x"DEADBEEF" & std_logic_vector(test_pkt_cnt)        when 6,  -- Padding + T4
        x"0000000000000000"                                  when others;

    ---------------------------------------------------------------------------
    -- LED Status (active LOW on AX7203)
    ---------------------------------------------------------------------------
    process(axi_aclk)
    begin
        if rising_edge(axi_aclk) then
            heartbeat_counter <= heartbeat_counter + 1;
        end if;
    end process;

    led(0) <= not pcie_link_up;           -- PCIe Link Up
    led(1) <= not phy_reset_done;         -- PHY Reset Complete
    led(2) <= not rgmii_rxc_buf;          -- RGMII RX clock activity (will blink)
    led(3) <= not heartbeat_counter(26);  -- Heartbeat

end Behavioral;
