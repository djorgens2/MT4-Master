//+------------------------------------------------------------------+
//|                                                       man-v3.mq4 |
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
input int       inpIdleTrigger          = 50;    // Market idle trigger
input int       inpEQChgPct             = 2;     // Lead order equity% change event
input YesNoType inpShowPolyArrows       = No;    // Show poly direction change arrows
  
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
  CPipFractal   *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,inpIdleTrigger,fractal);
  CEvent        *pfevents               = new CEvent();
  
  //--- Application behavior switches
  bool           PauseOn                = true;
  string         ShowData               = "APP";

  //--- Equity performance operationals
  enum EquityDimension {
                         eqHigh,
                         eqLow,
                         eqNet
                       };
                       
  double         eqBounds[3][2];
    
  //--- PipFractal metrics
  int            pfPolyDir              = DirectionNone;
  double         pfPolyBounds[2]        = {0.00,0.00};
  int            pfPolyChange           = 0;
  int            pfStdDevDir            = DirectionNone;
  int            pfState                = NoState;

  //--- Session metrics
  int            sDailyDir              = DirectionNone;
  int            sBiasDir               = DirectionNone;

  bool           sHedging               = false;
  bool           sTrap                  = false;
  bool           sAlert                 = false;
  bool           sCorrection            = false;
  bool           sBreakout              = false;
  bool           sReversal              = false;
  bool           sValidSession          = false;

  //--- Fractal metrics
  int            fDailyDir              = DirectionNone;
  int            fState                 = NoState;  

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
    static bool gdOneTime                = true;
    
    pfevents.ClearEvents();
        
    fractal.Update();
    pfractal.Update();
    
//    pfractal.ShowFiboArrow();
    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      session[type].Update();

      if (session[type].IsOpen())
        leadSession    = session[type];
        
      if (session[type].Event(NewBreakout))
        sBreakout                      = true;

      if (session[type].Event(NewReversal))
        sReversal                      = true;
    }
    
    if (IsChanged(gdOneTime,false))
      SetDailyAction();
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string          rsComment        = EnumToString(leadSession.Type())+" "+ActionText(pfPolyDir);
      
    Append(rsComment,"Long: "+DoubleToStr(OrderMargin(OP_BUY),1)+"%\n"
                     "Short: "+DoubleToStr(OrderMargin(OP_SELL),1)+"%\n","\n");

    //--- PipMA Display
    UpdateDirection("lbPMPolyDir",pfPolyDir,DirColor(pfPolyDir),10);
    UpdateDirection("lbPMBias",pfractal.Direction(Pivot),DirColor(pfractal.Direction(Pivot)),10);

    if (pfractal.Direction(Term)==pfractal.Direction(Boundary))
      UpdateDirection("lbPMDiv",DirectionNone,clrLightGray,10);
    else
      UpdateDirection("lbPMDiv",pfractal.Direction(Boundary),DirColor(pfractal.Direction(Boundary)),10);

    if (pfractal.Direction(Range)==pfractal.Direction(Boundary))
      UpdateDirection("lbPMRev",DirectionNone,clrLightGray,10);
    else
      UpdateDirection("lbPMRev",pfractal.Direction(Boundary),DirColor(pfractal.Direction(Boundary)),10);

    UpdateDirection("lbPMStdDevDir",pfractal.Direction(StdDev),DirColor(pfractal.Direction(StdDev)),10);
    
    //--- Session Display
    UpdateDirection("lbSDailyDir",sDailyDir,DirColor(sDailyDir),20);
    UpdateDirection("lbSTradeDir",Direction(session[Daily].Bias(Active,Pivot),InAction),DirColor(Direction(session[Daily].Bias(Active,Pivot),InAction)),10);
    UpdateDirection("lbSBiasDir",sBiasDir,DirColor(sBiasDir),10);
    
    if (sTrap)
      UpdateDirection("lbSTrap",leadSession[Active].BreakoutDir,leadSession[Active].BreakoutDir,10);
    else
      UpdateDirection("lbSTrap",DirectionNone,clrLightGray,10);
      

    if (sAlert)
      UpdateDirection("lbSAlert",sBiasDir,DirColor(sBiasDir),10);
    else
      UpdateDirection("lbSAlert",DirectionNone,clrLightGray,10);

    if (sCorrection)
      UpdateDirection("lbSCorrection",sBiasDir,DirColor(sBiasDir),10);
    else
      UpdateDirection("lbSCorrection",DirectionNone,clrLightGray,10);

    if (sBreakout)
      UpdateDirection("lbSBreakout",sBiasDir,DirColor(sBiasDir),10);
    else
      UpdateDirection("lbSBreakout",DirectionNone,clrLightGray,10);
          
    if (sReversal)
      UpdateDirection("lbSReversal",sBiasDir,DirColor(sBiasDir),10);
    else
      UpdateDirection("lbSReversal",DirectionNone,clrLightGray,10);
          
    if (sValidSession)
      UpdateLabel("lbSValidSession",BoolToStr(leadSession.Bias(Active,Pivot)==OP_BUY,"LONG","SHORT"),DirColor(Direction(leadSession.Bias(Active,Pivot),InAction)),10);
    else
      UpdateLabel("lbSValidSession","HEDGE",DirColor(Direction(leadSession.Bias(Active,Pivot),InAction)),10);

    UpdateLine("lnPivot",leadSession.Pivot(Active),STYLE_SOLID,clrSteelBlue);
    UpdateLine("lnOffSession",session[Daily].Pivot(OffSession),STYLE_DOT,clrSteelBlue);
    UpdateLine("lnPrior",session[Daily].Pivot(Prior),STYLE_DOT,clrGoldenrod);
    UpdateLine("lnResistance",leadSession[Active].Resistance,STYLE_SOLID,clrForestGreen);
    UpdateLine("lnSupport",leadSession[Active].Support,STYLE_SOLID,clrFireBrick);

    if (ShowData=="FRACTAL"||ShowData=="FIBO")
      fractal.RefreshScreen();
    
    if (ShowData=="PIPMA")
      pfractal.RefreshScreen();
    
    if (ShowData=="APP")
      Comment(rsComment);
      
    
  }

