//+------------------------------------------------------------------+
//|                                                       man-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "4.00"
#property strict

#define debug false

#include <Class/Session.mqh>
#include <Class/TickMA.mqh>
#include <Class/Order.mqh>


  //--- Fractal Model
  enum FractalModel
       {
         Session,   // Session
         TickMA     // TickMA
       };


  //--- Display Configuration
  enum ShowType
       {
         stNone   = NoValue,   // None
         stOrigin = Origin,    // Origin
         stTrend  = Trend,     // Trend
         stTerm   = Term       // Term
       };


  //--- Configuration
  input string           appHeader           = "";          // +--- Application Config ---+
  input BrokerModel      inpBrokerModel      = Discount;    // Broker Model
  input FractalModel     inpFractalModel     = TickMA;      // Fractal Model
  input ShowType         inpShowFractal      = stNone;      // Show Fractal/Pivot Lines
  input ShowType         inpShowEvents       = stNone;      // Show Event Flags for Fractal
  input YesNoType        inpShowComments     = No;          // Show Comments
  input int              inpIndSNVersion     = 2;           // Control Panel Version
  input YesNoType        inpPauseOn          = No;          // Pause on Event?


  //---- Extern Variables
  input string           ordHeader           = "";         // +----- Order Options -----+
  input double           inpMinTarget        = 5.0;        // Equity% Target
  input double           inpMinProfit        = 0.8;        // Minimum take profit%
  input double           inpMaxRisk          = 50.0;       // Maximum Risk%
  input double           inpMaxMargin        = 60.0;       // Maximum Open Margin
  input double           inpLotFactor        = 2.00;       // Scaling Lotsize Balance Risk%
  input double           inpLotSize          = 0.00;       // Lotsize Override
  input int              inpDefaultStop      = 50;         // Default Stop Loss (pips)
  input int              inpDefaultTarget    = 50;         // Default Take Profit (pips)
  input double           inpZoneStep         = 2.5;        // Zone Step (pips)
  input double           inpMaxZoneMargin    = 5.0;        // Max Zone Margin


  //--- Regression parameters
  input string           regrHeader          = "";           // +--- Regression Config ----+
  input int              inpPeriods          = 80;           // Retention
  input double           inpAgg              = 2.5;          // Tick Aggregation


  //--- Session Inputs
  input string           sessHeader          = "";           // +--- Session Config -------+
  input int              inpAsiaOpen         = 1;            // Asia Session Opening Hour
  input int              inpAsiaClose        = 10;           // Asia Session Closing Hour
  input int              inpEuropeOpen       = 8;            // Europe Session Opening Hour
  input int              inpEuropeClose      = 18;           // Europe Session Closing Hour
  input int              inpUSOpen           = 14;           // US Session Opening Hour
  input int              inpUSClose          = 23;           // US Session Closing Hour
  input int              inpGMTOffset        = 0;            // Offset from GMT+3


  //-- Internal EA Configuration
  string                 indSN               = "CPanel-v"+(string)inpIndSNVersion;
  string                 objectstr           = "[man-v4]";
  FractalType            show                = FractalTypes;

  
  //-- Class defs
  COrder                *order;
  CSession              *s;
  CTickMA               *t;

  
  //-- Strategy Types
  enum    StrategyType
          {
            Opener,          //-- New Position (Opener)
            Build,           //-- Increase Position
            Hedge,           //-- Contrarian drawdown management
            Cover,           //-- Aggressive balancing on excessive drawdown
            Capture,         //-- Contrarian profit protection
            Mitigate,        //-- Risk management on pattern change
            Defer,           //-- Defer to contrarian manager
            Wait             //-- Hold, wait for signal
          };


  //-- Roles
  enum    RoleType
          {
            Buyer,           //-- Purchasing Manager
            Seller,          //-- Selling Manager
            Unassigned,      //-- No Manager
            RoleTypes
          };


  //-- 
  struct  SessionDetail
          {
            int              HourOpen;                   //-- Role DCA
            int              HourClose;
            //double           Profit[MeasureTypes];
            //double           TakeProfit;
            //double           StopLoss;
          };


  //-- 
  struct  MitigationDetail
          {
            double           DCA;                   //-- Role DCA
            double           Equity[MeasureTypes];
            double           Profit[MeasureTypes];
            double           TakeProfit;
            double           StopLoss;
          };


  //-- Manager Config by Role
  struct  ManagerRec
          {
            StrategyType     Strategy;         //-- Role Responsibility/Strategy
            MitigationDetail Risk;             //-- Risk Mitigation Detail
            MitigationDetail Fund;             //-- Fund Management Detail
            OrderSummary     Entry;            //-- Role Entry Zone Summary
            bool             Hold;             //-- Hold Role Profit
            bool             Trigger;          //-- Trigger state
          };


  //-- Signals (Events) requiring Manager Action (Response)
  struct  SignalRec
          {
            FractalModel     Source;
            bool             Model[2];
            FractalType      Type;
            FractalState     State;
            EventType        Event;
            AlertType        Alert;
            int              Direction;
            RoleType         Lead;
            RoleType         Bias;
            PivotRec         Pivot;
            bool             Fired;
          };


  //-- Master Control Operationals
  struct  MasterRec
          {
            RoleType         Lead;                  //-- Process Manager (Owner|Lead)
            SessionDetail    Session[SessionTypes]; //-- Holds Session Data
          };


  //-- Data Collections
  MasterRec                  master;
  SignalRec                  signal;
  ManagerRec                 manager[RoleTypes];  //-- Manager Detail Data


