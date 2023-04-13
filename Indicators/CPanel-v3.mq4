//+------------------------------------------------------------------+
//|                                                    CPanel-v3.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "3.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   10

#define debug false

#include <Class\Session.mqh>
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
input int          inpPeriods        =  80;         // Retention
input int          inpDegree         =   6;         // Poiy Regression Degree
input double       inpAgg            = 2.5;         // Tick Aggregation
input YesNoType    inpShowZones      = Yes;         // Show Zone Lines
input YesNoType    inpShowTickBounds =  No;         // Show Tick Boundary
input YesNoType    inpShowSegBounds  = Yes;         // Show Segment Boundary
input YesNoType    inpShowRulers     = Yes;         // Show Fractal Rulers

//--- Indicator defs
int            indWinId              = -1;
string         indSN                 = "CPanel-v3";

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

double         highbuffer        = NoValue;
double         lowbuffer         = NoValue;

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
    //-- Range
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
    UpdateLabel("tmaSMAMomentumHi"+(string)indWinId,DoubleToStr(t.Momentum().High.Now,Digits),Color(Direction(t.Momentum().High.Bias,InAction),IN_CHART_DIR),9);
    UpdateDirection("tmaSMABiasHi"+(string)indWinId,t.Direction(t.SMA().High),Color(t.Direction(t.SMA().High)),18);

    //-- Low Bias
    UpdateDirection("tmaSMATermLo"+(string)indWinId,t.Fractal().Low.Direction[Term],Color(t.Fractal().Low.Direction[Term]),18);
    UpdateDirection("tmaSMATrendLo"+(string)indWinId,t.Fractal().Low.Direction[Trend],Color(t.Fractal().Low.Direction[Trend]),10,Narrow);
    UpdateLabel("tmaSMAStateLo"+(string)indWinId,proper(DirText(t.Direction(t.SMA().Low)))+" "+FractalTag[t.Fractal().Low.Type]+" "+
                  BoolToStr(Close[0]<t.SMA().Low[0],"Hold",BoolToStr(Close[0]>t.SMA().Close[0],"Rally","Pullback")),Color(t.Direction(t.SMA().Low)),12);
    UpdateLabel("tmaSMAMomentumLo"+(string)indWinId,DoubleToStr(t.Momentum().Low.Now,Digits),Color(Direction(t.Momentum().Low.Bias,InAction),IN_CHART_DIR),9);
    UpdateDirection("tmaSMABiasLo"+(string)indWinId,t.Direction(t.SMA().Low),Color(t.Direction(t.SMA().Low)),18);

    //-- Linear
    UpdateLabel("tmaLinearStateOpen"+(string)indWinId,NegLPad(t.Linear().Open.Now,Digits)+" "+NegLPad(t.Linear().Open.Max,Digits)+" "+
                  NegLPad(t.Linear().Open.Min,Digits),Color(t.Linear().Open.Direction),12);
    UpdateDirection("tmaLinearBiasOpen"+(string)indWinId,Direction(t.Linear().Open.Bias,InAction),Color(Direction(t.Linear().Open.Bias,InAction)),18);
    UpdateLabel("tmaLinearStateClose"+(string)indWinId,NegLPad(t.Linear().Close.Now,Digits)+" "+NegLPad(t.Linear().Close.Max,Digits)+" "+
                  NegLPad(t.Linear().Close.Min,Digits),Color(t.Linear().Close.Direction),12);
    UpdateDirection("tmaLinearBiasClose"+(string)indWinId,Direction(t.Linear().Close.Bias,InAction),Color(Direction(t.Linear().Close.Bias,InAction)),18);
    UpdateDirection("tmaLinearBiasNet"+(string)indWinId,Direction(t.Linear().Bias,InAction),Color(Direction(t.Linear().Bias,InAction)),24);
    
    //-- Fractal
    UpdateDirection("tmaFractalDir"+(string)indWinId,t.Fractal().Direction,Color(t.Fractal().Direction),18);
    UpdateLabel("tmaFractalState"+(string)indWinId,EnumToString(t.Fractal().Type)+" "+EnumToString(t.Fractal().State),Color(t.Fractal().Direction),12);
    UpdateDirection("tmaFractalBias"+(string)indWinId,Direction(t.Fractal().Bias,InAction),Color(Direction(t.Fractal().Bias,InAction)),18);

    if (inpShowSegBounds==Yes)
    {
      UpdatePriceLabel("tmaPL(sp):"+(string)indWinId,t.Fractal().Support,clrRed);
      UpdatePriceLabel("tmaPL(rs):"+(string)indWinId,t.Fractal().Resistance,clrLawnGreen);
      UpdatePriceLabel("tmaPL(e):"+(string)indWinId,t.Fractal().Expansion,clrGoldenrod);

      if (t[NewHigh]||t[NewLow])
        UpdatePriceLabel("tmaNewBoundary",Close[0],Color(BoolToInt(t[NewHigh],DirectionUp,DirectionDown),IN_DARK_DIR));
    }

    //-- Fractal Bounds
    if (inpShowZones==Yes)
    {
      UpdateRay("tmaPlanSup:"+(string)indWinId,t.Range().Support,inpPeriods-1);
      UpdateRay("tmaPlanRes:"+(string)indWinId,t.Range().Resistance,inpPeriods-1);
      UpdateRay("tmaRangeMid:"+(string)indWinId,t.Range().Mean,inpPeriods-1);
      UpdateRay("tmaClose:"+(string)indWinId,Close[0],inpPeriods-1);
      
      Arrow("tmaFrRes:"+(string)indWinId,ArrowDown,clrLawnGreen,t.Bar(Resistance),t.Fractal().High.Resistance+point(6),indWinId);
      Arrow("tmaFrSup:"+(string)indWinId,ArrowUp,clrRed,t.Bar(Support),t.Fractal().Low.Support,indWinId);
    }

    if (inpShowRulers==Yes)
    {
      for (int bar=0;bar<inpPeriods;bar++)
      {
        ObjectSetText("tmaFrHi:"+(string)indWinId+"-"+(string)bar,"-",9,"Stencil",clrRed);
        ObjectSetText("tmaFrLo:"+(string)indWinId+"-"+(string)bar,"-",9,"Stencil",clrRed);

        ObjectSet("tmaFrHi:"+(string)indWinId+"-"+(string)bar,OBJPROP_PRICE1,highbuffer+point(2));
        ObjectSet("tmaFrLo:"+(string)indWinId+"-"+(string)bar,OBJPROP_PRICE1,lowbuffer);

        ObjectSet("tmaFrHi:"+(string)indWinId+"-"+(string)bar,OBJPROP_TIME1,Time[bar]);
        ObjectSet("tmaFrLo:"+(string)indWinId+"-"+(string)bar,OBJPROP_TIME1,Time[bar]);        
      }

      for (FractalType type=Origin;type<FractalTypes;type++)
      {
        if (type<=t.Fractal().High.Type)
          ObjectSetText("tmaFrHi:"+(string)indWinId+"-"+(string)t.Fractal().High.Bar[type],FractalTag[type],9,"Stencil",clrRed);

        if (type<=t.Fractal().Low.Type)
          ObjectSetText("tmaFrLo:"+(string)indWinId+"-"+(string)t.Fractal().Low.Bar[type],FractalTag[type],9,"Stencil",clrRed);
      }
    }

    UpdateLabel("Clock"+(string)indWinId,TimeToStr(Time[0]),clrDodgerBlue,16);
    UpdateLabel("Price"+(string)indWinId,Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);
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
    t.Update();

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
    indWinId = ChartWindowFind(0,indSN);
  
    //-- Account Information Box
    DrawBox("bxfAI",5,28,352,144,C'5,10,25',BORDER_FLAT,SCREEN_UL,indWinId);

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      DrawBox("bxhAI-Session"+EnumToString(type),(75*type)+60,5,70,20,C'60,60,60',BORDER_RAISED,SCREEN_UL,indWinId);
      DrawBox("bxbAI-OpenInd"+EnumToString(type),(75*type)+64,9,7,12,C'60,60,60',BORDER_RAISED,SCREEN_UL,indWinId);
      NewLabel("lbhAI-Session"+EnumToString(type),LPad(EnumToString(type)," ",4),85+(74*type),7,clrWhite,SCREEN_UL,indWinId);
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
    NewLabel("lbvAC-Trading","Trade",408,7,clrDarkGray,SCREEN_UL,indWinId);
    NewLabel("lbvAC-SysMsg","",508,7,clrDarkGray,SCREEN_UL,indWinId);

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
      NewLabel("lbvOC-"+ActionText(action)+"-Strategy","Strategy",234,(146*(action+1))+30,clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Hold","O",336,(146*(action+1))+26,clrDarkGray,SCREEN_UL,indWinId);
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
          NewLabel("lbvOQ-"+ActionText(col)+"-Target","Target",966,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Stop","Stop",1026,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Profit","----- Profit -----",1090,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Swap","----- Swap ----",1170,176+(col*146),clrGold,SCREEN_UL,indWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Net","----- Net -----",1252,176+(col*146),clrGold,SCREEN_UL,indWinId);
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
    NewLabel("lbhRQ-"+"-Expiry","Expiration",810,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Limit","Limit",906,30,clrGold,SCREEN_UL,indWinId);
    NewLabel("lbhRQ-"+"-Cancel","Cancel",954,30,clrGold,SCREEN_UL,indWinId);
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
      NewLabel("lbvRQ-"+(string)row+"-Limit","0.00000",906,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Cancel","0.00000",954,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Resubmit","Sell Limit",1002,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Step","99.9",1058,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
      NewLabel("lbvRQ-"+(string)row+"-Memo","1234567890123456789012345678901234567",1092,44+(row*11),clrDarkGray,SCREEN_UL,indWinId);
    }

    //--- Create Display Visuals
    for (int obj=0;obj<inpPeriods;obj++)
    {
      ObjectCreate("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJ_TREND,indWinId,0,0);
      ObjectSet("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJPROP_WIDTH,1);

      ObjectCreate("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJ_TREND,indWinId,0,0);
      ObjectSet("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJPROP_WIDTH,3);
    }

    //-- App Data Area
    DrawBox("bxhPivot",300,330,65,60,C'0,42,0',BORDER_FLAT,SCREEN_UR,indWinId);
    //DrawBox("bxfOC-Short",5,320,352,144,C'42,0,0',BORDER_FLAT,SCREEN_UL,indWinId);

    NewLabel("lbhBias","Bias",160,345,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("lbhLead","Lead",160,360,clrDarkGray,SCREEN_UR,indWinId);
    NewLabel("lbhFractal","Origin",160,375,clrDarkGray,SCREEN_UR,indWinId);

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

    NewLabel("Clock"+(string)indWinId,"",10,5,clrDarkGray,SCREEN_LR,indWinId);
    NewLabel("Price"+(string)indWinId,"",10,30,clrDarkGray,SCREEN_LR,indWinId);

    if (inpShowSegBounds==Yes)
    {
      NewPriceLabel("tmaPL(sp):"+(string)indWinId,0.00,false,indWinId);
      NewPriceLabel("tmaPL(rs):"+(string)indWinId,0.00,false,indWinId);
      NewPriceLabel("tmaPL(e):"+(string)indWinId,0.00,false,indWinId);
      NewPriceLabel("tmaNewBoundary",0.00,false);
    }

    if (inpShowTickBounds==Yes)
    {
      NewPriceLabel("tmaPL(th):"+(string)indWinId,0.00,false,indWinId);
      NewPriceLabel("tmaPL(tl):"+(string)indWinId,0.00,false,indWinId);
    }

    //--- Create Display Visuals
    NewRay("tmaRangeMid:"+(string)indWinId,STYLE_DOT,clrDarkGray,false,indWinId);
    NewRay("tmaPlanSup:"+(string)indWinId,STYLE_DOT,clrRed,false,indWinId);
    NewRay("tmaPlanRes:"+(string)indWinId,STYLE_DOT,clrLawnGreen,false,indWinId);
    NewRay("tmaClose:"+(string)indWinId,STYLE_SOLID,clrDarkGray,false,indWinId);
    
    for (int obj=0;obj<inpPeriods;obj++)
    {
      if (inpShowRulers==Yes)
      {
        ObjectCreate("tmaFrHi:"+(string)indWinId+"-"+(string)obj,OBJ_TEXT,indWinId,0,0);
        ObjectCreate("tmaFrLo:"+(string)indWinId+"-"+(string)obj,OBJ_TEXT,indWinId,0,0);
      }

      ObjectCreate("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJ_TREND,indWinId,0,0);
      ObjectSet("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaHL:"+(string)indWinId+"-"+(string)obj,OBJPROP_WIDTH,1);

      ObjectCreate("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJ_TREND,indWinId,0,0);
      ObjectSet("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaOC:"+(string)indWinId+"-"+(string)obj,OBJPROP_WIDTH,3);
    }

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
    SetIndexLabel (3,""); 
    SetIndexLabel (4,""); 
    SetIndexLabel (5,""); 
    SetIndexLabel (6,""); 
    SetIndexLabel (7,""); 
    SetIndexLabel (8,""); 
    SetIndexLabel (9,""); 

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
  }