//+------------------------------------------------------------------+
//|                                                         Test.mq4 |
//|                                                 Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define Hide       true
#define NoHide     false
#define NoQueue    false

#include <Class/Order.mqh>
#include <Class/TickMA.mqh>

//--- input parameters
input string        ordRegrConfig      = "";          // +--- Regression Config ---+
input int           inpPeriods         = 80;          // Retention
input int           inpDegree          = 6;           // Poiy Regression Degree
input double        inpAgg             = 2.5;         // Tick Aggregation
input PriceType     inpShowFractal     = PriceTypes;  // Show Fractal

input string        ordHeader          = "";          // +----- Order Options -----+
input BrokerModel   inpBrokerModel     = Discount;    // Brokerage Leverage Model
input OrderMethod   inpMethodLong      = Hold;        // Buy Method        
input OrderMethod   inpMethodShort     = Hold;        // Sell Method        
input double        inpMinTarget       = 5.0;         // Equity% Target
input double        inpMinProfit       = 0.8;         // Minimum take profit%
input double        inpMaxRisk         = 5.0;         // Maximum Risk%
input double        inpMaxMargin       = 60.0;        // Maximum Margin
input double        inpLotFactor       = 2.00;        // Lot Risk% of Balance
input double        inpLotSize         = 0.00;        // Lot size override
input int           inpDefaultStop     = 50;          // Default Stop Loss (pips)
input int           inpDefaultTarget   = 50;          // Default Take Profit (pips)

CTickMA       *tick                    = new CTickMA(inpPeriods,inpDegree,inpAgg);
COrder        *order                   = new COrder(inpBrokerModel,inpMethodLong,inpMethodShort);

bool           PauseOn                 = true;
int            Tick                    = 0;

