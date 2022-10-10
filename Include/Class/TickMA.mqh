//+------------------------------------------------------------------+
//|                                                       TickMA.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\Event.mqh>
#include <fractal_lib.mqh>

#define Fast           2
#define Slow           3

class CTickMA : public CEvent
  {

private:

    enum   SMAState
           {
             Convergence,      // Trending
             Parabolic,        // Active
             Consolidation,    // Consolidating
             Flatline          // Flatline
           };

    enum   PriceType
           {
             ptOpen,      // Open
             ptHigh,      // High
             ptLow,       // Low
             ptClose,     // Close
             PriceTypes   // None
           };

    enum   CountType
           {
             Ticks,
             Segments
           };

    struct TickRec
           {
             int            Count;
             double         Open;
             double         High;
             double         Low;
             double         Close;
           };

    struct SegmentRec
           {
             int            Direction[FractalTypes];
             int            Bias;
             EventType      Event;
             int            Count;
             double         Open;
             double         High;
             double         Low;
             double         Close;
           };

    struct RangeRec
           {
             int            Direction;
             FractalState   State;
             EventType      Event;
             int            Age;
             double         High;
             double         Low;
             double         Now;
             double         Mean;
             double         Retrace;
             double         Support;
             double         Resistance;
           };

    struct SMARec
           {
             int            Direction;   //-- Expansion Direction
             int            Bias;        //-- Open/Close cross
             EventType      Event;       //-- Aggregate event
             SMAState       State;       //-- Aggregate state
             double         Open[];
             double         High[];
             double         Low[];
             double         Close[];
           };

    struct MomentumDetail
           {
             int            Direction;
             int            Bias;
             EventType      Event;
             double         Now;
             double         Change;
           };
           
    struct MomentumRec
           {
             MomentumDetail Open;
             MomentumDetail High;
             MomentumDetail Low;
             MomentumDetail Close;
           };

    struct FractalDetail
           {
             FractalType    Type;
             int            Direction[FractalTypes];
             int            Bar[FractalTypes];
             double         Point[FractalTypes];
           };

    struct FractalRec
           {
             int            Direction;
             int            Bias;
             FractalType    Type;
             FractalState   State;
             EventType      Event;
             FractalDetail  High;
             FractalDetail  Low;
             double         Support;
             double         Resistance;
             double         Expansion;
           };

    struct PolyRec
           {
             int            Direction;
             int            Bias;
             double         Open[];
             double         High;
             double         Low;
             double         Close[];
           };

    struct FOCRec
           {
             int            Direction;
             int            Bias;
             FractalState   State;
             EventType      Event;
             double         Price[];
             double         Lead;
             double         Origin;
             double         Min;
             double         Max;
             double         Now;
           };

    struct LinearRec
           {
             int            Direction;
             int            Bias;
             EventType      Event;
             FOCRec         Open;
             FOCRec         Close;
           };

    void             CalcFOC(PriceType Type, FOCRec &FOC);
    void             CalcSMA(void);
    void             CalcPoly(PriceType Type, double &Poly[]);
    void             CalcLinear(double &Source[], double &Target[]);
    void             CalcFractal(FractalDetail &Fractal, double &Price[]);
    void             CalcMomentum(MomentumDetail &Detail, double &SMA[]);

    void             NewTick();
    void             NewSegment(void);

    void             UpdateTick(void);
    void             UpdateSegment(void);
    void             UpdateRange(void);
    void             UpdateSMA(void);
    void             UpdatePoly(void);
    void             UpdateLinear(void);
    void             UpdateFractal(void);

    int              tmaPeriods;
    int              tmaDegree;
    double           tmaTickAgg;

    int              tmaDirection[FractalTypes];
    int              tmaBar;
    
    //-- Aggregation Structures
    TickRec          tr[];           //-- Tick Record
    SegmentRec       sr[];           //-- Segment Record
    RangeRec         range;          //-- Range Record
    SMARec           sma;            //-- SMA Master Record
    PolyRec          poly;           //-- Poly Regr Record
    LinearRec        line;           //-- Linear Regr Record
    FractalRec       fr;             //-- Fractal Record
    MomentumRec      mr;             //-- Momentum Record

public:
                     CTickMA(int Periods, int Degree, double Aggregate);
                    ~CTickMA();

    void             Update(void);

    //-- Data Collections
    TickRec          Tick(int Node=0)      { return(tr[Node]); };
    SegmentRec       Segment(int Node=0)   { return(sr[Node]); };
    RangeRec         Range(void)           { return(range); };
    SMARec           SMA(void)             { return(sma); };
    PolyRec          Poly(void)            { return(poly); };
    LinearRec        Linear(void)          { return(line); };
    FractalRec       Fractal(void)         { return(fr); };
    MomentumRec      Momentum(void)        { return(mr); };
    
    MomentumDetail   Momentum(PriceType Type);
    
    int              Count(CountType Type) { return(BoolToInt(IsEqual(Type,Ticks),ArraySize(tr),ArraySize(sr))); };
    int              Direction(double &Price[], int Speed=Fast) { return(Direction(Price[0]-Price[Speed-1])); };

    //-- Format strings
    string           TickStr(int Count=0);
    string           TickHistoryStr(int Count=0);
    string           SegmentStr(int Node);
    string           SegmentHistoryStr(int Count=0);
    string           SegmentTickStr(int Node);
    string           SMAStr(int Count=0);
    string           PolyStr(void);
    string           RangeStr(void);
    string           FOCStr(FOCRec &FOC);
    string           LinearStr(int Count=0);
    string           EventStr(EventType Type);
    string           FractalDetailStr(FractalDetail &Fractal);
    string           FractalStr(FractalRec &Fractal);
    string           MomentumStr(void);
    string           MomentumDetailStr(PriceType Type);
  };

