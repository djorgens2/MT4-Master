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
#define  SevereContraction   -4
#define  ActiveContraction   -3
#define  Contracting         -2
#define  IdleContraction     -1
#define  Idle                 0
#define  IdleExpansion        1
#define  Expanding            2
#define  ActiveExpansion      3
#define  SevereExpansion      4


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPipRegression : public CTrendRegression
  {

private:

       bool     CalcDirection(double Last, double Current, int &Direction);
       int      CalcState(double Last, double Current);
        

public:

                CPipRegression(int Degree, int Periods, double Tolerance);
               ~CPipRegression();                     

    virtual
       void     UpdateBuffer(double &MA[], double &PolyBuffer[], double &TrendBuffer[]);
       
    virtual
       void     Update(void);

    virtual
       int      Direction(int Direction, bool Contrarian=false);
       string   Text(int Type);
       int      Age(int Measure);
       double   Range(int Measure);
       bool     HistoryLoaded(void) {return (pipHistory.Count == prPeriods+prDegree); }

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
       
       double   ptrRangeSize;
       double   ptrRangeMean;
       double   ptrPriceHigh;
       double   ptrPriceLow;
       double   ptrPriceMid;
              
       int      ptrRangeState;
       int      ptrRangeDir;
       int      ptrRangeDirHigh;
       int      ptrRangeDirLow;
        
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
int CPipRegression::CalcState(double Last, double Current)
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
      if (ptrRangeState>Idle)
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
      if (ptrRangeState<Idle)
      {
        if (FOCDirection()!=ptrRangeDir)
          return (Idle);
        
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
    static int cmaRangeDir  = DirectionNone;
    static int cmaAggregate = DirectionNone;
    
    ClearEvent(NewAggregate);
    
    if (NormalizeDouble(fabs(Pip(pipHistory[0]-Close[0])),Digits)>=1.0)
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
        SetEvent(NewHigh);
        
      if (NormalizeDouble(Close[0],Digits)<=NormalizeDouble(ptrPriceLow,Digits))
        SetEvent(NewLow);
        
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

    if (IsChanged(cmaAggregate,ptrRangeDirHigh+ptrRangeDirLow))
      SetEvent(NewAggregate);

    ptrTick++;
  }

//--- Public methods

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPipRegression::CPipRegression(int Degree, int Periods, double Tolerance) : CTrendRegression(Degree,Periods,0)
  {
    SetTrendlineTolerance(Tolerance);
    
    pipHistory = new CArrayDouble(Degree+Periods);    
    pipHistory.Truncate  = true;

    pipHistory.SetAutoCompute(true,0,Periods);
    pipHistory.SetPrecision(Digits);
    
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
      case PolyAmplitude: return (prPolyAmpDirection*dContrary);
      case Polyline:      return (prPolyDirection*dContrary);
      case Amplitude:     return (prAmpDirection*dContrary);
      case Trendline:     return (trTrendlineDir*dContrary);
      case Pivot:         return (trPivotDir*dContrary);
      case StdDev:        return (trStdDevDir*dContrary);
      case Range:         return (ptrRangeDir*dContrary);
      case RangeHigh:     return (ptrRangeDirHigh*dContrary);
      case RangeLow:      return (ptrRangeDirLow*dContrary);
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
  
//+------------------------------------------------------------------+
//| Text - translates supplied type code to text                     |
//+------------------------------------------------------------------+
string CPipRegression::Text(int Type)
{
  if (Type == InState)
    switch (ptrRangeState)
    {
      case SevereContraction:   return("Severe Contraction");
      case ActiveContraction:   return("Active Contraction");
      case Contracting:         return("Contracting");
      case IdleContraction:     return("Idle Contraction");
      case Idle:                return("Idle");
      case IdleExpansion:       return("Idle Expansion");
      case Expanding:           return("Expanding");
      case ActiveExpansion:     return("Active Expansion");
      case SevereExpansion:     return("Severe Expansion");
      default:                  return("Bad State Code");
    }
  
  if (Type == InDirection)
    switch (trFOCAmpDir)
    {
      case ShortCorrection:     return("Correction(S)");
      case ShortReversal:       return("Reversal(S)");
      case MarketPullback:      return("Pullback");
      case DirectionDown:       return("Short");
      case DirectionNone:       return("None");
      case DirectionUp:         return("Long");
      case MarketRally:         return("Rally");
      case LongReversal:        return("Reversal(L)");
      case LongCorrection:      return("Correction(L)");
      default:                  return("Bad Direction Code");
    }
    
  return ("Bad text type");
}
