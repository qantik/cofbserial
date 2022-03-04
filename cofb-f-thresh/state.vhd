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
          
          round : in std_logic_vector(5 downto 0);
          cycle : in std_logic_vector(6 downto 0);

          ct    : out std_logic;
          sbox_ing : out std_logic_vector(3 downto 0);
          sbox_outg : in std_logic_vector(3 downto 0);
          sbox_inf : out std_logic_vector(3 downto 0);
          sbox_outf : in std_logic_vector(3 downto 0);
          era : in std_logic;
          lala : out std_logic_vector(127 downto 0));
end entity state;

architecture behavioural of state is
    signal st_curr, st_next : std_logic_vector(127 downto 0);

    signal sbox0             : std_logic;
    --signal sbox_in, sbox_out : std_logic_vector(3 downto 0);

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
        
    signal round_i : integer range 0 to 39;
    signal cycle_i : integer range 0 to 127;

begin

    lala <= st_curr;
        
    cycle_i <= to_integer(unsigned(cycle));

    --sbox_in <= sbox0 & st_curr(31) & st_curr(63) & st_curr(95);
    --sbox : entity work.sbox port map (sbox_in, sbox_out);

    fsm : process(clk)
    begin
        if rising_edge(clk) then
            st_curr <= st_next;
        end if;
    end process fsm;
    
    pipe : process(st_curr, cycle_i, round_key, round_constant, data, round_lfsr, load_en, epoch, sbox_outg, sbox_outf, nonce)
    --pipe : process(all)
        variable st_tmp : std_logic_vector(127 downto 0);
        variable s0     : std_logic;
        variable t, s, tt  : std_logic;
    begin
        st_tmp := st_curr;

        t := st_tmp(127) xor round_key xor round_constant;
        tt := t xor data xor round_lfsr;
           
        ct <= t;
        
        sbox_ing <= t & st_curr(31) & st_curr(63) & st_curr(95);
        sbox_inf <= st_curr(0) & st_curr(32) & st_curr(64) & st_curr(96);
        if load_en = '1' then
            sbox_ing <= nonce & st_curr(31) & st_curr(63) & st_curr(95);
        elsif epoch = '1' then
            --sbox_in <= st_curr(63) & st_curr(31) & t & st_curr(95);
            sbox_ing <= st_curr(63) & st_curr(31) & tt & st_curr(95);
            --sbox_inf <= st_curr(64) & st_curr(32) & st_curr(0) & st_curr(96);
        end if;

        -- substitution
        if cycle_i >= 96 then
            if epoch = '1' then
                st_tmp(95) := sbox_outg(0);
                st_tmp(63) := sbox_outg(3);
                st_tmp(31) := sbox_outg(2);
            else
                st_tmp(95) := sbox_outg(0);
                st_tmp(63) := sbox_outg(1);
                st_tmp(31) := sbox_outg(2);
            end if;
        end if;
        
        if cycle_i >= 97 or cycle_i = 0 then
            if epoch = '1' and cycle_i /= 0 then
                st_tmp(96) := sbox_outf(0);
                --st_tmp(64) := sbox_outf(3);
                st_tmp(64) := sbox_outf(1);
                st_tmp(32) := sbox_outf(2);
                st_tmp(0) := sbox_outf(3);
                --st_tmp(0) := sbox_outf(1);
            else
                st_tmp(96) := sbox_outf(0);
                st_tmp(64) := sbox_outf(1);
                st_tmp(32) := sbox_outf(2);
                st_tmp(0) := sbox_outf(3);
            end if;
        end if;

        if load_en = '1' then
            if cycle_i >= 96 then
                s0 := sbox_outg(3);
            else
                s0 := nonce;
            end if;
        elsif epoch = '1' then
            if cycle_i >= 96 then
                s0 := sbox_outg(1);
            else
                s0 := tt;
            end if;
        else
            if cycle_i >= 96 then
                s0 := sbox_outg(3);
            else
                s0 := t;
            end if;
        end if;

        -- G
        if epoch = '1' and cycle_i >= 1 and cycle_i < 64 then
            s := st_tmp(0);
            st_tmp(0) := s0;
            s0 := s;
        elsif epoch = '1' and cycle_i >= 64 then
            s := st_tmp(63);
            st_tmp(63) := s0;
            s0 := s;
        end if;

        -- permutation layer A
        if cycle_i mod 8 = 7 then
            swap(st_tmp(96), st_tmp(97));
        end if;
        if (cycle_i mod 8 = 5) or (cycle_i mod 8 = 7) then
            swap(st_tmp(96), st_tmp(99));
        end if;
        if cycle_i mod 8 = 5 then
            swap(st_tmp(96), st_tmp(98));
        end if;
        --if cycle_i mod 8 = 0 then
        --    swap(st_tmp(97), st_tmp(98));
        --end if;
        --if (cycle_i mod 8 = 6) or (cycle_i mod 8 = 0) then
        --    swap(st_tmp(97), st_tmp(100));
        --end if;
        --if cycle_i mod 8 = 6 then
        --    swap(st_tmp(97), st_tmp(99));
        --end if;

        -- permutation layer X1
        if cycle_i = 0 or cycle_i = 1 or cycle_i = 42 or cycle_i = 43 or cycle_i = 50 or
           cycle_i = 51 or cycle_i = 58 or cycle_i = 59 or cycle_i = 66 or cycle_i = 67 or
           cycle_i = 104 or cycle_i = 105 or cycle_i = 112 or cycle_i = 113 or cycle_i = 120 or
           cycle_i = 121 then
            swap(st_tmp(99), st_tmp(103));
        end if;
        if cycle_i = 6 or cycle_i = 7 or cycle_i = 10 or cycle_i = 11 or cycle_i = 14 or
           cycle_i = 15 or cycle_i = 18 or cycle_i = 19 or cycle_i = 22 or cycle_i = 23 or
           cycle_i = 26 or cycle_i = 27 or cycle_i = 30 or cycle_i = 31 or cycle_i = 34 or
           cycle_i = 35 or cycle_i = 72 or cycle_i = 73 or cycle_i = 80 or cycle_i = 81 or
           cycle_i = 88 or cycle_i = 89 or cycle_i = 96 or cycle_i = 97 then
            swap(st_tmp(99), st_tmp(101));
        end if;
        if cycle_i = 74 or cycle_i = 75 or cycle_i = 82 or cycle_i = 83 or cycle_i = 90 or
           cycle_i = 91 or cycle_i = 98 or cycle_i = 99 then
            swap(st_tmp(99), st_tmp(105));
        end if;

        -- permutation layer X2
        if cycle_i = 2 or cycle_i = 3 or cycle_i = 34 or cycle_i = 35 or cycle_i = 66 or
           cycle_i = 67 or cycle_i = 98 or cycle_i = 99 then
            swap(st_tmp(105), st_tmp(123));
        end if;
        if cycle_i = 4 or cycle_i = 5 or cycle_i = 26 or cycle_i = 27 or cycle_i = 36 or
           cycle_i = 37 or cycle_i = 58 or cycle_i = 59 or cycle_i = 68 or cycle_i = 69 or
           cycle_i = 90 or cycle_i = 91 or cycle_i = 100 or cycle_i = 101 or cycle_i = 122 or
           cycle_i = 123 then
            swap(st_tmp(105), st_tmp(117));
        end if;
        if cycle_i = 6 or cycle_i = 7 or cycle_i = 18 or cycle_i = 19 or cycle_i = 28 or
           cycle_i = 29 or cycle_i = 38 or cycle_i = 39 or cycle_i = 50 or cycle_i = 51 or
           cycle_i = 60 or cycle_i = 61 or cycle_i = 70 or cycle_i = 71 or cycle_i = 82 or
           cycle_i = 83 or cycle_i = 92 or cycle_i = 93 or cycle_i = 102 or cycle_i = 103 or
           cycle_i = 114 or cycle_i = 115 or cycle_i = 124 or cycle_i = 125 then
            swap(st_tmp(105), st_tmp(111));
        end if;
        --if cycle_i = 1 or cycle_i = 2 or cycle_i = 43 or cycle_i = 44 or cycle_i = 51 or
        --   cycle_i = 52 or cycle_i = 59 or cycle_i = 60 or cycle_i = 67 or cycle_i = 68 or
        --   cycle_i = 105 or cycle_i = 106 or cycle_i = 113 or cycle_i = 114 or cycle_i = 121 or
        --   cycle_i = 122 then
        --    swap(st_tmp(100), st_tmp(104));
        --end if;
        --if cycle_i = 7 or cycle_i = 8 or cycle_i = 11 or cycle_i = 12 or cycle_i = 15 or
        --   cycle_i = 16 or cycle_i = 19 or cycle_i = 20 or cycle_i = 23 or cycle_i = 24 or
        --   cycle_i = 27 or cycle_i = 28 or cycle_i = 31 or cycle_i = 32 or cycle_i = 35 or
        --   cycle_i = 36 or cycle_i = 73 or cycle_i = 74 or cycle_i = 81 or cycle_i = 82 or
        --   cycle_i = 89 or cycle_i = 90 or cycle_i = 97 or cycle_i = 98 then
        --    swap(st_tmp(100), st_tmp(102));
        --end if;
        --if cycle_i = 75 or cycle_i = 76 or cycle_i = 83 or cycle_i = 84 or cycle_i = 91 or
        --   cycle_i = 92 or cycle_i = 99 or cycle_i = 100 then
        --    swap(st_tmp(100), st_tmp(106));
        --end if;

        ---- permutation layer X2
        --if cycle_i = 3 or cycle_i = 4 or cycle_i = 35 or cycle_i = 36 or cycle_i = 67 or
        --   cycle_i = 68 or cycle_i = 99 or cycle_i = 100 then
        --    swap(st_tmp(106), st_tmp(124));
        --end if;
        --if cycle_i = 5 or cycle_i = 6 or cycle_i = 27 or cycle_i = 28 or cycle_i = 37 or
        --   cycle_i = 38 or cycle_i = 59 or cycle_i = 60 or cycle_i = 69 or cycle_i = 70 or
        --   cycle_i = 91 or cycle_i = 92 or cycle_i = 101 or cycle_i = 102 or cycle_i = 123 or
        --   cycle_i = 124 then
        --    swap(st_tmp(106), st_tmp(118));
        --end if;
        --if cycle_i = 7 or cycle_i = 8 or cycle_i = 19 or cycle_i = 20 or cycle_i = 29 or
        --   cycle_i = 30 or cycle_i = 39 or cycle_i = 40 or cycle_i = 51 or cycle_i = 52 or
        --   cycle_i = 61 or cycle_i = 62 or cycle_i = 71 or cycle_i = 72 or cycle_i = 83 or
        --   cycle_i = 84 or cycle_i = 93 or cycle_i = 94 or cycle_i = 103 or cycle_i = 104 or
        --   cycle_i = 115 or cycle_i = 116 or cycle_i = 125 or cycle_i = 126 then
        --    swap(st_tmp(106), st_tmp(112));
        --end if;
       
        rotate(st_tmp, s0);

        st_next <= st_tmp;

    end process pipe;

end architecture behavioural;