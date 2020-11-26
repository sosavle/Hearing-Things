LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_signed.all;
USE ieee.numeric_std.all;

ENTITY toplevel IS
   PORT ( 
			 CLOCK_50, CLOCK2_50, AUD_DACLRCK   	: IN    STD_LOGIC;
          AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT  	: IN    STD_LOGIC;
          KEY                                	: IN    STD_LOGIC_VECTOR(0 DOWNTO 0);
			 AUD_XCK											: OUT   STD_LOGIC;
          I2C_SDAT           			           	: INOUT STD_LOGIC;
			 
			 --finish the rest of the ports
			 I2C_SCLK, AUD_DACDAT						: OUT	  STD_LOGIC       
	);
END toplevel;

ARCHITECTURE Behavior OF toplevel IS
   COMPONENT clock_generator --this component is completed for you
      PORT( CLOCK_27 : IN STD_LOGIC;
            reset    : IN STD_LOGIC;
            AUD_XCK  : OUT STD_LOGIC);
   END COMPONENT;

   COMPONENT audio_and_video_config
      PORT( CLOCK_50:	IN		STD_LOGIC;
				reset:		IN		STD_LOGIC;
				I2C_SDAT:	INOUT	STD_LOGIC;
				I2C_SCLK:	OUT	STD_LOGIC
		);
   END COMPONENT;   

   COMPONENT audio_codec
		PORT( CLOCK_50:				IN	STD_LOGIC;
				reset:					IN STD_LOGIC;
				read_s:					IN STD_LOGIC;
				write_s:					IN STD_LOGIC;
				writedata_left:		IN STD_LOGIC_VECTOR(23 downto 0);
				writedata_right:		IN STD_LOGIC_VECTOR(23 downto 0);
				AUD_ADCDAT:				IN STD_LOGIC;
				AUD_BCLK:				IN STD_LOGIC;
				AUD_ADCLRCK:			IN STD_LOGIC;
				AUD_DACLRCK:			IN STD_LOGIC;
				read_ready:				OUT STD_LOGIC;
				write_ready:			OUT STD_LOGIC;
				readdata_left:			OUT STD_LOGIC_VECTOR(23 downto 0);
				readdata_right:		OUT STD_LOGIC_VECTOR(23 downto 0);
				AUD_DACDAT:				OUT STD_LOGIC
		);
   END COMPONENT;
	
	COMPONENT ram2p
		PORT(
			clock: IN STD_LOGIC;
			data: IN STD_LOGIC_VECTOR(23 DOWNTO 0);
			rdaddress: IN STD_LOGIC_VECTOR(10 DOWNTO 0);
			wraddress: IN STD_LOGIC_VECTOR(10 DOWNTO 0);
			wren: IN STD_LOGIC;
			q: OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
		);
	END COMPONENT;

   SIGNAL read_ready, write_ready, read_s, write_s 		: STD_LOGIC;
   SIGNAL readdata_left, readdata_right            		: STD_LOGIC_VECTOR(23 DOWNTO 0);
   SIGNAL writedata_left, writedata_right          		: STD_LOGIC_VECTOR(23 DOWNTO 0);   
   SIGNAL reset                                    		: STD_LOGIC;
	--SIGNAL slowClock:Std_logic;
	--signal counter:std_logic_vector(3 downto 0);
	--SIGNAL state: std_logic_vector(10 downto 0);
	
	type readState is (oddReads, evenReads);
	signal state: readState;
	constant ramSize:integer := 2048;
	signal writeIndex: integer := 0;
	signal readIndex: integer := 1;
	
	signal rdaddress: std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(readIndex, 11));
	signal wraddress: std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(writeIndex, 11));
	
	signal ql: STD_LOGIC_VECTOR(23 DOWNTO 0);
	signal qr:STD_LOGIC_VECTOR(23 DOWNTO 0);
 
BEGIN
	reset <= NOT(KEY(0));
	-- read_s <= read_ready;
	
	
	-- State Machine
	stateControl: PROCESS(CLOCK2_50, reset) BEGIN
		-- Reset
		if reset = '1' then
			state <= oddReads;
			readIndex <= 1;
			writeIndex <= 0;
			write_s <= '0';
			read_s <= '0';
			
		-- Sequential Logic
		elsif rising_edge(CLOCK2_50) then
			
			if read_ready and write_ready then
				read_s <= '1';
				write_s <= '1';
			
				-- Switch State if read all the way
				if readIndex >= ramSize-1 then
					if state = oddReads then
						readIndex <= 0;
						state <= evenReads;
					else
						readIndex <= 1;
						state <= oddReads;
					end if;	
				
				-- Otherwise increment reads
				else
					readIndex <= readIndex + 2;
				end if;
				
				-- Make sure write indices do not go overboard
				if writeIndex >= ramSize-1 then
					writeIndex <= 0;
				else
					writeIndex <= writeIndex + 1;
				end if;
				
			else
				read_s <= '0';
				write_s <= '0';
			end if;
			
		end if;
		
		-- Read and Write to appropriate addresses in memory
		rdaddress <= std_logic_vector(to_unsigned(readIndex, 11));
		wraddress <= std_logic_vector(to_unsigned(writeIndex, 11));
	END PROCESS;
	
	
	
	/*writedata: PROCESS(read_ready, write_ready, state, reset) BEGIN
			
		elsif write_ready = '1' and state = "11111111111" then
			writedata_left <= lbuffer(0);
			writedata_right <= rbuffer(0);
			write_s <= '1';
			
		else
			-- Store current
			lbuffer(i) <= readdata_left;
			rbuffer(i) <= readdata_right;
			write_s <= '0';	
		end if;	
		i <= i + 1;
	END PROCESS;*/
	
	
	-- 2KB CIRCULAR BUFFERS FOR FREQUENCY MANIPULATIONS
	lbuffer: ram2p PORT MAP(CLOCK2_50, readdata_left, rdaddress, wraddress, read_ready, ql);
	rbuffer: ram2p PORT MAP(CLOCK2_50, readdata_right, rdaddress, wraddress, read_ready, qr);
	
	writedata_left <= ql when write_ready = '1' else (others =>'0');
	writedata_right <= qr when write_ready = '1' else (others =>'0');
   
  	my_clock_gen: clock_generator PORT MAP (CLOCK2_50, reset, AUD_XCK);
	
	av_config: audio_and_video_config PORT MAP (CLOCK_50, reset, I2C_SDAT, I2C_SCLK);
	
	codec: audio_codec PORT MAP (CLOCK2_50, reset, read_s,	write_s, writedata_left, 
										  writedata_right, AUD_ADCDAT, AUD_BCLK, AUD_ADCLRCK, 
										  AUD_DACLRCK,read_ready, write_ready, readdata_left, 
										  readdata_right,AUD_DACDAT);
										  

	
	
  
END Behavior;
