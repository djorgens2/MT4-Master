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
  CArrayDouble       *dbBounds               = new CArrayDouble(6);
  CSession           *leadSession;
  
  bool                PauseOn                = true;

  int                 dbDailyAction;
  int                 dbBoundsCount;
  int                 dbPriceZone;
  int                 dbUpperBound;
  int                 dbLowerBound;

  //--- Check Performance Operationals
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
    for (SessionType type=Asia;type<SessionTypes;type++)
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
    string rsComment  = "Asian Session Closed";
       
    if (session[Asia].IsOpen())
      rsComment       = "Asian Session Open";

    UpdateLine("ActiveHigh",session[Asia][ActiveSession].High,STYLE_SOLID,DirColor(session[Asia][ActiveSession].Direction));
    UpdateLine("ActiveLow",session[Asia][ActiveSession].Low,STYLE_SOLID,DirColor(session[Asia][ActiveSession].Direction));

    UpdateLine("OffHigh",session[Asia][OffSession].High,STYLE_SOLID,clrGoldenrod);
    UpdateLine("OffLow",session[Asia][OffSession].Low,STYLE_SOLID,clrGoldenrod);

    UpdateLine("PriorHigh",session[Asia][PriorSession].High,STYLE_SOLID,clrSteelBlue);
    UpdateLine("PriorLow",session[Asia][PriorSession].Low,STYLE_SOLID,clrSteelBlue);

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
    
    session[Daily]        = new CSession(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose);
    
    leadSession           = session[Daily];
    
    NewLine("ActiveHigh");
    NewLine("ActiveLow");
    NewLine("PriorHigh");
    NewLine("PriorLow");
    NewLine("OffHigh");
    NewLine("OffLow");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete dbBounds;
    
    ObjectDelete("mvUpperBound");
    ObjectDelete("mvLowerBound");
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
      
    for (int x=0;x<6;x++)
      ObjectDelete("dbBounds"+IntegerToString(x));
  }