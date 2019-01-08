function options = mogSortOptions(varargin)
% options = mogSortOptions();
% 
%   Lets the user set or modify the default options used in the sorting
%   process
%
options = struct();

%% Default options
% artifactDetector
options.voltageThreshold = int16(1000); % ThreshDetect - set to Inf to disable
options.varianceMax = 1e03;          % varDetect - set to Inf to disable
options.freqThreshold = 2000;   %FreqDetect - set to Inf to disable

% iterativePCA
options.numPcaDimensionsToUse = 5; %used in a lot of stuff (iterativePca, getting prior Model)
options.highScoreZScore = 4; %zscore threshold for throwing out high scores
options.keepPCA = false; % keep the pca space

% clusteringFcn
options.sort = 1; % sort options  % default option - fresh data fit
options.maxClusterIter = 1500; %max iterations when clustering
options.clusterErrorTolerance = 1e-5; %Error tolerance to use while clustering
options.clusterNumStep = 2; %when using prior Model, step size of numClusters to look at(1:5 if priorClusters = 3 and step = 2)
options.nClusters = 1:5;    %default number of units to cluster over - with no prior Model
options.subsetSize = 10000; %size of subset to cluster over (speeds it up)
options.numFolds = 30; %number of folds (using monte carlo cross validation)
options.holdoutProportion = 0.5; %size of partition 
options.guessClusters = false;% guess clusters % false - default clusters | true - evalCluster
options.maxRetry = 5;

% options.extraClusterMu = 0.05; %Mu to use when adding an extra gaussian model to cluster over
% options.extraClusterSigma = 0.01; %Sigma to use when adding extra gaussian model to cluster over
options.extraClusterProportion = 0.5; % Proportion to use when adding an extra gaussian model to cluster over

options.lowPostProb = 0.5; % Threshold for selecting waves when creating initial conditions for an extra component

% alignWaves
options.numSamplesToShift = 20; %number of time samples to shift waves when aligning

% noiseCluster
load('template'); %load default template
options.template = template; %set default template

%% user-specified values:
availableOptions = fieldnames(options);

%users should specify options as parameter-value pairs
for vx = 1:2:numel(varargin)
    %Throw an error if the user tries to set an unknown option:
    assert(ismember(varargin{vx},availableOptions),'mogSort:badOption','Unrecognized option ''%s''',varargin{vx}); 
    %Overwrite the default value with the user-specified value:
    options.(varargin{vx}) = varargin{vx+1};
end
    
