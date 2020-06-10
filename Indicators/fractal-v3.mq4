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
input string fractalHeader     = "";     //+----- Fractal inputs -----+
input int    inpRange          = 120;    // Maximum fractal pip range
input int    inpRangeMin       = 60;     // Minimum fractal pip range
input bool   inpShowComment    = false;  // Display data
input bool   inpShowLines      = false;  // Display fractal price lines
input bool   inpShowFibo       = false;  // Display Fibonacci lines
input bool   inpShowPoints     = false;  // Display Fractal points


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


CFractal  *fractal            = new CFractal(inpRange,inpRangeMin);

double    indFractalBuffer[];
double    indDivergentBuffer[];
double    indConvergentBuffer[];

//+------------------------------------------------------------------+
//| RefreshFibo - Update fibo objects                                |
//+------------------------------------------------------------------+
void RefreshFibo(void)
  {
    ObjectSet("fFiboRetrace",OBJPROP_TIME1,Time[fractal[Root].Bar]);
    ObjectSet("fFiboRetrace",OBJPROP_PRICE1,fractal[Root].Price);
    ObjectSet("fFiboRetrace",OBJPROP_TIME2,Time[fractal[Expansion].Bar]);
    ObjectSet("fFiboRetrace",OBJPROP_PRICE2,fractal[Expansion].Price);

    if (fractal.IsMajor(Divergent))
    {
      ObjectSet("fFiboExpansion",OBJPROP_TIME1,Time[fractal[Expansion].Bar]);
      ObjectSet("fFiboExpansion",OBJPROP_PRICE1,fractal[Expansion].Price);
      ObjectSet("fFiboExpansion",OBJPROP_TIME2,Time[fractal[Divergent].Bar]);
      ObjectSet("fFiboExpansion",OBJPROP_PRICE2,fractal[Divergent].Price);
    }
    else
    {
      ObjectSet("fFiboExpansion",OBJPROP_TIME1,Time[fractal[Base].Bar]);
      ObjectSet("fFiboExpansion",OBJPROP_PRICE1,fractal[Base].Price);
      ObjectSet("fFiboExpansion",OBJPROP_TIME2,Time[fractal[Root].Bar]);
      ObjectSet("fFiboExpansion",OBJPROP_PRICE2,fractal[Root].Price);
    }
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen - Repaints screen objects, data                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static FibonacciLevel expand[3]  = {Fibo161,Fibo161,Fibo61};
    static int expdir[3]  = {DirectionNone,DirectionNone,DirectionNone};
    
    if (IsChanged(expdir[2],fractal.Direction(Base)))
      expand[2]                 = Fibo161;
      
    if (FiboLevels[expand[2]]<fractal.Fibonacci(Base,Expansion,Now))
    {
      Flag(EnumToString(expand[2]),clrWhite);
      expand[2]++;
    }

    for (RetraceType fibo=Trend;fibo<=Term;fibo++)
    {
      if (IsChanged(expdir[fibo],fractal.Direction(fibo)))
      {
        expand[fibo]            = Fibo161;
        
        if (fibo==Trend)
          NewArrow(BoolToInt(fractal.Direction(Trend)==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),Color(fractal.Direction(Trend),IN_CHART_DIR));
      }
        
      if (FiboLevels[expand[fibo]]<fractal.Fibonacci(fibo,Expansion,Now))
      {
        Flag(EnumToString(expand[fibo]),BoolToInt(fibo==Trend,clrYellow,clrGoldenrod));
        expand[fibo]++;
      }
    }   
      
    if (inpShowComment)
      fractal.RefreshScreen();
    
    if (fractal.IsMajor(Divergent))
      SetIndexStyle(1,DRAW_SECTION,STYLE_SOLID);
    else
    if (fractal.IsMinor(Divergent))
      SetIndexStyle(1,DRAW_SECTION,STYLE_DASHDOTDOT);
    else
      SetIndexStyle(1,DRAW_SECTION,STYLE_DOT);
      
    if (fractal.IsMajor(Convergent))
      SetIndexStyle(2,DRAW_SECTION,STYLE_SOLID);      
    else
    if (fractal.IsMinor(Convergent))
      SetIndexStyle(2,DRAW_SECTION,STYLE_DASHDOTDOT);      
    else
      SetIndexStyle(2,DRAW_SECTION,STYLE_DOT);
                
    if (inpShowLines)
    {
      UpdateLine("fOriginTop",fractal.Price(Origin,Top),STYLE_SOLID,clrWhite);
      UpdateLine("fOriginBottom",fractal.Price(Origin,Bottom),STYLE_DOT,clrWhite);

      UpdateLine("fExpansion",fractal[Expansion].Price,STYLE_SOLID,clrMaroon);
      UpdateLine("fDivergent",fractal[Divergent].Price,STYLE_DOT,clrMaroon);
      UpdateLine("fConvergent",fractal[Convergent].Price,STYLE_DOT,clrGoldenrod);
      UpdateLine("fInversion",fractal[Inversion].Price,STYLE_DOT,clrSteelBlue);
      UpdateLine("fConversion",fractal[Conversion].Price,STYLE_DOT,clrDarkGray);
      UpdateLine("fRetrace",fractal.Price(fractal.State(),Next),STYLE_SOLID,clrWhite);
    }
    
    if (inpShowPoints)
    {
      UpdatePriceTag("ptExpansion",fractal[Expansion].Bar,fractal[Expansion].Direction);
      UpdatePriceTag("ptRoot",fractal[Root].Bar,fractal[Root].Direction);
      UpdatePriceTag("ptBase",fractal[Base].Bar,fractal[Base].Direction);
      UpdatePriceTag("ptPrior",fractal[Prior].Bar,fractal[Prior].Direction);
      UpdatePriceTag("ptTerm",fractal[Term].Bar,fractal[Term].Direction);
      UpdatePriceTag("ptTrend",fractal[Trend].Bar,fractal[Trend].Direction);
      UpdatePriceTag("ptOrigin",fractal.Origin(Bar),fractal[Expansion].Direction);
    }
    
    if (inpShowFibo)
      RefreshFibo();
  }
  
