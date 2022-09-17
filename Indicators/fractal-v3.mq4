//+------------------------------------------------------------------+
//|                                                   fractal-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <std_utility.mqh>
#include <stdutil.mqh>
#include <Class\Fractal.mqh>

//--- Input params
input string      fractalHeader     = "";           //+----- Fractal inputs -----+
input int         inpRange          = 120;          // Maximum fractal pip range
input int         inpRangeMin       = 60;           // Minimum fractal pip range
input bool        inpShowComment    = false;        // Show data in comment
input bool        inpShowFibo       = false;        // Show Fibonacci Indicators
input bool        inpShowPoints     = false;        // Show Fractal points
input bool        inpShowFlags      = false;        // Show Fibonacci Events
input bool        inpShowExpEvents  = false;        // Show Expansion Events
input FractalType inpShowTypeLines  = FractalTypes; // Show Fibonacci Lines by Type
input int         inpUpOffset       = 12;           // Upper tag offset
input int         inpDownOffset     = 8;            // Lower tag offset


#property indicator_buffers   3
#property indicator_plots     3


//--- plot poly Major
#property indicator_label1    "indFractal"
#property indicator_type1     DRAW_SECTION
#property indicator_color1    clrFireBrick
#property indicator_style1    STYLE_SOLID
#property indicator_width1    1

//--- plot poly Divergent
#property indicator_label2    "indDivergent"
#property indicator_type2     DRAW_SECTION
#property indicator_color2    clrGoldenrod
#property indicator_style2    STYLE_SOLID
#property indicator_width2    1

//--- plot poly Convergent
#property indicator_label3    "indConvergent"
#property indicator_type3     DRAW_SECTION
#property indicator_color3    clrSteelBlue
#property indicator_style3    STYLE_SOLID
#property indicator_width3    1


CFractal  *f                = new CFractal(inpRange,inpRangeMin,inpShowFlags);

double    indFractalBuffer[];
double    indDivergentBuffer[];
double    indConvergentBuffer[];

//+------------------------------------------------------------------+
//| RefreshFibo - Update fibo objects                                |
//+------------------------------------------------------------------+
void RefreshFibo(void)
  {
    ObjectSet("fFiboRetrace",OBJPROP_TIME1,Time[f[Root].Bar]);
    ObjectSet("fFiboRetrace",OBJPROP_PRICE1,f[Root].Price);
    ObjectSet("fFiboRetrace",OBJPROP_TIME2,Time[f[Expansion].Bar]);
    ObjectSet("fFiboRetrace",OBJPROP_PRICE2,f[Expansion].Price);

    if (f.Is(Divergent,Max))
    {
      ObjectSet("fFiboExpansion",OBJPROP_TIME1,Time[f[Expansion].Bar]);
      ObjectSet("fFiboExpansion",OBJPROP_PRICE1,f[Expansion].Price);
      ObjectSet("fFiboExpansion",OBJPROP_TIME2,Time[f[Divergent].Bar]);
      ObjectSet("fFiboExpansion",OBJPROP_PRICE2,f[Divergent].Price);
    }
    else
    {
      ObjectSet("fFiboExpansion",OBJPROP_TIME1,Time[f[Base].Bar]);
      ObjectSet("fFiboExpansion",OBJPROP_PRICE1,f[Base].Price);
      ObjectSet("fFiboExpansion",OBJPROP_TIME2,Time[f[Root].Bar]);
      ObjectSet("fFiboExpansion",OBJPROP_PRICE2,f[Root].Price);
    }
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen - Repaints screen objects, data                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    const color rsFlagColor[5]  = {clrDarkOrange,clrGoldenrod,clrIndianRed,clrNONE,clrGray};

    if (inpShowExpEvents)
      if (f.Event(NewFibonacci))
        for (FractalType type=Origin;type<Root;type++)
          if (f[type].Event==NewFibonacci)
            Flag("[fr3]"+EnumToString(type)+" "+EnumToString(f.EventFibo(type)),rsFlagColor[type],0,f.Forecast(type,Expansion,f.EventFibo(type)),inpShowFlags);

    if (inpShowComment)
      f.RefreshScreen(Always);
    
    SetIndexStyle(1,DRAW_SECTION,BoolToInt(f.Is(Divergent,Max),STYLE_SOLID,BoolToInt(f.Is(Divergent,Min),STYLE_DASHDOTDOT,STYLE_DOT)));
    SetIndexStyle(2,DRAW_SECTION,BoolToInt(f.Is(Convergent,Max),STYLE_SOLID,BoolToInt(f.Is(Convergent,Min),STYLE_DASHDOTDOT,STYLE_DOT)));

    if (inpShowPoints)
    {
      UpdatePriceTag("ptExpansion",f[Expansion].Bar,f[Expansion].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptRoot",f[Root].Bar,f[Root].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptBase",f[Base].Bar,f[Base].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptPrior",f[Prior].Bar,f[Prior].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptTerm",f[Term].Bar,f[Term].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptTrend",f[Trend].Bar,f[Trend].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptOrigin",f[Origin].Bar,f[Expansion].Direction,inpUpOffset,inpDownOffset);
    }
    
    if (inpShowFibo)
      RefreshFibo();

    if (inpShowTypeLines==FractalTypes)
      return;

    FractalType Type   = (FractalType)inpShowTypeLines;
    
    UpdateLine("ftl:fpOrigin",f.Price(Type,fpOrigin),STYLE_SOLID,clrWhite);
    UpdateLine("ftl:fpBase",f.Price(Type,fpBase),STYLE_DOT,clrWhite);
    UpdateLine("ftl:fpRoot",f.Price(Type,fpRoot),STYLE_DOT,clrWhite);
    UpdateLine("ftl:fpExpansion",f.Price(Type,fpExpansion),STYLE_SOLID,clrMaroon);
    UpdateLine("ftl:fpRetrace",f.Price(Type,fpRetrace),STYLE_SOLID,clrGoldenrod);
    UpdateLine("ftl:fpRecovery",f.Price(Type,fpRecovery),STYLE_SOLID,clrSteelBlue);
  }
  
