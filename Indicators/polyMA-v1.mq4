//+------------------------------------------------------------------+
//|                                                    polyMA-v1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_separate_window

#property indicator_buffers   2
#property indicator_plots     2

//--- plot poly
#property indicator_label1    "indPoly"
#property indicator_type1     DRAW_LINE
#property indicator_color1    clrFireBrick
#property indicator_style1    STYLE_SOLID
#property indicator_width1    1

//--- Input params
input int    inpDegree        = 6;        // Degree of the regression
input int    inpPeriods       = 24;       // Number of periods
input int    inpMAPeriods     = 3;        // Moving Average periods

#include <Class\PolyRegression.mqh>
#include <std_utility.mqh>

double    indPolyBuffer[];
string    indShortName        = "polyMA-v1 ("+IntegerToString(inpDegree)+":"+IntegerToString(inpPeriods)+":"+IntegerToString(inpMAPeriods)+")";

CPolyRegression *pregr = new CPolyRegression(inpDegree,inpPeriods,inpMAPeriods);

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
    pregr.UpdateBuffer(indPolyBuffer);
    SetLevelValue(1,pregr.PMean());
  
    UpdateLabel("pmAmpCur",NegLPad(Pip(pregr.PAmpMean()),1),DirColor(pregr.PAmpDirection()),15);
    UpdateLabel("pmAmpPos",DoubleToStr(Pip(pregr.PAmpPos()),1),DirColor(pregr.PAmpDirection()),9);
    UpdateLabel("pmAmpNeg",NegLPad(Pip(pregr.PAmpNeg()),1),DirColor(pregr.PAmpDirection()),9);
    UpdateLabel("pmAmpMax",NegLPad(Pip(pregr.PAmpMax()),1),DirColor(pregr.PAmpDirection()),15);

    UpdateDirection("pmAmpDir",pregr.PAmpDirection(),DirColor(pregr.PAmpDirection()),20);
  
    return(rates_total);
  }


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    SetIndexBuffer(0,indPolyBuffer);
    SetIndexEmptyValue(0,0.00);
    ArrayInitialize(indPolyBuffer,0.00);

    IndicatorShortName(indShortName);
    int IndWinId = ChartWindowFind(0,indShortName);

    NewLabel("pmAmp0","Amplitude",140,12,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("pmAmp1","Current",20,22,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("pmAmp2","Pos",12,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("pmAmp3","Neg",51,65,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("pmAmp4","Max",113,22,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("pmAmpCur","",18,32,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("pmAmpPos","",12,53,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("pmAmpNeg","",47,53,clrLightGray,SCREEN_UL,IndWinId);    
    NewLabel("pmAmpDir","",167,27,clrLightGray,SCREEN_UL,IndWinId);
    NewLabel("pmAmpMax","",92,32,clrLightGray,SCREEN_UL,IndWinId);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregr;
  }