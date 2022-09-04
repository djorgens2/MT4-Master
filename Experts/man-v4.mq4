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
                   Inactive,
                   Activated,
                   Contrarian,
                   Conforming,
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
                 };

  struct         ZoneRec
                 {
                   int             Now;                //-- Hold type
                   int             Net;                //-- Hold type
                   int             Change;             //-- Hold type
                 };

  struct         PlanRec
                 {
                   int             Direction;          //-- Direction
                   int             Bias;               //-- Bias
                   int             Hedge;              //-- Hedge Action
                   ZoneRec         Zone;               //-- Plan Zone Summary
                   double          Support;            //-- Plan Support
                   double          Resistance;         //-- Plan Resistance
                   double          Expansion;          //-- Plan Expansion
                 };

  struct         SessionDetail
                 {
                   SessionType     Session;            //-- Lead session
                   EventType       Event;              //-- Session Event
                   int             Bias;               //-- Session Directions
                   double          Price;              //-- Session Directions
                   datetime        Start;
                 };

  struct         SessionMaster
                 {
                   SessionType     Lead;                    //-- Lead session
                   int             Direction[FractalTypes]; //-- Session Directions
                   SessionDetail   Support;
                   SessionDetail   Resistance;
                 };

  struct         ManagerRec
                 {
                   int             Action;             //-- Preset Action
                   StrategyType    Strategy;           //-- Strategy
                   OrderSummary    Zone;               //-- Current Zone Detail (rec)
                   PlanType        Plan;               //-- Plan Detail
                 };

  ManagerRec     mr[2];
  SessionMaster  sm;
  PlanRec        plan[PlanTypes];
  HoldRec        hold[PlanTypes];


//+------------------------------------------------------------------+
//| RefreshPanel - Repaints cPanel-v3                                |
//+------------------------------------------------------------------+
void RefreshPanel(void)
  {
    static StrategyType strategytype[2];
    const  color        holdcolor[HoldTypes]     = {clrDarkGray,clrLawnGreen,clrRed,clrYellow};
    
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
      UpdateLabel("lbvOC-"+ActionText(action)+"-Strategy",EnumToString(mr[action].Strategy)+" "+EnumToString(hold[Segment].Type[action]),
                           BoolToInt(IsChanged(strategytype[action],mr[action].Strategy),clrYellow,clrDarkGray));
      UpdateLabel("lbvOC-"+ActionText(action)+"-Trigger",CharToStr(176),holdcolor[hold[Segment].Type[action]],16,"Wingdings");
//      UpdateLabel("lbvOC-"+ActionText(action)+"-Trigger",CharToStr(176),BoolToInt(IsEqual(action,t.SMA().Hold),clrYellow,clrDarkGray),16,"Wingdings");
//      UpdateLabel("lbvOC-"+ActionText(action)+"-Trigger",CharToStr(176),BoolToInt(mr[action].Hold,clrYellow,clrDarkGray),16,"Wingdings");
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    #define type Session
    static int now = NoValue;
    
    if (IsChanged(now,plan[type].Zone.Now))
      Print(PlanStr(type));

    UpdateLine("czDCA:"+(string)OP_BUY,order.DCA(OP_BUY),STYLE_DOT,clrForestGreen);
    UpdateLine("czDCA:"+(string)OP_SELL,order.DCA(OP_SELL),STYLE_DOT,clrMaroon);

    UpdateRay("tmaSupport:1",plan[type].Support,inpPeriods-1);
    UpdateRay("tmaResistance:1",plan[type].Resistance,inpPeriods-1);
    UpdateRay("tmaExpansion:1",plan[type].Expansion,inpPeriods-1);

    for (int zone=0;zone<inpShowZone;zone++)
    {
      UpdateLine("crDAM:ZoneHi:"+(string)zone,order.DCA(OP_BUY)+fdiv(point(inpZoneStep),2)+(point(inpZoneStep)*zone),STYLE_DOT,clrForestGreen);
      UpdateLine("crDAM:ZoneLo:"+(string)zone,order.DCA(OP_BUY)-fdiv(point(inpZoneStep),2)-(point(inpZoneStep)*zone),STYLE_DOT,clrFireBrick);
    }
//    UpdateLine("czDCA:"+(string)OP_SELL,order.DCA(OP_SELL),STYLE_SOLID,clrRed);
//    UpdateLine("crDAM:ActiveMid",s[Daily].Pivot(ActiveSession),STYLE_DOT,Color(s[Daily][Term].Direction));
//    UpdateLine("crDAM:PriorMid",s[Daily].Pivot(PriorSession),STYLE_DOT,Color(s[Daily][Term].Direction));

      string text = "";
//    if (t.ActiveEvent())
//    {
//      for (EventType event=1;event<EventTypes;event++)
//        if (t[event])
//        {
//          Append(text,EventText[event],"\n");
//          Append(text,EnumToString(t.EventAlertLevel(event)));
//        }
//      Comment(text);
//    } else Comment("");
//    Comment(PlanStr(type));
    for (SessionType session=Daily;session<SessionTypes;session++)
      if (s[session].ActiveEvent())
        Append(text,EnumToString(session)+" "+s[session].ActiveEventStr(),"\n\n");
        
    Comment(text);
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
//| Zone - Returns calculated Zone of supplied Plan                  |
//+------------------------------------------------------------------+
int Zone(PlanType Type)
  {
    switch (Type)
    {
      case Segment:  if (IsEqual(plan[Type].Direction,DirectionUp))
                      return (BoolToInt(IsHigher(t.Fractal().Expansion,t.Fractal().Resistance),1)+BoolToInt(IsEqual(hold[Type].Direction,DirectionUp),1));

                     return (BoolToInt(IsLower(t.Fractal().Expansion,t.Fractal().Support),-1)+BoolToInt(IsEqual(hold[Type].Direction,DirectionDown),-1));

      case SMA:      if (IsEqual(plan[Type].Direction,DirectionUp))
                       return (BoolToInt(IsHigher(t.Tick().High,plan[Type].Support,NoUpdate,Digits),1)+
                               BoolToInt(IsHigher(t.Tick().High,plan[Type].Resistance,NoUpdate,Digits),1)+
                               BoolToInt(IsHigher(t.Tick().High,plan[Type].Expansion,NoUpdate,Digits),1)-1);

                     return (BoolToInt(IsLower(t.Tick().Low,plan[Type].Support,NoUpdate,Digits),-1)+
                             BoolToInt(IsLower(t.Tick().Low,plan[Type].Resistance,NoUpdate,Digits),-1)+
                             BoolToInt(IsLower(t.Tick().Low,plan[Type].Expansion,NoUpdate,Digits),-1)+1);

      case Linear:   if (IsEqual(plan[Type].Direction,DirectionUp))
                       return (BoolToInt(IsHigher(t.Tick().Open,t.Range().Mean),1)+BoolToInt(IsHigher(t.Tick().Open,t.Linear().Close.Lead),1));

                     return (BoolToInt(IsLower(t.Tick().Open,t.Range().Mean),-1)+BoolToInt(IsLower(t.Tick().Open,t.Linear().Close.Lead),-1));

      case Session:  if (IsEqual(plan[Type].Direction,DirectionUp))
                       return (BoolToInt(IsHigher(t.Tick().High,plan[Type].Support,NoUpdate,Digits),1)+
                               BoolToInt(IsHigher(t.Tick().High,plan[Type].Resistance,NoUpdate,Digits),1)+
                               BoolToInt(IsHigher(t.Tick().High,plan[Type].Expansion,NoUpdate,Digits),1)-1);

                     return (BoolToInt(IsLower(t.Tick().Low,plan[Type].Support,NoUpdate,Digits),-1)+
                             BoolToInt(IsLower(t.Tick().Low,plan[Type].Resistance,NoUpdate,Digits),-1)+
                             BoolToInt(IsLower(t.Tick().Low,plan[Type].Expansion,NoUpdate,Digits),-1)+1);
    }

    return (NoValue);
  }

//+------------------------------------------------------------------+
//| UpdateHold - Updates Hold on supplied Plan                       |
//+------------------------------------------------------------------+
void UpdateHold(PlanType Plan)
  {
    int     bias           = hold[Plan].Bias;

    switch (Plan)
    {
      case Segment:   //-- Segment Hold: Contrarian=Entry; Conforming=Exit/Profit
                      if (t.Tick().Low<t.SMA().Low[0])
                        if (t[NewLow])
                        {
                          hold[Plan].Bias             = OP_SELL;
                          hold[Plan].Type[OP_BUY]     = Contrarian;
                          hold[Plan].Type[OP_SELL]    = Conforming;
                          hold[Plan].Event            = BoolToEvent(NewDirection(hold[Plan].Direction,DirectionDown),NewDirection);
                        }

                      if (t.Tick().High>t.SMA().High[0])
                        if (t[NewHigh])
                        {
                          hold[Plan].Bias             = OP_BUY;
                          hold[Plan].Type[OP_BUY]     = Conforming;
                          hold[Plan].Type[OP_SELL]    = Contrarian;
                          hold[Plan].Event            = BoolToEvent(NewDirection(hold[Plan].Direction,DirectionUp),NewDirection);
                        }

                      for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
                        switch (hold[Plan].Type[action])
                        {
                          case Conforming:    hold[Plan].Type[action] = (HoldType)BoolToInt(t[NewSegment],Activated,Conforming);
                                              break;
                          case Contrarian:    hold[Plan].Type[action] = (HoldType)BoolToInt(IsEqual(BoolToInt(t[NewHigh],OP_BUY,BoolToInt(t[NewLow],OP_SELL,OP_NO_ACTION)),action),Activated,Contrarian);
                                              break;
                          case Activated:     hold[Plan].Type[action] = Inactive;
                        }
                      break;

      case SMA:       hold[Plan].Event                = BoolToEvent(NewDirection(hold[Plan].Direction,t.Fractal().Direction),NewDirection);
      
                      if (IsEqual(t.Fractal().High.Type,Divergent)&&IsEqual(t.Fractal().Low.Type,Divergent))
                      {
                        hold[Plan].Bias               = Action(t.Fractal().Direction,InDirection,InContrarian);

                        hold[Plan].Type[hold[Plan].Bias]                                  = (HoldType)BoolToInt(hold[Plan].Type[hold[Plan].Bias]>Activated,Activated,Inactive);
                        hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)]    = (HoldType)BoolToInt(IsEqual(hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)],Conforming),Activated,Contrarian);
                      }
                      else
                      {
                        hold[Plan].Bias               = Action(t.Fractal().Direction);

                        if (IsEqual(t.Fractal().Type,Expansion))
                        {
                          hold[Plan].Type[hold[Plan].Bias]                                = Conforming;
                          hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)]  = Contrarian;
                        }
                        else
                        {
                          hold[Plan].Type[OP_BUY]     = (HoldType)BoolToInt(hold[Plan].Type[OP_BUY]>Activated,Activated,Inactive);
                          hold[Plan].Type[OP_SELL]    = (HoldType)BoolToInt(hold[Plan].Type[OP_SELL]>Activated,Activated,Inactive);
                        }
                      }
                      break;

      case Linear:    hold[Plan].Event                = BoolToEvent(NewDirection(hold[Plan].Direction,t.Linear().Direction),NewDirection);

                      if (IsEqual(t.Linear().Close.Now,0.00,Digits))
                      {
                        //-- No Bias
                      }
                      else
                      if (IsEqual(t.Linear().Close.Max,t.Linear().Close.Now,Digits))
                      {
                        hold[Plan].Bias               = Action(t.Linear().Close.Now);
                        
                        if (t.Event(NewExpansion,Critical))
                        {
                          hold[Plan].Type[hold[Plan].Bias]                                = Conforming;
                          hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)]  = Contrarian;
                        }
                      }
                      else
                      if (IsEqual(t.Linear().Close.Min,t.Linear().Close.Now,Digits))
                      {
                        hold[Plan].Bias               = Action(t.Linear().Close.Now,InDirection,InContrarian);

                        hold[Plan].Type[hold[Plan].Bias]                                  = (HoldType)BoolToInt(hold[Plan].Type[hold[Plan].Bias]>Activated,Activated,Inactive);
                        hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)]    = (HoldType)BoolToInt(IsEqual(hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)],Conforming),Activated,Contrarian);
                      }
                      else
                        for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
                          hold[Plan].Type[action]                                         = (HoldType)BoolToInt(hold[Plan].Type[action]>Activated,Activated,Inactive);
                      break;

      case Session:   //hold[Plan].Event                = BoolToEvent(NewDirection(hold[Plan].Direction,s[Daily][NewDirection]),NewDirection);
