//+------------------------------------------------------------------+
//|                                                       man-v5.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "5.10"
#property strict

#define debug false

#include <Class/Session.mqh>
#include <Class/TickMA.mqh>
#include <ordman.mqh>

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


//--- App Configuration
input string           appHeader           = "";            // +--- Application Config ---+
input BrokerModel      inpBrokerModel      = Discount;      // Broker Model
input FractalModel     inpFractalModel     = TickMA;        // Fractal Model
input ShowType         inpShowFractal      = stNone;        // Show Fractal/Pivot Lines
input string           inpBaseCurrency     = "XRPUSD";      // Account Base Currency
input string           inpComFile          = "manual.csv";  // Command File Name
input YesNoType        inpShowComments     = No;            // Show Comments
input int              inpIndSNVersion     = 2;             // Control Panel Version


//--- Regression parameters
input string           regrHeader          = "";           // +--- Regression Config ----+
input int              inpPeriods          = 80;           // Retention
input double           inpAgg              = 2.5;          // Tick Aggregation


//---- Extern Variables
input string           ordHeader           = "";            // +----- Order Options -----+
input double           inpMinTarget        = 5.0;           // Equity% Target
input double           inpMinProfit        = 0.8;           // Minimum take profit%
input double           inpMaxRisk          = 50.0;          // Maximum Risk%
input double           inpMaxMargin        = 60.0;          // Maximum Open Margin
input double           inpLotFactor        = 2.00;          // Scaling Lotsize Balance Risk%
input double           inpLotSize          = 0.00;          // Lotsize Override
input int              inpDefaultStop      = 50;            // Default Stop Loss (pips)
input int              inpDefaultTarget    = 50;            // Default Take Profit (pips)
input double           inpZoneStep         = 2.5;           // Zone Step (pips)
input double           inpMaxZoneMargin    = 5.0;           // Max Zone Margin

string                 indSN               = "CPanel-v"+(string)inpIndSNVersion;


  //-- Strategy Types
  enum    StrategyType
          {
            Wait,            //-- Hold, wait for signal
            Manage,          //-- Maintain Margin, wait for profit oppty's
            Build,           //-- Increase Position
            Cover,           //-- Aggressive balancing on excessive drawdown
            Capture,         //-- Contrarian profit protection
            Mitigate,        //-- Risk management on pattern change
            Defer            //-- Defer to contrarian manager
          };


  //-- Roles
  enum    RoleType
          {
            Buyer,           //-- Purchasing Manager
            Seller,          //-- Selling Manager
            Unassigned,      //-- No Manager
            RoleTypes
          };

  //-- Session Data
  struct  SessionDetail
          {
            int              HourOpen;                   //-- Role DCA
            int              HourClose;
            //double           Profit[MeasureTypes];
            //double           TakeProfit;
            //double           StopLoss;
          };


  //-- Risk Mitigation Data
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
            double           Crest;
            double           Trough;
            bool             Fired;
          };


  //-- Master Control Operationals
  struct  MasterRec
          {
            RoleType         Lead;                  //-- Process Manager (Owner|Lead)
            SessionDetail    Session[SessionTypes]; //-- Holds Session Data
          };


  //-- Data Collections
  MasterRec              master;
  SignalRec              signal;
  ManagerRec             manager[RoleTypes];  //-- Manager Detail Data
  
  //-- Class defs
  COrder                *order;
  CTickMA               *t;
  CSession              *s;

  //-- Operational Variables
  int    winid         = NoValue;
  double sigHi         = NoValue;
  double sigLo         = NoValue;
  double crest[];
  double trough[];

//+------------------------------------------------------------------+
//| RefreshPanel - Updates control panel display                     |
//+------------------------------------------------------------------+
void RefreshPanel(void)
  {
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

      //-- Session Box
      UpdateDirection("tmaSessionTrendDir"+(string)winid,s[Trend].Direction,Color(s[Trend].Direction),16);
      UpdateDirection("tmaSessionTermDir"+(string)winid,s[Term].Direction,Color(s[Term].Direction),32);
      UpdateLabel("tmaSessionState"+(string)winid,center(EnumToString(s[Trend].State),18),Color(s[Trend].Direction),16);
      UpdateLabel("tmaSessionFractalState"+(string)winid,center(proper(ActionText(s[ActiveSession].Lead))+" "+
                    BoolToStr(IsEqual(s[ActiveSession].Lead,s[ActiveSession].Bias),"Hold","Hedge"),30),Color(Direction(s[ActiveSession].Lead,InAction)),12);
      UpdateDirection("tmaSessionPivotLead"+(string)winid,Direction(s[ActiveSession].Lead,InAction),Color(Direction(s[ActiveSession].Lead,InAction)),18);
      UpdateDirection("tmaSessionPivotBias"+(string)winid,Direction(s[ActiveSession].Bias,InAction),Color(Direction(s[ActiveSession].Bias,InAction)),18);


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
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
//    Comment("Source Value ["+inpBaseCurrency+"]:"+DoubleToStr(iClose(inpBaseCurrency,0,0)));
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
      
    UpdatePriceLabel("sigHi",signal.Pivot.High,clrLawnGreen,-3);
    UpdatePriceLabel("sigLo",signal.Pivot.Low,clrRed,-3);
  }


