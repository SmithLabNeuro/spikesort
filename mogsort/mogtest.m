load('/Users/smithlab/Desktop/cache/ch19.mat');
waves = Waveforms';
mogopt = mogSortOptions;
mogopt.sortcodeToIgnore = 255;
mogopt.WaveformInfoUnits = Unit;
sortCode = mogSorter(waves,mogopt);
