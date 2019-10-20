//+------------------------------------------------------------------+
//|                                                   dj-live-v7.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "7.00"
#property strict


#include <manual.mqh>
#include <Class\Session.mqh>
#include <Class\PipFractal.mqh>

  
input string    fractalHeader        = "";    //+------ Fractal Options ---------+
input int       inpRangeMin          = 60;    // Minimum fractal pip range
input int       inpRangeMax          = 120;   // Maximum fractal pip range
input int       inpPeriodsLT         = 240;   // Long term regression periods

input string    RegressionHeader     = "";    //+------ Regression Options ------+
input int       inpDegree            = 6;     // Degree of poly regression
input int       inpSmoothFactor      = 3;     // MA Smoothing factor
input double    inpTolerance         = 0.5;   // Directional sensitivity
input int       inpPipPeriods        = 200;   // Trade analysis periods (PipMA)
input int       inpRegrPeriods       = 24;    // Trend analysis periods (RegrMA)

input string    SessionHeader        = "";    //+---- Session Hours -------+
input int       inpAsiaOpen          = 1;     // Asian market open hour
input int       inpAsiaClose         = 10;    // Asian market close hour
input int       inpEuropeOpen        = 8;     // Europe market open hour
input int       inpEuropeClose       = 18;    // Europe market close hour
input int       inpUSOpen            = 14;    // US market open hour
input int       inpUSClose           = 23;    // US market close hour
input int       inpGMTOffset         = 0;     // GMT Offset

  //--- Class Objects
  CSession           *session[SessionTypes];
  CSession           *lead;
  CFractal           *fractal        = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal       = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,50,fractal);
  CEvent             *sEvent         = new CEvent();
  CEvent             *fEvent         = new CEvent();
  CEvent             *toEvent        = new CEvent();
  
  //--- App enums
  enum                StrategyType
                      {
                        NoStrategy,
                        Build,
                        Hold,
                        Release,
                        Scalp,
                        Halt
                      };
                      
  //--- Collection Objects
  struct              SessionDetail 
                      {
                        int            OpenDir;
                        int            ActiveDir;
                        int            OpenBias;
                        int            ActiveBias;
                        int            FractalDir;
                        StrategyType   Strategy[2];
                        double         Entry[2];
                        double         Profit[2];
                        double         Risk[2];
                        int            NewFractalCnt;
                        bool           NewFractal;
                        bool           IsValid;
                        bool           Reversal;
                        bool           Alerts;
                      };


  //--- Display operationals
  string              rsShow              = "APP";
  bool                PauseOn             = true;
  bool                LoggingOn           = false;
  bool                Alerts[EventTypes];
  
  //--- Session operationals
  SessionDetail       detail[SessionTypes];
  SessionDetail       history[SessionTypes];
  
  //--- Trade operationals
  bool                OrderTrigger         = false;
  
  double              toBoundaryPrice      = 0.00;
  int                 toBoundaryDir        = DirectionNone;
  
  

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    static string cpMessage   = "";
    if (PauseOn)
      if (IsChanged(cpMessage,Message))
        Pause(Message,AccountCompany()+" Event Trapper");

    if (LoggingOn)
      Print(Message);
  }
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      session[type].Update();
      
      if (session[type].IsOpen())
        lead             = session[type];
    }
    
    fractal.Update();
    pfractal.Update();
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "";

    if (rsShow=="APP")
    {
      for (SessionType type=Daily;type<SessionTypes;type++)
        rsComment       += BoolToStr(lead.Type()==type,"-->")+EnumToString(type)
                           +BoolToStr(session[type].IsOpen()," ("+IntegerToString(session[type].SessionHour())+")"," Closed")
                           +"\n  Direction (Open/Active): "+DirText(detail[type].OpenDir)+"/"+DirText(detail[type].ActiveDir)
                           +"\n  Bias (Open/Active): "+ActionText(detail[type].OpenBias)+"/"+ActionText(detail[type].ActiveBias)
                           +"\n  State: "+BoolToStr(detail[type].IsValid,"OK","Invalid")
                           +"  "+BoolToStr(detail[type].Reversal,"Reversal",BoolToStr(detail[type].FractalDir==DirectionNone,"",DirText(detail[type].FractalDir)))
                           +"\n\n";

      Comment(rsComment);
    }
    
    if (rsShow=="FRACTAL")
      fractal.RefreshScreen();

    if (rsShow=="PIPMA")
      if (pfractal.HistoryLoaded())
        pfractal.RefreshScreen();

    if (rsShow=="DAILY")
      session[Daily].RefreshScreen();
      
    if (rsShow=="LEAD")
      lead.RefreshScreen();

    if (rsShow=="ASIA")
      session[Asia].RefreshScreen();

    if (rsShow=="EUROPE")
      session[Europe].RefreshScreen();

    if (rsShow=="US")
      session[US].RefreshScreen();

    sEvent.ClearEvents();
    rsComment    = "";
    
    for (EventType type=0;type<EventTypes;type++)
      if (Alerts[type]&&pfractal.Event(type))
      {
        rsComment   = "PipMA "+pfractal.ActiveEventText()+"\n";
//        CallPause("PipMA "+pfractal.ActiveEventText());
        break;
      }

    for (SessionType show=Daily;show<SessionTypes;show++)
      if (detail[show].Alerts)
        for (EventType type=0;type<EventTypes;type++)
          if (Alerts[type]&&session[show].Event(type))
          {
            if (session[show].Event(NewFractal))
            {
              if (!detail[show].NewFractal)
                sEvent.SetEvent(type);
            }
            else
              sEvent.SetEvent(type);
          }

    if (sEvent.ActiveEvent())
    {
      Append(rsComment,"Processed "+sEvent.ActiveEventText(true)+"\n","\n");
    
      for (SessionType show=Daily;show<SessionTypes;show++)
        Append(rsComment,EnumToString(show)+" ("+BoolToStr(session[show].IsOpen(),
           "Open:"+IntegerToString(session[show].SessionHour()),
           "Closed")+")"+session[show].ActiveEventText(false)+"\n","\n");
    }

    if (StringLen(rsComment)>0)
      CallPause(rsComment);
  }

