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
input double   inpDailyTarget          = 25;   // Daily target
input int      inpMaxMargin            = 60;    // Maximum trade margin (volume)
  
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

  //--- Records
  struct OpenOrderRec
  {
    int               Action;
    int               Ticket;
    double            Lots;
    double            Margin;
    double            MaxEquity;
    double            MinEquity;
    int               EquityDir;
    EventType         EquityEvent;
  };

  //--- Class Objects
  CSessionArray      *session[SessionTypes];
  CFractal           *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CEvent             *events                 = new CEvent();
  
  OnOffType           mvScalper              = Off;
  bool                mvAlert                = false;
  double              mvAlertPrice           = 0.00;
  int                 mvAlertDir             = DirectionNone;

  
  SessionType         mvLeadSession;
  ReservedWords       mvStrategy;
  double              mvActiveBounds[2];
  int                 mvActiveDir            = DirectionNone;

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    Pause(Message,"Event Trapper");
  }
  
//+------------------------------------------------------------------+
//| CallAlert - Alerts and resets                                    |
//+------------------------------------------------------------------+
void CallAlert(void)
  {
    Pause("Price Target Hit","Price Alert");
    mvAlert           = false;
    mvAlertPrice      = 0.00;
    mvAlertDir        = DirectionNone;
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
        if (session[type].SessionIsOpen())
          mvLeadSession    = type;
    }
    
    if (pfractal.HistoryLoaded())
    {
     if (pfractal.Event(NewHigh))
       if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)))
         if (IsChanged(mvActiveDir,DirectionUp))
         {
           mvActiveBounds[OP_BUY]=High[0];
//           CallPause("New pipMA poly up");
         }
         
     if (pfractal.Event(NewLow))
       if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
         if (IsChanged(mvActiveDir,DirectionDown))
         {
           mvActiveBounds[OP_SELL]=Low[0];
//           CallPause("New pipMA poly down");
         }
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdatePriceLabel("mvUpperBound",mvActiveBounds[OP_BUY],clrYellow);
    UpdatePriceLabel("mvLowerBound",mvActiveBounds[OP_SELL],clrRed);
    UpdateDirection("lbActiveDir",mvActiveDir,DirColor(mvActiveDir),16);
  }

//+------------------------------------------------------------------+
//| SetScalper - Signals Scalping begin/end                          |
//+------------------------------------------------------------------+
void SetScalper(OnOffType Switch)
  {
    mvScalper = Switch;

    if (mvScalper==On)
      CallPause("Scalper Enabled");
  }

//+------------------------------------------------------------------+
//| SetAlert - Sets an alert for the supplied target price           |
//+------------------------------------------------------------------+
void SetAlert(double Target)
  {
    mvAlert       = true;
    mvAlertPrice  = Target;
    mvAlertDir    = DirectionDown;
    
    if (IsHigher(Bid,Target,NoUpdate))
      mvAlertDir  = DirectionUp;
      
  }

//+------------------------------------------------------------------+
//| SetTrend - Signals short term/long term trend                    |
//+------------------------------------------------------------------+
void SetTrend(ReservedWords Strategy, int Direction)
  {
    mvStrategy     = Strategy;
    
    switch (Strategy)
    {
      default:        /* do something */;
    }
     
    UpdateLabel("lbScalper",EnumToString(Strategy),BoolToInt(mvScalper==On,clrGoldenrod,DirColor(Direction)),24);    
  }
  
//+------------------------------------------------------------------+
//| SetTradePlan                                                     |
//+------------------------------------------------------------------+
void SetTradePlan(void)
  {  
    if (fractal.State(Major)==Expansion)
    {
      //-- Set up for trend
      if (fractal.IsBreakout(Expansion))
        SetTrend(Breakout,fractal[Expansion].Direction);
        
      if (fractal.IsReversal(Expansion))
        SetTrend(Reversal,fractal[Expansion].Direction);
    }
    else
    if (fractal.Fibonacci(Divergent,Expansion,Max)>1-FiboPercent(Fibo23))
    {
      //--- Set up for Reversal
      SetTrend(Correction,Direction(fractal[fractal.State(Major)].Direction));
    }
    else
    if (fractal.Fibonacci(Convergent,Expansion,Max)>1-(FiboPercent(Fibo23)))
    {
      //--- Set up for Trend Continuation
      SetTrend(Continuation,Direction(fractal[fractal.State(Major)].Direction));
    }
    else
    {
      //--- Set up for Convergence/Divergence
      SetTrend(Contrarian,Direction(fractal[fractal.State(Major)].Direction,InContrarian));
    }
    
    //--- Set up for scalping
    if (fractal.State(Major)==fractal.State(Minor))
      SetScalper(Off);
    else
      SetScalper(On);
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void CheckPerformance(void)
  {
    if (IsHigher(High[0],mvActiveBounds[OP_BUY]))
      events.SetEvent(NewHigh);
         
    if (IsLower(Low[0],mvActiveBounds[OP_SELL]))
      events.SetEvent(NewLow);    
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void ExecuteScalper(void)
  {
    static bool esTrigger     = false;
    
    if (pfractal.HistoryLoaded())
    {
      if (events[NewHigh] || events[NewLow])
        esTrigger               = true;
      
      if (esTrigger)
      {
        if (pfractal.Direction(Polyline)!=mvActiveDir)
          //if (mvTradeAction==Action(mvActiveDir))
          {
//            CallPause("Order!");
//            OpenOrder(Action(mvActiveDir),"Scalper");
          }

        if (OrderFulfilled(Action(mvActiveDir)))
          esTrigger             = false;
      }
    }
    
    UpdateLabel("lbScalper",EnumToString(mvStrategy),BoolToInt(esTrigger,clrGoldenrod,DirColor(mvActiveDir)),24);    
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
        SetTradePlan();
      
      if (gdHour==4||gdHour==11||gdHour==17)
        CallPause("Mid-Session Reversal or Profit Taking");
    }

    CheckPerformance();
    
    if (mvAlert)
    {
      if (mvAlertDir==DirectionUp)
        if (IsHigher(Bid,mvAlertPrice,NoUpdate))
          CallAlert();

      if (mvAlertDir==DirectionDown)
        if (IsLower(Bid,mvAlertPrice,NoUpdate))
          CallAlert();
    }
        
    switch (mvStrategy)
    {
      case Scalp:  ExecuteScalper();
                   break;
    }
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
    
    if (Command[0]=="ALERT")
      SetAlert(StrToDouble(Command[1]));

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
    NewLabel("lbActiveDir","",1175,5,clrDarkGray);
    NewPriceLabel("mvUpperBound");
    NewPriceLabel("mvLowerBound");

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
    
    ObjectDelete("mvUpperBound");
    ObjectDelete("mvLowerBound");
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }