//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2017, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.10"
#property strict

#include <Class\PipFractal.mqh>
#include <manual.mqh>

input string appHeader               = "";    //+------ App Options -------+
input bool   inpShowFiboLines        = false; // Display Fibonacci Lines

input string fractalHeader           = "";    //+------ Fractal Options ------+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

input string PipMAHeader             = "";    //+------ PipMA Options ------+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpPeriods              = 200;   // Number of poly regression periods
input double inpTolerance            = 0.5;   // Directional change sensitivity

//--- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPeriods,inpTolerance,fractal);

//--- Operational variables
  int              display           = NoValue;

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();
    pfractal.Update();
  }

//+------------------------------------------------------------------+
//| ShowAppData - Hijacks the comment for application metrics        |
//+------------------------------------------------------------------+
void ShowAppData(void)
  {
    string        rsComment   = "";

    rsComment     = "No Comment";
    
    Comment(rsComment);  
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    switch (display)
    {
      case 0:  fractal.RefreshScreen();
               break;
      case 1:  pfractal.RefreshScreen();
               break;
      case 2:  ShowAppData();
               break;
      default: Comment("No Data");
    }

    //--- Standard Deviation channel lines
    UpdateLine("oBase",pfractal.Price(Origin,Base),STYLE_SOLID,clrGoldenrod);
    UpdateLine("oRoot",pfractal.Price(Origin,Root),STYLE_SOLID,clrSteelBlue);
    UpdateLine("oExpansion",pfractal.Price(Origin,Expansion),STYLE_SOLID,clrRed);
    UpdateLine("oRetrace",pfractal.Price(Origin,Retrace),STYLE_DOT,clrLightGray);
    
    pfractal.ShowFiboArrow();
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
    if (Command[0]=="SHOW")
      if (InStr(Command[1],"NONE"))
        display  = NoValue;
      else
      if (InStr(Command[1],"FIB"))
        display  = 0;
      else
      if (InStr(Command[1],"PIP"))
        display  = 1;
      else
      if (InStr(Command[1],"APP"))
        display  = 2;
      else
        display  = NoValue;  
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
    
    NewLine("oBase");
    NewLine("oRoot");
    NewLine("oExpansion");
    NewLine("oRetrace");
    
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