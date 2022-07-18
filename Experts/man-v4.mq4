//+------------------------------------------------------------------+
//|                                                       man-v4.mq4 |
//|                                                 Dennis Jorgenson |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
//#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define Hide       true
#define NoHide     false

#include <Class/Order.mqh>
#include <Class/TickMA.mqh>
#include <Class/Session.mqh>

//--- Show Options
input string        showHeader         = "";          // +--- Show Options ---+
input int           inpShowZone        = 0;           // Show (n) Zone Lines

//--- Regression parameters
input string        regrHeader         = "";          // +--- Regression Config ---+
input int           inpPeriods         = 80;          // Retention
input int           inpDegree          = 6;           // Poiy Regression Degree
input double        inpAgg             = 2.5;         // Tick Aggregation
input PriceType     inpShowFractal     = PriceTypes;  // Show Fractal

input string        ordHeader          = "";          // +----- Order Options -----+
input BrokerModel   inpBrokerModel     = Discount;    // Brokerage Leverage Model
input double        inpMinTarget       = 5.0;         // Equity% Target
input double        inpMinProfit       = 0.8;         // Minimum take profit%
input double        inpMaxRisk         = 5.0;         // Maximum Risk%
input double        inpMaxMargin       = 60.0;        // Maximum Margin
input double        inpLotFactor       = 2.00;        // Lot Size Risk% of Balance
input double        inpLotSize         = 0.00;        // Lot size override
input int           inpDefaultStop     = 50;          // Default Stop Loss (pips)
input int           inpDefaultTarget   = 50;          // Default Take Profit (pips)
input double        inpZoneStep        = 2.5;         // Zone Step (pips)
input double        inpMaxZoneMargin   = 5.0;         // Max Zone Margin

//--- Operational Inputs
input int            inpAsiaOpen     = 1;            // Asia Session Opening Hour
input int            inpAsiaClose    = 10;           // Asia Session Closing Hour
input int            inpEuropeOpen   = 8;            // Europe Session Opening Hour
input int            inpEuropeClose  = 18;           // Europe Session Closing Hour
input int            inpUSOpen       = 14;           // US Session Opening Hour
input int            inpUSClose      = 23;           // US Session Closing Hour
input int            inpGMTOffset    = 0;            // Offset from GMT+3

  CTickMA       *t                   = new CTickMA(inpPeriods,inpDegree,inpAgg);
  COrder        *order               = new COrder(inpBrokerModel,Hold,Hold);
  CSession      *s[SessionTypes];

  bool           PauseOn             = true;
  int            Tick                = 0;

  enum           StrategyType
                 {
                   Protect,
                   Position,
                   Mitigate,
                   Capture,
                   Release
                 };

  struct         ManagerRec
                 {
                   StrategyType      Strategy;     //-- Action Strategy;
                   OrderSummary      Zone;         //-- Current Zone Detail (rec)
                   bool              Hold;         //-- Order Hold by Action
                   double            Pivot;        //-- Trigger Pivot
                 };

  ManagerRec     mr[2];

//+------------------------------------------------------------------+
//| RefreshPanel - Repaints cPanel-v3                                |
//+------------------------------------------------------------------+
void RefreshPanel(void)
  {
    static StrategyType strategy[2];
    
    //-- Update Control Panel (Session)
    for (SessionType type=0;type<SessionTypes;type++)
    {
      if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s[type].Event(NewFractal)||s[type].Event(NewHour))
      {
        UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[type][Term].Direction,IN_DARK_DIR));
        UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s[type].IsOpen(),clrYellow,clrBoxOff));
      }
    }

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      UpdateLabel("lbvOC-"+ActionText(action)+"-Strategy",EnumToString(mr[action].Strategy)+" ["+(string)DCAZone(action)+"]",
                           BoolToInt(IsChanged(strategy[action],mr[action].Strategy),clrYellow,clrDarkGray));
      UpdateLabel("lbvOC-"+ActionText(action)+"-Trigger",CharToStr(176),BoolToInt(mr[action].Hold,clrRed,BoolToInt(IsEqual(action,t.SMA().Hold),clrYellow,clrDarkGray)),16,"Wingdings");
