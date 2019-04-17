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
#include <Class\Session.mqh>

input string   SessionHeader           = "";    //+---- Session Hours -------+
input int      inpAsiaOpen             = 1;     // Asian market open hour
input int      inpAsiaClose            = 10;    // Asian market close hour
input int      inpEuropeOpen           = 8;     // Europe market open hour
input int      inpEuropeClose          = 18;    // Europe market close hour
input int      inpUSOpen               = 14;    // US market open hour
input int      inpUSClose              = 23;    // US market close hour


  //--- Class Objects
  CSession           *session[SessionTypes];
  CSession           *leadSession;
  
  bool                PauseOn                = true;
  int                 ShowFibo               = Active;
  
  //--- Check Performance Operationals


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
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      session[type].Update();
      
      if (session[type].IsOpen())
        leadSession    = session[type];
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    static int rsActiveDirChg   = 0;
    
    string rsComment  = "Lead: "+EnumToString(leadSession.Type());

    UpdateLine("LeadHigh",leadSession[ShowFibo].High,STYLE_SOLID,DirColor(session[Asia][ShowFibo].Direction));
    UpdateLine("LeadLow",leadSession[ShowFibo].Low,STYLE_SOLID,DirColor(session[Asia][ShowFibo].Direction));
    UpdateLine("LeadPivot",leadSession.Pivot(ShowFibo),STYLE_DOT,DirColor(session[Asia][ShowFibo].Direction));

    UpdateLine("LeadResistance",leadSession[ShowFibo].Resistance,STYLE_DOT,clrForestGreen);
    UpdateLine("LeadSupport",leadSession[ShowFibo].Support,STYLE_DOT,clrFireBrick);

    Comment(rsComment);
  }
  
//+------------------------------------------------------------------+
//| SetDailyAction - sets the trend hold/hedge parameters            |
//+------------------------------------------------------------------+
void SetDailyAction(void)
  {  
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

//      if (SessionHour()>5)
//        if (sEvent[NewDirection])
//        {
//          if (sEvent[NewHigh])
//            NewArrow(SYMBOL_ARROWUP,clrYellow,EnumToString(sType)+"-Long",usLastSession.High,sBar);
//
//          if (sEvent[NewLow])
//            NewArrow(SYMBOL_ARROWDOWN,clrRed,EnumToString(sType)+"-Short",usLastSession.Low,sBar);
//        }
//        else
//        {
//          if (srec[RecordType(OffSession)].Direction!=srec[RecordType(Active)].Direction)
//            if (IsChanged(
//        }
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="SHOW")
    {
      if (Command[1]=="ACTIVE")     ShowFibo=Active;
      if (Command[1]=="PRIOR")      ShowFibo=Prior;
      if (Command[1]=="OFFSESSION") ShowFibo=OffSession;
      if (Command[1]=="ORIGIN")     ShowFibo=Origin;
      if (Command[1]=="TREND")      ShowFibo=Trend;
      if (Command[1]=="TERM")       ShowFibo=Term;
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
    
    session[Daily]        = new CSession(Daily,0,23);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose);

    NewLine("LeadHigh");
    NewLine("LeadLow");
    NewLine("LeadPivot");
    NewLine("LeadResistance");
    NewLine("LeadSupport");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }