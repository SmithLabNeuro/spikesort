function [sortCode] = mogSorter2(waves,m,nClusters,options)


if nargin < 3
    options = mogSortOptions();
end

samplesPerWaveform = size(waves,1);
nWaveform = size(waves,2);

sortCode = double.empty(nWaveform,0);
% if sum(isempty(m(nClusters,:))) == 30
%     return
% end

waves = double(waves);
% If the waveforms don't match our template, improvise
if samplesPerWaveform <= size(options.template,1)
    options.template = options.template(1:samplesPerWaveform);
else
    options.template = [options.template;options.template(end)*ones(samplesPerWaveform-size(options.template,1))];
end

thresholdVec = max(abs(waves)) <= options.voltageThreshold; % Threshold Detector

varVec =  var(waves) <= options.varianceMax; % Variance detector

fftWave = abs(fft(waves));
fftWave = fftWave(1:samplesPerWaveform/2, :);   %fft is symmetric, only need first half
fftWaveMax = max(real(fftWave), [], 1);
freqVec = fftWaveMax <= options.freqThreshold; % Frequency Detector

%templateCorr = corr(waves, options.template);
%templateCorrVec = templateCorr > options.noiseCorrThreshold;
selectionVec = thresholdVec & varVec & freqVec;
%selectionVec = selectionVec & templateCorrVec';

%selectionVec = true(1,nWaveform);
pcaIndexVec = true(1,nWaveform);
condition = true;      % Ensures the loop executes at least once

% Beginning of loop - iterate while there is a zscore greater than 4
while condition
    waveformOK = waves(:,selectionVec & pcaIndexVec);
    % Additional check if too few waves to do PCA
    if size(waveformOK,2) < samplesPerWaveform
        fprintf('Too few waves to do PCA,failed to sort!\n');
        return;
    end
    
    %% PCA
    % update the PCA each day
    [~, score] = pca(double(waveformOK)', 'rows', 'complete');
   
    %% Find large coefficients
    % Mean and z scores of the coefficients
    meanScore = mean(score, 2)';
    zscoreScore = zscore(meanScore)';
    
    % Initialize the score vector and counter
    scoreVec = ones(1,nWaveform);
    counter = 0;
    
    % Loop through spikes and flag high coefficients for indexVec
    for iSpike = 1:nWaveform
        if selectionVec(1, iSpike) && pcaIndexVec(1, iSpike)   %only check zscores for the waves used in pca
            counter = counter + 1;
            if zscoreScore(counter) > options.highScoreZScore % Flag the high scores
                scoreVec(1, iSpike) = 0;
            end 
        end
    end % End of spike loop to flag high coefficients
    % Combine pcaIndexVec and scoreVec

    scoreVec = logical(scoreVec);
    pcaIndexVec = scoreVec & pcaIndexVec;
    
    % Check condition for while loop - if no waves were thrown out
    % during this round, exit loop

    if sum(scoreVec) == nWaveform   % Since we are reinitializing scoreVec with every round of PCA
        condition = false;
    end
end % End of while loop (iterative PCA)
selectionVec = selectionVec & pcaIndexVec;


numPcaDimensionsToUse = options.numPcaDimensionsToUse;
fitOptions = statset('MaxIter',options.maxClusterIter,'TolFun',options.clusterErrorTolerance);

allDat = score(:, 1:numPcaDimensionsToUse);
result = m(nClusters,find(~isempty(m(nClusters,:)),1,'last'));
clusterMembership = cluster(result.obj,allDat);

% Preallocate vec of min errors for each cluster
minErr = zeros(size(waves, 2), nClusters);
indexErr = zeros(size(waves, 2), nClusters);

% Cluster loop to get shifted waves and error

for nCluster = 1:nClusters
    
    % Get shifted waves
    
    % Mean of the waves from the cluster
    waveInds = find(selectionVec);
    clusterWaves = waves(:,waveInds(clusterMembership == nCluster));
    meanWave = mean(clusterWaves, 2);
    clusterMean(1, nCluster) = mean(meanWave);
    clusterSd(2, nCluster) = std(meanWave);
    % Shift the mean waves up to 20 samples
    numSamplesToShift = options.numSamplesToShift;
    temporarySignal = [0; meanWave]; % Add nan that will be used to fill in missing values
    sigLength = length(meanWave);
    pointer = ones(sigLength, numSamplesToShift);
    [r,c] = find(pointer);
    inds = sub2ind(size(pointer),r,c);
    pointer(inds) = r(inds)-c(inds)+2; % Add 2 since we appended an nan
    pointer(r<c) = 1; % Fill in things above the diagonal with nans
    shiftedWaves = temporarySignal(pointer); % Shifted means
    clear temporarySignal;
    
    %% Min error between total waveform and shifted waves
    waveErr = pdist2(waves', shiftedWaves');
    [minErrVec,indexShift] = min(waveErr,[],2);
    minErr(:, nCluster) = minErrVec;
    indexErr(:, nCluster) = indexShift;
    
end % End cluster loop to get min error
%% Shift the waves

% Preallocate
waveAlign = zeros(size(waves));
nRand = 100; % number of random numbers to generate

% Spike loop to shift waves
for iSpike = 1:size(waves, 2)
    
    % For each spike, get the shift where that wave had the min error
    [~, clusterMin] = min(minErr(iSpike, :));  % get the max corr
    
    if indexErr(iSpike, clusterMin) == 1 % don't shift the wave if it is only shifted by one timepoint
        waveAlign(:, iSpike) = waves(:, iSpike);
    else % Shift the wave
        
        startSpike = indexErr(iSpike, clusterMin) + 1;
        nanIndex = samplesPerWaveform - indexErr(iSpike, clusterMin);
        waveAlign(1:nanIndex, iSpike) = waves(startSpike:end, iSpike);
        
        % Fill in extra space in spike with random numbers
        nToFill = samplesPerWaveform - nanIndex;
        randNum = clusterMean(clusterMin) + randn(nRand, 1);
        
        waveAlign(nanIndex + 1:end, iSpike) = randNum(1:nToFill);        
    end
end % End of spike loop to shift waves

pcaIndexVec = true(1, size(waves, 2));
condition = true;      % Ensures the loop executes at least once

% Beginning of loop - iterate while there is a zscore greater than 4
while condition
    waveformOK = waveAlign(:,selectionVec & pcaIndexVec);
    
    % Additional check if too few waves to do PCA
    if size(waveformOK, 2) < samplesPerWaveform
        fprintf('Too few waves to do PCA,failed to sort!\n');
        return
    end
    
    %% PCA
    % update the PCA each day
    [~, score] = pca(double(waveformOK)', 'rows', 'complete');
    
    %% Find large coefficients
    % Mean and z scores of the coefficients
    meanScore = mean(score, 2)';
    zscoreScore = zscore(meanScore)';
    
    % Initialize the score vector and counter
    scoreVec = ones(1, size(waves, 2));
    counter = 0;
    
    % Loop through spikes and flag high coefficients for indexVec
    for iSpike = 1:size(waves, 2)
        if selectionVec(1, iSpike) && pcaIndexVec(1, iSpike)   %only check zscores for the waves used in pca
            counter = counter + 1;
            if zscoreScore(counter) > options.highScoreZScore % Flag the high scores
                scoreVec(1, iSpike) = 0;
            end
        end
    end % End of spike loop to flag high coefficients
    % Combine pcaIndexVec and scoreVec
    
    scoreVec = logical(scoreVec);
    pcaIndexVec = scoreVec & pcaIndexVec;
    
    % Check condition for while loop - if no waves were thrown out
    % during this round, exit loop
    
    if sum(scoreVec) == size(waves, 2)    % Since we are reinitializing scoreVec with every round of PCA
        condition = false;
    end
end % End of while loop (iterative PCA)
selectionVec = selectionVec & pcaIndexVec;
allDat = score(:, 1:numPcaDimensionsToUse);

% Now fit the selected model to the full dataset:
count = 0; error_count = 0;
while count == error_count
    result = [];
    try
        result = gmdistribution.fit(allDat,nClusters,'options',fitOptions,'replicates',1,'start','plus','Regularize', 1e-5);
    catch 
        error_count = error_count+1;
    end
    count = count+1;
end
clusterFinal = cluster(result,allDat);

% Get sort codes into a vec for each wave
goodCounter = 0;
for iSpike = 1:nWaveform
    if selectionVec(iSpike)   % Waves that made it through to the end
        goodCounter = goodCounter + 1;
        sortCode(iSpike,1) = clusterFinal(goodCounter);
    else    % Waves that were thrown out at some point
        sortCode(iSpike,1) = 255;
    end % End of selectionVec loop
end % End of spike loop
% end % End of nSpikeFlag loop


