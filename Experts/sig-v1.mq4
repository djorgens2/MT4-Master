//+------------------------------------------------------------------+
//|                                                       sig-v1.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <std_utility.mqh>
#include <manual.mqh>

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    int  fHandle=FileOpen("orders.csv",FILE_CSV|FILE_WRITE);
        
    manualProcessRequest();
    orderMonitor();    

    if(fHandle>0)
      for (int ord=0;ord<OrdersTotal();ord++)
        if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
          FileWrite(fHandle,DoubleToStr(OrderTicket(),0)+";"+ActionText(OrderType())+";"+DoubleToStr(OrderOpenPrice(),Digits));

    FileClose(fHandle);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {    
    manualInit();

    return(INIT_SUCCEEDED);
  }
