//+------------------------------------------------------------------+
//|                                                     alert-v1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <pipMA-v3.mqh>

//--- Operational Variables
int      lastEvent    = OP_NO_ACTION;

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData()
  {
    pipMAGetData();
    regrMAGetData();
  }

//+------------------------------------------------------------------+
//| EventAlert                                                       |
//+------------------------------------------------------------------+
void EventAlert(int Action, string Text="")
  {
    Alert(proper(Symbol()+":"+Text+" "+ActionText(Action))+" event occurred");
    lastEvent = Action;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    
    manualProcessRequest();
    orderMonitor();

    if (pipMALoaded)
    {
      if (Bid>data[dataRngHigh]&&lastEvent!=OP_SELL)
        if (Bid>regr[regrLT])
          EventAlert(OP_SELL,"New High");
        else
          EventAlert(OP_SELL,"Rally");
        
      if (Bid<data[dataRngLow]&&lastEvent!=OP_BUY)
        if (Bid<regr[regrLT])
          EventAlert(OP_BUY,"New Low");
        else
          EventAlert(OP_BUY,"Pullback");
    }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();    
    
    SetMode(Manual);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }
