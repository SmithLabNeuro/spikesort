function [ dat,nevfile ] = sort2bcistruct(maskFile,nevFile,gammaVal)

% This function takes in the classification mask from the neural network and
% generates a bci struct.

    addpath('~/Dropbox/smithlab/matlab/utils');
    addpath(genpath('~/Dropbox/smithlabrig/Ex/ex_bci/structBuilders/'));

    % load mask file (if string input)
    fprintf('Loading mask file...\n');
    if ischar(maskFile)
        load(maskFile,'pSpike'); %load mask
    else
        pSpike = maskFile;
        clear maskFile;
    end
    
    % read NEV file
    fprintf('Reading nev file...\n')
    nevfile = readNEV(nevFile);
    
    % apply the mask
    fprintf('Applying mask...\n')
    slabel = zeros(size(pSpike)); %spike classification
    slabel(pSpike>gammaVal) = 1;
    slabel(nevfile(:,1)==0) = 0; % need to make sure digital code indices in the mask aren't 1
    clear nn_labels;
    nevfile(slabel==1,2) = 1; % move to sort code 1
    
    % generate bci struct
    fprintf('Generating bci struct...\n')
    dat = nev2bcistruct(nevfile,'nevreadflag',1);
    
end