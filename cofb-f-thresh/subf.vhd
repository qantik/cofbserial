library ieee;
use ieee.std_logic_1164.all;

entity subf is
    port (x1, x2, x3 : in  std_logic_vector(3 downto 0);
          y1, y2, y3 : out std_logic_vector(3 downto 0));
end subf;

architecture parallel of subf is
    signal f1in0, f1in1, f1out : std_logic_vector(3 downto 0);
    signal f2in0, f2in1, f2out : std_logic_vector(3 downto 0);
    signal f3in0, f3in1, f3out : std_logic_vector(3 downto 0);
begin

   f1in0 <= x2;
   f1in1 <= x3;

   f2in0 <= x1;
   f2in1 <= x3;
   
   f3in0 <= x1;
   f3in1 <= x2;

   fl1 : entity work.fbox1 port map(f1in0, f1in1, f1out);
   fl2 : entity work.fbox2 port map(f2in0, f2in1, f2out);
   fl3 : entity work.fbox3 port map(f3in0, f3in1, f3out);

   y1 <= f1out;
   y2 <= f2out;
   y3 <= f3out;

end parallel;


