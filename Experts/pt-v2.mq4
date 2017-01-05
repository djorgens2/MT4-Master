//+------------------------------------------------------------------+
//|                                                        pt-v2.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.1"
#property strict

#include <manual.mqh>
#include <pipMA-v3.mqh>
#include <regrMA-v1.mqh>

double   lastBid        = 0.00;

int      ptAction       = OP_NO_ACTION;

//+------------------------------------------------------------------+
//| GetData - gets indicator data                                    |
//+------------------------------------------------------------------+
void GetData()
  {
    pipMAGetData();
    regrMAGetData();
  }

//+------------------------------------------------------------------+
//| RefreshScreen - repaint visual data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
     if (manualAuto)
       if (ptAction == OP_NO_ACTION)
         UpdateLabel("ptAction", "Looking for entry");
       else
         UpdateLabel("ptAction", "Waiting on "+proper(ActionText(ptAction)),dirColor(ptAction));
     else
       UpdateLabel("ptAction", manComFile);
  }

//+------------------------------------------------------------------+
//| AutoTrade - Executes trades in auto mode                         |
//+------------------------------------------------------------------+
void AutoTrade()
  {
/*    if (pipMANewHigh() && regr[regrStr] == REGR_STRONG_SHORT)
      ptAction = OP_SELL;
      
    if (ptAction == OP_SELL)
    {
      if (Close[0]>regr[regrST] && data[dataPipDir]==DIR_DOWN)
      {
        OpenLimitOrder(OP_SELL,Close[0]+point(0.5),data[dataRngLow],"Auto", IN_PRICE);

        ptAction = OP_NO_ACTION;
      }
    }
*/
    if (dataLast[dataFOCPivDir]!=data[dataFOCPivDir])
    {
      if (data[dataFOCPivDir]==DIR_UP)
      {
        ptAction = OP_BUY;
        NewArrow(SYMBOL_ARROWUP,clrYellow);
      }
      else
      {
        ptAction = OP_SELL;
        NewArrow(SYMBOL_ARROWDOWN,clrRed);
      }  

    }    
    lastBid = Bid;
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
    
    NewLabel("ptAction","",60,13,clrWhiteSmoke,SCREEN_UL);
    
    Print(AccountLeverage());
    Print(MarketInfo(Symbol(), MODE_LOTSIZE));
    Print(MarketInfo(Symbol(), MODE_MINLOT));
    Print(MarketInfo(Symbol(), MODE_MAXLOT));    
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }