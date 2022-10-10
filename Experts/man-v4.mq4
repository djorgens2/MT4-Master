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

  enum           ActionType
                 {
                   Hedge,
                   Build,
                   ActionTypes
                 };

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

//--- Show Options
input string        showHeader         = "";          // +--- Show Options ---+
input int           inpPeriodsIdle     = 6;           // Idle Time (In Periods)
input int           inpShowZone        = 0;           // Show (n) Zone Lines
input               PlanType plantype  = Segment;     // Plan Type Alert Dialogue


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
  int            id                    = IDOK;
    
  //-- Validations
  bool Holds    = true;
  bool Details  = true;
  bool Priors   = true;  
  bool Prices   = false;
  bool Biases   = false;
  bool Hedges   = false;
  bool Zones    = false;

  struct         HoldDetail
                 {
                   int        Bias;
                   HoldType   Type;
                   double     Open;
                   double     High;
                   double     Low;
                   double     Close;
                 };

  struct         HoldRec
                 {
                   int             Direction;          //-- Direction
                   int             Bias;               //-- Bias
                   EventType       Event;              //-- Hold Event
                   HoldDetail      Active[2];          //-- Hold Detail by Manager(Action)
                   HoldDetail      Prior[2];           //-- Prior boundaries by Action
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

  struct         SessionMaster
                 {
                   SessionType     Lead;               //-- Lead session
                   SessionType     Pivot;              //-- Pivot session
                   int             Hedge;              //-- Net Equal Term Direction
                   bool            Expansion;          //-- All Session Breakout/Reversal Flag
                 };

  struct         ManagerRec
                 {
                   int             Action;             //-- Preset Action
                   ActionType      Request;            //-- Action requested
                   int             Bias;               //-- Immediate bias (Lowest Level);
                   StrategyType    Strategy;           //-- Strategy
                   OrderSummary    Zone;               //-- Current Zone Detail (rec)
                   PlanType        Plan;               //-- Plan Detail
                   double          Momentum;           //-- Momentum factor
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
      UpdateLabel("lbvOC-"+ActionText(action)+"-Strategy",EnumToString(mr[action].Strategy)+" "+EnumToString(hold[Segment].Active[action].Type),
                           BoolToInt(IsChanged(strategytype[action],mr[action].Strategy),clrYellow,clrDarkGray));
                           
      for (PlanType type=Segment;type<PlanTypes;type++)
        UpdateLabel("lbvOC-"+ActionText(action)+"-Hold"+EnumToString(type),CharToStr(176),holdcolor[hold[type].Active[action].Type],16,"Wingdings");
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text = "";
    //UpdateLine("czDCA:"+(string)OP_BUY,order.DCA(OP_BUY),STYLE_DOT,clrForestGreen);
    //UpdateLine("czDCA:"+(string)OP_SELL,order.DCA(OP_SELL),STYLE_DOT,clrMaroon);

    UpdateLine("[m4]DailyMid",s[Daily].Pivot(OffSession),STYLE_DOT,clrDarkGray);
    UpdateLine("[m4]Lead",s[sm.Lead].Pivot(ActiveSession),STYLE_DOT,Color(sm.Lead,Bright));

    UpdateRay("tmaPlanExp:1",plan[plantype].Expansion,inpPeriods-1);
    UpdateRay("tmaPlanSup:1",plan[plantype].Support,inpPeriods-1);
    UpdateRay("tmaPlanRes:1",plan[plantype].Resistance,inpPeriods-1);
      
    for (int zone=0;zone<inpShowZone;zone++)
    {
      UpdateLine("crDAM:ZoneHi:"+(string)zone,order.DCA(OP_BUY)+fdiv(point(inpZoneStep),2)+(point(inpZoneStep)*zone),STYLE_DOT,clrForestGreen);
      UpdateLine("crDAM:ZoneLo:"+(string)zone,order.DCA(OP_BUY)-fdiv(point(inpZoneStep),2)-(point(inpZoneStep)*zone),STYLE_DOT,clrFireBrick);
    }

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
//    text=(PlanStr(type));

    for (PlanType type=Segment;type<PlanTypes;type++)
      Append(text,PlanStr(type),"\n");

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
//| Event - Application Specific Event Detection                     |
//+------------------------------------------------------------------+
bool Event(EventType Type)
  {
    return (!IsEqual(Type,NoEvent));
  }

//+------------------------------------------------------------------+
//| Zone - Returns calculated Zone of supplied Plan                  |
//+------------------------------------------------------------------+
int Zone(PlanType Type, double Pivot)
  {
    if (IsEqual(plan[Type].Direction,DirectionUp))
      return (BoolToInt(IsHigher(Pivot,plan[Type].Support,NoUpdate,Digits),1)+
              BoolToInt(IsHigher(Pivot,plan[Type].Resistance,NoUpdate,Digits),1)+
              BoolToInt(IsHigher(Pivot,plan[Type].Expansion,NoUpdate,Digits),1)-1);

    return (BoolToInt(IsLower(Pivot,plan[Type].Support,NoUpdate,Digits),-1)+
            BoolToInt(IsLower(Pivot,plan[Type].Resistance,NoUpdate,Digits),-1)+
            BoolToInt(IsLower(Pivot,plan[Type].Expansion,NoUpdate,Digits),-1)+1);
  }

//+------------------------------------------------------------------+
//| StampHold - Updates Hold data on supplied Plan Hold Type change  |
//+------------------------------------------------------------------+
void StampHold(HoldDetail &Hold, HoldType Type)
  {
    bool conforming            = IsEqual(Hold.Type,Conforming);

    if (IsEqual(Type,Activated))
      if (IsChanged(Hold.Type,Type))
        Hold.Close              = BoolToDouble(conforming,Close[0],Hold.Close);

    if (Type>Activated)
      if (IsChanged(Hold.Type,Type))
        if (IsEqual(Type,Conforming))
        {
          if (IsHigher(Close[0],Hold.Open))
            Hold.Bias           = OP_BUY;

          if (IsLower(Close[0],Hold.Open))
            Hold.Bias           = OP_SELL;

          Hold.High             = Close[0];
          Hold.Low              = Close[0];
          Hold.Close            = NoValue;
        }
  }

//+------------------------------------------------------------------+
//| UpdateHold - Updates Hold on supplied Plan                       |
//+------------------------------------------------------------------+
void UpdateHold(PlanType Plan)
  {
    int     bias      = NoBias;

    switch (Plan)
    {
      case Segment:   //-- Catches on OOB SMA() High/Low bounds, Soft Release in bounds, hard release on NewSegment
                      if (t.Tick().Low<t.SMA().Low[0])
                        if (t[NewLow])
                        {
                          bias                    = OP_SELL;
                          hold[Plan].Event        = BoolToEvent(NewDirection(hold[Plan].Direction,DirectionDown),NewDirection);

                          StampHold(hold[Plan].Active[OP_BUY],Contrarian);
                          StampHold(hold[Plan].Active[OP_SELL],Conforming);
                        }

                      if (t.Tick().High>t.SMA().High[0])
                        if (t[NewHigh])
                        {
                          bias                    = OP_BUY;
                          hold[Plan].Event        = BoolToEvent(NewDirection(hold[Plan].Direction,DirectionUp),NewDirection);

                          StampHold(hold[Plan].Active[OP_BUY],Conforming);
                          StampHold(hold[Plan].Active[OP_SELL],Contrarian);
                        }

                      if (t.Tick().High<t.SMA().High[0]&&t.Tick().Low>t.SMA().Low[0])
                        for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
                          switch (hold[Plan].Active[action].Type)
                          {
                            case Conforming:    StampHold(hold[Plan].Active[action],(HoldType)BoolToInt(t[NewSegment],Activated,Conforming));
                                                break;
                            case Contrarian:    StampHold(hold[Plan].Active[action],
                                                   (HoldType)BoolToInt(IsEqual(BoolToInt(t[NewHigh],OP_BUY,
                                                             BoolToInt(t[NewLow],OP_SELL,NoAction)),action),Activated,Contrarian));
                                                break;
                            case Activated:     hold[Plan].Active[action].Type = Inactive;
                          }
                      break;

      case SMA:       //-- Catches on High/Low SMA() Fractal Expansions, Soft Release on single divergence, hard release dual divergence
                      hold[Plan].Event                = BoolToEvent(NewDirection(hold[Plan].Direction,t.Fractal().Direction),NewDirection);
      
                      if (t[NewFractal])
                      {
                        bias         = Action(t.Fractal().Direction);
                        StampHold(hold[Plan].Active[bias],Conforming);
                        StampHold(hold[Plan].Active[Action(bias,InAction,InContrarian)],Contrarian);
                      }

                      if (t.Event(NewExpansion,Major))
                        if (t.Fractal().High.Type!=t.Fractal().Low.Type)
                        {
                          bias       = Action(IsEqual(t.Fractal().High.Type,Expansion),OP_BUY,OP_SELL);
                          StampHold(hold[Plan].Active[bias],Contrarian);
                        }

                      if (t.Event(NewDivergence,Major))
                      {
                        if (t.Fractal().High.Type!=t.Fractal().Low.Type);
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
                        bias                          = Action(t.Linear().Close.Now);
                        
                        if (t.Event(NewExpansion,Critical))
                        {
                          hold[Plan].Active[bias].Type                                = Conforming;
                          hold[Plan].Active[Action(bias,InAction,InContrarian)].Type  = Contrarian;
                        }
                      }
                      else
                      if (IsEqual(t.Linear().Close.Min,t.Linear().Close.Now,Digits))
                      {
                        bias                          = Action(t.Linear().Close.Now,InDirection,InContrarian);

                        hold[Plan].Active[bias].Type                                  = (HoldType)BoolToInt(hold[Plan].Active[bias].Type>Activated,Activated,Inactive);
                        hold[Plan].Active[Action(bias,InAction,InContrarian)].Type    = (HoldType)BoolToInt(IsEqual(hold[Plan].Active[Action(bias,InAction,InContrarian)].Type,Conforming),Activated,Contrarian);
                      }
                      else
                        for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
                          hold[Plan].Active[action].Type     = (HoldType)BoolToInt(hold[Plan].Active[action].Type>Activated,Activated,Inactive);
                      break;

      case Session:   hold[Plan].Event                = BoolToEvent(NewDirection(hold[Plan].Direction,s[Daily][Trend].Direction),NewDirection);
                      bias                            = s[Daily][Term].Bias;

                      if (sm.Expansion)
                        if (IsEqual(s[Daily][Term].Direction,s[Daily][Trend].Direction))
                        {
                          hold[Plan].Active[bias].Type                                = Conforming;
                          hold[Plan].Active[Action(bias,InAction,InContrarian)].Type  = Contrarian;
                        }
                        else hold[Plan].Active[bias].Type                             = Contrarian;
                      else
                        for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
                          if (IsEqual(hold[Plan].Active[action].Type,Conforming))
                            hold[Plan].Active[action].Type   = (HoldType)BoolToInt(IsEqual(s[Daily][Trend].State,Reversal)||IsEqual(s[Daily][Trend].State,Breakout),Conforming,Activated);
                          else
                          if (IsEqual(hold[Plan].Active[action].Type,Contrarian))
                            hold[Plan].Active[action].Type   = (HoldType)BoolToInt(IsEqual(action,t.Segment().Direction[Lead]),Contrarian,Activated);
                          else
                            hold[Plan].Active[action].Type   = Inactive;
                      break;
    }

    hold[Plan].Event      = BoolToEvent(NewAction(hold[Plan].Bias,bias),NewBias,hold[Plan].Event);

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      if (IsEqual(hold[Plan].Active[action].Type,Conforming))
      {
        hold[Plan].Active[action].High       = fmax(Close[0],hold[Plan].Active[action].High);
        hold[Plan].Active[action].Low        = fmin(Close[0],hold[Plan].Active[action].Low);
      }
      
      if (IsEqual(hold[Plan].Active[action].Type,Activated))
        hold[Plan].Prior[action]             = hold[Plan].Active[action];
    }
  }

//+------------------------------------------------------------------+
//| UpdatePlan - Updates supplied Plan based on incoming Zone        |
//+------------------------------------------------------------------+
void UpdatePlan(PlanType Type)
  {
    ZoneRec zone           = plan[Type].Zone;
    double  pivot          = BoolToDouble(IsEqual(t.Segment().Direction[Lead],DirectionUp),t.Segment().High,t.Segment().Low);

    switch (Type)
    {
      case Segment: plan[Type].Direction       = t.Segment().Direction[Trend];
                    plan[Type].Support         = t.SMA().Low[0];
                    plan[Type].Resistance      = t.SMA().High[0];
                    plan[Type].Expansion       = BoolToDouble(IsEqual(plan[Type].Direction,DirectionUp),t.Fractal().Resistance,t.Fractal().Support);
                    plan[Type].Hedge           = BoolToInt(IsEqual(t.Segment().Direction[Term],t.Segment().Direction[Trend]),NoAction,Action(t.Segment().Direction[Term]));
                    break;

      case SMA:     plan[Type].Direction       = t.Fractal().Direction;
                    plan[Type].Expansion       = BoolToDouble(IsEqual(plan[Type].Direction,DirectionUp),t.Fractal().High.Point[Expansion],t.Fractal().Low.Point[Expansion],Digits);
                    plan[Type].Resistance      = t.Fractal().High.Point[t.Fractal().High.Type];
                    plan[Type].Support         = t.Fractal().Low.Point[t.Fractal().Low.Type];
                    plan[Type].Hedge           = NoAction;
                    
                    if (IsEqual(plan[Type].Direction,DirectionUp))
                      if (t.Segment().Low<t.Fractal().Low.Point[Root])
                        plan[Type].Hedge       = OP_SELL;

                    if (IsEqual(plan[Type].Direction,DirectionDown))
                      if (t.Segment().High>t.Fractal().High.Point[Root])
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
                    plan[Type].Support         = BoolToDouble(IsEqual(plan[Type].Direction,DirectionUp),Price(Fibo23,t.Range().Low,t.Range().High,Expansion),t.Range().Mean,Digits);
                    plan[Type].Resistance      = BoolToDouble(IsEqual(plan[Type].Direction,DirectionUp),t.Range().Mean,Price(Fibo23,t.Range().Low,t.Range().High,Retrace),Digits);
                    plan[Type].Expansion       = BoolToDouble(IsEqual(plan[Type].Direction,DirectionUp),Price(Fibo23,t.Range().Low,t.Range().High,Retrace),Price(Fibo23,t.Range().Low,t.Range().High,Expansion),Digits);
                    plan[Type].Hedge           = BoolToInt(IsEqual(t.Linear().Close.Max,t.Linear().Close.Now,Digits),NoAction,
                                                 BoolToInt(IsEqual(t.Linear().Close.Min,t.Linear().Close.Now,Digits),Action(t.Linear().Close.Now,InDirection,InContrarian),NoAction));
                    break;

      case Session: plan[Type].Direction       = s[Daily][Trend].Direction;
                    plan[Type].Support         = s[Daily].Forecast(Trend,Correction);
                    plan[Type].Resistance      = s[Daily].Forecast(Trend,Retrace,Fibo50);
                    plan[Type].Expansion       = s[Daily].Forecast(Trend,Retrace,Fibo23);
                    plan[Type].Hedge           = sm.Hedge;
                    break;

      case Fractal: plan[Type].Direction       = BoolToInt(IsEqual(f[Base].State,Correction),f[Divergent].Direction,f[Expansion].Direction);
                    plan[Type].Support         = f.Forecast(Base,Correction);
                    plan[Type].Resistance      = f.Forecast(Base,Retrace,Fibo50);
                    plan[Type].Expansion       = f.Forecast(Base,Recovery);
                    plan[Type].Hedge           = BoolToInt(IsEqual(plan[Type].Direction,Direction(plan[Type].Zone.Change)),NoAction,Action(plan[Type].Zone.Change));
                    break;
    }

    if (IsChanged(plan[Type].Zone.Now,Zone(Type,pivot)))
    {
      plan[Type].Zone.Change    = plan[Type].Zone.Now-zone.Now;
      plan[Type].Zone.Net      += plan[Type].Zone.Change;
    }

    if (NewAction(plan[Type].Bias,Action(Direction(plan[Type].Zone.Change))))
      plan[Type].Zone.Net       = plan[Type].Zone.Change;
  }

//+------------------------------------------------------------------+
//| UpdateTick - Updates & Retrieves Tick data and fractals          |
//+------------------------------------------------------------------+
void UpdateTick(void)
  {
    int direction   = NoDirection;

    t.Update();

//    if (t.Event(NewReversal,Critical))
//        Flag("lnRangeReversal",Color(direction));
//
//    if (t.Event(NewBreakout,Critical))
//        Flag("lnRangeBreakout",clrSteelBlue);
//    if (IsChanged(mr[OP_BUY].Momentum,t.Momentum().High.Now)&&IsChanged(mr[OP_SELL].Momentum,t.Momentum().Low.Now))
//      if (!IsEqual(Direction(t.Momentum().High.Change),Direction(t.Momentum().Low.Change)))
//        CallPause("Double Momentum Change - Parabolic\n"+t.MomentumStr(),Always);
//      
//    if (t[NewTick])
//      if (NewDirection(direction,Direction(t.Tick().Open-t.Linear().Close.Lead)))
//        Flag("lnDirChg",Color(direction));
    
    
  }

//+------------------------------------------------------------------+
//| UpdateSession - Updates Session Fractal Data                     |
//+------------------------------------------------------------------+
void UpdateSession(void)
  {
    sm.Expansion       = false;
    sm.Hedge           = NoAction;

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      s[type].Update();

      sm.Pivot                  = sm.Lead;
      sm.Lead                   = (SessionType)BoolToInt(s[type][SessionOpen]||s[type][SessionClose],type,sm.Lead);
      sm.Expansion              = sm.Expansion||s[type][NewExpansion];
      
      if (type>Daily)
        sm.Hedge                = BoolToInt(IsEqual(s[Daily][Term].Direction,s[type][Term].Direction),sm.Hedge,s[sm.Lead][Term].Bias);
    }    
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
//| IsChanged - Returns true on Hold Type change                     |
//+------------------------------------------------------------------+
bool IsChanged(HoldType &Original, HoldType Check)
  {
    if (Original==Check)
      return (false);

    Original                 = Check;

    return (true);   
  }

//+------------------------------------------------------------------+
//| NewStrategy - True on Micro Strategy Change by Action            |
//+------------------------------------------------------------------+
bool NewStrategy(ManagerRec &Manager, PlanType Plan)
  {
//    StrategyType strategy;

    bool         capture          = IsEqual(order[Manager.Action].Count,0);
    bool         mitigate         = !capture;
    int          zone             = Zone(Plan,order.DCA(Manager.Action));
    
    switch (plan[Plan].Zone.Now)
    {
      case -2:  switch (zone)
                {
                  case -3:
                  case -2: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),Release,(StrategyType)BoolToInt(mitigate,Mitigate,Position))));
                  case -1:
                  case  0: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),(StrategyType)BoolToInt(mitigate,Mitigate,Position),Position)));
                  default: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),(StrategyType)BoolToInt(capture,Capture,Mitigate),Protect)));
                }
      case -1:  
      case +1:  switch (zone)
                {
                  case -3: return (IsChanged(Manager.Strategy,Release));
                  case -2: 
                  case -1: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(mitigate,Mitigate,Position)));
                  case  0:
                  case +1: return (IsChanged(Manager.Strategy,Position));
                  default: return (IsChanged(Manager.Strategy,Protect));
                }
      case +2:  switch (zone)
                {
                  case -3:
                  case -2: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),(StrategyType)BoolToInt(mitigate,Mitigate,Position),Release)));
                  case -1:
                  case  0: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),(StrategyType)Position,BoolToInt(mitigate,Mitigate,Position))));
                  default: return (IsChanged(Manager.Strategy,(StrategyType)BoolToInt(IsEqual(Manager.Action,OP_BUY),Protect,(StrategyType)BoolToInt(capture,Capture,Mitigate))));
                }
      default:  switch (zone)
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
      order.SetEquityHold(NoAction);

    if (Tick==18000)
    {
      order.SetEquityHold(OP_SELL);
      order.SetOrderMethod(OP_SELL,Full,ByProfit);
    }
    
    if (Bid<17.60)
      order.SetEquityHold(NoAction);

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
      if (NewStrategy(mr[Action],Linear))
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
//| IsChanged - Returns true on Plan/Hold Changes by PlanType        |
//+------------------------------------------------------------------+
bool IsChanged(PlanType Type)
  {
    static PlanRec lastplan[PlanTypes];
    static HoldRec lasthold[PlanTypes];
    
    bool ischanged           = false;
    
    if (Biases)
    {
      ischanged     = ischanged||plan[Type].Direction!=lastplan[Type].Direction;
      ischanged     = ischanged||plan[Type].Bias!=lastplan[Type].Bias;
    }
    
    if (Zones)
    {
      ischanged     = ischanged||plan[Type].Zone.Now!=lastplan[Type].Zone.Now;
      ischanged     = ischanged||plan[Type].Zone.Net!=lastplan[Type].Zone.Net;
      ischanged     = ischanged||plan[Type].Zone.Change!=lastplan[Type].Zone.Change;
    }

    if (Hedges)
      ischanged     = ischanged||plan[Type].Hedge!=lastplan[Type].Hedge;

    if (Prices)
    {
      ischanged     = ischanged||plan[Type].Support!=lastplan[Type].Support;
      ischanged     = ischanged||plan[Type].Resistance!=lastplan[Type].Resistance;
      ischanged     = ischanged||plan[Type].Expansion!=lastplan[Type].Expansion;
    }
    
    if (Holds)
    {
      ischanged     = ischanged||hold[Type].Active[OP_BUY].Type!=lasthold[Type].Active[OP_BUY].Type;
      ischanged     = ischanged||hold[Type].Active[OP_SELL].Type!=lasthold[Type].Active[OP_SELL].Type;
      ischanged     = ischanged||hold[Type].Direction!=lasthold[Type].Direction;
      ischanged     = ischanged||hold[Type].Bias!=lasthold[Type].Bias;
      ischanged     = ischanged||hold[Type].Event!=lasthold[Type].Event;
    }

    if (Details)
      for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
      {
        ischanged   = ischanged||hold[Type].Active[action].Bias!=lasthold[Type].Active[action].Bias;
        ischanged   = ischanged||hold[Type].Active[action].Open!=lasthold[Type].Active[action].Open;
        ischanged   = ischanged||hold[Type].Active[action].High!=lasthold[Type].Active[action].High;
        ischanged   = ischanged||hold[Type].Active[action].Low!=lasthold[Type].Active[action].Low;
        ischanged   = ischanged||hold[Type].Active[action].Close!=lasthold[Type].Active[action].Close;
      }

    lastplan[Type]      = plan[Type];
    lasthold[Type]      = hold[Type];

    return (ischanged);
  }

