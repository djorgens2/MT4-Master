//+------------------------------------------------------------------+
//|                                                        PipMA.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\Event.mqh>

class CPipMA : public CEvent
  {
    private:

      enum   RegressionMethod
             {
               rmOpen,
               rmHigh,
               rmLow,
               rmClose,
               rmMean
             };

      //struct SlopeRec
      //  {
      //    double       Open;
      //    double       Close;
      //    double       Composite;
      //    double       SMA;
      //  };

       struct SMARec
        {
          double       Fast;
          double       Slow;
        };

      struct           TriggerRec
        {
          int          Bias;      //-- Slow v. Fast direction
          EventType    Event;     //-- Trigger Event
          double       Open;      //-- Open on Agg Tick Segment
          double       High;      //-- Highest Price below Open
          double       Low;       //-- Lowest Price below Open
          double       Close[];   //-- Tick History
          double       Retrace;   //-- Active Retrace
          SMARec       SMA[];     //-- Trigger SMA
        };

      struct OHLCRec
        {
          int          Segment;
          int          Count;
          double       Open;
          double       High;
          double       Low;
          double       Close;
        };

      struct PipMARec
        {
          int          BreakoutDir;
          int          Direction;
          int          Bias;  
          TriggerRec   Trigger;
          OHLCRec      SMA;
          OHLCRec      Tick[];
        };

      //-- Methods
      double         CalcSMA(OHLCRec &OHLC[], RegressionMethod Method, int Segments);

      void           UpdateTick(void);
      void           UpdateMaster(void);
      void           UpdateTrigger(TriggerRec &Trigger);

      //-- User-Defined Properties
      double         pmaAgg;
      int            pmaRegr;
      int            pmaKeep;
      int            pmaSMASlow;
      int            pmaSMAFast;

      int            trgKeep;
      int            trgSMASlow;
      int            trgSMAFast;

      
      //-- Data Collections
      PipMARec       pma;

      //-- Variable Properties

    public:

                     CPipMA(int RetainedSize, int Regression, int SMA, double Aggregation);
                    ~CPipMA();
     
      //--- Data Entry/Update Methods
      void           Update(void);

      //--- Data Retrieval Methods
      TriggerRec     Trigger(void) const {return(pma.Trigger);};

      //-- Formatted data outputs
      string         TriggerStr(void);
      string         OHLCStr(int Node);
      string         SMAStr(OHLCRec &SMA);
      string         HistoryStr(void);
      string         MasterStr(void);
      
      OHLCRec        operator[](const int Node)        const {return(pma.Tick[Node]);};
  };

//+------------------------------------------------------------------+
//| CalcRegression - Calculate Linear Regression; return slope       |
//+------------------------------------------------------------------+
double CalcRegression(RegressionMethod Method)
  {
    //--- Linear regression line
//    double m[5]      = {0.00,0.00,0.00,0.00,0.00};   //--- slope
//    double b         = 0.00;                         //--- y-intercept
//    
//    double sumx      = 0.00;
//    double sumy      = 0.00;
//    
//    for (int idx=0;idx<inpRegressionFactor;idx++)
//    {
//      sumx += idx+1;
//      sumy += BoolToDouble(Method==rmOpen,tm.Tick[idx].Open,tm.Tick[idx].Close,Digits);
//      
//      m[1] += (idx+1)*BoolToDouble(Method==rmOpen,tm.Tick[idx].Open,tm.Tick[idx].Close,Digits);  // Exy
//      m[3] += pow(idx+1,2);                          // E(x^2)
//    }
//    
//    m[2]    = fdiv(sumx*sumy,inpRegressionFactor);   // (Ex*Ey)/n
//    m[4]    = fdiv(pow(sumx,2),inpRegressionFactor); // [(Ex)^2]/n
//    
//    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
//    b       = (sumy-m[0]*sumx)/inpRegressionFactor;
//    
//    return (m[0]*(-1)); //-- inverted tail to head slope
return(0);
  }

