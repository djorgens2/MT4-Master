//+------------------------------------------------------------------+
//|                                                     pipMA-v5.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "5.01"
#property strict
#property indicator_separate_window
#property indicator_buffers 3


#include <Class\PipRegression.mqh>
#include <std_utility.mqh>

//--- Input params
input int    inpDegree      = 6;     // Degree of poly regression
input int    inpPeriods     = 200;   // Number of poly regression periods
input double inpTolerance   = 0.5;   // Trend change tolerance (sensitivity)
input bool   inpShowData    = false; // Display chart window data/lines

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

string   ShortName          = "pipMA-v5: Degree:"+IntegerToString(inpDegree)+" Period:"+IntegerToString(inpPeriods);
int      IndWinId  = -1;

CPipRegression *pregr = new CPipRegression(inpDegree,inpPeriods,inpTolerance);

double    indHistoryBuffer[];
double    indTLineBuffer[];
double    indPLineBuffer[];

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
    pregr.UpdateBuffer(indHistoryBuffer,indPLineBuffer,indTLineBuffer);
    
    if (Bars>inpPeriods)
      indHistoryBuffer[inpPeriods]=0.00;

    RefreshScreen();                 

    return(rates_total);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - updates screen data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    static int lastDir    = DirectionNone;
  
    ObjectSet("piprMean",OBJPROP_TIME1,Time[0]);
    ObjectSet("piprMean",OBJPROP_PRICE1,pregr.Range(Mean));

    if (pregr.TrendWane())
      ObjectSet("piprMean", OBJPROP_COLOR, clrYellow);
    else
      ObjectSet("piprMean", OBJPROP_COLOR, DirColor(pregr.FOCDirection()));

    UpdatePriceLabel("piprHead",pregr.Trendline(Head),DirColor(pregr.Direction(Trendline)));
    UpdatePriceLabel("piprTail",pregr.Trendline(Tail),DirColor(pregr.Direction(Trendline)));

    UpdateLine("piprFOCPivot",pregr.Pivot(Price),STYLE_DASHDOTDOT,DirColor(pregr.Direction(Pivot)));
    UpdateLine("piprIntPos",pregr.Intercept(Top),STYLE_DASHDOTDOT,clrForestGreen);
    UpdateLine("piprIntNeg",pregr.Intercept(Bottom),STYLE_DASHDOTDOT,clrMaroon);

    SetLevelValue(1,pregr.Range(Mid));
    
    if (pregr.FOCDirection()!=lastDir)
      SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,1,DirColor(pregr.FOCDirection(),clrYellow,clrRed));

    SetIndexStyle(2,DRAW_LINE,STYLE_DOT,1,DirColor(pregr.Direction(Polyline)));
    
    UpdateLabel("lrFOCNow",NegLPad(pregr.FOC(Now),1),DirColor(pregr.FOCDirection()),15);
    UpdateLabel("lrFOCPivDev",NegLPad(Pip(pregr.Pivot(Deviation)),1),DirColor(pregr.Direction(Pivot)),15);
    UpdateDirection("lrFOCPivDir",pregr.Direction(Pivot),DirColor(pregr.Direction(Pivot)),20);
    UpdateLabel("lrFOCRange",DoubleToStr(Pip(pregr.Range(Size)),1),DirColor(pregr.FOCDirection()),15);

    UpdateLabel("lrFOCDev",DoubleToStr(pregr.FOC(Deviation),1),DirColor(pregr.FOCDirection()));
    UpdateLabel("lrFOCMax",NegLPad(pregr.FOC(Max),1),DirColor(pregr.FOCDirection()));
    UpdateLabel("lrFOCPivDevMin",NegLPad(Pip(pregr.Pivot(Min)),1),DirColor(pregr.Direction(Pivot)));
    UpdateLabel("lrFOCPivDevMax",NegLPad(Pip(pregr.Pivot(Max)),1),DirColor(pregr.Direction(Pivot)));
    UpdateLabel("lrFOCPivPrice",DoubleToStr(pregr.Pivot(Price),Digits),DirColor(pregr.Direction(Pivot)));
    UpdateLabel("lrFOCTick",LPad(IntegerToString(pregr.Count(Tick))," ",2),DirColor(pregr.Direction(Tick)));
    UpdateLabel("lrFOCAge",LPad(IntegerToString(pregr.Count(BoolToInt(pregr.Direction(Range)==DirectionUp,RangeHigh,RangeLow)))," ",2),DirColor(pregr.Direction(Range)));
    UpdateLabel("lrPricePolyDev",NegLPad(pregr.Poly(Deviation),1),DirColor(pregr.Direction(Polyline)));
    UpdateLabel("lrPolyTrendDev",NegLPad(pregr.Trendline(Deviation),1),DirColor(pregr.Direction(Polyline)));
    
    UpdateLabel("lrFOCAmpDirection",pregr.Text(InDirection),DirColor(pregr.FOCDirection()));
    UpdateLabel("lrFOCState",pregr.Text(InState),DirColor(pregr.FOCDirection()));
    
    UpdateLabel("lrAmpData","Amp: "+DoubleToStr(pregr.FOCAmp(Now),1)
               +" x:"+DoubleToStr(pregr.FOCAmp(Max),1)
               +" p:"+DoubleToStr(pregr.FOCAmp(Peak),1),DirColor(pregr.Direction(FOCAmplitude)),10);
               
    UpdateDirection("lrStdDevDir",pregr.Direction(StdDev),DirColor(pregr.Direction(StdDev)),10);

    UpdateLabel("lrStdDevData","Std Dev: "+DoubleToStr(Pip(pregr.StdDev(Now)),1)
               +" x:"+DoubleToStr(fmax(Pip(pregr.StdDev(Positive)),fabs(Pip(pregr.StdDev(Negative)))),1)
               +" p:"+DoubleToStr(Pip(pregr.StdDev()),1)
               +" +"+DoubleToStr(Pip(pregr.StdDev(Positive)),1)
               +" "+DoubleToStr(Pip(pregr.StdDev(Negative)),1),DirColor(pregr.Direction(StdDev)),10);
               
    if (pregr.Event(NewBoundary))
    {
      if (pregr.Event(NewHigh))
        UpdateLabel("lrEvent","New High",clrLawnGreen,16);

      if (pregr.Event(NewLow))
        UpdateLabel("lrEvent","New Low",clrRed,16);
    }
    else
      UpdateLabel("lrEvent","No Event",clrGray,16);

    if (inpShowData)
    {
      if (pregr.Event(NewLow))
        UpdateLine("piprRngLow",pregr.Range(Bottom),STYLE_DOT,clrGoldenrod);
      else
        UpdateLine("piprRngLow",pregr.Range(Bottom),STYLE_DOT,DirColor(pregr.Direction(RangeLow)));

      UpdateLine("piprRngMid",pregr.Range(Mid),STYLE_DOT,clrGray);

      if (pregr.Event(NewHigh))
        UpdateLine("piprRngHigh",pregr.Range(Top),STYLE_DOT,clrGoldenrod);
      else
        UpdateLine("piprRngHigh",pregr.Range(Top),STYLE_DOT,DirColor(pregr.Direction(RangeHigh)));
    }

    lastDir = pregr.FOCDirection();
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
    delete pregr;
    
    ObjectDelete("piprRngLow");
    ObjectDelete("piprRngMid");
    ObjectDelete("piprRngHigh");
  }
