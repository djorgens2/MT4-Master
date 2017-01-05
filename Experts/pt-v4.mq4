//+------------------------------------------------------------------+
//|                                                        pt-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "http://www.dennisjorgenson.com"
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <pipMA-v3.mqh>

//--- Operational variables
double ptOrderFOCTrend  = 0.00;
double ptLotsLong       = 0.00;
double ptLotsShort      = 0.00;
int    ptProfitAction   = OP_NO_ACTION;

//+------------------------------------------------------------------+
//| GetData - gets indicator data                                    |
//+------------------------------------------------------------------+
void GetData()
  {
    pipMAGetData();
    regrMAGetData();
    
    ptLotsLong  = LotCount(OP_BUY);
    ptLotsShort = LotCount(OP_SELL);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - repaint visual data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
  }

//+------------------------------------------------------------------+
//| EventOpen - Identifies potential order entry points              |
//+------------------------------------------------------------------+
bool EventOpen(int Action)
  {
     if (Action == OP_SELL &&  data[dataRngDir] == DIR_UP)
     {
       if (data[dataFOCPivDir] == DIR_DOWN)
         return (true);
     }
     
     if (Action == OP_BUY &&  data[dataRngDir] == DIR_DOWN)
     {
       if (data[dataFOCPivDir] == DIR_UP)
         return (true);
     }
     
     return (false);
  }
  
//+------------------------------------------------------------------+
//| EventClose - Identifies potential order exit points              |
//+------------------------------------------------------------------+
bool EventClose(int Action)
  {
     if (Action == OP_SELL && LotCount(OP_BUY)>ptLotsLong && Bid<regr[regrLT] && ptProfitAction!=OP_SELL)
     {
       ptProfitAction = OP_SELL;

       return (true);
     }
     
     if (Action == OP_BUY && LotCount(OP_SELL)>ptLotsShort && Bid>regr[regrLT] && ptProfitAction!=OP_BUY)
     {
       ptProfitAction = OP_BUY;

       return (true);
     }
          
     return (false);
  }

//+------------------------------------------------------------------+
//| AutoTrade - Executes trades in auto mode                         |
//+------------------------------------------------------------------+
void AutoTrade()
  {    
    if (pipMALoaded())
    {
      //--- New orders
      if (data[dataFOCDev]>0.1)
      {
        if (EventOpen(OP_SELL))
          if (Bid>data[dataFOCPiv] && Bid<data[dataRngHigh])
          {
            if (ptOrderFOCTrend != data[dataFOCMax])
            {
              OpenLimitOrder(OP_SELL,data[dataRngHigh],data[dataRngLow],0.00,"Auto",IN_PRICE);
              OpenMITOrder(OP_SELL,data[dataFOCPiv],data[dataRngHigh],0.00,"Auto",IN_PRICE);
              
              ptProfitAction = OP_NO_ACTION;
            }
            
            ptOrderFOCTrend = data[dataFOCMax]; //-- s/b contained in "if" above?
          }

        if (EventOpen(OP_BUY))
          if (Ask<data[dataFOCPiv] && Ask>data[dataRngLow])
          {
            if (ptOrderFOCTrend != data[dataFOCMax])
            {
              OpenLimitOrder(OP_BUY,data[dataRngLow],data[dataRngHigh],0.00,"Auto",IN_PRICE);
              OpenMITOrder(OP_BUY,data[dataFOCPiv],data[dataRngLow],0.00,"Auto",IN_PRICE);

              ptProfitAction = OP_NO_ACTION;
            }
            
            ptOrderFOCTrend = data[dataFOCMax]; //-- s/b contained in "if" above?
          }
      }
      else
      if (orderPending())
      {
        CloseLimitOrder();
        CloseMITOrder();
      }
      
      //--- Profit Orders
      if (EventClose(OP_SELL))
        CloseOrders(CLOSE_CONDITIONAL, OP_SELL);
      
      if (EventClose(OP_BUY))
        CloseOrders(CLOSE_CONDITIONAL, OP_BUY);
    }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();

    manualProcessRequest();
    orderMonitor();

    if (manualAuto)
      AutoTrade();
      
    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();    
    
    SetMode(Auto);
    
    eqhalf   = true;
    eqprofit = true;
    
    SetRisk(80);
    SetTarget(200);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }