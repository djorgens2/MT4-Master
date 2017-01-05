//+------------------------------------------------------------------+
//|                                                   fractal-v1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <std_utility.mqh>
#include <stdutil.mqh>

#property indicator_buffers   3
#property indicator_plots     3


//--- plot poly
#property indicator_label1    "indFractal"
#property indicator_type1     DRAW_SECTION
#property indicator_color1    clrFireBrick
#property indicator_style1    STYLE_SOLID
#property indicator_width1    1

//--- plot poly
#property indicator_label2    "indHighBar"
#property indicator_type2     DRAW_SECTION
#property indicator_color2    clrGoldenrod
#property indicator_style2    STYLE_SOLID
#property indicator_width2    1
//--- plot poly
#property indicator_label3    "indLowBar"
#property indicator_type3     DRAW_SECTION
#property indicator_color3    clrSteelBlue
#property indicator_style3    STYLE_SOLID
#property indicator_width3    1


//--- Input params
input int    inpRange         = 120;        // Fractal range

double    indFractalBuffer[];
double    indLowBarBuffer[];
double    indHighBarBuffer[];

int       fDirection          = 0;
int       fHighBar            = 0;
int       fLowBar             = 0;
int       fRetraceBar         = 0;
int       fInversionBar       = 0;

bool      fPeg                = false;
bool      fDivergent          = false;
bool      fConvergent         = false;

double    fBoxTop             = 0.00;
double    fBoxBottom          = 0.00;
int       fBoxAction          = OP_NO_ACTION;

//+------------------------------------------------------------------+
//| SetBuffer - sets the retrace buffer values                       |
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
//| ClearRetrace - initializes all retrace values                    |
//+------------------------------------------------------------------+
void ClearRetrace(void)
  {
    fPeg          = false;
    fDivergent    = false;
    fConvergent   = false;
        
    fRetraceBar   = OP_NO_ACTION;
    fInversionBar = OP_NO_ACTION;
    
    SetBuffer(indHighBarBuffer,OP_NO_ACTION,OP_NO_ACTION);
    SetBuffer(indLowBarBuffer,OP_NO_ACTION,OP_NO_ACTION);
  }

//+------------------------------------------------------------------+
//| RetracePercent - computes the current retrace percent            |
//+------------------------------------------------------------------+
double RetracePercent(double Price, double RetraceFrom, double Range)
  {
    if (NormalizeDouble(Range,Digits)==0.00)
      return (0.00);
      
    if (Price<RetraceFrom)
      return ((NormalizeDouble(RetraceFrom-Price,Digits)/Range)*100);

    return ((NormalizeDouble(Price-RetraceFrom,Digits)/Range)*100);
  }

//+------------------------------------------------------------------+
//| UpdateActionBox - computes short term trade ranges               |
//+------------------------------------------------------------------+
void UpdateActionBox(int Action, double BoxTop, double BoxBottom)
  {
    fBoxAction    = Action;
    fBoxTop       = BoxTop;
    fBoxBottom    = BoxBottom;
  }

//+------------------------------------------------------------------+
//| BarRange - computes the range between the bars                   |
//+------------------------------------------------------------------+
double BarRange(int HighBar=0, int LowBar=0)
  {  
    return (NormalizeDouble(High[HighBar]-Low[LowBar],Digits));
  }

//+------------------------------------------------------------------+
//| BarUpdate - updates bar pointers                                 |
//+------------------------------------------------------------------+
void BarUpdate(void)
  {
    fHighBar++;
    fLowBar++;
    
    if (fRetraceBar!=OP_NO_ACTION)
      fRetraceBar++;

    if (fInversionBar!=OP_NO_ACTION)
      fInversionBar++;
  }

