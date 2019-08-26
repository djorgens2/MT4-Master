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
input bool      inpFIFO                 = true;  // US Rules: FIFO
input bool      inpUniDir               = true;  // US Rules: Non-Hedging
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
                        indSession,
                        indBreak6,
                        indHedge
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
  IndicatorType  ShowLines              = indPipMA;
  double         StopPrice              = 0.00;
  int            StopAction             = OP_NO_ACTION;
  ReservedWords  AlertLevel             = Tick;

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
  double         sHedgeMajor            = 0.00;
  double         sHedgeMinor            = 0.00;

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
  int            pfFOCDir               = DirectionNone;
  EventType      pfFOCEvent             = NoEvent;
    
  int            pfDevDirIdx            = 0;
  int            pfPivotDirIdx          = 0;
  
  //--- Break 6 Monitor  
  double         b6_High                = 0.00;
  double         b6_Low                 = 0.00;
  double         b6_Top                 = 0.00;
  double         b6_Bottom              = 0.00;
  int            b6_Dir                 = DirectionNone;
  
  //--- Fractal metrics
  int            fDailyDir              = DirectionNone;


//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message, ReservedWords EventLevel=Tick, int Action=OP_NO_ACTION)
  {
    int cpMBID     = NoValue;
    
    if (pfractal.HistoryLoaded())
    {
      if (Action==OP_NO_ACTION)
      {
        if (PauseOn)
          if (EventLevel>=AlertLevel)
            Pause(Message,EnumToString(EventLevel)+" Event Trapper");
      }
      else
      {
        if (OrderOn)
        {
          cpMBID = Pause(Message, "Open "+ActionText(Action)+" order?",MB_ICONQUESTION|MB_YESNOCANCEL|MB_DEFBUTTON2);
      
          if (cpMBID==IDYES)
            OpenOrder(Action,Message);

          if (cpMBID==IDNO)
            OpenOrder(Action(Action,InAction,InContrarian),Message);          
        }
        else
        if (PauseOn)
          if (AlertLevel==Tick)
            Pause(Message,EnumToString(EventLevel)+" Order Event Trapper");
      }  
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
    
//    pfractal.ShowFiboArrow();
    
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
//| ShowLines - Updates Lines for the actively requested indicator   |
//+------------------------------------------------------------------+
void ShowLines(void)
  {
    static IndicatorType slIndicator = indPipMA;
    
    if (slIndicator!=ShowLines)
    {
      switch (slIndicator)
      {
      case indHedge:      UpdateLine("lnHedgeMinor",0.00,STYLE_DOT,clrSteelBlue);
                          UpdateLine("lnHedgeMajor",0.00,STYLE_SOLID,clrSteelBlue);
                          break;

        case indSession:  UpdateLine("lnDailyOffsession",0.00,STYLE_DOT,clrGoldenrod);
                          UpdateLine("lnDailyActive",0.00,STYLE_DOT,clrSteelBlue);
                          UpdateLine("lnLeadActive",0.00,STYLE_SOLID,clrSteelBlue);
                          UpdateLine("lnLeadSupport",0.00,STYLE_SOLID,clrFireBrick);
                          UpdateLine("lnLeadResistance",0.00,STYLE_SOLID,clrForestGreen);
                          break;
        case indBreak6:   UpdateLine("lnBreak6Bottom",0.00,STYLE_SOLID,clrFireBrick);
                          UpdateLine("lnBreak6Top",0.00,STYLE_SOLID,clrForestGreen);
                          UpdateLine("lnBreak6Low",0.00,STYLE_DOT,clrFireBrick);
                          UpdateLine("lnBreak6High",0.00,STYLE_DOT,clrForestGreen);
                          break;
      }
      
      slIndicator         = ShowLines;
    }
    
    switch (slIndicator)
    {
      case indHedge:      UpdateLine("lnHedgeMinor",sHedgeMinor,STYLE_DOT,clrSteelBlue);
                          UpdateLine("lnHedgeMajor",sHedgeMajor,STYLE_SOLID,clrSteelBlue);
                          break;

      case indSession:    UpdateLine("lnDailyOffsession",session[Daily].Pivot(OffSession),STYLE_DOT,clrGoldenrod);
                          UpdateLine("lnDailyActive",session[Daily].Pivot(ActiveSession),STYLE_DOT,clrSteelBlue);
                          UpdateLine("lnLeadActive",leadSession.Pivot(ActiveSession),STYLE_SOLID,clrSteelBlue);
                          UpdateLine("lnLeadSupport",leadSession[ActiveSession].Support,STYLE_SOLID,clrFireBrick);
                          UpdateLine("lnLeadResistance",leadSession[ActiveSession].Resistance,STYLE_SOLID,clrForestGreen);

                          break;
      case indBreak6:     UpdateLine("lnBreak6Bottom",b6_Bottom,STYLE_SOLID,clrFireBrick);
                          UpdateLine("lnBreak6Top",b6_Top,STYLE_SOLID,clrForestGreen);
                          UpdateLine("lnBreak6Low",b6_Low,STYLE_DOT,clrFireBrick);
                          UpdateLine("lnBreak6High",b6_High,STYLE_DOT,clrForestGreen);
                          break;

    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string          rsComment        = "Daily:  ["+IntegerToString(session[Daily].SessionHour())+"] "+ActionText(sDailyAction)+" "+DirText(sDailyDir)
                                                  +" "+EnumToString(session[Daily][ActiveSession].TermState)
                                                  +"  ("+BoolToStr(sDailyHold,"Hold","Hedge")+")\n"+
                                       "Lead:   ["+IntegerToString(leadSession.SessionHour())+"] "+EnumToString(leadSession.Type())+" "
                                                  +ActionText(leadSession.Bias(),InAction)+" "
                                                  +EnumToString(leadSession[ActiveSession].TermState)
                                                  +"  ("+BoolToStr(sBiasHold,"Hold","Hedge")+")\n"+
                                       "Break-6: "+DirText(b6_Dir)+"\n"+
                                       "pipMA:   "+DirText(pfFOCDir)+" ["+EnumToString(pfFOCEvent)+"] "+BoolToStr(pfContrarian,"Contrarian","Conforming")+"\n";
      
    if (triggerSet)
      UpdateLabel("lbTriggerState","Fired "+ActionText(triggerAction),clrYellow);
    else
      UpdateLabel("lbTriggerState","Waiting ("+DirText(pfFOCDir)+
                  " "+EnumToString(pfFOCEvent)+"):"+BoolToStr(pfContrarian,"Contrarian","Conforming")+
                  " t:"+DoubleToStr(pfHighBar,Digits)+
                  " b:"+DoubleToStr(pfLowBar,Digits),clrDarkGray);
      
 
    Append(rsComment,"\nAccount Analysis\n"+"-----------------------\n"+
                     "Long:  "+DoubleToStr(OrderMargin(OP_BUY),1)+"%\n"+
                     "Short: "+DoubleToStr(OrderMargin(OP_SELL),1)+"%\n"+
                     "Goal:  "+DoubleToStr(objDailyGoal,0)+"\n"+
                     "Alert: "+EnumToString(AlertLevel),"\n");
                     
    ShowLines();
    
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
void Rebalance(EventType Event, IndicatorType Indicator, ReservedWords EventLevel)
  {
    switch (Event)
    {
      case NewTradeBias:    if (EventLevel==Major)
                              sHedgeMajor        = Close[0];
                            if (EventLevel==Minor)
                              sHedgeMinor        = Close[0];
                            break;                            
      case NewTrend:        if (Indicator==indPipMA)
                              CallPause("New Trend on PipMA",EventLevel);
                            break;
      case NewDirection:    if (Indicator==indPipMA)
                              CallPause("New Direction on PipMA",EventLevel);
                            break;
      case NewFOC:          CallPause("Rebalancing on FOC Change: "+EnumToString(pfFOCEvent)+" on "+StringSubstr(EnumToString(Indicator),3),EventLevel);
                            break;
      case NewContraction:  CallPause("Contracting trade range");
                            break;
      default:              CallPause("Rebalancing event "+EnumToString(Event)+" on "+StringSubstr(EnumToString(Indicator),3),EventLevel);
    }
    
    
    
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
    ReservedWords eeEventLevel      = Tick;
    
    if (OrderOn)
      eeEventLevel                  = Major;

    CallPause("Entry/Exit event "+EnumToString(Event)+" on "+StringSubstr(EnumToString(Indicator),3),eeEventLevel,Action(pfPolyDirMinor,InDirection));
  }
  
//+------------------------------------------------------------------+
//| AnalyzeBreak6 - Checks for intra-session 6 hour trend changes    |
//+------------------------------------------------------------------+
void AnalyzeBreak6(void)
  {    
    if (session[Daily].Event(NewDay))
    {
      b6_High              = Open[0];
      b6_Low               = Open[0];
    }
    else
    if (session[Daily].Event(NewHour))
    {
      b6_Top               = High[iHighest(Symbol(),PERIOD_H1,MODE_HIGH,6)];
      b6_Bottom            = Low[iLowest(Symbol(),PERIOD_H1,MODE_LOW,6)];
    }
    
    if (IsHigher(Close[0],b6_High))
      if (session[Daily].SessionHour()>2)
        if (IsChanged(b6_Dir,DirectionUp))
          Rebalance(NewRally,indBreak6,Major);
    
    if (IsLower(Close[0],b6_Low))
      if (session[Daily].SessionHour()>2)
        if (IsChanged(b6_Dir,DirectionDown))
          Rebalance(NewPullback,indBreak6,Major);
  }

//+------------------------------------------------------------------+
//| AnalyzePipMA - PipMA Analysis routine                            |
//+------------------------------------------------------------------+
void AnalyzePipMA(void)
  {
    static double  apFOCDeviation    = 0.00;
    
    EventType      apFOCEvent        = NoEvent;
    ReservedWords  apAlertLevel      = Tick;
    
    if (pfractal.HistoryLoaded())
    {
      //--- Check FOC State
      if (IsHigher(pfractal.FOC(Deviation),apFOCDeviation))
      {
        if (IsChanged(pfContrarian,true))
          apFOCEvent                 = TrendWane;
            
        if (pfFOCEvent==TrendWane)
          if (pfractal.FOC(Deviation)>inpTolerance)
          {
            apFOCEvent               = TrendCorrection;
            apAlertLevel             = Minor;
          }
      }

      if (IsLower(pfractal.FOC(Deviation),apFOCDeviation))
        if (IsChanged(pfContrarian,false))
          if (IsChanged(pfFOCDir,pfractal.FOCDirection()))
          {
            apFOCEvent               = MarketCorrection;
            apAlertLevel             = Major;
          }            
          else
          {
            apFOCEvent               = TrendResume;
            apAlertLevel             = Minor;
          }
          
      if (IsEqual(pfractal.FOC(Deviation),0,00))
        if (IsEqual(pfractal.FOC(Now),pfractal.FOC(Max)))
          if (!IsEqual(pfFOCEvent,MarketResume))
          {
            pfFOCDir                 = pfractal.FOCDirection(inpTolerance);
            pfContrarian             = false;

            apFOCEvent               = MarketResume;
            apAlertLevel             = Major;
          }

      if (apFOCEvent!=NoEvent)
        if (IsChanged(pfFOCEvent,apFOCEvent))
          Rebalance(NewFOC,indPipMA,apAlertLevel);
    
      //--- Risk Management/Equity Check events
      if (pfractal.Event(NewHigh))
      {
        if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)))
          if (IsChanged(pfPolyDirMajor,DirectionUp))
            Rebalance(NewPoly,indPipMA,Minor);

        if (IsChanged(pfDir,DirectionUp))
          Rebalance(NewHigh,indPipMA,Tick);
      }

      if (pfractal.Event(NewLow))
      {
        if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
          if (IsChanged(pfPolyDirMajor,DirectionDown))
            Rebalance(NewPoly,indPipMA,Minor);

        if (IsChanged(pfDir,DirectionDown))
          Rebalance(NewLow,indPipMA,Tick);
      }
          
      //--- Pivot Directional Change Detection -- very reliable
      if (pfractal.Event(NewMajor))
        if (IsChanged(pfDevDir,pfractal.Direction(Pivot)))
          Rebalance(NewTrend,indPipMA,Major);
        else
          Rebalance(NewMajor,indPipMA,Major);
  
      if (pfractal.Event(NewMinor))
        if (IsChanged(pfDevDir,pfractal.Direction(Pivot)))
          Rebalance(NewDirection,indPipMA,Major);
        else
          Rebalance(NewMinor,indPipMA,Minor);

      //--- Contracting market detection -- noisy but detects market consolidations
      if (IsLower(pfractal.Range(Top),pfHighBar))
        Rebalance(NewContraction,indPipMA,Tick);

      if (IsHigher(pfractal.Range(Bottom),pfLowBar))
        Rebalance(NewContraction,indPipMA,Tick);
              
      //--- Entry/Exit events
      if (IsChanged(pfConforming,pfractal.Direction(RangeHigh)==pfractal.Direction(RangeLow)))
        Rebalance(NewRange,indPipMA,Minor);
    
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
      Rebalance(NewRetrace,indFractal,Tick);

    if (fractal.Event(NewMinor))
      Rebalance(NewMinor,indFractal,Minor);

    if (fractal.Event(NewMajor))
      Rebalance(NewMajor,indFractal,Major);

    if (fractal.Event(MarketCorrection))
      Rebalance(MarketCorrection,indFractal,Major);

    if (fractal.Event(MarketResume))
      Rebalance(MarketResume,indFractal,Major);
  }

//+------------------------------------------------------------------+
//| AnalyzeSession - Session Analysis routine                        |
//+------------------------------------------------------------------+
void AnalyzeSession(void)
  {    
    //--- Lead Session Events
    if (leadSession.Event(SessionOpen))
      CallPause("New Lead Session Open: "+EnumToString(leadSession.Type()));
    
    if (IsChanged(sBiasDir,Direction(leadSession.Bias(),InAction)))
      if (IsChanged(sBiasHold,sDailyDir==Direction(leadSession.Bias(),InAction)))
        Rebalance(NewTradeBias,indSession,Minor);
    
    if (IsChanged(sBiasState,leadSession[ActiveSession].TermState))
      Rebalance(NewState,indSession,Minor);
        
    //--- Daily Session Events
    if (IsChanged(sDailyHold,sDailyDir==Direction(session[Daily].Bias(),InAction)))
      Rebalance(NewTradeBias,indSession,Major);

    if (IsChanged(sDailyState,session[Daily][ActiveSession].TermState))
      Rebalance(NewState,indSession,Major);
  }

//+------------------------------------------------------------------+
//| SetDailyAction - sets up the daily trade ranges and strategy     |
//+------------------------------------------------------------------+
void SetDailyAction(void)
  {
    fDailyDir         = fractal.Direction(fractal.State(Major));
    sDailyDir         = Direction(session[Daily].Pivot(ActiveSession)-session[Daily].Pivot(PriorSession));
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
      
    AnalyzeBreak6();
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
//    if (Command[0]=="PLAN")
//    {
//      planAction           = ActionCode(Command[2]);
//      planPrice            = StrToDouble(Command[1]);
//
//    }    

    if (Command[0]=="PRICE")
    {
      StopPrice            = StrToDouble(Command[1]);
      StopAction           = ActionCode(Command[2]);
    }
    
    if (Command[0]=="LINES")
      if (Command[1]=="PIPMA")
        ShowLines          = indPipMA;
      else
      if (Command[1]=="BREAK6")
        ShowLines          = indBreak6;
      else
      if (Command[1]=="SESSION")
        ShowLines          = indSession;
      else
      if (Command[1]=="FRACTAL")
        ShowLines          = indFractal;
      else
      if (Command[1]=="HEDGE")
        ShowLines          = indHedge;


    if (Command[0]=="ALERT")
      if (Command[1]=="MINOR")
        AlertLevel         = Minor;
      else
      if (Command[1]=="MAJOR")
        AlertLevel         = Major;
      else
        AlertLevel         = Tick;

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
      session[type].ShowDirArrow(true);

    NewLabel("lbTriggerState","",350,5);

    NewLine("lnDailyOffsession");
    NewLine("lnDailyActive");
    NewLine("lnLeadActive");
    NewLine("lnLeadSupport");
    NewLine("lnLeadResistance");
    NewLine("lnMajorBias");
    NewLine("lnMinorBias");
    
    NewLine("lnBreak6Bottom");
    NewLine("lnBreak6Top");
    NewLine("lnBreak6Low");
    NewLine("lnBreak6High");
    
    NewLine("lnHedgeMajor");
    NewLine("lnHedgeMinor");
    
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