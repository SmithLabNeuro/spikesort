% paths

function paths = mypaths

% data and classification labels
datapath   = '~/projects/SmithYu/microstim/data/';
labelspath = '~/projects/SmithYu/microstim/data/ustim_classified_labels/';

% NASnet path for saved networks and training data
netpath    = '~/projects/SmithYu/microstim/NASNet/';
trdatapath = '~/projects/SmithYu/microstim/NASNet/ustim_training_data/';

% git repo for this code
codepath   = '~/git_projects/SmithYu_microstim/NASNet/';

addpath(codepath)

paths = {datapath, labelspath, netpath, trdatapath};


end