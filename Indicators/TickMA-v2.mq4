//+------------------------------------------------------------------+
//|                                                    TickMA-v2.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.01"
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

//--- Enum Fractal Show Options
enum ShowOptions 
     {
       NoShow,      // Hide Fractals
       SMAOpen,     // SMA (Open)
       SMAHigh,     // SMA (High)
       SMALow,      // SMA (Low)
       SMAClose     // SMA (Close)
     };

//--- input parameters
input int          inpPeriods        =  80;         // Retention
input int          inpDegree         =   6;         // Poiy Regression Degree
input double       inpAgg            = 2.5;         // Tick Aggregation
input ShowOptions  inpShowFractal    = NoShow;      // Show Fractal

//--- Indicator defs
string         ShortName          = "TickMA-v2: "+(string)inpPeriods+":"+(string)inpDegree+":"+(string)inpAgg;
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
CTickMA       *t                 = new CTickMA(inpPeriods,inpDegree,inpAgg);

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static int bias          = DirectionNone;
    static int id            = 1;
    const color labelcolor[] = {clrWhite,clrYellow,clrLawnGreen,clrRed,clrGoldenrod,clrSteelBlue};
    double f[];
    
    if (!IsEqual(inpShowFractal,NoShow))
    {
      if (inpShowFractal==SMAHigh)   ArrayCopy(f,t.SMA().High.Point);
      if (inpShowFractal==SMALow)    ArrayCopy(f,t.SMA().Low.Point);

      for (FractalPoint fp=0;fp<FractalPoints;fp++)
        UpdatePriceLabel("tmaPL"+StringSubstr(EnumToString(inpShowFractal),2)+":"+StringSubstr(EnumToString(fp),2),f[fp],labelcolor[fp]);
      
      UpdatePriceLabel("tmaPL"+StringSubstr(EnumToString(inpShowFractal),2)+":Now",BoolToDouble(inpShowFractal==SMAHigh,t.SMA().High.Price[0],t.SMA().Low.Price[0]),clrDarkGray);
    }

    UpdateLabel("tmaRangeState"+(string)IndWinId,EnumToString(t.Range().State)+" ["+string(t.Count(Ticks)-1)+":"+
                  string(t.Count(Segments)-1)+"] Z/A ["+(string)t.Linear().Zone+":"+(string)t.Range().Age+"]",Color(Direction(t.Range().Direction)),12);
    UpdateLabel("tmaSegmentState"+(string)IndWinId,"Segment ["+(string)t.Segment(0).Price.Count+"]: "+
                  BoolToStr(IsEqual(t.Segment(0).Direction,t.Segment(0).ActiveDir),
                  proper(DirText(t.Segment(0).Direction)),"Hedge"),Color(t.Segment(0).Direction),12);
    UpdateDirection("tmaSegmentBias"+(string)IndWinId,Direction(t.Segment(0).Bias,InAction),Color(Direction(t.Segment(0).Bias,InAction)),18);
    UpdateDirection("tmaSegmentDir"+(string)IndWinId,t.Segment(0).ActiveDir,Color(t.Segment(0).ActiveDir),18);
    UpdateLabel("tmaSMAState"+(string)IndWinId,BoolToStr(IsEqual(t.SMA().Event,NoEvent),
                  proper(DirText(t.SMA().Direction))+" "+EnumToString(t.SMA().State),EventText[t.SMA().Event]),Color(t.SMA().Direction),12);
    UpdateDirection("tmaSMABias"+(string)IndWinId,Direction(t.SMA().Bias,InAction),Color(Direction(t.SMA().Bias,InAction)),18);
    UpdateLabel("tmaSMAStateHi"+(string)IndWinId,BoolToStr(IsEqual(t.SMA().High.Event,NoEvent),
                  proper(DirText(t.SMA().High.Direction))+" "+EnumToString(t.SMA().High.State),EventText[t.SMA().High.Event]),
                  BoolToInt(t.SMA().High.Peg.IsPegged,clrYellow,Color(t.SMA().High.Direction)),12);
    UpdateDirection("tmaSMABiasHi"+(string)IndWinId,Direction(t.SMA().High.Bias,InAction),Color(Direction(t.SMA().High.Bias,InAction)),18);
    UpdateLabel("tmaSMAStateLo"+(string)IndWinId,BoolToStr(IsEqual(t.SMA().Low.Event,NoEvent),
                  proper(DirText(t.SMA().Low.Direction))+" "+EnumToString(t.SMA().Low.State),EventText[t.SMA().Low.Event]),
                  BoolToInt(t.SMA().Low.Peg.IsPegged,clrYellow,Color(t.SMA().Low.Direction)),12);
    UpdateDirection("tmaSMABiasLo"+(string)IndWinId,Direction(t.SMA().Low.Bias,InAction),Color(Direction(t.SMA().Low.Bias,InAction)),18);
    UpdateLabel("tmaLinearStateOpen"+(string)IndWinId,NegLPad(t.Linear().Open.Now,Digits)+" "+NegLPad(t.Linear().Open.Max,Digits)+" "+
                  NegLPad(t.Linear().Open.Min,Digits),Color(t.Linear().Open.Direction),12);
    UpdateDirection("tmaLinearBiasOpen"+(string)IndWinId,Direction(t.Linear().Open.Bias,InAction),Color(Direction(t.Linear().Open.Bias,InAction)),18);
    UpdateLabel("tmaLinearStateClose"+(string)IndWinId,NegLPad(t.Linear().Close.Now,Digits)+" "+NegLPad(t.Linear().Close.Max,Digits)+" "+
                  NegLPad(t.Linear().Close.Min,Digits),Color(t.Linear().Close.Direction),12);
    UpdateDirection("tmaLinearBiasClose"+(string)IndWinId,Direction(t.Linear().Close.Bias,InAction),Color(Direction(t.Linear().Close.Bias,InAction)),18);
    UpdateDirection("tmaLinearBiasNet"+(string)IndWinId,Direction(t.Linear().Bias,InAction),Color(Direction(t.Linear().Bias,InAction)),24);
    
    UpdateLabel("Clock",TimeToStr(Time[0]),clrDodgerBlue,16);
    UpdateLabel("Price",Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);
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
    const  int labelcolor[2][7]   = {{clrNONE,clrForestGreen,clrLawnGreen,clrLawnGreen,clrLawnGreen,clrLawnGreen,clrWhite},
                                     {clrNONE,clrFireBrick,clrRed,clrRed,clrRed,clrRed,clrWhite}};
    static int action             = OP_NO_ACTION;

    t.Update();
    
    NewAction(action,t.SMA().Bias);
    
    UpdatePriceLabel("tmaNewLow",BoolToDouble(t[NewLow],Close[0],0.00),labelcolor[action][t.EventAlertLevel(NewLow)]);
    UpdatePriceLabel("tmaNewHigh",BoolToDouble(t[NewHigh],Close[0],0.00),labelcolor[action][t.EventAlertLevel(NewHigh)]);

    SetLevelValue(0,BoolToDouble(inpShowFractal==SMAHigh,t.SMA().High.Price[0],t.SMA().Low.Price[0]));
    SetLevelValue(1,t.Range().Mean);

    SetIndexStyle(8,DRAW_LINE,STYLE_SOLID,1,Color(t.Linear().Direction,IN_CHART_DIR));
    SetIndexStyle(9,DRAW_LINE,STYLE_DASH,1,Color(t.Range().Direction,IN_CHART_DIR));

    ResetBuffer(plSMAOpenBuffer,t.SMA().Open.Price);
    ResetBuffer(plSMACloseBuffer,t.SMA().Close.Price);
    ResetBuffer(plSMAHighBuffer,t.SMA().High.Price);
    ResetBuffer(plSMALowBuffer,t.SMA().Low.Price);

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
      UpdateNode("tmaHL:"+(string)IndWinId+"-",node,t.Segment(node).Price.High,t.Segment(node).Price.Low);
      UpdateNode("tmaOC:"+(string)IndWinId+"-",node,t.Segment(node).Price.Open,t.Segment(node).Price.Close);
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

    //--- Create Display Visuals
    for (int obj=0;obj<inpPeriods;obj++)
    {
      ObjectCreate("tmaHL:"+(string)IndWinId+"-"+(string)obj,OBJ_TREND,IndWinId,0,0);
      ObjectSet("tmaHL:"+(string)IndWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaHL:"+(string)IndWinId+"-"+(string)obj,OBJPROP_WIDTH,1);

      ObjectCreate("tmaOC:"+(string)IndWinId+"-"+(string)obj,OBJ_TREND,IndWinId,0,0);
      ObjectSet("tmaOC:"+(string)IndWinId+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("tmaOC:"+(string)IndWinId+"-"+(string)obj,OBJPROP_WIDTH,3);
    }

    if (!IsEqual(inpShowFractal,NoShow))
    {
      for (FractalPoint fp=0;fp<FractalPoints;fp++)
        NewPriceLabel("tmaPL"+StringSubstr(EnumToString(inpShowFractal),2)+":"+StringSubstr(EnumToString(fp),2),0.00,false,IndWinId);

      NewPriceLabel("tmaPL"+StringSubstr(EnumToString(inpShowFractal),2)+":Now",0.00,false,IndWinId);
    }

    NewLabel("tmaRangeState"+(string)IndWinId,"",32,2,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSegmentState"+(string)IndWinId,"",32,20,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSegmentBias"+(string)IndWinId,"",5,16,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSegmentDir"+(string)IndWinId,"",180,18,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMAState"+(string)IndWinId,"",32,38,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMABias"+(string)IndWinId,"",5,34,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMAStateHi"+(string)IndWinId,"",32,56,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMABiasHi"+(string)IndWinId,"",5,52,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMAStateLo"+(string)IndWinId,"",32,74,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaSMABiasLo"+(string)IndWinId,"",5,70,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearStateOpen"+(string)IndWinId,"",32,92,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearBiasOpen"+(string)IndWinId,"",5,88,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearStateClose"+(string)IndWinId,"",32,110,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearBiasClose"+(string)IndWinId,"",5,106,clrDarkGray,SCREEN_UR,IndWinId);
    NewLabel("tmaLinearBiasNet"+(string)IndWinId,"",210,96,clrDarkGray,SCREEN_UR,IndWinId);

    NewLabel("Clock","",10,5,clrDarkGray,SCREEN_LR,IndWinId);
    NewLabel("Price","",10,30,clrDarkGray,SCREEN_LR,IndWinId);

    NewPriceLabel("tmaNewLow");
    NewPriceLabel("tmaNewHigh");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
  }