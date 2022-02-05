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
#include <Class\TickMA.mqh>

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

  input string        PipMAConfig        = "";     //+------ TickMA Config ------+
  input int           inpRetention       = 80;     // History Retention
  input int           intDegree          = 6;      // Polynomial Regression Degree
  input double        inpTickAgg         = 2.5;    // Tick Aggregation Range

  //-- Structure Defs

  //--- Class Defs
  CTickMA        *t                  = new CTickMA(inpRetention,intDegree,inpTickAgg);
  COrder         *order              = new COrder(Discount,Hold,Hold);
 
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    t.Update();
    order.Update();
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
    static OrderRequest request;

    if (IsEqual(t.Linear().Bias,OP_BUY))
      if (t[NewBias])
      {
        request                = order.BlankRequest("[Auto] Long");
        request.Memo           = "[Seg:"+(string)t.Count(Segments)+"]";

        request.Type           = OP_BUY;
        request.Price          = t.Linear().Open.Price[0];
        request.TakeProfit     = 0.00;
        request.StopLoss       = 0.00;
      }
    
    order.SetRiskLimits(OP_BUY,80,60,2.5);
      
    //--- Queue Order Test
    if (IsEqual(request.Type,OP_BUY))
      if (IsEqual(t.Linear().Bias,t.Segment(0).Bias))
        if (IsHigher(Bid,request.Price))
        {
          request.Pend.Type       = OP_NO_ACTION;
          request.Pend.Step       = 2;
          request.Pend.Limit      = Bid-point(inpDefaultTarget);
          request.Pend.Cancel     = Bid+point(10);
          request.Expiry          = TimeCurrent()+(Period()*(60*12));
     
          if (order.Submitted(request))
            request.Type          = OP_NO_ACTION;
          else order.PrintLog();
        }
    
    order.ExecuteOrders(OP_BUY);
  }

//+------------------------------------------------------------------+
//| ManageShort - Verifies position integrity, adjusts, closures     |
//+------------------------------------------------------------------+
void ManageShort(void)
  {
    static OrderRequest request;
    
    if (IsEqual(t.Linear().Bias,OP_SELL))
      if (t[NewBias])
      {
        request                = order.BlankRequest("[Auto] Short");
        request.Memo           = "[Seg:"+(string)t.Count(Segments)+"]";

        request.Type           = OP_SELL;
        request.Price          = t.Linear().Open.Price[0];
        request.TakeProfit     = 0.00;
        request.StopLoss       = 0.00;
      }
    
    order.SetRiskLimits(OP_SELL,80,60,2.5);
      
    //--- Queue Order Test
    if (IsEqual(request.Type,OP_SELL))
      if (IsEqual(t.Linear().Bias,t.Segment(0).Bias))
        if (IsHigher(Bid,request.Price))
        {
          request.Pend.Type       = OP_NO_ACTION;
          request.Pend.Step       = 2;
          request.Pend.Limit      = Bid-point(inpDefaultTarget);
          request.Pend.Cancel     = Bid+point(10);
          request.Expiry          = TimeCurrent()+(Period()*(60*12));
     
          if (order.Submitted(request))
            request.Type          = OP_NO_ACTION;
          else order.PrintLog();
        }

    order.ExecuteOrders(OP_SELL);
  }

//+------------------------------------------------------------------+
//| UpdateOrders - Verifies position integrity, adjusts, closures    |
//+------------------------------------------------------------------+
void UpdateOrders(void)
  {
    ManageLong();
    ManageShort();
      
    order.ExecuteRequests();
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int count  = 0;
    
    if (order[Net].Count<count)
    {
//      Print(order.OrderStr());
      count--;
    }
//    if (pma[NewHigh])
//      Print(pma.MasterStr());
//      Print(pma.OHLCStr(0));
//      
//    if (IsBetween(pma[0].Segment,11,12))
//      Print(pma.TickStr());
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
      UpdateOrders();

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
    delete t;
    delete order;
  }