% plx2nev(filename)
%
% Plexon plx to NEV convertor. plx2nev takes a PLX filename and
% writes the spike waveform data to a NEV file with the same filename
% but a NEV extension
%
% INPUT
%     filename: string containing the plx file to be written as an nev file
%

function plx2nev(filename)

fidRead = fopen(filename);
disp('plx2nev: Reading PLX file header');

%% File Header
magicNumber = fread(fidRead, 1, 'uint32'); %magic num
versionNum = fread(fidRead, 1, 'int32');
comment = fread(fidRead, 128, 'char'); %user comment
adFreq = fread(fidRead, 1, 'int32');
numDSPChan = fread(fidRead, 1, 'int32');
numEventChan = fread(fidRead, 1, 'int32');
numSlowChan = fread(fidRead, 1, 'int32');
numPointsWave = fread(fidRead, 1, 'int32');
numPtsPreThresh = fread(fidRead, 1, 'int32');
yearStamp = fread(fidRead, 1, 'int32');   %year
monthStamp = fread(fidRead, 1, 'int32');  %month
dayStamp = fread(fidRead, 1, 'int32');    %day
hourStamp = fread(fidRead, 1, 'int32');
minStamp = fread(fidRead, 1, 'int32');
secStamp = fread(fidRead, 1, 'int32');
fastRead = fread(fidRead, 1, 'int32');    %reserved
waveformFreq = fread(fidRead, 1, 'int32');
lastTimeStamp = fread(fidRead, 1, 'double');

%read in the next items if version >= 103
if versionNum >= 103
    trodalness = fread(fidRead, 1, 'char');
    dataTrodalness = fread(fidRead, 1, 'char');
    bitsPerSpikeSample = fread(fidRead, 1, 'char');
    bytesPerSpikeSample = bitsPerSpikeSample / 8; % get bytes per spike sample
    bitsPerSlowSample = fread(fidRead, 1, 'char');
    spikeMaxMagMV = fread(fidRead, 1, 'ushort');
    slowMaxMagMV = fread(fidRead, 1, 'ushort');
end

%Read in the next item if version >= 105
if versionNum >= 105
    spikePreAmpGain = fread(fidRead, 1, 'ushort');
% else
%     spikePreAmpGain = 1000;
end
% Figure out the number of padding bytes based on what you've read so far
% if versionNum >= 105
%     paddingBytes = 46;
% elseif versionNum >= 103
%     paddingBytes = 44;
% else
%     paddingBytes = 38;
% end
% paddingJunk = fread(fidRead, paddingBytes, 'char');   %padding so this part of header is 256 bytes

% Better solution - just seek to 256 bytes
fseek(fidRead,256,'bof');

%Counters for number of timestamps, waveforms in each channel
tsCounts = fread(fidRead, [130, 5], 'int32');
wfCounts = fread(fidRead, [130, 5], 'int32');
evCounts = fread(fidRead, [1, 512], 'int32');

spikesAccordingToHeader = sum(sum(tsCounts));
%contAccordingToHeader = sum(sum(wfCounts));
eventsAccordingToHeader = sum(evCounts);

fileHeaderSize = ftell(fidRead);

%% Spike Header
voltageConversion = nan(numDSPChan,1);

plxChannelNum = nan(numDSPChan,1);

