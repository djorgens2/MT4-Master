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

//--- input parameters
input string        regrHeader         = "";          // +--- Regression Config ---+
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
  COrder        *order               = new COrder(inpBrokerModel,inpMethodLong,inpMethodShort);
  CSession      *s[SessionTypes];

  bool           PauseOn             = true;
  int            Tick                = 0;

  enum           StrategyType
                 {
                   Protect,
                   Position,
                   Release,
                   Build,
                   Evaluate,
                   Capture
                 };

  struct         ManagerRec
                 {
                   StrategyType      Strategy;   //-- Action Strategy;
                   OrderSummary      Zone;
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

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      UpdateLabel("lbvOC-"+ActionText(action)+"-Strategy",EnumToString(mr[action].Strategy),BoolToInt(IsChanged(strategy[action],mr[action].Strategy),clrYellow,clrDarkGray));
      UpdateLabel("lbvOC-"+ActionText(action)+"-Trigger",CharToStr(176),BoolToInt(IsEqual(action,t.SMA().Hold),clrYellow,clrDarkGray),16,"Wingdings");
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
      if (inpShowFractal==ptOpen)   ArrayCopy(f,t.SMA().Open.Point);
      if (inpShowFractal==ptHigh)   ArrayCopy(f,t.SMA().High.Point);
      if (inpShowFractal==ptLow)    ArrayCopy(f,t.SMA().Low.Point);
      if (inpShowFractal==ptClose)  ArrayCopy(f,t.SMA().Close.Point);

      for (FractalPoint fp=0;fp<FractalPoints;fp++)
        UpdateLine("tmaSMAFractal:"+StringSubstr(EnumToString(fp),2),f[fp],STYLE_SOLID,linecolor[fp]);
    }
    
    UpdateLine("czDCA:"+(string)OP_BUY,order.DCA(OP_BUY),STYLE_DOT,clrGoldenrod);

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
//| UpdateTick - Calculates position, trajectory, velocity on a tick |
//+------------------------------------------------------------------+
void UpdateTick(void)
  {
    const  int labelcolor[2][7]   = {{clrNONE,clrForestGreen,clrLawnGreen,clrLawnGreen,clrLawnGreen,clrLawnGreen,clrWhite},
                                     {clrNONE,clrFireBrick,clrRed,clrRed,clrRed,clrRed,clrWhite}};
    static int action             = OP_NO_ACTION;

    t.Update();
    
    NewAction(action,t.SMA().Bias);
    
    UpdatePriceLabel("tmaNewLow",BoolToDouble(t[NewLow],Close[0],0.00),labelcolor[action][t.EventAlertLevel(NewLow)]);
    UpdatePriceLabel("tmaNewHigh",BoolToDouble(t[NewHigh],Close[0],0.00),labelcolor[action][t.EventAlertLevel(NewHigh)]);
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
//| NewStrategy - Returns calculated New Strategy by Action          |
//+------------------------------------------------------------------+
bool NewStrategy(int Action)
  {
    switch (t.Linear().Zone)
    {
      case -2:  return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Capture,Protect)));
      case -1:  return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Evaluate,Position)));
      case  1:  return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Position,Evaluate)));
      case  2:  return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(Action,OP_BUY),Protect,Capture)));
      default:  return (IsChanged(mr[Action].Strategy,(StrategyType)BoolToInt(IsEqual(t.Linear().Close.Direction,Direction(Action,InAction)),Release,Build)));
    }
  }

