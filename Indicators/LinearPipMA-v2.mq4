//+------------------------------------------------------------------+
//|                                                  LinearPipMA.mq4 |
//|                                                 Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 12
#property indicator_plots   12

#include <Class\PipMA.mqh>
#include <std_utility.mqh>

//--- plot plOpen
#property indicator_label1  "plOpen"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrForestGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot plClose
#property indicator_label2  "plClose"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- plot plHigh
#property indicator_label3  "plHigh"
#property indicator_type3   DRAW_SECTION
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- plot plLow
#property indicator_label4  "plLow"
#property indicator_type4   DRAW_SECTION
#property indicator_color4  clrGoldenrod
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- plot plOpenSMA
#property indicator_label5  "plOpenSMA"
#property indicator_type5   DRAW_SECTION
#property indicator_color5  clrForestGreen
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- plot plCloseSMA
#property indicator_label6  "plCloseSMA"
#property indicator_type6   DRAW_SECTION
#property indicator_color6  clrFireBrick
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- plot plHighSMA
#property indicator_label7  "plHighSMA"
#property indicator_type7   DRAW_SECTION
#property indicator_color7  clrSilver
#property indicator_style7  STYLE_DOT
#property indicator_width7  1

//--- plot plLowSMA
#property indicator_label8  "plLowSMA"
#property indicator_type8   DRAW_SECTION
#property indicator_color8  clrGoldenrod
#property indicator_style8  STYLE_DOT
#property indicator_width8  1

//--- plot plHighPoly
#property indicator_label9  "plHighPoly"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrForestGreen
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

//--- plot plLowPoly
#property indicator_label10 "plLowPoly"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrFireBrick
#property indicator_style10 STYLE_SOLID
#property indicator_width10 1

//--- plot plSlope
#property indicator_label11 "plSlopeOpen"
#property indicator_type11  DRAW_SECTION
#property indicator_color11 clrDodgerBlue
#property indicator_style11 STYLE_SOLID
#property indicator_width11 1

#property indicator_label12 "plSlopeClose"
#property indicator_type12  DRAW_SECTION
#property indicator_color12 clrDodgerBlue
#property indicator_style12 STYLE_DASH
#property indicator_width12 1

//--- input parameters
input int      inpPeriods             =  90;   // Retention
input int      inpDegree              =   6;   // Poiy Regression Degree
input int      inpSMA                 =   3;   // SMA Smoothing
input double   inpAgg                 = 2.5;   // Tick Aggregation

//--- Indicator defs
string         ShortName          = "Linear-PipMA-v2: "+(string)inpPeriods+":"+(string)inpDegree+":"+(string)inpSMA+":"+(string)inpAgg;
int            IndWinId  = -1;

//--- Indicator buffers
double         plOpenBuffer[];
double         plCloseBuffer[];
double         plHighBuffer[];
double         plLowBuffer[];
double         plSMAOpenBuffer[];
double         plSMACloseBuffer[];
double         plSMAHighBuffer[];
double         plSMALowBuffer[];
double         plPolyOpenBuffer[];
double         plPolyCloseBuffer[];
double         plSlopeOpenBuffer[];
double         plSlopeCloseBuffer[];

//--- Class defs
CPipMA        *pma           = new CPipMA(inpPeriods,inpDegree,inpSMA,inpAgg);

//--- Work buffer arrays
double         plClose[];
double         plOpen[];
double         plHigh[];
double         plLow[];
double         plSMAOpen[];
double         plSMAClose[];
double         plSMAHigh[];
double         plSMALow[];

//+------------------------------------------------------------------+
//| RefreshScreen - Repaint indicator display                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static EventType tick    = NoEvent;
    static EventType term    = NoEvent;
    
    int    dircolor          = Color(Direction(plSlopeCloseBuffer[0]-plSlopeOpenBuffer[0],IN_CHART_DIR));

//    SetLevelValue(1,fdiv(plSlopeOpenBuffer[0]+plSlopeOpenBuffer[inpPeriods-1],2));
    SetIndexStyle(10,DRAW_LINE,STYLE_SOLID,1,dircolor);
    SetIndexStyle(11,DRAW_LINE,STYLE_DASH,1,dircolor);
    
    if (pma.ActiveEvent())
    {
      event                  = pma.LastEvent();
      term                   = BoolToEvent(pma[NewReversal],NewReversal,
                               BoolToEvent(pma[NewBreakout],NewBreakout,term));
    }

    UpdateLabel("plMasterEvent",EventText[tick],BoolToInt(pma.ActiveEvent(),clrYellow,clrDarkGray),12);
  }

//+------------------------------------------------------------------+
//| ResetBuffer - Reset Buffer on bar change                         |
//+------------------------------------------------------------------+
void ResetBuffer(double &Buffer[], double &Source[], int Count)
  {
    ArrayInitialize(Buffer,0.00);
    ArrayCopy(Buffer,Source,0,0,Count);
  }