//+------------------------------------------------------------------+
//| CalcFOC - Computes Linear(FOC) Fractal states, events            |
//+------------------------------------------------------------------+
void CTickMA::CalcFOC(PriceType Type, FOCRec &FOC)
  {
    int    bias             = FOC.Bias;

    double maxFOC           = fabs(FOC.Max);
    double minFOC           = fabs(FOC.Min);
    double nowFOC           = fabs(FOC.Now);
    
    AlertLevel alertlevel   = (AlertLevel)BoolToInt(IsEqual(Type,ptClose),Major,Notify);
    
    FOC.Event               = NoEvent;

    //--- compute FOC metrics
    if (Event(NewTick)||Event(NewExpansion,Critical))
    {
      FOC.Lead              = FOC.Price[0];
      FOC.Origin            = FOC.Price[tmaPeriods-1];
      FOC.Now               = (atan(fdiv(pip(FOC.Lead-FOC.Origin),tmaPeriods))*180)/M_PI;
      
      if (Event(NewExpansion,Critical))
        if (!IsEqual(Direction(FOC.Now),range.Direction))
          SetEvent(AdverseEvent,Critical);

      if (NewDirection(FOC.Direction,Direction(FOC.Lead-FOC.Price[1])))
      {
        maxFOC              = NoValue;
        FOC.Event           = BoolToEvent(NewState(FOC.State,Reversal),NewReversal);
      }

      if (IsHigher(fabs(FOC.Now),maxFOC,NoUpdate,3)||Event(NewExpansion,Critical))
      {
        bias                = Action(FOC.Direction);

        FOC.Min             = FOC.Now;
        FOC.Max             = FOC.Now;
        FOC.Event           = BoolToEvent(NewState(FOC.State,Breakout),NewBreakout,FOC.Event);
      }
      else
      if (IsLower(fabs(FOC.Now),minFOC,NoUpdate,3))
      {
        bias                = Action(FOC.Direction,InDirection,InContrarian);

        FOC.Min             = FOC.Now;
        
        if (IsEqual(poly.Bias,bias))
          FOC.Event         = BoolToEvent(NewState(FOC.State,(FractalState)BoolToInt(IsEqual(FOC.Direction,DirectionUp),Pullback,Rally)),
                                                             FractalEvent((FractalState)BoolToInt(IsEqual(FOC.Direction,DirectionUp),Pullback,Rally)));
      }
      else bias             = NoBias;
//        bias                = Action(fabs(FOC.Now)-nowFOC);

      SetEvent(BoolToEvent(IsChanged(FOC.Bias,bias),NewBias),alertlevel);
      SetEvent(FOC.Event,alertlevel);
    }
  }

//+------------------------------------------------------------------+
//| CalcSMA - Calc SMA on supplied segment (bar)                     |
//+------------------------------------------------------------------+
void CTickMA::CalcSMA(void)
  {
    TickRec calcsma       = {0,0.00,0.00,0.00,0.00};

    if (Event(NewSegment))
    {
      ArrayCopy(sma.Open,sma.Open,1,0,tmaPeriods-1);
      ArrayCopy(sma.High,sma.High,1,0,tmaPeriods);
      ArrayCopy(sma.Low,sma.Low,1,0,tmaPeriods);
      ArrayCopy(sma.Close,sma.Close,1,0,tmaPeriods-1);
    }

    for (int node=0;node<Slow;node++)
    {
      if (node<Fast)
      {
        calcsma.High     += sr[node].High;
        calcsma.Low      += sr[node].Low;
      }

      calcsma.Open       += sr[node].Open;
      calcsma.Close      += sr[node].Close;
    }

    sma.Open[0]           = fdiv(calcsma.Open,Slow);
    sma.High[0]           = fdiv(calcsma.High,Fast);
    sma.Low[0]            = fdiv(calcsma.Low,Fast);
    sma.Close[0]          = fdiv(calcsma.Close,Slow);
  }

