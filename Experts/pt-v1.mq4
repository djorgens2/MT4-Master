//+------------------------------------------------------------------+
//|                                                        pt-v1.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <pipMA-v3.mqh>
#include <std_order.mqh>

//--- Trade(td) operational vars
bool      tdOrderEntry       = false;
bool      tdOrderPending     = false;

int       tdOrderAction      = OP_NO_ACTION;

//+------------------------------------------------------------------+
//| GetData - update current trade data                              |
//+------------------------------------------------------------------+
void GetData()
  {
    //--- get order details
    ordGetData();
    
    //--- get pipMA data
    pipMAGetData();
                 
  }

//+------------------------------------------------------------------+
//| RefreshScreen - updates screen labels and indicators             |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    ordRefreshScreen();
    
    UpdateLabel("lbDataRngMA",DoubleToStr(data[0],Digits)+":"+DoubleToStr(data[1],Digits)+":"+DoubleToStr(data[2],Digits)+":"+DoubleToStr(data[3],Digits)+":"+DoubleToStr(data[4],Digits));
  }

//+------------------------------------------------------------------+
//| OrderEntry - Scans for trade openings                            |
//+------------------------------------------------------------------+
bool OrderEntry()
  {
/*    if (pipMASTLoaded())
    {
      if (pipMANewHigh())
      {
        if (ObjectFind("arrow_"+TimeToStr(Time[0])+":init") < 0)
          NewArrow(4,clrYellow,"init");
        if (tdOrderAction!= OP_SELL)
          NewArrow(SYMBOL_ARROWUP,clrDodgerBlue,"NewHigh");
        tdOrderAction      = OP_SELL;
        return(true);
      }

      if (pipMANewLow())
      {
        if (ObjectFind("arrow_"+TimeToStr(Time[0])+":init") < 0)
          NewArrow(4,clrYellow,"init");
        if (tdOrderAction!= OP_BUY)
          NewArrow(SYMBOL_ARROWDOWN,clrRed,"NewLow");
        tdOrderAction      = OP_BUY;
        return(true);
      }
    }
*/   
    return(false);
  }

//+------------------------------------------------------------------+
//| ExecuteOrder - Validates indicators and executes favorable trades|
//+------------------------------------------------------------------+
void ExecuteOrder()
  {
    int action             = ordEntryMonitor();
    
    if (action == ORD_OPEN_MIT)
    {
      tdOrderEntry         = false;
      tdOrderPending       = false;
    }
  }

//+------------------------------------------------------------------+
//| Monitor - Identifies market entry opportunities                  |
//+------------------------------------------------------------------+
void EntryMonitor()
  {
/*    if (tdOrderPending)
      ExecuteOrder();
    else
    if (tdOrderEntry)
    {
      if (tdOrderAction == OP_BUY && pipMANewLow())
        tdOrderPending       = ordOpenMIT(OP_BUY, pipMA[pipMAMid], Close[0]);

      if (tdOrderAction == OP_SELL && pipMANewHigh())
        tdOrderPending       = ordOpenMIT(OP_SELL, pipMA[pipMAMid], Close[0]);
    }
    else */tdOrderEntry        = OrderEntry();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    RefreshScreen();
    
    EntryMonitor();
    //ProfitMonitor();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ordInit();
            
    NewLabel("lbDataRngMA","",5,33,clrWhite,SCREEN_UL);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }
