//+------------------------------------------------------------------+
//|                                                   dj-live-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict


#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\Session.mqh>

input string    EAHeader                = "";    //+---- Application Options -------+
input YesNoType inpShowPolyArrows       = No;    // Show poly direction change arrows
input double    inpDailyTarget          = 10;    // Daily % growth objective
  
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

  //--- Class Objects
  CSession      *session[SessionTypes];
  CSession      *leadSession;

  CFractal      *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal   *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,50,fractal);
  
  //--- Application behavior switches
  bool           PauseOn                = true;
  string         ShowData               = "APP";
  double         StopPrice              = 0.00;
  int            StopAction             = OP_NO_ACTION;

  //--- daily objectives
  double         objDailyGoal           = 0.00;
  
  //--- Trigger Properties
  bool           triggerSet             = false;
  int            triggerAction          = OP_NO_ACTION;
  string         triggerRemarks         = "";
  double         triggerEntry           = 0.00;
  double         triggerStop            = 0.00;
  
  //--- Session metrics
  int            sDailyDir              = DirectionNone;
  int            sBiasDir               = DirectionNone;
  ReservedWords  sBiasState             = NoState;

  //--- PipFractal metrics
  int            pfDir                  = DirectionNone;
  double         pfHighBar              = 0.00;
  double         pfLowBar               = 0.00;
  
  //--- Fractal metrics
  int            fDailyDir              = DirectionNone;


//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (pfractal.HistoryLoaded())
      if (PauseOn)
        Pause(Message,"Event Trapper");
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    static bool gdOneTime                = true;
    
    fractal.Update();
    pfractal.Update();
    
    pfractal.ShowFiboArrow();
    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      session[type].Update();

      if (session[type].IsOpen())
        leadSession    = session[type];
    }
    
    if (IsChanged(gdOneTime,false))
      SetDailyAction();
  }


//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string          rsComment        = EnumToString(leadSession.Type());
      
    if (triggerSet)
      UpdateLabel("lbTriggerState","Fired "+ActionText(triggerAction),clrYellow);
    else
      UpdateLabel("lbTriggerState","Waiting..."+
                  " t:"+DoubleToStr(pfHighBar,Digits)+
                  " b:"+DoubleToStr(pfLowBar,Digits),clrDarkGray);
      
 
    Append(rsComment,"Long: "+DoubleToStr(OrderMargin(OP_BUY),1)+"%\n"+
                     "Short: "+DoubleToStr(OrderMargin(OP_SELL),1)+"%\n"+
                     "Bias: "+DirText(sBiasDir)+" "+EnumToString(sBiasState)+"\n"+
                     "Goal: "+DoubleToStr(objDailyGoal,0),"\n");
                     
    if (ShowData=="FRACTAL"||ShowData=="FIBO")
      fractal.RefreshScreen();
    
    if (ShowData=="PIPMA")
      pfractal.RefreshScreen();
    
    if (ShowData=="APP")
      Comment(rsComment);
  }

//+------------------------------------------------------------------+
//| SetTrigger - validates current strategy, sets bounds and limits  |
//+------------------------------------------------------------------+
void SetTrigger(EventType Event)
  {
    if (!triggerSet)
    {
//      if (Action==OP_SELL && Close[0]<Stop)
//        return;
//        
//      if (Action==OP_BUY && Close[0]>Stop)
//        return;

//      if (OrderMargin(Action)<=ordEQMaxRisk)
//      {
//        triggerSet                   = true;
//        triggerAction                = Action(pfractal.Direction;
//        triggerRemarks               = EnumToString(Event);
//        triggerEntry                 = Entry;
//        triggerStop                  = Stop;
//
//        OpenMITOrder(Action,Entry,Stop,0.00,0.00,Remarks);
//        OpenLimitOrder(Action,Stop,Entry,0.00,Pip(3,InPoints),Remarks);

//        CallPause("New Trigger\n"+Remarks);
//      }
    }
  }

//+------------------------------------------------------------------+
//| Rebalance - Rebalance Equity Load based on event                 |
//+------------------------------------------------------------------+
void Rebalance(EventType Event)
  {
    CallPause("Rebalancing event "+EnumToString(Event));

//    if (triggerSet)
//      triggerSet                     = false;
      
    pfHighBar                        = pfractal.Range(Top);
    pfLowBar                         = pfractal.Range(Bottom);
    
    if (Event==NewMinor)
    {
      if (pfractal.Fibonacci(Origin,Expansion,Expansion,InDecimal)>FiboPercent(Fibo23))
      {
        CallPause("Good time to trade contrarian?");
      }
    }
    else
    {
//      SetTrigger(Event);
//      CheckEquity();
    }    
//      SetStopPrice(OP_SELL,leadSession[Active].Resistance);
//      SetStopPrice(OP_BUY,leadSession[Active].Support);
  }
  
//+------------------------------------------------------------------+
//| AnalyzePipMA - PipMA Analysis routine                            |
//+------------------------------------------------------------------+
void AnalyzePipMA(void)
  {
    if (pfractal.HistoryLoaded())
    {
      if (pfractal.Event(NewHigh))
        if (IsChanged(pfDir,DirectionUp))
          Rebalance(NewHigh);

      if (pfractal.Event(NewLow))
        if (IsChanged(pfDir,DirectionDown))
          Rebalance(NewLow);
          
      if (pfractal.Event(NewMajor))
        CallPause("pipMA-New Major");
          
      if (pfractal.Event(NewMinor))
        CallPause("pipMA-New Minor");

//       if (IsLower(pfractal.Range(Top),pfHighBar))
//         SetTrigger(OP_SELL,"pfHighBar Drop @"+DoubleToStr(pfHighBar,Digits),pfLowBar,pfHighBar);
//
//       if (IsHigher(pfractal.Range(Bottom),pfLowBar))
//         SetTrigger(OP_BUY,"pfHighBar Rise @"+DoubleToStr(pfLowBar,Digits),pfHighBar,pfLowBar);
    }
    else
    {
      pfHighBar       = pfractal.Range(Top);
      pfLowBar        = pfractal.Range(Bottom);
    }
  }

//+------------------------------------------------------------------+
//| AnalyzeSession - Session Analysis routine                        |
//+------------------------------------------------------------------+
void AnalyzeSession(void)
  {    
//    if (leadSession.Event(SessionOpen))
//      sevents.SetEvent(SessionOpen);
    
    if (IsChanged(sBiasDir,Direction(leadSession.Bias(),InAction)))
      Rebalance(NewTradeBias);
      
//    if (IsChanged(sBiasState,leadSession[Active].State))
//      Rebalance(NewState);
  }

//+------------------------------------------------------------------+
//| SetDailyAction - sets up the daily trade ranges and strategy     |
//+------------------------------------------------------------------+
void SetDailyAction(void)
  {
    fDailyDir         = fractal.Direction(fractal.State(Major));
    sDailyDir         = Direction(session[Daily].Pivot(Active)-session[Daily].Pivot(Prior));
    
    objDailyGoal      = (AccountBalance()*(inpDailyTarget/100))+AccountBalance();
    
    SetTradeResume();
    CallPause("Daily Action");
  }

//+------------------------------------------------------------------+
//| CheckTrigger - Checks trigger for order events                   |
//+------------------------------------------------------------------+
void CheckTriggers(void)
  {
    if (triggerSet)
    {
      if (OrderFulfilled())
        triggerSet       = false;
        
      if (!IsBetween(Close[0],triggerEntry,triggerStop))
        triggerSet       = false;
    }
    
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (AccountEquity()>objDailyGoal)
    {
//      CloseOrders(CloseAll);
//      SetProfitPolicy(eqhalt);
    }
    
    if (IsEqual(Close[0],StopPrice))
      CallPause("Stop Price hit @"+DoubleToStr(StopPrice,Digits));
      
    AnalyzePipMA();
    AnalyzeSession();
    CheckTriggers();
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PRICE")
    {
      StopPrice               = StrToDouble(Command[1]);
      StopAction              = ActionCode(Command[2]);
    }
    
    if (Command[0]=="PAUSE")
        PauseOn    = true;

    if (Command[0]=="PLAY")
        PauseOn    = false;
        
    if (Command[0]=="SHOW")
        ShowData        = Command[1];        
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
    
    if (session[Daily].Event(SessionOpen))
      SetDailyAction();
      
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

    NewLabel("lbTriggerState","",350,5);
    
    leadSession           = session[Daily];
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete session[type];      
  }