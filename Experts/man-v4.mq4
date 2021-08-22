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
#include <Class\Fractal.mqh>

input string    EAHeader                = "";    //+---- Application Options -------+
input int       inpIdleTrigger          = 50;    // Market idle trigger
input int       inpEQChgPct             = 2;     // Lead order equity% change event
input YesNoType inpShowPolyArrows       = No;    // Show poly direction change arrows
  
input string    fractalHeader           = "";    //+------ Fractal Options ---------+
input int       inpRangeMin             = 60;    // Minimum fractal pip range
input int       inpRangeMax             = 120;   // Maximum fractal pip range

  //--- Class Objects
  CFractal      *f                      = new CFractal(inpRangeMax,inpRangeMin);
  
  //--- Application behavior switches
  bool           PauseOn                = true;

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
    f.Update();
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text  = "\n";
    
    for (FractalType type=Origin;type<FractalTypes;type++)
    {
      Append(text,f.FractalStr());
      Append(text,f.PriceStr());
      Append(text,"Fibonacci (e)"+DoubleToStr(f.Fibonacci(type,Expansion,Min,InPercent),1));
      Append(text,DoubleToStr(f.Fibonacci(type,Expansion,Max,InPercent),1),";");
      Append(text,DoubleToStr(f.Fibonacci(type,Expansion,Now,InPercent),1),";");
      Append(text,"(rt)"+DoubleToStr(f.Fibonacci(type,Retrace,Min,InPercent),1),";");
      Append(text,DoubleToStr(f.Fibonacci(type,Retrace,Max,InPercent),1),";");
      Append(text,DoubleToStr(f.Fibonacci(type,Retrace,Now,InPercent),1),";");
    }
    
    Comment(text);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    #define format InPercent
    
    double Points[FractalPoints];
    
    f.FractalPoints(Origin,Points);
    
    Print(fdiv(Points[fpRetrace]-Points[fpRoot],(Points[fpBase]-Points[fpRoot]))*BoolToInt(format==InDecimal,1,100));
    Print(f.Fibonacci(Origin,Expansion,Min,InPercent));

    
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
    delete f;
  }