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
#include <Class\Fractal.mqh>
#include <Class\PipFractal.mqh>

input string       EAHeader          = "";    //+------ App Config inputs ------+
input int          inpTrigger        = 6;     // Open Order Trigger in Periods
input int          inpStall          = 6;     // Trend Stall Factor in Periods

input string       FractalHeader     = "";    //+------ Fractal Options ---------+
input int          inpRangeMin       = 60;    // Minimum fractal pip range
input int          inpRangeMax       = 120;   // Maximum fractal pip range


input string       PipMAHeader       = "";    //+------ PipMA inputs ------+
input int          inpDegree         = 6;     // Degree of poly regression
input int          inpPeriods        = 200;   // Number of poly regression periods
input double       inpTolerance      = 0.5;   // Trend change tolerance (sensitivity)
input double       inpAggFactor      = 2.5;   // Tick Aggregate factor (1=1 PIP);
input int          inpIdleTime       = 50;    // Market idle time in Pips

//#define            Flush             true
   
  enum DisplayTypes
  {
    Display,
    Log
  };

  //--- Class Objects
  CFractal        *f                 = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal     *pf                = new CPipFractal(inpDegree,inpPeriods,inpTolerance,inpAggFactor,inpIdleTime);
  
  bool             PauseOn           = true;
  
  //--- Data Definitions
  enum             TradeStrategy  //--- Trade Strategies
                   {
                     tsHalt,
                     tsRisk,
                     tsScalp,
                     tsHedge,
                     tsHold,
                     tsProfit
                   };

  //struct           FractalRec        //-- Canonical Fractal Rec
  //                 {
  //                   TradeStrategy   Strategy;
  //                   ReservedWords   State;
  //                   bool            Trigger;
  //                   double          Root;
  //                   double          Prior;
  //                   double          Active;
  //                   double          TickPush;
  //                 };

  struct           PivotRec          //-- Price Consolidation Pivots
                   {
                     int             Direction;
                     int             Count;
                     double          Open;
                     double          Close;
                     double          High;
                     double          Low;
                   };
  
  struct           PivotHistory
                   {
                     PivotRec        Lead;
                     PivotRec        Prior;
                   };

  struct           PivotMaster
                   {
                     int             Action;      //-- Consolidation Pivot Action
                     int             Direction;   //-- Tick Direction
                     int             Bias;        //-- Master Bias (Action/Contrarian Hedge)
                     int             Segment;     //-- Count of Consolidation Segments;
                     int             Pocket;      //-- Contrarian Pocket Action
                     int             SignalBias;  //-- Contrarian Signal in Action;
                     PivotHistory    Master;      //-- Micro Trend Pivots
                     PivotHistory    Active;      //-- Active Term Legs 
                     PivotHistory    Pivot;       //-- Consolidation Pivots Lead/Prior
                     PivotHistory    Tick;        //-- Full Tick Lead/Prior
                   };

  struct           TriggerRec
                   {
                     bool            Fired;
                     PivotRec        Pivot;
                   };
                   
  struct           ActionMaster
                   {
                     ActionState     State;
                     TriggerRec      Trigger;
                   };
                                   
  //--- Fractal Variables  
  PivotMaster      pm;
  
  //--- Order Management
  ActionMaster     am[2];
  
//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (PauseOn)
      Pause(Message,AccountCompany()+" Event Trapper");
    else
      Print(Message);
  }

//+------------------------------------------------------------------+
//| PivotStr                                                         |
//+------------------------------------------------------------------+
string PivotStr(string Type, PivotRec &Pivot)
  {
    string prText        = "|"+Type;
    
    Append(prText,DirText(Pivot.Direction),"|");
    Append(prText,(string)Pivot.Count,"|");
    Append(prText,DoubleToStr(Pivot.Open,Digits),"|");
    Append(prText,DoubleToStr(Pivot.High,Digits),"|");
    Append(prText,DoubleToStr(Pivot.Low,Digits),"|");
    Append(prText,DoubleToStr(Pivot.Close,Digits),"|");

    return(prText);
  }