//+------------------------------------------------------------------+
//| UpdateFractal - computes new fractal legs and updates buffers    |
//+------------------------------------------------------------------+
void UpdateFractal(int fbar)
  {
    int lastHighBar   = fHighBar;
    int lastLowBar    = fLowBar;

    if (NormalizeDouble(High[fbar],Digits)>=NormalizeDouble(High[fHighBar],Digits))
      fHighBar        = fbar;
          
    if (NormalizeDouble(Low[fbar],Digits)<=NormalizeDouble(Low[fLowBar],Digits))
      fLowBar         = fbar;
        
//    indHighBarBuffer[fbar] = High[fHighBar];
//    indLowBarBuffer[fbar]  = Low[fLowBar];
    
    //--- Handle initialization
    if (fDirection == DirectionNone)
    {
      if (fHighBar<fLowBar)
      {
        fDirection  = DirectionUp;
        indFractalBuffer[fLowBar] = NormalizeDouble(Low[fLowBar],Digits);
      }
      
      if (fHighBar>fLowBar)
      {
        fDirection  = DirectionDown; 
        indFractalBuffer[fHighBar] = NormalizeDouble(High[fHighBar],Digits);
      }
    }
    else
    {

      //--- Handle up-trends
      if (fDirection == DirectionUp)
      {
        //--- Check trend continuation
        if (fHighBar == fbar)
        {
          indFractalBuffer[fbar]          = High[fbar];
            
          if (fPeg)
          {
            indFractalBuffer[fRetraceBar] = Low[fRetraceBar];
            fLowBar                       = fRetraceBar;
          }
          else
          if (lastHighBar>fbar)
            indFractalBuffer[lastHighBar] = 0.00;

          UpdateActionBox(OP_SELL,High[fHighBar]-Pip(inpRange*(0.25),InPoints),High[fHighBar]+Pip(inpRange*(0.75),InPoints));
          ClearRetrace();
        }
        else

        //--- Check trend change
        if (fLowBar == fbar)
        {
          indFractalBuffer[fbar] = Low[fbar];

          fDirection    = DirectionDown;
          
          UpdateActionBox(OP_BUY,Low[fLowBar],Low[fLowBar]-Pip(inpRange/2,InPoints));
          ClearRetrace();
        }
        else

        //--- Check retrace pegs
        {
          if (fRetraceBar == OP_NO_ACTION)
            fRetraceBar   = fbar;
          else
          {
            if (NormalizeDouble(Low[fbar],Digits)<=NormalizeDouble(Low[fRetraceBar],Digits))
            {
              fRetraceBar   = fbar;
              fInversionBar = OP_NO_ACTION;
            }
            else
            if (fInversionBar == OP_NO_ACTION)
              fInversionBar = fbar;
            else
            if (NormalizeDouble(High[fbar],Digits)>=NormalizeDouble(High[fInversionBar],Digits))
              fInversionBar = fbar;
          }

          SetBuffer(indHighBarBuffer,fHighBar,fRetraceBar);
          SetBuffer(indLowBarBuffer,fInversionBar,fRetraceBar);          

          //--- Check trend 50% retrace
          if (RetracePercent(Low[fbar],High[fHighBar],BarRange(fHighBar,fLowBar))>50)
            fPeg          = true;
          
          //--- Check excessive retraces`
          if (BarRange(fHighBar,fRetraceBar)>Pip(inpRange,InPoints))
          {
            fPeg          = true;
            fDivergent    = true;
          }

          //--- Check excessive corrections
          if (fInversionBar == OP_NO_ACTION)
            fConvergent   = false;
          else
          if (BarRange(fInversionBar,fRetraceBar)>Pip(inpRange,InPoints))
          {
            fConvergent   = true;
            fDivergent    = false;
          }          
        }
      }
      else

      //--- Handle down-trends
      if (fDirection == DirectionDown)
      {
        //--- Check trend continuation
        if (fLowBar == fbar)
        {
          indFractalBuffer[fbar]          = Low[fbar];
            
          if (fPeg)
          {
            indFractalBuffer[fRetraceBar] = High[fRetraceBar];
            fHighBar                       = fRetraceBar;
          }
          else
          if (lastLowBar>fbar)
            indFractalBuffer[lastLowBar] = 0.00;

          UpdateActionBox(OP_BUY,Low[fLowBar]+Pip(inpRange*(0.25),InPoints),Low[fLowBar]-Pip(inpRange*(0.75),InPoints));
          ClearRetrace();
        }
        else

        //--- Check trend change
        if (fHighBar == fbar)
        {
          indFractalBuffer[fbar] = High[fbar];
          
          fDirection    = DirectionUp;

          UpdateActionBox(OP_SELL,High[fHighBar],High[fHighBar]+Pip(inpRange/2,InPoints));
          ClearRetrace();
        }
        else

        //--- Check retrace pegs
        {
          if (fRetraceBar == OP_NO_ACTION)
            fRetraceBar   = fbar;
          else
          {
            if (NormalizeDouble(High[fbar],Digits)>=NormalizeDouble(High[fRetraceBar],Digits))
            {
              fRetraceBar   = fbar;
              fInversionBar = OP_NO_ACTION;
            }
            else
            if (fInversionBar == OP_NO_ACTION)
              fInversionBar = fbar;
            else
            if (NormalizeDouble(Low[fbar],Digits)<=NormalizeDouble(Low[fInversionBar],Digits))
              fInversionBar = fbar;
          }
              
          SetBuffer(indHighBarBuffer,fRetraceBar,fLowBar);
          SetBuffer(indLowBarBuffer,fRetraceBar,fInversionBar);
          
          //--- Check trend 50% retrace
          if (RetracePercent(High[fbar],Low[fLowBar],BarRange(fHighBar,fLowBar))>50)
            fPeg          = true;

          //--- Check excessive retrace
          if (BarRange(fRetraceBar,fLowBar)>Pip(inpRange,InPoints))
          {
            fPeg          = true;
            fDivergent    = true;
          } 

          //--- Check excessive corrections
          if (fInversionBar == OP_NO_ACTION)
              fConvergent   = false;
          else          
          if (BarRange(fRetraceBar,fInversionBar)>Pip(inpRange,InPoints))
          {
            fConvergent   = true;
            fDivergent    = false;
          }
        }
      }
    }
  }
  
//+------------------------------------------------------------------+
//| InitFractal                                                      |
//+------------------------------------------------------------------+
void InitFractal(void)
  {    
    fDirection  = DirectionNone;
    
    fHighBar    = Bars-1;
    fLowBar     = Bars-1;
    fRetraceBar = -1;
    
    for (int fbar=Bars-1; fbar>0; fbar--)
      UpdateFractal(fbar);
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
    if (prev_calculated == 0)
      InitFractal();
    else
    {
      if (NewBar())
        BarUpdate();
        
      UpdateFractal(0);
    }
      
    RefreshScreen();
    
    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string report = "";
//    report += DoubleToStr(Close[0],Digits)+":"+DoubleToStr(High[fHighBar],Digits)+":"+DoubleToStr(Low[fLowBar],Digits)+":"+DoubleToStr(BarRange(fHighBar,fLowBar),Digits)+"\n";

    if (fDirection == DirectionDown)
      report += "Time: "+Direction(fDirection)+" "+DoubleToStr(RetracePercent(Close[0],Low[fLowBar],BarRange(fHighBar,fLowBar)),1)+"%";
    
    if (fDirection == DirectionUp)
      report += "Time: "+Direction(fDirection)+" "+DoubleToStr(RetracePercent(Close[0],High[fHighBar],BarRange(fHighBar,fLowBar)),1)+"%";

    if (fPeg)
    {
      report += " Peg ";
      SetIndexStyle(1,DRAW_SECTION,STYLE_SOLID);
    }
    else
      SetIndexStyle(1,DRAW_SECTION,STYLE_DOT);
      
    if (fDivergent)
      report += " Divergent ";
    
    if (fConvergent)
    {
      report += " Convergent ";
      SetIndexStyle(2,DRAW_SECTION,STYLE_SOLID);      
    }
    else
      SetIndexStyle(2,DRAW_SECTION,STYLE_DOT);

    if (fBoxAction!=OP_NO_ACTION)
      report += " Action Box("+ActionText(fBoxAction)+":"+DoubleToStr(fBoxTop,Digits)+":"+DoubleToStr(fBoxBottom,Digits)+")";
      
    Comment(report);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {    
    SetIndexBuffer(0,indFractalBuffer);
    SetIndexEmptyValue(0,0.00);
    ArrayInitialize(indFractalBuffer,0.00);    
    
    SetIndexBuffer(1,indHighBarBuffer);
    SetIndexEmptyValue(1,0.00);
    ArrayInitialize(indHighBarBuffer,0.00);    

    SetIndexBuffer(2,indLowBarBuffer);
    SetIndexEmptyValue(2,0.00);
    ArrayInitialize(indLowBarBuffer,0.00);
    
    return(INIT_SUCCEEDED);
  }
