//+------------------------------------------------------------------+
//|                                                     pipMA-v2.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

#define pipMAMeasures        30
#define pipMACur              0  //--- current value
#define pipMAST               1  //--- short term
#define pipMALT               2  //--- long term
#define pipMARegrST           3  //--- regression short term
#define pipMARegrLT           4  //--- regression long term
#define pipMARegrGap          5  //--- regression gap
#define pipMARegrGapMax       6  //--- regression gap
#define pipMARegrStrST        7  //--- regression short term strength
#define pipMARegrStrLT        8  //--- regression long term strength
#define pipMALow              9  //--- range low
#define pipMAMid             10  //--- range bisector
#define pipMAHigh            11  //--- range high
#define pipMARange           12  //--- range size
#define pipMADev             13  //--- price deviation off mid
#define pipMADevMax          14  //--- max cur deviation (price off mid)
#define pipMAGapCur          15  //--- current gap off mid
#define pipMAGapST           16  //--- gap between cur and short term
#define pipMAGapLT           17  //--- gap between cur and long term
#define pipMAMaxGapST        18  //--- max short term deviation
#define pipMAMaxGapLT        19  //--- max long term deviation
#define pipMARngDir          20  //--- Aggregate direction of the range
#define pipMAMidDir          21  //--- mid range direction
#define pipMAHighDir         22  //--- high range direction
#define pipMALowDir          23  //--- low range direction
#define pipMARngStr          24  //--- pip ma range strength
#define pipMAIndStrCur       25  //--- pip ma cur indicator strength
#define pipMAIndStrST        26  //--- pip ma ST indicator strength
#define pipMAIndStrLT        27  //--- pip ma LT indicator strength
#define pipMAHistIndex       28  //--- size of pip change history
#define pipMARates           29  //--- number of bars pipma is active

//--- buffer constants
#define PIP_MA                0
#define PIP_MA_STERM          1
#define PIP_MA_LTERM          2
#define PIP_MA_REGR_STERM     3
#define PIP_MA_REGR_LTERM     4
#define PIP_MA_MEASURES       5

//--- wave measures
#define regrWaveDir           0
#define regrWaveValue         1
#define regrWavePriceIdx      2

#include <std_utility.mqh>

//--- input parameters
input int      inpMAPeriod = 200;   // Pip Change History
input int      inpMASTerm  = 3;     // Pip Short Term Period
input int      inpMALTerm  = 24;    // Pip Long Term Period
input int      inpRegrDeg  = 6;     // Regression Degree
input int      inpRegrRng  = 120;   // Regression Range

//+------------------------------------------------------------------+
//| Operational Data Arrays                                          |
//+------------------------------------------------------------------+

double  pipMA[pipMAMeasures];
double  pipMALast[pipMAMeasures];

double  regrWaveST[3][6];
double  regrWaveLT[3][6];


//+------------------------------------------------------------------+
//| pipMAGetData - Loads current pipMA data into measures            |
//+------------------------------------------------------------------+
void pipMAGetData()
  {
    string str = "";
    
    ArrayCopy(pipMALast,pipMA);
    
    for (int measure=0; measure<pipMAMeasures; measure++)
    {
      pipMA[measure] = iCustom(Symbol(), Period(),"PipMA-v2", inpMAPeriod, inpMASTerm, inpMALTerm, inpRegrDeg, inpRegrRng, PIP_MA_MEASURES, measure);
      str=str+(DoubleToStr(pipMA[measure],Digits)+";");
    }

//    pipMACalculateWave(regrWaveST,indCurBuffer);
//    pipMACalculateWave(regrWaveLT,indLTBuffer);
//    Print(str);
  }
  
//+------------------------------------------------------------------+
//| pipMALoaded - Returns true once the pipMA tick array is loaded   |
//+------------------------------------------------------------------+
bool pipMALoaded()
  {
    if (pipMA[pipMAHistIndex] >= inpMAPeriod)
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| pipMASTLoaded - Returns true once the pipMA short term ind is on |
//+------------------------------------------------------------------+
bool pipMASTLoaded()
  {
    if (pipMA[pipMARates] >= inpMASTerm)
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| pipMALTLoaded - Returns true once the pipMA long term ind is on  |
//+------------------------------------------------------------------+
bool pipMALTLoaded()
  {
    if (pipMA[pipMARates] >= inpMALTerm)
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| pipMASTRegrLoaded - Returns true when pipMA ST Regression is on  |
//+------------------------------------------------------------------+
bool pipMATRegrLoaded()
  {
    if (pipMA[pipMARegrST] >= 0.00)
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| pipMALTLoaded - Returns true once the pipMA long term ind is on  |
//+------------------------------------------------------------------+
bool pipMALTRegrLoaded()
  {
    if (pipMA[pipMARegrLT] >= 0.00)
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| pipMANewLow - Returns true if the low range is hit               |
//+------------------------------------------------------------------+
bool pipMANewLow()
  {
    if (pipMALast[pipMALow] > pipMA[pipMALow])
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| pipMANewHigh - Returns true if the high range is hit             |
//+------------------------------------------------------------------+
bool pipMANewHigh()
  {
    if (pipMALast[pipMAHigh] < pipMA[pipMAHigh])
      return (true);
      
    return (false);
  }

int pipMACalculateWave(double &Wave[3][6], double &Buffer[])
  {
    int    idx;
    int    wdir    = dir(Buffer[0]-Buffer[1]);
    int    widx    = 0;
    double wval    = 0.00;

    int    pmin    = 0;
    int    pmax    = 0;
    
    double waveLast[3][6];
    
    ArrayCopy(waveLast,Wave);
    ArrayInitialize(Wave,0.00);
        
    for (idx=1; idx<inpRegrRng && Buffer[idx]>0.00; idx++)
    {
      if (dir(Buffer[idx-1]-Buffer[idx]) == DIR_NONE ||
          dir(Buffer[idx-1]-Buffer[idx]) == wdir || wdir == DIR_NONE)
      {
        if (Low[idx]<Low[pmin])
          pmin = idx;

        if (High[idx]>High[pmax])
          pmax = idx;
          
        Wave[regrWaveValue][widx]  = fmax(fabs(Buffer[idx]), wval)*wdir;
      }
      else
      {
        wdir = dir(Buffer[idx-1]-Buffer[idx]);
        Wave[regrWaveDir][widx]        = wdir;
        
        if (wdir == DIR_UP)
          Wave[regrWavePriceIdx][widx] = pmin;
        else
          Wave[regrWavePriceIdx][widx] = pmax;

        widx++;
      }
    }
    
    if (wdir == DIR_UP)
      Wave[regrWavePriceIdx][widx] = pmin;
    else
      Wave[regrWavePriceIdx][widx] = pmax;
      
    return(-1);
  }