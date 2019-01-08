%waves2nev(outputFilename,waves,channels,sortcodes,times)
%
% The goal of this function is to take in waveforms and write out a
% NEV format file containing those waves.
%
% outputFilename is the name of the output file (must end in .nev)
% waves is a nspikes X samples matrix of waveforms
% channels, sortcodes and times must be nspikes X 1 vectors
%
% Optional arguments (name/value pairs):
% samplingRate is the rate of the waveform data in samples/sec (defaults to 30000)
% nVPerBit is the number of nanoVolts per bit in the wavform data (defaults to 200)
%  This can either be a scalar, or a vector of length equal to
%  length(unique(channels)) [Note that this would be unusual,
%  typically all channels have the same nVPerBit value]
%
% Example:
%
% waves2nev('test.nev',waves,channels,sortcodes,times,'samplingRate',30000,'nVPerBit',200);
%

function waves2nev(outputFilename,waves,channels,sortcodes,times,varargin)

% First, some error checks
% Check that channels and sortcodes and times are the same length
% check that those 3 are the same dimension as the rows of waves
% samplingRate needs to be a positive integer
% check that nVPerBit is either a scalar, or it's a vector
% of length (unique(channels))

p = inputParser;
p.addOptional('nVPerBit',200,@isnumeric);
p.addOptional('samplingRate',30000,@isnumeric);

p.parse(varargin{:});
nVPerBit = p.Results.nVPerBit;
samplingRate = p.Results.samplingRate;

assert(endsWith(outputFilename,'.nev'),'Error: The outputFile is not NEV file');
assert(length(channels) == length(sortcodes) && length(sortcodes) == length(times),'Error: The length of channels,sortcodes and times are not the same');
assert(size(waves,1) == length(channels),'Error: The number of waves is not the same as the length of channels');
if ~(mod(times(1),1) == 0)
    disp('Converting times ...');
    times = times.*samplingRate;
end


% did they send in someting that looks like uV?
% maybe some error checking - is it a double, etc
% If they did send in uV, and they didn't specify nVPerBit, then divide the
% waveform by .2, convert to int16, and write "200" in the nVPerBit
% location

if isa(waves,'double')
    nVPerBit = 200;
    waves = waves ./.2;
elseif isa(waves,'int16')
    nVPerBit = p.Results.nVPerBit;
end

assert(mod(samplingRate,1) == 0 && samplingRate > 0,'Error: samplingRate is not a positive integer'); 
assert(isscalar(nVPerBit) || length(nVPerBit) == length(unique(channels)),'Error: nVPerBit should be a scalar or a vector of length (unique(channels))');

if (isscalar(nVPerBit))
    nVPerBit = nVPerBit * ones(length(unique(channels)),1);
end

%% START WRITING NEV FILE - header first

% Use the same name as the PLX file, but with .nev at the end
fidWrite = fopen(outputFilename, 'W', 'l');

% Write basic header
chanList = unique(channels);
numExtHdr = length(chanList); 
extHdrBytes = 32;
basicHdrBytes = 336;
fwrite(fidWrite, 'NEURALEV', 'char');   % file type ID
fwrite(fidWrite, [0;0], 'uchar'); % File Spec
fwrite(fidWrite, 0, 'uint16'); % additional flags
headerSize = basicHdrBytes + (numExtHdr * extHdrBytes);
fwrite(fidWrite, headerSize, 'uint32'); % add up bytes in basic and extended header for header size

nWordsinWave = size(waves,2);
fwrite(fidWrite, 8+(2*nWordsinWave), 'uint32'); %% Bytes in data packets (8 + nBytesinWaveform)

% this is "samplingRate"
fwrite(fidWrite, samplingRate, 'uint32'); % time resolution of time stamps
fwrite(fidWrite, samplingRate, 'uint32'); % Time resolutions of samples (sampling frequency)

