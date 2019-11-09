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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPolyRegression
  {
    
public:
    enum        WaveType
                {
                  Ebb,
                  Eddy,
                  Ordinary,
                  Riptide,
                  Tidal,
                  Rogue
                };

    //--- Wave Analytics Record
     struct     WaveSegment
                {
                  ReservedWords   Type;
                  int             Direction;
                  double          Open;
                  double          High;
                  double          Low;
                  double          Close;
                  bool            IsOpen;
                };

    //--- Crest/Trough analytics
     struct     WaveRec
                {
                  int             Action;
                  ReservedWords   State;
                  WaveSegment     Active[2];
                  WaveSegment     Crest;
                  WaveSegment     Trough;
                  bool            Breakout;
                  bool            Reversal;
                  bool            Retrace;
                };

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
       bool     Event(EventType Event)      { return (prEvents[Event]); }         //-- returns the event signal for the specified event
       bool     EventAlert(EventType Event, AlertLevelType AlertLevel)            //-- returns the event signal for the specified event & alert level
                                            { return (prEvents.EventAlert(Event,AlertLevel)); }
       bool     ActiveEvent(void)           { return (prEvents.ActiveEvent()); }  //-- returns true on active event
       string   ActiveEventText(const bool WithHeader=true)
                                            { return  (prEvents.ActiveEventText(WithHeader));}  //-- returns the string of active events
       

    //--- Poly properties
       double   MA(int Measure);
       double   Poly(int Measure);

       WaveRec       Wave(void) { return(prWave); }
       WaveSegment   ActiveWave(void) {return (prWave.Active[prWave.Action]); }
       WaveSegment   ActiveWaveSegment(void) {if (ActiveWave().Type==Crest) return (prWave.Crest); return (prWave.Trough); }
       ReservedWords PolyState(void) { return(prPolyState); }

    virtual
       int     Direction(int Direction, bool Contrarian=false);
     
protected:

       //--- Protected methods
    virtual
       void     CalcMA(void);
       void     CalcWave(void);
       void     UpdatePoly(void);
       
       //--- Event methods
       void     SetEvent(EventType Event, AlertLevelType AlertLevel=Notify)
                                 { prEvents.SetEvent(Event,AlertLevel); }    //-- sets the event condition
       void     ClearEvent(EventType Event) { prEvents.ClearEvent(Event); }  //-- clears the event condition
       
       bool     NewState(ReservedWords &State, ReservedWords ChangeState, bool Update=true);
       bool     NewDirection(int &Direction, int ChangeDirection, bool Update=true);


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
       int      prPolyTrendDir;
       
       double   prPolyBoundary;
       
       bool     prPolyCrest;
       bool     prPolyTrough;

       ReservedWords prPolyState;

       //--- Poly deviation
       double   prRSquared;    

private:

       //--- private methods
       void     CalcPolyState(void);
       void     CalcPoly(void);
       
       //--- Wave methods
       void     OpenWave(WaveSegment &Segment);
       void     CloseWave(WaveSegment &Segment, int Action=NoValue);
       void     UpdateWave(WaveSegment &Segment);

       void     InitWaveSegment(WaveSegment &Segment);
       void     InitWave(void);
       
       
       //--- Event Array
       CEvent   *prEvents;    //--- Event array

       WaveRec   prWave;
  };

//+------------------------------------------------------------------+
//| NewDirection - Returns true if a direction has a legit change    |
//+------------------------------------------------------------------+
bool CPolyRegression::NewDirection(int &Direction, int ChangeDirection, bool Update=true)
  {
    if (ChangeDirection==DirectionNone)
      return (false);
      
    //--- In this class, an invalid direction is always set with no change
    if (Direction==DirectionNone)
    {
      Direction                    = ChangeDirection;
      return (false);
    }
    
    return (IsChanged(Direction,ChangeDirection,Update));
  }
  
//+------------------------------------------------------------------+
//| NewState - Returns true if state has a legit change              |
//+------------------------------------------------------------------+
bool CPolyRegression::NewState(ReservedWords &State, ReservedWords ChangeState, bool Update=true)
  {    
    if (ChangeState==NoState)
      return (false);

    if (ChangeState==Breakout)
      if (State==Reversal)
        return (false);

    if (IsChanged(State,ChangeState))
    {
      switch (State)
      {
        case Rally:       SetEvent(NewRally,Nominal);
                          break;
        case Pullback:    SetEvent(NewPullback,Nominal);
                          break;
        case Crest:       SetEvent(NewCrest,Minor);
                          break;
        case Trough:      SetEvent(NewTrough,Minor);
                          break;
      }
      
      return (true);
    }
      
    return (false);
  }