//      UpdateLabel("lbvOC-"+ActionText(action)+"-Trigger",CharToStr(176),BoolToInt(IsEqual(action,t.SMA().Hold),clrYellow,clrDarkGray),16,"Wingdings");
//      UpdateLabel("lbvOC-"+ActionText(action)+"-Trigger",CharToStr(176),BoolToInt(mr[action].Hold,clrYellow,clrDarkGray),16,"Wingdings");
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdateLine("czDCA:"+(string)OP_BUY,order.DCA(OP_BUY),STYLE_SOLID,clrYellow);
    
    for (int zone=0;zone<inpShowZone;zone++)
    {
      UpdateLine("crDAM:ZoneHi:"+(string)zone,order.DCA(OP_BUY)+fdiv(point(inpZoneStep),2)+(point(inpZoneStep)*zone),STYLE_DOT,clrForestGreen);
      UpdateLine("crDAM:ZoneLo:"+(string)zone,order.DCA(OP_BUY)-fdiv(point(inpZoneStep),2)-(point(inpZoneStep)*zone),STYLE_DOT,clrFireBrick);
    }
//    UpdateLine("czDCA:"+(string)OP_SELL,order.DCA(OP_SELL),STYLE_SOLID,clrRed);
//    UpdateLine("crDAM:ActiveMid",s[Daily].Pivot(ActiveSession),STYLE_DOT,Color(s[Daily][Term].Direction));
//    UpdateLine("crDAM:PriorMid",s[Daily].Pivot(PriorSession),STYLE_DOT,Color(s[Daily][Term].Direction));

    if (t.ActiveEvent())
    {
      string text = "";

      for (EventType event=1;event<EventTypes;event++)
        if (t[event])
        {
          Append(text,EventText[event],"\n");
          Append(text,EnumToString(t.EventAlertLevel(event)));
        }
      Comment(text);
    }
  }

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message, bool Pause)
  {
    if (Pause)
      Pause(Message,AccountCompany()+" Event Trapper");
    else
      Print(Message);
  }

//+------------------------------------------------------------------+
//| UpdateSession - Updates Session Fractal Data                     |
//+------------------------------------------------------------------+
void UpdateSession(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();
      
    if (s[Asia].Event(NewTerm))
      CallPause("New Asia Term",Always);
  }

//+------------------------------------------------------------------+
//| UpdateTrigger - Tests and Updates Entry Triggers by Action       |
//+------------------------------------------------------------------+
void UpdateTrigger(void)
  {
    if (t[NewLow])
    {
      if (IsEqual(t.SMA().Hold,OP_SELL))
        mr[OP_BUY].Hold           = true;
      
      if (IsChanged(mr[OP_SELL].Hold,false))
        mr[OP_SELL].Pivot         = Bid;
    }

    if (t[NewHigh])
    {
      if (IsEqual(t.SMA().Hold,OP_BUY))
        mr[OP_SELL].Hold          = true;

      if (IsChanged(mr[OP_BUY].Hold,false))
        mr[OP_BUY].Pivot          = Bid;
    }
  }