//+------------------------------------------------------------------+
//| RefreshFractal - Updates TickMA visuals                          |
//+------------------------------------------------------------------+
void RefreshFractal(int Direction, double &Fractal[])
  {
    if (inpShowFractal>stNone)
    {
      UpdateRay(objectstr+"lnS_fp[o]",inpPeriods,Fractal[fpOrigin],-8);
      UpdateRay(objectstr+"lnS_fp[b]",inpPeriods,Fractal[fpBase],-8);
      UpdateRay(objectstr+"lnS_fp[r]",inpPeriods,Fractal[fpRoot],-8,0,
                BoolToInt(IsEqual(Direction,DirectionUp),clrRed,clrLawnGreen));
      UpdateRay(objectstr+"lnS_fp[e]",inpPeriods,Fractal[fpExpansion],-8,0,
                BoolToInt(IsEqual(Direction,DirectionUp),clrLawnGreen,clrRed));
      UpdateRay(objectstr+"lnS_fp[rt]",inpPeriods,Fractal[fpRetrace],-8,0);
      UpdateRay(objectstr+"lnS_fp[rc]",inpPeriods,Fractal[fpRecovery],-8,0);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        UpdateRay(objectstr+"lnS_"+EnumToString(fibo),inpPeriods,fprice(Fractal[fpBase],Fractal[fpRoot],fibo),-8,0,Color(Direction,IN_DARK_DIR));
        UpdateText(objectstr+"lnT_"+EnumToString(fibo),"",fprice(Fractal[fpBase],Fractal[fpRoot],fibo),-5,Color(Direction,IN_DARK_DIR));
      }

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        UpdateText(objectstr+"lnT_"+fp[point],"",Fractal[point],-6);
    }
  }


//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text     = "";

    Append(text,BoolToStr(IsEqual(inpFractalModel,TickMA),t.DisplayStr(),s.DisplayStr()));
    Append(text,BoolToStr(IsEqual(inpFractalModel,TickMA),"Tick "+t.ActiveEventStr(),"Session "+s.ActiveEventStr()),"\n\n");
    Append(text,BoolToStr(IsEqual(inpFractalModel,TickMA),"Session "+s.ActiveEventStr(),"TickMA "+t.ActiveEventStr()),"\n\n");

    if (inpShowComments==Yes)
      Comment(text);

    string alert    = "";

    if (signal.Fired)
    {
      if (t[NewFibonacci]) alert = "Tick";
      else
      if (s[NewFibonacci]) alert = "Session";
      else
                           alert = EnumToString(signal.Source);

      Append(alert,"Trigger ["+EnumToString(signal.Event)+"]");
      Append(alert,"Fractal ["+EnumToString(signal.Type)+"]:"+EnumToString(signal.State),"\n");
      Append(alert,"Lead Bias ["+EnumToString(signal.Lead)+"]:"+ActionText(signal.Bias),"\n");
      Append(alert,text,"\n\n");

      if (inpPauseOn==Yes) Pause(alert,"Trigger Check");
      Arrow("arr"+ActionText(signal.Lead)+":"+BoolToStr(signal.Model[TickMA],"Tick","Session"),
           (ArrowType)BoolToInt(signal.Direction==DirectionUp,
            ArrowUp,BoolToInt(signal.Direction==DirectionDown,ArrowDown,ArrowHold)),
            Color(signal.Direction,IN_CHART_DIR));
    }
  }

//+------------------------------------------------------------------+
//| RefreshPanel - Updates control panel display                     |
//+------------------------------------------------------------------+
void RefreshPanel(void)
  {
    static FractalType fractal   = Prior;
    static int         winid     = NoValue;
    
    //-- Update Control Panel (Application)
    if (IsChanged(winid,ChartWindowFind(0,indSN)))
      order.ConsoleAlert("Connected to "+indSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));

    if (winid>NoValue)
    {
      //-- Update Control Panel (Session)
      for (SessionType type=Daily;type<SessionTypes;type++)
        if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s.Event(NewTerm)||s.Event(NewHour))
        {
          UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[Term].Direction,IN_DARK_DIR));
          UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s.IsOpen(master.Session[type].HourOpen,master.Session[type].HourClose),clrYellow,clrBoxOff));
        }

      for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
      {
        UpdateLabel("lbvOC-"+ActionText(role)+"-Strategy",BoolToStr(manager[role].Trigger,"*")+EnumToString(manager[role].Strategy),
                                                          BoolToInt(manager[role].Trigger,Color(Direction(signal.Lead,InAction)),clrDarkGray));
        UpdateLabel("lbvOC-"+ActionText(role)+"-Hold",CharToStr(176),BoolToInt(manager[role].Hold,clrYellow,clrDarkGray),16,"Wingdings");
      }

      UpdateLabel("lbvOC-BUY-Manager",BoolToStr(IsEqual(master.Lead,Buyer),CharToStr(108)),clrGold,11,"Wingdings");
      UpdateLabel("lbvOC-SELL-Manager",BoolToStr(IsEqual(master.Lead,Seller),CharToStr(108)),clrGold,11,"Wingdings");
    }
  }


//+------------------------------------------------------------------+
//| NewManager - Returns true on change in Operations Manager        |
//+------------------------------------------------------------------+
bool NewManager(RoleType &Incumbent, RoleType Incoming)
  {
    if (IsEqual(Incoming,Incumbent))
      return false;
      
    Incumbent       = Incoming;

    return true;  
  }


//+------------------------------------------------------------------+
//| Manager - Returns the manager for the supplied Fractal           |
//+------------------------------------------------------------------+
RoleType Manager(FractalRec &Fractal)
  {
    return (RoleType)BoolToInt(IsEqual(Fractal.State,Correction),Action(Fractal.Direction,InDirection,InContrarian),Action(Fractal.Direction));
  }


