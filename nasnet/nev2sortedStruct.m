function [ dat,nevfile ] = nev2sortedStruct(nevFile,gammaVal,saveFlag)

% This function takes in the classification mask from the neural network and
% generates a bci struct.

    % check for optional saveFlag argument (default is to save)
    if ~exist('saveFlag','var');saveFlag=1;end

    % make sure these two directories are in your path
    addpath('~/Dropbox/smithlab/matlab/utils');
    addpath(genpath('~/Dropbox/smithlabrig/Ex/ex_bci/structBuilders/'));

    % classify spikes
    fprintf('Classifying spikes...\n');
    pSpike = classifySpikes(nevFile);
    
    % convert to bci struct
    fprintf('Creating structure...\n');
    for i_val = 1:length(gammaVal)
        [dat,nevfile] = sort2bcistruct(pSpike,nevFile,gammaVal(i_val));

        % save file
        if saveFlag == 1
            fprintf('Saving file...\n');
            saveFname = sprintf('%s_000%d_sort%.1f.mat',nevFile(1:8),str2double(nevFile(end-4)),gammaVal(i_val));
            save(saveFname,'dat');
        end
    end
    
end