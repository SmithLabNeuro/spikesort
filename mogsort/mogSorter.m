function [bestModel,m] = mogSorter(waves,options,varargin)
%function sortCode = mogSorter(waves,options)
% 52*n

if nargin < 2
    options = mogSortOptions();
end

%sc = options.WaveformInfoUnits;
samplesPerWaveform = size(waves,1);
nWaveform = size(waves,2);

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
        bestModel = nan;
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

%% Get a subset of randomly chosen waves from the included data
subsetSize = options.subsetSize;
subsetDat = randperm(sum(selectionVec), min(sum(selectionVec), subsetSize));
dat = score(subsetDat, 1:numPcaDimensionsToUse);

%% Get number of clusters to use based on sort options
if options.guessClusters
    eva =  evalclusters(dat,'kmeans','CalinskiHarabasz','KList',options.nClusters);
    nOptimalClusters = eva.OptimalK;
    maxClusterNum = nOptimalClusters + options.clusterNumStep;
    minClusterNum = nOptimalClusters - options.clusterNumStep;
    
    if minClusterNum <= 0
        minClusterNum = 1;
    end
    
    nClusters = minClusterNum:maxClusterNum;
else
    nClusters = options.nClusters;
end

% Number of clusters and folds to use
numFolds = options.numFolds; 

% Define a random partition in the data of a specified size
holdoutProportion = options.holdoutProportion;

% Preallocate
[bic,negLL] = deal(nan(numel(nClusters),1));
m = deal(struct('obj',{[]}));

%% Cluster loop
% Update the PCA space (1.Fresh model fit)
for clusterIdx = 1:numel(nClusters)
    if options.prior(clusterIdx) ~=0
        % Try catch for ill conditioned covariance matrix
        try
            % Training data
            cvo = cvpartition(size(dat,1),'holdout',holdoutProportion); %object that generates indices of training and test data for x-validation
            m(clusterIdx,1).obj = gmdistribution.fit(dat(cvo.training,:),nClusters(clusterIdx),'options',fitOptions,'replicates',1, 'start', 'plus','Regularize', 1e-5); %the 'm' is for 'model'
            
            % get the (negative log) likelihood of the test data
            [~,negLL(clusterIdx,1)] = m(clusterIdx,1).obj.posterior(dat(cvo.test,:));
            bic(clusterIdx,1) = m(clusterIdx,1).obj.BIC;
            
        catch ME
            switch(ME.identifier)
                case {'stats:gmdistribution:MisshapedInitSingleCov','stats:gmdistribution:IllCondCovIter'}
                    count = 0;error_count = 0;
                    while count == error_count
                        if count >= options.maxRetry
                            fprintf('Fail to fit GM model in %d tries',options.maxRetry);
                            negLL(clusterIdx,1) = nan;
                            break;
                        end
                        try
                            m(clusterIdx,1).obj = gmdistribution.fit(dat(cvo.training,:),nClusters(clusterIdx),'options',fitOptions,'replicates',1, 'start', 'plus','Regularize', 1e-5);
                            [~,negLL(clusterIdx,1)] = m(clusterIdx,1).obj.posterior(dat(cvo.test,:)); %get the (negative log) likelihood of the test data
                            bic(clusterIdx,1) = m(clusterIdx,1).obj.BIC;
                        catch
                            error_count = error_count + 1;
                        end % end of inner try-catch
                        count = count + 1;
                    end
                otherwise
                    rethrow(ME);
            end % End of switch case on ME.identifier
        end % End of try catch
        
    else
        negLL(clusterIdx,1) = nan;
    end
end % End of clusters loop
% Sanity check of last resort that we got a fit:
assert(~all(isnan(negLL(:))),'Couldn''t fit the data!'); %if all the entries of negLL are NaN then no fit was ever successful

% Figure out the best model
meanNegLL = negLL;
nanflag = ~isnan(meanNegLL);
[~,Idx] = min(meanNegLL(nanflag));
flag = find(nanflag);
bestModelIdx = flag(Idx);
bestModel = nClusters(bestModelIdx); % actual # of clusters

% Now fit the selected model to the full dataset:
allDat = score(:,1:numPcaDimensionsToUse);
count = 0; error_count = 0;
while count == error_count
    result = [];
    try
        result = gmdistribution.fit(allDat,bestModel,'options',fitOptions,'replicates',1,'start','plus','Regularize', 1e-5);
    catch 
        error_count = error_count+1;
    end
    count = count+1;
end
clusterMembership = cluster(result,allDat);

% Preallocate vec of min errors for each cluster
minErr = zeros(size(waves, 2), bestModel);
indexErr = zeros(size(waves, 2), bestModel);