int            Tickets[];
OrderSummary   NodeNow[2];
int            IndexNow[2];

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+`
void GetData(void)
  {
    static int index[2]  = {0,0};
    
    tick.Update();
    order.Update();
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      IndexNow[action]    = order.Zone(action);
      order.GetZone(action,IndexNow[action],NodeNow[action]);

      //if (IsChanged(index[action],IndexNow[action]))
      //  Print(order.ZoneSummaryStr(action));
    }
    
    if (order.Fulfilled())
    {
//      Print(DoubleToStr(order[Net].Margin,1)+"%");
//      Print(DoubleToStr(order[OP_BUY].Lots,Account.LotPrecision)+" $"+DoubleToStr(order[OP_BUY].Value,0));
//      for (int node=0;node<order.Nodes(OP_BUY);node++)
//      Print("Zone: $"+DoubleToStr(order.Zone(OP_BUY,node).Value,2));
    }
  }



//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    const color linecolor[] = {clrWhite,clrYellow,clrLawnGreen,clrRed,clrGoldenrod,clrSteelBlue};
    double f[];
    
    if (!IsEqual(inpShowFractal,PriceTypes))
    {
      if (inpShowFractal==ptOpen)   ArrayCopy(f,tick.SMA().Open.Point);
      if (inpShowFractal==ptHigh)   ArrayCopy(f,tick.SMA().High.Point);
      if (inpShowFractal==ptLow)    ArrayCopy(f,tick.SMA().Low.Point);
      if (inpShowFractal==ptClose)  ArrayCopy(f,tick.SMA().Close.Point);

      for (FractalPoint fp=0;fp<FractalPoints;fp++)
        UpdateLine("tmaSMAFractal:"+StringSubstr(EnumToString(fp),2),f[fp],STYLE_SOLID,linecolor[fp]);
    }
    
    UpdateLine("czDCA:"+(string)OP_BUY,order.DCA(OP_BUY),STYLE_DOT,clrGoldenrod);
    
    if (tick.ActiveEvent())
    {
      string text = "";

      for (EventType event=1;event<EventTypes;event++)
        if (tick[event])
        {
          Append(text,EventText[event],"\n");
          Append(text,EnumToString(tick.AlertLevel(event)));
        }
      Comment(text);
    }
  }

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (PauseOn)
      Pause(Message,AccountCompany()+" Event Trapper");
    else
      Print(Message);
  }

//+------------------------------------------------------------------+
//| Stop/TP Test                                                     |
//+------------------------------------------------------------------+
void Test1(void)
  {    
    OrderRequest eRequest   = order.BlankRequest("Test[1] Market");
    
    eRequest.Type           = OP_BUY;
    eRequest.Memo           = "Test 1-General Functionality";
    
//    order.DisableTrade(OP_BUY);
    order.SetRiskLimits(OP_BUY,80,80,2);
  
    //--- Stop/Limit Test
    if (OrdersTotal()<3)
    {
      eRequest.Lots            = order.LotSize(OP_BUY);
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));
     
      order.Submitted(eRequest);
    }
    else
    {
      eRequest.Memo            = "Test-Tick["+(string)Tick+"]";
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));

      switch(Tick)
      {
        case 4:  order.SetStopLoss(OP_BUY,0.00,20,NoHide);
                 order.SetTakeProfit(OP_BUY,0.00,20,NoHide);
                 order.SetDefaultMethod(OP_BUY,Full);
                 break;
        case 5:  order.SetStopLoss(OP_BUY,17.40,0,NoHide);
                 order.SetTakeProfit(OP_BUY,18.75,30,NoHide);
                 order.SetOrderMethod(OP_BUY,Hold,order.Ticket(OP_BUY,Max).Ticket,ByTicket);
                 break;
        case 6:  order.SetStopLoss(OP_BUY,17.8,70,NoHide);
                 order.SetTakeProfit(OP_BUY,18.20,70,NoHide);
                 order.Submitted(eRequest);
                 order.SetOrderMethod(OP_BUY,Hold,0,ByZone);
                 break;
        case 7:  order.SetStopLoss(OP_BUY,0.00,0,NoHide);
                 order.SetTakeProfit(OP_BUY,0.00,0,NoHide);
                 eRequest.TakeProfit   = 18.16;
                 order.Submitted(eRequest);
                 break;
        case 8:  order.SetStopLoss(OP_BUY,0.00,20,NoHide,false);
                 order.SetTakeProfit(OP_BUY,0.00,0,Hide);
                 order.Submitted(eRequest);
                 break;
        case 9:  order.SetStopLoss(OP_BUY,17.2,0,Hide);
                 order.SetTakeProfit(OP_BUY,18.20,0,Hide);
                 break;
        case 10: order.SetStopLoss(OP_BUY,17.2,0,Hide);
                 order.SetTakeProfit(OP_BUY,18.11,0,Hide);
                 break;
        case 11: order.SetRiskLimits(OP_SELL,80,80,4);
                 order.SetStopLoss(OP_SELL,0.00,30,NoHide);
                 order.SetTakeProfit(OP_SELL,0.00,30,NoHide);
                 eRequest.Type   = OP_SELL;
                 order.Submitted(eRequest);
                 break;
        case 12: order.SetStopLoss(OP_SELL,18.40,0,NoHide);
                 order.SetTakeProfit(OP_SELL,17.50,0,NoHide);
                 eRequest.Type   = OP_SELL;
                 order.Submitted(eRequest);
                 break;
        case 13: order.SetStopLoss(OP_SELL,18.40,20,NoHide);
                 order.SetTakeProfit(OP_SELL,0.00,20,NoHide);
                 eRequest.Type   = OP_SELL;
                 order.Submitted(eRequest);
                 break;
        case 14: order.SetStopLoss(OP_SELL,0.00,50,Hide);
                 order.SetTakeProfit(OP_SELL,0.00,30,NoHide);
                 eRequest.Type   = OP_SELL;
                 order.Submitted(eRequest);
                 break;
      }
      Print("Break");
      for (int ord=0;ord<order[OP_BUY].Count;ord++)
        Print(order.OrderDetailStr(order.Ticket(order[OP_BUY].Ticket[ord])));
    }
    
//    if (Tick>8)
//     Print(order.QueueStr());
  }

//+------------------------------------------------------------------+
//| Long Queue Orders (Limit/Stop) + Zone Summary tests              |
//+------------------------------------------------------------------+
void Test2(void)
  {
    int req                 = 0;
    OrderRequest eRequest   = order.BlankRequest("Test[2] Resub");
    
    eRequest.Memo           = "Test 2-Pend/Recur Test";
    
    static bool fill   = false;

    order.SetRiskLimits(OP_BUY,80,80,2);
      
    //--- Queue Order Test
      if (!fill) 
      {
        eRequest.Pend.Type       = OP_BUYSTOP;
        eRequest.Pend.Limit      = 17.970;
        eRequest.Pend.Step       = 2;
        eRequest.Pend.Cancel     = 18.112;

        eRequest.Type            = OP_BUYLIMIT;
        eRequest.Price           = 17.994;
        eRequest.TakeProfit      = 18.12;
        eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
    
//        Print(order.RequestStr(eRequest));
        if (order.Submitted(eRequest))
//          Print(order.RequestStr(eRequest));
          fill=true;
          
        eRequest.Pend.Type       = OP_SELLSTOP;
        eRequest.Pend.Limit      = 18.160;
        eRequest.Pend.Step       = 2;
        eRequest.Pend.Cancel     = 17.765;

        eRequest.Type            = OP_SELLLIMIT;
        eRequest.Price           = 18.116;
        eRequest.TakeProfit      = 17.765;
        eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));

        if (order.Submitted(eRequest))
//          Print(order.RequestStr(eRequest));
          fill=true;
      }

      if (Tick==1260)
        order.SetStopLoss(OP_BUY,0.00,25,false);
      if (Tick==1300)
        order.SetStopLoss(OP_BUY,0.00,50,false,false);
//      if (order[OP_BUY].Count>0)
//        Print(order.ZoneSummaryStr());
//

      if (order.Fulfilled())
      {
//        Print("Fulfilled: "+order.ZoneSummaryStr(order.Zone(OP_BUY,order.NodeIndex(OP_BUY)).Count));
//        Print(order.OrderStr());
      } 

//      Print(order.QueueStr());
  }

//+------------------------------------------------------------------+
//| Short Queue Orders (Limit/Stop) + Zone Summary tests             |
//+------------------------------------------------------------------+
void Test3(void)
  {
    OrderRequest eRequest   = order.BlankRequest("Test[3] Shorts");
    
    eRequest.Memo           = "Test 3-Short Pend/Recur Test";
    
    order.SetRiskLimits(OP_BUY,80,80,2);
      
    //--- Queue Order Test
    if (IsEqual(order[OP_SELL].Count,0))
      if (Close[0]>18.09)
      {
        eRequest.Pend.Type       = OP_SELLSTOP;
        eRequest.Pend.Limit      = 17.982;
        eRequest.Pend.Step       = 2;
        eRequest.Pend.Cancel     = 18.112;
        eRequest.Type            = OP_SELLLIMIT;
        eRequest.Price           = 0.00;
        eRequest.TakeProfit      = 18.12;
        eRequest.Price           = 17.982;
        eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));
     
        order.Submitted(eRequest);
//        order.PrintLog();
//        Print(order.QueueStr());
      }      
  }

//+------------------------------------------------------------------+
//| Duplicate EA request management                                  |
//+------------------------------------------------------------------+
void Test4(void)
  {
    OrderRequest eRequest   = order.BlankRequest("Test[4] Dups");
    
    eRequest.Memo           = "Test 4-Lotsa Dups";
    
    order.SetRiskLimits(OP_BUY,80,80,2);
      
    //--- Queue Order Test
    if (Tick<20)
    {
      eRequest.Pend.Type       = OP_SELLSTOP;
      eRequest.Pend.Limit      = 17.75;
      eRequest.Pend.Step       = 2;
      eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_SELLLIMIT;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.982;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
     
      order.Submitted(eRequest);
    }
  }

//+------------------------------------------------------------------+
//| Margin management                                                |
//+------------------------------------------------------------------+
void Test5(void)
  {
    OrderRequest eRequest   = order.BlankRequest("Test[5] Margin");
    
    order.SetRiskLimits(OP_BUY,80,80,2);
    order.SetRiskLimits(OP_SELL,80,80,5);
      
    //--- Queue Order Test
    if (Tick<4)
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_BUY;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.982;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
    }
    else
    if (Tick<8)
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_SELL;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.982;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));     
    }
    
    eRequest.Memo           = "Margin "+DoubleToStr(order.Margin(InPercent),1)+"%";
    order.Submitted(eRequest);
  }

//+------------------------------------------------------------------+
//| Request Fulfilled/Reject/Expired signals                         |
//+------------------------------------------------------------------+
void Test6(void)
  {
    OrderRequest eRequest   = order.BlankRequest("Test[6] Margin");
    
    order.SetRiskLimits(OP_BUY,80,80,2);
    order.SetRiskLimits(OP_SELL,80,15,5);
      
    //--- Queue Order Test
    if (Tick<4)
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_BUYLIMIT;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.892;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
    }
    else
    if (IsBetween(Tick,4,8))
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_SELLLIMIT;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 18.14;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
    }
    
    if (Tick<8)
    {
//      eRequest.Memo           = "Margin "+DoubleToStr(order.Margin(Operation(eRequest.Type),Pending,InPercent),1)+"%";
      order.Submitted(eRequest);
    }
    
    if (order.Pending())
      order.PrintSnapshotStr();

    if (order.Fulfilled(OP_BUY))
      Print(order.QueueStr());
      
    if (order.Rejected())
      Print(order.QueueStr());
      
    if (order.Expired(OP_SELL))
      Print(order.QueueStr());
  }

//+------------------------------------------------------------------+
//| Stop/TP Split Retain Test                                        |
//+------------------------------------------------------------------+
void Test7(void)
  {
    OrderRequest eRequest   = order.BlankRequest("Test[7] Splits");
    
    eRequest.Type           = OP_BUY;
    eRequest.Memo           = "Test 7-Split/Retain";
    
//    order.DisableTrade(OP_BUY);
    order.SetRiskLimits(OP_BUY,10,80,2);
    order.SetRiskLimits(OP_SELL,15,80,2);
    order.SetDefaultMethod(OP_BUY,Split,NoUpdate);
    order.SetDefaultMethod(OP_SELL,Hold,NoUpdate);
  
    //--- Split/Retain Test
    if (Tick<4)
    {
      eRequest.Lots            = order.LotSize(OP_BUY)*4;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));     

      order.Submitted(eRequest);
    }
    else
    {
      eRequest.Memo            = "Test-Tick["+(string)Tick+"]";
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));

      switch(Tick)
      {
        case 4:       order.SetStopLoss(OP_BUY,0.00,0,Hide);
                      order.SetTakeProfit(OP_BUY,0.00,0,Hide);
                      order.SetOrderMethod(OP_BUY,Retain,2,ByTicket);
                      order.SetOrderMethod(OP_BUY,Full,3,ByTicket);
                      break;
        case 3900:    eRequest.Lots            = order.LotSize(OP_BUY)*4;
                      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));     
                      order.Submitted(eRequest);
                      break;
        case 5240:    eRequest.Type            = OP_SELL;
                      eRequest.Lots            = order.LotSize(OP_SELL)*4;
                      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));     
                      order.Submitted(eRequest);
                      break;
        case 11460:   eRequest.Lots            = order.LotSize(OP_BUY)*4;
                      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));     
                      order.Submitted(eRequest);
                      break;
        case 11461:   order.SetDefaultMethod(OP_BUY,DCA);
                      break;
      }
    }
  }

//+------------------------------------------------------------------+
//| FOC Data Dump Analysis                                           |
//+------------------------------------------------------------------+
void Test8(void)
  {
    if (tick[NewTick])
      Print(tick.TickStr(1)+"|"+tick.LineStr());
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    #define Test 8
    ++Tick;
//    Comment("Tick: "+(string)++Tick);
    
    switch (Test)
    {
      case 1:  Test1();
               break;
      case 2:  Test2();
               break;
      case 3:  Test3();
               break;
      case 4:  Test4();
               break;
      case 5:  Test5();
               break;
      case 6:  Test6();
               break;
      case 7:  Test7();
               break;
      case 8:  Test8();
               break;
    }
    
//    if (order[OP_BUY].Count>0)
//      Print(order.QueueStr());

    order.ExecuteOrders(OP_BUY);
        if (order[Closed].Type[OP_BUY].Count>0)
          Pause("Order closed (processed)","Snapshot Check");
    order.ExecuteOrders(OP_SELL);
        if (order[Closed].Type[OP_SELL].Count>0)
          Pause("Order closed (processed)","Snapshot Check");
    order.ExecuteRequests();
 
//    if (Tick==5) Print (">>>After:"+order.OrderStr());
    
    //if (order.Fulfilled())
    //{
    //  Print(order.OrderStr());
    //  if (order[OP_BUY].Count>0)
    //order.PrintLog();
    //  Print(order.ZoneSummaryStr());
    //}
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    static FractalState state   = NoState;

    GetData();
    Execute();
    
    RefreshScreen();

    if (IsEqual(tick.SMA().High.Event,NewBias))
    {
//      Print(tick.SMAStr());
//      CallPause("New Bias: "+proper(ActionText(tick.SMA().High.Bias))+"\nState: "+
//                   proper(DirText(tick.SMA().High.Direction))+
//                   " "+EnumToString(tick.SMA().High.State)+
//                   "\n"+EnumToString(tick.SMA().High.Event));
    }

//    if (tick.Event(NewHigh,Nominal))
//      Pause
    //if (tick[NewSegment])
    //  Print(tick.SMAStr());
    //if (IsChanged(state,tick.Range().State))
    //  if (state&&(Reversal||Breakout))
    //    Pause("New "+EnumToString(state),"State Check");
    //if (tick.Event(NewReversal,Minor)) 
    //  Pause("New Reversal(Minor)","Reversal Check()");
//    if (tick[NewSegment])
//      Pause("New Segment","NewSegment() Test");
//
//    if (tick[NewExpansion])
//      Pause("New Expansion: "+DirText(tick.Range().Direction),"NewExpansion()");
    //if (tick[NewTick])
    //  Print(tick.PolyStr());
    //if (tick[NewBias])
    //  if (tick.Segments()>0)
    //    Pause("Bias Check: "+ActionText(tick.Segment(0).Bias),"NewBias()");    
//    if (tick[NewDirection])
//      if (tick.Segments()>0)
//        Pause("Direction Check: "+ActionText(Action(tick.Segment(0).Direction)),"NewDirection()");    
//    if (tick[NewTick])
//      Print(tick.TickHistoryStr(200));
    //if (tick[NewSegment])
    //  Print (tick.SegmentStr(1));
//    if (tick.SegmentTickStr(4)!="")
//      Print(tick.SegmentTickStr(4));
    //if (tick[NewTick])
      //if (tick.Segments()<=110)
      //  if (tick.SegmentTickStr(tick.Segments()-1)!="")
      //    Print(tick.SegmentTickStr(tick.Segments()-1));
    //if (tick[NewTick])
    //  if (IsBetween(tick.Segments(),840,860))
    //    Print(tick.SegmentTickStr(tick.Segments()-1));
//        Print(tick.SegmentStr(1));
    //if (tick.Segments()==80)
    //  Print(tick.SegmentHistoryStr(tick.Segments()));

  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    if (!IsEqual(inpShowFractal,PriceTypes))
      for (FractalPoint fp=0;fp<FractalPoints;fp++)
        NewLine("tmaSMAFractal:"+StringSubstr(EnumToString(fp),2),0.00);

    order.Enable();

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      order.Enable(action);
      order.SetEquityTargets(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetZoneStep(action,2.5,60.0);
    }

    NewLine("czDCA:0");

    Print(order.MasterStr(OP_BUY));
  
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete tick;
    delete order;
  }
