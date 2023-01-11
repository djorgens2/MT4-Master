//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class/TickMA.mqh>
#include <Class/Order.mqh>
#include <Class/Session.mqh>

enum PivotType
     {
       Buy,
       Sell,
       Wait,
       PivotTypes
     };

enum StrategyType
     {
       Extend,
       Contrarian,
       Mitigation,
       Hedge
     };

//--- Configuration
input string        appHeader          = "";          // +--- Application Config ---+
input BrokerModel   inpBrokerModel     = Discount;    // Broker Model
input double        inpZoneStep        = 2.5;         // Zone Step (pips)
input double        inpMaxZoneMargin   = 5.0;         // Max Zone Margin


//--- Regression parameters
input string        regrHeader         = "";          // +--- Regression Config ---+
input int           inpPeriods         = 80;          // Retention
input int           inpDegree          = 6;           // Poiy Regression Degree
input double        inpAgg             = 2.5;         // Tick Aggregation


//--- Session Inputs
input SessionType    inpShowFractal    = Daily;        // Display Session Fractal
input int            inpAsiaOpen       = 1;            // Asia Session Opening Hour
input int            inpAsiaClose      = 10;           // Asia Session Closing Hour
input int            inpEuropeOpen     = 8;            // Europe Session Opening Hour
input int            inpEuropeClose    = 18;           // Europe Session Closing Hour
input int            inpUSOpen         = 14;           // US Session Opening Hour
input int            inpUSClose        = 23;           // US Session Closing Hour
input int            inpGMTOffset      = 0;            // Offset from GMT+3

  struct MasterControl
  {
    int             Manager;
    int             Lead;
    int             Direction;
    int             Bias;
    PivotType       Active;
    FractalState    State;
    bool            Broken;
    double          Pivot[PivotTypes];
  };
  
  CTickMA          *t                  = new CTickMA(inpPeriods,inpDegree,inpAgg);
  COrder           *order              = new COrder(inpBrokerModel,Hold,Hold);
  CSession         *s[SessionTypes];

  MasterControl     master;

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    const  color  pivotcolor[PivotTypes]  = {clrYellow,clrRed,clrDarkGray};
    string        text                    = "";

    for (PivotType type=0;type<PivotTypes;type++)
      UpdateLine("lnPivot:"+EnumToString(type),master.Pivot[type],STYLE_SOLID,pivotcolor[type]);

    for (SessionType session=Daily;session<SessionTypes;session++)
      if (s[session].ActiveEvent())
        Append(text,EnumToString(session)+" "+s[session].ActiveEventStr(),"\n\n");

    Comment(s[inpShowFractal].FractalStr()+"\n\n"+text);
  }

//+------------------------------------------------------------------+
//| NewPivot - Detects/Updates Active Pivot Type                     |
//+------------------------------------------------------------------+
bool NewPivot(PivotType &Type, int Bias)
  {
    if (IsEqual(Type,BoolToInt(IsEqual(Bias,NoBias),Wait,Bias)))
      return false;
      
    Type              = (PivotType)BoolToInt(IsEqual(Bias,NoBias),Wait,Bias);

    return true;
  }

//+------------------------------------------------------------------+
//| UpdateTickMA - Updates TickMA data                               |
//+------------------------------------------------------------------+
void UpdateTickMA(void)
  {
    FractalState state        = NoState;
    bool         change       = false;
    static int   bias         = NoBias;

    t.Update();

    if (NewPivot(master.Active,t.Linear().Close.Bias))
    {
      if (NewDirection(master.Direction,Direction(t.Linear().Close.Bias,InAction)))
        master.Broken         = IsEqual(master.State,Retrace);

      state                   = (FractalState)BoolToInt(IsEqual(master.Active,NoAction),Retrace,
                                              BoolToInt(t[NewLow],Pullback,
                                              BoolToInt(t[NewHigh],Rally)));

      master.Pivot[master.Active]  = Close[0];

      //-- Active Bias (Checkpoint Bias Changes - useful but analysis needed)
      if (NewAction(master.Bias,t.Linear().Close.Bias));
//        Flag("[tm]Active",BoolToInt(IsEqual(t.Linear().Bias,Buy),clrSteelBlue,clrGoldenrod));

      Flag("[tm]State",Color(Direction(t.Linear().Close.Bias,InAction),IN_CHART_DIR));
      Arrow("[tm]State",Direction(t.Linear().Close.Bias,InAction),
                        Color(Direction(t.Linear().Close.Bias,InAction),IN_CHART_DIR));
    }

    //if (t[NewTick])
    //if (IsEqual(t.Poly().Bias,t.SMA().Bias))
    //  if (IsChanged(bias,t.Poly().Bias))
    //  Flag("[tm]Bias[nano]",Color(Direction(t.Poly().Bias,InAction),IN_CHART_DIR));

  //      Pause("Nano Bias Change","BiasChange()");

    //-- Confirmation test
    if (IsEqual(t.Linear().Close.Bias,t.Linear().Open.Bias))
      if (NewAction(master.Manager,t.Linear().Bias))
      {
        change              = true;
//        Flag("[tm]Confirm",BoolToInt(IsEqual(master.Manager,OP_BUY),clrLawnGreen,clrMagenta));
      }

      //-- Caution test #1
      if (IsEqual(t.Linear().Event,NewBias))
      {
//        state                 = Reversal;
//        tick[Trend]           = t.Linear().Close.Bias;

//        if (!change)
//          Flag("[tm]LineBias",Color(Direction(t.Linear().Bias,InAction),IN_CHART_DIR));
      }

      //-- Caution test #2; Leader Change
      if (IsChanged(master.Lead,Action(t.Segment().Direction[Term])));
//        if (IsEqual(master.Manager,master.Lead))
//          Flag("[tm]SegLead",Color(t.Segment().Direction[Term],IN_CHART_DIR));
//        else
//        if (Close[0]>t.Linear().Close.Lead)
//          Flag("[tm]SegLead",BoolToInt(IsEqual(master.Manager,Buy),clrOrange,clrFireBrick));
//        else
//          Flag("[tm]SegLead",clrDarkGray);
//
      if (NewState(master.State,state));

    //if (t[AdverseEvent])
    //  Flag("AdverseEvent",clrMagenta);
//      if (!IsEqual(state,NoState))
//        Pause("New State: "+EnumToString(tick.State),"Linear State Change");

//    Comment("Tick State: "+TickStr());
  }

//+------------------------------------------------------------------+
//| UpdateSession - Updates Session data                             |
//+------------------------------------------------------------------+
void UpdateSession(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      s[type].Update();

    }
  }

//+------------------------------------------------------------------+
//| ManageOrders - Lead Manager order processor                      |
//+------------------------------------------------------------------+
void ManageOrders(int Manager)
  {
    OrderRequest request = order.BlankRequest(BoolToStr(IsEqual(Manager,Buy),"Purchasing","Sales"));
    
    if (order.Free(Manager)>order.Split(Manager)||IsEqual(order.Entry(Manager).Count,0))
      switch (Manager)
      {
        case Buy:          //request.Type    = OP_BUY;
                           request.Memo    = "Long Manager";
                           break;
      }

    if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
      if (order.Submitted(request))
        Print ("Yay");
      else
        order.PrintLog();
  }

//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(int Manager)
  {
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    order.Update();

    //-- Handle Active Management
    if (IsBetween(master.Manager,Buy,Sell))
    {
      ManageOrders(master.Manager);
      ManageRisk(Action(master.Manager,InAction,InContrarian));
    }
    else
    
    //-- Handle Unassigned Manager
    {
      ManageRisk(Buy);
      ManageRisk(Sell);
    }

    order.ExecuteOrders(Buy);
    order.ExecuteOrders(Sell);

    order.ExecuteRequests();
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
  
    UpdateTickMA();
    UpdateSession();

    InitializeTick();
    GetManualRequest();

    while (AppCommand(otParams,6))
      ExecAppCommands(otParams);

    OrderMonitor(Mode());

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
    order.Enable();

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      if (order[action].Lots>0)
        order.Disable(action,"Open Positions Detected; Preparing execution plan");
      else
        order.Enable(action,"System started "+TimeToString(TimeCurrent()));

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
    ManualInit();
    OrderConfig();
   
    //-- Initialize master data
    master.Manager       = NoAction;
    master.Lead          = NoAction;
    master.Direction     = NewDirection;
    master.Bias          = NewBias;
    master.Active        = PivotTypes;
    master.State         = NoState;
    master.Broken        = false;

    ArrayInitialize(master.Pivot,0.00);

    //-- Initialize pivot data
    for (PivotType type=0;type<PivotTypes;type++)
      NewLine("lnPivot:"+EnumToString(type));

    //-- Initialize Session
    s[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

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
//| TickStr - returns formatted tick data text                       |
//+------------------------------------------------------------------+
string TickStr()
  {
    string text     = "";

    Append(text,BoolToStr(IsEqual(master.Direction,NewDirection),"Pending",DirText(master.Direction)));
    Append(text,BoolToStr(IsEqual(master.Bias,NewBias),"Pending",ActionText(master.Bias)),"|");
    Append(text,ActionText(master.Active),"|");
    Append(text,BoolToStr(IsEqual(master.State,NoState),"Pending",EnumToString(master.State)),"|");
    Append(text,BoolToStr(master.Broken,"Broken"),"|");

    for (int type=0;type<PivotTypes;type++)
      Append(text,DoubleToStr(master.Pivot[type],Digits),"|");

    return text;
  }