//+------------------------------------------------------------------+
//| InitWaveSegment - Initializes wave segments on open              |
//+------------------------------------------------------------------+
void CPolyRegression::InitWaveSegment(WaveSegment &Segment)
  {
    Segment.Direction        = DirectionNone;
    Segment.Open             = Close[0];
    Segment.High             = Close[0];
    Segment.Low              = Close[0];
    Segment.Close            = Close[0];
    Segment.IsOpen           = false;
  }

//+------------------------------------------------------------------+
//| InitWave - Initializes wave properties on first use              |
//+------------------------------------------------------------------+
void CPolyRegression::InitWave(void)
  {
    prWave.Action            = NoValue;
    prWave.State             = NoState;

    InitWaveSegment(prWave.Active[OP_BUY]);
    InitWaveSegment(prWave.Active[OP_SELL]);
    InitWaveSegment(prWave.Crest);
    InitWaveSegment(prWave.Trough);
    
    prWave.Crest.Type        = Crest;
    prWave.Trough.Type       = Trough;
  }
 
//+------------------------------------------------------------------+
//| CloseWave - Closes the completed wave segment and updates state  |
//+------------------------------------------------------------------+
void CPolyRegression::CloseWave(WaveSegment &Segment, int Action=NoValue)
  {    
    Segment.IsOpen                = false;

    if (Segment.Type==Crest)
      if (Segment.Direction==DirectionUp)
        Action                    = OP_BUY;
      
    if (Segment.Type==Trough)
      if (Segment.Direction==DirectionDown)
        Action                    = OP_SELL;

    if (Action==NoValue)
    {
      //-- Manage rally/pullback; non-critical interior trading range
      if (prWave.Action==OP_BUY)
      {
        if (!IsHigher(Segment.High,prWave.Active[OP_BUY].High))
        {
          prWave.Reversal              = false;
          prWave.Breakout              = false;
        }
        
        if (Segment.Type==Trough)
        {
          prWave.Active[OP_BUY].Low    = Segment.Low;
          prWave.Retrace               = true;
        }
      }

      if (prWave.Action==OP_SELL)
      {
        if (!IsLower(Segment.Low,prWave.Active[OP_SELL].Low))
        {
          prWave.Reversal              = false;
          prWave.Breakout              = false;
        }
        
        if (Segment.Type==Crest)
        {
          prWave.Active[OP_SELL].High  = Segment.High;
          prWave.Retrace               = true;
        }
      }
    }
    else
    if (IsChanged(prWave.Action,Action))
    {
      //-- New Action Manager Assignment
      if (prWave.Action==OP_BUY)
      {
        prWave.Active[OP_SELL].Low     = fmin(prWave.Active[OP_SELL].Low,Segment.Low);
        
        prWave.Active[OP_BUY].Open     = prWave.Active[OP_SELL].Low;
        prWave.Active[OP_BUY].High     = Segment.High;
        prWave.Active[OP_BUY].Low      = prWave.Active[OP_SELL].Low;
        prWave.Active[OP_BUY].Close    = Segment.Low;
      }

      if (prWave.Action==OP_SELL)
      {
        prWave.Active[OP_BUY].High     = fmax(prWave.Active[OP_BUY].High,Segment.High);

        prWave.Active[OP_SELL].Open    = prWave.Active[OP_BUY].High;
        prWave.Active[OP_SELL].High    = prWave.Active[OP_BUY].High;
        prWave.Active[OP_SELL].Low     = Segment.Low;
        prWave.Active[OP_SELL].Close   = Segment.High;
      }

      prWave.Reversal                  = true;
    }
    else
    {
      //-- Manage major move price levels
      if (prWave.Action==OP_BUY)
      {
        prWave.Active[OP_BUY].High     = Segment.High;
        prWave.Active[OP_BUY].Close    = Segment.Low;
      }

      if (prWave.Action==OP_SELL)
      {
        prWave.Active[OP_SELL].Low     = Segment.Low;
        prWave.Active[OP_SELL].Close   = Segment.High;
      }

      prWave.Retrace                   = false;
    }
  }

