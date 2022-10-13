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
    ManagerType   Manager;            //-- Manager Action (Contrary to OP_[BUY|SELL]
    StrategyType  Strategy;           //-- Manager Strategy
    FractalType   Type;               //-- Last Fractal triggered
    int           Bias;               //-- Bias for Action
    bool          Confirmed;          //-- Bias Confirmation
    double        Pivot;              //-- Bias Pivot
    double        AOO;                //-- Area of Operation
    double        EquityRiskMax;      //-- Maximum Risk by Manager
    double        EquityTargetMin;    //-- Minimum Equity Target by Manager
    double        EquityTarget;       //-- Equity Target by Manager
    double        StopLoss;           //-- Stop Loss by Manager
    double        TakeProfit;         //-- Take Profit by Manager
  };

  ManagerType     manager[FractalTypes];
  ManagerAction   ma[2];
  SessionMaster   sm;

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

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      UpdateLabel("lbvOC-"+ActionText(action)+"-Strategy",BoolToStr(ma[ma[action].Manager].Strategy==NoStrategy,"Pending",EnumToString(ma[ma[action].Manager].Strategy)),
                                                          BoolToInt(ma[ma[action].Manager].Strategy==NoStrategy,clrDarkGray,Color(ma[ma[action].Manager].Strategy)));
      UpdateLabel("lbvOC-"+ActionText(action)+"-Hold",CharToStr(176),BoolToInt(ma[action].Confirmed,clrYellow,
                                                          BoolToInt(ma[ma[action].Manager].Confirmed,clrRed,clrDarkGray)),16,"Wingdings");
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
//    OrderRequest request       = order.BlankRequest("[Auto] "+BoolToStr(IsEqual(Action,OP_BUY),"Long","Short"));
//
//    if (t[NewHigh]||t[NewLow])
//    {
//      if (NewStrategy(mr[Action],Linear))
//      {
//        order.Cancel(BoolToInt(IsEqual(Action,OP_BUY),OP_BUYLIMIT,OP_SELLLIMIT),"Strategy Change");
//        order.Cancel(BoolToInt(IsEqual(Action,OP_BUY),OP_BUYSTOP,OP_SELLSTOP),"Strategy Change");
//      }
//        
//      switch (mr[Action].Strategy)
//      {
////        case Protect:     if (mr[OP_BUY].Hold)
////                          {
////                            order.SetOrderMethod(OP_BUY,(OrderMethod)BoolToInt(mr[OP_BUY].Hold,Hold,Split),ByAction);
////                            order.SetTakeProfit(OP_BUY,t.Tick(0).High,0,Hide);
////                          }
////                          break;
//        case Protect:     request    = Protect(Action,request);
//                          break;
//        case Position:    request    = Position(Action,request);
//                          break;
//        case Release:     request    = Release(Action,request);
//                          break;
//        case Mitigate:    request    = Mitigate(Action,request);
//                          break;
//        case Capture:     request    = Capture(Action,request);
//                          break;
//      }
//
//      if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
//        if (!order.Submitted(request))
//          if (IsEqual(request.Status,Rejected))
//            CallPause(order.RequestStr(request),PauseOn);
//    }
//
//    order.ExecuteOrders(Action);
  }

//+------------------------------------------------------------------+
//| ManageOrders - Handle Order, Request, Risk & Profit by Manager   |
//+------------------------------------------------------------------+
void ManageOrders(ManagerType Manager)
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
        if (order.LotSize(action)<=order.Free(action))
          if (ma[Manager].Confirmed)
          {
            request.Type      = action;
            request.Memo      = "Order "+ActionText(request.Type)+" Test";
   
            if (order.Submitted(request))
              Print(order.RequestStr(request));
            else {/* identifyfailure */}
          }
    }

    //-- Process Contrarian Queue
    if (order.Enabled(action))
      order.ExecuteOrders(action);
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
    int          action     = Action(Manager,InAction,InContrarian);
    int          calc       = Zone(Manager,order.DCA(action))-Zone(action,s[sm.Lead].Pivot(ActiveSession));

    switch (Zone(Manager,order.DCA(action)))
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
    
    if (manager[

    return IsChanged(ma[Manager].Strategy,strategy);
  }

//+------------------------------------------------------------------+
//| NewTrigger - Tests and sets trigger boundaries                   |
//+------------------------------------------------------------------+
bool NewTrigger(void)
  {
    static int    bias         = NoBias;
           bool   triggered    = false;

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      if (NewBias(action,ma[action].Bias,BoolToInt(Close[0]>ma[action].AOO,OP_BUY,OP_SELL)))
        ma[action].Confirmed  = false;

      if (IsChanged(ma[action].Confirmed,ma[action].Confirmed||(IsEqual(ma[action].Bias,OP_BUY)&&Close[0]>t.SMA().High[0])||(IsEqual(ma[action].Bias,OP_SELL)&&Close[0]<t.SMA().Low[0])))
        manager[Term]            = (ManagerType)action;
    }

    if (ma[OP_BUY].Confirmed&&ma[OP_SELL].Confirmed)
      if (IsEqual(ma[OP_BUY].Bias,ma[OP_SELL].Bias))
        if (NewManager(manager[Trend],manager[Term]))
          Flag("manager[Term]",Color(Direction(manager[Trend])));

    if (IsChanged(bias,t.Fractal().Bias))
      if (NewManager(manager[Lead],bias))
        triggered              = true;

    if (t.Event(NewReversal,Critical))
    {
      if (NewManager(manager[Lead],Action(t.Range().Direction)))
        if (IsChanged(bias,manager[Lead]))
          Flag("lnRangeReversal",clrWhite);

      triggered                = true;
    }

    if (t.Event(NewBreakout,Critical))
    {
      if (NewManager(manager[Lead],Action(t.Range().Direction)))
        if (IsChanged(bias,manager[Lead]))
          Flag("lnRangeBreakout",clrSteelBlue);

      triggered                = true;
    }

    if (triggered)
    {
//      Flag("New "+ActionText(action),Color(Direction(action,InAction)));
      ma[manager[Lead]].Type       = (FractalType)BoolToInt(t[NewHigh],t.Fractal().High.Type,t.Fractal().Low.Type);
      ma[manager[Lead]].Bias       = Action(manager[Lead],InAction,InContrarian);
      ma[manager[Lead]].Pivot      = Close[0];
      ma[manager[Lead]].AOO        = BoolToDouble(IsEqual(manager[Lead],OP_BUY),ma[manager[Lead]].Pivot,ma[manager[Lead]].Pivot)+(point(inpAreaOfOperation)*Direction(manager[Lead],InAction));
      ma[manager[Lead]].Confirmed  = false;

      UpdatePriceLabel("manager[Lead]-"+EnumToString(manager[Lead]),Close[0],Color(Direction(ma[manager[Lead]].Bias,InAction)));
      return true;
    }
    
    return NewMomentum();
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {    
    if (NewTrigger())
      if (IsBetween(manager[Lead],OP_BUY,OP_SELL))
      {
//      Pause("New Trigger!","Change");
        ManageOrders((ManagerType)manager[Lead]);
        ManageOrders((ManagerType)Action(manager[Lead],InAction,InContrarian));
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

    Print (ManagerStr());
    RefreshScreen();
    RefreshPanel();
  }


//+------------------------------------------------------------------+
//| ManagerStr - returns formatted Manager data                      |
//+------------------------------------------------------------------+
string ManagerStr(void)
  {
    string text   = "";
    
    Append(text,"Manager Active: "+EnumToString((ManagerType)manager[Lead]),"\n");
    Append(text,"Confirmed: "+EnumToString((ManagerType)manager[Term]));
    Append(text,"Trend: "+BoolToStr(IsEqual(manager[Trend],OP_BUY),"Long",BoolToStr(IsEqual(manager[Trend],OP_SELL),"Short","Pending Confirmation")),"\n");

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

//+------------------------------------------------------------------+  
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    // -- Opening Protection (existing positions)
    order.Enable();
    order.Disable(OP_BUY);
    order.Disable(OP_SELL);

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      //-- Manager Config
      ma[action].Manager           = (ManagerType)action;
      ma[action].Strategy          = NoStrategy;
      ma[action].Type              = Expansion;
      ma[action].Bias              = NoBias;
      ma[action].Confirmed         = false;
      ma[action].Pivot             = NoValue;
      ma[action].AOO               = NoValue;
      ma[action].EquityRiskMax     = inpEquityRiskMax;
      ma[action].EquityTargetMin   = inpEquityTargetMin;
      ma[action].EquityTarget      = inpEquityTarget;
      ma[action].StopLoss          = NoValue;
      ma[action].TakeProfit        = NoValue;

      //-- Order Config
      order.Enable(action);
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetEquityTargets(action,ma[action].EquityTarget,ma[action].EquityTargetMin);
      order.SetRiskLimits(action,ma[action].EquityRiskMax,inpMaxMargin,inpLotFactor);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
      order.SetDefaultMethod(action,Hold);

      NewPriceLabel("manager[Lead]-"+EnumToString(ma[action].Manager));
    }

    ArrayInitialize(manager,Unassigned);

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