//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal Price Arrays                       |
//+------------------------------------------------------------------+
void UpdateSignal(void)
  {
    double sma;
    
    signal.Crest           = NoValue;
    signal.Trough          = NoValue;

    if (t[NewBoundary])
    {
      if (t[NewHigh])
        if (IsChanged(sigHi,t.SMA().High[0]))
        {
          ArrayResize(crest,fmin(t.Count(Segments),inpPeriods),inpPeriods);
          ArrayInitialize(crest,0.00);

          sma  = t.Range().Low;

          for (int node=2;node<ArraySize(crest)-1;node++)
            if (t.SMA().High[node]>t.SMA().High[node-1])
              if (t.SMA().High[node]>t.SMA().High[node+1])
                if (IsHigher(t.SMA().High[node],sma))
                {
                  signal.Crest     = Close[0];
                  crest[node]      = sma;
                }
        }
        
      if (t[NewLow])
        if (IsChanged(sigLo,t.SMA().Low[0]))
        {
          ArrayResize(trough,fmin(t.Count(Segments),inpPeriods),inpPeriods);
          ArrayInitialize(trough,0.00);

          sma   = t.Range().High;
          
          for (int node=2;node<ArraySize(trough)-1;node++)
            if (t.SMA().Low[node]<t.SMA().Low[node-1])
              if (t.SMA().Low[node]<t.SMA().Low[node+1])
                if (IsLower(t.SMA().Low[node],sma))
                {
                  signal.Trough    = Close[0];
                  trough[node]     = sma;
                }
        }
    }
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
      manager[master.Lead].Fund.TakeProfit  = Fractal.Price((FibonacciType)(Fractal[Origin].Extension.Level+BoolToInt(Fractal[Origin].Extension.Level<Fibo823,1)),Origin,Extension);

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
    order.Update(BoolToDouble(inpBaseCurrency=="XRPUSD",iClose(inpBaseCurrency,0,0),1));

    s.Update();
    t.Update();
    
    //-- Update Signals
    signal.Event              = NoEvent;
    signal.Alert              = fmax(s.MaxAlert(),t.MaxAlert());
    signal.Fired              = false;

    UpdateSignal(Session,s);
    UpdateSignal(TickMA,t);
    UpdateSignal();

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
                    //if (inpShowFractal>stNone) RefreshFractal(s[show].Direction,s[show].Fractal);
                    break;
      case TickMA:  UpdateManager(t);
                    //if (inpShowFractal>stNone) RefreshFractal(t[show].Direction,t[show].Fractal);
    }
  }

//+------------------------------------------------------------------+
//| SetLeadStrategy - Set Strategy for supplied Role                 |
//+------------------------------------------------------------------+
void SetLeadStrategy(RoleType Role, bool Trigger)
  {
//Wait             //-- Hold, wait for signal
//Manage,          //-- Manage Margin; Seek Profit
//Build,           //-- Increase Position
//Cover,           //-- Aggressive balancing on excessive drawdown
//Capture,         //-- Contrarian profit protection
//Mitigate,        //-- Risk management on pattern change
//Defer,           //-- Defer to contrarian manager

//    RoleType     contrarian = (RoleType)Action(Role,InAction,InContrarian);
//    StrategyType strategy   = Wait;
    
    if (Trigger)
      switch (Role)
      {
        case Buyer:   if (t[NewTick])
                        if (t.Linear().Head<Close[0])
                          manager[Role].Strategy      = (StrategyType)BoolToInt(order[OP_SELL].Lots>0,Manage);
                        else
                          manager[Role].Strategy      = (StrategyType)BoolToInt(IsEqual(t.Linear().Direction,t.Range().Direction),Build);
                      //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
                      break;

        case Seller:  if (t[NewTick])
                        if (t.Linear().Head>Close[0])
                          manager[Role].Strategy      = (StrategyType)BoolToInt(order[OP_SELL].Lots>0,Manage);
                        else
                          manager[Role].Strategy      = (StrategyType)BoolToInt(IsEqual(t.Linear().Direction,t.Range().Direction),Build);
                     //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
      }
  }