//+------------------------------------------------------------------+
//| OpenWave - Starts a new wave segment                             |
//+------------------------------------------------------------------+
void CPolyRegression::OpenWave(WaveSegment &Segment)
  {
    InitWaveSegment(Segment);
    prWave.Active[prWave.Action].Type  = Segment.Type;
    Segment.IsOpen                     = true;
  }

//+------------------------------------------------------------------+
//| UpdateWave - Updates wave data and state                         |
//+------------------------------------------------------------------+
void CPolyRegression::UpdateWave(WaveSegment &Segment)
  {
    IsHigher(Close[0],Segment.High);
    IsLower(Close[0],Segment.Low);
    
    Segment.Close                  = Close[0];
    
    if (IsLower(Close[0],Segment.Open,NoUpdate))
      Segment.Direction            = DirectionDown;
      
    if (IsHigher(Close[0],Segment.Open,NoUpdate))
      Segment.Direction            = DirectionUp;
  
  }

//+------------------------------------------------------------------+
//| CalcWave - Manages Crest/Trough analytics points                 |
//+------------------------------------------------------------------+
void CPolyRegression::CalcWave(void)
  {
    switch (prPolyState)
    {
      case Pullback:   CloseWave(prWave.Crest);
                       break;
                       
      case Rally:      CloseWave(prWave.Trough);
                       break;

      case Crest:      if (prWave.Crest.IsOpen)
                         UpdateWave(prWave.Crest);
                       else
                         OpenWave(prWave.Crest);
                       break;
                    
      case Trough:     if (prWave.Trough.IsOpen)
                         UpdateWave(prWave.Trough);
                       else
                         OpenWave(prWave.Trough);
                       break;

      case NoState:    if (maData[ArraySize(maData)-1]>0.00)
                       {
                         if (prWave.Crest.IsOpen)
                           CloseWave(prWave.Crest);

                         if (prWave.Trough.IsOpen)
                           CloseWave(prWave.Crest);
                       }
                       else
                       if (Event(NewHigh)&&prWave.Action!=OP_BUY)
                       {
                         CloseWave(prWave.Trough,OP_BUY);
                         OpenWave(prWave.Crest);
                       }
                       else
                       if (Event(NewLow)&&prWave.Action!=OP_SELL)
                       {
                         CloseWave(prWave.Crest,OP_SELL);
                         OpenWave(prWave.Trough);
                       }                       
                       else
                       {
                         if (prWave.Crest.IsOpen)
                           UpdateWave(prWave.Crest);

                         if (prWave.Trough.IsOpen)
                           UpdateWave(prWave.Trough);
                       }
                       break;
    }
  }

//+------------------------------------------------------------------+
//| CalcPolyState - computes the current Poly state                  |
//+------------------------------------------------------------------+
void CPolyRegression::CalcPolyState(void)
  {
    ReservedWords cpState          = NoState;
    
    if (Event(NewPoly))
    {
      if (IsChanged(prPolyCrest,false))
        cpState                    = Pullback;

      if (IsChanged(prPolyTrough,false))
        cpState                    = Rally;
    }
    
    if (Event(NewHigh))
      if (Event(NewPolyBoundary))
        if (IsChanged(prPolyCrest,true))
          cpState                  = Crest;

    if (Event(NewLow))
      if (Event(NewPolyBoundary))
        if (IsChanged(prPolyTrough,true))
          cpState                  = Trough;

    if (NewState(prPolyState,cpState))
      SetEvent(NewPolyState,Minor);
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
     
    //-- Initialize trend direction (occurs once);
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
    
    prPolyState          = NoState;
    
    prPolyDirection      = DirectionNone;
    prPolyTrendDir       = DirectionNone;
    
    prPolyCrest          = false;
    prPolyTrough         = false;

    SetDegree(Degree);
    SetPeriods(Periods);
    SetMAPeriods(MAPeriods);
    
    InitWave();
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
       case Strength:   return (fdiv(maData[0]-prPolyBottom,this.Poly(Range)));
       case Deviation:  return (Pip(prPricePolyDev));
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
      prEvents.ClearEvents();
      
      CalcMA();

      CalcPoly();
      CalcPolyState();
      
      CalcWave();
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