//
//                      if (s[Asia][NewExpansion])
//                      {
//                        hold[Plan].Type[hold[Plan].Bias]                                = Conforming;
//                        hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)]  = Contrarian;
//                      }
//
//                      else
//                      if (IsEqual(t.Linear().Close.Min,t.Linear().Close.Now,Digits))
//                      {
//                        hold[Plan].Bias               = Action(t.Linear().Close.Now,InDirection,InContrarian);
//
//                        hold[Plan].Type[hold[Plan].Bias]                                  = (HoldType)BoolToInt(hold[Plan].Type[hold[Plan].Bias]>Activated,Activated,Inactive);
//                        hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)]    = (HoldType)BoolToInt(IsEqual(hold[Plan].Type[Action(hold[Plan].Bias,InAction,InContrarian)],Conforming),Activated,Contrarian);
//                      }
//                      else
//                        for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
//                          hold[Plan].Type[action]                                         = (HoldType)BoolToInt(hold[Plan].Type[action]>Activated,Activated,Inactive);
                      break;
    }

    hold[Plan].Event      = BoolToEvent(NewBias(bias,hold[Plan].Bias),NewBias);
  }

//+------------------------------------------------------------------+
//| UpdatePlan - Updates supplied Plan based on incoming Zone        |
//+------------------------------------------------------------------+
void UpdatePlan(PlanType Type)
  {
    ZoneRec zone           = plan[Type].Zone;

    switch (Type)
    {
      case Segment: plan[Type].Direction       = t.Segment().Direction[Trend];
                    plan[Type].Support         = t.Fractal().Support;
                    plan[Type].Resistance      = t.Fractal().Resistance;
                    plan[Type].Expansion       = t.Fractal().Expansion;
                    plan[Type].Hedge           = BoolToInt(IsEqual(t.Segment().Direction[Term],t.Segment().Direction[Trend]),OP_NO_ACTION,Action(t.Segment().Direction[Term]));
                    break;

      case SMA:     plan[Type].Direction       = t.Fractal().Direction;
                    plan[Type].Expansion       = BoolToDouble(IsEqual(plan[Type].Direction,DirectionUp),t.Fractal().High.Point[Expansion],t.Fractal().Low.Point[Expansion],Digits);
                    plan[Type].Resistance      = t.Fractal().High.Point[t.Fractal().High.Type];
                    plan[Type].Support         = t.Fractal().Low.Point[t.Fractal().Low.Type];
                    plan[Type].Hedge           = OP_NO_ACTION;
                    
                    if (IsEqual(plan[Type].Direction,DirectionUp))
                      if (t.Segment().Price.Low<t.Fractal().Low.Point[Root])
                        plan[Type].Hedge       = OP_SELL;

                    if (IsEqual(plan[Type].Direction,DirectionDown))
                      if (t.Segment().Price.High>t.Fractal().High.Point[Root])
                        plan[Type].Hedge       = OP_BUY;

                    if (t.Fractal().High.Type>Convergent)
                      for (FractalType type=t.Fractal().High.Type;type>Expansion;type--)
                        plan[Type].Resistance  = fmax(plan[Type].Resistance,t.Fractal().High.Point[type]);
                    else plan[Type].Resistance = fmax(t.Fractal().High.Point[Base],t.Fractal().High.Point[Root]);
                    
                    if (t.Fractal().Low.Type>Convergent)
                      for (FractalType type=t.Fractal().Low.Type;type>Expansion;type--)
                        plan[Type].Support     = fmin(plan[Type].Support,t.Fractal().Low.Point[type]);
                    else plan[Type].Support    = fmin(t.Fractal().Low.Point[Base],t.Fractal().Low.Point[Root]);

                    break;

      case Linear:  plan[Type].Direction       = t.Linear().Close.Direction;
                    plan[Type].Support         = BoolToDouble(IsEqual(t.Range().Direction,DirectionUp),t.Range().Low,t.Range().Mean,Digits);
                    plan[Type].Resistance      = BoolToDouble(IsEqual(t.Range().Direction,DirectionUp),t.Range().Mean,t.Range().High,Digits);
                    plan[Type].Expansion       = BoolToDouble(IsEqual(t.Range().Direction,DirectionUp),t.Range().High,t.Range().Low,Digits);
                    plan[Type].Hedge           = BoolToInt(IsEqual(t.Linear().Close.Max,t.Linear().Close.Now,Digits),OP_NO_ACTION,
                                                 BoolToInt(IsEqual(t.Linear().Close.Min,t.Linear().Close.Now,Digits),Action(t.Linear().Close.Now,InDirection,InContrarian),OP_NO_ACTION));
                    break;

      case Session: plan[Type].Direction       = sm.Direction[Term];
                    
                    //if (IsEqual(sd.Event,NewBias))
                    //{
                    //  plan[Type].Support         = BoolToDouble(IsEqual(sd.Direction[Lead],DirectionUp),t.Range().Low,t.Range().Mean,Digits);
                    //  plan[Type].Resistance      = BoolToDouble(IsEqual(sd.Direction[Lead],DirectionUp),t.Range().Mean,t.Range().High,Digits);
                    //}
                    //plan[Type].Support         = s[Asia][PriorSession].Low;
                    //plan[Type].Resistance      = s[Asia][PriorSession].High;
                    //plan[Type].Expansion       = s[Asia].Forecast(Term,Expansion,fmax(Fibo161,Level(s[Asia].Expansion(Term,Max))));
                    
//                    plan[Type].Hedge           = BoolToInt(IsEqual(t.Linear().Close.Max,t.Linear().Close.Now,Digits),OP_NO_ACTION,
//                                                 BoolToInt(IsEqual(t.Linear().Close.Min,t.Linear().Close.Now,Digits),Action(t.Linear().Close.Now,InDirection,InContrarian),OP_NO_ACTION));
                    break;
    }

    if (IsChanged(plan[Type].Zone.Now,Zone(Type)))
    {
      plan[Type].Zone.Change    = plan[Type].Zone.Now-zone.Now;
      plan[Type].Zone.Net      += plan[Type].Zone.Change;
    }

    if (NewBias(plan[Type].Bias,Action(Direction(plan[Type].Zone.Change))))
      plan[Type].Zone.Net       = plan[Type].Zone.Change;
  }

