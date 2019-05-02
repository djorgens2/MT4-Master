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
  CSession           *sessionLead;
  CEvent             *sessionEvent     = new CEvent();
  
  bool                PauseOn          = true;
  int                 ShowFibo         = Active;
  SessionType         ShowSession      = Daily;
  bool                ShowLead         = false;
  
  //--- Event operationals
  int                 evBrkDir         = DirectionNone;
  int                 evRevDir         = DirectionNone;
  int                 evCount          = 0;


//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (PauseOn)
      Pause(Message,"Event Trapper");
    else
      Print(Message);
  }
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    sessionEvent.ClearEvents();
    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      session[type].Update();
      
      if (session[type].IsOpen())
        sessionLead    = session[type];
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    static int      rsActiveDirChg     = 0;
    const  string   rsSessionPeriod[6] = {"Origin","Trend","Term","Prior","OffSession","Active"};
    CSession       *rsSession;
    
    string rsComment  = "Lead: "+EnumToString(sessionLead.Type());
    
    if (ShowFibo!=None)
    {
      if (ShowLead)
      {
        Append(rsComment,"Show Lead: ","\n");
        rsSession     = sessionLead;
      }
      else
      {
        Append(rsComment,"Show: ","\n");
        rsSession     = session[ShowSession];
      }
      
      Append(rsComment,EnumToString(rsSession.Type())+" "+rsSessionPeriod[rsSession.RecordType(ShowFibo)]);
      
      UpdateLine("LeadHigh",rsSession[ShowFibo].High,STYLE_SOLID,DirColor(session[ShowSession][ShowFibo].Direction));
      UpdateLine("LeadLow",rsSession[ShowFibo].Low,STYLE_SOLID,DirColor(session[ShowSession][ShowFibo].Direction));
      UpdateLine("LeadPivot",rsSession.Pivot(ShowFibo),STYLE_DOT,DirColor(session[ShowSession][ShowFibo].Direction));
      UpdateLine("LeadResistance",rsSession[ShowFibo].Resistance,STYLE_DOT,clrForestGreen);
      UpdateLine("LeadSupport",rsSession[ShowFibo].Support,STYLE_DOT,clrFireBrick);
    }
    
    Comment(rsComment);
  }

//+------------------------------------------------------------------+
//| Act - computes the best course of action and executes            |
//+------------------------------------------------------------------+
void Act(int ActionOverride=OP_NO_ACTION)
  {
    int aDir      = session[Asia][Active].Direction;
    
    
  }

//+------------------------------------------------------------------+
//| CheckProfit - take profit at specified level and conditions      |
//+------------------------------------------------------------------+
void CheckProfit(void)
  {
    double pcLProfit    = LotValue(OP_BUY,Profit,InEquity);
    double pcLNet       = LotValue(OP_BUY,Net,InEquity);
    double pcSProfit    = LotValue(OP_SELL,Profit,InEquity);
    double pcSNet       = LotValue(OP_SELL,Net,InEquity);
    
    double pcLMargin    = MarginPercent(OP_BUY);
    double pcSMargin    = MarginPercent(OP_SELL);
    
    //--- check long
    if (EquityPercent()>ordEQMinTarget)
    {
      
    }
    
    
  }

