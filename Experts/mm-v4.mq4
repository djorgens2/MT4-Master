//+------------------------------------------------------------------+
//|                                                        mm-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipFractal.mqh>
#include <Class\PriceEvent.mqh>
#include <Class\TrendRegression.mqh>

#include <manual.mqh>

input string prHeader                = "";    //+---- Regression Inputs -----+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpPipPeriods           = 200;   // Pip history regression periods
input int    inpTrendPeriods         = 24;    // Trend regression periods
input int    inpSmoothFactor         = 3;     // Moving Average smoothing factor
input double inpTolerance            = 0.5;   // Trend change sensitivity

input string fractalHeader           = "";    //+----- Fractal inputs -----+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range


//--- Class definitions
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);  
  CTrendRegression *trend            = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);

   
//--- Operational variables
  int               mmDirection      = DirectionNone;
  int               mmAction         = OP_NO_ACTION;
  bool              mmNewDirection   = false;
  int               mmEventCount     = 0;
  
  CPriceEvent      *mmEvents[];
  CPriceEvent      *ActiveEvent;
  CPriceEvent      *PriorEvent;
  

//--- Order Manager operational variables
  int               omFiboLevel      = Fibo50;
  int               omQuota          = 0;
  
//+------------------------------------------------------------------+
//| RefreshScreen - repaints screen data                             |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string rsReport   = "";
    string rsEvent    = "";
    
    if (pfractal.Event(NewHigh))
      rsEvent         = "PipMA (New High)";

    if (pfractal.Event(NewLow))
      rsEvent         = "PipMA (New Low)";

    rsReport         += "PipMA: "+DirText(pfractal.Direction())
                       +" "+DoubleToStr(pfractal.FOC(Now),1)
                       +" "+DoubleToStr(pfractal.FOC(Max),1)
                       +" "+DoubleToStr(pfractal.FOC(Deviation),1)
                       +" "+DoubleToStr(pfractal.FOC(Retrace)*100.0,2)+"%"
                       +" "+rsEvent+"\n\n";

    rsReport         += "*---------- Term Data --------------*\n";
    rsReport         += " Direction: " +DirText(pfractal[Term].Direction)+"\n";
    rsReport         += "Prior: "      +DoubleToStr(pfractal[Term].Prior,Digits)
                       +"  Base: "     +DoubleToStr(pfractal[Term].Base,Digits)
                       +"  Root: "     +DoubleToStr(pfractal[Term].Root,Digits)
                       +"  Expansion: "+DoubleToStr(pfractal[Term].Expansion,Digits)
                       +"  Retrace: "  +DoubleToStr(pfractal[Term].Retrace,Digits)+"\n";
                       
    rsReport         += "Long Retrace: ("+DoubleToStr(pfractal.Fibonacci(Term,DirectionUp,InRetrace,InNow)*100,1)+"% "
                                         +DoubleToStr(pfractal.Fibonacci(Term,DirectionUp,InRetrace,InMax)*100,1)+"%)"
                       +"  Expansion: (" +DoubleToStr(pfractal.Fibonacci(Term,DirectionUp,InExpansion,InNow)*100,1)+"% "
                                         +DoubleToStr(pfractal.Fibonacci(Term,DirectionUp,InExpansion,InMax)*100,1)+"%)\n";

    rsReport         += "Short Retrace: ("+DoubleToStr(pfractal.Fibonacci(Term,DirectionDown,InRetrace,InNow)*100,1)+"% "
                                          +DoubleToStr(pfractal.Fibonacci(Term,DirectionDown,InRetrace,InMax)*100,1)+"%)"
                       +"  Expansion: ("  +DoubleToStr(pfractal.Fibonacci(Term,DirectionDown,InExpansion,InNow)*100,1)+"% "
                                          +DoubleToStr(pfractal.Fibonacci(Term,DirectionDown,InExpansion,InMax)*100,1)+"%)\n\n";

    rsReport         += "*---------- Trend Data --------------*\n";
    rsReport         += "Direction: "  +DirText(pfractal[Trend].Direction);

    if (ActiveEvent != NULL)
      rsReport       += "  Confirmed: "+BoolToStr(ActiveEvent.IsConfirmed());

    rsReport         += "\n";
    rsReport         += "Prior: "      +DoubleToStr(pfractal[Trend].Prior,Digits)
                       +"  Base: "     +DoubleToStr(pfractal[Trend].Base,Digits)
                       +"  Root: "     +DoubleToStr(pfractal[Trend].Root,Digits)
                       +"  Expansion: "+DoubleToStr(pfractal[Trend].Expansion,Digits)
                       +"  Retrace: "  +DoubleToStr(pfractal[Trend].Retrace,Digits)+"\n";
                       
    rsReport         += "Long Retrace: ("+DoubleToStr(pfractal.Fibonacci(Trend,DirectionUp,InRetrace,InNow)*100,1)+"% "
                                         +DoubleToStr(pfractal.Fibonacci(Trend,DirectionUp,InRetrace,InMax)*100,1)+"%)"
                       +"  Expansion: (" +DoubleToStr(pfractal.Fibonacci(Trend,DirectionUp,InExpansion,InNow)*100,1)+"% "
                                         +DoubleToStr(pfractal.Fibonacci(Trend,DirectionUp,InExpansion,InMax)*100,1)+"%)\n";
                                        
    rsReport         += "Short Retrace: ("+DoubleToStr(pfractal.Fibonacci(Trend,DirectionDown,InRetrace,InNow)*100,1)+"% "
                                          +DoubleToStr(pfractal.Fibonacci(Trend,DirectionDown,InRetrace,InMax)*100,1)+"%)"
                       +"  Expansion: ("  +DoubleToStr(pfractal.Fibonacci(Trend,DirectionDown,InExpansion,InNow)*100,1)+"% "
                                          +DoubleToStr(pfractal.Fibonacci(Trend,DirectionDown,InExpansion,InMax)*100,1)+"%)\n\n";

    if (ActiveEvent != NULL)
    {
      rsReport       += "*---------- Event Data --------------*\n";
      rsReport       += "Direction: "+DirText(ActiveEvent.Direction())
                       +"  Pegged: " +BoolToStr(ActiveEvent.IsPegged())+"\n";
                       
      rsReport       += "Root: "       +DoubleToStr(ActiveEvent.Event(Root),Digits)
                       +"  Expansion: "+DoubleToStr(ActiveEvent.Event(Expansion),Digits)
                       +"  Retrace: "  +DoubleToStr(ActiveEvent.Event(Retrace),Digits)+"\n";

      rsReport       += "Events: "     +IntegerToString(ActiveEvent.EventCount())
                       +"  Fibonacci: "+DoubleToStr(ActiveEvent.Event(Fibonacci)*100,1)+"%"
                       +"  Updated: "  +TimeToStr(ActiveEvent.EventUpdated())+"\n\n";
    }
    
    rsReport         += "*---------- MM Data --------------*\n";
    rsReport         += "Trade Direction: "+DirText(mmDirection)+"\n\n";

    UpdateLine("pfPrior",pfractal[Trend].Prior,STYLE_SOLID,clrYellow);
    UpdateLine("pfBase",pfractal[Trend].Base,STYLE_DOT,clrRed);  
    UpdateLine("pfRoot",pfractal[Trend].Root,STYLE_DOT,clrGoldenrod);
    UpdateLine("pfExpansion",pfractal[Trend].Expansion,STYLE_DOT,clrSteelBlue);
    UpdateLine("pfRetrace",pfractal[Trend].Retrace,STYLE_DOT,clrLightGray);

    Comment(rsReport);
  }

