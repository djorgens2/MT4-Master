//+------------------------------------------------------------------+
//|                                               PolyRegression.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\ArrayDouble.mqh>
#include <stdutil.mqh>

//--- Expanded directional defines (for amplitudes)
#define  ShortCorrection     -4
#define  ShortReversal       -3
#define  Pullback            -2
#define  Rally                2
#define  LongReversal         3
#define  LongCorrection       4

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPolyRegression
  {

private:

    //--- private methods
       void     prCalcPolyState(void);
       void     prCalcPoly(void);
       void     prCalcPolyAmplitude(void);
       
    //--- Event Array
       bool     prEvents[EventTypes];    //--- Event array
    
public:

                CPolyRegression(int Degree, int PolyPeriods, int MAPeriods);
               ~CPolyRegression();
               
    virtual
       void     Update(void);
       void     UpdateBuffer(double &PolyBuffer[]);
     

    //--- configuration methods
    virtual
       void     SetPeriods(int Periods);
       void     SetDegree(int Degree)       { prDegree  = Degree; }
       void     SetMAPeriods(int MAPeriods) { maPeriods = MAPeriods; }
       
    //--- Event methods
       bool     Event(EventType Event) { return (prEvents[Event]); }    //-- returns the event signal for the specified event

    //--- Poly properties
       double   MA(int Measure);
       double   Poly(int Measure);
       double   Amp(int Measure);

       ReservedWords State(void) { return(prPolyState); }

    virtual
       int     Direction(int Direction, bool Contrarian=false);
     
protected:

    //--- Protected methods
    virtual
       void     CalcMA(void);
       void     UpdatePoly(void);

       //--- Event methods
       void     SetEvent(EventType Event)   { prEvents[Event]=true; }   //-- sets the event condition
       void     ClearEvent(EventType Event) { prEvents[Event]=false; }  //-- clears the event condition

       //--- input parameters
       int      prDegree;            // degree of regression
       int      prPeriods;           // number of periods
       int      maPeriods;           // periods to compute the slow ma on

       double   prData[];            // computed poly regression values
       double   maData[];            // base moving average data
       double   maTop;               // highest value in the madata array
       double   maBottom;            // lowest value in the madata array
       double   maMean;              // mean value of the madata array


       //--- PolyMeasures
       double   prPolyTop;
       double   prPolyBottom;
       double   prPolyMean;
       double   prPolyHead;
       double   prPolyTail;
       double   prPricePolyDev;

       int      prPolyDirection;
       int      prPolyAmpDirection;
       int      prTopBar;
       int      prBottomBar;

       ReservedWords prPolyState;


       //--- Amplitude Measures
       double   prAmpNow;             //--- Current amplitude (Head-Mean)
       double   prAmpMean;
       double   prAmpPositive;
       double   prAmpNegative;
       double   prAmpMax;
       double   prAmpMaxMean;

       int      prAmpDirection;

       //--- Poly deviation
       double   prRSquared;    
  };


//+------------------------------------------------------------------+
//| prCalcAmplitude - Compute Amplitude measures                     |
//+------------------------------------------------------------------+
void CPolyRegression::prCalcPolyAmplitude(void)
  {
    double negAmp       = 0.00;
    double posAmp       = 0.00;
    
    int    posCnt       = 0;
    int    negCnt       = 0;
    int    ampCnt       = 0;
    
    prAmpNow        = NormalizeDouble(prPolyHead,Digits)-NormalizeDouble(prPolyMean,Digits);
    prAmpMean       = 0.00;
    prAmpMax        = (prPolyTop-prPolyBottom)/2;
    prAmpMaxMean    = 0.00;
    
    for (int idx=0; idx<prPeriods; idx++)
    {
      if (NormalizeDouble(fabs(prData[idx]-prPolyMean),Digits)>0.00)
      {
        prAmpMean  += NormalizeDouble(fabs(prData[idx]-prPolyMean),Digits);
        ampCnt++;
     
        if (prData[idx]-prPolyMean>0.00)
        {
          posAmp       += NormalizeDouble(prData[idx]-prPolyMean,Digits);
          posCnt++;
        }

        if (prData[idx]-prPolyMean<0.00)
        {
          negAmp       += NormalizeDouble(prData[idx]-prPolyMean,Digits);
          negCnt++;
        }
      }
    }

    prAmpMean       = fdiv(prAmpMean,ampCnt);
    prAmpPositive   = fdiv(posAmp,posCnt);
    prAmpNegative   = fdiv(negAmp,negCnt);      
    prAmpMaxMean    = fdiv(prAmpPositive+fabs(prAmpNegative),2);
        
    //--- Set Amplitude direction
    if (prPolyHead>prPolyMean)
      prAmpDirection = DirectionUp;
      
    if (prPolyHead<prPolyMean)
      prAmpDirection = DirectionDown;
  }