//+------------------------------------------------------------------+
//| SetBuffer - sets the retrace/inversion buffer values             |
//+------------------------------------------------------------------+
void SetBuffer(double &Buffer[], RetraceType Start, RetraceType End)
  {
    ArrayInitialize(Buffer,0.00);

    if (fractal[Start].Bar>NoValue && fractal[End].Bar>NoValue)
    {
      Buffer[fractal[Start].Bar] = fractal[Start].Price;
      Buffer[fractal[End].Bar]   = fractal[End].Price;
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
    fractal.UpdateBuffer(indFractalBuffer);

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
    SetIndexBuffer(0,indFractalBuffer);
    SetIndexEmptyValue(0,0.00);
    ArrayInitialize(indFractalBuffer,0.00);
    
    SetIndexBuffer(1,indDivergentBuffer);
    SetIndexEmptyValue(1,0.00);
    ArrayInitialize(indDivergentBuffer,0.00);

    SetIndexBuffer(2,indConvergentBuffer);
    SetIndexEmptyValue(2,0.00);
    ArrayInitialize(indConvergentBuffer,0.00);

    if (inpShowLines)
    {
      NewLine("fOriginTop");
      NewLine("fOriginBottom");

      NewLine("fExpansion");
      NewLine("fDivergent");
      NewLine("fConvergent");
      NewLine("fInversion");
      NewLine("fConversion");
      NewLine("fRetrace");
    }
   
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

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    delete fractal;
    
    ObjectDelete("fOriginTop");
    ObjectDelete("fOriginBottom");

    ObjectDelete("fExpansion");
    ObjectDelete("fConvergent");
    ObjectDelete("fDivergent");
    ObjectDelete("fInversion");
    ObjectDelete("fConversion");
    ObjectDelete("fRetrace");
    
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