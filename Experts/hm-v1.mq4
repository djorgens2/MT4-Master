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
#include <Class/Fibonacci.mqh>

  CFibonacci       *fibo                = new CFibonacci(24);


//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string rsComment;
    
    rsComment   = "Fibo Term: (b) "+DoubleToStr(fibo[Term].Base,Digits)
                  +" (r) "+DoubleToStr(fibo[Term].Root,Digits)
                  +" (h) "+DoubleToStr(fibo[Term].High,Digits)
                  +" (l) "+DoubleToStr(fibo[Term].Low,Digits)+"\n";
                  
    rsComment   = "(TmLE) Now: "+DoubleToStr(fibo.Fibonacci(Term,Linear,Now,InPercent),2)
                  +"%  Expansion: "+DoubleToStr(fibo.Fibonacci(Term,Linear,Max,InPercent),2)
                  +"%  Retrace: "+DoubleToStr(fibo.Fibonacci(Term,Linear,Min,InPercent),2)+"%\n";
                  
    rsComment  += "(TmGE) Now: "+DoubleToStr(fibo.Fibonacci(Term,Geometric,Now,InPercent),2)
                  +"%  Expansion: "+DoubleToStr(fibo.Fibonacci(Term,Geometric,Max,InPercent),2)
                  +"%  Retrace: "+DoubleToStr(fibo.Fibonacci(Term,Geometric,Min,InPercent),2)+"%";

    Comment(rsComment);
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

//    RefreshScreen();
    
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
    delete fibo;
  }