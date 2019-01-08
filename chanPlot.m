function waves = chanPlot(fname,channel,varargin)
%function chanPlot(fname,channel)
%
% Takes as input a NEV filename string and a list of channels, and
% plots the spike image for those channels. Can take optional
% name/value pair arguments:
%
% 'plotType' - errorshade (mean +/- SEM), spikesort (using
%       genSpikeMap, the default option), plot (plots every waveform)
% 'numWaves' - number of waveforms to plot
% 'resolution' - pixel size of output image (defaults to 800)
% 'uvoltLimit' - Y limit of plot (defaults to 500 uV)

% Takes as input a filename string along with a channel, then plots the spike image
%

global WaveformInfo;
global FileInfo;

p = inputParser;

% uvoltLimit input should be a single numble or a row vector
p.addOptional('uvoltLimit',500,@isnumeric);
p.addOptional('plotType','spikesort',@ischar); % errorshade, spikesort, plot
p.addOptional('numWaves',-1,@isnumeric);
p.addOptional('resolution',800,@isnumeric);
p.addOptional('nonoise',false,@islogical);

p.parse(varargin{:});

uvoltLimit = p.Results.uvoltLimit;
plotType = p.Results.plotType;
resolution = [p.Results.resolution p.Results.resolution];
numWaves = p.Results.numWaves;

assert(numel(uvoltLimit)==1 || (ismatrix(uvoltLimit) && numel(uvoltLimit)==numel(channel)),'Invalid uvolt limit');
assert(sum(strcmp(plotType,{'spikesort','errorshade','plot'})) == 1,'Invalid plot type');

colors = [
    [0 0 0] % black (sort code 0, unsorted)
    [1 0 0] % red (sort code 1)
    [0 1 0] % green (sort code 2)
    [0 0 1] % blue (etc)
    [1 0 1] % magenta
    [0 1 1] % cyan
    [1 0 .5] % pink
    [1 .5 0] % orange
    [1 1 0] % yellow
    [.5 0 .5] % purple
    [0 1 .5] % sea foam green
    [.5 .5 0] % bronze
    [0 .5 .5] % teal
    [.5 0 1] % light purple
    [0 .5 1] % light blue
    [.5 1 0] % chartreuse
    ];
colors(256,:) = [.7 .7 .7];
colors1 =colors;
% for imagesc
colors = 1 - colors;
for i = 1:size(colors,1)
    colors(i,:) = colors(i,:) ./ sqrt(sum(colors(i,:).^2));
end

colors(1,:) = colors(1,:)/2;

% for plot
for i = 1:size(colors1,1)
    colors1(i,:) = colors1(i,:) ./ sqrt(sum(colors1(i,:).^2));
end

colors1(1,:) = colors1(1,:)/2;

% load all the spike waveforms into the WaveformInfo global
spikeDisplayC({fname},channel);
waves = WaveformInfo;

if nargout < 1
    figure;hold on;
    % for plot comparison
    %     fig = get(groot,'CurrentFigure');
    %     if isempty(fig)
    %         figure;
    %     end
    if numel(uvoltLimit) == 1
        uvoltLimit = uvoltLimit .* ones(1,numel(channel)); % row vector
    end
    %% loop over j
    y1 = inf*ones(numel(channel),1); y2=-inf*ones(numel(channel),1); x1 = ones(numel(channel),1);x2=ones(numel(channel),1);
    for j=1:numel(channel)
        subplot(numel(channel),1,j);
        
        %  nvscale(j) = FileInfo.nVperBit(uprobechan(j));
%         units = unique(WaveformInfo(j).Unit);
        
        y1(j) = double(min(min(WaveformInfo(j).Waveforms)));
        y2(j) = double(max(max(WaveformInfo(j).Waveforms)));
        x1(j) = 1; x2(j) = size(WaveformInfo(j).Waveforms,2);
        
        % identify non-zero and non-255 waveforms
        %p = find(WaveformInfo(j).Unit > 0 & WaveformInfo(j).Unit < 255);
        
        % find all waveforms
        n = find(WaveformInfo(j).Unit >= 0 & WaveformInfo(j).Unit <= 255);
        if numWaves > 0 && length(n)>=numWaves
            n=n(randperm(length(n),numWaves));
        end
        if strcmp(plotType,'errorshade')
            wv=WaveformInfo(j).Waveforms(n,:);
            errorshade(1:x2(j),nanmean(double(wv),1),nanstd(double(wv)));
            title(sprintf('Channel %i',channel(j)));
        elseif strcmp(plotType,'spikesort')
            im = genSpikeMapColor(WaveformInfo(j).Waveforms(n,:), ...
                WaveformInfo(j).Unit(n),resolution(1),resolution(2),y1(j),y2(j),colors,max(1,round(log10(length(n)/10))));
            
            nvscale=FileInfo.nVperBit(FileInfo.nVperBit>0);
            disp(nvscale);
            
            % conversion factor for uV
            uvolt = nvscale(1)*.001;
            
            % convert to milliseconds
            msec = x2(j)/FileInfo.SamplingRate;
            imagesc([x1(j) x2(j)],[y1(j)*uvolt y2(j)*uvolt],1-im);
            axis xy; axis on;
            box off;
            xlim([0 x2(j)]);
            % scale
            xvalms = 0:0.2:1.6;
            %xtvals = get(gca,'xtick');
            set(gca,'xtick',(xvalms./msec)*x2(j));
            set(gca,'xticklabel',num2cell(xvalms));
            ylim([-uvoltLimit(1,j),uvoltLimit(1,j)]);
            %ylim([min(y1) max(y2)]);
            set(gca,'ytick',-uvoltLimit(1,j):2*uvoltLimit(1,j)/5:uvoltLimit(1,j));
            set(gca,'yticklabel',num2cell(get(gca,'ytick')));
            %set(gca,'tickdir','out');
            title(sprintf('Channel %i',channel(j)));
           
            
        elseif strcmp(plotType,'plot')
            nvscale=FileInfo.nVperBit(FileInfo.nVperBit>0);
            disp(nvscale);
            
            % conversion factor for uV
            uvolt = nvscale(1)*0.001;
            
            % convert to milliseconds
            msec = x2(j)/FileInfo.SamplingRate;
            sortcodes = unique(WaveformInfo(j).Unit(n));
            plot(WaveformInfo(j).Waveforms((WaveformInfo(j).Unit(n)==255),:)'.*uvolt,'Color',colors1(256,:));
            for i = 1:length(sortcodes)-1
                plot(WaveformInfo(j).Waveforms((WaveformInfo(j).Unit(n)==sortcodes(i)),:)'.*uvolt,'Color',colors1(i+1,:));
            end
            xlim([0 x2(j)]);
            % scale
            xvalms = 0:0.2:1.6;
            %xtvals = get(gca,'xtick');
            set(gca,'xtick',(xvalms./msec)*x2(j));
            set(gca,'xticklabel',num2cell(xvalms));
            ylim([-uvoltLimit(1,j),uvoltLimit(1,j)]);
            %ylim([min(y1) max(y2)]);
            set(gca,'ytick',-uvoltLimit(1,j):2*uvoltLimit(1,j)/5:uvoltLimit(1,j));
            set(gca,'yticklabel',num2cell(get(gca,'ytick')));
            %set(gca,'tickdir','out');
            title(sprintf('Channel %i',channel(j)));
        end
    end
end

function spikes = spikeDisplayC(filenames,channels)
global loc;
global FileInfo;
global WaveformInfo;

FileInfo=struct('filename',[],'format','nev','HeaderSize',0,...
    'PacketSize',0,'ActiveChannels',[],'PacketOrder',uint8([]),...
    'SpikesNumber',[],'BytesPerSample',0); %initialize FileInfo structure

for i=1:length(filenames)
    FileInfo(i).filename=filenames{i} ;
end

ActiveChannelList=[];

for i = 1:length(FileInfo)
    spikesort_nevscan(i,false);
    
    ActiveChannelList = union(ActiveChannelList,FileInfo(i).ActiveChannels);
end

if length(unique([FileInfo(:).PacketSize]))~=1
    error('Variable Packet Sizes');
end

WaveformSize=(FileInfo(1).PacketSize-8)/FileInfo(1).BytesPerSample;
%ByteLength=['int' num2str(FileInfo(1).BytesPerSample*8)];

totalSpikes = NaN(length(channels),1);
for j = 1:length(channels)
    totalSpikes(j) = 0;
    for i = 1:length(FileInfo)
        totalSpikes(j) = totalSpikes(j) + length(find(FileInfo(i).PacketOrder==channels(j)));
    end
end

for channelIndex = 1:length(channels)
    WaveformInfo(channelIndex).Waveforms=[];
    WaveformInfo(channelIndex).Unit=[];
    WaveformInfo(channelIndex).Times=[];
    
    for fileIndex = 1:length(FileInfo)
        PacketNumbers= FileInfo(fileIndex).PacketOrder==channels(channelIndex);
        loc = FileInfo(fileIndex).HeaderSize + FileInfo(fileIndex).Locations(PacketNumbers);
        if isempty(loc)
            
        else
            [wav, times, units] = readWaveforms2(loc,WaveformSize, FileInfo(fileIndex).filename);
            WaveformInfo(channelIndex).Waveforms =cat(1,WaveformInfo(channelIndex).Waveforms,wav');
            WaveformInfo(channelIndex).Unit = cat(1,WaveformInfo(channelIndex).Unit,units);
            WaveformInfo(channelIndex).Times = cat(1,WaveformInfo(channelIndex).Times,double(times)/FileInfo(fileIndex).TimeResolutionTimeStamps*1000);
        end
    end
end