//+------------------------------------------------------------------+
//| ManageLong - Manages the Long Order Processing                   |
//+------------------------------------------------------------------+
void ManageLong(void)
  {
    static bool trigger        = false;
    
    if (NewStrategy(OP_BUY))
    {
      CallPause("New Strategy",Always);
    }
    //{
    //  order.SetOrderMethod(OP_BUY,(OrderMethod)BoolToInt(mr[OP_BUY].Hold,Hold,Split),ByAction);
    //  order.SetTakeProfit(OP_BUY,t.Tick(0).High,0,Hide);
    //}

    switch (mr[OP_BUY].Strategy)
    {
//      case Protect:     if (mr[OP_BUY].Hold)
//                        {
//
//                        }
//                        break;
      case Position:    break;
      case Release:     break;
      case Build:       break;
      case Evaluate:    break;
      case Capture:     break;
    }

    //-- Hunt for Profit
//    if (IsChanged(lastSeg,t.Segment(0).Price.Count))
//    {
//      Pause("Seg ["+(string)lastSeg+"]: "+DirText(t.Segment(0).Direction)+"\n"+
//            "High: "+DoubleToStr(t.Momentum(t.SMA().High),Digits)+"\n"+
//            "Low:  "+DoubleToStr(t.Momentum(t.SMA().Low),Digits),"Segment Check");

    //  switch (lastSeg)
    //  {
    //    case 1:  //-- release holds
    //             //order.SetDefaultMethod(OP_BUY,Split);
    //             break;
    //    case 2:  //-- set targets
    //             break;
    //    default: //-- set Holds
    //             break;
    //  }
    //}

    //-- Position Management
//    if (t[NewDirection])
//      Print(t.EventStr(NewDirection));

    //if (t[NewTick])
    //{
    //    if (IsEqual(t.Segment(0).Direction,t.Segment(0).ActiveDir))
    //    switch (t.Linear().
    //    {
    //    }
    //  else
    //  {
    //  }
    //}
      
      //if (IsEqual(t.Segment(0).Direction,t.Segment(0).ActiveDir))
      ////-- Manage Convergence
      //{
      //}
      //else
      ////-- Manage Divergence
      //{
      //}

    OrderRequest request   = order.BlankRequest("[Auto] Long");

    order.SetRiskLimits(OP_BUY,10,80,2);

    if (IsEqual(t.Linear().Bias,OP_BUY))
      switch (t.SMA().State)
      {
        case Consolidation:
          switch (t.SMA().Direction)
          {
            case DirectionUp:     //if (IsChanged(trigger,true))
                                  //    SetFlag("Con",Color(t.SMA().Direction,IN_CHART_DIR));
                                  break;

            case DirectionDown:   request.Type           = OP_BUYLIMIT;
                                  request.Memo           = "In-Trend Consolidation";
 
                                  request.Price          = Bid;
                                  request.Lots           = 0.00;
                                  request.Expiry         = TimeCurrent()+(Period()*(60*2));

                                  request.Pend.Step      = 2.0;
                                  request.Pend.Type      = OP_BUYSTOP;
                                  break;
          }
          break;

        default:  trigger   = false;
      }

    if (IsChanged(trigger,!IsEqual(request.Type,OP_NO_ACTION)))
      if (!order.Submitted(request))
        CallPause(order.RequestStr(request),PauseOn);

    order.ExecuteOrders(OP_BUY);

  }

//+------------------------------------------------------------------+
//| ManageShort - Manages the Short Order Processing                 |
//+------------------------------------------------------------------+
void ManageShort(void)
  {
    FractalRec exit        = t.SMA().High;
    FractalRec entry       = t.SMA().Low;

    switch (mr[OP_SELL].Strategy)
    {
      case Protect:     break;
      case Position:    break;
      case Release:     break;
      case Build:       break;
      case Evaluate:    break;
      case Capture:     break;
    }
    
    if (NewStrategy(OP_SELL))
    {}

    order.SetRiskLimits(OP_SELL,15,80,2);
    order.SetDefaultMethod(OP_SELL,Hold,NoUpdate);

    switch (t.SMA().State)
    {
      case Consolidation:  switch (t.SMA().Direction)
                           {
//                             case DirectionUp:   if (IsChanged(trigger,true));
//
//                                                 break;
//                             case DirectionDown: if (IsChanged(trigger,true));
//
//                                                 break;
                           }
                           break;
      default:             break; //trigger   = false;
    }

    order.ExecuteOrders(OP_SELL);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int direction    = DirectionChange;

//    if (s[Asia].ActiveEvent())
    if (s[Daily][NewFractal])
      if (IsChanged(direction,s[Daily][Term].Direction))
        CallPause(s[Daily].CommentStr(), Always);
    
    ManageLong();
    ManageShort();
    
    order.ExecuteRequests();
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
    
    order.Update();

    Execute();
    
    RefreshScreen();
    RefreshPanel();
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
      order.SetZoneStep(action,inpZoneStep,inpMaxZoneMargin);
      order.SetDefaultMethod(action,Hold);
    }

    s[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    NewLine("czDCA:0");
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
