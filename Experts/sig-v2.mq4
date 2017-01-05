//+------------------------------------------------------------------+
//|                                                       sig-v2.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#import "FXBlueQuickChannel.dll"
  int QC_StartSenderW(string);
  int QC_ReleaseSender(int);
  int QC_SendMessageW(int, string, int);
  int QC_StartReceiverW(string, int);
  int QC_ReleaseReceiver(int);
  int QC_GetMessages5W(int, uchar&[], int);
  int QC_CheckChannelW(string);
  int QC_ChannelHasReceiverW(string);
#import

#include <std_utility.mqh>
#include <manual.mqh>

// External, user-configurable properties
input string  ChannelName = "QuickChannelTest";  //Sender Name


int glbHandle = 0;      // Handle which is acquired during init() and freed during deinit()
int ordTickets[10];     // Ticket list
int ordTicketsLast[10]; // holds all tickets from prior tick

double ordBestPrice       = 0.00;
int    ordBestAction      = OP_NO_ACTION;

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string strMsg = "";  // send buffer
    int    ord=0;
    
    manualProcessRequest();
    orderMonitor();    

    ArrayCopy(ordTicketsLast,ordTickets);
    ArrayInitialize(ordTickets,0);
       
    if (glbHandle != 0)
    {      
      while (ordTicketsLast[ord]>0)
      {
        if (OrderSelect(ordTicketsLast[ord],SELECT_BY_TICKET,MODE_HISTORY) && OrderCloseTime()>0)
          strMsg = strMsg +
                   OrderSymbol() +";" +
                   DoubleToStr(OrderTicket(),0) +";" +
                   ActionText(OrderType()) +";" +
                   DoubleToStr(OrderOpenPrice(),Digits) +";" +
                   DoubleToStr(OrderClosePrice(),Digits) +";" +
                   DoubleToStr(OrderProfit(),Digits) +"\n";

          ord++;
      }

      for (ord=0;ord<OrdersTotal();ord++)
        if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        {
          strMsg = strMsg +
                   OrderSymbol() +";" +
                   DoubleToStr(OrderTicket(),0) +";" +
                   ActionText(OrderType()) +";" +
                   DoubleToStr(OrderOpenPrice(),Digits) +";" +
                   DoubleToStr(0.00,Digits) +";" +
                   DoubleToStr(0.00,Digits) +"\n";

          ordTickets[ord] = OrderTicket();
        }

      int result = QC_SendMessageW(glbHandle, strMsg, 0);
      if (result == 0) Alert("QuickChannel message failed");
    }
    
    if (orderPending())
    {
      if (ordBestAction == OP_NO_ACTION)
      {
        ordBestAction  = fmax(ordLimitAction,ordMITAction);
        ordBestPrice   = ActionPrice(fmax(ordLimitAction,ordMITAction));        
      }
      else
      {
        if (ordBestAction == OP_BUY)
          ordBestPrice = fmin(ordBestPrice,Ask);
          
        if (ordBestAction == OP_SELL)
          ordBestPrice = fmax(ordBestPrice,Bid);        
      }      

      Comment(ActionText(ordBestAction)+" "+DoubleToStr(ordBestPrice,Digits));
    }
    else
    {
      ordBestPrice  = 0.00;
      ordBestAction = OP_NO_ACTION;
    }

  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    glbHandle = QC_StartSenderW(ChannelName);
   
    if (glbHandle == 0)
      Alert("Failed to get a QuickChannel sender handle");
      
    manualInit();
      
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    QC_ReleaseSender(glbHandle);
    glbHandle = 0;
  }
