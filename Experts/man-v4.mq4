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
#include <Class\PipFractal.mqh>
#include <Class\Sessions.mqh>

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
  CSessions          *session[SessionTypes];
  CFractal           *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CEvent             *events                 = new CEvent();

  CArrayDouble       *sbounds                = new CArrayDouble(6);
  CSessions          *leadSession;
  
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
  int                 pfPolyAction;
  int                 pfPolyDir;
  double              pfPolyBounds[2];
  int                 fTrendAction;
  
  int                 dbAction;
  int                 dbDir;
  int                 dbCount;
  int                 dbZone;
  int                 dbUpper;
  int                 dbLower;
  

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
    pfractal.Update();
    
    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      session[type].Update();

      if (type<Daily)
        if (session[type].IsOpen())
          leadSession    = session[type];
    }    
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdatePriceLabel("pfUpperBound",pfPolyBounds[OP_BUY],clrYellow);
    UpdatePriceLabel("pfLowerBound",pfPolyBounds[OP_SELL],clrRed);
    
//    NewLabel("lbFAction","",560,27,clrDarkGray);
//    NewLabel("lbFDir","",540,27,clrDarkGray);
//    NewLabel("lbPFAction","",560,38,clrDarkGray);
//    NewLabel("lbPFDir","",540,38,clrDarkGray);
    
    UpdateDirection("lbDBDir",dbDir,DirColor(dbDir),16);
    UpdateLabel("lbDBAction",ActionText(dbAction)+" ("+IntegerToString(dbZone)+")",clrGoldenrod,16);
    UpdateDirection("lbPolyDir",pfPolyDir,DirColor(pfPolyDir),16);
    UpdateLabel("lbPolyAction",ActionText(pfPolyAction),DirColor(pfPolyDir),16);

    UpdateLabel("lbStrategy",ActionText(dbAction)+" ("+IntegerToString(dbZone)+")",clrGoldenrod,24);
    
/*    
    for (int bound=0;bound<dbCount;bound++)
      if (dbZone==NoValue&&bound==0)  //--- Breakout lower
        UpdateLine("sbounds"+IntegerToString(bound),sbounds[bound],STYLE_SOLID,clrFireBrick);
      else
      if (dbZone==dbCount&&bound==dbZone)
        UpdateLine("sbounds"+IntegerToString(bound),sbounds[bound],STYLE_SOLID,clrForestGreen);
      else
      {
        if (bound==dbZone)
          UpdateLine("sbounds"+IntegerToString(bound),sbounds[bound],STYLE_DOT,clrAzure);
        else
        if (bound==dbUpper)
          UpdateLine("sbounds"+IntegerToString(bound),sbounds[bound],STYLE_DOT,clrForestGreen);
        else
        if (bound==dbLower)
          UpdateLine("sbounds"+IntegerToString(bound),sbounds[bound],STYLE_DOT,clrFireBrick);
        else
          UpdateLine("sbounds"+IntegerToString(bound),sbounds[bound],STYLE_DOT,clrDarkGray);
      }
*/
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
     
  }

//+------------------------------------------------------------------+
//| SetSessionLimits - Updates the price limits based on actual      |
//+------------------------------------------------------------------+
void SetSessionLimits(void)
  {
//    CallPause("Lead session open: "+EnumToString(leadSession.Type()));
  }
  
//+------------------------------------------------------------------+
//| SetDailyAction - sets the trend hold/hedge parameters            |
//+------------------------------------------------------------------+
void SetDailyAction(void)
  {  
    dbCount             = 0;
    
    //--- Set Daily Bias and Limits
    dbAction            = session[Daily].TradeBias();

    sbounds.Initialize(NoValue);

    for (SessionType type=Asia;type<Daily;type++)
    {
      if (sbounds.Find(session[type].History(0).TermHigh)==NoValue)
        sbounds.SetValue(dbCount++,session[type].History(0).TermHigh);

      if (sbounds.Find(session[type].History(0).TermLow)==NoValue)
        sbounds.SetValue(dbCount++,session[type].History(0).TermLow);
    }
    
    sbounds.Sort(0,dbCount-1);
    
    for (dbZone=0;dbZone<6;dbZone++)
      if (sbounds[dbZone]>Close[0])
        break;

    dbUpper             = dbZone--;
    dbLower             = dbZone-1;
    
    //--- Set Fractal Direction and Limits
    
    //--- Set Hedging Indicator and Limits
  }

//+------------------------------------------------------------------+
//| SetEvents - analyzes price action and sets alerts                |
//+------------------------------------------------------------------+
void SetEvents(void)
  {
    string seEvents     = TimeToStr(Time[0])+"\n";
    string seEventsTerm = "";
         
    events.ClearEvents();

    for (SessionType type=Asia;type<SessionTypes;type++)
      if (session[type].ActiveEvent())
      {
        seEvents    += "\n"+EnumToString(session[type].Type());
        
        if (session[type]==leadSession)
          Append(seEvents,"Lead");
        else
          Append(seEvents,BoolToStr(session[type].IsOpen(),"Open","Closed"));
          
        Append(seEvents,EnumToString(session[type].State(Term))+"\n");
          
        for (EventType event=0;event<EventTypes;event++)
          if (session[type].Event()[event])
          {
            events.SetEvent(event);
            
            if (event!=NewTerm)
              seEvents += "  "+EnumToString(event)+"\n";
          }
          
        if (session[type].Event()[NewTerm])
        {
          seEventsTerm    = "\n  ***Term("+EnumToString(type)+")***\n";
          
          for (EventType event=0;event<EventTypes;event++)
            if (session[type].Event(Term)[event])
              seEventsTerm += "    "+EnumToString(event)+"\n";
              
          seEvents += seEventsTerm;
        }
      }

    if (pfractal.HistoryLoaded())
    {
     if (pfractal.Event(NewHigh))
       if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)))
         if (IsChanged(pfPolyDir,DirectionUp))
         {
           pfPolyBounds[OP_BUY]=High[0];
           events.SetEvent(NewRally);
         }
         
     if (pfractal.Event(NewLow))
       if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
         if (IsChanged(pfPolyDir,DirectionDown))
         {
           pfPolyBounds[OP_SELL]=Low[0];
           events.SetEvent(NewPullback);
         }
    }

    if (events.ActiveEvent())
      CallPause(seEvents);
        
    if (IsHigher(High[0],pfPolyBounds[OP_BUY]))
      events.SetEvent(NewHigh);
         
    if (IsLower(Low[0],pfPolyBounds[OP_SELL]))
      events.SetEvent(NewLow);      
  }

//+------------------------------------------------------------------+
//| ManageTrades - opens trades based on alerts received             |
//+------------------------------------------------------------------+
void ManageTrades(int Action)
  {
  }

//+------------------------------------------------------------------+
//| ManageProfit - Takes profit based on alerts received             |
//+------------------------------------------------------------------+
void ManageProfit(int Action)
  {
  }

//+------------------------------------------------------------------+
//| ManageRisk - Manages Risk, dollar cost averaging, hedging        |
//+------------------------------------------------------------------+
void ManageRisk(int Action)
  {
  }

//+------------------------------------------------------------------+
//| ProcessActionEvent - Manages positional open/close events        |
//+------------------------------------------------------------------+
void ProcessActionEvent(int Action)
  {
    ManageTrades(Action);
    ManageProfit(Action);
    ManageRisk(Action);
    
    //-- CheckPerformance
    // ...
  }

//+------------------------------------------------------------------+
//| ProcessSessionEvent - Manages session level events               |
//+------------------------------------------------------------------+
void ProcessSessionEvent(CSessions &Session)
  {
  }

//+------------------------------------------------------------------+
//| ProcessFractalEvent - Manages fractal event (long-term)          |
//+------------------------------------------------------------------+
void ProcessFractalEvent(void)
  {
  }

//+------------------------------------------------------------------+
//| ProcessPipFractalEvent - Manages fractal event (short-term)      |
//+------------------------------------------------------------------+
void ProcessPipFractalEvent(void)
  {
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    SetEvents();
    
    if (events[SessionOpen])
    {
      if (session[Daily].Event(SessionOpen))
        SetDailyAction();

      SetSessionLimits();      
    }
      
    if (events[NewRally])
      ProcessActionEvent(OP_BUY);
    else
    if (events[NewPullback])
      ProcessActionEvent(OP_SELL);
    else
    {
      for (SessionType type=Asia;type<SessionTypes;type++)
        if (session[type].ActiveEvent())
          for (EventType event=0;event<EventTypes;event++)
            ProcessSessionEvent(session[type]);

      if (fractal.ActiveEvent())
        ProcessFractalEvent();
          
      if (pfractal.ActiveEvent())
        ProcessPipFractalEvent();
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
    
    session[Daily]        = new CSessions(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]         = new CSessions(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]       = new CSessions(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]           = new CSessions(US,inpUSOpen,inpUSClose);
    
    leadSession           = session[Daily];
    
    NewLabel("lbDBAction","",560,5,clrDarkGray);
    NewLabel("lbDBDir","",540,5,clrDarkGray);
    NewLabel("lbPolyAction","",560,25,clrDarkGray);
    NewLabel("lbPolyDir","",540,25,clrDarkGray);
    NewLabel("lbFAction","",560,35,clrDarkGray);
    NewLabel("lbFDir","",540,35,clrDarkGray);
    NewLabel("lbPFAction","",560,45,clrDarkGray);
    NewLabel("lbPFDir","",540,45,clrDarkGray);

    NewPriceLabel("pfUpperBound");
    NewPriceLabel("pfLowerBound");

    for (int x=0;x<6;x++)
      NewLine("sbounds"+IntegerToString(x));

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
    delete sbounds;
    
    ObjectDelete("pfUpperBound");
    ObjectDelete("pfLowerBound");
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
      
    for (int x=0;x<6;x++)
      ObjectDelete("sbounds"+IntegerToString(x));
  }