void PrintRec(DisplayTypes Destination)
  {
    string prDisplay    = "";
    
    switch (Destination)
    {
      case Log:       Print("|Record|"+ActionText(pm.Action)+"|"+DirText(pm.Direction)+"|"+ActionText(pm.Bias)+"|"+(string)pm.Segment+"|"+(string)pf.Count(Tick));
                      Print(PivotStr("Master[Lead]",pm.Master.Lead));
                      Print(PivotStr("Master[Prior]",pm.Master.Prior));
                      Print(PivotStr("Active[Lead]",pm.Active.Lead));
                      Print(PivotStr("Active[Prior]",pm.Active.Prior));
                      Print(PivotStr("Pivot[Lead]",pm.Pivot.Lead));
                      Print(PivotStr("Pivot[Prior]",pm.Pivot.Prior));
                      Print(PivotStr("Tick[Lead]",pm.Tick.Lead));
                      Print(PivotStr("Tick[Prior]",pm.Tick.Prior));
                      break;
      case Display:   prDisplay    = "|Record|"+ActionText(pm.Action)+"|"+DirText(pm.Direction)+"|"+ActionText(pm.Bias)+"|"+(string)pm.Segment+"|"+(string)pf.Count(Tick)+"\n";
                      prDisplay   += PivotStr("Master[Lead]",pm.Master.Lead)+"\n";
                      prDisplay   += PivotStr("Master[Prior]",pm.Master.Prior)+"\n";
                      prDisplay   += PivotStr("Active[Lead]",pm.Active.Lead)+"\n";
                      prDisplay   += PivotStr("Active[Prior]",pm.Active.Prior)+"\n";
                      prDisplay   += PivotStr("Pivot[Lead]",pm.Pivot.Lead)+"\n";
                      prDisplay   += PivotStr("Pivot[Prior]",pm.Pivot.Prior)+"\n";
                      prDisplay   += PivotStr("Tick[Lead]",pm.Tick.Lead)+"\n";
                      prDisplay   += PivotStr("Tick[Prior]",pm.Tick.Prior)+"\n";
                      CallPause(prDisplay);
                      break;
    }
                      
  }

//+------------------------------------------------------------------+  
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "-- Manual-v2 --\n";
    
    for (int action=OP_BUY;action==OP_SELL;action++)
      if (am[action].Trigger.Fired)
        Append(rsComment,"Trigger["+ActionText(pm.Action)+"]","\n");
    
    if (NewPocket())
      Append(rsComment,"Pocket["+ActionText(pm.Pocket)+"]","\n");

    Comment(rsComment);
//    pf.RefreshScreen();
  }
  
//+------------------------------------------------------------------+
//| UpdateFractal                                                    |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {
    f.Update();
  }

//+------------------------------------------------------------------+
//| NewAction - Updates Action on change; filters OP_NO_ACTION       |
//+------------------------------------------------------------------+
bool NewAction(int &Change, int Compare, bool Update=true)
  {
    if (Compare==OP_NO_ACTION)
      return (false);
      
    if (IsChanged(Change,Compare,Update))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| NewDirection - Updates Direction on change;filters DirectionNone |
//+------------------------------------------------------------------+
bool NewDirection(int &Change, int Compare, bool Update=true)
  {
    if (Compare==DirectionNone)
      return (false);

    if (Change==DirectionNone)
      if (IsChanged(Change,Compare,Update))
        return (false);
    
    if (IsChanged(Change,Compare,Update))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| NewPocket - returns true on a Pocket Boundary price hit          |
//+------------------------------------------------------------------+
bool NewPocket(void)
  {
    if (pm.Pocket==OP_NO_ACTION)
      return (false);
      
    if (IsEqual(Close[0],pm.Tick.Lead.High)||IsEqual(Close[0],pm.Tick.Lead.Low))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| CalcLinearTrend                                                  |
//+------------------------------------------------------------------+
void CalcLinearTrend(double &Price[])
  {
    //--- Linear regression line
    double m[5]      = {0.00,0.00,0.00,0.00,0.00};  //--- slope
    double b         = 0.00;                        //--- y-intercept
    
    double sumx      = 0.00;
    double sumy      = 0.00;
    
    for (int idx=0;idx<inpTrigger;idx++)
    {
      sumx += idx+1;
      sumy += Price[idx];
      
      m[1] += (idx+1)* Price[idx];  // Exy
      m[3] += pow(idx+1,2);         // E(x^2)
    }
    
    m[2]    = fdiv(sumx*sumy,inpTrigger);   // (Ex*Ey)/n
    m[4]    = fdiv(pow(sumx,2),inpTrigger); // [(Ex)^2]/n
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy-m[0]*sumx)/inpTrigger;
    
    for (int idx=0;idx<inpTrigger;idx++)
      Price[idx] = (m[0]*(idx+1))+b; //--- y=mx+b
  }

//+------------------------------------------------------------------+
//| Flush - returns default initial pivot rec                        |
//+------------------------------------------------------------------+
PivotRec Flush(int Direction=DirectionNone, int Count=0)
  {
    PivotRec Default;
    
    Default.Direction      = Direction;
    Default.Count          = Count;
    
    Default.High           = Close[0];
    Default.Low            = Close[0];
    Default.Open           = Close[0];
    Default.Close          = BoolToDouble(Direction==DirectionNone,Close[0],NoValue);
    
    return (Default);
  }

//+------------------------------------------------------------------+
//| PivotBias - Returns the computed Bias in Action                  |
//+------------------------------------------------------------------+
int PivotBias(bool Contrarian=false)
  {
    if (pm.Segment>0)
      return(Action(pm.Pivot.Prior.Direction));
      
    return(Action(pm.Pivot.Lead.Direction));
  }

//+------------------------------------------------------------------+
//| UpdatePivot                                                      |
//+------------------------------------------------------------------+
void UpdatePivot(PivotHistory &Pivot, PivotRec &Copy, bool Reset=true)
  {
    Pivot.Lead.Count       = BoolToInt(Reset,1,Pivot.Lead.Count);
    Pivot.Prior            = Pivot.Lead;
    Pivot.Lead             = Copy;
    Pivot.Lead.Close       = NoValue;
  }

//+------------------------------------------------------------------+
//| UpdatePipMA                                                      |
//+------------------------------------------------------------------+
void UpdatePipMA(void)
  {
    #define TickReset   1
    
    pf.Update();

    if (pf.Event(NewTick))
    {
      //-- Process Tick Segment
      if (pm.Tick.Lead.Direction==pf.Direction(Tick))
        if (NewDirection(pm.Tick.Lead.Direction,Direction(pm.Tick.Lead.Close-pm.Tick.Lead.Open)))
          UpdatePivot(pm.Tick,Flush(pm.Tick.Lead.Direction,TickReset));
        else
          UpdatePivot(pm.Tick,Flush(pf.Direction(Tick),++pm.Tick.Lead.Count),false);
      else
        if (NewDirection(pm.Tick.Lead.Direction,pf.Direction(Tick)))
          UpdatePivot(pm.Tick,Flush(pf.Direction(Tick),TickReset));
          
      pm.SignalBias = BoolToInt(pm.Tick.Lead.Direction==pf.Direction(Tick),OP_NO_ACTION,Action(pm.Tick.Lead.Direction,InDirection,InContrarian));
      
      //-- Process Active Segment
      if (pm.Tick.Prior.Count==TickReset)
      {
        pm.Segment                = BoolToInt(pm.Active.Lead.Count==pm.Active.Prior.Count,++pm.Segment,0);
        pm.Direction              = pf.Direction(Tick);
        pm.Action                 = Action(pf.Direction(Tick));
        
        UpdatePivot(pm.Active,pm.Tick.Prior,false);
      }

      pm.Active.Lead.Count        = pm.Tick.Prior.Count;
      pm.Active.Lead.Close        = pm.Tick.Prior.Open;
    }

    //-- Process Pivot/Master Segments
    if (pm.Segment>0)
    {
      //-- Open for potential new Pivot; (if) retire prior Pivot
      if (pf.Event(NewTick))
        if (pm.Segment==TickReset)
          if (pm.Pivot.Lead.Close>NoValue)
            UpdatePivot(pm.Pivot,pm.Active.Prior,false);
          else
            pm.Pivot.Lead         = pm.Active.Prior;

      pm.Pivot.Lead.Direction     = pm.Active.Lead.Direction;
      pm.Pivot.Lead.High          = BoolToDouble(pm.Pivot.Lead.Direction==DirectionUp,pm.Pivot.Lead.High,fmax(pm.Pivot.Lead.High,pm.Active.Lead.High));
      pm.Pivot.Lead.Low           = BoolToDouble(pm.Pivot.Lead.Direction==DirectionUp,fmin(pm.Pivot.Lead.Low,pm.Active.Lead.Low),pm.Pivot.Lead.Low);

      //-- Consolidation Breakout; Close Pivot
      if (pm.Active.Lead.Count>pm.Active.Prior.Count)
      {
        pm.Pivot.Lead.Close       = pm.Tick.Prior.Close;
        pm.Pivot.Lead.High        = fmax(pm.Pivot.Lead.High,pm.Pivot.Lead.Close);
        pm.Pivot.Lead.Low         = fmin(pm.Pivot.Lead.Low,pm.Pivot.Lead.Close);

        pm.Segment                = 0;

        //-- Check for Bias Change
        if (NewAction(pm.Bias,PivotBias()))
          UpdatePivot(pm.Master,pm.Active.Lead);
      }
    }

//    if (pm.SignalBias!=OP_NO_ACTION)
//      Print("Special|"+(string)pf.Count(History)+"|"+PivotStr("Tick[Lead]",pm.Tick.Lead));    

    if (IsHigher(Close[0],pm.Tick.Lead.High))
      pm.Tick.Lead.Close          = Close[0];

    if (IsLower(Close[0],pm.Tick.Lead.Low))
      pm.Tick.Lead.Close          = Close[0];

    //-- Manage Active Leg Data
    pm.Active.Lead.High           = fmax(pm.Active.Lead.High,Close[0]);
    pm.Active.Lead.Low            = fmin(pm.Active.Lead.Low,Close[0]);

    //-- Manage Tick Data & Events
//    pm.Pocket                                         = OP_NO_ACTION;
//
//    if (IsHigher(Close[0],pm.Tick.Prior.High,NoUpdate))
//      pm.Pocket                                       = OP_BUY;
//
//    if (IsLower(Close[0],pm.Tick.Prior.Low,NoUpdate))
//      pm.Pocket                                       = OP_SELL;
//
    //-- Manage Master Leg Data
    if (pf.Event(NewTick))
      if (Action(pm.Direction)==pm.Bias)
        pm.Master.Lead.Close      = pm.Active.Lead.Close;
        
    pm.Master.Lead.High           = fmax(pm.Master.Lead.High,Close[0]);
    pm.Master.Lead.Low            = fmin(pm.Master.Lead.Low,Close[0]);

    //-- Prints (Testing)
    if (pf.Event(NewTick))
    {
//      PrintRec(Display);
//      Print(PivotStr("Tick[Prior]",pm.Tick.Prior));
//      Print(PivotStr("Tick[Lead]",pm.Tick.Lead));
        //if (pm.Tick.Lead.Count==TickReset)
        //{
        //  Print("Consolidation: "+(string)pm.Segment);
        //Print(PivotStr("Active[Lead]|"+(string)pm.Segment+"|",pm.Active.Lead));
        //Print(PivotStr("Active[Prior]|"+(string)pm.Segment+"|",pm.Active.Prior));
        //}
      //Print(PivotStr("Pivot[Prior]|"+(string)pm.Segment+"|",pm.Pivot.Prior));
      //Print(PivotStr("Pivot[Lead]|"+(string)pm.Segment+"|",pm.Pivot.Lead));
      //Print(BoolToStr(pm.Bias==Action(pm.Master.Lead.Direction),">","--")+PivotStr("Master[Lead]: ",pm.Master.Lead));
      //Print(BoolToStr(pm.Bias==Action(pm.Master.Prior.Direction),"--",">")+PivotStr("Master[Prior]: ",pm.Master.Prior));
    }
  }

//+------------------------------------------------------------------+
//| AnalyzeMarket                                                    |
//+------------------------------------------------------------------+
void AnalyzeAction(void)
  {
    if (NewPocket())
    {
//      if (IsChanged(am[pm.Pocket].Trigger.Fired,true))
//        UpdatePivot(am[pm.Pocket].Trigger.Pivot);

      //-- Deep Assessment by Action
      //if (pm.Pocket==
    }
    else
    {};    

    //am[pm.Pocket].Trigger.Pivot.High   = fmax(Close[0],am[pm.Pocket].Trigger.Pivot.High);
    //am[pm.Pocket].Trigger.Pivot.Low    = fmin(Close[0],am[pm.Pocket].Trigger.Pivot.Low);
    //am[pm.Pocket].Trigger.Pivot.Close  = Close[0];
  }

//+------------------------------------------------------------------+
//| ManageOrders                                                     |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {
//    if (pf.Event(NewTick))
//      if (IsChanged(om.Action,pm.Action))
//      {
//        //-- New Bias Setup
//      }
//
//    for (int action=OP_BUY;action==OP_SELL;action++)
//      if (pf.Direction(Tick)==pm.Direction)
//      {
//        //-- Profit Management
//        
//        //-- Risk Management
//      }
//      else
//      {
//        //--- Entry Opportunity
//      }

  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    AnalyzeAction();
    
    ManageOrders();
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PAUSE")
      PauseOn                     = true;
      
    if (Command[0]=="PLAY")
      PauseOn                     = false;    
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

    OrderMonitor();

    UpdateFractal();
    UpdatePipMA();

    RefreshScreen();
    
    if (AutoTrade())
      Execute();
    
    ReconcileTick();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ManualInit();
    
    //-- Init Pivot Master Record
    pm.Action                     = OP_NO_ACTION;
    pm.Direction                  = DirectionNone;
    pm.Bias                       = OP_NO_ACTION;
    pm.Segment                    = 0;
    
    pm.Tick.Lead                  = Flush();
    UpdatePivot(pm.Tick,Flush());

    pm.Active                     = pm.Tick;
    pm.Pivot                      = pm.Tick;
    pm.Master                     = pm.Tick;

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    delete f;
    delete pf;
  }