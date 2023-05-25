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

enum      StrategyType
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

enum      ResponseType
          {   
            Breakaway,       //-- Breakout Response
            CrossCheck,      //-- Cross Check for SMA, Poly, TL, et al
            Trigger,         //-- Event Triggering Action
            Review           //-- Reviewable event
          };

enum      RoleType
          {
            Buyer,           //-- Purchasing Manager
            Seller,          //-- Selling Manager
            Unnassigned      //-- No Manager
          };

enum      SignalClass
          {
            Tick,            // Tick
            Segment,         // Segment
            SMA,             // Simple MA
            Poly,            // Poly
            Linear,          // Linear
            Range,           // Trading Range
            Fractal,         // Fractal
            Fibonacci,       // Fibonacci
            SignalClasses    // All Alerts
          };

struct    ManagerRec
          {
            StrategyType     Strategy;     //-- Role Responsibility/Strategy
            double           DCA;           //-- Role DCA
            FiboLevel        DCALevel;      //-- DCA Fibo Level
            OrderSummary     Entry;         //-- Role Entry Zone Summary
            bool             Hold;          //-- Hold Role Profit
          };

struct    SignalRec
          {
            SignalClass      Class;
            ResponseType     Response;
            EventType        Event;
            AlertLevel       Alert;
            FractalState     State;
            int              Direction;
            int              Bias;
            double           Price;
            string           Text;
            datetime         Updated;
            bool             Fired;
          };

struct    MasterRec
          {
            RoleType         Lead;          //-- Process Manager (Owner|Lead)
            ManagerRec       Manager[2];    //-- Manager Detail Data
            FractalType      Fractal;       //-- Fractal Lead
            FractalState     State;         //-- Fractal State
            bool             Trap;          //-- Bull/Bear Trap Flag
            PivotRec         Pivot;         //-- Active Pivot
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
  SignalRec            sig_t;               //-- Last Tick Signal
  SignalRec            sig_s;               //-- Last Session Signal
  

//+------------------------------------------------------------------+
//| Alert - Overload to include pause                                |
//+------------------------------------------------------------------+
void Alert(string Text, bool Pause, int Action=NoAction)
  {
    if (Pause)
      if (IsBetween(Action,OP_BUY,OP_SELL))
      {
        int id = Pause("Actionable Item: "+ActionText(Action)+"\n\n"+Text,"Take Action?",MB_OKCANCEL|MB_ICONEXCLAMATION);
        if (id==IDOK)
          OpenOrder(Action,"Event Response");
      }
      else Pause(Text,"Alert Trap");
    else
      Alert(Text);
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
    Append(text,EnumToString(master.Lead));
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
    {
      if (IsChanged(type,master.Fractal))
        UpdateLabel("lbhFractal",EnumToString(master.Fractal),Color(s[Daily][master.Fractal].Direction));

      for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
        UpdateLabel("lbvOC-"+ActionText(role)+"-Strategy",EnumToString(master.Manager[role].Strategy),clrDarkGray);

      UpdateLabel("lbvOC-BUY-Manager",BoolToStr(IsEqual(master.Lead,Buyer),CharToStr(108)),clrGold,11,"Wingdings");
      UpdateLabel("lbvOC-SELL-Manager",BoolToStr(IsEqual(master.Lead,Seller),CharToStr(108)),clrGold,11,"Wingdings");
    }
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
      master.Lead                       = (RoleType)Action(s[Daily][Origin].Direction);
      master.Pivot                      = s[Daily].Pivot();
    }
    else 
    {
      if (s[Daily][NewCorrection])
        master.Lead                     = (RoleType)Action(s[Daily][Origin].Direction,InDirection,InContrarian);

      if (s[Daily][NewRecovery])
        master.Lead                     = (RoleType)Action(s[Daily][Origin].Direction);

      UpdatePivot(master.Pivot,s[Daily][Origin].Direction);
    }

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      master.Manager[role].Strategy     = Wait;
      master.Manager[role].DCA          = order.DCA(role);
      master.Manager[role].DCALevel     = Level(Retrace(s[Daily][Origin].Point[fpRoot],s[Daily][Origin].Point[fpExpansion],master.Manager[role].DCA));
      master.Manager[role].Entry        = order.Entry(role);
    }
  }

//+------------------------------------------------------------------+
//| ManageOrders - Lead Manager order processor                      |
//+------------------------------------------------------------------+
void ManageOrders(RoleType Role, StrategyType Strategy=NoValue)
  {
    OrderRequest  request    = order.BlankRequest(EnumToString(Role));
    StrategyType  strategy   = (StrategyType)BoolToInt(IsEqual(order.Entry(Role).Count,0),Opener,
                                             BoolToInt(IsEqual(Strategy,NoValue),master.Manager[Role].Strategy,Strategy));

    //--- R1: Free Zone
    if (order.Free(Role)>order.Split(Role))
    {
      request.Action         = Action(Role,InAction);
      request.Requestor      = "Auto Open ("+request.Requestor+")";

      switch (strategy)
      {
        case Opener:         
                             break;
        case Build:          break;
        case Hedge:          break;
        case Cover:          break;
        case Capture:        break;
        case Mitigate:       break;
        case Wait:           break;
      }
    }

    if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
      if (!order.Submitted(request))
        order.PrintLog();

    order.ExecuteOrders(Role,master.Manager[Role].Hold);
  }

//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(int Manager)
  {
    order.ExecuteOrders(Manager);
  }

//+------------------------------------------------------------------+
//| InitSignal - Inits a FractalRec for supplied Signal              |
//+------------------------------------------------------------------+
void InitSignal(SignalRec &Signal)
  {
    Signal.Class       = NoValue;
    Signal.Response    = NoValue;
    Signal.Event       = NoEvent;
    Signal.Alert       = NoAlert;
    Signal.State       = NoState;
    Signal.Direction   = NoDirection;
    Signal.Bias        = NoBias;
    Signal.Text        = "";
    Signal.Price       = Close[0];
    Signal.Updated     = TimeCurrent();
    Signal.Fired       = false;
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal detail on Tick                     |
//+------------------------------------------------------------------+
void UpdateSignal(CTickMA &Signal)
  {
    SignalRec signal;
    
    InitSignal(signal);
    
    signal.Response            = Review;
    
    if (Signal[Critical])
    {
      signal.Class             = Range;
      signal.Response          = Breakaway;
      signal.Alert             = Critical;
      signal.State             = Signal.Range().State;
      signal.Direction         = Signal.Range().Direction;
      signal.Bias              = Action(Signal.Range().Direction);

//      if (Signal[NewContraction])  ltext = "Origin [Critical]: Contraction";

      if (Signal[NewBias])
      {
        signal.Response        = CrossCheck;
        signal.Event           = NewBias;
        signal.Bias            = Signal.Linear().Close.Bias;
        signal.Text            = "Origin [Critical]: Bias";
      }

      if (Signal[NewRetrace])
      {
        signal.Event           = NewRetrace;
        signal.Bias            = Action(Signal.Range().Direction,InDirection,InContrarian);
        signal.Text            = "Origin [Critical]: Retrace";
      }

      if (Signal[NewExpansion])
      {
        signal.Event           = NewExpansion;
        signal.Text            = "Origin [Critical]: Expansion";
      }

      if (Signal[AdverseEvent])
      {
        signal.Event           = NewCorrection;
        signal.Bias            = Action(Signal.Range().Direction,InDirection,InContrarian);
        signal.Text            = "Origin [Critical]: Adverse Expansion";
      }

      if (Signal[NewBreakout])
      {
        signal.Event           = NewBreakout;
        signal.Text            = "Origin [Critical]: Breakout";
      }

      if (Signal[NewReversal])
      {
        signal.Event           = NewReversal;
        signal.Text            = "Origin [Critical]: Reversal";
      }
    }
    else
    if (Signal[NewFractal])
    {
      signal.Alert             = Signal.EventLevel(NewFractal);
      signal.State             = Signal.Fractal().State;
      signal.Direction         = Signal.Fractal().Direction;
      signal.Bias              = Signal.Fractal().Bias;

      switch (signal.Alert)
      {
        case Nominal:  //-- Leader Change triggering event
                       signal.Class      = Segment;
                       signal.Alert      = Signal.HighAlert();
                       signal.Response   = Trigger;
                       signal.Event      = NewDirection;
                       signal.State      = (FractalState)BoolToInt(Signal[NewRally],Rally,Pullback);
                       signal.Bias       = BoolToInt(Signal[NewRally],OP_BUY,BoolToInt(Signal[NewPullback],OP_SELL));
                       signal.Text       = "Segment [Minor]: "+EnumToString(signal.State);
                       break;

        case Warning:  signal.Class      = Segment;
                       signal.Event      = NewState;
                       signal.State      = (FractalState)BoolToInt(Signal[NewHigh],Rally,BoolToInt(Signal[NewLow],Pullback,Flatline));
                       signal.Text       = "Segment [Warning]: "+EnumToString(Signal.Fractal().Type);
                       break;

        case Minor:    signal.Class      = Fractal;
                       signal.Response   = Trigger;
                       signal.Event      = NewTerm;
                       signal.Text       = "Term [Minor]: "+EnumToString(Signal.Fractal().Type);
                       break;

        case Major:    signal.Class      = Fractal;
                       signal.Response   = Breakaway;
                       signal.Event      = NewTrend;
                       signal.Text       = "Trend [Major]: "+BoolToStr(IsEqual(Signal.Fractal().Type,Expansion),
                                              EnumToString(Signal.Fractal().State),EnumToString(Signal.Fractal().Type));
                       break;
      }
    }
    else
    {
      signal.Alert      = Signal.HighAlert();
      signal.Direction  = Signal.Segment().Direction[Trend];
      signal.Bias       = Action(Signal.Segment().Direction[Term]);
      signal.State      = (FractalState)BoolToInt(Signal[NewHigh],Rally,BoolToInt(Signal[NewLow],Pullback));

      if (Signal[NewSegment])
      {
        signal.Class    = Segment;
        signal.Event    = NewSegment;
        signal.Text     = "Segment ["+BoolToStr(Signal[NewHigh],"+",BoolToStr(Signal[NewLow],"-","#"))+"]";
      }
      else
      if (Signal[NewTick])
      {
        signal.Class    = Tick;
        signal.Event    = NewTick;
        signal.Text     = "Tick Level ["+BoolToStr(Signal.Segment().Direction[Term]==DirectionUp,"+",
                           BoolToStr(Signal.Segment().Direction[Term]==DirectionDown,"-","#"))+(string)Signal.Segment().Count+"]";
      }
      else
      if (Signal[Minor])
      { 
        signal.Class    = SMA;
        signal.Response = CrossCheck;
        signal.Event    = BoolToEvent(Signal[NewHigh],NewRally,BoolToEvent(Signal[NewLow],NewPullback,NewFlatline));
        signal.Text     = "SMA Check [Minor]: "+BoolToStr(Signal[NewHigh],"High",BoolToStr(Signal[NewLow],"Low","Flatline"));

        Arrow("SMA:"+(string)Signal.Count(Ticks),ArrowDash,BoolToInt(Signal[NewHigh],clrYellow,clrRed));
      }
    }

    static string last   = "";
    if (IsEqual(signal.Class,NoValue))
      sig_t.Fired       = false;
    else
    {
      sig_t             = signal;
      sig_t.Fired       = true;
      
      if (IsChanged(last,signal.Text)||t.ActiveEvent())
        Alert(Symbol()+">"+SignalStr(sig_t)+"|"+t.EventStr());//,IsBetween(signal.Bias,OP_BUY,OP_SELL),signal.Bias);
    }
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
    if (IsBetween(master.Lead,Buyer,Seller))
    {
      ManageOrders(master.Lead);
      ManageRisk(Action(master.Lead,InAction,InContrarian));
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
    OrderMonitor(Mode());
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

    InitSignal(sig_t);
    InitSignal(sig_s);

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
//| SignalStr - Returns formated SignalRec string                    |
//+------------------------------------------------------------------+
string SignalStr(SignalRec &Signal)
  {
    string text   = TimeToStr(Signal.Updated);
   
    Append(text,DoubleToStr(Signal.Price,Digits),"|");
    Append(text,EnumToString(Signal.Alert),"|");
    Append(text,Signal.Text,"|");
    Append(text,EnumToString(Signal.Class),"|");

    Append(text,BoolToStr(Signal.Response==NoValue,"No Response",EnumToString(Signal.Response)),"|");
    Append(text,EnumToString(Signal.Alert),"|");
    Append(text,EnumToString(Signal.Event),"|");
    Append(text,EnumToString(Signal.State),"|");
    Append(text,DirText(Signal.Direction),"|");
    Append(text,ActionText(Signal.Bias),"|");
    
    return text;
  }