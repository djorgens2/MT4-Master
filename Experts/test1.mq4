//+------------------------------------------------------------------+
//|                                                        test1.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class/Session.mqh>

//-- Option Enums
enum ShowOptions
     {
       ShowNone,             // None
       ShowActiveSession,    // Active Session
       ShowPriorSession,     // Prior Session
       ShowOffSession,       // Off Session
       ShowOrigin,           // Origin
       ShowTrend,            // Trend
       ShowTerm              // Term
     };

double handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
     //iCustom(_Symbol,_Period,"Session-v1",Daily,0,23,0,Yes,Trend,ShowTrend);

     return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
     double val1 = iCustom(_Symbol,_Period,"Session-v1",Daily,0,23,0,Yes,Trend,ShowTrend,0,0);
     //double val2 = iCustom(_Symbol,_Period,"Session-v1",Daily,0,23,0,Yes,Trend,ShowTrend,1,0);
     //double val3 = iCustom(_Symbol,_Period,"Session-v1",Daily,0,23,0,Yes,Trend,ShowTrend,2,0);
  }
