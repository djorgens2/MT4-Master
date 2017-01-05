//+------------------------------------------------------------------+
//|                                                     tcopy-v1.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
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

#include <manual.mqh>
#include <pipMA-v3.mqh>

//--- user-configurable properties
input string  ChannelName    = "QuickChannelTest";  // Channel Name
input string  SymbolOverride = "";                  // Symbol

#define QC_BUFFER_SIZE     10000

#define STRAT_DROP          1 //-- Order processing finalized
#define STRAT_NONE          0 //-- No action
#define STRAT_CLOSE        -1 //-- Waiting for close
#define STRAT_CARRY        -2 //-- Wait for close exit price

//--- order array constants
#define cOrdMeasures       12
#define cOrdMSymbol         0
#define cOrdMTicket         1
#define cOrdMAction         2
#define cOrdMEntryPrice     3
#define cOrdMExitPrice      4
#define cOrdMProfit         5
#define cOrdSTicket         6
#define cOrdSAction         7
#define cOrdSEntryPrice     8
#define cOrdSExitPrice      9
#define cOrdSExitClose     10
#define cOrdSStatus        11


// Handle which is acquired during start() and freed during deinit()
int glbHandle = 0;

//--- order variables
string ordList[][6];
double ordRec[20][cOrdMeasures];
int    ordMOpen      = 0;
int    ordMClose     = 0;
int    ordMMsgCnt    = 0;


//--- trade copy operataional vars
int    tcAction      = OP_NO_ACTION;
int    tcDir         = DIR_NONE;

double tcEntryPrice  = 0.00;
double tcEventPrice  = 0.00;
double tcCarryPrice  = 0.00;
double tcEntryCount  = 0.00;

string tcSymbol      = Symbol();

//--- history
double lastBid       = Bid;
double lastAsk       = Ask;

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
        ordMMsgCnt = 0;
      else
      {
        string strMsgList = CharArrayToString(buffer, 0, res);
        
        if (strMsgList != "")
        {         
          string Messages[];
          string Orders[];
          
          StringSplit(strMsgList, "\n", Messages);
          ArrayResize(ordList, ArraySize(Messages)-1);
          
          ordMMsgCnt = ArraySize(Messages)-1;

          for (int i = 0; i < ArraySize(Messages)-1; i++)
          {
            StringSplit(Messages[i],";",Orders);
            
            for (int j=0;j<ArraySize(Orders);j++)
              ordList[i][j] = Orders[j];
          }
        }  
      }
    }
  }

