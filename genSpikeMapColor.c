#include <math.h>
#include <mex.h>

#define PI 3.14159265

double thresh = .1;
int step = 10;

static int tran(int p, int range1, int range2, int pix)
{
  double newP;

  newP = ((double)(p - range1))/(range2 - range1);
  return (int)(newP*pix);
}

void drawOnMap(double map[],int x,int y,int xPix,int yPix,double colors[],int unit)
{
  if (x >= 0 && x <= xPix - 1 && y >= 0 && y <= yPix)
  {
    map[y+x*yPix]=colors[unit];
    map[y+x*yPix+xPix*yPix]=colors[unit+256];
    map[y+x*yPix+2*xPix*yPix]=colors[unit+512];
  }
}

void genSpikeMap(double map[], short waveforms[], unsigned char units[], double colors[], int spikeCount, int waveformSize, int xPix, int yPix, int xRange1, int xRange2, int yRange1, int yRange2)
{
  int x, y, oldX, oldY, newX, newY;
  int i, j, k;
  double r;
  int * tranX;
  int unit;

  tranX = (int *) malloc(waveformSize * sizeof(int));
  
  for (i = 0; i < waveformSize; i++)
  {
    tranX[i] = tran(i, xRange1, xRange2, xPix);
  }
  
  k = 0;

  for (i = 0; i < spikeCount; i++)
  {
    y = tran(waveforms[i],yRange1,yRange2,yPix);
    x = tranX[0];
    
    unit = units[i];

    if (k == 0)
    {
      drawOnMap(map,x,y,xPix,yPix,colors,unit);
      k+=step;
    }

    for (j = 1; j < waveformSize; j++)
    {
      oldX = tranX[j-1];
      oldY = tran(waveforms[i+spikeCount*(j-1)],yRange1,yRange2, yPix);
      newX = tranX[j];
      newY = tran(waveforms[i+spikeCount*j],yRange1, yRange2, yPix);

      r = sqrt((oldX - newX)*(oldX - newX) + (oldY-newY)*(oldY-newY));

      for (; k < r; k+=step)
      {
	x = floor(.5+oldX+(newX-oldX)*(k/r));
	y = floor(.5+oldY+(newY-oldY)*(k/r));

	drawOnMap(map,x,y,xPix,yPix,colors,unit);
      }

      k = k % (int)(ceil(r));

      y = tran(waveforms[i+spikeCount*j],yRange1,yRange2,yPix);
      x = tranX[j];
      
      if (k == 0)
      {
	drawOnMap(map,x,y,xPix,yPix,colors,unit);
	k += step;
      }
    }
  }
  
  free (tranX);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] )
{ 
/* the line below used to be int dim[3] but we changed it because newer matlab version needed it to be mwSize */
    mwSize dim[3];
  short * waveforms;
  int spikeCount, waveformSize, winFloor, winCeil;
  double * c;
  int xPix, yPix;
  double * colors;
  unsigned char * units;
  
  /* Get preferred image matrix resolution */
  xPix = (int) * mxGetPr(prhs[2]);
  yPix = (int) * mxGetPr(prhs[3]);

  /* Create output array */
  dim[0] = xPix;
  dim[1] = yPix;
  dim[2] = 3;
  plhs[0] = mxCreateNumericArray(3, dim, mxDOUBLE_CLASS, mxREAL);

  /* Get the actual waveforms and associated sizes */
  waveforms = (short *) mxGetPr(prhs[0]);
  spikeCount = mxGetDimensions(prhs[0])[0];
  waveformSize = mxGetDimensions(prhs[0])[1];
  
  /* if no spikes were passed in, don't proceed - return all 0's */
  if (spikeCount == 0)
    return;

  units = (unsigned char *) mxGetPr(prhs[1]);
  
  winFloor = (int) * mxGetPr(prhs[4]);
  winCeil = (int) * mxGetPr(prhs[5]);
  
  colors = (double *) mxGetPr(prhs[6]);
  
  step = (int) * mxGetPr(prhs[7]);
  
  c = mxGetPr(plhs[0]);
  
  genSpikeMap(c, waveforms, units, colors, spikeCount, waveformSize, xPix, yPix, -1, waveformSize, winFloor, winCeil);
}