//+------------------------------------------------------------------+
//| CalcPoly - computes polynomial regression to x degree            |
//+------------------------------------------------------------------+
void CTickMA::CalcPoly(PriceType Type, double &Poly[])
  {
    double ai[10,10],b[10],x[10],sx[20];
    double sum;
    double qq,rr,tt;

    int    ii,jj,kk,ll,nn;
    int    mi,n;

    double src;

    sx[1]  = tmaPeriods+1;
    nn     = tmaDegree+1;

    //----------------------sx-------------
    for(mi=1;mi<=nn*2-2;mi++)
    {
      sum=0;

      for(n=0;n<=tmaPeriods;n++)
        sum+=pow(n,mi);

      sx[mi+1]=sum;
    }

    //----------------------syx-----------
    ArrayInitialize(b,0.00);

    for(mi=1;mi<=nn;mi++)
    {
      sum=0.00000;

      for(n=0;n<=tmaPeriods;n++)
      {
        src    = BoolToDouble(IsEqual(Type,ptOpen),sr[n].Open,
                 BoolToDouble(IsEqual(Type,ptClose),sr[n].Close,
                 BoolToDouble(IsEqual(Type,ptHigh),sr[n].High,
                 BoolToDouble(IsEqual(Type,ptLow),sr[n].Low))));

        if(mi==1)
          sum += src;
        else
          sum += src*pow(n, mi-1);
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
        if(fabs(ai[ii,kk])>rr)
        {
           rr=fabs(ai[ii,kk]);
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

    for(n=0;n<=tmaPeriods-1;n++)
    {
      sum=0;

      for(kk=1;kk<=tmaDegree;kk++)
        sum+=x[kk+1]*pow(n,kk);

      Poly[n]=x[1]+sum;
    }
  }

//+------------------------------------------------------------------+
//| CalcLinear - Calculate Linear Regression                         |
//+------------------------------------------------------------------+
void CTickMA::CalcLinear(double &Source[], double &Target[])
  {
    //--- Linear regression line
    double m[5]           = {0.00,0.00,0.00,0.00,0.00};   //--- slope
    double b              = 0.00;                         //--- y-intercept

    double sumx           = 0.00;
    double sumy           = 0.00;
    
    for (int idx=0;idx<tmaPeriods;idx++)
    {
      sumx += idx+1;
      sumy += Source[idx];
      
      m[1] += (idx+1)*Source[idx];            // Exy
      m[3] += pow(idx+1,2);                   // E(x^2)
    }
    
    m[2]    = fdiv(sumx*sumy,tmaPeriods);     // (Ex*Ey)/n
    m[4]    = fdiv(pow(sumx,2),tmaPeriods);   // [(Ex)^2]/n
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy-m[0]*sumx)/tmaPeriods;

    for (int idx=0;idx<tmaPeriods;idx++)
      Target[idx]    = (m[0]*(idx+1))+b;      //--- y=mx+b
  }

//+------------------------------------------------------------------+
//| NewTick - inserts a new 0-Base tick aggregation record           |
//+------------------------------------------------------------------+
void CTickMA::NewTick()
  {
    ArrayResize(tr,ArraySize(tr)+1,32768);

    if (ArraySize(tr)>1)
      ArrayCopy(tr,tr,1,0,ArraySize(tr)-1);

    tr[0].Count               = 0;
    tr[0].Open                = BoolToDouble(IsEqual(tmaBar,0),Close[0],Open[tmaBar]);
    tr[0].High                = BoolToDouble(IsEqual(tmaBar,0),Close[0],High[tmaBar]);
    tr[0].Low                 = BoolToDouble(IsEqual(tmaBar,0),Close[0],Low[tmaBar]);
    tr[0].Close               = Close[tmaBar];
    
    if (ArraySize(tr)>1)
      SetEvent(BoolToEvent(tr[0].Open>tr[1].Open,NewHigh,NewLow));

    SetEvent(NewTick,Notify);
  }

//+------------------------------------------------------------------+
//| NewSegment - inserts a new 0-Base segment aggregation record     |
//+------------------------------------------------------------------+
void CTickMA::NewSegment(void)
  {
    ArrayResize(sr,ArraySize(sr)+1,32768);

    if (ArraySize(sr)>1)
      ArrayCopy(sr,sr,1,0,ArraySize(sr)-1);

    ArrayCopy(sr[0].Direction,tmaDirection);

    sr[0].Count               = 0;
    sr[0].Open                = tr[0].Open;
    sr[0].High                = tr[0].High;
    sr[0].Low                 = tr[0].Low;
    sr[0].Close               = tr[0].Close;
    sr[0].Event               = NoEvent;

    if (ArraySize(tr)>1)
    {
      sr[0].High              = fmax(sr[0].High,tr[1].High);
      sr[0].Low               = fmin(sr[0].Low,tr[1].Low);
    }
    else
    {
      sr[0].High              = fmax(sr[0].High,BoolToDouble(IsEqual(tmaBar,0),Close[0],High[tmaBar],Digits));
      sr[0].Low               = fmin(sr[0].Low,BoolToDouble(IsEqual(tmaBar,0),Close[0],Low[tmaBar],Digits));
    }

    SetEvent(NewSegment,Nominal);
  }

//+------------------------------------------------------------------+
//| CalcFractal - Computes Fractal Points of the supplied Price array|
//+------------------------------------------------------------------+
void CTickMA::CalcFractal(FractalDetail &Fractal, double &Price[])
  {
    FractalDetail fractal;
    FractalType   type;
    FractalType   hightype          = Expansion;
    FractalType   lowtype           = Expansion;

    int           direction         = DirectionChange;
    int           bar               = 0;
    double        high              = Price[0];
    double        low               = Price[0];

    ArrayInitialize(fractal.Direction,DirectionNone);
    ArrayInitialize(fractal.Bar,NoValue);
    ArrayInitialize(fractal.Point,NoValue);

    for (type=Expansion;type>NoValue;type--)
      for (bar=bar;bar<tmaPeriods;bar++)
        if (NewDirection(direction,Direction(Price[bar]-Price[bar+1])))
        {
          fractal.Direction[type]   = direction;
          fractal.Point[type]       = Price[bar];
          fractal.Bar[type]         = bar;

          hightype                  = (FractalType)BoolToInt(IsHigher(Price[bar],high),type,hightype);
          lowtype                   = (FractalType)BoolToInt(IsLower(Price[bar],low),type,lowtype);

          break;
        }

    for (type=(FractalType)(Expansion-fmax(hightype,lowtype));type>Origin;type--)
      for (bar=bar;bar<tmaPeriods;bar++)
        if (NewDirection(direction,Direction(Price[bar]-Price[bar+1])))
        {
          ArrayCopy(fractal.Direction,fractal.Direction,1,0,FractalTypes-1);
          ArrayCopy(fractal.Point,fractal.Point,1,0,FractalTypes-1);
          ArrayCopy(fractal.Bar,fractal.Bar,1,0,FractalTypes-1);

          fractal.Direction[Origin] = direction;
          fractal.Point[Origin]     = Price[bar];
          fractal.Bar[Origin]       = bar;

          break;
        }

    fractal.Type                    = (FractalType)fmin(Expansion+(Expansion-fmax(hightype,lowtype)),Lead);
    fractal.Direction[Term]         = BoolToInt(IsHigher(Price[0],fractal.Point[Root],NoUpdate),DirectionUp,DirectionDown);
    fractal.Direction[Trend]        = fractal.Direction[Expansion];

    if (IsChanged(Fractal.Type,fractal.Type))
      SetEvent(FractalEvent(Fractal.Type),Major);
      
    if (IsChanged(Fractal.Direction[Term],fractal.Direction[Term]))
      SetEvent(NewTerm,Major);

    if (IsChanged(Fractal.Direction[Trend],fractal.Direction[Trend]))
      SetEvent(NewTrend,Major);

    Fractal                         = fractal;
  }

//+------------------------------------------------------------------+
//| CalcMomentum - Computes the Momentum for the supplied SMA array  |
//+------------------------------------------------------------------+
void CTickMA::CalcMomentum(MomentumDetail &Detail, double &SMA[])
  {
    double momentum       = (SMA[0]-SMA[1])-(SMA[1]-SMA[2]);
    double change         = momentum-Detail.Now;
    
    Detail.Event          = NoEvent;

    if (IsEqual(change,0.00))
      return;

    Detail.Event          = BoolToEvent(IsEqual(Direction(change),DirectionUp),NewRally,NewPullback);
    Detail.Now            = momentum;
    Detail.Change         = change;
      
    if (NewAction(Detail.Bias,Action(change)))
      Detail.Event        = NewBias;

    if (NewDirection(Detail.Direction,Direction(momentum)))
      Detail.Event        = NewDirection;
  }

//+------------------------------------------------------------------+
//| UpdateTick - Calc tick bounds and update tick history            |
//+------------------------------------------------------------------+
void CTickMA::UpdateTick(void)
  {
    if (fabs(tr[0].Open-Close[tmaBar])>=tmaTickAgg)
      NewTick();

    if (IsHigher(BoolToDouble(IsEqual(tmaBar,0),Close[0],High[tmaBar]),tr[0].High))
      SetEvent(NewHigh,Notify);

    if (IsLower(BoolToDouble(IsEqual(tmaBar,0),Close[0],Low[tmaBar]),tr[0].Low))
      SetEvent(NewLow,Notify);

    SetEvent(BoolToEvent(Event(NewHigh)||Event(NewLow),NewBoundary),Notify);

    tr[0].Close           = Close[tmaBar];
    tr[0].Count++;
  }

//+------------------------------------------------------------------+
//| UpdateSegment - Calc segment bounds and update segment history   |
//+------------------------------------------------------------------+
void CTickMA::UpdateSegment(void)
  {
    if (Count(Ticks)>1)
      if (NewDirection(tmaDirection[Lead],Direction(tr[0].Open-tr[1].Close)))
        NewSegment();

    if (IsHigher(tr[0].High,sr[0].High))
    {
      if (Count(Segments)>1)
        if (IsHigher(sr[0].High,sr[1].High,NoUpdate,Digits))
          if (NewDirection(tmaDirection[Term],DirectionUp))
          {
            fr.Support     = fr.Expansion;
            fr.Expansion   = sr[0].High;

            SetEvent(NewRally,Nominal);
          }

      if (IsEqual(tmaDirection[Term],DirectionUp))
        fr.Expansion       = fmax(fr.Expansion,sr[0].High);

      SetEvent(NewHigh,Nominal);
    }

    if (IsLower(tr[0].Low,sr[0].Low))
    {
      if (Count(Segments)>1)
        if (IsLower(sr[0].Low,sr[1].Low,NoUpdate,Digits))
          if (NewDirection(tmaDirection[Term],DirectionDown))
          {
            fr.Resistance  = fr.Expansion;
            fr.Expansion   = sr[0].Low;

            SetEvent(NewPullback,Nominal);
          }

      if (IsEqual(tmaDirection[Term],DirectionDown))
        fr.Expansion       = fmin(fr.Expansion,sr[0].Low);

      SetEvent(NewLow,Nominal);
    }

    if (NewDirection(sr[0].Direction[Term],tmaDirection[Term]))
      SetEvent(NewTerm,Nominal);

    if (!IsBetween(fr.Expansion,fr.Support,fr.Resistance,Digits))
      if (IsChanged(tmaDirection[Trend],tmaDirection[Term]))
        SetEvent(NewTrend,Nominal);

    sr[0].Close            = tr[0].Close;
    sr[0].Count           += BoolToInt(Event(NewTick),1);

    SetEvent(BoolToEvent(NewAction(sr[0].Bias,Action(Direction(sr[0].Close-sr[0].Open),InDirection)),NewBias),Nominal);

    sr[0].Event            = BoolToEvent(Event(NewDirection,Nominal),  NewDirection,
                               BoolToEvent(Event(NewPullback,Nominal), NewPullback,
                               BoolToEvent(Event(NewRally,Nominal),    NewRally,
                               BoolToEvent(Event(NewSegment,Nominal),  NewSegment,
                               BoolToEvent(Event(NewLow,Nominal),      NewLow,
                               BoolToEvent(Event(NewHigh,Nominal),     NewHigh,
                               BoolToEvent(Event(NewBias,Nominal),     NewBias,NoEvent)))))));
  }

//+------------------------------------------------------------------+
//| UpdateRange - Calc range bounds within regression Periods        |
//+------------------------------------------------------------------+
void CTickMA::UpdateRange(void)
  {
    double rangehigh      = BoolToDouble(IsEqual(tmaBar,0),Close[tmaBar],High[tmaBar],Digits);
    double rangelow       = BoolToDouble(IsEqual(tmaBar,0),Close[tmaBar],Low[tmaBar],Digits);

    range.Event           = NoEvent;
    range.Age            += BoolToInt(Event(NewSegment),1);

    if (IsHigher(BoolToDouble(IsEqual(tmaBar,0),Close[tmaBar],High[tmaBar],Digits),range.High))
      range.Event         = NewExpansion;

    if (IsLower(BoolToDouble(IsEqual(tmaBar,0),Close[tmaBar],Low[tmaBar],Digits),range.Low))
      range.Event         = NewExpansion;

    if (Event(NewTick))
    {
      for (int node=0;node<fmin(ArraySize(sr),tmaPeriods);node++)
      {
        rangehigh         = fmax(rangehigh,sr[node].High);
        rangelow          = fmin(rangelow,sr[node].Low);
      }

      if (IsChanged(range.High,rangehigh))
        range.Event       = NewContraction;

      if (IsChanged(range.Low,rangelow))
        range.Event       = NewContraction;

      range.Now           = range.High-range.Low;
      range.Mean          = fdiv(range.High+range.Low,2);
      range.Support       = Price(Fibo23,range.Low,range.High,Expansion);
      range.Resistance    = Price(Fibo23,range.Low,range.High,Retrace);
    }

    if (IsEqual(range.Event,NewExpansion)||tmaBar>0)
    {
      if (NewDirection(range.Direction,BoolToInt(Event(NewHigh),DirectionUp,DirectionDown)))
        if (IsChanged(range.State,Reversal))
        {
          SetEvent(NewReversal,Critical);
          SetEvent(NewDirection,Critical);
        }

      if (IsEqual(range.State,Retrace))
        SetEvent(BoolToEvent(IsChanged(range.State,Breakout),NewBreakout),Critical);

      range.Retrace       = Close[tmaBar];
      range.Age           = 0;
    }
    else
    {
      range.Retrace       = BoolToDouble(IsEqual(range.Direction,DirectionUp),
                              fmin(Close[tmaBar],range.Retrace),
                              fmax(Close[tmaBar],range.Retrace));

      if (IsChanged(range.State,(FractalState)BoolToInt(IsEqual(range.Direction,Direction(range.Retrace-range.Mean)),range.State,Retrace)))
        range.Event       = NewRetrace;
    }

    SetEvent(range.Event,Critical);
  }

//+------------------------------------------------------------------+
//| UpdateSMA - Calc SMA bounds and simple SMA Regression            |
//+------------------------------------------------------------------+
void CTickMA::UpdateSMA(void)
  {
    SMAState  state  = NoValue;
    EventType event  = NoEvent;

    CalcSMA();

    //-- Prep SMA variables
    int dirHigh      = Direction(sma.High[0]-sma.High[1]);
    int dirLow       = Direction(sma.Low[0]-sma.Low[1]);

    sma.Event        = NoEvent;
    sma.Bias         = Action(sma.Close[0]-sma.Open[0]);

    //-- Handle convergences
    if (IsEqual(dirHigh,dirLow))
    {
      if (NewDirection(sma.Direction,dirHigh))
        event        = NewDirection;

      state          = Convergence;
    }
    else

    //-- Handle parabolics
    if (IsEqual(dirHigh,DirectionUp)&&IsEqual(dirLow,DirectionDown))
    {
      sma.Direction  = sr[0].Direction[Lead];
      event          = NewParabolic;
      state          = Parabolic;
    }
    else

    //-- Handle consolidations
    if (IsEqual(dirHigh,DirectionDown)&&IsEqual(dirLow,DirectionUp))
    {
      event          = NewContraction;
      state          = Consolidation;
    }
    else
    
    //-- Handle Flatlines
    if (IsEqual(dirHigh,DirectionNone)&&IsEqual(dirLow,DirectionNone))
    {
      event          = NewFlatline;
      state          = Flatline;
      Print("Flatline");
    }

    if (NewState(sma.State,state))
    {
      sma.Event      = event;

      SetEvent(NewState,Minor);
      SetEvent(sma.Event,Minor);
    }
  }

//+------------------------------------------------------------------+
//| UpdatePoly - Calc poly regression by Periods and Degree          |
//+------------------------------------------------------------------+
void CTickMA::UpdatePoly(void)
  {
    CalcPoly(ptOpen,poly.Open);
    CalcPoly(ptClose,poly.Close);
    
    poly.Direction             = Direction(poly.Close[0]-poly.Close[1]);
    poly.Bias                  = Action(Direction(poly.Close[0]-poly.Open[0]));
  }

//+------------------------------------------------------------------+
//| UpdateLinear - Calc linear regression from Poly Regression       |
//+------------------------------------------------------------------+
void CTickMA::UpdateLinear(void)
  {
    int bias                   = NoBias;

    CalcLinear(poly.Open,line.Open.Price);
    CalcLinear(poly.Close,line.Close.Price);

    CalcFOC(ptOpen,line.Open);
    CalcFOC(ptClose,line.Close);

    line.Direction             = line.Open.Direction;
    line.Event                 = NoEvent;

    if (Event(NewTick))
    {
      //-- Handle Zero Deviation
      if (IsEqual(line.Close.Min,line.Close.Max,Digits))
        bias                   = Action(line.Close.Max-line.Open.Now);
      else
      if (IsEqual(line.Close.Min,line.Close.Now,Digits))
        bias                   = Action(line.Close.Min-line.Open.Now);
      else
      if (Event(NewBias,Major))
        bias                   = line.Close.Bias;

      line.Event               = BoolToEvent(NewAction(line.Bias,bias),NewBias);

      SetEvent(line.Event,Critical);
    }
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Updates Composite Fractal                        |
//+------------------------------------------------------------------+
void CTickMA::UpdateFractal(void)
  {
    fr.Event               = NoEvent;
    fr.Bias                = Action(Direction(fr.High.Bar[Expansion]-fr.Low.Bar[Expansion]));

    if (IsChanged(fr.Type,(FractalType)BoolToInt(IsEqual(fr.High.Type,fr.Low.Type),fr.High.Type,fr.Type)))
    {
      if (IsEqual(fr.Type,Expansion))
      {
        if (NewDirection(fr.Direction,fr.High.Direction[Trend]))
        {
          if (NewState(fr.State,Reversal))
            fr.Event        = NewReversal;
        }
        else
        {
          if (NewState(fr.State,Breakout))
            fr.Event        = NewBreakout;
        }
        
        SetEvent(NewFractal,Major);
      }
      else 
      {
        if (NewState(fr.State,Retrace))
          fr.Event          = FractalEvent(fr.Type);
      }
        
      SetEvent(fr.Event,Major);
    }
  }

//+------------------------------------------------------------------+
//| TickMA Class Constructor                                         |
//+------------------------------------------------------------------+
CTickMA::CTickMA(int Periods, int Degree, double Aggregate)
  {
    tmaPeriods                 = Periods;
    tmaDegree                  = Degree;
    tmaTickAgg                 = point(Aggregate);
    tmaBar                     = Bars-1;

    ArrayInitialize(tmaDirection,DirectionChange);

    ArrayResize(poly.Open,tmaPeriods);
    ArrayResize(poly.Close,tmaPeriods);

    ArrayResize(line.Open.Price,tmaPeriods);
    ArrayResize(line.Close.Price,tmaPeriods);

    NewTick();
    NewSegment();
    
    //-- Initialize Range
    range.Direction           = Direction(Close[tmaBar]-Close[tmaBar]);
    range.High                = High[tmaBar];
    range.Low                 = Low[tmaBar];
    range.Mean                = fdiv(range.High+range.Low,2,Digits);
    range.Retrace             = Close[tmaBar];
    range.State               = NoState;
    
    //-- Preload SMA Price arrays
    ArrayResize(sma.Open,tmaPeriods);
    ArrayResize(sma.High,tmaPeriods+1);
    ArrayResize(sma.Low,tmaPeriods+1);
    ArrayResize(sma.Close,tmaPeriods);

    //-- Preload History (Initialize)
    fr.Support                = Low[tmaBar];
    fr.Resistance             = High[tmaBar];
    fr.Expansion              = Close[tmaBar];

    for (tmaBar=Bars-1;tmaBar>0;tmaBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| TickMA Class Destructor                                          |
//+------------------------------------------------------------------+
CTickMA::~CTickMA()
  {

  }

//+------------------------------------------------------------------+
//| Update - Tick-by-tick update                                     |
//+------------------------------------------------------------------+
void CTickMA::Update(void)
  {
    ClearEvents();

    UpdateTick();
    UpdateSegment();
    UpdateRange();

    if (Count(Segments)>Slow)
    {
      UpdateSMA();

      CalcMomentum(mr.Open,sma.Open);
      CalcMomentum(mr.High,sma.High);
      CalcMomentum(mr.Low,sma.Low);
      CalcMomentum(mr.Close,sma.Close);
    }

    if (Count(Segments)>tmaPeriods)
    {
      UpdatePoly();
      UpdateLinear();

      CalcFractal(fr.High,sma.High);
      CalcFractal(fr.Low,sma.Low);
      
      UpdateFractal();
    }
  }

//+------------------------------------------------------------------+
//| TickStr - Returns formatted Tick String by Node                  |
//+------------------------------------------------------------------+
string CTickMA::TickStr(int Node=0)
  {
    string text     = "";

    if (ArraySize(tr)>Node)
    {
      Append(text,"Tick|"+(string)(ArraySize(tr)-(Node+1)),"\n");
      Append(text,(string)tr[Node].Count,"|");
      Append(text,DoubleToStr(tr[Node].Open,Digits),"|");
      Append(text,DoubleToStr(tr[Node].High,Digits),"|");
      Append(text,DoubleToStr(tr[Node].Low,Digits),"|");
      Append(text,DoubleToStr(tr[Node].Close,Digits),"|");
    }

    return text;
  }

//+------------------------------------------------------------------+
//| TickHistoryStr - Returns formatted Tick History from 0 to Count  |
//+------------------------------------------------------------------+
string CTickMA::TickHistoryStr(int Count=0)
  {
    string text  = "";
    int    count = fmin(Count,ArraySize(tr));

    for (int node=count;node>0;node--)
      Append(text,TickStr(node-1),"\n");

    return text;
  }

//+------------------------------------------------------------------+
//| SegmentStr - Returns formatted segment text from Now(0) to Count |
//+------------------------------------------------------------------+
string CTickMA::SegmentStr(int Node)
  {
    string text  = "";

    if (Count(Segments)>Node)
    {
      Append(text,"Segment|"+(string)(ArraySize(sr)-(Node+1)));
      Append(text,DirText(sr[Node].Direction[Trend]),"|");
      Append(text,DirText(sr[Node].Direction[Term]),"|");
      Append(text,DirText(sr[Node].Direction[Lead]),"|");
      Append(text,ActionText(sr[Node].Bias),"|");
      Append(text,EnumToString(sr[Node].Event),"|");

      Append(text,(string)sr[Node].Count,"|");
      Append(text,DoubleToStr(sr[Node].Open,Digits),"|");
      Append(text,DoubleToStr(sr[Node].High,Digits),"|");
      Append(text,DoubleToStr(sr[Node].Low,Digits),"|");
      Append(text,DoubleToStr(sr[Node].Close,Digits),"|");
    }

    return text;
  }

//+------------------------------------------------------------------+
//| SegmentHistoryStr - Return formatted segment text from Count to 0|
//+------------------------------------------------------------------+
string CTickMA::SegmentHistoryStr(int Count=0)
  {
    string text  = "\n";
    int    count = fmin(Count,ArraySize(sr));

    for (int node=count;node>0;node--)
      Append(text,SegmentStr(node-1),"\n");

    return text;
  }

//+------------------------------------------------------------------+
//| SegmentTickStr - Returns formatted segment and related tick text |
//+------------------------------------------------------------------+
string CTickMA::SegmentTickStr(int Node)
  {
    string text  = "";

    if (IsEqual(ArraySize(sr)-1,Node))
      return (SegmentStr(0)+"|"+TickStr(1));

    return text;
  }

//+------------------------------------------------------------------+
//| RangeStr - Returns formatted range text and prices               |
//+------------------------------------------------------------------+
string CTickMA::RangeStr(void)
  {
    string text      = "Range";

    Append(text,DirText(range.Direction),"|");
    Append(text,EnumToString(range.State),"|");
    Append(text,EnumToString(range.Event),"|");
    Append(text,DoubleToStr(range.High,Digits),"|");
    Append(text,DoubleToStr(range.Low,Digits),"|");
    Append(text,DoubleToStr(range.Mean,Digits),"|");
    Append(text,DoubleToStr(range.Retrace,Digits),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| SMAStr - Returns Master formatted SMA text, prices, Fractal      |
//+------------------------------------------------------------------+
string CTickMA::SMAStr(int Count=0)
  {
    string text      = "SMA";

    Append(text,DirText(sma.Direction),"|");
    Append(text,ActionText(sma.Bias),"|");
    Append(text,EnumToString(sma.State),"|");
    Append(text,EnumToString(sma.Event),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| PolyStr - Returns formatted poly text and prices                 |
//+------------------------------------------------------------------+
string CTickMA::PolyStr(void)
  {
    string text      = "Poly";
    string textopen  = "Open";
    string textclose = "Close";

    Append(text,DirText(poly.Direction),"|");
    Append(text,ActionText(poly.Bias),"|");
    Append(text,DoubleToStr(poly.High,Digits),"|");
    Append(text,DoubleToStr(poly.Low,Digits),"|");

    for (int node=0;node<tmaPeriods;node++)
    {
      Append(textopen,DoubleToStr(poly.Open[node],Digits),"|");
      Append(textclose,DoubleToStr(poly.Close[node],Digits),"|");
    }

    Append(text,textopen,"\n");
    Append(text,textclose,"\n");
    
    return text;
  }

//+------------------------------------------------------------------+
//| FOCStr - Returns formatted FOC text & prices for supplied FOCRec |
//+------------------------------------------------------------------+
string CTickMA::FOCStr(FOCRec &FOC)
  {
    string text     = "";

    Append(text,DirText(FOC.Direction),"|");
    Append(text,ActionText(FOC.Bias),"|");
    Append(text,EnumToString(FOC.State),"|");
    Append(text,EnumToString(FOC.Event),"|");
    Append(text,DoubleToStr(FOC.Min,Digits),"|");
    Append(text,DoubleToStr(FOC.Max,Digits),"|");
    Append(text,DoubleToStr(FOC.Now,Digits),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| LinearStr - Returns formatted Linear Regression/FOC text & prices|
//+------------------------------------------------------------------+
string CTickMA::LinearStr(int Count=0)
  {
    string text      = "Line";
    string textopen  = "Open";
    string textclose = "Close";

    Append(text,DirText(line.Direction),"|");
    Append(text,ActionText(line.Bias),"|");
    Append(text,EnumToString(line.Event),"|");
    Append(textopen,FOCStr(line.Open),"|");
    Append(textclose,FOCStr(line.Close),"|");

    for (int node=0;node<Count;node++)
    {
      Append(textopen,DoubleToStr(line.Open.Price[node],Digits),"|");
      Append(textclose,DoubleToStr(line.Close.Price[node],Digits),"|");
    }

    Append(text,textopen,"|");
    Append(text,textclose,"|");
    
    return text;
  }

//+------------------------------------------------------------------+
//| EventStr - Returns text on all collections by supplied event     |
//+------------------------------------------------------------------+
string CTickMA::EventStr(EventType Type)
  {
    string text      = "|"+EnumToString(Type);

    Append(text,EnumToString(EventLevel(Type)),"|");
    
    if (Event(Type))
    {
      Append(text,EnumToString(sr[0].Event),"|");
      Append(text,EnumToString(sma.Event),"|");
      Append(text,EnumToString(range.Event),"|");
      Append(text,EnumToString(line.Event),"|");
      Append(text,EnumToString(line.Open.Event),"|");
      Append(text,EnumToString(line.Close.Event),"|");

      Append(text,EventStr(),"|");
    }      

    return text;
  }

//+------------------------------------------------------------------+
//| FractalDetailStr - Formats Fractal Detail for supplied Fractal   |
//+------------------------------------------------------------------+
string CTickMA::FractalDetailStr(FractalDetail &Fractal)
  {
    string text      = "";

    for (FractalType type=Origin;type<FractalTypes;type++)
    {
      Append(text,EnumToString(type),"|");
      Append(text,DirText(Fractal.Direction[type]),"|");
      Append(text,(string)Fractal.Bar[type],"|");
      Append(text,DoubleToStr(Fractal.Point[type],Digits),"|");
    }
    
    return text;
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns formatted Fractal data of supplied Fractal  |
//+------------------------------------------------------------------+
string CTickMA::FractalStr(FractalRec &Fractal)
  {
    string text      = "";
    
    Append(text,DirText(Fractal.Direction),"|");
    Append(text,EnumToString(Fractal.Type),"|");
    Append(text,EnumToString(Fractal.State),"|");
    Append(text,EnumToString(Fractal.Event),"|");
    
    Append(text,"High|"+FractalDetailStr(Fractal.High),"|");
    Append(text,"Low|"+FractalDetailStr(Fractal.Low),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| Momentum - Returns MomentumDetail by PriceType                   |
//+------------------------------------------------------------------+
MomentumDetail CTickMA::Momentum(PriceType Type)
  {
    MomentumDetail detail     = {NoDirection,NoBias,NoEvent,0.00,0.00};

    switch (Type)
    {
      case ptOpen:   return (mr.Open);
      case ptHigh:   return (mr.High);
      case ptLow:    return (mr.Low);
      case ptClose:  return (mr.Close);
    }
    
    return detail;
  }

//+------------------------------------------------------------------+
//| MomentumDetailStr - Returns formatted Momentum data by PriceType |
//+------------------------------------------------------------------+
string CTickMA::MomentumDetailStr(PriceType Type)
  {
    const string type[PriceTypes] = {"Open","High","Low","Close"};
    string       text             = "";

    MomentumDetail detail  = Momentum(Type);

    Append(text,type[Type],"|");
    Append(text,DirText(detail.Direction),"|");
    Append(text,ActionText(detail.Bias),"|");
    Append(text,EnumToString(detail.Event),"|");
    Append(text,DoubleToStr(detail.Now,Digits),"|");
    Append(text,DoubleToStr(detail.Change,Digits),"|");
    
    return text;
  }

//+------------------------------------------------------------------+
//| MomentumStr - Returns formatted Momentum data by Action          |
//+------------------------------------------------------------------+
string CTickMA::MomentumStr(void)
  {
    string text      = "";

    for (PriceType type=ptOpen;type<PriceTypes;type++)
      Append(text,MomentumDetailStr(type),"\n");

    return text;
  }

//+------------------------------------------------------------------+
//| NewState - Identifies State changes to SMA's                     |
//+------------------------------------------------------------------+
bool NewState(SMAState &State, SMAState Change, bool Update=true)
  {
    if (IsEqual(Change,NoValue))
      return (false);
      
    if (IsEqual(State,Change))
      return (false);
      
    if (Update)
      State           = Change;
      
    return (true);
  }