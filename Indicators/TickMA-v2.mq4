//+------------------------------------------------------------------+
//|                                                    TickMA-v2.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.02"
#property strict
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   10

#include <Class\TickMA.mqh>
#include <std_utility.mqh>

#define debug false

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
input int       inpPeriods        =  80;         // Retention
input int       inpDegree         =   6;         // Poiy Regression Degree
input double    inpAgg            = 2.5;         // Tick Aggregation
input bool      inpShowComment    = true;        // Display Comments
input bool      inpSegBounds      = true;        // Show Segment Bounds
input bool      inpFractalBounds  = true;        // Show Fractal Bounds
input bool      inpFractalRulers  = true;        // Show Fractal Rulers

//--- Indicator defs
string         indSN              = "TickMA-v2: "+(string)inpPeriods+":"+(string)inpDegree+":"+(string)inpAgg;
int            indWinId           = NoValue;
int            indSegHist         = NoValue;

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
CTickMA       *t                 = new CTickMA(inpPeriods,inpDegree,inpAgg);

//--- Operational Vars
double         highbuffer        = NoValue;
double         lowbuffer         = NoValue;

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    if (inpSegBounds)
    {
      UpdatePriceLabel("tmaPL(sp):"+(string)indWinId,t.Segment().Support,clrRed);
      UpdatePriceLabel("tmaPL(rs):"+(string)indWinId,t.Segment().Resistance,clrLawnGreen);
      UpdatePriceLabel("tmaPL(e):"+(string)indWinId,t.Segment().Expansion,clrGoldenrod);
    }

    //-- Range/Poly
    UpdateLabel("tmaRangeState"+(string)indWinId,EnumToString(t.Range().State)+
                  BoolToStr(debug," ["+string(t.Count(Ticks)-1)+":"+string(t.Count(Segments)-1)+"]")+" Age ["+(string)t.Range().Age+"]",
                  Color(Direction(t.Range().Direction)),12);
    UpdateDirection("tmaPolyBias"+(string)indWinId,t.Poly().Direction,Color(Direction(t.Poly().Bias,InAction)),18);

    //-- Segment
    UpdateDirection("tmaSegmentTerm"+(string)indWinId,t.Segment().Direction[Term],Color(t.Segment().Direction[Term]),18);
    UpdateDirection("tmaSegmentTrend"+(string)indWinId,t.Segment().Direction[Trend],Color(t.Segment().Direction[Trend]),10,Narrow);
    UpdateLabel("tmaSegmentState"+(string)indWinId,proper(DirText(t.Segment().Direction[Term]))+" ["+(string)t.Segment().Count+"]: "+
                  proper(ActionText(Action(t.Segment().Direction[Lead]))),Color(t.Segment().Direction[Term]),12);
    UpdateDirection("tmaSegmentBias"+(string)indWinId,t.Segment().Direction[Lead],Color(Direction(t.Segment().Bias,InAction)),18);

    //-- Net Bias
    UpdateLabel("tmaSMAState"+(string)indWinId,BoolToStr(IsEqual(t.SMA().Event,NoEvent),
                  proper(DirText(t.SMA().Direction))+" "+EnumToString(t.SMA().State),EventText[t.SMA().Event]),Color(t.SMA().Direction),12);
    UpdateDirection("tmaSMABias"+(string)indWinId,t.SMA().Direction/*Lead*/,Color(Direction(t.SMA().Bias,InAction)),18);

    //-- High Bias
    UpdateDirection("tmaSMATermHi"+(string)indWinId,t.Fractal().High.Direction[Term],Color(t.Fractal().High.Direction[Term]),18);
    UpdateDirection("tmaSMATrendHi"+(string)indWinId,t.Fractal().High.Direction[Trend],Color(t.Fractal().High.Direction[Trend]),10,Narrow);
    UpdateLabel("tmaSMAStateHi"+(string)indWinId,proper(DirText(t.Direction(t.SMA().High)))+" "+FractalTag[t.Fractal().High.Type]+" "+
                  BoolToStr(Close[0]>t.SMA().High[0],"Hold",BoolToStr(Close[0]>t.SMA().Close[0],"Rally","Pullback")),Color(t.Direction(t.SMA().High)),12);
    UpdateLabel("tmaSMAMomentumHi"+(string)indWinId,DoubleToStr(pip(t.Momentum().High.Now),1),Color(Direction(t.Momentum().High.Bias,InAction),IN_CHART_DIR),9);
    UpdateDirection("tmaSMABiasHi"+(string)indWinId,t.Direction(t.SMA().High),Color(t.Direction(t.SMA().High)),18);

    //-- Low Bias
    UpdateDirection("tmaSMATermLo"+(string)indWinId,t.Fractal().Low.Direction[Term],Color(t.Fractal().Low.Direction[Term]),18);
    UpdateDirection("tmaSMATrendLo"+(string)indWinId,t.Fractal().Low.Direction[Trend],Color(t.Fractal().Low.Direction[Trend]),10,Narrow);
    UpdateLabel("tmaSMAStateLo"+(string)indWinId,proper(DirText(t.Direction(t.SMA().Low)))+" "+FractalTag[t.Fractal().Low.Type]+" "+
                  BoolToStr(Close[0]<t.SMA().Low[0],"Hold",BoolToStr(Close[0]>t.SMA().Close[0],"Rally","Pullback")),Color(t.Direction(t.SMA().Low)),12);
    UpdateLabel("tmaSMAMomentumLo"+(string)indWinId,DoubleToStr(pip(t.Momentum().Low.Now),1),Color(Direction(t.Momentum().Low.Bias,InAction),IN_CHART_DIR),9);
    UpdateDirection("tmaSMABiasLo"+(string)indWinId,t.Direction(t.SMA().Low),Color(t.Direction(t.SMA().Low)),18);

    //-- Linear
    UpdateLabel("tmaLinearStateOpen"+(string)indWinId,NegLPad(t.Linear().Open.Now,3)+" "+NegLPad(t.Linear().Open.Max,3)+" "+
                  NegLPad(t.Linear().Open.Min,3),Color(t.Linear().Open.Direction),12);
    UpdateDirection("tmaLinearBiasOpen"+(string)indWinId,Direction(t.Linear().Open.Bias,InAction),Color(Direction(t.Linear().Open.Bias,InAction)),18);
    UpdateLabel("tmaLinearStateClose"+(string)indWinId,NegLPad(t.Linear().Close.Now,3)+" "+NegLPad(t.Linear().Close.Max,3)+" "+
                  NegLPad(t.Linear().Close.Min,3),Color(t.Linear().Close.Direction),12);
    UpdateDirection("tmaLinearBiasClose"+(string)indWinId,Direction(t.Linear().Close.Bias,InAction),Color(Direction(t.Linear().Close.Bias,InAction)),18);
    UpdateDirection("tmaLinearBiasNet"+(string)indWinId,Direction(t.Linear().Bias,InAction),Color(Direction(t.Linear().Bias,InAction)),24);

    //-- Fractal
    UpdateDirection("tmaFractalDir"+(string)indWinId,t.Fractal().Direction,Color(t.Fractal().Direction),18);
    UpdateLabel("tmaFractalState"+(string)indWinId,EnumToString(t.Fractal().Type)+" "+EnumToString(t.Fractal().State),Color(t.Fractal().Direction),12);
    UpdateDirection("tmaFractalBias"+(string)indWinId,Direction(t.Fractal().Bias,InAction),Color(Direction(t.Fractal().Bias,InAction)),18);

    //-- Fractal Bounds
    if (inpFractalBounds)
    {
      UpdateRay("tmaPlanSup:"+(string)indWinId,t.Range().Support,inpPeriods-1);
      UpdateRay("tmaPlanRes:"+(string)indWinId,t.Range().Resistance,inpPeriods-1);
      UpdateRay("tmaRangeMid:"+(string)indWinId,t.Range().Mean,inpPeriods-1);
      UpdateRay("tmaClose:"+(string)indWinId,Close[0],inpPeriods-1);
    }

    //-- Fractal Rulers
    if (inpFractalRulers)
    {
      if (t[NewSegment]) indSegHist++;
      
      for (int bar=0;bar<inpPeriods;bar++)
      {
        ObjectSetText("tmaFrHi:"+(string)indWinId+"-"+(string)bar,"-",9,"Stencil",BoolToInt(IsEqual(bar,indSegHist),clrWhite,clrRed));
        ObjectSetText("tmaFrLo:"+(string)indWinId+"-"+(string)bar,"-",9,"Stencil",BoolToInt(IsEqual(bar,indSegHist),clrWhite,clrRed));

        ObjectSet("tmaFrHi:"+(string)indWinId+"-"+(string)bar,OBJPROP_PRICE1,highbuffer+point(2));
        ObjectSet("tmaFrLo:"+(string)indWinId+"-"+(string)bar,OBJPROP_PRICE1,lowbuffer);

        ObjectSet("tmaFrHi:"+(string)indWinId+"-"+(string)bar,OBJPROP_TIME1,Time[bar]);
        ObjectSet("tmaFrLo:"+(string)indWinId+"-"+(string)bar,OBJPROP_TIME1,Time[bar]);
      }

      for (FractalType type=Origin;type<FractalTypes;type++)
      {
        if (type<=t.Fractal().High.Type)
          ObjectSetText("tmaFrHi:"+(string)indWinId+"-"+(string)t.Fractal().High.Bar[type],FractalTag[type],9,"Stencil",
            BoolToInt(IsEqual(t.Fractal().High.Bar[type],t.Find(t.Fractal().Resistance[3],t.SMA().High)),clrGoldenrod,clrRed));

        if (type<=t.Fractal().Low.Type)
          ObjectSetText("tmaFrLo:"+(string)indWinId+"-"+(string)t.Fractal().Low.Bar[type],FractalTag[type],9,"Stencil",
            BoolToInt(IsEqual(t.Fractal().Low.Bar[type],t.Find(t.Fractal().Support[3],t.SMA().Low)),clrGoldenrod,clrRed));
      }
    }

    //-- General
    UpdateLabel("Clock",TimeToStr(TimeCurrent()),clrDodgerBlue,16);
    UpdateLabel("Price",Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);

    string text   = "";

    if (t.ActiveEvent())
      text        = t.ActiveEventStr();

    Append(text,"Supports:","\n");
    for (int i=0;i<4;i++)
      Append(text,DoubleToStr(t.Fractal().Support[i],Digits));

    Append(text,"Resistances:","\n");
    for (int i=0;i<4;i++)
      Append(text,DoubleToStr(t.Fractal().Resistance[i],Digits));

    if (inpShowComment)
      Comment(text);
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
//| UpdateTickMA - refreshes indicator data                          |
//+------------------------------------------------------------------+
void UpdateTickMA(void)
  {
    t.Update();

    if (t[NewBoundary])
      UpdatePriceLabel("tmaNewBoundary",Close[0],Color(BoolToInt(t[NewHigh],DirectionUp,DirectionDown),IN_DARK_DIR));

    SetIndexStyle(8,DRAW_LINE,STYLE_SOLID,1,Color(t.Linear().Direction,IN_CHART_DIR));
    SetIndexStyle(9,DRAW_LINE,STYLE_DASH,1,Color(t.Range().Direction,IN_CHART_DIR));

    ResetBuffer(plSMAOpenBuffer,t.SMA().Open);
    ResetBuffer(plSMACloseBuffer,t.SMA().Close);
    ResetBuffer(plSMAHighBuffer,t.SMA().High);
    ResetBuffer(plSMALowBuffer,t.SMA().Low);

    ResetBuffer(plPolyOpenBuffer,t.Poly().Open);
    ResetBuffer(plPolyCloseBuffer,t.Poly().Close);
    ResetBuffer(plLineOpenBuffer,t.Linear().Open.Price);
    ResetBuffer(plLineCloseBuffer,t.Linear().Close.Price);
  }

//+------------------------------------------------------------------+
//| UpdateNode - Repaints Node Bars                                  |
//+------------------------------------------------------------------+
void UpdateNode(string NodeName, int Node, double Price1, double Price2)
  {
    ObjectSet(NodeName+(string)Node,OBJPROP_COLOR,Color(t.Segment(Node).Close-t.Segment(Node).Open));
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
    highbuffer     = t.Range().High;
    lowbuffer      = t.Range().Low;

    if (t[NewSegment])
    {
      ArrayInitialize(plHighBuffer,0.00);
      ArrayInitialize(plLowBuffer,0.00);
    }

    for (int node=0;node<inpPeriods;node++)
    {
      UpdateNode("tmaHL:"+(string)indWinId+"-",node,t.Segment(node).High,t.Segment(node).Low);
      UpdateNode("tmaOC:"+(string)indWinId+"-",node,t.Segment(node).Open,t.Segment(node).Close);

      highbuffer   = fmax(highbuffer,plSMAHighBuffer[node]);
      highbuffer   = fmax(highbuffer,plSMALowBuffer[node]);
      highbuffer   = fmax(highbuffer,plPolyOpenBuffer[node]);
      highbuffer   = fmax(highbuffer,plPolyCloseBuffer[node]);
      highbuffer   = fmax(highbuffer,plLineOpenBuffer[node]);
      highbuffer   = fmax(highbuffer,plLineCloseBuffer[node]);

      lowbuffer    = fmin(lowbuffer,plSMAHighBuffer[node]);
      lowbuffer    = fmin(lowbuffer,plSMALowBuffer[node]);
      lowbuffer    = fmin(lowbuffer,plPolyOpenBuffer[node]);
      lowbuffer    = fmin(lowbuffer,plPolyCloseBuffer[node]);
      lowbuffer    = fmin(lowbuffer,plLineOpenBuffer[node]);
      lowbuffer    = fmin(lowbuffer,plLineCloseBuffer[node]);
      }

    plHighBuffer[0]        = fmax(highbuffer,t.Range().High)+point(2);
    plLowBuffer[0]         = fmin(lowbuffer,t.Range().Low);
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
    IndicatorShortName(indSN);
    indWinId = ChartWindowFind(0,indSN);

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

    SetIndexLabel (0,""); 
    SetIndexLabel (1,""); 
//    SetIndexLabel (2,"");
//    SetIndexLabel (3,"");
//    SetIndexLabel (4,""); 
//    SetIndexLabel (5,"");
    SetIndexLabel (6,""); 
    SetIndexLabel (7,""); 
    SetIndexLabel (8,""); 
    SetIndexLabel (9,""); 

    //--- Create Display Visuals
    for (int obj=0;obj<inpPeriods;obj++)
    {
      ObjectCreate("tmaFrHi:"+(string)indWinId+"-"+(string)obj,OBJ_TEXT,indWinId,0,0);
      ObjectCreate("tmaFrLo:"+(string)indWinId+"-"+(string)obj,OBJ_TEXT,indWinId,0,0);

      ObjectCreate("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJ_TREND,indWinId,0,0);
      ObjectSet("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJPROP_WIDTH,1);

      ObjectCreate("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJ_TREND,indWinId,0,0);
      ObjectSet("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJPROP_WIDTH,3);
    }

    //--- Indicator Rays
    NewRay("tmaRangeMid:"+(string)indWinId,STYLE_DOT,clrDarkGray,false,indWinId);
    NewRay("tmaPlanSup:"+(string)indWinId,STYLE_DOT,clrRed,false,indWinId);
    NewRay("tmaPlanRes:"+(string)indWinId,STYLE_DOT,clrLawnGreen,false,indWinId);
    NewRay("tmaClose:"+(string)indWinId,STYLE_SOLID,clrDarkGray,false,indWinId);

    if (inpSegBounds)
    {
      NewPriceLabel("tmaPL(sp):"+(string)indWinId,0.00,false,indWinId);
      NewPriceLabel("tmaPL(rs):"+(string)indWinId,0.00,false,indWinId);
      NewPriceLabel("tmaPL(e):"+(string)indWinId,0.00,false,indWinId);
    }

    NewLabel("tmaRangeState"+(string)indWinId,"",32,2,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaPolyBias"+(string)indWinId,"",5,0,clrDarkGray,SCREEN_UR,indWinId);

    NewLabel("tmaSegmentState"+(string)indWinId,"",32,20,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentBias"+(string)indWinId,"",5,16,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentTerm"+(string)indWinId,"",215,16,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentTrend"+(string)indWinId,"",205,12,clrDarkGray,SCREEN_UR,indWinId);

    NewLabel("tmaSMAState"+(string)indWinId,"",32,38,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMABias"+(string)indWinId,"",5,34,clrDarkGray,SCREEN_UR,indWinId);

    NewLabel("tmaSMATermHi"+(string)indWinId,"",215,52,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMATrendHi"+(string)indWinId,"",205,48,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMAStateHi"+(string)indWinId,"",72,56,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMAMomentumHi"+(string)indWinId,"-9.999",32,59,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMABiasHi"+(string)indWinId,"",5,52,clrDarkGray,SCREEN_UR,indWinId);

    NewLabel("tmaSMATermLo"+(string)indWinId,"",215,70,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMATrendLo"+(string)indWinId,"",205,66,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMAStateLo"+(string)indWinId,"",72,74,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMAMomentumLo"+(string)indWinId,"-9.999",32,76,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMABiasLo"+(string)indWinId,"",5,70,clrDarkGray,SCREEN_UR,indWinId);

    NewLabel("tmaLinearBiasNet"+(string)indWinId,"",210,96,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearStateOpen"+(string)indWinId,"",32,92,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearBiasOpen"+(string)indWinId,"",5,88,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearStateClose"+(string)indWinId,"",32,110,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearBiasClose"+(string)indWinId,"",5,106,clrDarkGray,SCREEN_UR,indWinId);

    NewLabel("tmaFractalDir"+(string)indWinId,"",215,124,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalState"+(string)indWinId,"",32,128,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalBias"+(string)indWinId,"",5,124,clrDarkGray,SCREEN_UR,indWinId);

    NewLabel("Clock","",10,5,clrDarkGray,SCREEN_LR,indWinId);
    NewLabel("Price","",10,30,clrDarkGray,SCREEN_LR,indWinId);

    NewPriceLabel("tmaNewBoundary");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
  }