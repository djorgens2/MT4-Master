//+------------------------------------------------------------------+
//|                                                    TickMA-v1.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   10

#include <Class\TickMA.mqh>
#include <std_utility.mqh>

//--- plot plHigh
#property indicator_label1  "plHigh"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrNONE
#property indicator_style1  STYLE_DOT
#property indicator_width1  0

//--- plot plLow
#property indicator_label2  "plLow"
#property indicator_type2   DRAW_SECTION
#property indicator_color2  clrNONE
#property indicator_style2  STYLE_DOT
#property indicator_width2  0

//--- plot plOpenSMA
#property indicator_label3  "plOpenSMA"
#property indicator_type3   DRAW_SECTION
#property indicator_color3  clrForestGreen
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- plot plHighSMA
#property indicator_label4  "plHighSMA"
#property indicator_type4   DRAW_SECTION
#property indicator_color4  clrGoldenrod
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- plot plLowSMA
#property indicator_label5  "plLowSMA"
#property indicator_type5   DRAW_SECTION
#property indicator_color5  clrSilver
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- plot plCloseSMA
#property indicator_label6  "plCloseSMA"
#property indicator_type6   DRAW_SECTION
#property indicator_color6  clrFireBrick
#property indicator_style6  STYLE_DOT
#property indicator_width6  1

//--- plot plOpenPoly
#property indicator_label7  "plOpenPoly"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrForestGreen
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

//--- plot plClosePoly
#property indicator_label8 "plClosePoly"
#property indicator_type8  DRAW_LINE
#property indicator_color8 clrFireBrick
#property indicator_style8 STYLE_SOLID
#property indicator_width8 1

//--- plot plOpenLine
#property indicator_label9 "plOpenLine"
#property indicator_type9  DRAW_SECTION
#property indicator_color9 clrDodgerBlue
#property indicator_style9 STYLE_SOLID
#property indicator_width9 1

//--- plot plCloseLine
#property indicator_label10 "plCloseLine"
#property indicator_type10  DRAW_SECTION
#property indicator_color10 clrDodgerBlue
#property indicator_style10 STYLE_DASH
#property indicator_width10 1

//--- input parameters
input int      inpPeriods             =  90;   // Retention
input int      inpDegree              =   6;   // Poiy Regression Degree
input int      inpSMA                 =   3;   // SMA Smoothing
input double   inpAgg                 = 2.5;   // Tick Aggregation

//--- Indicator defs
string         ShortName          = "TickMA-v2: "+(string)inpPeriods+":"+(string)inpDegree+":"+(string)inpSMA+":"+(string)inpAgg;
int            IndWinId  = -1;

//--- Indicator buffers
double         plHighBuffer[];
double         plLowBuffer[];
double         plSMAOpenBuffer[];
double         plSMACloseBuffer[];
double         plSMAHighBuffer[];
double         plSMALowBuffer[];
double         plPolyOpenBuffer[];
double         plPolyCloseBuffer[];
double         plLineOpenBuffer[];
double         plLineCloseBuffer[];

double         plSMAOpen[1];
double         plSMAClose[1];
double         plSMAHigh[1];
double         plSMALow[1];

//--- Class defs
CTickMA       *t                 = new CTickMA(inpPeriods,inpDegree,inpSMA,inpAgg);

//--- Object defs
//double

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdateLabel("tmaRangeState",EnumToString(t.Range().State),clrDarkGray,12);
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
    if (t[NewSegment])
      ArrayCopy(Source,Source,1,0,inpPeriods-1);
    
    Source[0]          = Price;
  }

