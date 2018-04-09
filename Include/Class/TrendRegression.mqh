//+------------------------------------------------------------------+
//|                                              TrendRegression.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\PolyRegression.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CTrendRegression : public CPolyRegression
  {

private:

    int       trLastPivotDir;
    int       trTrendAlert;

    CArrayDouble *trFOCHistory;

    double    trData[];            // computed trend regression values
    
  //--- private methods
    void      trCalcTrendline(void);
    void      trCalcPivot(void);
    void      trCalcFOC(void);
    void      trCalcFOCAmplitude(void);
    void      trCalcEventWane(void);


public:

              CTrendRegression(int Degree, int Periods, int MAPeriods);
             ~CTrendRegression();
             
  virtual
     void     SetPeriods(int Periods);

     //--- data access methods
     void     UpdateBuffer(double &PolyBuffer[], double &TrendBuffer[]);

  virtual
     void     Update(void);

     void     SetTrendlineTolerance(double Tolerance) {trTrendlineTolerance = Tolerance;};

     double   Trendline(int Measure);
     double   FOC(int Measure);
     double   FOCAmp(int Measure);
     double   Pivot(int Measure);
     double   StdDev(int Measure);
     double   Intercept(int Measure);
     
     bool     TrendWane(void) {return (fabs(this.FOC(Retrace))>FiboPercent(Fibo50)); }   //-- returns the trend wane indicator
     
   virtual
     int      Direction(int Direction, bool Contrarian=false);
     int      FOCDirection(double Tolerance=0);
          
    double operator[](const int Bar) const { return(trData[Bar]); }

protected:

    void      UpdateTrendline(void);

    double    trTrendlineTolerance;
    int       trLastTrendlineDir;
    
    double    trTrendlineNow;
    double    trTrendlineHigh;
    double    trTrendlineLow;
    double    trTrendlineMean;
    double    trTrendlineRange;
    int       trTrendlineDir;
    
    //--- Factor of change (angle regression) measures
    double    trFOCNow;
    double    trFOCMin;
    double    trFOCMax;
    double    trFOCDev;
    double    trFOCRetrace;
    int       trFOCDir;

    //--- Trend line pivot measures
    double    trPivotPrice;
    double    trPivotMin;
    double    trPivotMax;
    double    trPivotDev;
    int       trPivotDir;

    //--- MA intercept measures
    double    trTopInt;                //--- The tl intercept of the highest ma
    double    trBottomInt;             //--- The tl intercept of the lowest ma

    //--- Trendline standard deviation oscillation measures
    double    trStdDev;                //--- Standard deviation; short form (pos/|neg|)/2
    double    trStdDevNow;             //--- Deviation as of this tick
    double    trStdDevPos;             //--- Highest deviation;  max({0,pos,n}-trend)
    double    trStdDevNeg;             //--- Lowest deviation;   min({0,neg,n}-trend)
    double    trStdDevPosInt;          //--- The tl intercept of the highest deviation
    double    trStdDevNegInt;          //--- The tl intercept of the lowest deviation
    int       trStdDevDir;             //--- Direction of last standard deviation expansion    

    //--- FOC oscillation amplitude measures
    double    trFOCAmpNow;             //--- Current pos/neg amplitude
    double    trFOCAmpMax;             //--- Current amplitude (wave height)
    double    trFOCAmpPeak;            //--- Current amplitude bisector (weighted by cur pos/neg amplitude?)
    int       trFOCAmpDir;             //--- Direction of the most recent standard deviation

    double    trFOCAmpMean;            //--- Mean Amplitude (Crest+|Trough|)
    double    trFOCAmpMeanPeak;        //--- Mean Amplitude bisector (should consider weighting the mean using the Pos/Neg amplitudes?)
    double    trFOCAmpMeanPos;         //--- Mean of the positive amplitudes
    double    trFOCAmpMeanNeg;         //--- Mean of the negative amplitudes
    int       trFOCAmpMeanDir;         //--- direction of MeanPos+MeanNeg
  };
  
  
//+------------------------------------------------------------------+
//| SetPeriods - Configure period objects and parameters             |
//+------------------------------------------------------------------+
void CTrendRegression::SetPeriods(int Periods)
  {
    prPeriods = Periods;
    
    ArrayResize(prData,Periods);    
    ArrayResize(maData,prPeriods+prDegree);
    ArrayResize(trData,Periods);
  }

