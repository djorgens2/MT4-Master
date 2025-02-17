//+------------------------------------------------------------------+
//|                                                    TickMA-v2.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.09"
#property strict
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   7

#include <Class/TickMA.mqh>

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

//--- plot plOpenLine
#property indicator_label7  "plTrendLine"
#property indicator_type7   DRAW_SECTION
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

enum ShowType
     {
       stNone   = NoValue,   // None
       stOrigin = Origin,    // Origin
       stTrend  = Trend,     // Trend
       stTerm   = Term       // Term
     };

//--- input parameters
input int          inpPeriods        = 80;          // Retention
input double       inpAgg            = 2.5;         // Tick Aggregation
input YesNoType    inpShowComment    = No;          // Display Comments
input ShowType     inpShowFibo       = stNone;      // Show Fractal Bounds
input ShowType     inpShowEvents     = stNone;      // Show Events

//--- Indicator defs
string         indObjectStr       = "[tv2]";
string         indSN              = "TickMA-v2";
int            indWinId           = NoValue;

//--- Indicator buffers
double         plHighBuffer[];
double         plLowBuffer[];
double         plSMAOpenBuffer[];
double         plSMACloseBuffer[];
double         plSMAHighBuffer[];
double         plSMALowBuffer[];
double         plLineBuffer[];

double         plSMAOpen[1];
double         plSMAClose[1];
double         plSMAHigh[1];
double         plSMALow[1];

//--- Class defs
CTickMA       *t                 = new CTickMA(inpPeriods,inpAgg,(FractalType)inpShowEvents);

//--- Operational Vars
FractalType    show;

double         highbuffer        = NoValue;
double         lowbuffer         = NoValue;