//+------------------------------------------------------------------+
//| SetBuffer - sets the retrace/inversion buffer values             |
//+------------------------------------------------------------------+
void SetBuffer(double &Buffer[], FractalType Start, FractalType End)
  {
    ArrayInitialize(Buffer,0.00);

    if (f[Start].Bar>NoValue && f[End].Bar>NoValue)
    {
      Buffer[f[Start].Bar] = f[Start].Price;
      Buffer[f[End].Bar]   = f[End].Price;
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
    f.UpdateBuffer(indFractalBuffer);

    SetBuffer(indDivergentBuffer,Expansion,Divergent);
    SetBuffer(indConvergentBuffer,Divergent,Convergent);

    RefreshScreen();

    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    f.Update();
    
    SetIndexBuffer(0,indFractalBuffer);
    SetIndexEmptyValue(0,0.00);
    ArrayInitialize(indFractalBuffer,0.00);
    
    SetIndexBuffer(1,indDivergentBuffer);
    SetIndexEmptyValue(1,0.00);
    ArrayInitialize(indDivergentBuffer,0.00);

    SetIndexBuffer(2,indConvergentBuffer);
    SetIndexEmptyValue(2,0.00);
    ArrayInitialize(indConvergentBuffer,0.00);

    if (inpShowPoints)
    {
      NewPriceTag("ptExpansion","(e)",clrRed,12);
      NewPriceTag("ptRoot","(r)",clrRed,12);
      NewPriceTag("ptBase","(b)",clrRed,12);
      NewPriceTag("ptPrior","(p)",clrRed,12);
      NewPriceTag("ptTerm","(tm)",clrRed,12);
      NewPriceTag("ptTrend","(tr)",clrRed,12);
      NewPriceTag("ptOrigin","(o)",clrRed,12);
    } 
   
    if (inpShowFibo)
    {
      ObjectCreate("fFiboRetrace",OBJ_FIBO,0,0,0);
      ObjectSet("fFiboRetrace",OBJPROP_LEVELCOLOR,clrMaroon);
     
      ObjectCreate("fFiboExpansion",OBJ_FIBO,0,0,0);
      ObjectSet("fFiboExpansion",OBJPROP_LEVELCOLOR,clrForestGreen);
    }

    if (inpShowTypeLines!=FractalTypes)
      for (FractalPoint type=fpOrigin;type<FractalPoints;type++)
        NewLine("ftl:"+EnumToString(type));

    return(INIT_SUCCEEDED);    
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    delete f;
    
    for (FractalPoint type=fpOrigin;type<FractalPoints;type++)
      ObjectDelete("ftl:"+EnumToString(type));

    ObjectDelete("ptExpansion");
    ObjectDelete("ptRoot");
    ObjectDelete("ptBase");
    ObjectDelete("ptPrior");
    ObjectDelete("ptTerm");
    ObjectDelete("ptTrend");
    ObjectDelete("ptOrigin");

    ObjectDelete("fFiboRetrace");
    ObjectDelete("fFiboExpansion");

    Comment("");
  }