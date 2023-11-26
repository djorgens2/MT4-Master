//+------------------------------------------------------------------+
//|                                                     tcopy-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

// Imports from the QuickChannel library
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

#define cOrdMSymbol         0
#define cOrdMTicket         1
#define cOrdMAction         2
#define cOrdMEntryPrice     3

#include <manual.mqh>

//--- user-configurable properties
input string  ChannelName    = "QuickChannelTest";  // Channel Name
input string  SymbolOverride = "";                  // Symbol
input bool    EnableHedging  = false;               // Enable Hedging (assumes master is uni-directional)

#define QC_BUFFER_SIZE     10000

// Handle which is acquired during start() and freed during deinit()
int glbHandle = 0;

//--- order variables
string Messages[];
string Orders[];
string OrderDetail[];

//--- trade copy operataional vars
int    tcAction           = OP_NO_ACTION;
int    tcMasterAction     = OP_NO_ACTION;

int    tcOrdCount         = 0;
int    tcMsgCount         = 0;
int    tcLongCount        = 0;
int    tcShortCount       = 0;

string tcSymbol           = Symbol();

int    tcSlaveCount       = 0;
int    tcSlaveLongCount   = 0;
int    tcSlaveShortCount  = 0;

string msg                = "";
string order              = "";
  
//+------------------------------------------------------------------+
//| GetChannelData - retrieves open positions from the master        |
//+------------------------------------------------------------------+
void GetChannelData()
  {
    if (glbHandle == 0)
    {
      glbHandle = QC_StartReceiverW(ChannelName, WindowHandle(tcSymbol, Period()));
   
      if (glbHandle == 0)
        Comment("Failed to get a QuickChannel receiver handle");
    }
    
    if (glbHandle != 0)
    {
      uchar buffer[];
      ArrayResize(buffer, QC_BUFFER_SIZE);
      
      int res = QC_GetMessages5W(glbHandle, buffer, QC_BUFFER_SIZE);
      
      if (res == 0)
        tcMsgCount = 0;
      else
      {
        string strMsgList = CharArrayToString(buffer, 0, res);
        
        order        = "";

        tcLongCount  = 0;
        tcShortCount = 0;

        tcMsgCount        = StringSplit(strMsgList, "\t", Messages);
        
        if (tcMsgCount>0)
        {
          tcOrdCount        = StringSplit(Messages[tcMsgCount-1], "\n", Orders);
        
          if (Orders[0]!="No Orders")
          {
            for (int idx=0; idx<tcOrdCount; idx++)
            {
              StringSplit(Orders[idx],";",OrderDetail);
              tcAction        = ActionCode(OrderDetail[2]);
   
              if (tcAction == OP_BUY)  tcLongCount++;
              if (tcAction == OP_SELL) tcShortCount++;
   
              order = order +
                      OrderDetail[0] + " | " +
                      OrderDetail[1] + " | " +
                      OrderDetail[2] + " | " +
                      OrderDetail[3] + " | " +
                      "\n";
            }
             
            tcMasterAction     = OP_NO_ACTION;
             
            if (EnableHedging)
            {
              if (tcLongCount  > 0) tcMasterAction = OP_BUY;
              if (tcShortCount > 0) tcMasterAction = OP_SELL;
            }
          }
        }
      }
    }
  }

//+------------------------------------------------------------------+
//| GetData - processes channel and compiles active order info       |
//+------------------------------------------------------------------+
void GetData()
  {    
    GetChannelData();
    
    tcSlaveCount      = 0;
    tcSlaveLongCount  = 0;
    tcSlaveShortCount = 0;
    
    for (int idx=0; idx<OrdersTotal(); idx++)
      if (OrderSelect(idx,SELECT_BY_POS,MODE_TRADES))
        if (tcSymbol == OrderSymbol())
        {
          tcSlaveCount++;
          
          if (OrderType() == OP_BUY)  tcSlaveLongCount++;
          if (OrderType() == OP_SELL) tcSlaveShortCount++;
        }
  }
 
//+------------------------------------------------------------------+
//| CopyTrade - Executes the copy trade strategy                     |
//+------------------------------------------------------------------+
void CopyTrade()
  {
    int ord;
        
    int  OpenLong    = fmax(tcLongCount-tcSlaveLongCount,0);
    int  CloseLong   = fmax(tcSlaveLongCount-tcLongCount,0);
    int  OpenShort   = fmax(tcShortCount-tcSlaveShortCount,0);
    int  CloseShort  = fmax(tcSlaveShortCount-tcShortCount,0);
    

    msg  = ChannelName+" ("+tcSymbol+":"+IntegerToString(glbHandle)+")\n" +
           "Master: Long("+IntegerToString(tcLongCount)+") Short("+IntegerToString(tcShortCount)+")\n"
           "Slave: "+tcSymbol+" ("+IntegerToString(tcSlaveCount)+":"+IntegerToString(tcSlaveLongCount)+":"+IntegerToString(tcSlaveShortCount)
                    +") CS: "+IntegerToString(CloseShort)+" CL:"+IntegerToString(CloseLong)+" OS:"+IntegerToString(OpenShort)+" OL:"+IntegerToString(OpenLong)+"\n"+order;

    Comment(msg);
    
    if (EnableHedging)
    {
    }
    else
    {
      for (ord=0; ord<CloseShort; ord++) CloseOrders(CLOSE_MAX);
      for (ord=0; ord<CloseLong;  ord++) CloseOrders(CLOSE_MAX);
      for (ord=0; ord<OpenShort;  ord++) OpenOrder(OP_SELL,"tcopy-v2");
      for (ord=0; ord<OpenLong;   ord++) OpenOrder(OP_BUY,"tcopy-v2");
    }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    CopyTrade();
    
    manualProcessRequest();
    orderMonitor();
    
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    Comment("Initializing");
    manualInit();
 
    if (StringLen(SymbolOverride)>0)
      tcSymbol = SymbolOverride;
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    QC_ReleaseReceiver(glbHandle);
    glbHandle = 0;
  }
