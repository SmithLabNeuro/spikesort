function [waveforms,times,units]=readWaveforms2(packetLocations,samples,filename)
%function [waveforms,times,units]=readWaveforms2(packetLocations,samples,filename)
%
% Updated readWaveforms using only native Matlab code
% 

% old way it was called as a Mex function:
%[wav,tim,uni] = readWaveforms(loc,WaveformInfo.NumSamples,FileInfo(i).filename);

global FileInfo
packetSize = FileInfo(1).PacketSize; 
% packet format (in our NEV files):
% 4b(time) + 2b(junk) + 1b(unit) + 1b(junk) + 104b(waveform samples * 2) = 112

spikeCount = numel(packetLocations);

fid = fopen(filename,'r');

if (fid==-1)
    error(['File ',filename,' not found.']);
end

% preallocate for speed
tempData = zeros(packetSize,spikeCount,'uint8');

fseek(fid,packetLocations(1),'bof');
pl2 = diff(packetLocations);

readStr = [num2str(packetSize),'*uint8=>uint8'];
for I=1:spikeCount-1
    tempData(:,I) = fread(fid,packetSize,readStr,pl2(I)-packetSize);
end
tempData(:,spikeCount)=fread(fid,packetSize,'uint8=>uint8');

times = typecast(reshape(tempData(1:4,:),numel(tempData(1:4,:)),1),'uint32');
units = tempData(7,:)';
waveforms = typecast(reshape(tempData(9:packetSize,:),numel(tempData(9:packetSize,:)),1),'int16');
waveforms = reshape(waveforms,samples,spikeCount);

fclose(fid);

% Slower method: memmapfile
%mmFormat={'uint32',[1],'tim';'uint16',[1],'j1';'uint8',[1],'uni';'uint8',[1],'j2';'int16',[52],'wav'};
%m = memmapfile(filename,'Format',mmFormat,'Offset',packetLocations(1));
%n = m.Data(((packetLocations - packetLocations(1))./112)+1);
%times = [n.tim]';
%units = [n.uni]';
%waveforms = [n.wav];

% Straightforward method (slow)
%for I=1:spikeCount
%    fseek(fid,packetLocations(I),'bof');
%    times(I) = fread(fid,1,'uint32');
%    junk = fread(fid,1,'uint16');
%    units(I) = fread(fid,1,'uint8');
%    junk = fread(fid,1,'uint8');
%    waveforms(:,I) = fread(fid,samples,'int16');
%end

% Slight speedup on straightforward method (skips one fread)
%for I=1:spikeCount
%    fseek(fid,packetLocations(I),'bof');
%    times(I) = fread(fid,1,'uint32=>uint32');
%    junk = fread(fid,1,'uint16=>uint16');
%    units(I) = fread(fid,1,'uint8=>uint8',1);
%    %junk = fread(fid,1,'uint8');
%    waveforms(:,I) = fread(fid,samples,'int16=>int16');
%end

