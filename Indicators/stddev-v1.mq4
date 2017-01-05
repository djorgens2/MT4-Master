//+------------------------------------------------------------------+
//|                                                    stddev-v1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_separate_window

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
#property indicator_label1    "indStdDevNow"
#property indicator_type1     DRAW_LINE
#property indicator_color1    clrFireBrick
#property indicator_style1    STYLE_SOLID
#property indicator_width1    1

//--- plot poly
#property indicator_label2    "indStdDevMax"
#property indicator_type2     DRAW_LINE
#property indicator_color2    clrYellow
#property indicator_style2    STYLE_SOLID
#property indicator_width2    1

double    indStdDevNowBuffer[];
double    indStdDevMaxBuffer[];

string    sName = "stddev-v1("+IntegerToString(inpDegree)+":"+IntegerToString(inpPeriods)+":"+IntegerToString(inpSmoothFactor)+")";

CTrendRegression *tregr = new CTrendRegression(inpDegree,inpPeriods,inpSmoothFactor);

//+------------------------------------------------------------------+
//| RefreshScreen - updates screen data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
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
    tregr.Update();
        
    indStdDevNowBuffer[0] = tregr.StdDev(Now);

    SetLevelValue(2,tregr.StdDev());
    SetLevelValue(3,-tregr.StdDev());    
    SetLevelValue(4,tregr.StdDev(Max));
    SetLevelValue(5,-tregr.StdDev(Max));
    
    SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,1,DirColor(dir(tregr.StdDev(Now)),clrYellow,clrRed));

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
    
    SetIndexBuffer(0,indStdDevNowBuffer);
    SetIndexEmptyValue(0,0.00);
    ArrayInitialize(indStdDevNowBuffer,0.00);
    
    SetIndexBuffer(1,indStdDevMaxBuffer);
    SetIndexEmptyValue(1,0.00);
    ArrayInitialize(indStdDevMaxBuffer,0.00);
    
    tregr.SetTrendlineTolerance(inpTolerance);
    
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
