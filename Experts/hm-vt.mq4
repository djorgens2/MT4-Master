//+------------------------------------------------------------------+
//|                                                        hm-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\Session.mqh>

//--- Input params
input string    appHeader          = "";    //+------ Application inputs ------+
input int       inpMarketIdle      = 50;    // Market Idle Alert (pipMA periods)
input bool      inpShowFiboArrow   = true;  // Display PipMA fibonacci arrows
input int       inpDailyTarget     = 12;    // Daily Target In Percentage

input string    PipMAHeader        = "";    //+------ PipMA inputs ------+
input int       inpDegree          = 6;     // Degree of poly regression
input int       inpPeriods         = 200;   // Number of poly regression periods
input double    inpTolerance       = 0.5;   // Trend change tolerance (sensitivity)
input int       inpIdleTime        = 50;    // Market idle time in Pips

input string    fractalHeader      = "";    //+------ Fractal inputs ------+
input int       inpFractalRange    = 60;    // Fractal test range in Pips

input string    SessionHeader      = "";    //+---- Session Hours -------+
input int       inpAsiaOpen        = 1;     // Asian market open hour
input int       inpAsiaClose       = 10;    // Asian market close hour
input int       inpEuropeOpen      = 8;     // Europe market open hour
input int       inpEuropeClose     = 18;    // Europe market close hour
input int       inpUSOpen          = 14;    // US market open hour
input int       inpUSClose         = 23;    // US market close hour


//--- Class defs
  CFractal     *fractal            = new CFractal(inpFractalRange*2,inpFractalRange);
  CPipFractal  *pfractal           = new CPipFractal(inpDegree,inpPeriods,inpTolerance,inpIdleTime,fractal);

  CSession     *session[SessionTypes];
  CSession     *leadSession;
  
  ReservedWords EventClass[WordCount];
  EventType     EventAlert[EventTypes];
  
  struct        hmEventRec
                {
                  ReservedWords  Class;
                  EventType      Event;
                  int            Action;
                  bool           Active;
                  datetime       EventTime;
                };
 
  EventType     EventLock          = NoEvent;
  string        hmIndicator[3]     = {"PIPFRACTAL","FRACTAL","SESSION"};
  bool          hmMonitor[3]         = {true,true,true};
  hmEventRec    hmEvent[3];

  //-- Operationals                   
  int           pfPolyDir          = DirectionNone;
  double        fMajor             = 0.00;
  double        fMinor             = 0.00;
  double        fRetrace           = 0.00;

  int           hmOrderAction      = OP_NO_ACTION;
  string        hmOrderReason      = "";

//+------------------------------------------------------------------+
//| WordFound - validates reserved words and returns the enum id     |
//+------------------------------------------------------------------+
bool WordFound(string Name, ReservedWords &WordCode)
  {
    WordCode              = NoValue;
    
    for (ReservedWords word=0;word<WordCount;word++)
      if (upper(EnumToString(word))==Name)
      {
        WordCode          = word;
        return (true);
      }

    return (false);
  }

//+------------------------------------------------------------------+
//| EventFound - validates event type and returns the enum id        |
//+------------------------------------------------------------------+
bool EventFound(string Name, EventType &EventCode)
  {
    EventCode              = NoValue;
    
    for (EventType event=0;event<EventTypes;event++)
      if (upper(EnumToString(event))==Name)
      {
        EventCode          = event;
        return (true);
      }

    return (false);
  }

//+------------------------------------------------------------------+
//| IndicatorFound - validates indicator name and returns the index  |
//+------------------------------------------------------------------+
bool IndicatorFound(string Name, int &IndicatorCode)
  {
    for (IndicatorCode=0;IndicatorCode<ArraySize(hmIndicator);IndicatorCode++)
      if (hmIndicator[IndicatorCode]==Name)
        return (true);

    IndicatorCode          = NoValue;
    
    return (false);
  }

//+------------------------------------------------------------------+
//| Monitoring - Returns true if this indicator is being monitored   |
//+------------------------------------------------------------------+
bool Monitoring(string Indicator)
  {
    for (int ind=0;ind<ArraySize(hmMonitor);ind++)
      if (upper(Indicator)==hmIndicator[ind])
        return (hmMonitor[ind]);
        
    return (false);
  }

