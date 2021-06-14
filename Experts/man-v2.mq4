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

  struct           PivotRec          //-- Price Consolidation Pivots
                   {
                     int             Direction;
                     bool            Broken;
                     int             Count;
                     double          Open;
                     double          Close;
                     double          High;
                     double          Low;
                   };
                   
  struct           PivotMaster
                   {
                     int             Count;
                     int             Direction;
                     int             Bias;
                     PivotRec        Open;
                     PivotRec        Active;
                     PivotRec        Prior;
                   };

  struct           FractalRecord     //-- Canonical Fractal Rec
                   {
                     TradeStrategy   Strategy;
                     ReservedWords   State;
                     bool            Trigger;
                     double          Root;
                     double          Prior;
                     double          Active;
                     double          TickPush;
                   };
                
  //--- Fractal Variables  
  PivotMaster      pr;
  
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
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "-- Manual-v2 --\n";
    
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
//| InitPivotRec                                                     |
//+------------------------------------------------------------------+
void InitPivotRec(PivotRec &Pivot)
  {
    Pivot.Direction      = pf.Direction(Tick);
    Pivot.Broken         = false;
    Pivot.Count          = pf.Count(Tick);
    Pivot.Open           = Close[0];
    Pivot.Close          = NoValue;
    Pivot.High           = Close[0];
    Pivot.Low            = Close[0];
  }

//+------------------------------------------------------------------+
//| UpdatePipMA                                                      |
//+------------------------------------------------------------------+
void UpdatePipMA(void)
  {    
    pf.Update();

    if (pf.Event(NewTick))
    {
      if (pf.Count(Tick)==1)
      {
        //-- New Direction --//
           
      }
      else
      {
      }
    
      CallPause("New Tick");
    }
  }

//+------------------------------------------------------------------+
//| AnalyzeMarket                                                    |
//+------------------------------------------------------------------+
void AnalyzeMarket(void)
  {

  }

//+------------------------------------------------------------------+
//| ManageOrders                                                     |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {

  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    AnalyzeMarket();
    
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
   
    //-- Init Master Record
    pr.Count                = 0;
    pr.Direction            = pf.Direction(Tick);
    pr.Bias                 = Action(pr.Direction);
    
    InitPivotRec(pr.Active);
    InitPivotRec(pr.Open);
    InitPivotRec(pr.Prior);
        
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