% Cluster loop to get shifted waves and error

for nCluster = 1:bestModel
    
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
        bestModel = nan;
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

numPcaDimensionsToUse = options.numPcaDimensionsToUse;
fitOptions = statset('MaxIter',options.maxClusterIter,'TolFun',options.clusterErrorTolerance);

%% Get a subset of randomly chosen waves from the included data
subsetSize = options.subsetSize;
subsetDat = randperm(sum(selectionVec), min(sum(selectionVec), subsetSize));
dat = score(subsetDat, 1:numPcaDimensionsToUse);

%% Get number of clusters to use based on sort options
% 1.Fresh model fit - use 'evalclusters' to guess optimal cluster number or
%                     use default cluster number
if options.guessClusters
    eva =  evalclusters(dat,'kmeans','CalinskiHarabasz','KList',options.nClusters);
    nOptimalClusters = eva.OptimalK;
    maxClusterNum = nOptimalClusters + options.clusterNumStep;
    minClusterNum = nOptimalClusters - options.clusterNumStep;
    
    if minClusterNum <= 0
        minClusterNum = 1;
    end
    
    nClusters = minClusterNum:maxClusterNum;
else
    nClusters = options.nClusters;
end

% Number of clusters and folds to use
numFolds = options.numFolds;

% Define a random partition in the data of a specified size
holdoutProportion = options.holdoutProportion;

% Preallocate
[bic,negLL] = deal(nan(numel(nClusters),numFolds));
m = deal(struct('obj',{[]}));

%% Cluster loop
% Update the PCA space (1.Fresh model fit)
for clusterIdx = 1:numel(nClusters)
    if options.prior(clusterIdx) ~=0
        % CV Folds loop
        for cvf = 1:numFolds
            % Try catch for ill conditioned covariance matrix
            try
                % Training data
                cvo = cvpartition(size(dat,1),'holdout',holdoutProportion); %object that generates indices of training and test data for x-validation
                m(clusterIdx,cvf).obj = gmdistribution.fit(dat(cvo.training,:),nClusters(clusterIdx),'options',fitOptions,'replicates',1, 'start', 'plus','Regularize', 1e-5); %the 'm' is for 'model'
                
                % get the (negative log) likelihood of the test data
                [~,negLL(clusterIdx,cvf)] = m(clusterIdx,cvf).obj.posterior(dat(cvo.test,:));
                bic(clusterIdx,cvf) = m(clusterIdx,cvf).obj.BIC;
                
            catch ME
                switch(ME.identifier)
                    case {'stats:gmdistribution:MisshapedInitSingleCov','stats:gmdistribution:IllCondCovIter'}
                        count = 0;error_count = 0;
                        while count == error_count
                            if count >= options.maxRetry
                                fprintf('Fail to fit GM model in %d tries',options.maxRetry);
                                negLL(clusterIdx,cvf) = nan;
                                break;
                            end
                            try
                                m(clusterIdx,cvf).obj = gmdistribution.fit(dat(cvo.training,:),nClusters(clusterIdx),'options',fitOptions,'replicates',1, 'start', 'plus','Regularize', 1e-5);
                                [~,negLL(clusterIdx,cvf)] = m(clusterIdx,cvf).obj.posterior(dat(cvo.test,:)); %get the (negative log) likelihood of the test data
                                bic(clusterIdx,cvf) = m(clusterIdx,cvf).obj.BIC;
                                
                            catch
                                error_count = error_count + 1;
                            end % end of inner try-catch
                            count = count + 1;
                        end
                    otherwise
                        rethrow(ME);
                end % End of switch case on ME.identifier
            end % End of try catch
        end % End of CV folds loop
    else
        negLL(clusterIdx,1:numFolds) = nan;
        m(clusterIdx,1:numFolds) = [];
    end
end % End of clusters loop
% Sanity check of last resort that we got a fit:
assert(~all(isnan(negLL(:))),'Couldn''t fit the data!'); %if all the entries of negLL are NaN then no fit was ever successful

% Figure out the best model
meanNegLL = nanmean(negLL,2);
nGoodFolds = sum(~isnan(negLL),2);
for i_clust = 1:length(nGoodFolds)
    if nGoodFolds(i_clust)<5
        meanNegLL(i_clust) = nan;
    end
end

nanflag = ~isnan(meanNegLL);
flag = find(nanflag);
[~,Idx] = min(meanNegLL(nanflag)./options.prior(nanflag)');

bestModelIdx = flag(Idx);
bestModel = options.nClusters(bestModelIdx); % actual # of clusters


