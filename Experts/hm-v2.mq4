//+------------------------------------------------------------------+
//|                                                        hm-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
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
input int    inpRangeMax        = 120;    // Maximum fractal pip range
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
//    UpdateLine("pfBaseT",pfractal[Term].Base,STYLE_DASH,clrGoldenrod);
//    UpdateLine("pfRootT",pfractal[Term].Root,STYLE_DASH,clrSteelBlue);
//    UpdateLine("pfExpansionT",pfractal[Term].Expansion,STYLE_DASH,clrFireBrick);

    UpdateLine("pfBase",pfractal[Trend].Base,STYLE_SOLID,clrGoldenrod);
    UpdateLine("pfRoot",pfractal[Trend].Root,STYLE_SOLID,clrSteelBlue);
    UpdateLine("pfExpansion",pfractal[Trend].Expansion,STYLE_SOLID,clrFireBrick);
//
//    UpdateLine("pfBaseO",pfractal.Price(Origin,Base),STYLE_DOT,clrGoldenrod);
//    UpdateLine("pfRootO",pfractal.Price(Origin,Root),STYLE_DOT,clrSteelBlue);
//    UpdateLine("pfExpansionO",pfractal.Price(Origin,Expansion),STYLE_DOT,clrFireBrick);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
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
    
    NewLine("pfBase");
    NewLine("pfRoot");
    NewLine("pfExpansion");

    NewLine("pfBaseT");
    NewLine("pfRootT");
    NewLine("pfExpansionT");

    NewLine("pfBaseO");
    NewLine("pfRootO");
    NewLine("pfExpansionO");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }