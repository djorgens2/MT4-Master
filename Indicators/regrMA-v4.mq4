//+------------------------------------------------------------------+
//|                                                    regrMA-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <Class\TrendRegression.mqh>
#include <std_utility.mqh>

//--- Input params
input int    inpDegree        = 6;        // Degree of the regression
input int    inpPeriods       = 24;       // Number of periods
input int    inpSmoothFactor  = 3;        // Moving Average smoothing factor
input double inpTolerance     = 0.5;      // Trend tolerance
input bool   inpShowData      = false;    // Shows computed metrics

#property indicator_buffers   2
#property indicator_plots     2

//--- plot poly
#property indicator_label1    "indPoly"
#property indicator_type1     DRAW_LINE
#property indicator_color1    clrFireBrick
#property indicator_style1    STYLE_SOLID
#property indicator_width1    1

//--- plot trend
#property indicator_label2    "indTrend"
#property indicator_type2     DRAW_LINE
#property indicator_color2    clrFireBrick
#property indicator_style2    STYLE_SOLID
#property indicator_width2    1

double    indPolyBuffer[];
double    indTrendBuffer[];

int       ampChg  = 0;
string    sName = "regrMA-v4("+IntegerToString(inpDegree)+":"+IntegerToString(inpPeriods)+":"+IntegerToString(inpSmoothFactor)+")";

CTrendRegression *tregr = new CTrendRegression(inpDegree,inpPeriods,inpSmoothFactor);

//+------------------------------------------------------------------+
//| RefreshScreen - updates screen data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    if (inpShowData)
    {
      UpdateLabel("rgFOCCur",NegLPad(tregr.FOC(Now),1),DirColor(tregr.FOCDirection()),15);
      UpdateLabel("rgFOCPivDev",NegLPad(Pip(tregr.Pivot(Deviation)),1),DirColor(tregr.Direction(Pivot)),15);
      UpdateDirection("rgFOCPivDir",tregr.Direction(Pivot),DirColor(tregr.Direction(Pivot)),20);

      UpdateLabel("rgFOCDev",DoubleToStr(tregr.FOC(Deviation),1),DirColor(tregr.FOCDirection()));
      UpdateLabel("rgFOCMax",NegLPad(tregr.FOC(Max),1),DirColor(tregr.FOCDirection()));
      UpdateLabel("rgFOCPivDevMin",NegLPad(Pip(tregr.Pivot(Min)),1),DirColor(tregr.Direction(Pivot)));
      UpdateLabel("rgFOCPivDevMax",NegLPad(Pip(tregr.Pivot(Max)),1),DirColor(tregr.Direction(Pivot)));
      UpdateLabel("rgFOCPivPrice",DoubleToStr(tregr.Pivot(Price),Digits),DirColor(tregr.Direction(Pivot)));
      UpdateLabel("rgFOCTrendLow",DoubleToStr(tregr.Trendline(Bottom),Digits),DirColor(tregr.Direction(Trendline)));
      UpdateLabel("rgFOCTrendHigh",DoubleToStr(tregr.Trendline(Top),Digits),DirColor(tregr.Direction(Trendline)));
      UpdateLabel("rgFOCAmpDir",proper(DirText(tregr.Direction(FOCAmplitude)))
                 +"  Retrace: "+DoubleToStr(tregr.FOC(Retrace)*100,1)+"%",DirColor(tregr.FOCDirection()));
      
      UpdateDirection("rgStdDevDir",tregr.Direction(StdDev),DirColor(tregr.Direction(StdDev)),9);
            
      if (tregr.TrendWane())
        UpdateDirection("rgFOCTrendDir",tregr.Direction(Trendline),clrYellow,20);
      else
        UpdateDirection("rgFOCTrendDir",tregr.Direction(Trendline),DirColor(tregr.Direction(Trendline)),20);

      UpdateLabel("rgStdDevData","Std Dev: "+DoubleToStr(Pip(tregr.StdDev(Now)),1)
                 +" x:"+DoubleToStr(fmax(Pip(tregr.StdDev(Positive)),fabs(Pip(tregr.StdDev(Negative)))),1)
                 +" p:"+DoubleToStr(Pip(tregr.StdDev()),1)
                 +" +"+DoubleToStr(Pip(tregr.StdDev(Positive)),1)
                 +" "+DoubleToStr(Pip(tregr.StdDev(Negative)),1),DirColor(dir(tregr.StdDev(Now))),8);
    }
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
    static int ocPolylineDir = DirectionNone;
    static int ocFOCDir      = DirectionNone;
    
    int        highStyle     = STYLE_DOT;
    int        lowStyle      = STYLE_DOT;
    
    tregr.UpdateBuffer(indPolyBuffer,indTrendBuffer);
        
    if (IsChanged(ocFOCDir,tregr.FOCDirection()))
      SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,1,DirColor(tregr.FOCDirection(),clrYellow,clrRed));
      
    if (IsChanged(ocPolylineDir,tregr.Direction(Polyline)))
      SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,1,DirColor(tregr.Direction(Polyline),clrForestGreen));


    RefreshScreen();
    
    //--- return value of prev_calculated for next call
    return(rates_total);    
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  { 
    IndicatorShortName(sName);
    
    SetIndexBuffer(0,indPolyBuffer);
    SetIndexEmptyValue(0,0.00);
    ArrayInitialize(indPolyBuffer,0.00);
    
    SetIndexBuffer(1,indTrendBuffer);
    SetIndexEmptyValue(1,0.00);
    ArrayInitialize(indTrendBuffer,0.00);
    
    tregr.SetTrendlineTolerance(inpTolerance);
    
    InitScreenObjects();
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete tregr;
    
    ObjectDelete("rgFOC0");
    ObjectDelete("rgFOC1");
    ObjectDelete("rgFOC2");
    ObjectDelete("rgFOC3");
    ObjectDelete("rgFOCCur");
    ObjectDelete("rgFOCPivDev");
    ObjectDelete("rgFOCPivDir");
    ObjectDelete("rgFOCTrendDir");    
    ObjectDelete("rgFOCDev");
    ObjectDelete("rgFOCMax");
    ObjectDelete("rgFOCPivDevMin");
    ObjectDelete("rgFOCPivDevMax");
    ObjectDelete("rgFOCPivPrice");
    ObjectDelete("rgFOCTrendLow");
    ObjectDelete("rgFOCTrendHigh");
    ObjectDelete("rgFOC5");
    ObjectDelete("rgFOC6");
    ObjectDelete("rgFOC7");
    ObjectDelete("rgFOC8");
    ObjectDelete("rgFOC9");
    ObjectDelete("rgFOC10");
    ObjectDelete("rgFOC11");
    ObjectDelete("rgFOC12");
    ObjectDelete("rgFOCAmpDir");
    ObjectDelete("rgFOCTrendDir");
    ObjectDelete("rgStdDevDir");
    ObjectDelete("rgStdDevData");
  }
  
