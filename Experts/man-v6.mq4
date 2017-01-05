//+------------------------------------------------------------------+
//|                                                       man-v6.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipFractal.mqh>
#include <Class\TrendRegression.mqh>
#include <manual.mqh>

input string appHeader               = "";    //+------ App Options -------+
input bool   inpShowFiboLines        = false; // Display Fibonacci Lines

input string fractalHeader           = "";    //+------ Fractal Options ------+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

input string PipMAHeader             = "";    //+------ PipMA Options ------+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpPeriods              = 200;   // Number of poly regression periods
input double inpTolerance            = 0.5;   // Directional change sensitivity

input string TRegressionHeader       = "";    //+------ T-Regression Options ------+
input int    inpTRDegree             = 6;     // Degree of trend regression
input int    inpTRPeriods            = 72;    // Number of trend regression periods
input int    inpTRSmoothFactor       = 3;     // Trend MA Smoothing Factor
input int    inpTRStdDevPad          = 5;     // Standard Deviation Pad (in pips)


//--- Class defs
  CTrendRegression *trend            = new CTrendRegression(inpTRDegree,inpTRPeriods,inpTRSmoothFactor);
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPeriods,inpTolerance,fractal);
  
//--- Operational variables
  int              display           = NoValue;

//--- Trend Analysis
  double           sdcMaxHeadPrice   = 0.00;            //--- Max TL head price
  double           sdcMaxTailPrice   = 0.00;            //--- Max TL tail price
  double           stdDevMax         = 0.00;            //--- Max standard deviation   

//+------------------------------------------------------------------+
//| ShowFiboArrow - paints the pipMA fibo arrow                      |
//+------------------------------------------------------------------+
void ShowFiboArrow(void)
  {
    static string    arrowName      = "";
    static int       arrowDir       = DirectionNone;
    static double    arrowPrice     = 0.00;
           uchar     arrowCode      = SYMBOL_DASH;

    if (IsChanged(arrowDir,pfractal.Direction(Term)))
    {
      arrowPrice                    = Close[0];
      arrowName                     = NewArrow(arrowCode,DirColor(arrowDir,clrYellow),DirText(arrowDir),arrowPrice);
    }
     
    if (pfractal.Fibonacci(Term,arrowDir,Expansion,Max)>FiboPercent(Fibo823))
      arrowCode                     = SYMBOL_POINT4;
    else
    if (pfractal.Fibonacci(Term,arrowDir,Expansion,Max)>FiboPercent(Fibo423))
      arrowCode                     = SYMBOL_POINT3;
    else
    if (pfractal.Fibonacci(Term,arrowDir,Expansion,Max)>FiboPercent(Fibo261))
      arrowCode                     = SYMBOL_POINT2;
    else  
    if (pfractal.Fibonacci(Term,arrowDir,Expansion,Max)>FiboPercent(Fibo161))
      arrowCode                     = SYMBOL_POINT1;
    else
    if (pfractal.Fibonacci(Term,arrowDir,Expansion,Max)>FiboPercent(Fibo100))
      arrowCode                     = SYMBOL_CHECKSIGN;
    else
      arrowCode                     = SYMBOL_DASH;

    switch (arrowDir)
    {
      case DirectionUp:    if (IsChanged(arrowPrice,fmax(arrowPrice,Close[0])))
                             UpdateArrow(arrowName,arrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                           break;
      case DirectionDown:  if (IsChanged(arrowPrice,fmin(arrowPrice,Close[0])))
                             UpdateArrow(arrowName,arrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                           break;
    }
  }

//+------------------------------------------------------------------+
//| ShowAppData - Hijacks the comment for application metrics        |
//+------------------------------------------------------------------+
void ShowAppData(void)
  {
    string        rsComment   = "";

    rsComment     = "No Comment";
    
    Comment(rsComment);  
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    switch (display)
    {
      case 0:  fractal.RefreshScreen();
               break;
      case 1:  pfractal.RefreshScreen();
               break;
      case 2:  ShowAppData();
               break;
      default: Comment("No Data");
    }

    //--- Standard Deviation channel lines
    UpdateRay("sdcTop",sdcMaxTailPrice+stdDevMax,inpTRPeriods-1,sdcMaxHeadPrice+stdDevMax,0,STYLE_DOT,clrYellow);
    UpdateRay("sdcBottom",sdcMaxTailPrice-stdDevMax,inpTRPeriods-1,sdcMaxHeadPrice-stdDevMax,0,STYLE_DOT,clrRed);
    UpdateRay("sdcTrend",sdcMaxTailPrice,inpTRPeriods-1,sdcMaxHeadPrice,0,STYLE_DOT,clrLightGray);

    ShowFiboArrow();
  }
    
//+------------------------------------------------------------------+
//| CalcStdDev - Computes the std dev channel                        |
//+------------------------------------------------------------------+
void CalcStdDev(void)
  {
    static double csdMaxDev    = 0.00;
    static int    csdDirection = DirectionNone;
    
//    for (int idx=inpTRPeriods-1;idx>0;idx--)
//      Print(DoubleToStr(High[idx],Digits)+";"+DoubleToString(Low[idx],Digits)+";"+DoubleToStr(trend[idx],Digits));

    if (IsChanged(csdDirection,trend.Direction(Trendline)))
    {
      sdcMaxHeadPrice          = trend.Trendline(Head);
      sdcMaxTailPrice          = trend.Trendline(Tail);
    }
        
    if (IsBetween(Close[0],trend.Trendline(Tail),trend.Trendline(Head),Digits))
    {
      if (csdDirection == DirectionUp)
        if (IsHigher(trend.Trendline(Head),sdcMaxHeadPrice))
          sdcMaxTailPrice        = trend.Trendline(Tail);
        
      if (csdDirection == DirectionDown)
        if (IsLower(trend.Trendline(Head),sdcMaxHeadPrice))
          sdcMaxTailPrice        = trend.Trendline(Tail);

      if (IsHigher(trend.StdDev(Actual)+Pip(inpTRStdDevPad,InPoints),csdMaxDev))
        stdDevMax                = csdMaxDev;
    }
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    trend.Update();
    fractal.Update();
    pfractal.Update();
    
    CalcStdDev();
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {    
    if (Command[0]=="SHOW")
      if (InStr(Command[1],"NONE"))
        display  = NoValue;
      else
      if (InStr(Command[1],"FIB"))
        display  = 0;
      else
      if (InStr(Command[1],"PIP"))
        display  = 1;
      else
      if (InStr(Command[1],"APP"))
        display  = 2;
      else
        display  = NoValue;
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
    
    NewRay("sdcTop",false);
    NewRay("sdcBottom",false);
    NewRay("sdcTrend",false);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete trend;
    delete fractal;
    delete pfractal;
  }