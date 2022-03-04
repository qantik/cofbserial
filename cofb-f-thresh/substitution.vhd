library ieee;
use ieee.std_logic_1164.all;

entity substitution is
    port (x1, x2, x3 : in  std_logic_vector(3 downto 0);
          y1, y2, y3 : out std_logic_vector(3 downto 0));
end substitution;

architecture parallel of substitution is
    signal f1in0, f1in1, f1out : std_logic_vector(3 downto 0);
    signal f2in0, f2in1, f2out : std_logic_vector(3 downto 0);
    signal f3in0, f3in1, f3out : std_logic_vector(3 downto 0);
    signal g1in0, g1in1, g1out : std_logic_vector(3 downto 0);
    signal g2in0, g2in1, g2out : std_logic_vector(3 downto 0);
    signal g3in0, g3in1, g3out : std_logic_vector(3 downto 0);

begin

   --g1in0 <= x2(0) & x2(1) & x2(2) & x2(3);
   --g1in1 <= x3(0) & x3(1) & x3(2) & x3(3);

   --g2in0 <= x1(0) & x1(1) & x1(2) & x1(3);
   --g2in1 <= x3(0) & x3(1) & x3(2) & x3(3);
   --
   --g3in0 <= x1(0) & x1(1) & x1(2) & x1(3);
   --g3in1 <= x2(0) & x2(1) & x2(2) & x2(3);
   
   g1in0 <= x2;
   g1in1 <= x3;

   g2in0 <= x1;
   g2in1 <= x3;
   
   g3in0 <= x1;
   g3in1 <= x2;

   gl1 : entity work.gbox1 port map (g1in0, g1in1, g1out);
   gl2 : entity work.gbox2 port map (g2in0, g2in1, g2out);
   gl3 : entity work.gbox3 port map (g3in0, g3in1, g3out);

   f1in0 <= g2out;
   f1in1 <= g3out;
   f2in0 <= g1out;
   f2in1 <= g3out;
   f3in0 <= g1out;
   f3in1 <= g2out;
   
   fl1 : entity work.fbox1 port map(f1in0, f1in1, f1out);
   fl2 : entity work.fbox2 port map(f2in0, f2in1, f2out);
   fl3 : entity work.fbox3 port map(f3in0, f3in1, f3out);

   y1 <= f1out;
   y2 <= f2out;
   y3 <= f3out;

end parallel;

