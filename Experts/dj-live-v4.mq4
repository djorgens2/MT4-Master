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
input YesNoType inpShowBreakouts        = No;    // Show session breakouts/reversals
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

input string    SessionHeader           = "";    //+---- Session Configuration -------+
input int       inpAsiaOpen             = 1;     // Asian market open hour
input int       inpAsiaClose            = 10;    // Asian market close hour
input int       inpEuropeOpen           = 8;     // Europe market open hour
input int       inpEuropeClose          = 18;    // Europe market close hour
input int       inpUSOpen               = 14;    // US market open hour
input int       inpUSClose              = 23;    // US market close hour
input int       inpGMTOffset            = 0;     // Offset from GMT+3 (Asia Open)

  //--- Indicators
  enum IndicatorType  {
                        indFractal,
                        indPipMA,
                        indSession  
                      };

  //--- Class Objects
  CSession      *session[SessionTypes];
  CSession      *leadSession;

  CFractal      *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal   *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,50,fractal);
  
  //--- Application behavior switches
  bool           PauseOn                = true;
  bool           OrderOn                = true;
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
  int            sDailyAction           = OP_NO_ACTION;
  int            sDailyDir              = DirectionNone;
  ReservedWords  sDailyState            = NoState;
  bool           sDailyHold             = false;
  int            sBiasDir               = DirectionNone;
  ReservedWords  sBiasState             = NoState;
  bool           sBiasHold              = false;

  //--- PipFractal metrics
  double         pfHighBar              = 0.00;
  double         pfLowBar               = 0.00;
  double         pfPolyPivot[2]         = {0.00,0.00};
  bool           pfConforming           = false;
  bool           pfContrarian           = false;  

  int            pfDir                  = DirectionNone;
  int            pfDevDir               = DirectionNone;
  int            pfPolyDirMajor         = DirectionNone;
  int            pfPolyDirMinor         = DirectionNone;
  
  int            pfDevDirIdx            = 0;
  
  
  //--- Fractal metrics
  int            fDailyDir              = DirectionNone;


