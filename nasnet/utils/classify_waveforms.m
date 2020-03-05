%
% classify waveforms using NASnet
%
% INPUTS:
%   -either a .nev or a .mat file
% OUTPUTS:
%   -classification labels
% OPTIONS:
%   -save classification labels into a .mat file
%   -write classification labels as sortcodes into the nev file 
%    (spikes=1, noise+artifacts=255)
%

%% specs

% mat or nev file containing the waveforms
filename   = 'Pe160527_s98ax_fixAndMultistim_movie_0001';
ext        = '.mat';

paths      = mypaths;
datapath   = paths{1};
labelspath = paths{2};
netpath    = paths{3};

% write classification labels as sortcodes into nev file
writelabels = false;
% save classification labels as a .mat file
savelabels  = true;

% channels to run classification on
chan = 1:96; % if empty all channels are read

% choose regular network or network trained to identify uStim artifacts
artifact  = false;
% classification threshold (anything waveform with probability>gamma will
% be classified as a spike/artifact)
gamma     = 0.8;

if artifact
    netName   = 'uStimNet_artifact';
else
    netName   = 'uStimNet';
end

g = num2str(gamma);
g = [g(1) g(3:end)];

filepath   = [datapath filename ext];
netpath    = [netpath netName];
labelspath = [labelspath filename '_' netName '_gamma' g];


%% run classfication and save labels

[slabel,spikes] = runNASNet(filepath,gamma,netpath,'channels', chan, ...
    'writelabels',writelabels);

if savelabels
    disp('saving new labels...')
    if artifact
        artifacts = spikes;
        save(labelspath,'artifacts')
    else
%         save(filepath,'spikes','-append')
        save(labelspath,'spikes')
    end
end