//+------------------------------------------------------------------+
//| UpdateTick - Updates & Retrieves Tick data and fractals          |
//+------------------------------------------------------------------+
void UpdateTick(void)
  {
    t.Update();

    UpdateTrigger();
    
    if (t[NewExpansion])
    {
//      if (IsEqual(t.Fractal().High.Type,Divergent))

//      if (IsEqual(t.Fractal().Low.Type,Divergent))
      
      //Pause("New Divergence\n"+"High:"+EnumToString(t.Fractal().High.Type)+"\nLow:"+EnumToString(t.Fractal().Low.Type),"Divergence Check");
    }
    if (t[NewDivergence])
    {
//      if (IsEqual(t.Fractal().High.Type,Divergent))

//      if (IsEqual(t.Fractal().Low.Type,Divergent))
      
      //Pause("New Divergence\n"+"High:"+EnumToString(t.Fractal().High.Type)+"\nLow:"+EnumToString(t.Fractal().Low.Type),"Divergence Check");
    }
    if (t[NewConvergence])
    {
//      if (IsEqual(t.Fractal().High.Type,Divergent))

//      if (IsEqual(t.Fractal().Low.Type,Divergent))
      
      //Pause("New Divergence\n"+"High:"+EnumToString(t.Fractal().High.Type)+"\nLow:"+EnumToString(t.Fractal().Low.Type),"Divergence Check");
    }

    //if (t[NewState])
    //  Pause("State Check","NewState()");
    //if (t.Event(NewReversal,Major))
    //  Pause("Fractal Event: NewReversal","Major:NewReversal()");
    //if (t.Event(NewBreakout,Major))
    //  Pause("Fractal Event: NewBreakout","Major:NewBreakout()");
//    if (t.Event(NewTerm,Nominal))
//      Pause("New Term: Level "+EnumToString(t.EventAlertLevel(NewTerm)),"NewTerm Event Check()");

//    if (t.Event(NewTerm,Major))
//    {
//      if (IsChanged(direction[OP_BUY],t.Fractal().High.Direction[Term]))
//        Pause("Major New Long Term","TickMA Fractal SMA() Event");
//
//      if (IsChanged(direction[OP_SELL],t.Fractal().Low.Direction[Term]))
//        Pause("Major New Short Term","TickMA Fractal SMA() Event");
//    }
    //else
    //if (t.Event(NewTrend,Major))
    //  Pause("Major New Term","TickMA Fractal SMA() Event");
    //else
    //if (t.Event(FractalEvent(frHigh.Type),Major))
    //  Pause("Major New "+EnumToString(frHigh.Type),"TickMA Fractal SMA() Event");
    
    //Print("SMA-High|",t.FractalStr(frHigh));
    //Print("SMA-Low|",t.FractalStr(frLow));
  }

//+------------------------------------------------------------------+
//| UpdateOrder - Updates & Retrieves order data                     |
//+------------------------------------------------------------------+
void UpdateOrder(void)
  {
    order.Update();
    
    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
      order.GetZone(action,order.Zone(action),mr[action].Zone);
  }

//+------------------------------------------------------------------+
//| DCAZone - Returns true on DCA Zone Change by Action              |
//+------------------------------------------------------------------+
int DCAZone(int Action)
  {
    int    zone              = BoolToInt(IsEqual(t.Linear().Direction,DirectionUp),2,3)*Direction(Action,InAction,Contrarian);
    double price             = t.Range().High;
    double step              = fdiv(price-t.Range().Mean,2,Digits);
    
    for (int count=0;count<5;count++)
    {
      if (order.DCA(Action)>price)
        return (zone);
        
      price                 -= step;
      zone                  += Direction(Action,InAction);
    }
    
    return(zone);
  }

//+------------------------------------------------------------------+
//| IsChanged - Returns true on Strategy Type change                 |
//+------------------------------------------------------------------+
bool IsChanged(StrategyType &Original, StrategyType Check)
  {
    if (Original==Check)
      return (false);
      
    Original                 = Check;
    
    return (true);   
  }

//+------------------------------------------------------------------+
//| NewStrategy - Returns true on Strategy Change by Action          |
//+------------------------------------------------------------------+
bool NewStrategy(int Action)
  {
    switch (t.Linear().Zone)
    {
      case -2:  switch (DCAZone(Action))
                {
                  case -3:
                  case -2: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Release,Mitigate)));
                  case -1:
                  case  0: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Mitigate,Position)));
                  default: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Capture,Protect)));
                }
      case -1:  
      case +1:  switch (DCAZone(Action))
                {
                  case -3: return (IsChanged(mr[Action].Strategy,Release));
                  case -2: 
                  case -1: return (IsChanged(mr[Action].Strategy,Mitigate));
                  case  0:
                  case +1: return (IsChanged(mr[Action].Strategy,Position));
                  default: return (IsChanged(mr[Action].Strategy,Protect));
                }
      case +2:  switch (DCAZone(Action))
                {
                  case -3:
                  case -2: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Mitigate,Release)));
                  case -1:
                  case  0: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Position,Mitigate)));
                  default: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Protect,Capture)));
                }
      default:  switch (DCAZone(Action))
                {
                  case -3: 
                  case -2: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(t.Linear().Close.Direction,Direction(Action,InAction)),Release,Mitigate)));
                  case -1: 
                  case  0: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(t.Linear().Close.Direction,Direction(Action,InAction)),Mitigate,Position)));
                  case +1: 
                  case +2: return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(t.Linear().Close.Direction,Direction(Action,InAction)),Position,Mitigate)));
                  default: return (IsChanged(mr[Action].Strategy,Protect));
                }
    }
  }

