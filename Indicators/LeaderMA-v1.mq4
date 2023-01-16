//+------------------------------------------------------------------+
//|                                                  LeaderMA-v1.mq4 |
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

#include <Class\Leader.mqh>
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
input int          inpPeriods        =  80;         // Retention
input int          inpDegree         =   6;         // Poiy Regression Degree
input double       inpAgg            = 2.5;         // Tick Aggregation
input bool         inpShowComment    = true;        // Display Comments
input bool         inpSegBounds      = true;        // Show Segment Bounds
input bool         inpFractalBounds  = true;        // Show Fractal Bounds
input bool         inpFractalRulers  = true;        // Show Fractal Rulers

//--- Indicator defs
string         ShortName          = "LeaderMA-v1: "+(string)inpPeriods+":"+(string)inpDegree+":"+(string)inpAgg;
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
CLeader       *t                 = new CLeader(inpPeriods,inpDegree,inpAgg);

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
      UpdatePriceLabel("tmaPL(sp):"+(string)IndWinId,t.Fractal().Support,clrRed);
      UpdatePriceLabel("tmaPL(rs):"+(string)IndWinId,t.Fractal().Resistance,clrLawnGreen);
      UpdatePriceLabel("tmaPL(e):"+(string)IndWinId,t.Fractal().Expansion,clrGoldenrod);
    }

    //-- Range/Poly
    UpdateLabel("tmaRangeState"+(string)IndWinId,EnumToString(t.Range().State)+
                  BoolToStr(debug," ["+string(t.Count(Ticks)-1)+":"+string(t.Count(Segments)-1)+"]")+" Age ["+(string)t.Range().Age+"]",
                  Color(Direction(t.Range().Direction)),12);
    UpdateDirection("tmaPolyBias"+(string)IndWinId,t.Poly().Direction,Color(Direction(t.Poly().Bias,InAction)),18);

    //-- Segment
    UpdateDirection("tmaSegmentTerm"+(string)IndWinId,t.Segment().Direction[Term],Color(t.Segment().Direction[Term]),18);
    UpdateDirection("tmaSegmentTrend"+(string)IndWinId,t.Segment().Direction[Trend],Color(t.Segment().Direction[Trend]),10,Narrow);
    UpdateLabel("tmaSegmentState"+(string)IndWinId,proper(DirText(t.Segment().Direction[Term]))+" ["+(string)t.Segment().Count+"]: "+
                  proper(ActionText(Action(t.Segment().Direction[Lead]))),Color(t.Segment().Direction[Term]),12);
    UpdateDirection("tmaSegmentBias"+(string)IndWinId,t.Segment().Direction[Lead],Color(Direction(t.Segment().Bias,InAction)),18);

    //-- Net Bias
    UpdateLabel("tmaSMAState"+(string)IndWinId,BoolToStr(IsEqual(t.SMA().Event,NoEvent),
                  proper(DirText(t.SMA().Direction))+" "+EnumToString(t.SMA().State),EventText[t.SMA().Event]),Color(t.SMA().Direction),12);
    UpdateDirection("tmaSMABias"+(string)IndWinId,t.SMA().Direction/*Lead*/,Color(Direction(t.SMA().Bias,InAction)),18);

    //-- High Bias
    UpdateDirection("tmaSMATermHi"+(string)IndWinId,t.Fractal().High.Direction[Term],Color(t.Fractal().High.Direction[Term]),18);
    UpdateDirection("tmaSMATrendHi"+(string)IndWinId,t.Fractal().High.Direction[Trend],Color(t.Fractal().High.Direction[Trend]),10,Narrow);
    UpdateLabel("tmaSMAStateHi"+(string)IndWinId,proper(DirText(t.Direction(t.SMA().High)))+" "+FractalTag[t.Fractal().High.Type]+" "+
                  BoolToStr(Close[0]>t.SMA().High[0],"Hold",BoolToStr(Close[0]>t.SMA().Close[0],"Rally","Pullback")),Color(t.Direction(t.SMA().High)),12);
    UpdateDirection("tmaSMABiasHi"+(string)IndWinId,t.Direction(t.SMA().High),Color(t.Direction(t.SMA().High)),18);

    //-- Low Bias
    UpdateDirection("tmaSMATermLo"+(string)IndWinId,t.Fractal().Low.Direction[Term],Color(t.Fractal().Low.Direction[Term]),18);
    UpdateDirection("tmaSMATrendLo"+(string)IndWinId,t.Fractal().Low.Direction[Trend],Color(t.Fractal().Low.Direction[Trend]),10,Narrow);
    UpdateLabel("tmaSMAStateLo"+(string)IndWinId,proper(DirText(t.Direction(t.SMA().Low)))+" "+FractalTag[t.Fractal().Low.Type]+" "+
                  BoolToStr(Close[0]<t.SMA().Low[0],"Hold",BoolToStr(Close[0]>t.SMA().Close[0],"Rally","Pullback")),Color(t.Direction(t.SMA().Low)),12);
    UpdateDirection("tmaSMABiasLo"+(string)IndWinId,t.Direction(t.SMA().Low),Color(t.Direction(t.SMA().Low)),18);

    //-- Linear
    UpdateLabel("tmaLinearStateOpen"+(string)IndWinId,NegLPad(t.Linear().Open.Now,Digits)+" "+NegLPad(t.Linear().Open.Max,Digits)+" "+
                  NegLPad(t.Linear().Open.Min,Digits),Color(t.Linear().Open.Direction),12);
    UpdateDirection("tmaLinearBiasOpen"+(string)IndWinId,Direction(t.Linear().Open.Bias,InAction),Color(Direction(t.Linear().Open.Bias,InAction)),18);
    UpdateLabel("tmaLinearStateClose"+(string)IndWinId,NegLPad(t.Linear().Close.Now,Digits)+" "+NegLPad(t.Linear().Close.Max,Digits)+" "+
                  NegLPad(t.Linear().Close.Min,Digits),Color(t.Linear().Close.Direction),12);
    UpdateDirection("tmaLinearBiasClose"+(string)IndWinId,Direction(t.Linear().Close.Bias,InAction),Color(Direction(t.Linear().Close.Bias,InAction)),18);
    UpdateDirection("tmaLinearBiasNet"+(string)IndWinId,Direction(t.Linear().Bias,InAction),Color(Direction(t.Linear().Bias,InAction)),24);
    
    //-- Fractal
    UpdateDirection("tmaFractalDir"+(string)IndWinId,t.Fractal().Direction,Color(t.Fractal().Direction),18);
    UpdateLabel("tmaFractalState"+(string)IndWinId,EnumToString(t.Fractal().Type)+" "+EnumToString(t.Fractal().State),Color(t.Fractal().Direction),12);
    UpdateDirection("tmaFractalBias"+(string)IndWinId,Direction(t.Fractal().Bias,InAction),Color(Direction(t.Fractal().Bias,InAction)),18);
//
//    //-- Fractal Bounds
    if (inpFractalBounds)
    {
      UpdateRay("tmaPlanSup:"+(string)IndWinId,t.Range().Support,inpPeriods-1);
      UpdateRay("tmaPlanRes:"+(string)IndWinId,t.Range().Resistance,inpPeriods-1);
      UpdateRay("tmaRangeMid:"+(string)IndWinId,t.Range().Mean,inpPeriods-1);
      UpdateRay("tmaClose:"+(string)IndWinId,Close[0],inpPeriods-1);
    }

    //-- Fractal Rulers
    if (inpFractalRulers)
    {
      for (int bar=0;bar<inpPeriods;bar++)
      {
        ObjectSetText("tmaFrHi:"+(string)IndWinId+"-"+(string)bar,"-",9,"Stencil",clrRed);
        ObjectSetText("tmaFrLo:"+(string)IndWinId+"-"+(string)bar,"-",9,"Stencil",clrRed);

        ObjectSet("tmaFrHi:"+(string)IndWinId+"-"+(string)bar,OBJPROP_PRICE1,highbuffer+point(2));
        ObjectSet("tmaFrLo:"+(string)IndWinId+"-"+(string)bar,OBJPROP_PRICE1,lowbuffer);

        ObjectSet("tmaFrHi:"+(string)IndWinId+"-"+(string)bar,OBJPROP_TIME1,Time[bar]);
        ObjectSet("tmaFrLo:"+(string)IndWinId+"-"+(string)bar,OBJPROP_TIME1,Time[bar]);
      }

      for (FractalType type=Origin;type<FractalTypes;type++)
      {
        if (type<=t.Fractal().High.Type)
          ObjectSetText("tmaFrHi:"+(string)IndWinId+"-"+(string)t.Fractal().High.Bar[type],FractalTag[type],9,"Stencil",clrRed);

        if (type<=t.Fractal().Low.Type)
          ObjectSetText("tmaFrLo:"+(string)IndWinId+"-"+(string)t.Fractal().Low.Bar[type],FractalTag[type],9,"Stencil",clrRed);
      }
    }

    //-- General
    UpdateLabel("Clock",TimeToStr(Time[0]),clrDodgerBlue,16);
    UpdateLabel("Price",Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);