//+------------------------------------------------------------------+
//| InitScreenObjects - sets up screen labels and trend lines        |
//+------------------------------------------------------------------+
void InitScreenObjects()
  {
    if (inpShowData)
    {
      NewLabel("rgFOC0","Factor of Change",10,78,clrGoldenrod,SCREEN_LL);
      NewLabel("rgFOC1","Pivot",140,78,clrGoldenrod,SCREEN_LL);
      NewLabel("rgFOC12","Trend",243,78,clrGoldenrod,SCREEN_LL);

      NewLabel("rgFOC2","Current",20,65,clrWhite,SCREEN_LL);
      NewLabel("rgFOC3","Dev",113,65,clrWhite,SCREEN_LL);
    
      NewLabel("rgFOCCur","",18,43,clrLightGray,SCREEN_LL);
      NewLabel("rgFOCPivDev","",95,43,clrLightGray,SCREEN_LL);
      NewLabel("rgFOCPivDir","",170,39,clrLightGray,SCREEN_LL);
      NewLabel("rgFOCTrendDir","",247,39,clrNONE,SCREEN_LL);

      NewLabel("rgFOCDev","",12,32,clrNONE,SCREEN_LL);
      NewLabel("rgFOCMax","",47,32,clrNONE,SCREEN_LL);
      NewLabel("rgFOCPivDevMin","",85,32,clrNONE,SCREEN_LL);
      NewLabel("rgFOCPivDevMax","",122,32,clrNONE,SCREEN_LL);
      NewLabel("rgFOCPivPrice","",160,32,clrNONE,SCREEN_LL);
      NewLabel("rgFOCTrendLow","",215,32,clrNONE,SCREEN_LL);
      NewLabel("rgFOCTrendHigh","",260,32,clrNONE,SCREEN_LL);
      
      NewLabel("rgFOC5","Dev",12,22,clrWhite,SCREEN_LL);
      NewLabel("rgFOC6","Max",51,22,clrWhite,SCREEN_LL);
      NewLabel("rgFOC7","Min",92,22,clrWhite,SCREEN_LL);
      NewLabel("rgFOC8","Max",127,22,clrWhite,SCREEN_LL);
      NewLabel("rgFOC9","Price",169,22,clrWhite,SCREEN_LL);
      NewLabel("rgFOC10","Low",228,22,clrWhite,SCREEN_LL);
      NewLabel("rgFOC11","High",270,22,clrWhite,SCREEN_LL);
      
      NewLabel("rgFOCAmpDir","",15,12,clrNONE,SCREEN_LL);
      NewLabel("rgStdDevDir","",5,0,clrLightGray,SCREEN_LL);
      NewLabel("rgStdDevData","",18,1,clrLightGray,SCREEN_LL);
    }
  }    
