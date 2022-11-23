//+------------------------------------------------------------------+
//|                                                       man-v5.mq4 |
//|                                                 Dennis Jorgenson |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
//#property link      "https://www.mql5.com"
#property version   "5.01"
#property strict

#define Hide       true
#define NoHide     false
#define debug      false

  //-- App-Specific Nomens
  enum           StrategyType
                 {
                   NoStrategy,
                   Protect,
                   Position,
                   Mitigate,
                   Capture,
                   Release
                 };

  enum           AccountSource
                 {
                   USD,
                   XRP
                 };

  enum           ManagerType
                 {
                   Sales,
                   Purchasing,
                   Unassigned    = -1
                 };

  enum           HoldType
                 {
                   Conforming,
                   Contrarian,
                   Activated,
                   Inactive,
                   Broken
                 };

#include <Class/Order.mqh>
#include <Class/TickMA.mqh>
#include <Class/Session.mqh>
#include <Class/Fractal.mqh>

//--- Show Options
input string        showHeader         = "";          // +--- Show Options ---+
input AccountSource inpSource          = XRP;         // Account Source
input int           inpPeriodsIdle     = 6;           // Idle Time (In Periods)
input int           inpAreaOfOperation = 6;           // Pips from trigger

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
input double        inpEquityTarget    = 5.0;         // Equity% Target
input double        inpEquityTargetMin = 0.8;         // Minimum take profit%
input double        inpEquityRiskMax   = 5.0;         // Maximum Risk%
input double        inpMaxMargin       = 60.0;        // Maximum Margin
input double        inpLotFactor       = 2.00;        // Lot Size Risk% of Balance
input double        inpLotSize         = 0.00;        // Lot size override
input int           inpDefaultStop     = 50;          // Default Stop Loss (pips)
input int           inpDefaultTarget   = 50;          // Default Take Profit (pips)
input double        inpZoneStep        = 2.5;         // Zone Step (pips)
input double        inpMaxZoneMargin   = 5.0;         // Max Zone Margin

//--- Session Inputs
input int           inpAsiaOpen        = 1;            // Asia Session Opening Hour
input int           inpAsiaClose       = 10;           // Asia Session Closing Hour
input int           inpEuropeOpen      = 8;            // Europe Session Opening Hour
input int           inpEuropeClose     = 18;           // Europe Session Closing Hour
input int           inpUSOpen          = 14;           // US Session Opening Hour
input int           inpUSClose         = 23;           // US Session Closing Hour
input int           inpGMTOffset       = 0;            // Offset from GMT+3

  CTickMA          *t                  = new CTickMA(inpPeriods,inpDegree,inpAgg);
  COrder           *order              = new COrder(inpBrokerModel,Hold,Hold);
  CSession         *s[SessionTypes];

  struct SessionMaster
  {
    SessionType   Lead;               //-- Lead session
    SessionType   Pivot;              //-- Pivot session
    int           Hedge;              //-- Net Equal Term Direction
    bool          Expansion;          //-- All Session Breakout/Reversal Flag
  };

  struct ManagerAction
  {
    ManagerType   Manager;            //-- Manager Type (Contrary to OP_[BUY=Sales|SELL=Purchase]
    int           Action;             //-- Manager's Action (Operation Responsibility)
    int           Bias;               //-- Bias for Action
    HoldType      Hold;               //-- Directional Hold
    StrategyType  Strategy;           //-- Manager Strategy
    FractalType   Type;               //-- Last Fractal triggered
    bool          Confirmed;          //-- Bias Confirmation
    double        Pivot;              //-- Bias Pivot
    AlertLevel    PivotAlert;         //-- Event Alert Level on Pivot Change
    double        AOO;                //-- Area of Operation
    double        EquityRiskMax;      //-- Maximum Risk by Manager
    double        EquityTargetMin;    //-- Minimum Equity Target by Manager
    double        EquityTarget;       //-- Equity Target by Manager
    double        StopLoss;           //-- Stop Loss by Manager
    double        TakeProfit;         //-- Take Profit by Manager
  };

  ManagerType     mb[FractalTypes];   //-- Manager Bias (mb) by Fractal
  ManagerAction   ma[2];              //-- Manager Pivot maint by Action
  SessionMaster   sm;                 //-- Session General

  bool            PauseOn               = false;
  int             Tick                  = 0;

