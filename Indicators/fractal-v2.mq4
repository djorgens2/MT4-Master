//+------------------------------------------------------------------+
//|                                                   fractal-v2.mq4 |
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

#property indicator_buffers   3
#property indicator_plots     3


//--- plot poly
#property indicator_label1    "indFractal"
#property indicator_type1     DRAW_SECTION
#property indicator_color1    clrFireBrick
#property indicator_style1    STYLE_SOLID
#property indicator_width1    1

//--- plot poly
#property indicator_label2    "indDivergent"
#property indicator_type2     DRAW_SECTION
#property indicator_color2    clrGoldenrod
#property indicator_style2    STYLE_SOLID
#property indicator_width2    1
//--- plot poly
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
//| SetBuffer - sets the retrace/inversion buffer values             |
//+------------------------------------------------------------------+
void SetBuffer(double &Buffer[], int HighBar, int LowBar)
  {
    ArrayInitialize(Buffer,0.00);

    if (HighBar != OP_NO_ACTION && LowBar != OP_NO_ACTION)
    {
      Buffer[HighBar] = High[HighBar];
      Buffer[LowBar]  = Low[LowBar];
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
          
      if (fractal.Direction() == DirectionUp)
      {
        SetBuffer(indDivergentBuffer,fractal.Bar(Root),fractal.Bar(Expansion));
        SetBuffer(indConvergentBuffer,fractal.Bar(Retrace),fractal.Bar(Expansion));
      }
       
      if (fractal.Direction() == DirectionDown)
      {
        SetBuffer(indDivergentBuffer,fractal.Bar(Expansion),fractal.Bar(Root));
        SetBuffer(indConvergentBuffer,fractal.Bar(Expansion),fractal.Bar(Retrace));
      }

      RefreshScreen();
    }
    
    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string report    = "";

    report      += "Trend Retraces: st:("+fractal.Text(Term)+" "+DoubleToStr(fractal.FiboRetrace(Term,InMax,InInteger),1)+"% "+DoubleToStr(fractal.FiboRetrace(Term,InNow,InInteger),1)+"%)"+
                                  " lt:("+fractal.Text(Trend)+" "+DoubleToStr(fractal.FiboRetrace(Trend,InMax,InInteger),1)+"% "+DoubleToStr(fractal.FiboRetrace(Trend,InNow,InInteger),1)+"%)\n";

    report      += "Internal Retraces: r:("+DoubleToStr(fractal.FiboRetrace(Root,InMax,InInteger),1)+"% "+DoubleToStr(fractal.FiboRetrace(Root,InNow,InInteger),1)+"%)"+
                                     " d:("+DoubleToStr(fractal.FiboRetrace(Divergent,InMax,InInteger),1)+"% "+DoubleToStr(fractal.FiboRetrace(Divergent,InNow,InInteger),1)+"%)"+
                                     " c:("+DoubleToStr(fractal.FiboRetrace(Convergent,InMax,InInteger),1)+"% "+DoubleToStr(fractal.FiboRetrace(Convergent,InNow,InInteger),1)+"%)\n";
    report      += "Fibo Expansions: a:("+DoubleToStr(fractal.FiboExpansion(Active,InMax,InInteger),1)+"% "+DoubleToStr(fractal.FiboExpansion(Active,InNow,InInteger),1)+"%)"+
                                   " r:("+DoubleToStr(fractal.FiboExpansion(Root,InMax,InInteger),1)+"% "+DoubleToStr(fractal.FiboExpansion(Root,InNow,InInteger),1)+"%)"+
                                   " b:("+DoubleToStr(fractal.FiboExpansion(Base,InMax,InInteger),1)+"% "+DoubleToStr(fractal.FiboExpansion(Base,InNow,InInteger),1)+"%)\n";
    report      += "State Direction: "+fractal.Text(StateTrend)+
                       "  Prices: b:"+DoubleToStr(fractal.StatePrice(StateBase),Digits)
                               +" r:"+DoubleToStr(fractal.StatePrice(StateRoot),Digits)
                               +" x:"+DoubleToStr(fractal.StatePrice(StateExpansion),Digits)
                               +" rt:"+DoubleToStr(fractal.StatePrice(StateRetrace),Digits)
                               +"  Retrace ("+DoubleToStr(fractal.StatePrice(StateRetracePctMax)*100,1)+"%"
                               +" "+DoubleToStr(fractal.StatePrice(StateRetracePctNow)*100,1)+"%)\n";
    report      += fractal.Text(StateTerm)+" Pivot Retrace: b: "+DoubleToStr(fractal.PivotPrice(Base),Digits)
                                          +" r: "+DoubleToStr(fractal.PivotPrice(Expansion),Digits)
                                          +" "+DoubleToString(fractal.PivotPrice(Retrace)*100,1)+"%\n";
    
    Comment(report);

    if (fractal.IsPegged())
      SetIndexStyle(1,DRAW_SECTION,STYLE_SOLID);
    else
      SetIndexStyle(1,DRAW_SECTION,STYLE_DOT);
      
    if (fractal.IsConvergent())
      SetIndexStyle(2,DRAW_SECTION,STYLE_SOLID);      
    else
      SetIndexStyle(2,DRAW_SECTION,STYLE_DOT);
                
    //--- Update Fibo Lines
    UpdateLine("fDivergent",fractal.PivotPrice(Divergent),STYLE_SOLID,DirColor(dir(Close[0]-fractal.PivotPrice(Divergent)),clrForestGreen,clrMaroon));
    UpdateLine("fConvergent",fractal.PivotPrice(Convergent),STYLE_SOLID,DirColor(dir(Close[0]-fractal.PivotPrice(Convergent)),clrForestGreen,clrMaroon));

    UpdateLine("rDivergent",fractal.RetracePrice(Divergent),STYLE_DOT,clrMaroon);
    UpdateLine("rConvergent",fractal.RetracePrice(Convergent),STYLE_DOT,clrGoldenrod);
    UpdateLine("rInversion",fractal.RetracePrice(Inversion),STYLE_DOT,clrSteelBlue);
    UpdateLine("rActive",fractal.RetracePrice(Active),STYLE_DOT,clrDarkGray);
    
    if (fractal.Direction() == DirectionUp)
    {
      UpdatePriceLabel("BaseBar",Low[fractal.Bar(Base)],clrWhite,fractal.Bar(Base));
      UpdatePriceLabel("RootBar",High[fractal.Bar(Root)],clrWhite,fractal.Bar(Root));
      UpdatePriceLabel("ExpansionBar",Low[fractal.Bar(Expansion)],clrWhite,fractal.Bar(Expansion));
      UpdatePriceLabel("RetraceBar",High[fractal.Bar(Retrace)],clrWhite,fractal.Bar(Retrace));
    }
    else
    {
      UpdatePriceLabel("BaseBar",High[fractal.Bar(Base)],clrWhite,fractal.Bar(Base));
      UpdatePriceLabel("RootBar",Low[fractal.Bar(Root)],clrWhite,fractal.Bar(Root));
      UpdatePriceLabel("ExpansionBar",High[fractal.Bar(Expansion)],clrWhite,fractal.Bar(Expansion));
      UpdatePriceLabel("RetraceBar",Low[fractal.Bar(Retrace)],clrWhite,fractal.Bar(Retrace));
    }
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

    NewLine("fDivergent");
    NewLine("fConvergent");
    
    NewLine("rDivergent");
    NewLine("rConvergent");
    NewLine("rInversion");
    NewLine("rActive");
    
    NewPriceLabel("BaseBar");
    NewPriceLabel("RootBar");
    NewPriceLabel("ExpansionBar");
    NewPriceLabel("RetraceBar");
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    delete fractal;
    
    ObjectDelete("fDivergent");
    ObjectDelete("fConvergent");
        
    ObjectDelete("rConvergent");
    ObjectDelete("rDivergent");
    ObjectDelete("rActive");
    ObjectDelete("rInversion");

    ObjectDelete("BaseBar");
    ObjectDelete("RootBar");
    ObjectDelete("ExpansionBar");
    ObjectDelete("RetraceBar");
    
    Comment("");
  }