//+------------------------------------------------------------------+
//|                                                     pipMA-v4.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property strict

//--- input parameters
input int  inpDegree      = 6;    // pip MA degree
input int  inpPeriod      = 200;  // pip MA range

#define   dataMeasures     54  //--- total measures count

//--- factor of change (FOC) measures
#define   dataTLCur         0  //--- current trend line value
#define   dataTLLow         1  //--- low trend line value
#define   dataTLMid         2  //--- mid trend line value
#define   dataTLHigh        3  //--- high trend line value
#define   dataFOCCur        4  //--- current factor of change
#define   dataFOCMin        5  //--- absolute retrace factor of change
#define   dataFOCMax        6  //--- highest factor of change this direction
#define   dataFOCDev        7  //--- current factor of change deviation
#define   dataFOCCurDir     8  //--- current direction from last deviation
#define   dataFOCTrendDir   9  //--- TL trend based on FOC max
#define   dataFOCPiv       10  //--- price where the FOC changes direction
#define   dataFOCPivDir    11  //--- pivot direction in price, up or down
#define   dataFOCPivDev    12  //--- deviation of price to pivot
#define   dataFOCPivDevMin 13  //--- min deviation of price to pivot since last pivot
#define   dataFOCPivDevMax 14  //--- deviation of price to pivot since last pivot
#define   dataFOCPoints    15  //--- Pips (to the point level) per FOC

//--- range measures
#define   dataRngMA        16  //--- moving average of the pip history range
#define   dataRngMADev     17  //--- deviation MA to Mid
#define   dataRngSize      18  //--- pip history range
#define   dataRngMax       19  //--- max pip history range
#define   dataRngContFact  20  //--- range contraction/expansion factor
#define   dataRngExpPrice  21  //--- last price where expansion began
#define   dataRngLow       22  //--- pip history range low
#define   dataRngMid       23  //--- pip history range bisector
#define   dataRngHigh      24  //--- pip history range high
#define   dataRngStr       25  //--- range strength based on composite range directions
#define   dataRngDir       26  //--- last range hit (high/low)
#define   dataRngLowDir    27  //--- direction of low range
#define   dataRngMidDir    28  //--- direction of range bisector
#define   dataRngHighDir   29  //--- direction of range high

//--- effective trading range measures
#define   dataETRHigh      30  //--- Effective range high
#define   dataETRLow       31  //--- Effective range low
#define   dataETRMid       32  //--- Effective mid bisector
#define   dataETRDir       33  //--- Effective dir (last direction hit)
#define   dataETRContFact  34  //--- Effective dir (last direction hit)
#define   dataETRRetrace   35  //--- Effective retrace, current price within trade range

//--- oscillation frequency measures
#define   dataAmpCur       36  //--- Current pos/neg amplitude
#define   dataAmpCurMax    37  //--- Current amplitude (wave height)
#define   dataAmpCurHigh   38  //--- Current wave crest value
#define   dataAmpCurLow    39  //--- Current wave trough value
#define   dataAmpCurMid    40  //--- Current amplitude bisector (weighted by cur pos/neg amplitude?)
#define   dataAmpCurPct    41  //--- Current frequency amplitude stated as a percent
#define   dataAmpCurDir    42  //--- Direction of the most recent standard deviation

#define   dataAmpMean      43  //--- Mean Amplitude (Crest+/Trough/)
#define   dataAmpMeanMid   44  //--- Mean Amplitude bisector (should consider weighting the mean using the Pos/Neg amplitudes?)
#define   dataAmpMeanPos   45  //--- Mean of the positive amplitudes
#define   dataAmpMeanNeg   46  //--- Mean of the negative amplitudes
#define   dataAmpMeanDir   47  //--- direction of MeanPos+MeanNeg

//--- other measures
#define   dataPLine        48  //--- current value of poly
#define   dataPLineDir     49  //--- direction of poly
#define   dataPLineMADir   50  //--- direction of pline to pipMA
#define   dataTickCur      51  //--- Current value of pip history
#define   dataTickDir      52  //--- direction of pip history tick (very fast)
#define   dataTickCnt      53  //--- ticks after change

//--- operational variables
double    data[dataMeasures];
double    dataLast[dataMeasures];

bool      pipMALoaded   = false;
bool      pipMARngHigh  = false;
bool      pipMARngLow   = false;

double    pipMAExpPrice = 0.0;

//+------------------------------------------------------------------+
//| pipMAGetData - update current pipMA data                         |
//+------------------------------------------------------------------+
void pipMAGetData()
  {
    ArrayCopy(dataLast,data);
    
    for (int idx=0; idx<dataMeasures; idx++)
      data[idx] = iCustom(Symbol(),Period(),"pipMA-v4",inpDegree,inpPeriod,3,idx);
    
    if (iCustom(Symbol(),Period(),"pipMA-v4",inpDegree,inpPeriod,0,inpPeriod-1)>0.00)
      pipMALoaded = true;
      
  }

//+------------------------------------------------------------------+
//| pipMANewHigh - returns true if a new high price is reached       |
//+------------------------------------------------------------------+
bool pipMANewHigh()
  {
    //--- compute initial high
    if (dataLast[dataRngHigh]!=0.00)
      if (Close[0]>dataLast[dataRngHigh])
      {
        pipMAExpPrice  = NormalizeDouble(Close[0]-point(1.0),Digits);
        pipMARngHigh   = true;

        return (true);
      }
      
    if (pipMARngHigh)
    {
      pipMAExpPrice = fmax(Close[0]-point(1.0),pipMAExpPrice);
      
      if (Close[0]<pipMAExpPrice)
        pipMARngHigh = false;
      else
        return (true);
    }

    return (false);
  }

//+------------------------------------------------------------------+
//| pipMANewLow - returns true if a new low price is reached         |
//+------------------------------------------------------------------+
bool pipMANewLow()
  {
    //--- compute initial low
    if (dataLast[dataRngLow]!=0.00)
      if (Close[0]<dataLast[dataRngLow])
      {
        pipMAExpPrice = Close[0]+point(1.0);
        pipMARngLow   = true;

        return(true);
      }
      
    if (pipMARngLow)
    {
      pipMAExpPrice = fmin(Close[0]+point(1.0),pipMAExpPrice);
      
      if (Close[0]>pipMAExpPrice)
        pipMARngLow = false;
      else
        return (true);
    }
    
    return (false);
  }