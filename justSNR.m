function [snr,avgWave] = justSNR(filename,nWaveforms)
%function [snr,avgWave] = justSNR(filename,nWaveforms)    
%function snr = justSNR(filename,nWaveforms)
%
% snr = justSNR takes a NEV filename as input and returns a list of
% channel numbers, sort codes, SNR values, and spike counts from
% that file. The default option is to read 50k waveforms from each
% sort code (sparse read) rather than all the waveforms
%
% justSNR(filename,nWaveforms) does a sparse read of nWaveforms to
% compute SNR (defaults to this option with a read of 50k waveforms)
%
% justSNR(filename,'all') does a full read of nWaveforms to
% compute SNR (this option is slow for big files)
%
% [snr,avgWave]=justSNR
% snr is a 4-column matrix with channel, sort code, SNR, #waveforms
%
% avgWave (if requested) is a
% nSamples x nUnits array of average waveforms from each sort code
%

clear global WaveformInfo
global WaveformInfo;

if nargin<2||isempty(nWaveforms)
    nWaveforms = 5e4;
end

switch class(nWaveforms)
    case 'char'
        if strcmpi(nWaveforms,'all')
            nevWaveforms(filename);
        else
            error('unrecognized option %s',nWaveforms);
        end
    otherwise
        %do the sparse read:
        nevWaveforms_sparse(filename,[],nWaveforms);
end

disp('Completed waveform read. Computing SNR...');

k = 1;

for i = 1:length(WaveformInfo) 
    units = unique(WaveformInfo(i).Unit);
    
    for j = 1:length(units)
        wav = WaveformInfo(i).Waveforms((WaveformInfo(i).Unit == ...
            units(j)),:);
        snr(k,:) = [WaveformInfo(i).Channel double(units(j)) getSNR(double(wav)) size(wav,1)];
        avgWave(:,k) = double(mean(wav,1)); %save the average waveform
        
        k = k + 1;
    end
end
end

function waveforms = nevWaveforms(filenames,channels)
%function waveforms = nevWaveforms(filenames,channels)
%
% filenames can be a single string or a cell array of strings
% channels is optional, uses all channels by default
%
clear global FileInfo
global loc;
global FileInfo;
global WaveformInfo;

FileInfo=struct('filename',[],'format','nev','HeaderSize',0,...
    'PacketSize',0,'ActiveChannels',[],'PacketOrder',uint8([]),...
    'SpikesNumber',[],'BytesPerSample',0,...
    'nSpikesToReadPerChannel',0); %initialize FileInfo structure

if iscell(filenames)
    for I=1:length(filenames)
        FileInfo(I).filename = filenames{I};
    end
else
    FileInfo(1).filename = filenames;
end

ActiveChannelList=[];

for i = 1:length(FileInfo)
    spikesort_nevscan(i,false);
    
    ActiveChannelList = union(ActiveChannelList,FileInfo(i).ActiveChannels);
end

if nargin < 2
    channels = ActiveChannelList;
end

if length(unique([FileInfo(:).PacketSize]))~=1
    error('Variable Packet Sizes');
end

WaveformSize=(FileInfo(1).PacketSize-8)/FileInfo(1).BytesPerSample;
ByteLength=['int' num2str(FileInfo(1).BytesPerSample*8)];

numSamples = (FileInfo(1).PacketSize-8)/2;