//+------------------------------------------------------------------+
//| CallPause - pauses based on class level events                   |
//+------------------------------------------------------------------+
void CallPause(ReservedWords Class, EventType Event, string Indicator, int Action=OP_NO_ACTION)
  {
    int     cpResponse;
    bool    cpContrarian   = false;
    string  cpMessage      = EnumToString(Event)+" alert detected on "+Indicator+"\n";
    int     cpStyle        = BoolToInt(Action==OP_NO_ACTION,MB_OKCANCEL|MB_ICONEXCLAMATION,MB_YESNOCANCEL|MB_ICONQUESTION);
    int     cpIndicator    = NoValue;
    
    if (IndicatorFound(Indicator,cpIndicator))
    {
      hmEvent[cpIndicator].Class      = Class;
      hmEvent[cpIndicator].Event      = Event;
      hmEvent[cpIndicator].Action     = Action;
      hmEvent[cpIndicator].Active     = true;
      hmEvent[cpIndicator].EventTime  = TimeCurrent();
    }
    
    if (Event==NoEvent)
      return;
      
    if (EventLock==NoEvent || Event==Event)
      if (Monitoring(Indicator))
        if (EventClass[Class] && EventAlert[Event])
        {
          if (Action!=OP_NO_ACTION)
            Append(cpMessage,ActionText(Action)+" triggered, click Yes to "+ActionText(Action)+", No to trade contrarian.","\n");
            
          if (Event==MarketCorrection)
            if (Indicator=="Session")
            {
              if (Class==Minor)
                Append(cpMessage,"Minor marktet correction in Session "+EnumToString(leadSession.Type()),"\n");

              if (Class==Major)
                Append(cpMessage,"Major marktet correction in Daily Session ","\n");
            }  
            
            
          cpResponse = Pause(cpMessage,EnumToString(Class)+" Alert",cpStyle);
      
          switch (cpStyle)
          {
            case MB_OKCANCEL|MB_ICONEXCLAMATION:  if (cpResponse==IDCANCEL)
                                                    EventClass[Class] = false;
                                                  break;

            default:  if (cpResponse==IDCANCEL)
                        return;

                      if (cpResponse==IDNO)
                        cpContrarian      = true;
                  
                      OpenOrder(Action(Action,InAction,cpContrarian),Indicator+"("+EnumToString(Event)+")");
          }
        }
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    for (int gdIndicator=0;gdIndicator<ArraySize(hmIndicator);gdIndicator++)
      hmEvent[gdIndicator].Active           = false;
      
    fractal.Update();
    pfractal.Update();
    
    if (inpShowFiboArrow)
      pfractal.ShowFiboArrow();

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
    UpdateLine("fRetrace",fRetrace,STYLE_DOT,clrRed);
    UpdateLine("fMinor",fMinor,STYLE_DASH,clrSteelBlue);
    UpdateLine("fMajor",fMajor,STYLE_SOLID,clrGoldenrod);

    if (fractal.Event(MarketCorrection))
      NewArrow(BoolToInt(fractal.Direction(fractal.State(Now))==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
               DirColor(fractal.Direction(fractal.State(Now)),clrYellow),"Correction-"+
               DirText(fractal.Direction(fractal.State(Major))));
  }

//+------------------------------------------------------------------+
//| ExecPipFractal - Micro management at the pfractal level          |
//+------------------------------------------------------------------+
void ExecPipFractal(void)
  {
    int           epfAction  = Action(pfractal.Direction(Tick),InDirection);

    ReservedWords epfClass   = Default;
    EventType     epfEvent   = NoEvent;

    if (pfractal.Event(NewBoundary))
    {
      epfClass               = Boundary;
      epfEvent               = NewBoundary;
      
      if (pfractal.HistoryLoaded())
      {
        if (pfractal.Event(NewHigh))
          if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)))
            if (IsChanged(pfPolyDir,DirectionUp))
            {
              epfClass       = Minor;
              epfEvent       = NewPoly;
            }

        if (pfractal.Event(NewLow))
          if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
            if (IsChanged(pfPolyDir,DirectionDown))
            {
              epfClass       = Minor;
              epfEvent       = NewPoly;
            }
      }
    }
        
    if (pfractal.Event(NewTerm))
    {
      epfClass              = Minor;
      epfEvent              = NewDivergence;
    }

    if (pfractal.Event(NewMinor))
    {
      epfClass              = Minor;

      if (pfractal.Event(NewTerm))
        epfEvent            = NewReversal;
      else
        epfEvent            = NewBreakout;
    }

    if (pfractal.Event(NewMajor))
    {
      epfClass              = Major;

      if (pfractal.Event(NewTrend))
        epfEvent            = NewReversal;
      else
        epfEvent            = NewBreakout;
    }

    if (pfractal.Event(MarketIdle))
      CallPause(Tick,MarketIdle,"PipFractal");

    if (pfractal.Event(MarketResume))
      CallPause(Tick,MarketResume,"PipFractal",epfAction);

    CallPause(epfClass,epfEvent,"PipFractal",epfAction);
  }
  