//+------------------------------------------------------------------+
//| UpdateTickMA - refreshes indicator data                          |
//+------------------------------------------------------------------+
void UpdateTickMA(void)
  {
    static int bars;

    t.Update();
    
    SetLevelValue(1,fdiv(t.Range().High+t.Range().Low,2));
    SetIndexStyle(8,DRAW_LINE,STYLE_SOLID,1,Color(t.Line().Direction,IN_CHART_DIR));
    SetIndexStyle(9,DRAW_LINE,STYLE_DASH,1,Color(t.Range().Direction,IN_CHART_DIR));

    UpdateBuffer(plSMAOpen,t.SMA().Slow.Open);
    UpdateBuffer(plSMAHigh,t.SMA().Fast.High);
    UpdateBuffer(plSMALow,t.SMA().Fast.Low);
    UpdateBuffer(plSMAClose,t.SMA().Slow.Close);

    if (IsChanged(bars,Bars)||t[NewTick])
    {
      ResetBuffer(plSMAOpenBuffer,plSMAOpen);
      ResetBuffer(plSMACloseBuffer,plSMAClose);
      ResetBuffer(plSMAHighBuffer,plSMAHigh);
      ResetBuffer(plSMALowBuffer,plSMALow);

      ResetBuffer(plPolyOpenBuffer,t.Poly().Open);
      ResetBuffer(plPolyCloseBuffer,t.Poly().Close);
      ResetBuffer(plLineOpenBuffer,t.Line().Open);
      ResetBuffer(plLineCloseBuffer,t.Line().Close);
    }
  }

//+------------------------------------------------------------------+
//| UpdateNode - Repaints Node Bars                                  |
//+------------------------------------------------------------------+
void UpdateNode(string NodeName, int Node, double Price1, double Price2)
  {
    ObjectSet(NodeName+(string)Node,OBJPROP_COLOR,Color(t.Segment(Node).Price.Close-t.Segment(Node).Price.Open));
    ObjectSet(NodeName+(string)Node,OBJPROP_PRICE1,Price1);
    ObjectSet(NodeName+(string)Node,OBJPROP_PRICE2,Price2);
    ObjectSet(NodeName+(string)Node,OBJPROP_TIME1,Time[Node]);
    ObjectSet(NodeName+(string)Node,OBJPROP_TIME2,Time[Node]);
  }

//+------------------------------------------------------------------+
//| UpdateSegment - Repaints visuals                                 |
//+------------------------------------------------------------------+
void UpdateSegment(void)
  {
    if (t[NewSegment])
    {
      ArrayInitialize(plHighBuffer,0.00);
      ArrayInitialize(plLowBuffer,0.00);
    }

    for (int node=0;node<inpPeriods;node++)
    {
      UpdateNode("tmaHL:",node,t.Segment(node).Price.High,t.Segment(node).Price.Low);
      UpdateNode("tmaOC:",node,t.Segment(node).Price.Open,t.Segment(node).Price.Close);
    }

    plHighBuffer[0]        = t.Range().High;
    plLowBuffer[0]         = t.Range().Low;
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
    UpdateTickMA();
    UpdateSegment();

    RefreshScreen();

    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- Initialize Indicator
    IndicatorShortName(ShortName);
    IndWinId = ChartWindowFind(0,ShortName);

    //--- Initialize Buffers
    SetIndexBuffer(0,plHighBuffer);
    SetIndexBuffer(1,plLowBuffer);
    SetIndexBuffer(2,plSMAOpenBuffer);
    SetIndexBuffer(3,plSMAHighBuffer);
    SetIndexBuffer(4,plSMALowBuffer);
    SetIndexBuffer(5,plSMACloseBuffer);
    SetIndexBuffer(6,plPolyOpenBuffer);
    SetIndexBuffer(7,plPolyCloseBuffer);
    SetIndexBuffer(8,plLineOpenBuffer);
    SetIndexBuffer(9,plLineCloseBuffer);

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

    //--- Create Display Visuals
    for (int obj=0;obj<inpPeriods;obj++)
    {
      ObjectCreate("tmaHL:"+(string)obj,OBJ_TREND,IndWinId,0,0);
      ObjectSet("tmaHL:"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaHL:"+(string)obj,OBJPROP_WIDTH,1);

      ObjectCreate("tmaOC:"+(string)obj,OBJ_TREND,IndWinId,0,0);
      ObjectSet("tmaOC:"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaOC:"+(string)obj,OBJPROP_WIDTH,3);
    }

    NewLabel("tmaRangeState","",5,5,clrDarkGray,SCREEN_UR,IndWinId);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
  }