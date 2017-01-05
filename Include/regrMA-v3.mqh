//+------------------------------------------------------------------+
//|                                                    regrMA-v3.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property strict

#include <std_utility.mqh>

//--- input parameters
input int inpRegrDegree     = 6;    // Poly regression degree
input int inpRegrFastRng    = 48;   // Short Term Poly regression range
input int inpRegrSlowRng    = 500;  // Long Term Poly regression range
input int inpRegrST         = 3;    // Short term poly MA
input int inpRegrLT         = 24;   // Long term poly MA


//--- buffer constants
#define   BUF_FAST_POLY_ST    0     //--- Fast Poly Short Term
#define   BUF_FAST_POLY_LT    1     //--- Fast Poly Long Term
#define   BUF_FAST_POLY_TL    2     //--- Fast Poly Trend Line
#define   BUF_SLOW_POLY_ST    3     //--- Slow Poly Short Term
#define   BUF_SLOW_POLY_LT    4     //--- Slow Poly Long Term
#define   BUF_SLOW_POLY_TL    5     //--- Slow Poly Trend Line
#define   BUF_FAST_DATA       6     //--- Fast data measures
#define   BUF_SLOW_DATA       7     //--- Slow data measures
#define   BUF_COMP_DATA       8     //--- Composite data measures
#define   BUF_FAST_POLY_STTL  9     //--- Fast Poly Short Term Trend

//--- measures constants
#define   regrMeasures       33
#define   regrPolyST          0  //--- Short term value
#define   regrPolyLT          1  //--- Long term value
#define   regrPolyHigh        2  //--- Current poly ST high value
#define   regrPolyLow         3  //--- Current poly ST low value
#define   regrPolyMid         4  //--- Current poly ST mid value
#define   regrPolyRange       5  //--- Current poly ST Range (high-low)
#define   regrPolyLastTop     6  //--- Poly ST adjacent top price
#define   regrPolyLastBottom  7  //--- Poly ST adjacent bottom price
#define   regrPolyTrueHigh    8  //--- Poly ST true (max) high
#define   regrPolyTrueLow     9  //--- Poly ST true (max) low
#define   regrPolyTrueRange  10  //--- Poly ST true (max) range
#define   regrPolyRetrace    11  //--- Current poly ST Retrace
#define   regrPolyDirST      12  //--- Short term direction (nose)
#define   regrPolyDirLT      13  //--- Long term directon (nose)
#define   regrPolyGap        14  //--- Poly gap (ST-LT)
#define   regrPolyGapMin     15  //--- Poly gap (min) ST-LT within a Dir LT
#define   regrPolyGapMax     16  //--- Poly gap (max) ST-LT within a Dir LT
#define   regrPolySTLTMid    17  //--- Poly mid gap (ST+LT)/2
#define   regrTLCur          18  //--- Current TLine price
#define   regrTLHigh         19  //--- High TLine price
#define   regrTLLow          20  //--- Low TLine price
#define   regrTLMid          21  //--- Mid TLine price
#define   regrFOCCur         22  //--- current factor of change
#define   regrFOCMin         23  //--- absolute retrace factor of change
#define   regrFOCMax         24  //--- highest factor of change this direction
#define   regrFOCDev         25  //--- current factor of change deviation
#define   regrFOCCurDir      26  //--- current direction from last deviation
#define   regrFOCTrendDir    27  //--- overall trend (based on FOC max)
#define   regrFOCPiv         28  //--- price where the FOC changes direction
#define   regrFOCPivDir      29  //--- pivot direction, up or down
#define   regrFOCPivDev      30  //--- deviation of price to pivot
#define   regrFOCPivDevMin   31  //--- min deviation of price to pivot since last pivot
#define   regrFOCPivDevMax   32  //--- deviation of price to pivot since last pivot

//--- comparative measure constants
#define   compMeasures           22
#define   compTLTailGap           0  //--- Current gap value of Slow TL at the ST Range
#define   compTLHeadGap           1  //--- Current gap value of Slow vs. Fast TL Head
#define   compTLStr               2  //--- Strength of Fast ST/LT composite TL
#define   compPolyGapST           3  //--- Gap of the ST poly between regr Fast and Slow
#define   compPolyGapLT           4  //--- Gap of the LT poly between regr Fast and Slow
#define   compPolyMidDev          5  //--- Deviation between Fast and Slow mid gaps
#define   compPolyRetrace         6  //--- Aggregate of the Slow and Fast retrace values
#define   compPolySTTLHead        7  //--- TL on the Fast poly ST Head
#define   compPolySTTLTail        8  //--- TL on the Fast poly ST Tail
#define   compPolySTTLMid         9  //--- Midpoint of Fast Poly STTL (in pips)
#define   compPolySTTLDir        10  //--- Direction of the Fast poly TL
#define   compPolySTTLFOC        11  //--- FOC for Fast Poly STTL
#define   compPolySTTLFOCMax     12  //--- Max value of current STTL direction
#define   compPolySTTLFOCMin     13  //--- Min value of current STTL direction
#define   compPolySTTLFOCDev     14  //--- Deviation between STTL Max and Min
#define   compPolySTTLGap        15  //--- Gap for Fast Poly STTL and the Fast TL
#define   compMajorPivot         16  //--- Composite of all indicators - Major Support/Resistance level
#define   compMajorPivotHigh     17  //--- MP Top - highest price
#define   compMajorPivotLow      18  //--- MP Bottom - lowest price
#define   compMajorPivotMid      19  //--- MP Midpoint - 50% retrace
#define   compMajorPivotDir      20  //--- MP Direction
#define   compMajorPivotRng      21  //--- MP Size in pips

//--- operational variables
double regrSlow[regrMeasures];
double regrSlowLast[regrMeasures];

double regrFast[regrMeasures];
double regrFastLast[regrMeasures];

double regrComp[regrMeasures];
double regrCompLast[regrMeasures];

//+------------------------------------------------------------------+
//| regrMAGetData - loads the measures                               |
//+------------------------------------------------------------------+
void regrMAGetData()
  {        
    ArrayCopy(regrSlowLast,regrSlow);
    ArrayCopy(regrFastLast,regrFast);
    ArrayCopy(regrCompLast,regrComp);

    for (int idx=0; idx<regrMeasures; idx++)
    {
      regrFast[idx]   = iCustom(Symbol(),Period(),"regrMA-v3",inpRegrDegree,inpRegrFastRng,inpRegrSlowRng,inpRegrST,inpRegrLT,BUF_FAST_DATA,idx);
      regrSlow[idx]   = iCustom(Symbol(),Period(),"regrMA-v3",inpRegrDegree,inpRegrFastRng,inpRegrSlowRng,inpRegrST,inpRegrLT,BUF_SLOW_DATA,idx);
      regrComp[idx]   = iCustom(Symbol(),Period(),"regrMA-v3",inpRegrDegree,inpRegrFastRng,inpRegrSlowRng,inpRegrST,inpRegrLT,BUF_COMP_DATA,idx);
    }  
  }
  