//+------------------------------------------------------------------+
//| trCalcPivot - calculates prices and stats based on the TL Pivot  |
//+------------------------------------------------------------------+
void CTrendRegression::trCalcPivot(void)
  {
    ClearEvent(NewPivot);
    ClearEvent(NewPivotDirection);
    
    if (trTrendlineDir!=trLastTrendlineDir && trTrendlineDir!=DirectionNone)
    {
      SetEvent(NewPivot);
      
      trPivotPrice = trTrendlineMean;
      
      trPivotMin   = Close[0]-trPivotPrice;
      trPivotMax   = Close[0]-trPivotPrice;
    }
    else
    {
      trPivotMax = fmax(trPivotMax,Close[0]-trPivotPrice);

      if (IsEqual(Close[0],trPivotMax))
        trPivotMin = trPivotMax;
      else
        trPivotMin = fmin(trPivotMin,Close[0]-trPivotPrice);
    }
    
    trPivotDev     = Close[0]-trPivotPrice;

    if (trPivotDev<0.00)
      trPivotDir   = DirectionDown;

    if (trPivotDev>0.00)
      trPivotDir   = DirectionUp;
      
    if (IsChanged(trLastPivotDir,trPivotDir))
      SetEvent(NewPivotDirection);
  }

//+------------------------------------------------------------------+
//| trCalcFOC - Computes factor of change of the trendline           |
//+------------------------------------------------------------------+
void CTrendRegression::trCalcFOC(void)
  {
    ClearEvent(NewDirection);

    //--- compute FOC metrics
    trFOCNow         = ((atan(Pip(trTrendlineRange)/prPeriods)*180)/M_PI)*trTrendlineDir;
    
    if (FOCDirection(trTrendlineTolerance) == trFOCDir)                //--- Update values for current trend
    {
      if (fabs(NormalizeDouble(trFOCNow,2)) >= fabs(NormalizeDouble(trFOCMax,2)))
      {
        trFOCMax     = trFOCNow;      
        trFOCMin     = 0.00;
      }
      else
      {    
        if (trFOCMin == 0.00)
          trFOCMin   = trFOCNow;
        else
          trFOCMin   = fmin(fabs(trFOCNow),fabs(trFOCMin))*trTrendlineDir;

        trFOCMax     = fmax(fabs(trFOCNow),fabs(trFOCMax))*trFOCDir;
      }
    }
    else
    if (trFOCDir+FOCDirection(trTrendlineTolerance) == DirectionNone)    
    {
      SetEvent(NewDirection);

      trFOCDir       = FOCDirection(trTrendlineTolerance);
      trFOCHistory.Insert(0,NormalizeDouble(trFOCMax,2));
      
      trFOCMax       = trFOCNow;
      trFOCMin       = trFOCNow;
    }
    else
      trFOCDir       = FOCDirection(trTrendlineTolerance);

    //--- compute deviation metrics
    trFOCDev         = NormalizeDouble(fabs(trFOCMax),1)-NormalizeDouble(fabs(trFOCNow),1);
    trFOCRetrace     = fdiv(NormalizeDouble(trFOCDev,1),NormalizeDouble(trFOCMax,1),5);
  }

