library ieee;
use ieee.std_logic_1164.all;

entity subg is
    port (x1, x2, x3 : in  std_logic_vector(3 downto 0);
          y1, y2, y3 : out std_logic_vector(3 downto 0));
end subg;

architecture parallel of subg is
    signal g1in0, g1in1, g1out : std_logic_vector(3 downto 0);
    signal g2in0, g2in1, g2out : std_logic_vector(3 downto 0);
    signal g3in0, g3in1, g3out : std_logic_vector(3 downto 0);
begin

   g1in0 <= x2;
   g1in1 <= x3;

   g2in0 <= x1;
   g2in1 <= x3;
   
   g3in0 <= x1;
   g3in1 <= x2;

   gl1 : entity work.gbox1 port map (g1in0, g1in1, g1out);
   gl2 : entity work.gbox2 port map (g2in0, g2in1, g2out);
   gl3 : entity work.gbox3 port map (g3in0, g3in1, g3out);

   y1 <= g1out;
   y2 <= g2out;
   y3 <= g3out;

end parallel;

