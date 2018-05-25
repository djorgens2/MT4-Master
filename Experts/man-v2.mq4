//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\SessionArray.mqh>

input string   EAHeader                = "";    //+---- Application Options -------+
input double   inpDailyTarget          = 3.6;   // Daily target
input int      inpMaxMargin            = 40;    // Maximum trade margin (volume)
  
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
  CSessionArray      *session[SessionTypes];
  CFractal           *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  
  OnOffType           mvScalper        = Off;

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void SetScalper(OnOffType Switch)
  {
    mvScalper = Switch;

    if (mvScalper==On)
      UpdateLabel("lbScalper","Scalper",clrLawnGreen,24);

    if (mvScalper==Off)
      UpdateLabel("lbScalper","Scalper",clrDarkGray,24);
  }
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();
    
    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      session[type].Update();
      
//      if (session[type].ActiveEvent())
//      {
//        udActiveEvent    = true;
//
//        for (EventType event=0;event<EventTypes;event++)
//          if (session[type].Event(event))
//            udEvent.SetEvent(event);
//      }
//            
//      if (type<Daily)
//        if (session[type].SessionIsOpen())
//          udLeadSession    = type;
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
  }

//+------------------------------------------------------------------+
//| SetupTradePlan                                                   |
//+------------------------------------------------------------------+
void SetupTradePlan(void)
  {
  }

//+------------------------------------------------------------------+
//| UpdateStrategy                                                   |
//+------------------------------------------------------------------+
void UpdateStrategy(void)
  {
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void CheckPerformance(void)
  {
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int gdHour  = 0;
    
    if (IsChanged(gdHour,TimeHour(Time[0])))
    {
      if (gdHour==inpAsiaOpen)
        SetupTradePlan();
        
      UpdateStrategy();
    }

    CheckPerformance();  
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="SCALP" || Command[0]=="SCALPER" || Command[0]=="SC")
    {
      if (Command[1]=="ON")
        SetScalper(On);
      if (Command[1]=="OFF")
        SetScalper(Off);
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
    
    session[Daily]        = new CSessionArray(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]         = new CSessionArray(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]       = new CSessionArray(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]           = new CSessionArray(US,inpUSOpen,inpUSClose);
    
    NewLabel("lbScalper","Scalper",1200,5,clrDarkGray);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }