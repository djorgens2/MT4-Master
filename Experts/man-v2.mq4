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
  CEvent             *events                 = new CEvent();

  CArrayDouble       *dbBounds               = new CArrayDouble(6);
  CSessionArray      *leadSession;
  
  //--- Enum Defs
  enum ActionProtocol {
                        NoProtocol,
                        CoverBreakout,
                        CoverReversal,
                        Hedging,
                        PullbackEntry,
                        RallyEntry,
                        DCAExit,
                        LossExit,
                        ActionProtocols
                      };
    
  ActionProtocol      opProtocol;
  int                 pfPolyDir;
  double              pfPolyBounds[2];
  int                 fTrendAction;
  
  int                 dbDailyAction;
  int                 dbBoundsCount;
  int                 dbPriceZone;
  int                 dbUpperBound;
  int                 dbLowerBound;

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
//    Pause(Message,"Event Trapper");
  }
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    events.ClearEvents();
        
    fractal.Update();
    pfractal.Update();
    
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
      if (type<Daily)
        if (session[type].IsOpen())
          leadSession    = session[type];
    }
    
    if (pfractal.HistoryLoaded())
    {
     if (pfractal.Event(NewHigh))
       if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)))
         if (IsChanged(pfPolyDir,DirectionUp))
           pfPolyBounds[OP_BUY]=High[0];
         
     if (pfractal.Event(NewLow))
       if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
         if (IsChanged(pfPolyDir,DirectionDown))
           pfPolyBounds[OP_SELL]=Low[0];
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdatePriceLabel("pfUpperBound",pfPolyBounds[OP_BUY],clrYellow);
    UpdatePriceLabel("pfLowerBound",pfPolyBounds[OP_SELL],clrRed);
    UpdateDirection("lbActiveDir",pfPolyDir,DirColor(pfPolyDir),16);
    
    //for (int bound=0;bound<6;bound++)
    //  if (dbPriceZone==0 || dbPriceZone==dbBoundsCount)
    //    UpdateLine("dbBounds"+IntegerToString(bound),dbBounds[bound],STYLE_SOLID,clrGoldenrod);
    //  else
    //  if (bound==dbUpperBound)
    //    UpdateLine("dbBounds"+IntegerToString(bound),dbBounds[bound],STYLE_DOT,clrForestGreen);
    //  else
    //  if (bound==dbLowerBound)
    //    UpdateLine("dbBounds"+IntegerToString(bound),dbBounds[bound],STYLE_DOT,clrFireBrick);
    //  else
    //  if (bound==dbPriceZone)
    //    UpdateLine("dbBounds"+IntegerToString(bound),dbBounds[bound],STYLE_DOT,clrGoldenrod);
    //  else
    //    UpdateLine("dbBounds"+IntegerToString(bound),dbBounds[bound],STYLE_DOT,clrDarkGray);
  }

//+------------------------------------------------------------------+
//| SetTrend - Signals short term/long term trend                    |
//+------------------------------------------------------------------+
void SetTrend(ActionProtocol Protocol, int Direction)
  {
    opProtocol     = Protocol;
    
    switch (Protocol)
    {
      default:        /* do something */;
    }
     
    UpdateLabel("lbStrategy",EnumToString(Protocol),clrGoldenrod,24);    
  }
  
//+------------------------------------------------------------------+
//| SetDailyAction - sets the trend hold/hedge parameters            |
//+------------------------------------------------------------------+
void SetDailyAction(void)
  {  
    dbBoundsCount        = 0;
    
    //--- Set Daily Bias and Limits
    dbDailyAction        = Action(session[Daily].TradeBias(),InDirection);

    dbBounds.Initialize(NoValue);

    for (SessionType type=Asia;type<Daily;type++)
    {
      if (dbBounds.Find(session[type].History(0).TermHigh)==NoValue)
        dbBounds.SetValue(dbBoundsCount++,session[type].History(0).TermHigh);

      if (dbBounds.Find(session[type].History(0).TermLow)==NoValue)
        dbBounds.SetValue(dbBoundsCount++,session[type].History(0).TermLow);
    }
    
    dbBounds.Sort(0,dbBoundsCount-1);
        
    for (dbPriceZone=0;dbPriceZone<6;dbPriceZone++)
      if (Close[0]<dbBounds[dbPriceZone])
        break;

    dbUpperBound        = dbPriceZone;
    dbLowerBound        = --dbPriceZone-1;
    
      
    Print("PZ: "+IntegerToString(dbPriceZone)+" Close: "+DoubleToStr(Close[0],Digits));
    //--- Set Fractal Direction and Limits
    
    //--- Set Hedging Indicator and Limits
  }


//+------------------------------------------------------------------+
//| CheckPerformance - verifies that the trade plan is working       |
//+------------------------------------------------------------------+
void CheckPerformance(void)
  {
    static int  cpDir   = DirectionNone;
    static int  cpIdx   = 0;
    static bool cpFire  = false;
    static bool cpScan  = false;
    static int  cpFibo  = NoValue;

    if (pfractal.Fibonacci(Term,Expansion,Now)>FiboPercent(Fibo100))
    {
      if (IsChanged(cpFibo,FiboLevel(pfractal.Fibonacci(Term,Expansion,Now)>FiboPercent(Fibo100))))
        cpScan          = true;

      if (IsChanged(cpDir,pfractal.Direction(Trend)))
        cpScan          = true;
    }

//    if (cpScan)
    if (pfractal.Age(Boundary)==50)
    {
      if (!cpFire)
        {
          cpFire            = true;
          NewPriceLabel("Boundary"+IntegerToString(cpIdx++),Close[0],true);
        }
    }
    else
      if (cpFire)
      {
        {
          if (pfractal.Event(NewHigh))
            NewArrow(SYMBOL_ARROWUP,clrYellow,"Breakout"+IntegerToString(cpIdx++));

          if (pfractal.Event(NewLow))
            NewArrow(SYMBOL_ARROWDOWN,clrRed,"Breakout"+IntegerToString(cpIdx++));
          
          if (pfractal.Event(NewBoundary))
          {
            Pause("Time to act","trigger");
            cpFire            = false;
            cpScan            = false;
          }
        }
      }
      
    Comment("Age: "+IntegerToString(pfractal.Age(Boundary)));
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (session[Daily].Event(SessionOpen))
      SetDailyAction();
      
    if (leadSession.Event(SessionOpen))
      CallPause("Lead session open: "+EnumToString(leadSession.Type()));

    CheckPerformance();
    
    switch (opProtocol)
    {
      case NoProtocol:  break;
    }
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
    
    session[Daily]        = new CSessionArray(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]         = new CSessionArray(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]       = new CSessionArray(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]           = new CSessionArray(US,inpUSOpen,inpUSClose);
    
    leadSession           = session[Daily];
    
    NewLabel("lbStrategy","Scalper",1200,5,clrDarkGray);
    NewLabel("lbActiveDir","",1175,5,clrDarkGray);
    NewPriceLabel("pfUpperBound");
    NewPriceLabel("pfLowerBound");

    for (int x=0;x<6;x++)
      NewLine("dbBounds"+IntegerToString(x));

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete events;
    delete dbBounds;
    
    ObjectDelete("mvUpperBound");
    ObjectDelete("mvLowerBound");
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
      
    for (int x=0;x<6;x++)
      ObjectDelete("dbBounds"+IntegerToString(x));
  }