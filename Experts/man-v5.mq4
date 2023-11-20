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


//--- Regression Config
input string           regrHeader          = "";           // +--- Regression Config ----+
input int              inpPeriods          = 80;           // Retention
input double           inpAgg              = 2.5;          // Tick Aggregation


//---- Session Config
input string           sessHeader         = "";            // +----- Session Hours ------+
input int              inpAsiaOpen        = 1;               // Asia Session Opening Hour
input int              inpAsiaClose       = 10;              // Asia Session Closing Hour
input int              inpEuropeOpen      = 8;               // Europe Session Opening Hour
input int              inpEuropeClose     = 18;              // Europe Session Closing Hour
input int              inpUSOpen          = 14;              // US Session Opening Hour
input int              inpUSClose         = 23;              // US Session Closing Hour


//---- Order Config
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


  //-- Manager Config by Role
  struct  ManagerRec
          {
            StrategyType     Strategy;             //-- Role Responsibility/Strategy
            OrderSummary     Entry;                //-- Role Entry Zone Summary
            double           Equity[MeasureTypes]; //-- Fund Stats
            double           DCA;                  //-- Role DCA
            double           TakeProfit;           //-- Take Profit
            double           StopLoss;             //-- Stop Loss
            bool             Hold;                 //-- Hold Role Profit
            bool             Trigger;              //-- Trigger state
          };


  //-- Pivot Metrics for Position Management
  struct  PivotDetail
          {
            int              Head;              //-- Lead Pivot Node
            int              Count;             //-- Pivot Count
            double           Pivot[];           //-- Pivot prices
            bool             Trigger;           //-- Pivot Change trigger
          };


  //-- Signals (Events) requiring Manager Action (Response)
  struct  SignalRec
          {
            FractalModel     Source;
            FractalType      Type;
            FractalState     State;
            EventType        Event;
            AlertType        Alert;
            int              Direction;
            RoleType         Lead;
            RoleType         Bias;
            PivotRec         Pivot;
            PivotDetail      Crest;
            PivotDetail      Trough;
            bool             Trigger;
          };


  //-- Master Control Operationals
  struct  MasterRec
          {
            RoleType         Lead;                  //-- Process Manager (Owner|Lead)
            RoleType         OnCall;                //-- Manager on deck while unassigned
          };


  //-- Data Collections
  MasterRec              master;
  SignalRec              signal;
  ManagerRec             manager[RoleTypes];  //-- Manager Detail Data
  
  //-- Class defs
  COrder                *order;
  CTickMA               *t;
  CSession              *s[SessionTypes];

  //-- Operational Variables
  int    winid         = NoValue;

//+------------------------------------------------------------------+
//| DebugPrint - Prints debug/event data                             |
//+------------------------------------------------------------------+
void DebugPrint(void)
  {
    if (debug)
    {
      string    text   = "";

      if (signal.Alert>NoAlert)
      {
        Append(text,"|"+BoolToStr(signal.Trigger,"Fired","Idle"));
        Append(text,BoolToStr(s[Daily].ActiveEvent(),EnumToString(s[Daily].MaxAlert()),"Idle"),"|");
        Append(text,BoolToStr(t.ActiveEvent(),EnumToString(t.MaxAlert()),"Idle"),"|");
        Append(text,TimeToStr(TimeCurrent()),"|");
        Append(text,EnumToString(signal.Alert),"|");

        for (EventType type=1;type<EventTypes;type++)
        {
          if (type<CrossCheck||type>Exception)
            Append(text,EnumToString(fmax(s[Daily].Alert(type),t.Alert(type))),"|");

          switch (type)
          {
            case NewSegment: Append(text,BoolToStr(t.Logged(NewLead,Nominal),"Nominal",
                                         BoolToStr(t.Logged(NewLead,Warning),"Warning","No Alert")),"|");
                             break;
            case NewChannel: Append(text,BoolToStr(t.Logged(NewLead,Notify),"Notify","No Alert"),"|");
                             break;
            case CrossCheck: Append(text,BoolToStr(IsEqual(signal.Event,CrossCheck),"Notify","No Alert"),"|");
                             break;
            case Exception:  Append(text,BoolToStr(IsEqual(signal.Event,Exception),"Critical","No Alert"),"|");
                             break;
          }
        }

        Print(text);
      }
    }
  }


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
        if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s[type].Event(NewTerm)||s[type].Event(NewHour))
        {
          UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[type][Term].Direction,IN_DARK_DIR));
          UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s[type].IsOpen(),clrYellow,clrBoxOff));
        }

      //-- Session Box
      UpdateDirection("tmaSessionTrendDir"+(string)winid,s[Daily][Trend].Direction,Color(s[Daily][Trend].Direction),16);
      UpdateDirection("tmaSessionTermDir"+(string)winid,s[Daily][Term].Direction,Color(s[Daily][Term].Direction),32);
      UpdateLabel("tmaSessionState"+(string)winid,center(EnumToString(s[Daily][Trend].State),18),Color(s[Daily][Trend].Direction),16);
      UpdateLabel("tmaSessionFractalState"+(string)winid,center(proper(ActionText(s[Daily][ActiveSession].Lead))+" "+
                    BoolToStr(IsEqual(s[Daily][ActiveSession].Lead,s[Daily][ActiveSession].Bias),"Hold","Hedge"),30),
                    Color(Direction(s[Daily][ActiveSession].Lead,InAction)),12);
      UpdateDirection("tmaSessionPivotLead"+(string)winid,Direction(s[Daily][ActiveSession].Lead,InAction),
                    Color(Direction(s[Daily][ActiveSession].Lead,InAction)),18);
      UpdateDirection("tmaSessionPivotBias"+(string)winid,Direction(s[Daily][ActiveSession].Bias,InAction),
                    Color(Direction(s[Daily][ActiveSession].Bias,InAction)),18);


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
//    Pause("New Manager: "+EnumToString(Incoming),"New Manager Check");

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
//| Manager - Returns the manager for the supplied Fractal           |
//+------------------------------------------------------------------+
RoleType Manager(SessionRec &Session)
  {
    return (RoleType)BoolToInt(IsEqual(Session.Bias,Session.Lead),Session.Lead,Unassigned);
  }


