//+------------------------------------------------------------------+
//|                                                PipRegression.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\TrendRegression.mqh>


//--- pipma state defs


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPipRegression : public CTrendRegression
  {

public:
       enum     RangeStateType
                {
                   SevereContraction   = -4,
                   ActiveContraction   = -3,
                   Contracting         = -2,
                   IdleContraction     = -1,
                   IdleFlat            =  0,
                   IdleExpansion       =  1,
                   Expanding           =  2,
                   ActiveExpansion     =  3,
                   SevereExpansion     =  4
                };

                CPipRegression(int Degree, int Periods, double Tolerance, double AggFactor, int IdleTime);
               ~CPipRegression();                     

    virtual
       void     UpdateBuffer(double &MA[], double &PolyBuffer[], double &TrendBuffer[]);
       
    virtual
       void     Update(void);
       
    void        SetMarketIdleTime(int IdleTime) {ptrMarketIdleTime = IdleTime;};

    
    RangeStateType TrendState(void) {return (ptrRangeState);};
    
    virtual
       int      Direction(int Direction, bool Contrarian=false);
       int      Age(int Measure);
       double   Range(int Measure);
       int      History(void)  {return (pipHistory.Count);};
       bool     HistoryLoaded(void) {return (pipHistory.Count == prPeriods+prDegree);};

protected:
    
    virtual
       void     CalcMA();

                CArrayDouble *pipHistory;

       bool     RangeChanged[3];

       int      ptrTick;
       int      ptrTickDir;       
       int      ptrRangeAge;
       int      ptrRangeAgeHigh;
       int      ptrRangeAgeLow;
       int      ptrMarketIdleTime;
       
       double   ptrAggFactor;
       double   ptrRangeSize;
       double   ptrRangeMean;
       double   ptrPriceHigh;
       double   ptrPriceLow;
       double   ptrPriceMid;
              
       RangeStateType  ptrRangeState;

       int      ptrRangeDir;
       int      ptrRangeDirHigh;
       int      ptrRangeDirLow;
        
private:

       bool             CalcDirection(double Last, double Current, int &Direction);
       RangeStateType   CalcState(double Last, double Current);        
  };


//--- Private methods

//+------------------------------------------------------------------+
//| CalcDirection - Computes direction and returns true if changed   |
//+------------------------------------------------------------------+
bool CPipRegression::CalcDirection(double Last, double Current, int &Direction)
  {
    if (NormalizeDouble(Current,Digits)==NormalizeDouble(Last,Digits))
      return (false);

    if (NormalizeDouble(Current,Digits)>NormalizeDouble(Last,Digits))
      Direction = DirectionUp;

    if (NormalizeDouble(Current,Digits)<NormalizeDouble(Last,Digits))
      Direction = DirectionDown;

    return (true);
  }

