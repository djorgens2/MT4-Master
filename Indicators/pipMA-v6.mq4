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
#property indicator_label2  "indTLine"
#property indicator_type2   DRAW_LINE
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
input string PipMAHeader        = "";    //+------ PipMA inputs ------+
input int    inpDegree          = 6;     // Degree of poly regression
input int    inpPeriods         = 200;   // Number of poly regression periods
input double inpTolerance       = 0.5;   // Trend change tolerance (sensitivity)
input bool   inpShowFibo        = true;  // Display lines and fibonacci points
input bool   inpShowComment     = false; // Display fibonacci data in Comment

input string fractalHeader      = "";    //+------ Fractal inputs ------+
input int    inpRangeMax        = 120;    // Maximum fractal pip range
input int    inpRangeMin        = 60;    // Minimum fractal pip range

//--- Class defs
  CFractal         *fractal     = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal    = new CPipFractal(inpDegree,inpPeriods,inpTolerance,fractal);

string    ShortName             = "pipMA-v6: Degree:"+IntegerToString(inpDegree)+" Period:"+IntegerToString(inpPeriods);
int       IndWinId  = -1;

double    indHistoryBuffer[];
double    indTLineBuffer[];
double    indPLineBuffer[];

//+------------------------------------------------------------------+
//| RefreshScreen - updates screen data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    static int lastDir    = DirectionNone;
  
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

    SetIndexStyle(2,DRAW_LINE,STYLE_DOT,1,DirColor(pfractal.Direction(Polyline)));
    
    UpdateLabel("lrFOCNow",NegLPad(pfractal.FOC(Now),1),DirColor(pfractal.FOCDirection()),15);
    UpdateLabel("lrFOCPivDev",NegLPad(Pip(pfractal.Pivot(Deviation)),1),DirColor(pfractal.Direction(Pivot)),15);
    UpdateDirection("lrFOCPivDir",pfractal.Direction(Pivot),DirColor(pfractal.Direction(Pivot)),20);
    UpdateLabel("lrFOCRange",DoubleToStr(Pip(pfractal.Range(Size)),1),DirColor(pfractal.FOCDirection()),15);

    UpdateLabel("lrFOCDev",DoubleToStr(pfractal.FOC(Deviation),1),DirColor(pfractal.FOCDirection()));
    UpdateLabel("lrFOCMax",NegLPad(pfractal.FOC(Max),1),DirColor(pfractal.FOCDirection()));
    UpdateLabel("lrFOCPivDevMin",NegLPad(Pip(pfractal.Pivot(Min)),1),DirColor(pfractal.Direction(Pivot)));
    UpdateLabel("lrFOCPivDevMax",NegLPad(Pip(pfractal.Pivot(Max)),1),DirColor(pfractal.Direction(Pivot)));
    UpdateLabel("lrFOCPivPrice",DoubleToStr(pfractal.Pivot(Price),Digits),DirColor(pfractal.Direction(Pivot)));
    UpdateLabel("lrFOCTick",LPad(IntegerToString(pfractal.Count(Tick))," ",2),DirColor(pfractal.Direction(Tick)));
    UpdateLabel("lrFOCAge",LPad(IntegerToString(pfractal.Count(BoolToInt(pfractal.Direction(Range)==DirectionUp,RangeHigh,RangeLow)))," ",2),DirColor(pfractal.Direction(Range)));
    UpdateLabel("lrPricePolyDev",NegLPad(pfractal.Poly(Deviation),1),DirColor(pfractal.Direction(Polyline)));
    UpdateLabel("lrPolyTrendDev",NegLPad(pfractal.Trendline(Deviation),1),DirColor(pfractal.Direction(Polyline)));
    
    UpdateLabel("lrFOCAmpDirection",pfractal.Text(InDirection),DirColor(pfractal.FOCDirection()));
    UpdateLabel("lrFOCState",pfractal.Text(InState),DirColor(pfractal.FOCDirection()));
    
    UpdateLabel("lrAmpData","Amp: "+DoubleToStr(pfractal.FOCAmp(Now),1)
               +" x:"+DoubleToStr(pfractal.FOCAmp(Max),1)
               +" p:"+DoubleToStr(pfractal.FOCAmp(Peak),1),DirColor(pfractal.Direction(FOCAmplitude)),10);
               
    UpdateDirection("lrStdDevDir",pfractal.Direction(StdDev),DirColor(pfractal.Direction(StdDev)),10);

    UpdateLabel("lrStdDevData","Std Dev: "+DoubleToStr(Pip(pfractal.StdDev(Now)),1)
               +" x:"+DoubleToStr(fmax(Pip(pfractal.StdDev(Positive)),fabs(Pip(pfractal.StdDev(Negative)))),1)
               +" p:"+DoubleToStr(Pip(pfractal.StdDev()),1)
               +" +"+DoubleToStr(Pip(pfractal.StdDev(Positive)),1)
               +" "+DoubleToStr(Pip(pfractal.StdDev(Negative)),1),DirColor(pfractal.Direction(StdDev)),10);
               
    if (pfractal.Event(NewAggregate))
      UpdateLabel("lrEvent","New Aggregate",DirColor(pfractal.Direction(Aggregate)),16);
    else
    if (pfractal.Event(NewDirection))
      UpdateLabel("lrEvent","New Direction",DirColor(pfractal.Direction(Term)),16);
    else
    if (pfractal.Event(NewMajor))
      UpdateLabel("lrEvent","New Major",DirColor(pfractal.Direction(Term)),16);
    else
    if (pfractal.Event(NewMinor))
      UpdateLabel("lrEvent","New Minor",DirColor(pfractal.Direction(Term)),16);
    else
    if (pfractal.Event(TrendWane))
      UpdateLabel("lrEvent","Trend Wane",DirColor(pfractal.Direction(Term)),16);
    else
    if (pfractal.Event(TrendResume))
      UpdateLabel("lrEvent","Trend Resume",DirColor(pfractal.Direction(Term)),16);
    else
    if (pfractal.Event(NewBoundary))
    {
      if (pfractal.Event(NewHigh))
        UpdateLabel("lrEvent","New High",clrLawnGreen,16);

      if (pfractal.Event(NewLow))
        UpdateLabel("lrEvent","New Low",clrRed,16);        
    }
    else
      UpdateLabel("lrEvent","No Event",clrGray,16);

    if (inpShowFibo)
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

    pfractal.ShowFiboArrow();
    
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
    NewLabel("lrFOC0","Factor of Change",10,12,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lrFOC1","Pivot",140,12,clrGoldenrod,SCREEN_UL,IndWinId);

    NewLabel("lrFOC2","Current",20,22,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC3","Dev",113,22,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC4","Range",215,22,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOCNow","",18,32,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivDev","",92,32,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivDir","",170,29,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("lrFOCRange","",212,32,clrLightGray,SCREEN_UL,IndWinId);

    NewLabel("lrFOCDev","",12,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCMax","",47,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivDevMin","",85,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivDevMax","",122,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCPivPrice","",160,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCTick","",212,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCAge","",235,53,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrPricePolyDevTxt","Price-Poly Deviation:",32,5,clrWhite,SCREEN_UR,IndWinId);
    NewLabel("lrPolyTrendDevTxt","Poly-Trend Deviation:",32,16,clrWhite,SCREEN_UR,IndWinId);
    NewLabel("lrPricePolyDev","Price-Poly Deviation",5,5,clrWhite,SCREEN_UR,IndWinId);
    NewLabel("lrPolyTrendDev","Poly-Trend Deviation",5,16,clrWhite,SCREEN_UR,IndWinId);
    NewLabel("lrEvent","",5,5,clrWhite,SCREEN_LR,IndWinId);

    NewLabel("lrFOC5","Dev",12,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC6","Max",51,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC7","Min",92,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC8","Max",127,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC9","Price",169,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC10","Tick",208,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lrFOC11","Age",234,65,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lrFOCAmpDirection","",15,78,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lrFOCState","",85,78,clrNONE,SCREEN_UL,IndWinId);

    //--- Amplitude/Standard Deviation labels
    NewLabel("lrAmpData","",5,18,clrLightGray,SCREEN_LL,IndWinId);
    NewLabel("lrStdDevData","",15,5,clrLightGray,SCREEN_LL,IndWinId);
    NewLabel("lrStdDevDir","",5,5,clrLightGray,SCREEN_LL,IndWinId);

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
    delete fractal;
    
    ObjectDelete("piprRngLow");
    ObjectDelete("piprRngMid");
    ObjectDelete("piprRngHigh");
  }
