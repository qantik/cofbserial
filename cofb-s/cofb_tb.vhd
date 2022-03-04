library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use ieee.std_logic_textio.all;

entity cofb_tb is
end entity cofb_tb;

architecture bench of cofb_tb is
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';

    signal key_in   : std_logic;
    signal nonce_in : std_logic;
    signal data_in  : std_logic;
    
    signal ready : std_logic;
    signal tag   : std_logic;
    signal ct    : std_logic;
    
    signal last_block  : std_logic;
    signal ad_empty    : std_logic;
    signal ad_partial  : std_logic;
    signal msg_empty   : std_logic;
    signal msg_partial : std_logic;

    signal cmp   : std_logic_vector(127 downto 0);
        
    constant clk_period   : time := 100 ns;
    constant reset_period : time := 25 ns;

begin

    cofb : entity work.cofb port map (clk, reset, key_in, nonce_in, data_in, last_block, ad_empty, ad_partial, msg_empty, msg_partial, ct, tag);

    clock : process
    begin
        clk <= '1';
        wait for clk_period/2;
        clk <= '0';
        wait for clk_period/2;
    end process clock;

    test : process
        file vec_file : text;
        file out_file : text;
        
        variable vec_line  : line;
        variable vec_space : character;

        -- header
        variable vec_id      : integer;
        variable vec_adlen   : integer;
        variable vec_msglen  : integer;
        variable vec_adpart  : std_logic;
        variable vec_msgpart : std_logic;

        -- data
        variable vec_key   : std_logic_vector(127 downto 0);
        variable vec_nonce : std_logic_vector(127 downto 0);
        variable vec_ad    : std_logic_vector(127 downto 0);
        variable vec_msg   : std_logic_vector(127 downto 0);
        variable vec_tag   : std_logic_vector(127 downto 0);
    begin
        file_open(vec_file, "./cofb-f/vectors_nodata.txt", read_mode);
        file_open(out_file, "./cofb-f/out.txt", write_mode);

        while not endfile(vec_file) loop
            -- parse vector header
            readline(vec_file, vec_line);
            read(vec_line, vec_id); read(vec_line, vec_space);
            read(vec_line, vec_adlen); read(vec_line, vec_space);
            read(vec_line, vec_adpart); read(vec_line, vec_space);
            read(vec_line, vec_msglen); read(vec_line, vec_space);
            read(vec_line, vec_msgpart);
	        
            readline(vec_file, vec_line);
            hread(vec_line, vec_key);
            readline(vec_file, vec_line);
            hread(vec_line, vec_nonce);
            
            data_in <= '0';
            
            if vec_adlen < 1 then ad_empty <= '1'; else ad_empty <= '0'; end if;
            if vec_msglen < 1 then msg_empty <= '1'; else msg_empty <= '0'; end if;
            ad_partial  <= vec_adpart;
            msg_partial <= vec_msgpart;
            last_block  <= '0';

            -- bitslice reorder key
            vec_key := vec_key(127 downto 96) & vec_key(31 downto 0) & vec_key(95 downto 64) & vec_key(63 downto 32);
        
            wait for clk_period/2;
            reset <= '1';
            wait for clk_period;
            reset <= '0';

            for i in 0 to 127 loop
                key_in <= vec_key(127-i);
                nonce_in  <= vec_nonce(127-i);
                wait for clk_period;
            end loop;
            
            wait for 4992*clk_period;

            for i in 0 to vec_adlen-2 loop
                readline(vec_file, vec_line);
                hread(vec_line, vec_ad);
                vec_ad := vec_ad(0) & vec_ad(63 downto 1) & vec_ad(127 downto 64);
                
                for j in 0 to 127 loop
                    key_in <= vec_key(127-j);
                    data_in <= vec_ad(127-j);
                    wait for clk_period;
                end loop;
            
                wait for 4992*clk_period;
            end loop;
           
            -- last ad block
            readline(vec_file, vec_line);
            hread(vec_line, vec_ad);
            vec_ad := vec_ad(0) & vec_ad(63 downto 1) & vec_ad(127 downto 64);
            last_block <= '1';
            for i in 0 to 127 loop
                key_in <= vec_key(127-i);
                data_in <= vec_ad(127-i);
                wait for clk_period;
            end loop;
            wait for 4992*clk_period;
            last_block <= '0';
           
            -- msg
            for i in 0 to vec_msglen-1 loop
                readline(vec_file, vec_line);
                hread(vec_line, vec_msg);
               
                if i = vec_msglen-1 then last_block <= '1'; end if;
                for j in 0 to 127 loop
                    key_in <= vec_key(127-j);
                    data_in <= vec_msg(127-j);
                    wait for clk_period;
                end loop;
                last_block <= '0';
            
                wait for 4992*clk_period;
            end loop;
          
            -- verify tag
            readline(vec_file, vec_line);
            hread(vec_line, vec_tag);
            for i in 0 to 127 loop
                cmp(127-i) <= tag;
                assert tag = vec_tag(127-i) report "incorrect tag"  severity failure;
                if i = 127 then wait for clk_period/2; else wait for clk_period; end if;
            end loop;
        
            hwrite(vec_line, cmp);
            writeline(out_file, vec_line);
   
        end loop;

        assert false report "test finished" severity failure;

    end process test;

end architecture bench;
    