//+------------------------------------------------------------------+
//| prCalcPolyState - computes prPoly state                          |
//+------------------------------------------------------------------+
void CPolyRegression::prCalcPolyState(void)
  {
    //--- Handle Extremes
    if (prTopBar == 0 || prBottomBar == 0)
    {
      prPolyState   = Max;
      
      if (prPolyDirection!=prPolyAmpDirection)
      {
        if (prTopBar == 0)
          if (prPolyDirection == DirectionDown)
            prPolyState = Reversal;

        if (prBottomBar == 0)
          if (prPolyDirection == DirectionUp)
            prPolyState = Reversal;
      }  
    }
    else
      
    //--- Handle Uptrends
    if (prTopBar<prBottomBar)
    {
      if (prPolyDirection == DirectionUp)
      {
        if (prPolyHead>prPolyMean)
          if (Low[0]>prPolyMean)
            prPolyState = Min;
          else
            prPolyState = Minor;

        if (prPolyHead<prPolyMean)
          if (High[0]>prPolyMean)
            prPolyState = Minor;
          else
            prPolyState = Major;
      }
      
      if (prPolyDirection == DirectionDown)
      {
        if (prPolyHead>prPolyMean)
          if (Low[0]>prPolyMean)
            if (High[0]>prPolyTop)
              prPolyState = Min;
            else
              prPolyState = Minor;

        if (prPolyHead<prPolyMean)
          if (High[0]<prPolyMean)
            prPolyState = Major;
          else
            prPolyState = Minor;
            
        if (Low[0]<prPolyBottom)
          prPolyState = Major;
      }
    }
    else
    
    //--- Handle Downtrends
    if (prTopBar>prBottomBar)
    {
      if (prPolyDirection == DirectionDown)
      {
        if (prPolyHead<prPolyMean)
          if (High[0]<prPolyMean)
            prPolyState = Min;   
          else
            prPolyState = Minor;

        if (prPolyHead>prPolyMean)
          if (Low[0]<prPolyMean)
            prPolyState = Minor;
          else
            prPolyState = Major;
      }
      
      if (prPolyDirection == DirectionUp)
      {
        if (prPolyHead<prPolyMean)
          if (High[0]<prPolyMean)
            prPolyState = Min;
          else
            prPolyState = Minor;

        if (prPolyHead>prPolyMean)
          if (Low[0]>prPolyMean)
            prPolyState = Major;
          else
            prPolyState = Minor;
            
        if (High[0]>prPolyTop)
          prPolyState = Major;
      }
    }
  }

