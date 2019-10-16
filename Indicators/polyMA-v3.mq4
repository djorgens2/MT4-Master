//+------------------------------------------------------------------+
//|                                                    polyMA-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers   3
#property indicator_plots     3

#include <std_utility.mqh>
#include <stdutil.mqh>
#include <Class\PolyRegression.mqh>

//--- plot poly
#property indicator_label1    "indPolyST"
#property indicator_type1     DRAW_LINE
#property indicator_color1    clrFireBrick
#property indicator_style1    STYLE_SOLID
#property indicator_width1    1

#property indicator_label2    "indPolyMT"
#property indicator_type2     DRAW_LINE
#property indicator_color2    clrFireBrick
#property indicator_style2    STYLE_SOLID
#property indicator_width2    1

#property indicator_label3    "indPolyLT"
#property indicator_type3     DRAW_LINE
#property indicator_color3    clrFireBrick
#property indicator_style3    STYLE_SOLID
#property indicator_width3    1
//--- Input params
input int    inpDegree        = 6;        // Degree of the regression
input int    inpPeriodsST     = 60;       // Short term regression periods
input int    inpPeriodsMT     = 120;      // Mid term regression periods
input int    inpPeriodsLT     = 240;      // Long term regression periods
input int    inpMAPeriods     = 3;        // MA Smoothing Factor

int       indWinId;
string    indShortName        = "polyMA-v3 ("+IntegerToString(inpDegree)
                               +"/"+IntegerToString(inpPeriodsST)
                               +":"+IntegerToString(inpPeriodsMT)
                               +":"+IntegerToString(inpPeriodsLT)
                               +"/"+IntegerToString(inpMAPeriods)+")";

CPolyRegression *pregrst = new CPolyRegression(inpDegree,inpPeriodsST,inpMAPeriods);
CPolyRegression *pregrmt = new CPolyRegression(inpDegree,inpPeriodsMT,inpMAPeriods);
CPolyRegression *pregrlt = new CPolyRegression(inpDegree,inpPeriodsLT,inpMAPeriods);

double    indPolyBufferST[];
double    indPolyBufferMT[];
double    indPolyBufferLT[];

//+------------------------------------------------------------------+
//| StrengthColor                                                    |
//+------------------------------------------------------------------+
color StrengthColor(double Strength)
  {    
    int scFibo = FiboLevel(Strength,Signed);
    
    if (scFibo<FiboRoot) return (clrGoldenrod);
    if (scFibo<Fibo38)   return (clrRed);
    if (scFibo<Fibo61)   return (clrYellow);
    if (scFibo<Fibo100)  return (clrLawnGreen);
    
    return (clrGoldenrod);
  }