//+------------------------------------------------------------------+
//| UpdateSignal - Updates Fractal data from Supplied Fractal        |
//+------------------------------------------------------------------+
void UpdateSignal(FractalModel Model, CFractal &Signal)
  {
    if (Signal.ActiveEvent())
    {
      signal.Event            = Exception;

      if (Signal.Event(NewFractal))
      {
        signal.Source         = Model;
        signal.Type           = (FractalType)BoolToInt(Signal.Event(NewFractal,Critical),Origin,
                                             BoolToInt(Signal.Event(NewFractal,Major),Trend,Term));
        signal.State          = Reversal;
        signal.Event          = NewFractal;
        signal.Direction      = Signal[signal.Type].Direction;
        signal.Pivot          = Signal[signal.Type].Pivot;
        signal.Trigger        = true;
      }
      else
      if (Signal.Event(NewFibonacci))
      {
        signal.Type           = (FractalType)BoolToInt(Signal.Event(NewFibonacci,Critical),Origin,
                                             BoolToInt(Signal.Event(NewFibonacci,Major),Trend,Term));
        signal.State          = Signal[signal.Type].State;
        signal.Event          = NewFibonacci;
        signal.Trigger        = true;
      }
      else
      if (Signal.Event(NewLead))
      {
        signal.Event          = NewLead;
        signal.Trigger        = true;
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

    if (signal.Trigger)
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
    double crest             = t.SMA().High[0];
    double trough            = t.SMA().Low[0];

    double chead             = signal.Crest.Pivot[signal.Crest.Head];
    double thead             = signal.Trough.Pivot[signal.Trough.Head];

    int    cflat             = 0;
    int    tflat             = 0;

    signal.Crest.Trigger     = false;
    signal.Trough.Trigger    = false;

    signal.Crest.Count       = 0;
    signal.Trough.Count      = 0;

    ArrayInitialize(signal.Crest.Pivot,0.00);
    ArrayInitialize(signal.Trough.Pivot,0.00);

    for (int node=2;node<inpPeriods-1;node++)
    {
      if (IsHigher(t.SMA().High[node],crest))
        if (t.SMA().High[node]>t.SMA().High[node-1])
        {
          if (t.SMA().High[node]>t.SMA().High[node+1])
          {
            signal.Crest.Pivot[node]     = crest;
            signal.Crest.Head            = BoolToInt(IsEqual(signal.Crest.Count++,0),node,signal.Crest.Head);
          }

          cflat              = BoolToInt(IsEqual(t.SMA().High[node],t.SMA().High[node+1]),node);
        }
        
      if (cflat>0)
        if (t.SMA().High[node]<t.SMA().High[cflat])
          if (IsChanged(signal.Crest.Pivot[cflat],crest))
            signal.Crest.Count++;

      if (IsLower(t.SMA().Low[node],trough))
        if (t.SMA().Low[node]<t.SMA().Low[node-1])
        {
          if (t.SMA().Low[node]<t.SMA().Low[node+1])
          {
            signal.Trough.Pivot[node]    = trough;
            signal.Trough.Head           = BoolToInt(IsEqual(signal.Trough.Count++,0),node,signal.Trough.Head);
          }

          tflat              = BoolToInt(IsEqual(t.SMA().Low[node],t.SMA().Low[node+1]),node);
        }

      if (tflat>0)
        if (t.SMA().Low[node]>t.SMA().Low[tflat])
          if (IsChanged(signal.Trough.Pivot[tflat],trough))
            signal.Trough.Count++;
    }

    signal.Crest.Trigger     = IsChanged(chead,signal.Crest.Head);
    signal.Trough.Trigger    = IsChanged(thead,signal.Trough.Head);
  }


//+------------------------------------------------------------------+
//| UpdateManager - Updates Manager data from Supplied Fractal       |
//+------------------------------------------------------------------+
void UpdateManager(void)
  {
    //-- Reset Manager Targets
//    if (NewManager(master.Lead,Manager(s[Daily][ActiveSession])))
    if (NewManager(master.Lead,Manager(t[Term])))
      if (master.Lead>Unassigned)
        ArrayInitialize(manager[master.Lead].Equity,order[master.Lead].Equity);

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      manager[role].DCA           = order.DCA(role);
      manager[role].Entry         = order.Entry(role);
      manager[role].Trigger       = signal.Trigger||manager[role].Trigger;
      manager[role].Equity[Now]   = order[role].Equity;
      manager[role].Equity[Min]   = fmin(order[role].Equity,manager[role].Equity[Min]);
      manager[role].Equity[Max]   = fmax(order[role].Equity,manager[role].Equity[Max]);
    }
  }
  

//+------------------------------------------------------------------+
//| UpdateMaster - Updates Master/Manager data                       |
//+------------------------------------------------------------------+
void UpdateMaster(void)
  {
    //-- Update Classes
    order.Update(BoolToDouble(inpBaseCurrency=="XRPUSD",iClose(inpBaseCurrency,0,0),1));

    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();

    t.Update();
    
    //-- Update Signals
    signal.Event              = NoEvent;
    signal.Alert              = fmax(s[Daily].MaxAlert(),t.MaxAlert());
    signal.Trigger            = false;

    UpdateSignal(Session,s[Daily]);
    UpdateSignal(TickMA,t);
    UpdateSignal();
    UpdateManager();

//if (t[NewLead])
//  Pause(t.EventLogStr(),"Display EventLog");
    DebugPrint();
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
//+--------------------------------------------------------- ---------+
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
                        if (signal.Crest.Trigger)
                        {}
                      //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
                      break;

        case Seller:  if (IsEqual(order.Entry(Role).Count,0))
                       if (signal.Crest.Trigger)
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
    SetLeadStrategy(Role,signal.Crest.Trigger||signal.Trough.Trigger);
    
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
                               case Build:   if (t.Event(NewHigh,Nominal))
                                             {
                                               request.Type    = OP_SELL;
                                               request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
                                               request.Memo    = "Contrarian (In-Trend)";
                                             }
                                             break;

                               //case Manage:  if (t[NewLow])
                               //              {
                               //                request.Type    = OP_SELL;
                               //                request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
                               //                request.Memo    = "Contrarian (In-Trend)";
                               //              }
                               //              break;
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
//| ManagePosition - Manage order positioning during consolidations  |
//+------------------------------------------------------------------+
void ManagePosition(RoleType Role)
  {
    if (order[Net].Count>0)
    {    
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
                     
                               //switch (manager[Role].Strategy)
                               //{
                               //  case Build:   if (t.Event(NewHigh,Nominal))
                               //                {
                               //                  request.Type    = OP_SELL;
                               //                  request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
                               //                  request.Memo    = "Contrarian (In-Trend)";
                               //                }
                               //                break;
                               //}
                               break;
        }

        if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
          if (order.Submitted(request))
            Print(order.RequestStr(request));
      }

      order.ExecuteOrders(Role,manager[Role].Hold);
    }
  }


//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Handle Active Management
    if (IsBetween(master.Lead,Buyer,Seller))
    {
      ManageLead(master.Lead);
      ManageRisk((RoleType)Action(master.Lead,InAction,InContrarian));
    }
    else

    //-- Handle Unassigned Manager
    {
      ManagePosition(Buyer);
      ManagePosition(Seller);
    }

    order.ExecuteRequests();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    ProcessComFile(order);
    UpdateMaster();

//    Execute();

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
    
    s[Daily]   = new CSession(Daily,0,23,0,false,(FractalType)BoolToInt(inpFractalModel==Session,inpShowFractal,NoValue));
    s[Asia]    = new CSession(Asia,inpAsiaOpen,inpAsiaClose,0);
    s[Europe]  = new CSession(Europe,inpEuropeOpen,inpEuropeClose,0);
    s[US]      = new CSession(US,inpUSOpen,inpUSClose,0);

    t = new CTickMA(inpPeriods,inpAgg,(FractalType)BoolToInt(inpFractalModel==TickMA,inpShowFractal,NoValue));

    OrderConfig();
    ManualInit(inpComFile);

    ArrayResize(signal.Crest.Pivot,inpPeriods);
    ArrayResize(signal.Trough.Pivot,inpPeriods);
    ArrayInitialize(signal.Crest.Pivot,0.00);
    ArrayInitialize(signal.Trough.Pivot,0.00);

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
    
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete s[type];
  }