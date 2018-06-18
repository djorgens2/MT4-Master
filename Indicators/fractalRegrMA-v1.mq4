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
#include <Class\Fractal.mqh>
#include <Class\TrendRegression.mqh>

//--- Input params
input string fractalHeader     = "";     //+----- Fractal inputs -----+
input int    inpRange          = 480;    // Maximum fractal pip range
input int    inpRangeMin       = 240;     // Minimum fractal pip range
input bool   inpShowComment    = true;  // Display data
input bool   inpShowLines      = false;  // Display fractal price lines
input bool   inpShowFibo       = false;  // Display Fibonacci lines
input bool   inpShowPoints     = true;  // Display Fractal points


#property indicator_buffers   9
#property indicator_plots     9


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

//--- plot poly
#property indicator_label4    "indPolyRoot"
#property indicator_type4     DRAW_LINE
#property indicator_color4    clrFireBrick
#property indicator_style4    STYLE_SOLID
#property indicator_width4    1

//--- plot trend
#property indicator_label5    "indTrendRoot"
#property indicator_type5     DRAW_LINE
#property indicator_color5    clrFireBrick
#property indicator_style5    STYLE_SOLID
#property indicator_width5    1

//--- plot trend
#property indicator_label6    "indPolyDivergent"
#property indicator_type6     DRAW_LINE
#property indicator_color6    clrGoldenrod
#property indicator_style6    STYLE_SOLID
#property indicator_width6    1

//--- plot trend
#property indicator_label7    "indTrendDivergent"
#property indicator_type7     DRAW_LINE
#property indicator_color7    clrGoldenrod
#property indicator_style7    STYLE_SOLID
#property indicator_width7    1

//--- plot trend
#property indicator_label8    "indPolyConvergent"
#property indicator_type8     DRAW_LINE
#property indicator_color8    clrLawnGreen
#property indicator_style8    STYLE_SOLID
#property indicator_width8    1

//--- plot trend
#property indicator_label9    "indTrendConvergent"
#property indicator_type9     DRAW_LINE
#property indicator_color9    clrLawnGreen
#property indicator_style9    STYLE_SOLID
#property indicator_width9    1

CFractal         *fractal     = new CFractal(inpRange,inpRangeMin);

CTrendRegression *rootTR;
CTrendRegression *divergentTR;
CTrendRegression *convergentTR;

double    indFractalBuffer[];
double    indDivergentBuffer[];
double    indConvergentBuffer[];

double    indPolyRootBuffer[];
double    indTrendRootBuffer[];

double    indPolyDivergentBuffer[];
double    indTrendDivergentBuffer[];

double    indPolyConvergentBuffer[];
double    indTrendConvergentBuffer[];

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
//| SetRegrMABuffers - sets the regrMA buffer values                 |
//+------------------------------------------------------------------+
void SetRegrMABuffers(void)
  {
    delete rootTR;
    delete divergentTR;
    
    ArrayInitialize(indTrendRootBuffer,0.00);
    ArrayInitialize(indPolyRootBuffer,0.00);

    ArrayInitialize(indTrendDivergentBuffer,0.00);
    ArrayInitialize(indPolyDivergentBuffer,0.00);

    ArrayInitialize(indTrendConvergentBuffer,0.00);
    ArrayInitialize(indPolyConvergentBuffer,0.00);

    rootTR          = new CTrendRegression(6,fractal[Root].Bar+1,3);
    divergentTR     = new CTrendRegression(6,fractal[Expansion].Bar+1,3);
    convergentTR    = new CTrendRegression(6,fractal[Divergent].Bar+1,3);

    rootTR.UpdateBuffer(indPolyRootBuffer,indTrendRootBuffer);

    if (fractal.IsDivergent())
      divergentTR.UpdateBuffer(indPolyDivergentBuffer,indTrendDivergentBuffer);

    if (fractal.IsConvergent())
      convergentTR.UpdateBuffer(indPolyConvergentBuffer,indTrendConvergentBuffer);
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
    if (prev_calculated>0)
    {
      fractal.UpdateBuffer(indFractalBuffer);
          
      SetBuffer(indDivergentBuffer,Expansion,Divergent);
      SetBuffer(indConvergentBuffer,Divergent,Convergent);
      
      SetRegrMABuffers();

      RefreshScreen();
    }
    
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

    SetIndexBuffer(3,indPolyRootBuffer);
    SetIndexEmptyValue(3,0.00);
    ArrayInitialize(indPolyRootBuffer,0.00);

    SetIndexBuffer(4,indTrendRootBuffer);
    SetIndexEmptyValue(4,0.00);
    ArrayInitialize(indTrendRootBuffer,0.00);

    SetIndexBuffer(5,indPolyDivergentBuffer);
    SetIndexEmptyValue(5,0.00);
    ArrayInitialize(indPolyDivergentBuffer,0.00);

    SetIndexBuffer(6,indTrendDivergentBuffer);
    SetIndexEmptyValue(6,0.00);
    ArrayInitialize(indTrendDivergentBuffer,0.00);

    SetIndexBuffer(7,indPolyConvergentBuffer);
    SetIndexEmptyValue(7,0.00);
    ArrayInitialize(indPolyDivergentBuffer,0.00);

    SetIndexBuffer(8,indTrendConvergentBuffer);
    SetIndexEmptyValue(8,0.00);
    ArrayInitialize(indTrendConvergentBuffer,0.00);

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

    Comment("");
  }