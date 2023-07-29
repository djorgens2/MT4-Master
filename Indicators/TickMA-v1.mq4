//+------------------------------------------------------------------+
//|                                                    TickMA-v1.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.09"
#property strict
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

#define printevent false

#include <Class\TickMA.mqh>

//--- plot plFractal
#property indicator_label1  "plFractal"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrGoldenrod
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

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
input YesNoType    inpRangeBounds    = No;          // Show Range Boundaries
input ShowType     inpShowFibo       = stNone;      // Show Fractal Bounds
input ShowType     inpShowEvents     = stNone;      // Show Events

//--- Indicator defs
string         indObjectStr       = "[tv1]";
string         indSN              = "TickMA-v1: "+(string)inpPeriods+":"+(string)inpAgg;
int            indWinId           = NoValue;

//--- Indicator buffers
double         plFractalBuffer[];

//--- Class defs
CTickMA       *t                 = new CTickMA(inpPeriods,inpAgg,(FractalType)inpShowEvents);

//--- Operational Vars
FractalType    show;

//+------------------------------------------------------------------+
//| FibonacciStr - Repaint screen elements                           |
//+------------------------------------------------------------------+
string FibonacciStr(string Type, FibonacciRec &Fibonacci)
  {
    string text    = Type;

    Append(text,EnumToString(Fibonacci.Level));
    Append(text,DoubleToStr(Fibonacci.Pivot,Digits));

//    Append(text,"      Now/Min/Max:   ","\n");
    Append(text,DoubleToStr(Fibonacci.Percent[Now]*100,1)+"%");
    Append(text,DoubleToStr(Fibonacci.Percent[Min]*100,1)+"%");
    Append(text,DoubleToStr(Fibonacci.Percent[Max]*100,1)+"%");

    return text;
  }


//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text   = "";

    if (inpShowFibo>stNone)
    {
      UpdateRay(indObjectStr+"lnS_Origin:"+EnumToString(show),inpPeriods,t[show].Fractal[fpOrigin],-8);
      UpdateRay(indObjectStr+"lnS_Base:"+EnumToString(show),inpPeriods,t[show].Fractal[fpBase],-8);
      UpdateRay(indObjectStr+"lnS_Root:"+EnumToString(show),inpPeriods,t[show].Fractal[fpRoot],-8,0,
                             BoolToInt(IsEqual(t[show].Direction,DirectionUp),clrRed,clrLawnGreen));
      UpdateRay(indObjectStr+"lnS_Expansion:"+EnumToString(show),inpPeriods,t[show].Fractal[fpExpansion],-8,0,
                             BoolToInt(IsEqual(t[show].Direction,DirectionUp),clrLawnGreen,clrRed));
      UpdateRay(indObjectStr+"lnS_Retrace:"+EnumToString(show),inpPeriods,t[show].Fractal[fpRetrace],-8,0);
      UpdateRay(indObjectStr+"lnS_Recovery:"+EnumToString(show),inpPeriods,t[show].Fractal[fpRecovery],-8,0);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        UpdateRay(indObjectStr+"lnS_"+EnumToString(fibo)+":"+EnumToString(show),inpPeriods,t.Price(fibo,show,Extension),-8,0,Color(t[show].Direction,IN_DARK_DIR));
        UpdateText(indObjectStr+"lnT_"+EnumToString(fibo)+":"+EnumToString(show),"",t.Price(fibo,show,Extension),-5,Color(t[show].Direction,IN_DARK_DIR));
      }

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        UpdateText(indObjectStr+"lnT_"+fp[point]+":"+EnumToString(show),"",t[show].Fractal[point],-7);
    }

    //-- General
    UpdateLabel("Clock",TimeToStr(TimeCurrent()),clrDodgerBlue,16);
    UpdateLabel("Price",Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);


    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
    {
      Append(text,"------- Fibonacci ["+EnumToString(type)+"] ------------------------","\n\n");
      Append(text," "+DirText(t[type].Direction),"\n");
      Append(text,EnumToString(t[type].State));
      Append(text,"["+ActionText(t[type].Pivot.Lead)+"]");
      Append(text,BoolToStr(IsEqual(t[type].Pivot.Bias,t[type].Pivot.Lead),"","Hedge"));
      Append(text,BoolToStr(IsEqual(t[type].Event,NoEvent),""," **"+EventText(t[type].Event)));
      Append(text,FibonacciStr("   Ext: ",t[type].Extension),"\n");
      Append(text,FibonacciStr("   Ret: ",t[type].Retrace),"\n");
    }

    Append(text,t.ActiveEventStr(),"\n\n");

    if (inpShowComment==Yes)
      Comment(text);
  }

//+------------------------------------------------------------------+
//| UpdateTickMA - refreshes indicator data                          |
//+------------------------------------------------------------------+
void UpdateTickMA(void)
  {
    t.Update();
    t.Fractal(plFractalBuffer);

    if (printevent)
      if (t.ActiveEvent())
        Print("|"+TimeToString(TimeCurrent())+"|"+t.EventStr(NoEvent,EventTypes));
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
    SetIndexBuffer(0,plFractalBuffer);
    SetIndexEmptyValue(0,0.00);
    SetIndexLabel (0,""); 

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

    //-- Clock & Price
    NewLabel("Clock","",10,5,clrDarkGray,SCREEN_LR,indWinId);
    NewLabel("Price","",10,30,clrDarkGray,SCREEN_LR,indWinId);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
  }