//+------------------------------------------------------------------+
//| CalcSMA - Computes the SMA of a double array                     |
//+------------------------------------------------------------------+
double CPipMA::CalcSMA(OHLCRec &OHLC[], RegressionMethod Method, int Segments)
  {
    double sma    = 0.00;

    for (int node=0;node<Segments;node++)   
      sma        += BoolToDouble(IsEqual(Method,rmOpen),OHLC[node].Open,
                    BoolToDouble(IsEqual(Method,rmClose),OHLC[node].Close,
                    BoolToDouble(IsEqual(Method,rmHigh),OHLC[node].High,
                    BoolToDouble(IsEqual(Method,rmLow),OHLC[node].Low))));

    return (fdiv(sma,Segments,8));
  }

//+------------------------------------------------------------------+
//| UpdateSlope - Computes slope aggregate detail                    |
//+------------------------------------------------------------------+
void UpdateSlope(void)
  {
//    static int pfbar          = 0;
//    double sma                = 0.00;

//    if (IsChanged(pfbar,Bars))
//      InsertOHLC(tm.Slope,inpSMAFactor);
//      
//    tm.Slope[0].Trigger       = false;
//    tm.Slope[0].Open          = CalcRegression(rmOpen);
//    tm.Slope[0].Close         = CalcRegression(rmClose);
//
//    for (int idx=0;idx<inpSMAFactor;idx++)
//      sma                    += NormalizeDouble(tm.Slope[idx].Open+tm.Slope[idx].Close,8);
//
//    tm.Slope[0].SMA           = fdiv(sma,inpSMAFactor);
  }

//+------------------------------------------------------------------+
//| UpdateMaster - Computes Master Events/Values on each Tick Agg    |
//+------------------------------------------------------------------+
void CPipMA::UpdateMaster(void)
  {
    if (NewAction(pma.Bias,Action(Direction(pma.SMA.Open-pma.SMA.Close),InDirection)))
      SetEvent(NewBias);

  //      //--- calc direction changes
//      if (NewDirection(
//      if (pmaBuffer[0]>pmaBuffer[1])
//        pma.TickDir            = DirectionUp;
// 
//      if (pmaBuffer[0]<pmaBuffer[1])
//        pma.TickDir            = DirectionDown;
//        
//      if (IsHigher(Close[0],pmaPriceHigh))
//        SetEvent(NewHigh,Nominal);
//        
//      if (IsLower(Close[0],pmaPriceHigh))
//        SetEvent(NewLow,Nominal);
//        
//      if (Event(NewHigh)||Event(NewLow))
//      {
//        if (IsChanged(cmaRangeDir,ptrRangeDir))
//          ptrRangeAge     = 0;
//
//        if (Event(NewHigh))
//          ptrRangeAgeHigh = 0;
//
//        if (Event(NewLow))
//          ptrRangeAgeLow  = 0;
//
//        SetEvent(NewBoundary);
//      }
//      
//      SetEvent(NewTick);
//        
//      ptrRangeAgeHigh++;
//      ptrRangeAgeLow++;
//      ptrRangeAge++;
//    }

//    ptrTick++;
  }

