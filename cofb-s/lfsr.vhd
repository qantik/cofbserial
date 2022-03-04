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

    signal a,b,c,up,trip,nop: std_logic;
    signal aux,aux_n: std_logic;
    
    signal count : unsigned(2 downto 0);
    signal round_i : integer range 0 to 42;
    signal cycle_i : integer range 0 to 127;
    signal cycle_h : integer range 0 to 63;

    signal msb : std_logic_vector(0 to 1);
    signal msb0 : std_logic_vector(0 to 1);

begin
        
    round_i <= to_integer(unsigned(round));
    cycle_i <= to_integer(unsigned(cycle));
    cycle_h <= to_integer(unsigned(cycle(5 downto 0) ));

    fsm : process(clk)
    begin
        if rising_edge(clk) then
            st_curr <= st_next;
        end if;
    end process fsm;

    ax : process(clk)
    begin
        if rising_edge(clk) then
            aux <= aux_n;
        end if;
    end process ax;
  
    axp : process(all)
    begin
        if cycle_h=0 then
            aux_n <= st_curr(63);
        else
            aux_n<=aux;
        end if;
    end process axp;
    

    abc : process(all)
    begin
        if nop='1' then 
        	b<='1'; 
        	a<='0';
        	c<='0';
        else 
        	if trip='1'  then
                    b<='1';
                else
                    b<='0';
                end if;

                if cycle_h=63  then
                    c<='0';
                else
                    c<='1';
                end if;

 		if  cycle_h=63 or cycle_h=62 or cycle_h=60 or cycle_h=59 then
                    a<='1';
                else
                    a<='0';
                end if;
                
        end if;
    end process abc;
	--000 - no multiplication
	--001 - 2x
	--010 - 3x
	--011 - 3^2x
	--100 - 3^3x
	--101 - 3^4x

    nt : process(all)
    begin
    nop<='1'; trip<='0';
      

    if round_i=0 and cycle_i<64 then
    nop<='1'; trip<='0';
    elsif round_i=0 and cycle_i>=64 then
        
                      if mult >1 then 
                         trip<='1'; 
                         nop<='0';
                      else
                        trip<='0';
                        nop<='0';
                      end if;

    elsif round_i=1 and cycle_i<64 then
        
                      if mult >2 then 
                         trip<='1'; 
                         nop<='0';
                      else
                        trip<='0';
                        nop<='1';
                      end if;
   elsif round_i=1 and cycle_i>=64 then
        
                      if mult >3 then 
                         trip<='1'; 
                         nop<='0';
                      else
                        trip<='0';
                        nop<='1';
                      end if;
  elsif round_i=2 and cycle_i<64 then
        
                      if mult >4 then 
                         trip<='1'; 
                         nop<='0';
                      else
                        trip<='0';
                        nop<='1';
                      end if;
  end if;
    end process nt;








   up <= (a and aux) xor (b and st_curr(63)) xor (c and st_curr(62));
  

    pipe : process(all)
        variable st_tmp : std_logic_vector(63 downto 0);
        variable s0,s1     : std_logic;
        
        variable round_i : integer range 0 to 42;
        variable cycle_i : integer range 0 to 127;
    begin
        st_tmp := st_curr;

        round_i := to_integer(unsigned(round));
        cycle_i := to_integer(unsigned(cycle));

        s1 := st_curr(63);
        if load_en = '1' then
            s0 := lfsr_in;
        else
            s0 := up;   
        end if;
 
        if cycle_i < 64 then
            lfsr_out <= up;
        else
            lfsr_out <= '0';
        end if;

        rotate(st_tmp, s0);

        st_next <= st_tmp;

    end process pipe;

end architecture behavioural;
