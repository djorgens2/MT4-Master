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
#include <Class\Session.mqh>

input string       EAHeader            = "";    //+------ App Config inputs ------+
input int          inpTrigger          = 6;     // Open Order Trigger in Periods
input int          inpStall            = 6;     // Fractal Stall Factor in Periods
input YesNoType    inpShowMasterLines  = Yes;   // Show Master Lines
input YesNoType    inpShowBroken       = No;    // Show Broken/Unbroken Flags

input string       FractalHeader       = "";    //+------ Fractal Options ---------+
input int          inpRangeMin         = 60;    // Minimum fractal pip range
input int          inpRangeMax         = 120;   // Maximum fractal pip range

input string       PipMAHeader         = "";    //+------ PipMA inputs ------+
input int          inpDegree           = 6;     // Degree of poly regression
input int          inpPeriods          = 200;   // Number of poly regression periods
input double       inpTolerance        = 0.5;   // Trend change tolerance (sensitivity)
input double       inpAggFactor        = 2.5;   // Tick Aggregate factor (1=1 PIP);
input int          inpIdleTime         = 50;    // Market idle time in Pips

input string       SessionHeader       = "";    //+---- Session Hours -------+
input int          inpAsiaOpen         = 1;     // Asian market open hour
input int          inpAsiaClose        = 10;    // Asian market close hour
input int          inpEuropeOpen       = 8;     // Europe market open hour`
input int          inpEuropeClose      = 18;    // Europe market close hour
input int          inpUSOpen           = 14;    // US market open hour
input int          inpUSClose          = 23;    // US market close hour
input int          inpGMTOffset        = 0;     // GMT Offset

  //-- General Operationals
  bool             PauseOn             = true;

  //-- Enumerations  
  enum DisplayTypes
  {
    Display,
    Log
  };

  //--- Class Objects
  CFractal        *f                 = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal     *pf                = new CPipFractal(inpDegree,inpPeriods,inpTolerance,inpAggFactor,inpIdleTime);
  CSession        *s[SessionTypes];
  
  //--- Data Definitions
  //enum             TradeStrategy  //--- Trade Strategies
  //                 {
  //                   tsHalt,
  //                   tsRisk,
  //                   tsScalp,
  //                   tsHedge,
  //                   tsHold,
  //                   tsProfit
  //                 };

  struct           FiboCalcRec
                   {
                     double          Min;
                     double          Max;
                     double          Now;
                   };

  struct           FractalDetail     //-- Canonical Fractal Rec
                   {
                     RetraceType     Type;
                     ReservedWords   State;
                     int             Direction;
                     int             Bias;
                     double          Age;
                     double          Price[FractalPoints];
                     FiboCalcRec     Expansion;
                     FiboCalcRec     Retrace;
                   };
  
  struct           FractalMaster
                   {
                     FractalDetail   f[6];
                     FractalDetail   s[SessionTypes][5];
                     FractalDetail   pf[3];
                   };

  //struct           LinearRegression  //-- Data structure for regression forecasts
  //                 {
  //                   int             Direction;
  //                   double          Base;
  //                   double          Step;
  //                   CArrayDouble    *Point[];
  //                   double          Forecast;
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
  
  struct           PivotSet
                   {
                     PivotRec        Lead;
                     PivotRec        Prior;
                   };

  struct           PivotMaster
                   {
                     int             Action;      //-- Consolidation Pivot Action
                     int             Direction;   //-- Tick Direction
                     int             Segment;     //-- Count of Consolidation Segments;
                     int             State;       //-- {TBD} Master State
                     int             Bias;        //-- Master Bias (Action/Contrarian Hedge)
                     bool            Broken;      //-- Master broken flag;
                     double          Correction;  //-- Master critical pivot price
                     PivotSet        Master;      //-- Micro Trend Pivots
                     PivotSet        Active;      //-- Active Term Legs 
                     PivotSet        Pivot;       //-- Consolidation Pivots Lead/Prior
                     PivotSet        Tick;        //-- Full Tick Lead/Prior
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

  //-- General Operational variables
  int             SignalBias;  //-- anomaly found; testing for actionable viability
                                   
  //--- Pivot Variables  
  FractalMaster    fm;
  
  //--- Pivot Variables  
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

//+------------------------------------------------------------------+  
//| PrintRec - Formasts and sends pivots to supplied output          |
//+------------------------------------------------------------------+
void PrintRec(DisplayTypes Output)
  {
    string prDisplay    = "";
    
    switch (Output)
    {
      case Log:       Print("|Record|"+ActionText(pm.Action)+"|"+DirText(pm.Direction)+"|"+ActionText(pm.Bias)+"|"+(string)pm.Segment+"|"+(string)pf.Count(Tick));
                      //Append(prText,BoolToStr(Pivot.Broken,"BROKEN","UNBROKEN"),"|");
                      //Append(prText,DoubleToStr(Pivot.Correction,Digits),"|");
                      //Append(prText,DoubleToStr(Pivot.Resume,Digits),"|");
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

    if (inpShowMasterLines==Yes)
    {
      UpdateLine("Master[Lead].High",pm.Master.Lead.High,STYLE_SOLID,Color(Direction(pm.Bias,InAction)));
      UpdateLine("Master[Lead].Low",pm.Master.Lead.Low,STYLE_SOLID,Color(Direction(pm.Bias,InAction)));
      UpdateLine("Master[Lead].Close",pm.Master.Lead.Close,STYLE_DOT,Color(Direction(pm.Bias,InAction)));
    }

    Comment(rsComment);
//    pf.RefreshScreen();
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
//| UpdateSession                                                    |
//+------------------------------------------------------------------+
void UpdateSession(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();
  }

////+------------------------------------------------------------------+
////| LoadFractal - copies fractal data from source to target by ind   |
////+------------------------------------------------------------------+
//void LoadFractal(RetraceType Type, FractalDetail &Target)
//  {
//  struct           FiboCalcRec
//                   {
//                     double          Min;
//                     double          Max;
//                     double          Now;
//                   };
//
//  struct           FractalDetail     //-- Canonical Fractal Rec
//                   {
//                     CanonicalFType  Type;
//                     ReservedWords   State;
//                     int             Direction;
//                     int             Bias;
//                     double          Age;
//                     double          Price[FractalPoints];
//                     FiboCalcRec     Expansion;
//                     FiboCalcRec     Retrace;
//                   };
//
//+------------------------------------------------------------------+
//| UpdateFractal                                                    |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {
    f.Update();
    
    RetraceType ufLeg              = f.Leg(Active);
    
    for (int slot=5;slot>NoValue;slot--)
    {
      //-- Load macro detail
      if (slot<3)
      {
        
        fm.f[slot].Type            = (RetraceType)slot;
      }
      else

      //-- Load meso detail
      {
        fm.f[slot].Type            = ufLeg;
        
        ufLeg                      = f.Previous(ufLeg,Convergent);
      }
    }
    
    for (int slot=0;slot<6;slot++)
      Print(EnumToString(fm.f[slot].Type));
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
//| SetBroken - Return Price and Set Broken State for supplied Pivot |
//+------------------------------------------------------------------+
void SetBroken(PivotRec &Pivot)
  {
    if (Pivot.Direction==DirectionNone)
      return;

    if (pf.Event(NewTick))
      if (pm.Segment==0)
        if (IsEqual(Pivot.Low,Close[0],Digits)||IsEqual(Pivot.High,Close[0],Digits))
          if (Pivot.Direction==pm.Direction)
          {
            if (IsChanged(pm.Broken,false))
            {
              Flag("Unbroken",clrWhite,inpShowBroken==Yes);
              pm.Correction     = (Close[0]);
            }
          }
          else
            if (IsChanged(pm.Broken,true))
            {
              Flag("Broken",Color(pm.Direction),inpShowBroken==Yes);
              pm.Correction     = (Close[0]);
            }
  }

//+------------------------------------------------------------------+
//| SetTrigger - tests for and maintains trigger states              |
//+------------------------------------------------------------------+
void SetTrigger(void)
  {
    CallPause("NewTick");
    
    if (Close[0]<pm.Tick.Lead.Close)
      if (Close[0]>fmin(pm.Tick.Lead.Low,pm.Tick.Prior.Low))
      {
        Print(PivotStr("Trigger[BUY]|",am[OP_BUY].Trigger.Pivot));
        am[OP_BUY].Trigger.Pivot    = Flush();
        am[OP_BUY].Trigger.Fired    = true;
        
        am[OP_SELL].Trigger.Fired   = false;

//        OpenOrder(OP_BUY,"Auto-Trig");
        CallPause("Buy Trigger Fired ["+(string)pf.Count(History)+"]:"+DoubleToStr(Close[0],Digits));
      }

    if (Close[0]>pm.Tick.Lead.Close)
      if (Close[0]<fmax(pm.Tick.Lead.High,pm.Tick.Prior.High))
      {
        Print(PivotStr("Trigger[SELL]|",am[OP_SELL].Trigger.Pivot));

        am[OP_SELL].Trigger.Pivot   = Flush();
        am[OP_SELL].Trigger.Fired   = true;

        am[OP_BUY].Trigger.Fired    = false;

//        OpenOrder(OP_SELL,"Auto-Trig");
        CallPause("Sell Trigger Fired ["+(string)pf.Count(History)+"]:"+DoubleToStr(Close[0],Digits));
      }
  }

//+------------------------------------------------------------------+
//| PivotBias - Returns the computed Bias in Action                  |
//+------------------------------------------------------------------+
int PivotBias(ReservedWords Type, bool Contrarian=false)
  {
    int tbDirection             = DirectionNone;
    
    switch (Type)
    {
      case Tick:    if (IsLower(pm.Tick.Lead.Low,pm.Tick.Prior.Low,NoUpdate)) tbDirection=DirectionDown;
                    if (IsHigher(pm.Tick.Lead.High,pm.Tick.Prior.High,NoUpdate)) tbDirection=DirectionUp;
                    break;

      case Pivot:   if (pm.Segment==0)
                    {
                      tbDirection = pm.Pivot.Lead.Direction;
      
                      if (IsLower(pm.Tick.Lead.Low,pm.Pivot.Lead.Low,NoUpdate)) tbDirection=DirectionDown;
                      if (IsHigher(pm.Tick.Lead.High,pm.Pivot.Lead.High,NoUpdate)) tbDirection=DirectionUp;
                    }
                    else
                    {
                      tbDirection = pm.Pivot.Prior.Direction;
      
                      if (IsLower(pm.Tick.Lead.Low,pm.Pivot.Prior.Low,NoUpdate)) tbDirection=DirectionDown;
                      if (IsHigher(pm.Tick.Lead.High,pm.Pivot.Prior.High,NoUpdate)) tbDirection=DirectionUp;
                    }
                    break;
                    
      case Active:  tbDirection = BoolToInt(pm.Active.Lead.Count>pm.Active.Prior.Count,pm.Active.Lead.Direction,pm.Active.Prior.Direction);
                    break;
                    
      case Master:  tbDirection = BoolToInt(pm.Segment==0,pm.Pivot.Lead.Direction,pm.Pivot.Prior.Direction);
    };
    
    return (Action(tbDirection,InDirection,Contrarian));
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
//| NewPivot - Copies current to prior; inits new pivot              |
//+------------------------------------------------------------------+
void NewPivot(PivotSet &Pivot, PivotRec &Copy, bool Reset=true)
  {
    Pivot.Lead.Count       = BoolToInt(Reset,1,Pivot.Lead.Count);
    Pivot.Prior            = Pivot.Lead;
    Pivot.Lead             = Copy;
    Pivot.Lead.Close       = NoValue;
  }

//+------------------------------------------------------------------+
//| UpdatePivot - Sets New Highs, Lows, and Conditional Close        |
//+------------------------------------------------------------------+
void UpdatePivot(PivotRec &Pivot, bool UpdateClose=true)
  {
    if (IsHigher(Close[0],Pivot.High))
      if (UpdateClose)
        Pivot.Close        = Close[0];

    if (IsLower(Close[0],Pivot.Low))
      if (UpdateClose)
        Pivot.Close        = Close[0];
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
      //-- Set Triggers (Pre-Update)
      SetTrigger();
      
      //-- Process Tick Segment
      if (pm.Tick.Lead.Direction==pf.Direction(Tick))
        if (NewDirection(pm.Tick.Lead.Direction,Direction(pm.Tick.Lead.Close-pm.Tick.Lead.Open)))
          NewPivot(pm.Tick,Flush(pm.Tick.Lead.Direction,TickReset));
        else
          NewPivot(pm.Tick,Flush(pf.Direction(Tick),++pm.Tick.Lead.Count),false);
      else
        if (NewDirection(pm.Tick.Lead.Direction,pf.Direction(Tick)))
          NewPivot(pm.Tick,Flush(pf.Direction(Tick),TickReset));
          
      SignalBias = BoolToInt(pm.Tick.Lead.Direction==pf.Direction(Tick),OP_NO_ACTION,Action(pm.Tick.Lead.Direction,InDirection,InContrarian));
      
      //-- Process Active Segment
      if (pm.Tick.Prior.Count==TickReset)
      {
        pm.Action                 = Action(pf.Direction(Tick));
        pm.Direction              = pf.Direction(Tick);
        pm.Segment                = BoolToInt(pm.Active.Lead.Count==pm.Active.Prior.Count,++pm.Segment,0);
        
        NewPivot(pm.Active,pm.Tick.Prior,false);
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
            NewPivot(pm.Pivot,pm.Active.Prior,false);
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
        if (NewAction(pm.Bias,PivotBias(Master)))
          NewPivot(pm.Master,pm.Active.Lead);
      }
    }

//    if (pm.SignalBias!=OP_NO_ACTION)
//      Print("Special|"+(string)pf.Count(History)+"|"+PivotStr("Tick[Lead]",pm.Tick.Lead));    

    //-- Manage Leg Data
    UpdatePivot(pm.Tick.Lead);
    UpdatePivot(pm.Active.Lead,NoUpdate);
    UpdatePivot(pm.Master.Lead,NoUpdate);

    //-- Manage Master Segments
    if (pf.Event(NewTick))
      if (Action(pm.Direction)==pm.Bias)
        pm.Master.Lead.Close      = pm.Active.Lead.Close;

    SetBroken(pm.Master.Lead);
    
    //-- Manage Trigger Segments
    for (int action=OP_BUY;action<=OP_SELL;action++)
      if (am[action].Trigger.Fired)
        UpdatePivot(am[action].Trigger.Pivot);

    //-- Prints (Testing)
    if (pf.Event(NewTick))
    {
//      CallPause("History["+(string)+pf.Count(History)+"|\n|"+PivotStr("Master[Lead]",pm.Master.Lead));
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
      //if (pm.Master.Lead.Correction>0.00)
      //Print(PivotStr("Master[Lead]|"+ActionText(pm.Bias)+"|",pm.Master.Lead));
//      Print(PivotStr("Master[Prior]|"+ActionText(pm.Bias)+"|",pm.Master.Prior));
    }
  }

//+------------------------------------------------------------------+
//| AnalyzeMarket                                                    |
//+------------------------------------------------------------------+
void AnalyzeAction(void)
  {
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

    UpdateSession();
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
    s[Daily]                      = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]                       = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]                     = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]                         = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    ManualInit();
    
    //-- Init Pivot Master Record
    pm.Action                     = OP_NO_ACTION;
    pm.Direction                  = DirectionNone;
    pm.Bias                       = OP_NO_ACTION;
    pm.Segment                    = 0;
    
    pm.Tick.Lead                  = Flush();
    NewPivot(pm.Tick,Flush());

    pm.Active                     = pm.Tick;
    pm.Pivot                      = pm.Tick;
    pm.Master                     = pm.Tick;
    
    if (inpShowMasterLines==Yes)
    {
      NewLine("Master[Lead].High");
      NewLine("Master[Lead].Low");
      NewLine("Master[Lead].Close");
    }

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