//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

#include <Class/Session.mqh>
#include <Class/TickMA.mqh>
#include <Class/Order.mqh>

#define   NoManager     NoAction


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
  string                 objectstr           = "[man-v2]";
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


  //-- Manager Response Types
  enum    ResponseType
          {   
            Breakaway,       //-- Breakout Response
            CrossCheck,      //-- Cross Check for SMA, Poly, TL, et al
            Trigger,         //-- Event Triggering Action
            Review           //-- Reviewable event
          };


  //-- Roles
  enum    RoleType
          {
            Buyer,           //-- Purchasing Manager
            Seller,          //-- Selling Manager
            Unnassigned,     //-- No Manager
            RoleTypes
          };


  //-- Manager Config by Role
  struct  ManagerRec
          {
            StrategyType     Strategy;         //-- Role Responsibility/Strategy
            double           DCA;              //-- Role DCA
            OrderSummary     Entry;            //-- Role Entry Zone Summary
            bool             Hold;             //-- Hold Role Profit
          };


  //-- Signals (Events) requiring Manager Action (Response)
  struct  SignalRec
          {
            FractalState     State;
            EventType        Event;
            AlertType        Alert;
            int              Direction;
            int              Lead;
            int              Bias;
            double           Price;
            string           Text;
            ResponseType     Response;
            bool             Fired;
            datetime         Updated;
            datetime         Resolved;
          };


  //-- Master Control Operationals
  struct  MasterRec
          {
            RoleType         Lead;                  //-- Process Manager (Owner|Lead)
            SessionRec       Session[SessionTypes]; //-- Holds Session Data
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


//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text     = "";

    if (inpShowComments==Yes)
    {
      Append(text,t.DisplayStr());
      Append(text,t.ActiveEventStr(),"\n\n");

      Comment(text);
    }
  }

//+------------------------------------------------------------------+
//| UpdatePanel - Updates control panel display                      |
//+------------------------------------------------------------------+
void UpdatePanel(void)
  {
    static FractalType fractal   = Prior;
    static int         winid     = NoValue;
    //static StrategyType strategytype[2];
    //const  color        holdcolor[HoldTypes]     = {clrDarkGray,clrLawnGreen,clrRed,clrYellow};
    
    //-- Update Control Panel (Application)
    if (IsChanged(winid,ChartWindowFind(0,indSN)))
      order.ConsoleAlert("Connected to "+indSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));

    if (winid>NoValue)
    {
      //if (IsChanged(fractal,master.Fractal))
      //  UpdateLabel("lbhFractal",EnumToString(master.Fractal),Color(s[Daily][master.Fractal].Direction));

      //-- Update Control Panel (Session)
      for (SessionType type=Daily;type<SessionTypes;type++)
        if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s.Event(NewTerm)||s.Event(NewHour))
        {
          UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[Term].Direction,IN_DARK_DIR));
          UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s.IsOpen(),clrYellow,clrBoxOff));
        }

      for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
      {
        UpdateLabel("lbvOC-"+ActionText(role)+"-Strategy",EnumToString(manager[role].Strategy),clrDarkGray);
//        UpdateLabel("lbvOC-"+ActionText(action)+"-Hold"+EnumToString(type),CharToStr(176),holdcolor[hold[type].Active[action].Type],16,"Wingdings");
      }

      UpdateLabel("lbvOC-BUY-Manager",BoolToStr(IsEqual(master.Lead,Buyer),CharToStr(108)),clrGold,11,"Wingdings");
      UpdateLabel("lbvOC-SELL-Manager",BoolToStr(IsEqual(master.Lead,Seller),CharToStr(108)),clrGold,11,"Wingdings");
    }
  }


//+------------------------------------------------------------------+
//| Manager - Returns the manager for the supplied Fractal           |
//+------------------------------------------------------------------+
RoleType Manager(FractalRec &Fractal)
  {
    return (RoleType)BoolToInt(IsEqual(Fractal.State,Correction),Action(Fractal.Direction,InDirection,InContrarian),Action(Fractal.Direction));
  }


