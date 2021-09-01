//+------------------------------------------------------------------+
//|                                               PolyRegression.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\Event.mqh>
#include <Class\ArrayDouble.mqh>
#include <stdutil.mqh>
#include <std_utility.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPolyRegression
  {
    
public:

                CPolyRegression(int Degree, int PolyPeriods, int MAPeriods);
               ~CPolyRegression();
                
    virtual
       void     Update(void);
       void     UpdateBuffer(double &PolyBuffer[]);
     

       //--- Event methods
       bool     Event(EventType Event)      { return (prEvents[Event]); }         //-- returns the event signal for the specified event
       bool     Event(EventType Event, AlertLevelType AlertLevel)            //-- returns the event signal for the specified event & alert level
                                            { return (prEvents.Event(Event,AlertLevel)); }
       bool     ActiveEvent(void)           { return (prEvents.ActiveEvent()); }  //-- returns true on active event
       string   ActiveEventText(const bool WithHeader=true)
                                            { return  (prEvents.ActiveEventText(WithHeader));}  //-- returns the string of active events
       

       //--- Poly methods
       double           MA(int Measure);
       double           Poly(int Measure);
       
    virtual
       int              Direction(int Direction, bool Contrarian=false);
     
protected:

       //--- Protected methods
    virtual
       void             CalcMA(void);
       void             UpdatePoly(void);
       
       //--- configuration methods
    virtual
       void             SetPeriods(int Periods);
       void             SetDegree(int Degree)       { prDegree  = Degree; }
       void             SetMAPeriods(int MAPeriods) { maPeriods = MAPeriods; }       
       
       
       //--- Event methods
       void             SetEvent(EventType Event, AlertLevelType AlertLevel=Notify)
                                                    { prEvents.SetEvent(Event,AlertLevel); }   //-- sets the event condition
       void             ClearEvent(EventType Event) { prEvents.ClearEvent(Event); }            //-- clears the event condition
       bool             NewDirection(int &Direction, int ChangeDirection, bool Update=true);


       //--- input parameters
       int              prDegree;            // degree of regression
       int              prPeriods;           // number of periods
       int              maPeriods;           // periods to compute the slow ma on

       double           prData[];            // computed poly regression values
       double           maData[];            // base moving average data
       double           maTop;               // highest value in the madata array
       double           maBottom;            // lowest value in the madata array
       double           maMean;              // mean value of the madata array


       //--- PolyMeasures
       double           prPolyTop;
       double           prPolyBottom;
       double           prPolyMean;
       double           prPolyHead;
       double           prPolyTail;
       double           prPricePolyDev;

       int              prPolyDirection;
       int              prPolyTrendDir;
       
       double           prPolyBoundary;
       
       bool             prPolyCrest;
       bool             prPolyTrough;

       ReservedWords prPolyState;

       //--- Poly deviation
       double           prRSquared;    

private:

       //--- Event Array
       CEvent          *prEvents;    //--- Event array

       void             CalcPoly(void);
  };

//+------------------------------------------------------------------+
//| NewDirection - Returns true if a direction has a legit change    |
//+------------------------------------------------------------------+
bool CPolyRegression::NewDirection(int &Direction, int ChangeDirection, bool Update=true)
  {
    if (ChangeDirection==DirectionNone)
      return (false);
      
    //--- In this class, an invalid direction is always set with no change
    //--- To override this behavior, send ChangeDirection=DirectionChange
    if (Direction==DirectionNone)
    {
      Direction                    = ChangeDirection;
      return (false);
    }
    
    return (IsChanged(Direction,ChangeDirection,Update));
  }

//+------------------------------------------------------------------+
//| CalcPoly - computes polynomial regression to x degree            |
//+------------------------------------------------------------------+
void CPolyRegression::CalcPoly(void)
  {
    int    cpTopBar           = 0;
    int    cpBottomBar        = 0;
    int    cpTrendDir         = DirectionNone;

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

    for (n=0;n<prPeriods;n++)
    {
      se_l           += pow(maData[n]-prData[n],2);
      se_y           += pow(prData[n]-mean_y,2);
      
      if (IsChanged(prPolyTop,fmax(prPolyTop,prData[n])))
        cpTopBar      = n;
        
      if (IsChanged(prPolyBottom,fmin(prPolyBottom,prData[n])))
        cpBottomBar   = n;
    }

    prRSquared        = ((1-(se_l/se_y))*100);  //--- R^2 factor
    prPolyMean        = fdiv(prPolyTop-prPolyBottom,2)+prPolyBottom;
    prPolyHead        = prData[0];
    prPolyTail        = prData[prPeriods-1];
    prPricePolyDev    = maData[0]-prPolyHead;
     
    //-- Complete init on first CalcPoly (occurs once);
    if (prPolyTrendDir==DirectionNone)
    {
      prPolyTrendDir    = Direction(cpBottomBar-cpTopBar);
      prPolyBoundary    = prPolyMean;
    }

    //-- Calculate changes in poly direction and boundary
    if (IsEqual(prPolyHead,prPolyTop))
    {
      cpTrendDir        = DirectionUp;
      
      if (IsHigher(prPolyTop,prPolyBoundary))
        SetEvent(NewPolyBoundary,Minor);
    }

    if (IsEqual(prPolyHead,prPolyBottom))
    {
      cpTrendDir        = DirectionDown;

      if (IsLower(prPolyBottom,prPolyBoundary))
        SetEvent(NewPolyBoundary,Minor);
    }
    
    if (NewDirection(prPolyTrendDir,cpTrendDir))
    {
      prPolyBoundary    = BoolToDouble(cpTrendDir==DirectionUp,prPolyTop,prPolyBottom);
      SetEvent(NewPolyTrend,Minor);
    }
    
    if (NewDirection(prPolyDirection,Direction(prData[0]-prData[2])))
      SetEvent(NewPoly,Nominal);
  }


//+------------------------------------------------------------------+
//| CalcMA - computes the SMA used to base the poly regression       |
//+------------------------------------------------------------------+
void CPolyRegression::CalcMA(void)
  {
    double agg  = 0.00;
    
    if (IsHigher(Close[0],maTop))
      SetEvent(NewHigh,Nominal);
      
    if (IsLower(Close[0],maBottom))
      SetEvent(NewLow,Nominal);
      
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
    prEvents             = new CEvent();
    
    prPolyDirection      = DirectionNone;
    prPolyTrendDir       = DirectionNone;
    
    SetDegree(Degree);
    SetPeriods(Periods);
    SetMAPeriods(MAPeriods);
  }


//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPolyRegression::~CPolyRegression()
  {
    delete prEvents;
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
      case PolyTrend:     return (prPolyTrendDir*dContrary);
      case Polyline:      return (prPolyDirection*dContrary);
    }
    
    return (DirectionNone);
  }
  
  
//+------------------------------------------------------------------+
//| MA - Returns the requested MA measure                            |
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
       case Deviation:  return (pip(prPricePolyDev));
    }
    
    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| UpdatePoly - Public interface to populate metrics                |
//+------------------------------------------------------------------+
void CPolyRegression::UpdatePoly(void)
  {    
    if (Bars > prPeriods)
    {
      prEvents.ClearEvents();
      
      CalcMA();
      CalcPoly();
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