//+------------------------------------------------------------------+
//| EquityCheck - seeks to preserve equity by monitoring eq% change  |
//+------------------------------------------------------------------+
void EquityCheck(void)
  {    
    string ecMessage        = "";
    double ecLotValue       = 0.00;
    
    for (int ec=OP_NO_ACTION;ec<=OP_SELL;ec++)
    {
      ecLotValue          = LotValue(ec,Net,InEquity);

      if (IsLower(ecLotValue,eqBounds[BoolToInt(ec==OP_NO_ACTION,eqNet,ec)][eqLow]))
        ecMessage +="New Low on "+BoolToStr(ec==OP_NO_ACTION,"All Trades",ActionText(ec))+"\n";
          
      if (IsHigher(ecLotValue,eqBounds[BoolToInt(ec==OP_NO_ACTION,eqNet,ec)][eqHigh]))
        ecMessage +="New High on "+BoolToStr(ec==OP_NO_ACTION,"All Trades",ActionText(ec))+"\n";
    }
//    if (IsEqual(OrderMargin(Action(sTradeDir,InDirection)),0.00))    
//    if (StringLen(ecMessage)>0)
//      CallPause(ecMessage);
  }

//+------------------------------------------------------------------+
//| SendOrder - verifies margin requirements and opens new positions |
//+------------------------------------------------------------------+
void SendOrder(int Direction, bool Contrarian)
  {
    int    soAction     = Action(Direction,InDirection,Contrarian);
    bool   soOpenOrder  = false;
    string soFibo       = " "+DoubleToStr(pfractal.Fibonacci(Term,Expansion,Now,InPercent),1)+"%";
    
    if (LotCount(soAction)==0.00)
      soOpenOrder       = true;
    else
      if (fabs(LotValue(soAction,Smallest,InEquity))>ordEQMinProfit)
        soOpenOrder     = true;
        
    //if (soOpenOrder)
    //{
    //  OpenOrder(soAction,BoolToStr(Contrarian,"Contrarian"+soFibo,"Trend"+soFibo));
    //  CallPause("New Order entry");
    //}
  }

//+------------------------------------------------------------------+
//| AnalyzePipMA - PipMA Analysis routine                            |
//+------------------------------------------------------------------+
void AnalyzePipMA(void)
  {
    if (pfractal.HistoryLoaded())
    {
      if (pfractal.Event(NewHigh))
      {
        pfevents.SetEvent(NewHigh);
        
        if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)))
          if (IsChanged(pfPolyDir,DirectionUp))
          {
            pfPolyBounds[OP_BUY]=High[0];
            pfevents.SetEvent(NewPoly);
          }
      }
      else    
      if (pfractal.Event(NewLow))
      {  
        pfevents.SetEvent(NewLow);

        if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
          if (IsChanged(pfPolyDir,DirectionDown))
          {
            pfPolyBounds[OP_SELL]=Low[0];
            pfevents.SetEvent(NewPoly);
          }
       }
    }
    
    if (pfevents[NewPoly])
    {
      if (inpShowPolyArrows==Yes)
        NewArrow(BoolToInt(pfPolyDir==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
                 DirColor(pfPolyDir,clrYellow,clrRed),
                 "pfPolyDir"+IntegerToString(pfPolyChange++));

      CallPause("New Poly");
      pfStdDevDir              = DirectionNone;
    } 
    
    if (pfractal.Event(NewStdDev))
    {
      pfStdDevDir              = pfractal.Direction(StdDev);
      
      if (inpShowPolyArrows==Yes)
        NewArrow(BoolToInt(pfractal.Direction(StdDev)==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
                 DirColor(pfractal.Direction(StdDev),clrGoldenrod,clrFireBrick),
                 "pfStdDevDir"+IntegerToString(pfPolyChange++));

      CallPause("New Standard Deviation");
    } 
    
  }

//+------------------------------------------------------------------+
//| AnalyzeFractal - Fractal Analysis routine                        |
//+------------------------------------------------------------------+
void AnalyzeFractal(void)
  {

  }

//+------------------------------------------------------------------+
//| ManageOrders - Looks for entry points and executes trades        |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {
    if (sDailyDir==sBiasDir)
      sHedging     = false;
    else
      sHedging     = true;
      
    if (sHedging)
    {}
    else
    {
      //if (LotCount(Action(sBiasDir,InDirection))*Spread(InPips)<EquityPercent())
    }
    
  }

//+------------------------------------------------------------------+
//| AnalyzeSession - Session Analysis routine                        |
//+------------------------------------------------------------------+
void AnalyzeSession(void)
  {
    if (leadSession.Event(SessionOpen))
    {
      if (leadSession.Type()==Daily)
        sDailyDir         = Direction(session[Daily].Pivot(OffSession)-session[Daily].Pivot(Prior));

      CallPause("Lead session open: "+EnumToString(leadSession.Type()));
    }
    
    if (IsChanged(sBiasDir,Direction(leadSession.Bias(Active,Pivot),InAction)))
      sAlert                           = true;
      
    if (Direction(leadSession.Bias(Active,Pivot),InAction)==leadSession[Active].BreakoutDir)
    {
      sAlert                           = false;
      sValidSession                    = true;
    }
    else
    {
      sAlert                           = true;
      sValidSession                    = false;
    }
      
    if (IsBetween(Close[0],leadSession[Active].Support,leadSession[Active].Resistance))
    {
      if (sReversal||sBreakout)
        sTrap                          = true;
    }
    else
      if (sReversal)
        sCorrection                    = true;
        
  }

//+------------------------------------------------------------------+
//| SetDailyAction - sets up the daily trade ranges and strategy     |
//+------------------------------------------------------------------+
void SetDailyAction(void)
  {
    pfPolyChange      = 0;
    fDailyDir         = fractal.Direction(fractal.State(Major));
          
    sTrap                              = false;
    sAlert                             = false;
    sCorrection                        = false;
    sReversal                          = false;
    sBreakout                          = false;
    sValidSession                      = false;
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (session[Daily].Event(SessionOpen))
      SetDailyAction();
      
    AnalyzePipMA();
    AnalyzeSession();
    
    EquityCheck();
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
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

    leadSession           = session[Daily];
    
    NewLine("lnOffSession");
    NewLine("lnPrior");
    NewLine("lnResistance");
    NewLine("lnSupport");
    NewLine("lnPivot");
      
    NewLabel("lbPMHead","------------- PipMA -----------",360,5,clrDarkGray);
    NewLabel("lbPMSubHead","Poly  Bias  Div  Rev  StdDev",360,16,clrDarkGray);
    NewLabel("lbPMPolyDir","x",366,28,clrDarkGray);
    NewLabel("lbPMBias","x",392,28,clrDarkGray);
    NewLabel("lbPMDiv","x",415,28,clrDarkGray);
    NewLabel("lbPMRev","x",437,28,clrDarkGray);
    NewLabel("lbPMStdDevDir","x",468,28,clrDarkGray);

    NewLabel("lbSDailyDir","x",500,12,clrDarkGray);
    
    NewLabel("lbSHead",   "-------------------------- Session ----------------------",525,5,clrDarkGray);
    NewLabel("lbSSubHead"," Daily   Bias  Trap  Alert  Corr  BkOut  Rev  Status",525,16,clrDarkGray);
    NewLabel("lbSTradeDir","x",535,28,clrDarkGray);
    NewLabel("lbSBiasDir","x",564,28,clrDarkGray);
    NewLabel("lbSTrap","x",590,28,clrDarkGray);
    NewLabel("lbSAlert","x",620,28,clrDarkGray);
    NewLabel("lbSCorrection","x",648,28,clrDarkGray);
    NewLabel("lbSBreakout","x",678,28,clrDarkGray);
    NewLabel("lbSReversal","x",706,28,clrDarkGray);
    NewLabel("lbSValidSession","x",728,28,clrDarkGray);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete pfevents;
    
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete session[type];
      
    ObjectDelete("lbPMHead");
    ObjectDelete("lbPMSubHead");
    ObjectDelete("lbPMPolyDir");
    ObjectDelete("lbPMBias");
    ObjectDelete("lbPMDiv");
    ObjectDelete("lbPMRev");
    ObjectDelete("lbPMStdDevDir");

    ObjectDelete("lbSDailyDir");

    ObjectDelete("lbSHead");
    ObjectDelete("lbSSubHead");
    ObjectDelete("lbSTradeDir");
    ObjectDelete("lbSBiasDir");
    ObjectDelete("lbSTrap");
    ObjectDelete("lbSAlert");
    ObjectDelete("lbSCorrection");
    ObjectDelete("lbSBreakout");
    ObjectDelete("lbSReversal");
    ObjectDelete("lbSValidSession");
  }