//+------------------------------------------------------------------+
//|                                                       man-v5.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.50"
#property strict

#include <Class\Order.mqh>
#include <Class\PipMA.mqh>

  //--- User Config
  input string        OrderConfig        = "";     //+------ Order Config ------+
  input double        inpMinTarget       = 5.0;    // Equity% Target
  input double        inpMinProfit       = 0.8;    // Minimum Take Profit%
  input double        inpMaxRisk         = 5.0;    // Maximum Risk%
  input double        inpMaxMargin       = 60.0;   // Maximum Margin
  input double        inpLotFactor       = 2.00;   // Lot Risk% of Balance
  input double        inpLotSize         = 0.00;   // Default Lot Size Override
  input double        inpMinLotSize      = 0.25;   // Minimum Lot Size
  input double        inpMaxLotSize      = 30.00;  // Maximum Lot Size
  input int           inpDefaultStop     = 50;     // Default Stop Loss (pips)
  input int           inpDefaultTarget   = 50;     // Default Take Profit (pips)

  input string        PipMAConfig        = "";     //+------ PipMA Config ------+
  input int           inpHistSize        = 80;     // History Retention
  input int           inpRegression      = 9;      // Linear Regression Factor
  input int           inpSMA             = 2;      // SMA Factor
  input double        inpAggSize         = 2.5;    // Tick Aggregation Range

  //-- Structure Defs

  //--- Class Defs
  CPipMA         *pma                = new CPipMA(inpHistSize,inpRegression,inpSMA,inpAggSize);
  COrder         *order              = new COrder(Discount,Hold,Hold);
  
  //--- Data Collections
  AccountMetrics  am;
 
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    pma.Update();
    order.Update(am);
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string rsComment = "";
    
  }

//+------------------------------------------------------------------+
//| ManageLong - Verifies position integrity, adjusts, closures      |
//+------------------------------------------------------------------+
void ManageLong(void)
  {
    
  }
//+------------------------------------------------------------------+
//| ManageShort - Verifies position integrity, adjusts, closures     |
//+------------------------------------------------------------------+
void ManageShort(void)
  {
    OrderRequest eRequest   = order.BlankRequest();
    
    eRequest.Requestor      = "Shorts Manager";
    eRequest.Memo           = "Price Fill Test";
    
    order.SetRiskLimits(OP_SELL,80,80,2);
      
    //--- Queue Order Test
    if (IsEqual(order[OP_SELL].Count,0))
    {
      eRequest.Pend.Type       = OP_SELLSTOP;
      eRequest.Pend.Limit      = 17.982;
      eRequest.Pend.Step       = 2;
      eRequest.Pend.Cancel     = 18.112;
      eRequest.Type            = OP_SELL;
      eRequest.Price           = 0.00;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.982;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));
     
      if (order.Submitted(eRequest))
      {
        Print(order.QueueStr());
        Print(pma.OHLCStr(0));
      }
      else order.PrintLog();
    }
  }

//+------------------------------------------------------------------+
//| UpdateOrders - Verifies position integrity, adjusts, closures    |
//+------------------------------------------------------------------+
void UpdateOrders(void)
  {
    int Tickets[];
    
    if (IsEqual(Close[0],18.076))
      ManageShort();
      
    order.Execute(Tickets,true);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int segment = 3;
    static bool fired  = false;
    
//    if (pma[NewBias])
//      segment  = pma[0].Segment;
//      
//    if (IsEqual(segment,pma[0].Segment))
//      Print(pma.OHLCStr(0));
//      Print(pma.TriggerStr());
//    if (IsEqual(segment,pma[0].Segment))
    //if (pma[0].Segment>segment)
    //  Print(pma.TriggerStr());
//    Print("|OHLC|"+pma.OHLCStr(0));
//    Print("|Trigger|"+pma.TriggerStr());
   //if (IsEqual(pma.Trigger().Event,NewHigh))
   //  Pause("New High","Trigger Event");
//      UpdateOrders();

//    if (pma[NewTick])
//      Print((string)pma[0].Segment);
//    Print(DoubleToStr(pma[0].Open,Digits));
//    Print(DoubleToStr(pma[0].High,Digits));
//    Print(DoubleToStr(pma[0].Low,Digits));
//    Print(DoubleToStr(pma[0].Close,Digits));
//    if (pma[NewTick])
//      Print(pma.OHLCStr());
//      Print(pma.MasterStr());
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    RefreshScreen();
    Execute();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    order.Enable();
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      order.Enable(action);
      order.SetEquityTargets(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetZoneStep(action,2.5,60.0);
    }

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pma;
    delete order;
  }