//+------------------------------------------------------------------+
//| NewDirection - Updates Direction based on an actual change       |
//+------------------------------------------------------------------+
bool NewDirection(int &Now, int New)
  {    
    if (New==DirectionNone)
      return (false);
      
    if (Now==DirectionNone)
      Now             = New;
      
    if (IsChanged(Now,New))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| NewBias - Updates Trade Bias based on an actual change           |
//+------------------------------------------------------------------+
bool NewBias(int &Now, int New)
  {    
    if (New==OP_NO_ACTION)
      return (false);
      
    if (IsChanged(Now,New))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| SetOrderAction - updates session detail on a new order event     |
//+------------------------------------------------------------------+
void SetOrderAction(SessionType Type)
  {
    OrderTrigger                   = true;
//    PauseOn                  = true;
  }

//+------------------------------------------------------------------+
//| ClearOrderAction - validates OrderTrigger and clears if needed   |
//+------------------------------------------------------------------+
void ClearOrderAction(SessionType Type)
  {
    OrderTrigger                   = false;
    UpdateLabel("lbTrigger","Waiting",clrLightGray);    
  }

//+------------------------------------------------------------------+
//| SetDailyAction - Prepare the daily strategy                      |
//+------------------------------------------------------------------+
void SetAsiaAction(void)
  {
    StrategyType saaStrategy      = NoStrategy;

    if (session[Asia].Event(SessionOpen))
    {}
    else
    if (session[Asia].IsOpen())
    {}
    else
    {}
  }

//+------------------------------------------------------------------+
//| SetDailyAction - Prepare the daily strategy                      |
//+------------------------------------------------------------------+
void SetDailyAction(void)
  {
    ArrayCopy(history,detail);
    
    //--- Update Session Detail
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      detail[type].FractalDir      = DirectionNone;
      detail[type].NewFractalCnt   = 0;
      detail[type].NewFractal      = false;
      detail[type].Reversal        = false;
    }
    
//    if (IsHigher(session[Daily][OffSession].High,session[Daily][PriorSession].High,NoUpdate)
//         || IsLower(session[Daily][OffSession].Low,session[Daily][PriorSession].Low,NoUpdate))
//    {
//      toEvent.SetEvent(OutOfBounds);
//      
//      if (NewDirection(toBoundaryDir,session[Daily].Fractal(ftTerm).Direction))
//        toEvent.SetEvent(NewFractal);
//
//      toBoundaryPrice              = BoolToDouble(toBoundaryDir==DirectionUp,session[Daily].Fractal(ftTerm).High,session[Daily].Fractal(ftTerm).Low);
//    }
//    else
//    {
//      if (NewDirection(toBoundaryDir,session[Daily][PriorSession].Direction))
//        toEvent.SetEvent(NewDirection);
//
//      toBoundaryPrice              = BoolToDouble(toBoundaryDir==DirectionUp,session[Daily][PriorSession].High,session[Daily][PriorSession].Low);
//    };

  }

//+------------------------------------------------------------------+
//| SetHourlyAction - sets session hold/hedge detail by type hourly  |
//+------------------------------------------------------------------+
void SetHourlyAction(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      detail[type].NewFractal      = false;
    }  
  }