//+------------------------------------------------------------------+
//| UpdateTrigger - Computes the bias on the tick                    |
//+------------------------------------------------------------------+
void CPipMA::UpdateTrigger(TriggerRec &Trigger)
  {
    static int slowaction      = OP_NO_ACTION;
    static int fastaction      = OP_NO_ACTION;
    
    ArrayCopy(Trigger.Close,Trigger.Close,1,0,trgKeep-1);
    ArrayCopy(Trigger.SMA,Trigger.SMA,1,0,trgKeep-1);
    
    Trigger.Event              = NoEvent;
    Trigger.Open               = pma.Tick[0].Open;
    Trigger.Close[0]           = Close[0];
    Trigger.SMA[0].Fast        = 0.00;
    Trigger.SMA[0].Slow        = 0.00;

    for (int node=0;node<trgKeep;node++)
    {
      Trigger.SMA[0].Fast     += BoolToDouble(node<trgSMAFast,Trigger.Close[node],0.00);
      Trigger.SMA[0].Slow     += BoolToDouble(node<trgSMASlow,Trigger.Close[node],0.00);
    }
    
    Trigger.SMA[0].Fast        = fdiv(Trigger.SMA[0].Fast,trgSMAFast,8);
    Trigger.SMA[0].Slow        = fdiv(Trigger.SMA[0].Slow,trgSMASlow,8);
    
    //-- Calculate Bias
    NewAction(slowaction,Action(Trigger.SMA[0].Slow-Trigger.SMA[2].Slow,InDirection));
    NewAction(fastaction,Action(Trigger.SMA[0].Fast-Trigger.SMA[2].Fast,InDirection));
    
    if (NewAction(Trigger.Bias,BoolToInt(IsEqual(slowaction,fastaction),slowaction,Trigger.Bias)))
      Trigger.Event            = NewBias;

    switch (Trigger.Bias)
    {
      case OP_BUY:    if (IsEqual(Trigger.Event,NewBias))
                        Trigger.High        = fmax(Trigger.Retrace,Close[0]);
                      else
                      if (IsHigher(Close[0],Trigger.High))
                      {
                        Trigger.Event       = NewHigh;
                        Trigger.Retrace     = Close[0];
                      }
                      
                      Trigger.Retrace       = fmin(Trigger.Retrace,Close[0]);
                      break;
                        
      case OP_SELL:   if (IsEqual(Trigger.Event,NewBias))
                        Trigger.Low         = fmin(Trigger.Retrace,Close[0]);
                      else
                      if (IsLower(Close[0],Trigger.Low))
                      {
                        Trigger.Event       = NewLow;
                        Trigger.Retrace     = Close[0];
                      }
                      
                      Trigger.Retrace       = fmax(Trigger.Retrace,Close[0]);
                      break;
    }
  }

//+------------------------------------------------------------------+
//| UpdateTick - Calc tick bounds and update tick history            |
//+------------------------------------------------------------------+
void CPipMA::UpdateTick(void)
  {
    if (fabs(pip(pma.Tick[0].Open-Close[0]))>=pmaAgg)
    {
      
      pma.SMA.High             = CalcSMA(pma.Tick,rmHigh,pmaSMAFast);
      pma.SMA.Low              = CalcSMA(pma.Tick,rmLow,pmaSMAFast);
      pma.SMA.Close            = CalcSMA(pma.Tick,rmClose,pmaSMASlow);

      ArrayCopy(pma.Tick,pma.Tick,1,0,pmaKeep-1);

      pma.Tick[0].Open         = Close[0];
      pma.Tick[0].High         = Close[0];
      pma.Tick[0].Low          = Close[0];

      pma.Tick[0].Segment      = pma.Tick[1].Segment+1;
      pma.Tick[0].Count        = 0;

      pma.SMA.Open             = CalcSMA(pma.Tick,rmOpen,pmaSMASlow);
    
      UpdateMaster();
      
      SetEvent(NewTick);
    }

    UpdateTrigger(pma.Trigger);

    pma.Tick[0].High           = fmax(Close[0],pma.Tick[0].High);
    pma.Tick[0].Low            = fmin(Close[0],pma.Tick[0].Low);
    pma.Tick[0].Close          = Close[0];

    pma.Tick[0].Count++;
  }

//+------------------------------------------------------------------+
//| CPipMA Constructor                                               |
//+------------------------------------------------------------------+
void CPipMA::CPipMA(int Retention, int Regression, int SMA, double Aggregation)
  {
    pmaKeep                    = Retention;
    pmaAgg                     = Aggregation;
    pmaRegr                    = Regression;
    pmaSMASlow                 = SMA;
    pmaSMAFast                 = SMA-1;
    
    trgSMASlow                 = SMA*2;
    trgSMAFast                 = SMA;
    trgKeep                    = trgSMASlow+trgSMAFast;

    ArrayResize(pma.Tick,pmaKeep,pmaKeep);
    ArrayResize(pma.Trigger.Close,trgKeep,trgKeep);
    ArrayResize(pma.Trigger.SMA,trgKeep,trgKeep);
    
    //-- Initialize Trigger
    pma.Trigger.Open           = Close[0];
    pma.Trigger.High           = Close[0];
    pma.Trigger.Low            = Close[0];
    pma.Trigger.Retrace        = Close[0];
  }

