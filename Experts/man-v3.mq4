//+------------------------------------------------------------------+
//|                                                       man-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "3.00"
#property strict

#include <manual.mqh>
#include <Class/TickMA.mqh>
#include <Class/Order.mqh>
#include <Class/Session.mqh>

#define   NoManager     NoAction

string    indSN      = "CPanel-v3";

enum DirectiveType
     {
       Build,           //-- Increase Position
       Hedge,           //-- Contrarian drawdown management
       Cover,           //-- Aggressive balancing on excessive drawdown
       Capture,         //-- Contrarian profit protection
       Mitigate,        //-- Risk management on pattern change
       Wait             //-- Hold, wait for signal
     };
     
enum RoleType
     {
       Buyer,           //-- Purchasing Manager
       Sales,           //-- Selling Manager
       Unnassigned      //-- No Manager
     };

enum SignalType
     {
       Tick,            // Tick
       Segment,         // Segment
       SMA,             // Simple MA
       Poly,            // Poly
       Linear,          // Linear
       Fractal,         // Fractal
       Fibonacci,       // Fibonacci
       SignalTypes      // All Alerts
     };

struct RoleRec
       {
         DirectiveType Directive;          //-- Role Responsibility/Strategy
         double        DCA;                //-- Role DCA
         FiboLevel     DCALevel;           //-- DCA Fibo Level
         OrderSummary  Entry;              //-- Role Entry Zone Summary
         bool          Hold;               //-- Hold Role Profit
       };

struct SignalRec
       {
         FractalRec    Tick[SignalTypes];
         FractalRec    Session[SignalTypes];
       };

struct MasterRec
       {
         RoleType      Director;           //-- Process Manager (Owner|Lead)
         RoleRec       Manager[2];         //-- Manager Detail Data
         SignalType    Tick;               //-- Last Tick Signal
         SignalType    Session;            //-- Last Session Signal
         FractalType   Fractal;            //-- Fractal Lead
         FractalState  State;              //-- Fractal State
         PivotRec      Pivot;              //-- Active Pivot
       };

//--- Configuration
input string           appHeader          = "";          // +--- Application Config ---+
input BrokerModel      inpBrokerModel     = Discount;    // Broker Model
input double           inpZoneStep        = 2.5;         // Zone Step (pips)
input double           inpMaxZoneMargin   = 5.0;         // Max Zone Margin
input AlertLevel       inpAlertTick       = Nominal;     // Tick Alert Level
input AlertLevel       inpAlertSession    = Nominal;     // Segment Alert Level


//--- Regression parameters
input string           regrHeader         = "";          // +--- Regression Config ----+
input int              inpPeriods         = 80;          // Retention
input int              inpDegree          = 6;           // Poly Regression Degree
input double           inpAgg             = 2.5;         // Tick Aggregation


//--- Session Inputs
input string           sessHeader        = "";           // +--- Session Config -------+
input SessionType      inpShowFractal    = Daily;        // Display Session Fractal
input int              inpAsiaOpen       = 1;            // Asia Session Opening Hour
input int              inpAsiaClose      = 10;           // Asia Session Closing Hour
input int              inpEuropeOpen     = 8;            // Europe Session Opening Hour
input int              inpEuropeClose    = 18;           // Europe Session Closing Hour
input int              inpUSOpen         = 14;           // US Session Opening Hour
input int              inpUSClose        = 23;           // US Session Closing Hour
input int              inpGMTOffset      = 0;            // Offset from GMT+3

  CTickMA             *t                 = new CTickMA(inpPeriods,inpDegree,inpAgg);
  COrder              *order             = new COrder(inpBrokerModel,Hold,Hold);
  CSession            *s[SessionTypes];
  
  MasterRec            master;
  MasterRec            legacy;
  SignalRec            signal;
  FractalRec           fractal;
  
  string               ltext;
  datetime             ltime;

//+------------------------------------------------------------------+
//| Alert - Writes events to log in debug; alerts on Live Market     |
//+------------------------------------------------------------------+
void Alert(FractalRec &Signal, AlertLevel Level)
  {
    string text     = "";

    if (IsBetween(Signal.Alert,Level,AlertLevels))
    {
      Append(text,Symbol()+">");
      Append(text,TimeToStr(TimeCurrent()));
      Append(text,StringSubstr(EnumToString(Signal.Event),3));
      
      Append(text,"["+EnumToString(Signal.Alert)+"]: ");

      switch (Signal.Alert)
      {
        case Notify:    Append(text,"Tick Level ["+(string)(t.Segment().Count)+"]");
        case Nominal:   break;
      }
      
//      if (LegacyTime>NoValue&&IsEqual(LegacyTime,Signal.Updated))
//        Alert(text);
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string        text                    = "";

    //-- Update Comment
    Append(text,"*----------- Master Fractal Pivots ----------------*");
    Append(text,"Fractal "+EnumToString(master.Fractal),"\n");
    Append(text,EnumToString(master.State));
    Append(text,EnumToString(master.Director));
    Append(text,s[Daily].PivotStr("Lead",master.Pivot),"\n");

    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
      Append(text,s[Daily].PivotStr(EnumToString(type),s[Daily].Pivot(type)),"\n");

    if (inpShowFractal==Daily)
      Append(text,s[inpShowFractal].FractalStr(5),"\n\n");

    Append(text,"Daily "+s[Daily].ActiveEventStr(),"\n\n");
    Append(text,"Tick "+t.ActiveEventStr(),"\n\n");

    Comment(text);
  }

//+------------------------------------------------------------------+
//| UpdatePanel - Updates control panel display                      |
//+------------------------------------------------------------------+
void UpdatePanel(void)
  {
    static FractalType type      = Prior;
    static int         winid     = NoValue;

    //-- Update Control Panel (Application)
    if (IsChanged(winid,ChartWindowFind(0,indSN)))
      order.ConsoleAlert("Connected to "+indSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));

    if (winid>NoValue)
      if (IsChanged(type,master.Fractal))
        UpdateLabel("lbhFractal",EnumToString(master.Fractal),Color(s[Daily][master.Fractal].Direction));
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
//| UpdateMaster - Updates Master/Manager data                       |
//+------------------------------------------------------------------+
void UpdateMaster(void)
  {
    //-- Update Classes
    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();

    if (s[Daily][NewFibonacci])
      for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
        if (IsEqual(s[Daily].Pivot(type).Event,NewFibonacci))
        {
          master.Fractal             = type;
          break;
        }

    if (IsChanged(master.State,s[Daily][Origin].State))
      Flag("New Origin State ["+EnumToString(s[Daily][Origin].State)+"]",Color(master.State));

    order.Update();
    t.Update();
    
    //-- Handle Main [Origin-Level/Macro] Events
    if (s[Daily].Event(NewBreakout,Critical)||s[Daily].Event(NewReversal,Critical))
    {
      master.Director                   = (RoleType)Action(s[Daily][Origin].Direction);
      master.Pivot                      = s[Daily].Pivot();
    }
    else 
    {
      if (s[Daily][NewCorrection])
        master.Director                 = (RoleType)Action(s[Daily][Origin].Direction,InDirection,InContrarian);

      if (s[Daily][NewRecovery])
        master.Director                 = (RoleType)Action(s[Daily][Origin].Direction);

      UpdatePivot(master.Pivot,s[Daily][Origin].Direction);
    }

    for (RoleType role=Buyer;IsBetween(role,Buyer,Sales);role++)
    {
      master.Manager[role].Directive    = Wait;
      master.Manager[role].DCA          = order.DCA(role);
      master.Manager[role].DCALevel     = Level(Retrace(s[Daily][Origin].Point[fpRoot],s[Daily][Origin].Point[fpExpansion],master.Manager[role].DCA));
      master.Manager[role].Entry        = order.Entry(role);
    }
  }

//+------------------------------------------------------------------+
//| ManageOrders - Lead Manager order processor                      |
//+------------------------------------------------------------------+
void ManageOrders(RoleType Role)
  {
    OrderRequest  request    = order.BlankRequest(EnumToString(Role));
    RoleRec       manager    = master.Manager[Role];

    //--- R1: Free Zone?
    if (order.Free(Role)>order.Split(Role)||IsEqual(order.Entry(Role).Count,0))
    {
      request.Action         = Role;
      request.Requestor      = "Auto Open ("+request.Requestor+")";
      
      switch (Role)
      {
        case Buyer:          break;
        case Sales:          break;
      }
    }

    if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
      if (!order.Submitted(request))
        order.PrintLog();
        
    order.ExecuteOrders(Role,manager.Hold);
  }

//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(int Manager)
  {
    order.ExecuteOrders(Manager);
  }

//+------------------------------------------------------------------+
//| SetSignal - Updates Signal detail on Tick                        |
//+------------------------------------------------------------------+
void SetSignal(FractalRec &Signal, EventType Event, AlertLevel Level)
  {
    Signal.Event              = Event;
    Signal.Alert              = Level;
    Signal.Updated            = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal detail on Tick                     |
//+------------------------------------------------------------------+
void UpdateSignal(CTickMA &Signal)
  {
//-- FractalType   Type;                     //-- Type
//-- FractalState  State;                    //-- State
//-- int           Direction;                //-- Direction based on Last Breakout/Reversal (Trend)
//-- double        Price;                    //-- Event Price
//-- int           Lead;                     //-- Bias based on Last Pivot High/Low hit
//-- int           Bias;                     //-- Active Bias derived from Close[] to Pivot.Open  
//-- EventType     Event;                    //-- Last Event; disposes on next tick
//-- AlertLevel    Alert;                    //-- Last Alert; disposes on next tick
//-- bool          Peg;                      //-- Retrace peg
//-- bool          Trap;                     //-- Trap flag (not yet implemented)
//-- datetime      Updated;                  //-- Last Update;
//-- double        Point[FractalPoints];     //-- Fractal Points (Prices)
//    FractalRec     fractal;

    InitSignal(fractal);

    if (Signal[NewTick])
      SetSignal(fractal,NewTick,Notify);

    if (Signal[NewSegment])
      SetSignal(fractal,NewSegment,Nominal);

    if (Signal.Event(NewTerm,Nominal))
      SetSignal(fractal,NewSegment,Minor);

    if (Signal[FractalEvent(Signal.Fractal().Type)])
      SetSignal(fractal,NewFractal,Signal.EventLevel(FractalEvent(Signal.Fractal().Type)));
      
    if (Signal[NewFractal])
      SetSignal(fractal,NewFractal,Signal.EventLevel(NewFractal));

    if (Signal[Critical])
      switch (Signal.Range().Event)
      {
        case AdverseEvent:    
        case NewBreakout:    
        case NewReversal:   SetSignal(fractal,NewFractal,Critical);
                            break;
      }
      
//    Alert(fractal,inpAlertTick);
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal detail on Tick                     |
//+------------------------------------------------------------------+
void UpdateSignal(CSession &Signal)
  {
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Handle Active Management
    if (IsBetween(master.Director,Buyer,Sales))
    {
      ManageOrders(master.Director);
      ManageRisk(Action(master.Director,InAction,InContrarian));
    }
    else
    
    //-- Handle Unassigned Manager
    {
      ManageRisk(OP_BUY);
      ManageRisk(OP_SELL);
    }

    order.ExecuteRequests();
  }

//+------------------------------------------------------------------+
//| ExecuteLegacy -                                                  |
//+------------------------------------------------------------------+ 
void ExecuteLegacy(void)
  {
    string text    = Symbol()+">"+TimeToStr(ltime)+";"+DoubleToStr(Close[0],Digits);
    ltime          = TimeCurrent();
    ltext          = "";

    OrderMonitor(Mode());

    if (t[Critical])
    {
//      if (t[NewContraction])  ltext = "Origin [Critical]: Contraction";
      if (t[NewExpansion])    ltext = "Origin [Critical]: Expansion";
      if (t[NewRetrace])      ltext = "Origin [Critical]: Retrace";
      if (t[AdverseEvent])    ltext = "Origin [Critical]: Adverse Event";
      if (t[NewBreakout])     ltext = "Origin [Critical]: Breakout";
      if (t[NewReversal])     ltext = "Origin [Critical]: Reversal";
    }
    else
    if (t[NewFractal])
      switch (t.EventLevel(NewFractal))
      {
        case Nominal:  ltext  = "Segment [Minor]: "+BoolToStr(t[NewRally],"Rally",
                                 BoolToStr(t[NewPullback],"Pullback","???"));
                       break;

        case Warning:  ltext  = "Segment [Warning]: "+BoolToStr(t[NewRally],"Rally",
                                 BoolToStr(t[NewPullback],"Pullback",EnumToString(t.Fractal().Type)));
                       break;

        case Minor:    ltext  = "Term [Minor]: Reversal";
                       break;

        case Major:    ltext  = "Trend [Major]: "+BoolToStr(t.Fractal().Trap,"Trap",
                                 BoolToStr(IsEqual(t.Fractal().Type,Expansion),EnumToString(t.Fractal().State),EnumToString(t.Fractal().Type)));
                       break;
      }
    else
    if (t[FractalEvent(t.Fractal().Type)])
    {
      ltext   = BoolToStr(t.Linear().Close.Event>NoEvent,"FOC "+EnumToString(t.Linear().Close.Event));
//      Append(ltext,BoolToStr(
      ltext  += " ["+EnumToString(t.EventLevel(FractalEvent(t.Fractal().Type)))+"]: "+EnumToString(FractalEvent(t.Fractal().Type));
    }
    else
    if (t[NewSegment])
      ltext  = "Segment "+BoolToStr(t[NewHigh],"High",BoolToStr(t[NewLow],"Low","???"));
    else
    if (t[NewTick])
      ltext  = "Tick Level ["+BoolToStr(t.Segment().Direction[Term]==DirectionUp,"+",BoolToStr(t.Segment().Direction[Term]==DirectionDown,"-","#"))+(string)t.Segment().Count+"]";

//    if (StringLen(ltext)>0||t.Linear().Close.Event>NoEvent)
//    {
//      ltime           = TimeCurrent();
////      Alert(Symbol()+">"+TimeToStr(ltime)+" "+ltext);
//      Alert(Symbol()+">"+TimeToStr(ltime)+"|"+ltext+
//                     "|"+EventText[t.Linear().Close.Event]+" "+EnumToString(t.Linear().Close.State)+" ["+ActionText(t.Linear().Close.Direction)+":"+ActionText(t.Linear().Close.Bias)+"]"+
//                     "|"+EventText[t.Linear().Close.Event]);
//    }

    if (t.ActiveEvent())
    {
      for (EventType event=NoEvent;event<EventTypes;event++)
        if (t[event])
          Append(text,EnumToString(event)+"["+EnumToString(t.EventLevel(event))+"]",":");

      Alert(text+"|"+ltext);
//        Alert(Symbol()+">"+TimeToStr(ltime)+"|"+ltext+
//                     "|"+EventText[t.Linear().Close.Event]+" "+EnumToString(t.Linear().Close.State)+" ["+ActionText(t.Linear().Close.Direction)+":"+ActionText(t.Linear().Close.Bias)+"]"+
//                     "|"+EventText[t.Linear().Close.Event]);
    }
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+ 
void ExecAppCommands(string &Command[])
  {
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string     otParams[];

    InitializeTick();
    GetManualRequest();

    while (AppCommand(otParams,6))
      ExecAppCommands(otParams);

    UpdateMaster();
    UpdateSignal(t);         //-- TickMA Alerts
    UpdateSignal(s[Daily]);  //-- Session Alerts
    UpdatePanel();

    if (Mode()==Legacy)
      ExecuteLegacy();

    if (Mode()==Auto)
      Execute();

    RefreshScreen();    
    ReconcileTick();        
  }

//+------------------------------------------------------------------+
//| OrderConfig Order class initialization function                  |
//+------------------------------------------------------------------+
void OrderConfig()
  {
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
//| InitSignal - Inits a FractalRec for supplied Signal              |
//+------------------------------------------------------------------+
void InitSignal(FractalRec &Signal)
  {
    Signal.Type        = NoValue;
    Signal.State       = NoState;
    Signal.Direction   = NoDirection;
    Signal.Price       = Close[0];
    Signal.Lead        = NoBias;
    Signal.Bias        = NoBias;
    Signal.Event       = NoEvent;
    Signal.Alert       = NoAlert;
    Signal.Peg         = false;
    Signal.Trap        = false;
    Signal.Updated     = NoValue;

    ArrayInitialize(Signal.Point,NoValue);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    datetime time      = NoValue;

    ManualInit();
    OrderConfig();
   
    //-- Initialize Session
    s[Daily]           = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]            = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]          = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]              = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
      if (s[Daily].Fibonacci(type).Level>Fibo61)
        if (IsHigher(s[Daily].Pivot(type).Time,time))
          master.Fractal = type;

    master.Pivot       = s[Daily].Pivot(Breakout,0,Max);

    for (SignalType type=0;type<SignalTypes;type++)
    {
      InitSignal(signal.Tick[type]);
      InitSignal(signal.Session[type]);
    };

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
