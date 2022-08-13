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
#define debug      false

#include <Class/Order.mqh>
#include <Class/TickMA.mqh>
#include <Class/Session.mqh>
#include <Class/Fractal.mqh>

//--- Show Options
input string        showHeader         = "";          // +--- Show Options ---+
input int           inpShowZone        = 0;           // Show (n) Zone Lines

input string        fractalHeader      = "";          //+----- Fractal inputs -----+
input int           inpRange           = 120;         // Maximum fractal pip range
input int           inpRangeMin        = 60;          // Minimum fractal pip range

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

//--- Session Inputs
input int            inpAsiaOpen       = 1;            // Asia Session Opening Hour
input int            inpAsiaClose      = 10;           // Asia Session Closing Hour
input int            inpEuropeOpen     = 8;            // Europe Session Opening Hour
input int            inpEuropeClose    = 18;           // Europe Session Closing Hour
input int            inpUSOpen         = 14;           // US Session Opening Hour
input int            inpUSClose        = 23;           // US Session Closing Hour
input int            inpGMTOffset      = 0;            // Offset from GMT+3

  CFractal      *f                     = new CFractal(inpRange,inpRangeMin,false);
  CTickMA       *t                     = new CTickMA(inpPeriods,inpDegree,inpAgg);
  COrder        *order                 = new COrder(inpBrokerModel,Hold,Hold);
  CSession      *s[SessionTypes];

  bool           PauseOn               = false;
  int            Tick                  = 0;

  enum           HoldType
                 {
                   Conforming,
                   Contrarian,
                   Activated,
                   Inactive,
                   HoldTypes
                 };

  enum           PlanType
                 {
                   Segment,
                   SMA,
                   Linear,
                   Session,
                   Fractal,
                   PlanTypes
                 };

  enum           StrategyType
                 {
                   Protect,
                   Position,
                   Mitigate,
                   Capture,
                   Release
                 };

  struct         HoldRec
                 {
                   HoldType        Type[2];            //-- Hold type
                   int             Direction;          //-- Direction
                   int             Bias;               //-- Bias
                   EventType       Event;              //-- Hold Event
                   double          Pivot;              //-- Bias pivot price
                   double          PivotNetChange;     //-- Net Change on pivot price
                 };

  struct         PlanRec
                 {
                   int             Direction;          //-- Direction
                   int             Bias;               //-- Bias
                   int             Zone;               //-- Zone Now
                   int             High;               //-- Zone High
                   int             Low;                //-- Zone Low
                   int             Net;                //-- Net Momemtum
                   int             Change;             //-- Momentum Change
                   double          Support;            //-- Plan Support
                   double          Resistance;         //-- Plan Resistance
                   double          Expansion;          //-- Plan Expansion
                 };

  struct         ManagerRec
                 {
                   int             Action;             //-- Preset Action
                   StrategyType    Strategy;           //-- Strategy
                   OrderSummary    Zone;               //-- Current Zone Detail (rec)
                   PlanType        Plan;               //-- Plan Detail
                 };

  ManagerRec     mr[2];
  PlanRec        plan[PlanTypes];
  HoldRec        hold;

//+------------------------------------------------------------------+
//| RefreshPanel - Repaints cPanel-v3                                |
//+------------------------------------------------------------------+
void RefreshPanel(void)
  {
    static StrategyType strategytype[2];
    const  color        holdcolor[HoldTypes]     = {clrYellow,clrRed,clrLawnGreen,clrDarkGray};
    
    //-- Update Control Panel (Session)
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s[type].Event(NewFractal)||s[type].Event(NewHour))
      {
        UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[type][Term].Direction,IN_DARK_DIR));
        UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s[type].IsOpen(),clrYellow,clrBoxOff));
      }
    }

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
//      UpdateLabel("lbvOC-"+ActionText(action)+"-Strategy",EnumToString(mr[action].Strategy)+" ["+(string)DCAZone(action)+"]",
      UpdateLabel("lbvOC-"+ActionText(action)+"-Strategy",EnumToString(mr[action].Strategy)+" "+EnumToString(hold.Type[action]),
                           BoolToInt(IsChanged(strategytype[action],mr[action].Strategy),clrYellow,clrDarkGray));
      UpdateLabel("lbvOC-"+ActionText(action)+"-Trigger",CharToStr(176),holdcolor[hold.Type[action]],16,"Wingdings");
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
//| Zone - Returns Zone by supplied Price                            |
//+------------------------------------------------------------------+
int Zone(PlanType Type)
  {
    switch (Type)
    {
      case Segment:  if (IsEqual(plan[Type].Direction,DirectionUp))
                      return (BoolToInt(IsHigher(t.Fractal().Expansion,t.Fractal().Resistance),1)+BoolToInt(IsEqual(hold.Direction,DirectionUp),1));

                     return (BoolToInt(IsLower(t.Fractal().Expansion,t.Fractal().Support),-1)+BoolToInt(IsEqual(hold.Direction,DirectionDown),-1));

      case SMA:      if (IsEqual(plan[Type].Direction,DirectionUp))
                       return (BoolToInt(IsHigher(t.Tick().High,plan[Type].Support),1)+
                               BoolToInt(IsHigher(t.Tick().High,plan[Type].Resistance),1)+
                               BoolToInt(IsHigher(t.Tick().High,plan[Type].Expansion),1)-1);

                     return (BoolToInt(IsLower(t.Tick().Low,plan[Type].Support),-1)+
                             BoolToInt(IsLower(t.Tick().Low,plan[Type].Resistance),-1)+
                             BoolToInt(IsLower(t.Tick().Low,plan[Type].Expansion),-1)+1);

      case Linear:   if (IsEqual(plan[Type].Direction,DirectionUp))
                       return (BoolToInt(IsHigher(t.Tick().Open,t.Range().Mean),1)+BoolToInt(IsHigher(t.Tick().Open,t.Linear().Close.Lead),1));

                     return (BoolToInt(IsLower(t.Tick().Open,t.Range().Mean),-1)+BoolToInt(IsLower(t.Tick().Open,t.Linear().Close.Lead),-1));
    }

    return (NoValue);
  }

//+------------------------------------------------------------------+
//| UpdateHold - Updates Holds on NewHigh/NewLow                     |
//+------------------------------------------------------------------+
void UpdateHold(void)
  {
    int    bias               = hold.Bias;

    hold.Event                = NoEvent;

    if (t[NewLow])
    {
      hold.Type[OP_SELL]      = (HoldType)BoolToInt(IsEqual(hold.Type[OP_SELL],Contrarian),Activated,Inactive);
      hold.Bias               = OP_SELL;

      if (IsEqual(t.SMA().Hold,OP_SELL))
      {
        hold.Type[OP_SELL]    = Conforming;
        hold.Type[OP_BUY]     = Contrarian;
        hold.Event            = BoolToEvent(NewDirection(hold.Direction,DirectionDown),NewDirection);
      }
    }

    if (t[NewHigh])
    {
      hold.Type[OP_BUY]       = (HoldType)BoolToInt(IsEqual(hold.Type[OP_BUY],Contrarian),Activated,Inactive);
      hold.Bias               = OP_BUY;

      if (IsEqual(t.SMA().Hold,OP_BUY))
      {
        hold.Type[OP_BUY]     = Conforming;
        hold.Type[OP_SELL]    = Contrarian;
        hold.Event            = BoolToEvent(NewDirection(hold.Direction,DirectionUp),NewDirection);
      }
    }

    if (NewBias(bias,hold.Bias))
    {
      hold.Event              = NewBias;
      hold.Pivot              = Close[0];
      hold.PivotNetChange     = Close[0]-hold.Pivot;
    }
  }

//+------------------------------------------------------------------+
//| UpdatePlan - Updates supplied Plan based on incoming Zone        |
//+------------------------------------------------------------------+
void UpdatePlan(PlanType Type)
  {
    int zone                    = 0;
    int change                  = 0;
    int direction               = 0;

    switch (Type)
    {
      case Segment: plan[Type].Support     = t.Fractal().Support;
                    plan[Type].Resistance  = t.Fractal().Resistance;
                    plan[Type].Expansion   = t.Fractal().Expansion;

                    direction              = t.Segment().Direction[Trend];
                    break;

      case SMA:     plan[Type].Expansion   = BoolToDouble(IsEqual(t.Fractal().Direction,DirectionUp),t.Fractal().High.Point[Expansion],t.Fractal().Low.Point[Expansion],Digits);
                    plan[Type].Resistance  = t.Fractal().High.Point[t.Fractal().High.Type];
                    plan[Type].Support     = t.Fractal().Low.Point[t.Fractal().Low.Type];

                    if (t.Fractal().High.Type>Convergent)
                      for (FractalType type=t.Fractal().High.Type;type>Expansion;type--)
                        plan[Type].Resistance  = fmax(plan[Type].Resistance,t.Fractal().High.Point[type]);
                    else plan[Type].Resistance = fmax(t.Fractal().High.Point[Base],t.Fractal().High.Point[Root]);
                    
                    if (t.Fractal().Low.Type>Convergent)
                      for (FractalType type=t.Fractal().Low.Type;type>Expansion;type--)
                        plan[Type].Support    = fmin(plan[Type].Support,t.Fractal().Low.Point[type]);
                    else plan[Type].Support   = fmin(t.Fractal().Low.Point[Base],t.Fractal().Low.Point[Root]);

                    direction   = t.Fractal().Direction;
                    break;

      case Linear:  plan[Type].Support     = BoolToDouble(IsEqual(t.Range().Direction,DirectionUp),t.Range().Low,t.Range().Mean,Digits);
                    plan[Type].Resistance  = BoolToDouble(IsEqual(t.Range().Direction,DirectionUp),t.Range().Mean,t.Range().High,Digits);
                    plan[Type].Expansion   = BoolToDouble(IsEqual(t.Range().Direction,DirectionUp),t.Range().High,t.Range().Low,Digits);

                    direction   = t.Linear().Close.Direction;
                    break;
    }

    zone                   = Zone(Type);
    change                 = zone-plan[Type].Zone;

    if (IsChanged(plan[Type].Zone,zone))
    {
      plan[Type].Bias           = Direction(change);
      plan[Type].Change         = change;
      plan[Type].High           = fmax(zone,plan[Type].High);
      plan[Type].Low            = fmin(zone,plan[Type].Low);
      plan[Type].Net            = plan[Type].High-plan[Type].Low;
    }
    
    if (NewDirection(plan[Type].Direction,direction))
    {
      plan[Type].High           = zone;
      plan[Type].Low            = zone;
      plan[Type].Net            = 0;
    }
  }