//+------------------------------------------------------------------+
//| SetOpenAction - sets session hold/hedge detail by type on open   |
//+------------------------------------------------------------------+
void SetOpenAction(SessionType Type)
  {
    if (NewDirection(detail[Type].OpenDir,Direction(session[Type].Pivot(OffSession)-session[Type].Pivot(PriorSession))))
      sEvent.SetEvent(NewDirection);
      
    if (NewBias(detail[Type].OpenBias,session[Type].Bias()))
      sEvent.SetEvent(NewTradeBias);

    switch (Type)
    {
      case Daily:   SetDailyAction();
                    break;
      case Asia:    SetAsiaAction();
                    break;
    }
  }

//+------------------------------------------------------------------+
//| SetOpenAction - sets session hold/hedge detail by type on open   |
//+------------------------------------------------------------------+
void SetHourlyAction(SessionType Type)
  {
    sEvent.SetEvent(NewHour);
    
    //-- Reset hourly action flags
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
    }    
  }

//+------------------------------------------------------------------+
//| CheckSessionEvents - updates trading strategy on session events  |
//+------------------------------------------------------------------+
void CheckSessionEvents(void)
  {          
    bool cseIsValid                = false;

    sEvent.ClearEvents();
    
    if (session[Daily].Event(NewHour))
      SetHourlyAction();
    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      if (session[type].Event(SessionOpen))
        SetOpenAction(type);

      if (NewDirection(detail[type].ActiveDir,Direction(session[type].Pivot(ActiveSession)-session[type].Pivot(PriorSession))))
        sEvent.SetEvent(NewDirection);

      if (NewBias(detail[type].ActiveBias,session[type].Bias()))
        sEvent.SetEvent(NewTradeBias);
        
      if (NewDirection(detail[type].FractalDir,session[type].Fractal(ftTerm).Direction))
      {
        detail[type].Reversal      = true;
        
        sEvent.SetEvent(NewReversal);
        
        if (type==Daily)
          sEvent.SetEvent(NewMajor);
        else
          sEvent.SetEvent(NewMinor);
      }
      
      if (session[type].Event(NewFractal))
        if (IsChanged(detail[type].NewFractal,true))
          detail[type].NewFractalCnt++;
        
      cseIsValid                   = detail[type].IsValid;

      if (detail[type].ActiveDir==detail[type].OpenDir)
        if (detail[type].ActiveBias==detail[type].OpenBias)
          if (detail[type].ActiveDir==Direction(detail[type].ActiveBias,InAction))
            cseIsValid             = true;

      if (IsChanged(detail[type].IsValid,cseIsValid))
        sEvent.SetEvent(MarketCorrection);
    }
  }
  
//+------------------------------------------------------------------+
//| CheckFractalEvents - updates trading strategy on fractal events  |
//+------------------------------------------------------------------+
void CheckFractalEvents(void)
  {    
    fEvent.ClearEvents();

    if (fractal.ActiveEvent())
      if (fractal.Event(NewMajor))
        CallPause("Fractal Major");
  }

//+------------------------------------------------------------------+
//| CheckOrderEvents - Check events when activated by order event    |
//+------------------------------------------------------------------+
void CheckOrderEvents(void)
  {
    if (IsChanged(OrderTrigger,true))
      UpdateLabel("lbTrigger","Trigger open",clrYellow);
  }
  
//+------------------------------------------------------------------+
//| CheckOrderEvents - Check events when activated by order event    |
//+------------------------------------------------------------------+
void CalcStrategy(void)
  {
//    if (session[type].Event(NewFractal)||session[type].Event(NewReversal)||session[type].Event(NewBreakout))
//      SetOrderAction(type);
//    else
//    if (session[type].Event(NewRally)||session[type].Event(NewPullback))
//      ClearOrderAction(type);      
  }
  

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    CheckSessionEvents();
    CheckFractalEvents();

    CalcStrategy();
    
    if (OrderTrigger)
      CheckOrderEvents();

  }

//+------------------------------------------------------------------+
//| AlertKey - Matches alert text and returns the enum               |
//+------------------------------------------------------------------+
EventType AlertKey(string Event)
  {
    string akType;
    
    for (EventType type=0;type<EventTypes;type++)
    {
      akType           = EnumToString(type);

      if (StringToUpper(akType))
        if (akType==Event)
          return (type);
    }    
    
    return(EventTypes);
  }


//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PAUSE")
      PauseOn                     = true;
      
    if (Command[0]=="PLAY")
      PauseOn                     = false;
    
    if (Command[0]=="LOG")
    {
      if (Command[1]=="ON")
        LoggingOn                 = true;

      if (Command[1]=="OFF")
        LoggingOn                 = false;
    }
    if (Command[0]=="SHOW")
      rsShow                      = Command[1];

    if (Command[0]=="DISABLE")
    {
      if (Command[1]=="ALL")
        ArrayInitialize(Alerts,false);
      else
      {
        Alerts[AlertKey(Command[1])]  = false;
        Print("Alerts for "+EnumToString(EventType(AlertKey(Command[1])))+" disabled.");
      }
    }

    if (Command[0]=="ENABLE")
    {
      if (Command[1]=="ALL")
        ArrayInitialize(Alerts,true);
      else
      {
        Alerts[AlertKey(Command[1])]  = true;
        Print("Alerts for "+EnumToString(EventType(AlertKey(Command[1])))+" enabled.");
      }
    }

    if (Command[0]=="ALERT")
    {
      if (Command[1]=="ON")
      {
        if (Command[2]=="ASIA")   detail[Asia].Alerts  = true;
        if (Command[2]=="EUROPE") detail[Asia].Alerts  = true;
        if (Command[2]=="US")     detail[Asia].Alerts  = true;
        if (Command[2]=="DAILY")  detail[Asia].Alerts  = true;
        if (Command[2]=="ALL")
          for (int alert=Daily;alert<SessionTypes;alert++)
           detail[alert].Alerts   = true;
      }        

      if (Command[1]=="OFF")
      {
        if (Command[2]=="ASIA")   detail[Asia].Alerts  = false;
        if (Command[2]=="EUROPE") detail[Asia].Alerts  = false;
        if (Command[2]=="US")     detail[Asia].Alerts  = false;
        if (Command[2]=="DAILY")  detail[Asia].Alerts  = false;
        if (Command[2]=="ALL")
          for (int alert=Daily;alert<SessionTypes;alert++)
           detail[alert].Alerts   = false;
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
    
    session[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
    
    NewLabel("lbTrigger","Waiting",5,5,clrLightGray,SCREEN_LL);

    ArrayInitialize(Alerts,true);

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      detail[type].OpenDir      = DirectionNone;
      detail[type].ActiveDir    = DirectionNone;
      detail[type].OpenBias     = OP_NO_ACTION;
      detail[type].ActiveBias   = OP_NO_ACTION;
//      detail[type].Strategy     = NoStrategy;
      detail[type].IsValid      = false;
      detail[type].FractalDir   = DirectionNone;
      detail[type].Reversal     = false;
      detail[type].Alerts       = true;
    }

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete session[type];
      
    delete fractal;
    delete pfractal;
    delete sEvent;
    delete fEvent;
    delete toEvent;
  }