//+------------------------------------------------------------------+
//| CPipMA Destructor                                                |
//+------------------------------------------------------------------+
void CPipMA::~CPipMA()
  {
  }

//+------------------------------------------------------------------+
//| CPipMA Destructor                                                |
//+------------------------------------------------------------------+
void CPipMA::Update(void)
  {
    ClearEvents();
    UpdateTick();
  }

//+------------------------------------------------------------------+
//| TriggerStr - Returns formatted Trigger string                    |
//+------------------------------------------------------------------+
string CPipMA::TriggerStr(void)
  {
    string text   = "";
    
    Append(text,(string)pma.Tick[0].Segment,"\n|");
    Append(text,ActionText(pma.Trigger.Bias),"|");
    Append(text,EnumToString(pma.Trigger.Event),"|");
    Append(text,DoubleToStr(pma.Trigger.Open,Digits),"|");
    Append(text,DoubleToStr(pma.Trigger.High,Digits),"|");
    Append(text,DoubleToStr(pma.Trigger.Low,Digits),"|");
    Append(text,DoubleToStr(pma.Trigger.Close[0],Digits),"|");
    Append(text,DoubleToStr(pma.Trigger.Retrace,Digits),"|");
    Append(text,DoubleToStr(pma.Trigger.SMA[0].Fast,8),"|");
    Append(text,DoubleToStr(pma.Trigger.SMA[0].Slow,8),"|");

    return (text);
  }    

//+------------------------------------------------------------------+
//| OHLCStr - Returns formatted OHLC string                          |
//+------------------------------------------------------------------+
string CPipMA::OHLCStr(int Node)
  {
    string text   = "";
    
    Append(text,(string)Node,"\n|");
    Append(text,(string)pma.Tick[Node].Segment,"|");
    Append(text,(string)pma.Tick[Node].Count,"|");
    Append(text,DoubleToStr(pma.Tick[Node].Open,Digits),"|");
    Append(text,DoubleToStr(pma.Tick[Node].High,Digits),"|");
    Append(text,DoubleToStr(pma.Tick[Node].Low,Digits),"|");
    Append(text,DoubleToStr(pma.Tick[Node].Close,Digits),"|");

    return (text);
  }    

//+------------------------------------------------------------------+
//| HistoryStr - Returns formatted OHLC string                       |
//+------------------------------------------------------------------+
string CPipMA::HistoryStr(void)
  {
    string text   = "";
    
    for (int node=0;node<pmaKeep;node++)
    {
      if (IsEqual(pma.Tick[node].Close,0.00))
        break;

      Append(text,OHLCStr(node));
    }
    
    return(text);
  }

//+------------------------------------------------------------------+
//| SMAStr - Returns formatted OHLC/SMA string                       |
//+------------------------------------------------------------------+
string CPipMA::SMAStr(OHLCRec &SMA)
  {
    string text   = "";
    
    Append(text,DoubleToStr(SMA.Open,8),"|");
    Append(text,DoubleToStr(SMA.High,8),"|");
    Append(text,DoubleToStr(SMA.Low,8),"|");
    Append(text,DoubleToStr(SMA.Close,8),"|");
    Append(text,DoubleToStr(SMA.Open-SMA.Close,8),"|");

    return (text);
  }    

//+------------------------------------------------------------------+
//| MasterStr - Returns formatted OHLC string                        |
//+------------------------------------------------------------------+
string CPipMA::MasterStr(void)
  {
    string text   = "";
    
    Append(text,DirText(pma.BreakoutDir),"|");
    Append(text,DirText(pma.Direction),"|");
    Append(text,ActionText(pma.Bias),"|");
    Append(text,(string)pma.Tick[0].Segment,"|");
    Append(text,DoubleToStr(pma.Tick[0].Open,Digits),"|");
    Append(text,DoubleToStr(pma.Tick[1].High,Digits),"|");
    Append(text,DoubleToStr(pma.Tick[1].Low,Digits),"|");
    Append(text,DoubleToStr(pma.Tick[1].Close,Digits),"|");
    Append(text,SMAStr(pma.SMA),"|");
    
    return(text);
  }
