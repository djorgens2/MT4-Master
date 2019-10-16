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

  
input string    fractalHeader           = "";    //+------ Fractal Options ---------+
input int       inpRangeMin             = 60;    // Minimum fractal pip range
input int       inpRangeMax             = 120;   // Maximum fractal pip range
input int       inpPeriodsLT            = 240;   // Long term regression periods

input string    RegressionHeader        = "";    //+------ Regression Options ------+
input int       inpDegree               = 6;     // Degree of poly regression
input int       inpSmoothFactor         = 3;     // MA Smoothing factor
input double    inpTolerance            = 0.5;   // Directional sensitivity
input int       inpPipPeriods           = 200;   // Trade analysis periods (PipMA)
input int       inpRegrPeriods          = 24;    // Trend analysis periods (RegrMA)

input string    SessionHeader           = "";    //+---- Session Hours -------+
input int       inpAsiaOpen             = 1;     // Asian market open hour
input int       inpAsiaClose            = 10;    // Asian market close hour
input int       inpEuropeOpen           = 8;     // Europe market open hour
input int       inpEuropeClose          = 18;    // Europe market close hour
input int       inpUSOpen               = 14;    // US market open hour
input int       inpUSClose              = 23;    // US market close hour
input int       inpGMTOffset            = 0;     // GMT Offset

  //--- Class Objects
  CSession           *session[SessionTypes];
  CSession           *lead;
  CFractal           *fractal             = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal            = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,50,fractal);
  CEvent             *sEvent              = new CEvent();
  CEvent             *fEvent              = new CEvent();
  
  //--- Collection Objects
  struct              SessionDetail 
                          {
                            int  OpenDir;
                            int  ActiveDir;
                            int  OpenBias;
                            int  ActiveBias;
                            int  FractalDir;
                            bool IsValid;
                            bool Reversal;
                            bool Alerts;
                          };


  //--- Display operationals
  string              rsShow              = "APP";
  bool                PauseOn             = true;
  bool                LoggingOn           = true;
  bool                Alerts[EventTypes];
  
  //--- Session operationals
  SessionDetail       sRec[SessionTypes];
  
  //--- Trade operationals
  bool                OrderTrigger         = false;

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
                           +"\n  Direction (Open/Active): "+DirText(sRec[type].OpenDir)+"/"+DirText(sRec[type].ActiveDir)
                           +"\n  Bias (Open/Active): "+ActionText(sRec[type].OpenBias)+"/"+ActionText(sRec[type].ActiveBias)
                           +"\n  State: "+BoolToStr(sRec[type].IsValid,"OK","Invalid")
                           +"  "+BoolToStr(sRec[type].Reversal,"Reversal",BoolToStr(sRec[type].FractalDir==DirectionNone,"",DirText(sRec[type].FractalDir)))
                           +"\n\n";

      Comment(rsComment);
    }
    
    if (rsShow=="FRACTAL")
      fractal.RefreshScreen();

    if (rsShow=="PIPMA")
      pfractal.RefreshScreen();

    if (rsShow=="DAILY")
      session[Daily].RefreshScreen();
      
    sEvent.ClearEvents();

    for (SessionType show=Daily;show<SessionTypes;show++)
      if (sRec[show].Alerts)
        for (EventType type=0;type<EventTypes;type++)
          if (Alerts[type]&&session[show].Event(type))
            sEvent.SetEvent(type);
       
    if (sEvent.ActiveEvent())
    {
      rsComment             = "Processed "+sEvent.ActiveEventText(true)+"\n";
    
      for (SessionType show=Daily;show<SessionTypes;show++)
        Append(rsComment,EnumToString(show)+" "+session[show].ActiveEventText(false)+"\n","\n");
      
      CallPause(rsComment);
    }
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
    if (NewDirection(sRec[Type].FractalDir,session[Type].Fractal(ftTerm).Direction))
      sRec[Type].Reversal    = true;
      
    OrderTrigger             = true;
//    PauseOn                  = true;
  }

//+------------------------------------------------------------------+
//| ClearOrderAction - validates OrderTrigger and clears if needed   |
//+------------------------------------------------------------------+
void ClearOrderAction(SessionType Type)
  {
    OrderTrigger                 = false;
    UpdateLabel("lbTrigger","Waiting",clrLightGray);    
  }

//+------------------------------------------------------------------+
//| SetOpenAction - sets session hold/hedge detail by type on open   |
//+------------------------------------------------------------------+
void SetOpenAction(SessionType Type)
  {
    if (NewDirection(sRec[Type].OpenDir,Direction(session[Type].Pivot(OffSession)-session[Type].Pivot(PriorSession))))
      sEvent.SetEvent(NewDirection);
      
    if (NewBias(sRec[Type].OpenBias,session[Type].Bias()))
      sEvent.SetEvent(NewTradeBias);
  }

//+------------------------------------------------------------------+
//| SetActiveAction - sets the active hold/hedge parameters          |
//+------------------------------------------------------------------+
void SetActiveAction(SessionType Type)
  {  
    bool saaIsValid          = sRec[Type].IsValid;

    sEvent.ClearEvents();
    
    if (NewDirection(sRec[Type].ActiveDir,Direction(session[Type].Pivot(ActiveSession)-session[Type].Pivot(PriorSession))))
      sEvent.SetEvent(NewDirection);

    if (NewBias(sRec[Type].ActiveBias,session[Type].Bias()))
      sEvent.SetEvent(NewTradeBias);
      
    if (sRec[Type].ActiveDir==sRec[Type].OpenDir)
      if (sRec[Type].ActiveBias==sRec[Type].OpenBias)
        if (sRec[Type].ActiveDir==Direction(sRec[Type].ActiveBias,InAction))
          saaIsValid         = true;

    if (IsChanged(sRec[Type].IsValid,saaIsValid))
    {
      if (Alerts[MarketCorrection])
        CallPause(EnumToString(session[Type].Type())+":Market Correction to "+BoolToStr(saaIsValid,"OK","Invalid"));
        
      sEvent.SetEvent(MarketCorrection);
    }
  }

//+------------------------------------------------------------------+
//| DailySetup - Prepare the daily strategy                          |
//+------------------------------------------------------------------+
void DailySetup(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      sRec[type].FractalDir      = DirectionNone;
      sRec[type].Reversal        = false;
    }    
  }

//+------------------------------------------------------------------+
//| CheckSessionEvents - updates trading strategy on session events  |
//+------------------------------------------------------------------+
void CheckSessionEvents(void)
  {          
    sEvent.ClearEvents();
    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      if (session[type].Event(SessionOpen))
        SetOpenAction(type);
        
      if (session[type].Event(NewFractal)||session[type].Event(NewReversal)||session[type].Event(NewBreakout))
        SetOrderAction(type);
      else
      if (session[type].Event(NewRally)||session[type].Event(NewPullback))
        ClearOrderAction(type);
        
      SetActiveAction(type);
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
      
    if (pfractal.ActiveEvent())
      CallPause("PipMA "+pfractal.ActiveEventText());
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (session[Daily].Event(SessionOpen))
      DailySetup();
      
    CheckSessionEvents();
    CheckFractalEvents();

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
      sRec[type].OpenDir      = DirectionNone;
      sRec[type].ActiveDir    = DirectionNone;
      sRec[type].OpenBias     = OP_NO_ACTION;
      sRec[type].ActiveBias   = OP_NO_ACTION;
      sRec[type].IsValid      = false;
      sRec[type].FractalDir   = DirectionNone;
      sRec[type].Reversal     = false;
      sRec[type].Alerts       = true;
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
  }