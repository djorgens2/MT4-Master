//+------------------------------------------------------------------+
//|                                                   dj-live-v6.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
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
  CSession           *sessionLead;
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
                            bool IsValid;
                          };


  bool                PauseOn             = true;
  
  //--- Session operationals
  SessionDetail       sRec[SessionTypes];
  
  //--- Display operationals
  string              rsShow              = "APP";


//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (PauseOn)
      Pause(Message,AccountCompany()+" Event Trapper");
    else
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
        sessionLead    = session[type];
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
        rsComment       += BoolToStr(sessionLead.Type()==type,"-->")+EnumToString(type)
                           +BoolToStr(session[type].IsOpen()," ("+IntegerToString(session[type].SessionHour())+")"," Closed")
                           +"\n  Direction (Open/Active): "+DirText(sRec[type].OpenDir)+"/"+DirText(sRec[type].ActiveDir)
                           +"\n  Bias (Open/Active): "+ActionText(sRec[type].OpenBias)+"/"+ActionText(sRec[type].ActiveBias)
                           +"\n  State: "+BoolToStr(sRec[type].IsValid,"OK","Invalid")
                           +"\n\n";

      Comment(rsComment);
    }
    
    if (rsShow=="FRACTAL")
      fractal.RefreshScreen();
  }

//+------------------------------------------------------------------+
//| NewDirection - Updates Direction based on an actual change       |
//+------------------------------------------------------------------+
bool NewDirection(int &Now, int New)
  {    
    if (New==DirectionNone)
      return (false);
      
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
//| CheckSessionEvents - updates trading strategy on session events  |
//+------------------------------------------------------------------+
void CheckSessionEvents(void)
  {    
    string cseEvents    = "";
          
    sEvent.ClearEvents();
    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      if (session[type].Event(SessionOpen))
        SetOpenAction(type);

      if (session[type].Event(NewState))
        cseEvents      += "--> "+Symbol()+":"+EnumToString(type)+"\n"+session[type].ActiveEventText()+"\n\n";
        
      SetActiveAction(type);
            
      if (session[type].Event(NewReversal))
      {
      }

      if (session[type].Event(NewBreakout))
      {
      }      
    }
    
    if (cseEvents!="")
      CallPause(cseEvents);
  }
  
//+------------------------------------------------------------------+
//| SetOpenAction - sets the trend hold/hedge params by type         |
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
    bool saaValid    = false;
    
    if (NewDirection(sRec[Type].ActiveDir,Direction(session[Type].Pivot(ActiveSession)-session[Type].Pivot(PriorSession))))
      sEvent.SetEvent(NewDirection);

    if (NewBias(sRec[Type].ActiveBias,session[Type].Bias()))
      sEvent.SetEvent(NewTradeBias);
      
    if (sRec[Type].ActiveDir==sRec[Type].OpenDir)
      if (sRec[Type].ActiveBias==sRec[Type].OpenBias)
        if (sRec[Type].ActiveDir==Direction(sRec[Type].ActiveBias,InAction))
          saaValid   = true;

    if (IsChanged(sRec[Type].IsValid,saaValid))
    {
      CallPause("Market Correction to "+BoolToStr(saaValid,"OK","Invalid"));
      sEvent.SetEvent(MarketCorrection);
    }
  }


//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    CheckSessionEvents();
    CheckFractalEvents();
//    CheckProfit();

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
    
    if (Command[0]=="SHOW")
      rsShow                      = Command[1];
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

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      sRec[type].OpenDir      = DirectionNone;
      sRec[type].ActiveDir    = DirectionNone;
      sRec[type].OpenBias     = OP_NO_ACTION;
      sRec[type].ActiveBias   = OP_NO_ACTION;
      sRec[type].IsValid      = false;
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