//+------------------------------------------------------------------+
//| ChangeTest - Test for changes in Actionable Analysis Data        |
//+------------------------------------------------------------------+
void ChangeTest(void)
  {
    string     text         = "";

    if (IsChanged(plantype))
    {
      Print(PlanStr(plantype));
      id = IDOK;
    }
      
    if (IsEqual(id,IDOK))
    {
      Append(text,BoolToStr(Biases,"Plan Direction:"+DirText(plan[plantype].Direction)+" Bias:"+ActionText(plan[plantype].Bias)+"\n"));
      Append(text,BoolToStr(Zones,"Zones Now"+(string)plan[plantype].Zone.Now+" Net:"+(string)plan[plantype].Zone.Net+" Chg:"+(string)plan[plantype].Zone.Change+"\n"));
      Append(text,BoolToStr(Hedges,"Hedge:"+ActionText(plan[plantype].Hedge)+"\n"));
      Append(text,BoolToStr(Prices,"Prices Sup:"+DoubleToStr(plan[plantype].Support,Digits)+
                                         " Res:"+DoubleToStr(plan[plantype].Resistance,Digits)+
                                         " Exp:"+DoubleToStr(plan[plantype].Expansion,Digits)+"\n"));
      Append(text,BoolToStr(Holds,"Holds Direction:"+DirText(hold[plantype].Direction)+" Bias:"+ActionText(hold[plantype].Bias)+" Event:"+EnumToString(hold[plantype].Event)+"\n"));

      if (Details)
        for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
          Append(text,HoldDetailStr(hold[plantype].Active[action],"Active")+"\n");

      if (Priors)
        for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
          Append(text,HoldDetailStr(hold[plantype].Prior[action],"Prior")+"\n");

      id = Pause("Change detected in "+EnumToString(plantype)+"\n\n"+text,"Plan Change Check",MB_OKCANCEL);
    }
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int direction    = DirectionChange;
           int action       = BoolToInt(IsEqual(order[Net].Lots,0.00),Action(t.Segment().Direction[Trend]),Action(Direction(order[Net].Lots)));
    static int event        = 0;

    ChangeTest();
    //if (Event(t.Linear().Close.Event))
    //  Print(t.FOCStr(t.Linear().Close)+"|"+DoubleToStr(Close[0],Digits));

//    if (IsChanged(Segment))
//      CallPause((string)++event+":"+PlanStr(Segment),Always);

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

    NewLine("czDCA:"+(string)OP_BUY);
    NewLine("czDCA:"+(string)OP_SELL);

    NewLine("[m4]Lead");
    NewLine("[m4]DailyMid");

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
//| HoldDetailStr - Returns formatted hold detail data               |
//+------------------------------------------------------------------+
string HoldDetailStr(HoldDetail &Detail, string Name)
  {
    string text         = Name;

    Append(text,EnumToString(Detail.Type));
    Append(text,ActionText(Detail.Bias));
    Append(text,DoubleToStr(Detail.Open,Digits));
    Append(text,DoubleToStr(Detail.High,Digits));
    Append(text,DoubleToStr(Detail.Low,Digits));
    Append(text,DoubleToStr(Detail.Close,Digits));

    return (text);
  }
//+------------------------------------------------------------------+
//| PlanStr - Returns formatted plan data                            |
//+------------------------------------------------------------------+
string PlanStr(PlanType Type)
  {
    string text         = EnumToString(Type);
    
    Append(text,DirText(plan[Type].Direction));
    Append(text,ActionText(plan[Type].Bias));
    Append(text,"Hedge["+BoolToStr(IsEqual(plan[Type].Hedge,NoAction),"NONE",ActionText(plan[Type].Hedge))+"]");
    Append(text,"zone["+(string)(plan[Type].Zone.Now)+"]");
    Append(text,"net["+(string)(plan[Type].Zone.Net)+"]");
    Append(text,"chg["+(string)(plan[Type].Zone.Change)+"]");
    Append(text,"cl["+DoubleToStr(Close[0],Digits)+"]");
    Append(text,"sma["+DoubleToStr(BoolToDouble(IsEqual(hold[Type].Bias,OP_BUY),t.SMA().High[0],t.SMA().Low[0]),Digits)+"]");
    Append(text,"sp["+DoubleToStr(plan[Type].Support,Digits)+"]");
    Append(text,"rs["+DoubleToStr(plan[Type].Resistance,Digits)+"]");
    Append(text,"exp["+DoubleToStr(plan[Type].Expansion,Digits)+"]");

    //-- Holds
    Append(text,DirText(hold[Type].Direction));
    Append(text,ActionText(hold[Type].Bias));
    Append(text,EnumToString(hold[Type].Event));

    Append(text,HoldDetailStr(hold[Type].Active[OP_BUY],"Long Active"));
    Append(text,HoldDetailStr(hold[Type].Prior[OP_BUY],"Prior"));
    Append(text,HoldDetailStr(hold[Type].Active[OP_SELL],"Short Active"));
    Append(text,HoldDetailStr(hold[Type].Prior[OP_SELL],"Prior"));
    
    return text;
  }