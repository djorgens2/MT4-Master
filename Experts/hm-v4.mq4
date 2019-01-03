//+------------------------------------------------------------------+
//|                                                        hm-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "4.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\Session.mqh>

input string   EAHeader                = "";    //+---- Application Options -------+
input int      inpIdleTrigger          = 50;    // Market idle trigger
  
input string   fractalHeader           = "";    //+------ Fractal Options ---------+
input int      inpRangeMin             = 60;    // Minimum fractal pip range
input int      inpRangeMax             = 120;   // Maximum fractal pip range

input string   RegressionHeader        = "";    //+------ Regression Options ------+
input int      inpDegree               = 6;     // Degree of poly regression
input int      inpSmoothFactor         = 3;     // MA Smoothing factor
input double   inpTolerance            = 0.5;   // Directional sensitivity
input int      inpPipPeriods           = 200;   // Short term regression analysis size

input string   SessionHeader           = "";    //+---- Session Hours -------+
input int      inpAsiaOpen             = 1;     // Asian market open hour
input int      inpAsiaClose            = 10;    // Asian market close hour
input int      inpEuropeOpen           = 8;     // Europe market open hour
input int      inpEuropeClose          = 18;    // Europe market close hour
input int      inpUSOpen               = 14;    // US market open hour
input int      inpUSClose              = 23;    // US market close hour


  //--- Class Objects
  CSession     *session[SessionTypes];
  CFractal     *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal  *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CEvent       *events                 = new CEvent();
  
  CSession     *leadSession;
  
  //--- Operational variables
  bool          pause                  = true;
  
  //--- Fractal Operational variables
  
  //--- PipFractal Operational variables
  bool          ctmTrig                = false;
  bool          ctmFire                = false;
  int           ctmAction              = OP_NO_ACTION;
  int           ctmDir                 = DirectionNone;
  double        ctmPivot               = NoValue;

//+------------------------------------------------------------------+
//| SetPause - Sets pause on or off                                  |
//+------------------------------------------------------------------+
void SetPause(void)
  {
    if (pause)
      pause    = false;
    else
      pause    = true;
  }

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (pause)
      Pause(Message,"Event Trapper");
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    events.ClearEvents();

    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      session[type].Update();
      
      if (type<Daily)
        if (session[type].IsOpen())
          leadSession    = session[type];
    }

    fractal.Update();
    pfractal.Update();
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string rsComment      ="";
    
    if (ctmTrig)
      rsComment   = "Looking for new "+ActionText(ctmAction)+"\n"
                    +"Range: "+DoubleToStr(round(Pip(ctmPivot-Close[0],InPips))*ctmDir,0)+"\n"
                    +"Age: "+IntegerToString(fmin(pfractal.Age(RangeHigh),pfractal.Age(RangeLow)));

    if (ctmFire)
      rsComment   = "FIRE!!";
    
//    //--- The Big Fractal Events
//    if (fractal.Event(MarketCorrection))
//      if (fractal.IsMajor(fractal.State(Now)))
//        NewArrow(BoolToInt(fractal[fractal.State(Now)].Direction==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
//                 DirColor(fractal[fractal.State(Now)].Direction,clrYellow,clrRed),
//                 "fmc("+EnumToString(fractal.State(Major))+"):",Close[0],0);
//      else
//        NewArrow(SYMBOL_CHECKSIGN,
//                 DirColor(fractal[fractal.State(Now)].Direction,clrYellow,clrRed),
//                 "fmc("+EnumToString(fractal.State(Minor))+"):",Close[0],0);
//
//    if (fractal.Event(MarketResume))
//        NewArrow(SYMBOL_STOPSIGN,
//                 DirColor(fractal[fractal.State(Now)].Direction,clrYellow,clrRed),
//                 "fmr("+EnumToString(fractal.State(Minor))+"):",Close[0],0);
//
//    if (fractal.Event(NewState))
//    {
//      NewPriceLabel("fo("+EnumToString((ReservedWords)fractal.Origin(State))+"):"+TimeToStr(Time[0]),Close[0],true);
//      UpdatePriceLabel("fo("+EnumToString((ReservedWords)fractal.Origin(State))+"):"+TimeToStr(Time[0]),Close[0],
//                       DirColor(fractal[fractal.State(Major)].Direction,clrYellow,clrRed));
//    }
//    else
//    if (fractal.Event(NewMajor))
//        NewArrow(SYMBOL_DASH,
//                 DirColor(fractal[fractal.State(Major)].Direction,clrYellow,clrRed),
//                 "fnm("+EnumToString(fractal.State(Major))+"):",Close[0],0);
                 
    UpdateLine("ctmPivot",ctmPivot,STYLE_SOLID,DirColor(ctmDir));
    UpdateLine("dOriginTop",fractal.Price(Origin,Top),STYLE_SOLID,clrWhite);
    UpdateLine("dOriginBottom",fractal.Price(Origin,Bottom),STYLE_SOLID,clrWhite);
    UpdateLine("dOriginRoot",fractal.Price(Origin),STYLE_SOLID,clrWhite);

    pfractal.ShowFiboArrow();
    
    Comment(rsComment);
  }