//    string text   = "";
//
//    if (t.ActiveEvent())
//      text        = t.ActiveEventStr();
//
//    if (inpShowComment)
//      Comment(text);
  }

//+------------------------------------------------------------------+
//| ResetBuffer - Reset Buffer on bar change                         |
//+------------------------------------------------------------------+
void ResetBuffer(double &Buffer[], double &Source[])
  {
    ArrayInitialize(Buffer,0.00);
    ArrayCopy(Buffer,Source,0,0,fmin(t.Count(Leaders),inpPeriods));
  }

//+------------------------------------------------------------------+
//| UpdateLeader - refreshes indicator data                          |
//+------------------------------------------------------------------+
void UpdateLeader(void)
  {
    t.Update();

//    if (t[NewBoundary])
//      UpdatePriceLabel("tmaNewBoundary",Close[0],Color(BoolToInt(t[NewHigh],DirectionUp,DirectionDown),IN_DARK_DIR));
//
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
    ObjectSet(NodeName+(string)Node,OBJPROP_COLOR,Color(t.Leader().Close[Node]-t.Leader().Open[Node]));
    ObjectSet(NodeName+(string)Node,OBJPROP_PRICE1,Price1);
    ObjectSet(NodeName+(string)Node,OBJPROP_PRICE2,Price2);
    ObjectSet(NodeName+(string)Node,OBJPROP_TIME1,Time[Node]);
    ObjectSet(NodeName+(string)Node,OBJPROP_TIME2,Time[Node]);
  }

//+------------------------------------------------------------------+
//| UpdateSegment - Repaints visuals                                 |
//+------------------------------------------------------------------+
void UpdateSegment(bool NewBar=false)
  {
    if (NewBar||t[NewLeader])
    {
      highbuffer     = t.Range().High;
      lowbuffer      = t.Range().Low;

      for (int node=0;node<fmin(t.Count(Leaders),inpPeriods);node++)
      {
        UpdateNode("tmaHL:"+(string)IndWinId+"-",node,t.Leader().High[node],t.Leader().Low[node]);
        UpdateNode("tmaOC:"+(string)IndWinId+"-",node,t.Leader().Open[node],t.Leader().Close[node]);

        highbuffer   = fmax(highbuffer,t.Leader().High[node]);
        highbuffer   = fmax(highbuffer,plSMAHighBuffer[node]);
        highbuffer   = fmax(highbuffer,plPolyOpenBuffer[node]);
        highbuffer   = fmax(highbuffer,plPolyCloseBuffer[node]);
        highbuffer   = fmax(highbuffer,plLineOpenBuffer[node]);
        highbuffer   = fmax(highbuffer,plLineCloseBuffer[node]);
   
        lowbuffer    = fmin(lowbuffer,BoolToDouble(t.Leader().Low[node]>0.00,t.Leader().Low[node],lowbuffer,Digits));
        lowbuffer    = fmin(lowbuffer,BoolToDouble(plSMALowBuffer[node]>0.00,plSMALowBuffer[node],lowbuffer,Digits));
        lowbuffer    = fmin(lowbuffer,BoolToDouble(plPolyOpenBuffer[node]>0.00,plPolyOpenBuffer[node],lowbuffer,Digits));
        lowbuffer    = fmin(lowbuffer,BoolToDouble(plPolyCloseBuffer[node]>0.00,plPolyCloseBuffer[node],lowbuffer,Digits));
        lowbuffer    = fmin(lowbuffer,BoolToDouble(plLineOpenBuffer[node]>0.00,plLineOpenBuffer[node],lowbuffer,Digits));
        lowbuffer    = fmin(lowbuffer,BoolToDouble(plLineCloseBuffer[node]>0.00,plLineCloseBuffer[node],lowbuffer,Digits));
      }
    }
    else
    {
      UpdateNode("tmaHL:"+(string)IndWinId+"-",0,t.Leader().High[0],t.Leader().Low[0]);
      UpdateNode("tmaOC:"+(string)IndWinId+"-",0,t.Leader().Open[0],t.Leader().Close[0]);
    }

    ArrayInitialize(plHighBuffer,highbuffer+point(2));
    ArrayInitialize(plLowBuffer,lowbuffer);
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
    UpdateLeader();
    UpdateSegment(rates_total!=prev_calculated);

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

    SetIndexLabel (0,""); 
    SetIndexLabel (1,""); 
    SetIndexLabel (2,""); 
//    SetIndexLabel (3,""); 
//    SetIndexLabel (4,""); 
    SetIndexLabel (5,""); 
    SetIndexLabel (6,""); 
    SetIndexLabel (7,""); 
    SetIndexLabel (8,""); 
    SetIndexLabel (9,""); 

    //--- Create Display Visuals
    for (int obj=0;obj<inpPeriods;obj++)
    {
      ObjectCreate("tmaFrHi:"+(string)IndWinId+"-"+(string)obj,OBJ_TEXT,IndWinId,0,0);
      ObjectCreate("tmaFrLo:"+(string)IndWinId+"-"+(string)obj,OBJ_TEXT,IndWinId,0,0);

      ObjectDelete("tmaHL:"+(string)IndWinId+"-"+(string)obj);
      ObjectCreate("tmaHL:"+(string)IndWinId+"-"+(string)obj,OBJ_TREND,IndWinId,0,0);
      ObjectSet("tmaHL:"+(string)IndWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaHL:"+(string)IndWinId+"-"+(string)obj,OBJPROP_WIDTH,1);

      ObjectDelete("tmaOC:"+(string)IndWinId+"-"+(string)obj);
      ObjectCreate("tmaOC:"+(string)IndWinId+"-"+(string)obj,OBJ_TREND,IndWinId,0,0);
      ObjectSet("tmaOC:"+(string)IndWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaOC:"+(string)IndWinId+"-"+(string)obj,OBJPROP_WIDTH,3);
    }

    //--- Indicator Rays
    NewRay("tmaRangeMid:"+(string)IndWinId,STYLE_DOT,clrDarkGray,false,IndWinId);
    NewRay("tmaPlanSup:"+(string)IndWinId,STYLE_DOT,clrRed,false,IndWinId);
    NewRay("tmaPlanRes:"+(string)IndWinId,STYLE_DOT,clrLawnGreen,false,IndWinId);
    NewRay("tmaClose:"+(string)IndWinId,STYLE_SOLID,clrDarkGray,false,IndWinId);

    if (inpSegBounds)
    {
      NewPriceLabel("tmaPL(sp):"+(string)IndWinId,0.00,false,IndWinId);
      NewPriceLabel("tmaPL(rs):"+(string)IndWinId,0.00,false,IndWinId);
      NewPriceLabel("tmaPL(e):"+(string)IndWinId,0.00,false,IndWinId);
    }

    NewLabel("tmaRangeState"+(string)IndWinId,"",32,2,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaPolyBias"+(string)IndWinId,"",5,0,clrDarkGray,SCREEN_UR,IndWinId);

    NewLabel("tmaSegmentState"+(string)IndWinId,"",32,20,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSegmentBias"+(string)IndWinId,"",5,16,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSegmentTerm"+(string)IndWinId,"",215,16,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSegmentTrend"+(string)IndWinId,"",205,12,clrDarkGray,SCREEN_UR,IndWinId);

    NewLabel("tmaSMAState"+(string)IndWinId,"",32,38,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMABias"+(string)IndWinId,"",5,34,clrDarkGray,SCREEN_UR,IndWinId);

    NewLabel("tmaSMATermHi"+(string)IndWinId,"",215,52,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMATrendHi"+(string)IndWinId,"",205,48,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMAStateHi"+(string)IndWinId,"",32,56,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMABiasHi"+(string)IndWinId,"",5,52,clrDarkGray,SCREEN_UR,IndWinId);

    NewLabel("tmaSMATermLo"+(string)IndWinId,"",215,70,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMATrendLo"+(string)IndWinId,"",205,66,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMAStateLo"+(string)IndWinId,"",32,74,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMABiasLo"+(string)IndWinId,"",5,70,clrDarkGray,SCREEN_UR,IndWinId);

    NewLabel("tmaLinearBiasNet"+(string)IndWinId,"",210,96,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearStateOpen"+(string)IndWinId,"",32,92,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearBiasOpen"+(string)IndWinId,"",5,88,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearStateClose"+(string)IndWinId,"",32,110,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearBiasClose"+(string)IndWinId,"",5,106,clrDarkGray,SCREEN_UR,IndWinId);

    NewLabel("tmaFractalDir"+(string)IndWinId,"",215,124,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaFractalState"+(string)IndWinId,"",32,128,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaFractalBias"+(string)IndWinId,"",5,124,clrDarkGray,SCREEN_UR,IndWinId);

    NewLabel("Clock","",10,5,clrDarkGray,SCREEN_LR,IndWinId);
    NewLabel("Price","",10,30,clrDarkGray,SCREEN_LR,IndWinId);

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