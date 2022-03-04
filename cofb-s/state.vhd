library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity state is
    port (clk   : in std_logic;
        
          load_en : in std_logic;

          nonce          : in std_logic;
          data           : in std_logic;
          round_key      : in std_logic;
          round_constant : in std_logic;
          round_lfsr     : in std_logic;

          epoch : in std_logic;
          ns    : in std_logic;
	  noswap: in std_logic;
          bc    : in std_logic;
          round : in std_logic_vector(5 downto 0);
          cycle : in std_logic_vector(6 downto 0);

          state_out    : out std_logic;
          ct_out: out std_logic);
end entity state;

architecture behavioural of state is
    signal st_curr, st_next : std_logic_vector(127 downto 0);

    signal sbox0,uv  ,rk,rc,stall, keystream        : std_logic;
    signal sbox_in, sbox_out : std_logic_vector(3 downto 0);

    -- rotate shifts a vector one position to the left
    -- and replaces the least significant bit with 'b'.
    procedure rotate (
        variable st : inout std_logic_vector(127 downto 0);
        variable b  : in std_logic) is
    begin
        st := st(126 downto 0) & b;
    end procedure rotate;

    -- swap switches the value between two input signals.
    -- procedure swap (variable a, b : inout std_logic_vector(7 downto 0)) is
    procedure swap (variable a, b : inout std_logic) is
        variable tmp : std_logic;
    begin
        tmp := a;
        a   := b;
        b   := tmp;
    end procedure swap;
        
    signal round_i : integer range 0 to 42;
    signal cycle_i : integer range 0 to 127;