//+------------------------------------------------------------------+
//| prCalcPoly - computes prPoly regression to x degree              |
//+------------------------------------------------------------------+
void CPolyRegression::prCalcPoly(void)
  {
    int    cpPolyDirection = prPolyDirection;
    
    double ai[10,10],b[10],x[10],sx[20];
    double sum; 
    double qq,mm,tt;

    int    ii,jj,kk,ll,nn;
    int    mi,n;

    double mean_y   = 0.00;
    double se_l     = 0.00;
    double se_y     = 0.00;
        
    ArrayInitialize(prData,0.00);

    sx[1]  = prPeriods+1;
    nn     = prDegree+1;
   
     //----------------------sx-------------
     for(mi=1;mi<=nn*2-2;mi++)
     {
       sum=0;
       for(n=0;n<=prPeriods; n++)
       {
          sum+=MathPow(n ,mi);
       }
       sx[mi+1]=sum;
     }  
     
     //----------------------syx-----------
     ArrayInitialize(b,0.00);
     for(mi=1;mi<=nn;mi++)
     {
       sum=0.00000;
       for(n=0;n<=prPeriods;n++)
       {
          if(mi==1) 
            sum += maData[n];
          else 
            sum += maData[n]*MathPow(n, mi-1);
       }
       b[mi]=sum;
     } 
     
     //===============Matrix================
     ArrayInitialize(ai,0.00);
     for(jj=1;jj<=nn;jj++)
     {
       for(ii=1; ii<=nn; ii++)
       {
          kk=ii+jj-1;
          ai[ii,jj]=sx[kk];
       }
     }

     //===============Gauss=================
     for(kk=1; kk<=nn-1; kk++)
     {
       ll=0;
       mm=0;
       for(ii=kk; ii<=nn; ii++)
       {
          if(MathAbs(ai[ii,kk])>mm)
          {
             mm=MathAbs(ai[ii,kk]);
             ll=ii;
          }
       }
       if (ll!=kk)
       {
          for(jj=1; jj<=nn; jj++)
          {
             tt=ai[kk,jj];
             ai[kk,jj]=ai[ll,jj];
             ai[ll,jj]=tt;
          }
          tt=b[kk];
          b[kk]=b[ll];
          b[ll]=tt;
       }  
       for(ii=kk+1;ii<=nn;ii++)
       {
          qq=ai[ii,kk]/ai[kk,kk];
          for(jj=1;jj<=nn;jj++)
          {
             if(jj==kk) ai[ii,jj]=0;
             else ai[ii,jj]=ai[ii,jj]-qq*ai[kk,jj];
          }
          b[ii]=b[ii]-qq*b[kk];
       }
     }  
     x[nn]=b[nn]/ai[nn,nn];
     for(ii=nn-1;ii>=1;ii--)
     {
       tt=0;
       for(jj=1;jj<=nn-ii;jj++)
       {
          tt=tt+ai[ii,ii+jj]*x[ii+jj];
          x[ii]=(1/ai[ii,ii])*(b[ii]-tt);
       }
     } 
     //=====================================
     
     for(n=0;n<=prPeriods-1;n++)
     {
       sum=0;
       for(kk=1;kk<=prDegree;kk++)
       {
          sum+=x[kk+1]*MathPow(n,kk);
       }
       mean_y += x[1]+sum;

       prData[n]=x[1]+sum;
     }

     //--- Compute poly range data
     mean_y = mean_y/prPeriods;

     prPolyTop         = prData[0];
     prPolyBottom      = prData[0];
     
     prTopBar          = 0;
     prBottomBar       = 0;

     for (n=0;n<prPeriods;n++)
     {
       se_l           += pow(maData[n]-prData[n],2);
       se_y           += pow(prData[n]-mean_y,2);
       
       if (IsChanged(prPolyTop,fmax(prPolyTop,prData[n])))
         prTopBar      = n;
         
       if (IsChanged(prPolyBottom,fmin(prPolyBottom,prData[n])))
         prBottomBar   = n;
     }

     prRSquared        = ((1-(se_l/se_y))*100);  //--- R^2 factor
     prPolyMean        = fdiv(prPolyTop-prPolyBottom,2)+prPolyBottom;
     prPolyHead        = prData[0];
     prPolyTail        = prData[prPeriods-1];
     prPricePolyDev    = maData[0]-prPolyHead;
     
     if (prData[0]-prData[2]>0.00)
       cpPolyDirection = DirectionUp;
     else  
     if (prData[0]-prData[2]<0.00)
       cpPolyDirection = DirectionDown;
     else
       cpPolyDirection = DirectionNone;
       
     if (IsChanged(prPolyDirection,cpPolyDirection))
     {
       if (prTopBar<prBottomBar)
         prPolyAmpDirection = DirectionUp;

       if (prTopBar>prBottomBar)
         prPolyAmpDirection = DirectionDown;
     }
  }


//+------------------------------------------------------------------+
//| CalcMA - computes the SMA used to base the poly regression       |
//+------------------------------------------------------------------+
void CPolyRegression::CalcMA(void)
  {
    double agg  = 0.00;
    
    maTop       = 0.00;
    maBottom    = 999.99;
    maMean      = 0.00;
    
    ArrayInitialize(maData,0.00);
    
    for (int pidx=0; pidx<ArraySize(maData); pidx++)
    {
      agg   = 0.00;

      for (int midx=pidx;midx<maPeriods+pidx;midx++)
        agg += Close[midx];

      maData[pidx] = agg/maPeriods;
      
      IsHigher(maData[pidx],maTop);
      IsLower(maData[pidx],maBottom);
      
      if (pidx<prPeriods)
        maMean    += maData[pidx];
    }
    
    maMean        /= prPeriods;
  }


