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
               rmMean,
               RegressionMethods
             };

       struct SMARec
        {
          int          Bias;
          double       Fast;
          double       Slow;
        };

      struct           TickRec
        {
          int          Bias;      //-- Slow v. Fast direction
          EventType    Event;     //-- Tick Event
          double       Open;      //-- Open on Agg Tick Segment
          double       High;      //-- Highest Price below Open
          double       Low;       //-- Lowest Price below Open
          double       Close[];   //-- Tick History
          double       Retrace;   //-- Active Retrace
          SMARec       SMA[];     //-- Tick SMA
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

      struct RegrRec
        {
          int          Direction;
          int          BreakoutDir;
          int          Bias;
          EventType    Event;
          int          Age;
          double       Open[];
          double       High;
          double       Low;
          double       Close[];
          double       Momentum;                 //-- Variance from last Close-Open;
          double       Regr[RegressionMethods];  //-- Regression Analysis Return (Slope/R^2/etc);
        };

      struct MasterRec
        {
          int          BreakoutDir;
          int          Direction;
          int          Bias;
          double       High;
          double       Low;
          bool         Locked;
          TickRec      Tick;
          OHLCRec      SMA;
          OHLCRec      History[];
          RegrRec      Poly;
          RegrRec      Slope;
        };

      //-- Methods
      double         CalcSMA(OHLCRec &OHLC[], RegressionMethod Method, int Segments);
      double         CalcPoly(OHLCRec &OHLC[], double &Poly[], RegressionMethod Method);
      double         CalcSlope(double &Source[], double &Destination[]);
      void           CalcRegression(RegrRec &Regr, AlertLevel Level);

      void           UpdateMaster(void);
      void           UpdateTick(TickRec &Tick);
      void           UpdateHistory(void);

      //-- User-Configuration
      double         pmaTickAgg;
      int            pmaPeriods;
      int            pmaDegree;
      int            pmaKeep;
      int            pmaSMASlow;
      int            pmaSMAFast;

      int            tickKeep;
      int            tickSMASlow;
      int            tickSMAFast;

      //-- Data Collections
      MasterRec      mr;

    public:

                     CPipMA(int RegrPeriods, int RegrDegree, int SMA, double TickAggregation);
                    ~CPipMA();
     
      //--- Data Entry/Update Methods
      void           Update(void);

      //--- Class Members & Public Properties
      TickRec        Tick(void) const {return(mr.Tick);};
      MasterRec      Master(void) const {return(mr);};

      //-- Formatted data outputs
      string         TickStr(void);
      string         OHLCStr(int Node);
      string         SMAStr(OHLCRec &SMA);
      string         PolyStr(RegressionMethod Method);
      string         HistoryStr(void);
      string         MasterStr(void);
      
      OHLCRec        operator[](const int Node)        const {return(mr.History[Node]);};
  };

//+------------------------------------------------------------------+
//| CalcSlope - Calculate Linear Regression; return slope            |
//+------------------------------------------------------------------+
double CPipMA::CalcSlope(double &Source[], double &Destination[])
  {
    //--- Linear regression line
    double m[5]           = {0.00,0.00,0.00,0.00,0.00};   //--- slope
    double b              = 0.00;                         //--- y-intercept

    double sumx           = 0.00;
    double sumy           = 0.00;
    
    for (int idx=0;idx<pmaPeriods;idx++)
    {
      sumx += idx+1;
      sumy += Source[idx];
      
      m[1] += (idx+1)*Source[idx];            // Exy
      m[3] += pow(idx+1,2);                   // E(x^2)
    }
    
    m[2]    = fdiv(sumx*sumy,pmaPeriods);     // (Ex*Ey)/n
    m[4]    = fdiv(pow(sumx,2),pmaPeriods);   // [(Ex)^2]/n
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy-m[0]*sumx)/pmaPeriods;

    for (int idx=0;idx<pmaPeriods;idx++)
      Destination[idx]    = (m[0]*(idx+1))+b;    //--- y=mx+b

    return (m[0]*(-1)); //-- inverted tail to head slope
  }