begin
        
    round_i <= to_integer(unsigned(round));
    cycle_i <= to_integer(unsigned(cycle));

    sbox : entity work.sbox port map (sbox_in, sbox_out);
    stall<='1' when ns='0' and round_i=3 else '0';

    ct_out <= data xor st_curr(127);
        rk<= '0' when ns='0' and (round_i=3 or round_i=2 or round_i=1) else round_key ;
        rc<= '0' when ns='0' and (round_i=3 or round_i=2 or round_i=1) else round_constant  ;   
    fsm : process(clk)
    begin
        if rising_edge(clk) then
            st_curr <= st_next;
        end if;
    end process fsm;
    
    pipe : process(all)
        variable st_tmp : std_logic_vector(127 downto 0);
        variable s0,s1     : std_logic;
        variable t, s, tt  : std_logic;
    begin
        st_tmp := st_curr;


        
     
        t := st_tmp(127) xor rk xor rc;
        tt := t xor  round_lfsr;
        uv<=tt;   
        state_out <= t;
        
        sbox_in <= t & st_curr(31) & st_curr(63) & st_curr(95);
        if load_en = '1' then
            sbox_in <= nonce & st_curr(31) & st_curr(63) & st_curr(95);
        end if;

        -- substitution
        if bc='1' and cycle_i >= 96 then

                st_tmp(95) := sbox_out(0);
                st_tmp(63) := sbox_out(1);
                st_tmp(31) := sbox_out(2);
        end if;

        if load_en = '1' then
            if cycle_i >= 96 then
                s0 := sbox_out(3);
            else
                s0 := nonce;
            end if;
          elsif ns = '0' and round_i=2 then
                s0 := tt;
        
        elsif bc='1' then 
            if cycle_i >= 96 then
                s0 := sbox_out(3);
            else
                s0 := t;
            end if;
        end if;

        -- G+m
        if  bc='0' and epoch ='0' and cycle_i >= 0 and cycle_i < 64 and round_i/=2 then
            s0 := st_tmp(127);
            s1 := data xor st_tmp(63);
            st_tmp(63):=s1;
        elsif bc='0' and epoch ='0' and cycle_i = 64 and round_i/=2 then
            s := st_tmp(63);
            s0 := st_tmp(127);
            st_tmp(63) := s0;
            s0 := s;
            s1 := data xor st_tmp(62);
            st_tmp(62):=s1;
	elsif bc='0' and epoch ='0' and cycle_i > 64 and  round_i/=2 then
            s := data xor st_tmp(62);
            s1:= st_tmp(63);
            s0 := st_tmp(127);
            st_tmp(63) := s0;
            st_tmp(62) := s1;      
            s0 := s;         
	 

        end if;

        if epoch = '1' then
            s0 := t;
        end if;

        -- permutation layer A
        if (bc='1' or (epoch='1'  and cycle_i < 96 )) and noswap='0' and cycle_i mod 8 = 7 then
            swap(st_tmp(96), st_tmp(97));
        end if;
        if (bc='1' or (epoch='1'  and cycle_i < 96)) and ((cycle_i mod 8 = 5) or (cycle_i mod 8 = 7)) and noswap='0' then
            swap(st_tmp(96), st_tmp(99));
        end if;
        if (bc='1' or (epoch='1'  and cycle_i < 96)) and noswap='0' and cycle_i mod 8 = 5 then
            swap(st_tmp(96), st_tmp(98));
        end if;
      
        -- permutation layer X1
        if (cycle_i = 0 or cycle_i = 1 or cycle_i = 42 or cycle_i = 43 or cycle_i = 50 or
           cycle_i = 51 or cycle_i = 58 or cycle_i = 59 or cycle_i = 66 or cycle_i = 67 or
           cycle_i = 104 or cycle_i = 105 or cycle_i = 112 or cycle_i = 113 or cycle_i = 120 or
           cycle_i = 121) and (bc='1' or (epoch='1' and cycle_i < 104 )) and noswap='0' then
            swap(st_tmp(99), st_tmp(103));
        end if;
        if (cycle_i = 6 or cycle_i = 7 or cycle_i = 10 or cycle_i = 11 or cycle_i = 14 or
           cycle_i = 15 or cycle_i = 18 or cycle_i = 19 or cycle_i = 22 or cycle_i = 23 or
           cycle_i = 26 or cycle_i = 27 or cycle_i = 30 or cycle_i = 31 or cycle_i = 34 or
           cycle_i = 35 or cycle_i = 72 or cycle_i = 73 or cycle_i = 80 or cycle_i = 81 or
           cycle_i = 88 or cycle_i = 89 or  ((cycle_i = 96 or cycle_i = 97) and (stall = '0'))) and (bc='1' or (epoch='1'  )) and noswap='0'  then
            swap(st_tmp(99), st_tmp(101));
        end if;
        if (cycle_i = 74 or cycle_i = 75 or cycle_i = 82 or cycle_i = 83 or cycle_i = 90 or
           cycle_i = 91 or ((cycle_i = 98 or cycle_i = 99) and (stall = '0')) ) and (bc='1' or (epoch='1'   )) and noswap='0' then
            swap(st_tmp(99), st_tmp(105));
        end if;

        -- permutation layer X2
        if (cycle_i = 2 or cycle_i = 3 or cycle_i = 34 or cycle_i = 35 or cycle_i = 66 or
           cycle_i = 67 or ((cycle_i = 98 or cycle_i = 99) and (stall = '0'))) and (bc='1' or (epoch='1'  )) and noswap='0' then
            swap(st_tmp(105), st_tmp(123));
        end if;
        if (cycle_i = 4 or cycle_i = 5 or cycle_i = 26 or cycle_i = 27 or cycle_i = 36 or
           cycle_i = 37 or cycle_i = 58 or cycle_i = 59 or cycle_i = 68 or cycle_i = 69 or
           cycle_i = 90 or cycle_i = 91 or ((cycle_i = 100 or cycle_i = 101) and (stall = '0')) or cycle_i = 122 or
           cycle_i = 123 ) and (bc='1' or (epoch='1' and   cycle_i < 122 )) and noswap='0' then
            swap(st_tmp(105), st_tmp(117));
        end if;
        if (cycle_i = 6 or cycle_i = 7 or cycle_i = 18 or cycle_i = 19 or cycle_i = 28 or
           cycle_i = 29 or cycle_i = 38 or cycle_i = 39 or cycle_i = 50 or cycle_i = 51 or
           cycle_i = 60 or cycle_i = 61 or cycle_i = 70 or cycle_i = 71 or cycle_i = 82 or
           cycle_i = 83 or cycle_i = 92 or cycle_i = 93 or ((cycle_i = 102 or cycle_i = 103) and (stall = '0')) or
           cycle_i = 114 or cycle_i = 115 or cycle_i = 124 or cycle_i = 125) and (bc='1' or (epoch='1'  and cycle_i<114 )) and noswap='0'  then
            swap(st_tmp(105), st_tmp(111));
        end if;
       
       
        rotate(st_tmp, s0);

        st_next <= st_tmp;

    end process pipe;

end architecture behavioural;
