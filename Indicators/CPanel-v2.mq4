//+------------------------------------------------------------------+
//|                                                    CPanel-v2.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   7

#include <Class/Session.mqh>
#include <Class/TickMA.mqh>

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


//--- Operational Vars
FractalType    show;


//--- input parameters
input int          inpPeriods        =  80;         // Retention
input double       inpAgg            = 2.5;         // Tick Aggregation
input YesNoType    inpShowComment    =  No;         // Show Comments
input ShowType     inpShowFractal    = stNone;      // Show Fractal & Events
input int          inpPanelVersion   =   2;         // Control Panel Version


//--- Indicator defs
int            indWinId              = NoValue;
string         indSN                 = "CPanel-v"+(string)inpPanelVersion;
string         pObjectStr            ="[cp-v"+(string)inpPanelVersion+"]";


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
CTickMA       *t                 = new CTickMA(inpPeriods,inpAgg,(FractalType)inpShowFractal);


//-- Operational vars
double         highbuffer        = NoValue;
double         lowbuffer         = NoValue;
double         crest[];
double         trough[];

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message, bool Pause)
  {
    if (Pause)
      Pause(Message,AccountCompany()+" Event Trapper");
    else
      Print(Message);
  }

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


    if (inpShowFractal>stNone)
    {
      UpdateRay("lnS_Origin:"+EnumToString(fractal),inpPeriods,t[fractal].Point[fpOrigin],-8);
      UpdateRay("lnS_Base:"+(string)indWinId,inpPeriods,t[fractal].Point[fpBase],-8);
      UpdateRay("lnS_Root:"+(string)indWinId,inpPeriods,t[fractal].Point[fpRoot],-8,0,
                               BoolToInt(IsEqual(t[fractal].Direction,DirectionUp),clrRed,clrLawnGreen));
      UpdateRay("lnS_Expansion:"+(string)indWinId,inpPeriods,t[fractal].Point[fpExpansion],-8,0,
                               BoolToInt(IsEqual(t[fractal].Direction,DirectionUp),clrLawnGreen,clrRed));
      UpdateRay("lnS_Retrace:"+(string)indWinId,inpPeriods,t[fractal].Point[fpRetrace],-8,0);
      UpdateRay("lnS_Recovery:"+(string)indWinId,inpPeriods,t[fractal].Point[fpRecovery],-8,0);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        UpdateRay("lnS_"+EnumToString(fibo)+":"+(string)indWinId,inpPeriods,t.Price(fibo,fractal,Extension),-8,0,Color(t[fractal].Direction,IN_DARK_DIR));
        UpdateText("lnT_"+EnumToString(fibo)+":"+(string)indWinId,"",t.Price(fibo,fractal,Extension),-5,Color(t[fractal].Direction,IN_DARK_DIR));
      }

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        UpdateText("lnT_"+fp[point]+":"+(string)indWinId,"",t[fractal].Point[point],-7);
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
    UpdateDirection("tmaSegmentTerm"+(string)indWinId,t.Segment().Direction,Color(t.Segment().Direction),32);