//+------------------------------------------------------------------+
//| UpdateTick - Updates & Retrieves Tick data and fractals          |
//+------------------------------------------------------------------+
void UpdateTick(void)
  {
    t.Update();

    UpdatePlan(Segment);
    UpdatePlan(SMA);
UpdateLine("lnSupport",plan[SMA].Support,STYLE_DASH,clrGreen);
UpdateLine("lnResistance",plan[SMA].Resistance,STYLE_DASH,clrMaroon);
UpdateLine("lnExpansion",plan[SMA].Expansion,STYLE_DASH,clrYellow);
    
    UpdatePlan(Linear);
    UpdateHold();
    
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
//| UpdateSession - Updates Session Fractal Data                     |
//+------------------------------------------------------------------+
void UpdateSession(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();
      
    if (s[Asia].Event(NewTerm))
      CallPause("New Asia Term",PauseOn);
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Update/Merge Fractal (macro/meso/micro) data     |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {
    f.Update();

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)

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
//| NewStrategy - True on Micro Strategy Change by Action            |
//+------------------------------------------------------------------+
bool NewStrategy(ManagerRec &Manager)
  {
//    StrategyType strategy;

    bool         capture          = IsEqual(order[Manager.Action].Count,0);
    bool         mitigate         = !capture;
    
    switch (plan[Linear].Zone)
    {
      case -2:  switch (DCAZone(Manager.Action))
                {
                  case -3:
                  case -2: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),Release,(StrategyType)BoolToInt(mitigate,Mitigate,Position))));
                  case -1:
                  case  0: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),(StrategyType)BoolToInt(mitigate,Mitigate,Position),Position)));
                  default: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),(StrategyType)BoolToInt(capture,Capture,Mitigate),Protect)));
                }
      case -1:  
      case +1:  switch (DCAZone(Manager.Action))
                {
                  case -3: return (IsChanged(Manager.Strategy,Release));
                  case -2: 
                  case -1: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(mitigate,Mitigate,Position)));
                  case  0:
                  case +1: return (IsChanged(Manager.Strategy,Position));
                  default: return (IsChanged(Manager.Strategy,Protect));
                }
      case +2:  switch (DCAZone(Manager.Action))
                {
                  case -3:
                  case -2: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),(StrategyType)BoolToInt(mitigate,Mitigate,Position),Release)));
                  case -1:
                  case  0: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),(StrategyType)Position,BoolToInt(mitigate,Mitigate,Position))));
                  default: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),Protect,(StrategyType)BoolToInt(capture,Capture,Mitigate))));
                }
      default:  switch (DCAZone(Manager.Action))
                {
                  case -3: 
                  case -2: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(t.Linear().Close.Direction,Direction(Manager.Action,InAction)),Release,(StrategyType)BoolToInt(mitigate,Mitigate,Position))));
                  case -1: 
                  case  0: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(t.Linear().Close.Direction,Direction(Manager.Action,InAction)),(StrategyType)BoolToInt(mitigate,Mitigate,Position),Position)));
                  case +1: 
                  case +2: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(t.Linear().Close.Direction,Direction(Manager.Action,InAction)),Position,BoolToInt(mitigate,Mitigate,Position))));
                  default: return (IsChanged(Manager.Strategy,Protect));
                }
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
//| Protect - Returns formatted/valid Protect Request by Action      |
//+------------------------------------------------------------------+
OrderRequest Protect(int Action, OrderRequest &Request)
  {
    Request.Memo          = "Protect ";

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
                                            //  Request.Type           = OP_BUY;
                                            //  Request.Memo          += "Divergent [Long]";
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
//| Position - Returns formatted/valid Positioning Request by Action |
//| 1/Build - Remove Worst/Keep Best                                 |
//| 2/Factors:                                                       |
//|   a/Segment Direction Balancing                                  |
//|   b/Follow Fractal Term                                          |
//|   c/Soft Target above prior convergences                         |
//|   d/Soft Stop on fractal root                                    |
//+------------------------------------------------------------------+
OrderRequest Position(int Action, OrderRequest &Request)
  {
    Request.Memo          = "Position ";

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
                                            //  Request.Type           = OP_BUY;
                                            //  Request.Memo          += "Divergent [Long]";
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
//| Release - Returns formatted/valid Release Request by Action      |
//+------------------------------------------------------------------+
OrderRequest Release(int Action, OrderRequest &Request)
  {
    Request.Memo          = "Release ";

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
                                            //  Request.Type           = OP_BUY;
                                            //  Request.Memo          += "Divergent [Long]";
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
//| Mitigate - Returns formatted/valid Mitigation Request by Action  |
//+------------------------------------------------------------------+
OrderRequest Mitigate(int Action, OrderRequest &Request)
  {
    Request.Memo          = "Mitigate ";

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
//| Capture - Returns formatted/valid Capture Request by Action      |
//+------------------------------------------------------------------+
OrderRequest Capture(int Action, OrderRequest &Request)
  {
    Request.Memo          = "Capture ";

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
                                            //  Request.Type           = OP_BUY;
                                            //  Request.Memo          += "Divergent [Long]";
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
    OrderRequest request       = order.BlankRequest("[Auto] "+BoolToStr(IsEqual(Action,OP_BUY),"Long","Short"));

    if (t[NewHigh]||t[NewLow])
    {
      if (NewStrategy(mr[Action]))
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
        case Protect:     request    = Protect(Action,request);
                          break;
        case Position:    request    = Position(Action,request);
                          break;
        case Release:     request    = Release(Action,request);
                          break;
        case Mitigate:    request    = Mitigate(Action,request);
                          break;
        case Capture:     request    = Capture(Action,request);
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
           int action       = BoolToInt(IsEqual(order[Net].Lots,0.00),Action(t.Segment().Direction[Trend]),Action(Direction(order[Net].Lots)));

    ManageOrders(action);
    ManageOrders(Action(action,InAction,InContrarian));
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
    UpdateFractal();
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

      mr[action].Action  = action;
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
    delete f;
    delete t;
    delete order;
    
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete s[type];
  }