//+------------------------------------------------------------------+
//| ExecFractal - Macro management at fractal level                  |
//+------------------------------------------------------------------+
void ExecFractal(void)
  {
    int           efAction   = Action(fractal[fractal.State(Now)].Direction,InDirection);

    ReservedWords efClass    = Default;
    EventType     efEvent    = NoEvent;
  
    if (fractal.Event(NewMajor))
    {
      efClass                = Major;
      
      if (fractal.IsDivergent())
        efEvent              = NewDivergence;
      else
        efEvent              = NewExpansion;
    }
    
    if (fractal.Event(MarketCorrection))
    {
      efEvent                = MarketCorrection;
      efClass                = Minor;
      
      if (fractal.IsMajor(fractal.State(Now)))
        efClass              = Major;
    }
    
    if (fractal.Event(NewFractal))
    {
      efClass                = Major;
      efEvent                = NewFractal;

      if (fractal.Event(NewBreakout))
        efEvent              = NewBreakout;

      if (fractal.Event(NewReversal))
        efEvent              = NewReversal;
    }
    
    if (fractal.IsMajor(fractal.State(Now)))
      fMajor                  = fractal.Price(fractal.State(Major),Fibo50);
    else
    if (fractal.IsMinor(fractal.State(Now)))
      fMinor                  = fractal.Price(fractal.State(Minor),Fibo50);
    else
      fRetrace                = fractal.Price(fractal.Next(fractal.State(Minor)),Fibo50);

    CallPause(efClass,efEvent,"Fractal",efAction);
  }

//+------------------------------------------------------------------+
//| ExecSession - Test for session events                            |
//+------------------------------------------------------------------+
void ExecSession(void)
  {
    int           esAction   = leadSession.ActiveBias();

    ReservedWords esClass    = Default;
    EventType     esEvent    = NoEvent;
      
    if (leadSession.Event(NewDirection))
      switch (leadSession.SessionHour())
      {
        case 1:   esClass    = Tick;
                  esEvent    = NewDirection;
                  break;

        case 2:   esClass    = Minor;
                  esEvent    = NewDirection;
                  break;

        default:  esClass    = Major;
                  esEvent    = NewBreakout;
                  break;
      }

    if (leadSession.Event(MarketCorrection))
    {
      esClass    = Minor;
      esEvent    = MarketCorrection;
    }

    if (session[Daily].Event(MarketCorrection))
    {
      esClass    = Major;
      esEvent    = MarketCorrection;
    }

    CallPause(esClass,esEvent,"Session",esAction);
    
//    if (leadSession.ActiveEvent())
    if (session[Asia].ActiveEvent())
      Pause(leadSession.ActiveEvents(),EnumToString(leadSession.Type())+" Session Events");
  }

//+------------------------------------------------------------------+
//| ExecRiskManagement - Corrects trade imbalances                   |
//+------------------------------------------------------------------+
void ExecRiskManagement(void)
  {
    if (EquityPercent()<=-ordEQMaxRisk)
      CloseOrders(CloseLoss);

    if (pfractal.Event(NewMajor))
    {
      OpenDCAPlan(Action(pfractal.Direction(Term),InDirection,InContrarian),EquityPercent()+ordEQMinProfit,CloseAll);
     // Pause("I got here","DCA Plan Open for "+ActionText(Action(pfractal.Direction(Term),InDirection,InContrarian)));
    }
        
        
//    if (LotValue(OP_SELL,Loss,InEquity)<-ordEQMinProfit)
//     if (LotValue(OP_SELL,Net,InEquity)>=0.00)
 
//        Pause("DCA Check (Short)","DCA Check");
//
//    if (LotValue(OP_BUY,Loss,InEquity)<-ordEQMinProfit)
//      if (LotValue(OP_BUY,Net,InEquity)>=0.00)
//        Pause("DCA Check (Long)","DCA Check");
  }

//+------------------------------------------------------------------+
//| ExecProfitManagement - Protects trade profits                    |
//+------------------------------------------------------------------+
void ExecProfitManagement(void)
  {
    int epmTickets[1]   = {0};

    if (fmin(pfractal.Age(RangeLow),pfractal.Age(RangeHigh))==1)
      SetEquityHold(Action(pfractal[Term].Direction,InDirection),3,true);    
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (TicketValue(OrderTicket(),InEquity)>ordEQMinTarget)
        {
          ArrayResize(epmTickets,ArraySize(epmTickets)+1);
          epmTickets[ArraySize(epmTickets)-1] = OrderTicket();
        }

    for (int ord=0;ord<ArraySize(epmTickets);ord++)
      CloseOrder(epmTickets[ord],true);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
//    if (session[Daily].Event(NewDay))
//      Pause ("Wake up, it''s a New Day","Alarm Clock");
//      
//    if (leadSession.Event(SessionOpen))
//      Pause ("Ahoy, Matey, the Market is Now OPEN","Alarm Clock");
      
    ExecPipFractal();
    ExecFractal();
    ExecSession();
//    ExecRiskManagement();
    //ExecProfitManagement();
    //ExecOrders();
  }

