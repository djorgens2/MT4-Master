//+------------------------------------------------------------------+
//|                                                    TickMA-v1.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.07"
#property strict
#property indicator_separate_window
#property indicator_buffers 11
#property indicator_plots   11

#include <Class\TickMA.mqh>

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
#property indicator_style9 STYLE_SOLID
#property indicator_width9 1

//--- plot plCloseLine
#property indicator_label10 "plCloseLine"
#property indicator_type10  DRAW_SECTION
#property indicator_style10 STYLE_DASH
#property indicator_width10 1

//--- plot plFractalLine
#property indicator_label11 "plFractalLine"
#property indicator_type11  DRAW_SECTION
#property indicator_color11 clrDodgerBlue
#property indicator_style11 STYLE_SOLID
#property indicator_width11 2

//--- input parameters
input int       inpPeriods        =  80;         // Retention
input int       inpDegree         =   6;         // Poiy Regression Degree
input double    inpAgg            = 2.5;         // Tick Aggregation
input bool      inpShowComment    = false;        // Display Comments
input bool      inpSegBounds      = true;        // Show Segment Bounds
input bool      inpFractalBounds  = true;        // Show Fractal Bounds
input bool      inpFractalRulers  = true;        // Show Fractal Rulers

//--- Indicator defs
string         indSN              = "TickMA-v1: "+(string)inpPeriods+":"+(string)inpDegree+":"+(string)inpAgg;
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
double         plFractalBuffer[];

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
      UpdatePriceLabel("tmaPL(sp):"+(string)indWinId,t.Pivot().Support,clrRed);
      UpdatePriceLabel("tmaPL(rs):"+(string)indWinId,t.Pivot().Resistance,clrLawnGreen);
      UpdatePriceLabel("tmaPL(ex):"+(string)indWinId,t.Pivot().Active,clrGoldenrod);
    }

    //-- Fractal
    UpdateDirection("tmaFractalTrendDir"+(string)indWinId,t.Fractal().Direction,Color(t.Fractal().Direction),16);
    UpdateDirection("tmaFractalTermDir"+(string)indWinId,t[t.Fractal().Type].Direction,Color(t[t.Fractal().Type].Direction),32);
    UpdateLabel("tmaFractalTrendState"+(string)indWinId,center(EnumToString(t.Fractal().State),12),Color(t.Fractal().Direction),16);
    UpdateLabel("tmaFractalTermState"+(string)indWinId,center(EnumToString(t.Fractal().Type)+" "+EnumToString(t[t.Fractal().Type].State),24),Color(Direction(t[t.Fractal().Type].Bias,InAction)),12);
    UpdateDirection("tmaFractalTrendBias"+(string)indWinId,Direction(t.Fractal().Bias,InAction),Color(Direction(t.Fractal().Bias,InAction)),18);
    UpdateDirection("tmaFractalTermBias"+(string)indWinId,Direction(t[t.Fractal().Type].Bias,InAction),Color(Direction(t[t.Fractal().Type].Bias,InAction)),18);

    //-- Linear Box
    UpdateDirection("tmaLinearBias"+(string)indWinId,Direction(t.Linear().Bias,InAction),Color(Direction(t.Linear().Bias,InAction)),32);
    UpdateDirection("tmaLinearDir"+(string)indWinId,t.Linear().Direction,Color(t.Linear().Direction),16);
    UpdateLabel("tmaLinearStateOpen"+(string)indWinId,lpad(t.Linear().Open.Now,3)+" "+lpad(t.Linear().Open.Max,3)+" "+
                  lpad(t.Linear().Open.Min,3),Color(t.Linear().Open.Direction),12);
    UpdateDirection("tmaLinearBiasOpen"+(string)indWinId,Direction(t.Linear().Open.Bias,InAction),Color(Direction(t.Linear().Open.Bias,InAction)),18);
    UpdateLabel("tmaLinearStateClose"+(string)indWinId,lpad(t.Linear().Close.Now,3)+" "+lpad(t.Linear().Close.Max,3)+" "+
                  lpad(t.Linear().Close.Min,3),Color(t.Linear().Close.Direction),12);
    UpdateDirection("tmaLinearBiasClose"+(string)indWinId,Direction(t.Linear().Close.Bias,InAction),Color(Direction(t.Linear().Close.Bias,InAction)),18);

    //-- SMA Box
    UpdateDirection("tmaSMABias"+(string)indWinId,Direction(t.SMA().Bias,InAction)/*Lead*/,Color(Direction(t.SMA().Bias,InAction)),32);
    UpdateDirection("tmaSMADir"+(string)indWinId,t.SMA().Direction/*Lead*/,Color(t.SMA().Direction),16);
    UpdateLabel("tmaSMAState"+(string)indWinId,center(BoolToStr(IsEqual(t.SMA().Event,NoEvent),
                  proper(DirText(t.SMA().Direction))+" "+EnumToString(t.SMA().State),EventText(t.SMA().Event)),16),
                  Color(Direction(t.SMA().Close[0]-t.SMA().Open[0])),12);
    UpdateLabel("tmaSMAMomentumHi"+(string)indWinId,DoubleToStr(pip(t.Momentum().High.Now),1),
                  Color(Direction(t.Momentum().High.Bias,InAction),IN_CHART_DIR),12);
    UpdateDirection("tmaSMABiasHi"+(string)indWinId,t.Direction(t.SMA().High),Color(t.Direction(t.SMA().High)),18);
    UpdateLabel("tmaSMAMomentumLo"+(string)indWinId,DoubleToStr(pip(t.Momentum().Low.Now),1),
                  Color(Direction(t.Momentum().Low.Bias,InAction),IN_CHART_DIR),12);
    UpdateDirection("tmaSMABiasLo"+(string)indWinId,t.Direction(t.SMA().Low),Color(t.Direction(t.SMA().Low)),18);

    //-- Segment/Tick Box
    UpdateDirection("tmaSegmentTerm"+(string)indWinId,t.Segment().Direction[Term],Color(t.Segment().Direction[Term]),32);
    UpdateDirection("tmaSegmentTrend"+(string)indWinId,t.Segment().Direction[Trend],Color(t.Segment().Direction[Trend]),16);
    UpdateLabel("tmaTickState"+(string)indWinId,proper(DirText(t.Segment().Direction[Lead]))+" ["+(string)t.Segment().Count+"]: "+
                  proper(ActionText(Action(t.Segment().Direction[Lead]))),Color(t.Segment().Direction[Lead]),12);
    UpdateDirection("tmaTickBias"+(string)indWinId,t.Segment().Direction[Lead],Color(Direction(t.Tick().Close-t.Tick().Open)),18);
    UpdateLabel("tmaSegmentState"+(string)indWinId,proper(DirText(t.Segment().Direction[Term]))+" "+
                  BoolToStr(IsBetween(t.Pivot().Active,t.Pivot().Support,t.Pivot().Resistance),
                  BoolToStr(IsEqual(t.Segment().Direction[Term],t.Segment().Direction[Trend]),
                      "Conforming: "+proper(ActionText(Action(t.Segment().Direction[Term]))),
                      "Contrarian: "+proper(ActionText(Action(t.Segment().Direction[Term],InDirection,InContrarian)))),
                      "Breakout: "+proper(ActionText(Action(t.Segment().Direction[Term])))),
                  Color(t.Segment().Direction[Term]),12);
    UpdateDirection("tmaSegmentBias"+(string)indWinId,t.Segment().Direction[Lead],Color(Direction(t.Segment().Bias,InAction)),18);

    //-- Fractal Bounds
    if (inpFractalBounds)
    {
      UpdateRay("tmaPlanSup:"+(string)indWinId,inpPeriods-1,t.Range().Support);
      UpdateRay("tmaPlanRes:"+(string)indWinId,inpPeriods-1,t.Range().Resistance);
      UpdateRay("tmaRangeMid:"+(string)indWinId,inpPeriods-1,t.Range().Mean);
      UpdateRay("tmaClose:"+(string)indWinId,inpPeriods-1,Close[0]);
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
        if (t.Fractal().High[type].Bar>NoValue)
          ObjectSetText("tmaFrHi:"+(string)indWinId+"-"+(string)t.Fractal().High[type].Bar,FractalTag[type],9,"Stencil",clrRed);
            //BoolToInt(IsEqual(t.Fractal().High.Bar[type],t.Find(t.Fractal().Resistance[3],t.SMA().High)),clrGoldenrod,clrRed));

        if (t.Fractal().Low[type].Bar>NoValue)
          ObjectSetText("tmaFrLo:"+(string)indWinId+"-"+(string)t.Fractal().Low[type].Bar,FractalTag[type],9,"Stencil",clrRed);
            //BoolToInt(IsEqual(t.Fractal().Low.Bar[type],t.Find(t.Fractal().Support[3],t.SMA().Low)),clrGoldenrod,clrRed));
      }
    }

    if (t.Event(NewDirection,Major))
    {
      Flag("RR-ChkPt-Open",BoolToInt(t.Event(NewExpansion,Critical),Color(t[Expansion].Direction,IN_CHART_DIR),
                           BoolToInt(t.Event(AdverseEvent),clrMagenta,Color(t[Expansion].Direction,IN_DARK_DIR))));
      Arrow("RR-ChkPt-High:"+TimeToStr(TimeCurrent()),ArrowDash,clrYellow,0,t.Range().High);
      Arrow("RR-ChkPt-Low:"+TimeToStr(TimeCurrent()),ArrowDash,clrRed,0,t.Range().Low);
    }

    //-- General
    UpdateLabel("Clock",TimeToStr(TimeCurrent()),clrDodgerBlue,16);
    UpdateLabel("Price",Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);

    string text   = "";

    if (t.ActiveEvent())
      text        = t.ActiveEventStr();

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
//| ResetFractal - Reset Fractal on NewSegment                       |
//+------------------------------------------------------------------+
void ResetFractal(void)
  {
    ArrayInitialize(plFractalBuffer,0.00);
    
    for (FractalType type=Origin;type<FractalTypes;type++)
      if (t[type].Bar>NoValue)
        plFractalBuffer[t[type].Bar] = t[type].Price;
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

    ResetFractal();
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
    SetIndexBuffer(10,plFractalBuffer);

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
    SetIndexLabel (10,"");     

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

    for (FractalType type=Origin;type<FractalTypes;type++)
      NewRay("tma["+FractalTag[type]+"]:"+(string)indWinId,STYLE_SOLID,clrDarkGray,false,indWinId);

    if (inpSegBounds)
    {
      //--- Segment Boundaries
      NewPriceLabel("tmaPL(sp):"+(string)indWinId,0.00,false,indWinId);
      NewPriceLabel("tmaPL(rs):"+(string)indWinId,0.00,false,indWinId);
      NewPriceLabel("tmaPL(ex):"+(string)indWinId,0.00,false,indWinId);
      
      //--- Indicator Rays
      NewRay("tmaRangeMid:"+(string)indWinId,STYLE_DOT,clrDarkGray,false,indWinId);
      NewRay("tmaPlanSup:"+(string)indWinId,STYLE_DOT,clrRed,false,indWinId);
      NewRay("tmaPlanRes:"+(string)indWinId,STYLE_DOT,clrLawnGreen,false,indWinId);
      NewRay("tmaClose:"+(string)indWinId,STYLE_SOLID,clrDarkGray,false,indWinId);
    }

    //-- App Data Frames
    DrawBox("bxhFractalDir"+(string)indWinId,300,5,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhFractalState"+(string)indWinId,230,5,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhFOCDir"+(string)indWinId,300,70,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhFOCState"+(string)indWinId,230,70,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSMABias"+(string)indWinId,300,135,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSMAState"+(string)indWinId,230,135,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSegBias"+(string)indWinId,300,200,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSegState"+(string)indWinId,230,200,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);

    //-- Fractal Data
    NewLabel("tmaHFractal"+(string)indWinId,"Fractal",250,51,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTrendDir"+(string)indWinId,"",244,8,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTermDir"+(string)indWinId,"",250,12,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTrendState"+(string)indWinId,"",60,10,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTrendBias"+(string)indWinId,"",15,10,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTermState"+(string)indWinId,"",34,38,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTermBias"+(string)indWinId,"",15,35,clrDarkGray,SCREEN_UR,indWinId);

    //-- Linear Data
    NewLabel("tmaHLinear"+(string)indWinId,"Linear",252,116,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaLinearDir"+(string)indWinId,"",244,72,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearBias"+(string)indWinId,"",250,76,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearStateOpen"+(string)indWinId,"",40,78,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearBiasOpen"+(string)indWinId,"",15,75,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearStateClose"+(string)indWinId,"",40,104,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearBiasClose"+(string)indWinId,"",15,100,clrDarkGray,SCREEN_UR,indWinId);

    //-- SMA Data
    NewLabel("tmaHSMA"+(string)indWinId,"SMA",258,181,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaSMABias"+(string)indWinId,"",250,142,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMADir"+(string)indWinId,"",244,138,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMAState"+(string)indWinId,"",76,154,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMAMomentumHi"+(string)indWinId,"-9.999",40,142,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMABiasHi"+(string)indWinId,"",15,138,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMAMomentumLo"+(string)indWinId,"-9.999",40,166,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMABiasLo"+(string)indWinId,"",15,165,clrDarkGray,SCREEN_UR,indWinId);

    //-- Segment Data
    NewLabel("tmaHSegment"+(string)indWinId,"Segment",248,246,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentTerm"+(string)indWinId,"",250,207,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentTrend"+(string)indWinId,"",244,203,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaTickState"+(string)indWinId,"",40,208,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaTickBias"+(string)indWinId,"",15,205,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentState"+(string)indWinId,"",40,233,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentBias"+(string)indWinId,"",15,230,clrDarkGray,SCREEN_UR,indWinId);

    //-- Clock & Price
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