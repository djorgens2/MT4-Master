//+------------------------------------------------------------------+
//|                                                       man-v1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
//#include <Sessions.mqh>
#include <Class\PipFractal.mqh>
#include <Class\Sessions-v1.mqh>

input string EAHeader                = "";    //+---- Application Options -------+
input int    inpMaxVolume            = 30;    // Maximum volume
input double inpDailyTarget          = 3.6;   // Daily target

input string fractalHeader           = "";    //+------ Fractal Options ---------+
input int    inpRangeMin             = 60;    // Minimum fractal pip range
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpPeriodsLT            = 240;   // Long term regression periods

input string RegressionHeader        = "";    //+------ Regression Options ------+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpSmoothFactor         = 3;     // MA Smoothing factor
input double inpTolerance            = 0.5;   // Directional sensitivity
input int    inpPipPeriods           = 200;   // Trade analysis periods (PipMA)
input int    inpRegrPeriods          = 24;    // Trend analysis periods (RegrMA)

input string SessionHeader           = "";    //+---- Session Hours -------+
input int    inpNewDay               = 0;     // New day market open hour
input int    inpEndDay               = 0;    // End of day hour
input int    inpAsiaOpen             = 1;     // Asian market open hour
input int    inpAsiaClose            = 10;    // Asian market close hour
input int    inpEuropeOpen           = 8;     // Europe market open hour
input int    inpEuropeClose          = 18;    // Europe market close hour
input int    inpUSOpen               = 14;    // US market open hour
input int    inpUSClose              = 23;    // US market close hour

//--- Class defs
  CFractal           *fractal        = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal       = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CSessions          *sessions       = new CSessions();

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    static int    gdPivotDir   = DirectionNone;
    static double gdPivotPrice = 0.00;
    
    fractal.Update();
    pfractal.Update();

//    UpdateSessions();
    
    if (IsChanged(gdPivotDir,pfractal.Direction(Pivot)))
      Pause("New Pivot Breakout\nDirection: "+DirText(pfractal.Direction(Range)),"ptrRangeDir() Issue");
//    if (pfractal.Age(Tick)==1)
  }

//+------------------------------------------------------------------+
//| CalcDailyPlan                                                    |
//+------------------------------------------------------------------+
void CalcDailyPlan(void)
  {
    
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
//    if (opNewDay)
//    {
//      Pause("New Day - What's the game plan?","NewDay()");
      
      CalcDailyPlan();
//    }
    
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
//    InitSessions();
        
    sessions.SetSessionHours(Daily,inpNewDay,inpEndDay);
    sessions.SetSessionHours(Asia,inpAsiaOpen,inpAsiaClose);
    sessions.SetSessionHours(Europe,inpEuropeOpen,inpEuropeClose);
    sessions.SetSessionHours(US,inpUSOpen,inpUSClose);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete sessions;
  }