//+------------------------------------------------------------------+
//|                                                       man-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict


#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\Session.mqh>

input string    EAHeader                = "";    //+---- Application Options -------+
input int       inpIdleTrigger          = 50;    // Market idle trigger
input int       inpEQChgPct             = 2;     // Lead order equity% change event
input YesNoType inpShowPolyArrows       = No;    // Show poly direction change arrows
  
input string    fractalHeader           = "";    //+------ Fractal Options ---------+
input int       inpRangeMin             = 60;    // Minimum fractal pip range
input int       inpRangeMax             = 120;   // Maximum fractal pip range
input int       inpPeriodsLT            = 240;   // Long term regression periods

input string    RegressionHeader        = "";    //+------ Regression Options ------+
input int       inpDegree               = 6;     // Degree of poly regression
input int       inpSmoothFactor         = 3;     // MA Smoothing factor
input double    inpTolerance            = 0.5;   // Directional sensitivity
input int       inpPipPeriods           = 200;   // Trade analysis periods (PipMA)
input int       inpRegrPeriods          = 24;    // Trend analysis periods (RegrMA)

  //--- Class Objects
  CFractal     *fractal                 = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal  *pfractal                = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,inpIdleTrigger,fractal);
  
  //--- Operational Switches
  bool          PauseOn                 = true;
  string        Show                    = "PIPMA";

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (PauseOn)
      Pause(Message,"Event Trapper");
  }
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {    
    fractal.Update();
    pfractal.Update();
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string          rsComment        = "";

    if (Show="PIPMA")
      pfractal.RefreshScreen();
      
    if (Show="SESSION");
      session.
          
//    Comment(rsComment);
  }

//+------------------------------------------------------------------+
//| AnalyzePipMA - PipMA Analysis routine                            |
//+------------------------------------------------------------------+
void AnalyzePipMA(void)
  {
    if (pfractal.HistoryLoaded())
      if (pfractal.Event(NewCrest)||pfractal.Event(NewTrough))
        CallPause("PipMA "+pfractal.ActiveEventText());
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    AnalyzePipMA();
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PAUSE")
        PauseOn    = true;

    if (Command[0]=="PLAY")
        PauseOn    = false;

    if (Command[0]=="SHOW")
        Show       = Command[1];
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
    GetData();

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
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
  }