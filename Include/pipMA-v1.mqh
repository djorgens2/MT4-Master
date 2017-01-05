//+------------------------------------------------------------------+
//|                                                     pipMA-v1.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

#define pipMAMeasures        24
#define pipMACur              0  //--- current value
#define pipMAST               1  //--- short term
#define pipMALT               2  //--- long term
#define pipMALow              3  //--- range low
#define pipMAMid              4  //--- range bisector
#define pipMAHigh             5  //--- range high
#define pipMARange            6  //--- range size
#define pipMADev              7  //--- price deviation off mid
#define pipMADevMax           8  //--- max cur deviation (price off mid)
#define pipMAGapCur           9  //--- current gap off mid
#define pipMAGapST           10  //--- gap between cur and short term
#define pipMAGapLT           11  //--- gap between cur and long term
#define pipMAMaxGapST        12  //--- max short term deviation
#define pipMAMaxGapLT        13  //--- max long term deviation
#define pipMARngDir          14  //--- Aggregate direction of the range
#define pipMAMidDir          15  //--- mid range direction
#define pipMAHighDir         16  //--- high range direction
#define pipMALowDir          17  //--- low range direction
#define pipMARngStr          18  //--- pip ma range strength
#define pipMAIndStrCur       19  //--- pip ma cur indicator strength
#define pipMAIndStrST        20  //--- pip ma ST indicator strength
#define pipMAIndStrLT        21  //--- pip ma LT indicator strength
#define pipMAHistIndex       22  //--- size of pip change history
#define pipMARates           23  //--- number of bars pipma is active

//--- buffer constants
#define PIP_MA                0
#define PIP_MA_STERM          1
#define PIP_MA_LTERM          2
#define PIP_MA_MEASURES       3

#include <std_utility.mqh>

//--- input parameters
input int      inpMAPeriod = 200;   // Pip Change History
input int      inpMASTerm  = 3;     // Pip Short Term Period
input int      inpMALTerm  = 24;    // Pip Long Term Period
input bool     inpFileData = false; // Write historical pipMA data

//+------------------------------------------------------------------+
//| Data Buffers                                                     |
//+------------------------------------------------------------------+

double  pipMA[pipMAMeasures];
double  pipMALast[pipMAMeasures];

//+------------------------------------------------------------------+
//| pipMAGetData - Loads current pipMA data into measures            |
//+------------------------------------------------------------------+
void pipMAGetData()
  {
    string str = "";
    
    ArrayCopy(pipMALast,pipMA);
    
    for (int measure=0; measure<pipMAMeasures; measure++)
    {
      pipMA[measure] = iCustom(Symbol(), Period(),"PipMA-v1", inpMAPeriod, inpMASTerm, inpMALTerm, PIP_MA_MEASURES, measure);
      str=str+(DoubleToStr(pipMA[measure],Digits)+";");
    }
    
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