gaveWarning = false;
for channelIndex = 1:length(channels)
    WaveformInfo(channelIndex).Waveforms = [];
    WaveformInfo(channelIndex).Unit = [];
    WaveformInfo(channelIndex).Times = [];
    for fileIndex = 1:length(FileInfo)
        
        PacketNumbers=find(FileInfo(fileIndex).PacketOrder==channels(channelIndex));
        loc = FileInfo(fileIndex).HeaderSize + FileInfo(fileIndex).Locations(PacketNumbers);
        [wav, times, units] = readWaveforms2(loc,numSamples, FileInfo(fileIndex).filename); 
        WaveformInfo(channelIndex).Channel = channels(channelIndex);
        WaveformInfo(channelIndex).Waveforms = [WaveformInfo(channelIndex).Waveforms; wav'];
        WaveformInfo(channelIndex).Unit = [WaveformInfo(channelIndex).Unit; units];
        try 
            WaveformInfo(channelIndex).Times = [WaveformInfo(channelIndex).Times; double(times)/FileInfo(fileIndex).TimeResolutionTimeStamps*1000];
        catch ME
            if ~gaveWarning&&strcmp(ME.identifier,'MATLAB:nonExistentField')
                warning(ME.identifier,ME.message);
                gaveWarning = true;
            elseif ~strcmp(ME.identifier,'MATLAB:nonExistentField')
                warning(ME.identifier,ME.message);
            end
        end
    end
end

waveforms = WaveformInfo;
end

function waveforms = nevWaveforms_sparse(filenames,channels,nWaveforms)
%function waveforms = nevWaveforms_sparse(filenames,channels,nWaveforms)
%
% filenames can be a single string or a cell array of strings
% channels is optional, uses all channels by default
%
% This is the sparse reading version that defaults to 50k waveforms
    
clear global FileInfo
global loc;
global FileInfo;
global WaveformInfo;

if nargin<3||isempty(nWaveforms)
    nWaveforms = 5e4; %read 50000 waveforms by default
end

FileInfo=struct('filename',[],'format','nev','HeaderSize',0,...
    'PacketSize',0,'ActiveChannels',[],'PacketOrder',uint8([]),...
    'SpikesNumber',[],'BytesPerSample',0,'nSpikesToReadPerChannel',nWaveforms); %initialize FileInfo structure

if iscell(filenames)
    for I=1:length(filenames)
        FileInfo(I).filename = filenames{I};
    end
else
    FileInfo(1).filename = filenames;
end

ActiveChannelList=[];

for i = 1:length(FileInfo)
    spikesort_nevscan(i,false); 
    ActiveChannelList = union(ActiveChannelList,FileInfo(i).ActiveChannels);
    FileInfo(i).maskedPacketOrder = FileInfo(i).PacketOrder;
end

assert(max(ActiveChannelList)<intmax(class(FileInfo(1).PacketOrder)),'Maximum active channel index equals maximum value for packet order class');

%choose a subset of spikes to read from disk:
for ch =1:numel(ActiveChannelList)
    [PacketNumbers,cumulativePn] = deal({[]});
    for i=1:length(FileInfo)
        PacketNumbers{i} = find(FileInfo(i).PacketOrder == ActiveChannelList(ch));
        if i>1
            %add the number of events from previous files to the packet
            %numbers from this file:
            cumulativePn{i} = PacketNumbers{i}+numel(vertcat(FileInfo(1:i-1).PacketOrder));
        else
            cumulativePn{i} = PacketNumbers{i};
        end
    end
    allPn = vertcat(cumulativePn{:});
    subset = allPn(randperm(numel(allPn),min(FileInfo(1).nSpikesToReadPerChannel,numel(allPn))));
    for i=1:length(FileInfo)
        %If the packet isn't in the subset, then set the packet order
        %to be greater than the maximum active channel index to ignore it:
        FileInfo(i).maskedPacketOrder(PacketNumbers{i}(~ismember(cumulativePn{i},subset))) = max(ActiveChannelList)+1;
    end
end

if nargin < 2 || isempty(channels) 
    channels = ActiveChannelList;
end

if length(unique([FileInfo(:).PacketSize]))~=1
    error('Variable Packet Sizes');
end

WaveformSize=(FileInfo(1).PacketSize-8)/FileInfo(1).BytesPerSample;
ByteLength=['int' num2str(FileInfo(1).BytesPerSample*8)];

numSamples = (FileInfo(1).PacketSize-8)/2;

gaveWarning = false; 
for channelIndex = 1:length(channels)
    WaveformInfo(channelIndex).Waveforms = [];
    WaveformInfo(channelIndex).Unit = [];
    WaveformInfo(channelIndex).Times = [];
    for fileIndex = 1:length(FileInfo)
        
        PacketNumbers = FileInfo(fileIndex).maskedPacketOrder==channels(channelIndex);
        loc = FileInfo(fileIndex).HeaderSize + FileInfo(fileIndex).Locations(PacketNumbers);
        [wav, times, units] = readWaveforms2(loc,numSamples, FileInfo(fileIndex).filename); 
        WaveformInfo(channelIndex).Channel = channels(channelIndex);
        WaveformInfo(channelIndex).Waveforms = [WaveformInfo(channelIndex).Waveforms; wav'];
        WaveformInfo(channelIndex).Unit = [WaveformInfo(channelIndex).Unit; units];
        try 
            WaveformInfo(channelIndex).Times = [WaveformInfo(channelIndex).Times; double(times)/FileInfo(fileIndex).TimeResolutionTimeStamps*1000];
        catch ME
            if ~gaveWarning&&strcmp(ME.identifier,'MATLAB:nonExistentField')
                warning(ME.identifier,ME.message);
                gaveWarning = true;
            elseif ~strcmp(ME.identifier,'MATLAB:nonExistentField')
                warning(ME.identifier,ME.message);
            end
        end
    end
end

waveforms = WaveformInfo;
end
