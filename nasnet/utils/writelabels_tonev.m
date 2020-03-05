%
% Write classified waveform labels (sortcodes) to nev file
% (spikes=1, noise+artifacts=255)
% This script allows you to combine labels if multiple networks have been 
% trained independently to identify either spikes or artifacts
%

%% data
filename   = 'Pe160527_s98ax_fixAndMultistim_movie_0001';

% load classification labels from network "netName", at classification
% threshold "gamma"
netName    = 'uStimNet';
gamma      = '08';

% load additional labels from a network trained specifically to detect
% uStim artifacts and combine them with the previous labels
rm_artifacts = true;
agamma       = '02'; 

% channels (make sure your list of labels was generated for these channels)
chan = 1:96; %if empty all channels are read.

% 512 is the highest available number of spike channels 
% (see Trellis NEV Spec manual)
maxspikech = 512;

%% pahts
paths      = mypaths;

datapath   = paths{1};
labelspath = paths{2};

nevfile    = [datapath filename '.nev'];

% labels/sortcodes are stored in spikes(:,2)
disp('loading classified data labels (spikes vs noise)...')
load([labelspath filename '_' netName '_gamma' gamma],'spikes');

if rm_artifacts
    disp('loading additional labels for detected artifacts in data...')
    load([labelspath filename '_' netName '_artifact_gamma' agamma],...
        'artifacts');
    % move artifacts to noise
    spikes(logical(artifacts(:,2)),2)=0;
end

%% spikes and noise labels

% move spikes to sort code 1 and noise to sort code 255
sortcodes = spikes(:,2)*1 + ~spikes(:,2)*255;

% which waveforms to overwrite
spikesidx = ones(size(spikes,1),1);

% set write=false for digital codes
% do the same for special channels which do not contain spiking data,
% for example channels for uStim
% (although moveToSortCode should already protect from doing that)
spikesidx(spikes(:,1)==0)         = 0;
sortcodes(spikes(:,1)==0)         = 0;
spikesidx(spikes(:,1)>maxspikech) = 0;
sortcodes(spikes(:,1)>maxspikech) = 0;


moveToSortCode(nevfile,spikesidx,sortcodes,'channels',chan);