//+------------------------------------------------------------------+
//| RefreshPanel - Repaints cPanel-v3                                |
//+------------------------------------------------------------------+
void RefreshPanel(void)
  {
    //-- Update Control Panel (Session)
    for (SessionType type=Daily;type<SessionTypes;type++)
      if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s[type].Event(NewFractal)||s[type].Event(NewHour))
      {
        UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[type][Term].Direction,IN_DARK_DIR));
        UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s[type].IsOpen(),clrYellow,clrBoxOff));
      }

    for (int manager=Sales;IsBetween(manager,Sales,Purchasing);manager++)
    {
      UpdateLabel("lbvOC-"+ActionText(ma[manager].Action)+"-Strategy",BoolToStr(ma[manager].Strategy==NoStrategy,"Pending",EnumToString(ma[manager].Strategy)),
                                                          BoolToInt(ma[manager].Strategy==NoStrategy,clrDarkGray,Color(ma[manager].Strategy)));
      UpdateLabel("lbvOC-"+ActionText(ma[manager].Action)+"-Hold",CharToStr(176),BoolToInt(IsEqual(ma[manager].Hold,Conforming),clrYellow,
                                                                                BoolToInt(IsEqual(ma[manager].Hold,Contrarian),clrRed,clrDarkGray)),16,"Wingdings");
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text = "";
    
    text = "Source Value ["+EnumToString(inpSource)+"]:"+DoubleToStr(iClose("XRPUSD",0,0))+"\n"+ManagerStr()+"\n\n"+t.ActiveEventStr();

    UpdateLine("[m4]Mid",s[Daily].Pivot(OffSession),STYLE_DOT,clrDarkGray);
    UpdateLine("[m4]Lead",s[sm.Lead].Pivot(ActiveSession),STYLE_DOT,Color(sm.Lead,Bright));
    //UpdateLine("[m4]DCABuy",order.DCA(OP_BUY),STYLE_DOT,clrForestGreen);
    //UpdateLine("[m4]DCASell",order.DCA(OP_SELL),STYLE_DOT,clrMaroon);

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
//| IsChanged - Returns true on Strategy Change by Manager           |
//+------------------------------------------------------------------+
bool IsChanged(StrategyType &Compare, StrategyType Value)
  {
    if (Value==NoStrategy)
      return false;

    if (Compare==Value)
      return false;
      
    Compare = Value;
    return true;
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
//| UpdateTick - Updates & Retrieves Tick data and fractals          |
//+------------------------------------------------------------------+
void UpdateTick(void)
  {
    t.Update();
  }

//+------------------------------------------------------------------+
//| UpdateOrder - Updates & Retrieves order data                     |
//+------------------------------------------------------------------+
void UpdateOrder(void)
  {
    order.Update();
  }

//+------------------------------------------------------------------+
//| Watch - Onboarding mitigation watch                              |
//+------------------------------------------------------------------+
void Watch(int Action)
  {
  }

//+------------------------------------------------------------------+
//| Zone - Returns calculated Zone of supplied Plan                  |
//+------------------------------------------------------------------+
int Zone(int Action, double Pivot)
  {
    const int zones[2][6]  = {{-3,-2,-1,0,1,2},{2,1,0,-1,-2,-3}};
    double    zone[5];
    
    zone[0]  = t.Range().High;
    zone[1]  = t.Range().Resistance;
    zone[2]  = t.Range().Mean;
    zone[3]  = t.Range().Support;
    zone[4]  = t.Range().Low;
    
    for (int node=0;node<5;node++)
      if (Pivot>zone[node])
        return zones[Action,node];

    return zones[Action][5];    
  }

//+------------------------------------------------------------------+
//| NewManager - Confirms Manager turnover on change in Bias         |
//+------------------------------------------------------------------+
bool NewManager(ManagerType &Manager, int Bias)
  {
    if (IsEqual(Bias,NoBias))
      return false;

    if (IsEqual(Manager,Bias))
      return false;

    Manager               = (ManagerType)Bias;

    return true;
  }

//+------------------------------------------------------------------+
//| NewBias - Confirms bias changes                                  |
//+------------------------------------------------------------------+
bool NewBias(int Action, int &Bias, int Change)
  {
    if (IsEqual(ma[Action].AOO,NoValue))
      return false;

    if (IsEqual(Action,OP_BUY))
      if (IsHigher(Close[0],ma[Action].AOO,NoUpdate,Digits))
        Change           = Action;

    if (IsEqual(Action,OP_SELL))
      if (IsLower(Close[0],ma[Action].AOO,NoUpdate,Digits))
        Change           = Action;

    return NewAction(Bias,Change);
  }

//+------------------------------------------------------------------+
//| NewMomentum - Tests changes in Momentum                          |
//+------------------------------------------------------------------+
bool NewMomentum(void)
  {
    return !(t.Momentum().High.Event==NoEvent&&t.Momentum().Low.Event==NoEvent);
  }

//+------------------------------------------------------------------+
//| NewStrategy - Updates strategy based on supplied Action Pivot    |
//+------------------------------------------------------------------+
bool NewStrategy(ManagerType Manager)
  {
    StrategyType strategy   = NoStrategy;
    int          action     = ma[Manager].Action;
    int          zone       = Zone(Manager,order.DCA(action))-Zone(action,s[sm.Lead].Pivot(ActiveSession));

    switch (zone)
    {
       case -3: //--Capture/Release
                strategy    = (StrategyType)BoolToInt(order.Recap(action,Loss).Equity<-ma[action].EquityRiskMax,Release,Capture);
                break;

       case -2: //--Mitigate/Release
                strategy    = (StrategyType)BoolToInt(order.Recap(action,Loss).Equity<-ma[action].EquityRiskMax,Release,Mitigate);
                break;
                
       case -1: //--Mitigate/Position
                strategy    = (StrategyType)BoolToInt(order.Recap(action,Loss).Equity<-ma[action].EquityRiskMax,Mitigate,Position);
                break;

       case  0: //--Position
                strategy    = Position;
                break;

       case +1: //--Position/Protect
                strategy    = (StrategyType)BoolToInt(order.Recap(action,Profit).Equity>ma[action].EquityTarget,Protect,Position);
                break;

       case +2: //--Protect
                strategy    = Protect;
                break;
    }

    if (IsEqual(mb[Lead],Unassigned))
      if (strategy<Position)
        Watch(action);

    return IsChanged(ma[Manager].Strategy,strategy);
  }

//+------------------------------------------------------------------+
//| NewTrigger - Tests and sets trigger boundaries                   |
//+------------------------------------------------------------------+
bool NewTrigger(void)
  {
    static int    bias         = NoBias;
    AlertLevel    alert        = NoAlert;
    static int    event        = 0;

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      if (NewBias(action,ma[action].Bias,BoolToInt(Close[0]>ma[action].AOO,OP_BUY,OP_SELL)))
        ma[action].Confirmed   = false;

      if (IsChanged(ma[action].Confirmed,ma[action].Confirmed||
                                (IsEqual(ma[action].Bias,OP_BUY)&&Close[0]>t.SMA().High[0])||
                                (IsEqual(ma[action].Bias,OP_SELL)&&Close[0]<t.SMA().Low[0])))
        mb[Term]               = (ManagerType)action;
    }

    if (ma[OP_BUY].Confirmed&&ma[OP_SELL].Confirmed)
      if (IsEqual(ma[OP_BUY].Bias,ma[OP_SELL].Bias))
        if (NewManager(mb[Trend],mb[Term]))
          NewArrow("tmaActiveEvent"+(string)event++,(ArrowType)BoolToInt(IsEqual(mb[Term],OP_BUY),ArrowUp,ArrowDown),Color(Direction(ma[mb[Trend]].Bias,InAction),IN_CHART_DIR));
          //UpdatePriceLabel("tmaActiveEvent",Close[0],Color(Direction(ma[mb[Trend]].Bias,InAction)));

    if (IsChanged(bias,t.Fractal().Bias))
      if (NewManager(mb[Lead],bias))
        alert                  = Minor;

    if (t.Event(NewReversal,Critical)||t.Event(NewBreakout,Critical))
      if (NewManager(mb[Lead],Action(t.Range().Direction)))
      {
        bias                   = mb[Lead];
        alert                  = Major;
      }
      else Flag("Continuation",clrGoldenrod);

    UpdateHold();

    if (alert>NoAlert)
    {
      ma[mb[Lead]].Type        = (FractalType)BoolToInt(t[NewHigh],t.Fractal().High.Type,t.Fractal().Low.Type);
      ma[mb[Lead]].Bias        = Action(mb[Lead],InAction,InContrarian);
      ma[mb[Lead]].Pivot       = Close[0];
      ma[mb[Lead]].PivotAlert  = alert;
      ma[mb[Lead]].AOO         = BoolToDouble(IsEqual(mb[Lead],OP_BUY),ma[mb[Lead]].Pivot,ma[mb[Lead]].Pivot)+(point(inpAreaOfOperation)*Direction(mb[Lead],InAction));
      ma[mb[Lead]].Confirmed   = false;

      //if (IsEqual(ma[mb[Lead]].Bias,mb[Trend]))
      if (alert==Major)
      Flag(EnumToString(alert),BoolToInt(alert==Minor,Color(Direction(bias,InAction)),BoolToInt(t[NewReversal],clrWhite,clrSteelBlue)));
//      UpdatePriceLabel("tmaActiveEvent",Close[0],BoolToInt(alert==Minor,Color(Direction(bias,InAction)),BoolToInt(t[NewReversal],clrWhite,clrSteelBlue)));
//      UpdatePriceLabel("mb[Lead]-"+EnumToString(mb[Lead]),Close[0],Color(Direction(ma[mb[Lead]].Bias,InAction)));
      return true;
    }
    
    return NewMomentum();
  }

//+------------------------------------------------------------------+
//| UpdateHold - Updates hold type based on trigger event            |
//+------------------------------------------------------------------+
void UpdateHold(void)
  {
    int term                     = mb[Term];
    int trend                    = mb[Trend];
    int antitrend                = Action(mb[Trend],InAction,InContrarian);

    if (ma[Sales].Confirmed&&ma[Purchasing].Confirmed)
      if (IsEqual(trend,NoBias))
      {
        ma[Sales].Hold           = Inactive;
        ma[Purchasing].Hold      = Inactive;
      }
      else
      if (IsEqual(ma[Sales].Bias,ma[Purchasing].Bias))
      {
        ma[trend].Hold           = Contrarian;
        ma[antitrend].Hold       = Conforming;
      }
      else
      if (IsEqual(term,trend))
      {
        ma[trend].Hold           = Conforming;
        ma[antitrend].Hold       = Contrarian;
      }
      else
      {
        ma[trend].Hold           = Contrarian;
        ma[antitrend].Hold       = Contrarian;
      }
    else
    {}
//        for (int manager=Sales;IsBetween(manager,Sales,Purchasing);manager++)
//
//            ma[manager].Hold     = (HoldType)BoolToInt(IsEqual(ma[manager].Bias,trend),Contrarian,Conforming);
//
//    if (t.Tick().High>t.SMA().Lead.High)
//    {
//      ma[OP_BUY].Hold       = 
//      ma[OP_SELL].Hold      = (HoldType)BoolToInt(IsEqual(hold,ma[OP_SELL].Bias),Contrarian,Conforming);
//    }
//    else
//    if (t.Tick().Low>t.SMA().Lead.Low)
//    {
//    }
//    else
//    {
//    }
    //    else
    //      ma[action].Hold          = (HoldType)BoolToInt(IsEqual(action,ma[action].Bias),Contrarian,BoolToInt(ma[action].Hold<Activated,Activated,Inactive));
    //  else
    //  if (ma[action].Confirmed)
    //    ma[action].Hold            = (HoldType)BoolToInt(IsEqual(ma[action].Bias,mb[Trend]),Conforming,Contrarian);
    //  else
    //    ma[action].Hold            = (HoldType)BoolToInt(ma[action].Hold<Activated,Activated,Inactive);
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
OrderRequest Position(ManagerType Manager, OrderRequest &Request)
  {
//    if (mr[OP_BUY].Hold)
//    {
//      order.SetOrderMethod(OP_BUY,(OrderMethod)BoolToInt(mr[OP_BUY].Hold,Hold,Split),ByAction);
//      order.SetTakeProfit(OP_BUY,t.Tick(0).High,0,Hide);
//    }

    if (ma[Manager].Confirmed)
      if (order.LotSize(ma[Manager].Bias)<=order.Free(ma[Manager].Bias))
      switch (ma[Manager].Action)
      {
        case OP_BUY:    //-- Looking for Long Adds
                        if (t[NewLow])
                        {
                          Request.Type           = OP_BUY;
                          Request.Memo           = "Position "+EnumToString(t.Fractal().Low.Type);
                        }

                         //if (order.Entry(Action).Count>0)
                         //{
                         //  //-- do something; order/dca/position checks...
                         //}
                         //else
                           //switch (t.Fractal().Low.Type)
                           //{
                           //  case Divergent:  if (IsEqual(t.Fractal().Low.Direction[Term],DirectionUp))
                           //                   {
                           //                   //  Request.Type           = OP_BUY;
                           //                   //  Request.Memo          += "Divergent [Long]";
                           //                   }
                           //                   break;
                           //  case Convergent: break;
                           //  case Expansion:  break;
                           //}
                        break;
        case OP_SELL:   //-- Looking for Short Adds
                        if (t[NewHigh])
                        {
                          Request.Type           = OP_SELL;
                          Request.Memo           = "Position "+EnumToString(t.Fractal().High.Type);
                        }
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
                                              //Request.Type           = OP_BUY;
                                              //Request.Memo          += "Divergent [Long]";
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
                      if (t[NewHigh])
                      {
                        // Do Something
                      }
                      break;
    }
    
    return (Request);
  }

//+------------------------------------------------------------------+
//| ManageOrders - Orders/Requests/Risk/Profit by Manager by Turn    |
//+------------------------------------------------------------------+
void ManageOrders(ManagerType Manager, HoldType Turn)
  {
    OrderRequest request      = order.BlankRequest(EnumToString(Manager));
    int action                = Operation(ma[Manager].Bias);

    if (order.Enabled(action))
    {
      if (NewStrategy(Manager))
      {
      };

      if (IsEqual(Manager,ma[Manager].Bias)||IsEqual(ma[Manager].Bias,NoBias))
      {
        //-- Risk mitigation steps
      }

      else
      {
        switch (ma[Manager].Strategy)
        {
          case Protect:     request    = Protect(Manager,request);
                            break;
          case Position:    request    = Position(Manager,request);
                            break;
          case Release:     request    = Release(Manager,request);
                            break;
          case Mitigate:    request    = Mitigate(Manager,request);
                            break;
          case Capture:     request    = Capture(Manager,request);
                            break;
        }

        //if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
        //  if (order.Submitted(request))
        //    Print(order.RequestStr(request));
        //  else {/* identifyfailure */}
      }

      //-- Process Contrarian Queue
      if (order.Enabled(action))
        order.ExecuteOrders(action);
    }
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {    
    if (NewTrigger())
      if (IsBetween(mb[Term],OP_BUY,OP_SELL))
      {
        ManageOrders((ManagerType)mb[Term],Conforming);
        ManageOrders((ManagerType)Action(mb[Term],InAction,InContrarian),Contrarian);
      }

    order.ExecuteRequests();    
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    UpdateOrder();
    UpdateTick();
    UpdateSession();

    Execute();

    RefreshScreen();
    RefreshPanel();
  }

//+------------------------------------------------------------------+  
//| OnBoarding - App opening with existing trades                    |
//+------------------------------------------------------------------+
void OnBoarding(int Action)
  {
    if (order[Action].Lots>0)
      order.Disable(Action,"Open Positions Detected; Preparing execution plan");
    else
      order.Enable(Action,"System started "+TimeToString(TimeCurrent()));

    //-- Order Config
    order.SetDefaults(Action,inpLotSize,inpDefaultStop,inpDefaultTarget);
    order.SetEquityTargets(Action,ma[Action].EquityTarget,ma[Action].EquityTargetMin);
    order.SetRiskLimits(Action,ma[Action].EquityRiskMax,inpMaxMargin,inpLotFactor);
    order.SetZoneLimits(Action,inpZoneStep,inpMaxZoneMargin);
    order.SetDefaultMethod(Action,Hold);
  }

//+------------------------------------------------------------------+  
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    // -- Opening Protection (existing positions)
    order.Enable();

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      //-- Manager Config
      ma[action].Manager           = (ManagerType)action;
      ma[action].Action            = Action(action,InAction,InContrarian);
      ma[action].Bias              = NoBias;
      ma[action].Hold              = Inactive;
      ma[action].Strategy          = NoStrategy;
      ma[action].Type              = Expansion;
      ma[action].Confirmed         = false;
      ma[action].Pivot             = NoValue;
      ma[action].AOO               = NoValue;
      ma[action].EquityRiskMax     = inpEquityRiskMax;
      ma[action].EquityTargetMin   = inpEquityTargetMin;
      ma[action].EquityTarget      = inpEquityTarget;
      ma[action].StopLoss          = NoValue;
      ma[action].TakeProfit        = NoValue;

      NewPriceLabel("mb[Lead]-"+EnumToString(ma[action].Manager));
      
      OnBoarding(action);
    }

    ArrayInitialize(mb,Unassigned);

    //-- Initialize Session
    s[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    NewLine("[m4]Lead");
    NewLine("[m4]Mid");
    NewLine("[m4]DCABuy");
    NewLine("[m4]DCASell");

    NewPriceLabel("tmaNewLow");
    NewPriceLabel("tmaNewHigh");
    NewPriceLabel("tmaActiveEvent");

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

//+------------------------------------------------------------------+
//| ManagerStr - returns formatted Manager data                      |
//+------------------------------------------------------------------+
string ManagerStr(void)
  {
    string text   = "";
    
    Append(text,"Manager Active: "+EnumToString((ManagerType)mb[Lead]),"\n");
    Append(text,"Confirmed: "+EnumToString((ManagerType)mb[Term]));
    if (mb[Term]>Unassigned)
      Append(text," ["+ActionText(ma[mb[Term]].Bias)+BoolToStr(ma[mb[Term]].Confirmed,"*")+"]");
    Append(text,"Trend: "+BoolToStr(IsEqual(mb[Trend],OP_BUY),"Long",BoolToStr(IsEqual(mb[Trend],OP_SELL),"Short","Pending Confirmation")),"\n");

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      Append(text,"Manager: "+EnumToString(ma[action].Manager),"\n");
      Append(text,"Strategy: "+BoolToStr(IsEqual(ma[action].Strategy,NoStrategy),"Pending",EnumToString(ma[action].Strategy)));
      Append(text,"Type: "+EnumToString(ma[action].Type));
      Append(text,"Bias: "+ActionText(ma[action].Bias)+BoolToStr(ma[action].Confirmed,"*"));
      Append(text,"Pivot: "+DoubleToString(ma[action].Pivot,Digits));
      Append(text,"AOO: "+DoubleToString(ma[action].AOO,Digits));
      Append(text,"Risk: "+DoubleToString(ma[action].EquityRiskMax,1)+"%");
      Append(text,"Target [Min]: "+DoubleToString(ma[action].EquityTargetMin,1)+"%");
      Append(text," [Max]: "+DoubleToString(ma[action].EquityTarget,1)+"%");
      Append(text,"Stop Loss: "+DoubleToString(ma[action].StopLoss,Digits));
      Append(text,"Take Profit: "+DoubleToString(ma[action].TakeProfit,Digits));
    }

    return text;
  }

