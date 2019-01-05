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
input int      inpIdleTrigger          = 50;    // Market idle trigger
  
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
  
  bool                PauseOn                = true;
    
  ActionProtocol      opProtocol;
  int                 pfPolyDir;
  double              pfPolyBounds[2];
  int                 fTrendAction;
  
  int                 dbDailyAction;
  int                 dbBoundsCount;
  int                 dbPriceZone;
  int                 dbUpperBound;
  int                 dbLowerBound;

  //--- Check Performance Operationals
  int                 cpTermDir              = DirectionNone;
  bool                cpTermFire             = false;
  int                 cpTermFibo             = NoValue;
  double              cpTermPivot[2]         = {NoValue,NoValue};
  
  int                 cpBiasDir              = DirectionNone;
  SignalType          cpBiasSignal           = Inactive;
  bool                cpBiasIdle             = false;
  bool                cpBiasFire             = false;
  int                 cpBiasOpenDir          = DirectionNone;
  int                 cpBiasCloseDir         = DirectionNone;
  double              cpBiasPivot[2]         = {NoValue,NoValue};

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
    events.ClearEvents();
        
    fractal.Update();
    pfractal.Update();
    
    pfractal.ShowFiboArrow();
    
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
    static int     rsIdx           = 0;
    static string  rsBiasFireName  = "";

    string         rsComment       = "Dir: "+DirText(cpTermDir)+"\n"
                                     + "Age: "+IntegerToString(pfractal.Age(Boundary))+"\n"
                                     + "Fibo ("+BoolToStr(pfractal.Direction(Trend)==DirectionUp,"^","v")+"): "+DoubleToStr(FiboPercent(cpTermFibo,InPercent),1)+"%\n"
                                     + "State: "+EnumToString((ReservedWords) pfractal.State());

    if (pfractal.Direction(Term)!=pfractal.Direction(Boundary))
      Append(rsComment,"Divergence","\n");
      
    if (pfractal.Direction(Range)!=pfractal.Direction(Boundary))
      Append(rsComment,"Reversal","\n");
      
    if (cpBiasIdle)
      Append(rsComment,"Idle: "+DoubleToStr(pfractal.Fibonacci(Term,Expansion,Now,InPercent),1)+"%","\n");

    if (cpTermFire)
      Append(rsComment,"Fire: "+DoubleToStr(pfractal.Fibonacci(Term,Expansion,Max,InPercent),1)+"%","\n");

//    UpdatePriceLabel("pfUpperBound",pfPolyBounds[OP_BUY],clrYellow);
//    UpdatePriceLabel("pfLowerBound",pfPolyBounds[OP_SELL],clrRed);
    UpdateDirection("lbActiveDir",pfPolyDir,DirColor(pfPolyDir),16);
    
    if (cpBiasSignal==Triggered)
    {
      rsBiasFireName            = "MarketIdle-"+IntegerToString(++rsIdx);
      NewPriceLabel(rsBiasFireName,Close[0],true);
      UpdatePriceLabel(rsBiasFireName,Close[0],DirColor(cpBiasOpenDir,clrForestGreen,clrFireBrick));
    }
    
    if (cpBiasFire)
      NewArrow(BoolToInt(cpBiasCloseDir==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
               BoolToInt(cpBiasCloseDir==DirectionUp,clrYellow,clrRed),
               EnumToString(cpBiasSignal)+"-"+IntegerToString(rsIdx));
    
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

    Comment(rsComment);
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
//| BalanceCheck - validate open positions & margin requirements     |
//+------------------------------------------------------------------+
void BalanceCheck(void)
  {
    CallPause("Auto balance open positions");
  }

//+------------------------------------------------------------------+
//| SendOrder - verifies margin requirements and opens new positions |
//+------------------------------------------------------------------+
void SendOrder(int Direction, bool Contrarian)
  {
    int    soAction     = Action(Direction,InDirection,Contrarian);
    bool   soOpenOrder  = false;
    string soFibo       = " "+DoubleToStr(pfractal.Fibonacci(Term,Expansion,Now,InPercent),1)+"%";
    
    if (LotCount(soAction)==0.00)
      soOpenOrder       = true;
    else
      if (fabs(LotValue(soAction,Smallest,InEquity))>ordEQMinProfit)
        soOpenOrder     = true;
        
    if (soOpenOrder)
    {
      OpenOrder(soAction,BoolToStr(Contrarian,"Contrarian"+soFibo,"Trend"+soFibo));
      CallPause("New Order entry");
    }
  }


//+------------------------------------------------------------------+
//| CheckPerformance - verifies that the trade plan is working       |
//+------------------------------------------------------------------+
void CheckPerformance(void)
  {
    static bool cpExcessiveIdle        = false;
    
    cpBiasFire                  = false;

    if (pfractal.Fibonacci(Term,Expansion,Now)>FiboPercent(Fibo100))
    {
      if (FiboLevel(pfractal.Fibonacci(Term,Expansion,Now)>cpTermFibo))
      {
        cpTermFire              = true;
        events.SetEvent(NewFractal);
      }

      if (IsChanged(cpTermDir,pfractal.Direction(Trend)))
      {
        cpTermFire              = true;
        events.SetEvent(NewTerm);
      }
        
      if (cpTermFire)
      {
        cpTermFibo              = FiboLevel(pfractal.Fibonacci(Term,Expansion,Now));
      }
    }

    if (cpTermFire)
    {
      //Pause("Fibo "+DoubleToStr(pfractal.Fibonacci(Term,Expansion,Now,InPercent),1)+"%","Fibo Expansion");
      cpTermFire                = false;
    }
      
    if (fmod(pfractal.Age(Boundary),inpIdleTrigger)==0.00)
      if (fdiv(pfractal.Age(Boundary),inpIdleTrigger)>1)
      {
        if (!cpExcessiveIdle)
        {
          CallPause("Excessive idle event, take action?");
          cpExcessiveIdle       = true;
        }
        
        cpBiasSignal            = Idle;
      }
      else
      if (cpBiasIdle)
        cpBiasSignal            = Waiting;
      else
      {          
        if (pfractal.Fibonacci(Term,Expansion,Now)>FiboPercent(Fibo100))
          SendOrder(cpBiasOpenDir,InContrarian);
        else
          CallPause("Trend action");
            
        cpBiasIdle              = true;
        cpBiasSignal            = Triggered;
        
        CallPause("The market is idle");
        events.SetEvent(MarketIdle);
      }
    else
      if (cpBiasIdle)
      {
        cpBiasSignal            = Waiting;
        cpExcessiveIdle         = false;
      
        if (pfractal.Event(NewBoundary))
        {
          if (pfractal.Event(NewHigh))
            cpBiasCloseDir      = DirectionUp;

          if (pfractal.Event(NewLow))
            cpBiasCloseDir      = DirectionDown;
          
          if (cpBiasCloseDir==cpBiasOpenDir)
            cpBiasSignal        = Confirmed;
          else  
            cpBiasSignal        = Rejected;

          CallPause("Time to act");

          cpBiasIdle            = false;
          cpBiasFire            = true;

          BalanceCheck();
          events.SetEvent(MarketResume);
        }
      }

    if (pfractal.Event(NewHigh))
      cpBiasOpenDir               = DirectionUp;

    if (pfractal.Event(NewLow))
      cpBiasOpenDir               = DirectionDown;
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

    if (pfractal.HistoryLoaded())
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
    if (Command[0]=="PAUSE")
      if (PauseOn)
        PauseOn    = false;
      else
        PauseOn    = true;
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