//+------------------------------------------------------------------+
//| Refresh Screen                                                   |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    int    rsMTColor       = BoolToInt(pregrmt.Direction(Polyline)==DirectionUp,clrForestGreen,clrMaroon);
    int    rsLTColor       = BoolToInt(pregrlt.Direction(Polyline)==DirectionUp,clrLawnGreen,clrRed);
    int    rsLTWidth       = 1;
    int    rsLTStyle       = Tick;

    //--- compute overbought/oversold price level
    double rsPolyTop       = fmax(pregrst.Poly(Top),fmax(pregrmt.Poly(Top),pregrlt.Poly(Top)));
    double rsPolyBottom    = fmin(pregrst.Poly(Bottom),fmin(pregrmt.Poly(Bottom),pregrlt.Poly(Bottom)));
    double rsPolyBoundary  = (rsPolyTop-rsPolyBottom)*0.20;
    double rsUpperBoundary = rsPolyTop-rsPolyBoundary;
    double rsLowerBoundary = rsPolyBottom+rsPolyBoundary;

    ReservedWords rsState  = Tick;
    
    if (pregrst.Poly(Head)>rsUpperBoundary)
      if (pregrmt.Poly(Head)>rsUpperBoundary)
        if (pregrlt.Poly(Head)>rsUpperBoundary)
          rsState          = OverBought;
    
    if (pregrst.Poly(Head)<rsLowerBoundary)
      if (pregrmt.Poly(Head)<rsLowerBoundary)
        if (pregrlt.Poly(Head)<rsLowerBoundary)
          rsState          = OverSold;

    switch (pregrlt.State())
    {
      case Rally:  
      case Pullback: rsLTStyle = STYLE_DOT;
                     break;
      case Breakout: rsLTStyle = STYLE_SOLID;
                     break;
      case Reversal: rsLTWidth = 2;
                     rsLTColor = clrYellow;
    }
    
    if (pregrlt.Event(NewRally))
      NewArrow(SYMBOL_DASH,clrYellow,TimeToStr(Time[0])+":Rally",Close[0]);

    if (pregrlt.Event(NewPullback))
      NewArrow(SYMBOL_DASH,clrRed,TimeToStr(Time[0])+":Pullback",Close[0]);

    if (pregrlt.Event(NewBreakout))
      NewArrow(BoolToInt(pregrlt.Direction(PolyTrend)==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
        BoolToInt(pregrlt.Direction(PolyTrend)==DirectionUp,clrYellow,clrRed),TimeToStr(Time[0])+":Breakout",Close[0]);

    if (pregrlt.Event(NewReversal))
      NewArrow(BoolToInt(pregrlt.Direction(PolyTrend)==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
        clrGoldenrod,TimeToStr(Time[0])+":Breakout",Close[0]);

    SetIndexStyle(0,DRAW_SECTION,STYLE_DOT,1,clrGray);
    SetIndexStyle(1,DRAW_SECTION,STYLE_SOLID,1,rsMTColor);
    SetIndexStyle(2,DRAW_SECTION,rsLTStyle,1,rsLTColor);

    SetLevelValue(1,pregrlt.Poly(Mean));
    SetLevelValue(2,rsUpperBoundary);
    SetLevelValue(3,rsLowerBoundary);

    UpdateLine("prPolyMeanST",pregrst.Poly(Mean),STYLE_DOT,clrGray);
    UpdateLine("prPolyMeanMT",pregrmt.Poly(Mean),STYLE_SOLID,rsMTColor);
    UpdateLine("prPolyMeanLT",pregrlt.Poly(Mean),rsLTStyle,rsLTColor);

    UpdateDirection("prPolyTrend",pregrlt.Direction(PolyTrend),DirColor(pregrlt.Direction(PolyTrend)),24);
    UpdateLabel("prDeviation",NegLPad(pregrlt.Poly(Deviation),1),DirColor(dir(pregrlt.Poly(Deviation))),16);

    UpdateLabel("prMARange",DoubleToStr(Pip(rsPolyTop-rsPolyBottom),1),DirColor(dir(pregrlt.Poly(Deviation))),16);
    UpdateLabel("prPolyState",proper(DirText(pregrlt.Direction(PolyTrend)))+" ("+EnumToString(pregrlt.State())+")",rsLTColor,12);
    UpdateLabel("prTrendState",BoolToStr(rsState!=Tick,EnumToString(rsState)),rsLTColor,12);

    UpdateLabel("prSTStrength",DoubleToStr(pregrst.Poly(Strength)*100,1),StrengthColor(pregrst.Poly(Strength)),16);
    UpdateLabel("prMTStrength",DoubleToStr(pregrmt.Poly(Strength)*100,1),StrengthColor(pregrmt.Poly(Strength)),16);
    UpdateLabel("prLTStrength",DoubleToStr(pregrlt.Poly(Strength)*100,1),StrengthColor(pregrlt.Poly(Strength)),16);
//    UpdateLabel("prLTStrength",IntegerToString(FiboLevel(pregrlt.Poly(Strength))),StrengthColor(pregrlt.Poly(Strength)),16);

    UpdatePriceLabel("prPolyMANow",pregrlt.MA(Now),clrWhite);
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    pregrst.UpdateBuffer(indPolyBufferST);
    pregrmt.UpdateBuffer(indPolyBufferMT);
    pregrlt.UpdateBuffer(indPolyBufferLT);
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
    GetData();
    RefreshScreen();
    
    return(rates_total);
  }   

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    SetIndexBuffer(0,indPolyBufferST);
    SetIndexEmptyValue(0,0.00);
    ArrayInitialize(indPolyBufferST,0.00);

    SetIndexBuffer(1,indPolyBufferMT);
    SetIndexEmptyValue(1,0.00);
    ArrayInitialize(indPolyBufferMT,0.00);

    SetIndexBuffer(2,indPolyBufferLT);
    SetIndexEmptyValue(2,0.00);
    ArrayInitialize(indPolyBufferLT,0.00);

    IndicatorShortName(indShortName);
    indWinId = ChartWindowFind(0,indShortName);
    
    NewLabel("pr0","Direction",60,17,clrGoldenrod,SCREEN_UL,indWinId);
    NewLabel("pr10","Strength",220,17,clrGoldenrod,SCREEN_UL,indWinId);
    NewLabel("pr1","Deviation",18,54,clrWhite,SCREEN_UL,indWinId);
    NewLabel("pr2","Range",120,54,clrWhite,SCREEN_UL,indWinId);
    NewLabel("pr21","Short",180,54,clrWhite,SCREEN_UL,indWinId);
    NewLabel("pr22","Mid",235,54,clrWhite,SCREEN_UL,indWinId);
    NewLabel("pr23","Long",290,54,clrWhite,SCREEN_UL,indWinId);
    NewLabel("prPolyTrend","",70,31,clrGray,SCREEN_UL,indWinId);
    NewLabel("prDeviation","",10,31,clrGray,SCREEN_UL,indWinId);
    NewLabel("prMARange","",110,31,clrGray,SCREEN_UL,indWinId);
    NewLabel("prPolyState","",5,5,clrGray,SCREEN_UR,indWinId);
    NewLabel("prTrendState","",5,20,clrGray,SCREEN_UR,indWinId);
    NewLabel("prSTStrength","",172,31,clrGray,SCREEN_UL,indWinId);
    NewLabel("prMTStrength","",227,31,clrGray,SCREEN_UL,indWinId);
    NewLabel("prLTStrength","",282,31,clrGray,SCREEN_UL,indWinId);

    NewLine("prPolyMeanST");
    NewLine("prPolyMeanMT");
    NewLine("prPolyMeanLT");

    NewPriceLabel("prPolyMANow",0.00,false,indWinId);
    
    return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregrst;
    delete pregrmt;
    delete pregrlt;
  }