//+------------------------------------------------------------------+
//| CalcPoly - computes polynomial regression to x degree            |
//+------------------------------------------------------------------+
double CPipMA::CalcPoly(OHLCRec &OHLC[], double &Poly[], RegressionMethod Method)
  {
    double ai[10,10],b[10],x[10],sx[20];
    double sum; 
    double qq,rr,tt;

    int    ii,jj,kk,ll,nn;
    int    mi,n;

    double mean_y   = 0.00;
    double se_l     = 0.00;
    double se_y     = 0.00;
        
    double src;

    sx[1]  = pmaPeriods+1;
    nn     = pmaDegree+1;
   
    //----------------------sx-------------
    for(mi=1;mi<=nn*2-2;mi++)
    {
      sum=0;

      for(n=0;n<=pmaPeriods;n++)
         sum+=MathPow(n,mi);

      sx[mi+1]=sum;
    }
     
    //----------------------syx-----------
    ArrayInitialize(b,0.00);

    for(mi=1;mi<=nn;mi++)
    {
      sum=0.00000;

      for(n=0;n<=pmaPeriods;n++)
      {
        src    = BoolToDouble(IsEqual(Method,rmOpen),OHLC[n].Open,
                 BoolToDouble(IsEqual(Method,rmClose),OHLC[n].Close,
                 BoolToDouble(IsEqual(Method,rmHigh),OHLC[n].High,
                 BoolToDouble(IsEqual(Method,rmLow),OHLC[n].Low))));

        if(mi==1) 
          sum += src;                                                                                                                                                                                   
        else 
          sum += src*MathPow(n, mi-1);
      }

      b[mi]=sum;
    } 
     
    //===============Matrix================
    ArrayInitialize(ai,0.00);

    for(jj=1;jj<=nn;jj++)
      for(ii=1; ii<=nn; ii++)
      {
         kk=ii+jj-1;
         ai[ii,jj]=sx[kk];
      }

    //===============Gauss=================
    for(kk=1; kk<=nn-1; kk++)
    {
      ll=0;
      rr=0;

      for(ii=kk;ii<=nn;ii++)
        if(MathAbs(ai[ii,kk])>rr)
        {
           rr=MathAbs(ai[ii,kk]);
           ll=ii;
        }

      if (ll!=kk)
      {
         for(jj=1;jj<=nn;jj++)
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

    //===============Final=================
    ArrayInitialize(Poly,0.00);

    for(n=0;n<=pmaPeriods-1;n++)
    {
      sum=0;

      for(kk=1;kk<=pmaDegree;kk++)
        sum+=x[kk+1]*MathPow(n,kk);

      mean_y += x[1]+sum;
      Poly[n]=x[1]+sum;
    }

    //--- Compute poly range data
    mean_y     = mean_y/pmaPeriods;

    for (n=0;n<pmaPeriods;n++)
    {
      src      = BoolToDouble(IsEqual(Method,rmOpen),OHLC[n].Open,
                 BoolToDouble(IsEqual(Method,rmClose),OHLC[n].Close,
                 BoolToDouble(IsEqual(Method,rmHigh),OHLC[n].High,
                 BoolToDouble(IsEqual(Method,rmLow),OHLC[n].Low))));

      se_l    += pow(src-Poly[n],2);
      se_y    += pow(Poly[n]-mean_y,2);
    }

    return (((1-fdiv(se_l,se_y))*100));  //--- R^2 factor
  }

//+------------------------------------------------------------------+
//| CalcSMA - Computes the SMA of a double array                     |
//+------------------------------------------------------------------+
double CPipMA::CalcSMA(OHLCRec &OHLC[], RegressionMethod Method, int SMA)
  {
    double sma    = 0.00;

    for (int node=0;node<SMA;node++)   
      sma        += BoolToDouble(IsEqual(Method,rmOpen),OHLC[node].Open,
                    BoolToDouble(IsEqual(Method,rmClose),OHLC[node].Close,
                    BoolToDouble(IsEqual(Method,rmHigh),OHLC[node].High,
                    BoolToDouble(IsEqual(Method,rmLow),OHLC[node].Low))));

    return (fdiv(sma,SMA,8));
  }

//+------------------------------------------------------------------+
//| UpdateRegression - Completes the Tick Regression Analysis        |
//+------------------------------------------------------------------+
void CPipMA::CalcRegression(RegrRec &Regr, AlertLevel Level)
  {
    
  }

//+------------------------------------------------------------------+
//| UpdateMaster - Computes Master Events/Values on each Tick Agg    |
//+------------------------------------------------------------------+
void CPipMA::UpdateMaster(void)
  {
    //--- calc master direction
    if (NewDirection(mr.Direction,Direction(mr.History[0].Open-mr.History[1].Open)))
    {
      if (IsChanged(mr.Locked,false))  //-- End of Trend Reset
      {
        mr.High              = mr.History[1].High;
        mr.Low               = mr.History[1].Low;
      };
      
      SetEvent(BoolToEvent(IsEqual(mr.Direction,DirectionUp),NewRally,NewPullback),Nominal);
    }
    else
    {
      if (IsChanged(mr.Locked,true))
        SetEvent(BoolToEvent(NewDirection(mr.BreakoutDir,mr.Direction),NewReversal,NewBreakout),Nominal);

      if (IsEqual(mr.Direction,DirectionUp))
        mr.High              = mr.History[1].High;

      if (IsEqual(mr.Direction,DirectionDown))
        mr.Low               = mr.History[1].Low;        
    }

    mr.High              = fmax(mr.High,mr.History[1].High);
    mr.Low               = fmin(mr.Low,mr.History[1].Low);      
  }

//+------------------------------------------------------------------+
//| UpdateTick - Computes the bias on the tick                       |
//+------------------------------------------------------------------+
void CPipMA::UpdateTick(TickRec &Tick)
  {
    static int slowaction     = OP_NO_ACTION;
    static int fastaction     = OP_NO_ACTION;
    
    ArrayCopy(Tick.Close,Tick.Close,1,0,tickKeep-1);
    ArrayCopy(Tick.SMA,Tick.SMA,1,0,tickKeep-1);
    
    Tick.Event                = NoEvent;
    Tick.Open                 = mr.History[0].Open;
    Tick.Close[0]             = Close[0];
    Tick.SMA[0].Fast          = 0.00;
    Tick.SMA[0].Slow          = 0.00;

    for (int node=0;node<tickKeep;node++)
    {
      Tick.SMA[0].Fast       += BoolToDouble(node<tickSMAFast,Tick.Close[node],0.00);
      Tick.SMA[0].Slow       += BoolToDouble(node<tickSMASlow,Tick.Close[node],0.00);
    }
    
    Tick.SMA[0].Fast          = fdiv(Tick.SMA [0].Fast,tickSMAFast,8);
    Tick.SMA[0].Slow          = fdiv(Tick.SMA[0].Slow,tickSMASlow,8);
    
    //-- Calculate Bias
    NewAction(slowaction,Action(Tick.SMA[0].Slow-Tick.SMA[2].Slow,InDirection));
    NewAction(fastaction,Action(Tick.SMA[0].Fast-Tick.SMA[2].Fast,InDirection));
    
    if (NewAction(Tick.Bias,BoolToInt(IsEqual(slowaction,fastaction),slowaction,Tick.Bias)))
      Tick.Event              = NewBias;

    switch (Tick.Bias)
    {
      case OP_BUY:    if (IsEqual(Tick.Event,NewBias))
                        Tick.High        = fmax(Tick.Retrace,Close[0]);
                      else
                      if (IsHigher(Close[0],Tick.High))
                      {
                        Tick.Event       = NewHigh;
                        Tick.Retrace     = Close[0];
                      }
                      
                      Tick.Retrace       = fmin(Tick.Retrace,Close[0]);
                      break;
                        
      case OP_SELL:   if (IsEqual(Tick.Event,NewBias))
                        Tick.Low         = fmin(Tick.Retrace,Close[0]);
                      else
                      if (IsLower(Close[0],Tick.Low))
                      {
                        Tick.Event       = NewLow;
                        Tick.Retrace     = Close[0];
                      }
                      
                      Tick.Retrace       = fmax(Tick.Retrace,Close[0]);
                      break;
    }
  }

//+------------------------------------------------------------------+
//| UpdateHistory - Calc tick bounds and update tick history         |
//+------------------------------------------------------------------+
void CPipMA::UpdateHistory(void)
  {
    if (fabs(pip(mr.History[0].Open-Close[0]))>=pmaTickAgg)
    {
      
      mr.SMA.High             = CalcSMA(mr.History,rmHigh,pmaSMAFast);
      mr.SMA.Low              = CalcSMA(mr.History,rmLow,pmaSMAFast);
      mr.SMA.Close            = CalcSMA(mr.History,rmClose,pmaSMASlow);
      
      //-- Calc regression metrics
      mr.Poly.Regr[rmOpen]    = CalcPoly(mr.History,mr.Poly.Open,rmOpen);
      mr.Poly.Regr[rmClose]   = CalcPoly(mr.History,mr.Poly.Close,rmClose);
      
      CalcRegression(mr.Poly,Minor);
      
      mr.Slope.Regr[rmOpen]   = CalcSlope(mr.Poly.Open,mr.Slope.Open);
      mr.Slope.Regr[rmClose]  = CalcSlope(mr.Poly.Close,mr.Slope.Close);

      CalcRegression(mr.Slope,Major);
      
      ArrayCopy(mr.History,mr.History,1,0,pmaKeep-1);

      mr.History[0].Open      = Close[0];
      mr.History[0].High      = Close[0];
      mr.History[0].Low       = Close[0];

      mr.History[0].Segment   = mr.History[1].Segment+1;
      mr.History[0].Count     = 0;

      mr.SMA.Open             = CalcSMA(mr.History,rmOpen,pmaSMASlow);
    
      if (NewAction(mr.Bias,Action(Direction(mr.SMA.Open-mr.SMA.Close),InDirection)))
                       SetEvent(NewBias);
      UpdateMaster();
      
      SetEvent(NewTick,Notify);
    }

    UpdateTick(mr.Tick);

    if (IsHigher(Close[0],mr.History[0].High))
      if (IsHigher(Close[0],mr.SMA.High,NoUpdate))
        SetEvent(NewHigh,Nominal);
        
    if (IsLower(Close[0],mr.History[0].Low))
      if (IsLower(Close[0],mr.SMA.Low,NoUpdate))
        SetEvent(NewLow,Nominal);

    mr.History[0].Close       = Close[0];
    mr.History[0].Count++;
  }

//+------------------------------------------------------------------+
//| CPipMA Constructor                                               |
//+------------------------------------------------------------------+
void CPipMA::CPipMA(int RegrPeriods, int RegrDegree, int SMA, double TickAggregation)
  {
    pmaPeriods                = RegrPeriods;
    pmaDegree                 = RegrDegree;
    pmaTickAgg                = TickAggregation;
    pmaSMASlow                = SMA;
    pmaSMAFast                = SMA-1;
    pmaKeep                   = RegrPeriods+RegrDegree;
    
    tickSMASlow               = SMA*2;
    tickSMAFast               = SMA;
    tickKeep                  = tickSMASlow+tickSMAFast;

    ArrayResize(mr.History,pmaKeep,pmaKeep);
    ArrayResize(mr.Tick.Close,tickKeep,tickKeep);
    ArrayResize(mr.Tick.SMA,tickKeep,tickKeep);
    ArrayResize(mr.Poly.Open,pmaPeriods,pmaPeriods);
    ArrayResize(mr.Poly.Close,pmaPeriods,pmaPeriods);
    ArrayResize(mr.Slope.Open,pmaPeriods,pmaPeriods);
    ArrayResize(mr.Slope.Close,pmaPeriods,pmaPeriods);
    
    //-- Initialize Tick
    mr.Tick.Open              = Close[0];
    mr.Tick.High              = Close[0];
    mr.Tick.Low               = Close[0];
    mr.Tick.Retrace           = Close[0];

    //-- Initialize Master
    mr.BreakoutDir            = DirectionNone;
    mr.Direction              = DirectionNone;
    mr.Bias                   = DirectionNone;
    mr.Locked                 = true;
    
    //-- Preload Time-Series History for Poly Regression Calcs
    for (int node=0;node<pmaKeep;node++)
    {
      mr.History[node].Open   = Open[node];
      mr.History[node].High   = High[node];
      mr.History[node].Low    = Low[node];
      mr.History[node].Close  = Close[node];
    }
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
    UpdateHistory();
  }

//+------------------------------------------------------------------+
//| TickStr - Returns formatted Tick string                          |
//+------------------------------------------------------------------+
string CPipMA::TickStr(void)
  {
    string text   = "";
    
    Append(text,(string)mr.History[0].Segment,"\n|");
    Append(text,ActionText(mr.Tick.Bias),"|");
    Append(text,EnumToString(mr.Tick.Event),"|");
    Append(text,DoubleToStr(mr.Tick.Open,Digits),"|");
    Append(text,DoubleToStr(mr.Tick.High,Digits),"|");
    Append(text,DoubleToStr(mr.Tick.Low,Digits),"|");
    Append(text,DoubleToStr(mr.Tick.Close[0],Digits),"|");
    Append(text,DoubleToStr(mr.Tick.Retrace,Digits),"|");
    Append(text,DoubleToStr(mr.Tick.SMA[0].Fast,8),"|");
    Append(text,DoubleToStr(mr.Tick.SMA[0].Slow,8),"|");

    return (text);
  }    

//+------------------------------------------------------------------+
//| OHLCStr - Returns formatted OHLC string                          |
//+------------------------------------------------------------------+
string CPipMA::OHLCStr(int Node)
  {
    string text   = "";
    
    Append(text,(string)Node,"\n|");
    Append(text,(string)mr.History[Node].Segment,"|");
    Append(text,(string)mr.History[Node].Count,"|");
    Append(text,DoubleToStr(mr.History[Node].Open,Digits),"|");
    Append(text,DoubleToStr(mr.History[Node].High,Digits),"|");
    Append(text,DoubleToStr(mr.History[Node].Low,Digits),"|");
    Append(text,DoubleToStr(mr.History[Node].Close,Digits),"|");

    return (text);
  }    

//+------------------------------------------------------------------+
//| HistoryStr - Returns formatted OHLC string                       |
//+------------------------------------------------------------------+
string CPipMA::HistoryStr(void)
  {
    string text   = "";
    
    for (int node=0;node<pmaPeriods;node++)
    {
      if (IsEqual(mr.History[node].Close,0.00))
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
//| PolyStr - Returns formatted Poly string                          |
//+------------------------------------------------------------------+
string CPipMA::PolyStr(RegressionMethod Method)
  {
    string text   = "";
    
    for (int period=pmaPeriods-1;period>0;period--)
      if (IsEqual(Method,rmClose))
        Append(text,DoubleToStr(mr.Poly.Close[period],Digits),"|");

    return (text);
  }    

//+------------------------------------------------------------------+
//| MasterStr - Returns formatted OHLC string                        |
//+------------------------------------------------------------------+
string CPipMA::MasterStr(void)
  {
    string text   = "";
    
    Append(text,DirText(mr.BreakoutDir),"|");
    Append(text,DirText(mr.Direction),"|");
    Append(text,ActionText(mr.Bias),"|");
    Append(text,BoolToStr(mr.Locked,"Locked","Unlocked"),"|");
    Append(text,DoubleToStr(mr.High,Digits),"|");
    Append(text,DoubleToStr(mr.Low,Digits),"|");
    Append(text,(string)mr.History[0].Segment,"|");
    Append(text,(string)mr.History[0].Count,"|");
    Append(text,DoubleToStr(mr.History[0].Open,Digits),"|");
    Append(text,DoubleToStr(mr.History[1].High,Digits),"|");
    Append(text,DoubleToStr(mr.History[1].Low,Digits),"|");
    Append(text,DoubleToStr(mr.History[1].Close,Digits),"|");
    Append(text,SMAStr(mr.SMA),"|");
    Append(text,EventStr(),"|");
    
    return(text);
  }