//+------------------------------------------------------------------+
//| InitSignal - Inits a FractalRec for supplied Signal              |
//+------------------------------------------------------------------+
void InitSignal(SignalRec &Signal)
  {
    Signal.State       = NoState;
    Signal.Event       = NoEvent;
    Signal.Alert       = NoAlert;
    Signal.Direction   = NoDirection;
    Signal.Lead        = NoManager;
    Signal.Bias        = NoBias;
    Signal.Price       = NoValue;
    Signal.Text        = "";
    Signal.Price       = Close[0];
    Signal.Response    = Review;
    Signal.Fired       = false;
    Signal.Updated     = TimeCurrent();
    Signal.Resolved    = NoValue;
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
//| UpdateFractal - Updates Fractal data from Supplied Source        |
//+------------------------------------------------------------------+
void UpdateFractal(CFractal &Fractal)
  {
    if ((ShowType)show>stNone) RefreshFractal(Fractal[show].Direction,Fractal[show].Fractal);
  }
  

//+------------------------------------------------------------------+
//| UpdateMaster - Updates Master/Manager data                       |
//+------------------------------------------------------------------+
void UpdateMaster(void)
  {
    //-- Update Classes
    order.Update();

    s.Update();
    t.Update();

    if (t.ActiveEvent())
      Print("|"+TimeToString(TimeCurrent())+"|"+t.EventStr(NoEvent,EventTypes));

    switch (inpFractalModel)
    {
      case Session: UpdateFractal(s);
                    break;
      case TickMA:  UpdateFractal(t);
    }
    
    //-- Handle Main [Origin-Level/Macro] Events
    master.Lead                  = Manager(s.Fractal(Term));

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      manager[role].DCA          = order.DCA(role);
      manager[role].Entry        = order.Entry(role);
    }
    
    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal detail on Tick                     |
//+------------------------------------------------------------------+
void UpdateSignal(CSession &Signal)
  {
    SignalRec alert;

    InitSignal(alert);

    for (EventType event=NewRally;IsBetween(event,NewRally,NewExtension);event++)
      if (Signal[event])
      {
        alert.State           = Signal.State(event);
        alert.Event           = event;
        alert.Alert           = Signal.Alert(event);
      }

    if (alert.Event>NoEvent)
    {
    }
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal detail on Tick                     |
//+------------------------------------------------------------------+
void UpdateSignal(CTickMA &Signal)
  {
    bool newstate    = false;
    SignalRec alert;

    InitSignal(alert);

    for (EventType event=NewRally;IsBetween(event,NewRally,NewExtension);event++)
      if (Signal[event])
        newstate     = true;

    //if (newstate)
    //  Pause("NewState\n"+Signal.DisplayStr()+"\n"+Signal.ActiveEventStr(),"Event Check");
  }

//+------------------------------------------------------------------+
//| ManageOrders - Lead Manager order processor                      |
//+------------------------------------------------------------------+
void ManageOrders(RoleType Role)
  {
    OrderRequest  request    = order.BlankRequest(EnumToString(Role));

    //--- R1: Free Zone?
    if (order.Free(Role)>order.Split(Role)||IsEqual(order.Entry(Role).Count,0))
    {
      request.Action         = Role;
      request.Requestor      = "Auto Open ("+request.Requestor+")";
      
      switch (Role)
      {
        case Buyer:          break;
        case Seller:         break;
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
      ManageOrders(master.Lead);
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
//    UpdateSignal(s);
    UpdateSignal(t);
    UpdatePanel();
//
//    Execute();
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
//| RoleConfig - Initializes each role on start                      |
//+------------------------------------------------------------------+
void RoleConfig(void)
  {
    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      manager[role].Strategy     = Wait;
    }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    DisplayConfig();
    OrderConfig();
    RoleConfig();

    s = new CSession(Daily,0,23,inpGMTOffset,true,(FractalType)BoolToInt(inpFractalModel==Session,show,NoValue));
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