//+------------------------------------------------------------------+
//| CalcState - Analyzes range data and computes state               |
//+------------------------------------------------------------------+
RangeStateType CPipRegression::CalcState(double Last, double Current)
  {
    const int Severe           = 4;
    int       State            = 0;
    int       Direction        = ptrRangeDirHigh+ptrRangeDir+ptrRangeDirLow;
    double    Tolerance        = 0.0;
    
    for (int idx=0; idx<3; idx++)
      if (RangeChanged[idx])
        State += (int)(pow(2,idx));

    //--- compute market action
    if (State == 0) //--- no change
    {
      //--- hold severe states
      if (fabs(ptrRangeState)==Severe)
        return (ptrRangeState);
        
      //--- validate expansion state
      if (ptrRangeState>IdleFlat)
      { 
        Tolerance = fabs(Pip(trTrendlineTolerance,InPoints)*ptrRangeState);

        if (ptrRangeDir==DirectionUp)
        {
          if (NormalizeDouble(Close[0],Digits)>NormalizeDouble(ptrPriceHigh,Digits)-NormalizeDouble(Tolerance,Digits))
            return (fmin(ptrRangeState,ActiveExpansion));
          else
          if (NormalizeDouble(Close[0],Digits)>NormalizeDouble(ptrPriceMid,Digits))
            return (fmin(ptrRangeState,Expanding));
          else
            return (IdleExpansion);
        }    
        else
        if (ptrRangeDir==DirectionDown)
        {
          if (NormalizeDouble(Close[0],Digits)>NormalizeDouble(ptrPriceLow,Digits)+NormalizeDouble(Tolerance,Digits))
            return (fmin(ptrRangeState,ActiveExpansion));
          else
          if (NormalizeDouble(Close[0],Digits)<NormalizeDouble(ptrPriceMid,Digits))
            return (fmin(ptrRangeState,Expanding));
          else
            return (IdleExpansion);
        }    
      }
      
      //--- validate contraction state
      if (ptrRangeState<IdleFlat)
      {
        if (FOCDirection()!=ptrRangeDir)
          return (IdleFlat);
        
        if (fabs(trFOCNow)>Tolerance)
          return (fmax(ptrRangeState,Contracting));

        return (IdleContraction);
      }
    }
    else
    {
      //--- calc market expansion
      if (NormalizeDouble(Current,Digits)>NormalizeDouble(Last,Digits))
      {  
        if (State == 7) //--- severe change
          return (SevereExpansion);
          
        return (fmax(ptrRangeState,ActiveExpansion));
      }

      //--- calc market contraction
      if (NormalizeDouble(Current,Digits)<NormalizeDouble(Last,Digits))
      {
        if (State == 7) //--- severe change
          if (ptrRangeState<Expanding)
            return (SevereContraction);

        return (fmin(ptrRangeState,ActiveContraction));
      }
    }

    return (ptrRangeState);
  }

//+------------------------------------------------------------------+
//| CalcMA - Morphs the global CalcMA to calc on pip history         |
//+------------------------------------------------------------------+
void CPipRegression::CalcMA(void)
  {
    static int  cmaRangeDir     = DirectionNone;
    
    if (NormalizeDouble(fabs(Pip(pipHistory[0]-Close[0])),Digits)>=ptrAggFactor)
    {

      pipHistory.Insert(0,Close[0]);
      pipHistory.Copy(maData);
      
      //--- set ma values
      maMean             = NormalizeDouble(pipHistory.Average(),Digits);
      maTop              = NormalizeDouble(pipHistory.Maximum(),Digits);
      maBottom           = NormalizeDouble(pipHistory.Minimum(),Digits);

      //--- calc range directions      
      RangeChanged[0]    = CalcDirection(ptrPriceMid,pipHistory.Mid(),ptrRangeDir);
      RangeChanged[1]    = CalcDirection(ptrPriceHigh,pipHistory.Maximum(),ptrRangeDirHigh);
      RangeChanged[2]    = CalcDirection(ptrPriceLow,pipHistory.Minimum(),ptrRangeDirLow);

      ptrRangeState      = CalcState(ptrRangeSize,pipHistory.Range());
      
      ptrRangeMean       = NormalizeDouble(pipHistory.Average(),Digits);
      ptrPriceHigh       = NormalizeDouble(pipHistory.Maximum(),Digits);
      ptrPriceLow        = NormalizeDouble(pipHistory.Minimum(),Digits);
      ptrPriceMid        = NormalizeDouble(pipHistory.Mid(),Digits);
      ptrRangeSize       = NormalizeDouble(pipHistory.Range(),Digits);
            
      //--- calc direction changes
      ptrTick            = 0;
      
      if (pipHistory[0]>pipHistory[1])
        ptrTickDir       = DirectionUp;
 
      if (pipHistory[0]<pipHistory[1])
        ptrTickDir       = DirectionDown;
        
      ClearEvent(NewHigh);
      ClearEvent(NewLow);
      ClearEvent(NewBoundary);
        
      if (NormalizeDouble(Close[0],Digits)>=NormalizeDouble(ptrPriceHigh,Digits))
        SetEvent(NewHigh,Nominal);
        
      if (NormalizeDouble(Close[0],Digits)<=NormalizeDouble(ptrPriceLow,Digits))
        SetEvent(NewLow,Nominal);
        
      if (Event(NewHigh)||Event(NewLow))
      {
        if (IsChanged(cmaRangeDir,ptrRangeDir))
          ptrRangeAge     = 0;

        if (Event(NewHigh))
          ptrRangeAgeHigh = 0;

        if (Event(NewLow))
          ptrRangeAgeLow  = 0;

        SetEvent(NewBoundary);
      }
        
      ptrRangeAgeHigh++;
      ptrRangeAgeLow++;
      ptrRangeAge++;
    }

    ptrTick++;
  }