//+------------------------------------------------------------------+
//| SetFiboArrow - paints the pipMA zero arrow                       |
//+------------------------------------------------------------------+
void SetFiboArrow(int Direction)
  {
    static string    arrowName      = "";
    static int       arrowDir       = DirectionNone;
    static double    arrowPrice     = 0.00;
           uchar     arrowCode      = SYMBOL_DASH;
           
    if (IsChanged(arrowDir,Direction))
    {
      arrowName                     = NewArrow(arrowCode,DirColor(arrowDir,clrYellow),DirText(arrowDir),arrowPrice);
      arrowPrice                    = Close[0];
    }
      
    if (pfractal.Fibonacci(Term,Direction,InExpansion,InMax)>FiboLevel(Fibo823))
      arrowCode                     = SYMBOL_POINT4;
    else
    if (pfractal.Fibonacci(Term,Direction,InExpansion,InMax)>FiboLevel(Fibo423))
      arrowCode                     = SYMBOL_POINT3;
    else
    if (pfractal.Fibonacci(Term,Direction,InExpansion,InMax)>FiboLevel(Fibo261))
      arrowCode                     = SYMBOL_POINT2;
    else  
    if (pfractal.Fibonacci(Term,Direction,InExpansion,InMax)>FiboLevel(Fibo161))
      arrowCode                     = SYMBOL_POINT1;
    else
    if (pfractal.Fibonacci(Term,Direction,InExpansion,InMax)>FiboLevel(Fibo100))
      arrowCode                     = SYMBOL_CHECKSIGN;
    else
      arrowCode                     = SYMBOL_DASH;

    switch (Direction)
    {
      case DirectionUp:    if (IsChanged(arrowPrice,fmax(arrowPrice,Close[0])))
                             UpdateArrow(arrowName,arrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                           break;
      case DirectionDown:  if (IsChanged(arrowPrice,fmin(arrowPrice,Close[0])))
                           {
                             UpdateArrow(arrowName,arrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                           }
                           break;
    }
  }

//+------------------------------------------------------------------+
//| RefreshIndicators - Updates screen indicators after update()     |
//+------------------------------------------------------------------+
void RefreshIndicators(void)
  {
    static int mbResult    = IDOK;
  
    if (mbResult == IDOK)
      if (pfractal.Event(HistoryLoaded))
        mbResult = Pause("PipMA History is loaded","Event: HistoryLoaded",MB_OKCANCEL||MB_ICONINFORMATION||MB_DEFBUTTON2);

    SetFiboArrow(pfractal[Term].Direction);
    UpdateDirection("pfPipMATrend",dir(pfractal.Trend(Head)-trend.Trend(Head)),DirColor(dir(pfractal.Trend(Head)-trend.Trend(Head))));  
  }
    
//+------------------------------------------------------------------+
//| AddEvent - creates a new active event                            |
//+------------------------------------------------------------------+
void AddEvent(void)
  {
    PriorEvent  = ActiveEvent;
    ActiveEvent = new CPriceEvent(pfractal.Direction(Trend),pfractal[Term].Root,pfractal.Fibonacci(Term,pfractal.Direction(),InExpansion,InMax));
    
    ArrayResize(mmEvents,++mmEventCount);

    mmEvents[mmEventCount-1]  = ActiveEvent;
  }
  
//+------------------------------------------------------------------+
//| GetData - retrieves data and calculates prelim stats             |
//+------------------------------------------------------------------+
void GetData(void)
  {
    pfractal.Update();
    trend.Update();

    mmNewDirection                 = false;
        
    if (pfractal.Fibonacci(Term,pfractal.Direction(),InExpansion,InMax)>FiboLevel(Fibo100))
      if (IsChanged(mmDirection,pfractal.Direction()))
      {
        mmNewDirection             = true;
        mmAction                   = DirectionAction(mmDirection);
      }

    if (ActiveEvent == NULL)
    {
      if (pfractal.Fibonacci(Term,pfractal.Direction(),InExpansion,InMax)>FiboLevel(Fibo161))
        AddEvent();
    }
    else
    {
      if (ActiveEvent.Direction()!=pfractal.Direction(Trend))
        AddEvent();
      
      ActiveEvent.Update(pfractal.Direction(),pfractal[Term].Root,pfractal.Fibonacci(Term,pfractal.Direction(),InExpansion,InMax));
    }
  }

//+------------------------------------------------------------------+
//| OrderManager -  Manages order entry execution                    |
//+------------------------------------------------------------------+
void OrderManager(void)
  {
    double omTradeFibo            = FiboLevel(omFiboLevel);
    
    if (mmNewDirection)
    {
      omFiboLevel                 = Fibo50;
      omQuota                     = 0;
    }
      
    if (IsLower(pfractal.Fibonacci(Term,mmDirection,InExpansion,InNow),omTradeFibo))
    {
      omFiboLevel++;
      omQuota++;
    }  
  }

//+------------------------------------------------------------------+
//| RiskManager - Manages risk and drawdown; minimize loss           |
//+------------------------------------------------------------------+
void RiskManager(void)
  {
  }

//+------------------------------------------------------------------+
//| ProfitManager - Manages profitable trades; maximize profit       |
//+------------------------------------------------------------------+
void ProfitManager(void)
  {
  }

//+------------------------------------------------------------------+
//| ExecuteTick - Executes trades, manages risk, takes profit        |
//+------------------------------------------------------------------+
void ExecuteTick(void)
  {
    OrderManager();
    RiskManager();
    ProfitManager();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    RefreshIndicators();
    
    manualProcessRequest();
    OrderMonitor();
    
    if (pfractal.Event(HistoryLoaded))
      if (AutoTrade())
        ExecuteTick();
    
    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();
    
    NewLine ("pfPrior");
    NewLine ("pfBase");
    NewLine ("pfRoot");
    NewLine ("pfExpansion");
    NewLine ("pfRetrace");
    NewLabel("pfPipMATrend","",264,60,clrDarkGray,SCREEN_LL);
    
    return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete trend;
    
    for (int Event=0;Event<mmEventCount;Event++)
      delete mmEvents[Event];
  }