//+------------------------------------------------------------------+
//| SetEventLock - Disables alerts for all events except provided    |
//+------------------------------------------------------------------+
void SetEventLock(string EventName)
  {
    EventLock              = NoEvent;
  
    for (EventType event=0;event<EventTypes;event++)
      if (upper(EnumToString(event))==EventName)
      {
        EventLock          = event;
        break;
      }
  }

//+------------------------------------------------------------------+
//| SetMonitorLock - Disables alerts for indicators except provided  |
//+------------------------------------------------------------------+
void SetMonitorLock(string Indicator)
  {
    ArrayInitialize(hmMonitor,false);

    for (int ind=0;ind<ArraySize(hmMonitor);ind++)
      if (hmIndicator[ind]==Indicator)
        hmMonitor[ind]       = true;
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    ReservedWords eacClass;
    EventType     eacEvent;

    int           eacIndicator;
    string        eacMsg;
    
    if (Command[0] == "SET")
    {
      if (Command[1] == "CLASS")
        if (WordFound(Command[2],eacClass))
        {
          if (Command[3] == "ON")
            EventClass[eacClass]   = true;
          
          if (Command[3] == "OFF")
            EventClass[eacClass]   = false;
        }
      
      if (Command[1] == "EVENT")
        if (EventFound(Command[2],eacEvent))
        {
          if (Command[3] == "ON")
            EventAlert[eacEvent]   = true;
          
          if (Command[3] == "OFF")
            EventAlert[eacEvent]   = false;
        }        
        
      if (Command[1] == "INDICATOR")
        if (IndicatorFound(Command[2],eacIndicator))
        {
          if (Command[3] == "ON")
            hmMonitor[eacIndicator]  = true;
          
          if (Command[3] == "OFF")
            hmMonitor[eacIndicator]  = false;
        }
    }

    if (Command[0] == "LOCK")
    {
      if (Command[1]=="EVENT")
        SetEventLock(Command[2]);

      if (Command[1] == "MONITOR")
        SetMonitorLock(Command[2]);
    }
    
      
    if (Command[0] == "SHOW")
    {
      if (Command[1] == "MONITOR")
      {
        eacMsg   = "Indicators currently monitoring:\n";
        
        for (int ind=0;ind<ArraySize(hmMonitor);ind++)
          if (Monitoring(hmIndicator[ind]))
            Append(eacMsg,"  - "+hmIndicator[ind],"\n");
       
        eacMsg   += "\n\nEvents currently monitoring:\n";

        for (EventType event=1;event<EventTypes;event++)
          if (EventAlert[event])
            Append(eacMsg,"  - "+EnumToString(event),"\n");
       
        eacMsg   += "\n\nEvent Class currently monitoring:\n";

        for (ReservedWords word=0;word<WordCount;word++)
          if (EventClass[word])
            Append(eacMsg,"  - "+EnumToString(word),"\n");

        Pause(eacMsg,"Monitors Currently Active",MB_OK|MB_ICONINFORMATION);
      }
      
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
    
    session[Daily]        = new CSession(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose);
    
    leadSession           = session[Daily];

    ArrayInitialize(EventAlert,false);
    
    EventAlert[NewBoundary]      = true;
    EventAlert[NewPoly]          = true;
    EventAlert[NewDivergence]    = true;
    EventAlert[NewBreakout]      = true;
    EventAlert[NewReversal]      = true;
    EventAlert[NewExpansion]     = true;
    EventAlert[MarketCorrection] = true;
    EventAlert[NewFractal]       = true;
    EventAlert[NewDirection]     = true;
    
    ArrayInitialize(EventClass,false);

    EventClass[Boundary]  = true;
    EventClass[Tick]      = true;
    EventClass[Minor]     = true;
    EventClass[Major]     = true;
         
    NewLine("fRetrace",fRetrace,STYLE_DOT,clrRed);
    NewLine("fMinor",fMinor,STYLE_DASH,clrSteelBlue);
    NewLine("fMajor",fMajor,STYLE_SOLID,clrGoldenrod);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pfractal;
    delete fractal;
        
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }