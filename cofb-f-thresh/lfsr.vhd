library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lfsr is
    port (clk     : in std_logic;
          reset   : in std_logic;
         
          load_en : in std_logic;
          lfsr_in : in std_logic;
          mult    :  in unsigned(2 downto 0);
          
          epoch : in std_logic;
          round : in std_logic_vector(5 downto 0);
          cycle : in std_logic_vector(6 downto 0);

          lfsr_out : out std_logic);
end entity lfsr;

architecture behavioural of lfsr is
    
    signal st_curr, st_next : std_logic_vector(63 downto 0);
    
    procedure rotate (
        variable st : inout std_logic_vector(63 downto 0);
        variable b  : in std_logic) is
    begin
        st := st(62 downto 0) & b;
    end procedure rotate;

    type coeffs is array(0 to 4) of std_logic;
    constant poly : coeffs := ('1', '1', '0', '1', '1');

    signal count : unsigned(2 downto 0);
    signal round_i : integer range 0 to 39;
    signal cycle_i : integer range 0 to 127;

    signal msb : std_logic_vector(0 to 1);
    signal msb0 : std_logic_vector(0 to 1);

begin
        
    round_i <= to_integer(unsigned(round));
    cycle_i <= to_integer(unsigned(cycle));

    fsm : process(clk)
    begin
        if rising_edge(clk) then
            st_curr <= st_next;
        end if;
    end process fsm;

    counter : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                count <= (others => '0');
            elsif round_i = 0 and cycle_i = 0 then
                if mult > 3 then
                    count <= mult-2;
                else
                    count <= mult;
                end if;
            end if;
        end if;
    end process;

    msb_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                msb  <= (others => '0');
                msb0 <= (others => '0');
            elsif round_i = 0 and cycle_i >= 0 and cycle_i < 2 then
                if load_en = '1' then
                    msb <= msb(1) & lfsr_in;
                elsif epoch = '1' then
                    msb <= msb(1) & st_curr(63);
                end if;
            elsif round_i = 0 and cycle_i >= 64 and cycle_i < 66 then
                if epoch = '1' then
                    msb0 <= msb0(1) & st_curr(63);
                end if;
            end if;
        end if;
    end process;

    pipe : process(st_curr, round_i, cycle_i, load_en, mult, lfsr_in, msb, msb0, count)
        variable st_tmp : std_logic_vector(63 downto 0);
        variable s0     : std_logic;
        
        variable round_i : integer range 0 to 39;
        variable cycle_i : integer range 0 to 127;
    begin
        st_tmp := st_curr;

        round_i := to_integer(unsigned(round));
        cycle_i := to_integer(unsigned(cycle));

        s0 := st_curr(63);
        if load_en = '1' then
            s0 := lfsr_in;
        end if;

        if round_i = 0 and mult >= 3 then
            if cycle_i >= 2 and cycle_i < 64 then
                st_tmp(1) := st_tmp(1) xor s0;
            end if;

            if cycle_i = 60 then
                st_tmp(1) := st_tmp(1) xor (msb(0) and poly(0));
            elsif cycle_i = 61 then
                st_tmp(1) := st_tmp(1) xor (msb(0) and poly(1)) xor (msb(1) and poly(0));
            elsif cycle_i = 62 then
                st_tmp(1) := st_tmp(1) xor (msb(0) and poly(2)) xor (msb(1) and poly(1));
            elsif cycle_i = 63 then
                st_tmp(1) := st_tmp(1) xor (msb(0) and poly(3)) xor (msb(1) and poly(2));
            elsif cycle_i = 64 then
                st_tmp(1) := st_tmp(1) xor (msb(0) and poly(4)) xor (msb(1) and poly(3));
            elsif cycle_i = 65 then
                st_tmp(1) := st_tmp(1) xor (msb(1) and poly(4));
            end if;
        end if;

        if round_i = 0 and cycle_i >= 64 then
            if count = 1 and cycle_i < 128 then
                if cycle_i = 127 then
                    s0 := '0';
                else
                    s0 := s0 xor s0 xor st_tmp(62);
                end if;
            elsif count = 2 and cycle_i < 127 then
                s0 := s0 xor st_tmp(62);
            elsif count = 3 and cycle_i < 126 then
                s0 := s0 xor st_tmp(61);
            end if;

            if count = 1 or count = 2 then
                if cycle_i >= 123 then
                    s0 := s0 xor (msb0(0) and poly(cycle_i-123));
                end if;
            elsif count = 3 then
                if cycle_i = 122 then
                    s0 := s0 xor (msb0(0) and poly(0));
                elsif cycle_i = 123 then
                    s0 := s0 xor (msb0(0) and poly(1)) xor (msb0(1) and poly(0));
                elsif cycle_i = 124 then
                    s0 := s0 xor (msb0(0) and poly(2)) xor (msb0(1) and poly(1));
                elsif cycle_i = 125 then
                    s0 := s0 xor (msb0(0) and poly(3)) xor (msb0(1) and poly(2));
                elsif cycle_i = 126 then
                    s0 := s0 xor (msb0(0) and poly(4)) xor (msb0(1) and poly(3));
                elsif cycle_i = 127 then
                    s0 := s0 xor (msb0(1) and poly(4));
                end if;
            end if;
        end if;

        if cycle_i >= 64 then
            lfsr_out <= s0;
        else
            lfsr_out <= '0';
        end if;

        rotate(st_tmp, s0);

        st_next <= st_tmp;

    end process pipe;

end architecture behavioural;