//+------------------------------------------------------------------+
//| EventText                                                        |
//+------------------------------------------------------------------+
string EventText(void)
  {
    string etText    = "";

    for (EventType event=0;event<EventTypes;event++)
      if (session[Daily].Event(event))
        etText       += "\n"+EnumToString(event);
        
    return (etText);
  }

//+------------------------------------------------------------------+
//| AnalysisAlert - Pauses for actionable events                     |
//+------------------------------------------------------------------+
void AnalysisAlert(void)
  {
    //--- Process Big Fractal events
    if (fractal.Event(MarketCorrection))
      if (fractal.IsMajor(fractal.State(Now)))
        CallPause("Major Fractal Market Correction ("+EnumToString(fractal.State(Major))+") "
                  +DirText(fractal[fractal.State(Now)].Direction));
      else
        CallPause("Minor Fractal Market Correction ("+EnumToString(fractal.State(Now))+") "
                  +DirText(fractal[fractal.State(Now)].Direction));

    if (fractal.Event(MarketResume))
        CallPause("Fractal Market Continuation ("+EnumToString(fractal.State(Now))+") "
                  +DirText(fractal[fractal.State(Now)].Direction));

    if (fractal.Event(NewState))
      CallPause("fo("+EnumToString((ReservedWords)fractal.Origin(State))+") "
                  +DirText(fractal[fractal.State(Now)].Direction));
    else
    if (fractal.Event(NewMajor))
      CallPause("Major Market Move ("+EnumToString(fractal.State(Major))+")"
                  +DirText(fractal[fractal.State(Now)].Direction));

    //--- Process Junior Fractal events
    if (pfractal.Event(NewTerm))
      CallPause("Junior Fractal Direction Change ("+DirText(pfractal[Term].Direction)+") ");
    else
    if (pfractal.Event(NewMinor))
      CallPause("Junior Fractal Minor Breakout ("+DirText(pfractal[Term].Direction)+") ");    
    else
    if (pfractal.Event(NewMajor))
      CallPause("Junior Fractal Major Breakout ("+DirText(pfractal[Term].Direction)+") ");      
  }

//+------------------------------------------------------------------+
//| CheckTrend - Monitors and establishes big picture positioning    |
//+------------------------------------------------------------------+
void CheckTrend(void)
  {
  }

//+------------------------------------------------------------------+
//| CheckTerm - Scans for best possible order entry conditions       |
//+------------------------------------------------------------------+
void CheckTerm(void)
  {    
//    if (pfractal.Event(NewTerm))
//      CallPause("Junior Fractal Direction Change ("+DirText(pfractal[Term].Direction)+") ");
//    else
//    if (pfractal.Event(NewMinor))
//      CallPause("Junior Fractal Minor Breakout ("+DirText(pfractal[Term].Direction)+") ");    
//    else
    if (pfractal.Event(NewMajor))
      if (pfractal[Term].Direction==DirectionUp)
        ctmTrigAge        = 0;

    if (pfractal.Event(NewBoundary))
    {
      ctmTrig             = true;
      ctmAction           = Action(pfractal[Term].Direction,InDirection,InContrarian);
      ctmDir              = pfractal[Term].Direction;
      ctmPivot            = Close[0];

      if (ctmFire)
      {
        CloseLimitOrder();
        CloseMITOrder();
        
        ctmFire           = false;
      }
    }
    
    if (ctmTrig)
    {
      if (ctmAction==OP_BUY)
        ctmPivot          = fmin(ctmPivot,Close[0]);
        
      if (ctmAction==OP_SELL)
        ctmPivot          = fmax(ctmPivot,Close[0]);

      if (Pip(round(ctmPivot-Close[0]),InPips)*ctmDir>fmin(pfractal.Age(RangeHigh),pfractal.Age(RangeLow)))
      {
        ctmFire           = true;
        ctmTrig           = false;
      }
    }
  }

//+------------------------------------------------------------------+
//| ExecuteTrades - Opens new positions within risk limits           |
//+------------------------------------------------------------------+
void ExecuteTrades(void)
  {
    if (ctmFire)
      if (OpenOrder(ctmAction,"Term Trigger"))
        ctmFire           = false;
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    AnalysisAlert();
    
    CheckTrend();
    CheckTerm();
    
    ExecuteTrades();    
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PAUSE")
      SetPause();
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
    
    NewLine("ctmPivot");

    NewLine("dOriginTop");
    NewLine("dOriginBottom");
    NewLine("dOriginRoot");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete events;
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }