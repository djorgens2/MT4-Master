//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                         Raw Order-Integration EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "2.02"
#property strict

#define debug true

#include <Class/Order.mqh>
#include <Class/Session.mqh>
#include <Class/TickMA.mqh>

//-- Class defs
COrder                *order;
CSession              *s[SessionTypes];
CTickMA               *t;


#include <ordman.mqh>

  //--- Fractal Model
  enum IndicatorType
       {
         Session,   // Session
         TickMA     // TickMA
       };


  //--- Show Fractal Event Flag
  enum ShowType
       {
         stNone   = NoValue,   // None
         stOrigin = Origin,    // Origin
         stTrend  = Trend,     // Trend
         stTerm   = Term       // Term
       };


  //--- EA Config
  input string           appHeader           = "";            // +--- Application Config ---+
  input BrokerModel      inpBrokerModel      = Discount;      // Broker Model
  input string           inpComFile          = "manual.csv";  // Command File
  input YesNoType        inpShowComments     = No;            // Show Comments
  input int              inpIndSNVersion     = 2;             // Control Panel Version

  //--- Order Config
  input string           ordHeader           = "";            // +------ Order Options ------+
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

  //--- Regression Config
  input string           regrHeader          = "";            // +--- Regression Config ----+
  input int              inpPeriods          = 80;            // Retention
  input double           inpAgg              = 2.5;           // Tick Aggregation
  input ShowType         inpShowType         = stNone;        // Show TickMA Fractal Events


  //--- Session Config
  input string           sessHeader          = "";            // +--- Session Config -------+
  input int              inpAsiaOpen         = 1;             // Asia Session Opening Hour
  input int              inpAsiaClose        = 10;            // Asia Session Closing Hour
  input int              inpEuropeOpen       = 8;             // Europe Session Opening Hour
  input int              inpEuropeClose      = 18;            // Europe Session Closing Hour
  input int              inpUSOpen           = 14;            // US Session Opening Hour
  input int              inpUSClose          = 23;            // US Session Closing Hour
  input int              inpGMTOffset        = 0;             // Offset from GMT+3


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
            int              Count;             //-- Pivot Count within inpPeriods
            double           Pivot[];           //-- Pivot prices
            bool             Trigger;           //-- Pivot Change trigger
          };


  //-- Signals (Events) requiring Manager Action (Response)
  struct  SignalRec
          {
            IndicatorType    Source;
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
            FractalState     EntryState;
            bool             ActiveEvent;
          };


  //-- Master Control Operationals
  struct  MasterRec
          {
            RoleType         Lead;              //-- Process Manager (Owner|Lead)
            RoleType         OnCall;            //-- Manager on deck while unassigned
          };


  //-- Data Collections
  MasterRec              master;
  SignalRec              signal;
  ManagerRec             manager[RoleTypes];    //-- Manager Detail Data
  

  //-- Internal EA Configuration
  string                 indSN               = "CPanel-v"+(string)inpIndSNVersion;
  string                 objectstr           = "[man-v2]";
  int                    fhandle;