//+------------------------------------------------------------------+
//| trCalcFOCAmplitude - Computes the amplitude oscillation measures |
//+------------------------------------------------------------------+
void CTrendRegression::trCalcFOCAmplitude(void)
  {    
    trFOCAmpNow           = fabs(trFOCNow)+fabs(trFOCHistory[0]);
    trFOCAmpMax           = fabs(trFOCMax)+fabs(trFOCHistory[0]);
    
    trFOCAmpPeak          = trFOCAmpMax/2;
    
    trFOCAmpMean          = trFOCHistory.MeanAbs();
    trFOCAmpMeanPeak      = trFOCHistory.MeanAbsMid();
    trFOCAmpMeanPos       = trFOCHistory.MeanPos();
    trFOCAmpMeanNeg       = trFOCHistory.MeanNeg();
    
    if (fabs(trFOCHistory.MeanNeg())>trFOCHistory.MeanPos())
      trFOCAmpMeanDir     = DirectionDown;
    else
    if (fabs(trFOCHistory.MeanNeg())<trFOCHistory.MeanPos())
      trFOCAmpMeanDir     = DirectionUp;
    else
      trFOCAmpMeanDir     = DirectionNone;
          
    //--- Compute current wave direction
    if (trFOCMax>trFOCAmpMeanPeak)
    {
      if (trFOCAmpDir == Rally)
      {
        if (NormalizeDouble(Close[0],Digits) == NormalizeDouble(High[0],Digits))
          trFOCAmpDir     = LongCorrection;
      }
      else
        trFOCAmpDir       = DirectionUp;

      if (fabs(trFOCHistory[0])>trFOCAmpMeanPeak && trFOCHistory[0]<0.00)
      {
        trFOCAmpDir       = Rally;

        if (trFOCMax>fabs(trFOCHistory[0]))
          trFOCAmpDir     = LongCorrection;
         
        if (trFOCMax>fabs(trFOCHistory[0])*1.5)
          trFOCAmpDir     = LongReversal;
         
        if (trFOCMax>trFOCAmpMeanPos)
          trFOCAmpDir     = DirectionUp;
      }
    }
    else
    if (fabs(trFOCMax)>trFOCAmpMeanPeak)
    {
      if (trFOCAmpDir == Pullback)
      {
        if (NormalizeDouble(Close[0],Digits) == NormalizeDouble(Low[0],Digits))
          trFOCAmpDir     = ShortCorrection;
      }
      else
        trFOCAmpDir       = DirectionDown;

      if (fabs(trFOCHistory[0])>trFOCAmpMeanPeak && trFOCHistory[0]>0.00)
      {
        trFOCAmpDir       = Pullback;

        if (fabs(trFOCMax)>trFOCHistory[0])
          trFOCAmpDir     = ShortCorrection;

        if (fabs(trFOCMax)>trFOCHistory[0]*1.5)
          trFOCAmpDir     = ShortReversal;

        if (trFOCMax<trFOCAmpMeanNeg)
          trFOCAmpDir     = DirectionDown;
      }
    }
  }
  
//+------------------------------------------------------------------+
//| trCalcTrendline - Computes trendline vector from supplied MA     |
//+------------------------------------------------------------------+
void CTrendRegression::trCalcTrendline(void)
  {
    //--- Linear regression line
    double m[5]      = {0.00,0.00,0.00,0.00,0.00};  //--- slope
    double b         = 0.00;                        //--- y-intercept
    
    double sumx      = 0.00;
    double sumy      = 0.00;
    
    for (int idx=0; idx<prPeriods; idx++)
    {
      sumx += idx+1;
      sumy += prData[idx];
      
      m[1] += (idx+1)* prData[idx];
      m[3] += pow(idx+1,2);
    }
    
    m[1]   *= prPeriods;
    m[2]    = sumx*sumy;
    m[3]   *= prPeriods;
    m[4]    = pow(sumx,2);
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy - m[0]*sumx)/prPeriods;
    
    //--- Calc trend line/Standard deviation
    trStdDevNeg         = 0.00;
    trStdDevPos         = 0.00;

    trTopInt            = NoValue;
    trBottomInt         = NoValue;

    for (int idx=0; idx<prPeriods; idx++)
    {
      trData[prPeriods-idx-1] = (m[0]*(prPeriods-idx-1))+b; //--- y=mx+b

      if (IsLower(maData[prPeriods-idx-1]-trData[prPeriods-idx-1],trStdDevNeg))
        trStdDevNegInt  = trData[prPeriods-idx-1];

      if (IsHigher(maData[prPeriods-idx-1]-trData[prPeriods-idx-1],trStdDevPos))
        trStdDevPosInt  = trData[prPeriods-idx-1];
        
      if (trTopInt==NoValue)
        if (IsEqual(maData[idx],maTop))
          trTopInt      = trData[idx];

      if (trBottomInt==NoValue)
        if (IsEqual(maData[idx],maBottom))
          trBottomInt   = trData[idx];
    }

    trStdDev            = (trStdDevPos-trStdDevNeg)/2;
    trStdDevNow         = maData[0]-trData[0];
    
    if (IsEqual(trStdDevNow,trStdDevNeg))
      trStdDevDir       = DirectionDown;
      
    if (IsEqual(trStdDevNow,trStdDevPos))
      trStdDevDir       = DirectionUp;
    
    //--- Calculate Trend measures
    trLastTrendlineDir  = trTrendlineDir;
    
    if (NormalizeDouble(trData[0],Digits)>NormalizeDouble(trData[prPeriods-1],Digits))
    {
      trTrendlineHigh       = trData[0];
      trTrendlineLow        = trData[prPeriods-1];
      trTrendlineDir        = DirectionUp;
    }
    else
    if (NormalizeDouble(trData[0],Digits)<NormalizeDouble(trData[prPeriods-1],Digits))
    {
      trTrendlineHigh       = trData[prPeriods-1];
      trTrendlineLow        = trData[0];
      trTrendlineDir        = DirectionDown;
    }
    else
    {
      trTrendlineHigh       = trData[0];
      trTrendlineLow        = trData[0];
      trTrendlineDir        = DirectionNone;
    }

    trTrendlineNow          = trData[0];
    trTrendlineRange        = trTrendlineHigh-trTrendlineLow;
    trTrendlineMean         = (trTrendlineRange/2)+trTrendlineLow;
  }