//+------------------------------------------------------------------+
//| SetStrategy - Sets the Manager Strategy                          |
//+------------------------------------------------------------------+
void SetStrategy(void)
  {
//    FractalState strategy        = NoState;
//
//    if (IsEqual(Close[0],s[Daily][Origin].Point[fpExpansion]))
//    {
//      //-- Do Breakout
//      strategy                 = Breakout;
//    }
//    else
//    if (IsEqual(Close[0],s[Daily][Origin].Point[fpRetrace]))
//    {
//      //-- Do Retrace
//      strategy                 = Retrace;
//    }
//    else
//    if (IsEqual(Close[0],s[Daily][Origin].Point[fpRecovery]))
//    {
//      //-- Do Recovery
//      strategy                 = Recovery;
//    }
//    else
//    if (s[Daily].Retrace(Origin,Max)>FiboCorrection)
//    {
//      //-- Do Correction
//      strategy                 = Correction;
//    }
//
//    if (NewState(master.State,strategy))
//      Flag("New State "+EnumToString(strategy),clrYellow);
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Fractal data from Supplied Fractal        |
//+------------------------------------------------------------------+
void UpdateSignal(FractalModel Model, CFractal &Signal)
  {
    signal.Model[Model]       = Signal.ActiveEvent();

    if (Signal.ActiveEvent())
    {
      signal.Source           = Model;
      signal.Event            = Exception;

      if (Signal.Event(NewFractal))
      {
        signal.Type           = (FractalType)BoolToInt(Signal.Event(NewFractal,Critical),Origin,
                                             BoolToInt(Signal.Event(NewFractal,Major),Trend,Term));
        signal.State          = Reversal;
        signal.Event          = NewFractal;
        signal.Direction      = Signal[signal.Type].Direction;
        signal.Pivot          = Signal[signal.Type].Pivot;
        signal.Fired          = true;
      }
      else
      if (Signal.Event(NewFibonacci))
      {
        signal.Type           = (FractalType)BoolToInt(Signal.Event(NewFibonacci,Critical),Origin,
                                             BoolToInt(Signal.Event(NewFibonacci,Major),Trend,Term));
        signal.State          = Signal[signal.Type].State;
        signal.Event          = NewFibonacci;
        signal.Fired          = true;
      }
      else
      if (Signal.Event(NewLead))
      {
        signal.Event          = NewLead;
        signal.Fired          = true;
      }
      else
      if (Signal.Event(NewBoundary))
        if (Signal.Event(NewDirection))           signal.Event = NewDirection;
        else
        if (IsEqual(Signal.MaxAlert(),Notify))    signal.Event = NewTick;
        else
        if (IsEqual(Signal.MaxAlert(),Nominal))   signal.Event = NewSegment;
        else
        if (Signal.Event(NewFlatline)||Signal.Event(NewConsolidation)||Signal.Event(NewParabolic)||Signal.Event(NewChannel))
                                                  signal.Event = CrossCheck;
        else
        if (Signal.Event(NewBias))                signal.Event = NewBias;
        else
        if (Signal.Event(NewExpansion))           signal.Event = NewExpansion;

        else                                      signal.Event = NewBoundary;
      else
        if (Signal.Event(NewFlatline)||Signal.Event(NewConsolidation)||Signal.Event(NewParabolic)||Signal.Event(NewChannel))
                                                  signal.Event = CrossCheck;
        else
        if (Signal.Event(NewBias))                signal.Event = NewBias;
        else
        if (Signal.Event(SessionClose))           signal.Event = SessionClose;
        else
        if (Signal.Event(SessionOpen))            signal.Event = SessionOpen;
        else
        if (Signal.Event(NewDay))                 signal.Event = NewDay;
        else
        if (Signal.Event(NewHour))                signal.Event = NewHour;
    }
    
    if (Signal[NewHigh])
      signal.Bias           = Buyer;

    if (Signal[NewLow])
      signal.Bias           = Seller;

    if (signal.Fired)
    {
      signal.Lead           = signal.Bias;
      signal.Pivot.High     = t.Segment().High;
      signal.Pivot.Low      = t.Segment().Low;
    }

    if (IsHigher(Close[0],signal.Pivot.High))
      signal.Lead           = Buyer;

    if (IsLower(Close[0],signal.Pivot.Low))
      signal.Lead           = Seller;
      
    UpdatePriceLabel("sigHi",signal.Pivot.High,clrLawnGreen,-1);
    UpdatePriceLabel("sigLo",signal.Pivot.Low,clrRed,-1);
  }

//+------------------------------------------------------------------+
//| UpdateManager - Updates Manager data from Supplied Fractal       |
//+------------------------------------------------------------------+
void UpdateManager(CFractal &Fractal)
  {
    RoleType incumbent   = master.Lead;

    //-- Reset Manager Targets
    if (NewManager(master.Lead,Manager(Fractal[Term])))
    {
      manager[incumbent].Risk.DCA           = order.DCA(incumbent);
      manager[incumbent].Risk.StopLoss      = Fractal[Origin].Fractal[fpRoot];
      manager[incumbent].Risk.TakeProfit    = Fractal.Price(Fractal[Origin].Extension.Level,Origin,Extension);

      ArrayInitialize(manager[incumbent].Risk.Equity,order[incumbent].Equity);
      ArrayInitialize(manager[incumbent].Risk.Profit,order[incumbent].Value);
    }
    
    //-- Reset Manager Order Config
    if (IsEqual(order[master.Lead].Count,0))
    {
      manager[master.Lead].Fund.DCA         = NoValue;
      manager[master.Lead].Fund.StopLoss    = NoValue;
      manager[master.Lead].Fund.TakeProfit  = NoValue;

      ArrayInitialize(manager[master.Lead].Fund.Equity,0.00);
      ArrayInitialize(manager[master.Lead].Fund.Profit,0.00);
    }
    else
    {
      manager[master.Lead].Fund.DCA         = order.DCA(master.Lead);

      manager[master.Lead].Fund.StopLoss    = Fractal[Origin].Fractal[fpRoot];
      manager[master.Lead].Fund.TakeProfit  = Fractal.Price((FibonacciType)(Fractal[Origin].Extension.Level+1),Origin,Extension);

      manager[master.Lead].Fund.Equity[Now] = order[master.Lead].Equity;
      manager[master.Lead].Fund.Equity[Min] = fmin(order[master.Lead].Equity,manager[master.Lead].Fund.Equity[Min]);
      manager[master.Lead].Fund.Equity[Max] = fmax(order[master.Lead].Equity,manager[master.Lead].Fund.Equity[Max]);

      manager[master.Lead].Fund.Profit[Now] = order[master.Lead].Value;
      manager[master.Lead].Fund.Profit[Min] = fmin(order[master.Lead].Value,manager[master.Lead].Fund.Profit[Min]);
      manager[master.Lead].Fund.Profit[Max] = fmax(order[master.Lead].Value,manager[master.Lead].Fund.Profit[Max]);

      manager[master.Lead].Risk.Equity[Min] = fmin(order[master.Lead].Equity,manager[master.Lead].Risk.Equity[Min]);
      manager[master.Lead].Risk.Equity[Max] = fmax(order[master.Lead].Equity,manager[master.Lead].Risk.Equity[Max]);
      manager[master.Lead].Risk.Profit[Min] = fmin(order[master.Lead].Value,manager[master.Lead].Risk.Profit[Min]);
      manager[master.Lead].Risk.Profit[Max] = fmax(order[master.Lead].Value,manager[master.Lead].Risk.Profit[Max]);
    }

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      manager[role].Entry        = order.Entry(role);
      manager[role].Trigger      = signal.Fired||manager[role].Trigger;
    }
  }
  