//--- Public methods

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPipRegression::CPipRegression(int Degree, int Periods, double Tolerance, double AggFactor, int IdleTime) : CTrendRegression(Degree,Periods,0)
  {
    SetTrendlineTolerance(Tolerance);
    SetMarketIdleTime(IdleTime);
    
    pipHistory = new CArrayDouble(Degree+Periods);
    pipHistory.Truncate  = true;

    pipHistory.SetAutoCompute(true);
    pipHistory.SetPrecision(Digits);
    
    ptrAggFactor         = AggFactor;
    ptrTick              = 0;
    ptrTickDir           = DirectionNone;
  }
  
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPipRegression::~CPipRegression()
  {
    delete pipHistory;
  }

//+------------------------------------------------------------------+
//|  Range - returns the value for the supplied Measure              |
//+------------------------------------------------------------------+
double CPipRegression::Range(int Measure)
  {
    switch (Measure)
    {
      case Size:         return (ptrRangeSize);
      case Mean:         return (ptrRangeMean);
      case Top:          return (ptrPriceHigh);
      case Bottom:       return (ptrPriceLow);
      case Mid:          return (ptrPriceMid);
    }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//|  Direction - returns the direction for the supplied type         |
//+------------------------------------------------------------------+
int CPipRegression::Direction(int Type, bool Contrarian=false)
  {
    int dContrary     = 1;
    
    if (Contrarian)
      dContrary       = DirectionInverse;

    switch (Type)
    {
      case PolyTrend:     return (prPolyTrendDir*dContrary);
      case Polyline:      return (prPolyDirection*dContrary);
      case Trendline:     return (trTrendlineDir*dContrary);
      case Pivot:         return (trPivotDir*dContrary);
      case StdDev:        return (trStdDevDir*dContrary);
      case Range:         return (ptrRangeDir*dContrary);
      case RangeHigh:     return (ptrRangeDirHigh*dContrary);
      case RangeLow:      return (ptrRangeDirLow*dContrary);
      case Boundary:      if ((ptrRangeAgeLow-ptrRangeAgeHigh)*dContrary>0) return (DirectionUp);
                          if ((ptrRangeAgeLow-ptrRangeAgeHigh)*dContrary<0) return (DirectionDown);
                          return (this.Direction(Range));
      case Aggregate:     return (BoolToInt(ptrRangeDirHigh==ptrRangeDirLow,ptrRangeDirHigh*dContrary,DirectionNone));
      case Tick:          return (ptrTickDir*dContrary);
    }

    return (ptrRangeDir);
  }

//+------------------------------------------------------------------+
//|  Age - returns the value for the supplied Measure                |
//+------------------------------------------------------------------+
int CPipRegression::Age(int Measure)
  {
    switch (Measure)
    {
      case History:        return (pipHistory.Count);
      case Tick:           return (ptrTick);
      case Boundary:       return (fmin(ptrRangeAgeHigh,ptrRangeAgeLow));
      case Range:          return (ptrRangeAge);
      case RangeHigh:      return (ptrRangeAgeHigh);
      case RangeLow:       return (ptrRangeAgeLow);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//|  UpdateBuffer - Updates data and returns buffer                  |
//+------------------------------------------------------------------+
void CPipRegression::UpdateBuffer(double &MA[], double &PolyBuffer[], double &TrendBuffer[])
  {    
    if (HistoryLoaded())
      UpdateBuffer(PolyBuffer,TrendBuffer);
    else
      CalcMA();
      
    ArrayCopy(MA,maData,0,0,fmin(prPeriods,pipHistory.Count));
  }

//+------------------------------------------------------------------+
//| Update - Public interface to populate metrics                    |
//+------------------------------------------------------------------+
void CPipRegression::Update(void)
  {
    if (HistoryLoaded())
    {
      UpdatePoly();
      UpdateTrendline();
    }
    else
      CalcMA();

  }
