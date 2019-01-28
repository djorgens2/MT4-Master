//+------------------------------------------------------------------+
//|                                                       man-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.41"
#property strict


#include <manual.mqh>
#include <Class\Fractal.mqh>

input string   EAHeader                = "";    //+---- Application Options -------+
  
input string   fractalHeader           = "";    //+------ Fractal Options ---------+
input int      inpRangeMin             = 60;    // Minimum fractal pip range
input int      inpRangeMax             = 120;   // Maximum fractal pip range
input int      inpPeriodsLT            = 240;   // Long term regression periods


  //--- Class Objects
  CFractal           *fractal          = new CFractal(inpRangeMax,inpRangeMin);

  double mRetrace                      = 0.00;
  double mMinor                        = 0.00;
  double mMajor                        = 0.00; 
  
//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    Pause(Message,"Event Trapper");
  }
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();

    if (fractal.IsMajor(fractal.State(Now)))
      mMajor                  = fractal.Price(fractal.State(Major),Fibo50);
    else
    if (fractal.IsMinor(fractal.State(Now)))
      mMinor                  = fractal.Price(fractal.State(Minor),Fibo50);
    else
      mRetrace                = fractal.Price(fractal.Next(fractal.State(Minor)),Fibo50);
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    //UpdateLine("mRetrace",mRetrace,STYLE_DOT,clrRed);
    //UpdateLine("mMinor",mMinor,STYLE_DASH,clrSteelBlue);
    //UpdateLine("mMajor",mMajor,STYLE_SOLID,clrGoldenrod);
//    UpdateLine("oTop",fractal.Price(Origin,Top),STYLE_DOT,clrRed);
//    UpdateLine("oBottom",fractal.Price(Origin,Bottom),STYLE_DASH,clrSteelBlue);
//    UpdateLine("oRetrace",fractal.Price(Origin,Retrace),STYLE_SOLID,clrGoldenrod);
      UpdateLine("fExpansion",fractal[Expansion].Price,STYLE_DOT,clrRed);
      UpdateLine("fRoot",BoolToDouble(fractal.Direction(Expansion)==DirectionUp,fractal.Price(Trend,Bottom),fractal.Price(Trend,Top)),STYLE_SOLID,clrSteelBlue);
      UpdateLine("fBase",fractal.Price(Trend,Previous),STYLE_DASH,clrGoldenrod);
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

    NewLine("mRetrace");
    NewLine("mMinor");
    NewLine("mMajor");
    
    NewLine("oTop");
    NewLine("oBottom");
    NewLine("oRetrace");
    
    NewLine("fBase");
    NewLine("fRoot");
    NewLine("fExpansion");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
  }