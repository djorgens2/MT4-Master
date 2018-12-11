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
input string appHeader          = "";    //+------ Application inputs ------+
//input int    inpShowLines       = 120;   // Maximum fractal pip range
//input int    inpRangeMin        = 60;    // Minimum fractal pip range

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

int hmShowLineType              = NoValue;

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
  
    switch (hmShowLineType)
    {
      case Term:       UpdateLine("pfBase",pfractal[Term].Base,STYLE_DASH,clrGoldenrod);
                       UpdateLine("pfRoot",pfractal[Term].Root,STYLE_DASH,clrSteelBlue);
                       UpdateLine("pfExpansion",pfractal[Term].Expansion,STYLE_DASH,clrFireBrick);
                       break;
      
      case Trend:      UpdateLine("pfBase",pfractal[Trend].Base,STYLE_SOLID,clrGoldenrod);
                       UpdateLine("pfRoot",pfractal[Trend].Root,STYLE_SOLID,clrSteelBlue);
                       UpdateLine("pfExpansion",pfractal[Trend].Expansion,STYLE_SOLID,clrFireBrick);
                       break;
                       
      case Origin:     UpdateLine("pfBase",pfractal.Price(Origin,Base),STYLE_DOT,clrGoldenrod);
                       UpdateLine("pfRoot",pfractal.Price(Origin,Root),STYLE_DOT,clrSteelBlue);
                       UpdateLine("pfExpansion",pfractal.Price(Origin,Expansion),STYLE_DOT,clrFireBrick);
                       break;

      default:         UpdateLine("pfBase",0.00,STYLE_DOT,clrNONE);
                       UpdateLine("pfRoot",0.00,STYLE_DOT,clrNONE);
                       UpdateLine("pfExpansionSQL",0.00,STYLE_DOT,clrNONE);
                       break;
    }

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
    if (Command[0] == "SHOW")
      if (Command[1] == "LINE")
      {
         hmShowLineType    = NoValue;

         if (Command[2] == "ORIGIN")
           hmShowLineType    = Origin;

         if (Command[2] == "TREND")
           hmShowLineType    = Trend;

         if (Command[2] == "TERM")
           hmShowLineType    = Term;
      }
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

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pfractal;
    delete fractal;   
  }