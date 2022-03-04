library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rc is
    port (clk   : in std_logic;
          reset : in std_logic;
   
          epoch : in std_logic;
          ns 	: in std_logic;
          round : in std_logic_vector(5 downto 0);
          cycle : in std_logic_vector(6 downto 0);
              
          rc_out : out std_logic);
end entity rc;

architecture behavioural of rc is

    signal st_curr, st_next : std_logic_vector(5 downto 0);
    signal trail : std_logic;

    procedure rotate (
        variable st : inout std_logic_vector(5 downto 0);
        variable b  : in std_logic) is
    begin
        st := st(4 downto 0) & b;
    end procedure rotate;

begin

    fsm : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                st_curr <= "000000";
            else
                st_curr <= st_next;
            end if;
        end if;
    end process fsm;

    pipe : process(all)
        variable st_tmp : std_logic_vector(5 downto 0);
        variable s0     : std_logic;
        
        variable round_i : integer range 0 to 42;
        variable cycle_i : integer range 0 to 127;
    begin
        st_tmp := st_curr;

        round_i := to_integer(unsigned(round));
        cycle_i := to_integer(unsigned(cycle));

        rc_out <= '0';
        s0 := '0';

        if round_i > 0 or epoch = '1' then
            if round_i = 4 and cycle_i = 0 and ns ='0' then
                st_tmp := "000000";
            elsif cycle_i = 96 then
                s0 := st_tmp(5) xnor st_tmp(4);
                rotate(st_tmp, s0);
                rc_out <= '1';
            elsif cycle_i >= 122 and cycle_i < 128 then
                s0 := st_tmp(5);
                rc_out <= s0;
                rotate(st_tmp, s0);
            end if;
        end if;

        st_next <= st_tmp;

    end process pipe;

end architecture behavioural;
