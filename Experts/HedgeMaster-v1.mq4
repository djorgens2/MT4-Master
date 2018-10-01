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
#include <Class\PipFractal.mqh>
#include <Class\Session.mqh>

input string   EAHeader                = "";    //+---- Application Options -------+
  
input string   fractalHeader           = "";    //+------ Fractal Options ---------+
input int      inpRangeMin             = 60;    // Minimum fractal pip range
input int      inpRangeMax             = 120;   // Maximum fractal pip range
input int      inpPeriodsLT            = 240;   // Long term regression periods

input string   RegressionHeader        = "";    //+------ Regression Options ------+
input int      inpDegree               = 6;     // Degree of poly regression
input int      inpSmoothFactor         = 3;     // MA Smoothing factor
input double   inpTolerance            = 0.5;   // Directional sensitivity
input int      inpPipPeriods           = 200;   // Trade analysis periods (PipMA)
input int      inpRegrPeriods          = 24;    // Trend analysis periods (RegrMA)

input string   SessionHeader           = "";    //+---- Session Hours -------+
input int      inpAsiaOpen             = 1;     // Asian market open hour
input int      inpAsiaClose            = 10;    // Asian market close hour
input int      inpEuropeOpen           = 8;     // Europe market open hour
input int      inpEuropeClose          = 18;    // Europe market close hour
input int      inpUSOpen               = 14;    // US market open hour
input int      inpUSClose              = 23;    // US market close hour


  //--- Class Objects
  CSession           *session[SessionTypes];
  CFractal           *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CEvent             *events                 = new CEvent();

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
    session[Daily].Update();
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
//    if (session[Daily].Event(SessionClose))
//      CallPause("Session Close");
//    if (session[Daily].Event(NewDay))
//      CallPause("NewDay");
    if (session[Daily].Event(MarketCorrection))
      CallPause("MarketCorrection");
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
    
    session[Daily]        = new CSession(Daily,inpAsiaOpen,inpUSClose);
    Print("Bad Trend Rec: "+DirText(session[Daily].Trend(NoValue).Direction)
                           +IntegerToString(session[Daily].Trend(NoValue).Age)
                           +EnumToString(session[Daily].Trend(NoValue).State)
                           +DoubleToStr(session[Daily].Trend(NoValue).Base,Digits)
                           +DoubleToStr(session[Daily].Trend(NoValue).Root,Digits)
                           +DoubleToStr(session[Daily].Trend(NoValue).Expansion,Digits));

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete session[Daily];
    
    delete fractal;
    delete pfractal;
    delete events;
    
//    for (SessionType type=Asia;type<SessionTypes;type++)
//      delete session[type];
  }