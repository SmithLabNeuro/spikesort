
% create .mat data file for NASnet classification
%
% using runNASNet for classification is much faster on .mat files, because
% .nev files have to be read and formated every time one wants to apply the
% network for classification. If you are only interested in obtaining the
% classification labels, without writing the results into the nev file, 
% working on mat files is more convenient.

%% specs

% nev file (do not specify the .nev extension)
filename = 'Pe160525_s96ax_fixAndMultistim_movie_0001';

paths    = mypaths;
datapath = paths{1};
filepath = [datapath filename];

% select channels 
chan     = 1:96; % if empty use all channels

%% read nev

[spikes,waveforms] = read_nev([filepath '.nev'],'channels',chan);

disp('checking that channels are valid...')
% 512 is the highest available number of spike channels 
% (see Trellis NEV Spec manual)
maxspikech = 512;
channels   = unique(spikes(:,1));

disp('Warning: the next operations may take some time, if file size is too big')

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
waveforms = [waveforms{:}]';

% save file (in same folder as nev file)
% note that NASnet only supports -v7.3 mat format
disp('saving waveforms in mat v7.3 formated file...')
save(filepath,'waveforms','spikes','-v7.3')