//+------------------------------------------------------------------+
//| CalcEventWane - Computes wane/resume indicators                  |
//+------------------------------------------------------------------+
void CTrendRegression::trCalcEventWane(void)
  {
    ClearEvent(TrendWane);
    ClearEvent(TrendResume);
    
    if (Event(NewDirection))
      trTrendAlert                 = TrendResume;
      
    else
      if (TrendWane())
      {
        if (IsChanged(trTrendAlert,TrendWane))
          SetEvent(TrendWane);
      }
      else
      {
        if (IsChanged(trTrendAlert,TrendResume))
            SetEvent(TrendResume);
      }
  }
  
//+------------------------------------------------------------------+
//| UpdateTrendline - updates trend data                             |
//+------------------------------------------------------------------+
void CTrendRegression::UpdateTrendline(void)
  {      
    if (Bars > prPeriods)
    {
      trCalcTrendline();
      trCalcPivot();
      trCalcFOC();
      trCalcFOCAmplitude();
      trCalcEventWane();
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTrendRegression::CTrendRegression(int Degree, int Periods, int MAPeriods) : CPolyRegression(Degree,Periods,MAPeriods)
  {
    SetDegree(Degree);
    SetPeriods(Periods);
    SetMAPeriods(MAPeriods);
    SetTrendlineTolerance(0.5);
        
    trFOCHistory             = new CArrayDouble(Periods);

    trFOCHistory.Truncate    = true;
    trFOCHistory.SetAutoCompute(true,0,Periods);
    
    trFOCHistory.SetPrecision(Digits);
    trFOCHistory.Initialize(0.00);
    
    trFOCDev                 = 0.00;
    trFOCDir                 = DirectionNone;
    trLastPivotDir           = DirectionNone;
    trTrendAlert             = TrendWane;
    

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTrendRegression::~CTrendRegression()
  {
    delete trFOCHistory;
  }

//+------------------------------------------------------------------+
//| FOCDirection - Computes the direction of the FOC                 |
//+------------------------------------------------------------------+
int CTrendRegression::FOCDirection(double Tolerance=0)
  {
    if (NormalizeDouble(trFOCNow,2)>Tolerance)
      return(DirectionUp);

    if (fabs(NormalizeDouble(trFOCNow,2))>Tolerance)
      return(DirectionDown);
      
    return(trFOCDir);
  }

//+------------------------------------------------------------------+
//| Direction - Returns the requested Direction for the given type   |
//+------------------------------------------------------------------+
int CTrendRegression::Direction(int Type, bool Contrarian=false)
  {
    int dContrary     = 1;
    
    if (Contrarian)
      dContrary       = DirectionInverse;

    switch (Type)
    {
      case PolyAmplitude: return (prPolyAmpDirection*dContrary);
      case Polyline:      return (prPolyDirection*dContrary);
      case Amplitude:     return (prAmpDirection*dContrary);
      case FOCAmplitude:  return (trFOCAmpDir*dContrary);
      case FOCAmpMean:    return (trFOCAmpMeanDir*dContrary);
      case Trendline:     return (trTrendlineDir*dContrary);
      case Pivot:         return (trPivotDir*dContrary);
      case StdDev:        return (trStdDevDir*dContrary);
    }
    
    return (DirectionNone);
  }
  
//+------------------------------------------------------------------+
//| Trendline - Returns the requested Trend measure                  |
//+------------------------------------------------------------------+
double CTrendRegression::Trendline(int Measure)
  {
    switch (Measure)
    {
       case Head:          return (NormalizeDouble(trData[0] ,Digits));
       case Tail:          return (NormalizeDouble(trData[prPeriods-1] ,Digits));
       case Now:           return (NormalizeDouble(trTrendlineNow,Digits));
       case Top:           return (NormalizeDouble(trTrendlineHigh,Digits));
       case Bottom:        return (NormalizeDouble(trTrendlineLow,Digits));
       case Mean:          return (NormalizeDouble(trTrendlineMean,Digits));
       case Range:         return (NormalizeDouble(trTrendlineRange,Digits));
       case Deviation:     return (NormalizeDouble(Pip(prPolyHead-trData[0]),Digits));
    }
    
    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| FOC - Returns the requested FOC measure                          |
//+------------------------------------------------------------------+
double CTrendRegression::FOC(int Measure)
  {
    switch (Measure)
    {
       case Now:           return (NormalizeDouble(trFOCNow,1));
       case Min:           return (NormalizeDouble(trFOCMin,1));
       case Max:           return (NormalizeDouble(trFOCMax,1));
       case Deviation:     return (NormalizeDouble(trFOCDev,1));
       case Retrace:       return (NormalizeDouble(trFOCRetrace,5));
    }
    
    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| Pivot - Returns the requested Pivot measure                      |
//+------------------------------------------------------------------+
double CTrendRegression::Pivot(int Measure)
  {
    switch (Measure)
    {
       case Price:         return (NormalizeDouble(trPivotPrice,Digits));
       case Min:           return (NormalizeDouble(trPivotMin,Digits));
       case Max:           return (NormalizeDouble(trPivotMax,Digits));
       case Deviation:     return (NormalizeDouble(trPivotDev,Digits));
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Intercept - Returns the Intercept value of price data to TLine   |
//+------------------------------------------------------------------+
double CTrendRegression::Intercept(int Measure)
  {
    switch (Measure)
    {
       case Positive:      return (NormalizeDouble(trStdDevPosInt,Digits));
       case Negative:      return (NormalizeDouble(trStdDevNegInt,Digits));
       case Top:           return (NormalizeDouble(trTopInt,Digits));
       case Bottom:        return (NormalizeDouble(trBottomInt,Digits));
    }

    return (NoValue);
  }

//+------------------------------------------------------------------+
//| FOCAmp - Returns FOCAmp values                                   |
//+------------------------------------------------------------------+
double CTrendRegression::FOCAmp(int Measure)
  {
    switch (Measure)
    {
       case Now:           return (NormalizeDouble(trFOCAmpNow,1));
       case Max:           return (NormalizeDouble(trFOCAmpMax,1));
       case Peak:          return (NormalizeDouble(trFOCAmpPeak,1));
       case Mean:          return (NormalizeDouble(trFOCAmpMean,1));
       case MeanPeak:      return (NormalizeDouble(trFOCAmpMeanPeak,1));
       case MeanPositive:  return (NormalizeDouble(trFOCAmpMeanPos,1));
       case MeanNegative:  return (NormalizeDouble(trFOCAmpMeanNeg,1));
    }
        
    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| StdDev - Returns the requested StdDev measure                    |
//+------------------------------------------------------------------+
double CTrendRegression::StdDev(int Measure=Actual)
  {
    switch (Measure)
    {
       case Actual:        return (NormalizeDouble(trStdDev,Digits));
       case Now:           return (NormalizeDouble(trStdDevNow,Digits));
       case Positive:      return (NormalizeDouble(trStdDevPos,Digits));
       case Negative:      return (NormalizeDouble(trStdDevNeg,Digits));
       case Max:           return (fmax(trStdDevPos,fabs(trStdDevNeg)));
       case Min:           return (fmin(trStdDevPos,fabs(trStdDevNeg)));
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| UpdateBuffer - updates data and returns new buffer data          |
//+------------------------------------------------------------------+
void CTrendRegression::UpdateBuffer(double &PolyBuffer[], double &TrendBuffer[])
  {      
    UpdateBuffer(PolyBuffer);
    UpdateTrendline();

    if (ArraySize(TrendBuffer)>prPeriods)
      TrendBuffer[prPeriods] = 0.00;
            
    ArrayCopy(TrendBuffer,trData);
  }

//+------------------------------------------------------------------+
//| Update - Public interface to populate metrics                    |
//+------------------------------------------------------------------+
void CTrendRegression::Update(void)
  {    
    UpdatePoly();
    UpdateTrendline();
  }
