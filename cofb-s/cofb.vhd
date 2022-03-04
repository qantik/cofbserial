library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cofb is
    port (clk   : in std_logic;
          reset : in std_logic;

          key   : in std_logic;
          nonce : in std_logic;
          data  : in std_logic;

          last_block  : in std_logic;
          ad_empty    : in std_logic;
          ad_partial  : in std_logic;
          msg_empty   : in std_logic;
          msg_partial : in std_logic;
          
          ct    	: out std_logic;
          ct_ready	: out std_logic;
          tag   	: out std_logic;
          tag_ready	: out std_logic);
end entity cofb;

architecture behavioural of cofb is

    signal count , count_n: unsigned(12 downto 0);
    signal cycle : std_logic_vector(6 downto 0);
    signal round : std_logic_vector(5 downto 0);
    signal round_i : integer range 0 to 42;
    signal cycle_i : integer range 0 to 127;

    signal round_key      : std_logic;
    signal round_constant : std_logic;

    type state_t is (nonce_st, ad_st, msg_st, ready_st);
    signal state, next_state : state_t;

    signal last  : std_logic;
    signal epoch,ns,bc,noswap : std_logic;
    signal mult  : unsigned(2 downto 0);

    signal key_load : std_logic;

    signal state_load : std_logic;
    signal state_out,ct_out : std_logic;
    
    signal lfsr_load : std_logic;
    signal lfsr_out  : std_logic;

begin
    
    cycle <= std_logic_vector(count(6 downto 0));
    round <= std_logic_vector(count(12 downto 7));
    round_i <= to_integer(unsigned(round));
    cycle_i <= to_integer(unsigned(cycle));

    last  <= '1' when (round_i = 39 and cycle_i = 127 and state=nonce_st) or (round_i = 42 and cycle_i = 127 and state/=nonce_st) else '0';
    epoch <= '1' when state /= nonce_st and round_i = 0 else '0';
    ns <= '1' when state  = nonce_st  else '0';   
    
    
    key_load   <= '1' when (round_i = 0 and state=nonce_st) or (round_i = 3 and state/=nonce_st ) else '0';
    state_load <= '1' when state = nonce_st and round_i = 0 else '0';

    bc <= '1' when state = nonce_st or round_i>2 else '0';
    noswap <= '1' when (round_i = 2 or (round_i=3 and cycle_i<96)) and state/=nonce_st else '0';
    ct <= ct_out;
    tag <= state_out;
   
    ct_ready  <= '1'  when round_i = 1 and ( state = msg_st ) else '0';

    tag_ready <= '1' when state=ready_st else '0'; --count >= 5248 and ( ( state = ad_st and (last_block='1' or ad_empty='1') and msg_empty='1') or
                                               -- ( state = msg_st and (last_block='1')  )                 )    else '0';

    load_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                lfsr_load <= '0';
            elsif state = nonce_st and last = '1' then
                lfsr_load <= '1';
            elsif state = ad_st and cycle_i = 63 then
                lfsr_load <= '0';
            end if;
        end if;
    end process load_reg;
	--000 - no multiplication
	--001 - 2x
	--010 - 3x
	--011 - 3^2x
	--100 - 3^3x
	--101 - 3^4x
    mult_fsm : process(all)
    begin
        mult <= "000";
        case state is
            when ad_st =>
                if ad_empty = '1' and msg_empty = '1' then
                    mult <= "101";
                elsif ad_empty = '1' and msg_empty = '0' then
		    mult <= "011";
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
            if reset = '0' then
                state <= nonce_st;
            else
                state <= next_state;
            end if;
        end if;
    end process state_reg;

    state_fsm : process(all)
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

    state_pipe : entity work.state port map (clk, state_load, nonce, data, round_key, round_constant, lfsr_out, epoch,ns,noswap,bc, round, cycle, state_out,ct_out);
    key_pipe   : entity work.key port map (clk, key_load, key, ns, round, cycle, round_key);
    rc_pipe    : entity work.rc port map (clk, reset, epoch, ns, round, cycle, round_constant);
    lfsr_pipe  : entity work.lfsr port map (clk, reset, lfsr_load, state_out, mult, epoch, round, cycle, lfsr_out);


    m: process(all)
    begin 
      
      if state = nonce_st and count = 5119 then 
            count_n <= (others => '0');
      else
	    count_n <= (count + 1) mod 5504; 
      end if;    
    end process m;

    counter : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                count <= (others => '0');
            else
                count <= count_n; 
            end if;
        end if;
    end process counter;

end architecture behavioural;
