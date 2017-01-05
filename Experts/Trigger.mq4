//+------------------------------------------------------------------+
//|                                                      Trigger.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\Order.mqh>

double trHighPrice       = High[0];
double trLowPrice        = Low[0];

double trBasePrice       = NoValue;
double trRootPrice       = NoValue;
double trExpansionPrice  = NoValue;
double trRetracePrice    = NoValue;

int    trDirection       = DirectionNone;

COrder *trOrder[];


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {    
    if (IsChanged(trHighPrice, fmax(trHighPrice,Close[0]),Digits))
    {
      if (IsChanged(trDirection,DirectionUp))
      {
        trBasePrice     = fmin(trLowPrice,Close[0]);
        trRootPrice     = High[0];
        trRetracePrice  = Close[0];
      }

    }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }
