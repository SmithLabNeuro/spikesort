
% create .mat data for NASnet training

%% specs

% labelled (hand-sorted) data
filename = 'Pe160513_s84ax_fixAndMultistim_movie_0001.nev';

% data path and path to save .mat formated training data
paths      = mypaths;
datapath   = paths{1};
trdatapath = paths{4};

% channels
chan = 1:96; % if empty use all channels

% train to detect spikes or to detect artifacts
artifact = false;

if artifact
    savename = 'ustim_handsorted_data_artifact';
else
    savename = 'ustim_handsorted_data';
end

%% read nev

[spikes,waves] = read_nev([datapath filename],'channels',chan);

disp('checking that channels are valid...')
% 512 is the highest available number of spike channels 
% (see Trellis NEV Spec manual)
maxspikech = 512;
channels   = unique(spikes(:,1));

disp('Warning: the next operations may take some time, if the file size is too big')

if ~isempty(find(channels==0,1))
    % These are digital codes. There are no waveforms to classify for
    % these indices, delete them
    disp('removing digital codes...')
    waveforms(spikes(:,1)==0)  = [];
    spikes(spikes(:,1)==0)     = [];
end
if ~isempty(find(channels>=maxspikech,1))
    % Same for non-spike data channels, such as uStim channels
    disp('removing non-spike channels...')
    waveforms(spikes(:,1)>=maxspikech) = [];
    spikes(spikes(:,1)>=maxspikech)    = [];
end

disp('converting cell array into a matrix...')
waves = [waves{:}]';

%%
% append sort codes
disp('appending sort codes...')
waveData = [nan(size(waves,1),1),waves];

% look for noise (0) and ustim artifacts (255). The rest are spikes
idx0   = spikes(:,2)==0;
idx255 = spikes(:,2)==255;
idx1   = ~idx0.*~idx255;

if artifact
    idx = idx255;
else
    idx = idx1;
end

disp('proportion of waveforms classified as...')
fprintf('spikes = %.2f \n', length(find(idx1))/length(idx));
fprintf('noise  = %.2f \n', length(find(idx0))/length(idx));
fprintf('uStim artifacts = %.2f \n', length(find(idx255))/length(idx));

% spikes (or ustim artifacts)
waveData(logical(idx),1)  = 1;
% noise+artifacts (or spikes+noise)
waveData(logical(~idx),1) = 0;


if ~isempty(find(isnan(waveData(:,1)),1))
error('Some waveforms could not be classified as either spikes or noise')
end

disp('saving labelled waveforms...')
% note that NASnet only supports -v7.3 mat format
save([trdatapath savename],'waveData','-v7.3')
% save training labels information in spikes (channels,sortcodes,time)
save([trdatapath savename '_spikes'],'spikes')