//+------------------------------------------------------------------+
//| ResetBuffer - Reset Buffer on bar change                         |
//+------------------------------------------------------------------+
void ResetBuffer(double &Buffer[], double &Source[])
  {
    ArrayInitialize(Buffer,0.00);
    ArrayCopy(Buffer,Source,0,0,inpPeriods);
  }

//+------------------------------------------------------------------+
//| LoadBuffer - Insert Regression buffer value                      |
//+------------------------------------------------------------------+
void UpdateBuffer(double &Source[], double Price)
  {
    ArrayCopy(Source,Source,1,0,inpPeriods-1);
    
    Source[0]          = Price;
  }

//+------------------------------------------------------------------+
//| UpdatePipMA - refreshes indicator data                           |
//+------------------------------------------------------------------+
void UpdatePipMA(void)
  {
    static int bars;

    pma.Update();
    
    if (pma[NewTick])
    {
      UpdateBuffer(plOpen,pma.Master().History[0].Open);
      UpdateBuffer(plClose,pma.Master().History[1].Close);
      UpdateBuffer(plHigh,pma.Master().History[1].High);
      UpdateBuffer(plLow,pma.Master().History[1].Low);
      UpdateBuffer(plSMAOpen,pma.Master().SMA.Open);
      UpdateBuffer(plSMAClose,pma.Master().SMA.Close);
      UpdateBuffer(plSMAHigh,pma.Master().SMA.High);
      UpdateBuffer(plSMALow,pma.Master().SMA.Low);
    }
      
    if (IsChanged(bars,Bars)||pma[NewTick])
    {
      ResetBuffer(plOpenBuffer,plOpen);
      ResetBuffer(plCloseBuffer,plClose);
      ResetBuffer(plHighBuffer,plHigh);
      ResetBuffer(plLowBuffer,plLow);
      ResetBuffer(plSMAOpenBuffer,plSMAOpen);
      ResetBuffer(plSMACloseBuffer,plSMAClose);
      ResetBuffer(plSMAHighBuffer,plSMAHigh);
      ResetBuffer(plSMALowBuffer,plSMALow);
      ResetBuffer(plPolyOpenBuffer,pma.Master().Poly.Open,pma[0].Segment);
      ResetBuffer(plPolyCloseBuffer,pma.Master().Poly.Close,pma[0].Segment);
      ResetBuffer(plSlopeOpenBuffer,pma.Master().Slope.Open,pma[0].Segment);
      ResetBuffer(plSlopeCloseBuffer,pma.Master().Slope.Close,pma[0].Segment);
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
    UpdatePipMA();
    RefreshScreen();
    return(rates_total);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- indicator buffers mapping
    SetIndexBuffer(0,plOpenBuffer);
    SetIndexBuffer(1,plCloseBuffer);
    SetIndexBuffer(2,plHighBuffer);
    SetIndexBuffer(3,plLowBuffer);
    SetIndexBuffer(4,plSMAOpenBuffer);
    SetIndexBuffer(5,plSMACloseBuffer);
    SetIndexBuffer(6,plSMAHighBuffer);
    SetIndexBuffer(7,plSMALowBuffer);
    SetIndexBuffer(8,plPolyOpenBuffer);
    SetIndexBuffer(9,plPolyCloseBuffer);
    SetIndexBuffer(10,plSlopeOpenBuffer);
    SetIndexBuffer(11,plSlopeCloseBuffer);
    
    //--- Set Empty Index Values
    SetIndexEmptyValue(0,0.00);
    SetIndexEmptyValue(1,0.00);
    SetIndexEmptyValue(2,0.00);
    SetIndexEmptyValue(3,0.00);
    SetIndexEmptyValue(4,0.00);
    SetIndexEmptyValue(5,0.00);
    SetIndexEmptyValue(6,0.00);
    SetIndexEmptyValue(7,0.00);
    SetIndexEmptyValue(8,0.00);
    SetIndexEmptyValue(9,0.00);
    SetIndexEmptyValue(10,0.00);
    SetIndexEmptyValue(11,0.00);
    
    //--- Set Buffer Size Limits
    ArrayResize(plOpen,inpPeriods);
    ArrayResize(plClose,inpPeriods);
    ArrayResize(plHigh,inpPeriods);
    ArrayResize(plLow,inpPeriods);
    ArrayResize(plSMAOpen,inpPeriods);
    ArrayResize(plSMAClose,inpPeriods);
    ArrayResize(plSMAHigh,inpPeriods);
    ArrayResize(plSMALow,inpPeriods);

    //--- Create Display Visuals
    IndicatorShortName(ShortName);
    IndWinId = ChartWindowFind(0,ShortName);

    NewLabel("plMasterEvent","",5,5,clrDarkGray,SCREEN_LR,IndWinId);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pma;
  }