% Spike Channel Headers
for iHeader = 1:numDSPChan
    nameDSP = fread(fidRead, 32, 'char'); % Name given to the DSP channel
    %disp(char(nameDSP'));
    sigName = fread(fidRead, 32, 'char'); % ame given to the corresponding SIG channel
    plxChannelNum(iHeader) = fread(fidRead, 1, 'int32');  %DSP channel number, 1 based
    wfRate = fread(fidRead, 1, 'int32');
    sigChan = fread(fidRead, 1, 'int32'); %SIG channel associated with this DSP channel
    sigRefChan = fread(fidRead, 1, 'int32'); %SIG channel used as a reference signal
    channelGain = fread(fidRead, 1, 'int32'); % actual gain divided by SpikePreAmpGain
    filter = fread(fidRead, 1, 'int32'); %either 0 or 1
    threshold = fread(fidRead, 1, 'int32');  %threshold for spike detection in a/d values
    method = fread(fidRead, 1, 'int32'); % Method used for sorting units, 1 - boxes, 2 - templates
    nUnits = fread(fidRead, 1, 'int32');  %number of sorted units
    template = fread(fidRead, 320, 'short');  %Templates used for template sorting, in a/d values [5][64]
    fit = fread(fidRead, 5, 'int32'); %template fit
    sortWidth = fread(fidRead, 1, 'int32');   %how many points to use in template sorting
    boxes = fread(fidRead, 40, 'short');  %the boxes used in boxes sorting
    sortBeginning = fread(fidRead, 1, 'int32');   %the beginning of the sorting window to use in template sorting
    comment = fread(fidRead, 128, 'char');
    paddingJunk = fread(fidRead, 11, 'int32');
    if versionNum >= 105
        voltageConversion(plxChannelNum(iHeader)) = spikeMaxMagMV / (0.5 * (2^bitsPerSpikeSample) * (channelGain) * (spikePreAmpGain));
    elseif versionNum >= 103
        voltageConversion(plxChannelNum(iHeader)) = spikeMaxMagMV / (0.5 * (2^bitsPerSpikeSample) * (channelGain) * (1000));
    else
        voltageConversion(plxChannelNum(iHeader)) = 3000 / (2048 * channelGain * 1000);
    end
    
end

% We don't need to read the Event header(s) or Slow channel header(s)
% for this converter
%
% %% Event Header
% 
% for iHeader = 1:numEventChan
%     nameEvent = fread(fidRead, 32, 'char'); % name given to this event
%     %disp(char(nameEvent'));
%     channelNumEvent = fread(fidRead, 1, 'int32'); % event number, 1-based
%     comment = fread(fidRead, 128, 'char');
%     paddingJunk = fread(fidRead, 33, 'int32');
% 
% end
% 
% 
% %% Slow Channel Header
% 
% for iHeader = 1:numSlowChan
%     nameSlow = fread(fidRead, 32, 'char');
%     %disp(char(nameSlow'));
%     channelNumSlow = fread(fidRead, 1, 'int32'); % channel number, 0-based
%     slowADFreq = fread(fidRead,1,'int32'); % digitization frequency
%     slowGain = fread(fidRead,1,'int32'); % gain at the adc card
%     slowEnabled = fread(fidRead,1,'int32'); % whether this channel is enabled for taking data, 0 or 1
%     slowPreAmpGain = fread(fidRead,1,'int32');
%     if versionNum >= 104
%         % indicates the spike channel corresponding to this continuous data channel
%         slowSpikeChannel = fread(fidRead,1,'int32');
%     end
%     comment = fread(fidRead, 128, 'char');
%     paddingJunk = fread(fidRead, 28, 'int32');
% end

%% Skip all headers to get to data blocks
nBytesinDSPHeader = 1020;  %number of bytes in DSP channel header
nBytesinEventHeader = 296;
nBytesinSlowHeader = 296;

DSPSkip = nBytesinDSPHeader * numDSPChan;
eventSkip = nBytesinEventHeader * numEventChan;
slowSkip = nBytesinSlowHeader * numSlowChan;
fseek(fidRead, fileHeaderSize + DSPSkip + eventSkip + slowSkip, 'bof'); %skip to first data block from beginning of file

%% Read a sample of spikes to determine packet size
spikesToRead = 1000;
minPacketFreq = 0.9; % if > this portion of packets are same size, use that

fprintf('plx2nev: Determining packet size ... ');
nWordsVec = zeros(1, spikesToRead);
nWordsCount = 0;

while nWordsCount < spikesToRead
    
    if feof(fidRead) == 1
        if nWordsCount+1 <= spikesToRead
            nWordsVec(nWordsCount+1:end)=[];
        end
        break;
    end
    
    dataType = fread(fidRead, 1, 'short');
    upperByte = fread(fidRead, 1, 'ushort');
    timestamp = fread(fidRead, 1, 'ulong');
    channelNum = fread(fidRead, 1, 'short'); %%
    
    sortCode = fread(fidRead, 1, 'short'); %%
    numWaveforms = fread(fidRead, 1, 'short'); % number of waveforms in following data block
    nWordsinWave = fread(fidRead, 1, 'short');
    
    if ~isempty(numWaveforms) && ~isempty(nWordsinWave)   % check for empty numWaveforms/nWordsinWave arrays
        if numWaveforms > 0 && dataType > 0 && nWordsinWave > 0 % Get all events
            waveform = fread(fidRead, [nWordsinWave, 1], 'short'); %Read in wave (as junk)
            if dataType == 1 % Spike
                nWordsCount = nWordsCount + 1;
                nWordsVec(:, nWordsCount) = nWordsinWave;
            end
        end
    end % End of loops to read in wave as junk and store nWordsinWave for spikes
    if nWordsCount > spikesToRead
        break
    end
    
end % End of loop to determine packet size
fprintf('read %d spikes ... ', nWordsCount);

%% Determine what packet size to use

if size(unique(nWordsVec), 2) > 1
    
    % Find frequency of each of the packet lengths found
    [modeWords, freqWords] = mode(nWordsVec);
    
    if freqWords / size(nWordsVec, 2) > minPacketFreq
        nWordsinWave = modeWords;
    else
        uniqueWords = unique(nWordsVec);    %already sorted
        maxChoice = numel(uniqueWords) + 1;
        
        fprintf('\nThe plx file has a variable packet length.\n');
        fprintf('Please select a packet length to proceed:\n');
        
        for iChoice = 1:numel(uniqueWords)
            fprintf('%d. Packet length is %d\n', iChoice, uniqueWords(iChoice));
        end
        fprintf('%d. Quit plx to nev conversion', maxChoice);
        
        userChoice = input('\n\nEnter your choice: ');
        
        while userChoice > maxChoice || userChoice < 0
            userChoice = input('Enter your choice: ');
        end
        
        % if statements for each choice
        if userChoice < numel(uniqueWords)
            nWordsinWave = uniqueWords(userChoice);
        else
            fprintf('\nplx2nev: Quitting...');
            fprintf('\nplx2nev: ERROR: was not able to convert waves');
            return
            % Stop conversion, print error
        end % End of implementing user's choice
        
    end
    
else
    nWordsinWave = unique(nWordsVec);
end% End of nWordsVec loop

fprintf('using %d words per packet\n', nWordsinWave);

fclose(fidRead);

%% START WRITING NEV FILE 
% Once packet size has been determined, write NEV header using 
% PLX header info and packet size

% Use the same name as the PLX file, but with .nev at the end
[pathstr, nevFile]=fileparts(filename);
nevFile = strcat(pathstr,'/',nevFile, '.nev');
fidWrite = fopen(nevFile, 'W', 'l');

% Write basic header
numExtHdr = numDSPChan;
extHdrBytes = 32;
basicHdrBytes = 336;
fwrite(fidWrite, 'NEURALEV', 'char');   % file type ID
fwrite(fidWrite, [0;0], 'uchar'); % File Spec
fwrite(fidWrite, 0, 'uint16'); % additional flags
headerSize = basicHdrBytes + (numExtHdr * extHdrBytes);
fwrite(fidWrite, headerSize, 'uint32'); % add up bytes in basic and extended header for header size

% nWordsInWave
fwrite(fidWrite, 8+(2*nWordsinWave), 'uint32'); %% Bytes in data packets (8 + nBytesinWaveform)

fwrite(fidWrite, adFreq, 'uint32'); % time resolution of time stamps
fwrite(fidWrite, adFreq, 'uint32'); % Time resolutions of samples (sampling frequency)

D = [num2str(dayStamp),'-',num2str(monthStamp),'-',num2str(yearStamp)];
[DayNumber] = weekday(D);

% write windows SYSTEM TIME structure - need better way
fwrite(fidWrite, yearStamp, 'uint16'); % Year
fwrite(fidWrite, monthStamp, 'uint16'); % Month
fwrite(fidWrite, DayNumber, 'uint16'); % DayOfWeek
fwrite(fidWrite, dayStamp, 'uint16'); % Day
fwrite(fidWrite, hourStamp, 'uint16'); % Hour
fwrite(fidWrite, minStamp, 'uint16'); % Minute
fwrite(fidWrite, secStamp, 'uint16'); % Second
fwrite(fidWrite, 0, 'uint16'); % Millisecond

fwrite(fidWrite, char(strcat({blanks(28)}, {'NULL'})), 'char'); % String labeling program that created file
fwrite(fidWrite, char(strcat({blanks(196)}, {'NULL'})), 'char'); % Comment field, null terminated
fwrite(fidWrite, blanks(52), 'char');   % reserved for future information
fwrite(fidWrite, 0, 'uint32'); % Processor timeStamp
fwrite(fidWrite, numExtHdr, 'uint32'); % # of extended Headers

%% Write extended headers - 32 bytes each
% note that some of these values are just default filler values
nVperBit = 1000000.*voltageConversion;

for iHeader=1:numExtHdr
    fwrite(fidWrite, 'NEUEVWAV', 'char'); % Packet ID (always set to 'NEUEVWAV')
    fwrite(fidWrite, plxChannelNum(iHeader), 'uint16'); % Electrode ID
    fwrite(fidWrite, 1, 'uchar'); % Front end ID
    fwrite(fidWrite, plxChannelNum(iHeader), 'uchar'); % Front end connector pin
    fwrite(fidWrite, nVperBit(plxChannelNum(iHeader)), 'uint16'); %% Neural amp digitization factor (nVolt per Bit)
    fwrite(fidWrite, 0, 'uint16'); % Energy Threshold
    fwrite(fidWrite, 0, 'int16'); % High Threshold
    fwrite(fidWrite, 0, 'int16'); % Low threshold
    fwrite(fidWrite, 0, 'uchar'); % Number of sorted units (set to 0)
    fwrite(fidWrite, 2, 'uchar'); % Number of bytes per waveform sample
    fwrite(fidWrite, 0, 'float'); % Stim Amp Digitization factor
    fwrite(fidWrite, blanks(6), 'uchar'); % Remaining bytes reserved
end
fprintf('plx2nev: Wrote %d extended headers\n',numExtHdr);

%% Sequential read and writing of spikes

% Open and seek to location of first data packet in plx file
fidRead = fopen(filename);
fseek(fidRead, fileHeaderSize + DSPSkip + eventSkip + slowSkip, 'bof');

spikeCount = 0;
eventCount = 0;
contCount = 0;
totalCount = 0;
printFreq = ceil(spikesAccordingToHeader/10); % print a status message every 10 percent

fprintf('plx2nev: Writing spikes into NEV ... ');
while feof(fidRead) == 0 %read until the end of file
%while spikeCount <1    
    % Read in data block header - 16 bytes
%     dataType = fread(fidRead, 1, 'int16'); % 1 = spike, 4 = event, 5 = continuous
%     upperByte = fread(fidRead, 1, 'uint16');
%     timestamp = fread(fidRead, 1, 'uint32');
%     channelNum = fread(fidRead, 1, 'int16'); %%
%     sortCode = fread(fidRead, 1, 'int16'); %%
%     numWaveforms = fread(fidRead, 1, 'int16'); % number of waveforms in following data block
%     sampleNWordsinWave = fread(fidRead, 1, 'int16');
        
    dataType = fread(fidRead, 1, 'short'); % 1 = spike, 4 = event, 5 = continuous
    upperByte = fread(fidRead, 1, 'ushort');
    timestamp = fread(fidRead, 1, 'ulong');
    channelNum = fread(fidRead, 1, 'short'); %%
    sortCode = fread(fidRead, 1, 'short'); %%
    numWaveforms = fread(fidRead, 1, 'short'); % number of waveforms in following data block
    sampleNWordsinWave = fread(fidRead, 1, 'short');

    if numWaveforms > 0% continuous data follows
        waveform = fread(fidRead, [sampleNWordsinWave*numWaveforms, 1], 'int16'); %Read in wave
    end

    % convert time stamp to seconds - seems to work fine
    ts = cast(bitshift(upperByte,32),'uint64') + cast(timestamp,'uint64');
    %ts = cast(ts,'double')/adFreq; % convert to seconds
    ts = cast(ts,'uint32');

    % Code Plexon suggests to convert timestamp + upperByte to seconds
    %LONGLONG ts = ((static_cast<LONGLONG>(dataBlock.UpperByteOf5ByteTimestamp)<<32) + static_cast<LONGLONG>(dataBlock.TimeStamp)) ;
    %double seconds = (double) ts / (double) fileHeader.ADFrequency ;
    
    if dataType == 1
        fwrite(fidWrite, timestamp, 'uint32'); % Timestamp of spike
        fwrite(fidWrite, channelNum, 'uint16'); % PacketID (electrode ID number)
        fwrite(fidWrite, sortCode, 'uchar'); % Sort Code
        fwrite(fidWrite, 0, 'uchar'); % Reserved for future unit info
        if numWaveforms > 0
            fwrite(fidWrite, waveform, 'int16'); % Write waveform
        end
        
        spikeCount = spikeCount + 1;
    elseif dataType == 4
        % For now, we're writing the channel num into sort code because
        % Plexon and NEV use different formats for events, not clear how to
        % translate properly. All NEV events are channel zero, but Plexon
        % has multiple channels. Also, all NEV events are an unsigned
        % int16, and Plexon is signed int16.
        
        %disp(['ch: ',num2str(channelNum),' sc: ',num2str(sortCode),' ts: ',num2str(timestamp)]);
        fwrite(fidWrite, timestamp, 'uint32'); % Timestamp of event
        fwrite(fidWrite, 0, 'uint16'); % Always zero for digital events
        fwrite(fidWrite, 0, 'uchar'); % packet insertion reason
        fwrite(fidWrite, 0, 'uchar'); % reserved
        fwrite(fidWrite, channelNum, 'uint16'); % Sort Code
        fwrite(fidWrite, zeros((nWordsinWave*2)-2,1)', 'uchar'); % Remaining bytes reserved

        eventCount = eventCount + 1;
    elseif dataType == 5
        contCount = contCount + 1;
    else
        disp(['Warning: Unrecognized data block type ',num2str(dataType)]);
    end
    totalCount = totalCount + 1;
    
    %disp(['timestamp=',num2str(timestamp),' tss=',num2str(ts)]);
    %disp(['count',num2str(totalCount),' type',num2str(type),' * ch',num2str(channelNum),' sc',num2str(sortCode)]);

    % status message as data blocks are written
    if rem(totalCount,printFreq)==0
        fprintf('%d%%, ',floor((spikeCount/spikesAccordingToHeader)*100));
    end

    % break out of loop if you reach end of file
    if feof(fidRead) == 1
        break
    end
    
end % End of while loop to read/write waves

fclose(fidRead);
fclose(fidWrite);

%% Print final status, and note if there were any problems
fprintf('\nplx2nev:   %d spikes were written to the nev file.\n',spikeCount);
fprintf('plx2nev:   %d events were written to the nev file.\n',eventCount);
fprintf('plx2nev:   ignored %d continuous blocks.\n',contCount);

if spikeCount ~= spikesAccordingToHeader
    fprintf('plx2nev: *** Warning: Header said %d spikes but only %d were written to the nev file! ***',spikesAccordingToHeader,spikeCount);
end
if eventCount ~= eventsAccordingToHeader
    fprintf('plx2nev: *** Warning: Header said %d events but only %d were written to the nev file! ***',eventsAccordingToHeader,eventCount);
end

fprintf('\n');