//+------------------------------------------------------------------+
//| SetPeriods - Configure period objects and parameters             |
//+------------------------------------------------------------------+
void CPolyRegression::SetPeriods(int Periods)
  {
    prPeriods = Periods;
    
    ArrayResize(prData,Periods);
    ArrayResize(maData,prPeriods+prDegree);
  }


//+------------------------------------------------------------------+
//| Constructor - initialize values on start                         |
//+------------------------------------------------------------------+
CPolyRegression::CPolyRegression(int Degree, int Periods, int MAPeriods)
  {
    SetDegree(Degree);
    SetPeriods(Periods);
    SetMAPeriods(MAPeriods); 
  }


//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPolyRegression::~CPolyRegression()
  {
  }
    
//+------------------------------------------------------------------+
//| Direction - Returns the requested Direction for the given type   |
//+------------------------------------------------------------------+
int CPolyRegression::Direction(int Type, bool Contrarian=false)
  {
    int dContrary     = 1;
    
    if (Contrarian)
      dContrary       = DirectionInverse;

    switch (Type)
    {
      case PolyAmplitude: return (prPolyAmpDirection*dContrary);
      case Polyline:      return (prPolyDirection*dContrary);
      case Amplitude:     return (prAmpDirection*dContrary);
    }
    
    return (DirectionNone);
  }
  
  
//+------------------------------------------------------------------+
//| Poly - Returns the requested Poly measure                        |
//+------------------------------------------------------------------+
double CPolyRegression::MA(int Measure)
  {
    switch (Measure)
    {
       case Now:        return (NormalizeDouble(maData[0],Digits));
       case Top:        return (NormalizeDouble(maTop,Digits));
       case Bottom:     return (NormalizeDouble(maBottom,Digits));
       case Mean:       return (NormalizeDouble(maMean,Digits));
    }
    
    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| Poly - Returns the requested Poly measure                        |
//+------------------------------------------------------------------+
double CPolyRegression::Poly(int Measure)
  {
    switch (Measure)
    {
       case Now:        return (NormalizeDouble(prData[0],Digits));
       case Top:        return (NormalizeDouble(prPolyTop,Digits));
       case Bottom:     return (NormalizeDouble(prPolyBottom,Digits));
       case Mean:       return (NormalizeDouble(prPolyMean,Digits));
       case Head:       return (NormalizeDouble(prPolyHead,Digits));
       case Tail:       return (NormalizeDouble(prPolyTail,Digits));
       case Range:      return (NormalizeDouble(prPolyTop-prPolyBottom,Digits));
       case Deviation:  return (Pip(prPricePolyDev));
    }
    
    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| Amp - Returns the requested Amplitude measure                    |
//+------------------------------------------------------------------+
double CPolyRegression::Amp(int Measure)
  {
    switch (Measure)
    {    
       case Now:        return (NormalizeDouble(prAmpNow,Digits));
       case Mean:       return (NormalizeDouble(prAmpMean,Digits));
       case Positive:   return (NormalizeDouble(prAmpPositive,Digits));
       case Negative:   return (NormalizeDouble(prAmpNegative,Digits));
       case Max:        return (NormalizeDouble(prAmpMax,Digits));
       case MaxMean:    return (NormalizeDouble(prAmpMaxMean,Digits));
    }
    
    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| Update - Public interface to populate metrics                    |
//+------------------------------------------------------------------+
void CPolyRegression::UpdatePoly(void)
  {    
    if (Bars > prPeriods)
    {
      CalcMA();

      prCalcPoly();
      prCalcPolyState();
      prCalcPolyAmplitude();
    }
  }
  

//+------------------------------------------------------------------+
//| UpdateBuffer - Public interface to calc and copy buffer data     |
//+------------------------------------------------------------------+
void CPolyRegression::UpdateBuffer(double &PolyBuffer[])
  {    
    UpdatePoly();
    
    if (ArraySize(PolyBuffer)>prPeriods)
      PolyBuffer[prPeriods] = 0.00;

    ArrayCopy(PolyBuffer,prData);
  }
  
//+------------------------------------------------------------------+
//| Update - Public interface to populate metrics                    |
//+------------------------------------------------------------------+
void CPolyRegression::Update(void)
  {    
    UpdatePoly();
  }