//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message, int Action=OP_NO_ACTION)
  {
    int cpMBID     = NoValue;
    
    if (pfractal.HistoryLoaded())
    {
      if (Action==OP_NO_ACTION)
      {
        if (PauseOn)
          Pause(Message,"Event Trapper");
      }
      else
      if (PauseOn)
        if (OrderOn)
        {
          cpMBID = Pause(Message, "Open "+ActionText(Action)+" order?",MB_ICONQUESTION|MB_YESNOCANCEL|MB_DEFBUTTON2);
      
          if (cpMBID==IDYES)
            OpenOrder(Action,Message);

          if (cpMBID==IDNO)
            OpenOrder(Action(Action,InAction,InContrarian),Message);          
        }
        else
          Pause(Message,"Event Trapper");
    }
    
    if (IsEqual(Close[0],StopPrice))
    {
      if (PauseOn)
        Pause(Message,"Price Trapper");

        OpenOrder(StopAction,"Test");

      //CloseOrders(CloseAll,Action(StopAction,InAction,InContrarian));
      //if (Test)
      //  if (++tidx<ArraySize(trec))
      //  {
      //    StopPrice   = trec[tidx].price;
      //    StopAction  = trec[tidx].action;
      //  }
      //  else
      //    Test     = false;
      //else
        StopPrice = 0.00;
    }
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
    string          rsComment        = "Daily:  ["+IntegerToString(session[Daily].SessionHour())+"] "+ActionText(sDailyAction)+" "+DirText(sDailyDir)
                                                  +" "+EnumToString(session[Daily][Active].State)
                                                  +"  ("+BoolToStr(sDailyHold,"Hold","Hedge")+")\n"+
                                       "Lead:   ["+IntegerToString(leadSession.SessionHour())+"] "+EnumToString(leadSession.Type())+" "
                                                  +ActionText(leadSession.Bias(),InAction)+" "
                                                  +EnumToString(leadSession[Active].State)
                                                  +"  ("+BoolToStr(sBiasHold,"Hold","Hedge")+")\n";
      
    if (triggerSet)
      UpdateLabel("lbTriggerState","Fired "+ActionText(triggerAction),clrYellow);
    else
      UpdateLabel("lbTriggerState","Waiting..."+
                  " t:"+DoubleToStr(pfHighBar,Digits)+
                  " b:"+DoubleToStr(pfLowBar,Digits),clrDarkGray);
      
 
    Append(rsComment,"\nMargin Analysis\n"+"-----------------------\n"+
                     "Long: "+DoubleToStr(OrderMargin(OP_BUY),1)+"%\n"+
                     "Short: "+DoubleToStr(OrderMargin(OP_SELL),1)+"%\n"+
                     "Goal: "+DoubleToStr(objDailyGoal,0),"\n");
                     

    UpdateLine("lnDailyOffsession",session[Daily].Pivot(OffSession),STYLE_DOT,clrGoldenrod);
    UpdateLine("lnDailyActive",session[Daily].Pivot(Active),STYLE_DOT,clrSteelBlue);
    UpdateLine("lnLeadActive",leadSession.Pivot(Active),STYLE_SOLID,clrSteelBlue);
    UpdateLine("lnLeadSupport",leadSession[Active].Support,STYLE_SOLID,clrFireBrick);
    UpdateLine("lnLeadResistance",leadSession[Active].Resistance,STYLE_SOLID,clrForestGreen);

    if (ShowData=="FRACTAL"||ShowData=="FIBO")
      fractal.RefreshScreen();
    
    if (ShowData=="PIPMA")
      pfractal.RefreshScreen();
    
    if (ShowData=="APP")
    {
      Comment(rsComment);
    }
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
void Rebalance(EventType Event, IndicatorType Indicator)
  {
    if (Event==NewContraction)
    {}
    else
      CallPause("Rebalancing event "+EnumToString(Event)+" on "+StringSubstr(EnumToString(Indicator),3));
    
    pfHighBar                        = pfractal.Range(Top);
    pfLowBar                         = pfractal.Range(Bottom);
    
//      SetStopPrice(OP_SELL,leadSession[Active].Resistance);
//      SetStopPrice(OP_BUY,leadSession[Active].Support);
  }
  

//+------------------------------------------------------------------+
//| SetEntryExit - Catches polyline changes for order events         |
//+------------------------------------------------------------------+
void SetEntryExit(EventType Event, IndicatorType Indicator)
  {
    static bool   eeTrigger         = false;
    int           eeAction          = Action(pfPolyDirMinor,InDirection);
    
    

    CallPause("Entry/Exit event "+EnumToString(Event)+" on "+StringSubstr(EnumToString(Indicator),3),Action(pfPolyDirMinor,InDirection));
  }
  
//+------------------------------------------------------------------+
//| AnalyzePipMA - PipMA Analysis routine                            |
//+------------------------------------------------------------------+
void AnalyzePipMA(void)
  {
    static double apFOCdeviation    = 0.00;

    bool          apTrig            = false;
    double        apPivot           = 0.00;
    
    if (pfractal.HistoryLoaded())
    {
      //--- Check FOC State
      if (IsHigher(pfractal.FOC(Deviation),apFOCdeviation))
        pfContrarian                  = true;
      else
      if (IsLower(pfractal.FOC(Deviation),apFOCdeviation))
        pfContrarian                  = false;
    
      //--- Risk Management/Equity Check events
      if (pfractal.Event(NewHigh))
      {
        if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)))
          if (IsChanged(pfPolyDirMajor,DirectionUp))
            Rebalance(NewPoly,indPipMA);

        if (IsChanged(pfDir,DirectionUp))
          Rebalance(NewHigh,indPipMA);
      }

      if (pfractal.Event(NewLow))
      {
        if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
          if (IsChanged(pfPolyDirMajor,DirectionDown))
            Rebalance(NewPoly,indPipMA);

        if (IsChanged(pfDir,DirectionDown))
          Rebalance(NewLow,indPipMA);
      }
          
      if (pfractal.Event(NewMajor))
      {
        Rebalance(NewMajor,indPipMA);
        apTrig          = true;
      }
  
      if (pfractal.Event(NewMinor))
      {
        Rebalance(NewMinor,indPipMA);
        apTrig          = true;
      }

      if (IsLower(pfractal.Range(Top),pfHighBar))
        Rebalance(NewContraction,indPipMA);

      if (IsHigher(pfractal.Range(Bottom),pfLowBar))
        Rebalance(NewContraction,indPipMA);
        
      if (apTrig)
      {
        if (IsChanged(pfDevDir,pfractal.Direction(Pivot)))
        {
           NewArrow(SYMBOL_DASH,DirColor(pfDevDir,clrYellow,clrRed),"pfDev-"+IntegerToString(pfDevDirIdx++));

           apPivot         = pfractal.Direction(Pivot);
           apTrig          = false;           
        }
      }
      
      //--- Entry/Exit events
      if (IsChanged(pfConforming,pfractal.Direction(RangeHigh)==pfractal.Direction(RangeLow)))
        Rebalance(NewRange,indPipMA);
    
      if (IsChanged(pfPolyDirMinor,pfractal.Direction(Polyline)))
        SetEntryExit(NewPoly,indPipMA);
    }
    else
    {
      pfHighBar       = pfractal.Range(Top);
      pfLowBar        = pfractal.Range(Bottom);
    }
  }

//+------------------------------------------------------------------+
//| AnalyzeFractal - Fractal Analysis routine                        |
//+------------------------------------------------------------------+
void AnalyzeFractal(void)
  {    
    if (fractal.Event(NewRetrace))
      Rebalance(NewRetrace,indFractal);

    if (fractal.Event(NewMinor))
      Rebalance(NewMinor,indFractal);

    if (fractal.Event(NewMajor))
      Rebalance(NewMajor,indFractal);

    if (fractal.Event(MarketCorrection))
      Rebalance(MarketCorrection,indFractal);

    if (fractal.Event(MarketResume))
      Rebalance(MarketResume,indFractal);
  }

//+------------------------------------------------------------------+
//| AnalyzeSession - Session Analysis routine                        |
//+------------------------------------------------------------------+
void AnalyzeSession(void)
  {    
    if (leadSession.Event(SessionOpen))
      CallPause("New Lead Session Open: "+EnumToString(leadSession.Type()));
      
    if (IsChanged(sDailyHold,sDailyDir==Direction(session[Daily].Bias(),InAction)))
      Rebalance(NewTradeBias,indSession);
    
    if (IsChanged(sBiasDir,Direction(leadSession.Bias(),InAction)))
      if (IsChanged(sBiasHold,sDailyDir==Direction(leadSession.Bias(),InAction)))
        Rebalance(NewTradeBias,indSession);
    
    if (IsChanged(sBiasState,leadSession[Active].State))
      Rebalance(NewState,indSession);
        
    if (IsChanged(sDailyState,session[Daily][Active].State))
      Rebalance(NewState,indSession);
  }

//+------------------------------------------------------------------+
//| SetDailyAction - sets up the daily trade ranges and strategy     |
//+------------------------------------------------------------------+
void SetDailyAction(void)
  {
    fDailyDir         = fractal.Direction(fractal.State(Major));
    sDailyDir         = Direction(session[Daily].Pivot(Active)-session[Daily].Pivot(Prior));
    sDailyAction      = Action(sDailyDir,InDirection);
    
    objDailyGoal      = (AccountBalance()*(inpDailyTarget/100))+AccountBalance();
    
    SetTradeResume();
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
    AnalyzeFractal();
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
    
    if (Command[0]=="ORDER")
      if (Command[1]=="ON")
        OrderOn    = true;
      else
        OrderOn    = false;

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
    
    session[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
    
    for (SessionType type=Daily;type<SessionTypes;type++)
      if (inpShowBreakouts==Yes)
        session[type].ShowDirArrow(true);
      else
        session[type].ShowDirArrow(false);

    NewLabel("lbTriggerState","",350,5);

    NewLine("lnDailyOffsession");
    NewLine("lnDailyActive");
    NewLine("lnLeadActive");
    NewLine("lnLeadSupport");
    NewLine("lnLeadResistance");
    
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