function spikesort_write2(fileIndex)

global FileInfo;
global WaveformInfo;

j = fileIndex;

ByteFormat=['int' num2str(FileInfo(j).BytesPerSample*8)];
UnitFormat='uchar';
WaveformSize=(FileInfo(j).PacketSize-8)/FileInfo(j).BytesPerSample;               
PacketSize=FileInfo(j).PacketSize/FileInfo(j).BytesPerSample;
UnitLength=1;
TimestampBytes = 4;
PacketIdBytes = 2;

filename=FileInfo(j).filename;
HeaderSize=FileInfo(j).HeaderSize;
Locations=FileInfo(j).Locations;%Locations are in bytes relative to header end
chan_Locations=Locations(FileInfo(j).PacketOrder==WaveformInfo.ChannelNumber);%packets from this channel

loc = chan_Locations + TimestampBytes + PacketIdBytes + HeaderSize; 

writeUnits2(loc, WaveformInfo.Unit, filename); 

FileInfo(j).units{WaveformInfo.ChannelNumber} = zeros(256,1);
FileInfo(j).units{WaveformInfo.ChannelNumber}(unique(double(WaveformInfo.Unit))+1) = 1;

end

function writeUnits2(packetLocations,units,filename)
%function writeUnits2(packetLocations,units,filename)
%
% Updated writeUnits using only native Matlab code
% 

% old way it was called as a Mex function:
%writeUnits(loc, WaveformInfo.Unit, filename);

fid = fopen(filename,'r+');

if (fid==-1)
    error(['File ',filename,' not found.']);
end

spikeCount = numel(packetLocations);

fseek(fid,packetLocations(1),'bof');
pl2 = diff(packetLocations)-1;

fwrite(fid,units(1),'uint8'); % write first unit without skipping
for I=2:spikeCount
    fwrite(fid,units(I),'uint8',pl2(I-1));
end

fclose(fid);
end

% works but slower
%for I=1:spikeCount
%    fseek(fid,packetLocations(I),'bof');
%    fwrite(fid,units(I),'uint8');
%end