//+------------------------------------------------------------------+
//| UpdateTick - Updates & Retrieves Tick data and fractals          |
//+------------------------------------------------------------------+
void UpdateTick(void)
  {
    t.Update();

//    if (t.Event(NewLow,Notify)) Pause("New Low Event","New Low()");
//    if (t.Event(NewHigh,Notify)) Pause("New High Event","New High()");

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
    SessionDetail detail;

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      s[type].Update();
      
      if (s[type][NewFractal])
        CallPause("Session "+EnumToString(type)+".NewFractal() Check",Always);
      
      if (s[type].Event(NewBias,Major))
      {
        Flag("[sv7] "+EnumToString(type)+" "+ActionText(s[type][Trend].Bias),Color(type,Bright));
  
        detail.Session          = type;
        detail.Event            = NewBias;
        detail.Price            = Close[0];
        
        if (IsEqual(s[type][Trend].Bias,OP_BUY))
          sm.Resistance         = detail;

        if (IsEqual(s[type][Trend].Bias,OP_SELL))
          sm.Support            = detail;
          
        UpdateLine("[sv7]Support",sm.Support.Price,STYLE_SOLID,clrMaroon);
        UpdateLine("[sv7]Resistance",sm.Resistance.Price,STYLE_SOLID,clrForestGreen);
      }
    }
      
    for (SessionType session=Daily;session<SessionTypes;session++)
      if (s[session][SessionOpen])
        sm.Lead                 = session;
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Update/Merge Fractal (macro/meso/micro) data     |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {
    f.Update();
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
    
    switch (plan[Linear].Zone.Now)
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
    UpdateOrder();
    UpdateTick();
    UpdateSession();
    UpdateFractal();

    for (PlanType Plan=Segment;Plan<PlanTypes;Plan++)
    {
      UpdatePlan(Plan);
      UpdateHold(Plan);
    }

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

    //-- Initialize Session
    s[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    sm.Direction[Trend]        = s[Daily][Trend].Direction;
    sm.Direction[Term]         = s[Daily][Term].Direction;
    sm.Direction[Lead]         = Direction(s[Daily][Term].Bias,InAction);

    plan[Session].Resistance   = s[Daily][ActiveSession].Resistance;
    plan[Session].Support      = s[Daily][ActiveSession].Support;
    plan[Session].Expansion    = s[Daily].Price(Term,fpExpansion);

    NewLine("czDCA:"+(string)OP_BUY);
    NewLine("czDCA:"+(string)OP_SELL);

    NewLine("crDAM:ActiveMid");
    NewLine("crDAM:PriorMid");

    NewLine("[sv7]Support");
    NewLine("[sv7]Resistance");

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

//+------------------------------------------------------------------+
//| PlanStr - Returns formatted plan data                            |
//+------------------------------------------------------------------+
string PlanStr(PlanType Type)
  {
    string text         = EnumToString(Type);
    
    Append(text,DirText(plan[Type].Direction));
    Append(text,ActionText(plan[Type].Bias));
    Append(text,"Hedge["+BoolToStr(IsEqual(plan[Type].Hedge,OP_NO_ACTION),"NONE",ActionText(plan[Type].Hedge))+"]");
    Append(text,"zone["+IntegerToString(plan[Type].Zone.Now,3)+"]");
    Append(text,"net["+IntegerToString(plan[Type].Zone.Net,3)+"]");
    Append(text,"chg["+IntegerToString(plan[Type].Zone.Change,3)+"]");
    Append(text,"cl{"+DoubleToStr(Close[0],Digits)+"]");
    Append(text,"sp{"+DoubleToStr(plan[Type].Support,Digits)+"]");
    Append(text,"rs{"+DoubleToStr(plan[Type].Resistance,Digits)+"]");
    Append(text,"exp{"+DoubleToStr(plan[Type].Expansion,Digits)+"]");

    //-- Holds
    Append(text,EnumToString(hold[Type].Type[OP_BUY]));
    Append(text,EnumToString(hold[Type].Type[OP_SELL]));
    Append(text,DirText(hold[Type].Direction));
    Append(text,ActionText(hold[Type].Bias));
    Append(text,EnumToString(hold[Type].Event));
    
    return (text);
  }