% Fill in the NEV time/date info from the current time
yearStamp = datestr(now,'yyyy');
monthStamp = datestr(now,'mm');
dayStamp = datestr(now,'dd');
D = [monthStamp,'-',dayStamp,'-',yearStamp];
[DayNumber] = weekday(D);
hourStamp = datestr(now,'HH');
minStamp = datestr(now,'MM');
secStamp = datestr(now,'SS');
%milsecStamp = datestr(now,'FFF');

% write windows SYSTEM TIME structure - need better way
fwrite(fidWrite, uint16(str2double(yearStamp)), 'uint16'); % Year
fwrite(fidWrite, uint16(str2double(monthStamp)), 'uint16'); % Month
fwrite(fidWrite, uint16(DayNumber), 'uint16'); % DayOfWeek
fwrite(fidWrite, uint16(str2double(dayStamp)), 'uint16'); % Day
fwrite(fidWrite, uint16(str2double(hourStamp)), 'uint16'); % Hour
fwrite(fidWrite, uint16(str2double(minStamp)), 'uint16'); % Minute
fwrite(fidWrite, uint16(str2double(secStamp)), 'uint16'); % Second
fwrite(fidWrite, 0, 'uint16'); % Millisecond

fwrite(fidWrite, char(strcat({'WAVES2NEV'},{blanks(19)}, {'NULL'})), 'char'); % String labeling program that created file
%fwrite(fidWrite, char(strcat({blanks(28)}, {'NULL'})), 'char'); % String labeling program that created file
fwrite(fidWrite, char(strcat({blanks(196)}, {'NULL'})), 'char'); % Comment field, null terminated
fwrite(fidWrite, blanks(52), 'char');   % reserved for future information
fwrite(fidWrite, 0, 'uint32'); % Processor timeStamp
fwrite(fidWrite, numExtHdr, 'uint32'); % # of extended Headers

%% Write extended headers - 32 bytes each
for iHeader=1:numExtHdr
    fwrite(fidWrite, 'NEUEVWAV', 'char'); % Packet ID (always set to 'NEUEVWAV')
    fwrite(fidWrite, chanList(iHeader), 'uint16'); % Electrode ID
    fwrite(fidWrite, 1, 'uchar'); % Front end ID
    fwrite(fidWrite, chanList(iHeader), 'uchar'); % Front end connector pin
    fwrite(fidWrite, nVPerBit(iHeader), 'uint16'); %% Neural amp digitization factor (nVolt per Bit)
%     fwrite(fidWrite, nVPerBit, 'uint16'); %% Neural amp digitization factor (nVolt per Bit)
    fwrite(fidWrite, 0, 'uint16'); % Energy Threshold
    fwrite(fidWrite, 0, 'int16'); % High Threshold
    fwrite(fidWrite, 0, 'int16'); % Low threshold
    fwrite(fidWrite, 0, 'uchar'); % Number of sorted units (set to 0)
    fwrite(fidWrite, 2, 'uchar'); % Number of bytes per waveform sample
    fwrite(fidWrite, nWordsinWave, 'uint16'); % Stim Amp Digitization factor
    fwrite(fidWrite, blanks(8), 'uchar'); % Remaining bytes reserved
end
fprintf('waves2nev: Wrote %d extended headers\n',numExtHdr);

%% Sequential read and writing of spikes

spikeCount = 0;

fprintf('waves2nev: Writing spikes into NEV ... ');

while spikeCount<size(waves,1) %read until the end of file
    
    spikeCount = spikeCount + 1;
    fwrite(fidWrite, times(spikeCount), 'uint32'); % Timestamp of spike
    fwrite(fidWrite, channels(spikeCount), 'uint16'); % PacketID (electrode ID number)
    fwrite(fidWrite, sortcodes(spikeCount), 'uchar'); % Sort Code
    fwrite(fidWrite, 0, 'uchar'); % Reserved for future unit info
    fwrite(fidWrite, waves(spikeCount,:), 'int16'); % Write waveform
    
end % End of while loop to read/write waves

fclose(fidWrite);

%% Print final status, and note if there were any problems

fprintf('\n');

