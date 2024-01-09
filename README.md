# Spikesort (A MATLAB-based spike sorter for NEV files)
Maintained by the Smith Laboratory (www.smithlab.net). If you use Spikesort and find it useful (or if you have problems), please drop us an email (matt@smithlab.net).

### Authors:
*Ryan Kelly* - wrote the original version of Spikesort in 2006 while he was a PhD student at CMU  
*Matthew Smith* - worked with Ryan Kelly on the original version, and led development since 2011  
*Adam Snyder* - extensive development of Spikesort from 2012-2018 while at Pitt/CMU as a postdoc  
*Shruti Vempati* - contributed bug fixes and improvements in 2016-2017 while she was a BioE undergrad at Pitt  
*Xiaohan Zhong* - cleaned up the code and added features in 2018 prior to the GitHub initial release

### Publishing data using Spikesort: 
If you use it in work you're going to publish, we would appreciate it if you would acknowledge us. You could put the software name and URL in your paper, or you could cite one or both of these references:
* Kelly RC, Smith MA, Samonds JM, Kohn A, Bonds AB, Movshon JA & Lee TS (2007) Comparison of recordings from microelectrode arrays and single electrodes in the visual cortex. Journal of Neuroscience, 27: 261-264
* Kelly RC (2010) Statistical Modeling of Spiking Activity in Large Scale Neuronal Networks, Ph.D. Thesis, Carnegie Mellon University

### DISCLAIMER: 
Spikesort is intended for sorting spike waveforms in NEV files (native format of Blackrock and Ripple hardware). This software modifies the NEV files and rewrites the sort codes for the channels. The authors of Spikesort take no responsibility for any errors in the software or in its use with your data. Remember that Spikesort modifies the NEV file, so you should have a backup before running this software. You should check that the sorting did what you thought it did with your NEV file. YOU ARE RESPONSIBLE FOR YOUR OWN DATA! That said, Spikesort continues to undergo development and has been used extensively. Bugs have existed in the software and will exist again, but it is relatively robust and mature.

### Cloning:
This repository uses submodules. Be sure to use the following for cloning:
```
git clone https://github.com/SmithLabNeuro/spikesort.git --recursive
```

Alternatively, if cloned without the `--recursive` flag, once in the repository local copy, run the following to initialize the submodules:
```
git submodule update --init
```

### Main File List:
*genSpikeMapColor.c + mex-compiled files* - take waveforms and produce an image shown in the GUI  
*genSpikeMapColorMatlab.m* – [NOT USED] this is a slower Matlab-native code version of *genSpikeMapColor.c*  
*getSNR.m* - calculate SNR (signal-to-noise ratio) - see Kelly et al 2007 (Journal of Neuroscience, 27: 261-264)  
*loadSort.m* - load the saved sort file  
*manageTempFiles.m* - manage temporary Spikesort files  
*readSampleWaveforms.m* - load a subset of spikes for sorting  
*readWaveforms2.m* - read the waveforms, times and units  
*readWaveforms2_timer.m* - uses a timer function so that it can run in the background  
*readWaveforms2_timer_sparse.m* - does a sparse (limited) read of waveforms for speed  
*rubberbandbox3.m* - draw a rubber band box and return the start and end points (for selecting spikes)  
*rubberBandMotionFunction.m* - window motion callback function  
*saveSort.m* - save a sort to a specified location  
*spikesort_gui.m* - define the operation callbacks  
*spikesort_nevscan.m* - read the NEV file & get file information (called when a set of files are loaded)  
*spikesort_write2.m* - called to write the sort codes to the NEV file  
*spikesort.m* - spikesort main function  
 
### Utility File List:
Note: in some cases these are not standalone, and call other Spikesort functions  
*chanPlot.m* - plot the spike waveforms for specified channel(s) with various plot options  
*justSNR.m* - return channels list, sort codes, SNR values and spike counts (and average waveform)  
*moveToSortCode.m* - write a list of sort codes into a NEV file  
*plx2nev.m* - take a PLX file and convert it to NEV file with the same file name but a NEV extension  
*plxSortFromNEV.m* - take a NEV-converted PLX file & write sort codes back into the PLX file  
*waves2nev.m* - take waveforms, channels, sort codes, times and write them into a NEV file  

### Notes:
**Mex Files:** Spikesort uses a Mex-compiled C function (genSpikeMapColor.c) to speed up generating the waveform image for display. This function is currently compiled for several platforms. If you need to recompile, go to the Spikesort directory and type "mex genSpikeMapColor.c". Alternatively, there is a matlab- native version (genSpikeMapColorMatlab.m), but it is much slower.  
**NEV files:** Spikesort works on NEV files, the native data format for Blackrock and Ripple hardware. If you have data from another recording setup, you can export your waveforms and convert them to a NEV using the waves2nev.m function supplied in the Spikesort directory. Also plx2nev.m converts Plexon PLX files to NEV.  
**Performance:** Spikesort creates temporary sort files of in-progress sorts. When you first run Spikesort, it will ask you where to store these files (you can change the location in the GUI). It will create a "spikesortunits" folder that contains ch*.mat and hist*.mat files. These are the cached waveforms and the sorting history for each channel. It cleans up that directory and creates a tempsort_*.mat file on exit. The speed of Spikesort will be affected strongly by the disk access speed of the NEV file and also of this spikesortunits directory.

### Usage:
For more details and a GUI tutorial, see [this file](README.pdf).