//+------------------------------------------------------------------+
//| UpdateStrategy - Manage Pending Orders, Bounds, and Risk         |
//+------------------------------------------------------------------+
void UpdateStrategy(int Action)
  {
    order.Cancel(BoolToInt(IsEqual(Action,OP_BUY),OP_BUYLIMIT,OP_SELLLIMIT));
    order.Cancel(BoolToInt(IsEqual(Action,OP_BUY),OP_BUYSTOP,OP_SELLSTOP));

    switch (mr[Action].Strategy)
    {
      case Protect:     //order.SetRiskLimits(OP_BUY,10,80,2);
                        break;
      case Position:    break;
      case Release:     break;
      case Mitigate:    Pause("Strategy Change: "+BoolToStr(IsEqual(Action,OP_BUY),"Long","Short")+" to "+EnumToString(mr[Action].Strategy),"New Strategy");
                        break;
      case Capture:     break;
    }
  }

//+------------------------------------------------------------------+
//| EquityHold Test by Action                                        |
//+------------------------------------------------------------------+
void Test9(void)
  {
    static bool fill   = false;

    OrderRequest request   = order.BlankRequest("Test[9] Hold");
    
    request.Memo           = "Test 9-Action Hold Test";

    order.SetRiskLimits(OP_BUY,80,80,2);
    order.SetDefaults(OP_BUY,0,0,0);
    order.SetDefaults(OP_SELL ,0,0,0);

    if (Tick==1)
      order.SetEquityHold(OP_BUY);
    
    if (Bid>18.12)
      order.SetEquityHold(OP_SELL);
      
    if (Tick==11415)
      order.SetEquityHold(OP_NO_ACTION);

    if (Tick==18000)
    {
      order.SetEquityHold(OP_SELL);
      order.SetOrderMethod(OP_SELL,Full,ByProfit);
    }
    
    if (Bid<17.60)
      order.SetEquityHold(OP_NO_ACTION);

    //--- Queue Order Test
      if (!fill) 
      {        
        request.Pend.Type       = OP_BUYSTOP;
        request.Pend.Limit      = 17.970;
        request.Pend.Step       = 2;
        request.Pend.Cancel     = 18.112;

        request.Type            = OP_BUYLIMIT;
        request.Price           = 17.994;
        request.Expiry          = TimeCurrent()+(Period()*(60*12));
    
        if (order.Submitted(request))
          fill=true;
          
        request.Pend.Type       = OP_SELLSTOP;
        request.Pend.Limit      = 18.160;
        request.Pend.Step       = 2;
        request.Pend.Cancel     = 17.765;

        request.Type            = OP_SELLLIMIT;
        request.Price           = 18.116;
        request.Expiry          = TimeCurrent()+(Period()*(60*12));

        if (order.Submitted(request))
          fill=true;
      }
  }

//+------------------------------------------------------------------+
//| ExecuteMitigate - True on new Mitigation Order by Action         |
//+------------------------------------------------------------------+
OrderRequest ExecuteMitigate(int Action, OrderRequest &Request)
  {
    Request.Memo          = "Mitigation ";

    switch (Action)
    {
      case OP_BUY:   //-- Looking for Long Adds
                     if (t[NewLow])
                     {
                       if (order.Entry(Action).Count>0)
                       {
                         //-- do something; order/dca/position checks...
                       }
                       else
                         switch (t.Fractal().Low.Type)
                         {
                           case Divergent:  if (IsEqual(t.Fractal().Low.Direction[Term],DirectionUp))
                                            {
                                              Request.Type           = OP_BUY;
                                              Request.Memo          += "Divergent [Long]";
                                            }
                                            break;
                           case Convergent: break;
                           case Expansion:  break;
                         }
                      }
                      break;
      case OP_SELL:   //-- Looking for Short Adds
                      break;
    }
    
    return (Request);
  }

