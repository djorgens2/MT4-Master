//+------------------------------------------------------------------+
//|                                                     pipMA-v3.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

#include <regrMA-v2.mqh>

//--- input parameters
input int  inpPeriod      = 200;    // pip MA range

#define   dataMeasures     32  //--- total measures count

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
#define   dataFOCTrendDir   9  //--- overall trend (based on FOC max)
#define   dataFOCPiv       10  //--- price where the FOC changes direction
#define   dataFOCPivDir    11  //--- pivot direction, up or down
#define   dataFOCPivDev    12  //--- deviation of price to pivot
#define   dataFOCPivDevMin 13  //--- min deviation of price to pivot since last pivot
#define   dataFOCPivDevMax 14  //--- deviation of price to pivot since last pivot

//--- range measures
#define   dataRngMA        15  //--- moving average of the pip history range
#define   dataRngMADev     16  //--- deviation MA to Mid
#define   dataRngSize      17  //--- pip history range
#define   dataRngMax       18  //--- max pip history range
#define   dataRngFactor    19  //--- range compression/expansion factor
#define   dataRngLow       20  //--- pip history range low
#define   dataRngMid       21  //--- pip history range bisector
#define   dataRngHigh      22  //--- pip history range high
#define   dataRngStr       23  //--- range strength based on composite range directions
#define   dataRngDir       24  //--- last range hit (high/low)
#define   dataRngLowDir    25  //--- direction of low range
#define   dataRngMidDir    26  //--- direction of range bisector
#define   dataRngHighDir   27  //--- direction of range high

//--- other measures
#define   dataPLine        28  //--- current value of poly
#define   dataPLineDir     29  //--- direction of poly
#define   dataPipDir       30  //--- direction of pip
#define   dataTickCnt      31  //--- ticks after change

//--- operational variables
double    data[dataMeasures];
double    dataLast[dataMeasures];

bool      pipMALoaded      = false;

//+------------------------------------------------------------------+
//| pipMAGetData - update current pipMA data                         |
//+------------------------------------------------------------------+
void pipMAGetData()
  {
    ArrayCopy(dataLast,data);
    
    for (int idx=0; idx<dataMeasures; idx++)
      data[idx] = iCustom(Symbol(),Period(),"pipMA-v3",inpRegrDeg,inpPeriod,3,idx);
    
    if (iCustom(Symbol(),Period(),"pipMA-v3",inpRegrDeg,inpPeriod,0,inpPeriod-1)>0.00)
      pipMALoaded = true;
      
  }

//+------------------------------------------------------------------+
//| pipMANewHigh - returns true if a new high price is reached       |
//+------------------------------------------------------------------+
bool pipMANewHigh()
  {
    if (data[dataRngHigh]>dataLast[dataRngHigh])
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| pipMANewLow - returns true if a new low price is reached         |
//+------------------------------------------------------------------+
bool pipMANewLow()
  {
    if (data[dataRngLow]<dataLast[dataRngLow])
      return (true);
      
    return (false);
  }