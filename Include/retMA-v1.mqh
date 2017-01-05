//+------------------------------------------------------------------+
//|                                                     retMA-v1.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

#define retMAMeasures        12
#define retMACur              0  //--- current value
#define retMAST               1  //--- short term
#define retMALT               2  //--- long term
#define retMACurDir           3  //--- long term
#define retMASTDir            4  //--- long term
#define retMALTDir            5  //--- long term
#define retMARngCur           6  //--- price deviation off mid
#define retMARngST            7  //--- price deviation off mid
#define retMARngLT            8  //--- price deviation off mid
#define retMARet              9  //--- max cur deviation (price off mid)
#define retMARetPct          10  //--- price deviation off mid
#define retMARetPctMax       11  //--- max cur deviation (price off mid)

//--- buffer constants
#define RET_MA                0
#define RET_MA_STERM          1
#define RET_MA_LTERM          2
#define RET_MA_MEASURES       3

//--- input parameters
input int   inpRetMACur   =   4;  // Current Retrace Period
input int   inpRetMAST    =   6;  // Short Term Retrace Period
input int   inpRetMALT    =  24;  // Long Term Retrace Period

#include <std_utility.mqh>

//+------------------------------------------------------------------+
//| Data Buffers                                                     |
//+------------------------------------------------------------------+

double  retMA[retMAMeasures];
double  retMALast[retMAMeasures];

//+------------------------------------------------------------------+
//| retMAGetData - Loads current pipMA data into measures            |
//+------------------------------------------------------------------+
void retMAGetData()
  {
    string str = "";
    
    ArrayCopy(retMALast,retMA);
    
    for (int measure=0; measure<retMAMeasures; measure++)
    {
      retMA[measure] = iCustom(Symbol(), Period(),"retMA-v1", inpRetMACur, inpRetMAST, inpRetMALT, RET_MA_MEASURES, measure);
      str=str+(DoubleToStr(retMA[measure],Digits)+";");
    }
    
//    Print(str);
  }
  
//+------------------------------------------------------------------+
//| retMANewLow - Returns true if the low range is hit               |
//+------------------------------------------------------------------+
bool retMANewLow(int Measure)
  {
    if (retMALast[Measure] > retMA[Measure])
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| retMANewHigh - Returns true if the high range is hit             |
//+------------------------------------------------------------------+
bool retMANewHigh(int Measure)
  {
    if (retMALast[Measure] < retMA[Measure])
      return (true);
      
    return (false);
  }