//+------------------------------------------------------------------+
//| DebugPrint - Prints debug/event data                             |
//+------------------------------------------------------------------+
void DebugPrint(void)
  {
    if (s[Daily].Pivot(Trend).Event==NewFibonacci)
    {
      Flag("s.Pivot-NewFiibo",Color(Direction(s[Daily].Pivot(Trend).Lead,InAction)));
//      if (debug) Pause("New Fibonacci Pivot","Pivot Test");
    }

    if (debug)
    {
      if (signal.Alert>NoAlert)
      {
        string ftext  = DoubleToString(Close[0],_Digits);
        
        Append(ftext,BoolToStr(signal.Trigger,"Fired","Idle"),"|");
        Append(ftext,BoolToStr(s[Daily].ActiveEvent(),EnumToString(s[Daily].MaxAlert()),"Idle"),"|");
        Append(ftext,BoolToStr(t.ActiveEvent(),EnumToString(t.MaxAlert()),"Idle"),"|");
        Append(ftext,TimeToStr(TimeCurrent()),"|");
        Append(ftext,EnumToString(signal.Alert),"|");
        Append(ftext,BoolToStr(signal.EntryState>NoValue,EnumToString(signal.EntryState),"------"),"|");

        for (EventType type=1;type<EventTypes;type++)
          switch (type)
          {
            case NewSegment: Append(ftext,EnumToString(fmax(s[Daily].Alert(type),t.Alert(type))),"|");
                             Append(ftext,BoolToStr(t.Logged(NewLead,Nominal),"Nominal",
                                         BoolToStr(t.Logged(NewLead,Warning),"Warning","NoAlert")),"|");
                             break;
            case NewChannel: Append(ftext,EnumToString(fmax(s[Daily].Alert(type),t.Alert(type))),"|");
                             Append(ftext,BoolToStr(t.Logged(NewLead,Notify),"Notify","NoAlert"),"|");
                             break;
            case Exception:  Append(ftext,BoolToStr(IsEqual(signal.Event,Exception),"Critical","No Alert"),"|");
                             break;
            default:         Append(ftext,EnumToString(fmax(s[Daily].Alert(type),t.Alert(type))),"|");
          }

        FileWrite(fhandle,ftext);
      }

      if (signal.EntryState>NoValue)
      {
        UpdateDirection("pvMasterLead",Direction(signal.Bias,InAction),Color(Direction(signal.Bias,InAction)),24);

        if (s[Daily][NewLead])
          //Flag(EnumToString(signal.Bias),Color(Direction(signal.Bias,InAction)));
          UpdatePriceLabel("pvMajorLead"+BoolToStr(signal.Bias==Buyer,"Long","Short"),Close[0],Color(Direction(signal.Bias,InAction)));
        else
        if (t[NewLead])
//          Flag(EnumToString(signal.Bias),Color(Direction(signal.Bias,InAction),IN_DARK_DIR));
          UpdatePriceLabel("pvMinorLead"+BoolToStr(signal.Bias==Buyer,"Long","Short"),Close[0],Color(Direction(signal.Bias,InAction),IN_DARK_DIR));
        else // Flag("NoLead",clrYellow);
          UpdatePriceLabel("pvLeadFibonacci",Close[0],clrYellow);
      }
    }
  }

//+------------------------------------------------------------------+
//| Clear Remove arrows/flags/Labels based on supplied ObjectName    |
//+------------------------------------------------------------------+
void Clear(string Key)
  {
    //-- Clean Open Chart Objects
    int fObject             = 0;
    
    while (fObject<ObjectsTotal())
      if (InStr(ObjectName(fObject),Key))
        ObjectDelete(ObjectName(fObject));
      else fObject++;
  }


//+------------------------------------------------------------------+
//| AlertColor Set Color for Supplied Alert for flags, text, et al.  |
//+------------------------------------------------------------------+
color AlertColor(AlertType Type)
  {
    switch (Type)
    {
      case NoAlert:  return clrNONE;
      case Notify:   return clrForestGreen;
      case Nominal:  return clrLawnGreen;
      case Warning:  return clrYellow;
      case Minor:    return clrSandyBrown;
      case Major:    return clrChocolate;
      case Critical: return clrRed;
    }

    return clrWhite;
  }


//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text     = "";
    static int         winid     = NoValue;
    
    //-- Update Control Panel (Application)
    if (IsChanged(winid,ChartWindowFind(0,indSN)))
    {
      //-- Update Panel
      order.ConsoleAlert("Connected to "+indSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));
      UpdateLabel("lbvAC-File",inpComFile,clrGoldenrod);
      
      //-- Hide non-Panel elements
      UpdateLabel("pvBalance","",clrNONE,1);
      UpdateLabel("pvProfitLoss","",clrNONE,1);
      UpdateLabel("pvNetEquity","",clrNONE,1);
      UpdateLabel("pvEquity","",clrNONE,1);
      UpdateLabel("pvMargin","",clrNONE,1);

    }

    if (IsEqual(winid,NoValue))
    {
      UpdateLabel("pvBalance","$"+dollar(order.Metrics().Balance,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvProfitLoss","$"+dollar(order.Metrics().Equity,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvNetEquity","$"+dollar(order.Metrics().EquityBalance,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvEquity",DoubleToStr(order.Metrics().EquityClosed*100,1)+"%",Color(order[Net].Value),14,"Consolas");
      UpdateLabel("pvMargin",DoubleToString(order.Metrics().Margin*100,1)+"%",Color(order[Net].Lots),14,"Consolas");

      Comment(order.QueueStr()+order.OrderStr());
    }
  }


//+------------------------------------------------------------------+
//| ManagerChanged - Returns true on change in Operations Manager    |
//+------------------------------------------------------------------+
bool ManagerChanged(RoleType &Incumbent, RoleType Incoming)
  {
    if (IsEqual(Incoming,Incumbent))
      return false;
      
    Incumbent       = Incoming;
    UpdateLabel("pvManager",EnumToString(Incoming),Color(Direction(Incoming,InAction)));
//    Pause("New Manager: "+EnumToString(Incoming),"New Manager Check");
//    Flag("New Manager: "+EnumToString(Incoming),(color)BoolToInt(Incoming==Buyer,clrYellow,clrMagenta));
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
void UpdateSignal(IndicatorType Source, CFractal &Signal)
  {
    if (Signal.ActiveEvent())
    {
      signal.Event            = Exception;

      if (Signal.Event(NewFractal))
      {
        signal.Source         = Source;
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
        if (Signal.Event(CrossCheck))
                                                  signal.Event = CrossCheck;
        else
        if (Signal.Event(NewBias))                signal.Event = NewBias;
        else
        if (Signal.Event(NewExpansion))           signal.Event = NewExpansion;

        else                                      signal.Event = NewBoundary;
      else
        if (Signal.Event(CrossCheck))
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
        
      if (Signal[NewPullback])                    signal.EntryState = Pullback;
      if (Signal[NewRally])                       signal.EntryState = Rally;
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
      
    UpdatePriceLabel("sigHi",signal.Pivot.High,clrLawnGreen,-6);
    UpdatePriceLabel("sigLo",signal.Pivot.Low,clrRed,-6);
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
    signal.ActiveEvent       = t.ActiveEvent()||s[Daily].ActiveEvent();

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
    if (ManagerChanged(master.Lead,Manager(s[Daily][Trend])))
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
//    order.Update(BoolToDouble(inpBaseCurrency=="XRPUSD",iClose(inpBaseCurrency,0,0),1));
      order.Update();

    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();

    t.Update();
    
    //-- Update Signals
    signal.Event              = NoEvent;
    signal.Alert              = fmax(s[Daily].MaxAlert(),t.MaxAlert());
    signal.Event              = fmax(s[Daily].MaxEvent(),t.MaxEvent());
    signal.Trigger            = false;
    signal.EntryState         = NoValue;

    UpdateSignal(Session,s[Daily]);
    UpdateSignal(TickMA,t);
    UpdateSignal();
    UpdateManager();

    DebugPrint();
  }

//+------------------------------------------------------------------+
//| SetStrategy - Set Strategy for supplied Role                     |
//+------------------------------------------------------------------+
void SetStrategy(RoleType Role)
  {

    RoleType     contrarian = (RoleType)Action(Role,InAction,InContrarian);
    StrategyType strategy   = Wait;

//Wait             //-- Hold, wait for signal
//Manage,          //-- Manage Margin; Seek Profit
//Build,           //-- Increase Position
//Cover,           //-- Aggressive balancing on excessive drawdown
//Capture,         //-- Contrarian profit protection
//Mitigate,        //-- Risk management on pattern change
//Defer,           //-- Defer to contrarian manager
   
       switch (Role)
       {
         case Buyer:   if (signal.EntryState==Pullback)
                       {
                         if (t.Linear().Head<Close[0])
                           manager[Role].Strategy      = (StrategyType)BoolToInt(order[OP_SELL].Lots>0,Manage);
                         else
                           manager[Role].Strategy      = (StrategyType)BoolToInt(IsEqual(t.Linear().Direction,t.Range().Direction),Build);
                       }

                       if (signal.EntryState==Rally)
                       {
                       }
                       //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
                       break;

         case Seller:  if (signal.EntryState==Rally)
                         if (t.Linear().Head>Close[0])
                           manager[Role].Strategy      = (StrategyType)BoolToInt(order[OP_SELL].Lots>0,Manage);
                         else
                           manager[Role].Strategy      = (StrategyType)BoolToInt(IsEqual(t.Linear().Direction,t.Range().Direction),Build);
                      //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
       }

  }


//+------------------------------------------------------------------+
//| ManageFund - Fund Manager order processor                        |
//+------------------------------------------------------------------+
void ManageFund(RoleType Role)
  {
    //-- Position checks
    SetStrategy(Role);
    
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

    order.ProcessOrders(Role);
  }


//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(RoleType Role)
  {
    SetStrategy(Role);
    order.ProcessOrders(Role);
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
     ManageRisk((RoleType)Action(master.Lead,InAction,InContrarian));
    }
   else

   //-- Handle Unassigned Manager
   {
     ManageRisk(Buyer);
     ManageRisk(Seller);
   }

    order.ProcessRequests();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    UpdateMaster();

    ProcessComFile();

    Execute();

    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| ScreenConfig Sets up display alternative in-lieu of CPanel       |
//+------------------------------------------------------------------+
void ScreenConfig(void)
  {
    NewLabel("pvBalance","",80,10,clrLightGray,SCREEN_UR);
    NewLabel("pvProfitLoss","",80,26,clrLightGray,SCREEN_UR);
    NewLabel("pvNetEquity","",80,42,clrLightGray,SCREEN_UR);
    NewLabel("pvEquity","",10,10,clrLightGray,SCREEN_UR);
    NewLabel("pvMargin","",10,42,clrLightGray,SCREEN_UR);
    NewLabel("pvMasterLead","",5,5,clrNONE,SCREEN_LL);
    NewLabel("pvManager","",5,40,clrNONE,SCREEN_LL);
    
    NewPriceLabel("pvMinorLeadLong");
    NewPriceLabel("pvMajorLeadLong");
    NewPriceLabel("pvMinorLeadShort");
    NewPriceLabel("pvMajorLeadShort");
    NewPriceLabel("pvLeadFibonacci");
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
      order.SetDefaultStop(action,0.00,inpDefaultStop,false);
      order.SetDefaultTarget(action,0.00,inpDefaultTarget,false);
    }
  }

//+------------------------------------------------------------------+
//| SessionConfig Session class initialization function              |
//+------------------------------------------------------------------+
void SessionConfig(void)
  {
    //-- Initialize TickMA
    t                    = new CTickMA(inpPeriods,inpAgg,(FractalType)inpShowType);

    //-- Initialize Session
    s[Daily]             = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]              = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]            = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]                = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
  }

//+------------------------------------------------------------------+
//| SignalConfig Signal setup and config function                    |
//+------------------------------------------------------------------+
void SignalConfig(void)
  {
    NewPriceLabel("sigHi");
    NewPriceLabel("sigLo");

    ArrayResize(signal.Crest.Pivot,inpPeriods);
    ArrayResize(signal.Trough.Pivot,inpPeriods);
    ArrayInitialize(signal.Crest.Pivot,0.00);
    ArrayInitialize(signal.Trough.Pivot,0.00);
  }

//+------------------------------------------------------------------+
//| InitMaster - Sets the startup values on the Manager Master       |
//+------------------------------------------------------------------+
void InitMaster(void)
  {
    master.Lead       = Unassigned;
    master.OnCall     = Unassigned;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ScreenConfig();
    OrderConfig();
    SessionConfig();
    SignalConfig();
    ManualConfig(inpComFile);

    InitMaster();

    string price="-20p*";
    
    if (debug)
      fhandle = FileOpen("debug-man-v2.csv",FILE_CSV|FILE_WRITE|FILE_ANSI);
    
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

    if (debug)
      FileClose(fhandle);
  }
