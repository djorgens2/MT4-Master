//+------------------------------------------------------------------+
//|                                                       sig-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property version   "1.30"
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


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string strMsg   = "";  // send buffer
    int    ord      = 0;
    int    ordCount = 0;
    
    manualProcessRequest();
    orderMonitor();    

    ArrayInitialize(ordTickets,0);
       
    if (glbHandle != 0)
    {      
      for (ord=0;ord<OrdersTotal();ord++)
        if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
          if (Symbol()==OrderSymbol())
          {
            strMsg = strMsg +
                     OrderSymbol() +";" +
                     DoubleToStr(OrderTicket(),0) +";" +
                     ActionText(OrderType()) +";" +
                     DoubleToStr(OrderOpenPrice(),Digits) +";" +
                     "\n";

            ordTickets[ord] = OrderTicket();
            ordCount++;
          }

      if (ordCount == 0)
        strMsg   = "No Orders";
        
      int result = QC_SendMessageW(glbHandle, strMsg, 0);
      if (result == 0) Alert("QuickChannel message failed");
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
