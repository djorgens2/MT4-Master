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
input bool        inpShowRootLines  = false;        // Show Modified Root Lines
input RetraceType inpShowTypeLines  = RetraceTypes; // Show Fibonacci Lines by Type
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

    if (fractal.IsRange(Divergent))
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
    if (inpShowFlags)
    {
      static FibonacciLevel expand[4]  = {Fibo161,Fibo161,Fibo161,Fibo161};
    
      if (fractal.IsRange(Divergent))
        ArrayInitialize(expand,Fibo161);
      else
      {
        //--Origin Fibo Flags
        if (FiboLevels[expand[3]]<fractal.Fibonacci(Origin,fpExpansion,Now))
        {
          Flag("Origin "+EnumToString(expand[3]),clrRed);
          expand[3]++;
        }

        //-- Base Fibo Flags
        if (FiboLevels[expand[2]]<fractal.Fibonacci(Base,fpExpansion,Now))
        {
          Flag("Base "+EnumToString(expand[2]),clrGray);
          expand[2]++;
        }

        //-- Trend/Term Fibo Flags
        for (RetraceType fibo=Trend;fibo<=Term;fibo++)
          if (FiboLevels[expand[fibo]]<fractal.Fibonacci(fibo,fpExpansion,Now))
          {
            Flag(EnumToString(fibo)+" "+EnumToString(expand[fibo]),BoolToInt(fibo==Trend,clrYellow,clrGoldenrod));
            expand[fibo]++;
          }
      }
    }
      
    if (inpShowComment)
      fractal.RefreshScreen();
    
    if (fractal.IsRange(Divergent,Max))
      SetIndexStyle(1,DRAW_SECTION,STYLE_SOLID);
    else
    if (fractal.IsRange(Divergent,Min))
      SetIndexStyle(1,DRAW_SECTION,STYLE_DASHDOTDOT);
    else
      SetIndexStyle(1,DRAW_SECTION,STYLE_DOT);
      
    if (fractal.IsRange(Convergent,Max))
      SetIndexStyle(2,DRAW_SECTION,STYLE_SOLID);      
    else
    if (fractal.IsRange(Convergent,Min))
      SetIndexStyle(2,DRAW_SECTION,STYLE_DASHDOTDOT);      
    else
      SetIndexStyle(2,DRAW_SECTION,STYLE_DOT);

    if (inpShowPoints)
    {
      UpdatePriceTag("ptExpansion",fractal[Expansion].Bar,fractal[Expansion].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptRoot",fractal[Root].Bar,fractal[Root].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptBase",fractal[Base].Bar,fractal[Base].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptPrior",fractal[Prior].Bar,fractal[Prior].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptTerm",fractal[Term].Bar,fractal[Term].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptTrend",fractal[Trend].Bar,fractal[Trend].Direction,inpUpOffset,inpDownOffset);
      UpdatePriceTag("ptOrigin",fractal.Origin().Bar,fractal[Expansion].Direction,inpUpOffset,inpDownOffset);
    }
    
    if (inpShowFibo)
      RefreshFibo();

    if (inpShowRootLines)
      for (RetraceType type=Trend;type<RetraceTypes;type++)
        UpdateLine("modRL:"+EnumToString(type),fractal[type].modRoot,STYLE_DOT,clrFireBrick);
      
    if (inpShowTypeLines==RetraceTypes)
      return;

    RetraceType Type   = (RetraceType)inpShowTypeLines;
    UpdateLine("ftl:fpOrigin",fractal.Price(Type,fpOrigin),STYLE_SOLID,Color(fractal.Direction(Type)));
    UpdateLine("ftl:fpBase",fractal.Price(Type,fpBase),STYLE_DOT,clrWhite);
    UpdateLine("ftl:fpRoot",fractal.Price(Type,fpRoot),STYLE_SOLID,clrWhite);
    UpdateLine("ftl:fpExpansion",fractal.Price(Type,fpExpansion),STYLE_SOLID,clrMaroon);
    UpdateLine("ftl:fpRetrace",fractal.Price(Type,fpRetrace),STYLE_SOLID,clrGoldenrod);
    UpdateLine("ftl:fpRecovery",fractal.Price(Type,fpRecovery),STYLE_SOLID,clrSteelBlue);        
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
    fractal.Update();
    
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

    if (inpShowTypeLines!=RetraceTypes)
      for (FractalPoint type=fpOrigin;type<FractalPoints;type++)
        NewLine("ftl:"+EnumToString(type));

    if (inpShowRootLines)
      for (RetraceType type=Trend;type<RetraceTypes;type++)
        NewLine("modRL:"+EnumToString(type));

//    DrawBox("bxbClear",402,5,20,20,C'90,90,90',BORDER_SUNKEN);
//    DrawBox("bxbOrigin",424,5,60,20,C'90,90,90',BORDER_RAISED);
//    
//    ObjectDelete("bxfFractalInfo");
//    DrawBox("bxfFractalInfo",400,28,400,200,C'0,0,60',BORDER_FLAT);
//    ObjectSet("bxfFractalInfo",OBJPROP_BACK,false);
//    ObjectSet("bxfFractalInfo",OBJPROP_ZORDER,0);
//    ObjectSet("bxfFractalInfo",OBJ_RECTANGLE_LABEL,0);
//
//    NewLabel("lbbFOrigin","",440,7);
//    ObjectSet("lbbFOrigin",OBJPROP_ZORDER,1);
//    ObjectSet("lbbFOrigin",OBJPROP_,false);
//    UpdateLabel("lbbFOrigin","Origin",clrWhite);
    return(INIT_SUCCEEDED);    
  }


//+------------------------------------------------------------------+
//| ChartEvent                                                       |
//+------------------------------------------------------------------+
//void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
//  {
//    static string oceOption   = "bxbClear";
//    
//    if (id==CHARTEVENT_OBJECT_CLICK)
//    {
//      if (sparam=="bxbClear")
//      {
//        ObjectSet("bxfFractalInfo",OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);
//        ObjectSet(sparam,OBJPROP_BORDER_TYPE,BORDER_SUNKEN);
//        ObjectSet(oceOption,OBJPROP_BORDER_TYPE,BORDER_RAISED);
//        
//        oceOption   = sparam;
//      }
//
//      if (StringSubstr(sparam,3)=="Origin")
//      {
//      Print(sparam+":"+StringSubstr(sparam,3));
//        ObjectSet("bxfFractalInfo",OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
//        ObjectSet(sparam,OBJPROP_BORDER_TYPE,BORDER_SUNKEN);
//        ObjectSet(oceOption,OBJPROP_BORDER_TYPE,BORDER_RAISED);
//        
//        oceOption   = sparam;
//      }
//    }
//  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    delete fractal;
    
    for (RetraceType type=Trend;type<RetraceTypes;type++)
      ObjectDelete("modRL:"+EnumToString(type));

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