//+------------------------------------------------------------------+
//| CheckSessionEvents - updates trading strategy on session events  |
//+------------------------------------------------------------------+
void CheckSessionEvents(void)
  {  
    int cseRevDir               = DirectionNone;
    int cseBrkDir               = DirectionNone;
    int cseCount                = 0;
    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      if (session[type].Event(NewReversal))
      {
        sessionEvent.SetEvent(NewReversal);
      
        if (cseRevDir==DirectionNone)
          cseRevDir              = session[type][Active].BreakoutDir;

        if (IsChanged(cseRevDir,session[type][Active].BreakoutDir))
          Pause("Really, differing reversals on different sessions?","Reversal 'Issue'");
          
        NewPriceLabel(EnumToString(type)+"-Reversal("+IntegerToString(++cseCount)+"):"+TimeToStr(Time[0]),Close[0],true);
        UpdatePriceLabel(EnumToString(type)+"-Reversal("+IntegerToString(cseCount)+"):"+TimeToStr(Time[0]),Close[0],DirColor(session[type][Active].BreakoutDir));
      }

      if (session[type].Event(NewBreakout))
      {
        sessionEvent.SetEvent(NewBreakout);

        if (cseBrkDir==DirectionNone)
          cseBrkDir              = session[type][Active].BreakoutDir;

        if (IsChanged(cseBrkDir,session[type][Active].BreakoutDir))
          Pause("Really, differing breakouts on different sessions?","Breakout 'Issue'");

        NewPriceLabel(EnumToString(type)+"-Breakout("+IntegerToString(++cseCount)+"):"+TimeToStr(Time[0]),Close[0]);
        UpdatePriceLabel(EnumToString(type)+"-Breakout("+IntegerToString(cseCount)+"):"+TimeToStr(Time[0]),Close[0],DirColor(session[type][Active].BreakoutDir));
      }
      
      if (sessionEvent[NewReversal] && sessionEvent[NewBreakout])
        for (int cnt=0;cnt<cseCount;cnt++)
        {
          UpdatePriceLabel(EnumToString(type)+"-Reversal("+IntegerToString(cnt+1)+"):"+TimeToStr(Time[0]),Close[0],clrYellow);
          UpdatePriceLabel(EnumToString(type)+"-Breakout("+IntegerToString(cnt+1)+"):"+TimeToStr(Time[0]),Close[0],clrYellow);
        }
    }
    
    if (sessionLead.SessionHour()>4)
      CallPause("Take Profit");

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
      
    if (sessionLead.Event(SessionOpen))
      CallPause("Lead session open: "+EnumToString(sessionLead.Type()));
      
    CheckSessionEvents();
    CheckProfit();

  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="SHOW")
    {
      if (Command[1]=="NONE")
      {
        ShowFibo                  = None;
        ShowLead                  = false;
                
        UpdateLine("LeadHigh",0.00,STYLE_SOLID,clrDarkGray);
        UpdateLine("LeadLow",0.00,STYLE_SOLID,clrDarkGray);
        UpdateLine("LeadPivot",0.00,STYLE_DOT,clrDarkGray);
        UpdateLine("LeadResistance",0.00,STYLE_DOT,clrDarkGray);
        UpdateLine("LeadSupport",0.00,STYLE_DOT,clrDarkGray);
      }
      else
      if (Command[1]=="LEAD")
      {
        ShowLead                  = true;
      }
      else
      {
        ShowLead                  = false;
      
        if (Command[1]=="DAILY")    ShowSession=Daily;
        if (Command[1]=="ASIA")     ShowSession=Asia;
        if (Command[1]=="EUROPE")   ShowSession=Europe;
        if (Command[1]=="US")       ShowSession=US;
      }
      
      if (Command[2]=="ORIGIN")     ShowFibo=Origin;
      if (Command[2]=="TREND")      ShowFibo=Trend;
      if (Command[2]=="TERM")       ShowFibo=Term;
      if (Command[2]=="PRIOR")      ShowFibo=Prior;
      if (Command[2]=="OFFSESSION") ShowFibo=OffSession;
      if (Command[2]=="ACTIVE")     ShowFibo=Active;
    }
    
    if (Command[0]=="PAUSE")
      PauseOn                     = true;
      
    if (Command[0]=="PLAY")
      PauseOn                     = false;
    
    if (Command[0]=="ACT")  
      Act();
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
    for (int bar=Bars-1;bar>0;bar--)
      Print("|"+TimeToStr(Time[bar])+
            "|"+DoubleToStr(Open[bar],Digits)+
            "|"+DoubleToStr(High[bar],Digits)+
            "|"+DoubleToStr(Low[bar],Digits)+
            "|"+DoubleToStr(Close[bar],Digits));

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