//+------------------------------------------------------------------+
//| SetRiskStrategy - Set Strategy for supplied Role                 |
//+------------------------------------------------------------------+
void SetRiskStrategy(RoleType Role, bool Trigger)
  {
//Opener,          //-- New Position (Opener)
//Build,           //-- Increase Position
//Cover,           //-- Aggressive balancing on excessive drawdown
//Capture,         //-- Contrarian profit protection
//Mitigate,        //-- Risk management on pattern change
//Defer,           //-- Defer to contrarian manager
//Wait             //-- Hold, wait for signal
    if (Trigger)
      switch (Role)
      {
        case Buyer:   if (IsEqual(order.Entry(Role).Count,0))
                        if (signal.Crest>0.00)
                        {}
                      //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
                      break;

        case Seller:  if (IsEqual(order.Entry(Role).Count,0))
                       if (signal.Crest>0.00)
                       {}
                     //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
      }
  }

//+------------------------------------------------------------------+
//| ManageLead - Lead Manager order processor                        |
//+------------------------------------------------------------------+
void ManageLead(RoleType Role)
  {
    //-- Position checks
    SetLeadStrategy(Role,signal.Crest>0||signal.Trough>0);
    
    //-- Free Zone/Order Entry
    if (order.Free(Role)>order.Split(Role)||IsEqual(order.Entry(Role).Count,0))
    {
      OrderRequest  request  = order.BlankRequest(EnumToString(Role));

      request.Action         = Role;
      request.Requestor      = "Auto ("+request.Requestor+")";

      switch (Role)
      {
        case Buyer:          if (t[NewTick])
                               manager[Role].Trigger  = false;
                             break;

        case Seller:         if (t[NewTick])
                               manager[Role].Trigger  = false;
                               
                             switch (manager[Role].Strategy)
                             {
                               case Build:   if (t[NewHigh])
                                             {
                                               request.Type    = OP_SELL;
                                               request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
                                               request.Memo    = "Contrarian (In-Trend)";
                                             }
                                             break;

                               case Manage:  if (t[NewLow])
                                             {
                                               request.Type    = OP_SELL;
                                               request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
                                               request.Memo    = "Contrarian (In-Trend)";
                                             }
                                             break;
                             }
                             break;
      }

      if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
        if (order.Submitted(request))
          Print(order.RequestStr(request));
    }

    order.ExecuteOrders(Role,manager[Role].Hold);
  }

//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(RoleType Role)
  {
    SetRiskStrategy(Role,IsEqual(manager[Action(Role,InAction,InContrarian)].Strategy,Defer));
    order.ExecuteOrders(Role);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Only occurs during testing
    if (t.Count(Segments)<inpPeriods)
      return;

    //-- Handle Active Management
    if (IsBetween(master.Lead,Buyer,Seller))
    {
      ManageLead(master.Lead);
      ManageRisk((RoleType)Action(master.Lead,InAction,InContrarian));
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
//    ProcessComFile(order);
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
      order.SetFundLimits(action,inpMinTarget,inpMinProfit,inpLotSize);
      order.SetRiskLimits(action,inpMaxRisk,inpLotFactor,inpMaxMargin);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
    }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    NewPriceLabel("sigHi");
    NewPriceLabel("sigLo");
    
    s = new CSession(Daily,0,23,0,false,(FractalType)BoolToInt(inpFractalModel==Session,inpShowFractal,NoValue));
    t = new CTickMA(inpPeriods,inpAgg,(FractalType)BoolToInt(inpFractalModel==TickMA,inpShowFractal,NoValue));

    OrderConfig();
    ManualInit(inpComFile);

    //int offset=0;
    //for (uchar chr=133;chr<220;chr++)
    //{
    //  NewLabel("char"+(string)chr,"",200,4+(24*offset++),clrYellow);
    //  UpdateLabel("char"+(string)chr,CharToStr(chr),clrYellow,24,"Consolas");
    //}
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete order;
    delete t;
    delete s;
  }