//+------------------------------------------------------------------+
//|                                                    apiary-v1.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <std_utility.mqh>
#include <Manual.mqh>

#define cOrdMTicket         0
#define cOrdMAction         1
#define cOrdMEntryPrice     2
#define cOrdSTicket         3

double ordRec[4][4];
double ordRecClose[4][2];

int    ordRecCount;
int    ordRecCloseCount;

int    actionM  = OP_NO_ACTION;
int    actionS  = OP_NO_ACTION;

bool   tp       = false;


//+------------------------------------------------------------------+
//| GetData - get trade data to copy                                 |
//+------------------------------------------------------------------+
void GetData()
  {
    int    try     =  0;
    int    fHandle = -1;
    string fRecord = "";
    
    int    ticket;

    actionM  = OP_NO_ACTION;
    actionS  = OP_NO_ACTION;
    
    //--- Get master
    ArrayInitialize(ordRec,0.00);

    while(fHandle<0)
    {
      fHandle=FileOpen("orders.csv",FILE_TXT|FILE_READ);

      if(fHandle<0)
        if (try==100)
        {
          Print("Error opening file for read: ",GetLastError());
          break;
        }
        else try++;
      else
      {
        ordRecCount = 0;
        
        while (FileIsEnding(fHandle)==false)
        {
          fRecord = FileReadString(fHandle);
          
          Parse(fRecord,";");
          
          actionM = ActionCode(params[1]);

          ordRec[ordRecCount][cOrdMTicket]     = StrToInteger(params[0]);
          ordRec[ordRecCount][cOrdMAction]     = actionM;
          ordRec[ordRecCount][cOrdMEntryPrice] = StrToDouble(params[2]);

          ordRecCount++;
        }
      }
    }

    FileClose(fHandle);

    //--- Get slave
    ArrayInitialize(ordRecClose,0.00);
    
    ordRecCloseCount = 0;
    
    for (int idx1=0; idx1<OrdersTotal(); idx1++)
    {
      bool found = false;
      
      if (OrderSelect(idx1,SELECT_BY_POS,MODE_TRADES))
      {
        ticket  = StrToInteger(OrderComment());
        actionS = OrderType();

        for (int idx2=0; idx2<ordRecCount; idx2++)
          if (ticket == ordRec[idx2][cOrdMTicket])
          {
            ordRec[idx2][cOrdSTicket] = OrderTicket();
            found = true;
          }
          
        if (!found)
        {
          ordRecClose[ordRecCloseCount][cOrdMTicket] = OrderTicket();
          ordRecClose[ordRecCloseCount][cOrdMAction] = actionS;

          if (OrderProfit()<0.00)
            CloseOrder(OrderTicket(),true);
          else
            ordRecCloseCount++;
        }
      }
    }
  }

//+------------------------------------------------------------------+
//| ProcessData - create orders and handle exits                     |
//+------------------------------------------------------------------+
void ProcessData()
  {
    double price  = 0.00;
    
    //--- execute closures
    if (OrdersTotal()>0)
    {
      if (ordRecCount == 0 && !tp)
      {
        SetTarget(EquityPercent());
        tp = true;
      }

      if (tp && EquityPercent()<0.5)
        CloseOrders(CLOSE_ALL);
        
      if (ordRecCount>0 && ordRecCloseCount>0)
        for (int idx=0; idx<ordRecCloseCount; idx++)
          CloseOrder((int)ordRecClose[idx][cOrdMTicket]);
    }
    else
    {
      SetTarget(ordMinTarget);
      tp = false;      
    }
    
    if (ordRecCount == 0)
    {
      CloseLimitOrder();
      CloseMITOrder();
    }
    
    //--- execute opens
    for (int idx=0; idx<ordRecCount; idx++)
      if (ordRec[idx][cOrdSTicket]==0.00)
        if (!orderPending())
        {
          if (ordRec[idx][cOrdMAction]==OP_BUY)
            price = fmin(Ask-point(0.5),ordRec[idx][cOrdMEntryPrice]-point(0.5));
               
          if (ordRec[idx][cOrdMAction]==OP_SELL)
            price = fmax(Bid+point(0.5),ordRec[idx][cOrdMEntryPrice]+point(0.5));

         OpenLimitOrder((int)ordRec[idx][cOrdMAction],price,0.00,DoubleToStr(ordRec[idx][cOrdMTicket],0),IN_PRICE);
       }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    ProcessData();
    
    manualProcessRequest();
    orderMonitor();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();
    
    return(INIT_SUCCEEDED);
  }
