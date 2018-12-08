//+------------------------------------------------------------------+
//|                                                        hm-v1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>

//--- Input params
input string PipMAHeader        = "";    //+------ PipMA inputs ------+
input int    inpDegree          = 6;     // Degree of poly regression
input int    inpPeriods         = 200;   // Number of poly regression periods
input double inpTolerance       = 0.5;   // Trend change tolerance (sensitivity)
input bool   inpShowFibo        = true;  // Display lines and fibonacci points
input bool   inpShowComment     = false; // Display fibonacci data in Comment

input string fractalHeader      = "";    //+------ Fractal inputs ------+
input int    inpRangeMax        = 120;   // Maximum fractal pip range
input int    inpRangeMin        = 60;    // Minimum fractal pip range

//--- Class defs
  CFractal         *fractal     = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal    = new CPipFractal(inpDegree,inpPeriods,inpTolerance,fractal);


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
    pfractal.RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int eMajorDir   = DirectionNone;
    static int eMinorDir   = DirectionNone;
    
    if (pfractal.Event(NewMinor))
      if (IsChanged(eMinorDir,pfractal.Direction(Term)))
        SendMail("New Minor ("+DirText(eMinorDir)+")","HM-V2 has detected a new minor trend");

    if (pfractal.Event(NewMajor))
      if (IsChanged(eMajorDir,pfractal.Direction(Term)))
        SendMail("New Major ("+DirText(eMajorDir)+")","HM-V2 has detected a new major trend");
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