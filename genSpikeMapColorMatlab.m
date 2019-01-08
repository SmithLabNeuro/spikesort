%function map = genSpikeMapColorMatlab(waves,unit,xPix,yPix,winFloor,winCeil,colors,step)
%
% This function is intended to replace the genSpikeMapColor.c Mex
% code with native Matlab. It doesn't work quite the same, but is
% functionally similar. The main downside is it is *much* slower.
%

function map = genSpikeMapColorMatlab(waves,unit,xPix,yPix,winFloor,winCeil,colors,step)

    if (1)
        xOversampleFactor = 10;
        %waves = double(waves);
        %linearly interpolate the waves to the correct 'x' pixelation:
        waves = interp1(1:size(waves,2),double(waves'),linspace(1,size(waves,2),xPix*xOversampleFactor),'spline');  
        %note, I think I actually need to add a blank space on either side to match the c function
        %convert the vertical values into pixel indices:
        waves = round(yPix.*((waves-winFloor)./(winCeil-winFloor)));
        %x-dimension lookup:
        xInd = repmat((1:size(waves,1))',1,size(waves,2));
        xInd = ceil(xInd./xOversampleFactor);
        %keep track of the unit (color) of each pixel:
        cInd = repmat(unit',size(waves,1),1);
        %make into x,y subscripts:
        %    fillPixels = [xInd(:),waves(:)];
        xInd = xInd(:);
        waves = waves(:);
        %vertical clipping:
        %clippedValues = waves<1|waves>yPix;
        keptValues = waves>=1&waves<=yPix;
        %xInd(clippedValues)=[];
        %waves(clippedValues)=[];
        xInd = xInd(keptValues);
        waves = waves(keptValues);
        %cInd(clippedValues) = []; %if anything is clipped this will turn into a vector, but that's desired anyway
        cInd = cInd(keptValues);
        usePixel = 1:size(xInd,1);
        %    [fillSubs,usePixel] = unique(fillPixels,'rows','stable');    
        uniqueColor = cInd(usePixel)+1; %add 1 so there's not unit=0
        %convert subscripts to array indices:
        uniqueInd = sub2ind([xPix,yPix],waves,xInd);
        %preallocate:
        map = zeros(xPix,yPix);
        %place colors:    
        map(uniqueInd) = uniqueColor+1;   
        %convert to RGB:
        map = ind2rgb(map,[0,0,0;colors]);        
        
    else
        
        xOversampleFactor = 10;
        %waves = double(waves);
        %linearly interpolate the waves to the correct 'x' pixelation:
        waves = interp1(1:size(waves,2),double(waves'),linspace(1,size(waves,2),xPix*xOversampleFactor),'spline');  
        %note, I think I actually need to add a blank space on either side to match the c function
        %convert the vertical values into pixel indices:
        waves = round(yPix.*((waves-winFloor)./(winCeil-winFloor)));
        %x-dimension lookup:
        xInd = repmat((1:size(waves,1))',1,size(waves,2));
        xInd = ceil(xInd./xOversampleFactor);
        %keep track of the unit (color) of each pixel:
        cInd = repmat(unit',size(waves,1),1);
        %make into x,y subscripts:
        fillPixels = [xInd(:),waves(:)];
        %vertical clipping:
        clippedValues = fillPixels(:,2)<1|fillPixels(:,2)>yPix;    
        fillPixels(clippedValues,:) = []; 
        cInd(clippedValues) = []; %if anything is clipped this will turn into a vector, but that's desired anyway
        fillSubs = fillPixels;
        usePixel = 1:size(fillSubs,1);
        %    [fillSubs,usePixel] = unique(fillPixels,'rows','stable');    
        uniqueColor = cInd(usePixel)+1; %add 1 so there's not unit=0
        %convert subscripts to array indices:
        uniqueInd = sub2ind([xPix,yPix],fillSubs(:,2),fillSubs(:,1));
        %preallocate:
        map = zeros(xPix,yPix);
        %place colors:    
        map(uniqueInd) = uniqueColor+1;   
        %convert to RGB:a
        map = ind2rgb(map,[0,0,0;colors]);        
    end
end