//+------------------------------------------------------------------+
//| GetData - retrieves indicator data and processes channel         |
//+------------------------------------------------------------------+
void GetData()
  {
    int idx;
    int ord;

    pipMAGetData();
    
    GetChannelData();
    
    ordMOpen  = 0;
    ordMClose = 0;
    
    //--- merge channel data
    for (ord=0; ord<ArrayRange(ordList,0); ord++)
    {
      if (ordList[ord][cOrdMSymbol] == tcSymbol)
      {
        for (idx = 0; idx<ArrayRange(ordRec,0);idx++)
        {
          if (ordRec[idx][cOrdMTicket] == StrToDouble(ordList[ord][cOrdMTicket]) ||
              ordRec[idx][cOrdMTicket] == 0.00)
            break;
        }
          
        ordRec[idx][cOrdMTicket]     = StrToInteger(ordList[ord][cOrdMTicket]);
        ordRec[idx][cOrdMAction]     = ActionCode(ordList[ord][cOrdMAction]);
        ordRec[idx][cOrdMEntryPrice] = StrToDouble(ordList[ord][cOrdMEntryPrice]);
        ordRec[idx][cOrdMExitPrice]  = StrToDouble(ordList[ord][cOrdMExitPrice]);
        ordRec[idx][cOrdMProfit]     = StrToDouble(ordList[ord][cOrdMProfit]);
        ordRec[idx][cOrdSStatus]     = OP_NO_ACTION;

        if (ordRec[idx][cOrdMExitPrice]>0.00)
          if (ordRec[idx][cOrdSTicket] == 0.00)
          {
            ordRec[idx][cOrdSStatus]   = OP_CLOSE;
            ordRec[idx][cOrdSExitClose]= STRAT_DROP;
          }
          else
          if (ordRec[idx][cOrdMProfit] < 0.00)
            ordRec[idx][cOrdSStatus]   = OP_HALT;
          else
            ordRec[idx][cOrdSStatus]   = OP_CLOSE;
      }
    }
    
    //--- merge channel updates and current open positions
    for (ord=0; ord<OrdersTotal(); ord++)
    {
      if (OrderSelect(ord, SELECT_BY_POS, MODE_TRADES))
      {
        for (idx = 0; idx<ArrayRange(ordRec,0);idx++)
          if (ordRec[idx][cOrdMTicket] == StrToInteger(OrderComment()) ||
              ordRec[idx][cOrdMTicket] == 0.00)
            break;
        
        ordRec[idx][cOrdSTicket]     = OrderTicket();
        ordRec[idx][cOrdSAction]     = OrderType();
        ordRec[idx][cOrdSEntryPrice] = OrderOpenPrice();

        if (ordRec[idx][cOrdSStatus] == OP_NO_ACTION)
          ordRec[idx][cOrdSStatus]     = OrderType();
        
        if (ordRec[ord][cOrdMTicket] == 0.00)
        {
          ordRec[idx][cOrdMTicket]   = StrToInteger(OrderComment());
          ordRec[idx][cOrdSStatus]   = OP_HALT;
        }
      }
    }
    
    //--- update closed positions
    for (ord = 0; ord<ArrayRange(ordRec,0);ord++)
    {
      if (ordRec[ord][cOrdSTicket] > 0.00)
        if (OrderSelect((int)ordRec[ord][cOrdSTicket], SELECT_BY_TICKET, MODE_HISTORY))
          if (OrderCloseTime() > 0)
          {
            ordRec[ord][cOrdSExitPrice] = OrderClosePrice();
            ordRec[ord][cOrdSExitClose] = STRAT_DROP;
            ordRec[ord][cOrdSStatus]    = OP_CLOSE;
          }

      if (ordRec[ord][cOrdMEntryPrice]>0.00)
      {
        if (ordRec[ord][cOrdMExitPrice]>0.00)
          ordMClose++;
        else
          ordMOpen++;
      }          
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - paints screen indicators and data                |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    string msg       = ActionText(tcAction)+" ("+IntegerToString(ordMOpen)+":"+IntegerToString(ordMClose)+":"+IntegerToString(ordMMsgCnt)+")\n";
    string newAction;

    int    ord       =  0;
    
    while (ordRec[ord][cOrdMTicket]>0.00)
    {
      if (ordRec[ord][cOrdSStatus] == OP_NO_ACTION)
        newAction    = "PEND";
      else
        newAction    = ActionText((int)ordRec[ord][cOrdSStatus]);
        
      msg = msg +
            DoubleToStr(ordRec[ord][cOrdMTicket],0) + " | " +
            ActionText((int)ordRec[ord][cOrdMAction]) + " | " +
            DoubleToStr(ordRec[ord][cOrdMEntryPrice],Digits) + " | " +
            DoubleToStr(ordRec[ord][cOrdMExitPrice], Digits) + " | " +
            DoubleToStr(ordRec[ord][cOrdSTicket],0) + " | " +
            newAction + " | " +
            DoubleToStr(ordRec[ord][cOrdSEntryPrice],Digits) + " | " +
            DoubleToStr(ordRec[ord][cOrdSExitPrice],Digits) + " | " +
            DoubleToStr(ordRec[ord][cOrdSExitClose],0) + " | " +
            ActionText((int)ordRec[ord][cOrdSStatus]) +"\n";

      ord++;
    }
    
    Comment(msg);  
  }
  
//+------------------------------------------------------------------+
//| CopyTrade - Executes the copy trade strategy                     |
//+------------------------------------------------------------------+
void CopyTrade()
  {
    int    ord;
    int    ordDir;

    int    bestTicket  = 0;
    double bestPrice   = 0.00;
    
    if (tcAction == OP_PEND)
    {
      if (EquityPercent()<=ordMinEQClose)
        CloseOrders(CLOSE_ALL);
    }
    else
    {
      tcAction = OP_NO_ACTION;
    
      for (ord=0; ord<ArrayRange(ordRec,0); ord++)
      {
        if (tcAction != OP_CLOSE)    
        {
          if (ordRec[ord][cOrdSStatus] == OP_NO_ACTION)
          {
            bestTicket     = (int)ordRec[ord][cOrdMTicket];

            if (ordRec[ord][cOrdMAction] == OP_BUY)
            {
              if (bestPrice == 0.00)
                bestPrice  = fmin(lastAsk,ordRec[ord][cOrdMEntryPrice])-point(0.5);
              else
                bestPrice  = fmin(bestPrice,ordRec[ord][cOrdMEntryPrice])-point(0.5);

              tcAction     = OP_BUY;
              tcDir        = DIR_UP;
            }
        
            if (ordRec[ord][cOrdMAction] == OP_SELL)
            {
              if (bestPrice == 0.00)
                bestPrice  = fmax(lastBid,ordRec[ord][cOrdMEntryPrice])+point(0.5);
              else
                bestPrice  = fmax(bestPrice,ordRec[ord][cOrdMEntryPrice])+point(0.5);

              tcAction     = OP_SELL;
              tcDir        = DIR_DOWN;
            }        
          }
        }
      
        if (ordRec[ord][cOrdSStatus] == OP_CLOSE)
        {
          if (ordRec[ord][cOrdSExitClose] == STRAT_NONE)
          {
            tcAction                    = OP_CLOSE;
            tcDir                       = DIR_NONE;
            
            if (ordRec[ord][cOrdSAction] == OP_SELL) tcDir = DIR_DOWN;
            if (ordRec[ord][cOrdSAction] == OP_BUY)  tcDir = DIR_UP;

            ordRec[ord][cOrdSExitClose] = -1;
            ordRec[ord][cOrdSExitPrice] = ActionPrice((int)ordRec[ord][cOrdSAction]);       
          } 
          else
            if (ordRec[ord][cOrdSExitClose] != data[data[dataPipDir]
            tcAction       = OP_CLOSE;
        }
        
        if (ordRec[ord][cOrdSStatus] == OP_HALT)
          CloseOrder((int)ordRec[ord][cOrdSTicket],true);
      }
    
      if (ordMOpen == 0)
      {
        SetTarget(EquityPercent()+0.1);

        tcAction = OP_PEND;
      }
      else
      if (tcAction == OP_CLOSE)
        for (ord=0; ord<ArrayRange(ordRec,0); ord++)
        {
          if (ordRec[ord][cOrdSExitClose] == -1 &&
                 (ActionPrice((int)ordRec[ord][cOrdSAction])>ordRec[ord][cOrdSExitPrice]+point(0.5)||
                  ActionPrice((int)ordRec[ord][cOrdSAction])<ordRec[ord][cOrdSExitPrice]-point(0.5)))
              CloseOrder((int)ordRec[ord][cOrdSTicket],true);
          }
      }
      else
      if (!orderPending())
        OpenLimitOrder(tcAction,bestPrice,0.00,LotSize(),IntegerToString(bestTicket),IN_PRICE);
    }
 
    if (OrdersTotal() == 0)
    {
      SetTarget(ordMinTarget);

      if (ordMOpen == 0)
      {
        ArrayInitialize(ordRec,0.00);

        tcAction = OP_NO_ACTION;
        
        if (orderPending())
        {
          CloseLimitOrder();
          CloseMITOrder();
        }
      }
    }     

    lastBid = Bid;
    lastAsk = Ask;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    CopyTrade();
    RefreshScreen();
    
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
    
    ArrayInitialize(ordRec,0.00);
 
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