double crest[];
double trough[];

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static FractalType fractal  = Term;

    if (t[NewFibonacci])
      fractal                   = (FractalType)BoolToInt(t.Event(NewFibonacci,Critical),Origin,
                                             BoolToInt(t.Event(NewFibonacci,Major),Trend,Term));

    UpdatePriceLabel("tmaPL(sp):"+(string)indWinId,t.Pivot().Support,clrRed,-1);
    UpdatePriceLabel("tmaPL(rs):"+(string)indWinId,t.Pivot().Resistance,clrLawnGreen,-1);
    UpdatePriceLabel("tmaPL(ex):"+(string)indWinId,t.Pivot().Active,clrGoldenrod,-1);

    if (inpShowFibo>stNone)
    {
      UpdateRay(indObjectStr+"lnS_Origin:"+EnumToString(show),inpPeriods,t[show].Point[fpOrigin],-8);
      UpdateRay(indObjectStr+"lnS_Base:"+EnumToString(show),inpPeriods,t[show].Point[fpBase],-8);
      UpdateRay(indObjectStr+"lnS_Root:"+EnumToString(show),inpPeriods,t[show].Point[fpRoot],-8,0,
                             BoolToInt(IsEqual(t[show].Direction,DirectionUp),clrRed,clrLawnGreen));
      UpdateRay(indObjectStr+"lnS_Expansion:"+EnumToString(show),inpPeriods,t[show].Point[fpExpansion],-8,0,
                             BoolToInt(IsEqual(t[show].Direction,DirectionUp),clrLawnGreen,clrRed));
      UpdateRay(indObjectStr+"lnS_Retrace:"+EnumToString(show),inpPeriods,t[show].Point[fpRetrace],-8,0);
      UpdateRay(indObjectStr+"lnS_Recovery:"+EnumToString(show),inpPeriods,t[show].Point[fpRecovery],-8,0);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        UpdateRay(indObjectStr+"lnS_"+EnumToString(fibo)+":"+EnumToString(show),inpPeriods,t.Price(fibo,show,Extension),-8,0,Color(t[show].Direction,IN_DARK_DIR));
        UpdateText(indObjectStr+"lnT_"+EnumToString(fibo)+":"+EnumToString(show),"",t.Price(fibo,show,Extension),-5,Color(t[show].Direction,IN_DARK_DIR));
      }

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        UpdateText(indObjectStr+"lnT_"+fp[point]+":"+EnumToString(show),"",t[show].Point[point],-7);
    }

    //-- Fractal Box
    UpdateDirection("tmaFractalTrendDir"+(string)indWinId,t[Trend].Direction,Color(t[Trend].Direction),16);
    UpdateDirection("tmaFractalTermDir"+(string)indWinId,t[Term].Direction,Color(t[Term].Direction),32);
    UpdateLabel("tmaFractalTrendState"+(string)indWinId,rpad(EnumToString(t[Trend].State)," ",20),Color(t[Trend].Direction),12,"Noto Sans Mono CJK HK");
    UpdateLabel("tmaFractalPivot"+(string)indWinId,rpad(EnumToString(fractal)+" "+EnumToString(t[fractal].State)," ",20),Color(t[fractal].Direction),12,"Noto Sans Mono CJK HK");
    UpdateLabel("tmaFractalPivotRet"+(string)indWinId,StringSubstr(EnumToString(t[fractal].Retrace.Level),4,4),Color(Direction(t[fractal].Pivot.Lead,InAction)),10,"Noto Sans Mono CJK HK");
    UpdateLabel("tmaFractalPivotExt"+(string)indWinId,StringSubstr(EnumToString(t[fractal].Extension.Level),4),Color(Direction(t[fractal].Pivot.Bias,InAction)),10,"Noto Sans Mono CJK HK");
    UpdateDirection("tmaFractalPivotLead"+(string)indWinId,Direction(t[fractal].Pivot.Lead,InAction),Color(Direction(t[fractal].Pivot.Lead,InAction)),16);
    UpdateDirection("tmaFractalPivotBias"+(string)indWinId,Direction(t[fractal].Pivot.Bias,InAction),Color(Direction(t[fractal].Pivot.Bias,InAction)),16);

    //-- Linear Box
    UpdateDirection("tmaLinearBias"+(string)indWinId,Direction(t.Linear().Bias,InAction),Color(Direction(t.Linear().Bias,InAction)),32);
    UpdateDirection("tmaLinearDir"+(string)indWinId,t.Linear().Direction,Color(t.Linear().Direction),16);
    UpdateLabel("tmaLinearState"+(string)indWinId,rpad(DirText(t.Linear().Direction)+" "+EnumToString(t.Linear().State)," ",20),Color(t.Linear().Direction),12,"Noto Sans Mono CJK HK");
    UpdateLabel("tmaLinearFOC"+(string)indWinId,center(lpad(t.Linear().FOC[Now],3,8)+lpad(t.Linear().FOC[Max],3,8)+lpad(t.Linear().FOC[Min],3,8),24),Color(t.Linear().Direction),12,"Noto Sans Mono CJK HK");
    UpdateDirection("tmaLinearLeadDir"+(string)indWinId,Direction(t.Linear().Lead,InAction),Color(Direction(t.Linear().Lead,InAction)),16);
    UpdateDirection("tmaLinearBiasDir"+(string)indWinId,Direction(t.Linear().Bias,InAction),Color(Direction(t.Linear().Bias,InAction)),16);

    //-- SMA Box
    UpdateDirection("tmaSMABias"+(string)indWinId,Direction(t.SMA().Bias,InAction)/*Lead*/,Color(Direction(t.SMA().Bias,InAction)),32);
    UpdateDirection("tmaSMADir"+(string)indWinId,t.SMA().Direction/*Lead*/,Color(t.SMA().Direction),16);
    UpdateLabel("tmaSMAState"+(string)indWinId,rpad(BoolToStr(IsEqual(t.SMA().Event,NoEvent),
                  proper(DirText(t.SMA().Direction))+" "+EnumToString(t.SMA().State),EventText(t.SMA().Event))," ",20),
                  Color(Direction(t.SMA().Close[0]-t.SMA().Open[0])),12,"Noto Sans Mono CJK HK");
    UpdateDirection("tmaSMABiasHi"+(string)indWinId,t.Direction(t.SMA().High),Color(t.Direction(t.SMA().High)),16);
    UpdateDirection("tmaSMABiasLo"+(string)indWinId,t.Direction(t.SMA().Low),Color(t.Direction(t.SMA().Low)),16);

    //-- Segment/Tick Box
    UpdateDirection("tmaSegmentTerm"+(string)indWinId,t.Direction(Term),Color(t.Direction(Term)),32);
    UpdateDirection("tmaSegmentTrend"+(string)indWinId,t.Direction(Trend),Color(t.Direction(Trend)),16);
    UpdateLabel("tmaTickState"+(string)indWinId,rpad(BoolToStr(t.Tick().Direction==DirectionUp,"Uptick","Downtick")+
                " ["+(string)t.Segment().Count+"]"," ",20),Color(Direction(t.Tick().Lead,InAction)),12,"Noto Sans Mono CJK HK");
    UpdateDirection("tmaTickBias"+(string)indWinId,Direction(t.Tick().Lead,InAction),Color(Direction(t.Tick().Bias,InAction)),16);
    UpdateLabel("tmaSegmentState"+(string)indWinId,rpad(proper(DirText(t.Direction(Term)))+" "+
                  BoolToStr(IsBetween(t.Pivot().Active,t.Pivot().Support,t.Pivot().Resistance),
                  BoolToStr(IsEqual(t.Direction(Term),t.Direction(Trend)),
                      "Conforming "+proper(ActionText(Action(t.Direction(Term)))),
                      "Contrarian "+proper(ActionText(Action(t.Direction(Term),InDirection,InContrarian)))),
                      "Breakout "+proper(ActionText(Action(t.Direction(Term)))))," ",21),
                  Color(t.Segment().Direction),12,"Noto Sans Mono CJK HK");
    UpdateDirection("tmaSegmentBias"+(string)indWinId,t.Direction(Lead),Color(Direction(t.Segment().Bias,InAction)),16);

    //-- Range Bounds
    UpdateRay("tmaPlanSup:"+(string)indWinId,inpPeriods-1,t.Range().Support);
    UpdateRay("tmaPlanRes:"+(string)indWinId,inpPeriods-1,t.Range().Resistance);
    UpdateRay("tmaRangeMid:"+(string)indWinId,inpPeriods-1,t.Range().Mean);
    UpdateRay("tmaClose:"+(string)indWinId,inpPeriods-1,Close[0]);
 
    //-- General
    UpdateLabel("Clock",TimeToStr(TimeCurrent()),clrDodgerBlue,16);
    UpdateLabel("Price",Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);
    
    string text   = "\n";

    Append(text,t.DisplayStr());
    Append(text,t.ActiveEventStr(),"\n\n");

    if (inpShowComment==Yes)
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
    double smahi     = t.SMA().High[0];
    double smalo     = t.SMA().Low[0];
    int    cflat     = 0;
    int    tflat     = 0;

    t.Update();

    ArrayInitialize(crest,0.00);
    ArrayInitialize(trough,0.00);

    for (int node=2;node<fmin(t.Count(Segments),inpPeriods)-1;node++)
    {
      if (IsHigher(t.SMA().High[node],smahi))
        if (t.SMA().High[node]>t.SMA().High[node-1])
        {
          if (t.SMA().High[node]>t.SMA().High[node+1])
            crest[node]      = smahi;

          cflat              = BoolToInt(IsEqual(t.SMA().High[node],t.SMA().High[node+1]),node);
        }
        
      if (cflat>0)
        if (t.SMA().High[node]<t.SMA().High[cflat])
        {
          crest[cflat]       = smahi;
          UpdatePriceLabel("crest-"+(string)cflat,crest[cflat],clrGoldenrod,cflat);
        }

      if (IsLower(t.SMA().Low[node],smalo))
        if (t.SMA().Low[node]<t.SMA().Low[node-1])
        {
          if (t.SMA().Low[node]<t.SMA().Low[node+1])
            trough[node]     = smalo;

          tflat              = BoolToInt(IsEqual(t.SMA().Low[node],t.SMA().Low[node+1]),node);
        }

      if (tflat>0)
        if (t.SMA().Low[node]>t.SMA().Low[tflat])
        {
          trough[tflat]      = smalo;
          UpdatePriceLabel("trough-"+(string)tflat,trough[tflat],clrGoldenrod,tflat);
        }

      UpdatePriceLabel("trough-"+(string)node,trough[node],clrRed,node);
      UpdatePriceLabel("crest-"+(string)node,crest[node],clrYellow,node);
    }
    
    SetIndexStyle(6,DRAW_LINE,STYLE_SOLID,1,Color(t.Linear().Direction,IN_CHART_DIR));

    ResetBuffer(plSMAOpenBuffer,t.SMA().Open);
    ResetBuffer(plSMACloseBuffer,t.SMA().Close);
    ResetBuffer(plSMAHighBuffer,t.SMA().High);
    ResetBuffer(plSMALowBuffer,t.SMA().Low);
    ResetBuffer(plLineBuffer,t.Linear().Point);
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
void UpdateSegment(bool Refresh)
  {
    highbuffer     = fmax(t.Segment(0).High,highbuffer);
    lowbuffer      = fmin(t.Segment(0).Low,lowbuffer);

    if (t[NewSegment]||Refresh)
    {
      highbuffer     = t.Segment(0).Low;
      lowbuffer      = t.Segment(0).High;

      ArrayInitialize(plHighBuffer,0.00);
      ArrayInitialize(plLowBuffer,0.00);

      for (int node=0;node<inpPeriods;node++)
        if (node<t.Count(Segments))
        {
          UpdateNode("tmaHL:"+(string)indWinId+"-",node,t.Segment(node).High,t.Segment(node).Low);
          UpdateNode("tmaOC:"+(string)indWinId+"-",node,t.Segment(node).Open,t.Segment(node).Close);

          highbuffer   = fmax(highbuffer,t.Segment(node).High);
          lowbuffer    = fmin(lowbuffer,t.Segment(node).Low);
        }
    }

    UpdateNode("tmaHL:"+(string)indWinId+"-",0,t.Segment(0).High,t.Segment(0).Low);
    UpdateNode("tmaOC:"+(string)indWinId+"-",0,t.Segment(0).Open,t.Segment(0).Close);

    plHighBuffer[0]        = highbuffer+point(2);
    plLowBuffer[0]         = lowbuffer;
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
    IndicatorShortName(indSN);
    indWinId = ChartWindowFind(0,indSN);

    //--- Initialize Buffers
    SetIndexBuffer(0,plHighBuffer);
    SetIndexBuffer(1,plLowBuffer);
    SetIndexBuffer(2,plSMAOpenBuffer);
    SetIndexBuffer(3,plSMAHighBuffer);
    SetIndexBuffer(4,plSMALowBuffer);
    SetIndexBuffer(5,plSMACloseBuffer);
    SetIndexBuffer(6,plLineBuffer);

    SetIndexEmptyValue(0,0.00);
    SetIndexEmptyValue(1,0.00);
    SetIndexEmptyValue(2,0.00);
    SetIndexEmptyValue(3,0.00);
    SetIndexEmptyValue(4,0.00);
    SetIndexEmptyValue(5,0.00);
    SetIndexEmptyValue(6,0.00);

    SetIndexLabel (0,""); 
    SetIndexLabel (1,""); 
//    SetIndexLabel (2,"");
//    SetIndexLabel (3,"");
//    SetIndexLabel (4,""); 
//    SetIndexLabel (5,"");
//    SetIndexLabel (6,""); 

    //-- Fibonacci Display Option
    if (IsBetween(inpShowFibo,Origin,Term))
    {
      show    = (FractalType)inpShowFibo;

      NewRay(indObjectStr+"lnS_Origin:"+EnumToString(show),STYLE_DOT,clrWhite,Never);
      NewRay(indObjectStr+"lnS_Base:"+EnumToString(show),STYLE_SOLID,clrYellow,Never);
      NewRay(indObjectStr+"lnS_Root:"+EnumToString(show),STYLE_SOLID,clrDarkGray,Never);
      NewRay(indObjectStr+"lnS_Expansion:"+EnumToString(show),STYLE_SOLID,clrDarkGray,Never);
      NewRay(indObjectStr+"lnS_Retrace:"+EnumToString(show),STYLE_DOT,clrGoldenrod,Never);
      NewRay(indObjectStr+"lnS_Recovery:"+EnumToString(show),STYLE_DOT,clrSteelBlue,Never);

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        NewText(indObjectStr+"lnT_"+fp[point]+":"+EnumToString(show),fp[point]);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        NewRay(indObjectStr+"lnS_"+EnumToString(fibo)+":"+EnumToString(show),STYLE_DOT,clrDarkGray,Never);
        NewText(indObjectStr+"lnT_"+EnumToString(fibo)+":"+EnumToString(show),DoubleToStr(fibonacci[fibo]*100,1)+"%");
      }
    }

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

    //--- Segment Boundaries
    NewPriceLabel("tmaPL(sp):"+(string)indWinId,0.00,false,indWinId);
    NewPriceLabel("tmaPL(rs):"+(string)indWinId,0.00,false,indWinId);
    NewPriceLabel("tmaPL(ex):"+(string)indWinId,0.00,false,indWinId);
      
    //--- Range Bounds Rays
    NewRay("tmaRangeMid:"+(string)indWinId,STYLE_DOT,clrDarkGray,false,indWinId);
    NewRay("tmaPlanSup:"+(string)indWinId,STYLE_DOT,clrRed,false,indWinId);
    NewRay("tmaPlanRes:"+(string)indWinId,STYLE_DOT,clrLawnGreen,false,indWinId);
    NewRay("tmaClose:"+(string)indWinId,STYLE_SOLID,clrDarkGray,false,indWinId);

    //-- App Data Frames
    DrawBox("bxhSessionDir"+(string)indWinId,300,5,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSessionState"+(string)indWinId,230,5,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhFractalDir"+(string)indWinId,300,70,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhFractalState"+(string)indWinId,230,70,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhFOCDir"+(string)indWinId,300,135,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhFOCState"+(string)indWinId,230,135,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSMABias"+(string)indWinId,300,200,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSMAState"+(string)indWinId,230,200,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSegBias"+(string)indWinId,300,265,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    DrawBox("bxhSegState"+(string)indWinId,230,265,220,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);

    //-- Session Data
    NewLabel("tmaHSession"+(string)indWinId,"Session",250,51,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaSessionTrendDir"+(string)indWinId,"",244,8,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionTermDir"+(string)indWinId,"",250,12,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionState"+(string)indWinId,"",64,10,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionFractalState"+(string)indWinId,"",64,34,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionPivotRet"+(string)indWinId,"",36,13,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionPivotExt"+(string)indWinId,"",36,38,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionPivotLead"+(string)indWinId,"",15,10,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionPivotBias"+(string)indWinId,"",15,35,clrDarkGray,SCREEN_UR,indWinId);

    //-- Fractal Data
    NewLabel("tmaHFractal"+(string)indWinId,"Fractal",250,116,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTrendDir"+(string)indWinId,"",244,73,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTermDir"+(string)indWinId,"",250,77,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalTrendState"+(string)indWinId,"",64,75,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalPivot"+(string)indWinId,"",64,98,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalPivotRet"+(string)indWinId,"[ 999 ]",36,79,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalPivotExt"+(string)indWinId,"[ 999 ]",36,102,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalPivotLead"+(string)indWinId,"",15,77,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaFractalPivotBias"+(string)indWinId,"",15,100,clrDarkGray,SCREEN_UR,indWinId);

    //-- Linear Data
    NewLabel("tmaHLinear"+(string)indWinId,"Linear",252,181,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaLinearDir"+(string)indWinId,"",244,137,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearBias"+(string)indWinId,"",250,141,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearState"+(string)indWinId,"",64,140,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearFOC"+(string)indWinId,"",34,164,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearLeadDir"+(string)indWinId,"",15,140,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaLinearBiasDir"+(string)indWinId,"",15,165,clrDarkGray,SCREEN_UR,indWinId);

    //-- SMA Data
    NewLabel("tmaHSMA"+(string)indWinId,"SMA",258,246,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaSMABias"+(string)indWinId,"",250,207,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMADir"+(string)indWinId,"",244,203,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMAState"+(string)indWinId,"",64,217,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMABiasHi"+(string)indWinId,"",15,205,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSMABiasLo"+(string)indWinId,"",15,230,clrDarkGray,SCREEN_UR,indWinId);

    //-- Segment Data
    NewLabel("tmaHSegment"+(string)indWinId,"Segment",248,311,clrGold,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentTerm"+(string)indWinId,"",250,272,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentTrend"+(string)indWinId,"",244,268,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaTickState"+(string)indWinId,"",64,270,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentState"+(string)indWinId,"",57,294,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaTickBias"+(string)indWinId,"",15,270,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSegmentBias"+(string)indWinId,"",15,294,clrDarkGray,SCREEN_UR,indWinId);

    //-- Clock & Price
    NewLabel("Clock","",10,5,clrDarkGray,SCREEN_LR,indWinId);
    NewLabel("Price","",10,30,clrDarkGray,SCREEN_LR,indWinId);

    ArrayResize(crest,inpPeriods);
    ArrayResize(trough,inpPeriods);

    for (int node=0;node<inpPeriods;node++)
    {
      NewPriceLabel("crest-"+(string)node,0.00,true,indWinId);
      NewPriceLabel("trough-"+(string)node,0.00,true,indWinId);
    }

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;

    //-- Clean Open Chart Objects
    int fObject             = 0;

    while (fObject<ObjectsTotal())
      if (InStr(ObjectName(fObject),indObjectStr))
        ObjectDelete(ObjectName(fObject));
      else fObject++;
  }