//    UpdateDirection("tmaSegmentTrend"+(string)indWinId,t.Segment().Direction[Trend],Color(t.Segment().Direction[Trend]),16);
    UpdateLabel("tmaTickState"+(string)indWinId,rpad(DirText(t.Tick().Direction)+" ["+(string)t.Segment().Count+"]"," ",20),
                  Color(Direction(t.Segment().Lead,InAction)),12,"Noto Sans Mono CJK HK");
    UpdateDirection("tmaTickBias"+(string)indWinId,Direction(t.Tick().Lead,InAction),Color(Direction(t.Tick().Bias,InAction)),16);
    UpdateLabel("tmaSegmentState"+(string)indWinId,rpad(proper(DirText(t.Segment().Direction))+" "+
                  BoolToStr(IsBetween(t.Pivot().Active,t.Pivot().Support,t.Pivot().Resistance),
                  BoolToStr(IsEqual(t.Segment().Direction,t.Segment().Direction),
                      "Conforming "+proper(ActionText(Action(t.Segment().Direction))),
                      "Contrarian "+proper(ActionText(Action(t.Segment().Direction,InDirection,InContrarian)))),
                      "Breakout "+proper(ActionText(Action(t.Segment().Direction))))," ",21),
                  Color(t.Segment().Direction),12,"Noto Sans Mono CJK HK");
    UpdateDirection("tmaSegmentBias"+(string)indWinId,Direction(t.Segment().Lead,InAction),Color(Direction(t.Segment().Bias,InAction)),16);


    //-- Range Bounds
    UpdateRay("tmaPlanSup:"+(string)indWinId,inpPeriods-1,t.Range().Support);
    UpdateRay("tmaPlanRes:"+(string)indWinId,inpPeriods-1,t.Range().Resistance);
    UpdateRay("tmaRangeMid:"+(string)indWinId,inpPeriods-1,t.Range().Mean);
    UpdateRay("tmaClose:"+(string)indWinId,inpPeriods-1,Close[0]);


    //-- General
    UpdateLabel("Clock",TimeToStr(TimeCurrent(),TIME_DATE|TIME_MINUTES|TIME_SECONDS),clrDodgerBlue,16);
    UpdateLabel("Price",Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);

    if (inpShowComment==Yes)
      if (t.ActiveEvent())
        Comment(t.DisplayStr());
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
//| UpdateIndicator - refreshes indicator data                       |
//+------------------------------------------------------------------+
void UpdateIndicator(void)
  {
    double smahi     = t.Range().Low;
    double smalo     = t.Range().High;

    t.Update();

    ArrayInitialize(crest,0.00);
    ArrayInitialize(trough,0.00);

    for (int node=2;node<fmin(t.Count(Segments),inpPeriods)-1;node++)
    {
      if (t.SMA().High[node]>t.SMA().High[node-1])
        if (t.SMA().High[node]>t.SMA().High[node+1])
          if (IsHigher(t.SMA().High[node],smahi))
            crest[node]      = smahi;

      if (t.SMA().Low[node]<t.SMA().Low[node-1])
        if (t.SMA().Low[node]<t.SMA().Low[node+1])
          if (IsLower(t.SMA().Low[node],smalo))
            trough[node]     = smalo;

      UpdatePriceLabel("trough-"+(string)node+":"+(string)indWinId,trough[node],clrRed,node);
      UpdatePriceLabel("crest-"+(string)node+":"+(string)indWinId,crest[node],clrYellow,node);
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
    UpdateIndicator();
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
    SetIndexLabel (2,"");
    SetIndexLabel (3,"");
    SetIndexLabel (4,"");
    SetIndexLabel (5,"");
    SetIndexLabel (6,"");

    if (inpShowFractal>stNone)
    {
      NewRay("lnS_Origin:"+(string)indWinId,STYLE_DOT,clrWhite,Never);
      NewRay("lnS_Base:"+(string)indWinId,STYLE_SOLID,clrYellow,Never);
      NewRay("lnS_Root:"+(string)indWinId,STYLE_SOLID,clrDarkGray,Never);
      NewRay("lnS_Expansion:"+(string)indWinId,STYLE_SOLID,clrDarkGray,Never);
      NewRay("lnS_Retrace:"+(string)indWinId,STYLE_DOT,clrGoldenrod,Never);
      NewRay("lnS_Recovery:"+(string)indWinId,STYLE_DOT,clrSteelBlue,Never);

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        NewText("lnT_"+fp[point]+":"+(string)indWinId,fp[point]);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        NewRay("lnS_"+EnumToString(fibo)+":"+(string)indWinId,STYLE_DOT,clrDarkGray,Never);
        NewText("lnT_"+EnumToString(fibo)+":"+(string)indWinId,DoubleToStr(fibonacci[fibo]*100,1)+"%");
      }
    }

    //-- Account Information Box
    DrawBox("bxfAI",5,28,352,144,C'5,10,25',BORDER_FLAT,SCREEN_UL,indWinId);

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      DrawBox("bxhAI-Session"+EnumToString(type),(75*type)+60,5,70,20,C'60,60,60',BORDER_RAISED,SCREEN_UL,indWinId);
      DrawBox("bxbAI-OpenInd"+EnumToString(type),(75*type)+64,9,7,12,C'60,60,60',BORDER_RAISED,SCREEN_UL,indWinId);
      NewLabel("lbhAI-Session"+EnumToString(type),lpad(EnumToString(type)," ",4),85+(74*type),7,clrWhite,SCREEN_UL,indWinId);
    }

    NewLabel("lbhAI-Bal","----- Balance/Equity -----",155,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbvAI-Bal","",140,42,clrDarkGray,SCREEN_UL,indWinId);
    NewLabel("lbvAI-Eq","",140,60,clrDarkGray,SCREEN_UL,indWinId);
    NewLabel("lbvAI-EqBal","",140,78,clrDarkGray,SCREEN_UL,indWinId);

    UpdateLabel("lbvAI-Bal","$ 999999999",clrDarkGray,16,"Consolas");
    UpdateLabel("lbvAI-Eq","$-999999999",clrDarkGray,16,"Consolas");
    UpdateLabel("lbvAI-EqBal","$ 999999999",clrDarkGray,16,"Consolas");

    NewLabel("lbhAI-Eq%","------  Equity % ------",24,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhAI-EqOpen%","Open",35,86,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbhAI-EqVar%","Var",96,86,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbvAI-Eq%","",36,42,clrNONE,SCREEN_UL,indWinId);
    NewLabel("lbvAI-EqOpen%","",16,68,clrNONE,SCREEN_UL,indWinId);
    NewLabel("lbvAI-EqVar%","",75,68,clrNONE,SCREEN_UL,indWinId);
    UpdateLabel("lbvAI-Eq%","-999.9%",clrDarkGray,16);
    UpdateLabel("lbvAI-EqOpen%","-99.9%",clrDarkGray,12);
    UpdateLabel("lbvAI-EqVar%","-99.9%",clrDarkGray,12);

    NewLabel("lbhAI-Spread","-- Spread --",290,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbvAI-Spread","",290,42,clrNONE,SCREEN_UL,indWinId);
    UpdateLabel("lbvAI-Spread","999.9",clrDarkGray,14);

    NewLabel("lbhAI-Margin","-- Margin --",290,66,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbvAI-Margin","",284,78,clrNONE,SCREEN_UL,indWinId);
    UpdateLabel("lbvAI-Margin","999.9%",clrDarkGray,14);

    NewLabel("lbhAI-OrderBias","Bias",27,153,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbvAI-OrderBias","",20,116,clrDarkGray,SCREEN_UL,indWinId);
    UpdateDirection("lbvAI-OrderBias",NoDirection,clrDarkGray,30);

    NewLabel("lbhAI-Orders","----------------------  Order Aggregates ----------------------",70,102,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhAI-"+"#","#",108,116,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbhAI-"+"L","Lots",144,116,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbhAI-"+"V","----  Value ----",188,116,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbhAI-"+"M","Mrg%",274,116,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbhAI-"+"E","Eq%",320,116,clrWhite,SCREEN_UL,indWinId);

    string key;

    for (int row=0;row<=2;row++)
    {
      key = BoolToStr(row==2,"Net",proper(ActionText(row)));
      NewLabel("lbhAI-"+key+"Action","",70,128+(row*12),clrDarkGray,SCREEN_UL,indWinId);

      NewLabel("lbvAI-"+key+"#","",104,128+(12*row),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvAI-"+key+"L","",130,128+(12*row),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvAI-"+key+"V","",186,128+(12*row),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvAI-"+key+"M","",266,128+(12*row),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvAI-"+key+"E","",310,128+(12*row),clrDarkGray,SCREEN_UL,indWinId);

      UpdateLabel("lbhAI-"+key+"Action",key,clrDarkGray,10);
      UpdateLabel("lbvAI-"+key+"#","99",clrDarkGray,10,"Consolas");
      UpdateLabel("lbvAI-"+key+"L","000.00",clrDarkGray,10,"Consolas");
      UpdateLabel("lbvAI-"+key+"V","-000000000",clrDarkGray,10,"Consolas");
      UpdateLabel("lbvAI-"+key+"M","-00.0",clrDarkGray,10,"Consolas");
      UpdateLabel("lbvAI-"+key+"E","999.9",clrDarkGray,10,"Consolas");
    }

    //-- App Comms
    NewLabel("lbhAC-Trade","Trading",365,7,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbhAC-SysMsg","Message",458,7,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbhAC-File","File",1175,7,clrWhite,SCREEN_UL,indWinId);
    NewLabel("lbvAC-Trading","Trade",408,7,clrDarkGray,SCREEN_UL,indWinId);
    NewLabel("lbvAC-SysMsg","",508,7,clrDarkGray,SCREEN_UL,indWinId);
    NewLabel("lbvAC-File","N/A",1200,7,clrGold,SCREEN_UL,indWinId);

    //-- Order Config
    DrawBox("bxfOC-Long",5,174,352,144,C'0,42,0',BORDER_FLAT,SCREEN_UL,indWinId);
    DrawBox("bxfOC-Short",5,320,352,144,C'42,0,0',BORDER_FLAT,SCREEN_UL,indWinId);

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      NewLabel("lbhOC-"+ActionText(action)+"-Trading","Trading",10,(146*(action+1))+30,clrWhite,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Strategy","Strategy",188,(146*(action+1))+30,clrWhite,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Equity","--------  Equity  ---------",36,(146*(action+1))+44,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQTarget","Target",22,(146*(action+1))+70,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQMin","Min",78,(146*(action+1))+70,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQPrice","T/P",130,(146*(action+1))+70,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Risk","---------  Risk  ----------",204,(146*(action+1))+44,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKBalance","Max",198,(146*(action+1))+70,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKMaxMargin","Margin",240,(146*(action+1))+70,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKPrice","S/L",296,(146*(action+1))+70,clrGold,SCREEN_UL,indWinId);

      NewLabel("lbhOC-"+ActionText(action)+"-EQBase","P/L",24,(146*(action+1))+100,clrGold,SCREEN_UL,indWinId);
      UpdateLabel("lbhOC-"+ActionText(action)+"-EQBase","P/L",clrWhite,10);
      NewLabel("lbhOC-"+ActionText(action)+"-DCA","DCA",194,(146*(action+1))+100,clrGold,SCREEN_UL,indWinId);
      UpdateLabel("lbhOC-"+ActionText(action)+"-DCA","DCA",clrWhite,10);

      NewLabel("lbhOC-"+ActionText(action)+"-Lots","------- Lot Sizing --------",36,(146*(action+1))+118,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotSize","Size",28,(146*(action+1))+144,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotMin","Min",78,(146*(action+1))+144,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotMax","Max",120,(146*(action+1))+144,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Zone","---------  Zone  ----------",204,(146*(action+1))+118,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Step","Step",194,(146*(action+1))+144,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-MaxMargin","Margin",240,(146*(action+1))+144,clrGold,SCREEN_UL,indWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-ZoneNow","Zone",294,(146*(action+1))+144,clrGold,SCREEN_UL,indWinId);

      NewLabel("lbvOC-"+ActionText(action)+"-Enabled","Enabled",50,(146*(action+1))+30,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Manager","",170,(146*(action+1))+29,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Strategy","Strategy",234,(146*(action+1))+30,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Hold","",336,(146*(action+1))+29,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EqTarget","999.9%",20,(146*(action+1))+56,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EqMin","99.9%",70,(146*(action+1))+56,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Target","9.99999",116,(146*(action+1))+56,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltTarget","Default 9.99999 50p",36,(146*(action+1))+82,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxRisk","99.9%",190,(146*(action+1))+56,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxMargin","99.9%",238,(146*(action+1))+56,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Stop","9.99999",282,(146*(action+1))+56,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltStop","Default 9.99999 50p",206,(146*(action+1))+82,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EQBase","999999999 (999%)",46,(146*(action+1))+100,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DCA","9.99999 (9.9%)",224,(146*(action+1))+100,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-LotSize","99.99",16,(146*(action+1))+130,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MinLotSize","99.99",68,(146*(action+1))+130,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxLotSize","999.99",110,(146*(action+1))+130,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltLotSize","Default 99.99",60,(146*(action+1))+156,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-ZoneStep","99.9",194,(146*(action+1))+130,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxZoneMargin","99.9%",236,(146*(action+1))+130,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-ZoneNow","-99",294,(146*(action+1))+130,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EntryZone","Entry 9.99999",220,(146*(action+1))+156,clrDarkGray,SCREEN_UL,indWinId);

      UpdateLabel("lbvOC-"+ActionText(action)+"-Hold",CharToStr(176),clrDarkGray,11,"Wingdings");
    }

    //-- Zone Margin frames
    DrawBox("bxfOZ-Long",360,174,960,144,C'0,42,0',BORDER_FLAT,SCREEN_UL,indWinId);
    DrawBox("bxfOZ-Short",360,320,960,144,C'42,0,0',BORDER_FLAT,SCREEN_UL,indWinId);

    //-- Zone Metrics
    for (int row=0;row<11;row++)
      for (int col=0;col<=OP_SELL;col++)
      {
        if (row==0)
        {
          NewLabel("lbhOZ-"+ActionText(col)+"Z","Zone",370,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"#","#",404,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"L","Lots",436,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"V","-------- Value ---------",482,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"M","Mrg%",592,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"E","Eq%",634,176+(col*146),clrGold,SCREEN_UL,indWinId);

          NewLabel("lbhOQ-"+ActionText(col)+"-Ticket","Ticket",674,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-State","State",760,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Price","Open",840,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Lots","Lots",906,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-ShowTP","X",966,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Target","Target",980,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-ShowSL","X",1026,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Stop","Stop",1040,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Profit","----- Profit -----",1090,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Swap","----- Swap ----",1170,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Net","----- Net -----",1252,176+(col*146),clrGold,SCREEN_UL,indWinId);
          
          UpdateLabel("lbvOQ-"+ActionText(col)+"-ShowTP",CharToStr(251),clrRed,12,"Wingdings");
          UpdateLabel("lbvOQ-"+ActionText(col)+"-ShowSL",CharToStr(252),clrLawnGreen,12,"Wingdings");
        }

        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"Z","",370,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"#","",400,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"L","",424,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"V","",482,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"M","",592,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"E","",630,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);

        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Ticket","",674,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-State","",760,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Price","",840,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Lots","",906,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-TP","",966,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-SL","",1026,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Profit","",1082,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Swap","",1166,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Net","",1236,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,indWinId);

        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"Z","-99",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"#","99",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"L","0000.00",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"V",dollar(-9999999999,14,false),clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"M","00.0",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"E","999.9",clrDarkGray,9,"Consolas");

        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Ticket",IntegerToString(99999999,10,'-'),clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-State","Hold",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Price","9.99999",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Lots","9999.99",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-TP","9.99999",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-SL","9.99999",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Profit",dollar(-9999999,11,false),clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Swap",dollar(-9999999,8,false),clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Net",dollar(-9999999,11,false),clrDarkGray,9,"Consolas");
      }

    //-- Request Queue
    DrawBox("bxfRQ-Request",360,28,960,144,C'0,12,24',BORDER_FLAT,SCREEN_UL,indWinId);

    //-- Request Queue Headers
    NewLabel("lbhRQ-"+"-Key","Request #",366,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Status","Status",426,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Requestor","Requestor",484,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Type","Type",569,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Price","Price",620,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Lots","Lots",668,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Target","Target",716,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Stop","Stop",764,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Expiry","--- Expiration -----",810,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-LBound","Low ---",906,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-UBound","High ---",950,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Resubmit","Resubmit",1002,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Step","Step",1058,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Memo","Order Comments",1092,30,clrGold,SCREEN_UL,indWinId);

    //-- Request Queue Fields
    for (int row=0;row<11;row++)
    {
      NewLabel("lbvRQ-"+(string)row+"-Key","00000000",366,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      UpdateLabel("lbvRQ-"+(string)row+"-Key","00000000",clrDarkGray,8,"Consolas");
      NewLabel("lbvRQ-"+(string)row+"-Status","Pending",426,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Requestor","Bellwether",484,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Type","Sell Limit",569,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Price","0.00000",620,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Lots","0000.00",668,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Target","0.00000",716,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Stop","0.00000",764,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Expiry","12/1/2019 11:00",810,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-LBound","0.00000",906,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-UBound","0.00000",954,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Resubmit","Sell Limit",1002,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Step","99.9",1058,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Memo","1234567890123456789012345678901234567",1092,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
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

    //--- Indicator Rays
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
    NewLabel("tmaSessionTrendDir"+(string)indWinId,"^",244,8,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionTermDir"+(string)indWinId,"^",250,12,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionState"+(string)indWinId,"State",64,10,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionFractalState"+(string)indWinId,"State",64,34,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionPivotRet"+(string)indWinId,"[ 999 ]",36,13,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionPivotExt"+(string)indWinId,"[ 999 ]",36,38,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionPivotLead"+(string)indWinId,"^",15,10,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("tmaSessionPivotBias"+(string)indWinId,"^",15,35,clrDarkGray,SCREEN_UR,indWinId);

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

    ArrayResize(crest,inpPeriods);
    ArrayResize(trough,inpPeriods);

    for (int node=0;node<inpPeriods;node++)
    {
      NewPriceLabel("crest-"+(string)node+":"+(string)indWinId,0.00,true,indWinId);
      NewPriceLabel("trough-"+(string)node+":"+(string)indWinId,0.00,true,indWinId);
    }

    //-- Clock & Price
    NewLabel("Tick","99999999",10,5,clrDarkGray,SCREEN_LR,indWinId);
    NewLabel("Clock","",10,18,clrDarkGray,SCREEN_LR,indWinId);
    NewLabel("Price","",10,44,clrDarkGray,SCREEN_LR,indWinId);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
  }