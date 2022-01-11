//+------------------------------------------------------------------+
//|                                                         Test.mq4 |
//|                                                 Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class/TickMA.mqh>

//--- input parameters
input int        inpPeriods             =  80;   // Retention
input int        inpDegree              =   6;   // Poiy Regression Degree
input double     inpAgg                 = 2.5;   // Tick Aggregation
input PriceType inpShowFractal   = PriceTypes;   // Show Fractal

CTickMA *tick         = new CTickMA(inpPeriods,inpDegree,inpAgg);

bool     PauseOn      = true;

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    const color linecolor[] = {clrWhite,clrYellow,clrLawnGreen,clrRed,clrGoldenrod,clrSteelBlue};
    double f[];
    
    if (!IsEqual(inpShowFractal,PriceTypes))
    {
      if (inpShowFractal==ptOpen)   ArrayCopy(f,tick.SMA().Open.Point);
      if (inpShowFractal==ptHigh)   ArrayCopy(f,tick.SMA().High.Point);
      if (inpShowFractal==ptLow)    ArrayCopy(f,tick.SMA().Low.Point);
      if (inpShowFractal==ptClose)  ArrayCopy(f,tick.SMA().Close.Point);

      for (FractalPoint fp=0;fp<FractalPoints;fp++)
        UpdateLine("tmaSMAFractal:"+StringSubstr(EnumToString(fp),2),f[fp],STYLE_SOLID,linecolor[fp]);
    }
  }

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (PauseOn)
      Pause(Message,AccountCompany()+" Event Trapper");
    else
      Print(Message);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    static FractalState state   = NoState;

    tick.Update();
    
    RefreshScreen();

    if (IsEqual(tick.SMA().High.Event,NewBias))
    {
//      Print(tick.SMAStr());
      CallPause("New Bias: "+proper(ActionText(tick.SMA().High.Bias))+"\nState: "+
                   proper(DirText(tick.SMA().High.Direction))+
                   " "+EnumToString(tick.SMA().High.State)+
                   "\n"+EnumToString(tick.SMA().High.Event));
    }
    //if (tick[NewSegment])
    //  Print(tick.SMAStr());
    //if (IsChanged(state,tick.Range().State))
    //  if (state&&(Reversal||Breakout))
    //    Pause("New "+EnumToString(state),"State Check");
    //if (tick.Event(NewReversal,Minor)) 
    //  Pause("New Reversal(Minor)","Reversal Check()");
//    if (tick[NewSegment])
//      Pause("New Segment","NewSegment() Test");
//
//    if (tick[NewExpansion])
//      Pause("New Expansion: "+DirText(tick.Range().Direction),"NewExpansion()");
    //if (tick[NewTick])
    //  Print(tick.PolyStr());
    //if (tick[NewBias])
    //  if (tick.Segments()>0)
    //    Pause("Bias Check: "+ActionText(tick.Segment(0).Bias),"NewBias()");    
//    if (tick[NewDirection])
//      if (tick.Segments()>0)
//        Pause("Direction Check: "+ActionText(Action(tick.Segment(0).Direction)),"NewDirection()");    
//    if (tick[NewTick])
//      Print(tick.TickHistoryStr(200));
    //if (tick[NewSegment])
    //  Print (tick.SegmentStr(1));
//    if (tick.SegmentTickStr(4)!="")
//      Print(tick.SegmentTickStr(4));
    //if (tick[NewTick])
      //if (tick.Segments()<=110)
      //  if (tick.SegmentTickStr(tick.Segments()-1)!="")
      //    Print(tick.SegmentTickStr(tick.Segments()-1));
    //if (tick[NewTick])
    //  if (IsBetween(tick.Segments(),840,860))
    //    Print(tick.SegmentTickStr(tick.Segments()-1));
//        Print(tick.SegmentStr(1));
    //if (tick.Segments()==80)
    //  Print(tick.SegmentHistoryStr(tick.Segments()));

  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    if (!IsEqual(inpShowFractal,PriceTypes))
      for (FractalPoint fp=0;fp<FractalPoints;fp++)
        NewLine("tmaSMAFractal:"+StringSubstr(EnumToString(fp),2),0.00);

  
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete tick;
  }