//+------------------------------------------------------------------+
//| ManageOrders - Manages Order Processing by Action                |
//+------------------------------------------------------------------+
void ManageOrders(int Action)
  {
    OrderRequest request;
    
    string       requestor     = "[Auto] "+BoolToStr(IsEqual(Action,OP_BUY),"Long","Short");
  
    if (t[NewHigh]||t[NewLow])
    {
      if (NewStrategy(Action))
      {
        order.Cancel(BoolToInt(IsEqual(Action,OP_BUY),OP_BUYLIMIT,OP_SELLLIMIT),"Strategy Change");
        order.Cancel(BoolToInt(IsEqual(Action,OP_BUY),OP_BUYSTOP,OP_SELLSTOP),"Strategy Change");
      }
        
      switch (mr[Action].Strategy)
      {
//        case Protect:     if (mr[OP_BUY].Hold)
//                          {
//                            order.SetOrderMethod(OP_BUY,(OrderMethod)BoolToInt(mr[OP_BUY].Hold,Hold,Split),ByAction);
//                            order.SetTakeProfit(OP_BUY,t.Tick(0).High,0,Hide);
//                          }
//                          break;
        case Protect:     request    = order.BlankRequest(requestor);
                          break;
        case Position:    request    = order.BlankRequest(requestor);
                          break;
        case Release:     request    = order.BlankRequest(requestor);
                          break;
        case Mitigate:    request    = ExecuteMitigate(Action,order.BlankRequest(requestor));
                          break;
        case Capture:     request    = order.BlankRequest(requestor);
                          break;
      }

      if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
        if (!order.Submitted(request))
          if (IsEqual(request.Status,Rejected))
            CallPause(order.RequestStr(request),PauseOn);
    }

    order.ExecuteOrders(Action);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int direction    = DirectionChange;
           int action       = BoolToInt(IsEqual(order[Net].Lots,0.00),Action(t.Segment(0).Direction[Trend]),Action(Direction(order[Net].Lots)));

    ManageOrders(BoolToInt(IsEqual(order[Net].Lots,0.00),Action(t.Segment(0).Direction[Trend]),Action(Direction(order[Net].Lots))));
    ManageOrders(BoolToInt(IsEqual(order[Net].Lots,0.00),Action(t.Segment(0).Direction[Trend],InDirection,InContrarian),Action(Direction(order[Net].Lots,InDirection,InContrarian))));
   // Test9();
    order.ExecuteRequests();

//    if (s[Asia].ActiveEvent())
//    if (s[Daily][NewFractal])
//      if (IsChanged(direction,s[Daily][Term].Direction))
//        CallPause(s[Daily].CommentStr(), Always);
//      if (IsEqual(t.Linear().Zone,0))

      
//    if (t[NewParabolic])
//      CallPause("New Parabolic");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    UpdateTick();
    UpdateSession();
    UpdateOrder();

    Execute();
    
    RefreshScreen();
    RefreshPanel();
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
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetEquityTargets(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
      order.SetDefaultMethod(action,Hold);
    }

    s[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    NewLine("czDCA:"+(string)OP_BUY);
    NewLine("czDCA:"+(string)OP_SELL);

    NewLine("crDAM:ActiveMid");
    NewLine("crDAM:PriorMid");

    for (int zone=0;zone<inpShowZone;zone++)
    {
      NewLine("crDAM:ZoneHi:"+(string)zone);
      NewLine("crDAM:ZoneLo:"+(string)zone);
    }

    NewPriceLabel("tmaNewLow");
    NewPriceLabel("tmaNewHigh");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
    delete order;
    
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete s[type];
  }