//+------------------------------------------------------------------+
//| UpdateMaster - Updates Master/Manager data                       |
//+------------------------------------------------------------------+
void UpdateMaster(void)
  {
    string    text   = "";

    //-- Update Classes
    order.Update();

    s.Update();
    t.Update();
    
    //-- Update Signals
    signal.Event              = NoEvent;
    signal.Alert              = fmax(s.MaxAlert(),t.MaxAlert());
    signal.Fired              = false;

    UpdateSignal(Session,s);
    UpdateSignal(TickMA,t);

    if (signal.Alert>NoAlert)
    {
      Append(text,"|"+BoolToStr(signal.Fired,"Fired","Idle"));
      Append(text,BoolToStr(signal.Model[Session],"Session","Idle"),"|");
      Append(text,BoolToStr(signal.Model[TickMA],"TickMA","Idle"),"|");
      Append(text,TimeToStr(TimeCurrent()),"|");
      Append(text,EnumToString(signal.Alert),"|");

      for (EventType type=1;type<EventTypes;type++) 
        Append(text,EnumToString(fmax(s.Alert(type),t.Alert(type))),"|");

      if (debug) Print(text);
    }


    switch (inpFractalModel)
    {
      case Session: UpdateManager(s);
                    if (inpShowFractal>stNone) RefreshFractal(s[show].Direction,s[show].Fractal);
                    break;
      case TickMA:  UpdateManager(t);
                    if (inpShowFractal>stNone) RefreshFractal(t[show].Direction,t[show].Fractal);
    }
  }

//+------------------------------------------------------------------+
//| ManageFund - Lead Manager order processor                        |
//+------------------------------------------------------------------+
void ManageFund(RoleType Role)
  {
    OrderRequest  request    = order.BlankRequest(EnumToString(Role));

    //--- R1: Free Zone?
    if (order.Free(Role)>order.Split(Role)||IsEqual(order.Entry(Role).Count,0))
    {
      request.Action         = Role;
      request.Requestor      = "Auto Open ("+request.Requestor+")";
      
      switch (Role)
      {
        case Buyer:          if (t[NewTick])
                               manager[Role].Trigger  = false;

                             break;

        case Seller:         if (t[NewTick])
                               manager[Role].Trigger  = false;
                             break;
      }
    }

    if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
      if (!order.Submitted(request))
        order.PrintLog();
        
    order.ExecuteOrders(Role,manager[Role].Hold);
  }

//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(int Manager)
  {
    order.ExecuteOrders(Manager);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Handle Active Management
    if (IsBetween(master.Lead,Buyer,Seller))
    {
      ManageFund(master.Lead);
      ManageRisk(Action(master.Lead,InAction,InContrarian));
    }
    else
    
    //-- Handle Unassigned Manager
    {
      ManageRisk(Buyer);
      ManageRisk(Seller);
    }

    order.ExecuteRequests();
    
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    UpdateMaster();

    Execute();
    
    RefreshScreen();
    RefreshPanel();
  }

//+------------------------------------------------------------------+
//| OrderConfig Order class initialization function                  |
//+------------------------------------------------------------------+
void OrderConfig(void)
  {
    order = new COrder(inpBrokerModel,Hold,Hold);
    order.Enable("System Enabled "+TimeToString(TimeCurrent()));

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      if (order[action].Lots>0)
        order.Disable(action,"Open "+proper(ActionText(action))+" Positions; Preparing execution plan");
      else
        order.Enable(action,"Action Enabled "+TimeToString(TimeCurrent()));

      //-- Order Config
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetEquityTargets(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
      order.SetDefaultMethod(action,Hold);
    }
  }

//+------------------------------------------------------------------+
//| DisplayConfig - Configure Display objects                         |
//+------------------------------------------------------------------+
void DisplayConfig(void)
  {
    NewPriceLabel("sigHi");
    NewPriceLabel("sigLo");

    if (IsChanged(show,(FractalType)inpShowFractal))
    {
      NewRay(objectstr+"lnS_fp[o]",STYLE_DOT,clrWhite,Never);
      NewRay(objectstr+"lnS_fp[b]",STYLE_SOLID,clrYellow,Never);
      NewRay(objectstr+"lnS_fp[r]",STYLE_SOLID,clrDarkGray,Never);
      NewRay(objectstr+"lnS_fp[e]",STYLE_SOLID,clrDarkGray,Never);
      NewRay(objectstr+"lnS_fp[rt]",STYLE_DOT,clrGoldenrod,Never);
      NewRay(objectstr+"lnS_fp[rc]",STYLE_DOT,clrSteelBlue,Never);

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        NewText(objectstr+"lnT_"+fp[point],fp[point]);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        NewRay(objectstr+"lnS_"+EnumToString(fibo),STYLE_DOT,clrDarkGray,Never);
        NewText(objectstr+"lnT_"+EnumToString(fibo),DoubleToStr(fibonacci[fibo]*100,1)+"%");
      }
    }
  }

//+------------------------------------------------------------------+
//| SessionConfig - Initializes each session on start                |
//+------------------------------------------------------------------+
void SessionConfig(void)
  {
    for (SessionType session=Daily;session<SessionTypes;session++)
    {
    }

    master.Session[Daily].HourOpen      = 0;
    master.Session[Daily].HourClose     = 23;
    master.Session[Asia].HourOpen       = inpAsiaOpen;
    master.Session[Asia].HourClose      = inpAsiaClose;
    master.Session[Europe].HourOpen     = inpEuropeOpen;
    master.Session[Europe].HourClose    = inpEuropeClose;
    master.Session[US].HourOpen         = inpUSOpen;
    master.Session[US].HourClose        = inpUSClose;
  }

//+------------------------------------------------------------------+
//| RoleConfig - Initializes each role on start                      |
//+------------------------------------------------------------------+
void RoleConfig(void)
  {
    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      manager[role].Strategy     = Wait;

      ArrayInitialize(manager[role].Risk.Equity,order[role].Equity);
      ArrayInitialize(manager[role].Risk.Profit,order[role].Value);
    }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    DisplayConfig();
    OrderConfig();
    SessionConfig();
    RoleConfig();

    s = new CSession(Daily,0,23,inpGMTOffset,false,(FractalType)BoolToInt(inpFractalModel==Session,show,NoValue));
    t = new CTickMA(inpPeriods,inpAgg,(FractalType)BoolToInt(inpFractalModel==TickMA,show,NoValue));

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete order;
    delete s;
    delete t;
  }
