library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cofb is
    port (clk   : in std_logic;
          reset : in std_logic;

          key   : in std_logic;
          nonce0, nonce1, nonce2 : in std_logic;
          data0, data1, data2    : in std_logic;

          last_block  : in std_logic;
          ad_empty    : in std_logic;
          ad_partial  : in std_logic;
          msg_empty   : in std_logic;
          msg_partial : in std_logic;
          
          ct0, ct1, ct2    : out std_logic;
          tag0, tag1, tag2 : out std_logic);
end entity cofb;

architecture behavioural of cofb is

    signal count : unsigned(12 downto 0);
    signal cycle : std_logic_vector(6 downto 0);
    signal round : std_logic_vector(5 downto 0);
    signal round_i : integer range 0 to 39;
    signal cycle_i : integer range 0 to 127;

    signal round_key      : std_logic;
    signal round_constant : std_logic;

    type state_t is (nonce_st, ad_st, msg_st, ready_st);
    signal state, next_state : state_t;

    signal last  : std_logic;
    signal epoch : std_logic;
    signal era   : std_logic;
    signal mult  : unsigned(2 downto 0);

    signal key_load : std_logic;

    signal state_load : std_logic;
    signal state_out0, state_out1, state_out2 : std_logic;
    
    signal lfsr_load : std_logic;
    signal lfsr_out0, lfsr_out1, lfsr_out2  : std_logic;

    signal x0g, x1g, x2g, y0g, y1g, y2g : std_logic_vector(3 downto 0);
    signal x0f, x1f, x2f, y0f, y1f, y2f : std_logic_vector(3 downto 0);

    signal test : std_logic;
    signal lala0, lala1, lala2, lele : std_logic_vector(127 downto 0);

begin
    
    cycle <= std_logic_vector(count(6 downto 0));
    round <= std_logic_vector(count(12 downto 7));
    round_i <= to_integer(unsigned(round));
    cycle_i <= to_integer(unsigned(cycle));

    last  <= '1' when round_i = 39 and cycle_i = 127 else '0';
    epoch <= '1' when state /= nonce_st and round_i = 0 else '0';
    era   <= '1' when state /= nonce_st and round_i = 1 and cycle_i = 0 else '0';
    
    key_load   <= '1' when round_i = 0  else '0';
    state_load <= '1' when state = nonce_st and round_i = 0 else '0';

    ct0 <= state_out0;
    ct1 <= state_out1;
    ct2 <= state_out2;
    tag0 <= state_out0;
    tag1 <= state_out1;
    tag2 <= state_out2;

    load_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                lfsr_load <= '0';
            elsif state = nonce_st and last = '1' then
                lfsr_load <= '1';
            elsif state = ad_st and cycle_i = 63 then
                lfsr_load <= '0';
            end if;
        end if;
    end process load_reg;

    mult_fsm : process(state, ad_empty, msg_empty, last_block, ad_partial, msg_partial)
    begin
        mult <= "000";
        case state is
            when ad_st =>
                if ad_empty = '1' and msg_empty = '1' then
                    mult <= "101";
                elsif last_block = '1' and ad_partial = '1' and msg_empty = '1' then
                    mult <= "101";
                elsif last_block = '1' and ad_partial = '0' and msg_empty = '1' then
                    mult <= "100";
                elsif last_block = '1' and ad_partial = '1' and msg_empty = '0' then
                    mult <= "011";
                elsif last_block = '1' and ad_partial = '0' and msg_empty = '0' then
                    mult <= "010";
                else
                    mult <= "001";
                end if;
            
            when msg_st =>
                if last_block = '1' and msg_partial = '1' then
                    mult <= "011";
                elsif last_block = '1' and msg_partial = '0' then
                    mult <= "010";
                else
                    mult <= "001";
                end if;

            when others =>
                mult <= "000";
        end case;

    end process mult_fsm;

    state_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= nonce_st;
            else
                state <= next_state;
            end if;
        end if;
    end process state_reg;

    state_fsm : process(state, last, last_block, msg_empty)
    begin
        next_state <= state;
        case state is
            when nonce_st =>
                next_state <= nonce_st;
                if last = '1' then
                    next_state <= ad_st;
                end if;
            
            when ad_st =>
                next_state <= ad_st;
                if last = '1' and last_block = '1' then
                    if msg_empty = '1' then
                        next_state <= ready_st;
                    else
                        next_state <= msg_st;
                    end if;
                end if;
            
            when msg_st =>
                next_state <= msg_st;
                if last = '1' and last_block = '1' then
                        next_state <= ready_st;
                end if;
            
            when ready_st =>
                next_state <= ready_st;

        end case;
    end process state_fsm;

    --sub : entity work.substitution port map (x0, x1, x2, y0, y1, y2);
    subg : entity work.subg port map (x0g, x1g, x2g, y0g, y1g, y2g);
    subf : entity work.subf port map (x0f, x1f, x2f, y0f, y1f, y2f);

    state_pipe0 : entity work.state port map (clk, state_load, nonce0, data0, round_key, round_constant, lfsr_out0, epoch, round, cycle, state_out0, x0g, y0g, x0f, y0f, era, lala0);
    state_pipe1 : entity work.state port map (clk, state_load, nonce1, data1, '0', '0', lfsr_out1, epoch, round, cycle, state_out1, x1g, y1g, x1f, y1f, era, lala1);
    state_pipe2 : entity work.state port map (clk, state_load, nonce2, data2, '0', '0', lfsr_out2, epoch, round, cycle, state_out2, x2g, y2g, x2f, y2f, era, lala2);

    --test <= state_out0 xor state_out1 xor state_out2;
    lele <= lala0 xor lala1 xor lala2;

    key_pipe   : entity work.key port map (clk, key_load, key, epoch, round, cycle, round_key);
    rc_pipe    : entity work.rc port map (clk, reset, epoch, round, cycle, round_constant);
    
    lfsr_pipe0  : entity work.lfsr port map (clk, reset, lfsr_load, state_out0, mult, epoch, round, cycle, lfsr_out0);
    lfsr_pipe1  : entity work.lfsr port map (clk, reset, lfsr_load, state_out1, mult, epoch, round, cycle, lfsr_out1);
    lfsr_pipe2  : entity work.lfsr port map (clk, reset, lfsr_load, state_out2, mult, epoch, round, cycle, lfsr_out2);

    counter : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                count <= (others => '0');
            else
                count <= (count + 1) mod 5120; 
            end if;
        end if;
    end process counter;

end architecture behavioural;
