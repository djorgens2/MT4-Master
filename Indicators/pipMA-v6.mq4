//+------------------------------------------------------------------+
//|                                                     pipMA-v6.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "6.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 3

#include <Class\PipFractal.mqh>
#include <std_utility.mqh>

//--- plot indPipValue
#property indicator_label1  "indPipHistory"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot indTLine
#property indicator_type2   DRAW_LINE
#property indicator_label2  "indTLine"
#property indicator_color2  clrGoldenrod
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- plot indPLine
#property indicator_label3  "indPLine"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCrimson
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Input params
input string         PipMAHeader          = "";                //+------ PipMA inputs ------+
input int            inpDegree            = 6;                 // Degree of poly regression
input int            inpPeriods           = 200;               // Number of poly regression periods
input double         inpTolerance         = 0.5;               // Trend change tolerance (sensitivity)
input double         inpAggFactor         = 1.0;               // Tick Aggregate factor (1=1 PIP);
input int            inpIdleTime          = 50;                // Market idle time in Pips
input bool           inpShowFibo          = true;              // Show fibonacci points
input bool           inpShowComment       = false;             // Display fibonacci data in Comment
input bool           inpShowBounds        = true;              // Display active trade range bounds
input PipFractalType inpShowFractal       = PipFractalTypes;   // Show fractal lines by type


  //--- Class defs
  CPipFractal *pfractal           = new CPipFractal(inpDegree,inpPeriods,inpTolerance,inpAggFactor,inpIdleTime);

  //--- Indicator Declarations
  string       ShortName          = "pipMA-v6: Degree:"+IntegerToString(inpDegree)+" Period:"+IntegerToString(inpPeriods);
  int          IndWinId  = -1;

  //--- Buffers
  double       indHistoryBuffer[];
  double       indTLineBuffer[];
  double       indPLineBuffer[];

  //--- Translation Arrays
  const string pmFiboPeriod[3]           = {"o","tr","tm"};
  const string pmFiboType[FractalPoints] = {"o","b","r","e","rt","rc"};

//+------------------------------------------------------------------+
//| UpdateEvent - Reports event changes retaining the last event     |
//+------------------------------------------------------------------+
void UpdateEvent(string EventText, int EventColor)
  {
    static string ueLastEvent    = "No Event";
    
    if (EventText=="No Event")
      UpdateLabel("lrEvent",ueLastEvent,clrGray,16);
    else
    if (IsChanged(ueLastEvent,EventText))
      UpdateLabel("lrEvent",EventText,EventColor,16);
    else
      UpdateLabel("lrEvent",ueLastEvent,clrYellow,16);
  }

//+------------------------------------------------------------------+
//| FOCText - returns the text string for the supplied FOC State     |
//+------------------------------------------------------------------+
string FOCText(RangeStateType State)
  {
    switch (State)
    {
      case SevereContraction: return("Severe Contraction");
      case ActiveContraction: return("Active Contraction");
      case Contracting:       return("Contracting");
      case IdleContraction:   return("Idle Contraction");
      case IdleFlat:          return("Market Idle");
      case IdleExpansion:     return("Idle Expansion");
      case Expanding:         return("Expanding");
      case ActiveExpansion:   return("Active Expansion");
      case SevereExpansion:   return("Severe Expansion");
      default:                return("No State");
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - updates screen data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    static int           lastDir    = DirectionNone;
  
    ObjectSet("piprMean",OBJPROP_TIME1,Time[0]);
    ObjectSet("piprMean",OBJPROP_PRICE1,pfractal.Range(Mean));

    if (pfractal.TrendWane())
      ObjectSet("piprMean", OBJPROP_COLOR, clrYellow);
    else
      ObjectSet("piprMean", OBJPROP_COLOR, DirColor(pfractal.FOCDirection()));

    UpdatePriceLabel("piprHead",pfractal.Trendline(Head),DirColor(pfractal.Direction(Trendline)));
    UpdatePriceLabel("piprTail",pfractal.Trendline(Tail),DirColor(pfractal.Direction(Trendline)));

    UpdateLine("piprFOCPivot",pfractal.Pivot(Price),STYLE_SOLID,DirColor(pfractal.Direction(Pivot)));
    UpdateLine("piprIntPos",pfractal.Intercept(Top),STYLE_DOT,clrForestGreen);
    UpdateLine("piprIntNeg",pfractal.Intercept(Bottom),STYLE_DOT,clrMaroon);

    SetLevelValue(1,pfractal.Range(Mid));
    
    if (pfractal.FOCDirection()!=lastDir)
      SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,1,DirColor(pfractal.FOCDirection(),clrYellow,clrRed));

    if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)) || IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
      SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,1,DirColor(pfractal.Direction(Polyline)));
    else
      SetIndexStyle(2,DRAW_LINE,STYLE_DOT,1,DirColor(pfractal.Direction(Polyline)));
    
    UpdateLabel("lrFOCNow",NegLPad(pfractal.FOC(Now),1),DirColor(pfractal.FOCDirection()),15);
    UpdateLabel("lrFOCPivDev",center(DoubleToStr(pip(pfractal.Pivot(Deviation)/inpAggFactor),1),7),DirColor(pfractal.Direction(Pivot)),15);
    UpdateDirection("lrFOCPivDir",pfractal.Direction(Pivot),DirColor(pfractal.Direction(Pivot)),20);
    UpdateLabel("lrFOCRange",DoubleToStr(pip(pfractal.Range(Size))/inpAggFactor,1),DirColor(pfractal.FOCDirection()),15);
    UpdateDirection("lrRangeDir",pfractal.Direction(Range),DirColor(pfractal.Direction(Range)),30);

    UpdateLabel("lrFOCDev",DoubleToStr(pfractal.FOC(Deviation),1),DirColor(pfractal.FOCDirection()));
    UpdateLabel("lrFOCMax",NegLPad(pfractal.FOC(Max),1),DirColor(pfractal.FOCDirection()));
    UpdateLabel("lrFOCPivDevMin",center(DoubleToStr(pip(pfractal.Pivot(Min)/inpAggFactor),1),7),DirColor(pfractal.Direction(Pivot)));
    UpdateLabel("lrFOCPivDevMax",center(DoubleToStr(pip(pfractal.Pivot(Max)/inpAggFactor),1),7),DirColor(pfractal.Direction(Pivot)));
    UpdateLabel("lrFOCPivPrice",DoubleToStr(pfractal.Pivot(Price),Digits),DirColor(pfractal.Direction(Pivot)));
    UpdateLabel("lrFOCTick",LPad(IntegerToString(pfractal.Age(Tick))," ",2),DirColor(pfractal.Direction(Tick)));
    UpdateLabel("lrFOCAge",LPad(IntegerToString(pfractal.Age(Range))," ",2),DirColor(pfractal.Direction(Range)));
    UpdateLabel("lrMALow",LPad(IntegerToString(pfractal.Age(RangeLow))," ",2),DirColor(DirectionDown));
    UpdateLabel("lrMAHigh",LPad(IntegerToString(pfractal.Age(RangeHigh))," ",2),DirColor(DirectionUp));

    UpdateDirection("lrPolyDir",pfractal.Direction(Polyline),DirColor(pfractal.Direction(Polyline)),16);
    UpdateLabel("lrPricePolyDev",NegLPad(pfractal.Poly(Deviation),1),Color(pfractal.Poly(Deviation)));
    UpdateLabel("lrPolyTrendDev",NegLPad(pfractal.Trendline(Deviation),1),Color(pfractal.Trendline(Deviation)));
    
    UpdateLabel("lrFOCState",center(FOCText(pfractal.TrendState()),22),DirColor(pfractal.FOCDirection()));
    UpdateLabel("lrStdDevData","Std Dev: "+DoubleToStr(pip(pfractal.StdDev(Now)),1)
               +" x:"+DoubleToStr(fmax(pip(pfractal.StdDev(Positive)),fabs(pip(pfractal.StdDev(Negative)))),1)
               +" p:"+DoubleToStr(pip(pfractal.StdDev()),1)
               +" +"+DoubleToStr(pip(pfractal.StdDev(Positive)),1)
               +" "+DoubleToStr(pip(pfractal.StdDev(Negative)),1),DirColor(pfractal.Direction(StdDev)),10);
               
    //---Fibonacci data
    UpdateLabel("lrFibo tm(e)",DoubleToStr(pfractal.Fibonacci(Term,Expansion,Now,InPercent),1),DirColor(pfractal.Direction(pftTerm)),16);
    UpdateLabel("lrFibo tm(e)x",DoubleToStr(pfractal.Fibonacci(Term,Expansion,Max,InPercent),1),DirColor(pfractal.Direction(pftTerm)),8);
    UpdateLabel("lrFibo tm(e)n",DoubleToStr(pfractal.Fibonacci(Term,Expansion,Min,InPercent),1),DirColor(pfractal.Direction(pftTerm)),8);
    UpdateLabel("lrFibo tr(e)",DoubleToStr(pfractal.Fibonacci(Trend,Expansion,Now,InPercent),1),DirColor(pfractal.Direction(pftTrend)),16);
    UpdateLabel("lrFibo tr(e)x",DoubleToStr(pfractal.Fibonacci(Trend,Expansion,Max,InPercent),1),DirColor(pfractal.Direction(pftTrend)),8);
    UpdateLabel("lrFibo tr(e)n",DoubleToStr(pfractal.Fibonacci(Trend,Expansion,Min,InPercent),1),DirColor(pfractal.Direction(pftTrend)),8);
    UpdateLabel("lrFibo o(e)",DoubleToStr(pfractal.Fibonacci(Origin,Expansion,Now,InPercent),1),DirColor(pfractal.Direction(pftOrigin)),16);
    UpdateLabel("lrFibo o(e)x",DoubleToStr(pfractal.Fibonacci(Origin,Expansion,Max,InPercent),1),DirColor(pfractal.Direction(pftOrigin)),8);
    UpdateLabel("lrFibo o(e)n",DoubleToStr(pfractal.Fibonacci(Origin,Expansion,Min,InPercent),1),DirColor(pfractal.Direction(pftOrigin)),8);
               
    UpdateLabel("lrFibo tm(rt)",DoubleToStr(pfractal.Fibonacci(Term,Retrace,Now,InPercent),1),DirColor(pfractal.Direction(pftTerm)),16);
    UpdateLabel("lrFibo tm(rt)x",DoubleToStr(pfractal.Fibonacci(Term,Retrace,Max,InPercent),1),DirColor(pfractal.Direction(pftTerm)),8);
    UpdateLabel("lrFibo tm(rt)n",DoubleToStr(pfractal.Fibonacci(Term,Retrace,Min,InPercent),1),DirColor(pfractal.Direction(pftTerm)),8);
    UpdateLabel("lrFibo tr(rt)",DoubleToStr(pfractal.Fibonacci(Trend,Retrace,Now,InPercent),1),DirColor(pfractal.Direction(pftTrend)),16);
    UpdateLabel("lrFibo tr(rt)x",DoubleToStr(pfractal.Fibonacci(Trend,Retrace,Max,InPercent),1),DirColor(pfractal.Direction(pftTrend)),8);
    UpdateLabel("lrFibo tr(rt)n",DoubleToStr(pfractal.Fibonacci(Trend,Retrace,Min,InPercent),1),DirColor(pfractal.Direction(pftTrend)),8);
    UpdateLabel("lrFibo o(rt)",DoubleToStr(pfractal.Fibonacci(Origin,Retrace,Now,InPercent),1),DirColor(pfractal.Direction(pftOrigin)),16);
    UpdateLabel("lrFibo o(rt)x",DoubleToStr(pfractal.Fibonacci(Origin,Retrace,Max,InPercent),1),DirColor(pfractal.Direction(pftOrigin)),8);
    UpdateLabel("lrFibo o(rt)n",DoubleToStr(pfractal.Fibonacci(Origin,Retrace,Min,InPercent),1),DirColor(pfractal.Direction(pftOrigin)),8);

    for (FractalPoint point=fpBase;point<FractalPoints;point++)
      for (FractalType type=Origin;type<(int)PipFractalTypes;type++)
      {
        UpdateLabel("lrFibo "+EnumToString(type)+":"+StringSubstr(EnumToString(point),2)+":p",lpad(DoubleToStr(pfractal.Price(type,point),Digits)," ",Digits+2),clrDarkGray);
        UpdateLabel("lrFibo "+EnumToString(type)+":"+StringSubstr(EnumToString(point),2)+":a",center((string)pfractal[type].Age[point],5),clrDarkGray);
      }
      
    color pfColor[FractalPoints] = {clrNONE,clrSteelBlue,clrGoldenrod,clrFireBrick,clrDarkGray,clrDarkGray};

    if (inpShowFractal<PipFractalTypes)
      for (FractalPoint point=fpBase;point<FractalPoints;point++)
        UpdateLine("pln["+pmFiboPeriod[inpShowFractal]+":"+pmFiboType[point]+"]",pfractal.Price((FractalType)inpShowFractal,point),BoolToInt(point==5,STYLE_DOT,STYLE_SOLID),pfColor[point]);
        
    if (pfractal.Event(NewIdle))
      UpdateEvent("Market is Idle",DirColor(pfractal.Direction(Aggregate)));
    else
    if (pfractal.Event(NewDirection))
      UpdateEvent("New Direction",DirColor(pfractal.Direction(pftTerm)));
    else
    if (pfractal.Event(NewOrigin))
      UpdateEvent("New Origin",DirColor(pfractal.Direction(pftOrigin)));
    else
    if (pfractal.Event(NewTrend))
      UpdateEvent("New Trend",DirColor(pfractal.Direction(pftTrend)));
    else
    if (pfractal.Event(NewTerm))
      UpdateEvent("New Term",DirColor(pfractal.Direction(pftTerm)));
    else
    if (pfractal.Event(NewWane))
      UpdateEvent("Trend Wane",DirColor(pfractal.Direction(pftTerm)));
    else
    if (pfractal.Event(NewRecovery))
      UpdateEvent("Trend Resume",DirColor(pfractal.Direction(pftTerm)));
    else
    if (pfractal.Event(NewBoundary))
    {
      if (pfractal.Event(NewHigh))
        UpdateEvent("New High",clrLawnGreen);

      if (pfractal.Event(NewLow))
        UpdateEvent("New Low",clrRed);        
    }
    else
      UpdateEvent("No Event",clrGray);
      
    UpdateLabel("lrFiboState",pfractal.StateText(),Color(pfractal.Direction(pftTerm)));

    if (inpShowBounds)
    {
      if (pfractal.Event(NewLow))
        UpdateLine("piprRngLow",pfractal.Range(Bottom),STYLE_DOT,clrGoldenrod);
      else
        UpdateLine("piprRngLow",pfractal.Range(Bottom),STYLE_DOT,DirColor(pfractal.Direction(RangeLow)));

      UpdateLine("piprRngMid",pfractal.Range(Mid),STYLE_DOT,clrGray);

      if (pfractal.Event(NewHigh))
        UpdateLine("piprRngHigh",pfractal.Range(Top),STYLE_DOT,clrGoldenrod);
      else
        UpdateLine("piprRngHigh",pfractal.Range(Top),STYLE_DOT,DirColor(pfractal.Direction(RangeHigh)));
    }

    if (inpShowComment)
      pfractal.RefreshScreen();
    
    lastDir = pfractal.FOCDirection();
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {    
    pfractal.UpdateBuffer(indHistoryBuffer,indPLineBuffer,indTLineBuffer);

    if (Bars>inpPeriods)
      indHistoryBuffer[inpPeriods]=0.00;

    RefreshScreen();                 

    return(rates_total);
  }

//+------------------------------------------------------------------+
//| InitScreenObjects - sets up screen labels and trend lines        |
//+------------------------------------------------------------------+
void InitScreenObjects()
  {
    //--- FOC Labels
    NewLabel("lrFOC0","Trend Factor",10,12,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFOC1","-------- Pivot --------",98,12,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFOC2","------- Range Age/State ---------      ----- Poly -----",206,12,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFOC3","Current",20,22,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC4","Dev",113,22,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC5","Range",217,22,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC6","Dev",12,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC7","Max",51,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC8","Min",92,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC9","Max",127,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC10","Price",169,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC11","Tick",208,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC12","Age",234,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC13","Low",270,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC14","High",340,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC15","Price",374,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC16","Trend",410,65,clrWhite,SCREEN_UL,IndWinId);

    //--- FOC Values
    NewLabel("lrFOCNow","",18,32,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivDev","",92,32,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivDir","",170,29,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrFOCRange","",212,32,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrFOCState","",266,22,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrRangeDir","",296,32,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrPolyDir","",394,36,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrPolyState","",385,22,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrPricePolyDev","",375,53,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrPolyTrendDev","",412,53,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOCDev","",12,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCMax","",47,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivDevMin","",85,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivDevMax","",122,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivPrice","",160,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCTick","",212,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCAge","",235,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrMALow","",270,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrMAHigh","",340,53,clrNONE,SCREEN_UL,IndWinId);

    
    NewLabel("lrWave01","State:",12,93,clrWhite,SCREEN_UL,IndWinId);    

    //--- Right-side labels and data
    NewLabel("lrEvent","",5,5,clrWhite,SCREEN_LR,IndWinId);
    NewLabel("lrStdDevData","",5,5,clrLightGray,SCREEN_UR,IndWinId);
    
    //--- Wave labels
    NewLabel("lrWave01","--------------- Wave Data --------------",12,82,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrWave02","State:",12,93,clrWhite,SCREEN_UL,IndWinId);    
    NewLabel("lrWaveState","",48,93,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrWave03","Long:",12,104,clrWhite,SCREEN_UL,IndWinId); 
    NewLabel("lrWave04","Short:",12,115,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrWaveStateL","Long",48,104,clrWhite,SCREEN_UL,IndWinId); 
    NewLabel("lrWaveStateS","Short",48,115,clrWhite,SCREEN_UL,IndWinId);

    //--- Fibo labels
    NewLabel("lrFibo00","--------------- Fibonacci Data -------------------",226,82,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFibo01","State:",226,93,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo02","Term",242,109,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFibo03","Trend",322,109,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFibo04","Origin",402,109,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFibo05","Max",226,155,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo06","Min",266,155,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo07","Max",306,155,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo08","Min",346,155,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo09","Max",386,155,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo10","Min",426,155,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo12","Max",226,205,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo13","Min",266,205,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo14","Max",306,205,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo15","Min",346,205,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo16","Max",386,205,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFibo17","Min",426,205,clrWhite,SCREEN_UL,IndWinId);
    
    NewLabel("lrFibo11","Expansion",202,165,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFibo18","Retrace",202,215,clrGoldenrod,SCREEN_UL,IndWinId);
    
    ObjectSet("lrFibo11",OBJPROP_ANGLE,90);
    ObjectSet("lrFibo18",OBJPROP_ANGLE,90);

    NewLabel("lrFiboState","",260,93,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tm(e)","",234,120,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tm(e)x","",224,142,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tm(e)n","",264,142,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tr(e)","",314,120,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tr(e)x","",304,142,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tr(e)n","",344,142,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo o(e)","",394,120,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo o(e)x","",384,142,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo o(e)n","",424,142,clrNONE,SCREEN_UL,IndWinId);

    NewLabel("lrFibo tm(rt)","",234,170,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tm(rt)x","",224,192,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tm(rt)n","",264,192,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tr(rt)","",314,170,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tr(rt)x","",304,192,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo tr(rt)n","",334,192,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo o(rt)","",394,170,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo o(rt)x","",384,192,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFibo o(rt)n","",424,192,clrNONE,SCREEN_UL,IndWinId);

    for (FractalPoint point=fpBase;point<FractalPoints;point++)
    {
      NewLabel("lrFibo "+StringSubstr(EnumToString(point),2),StringSubstr(EnumToString(point),2),160,218+(point*12),clrGoldenrod,SCREEN_UL,IndWinId);

      for (FractalType type=Origin;type<(int)PipFractalTypes;type++)
      {          
        NewLabel("lrFibo "+EnumToString(type)+":"+StringSubstr(EnumToString(point),2)+":p","0.00000",385-(type*80),218+(point*12),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lrFibo "+EnumToString(type)+":"+StringSubstr(EnumToString(point),2)+":a","9999",433-(type*80),218+(point*12),clrDarkGray,SCREEN_UL,IndWinId);
      }
    }

    //--- Price bubbles
    ObjectCreate("piprMean",OBJ_ARROW,IndWinId,0,0);
    ObjectSet("piprMean", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);

    ObjectCreate("piprHead",OBJ_ARROW,IndWinId,0,0);
    ObjectSet("piprHead", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);

    ObjectCreate("piprTail",OBJ_ARROW,IndWinId,0,0);
    ObjectSet("piprTail", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);

    NewLine("piprFOCPivot",0.00,STYLE_DASHDOT,clrLightGray,IndWinId);
    NewLine("piprIntPos",0.00,STYLE_DASHDOT,clrLightGray,IndWinId);
    NewLine("piprIntNeg",0.00,STYLE_DASHDOT,clrLightGray,IndWinId);

    NewLine("piprRngLow");
    NewLine("piprRngMid");
    NewLine("piprRngHigh");

    if (inpShowFractal<PipFractalTypes)
      for (FractalPoint point=fpBase;point<FractalPoints;point++)
        NewLine("pln["+pmFiboPeriod[inpShowFractal]+":"+pmFiboType[point]+"]");
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    SetIndexBuffer(0,indHistoryBuffer);
    SetIndexBuffer(1,indTLineBuffer);
    SetIndexBuffer(2,indPLineBuffer);
 
    SetIndexEmptyValue(0, 0.00);
    SetIndexEmptyValue(1, 0.00);
    SetIndexEmptyValue(2, 0.00);
   
    ArrayInitialize(indHistoryBuffer,0.00);
    ArrayInitialize(indTLineBuffer,  0.00);
    ArrayInitialize(indPLineBuffer,  0.00);
    
    IndicatorShortName(ShortName);
    IndWinId = ChartWindowFind(0,ShortName);

    InitScreenObjects();

    return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pfractal;

    ObjectDelete("piprRngLow");
    ObjectDelete("piprRngMid");
    ObjectDelete("piprRngHigh");
   
    if (inpShowFractal<PipFractalTypes)
      for (FractalPoint point=fpBase;point<FractalPoints;point++)
        ObjectDelete("pln["+pmFiboPeriod[inpShowFractal]+":"+pmFiboType[point]+"]");
  }
