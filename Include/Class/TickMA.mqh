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

class CTickMA : public CEvent
  {

private:

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
             int          Count;
             double       Open;
             double       High;
             double       Low;
             double       Close;
           };

    struct SegmentRec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             TickRec      Price;
           };

    struct RangeRec
           {
             int          Direction;
             FractalState State;
             EventType    Event;
             double       High;
             double       Low;
             double       Now;
             double       Mean;
             double       Retrace;
           };

    struct PegRec
           {
             //-- 1:Price[0] between Retrace/Expansion; set Retrace; 2:Price[0] between Retrace/Recovery; Set Recovery; 3:Once set, bounds set Breakout/Reversal;
             bool         IsPegged;
             double       Expansion;
             double       Retrace;
             double       Recovery;
           };

    struct FractalRec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             FractalState State;
             double       Price[];
             double       LastPrice;
             double       Point[FractalPoints];
             PegRec       Peg;
           };

    struct SMARec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             FractalState State;
             FractalRec   Open;
             FractalRec   High;
             FractalRec   Low;
             FractalRec   Close;
           };

    struct PolyRec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             double       Open[];
             double       High;
             double       Low;
             double       Close[];
           };

    struct FOCRec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             double       Price[];
             double       Min;
             double       Max;
             double       Now;

           };

    struct LineRec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             FOCRec       Open;
             FOCRec       Close;
           };

    void             InitFractal(FractalRec &Fractal, double Price);

    void             CalcFractal(FOCRec &FOC, AlertLevel Level);
    void             CalcFractal(FractalRec &Fractal, AlertLevel Level);
    void             CalcSMA(void);
    void             CalcPoly(double &Poly[], PriceType Type);
    void             CalcLinear(double &Source[], double &Target[]);

    void             NewTick();
    void             NewSegment(void);

    void             UpdateTick(void);
    void             UpdateSegment(void);
    void             UpdateRange(void);
    void             UpdateSMA(void);
    void             UpdatePoly(void);
    void             UpdateLinear(void);

    int              tmaPeriods;
    int              tmaDegree;
    int              tmaSMASlow;
    int              tmaSMAFast;
    int              tmaSMAKeep;
    double           tmaTickAgg;

    int              tmaSegmentDir;
    int              tmaSegmentBar;
    
    //-- Aggregation Structures
    TickRec          tr[];          //-- Tick Record
    SegmentRec       sr[];          //-- Segment Record
    RangeRec         range;         //-- Range Record
    SMARec           sma;           //-- SMA Master Record
    PolyRec          poly;          //-- Poly Regr Record
    LineRec          line;          //-- Linear Regr Record


public:

    void             Update(void);

    TickRec          Tick(int Node)        { return(tr[Node]); };
    SegmentRec       Segment(int Node)     { return(sr[Node]); };
    RangeRec         Range(void)           { return(range); };
    SMARec           SMA(void)             { return(sma); };
    PolyRec          Poly(void)            { return(poly); };
    LineRec          Line(void)            { return(line); };

    int              Count(CountType Type) { return(BoolToInt(IsEqual(Type,Ticks),ArraySize(tr),ArraySize(sr))); };

                     CTickMA(int Periods, int Degree, double Aggregate);
                    ~CTickMA();

    //-- Format strings
    string           TickStr(int Count=0);
    string           TickHistoryStr(int Count=0);
    string           SegmentStr(int Node);
    string           SegmentHistoryStr(int Count=0);
    string           SegmentTickStr(int Node);
    string           FractalStr(FractalRec &Fractal, int HistoryCount=0);
    string           SMAStr(int HistoryCount=0);
    string           PolyStr(void);
    string           RangeStr(void);
  };

//+------------------------------------------------------------------+
//| InitFractal - Initialize Fractal Rec on price[0]                 |
//+------------------------------------------------------------------+
void CTickMA::InitFractal(FractalRec &Fractal, double Price)
  {
    Fractal.Direction       = DirectionNone;
    Fractal.Bias            = OP_NO_ACTION;
    Fractal.Event           = NoEvent;
    Fractal.State           = NoState;

    Fractal.Peg.IsPegged    = false;
    Fractal.Peg.Expansion   = 0.00;       
    Fractal.Peg.Retrace     = 0.00;
    Fractal.Peg.Recovery    = 0.00;

    ArrayInitialize(Fractal.Point,Price);
    ArrayInitialize(Fractal.Point,Price);
  }

//+------------------------------------------------------------------+
//| CalcFractal - Computes Linear(FOC) Fractal states, events, points|
//+------------------------------------------------------------------+
void CTickMA::CalcFractal(FOCRec &FOC, AlertLevel Level)
  {
    int bias                = FOC.Bias;
    
    //--- compute FOC metrics
    FOC.Now                 = (atan(fdiv(pip(FOC.Price[0]-FOC.Price[tmaPeriods-1]),tmaPeriods))*180)/M_PI;
    FOC.Event               = NoEvent;

    if (NewDirection(FOC.Direction,Direction(FOC.Price[0]-FOC.Price[1])))
      FOC.Event             = NewDirection;
    else
    if (NormalizeDouble(fabs(FOC.Now),Digits)>NormalizeDouble(fabs(FOC.Max),Digits))
      FOC.Event             = NewExpansion;
    else
    if (NormalizeDouble(fabs(FOC.Now),Digits)<NormalizeDouble(fabs(FOC.Max),Digits))
      FOC.Event             = NewRetrace;
    
    if (IsEqual(FOC.Event,NoEvent))
      return;

    FOC.Min                 = FOC.Now;

    if (IsEqual(FOC.Event,NewRetrace))
      bias                  = Action(FOC.Direction,InDirection,InContrarian);
    else
    {
      FOC.Max               = FOC.Now;
      bias                  = Action(FOC.Direction);
    }
    
    if (Event(NewTick))
      SetEvent(BoolToEvent(IsChanged(FOC.Bias,bias),NewBias),Level);

    SetEvent(FOC.Event,Level);
  }

//+------------------------------------------------------------------+
//| CalcFractal - Computes Fractal states, events, points            |
//+------------------------------------------------------------------+
void CTickMA::CalcFractal(FractalRec &Fractal, AlertLevel Level)
  {
    int          direction  = Direction(Fractal.Price[0]-Fractal.LastPrice);

    FractalState state      = NoState;
    
    Fractal.Event           = NoEvent;
    Fractal.LastPrice       = Fractal.Price[0];

    //-- Filter SMA Flats
    if (IsEqual(direction,DirectionNone))
      return;

    //-- Handle SMA Change
    if (NewBias(Fractal.Bias,Action(direction)))
      Fractal.Event         = NewBias;

    //-- Handle Interior States
    if (IsBetween(Fractal.Price[0],Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Digits))
    {
      //-- Handle Retrace
      if (IsBetween(Fractal.Price[0],Fractal.Point[fpRoot],Fractal.Point[fpBase],Digits))
        state               = Retrace;
      else

      //-- Handle Recovery
      if (IsEqual(Fractal.State,Retrace)||IsEqual(Fractal.State,Recovery))
        state               = Recovery;
      else

      //-- Handle Rally/Pullback
        state                 = (FractalState)BoolToInt(IsEqual(Fractal.Bias,OP_BUY),Rally,Pullback);

      //-- Handle Convergences
      if (IsBetween(Fractal.Price[0],Fractal.Point[fpExpansion],Fractal.Point[fpRetrace],Digits))
        if (IsChanged(Fractal.Peg.IsPegged,true))
        {
          Fractal.Peg.Expansion     = Fractal.Point[fpExpansion];
          Fractal.Peg.Retrace       = Fractal.Point[fpRetrace];
          Fractal.Peg.Recovery      = Fractal.Point[fpRecovery];
        }

      if (Fractal.Peg.IsPegged)
        if (!IsBetween(Fractal.Price[0],Fractal.Peg.Expansion,Fractal.Peg.Retrace,Digits))
        {
          state           = (FractalState)BoolToInt(NewDirection(Fractal.Direction,direction),Reversal,Breakout);

          if (IsEqual(state,Reversal))
          {
            Fractal.Point[fpOrigin]    = Fractal.Point[fpExpansion];
            Fractal.Point[fpBase]      = Fractal.Point[fpRetrace];
            Fractal.Point[fpRoot]      = Fractal.Point[fpRecovery];
          }
          
          else
          {
            Fractal.Point[fpBase]      = Fractal.Point[fpExpansion];
            Fractal.Point[fpRoot]      = Fractal.Point[fpRetrace];
          }

          Fractal.Point[fpExpansion]   = Fractal.Price[0];
          Fractal.Point[fpRetrace]     = Fractal.Price[0];
          Fractal.Point[fpRecovery]    = Fractal.Price[0];

          Fractal.Peg.IsPegged         = false;
        }

      if (IsChanged(Fractal.Point[fpRetrace],BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),
                                               fmin(Fractal.Point[fpRetrace],Fractal.Price[0]),
                                               fmax(Fractal.Point[fpRetrace],Fractal.Price[0]),Digits)))
        Fractal.Point[fpRecovery]      = Fractal.Point[fpRetrace];
      else
        Fractal.Point[fpRecovery]      = BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),
                                           fmax(Fractal.Point[fpRecovery],Fractal.Price[0]),
                                           fmin(Fractal.Point[fpRecovery],Fractal.Price[0]),Digits);
    }
    else

    //-- Handle Breakout/Reversal
    {
      if (NewDirection(Fractal.Direction,direction))
      {
        state             = Reversal;

        Fractal.Point[fpOrigin]        = Fractal.Point[fpExpansion];
        Fractal.Point[fpBase]          = Fractal.Point[fpRoot];
        Fractal.Point[fpRoot]          = Fractal.Point[fpExpansion];
      }
      
      else
      {
        state             = (FractalState)BoolToInt(IsEqual(Fractal.State,Reversal),Reversal,Breakout);
          
//        if (!IsEqual(Fractal.State,Breakout)&&!IsEqual(Fractal.State,Reversal))  //-- Not on continuing Breakout/Reversal
        if (!IsEqual(Fractal.State,state))  //-- Set on new Breakout/Reversal
        {
          Fractal.Point[fpBase]        = Fractal.Point[fpExpansion];
          Fractal.Point[fpRoot]        = Fractal.Point[fpRetrace];
        }
      }

      Fractal.Point[fpExpansion]       = Fractal.Price[0];
      Fractal.Point[fpRetrace]         = Fractal.Price[0];
      Fractal.Point[fpRecovery]        = Fractal.Price[0];

      Fractal.Peg.IsPegged             = false;
    }

    if (IsChanged(Fractal.State,state))
    {
      Fractal.Event       = BoolToEvent(IsEqual(Fractal.Event,NewBias),Fractal.Event,FractalEvent[state]);

      SetEvent(FractalEvent[state]);
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
      ArrayCopy(sma.Open.Price,sma.Open.Price,1,0,tmaSMAKeep-1);
      ArrayCopy(sma.High.Price,sma.High.Price,1,0,tmaSMAKeep-1);
      ArrayCopy(sma.Low.Price,sma.Low.Price,1,0,tmaSMAKeep-1);
      ArrayCopy(sma.Close.Price,sma.Close.Price,1,0,tmaSMAKeep-1);
    }

    for (int node=0;node<tmaSMASlow;node++)
    {
      if (node<tmaSMAFast)
      {
        calcsma.High     += sr[node].Price.High;
        calcsma.Low      += sr[node].Price.Low;
      }

      calcsma.Open       += sr[node].Price.Open;
      calcsma.Close      += sr[node].Price.Close;
    }

    sma.Open.Price[0]     = fdiv(calcsma.Open,tmaSMASlow);
    sma.High.Price[0]     = fdiv(calcsma.High,tmaSMAFast);
    sma.Low.Price[0]      = fdiv(calcsma.Low,tmaSMAFast);
    sma.Close.Price[0]    = fdiv(calcsma.Close,tmaSMASlow);
  }

//+------------------------------------------------------------------+
//| CalcPoly - computes polynomial regression to x degree            |
//+------------------------------------------------------------------+
void CTickMA::CalcPoly(double &Poly[], PriceType Type)
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
        src    = BoolToDouble(IsEqual(Type,ptOpen),sr[n].Price.Open,
                 BoolToDouble(IsEqual(Type,ptClose),sr[n].Price.Close,
                 BoolToDouble(IsEqual(Type,ptHigh),sr[n].Price.High,
                 BoolToDouble(IsEqual(Type,ptLow),sr[n].Price.Low))));

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
//| CalcLine - Calculate Linear Regression                           |
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
      Target[idx]    = (m[0]*(idx+1))+b;    //--- y=mx+b
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
    tr[0].Open                = BoolToDouble(IsEqual(tmaSegmentBar,0),Close[0],Open[tmaSegmentBar]);
    tr[0].High                = BoolToDouble(IsEqual(tmaSegmentBar,0),Close[0],High[tmaSegmentBar]);
    tr[0].Low                 = BoolToDouble(IsEqual(tmaSegmentBar,0),Close[0],Low[tmaSegmentBar]);
    tr[0].Close               = Close[tmaSegmentBar];

    SetEvent(NewTick);
  }

//+------------------------------------------------------------------+
//| NewSegment - inserts a new 0-Base segment aggregation record     |
//+------------------------------------------------------------------+
void CTickMA::NewSegment(void)
  {
    ArrayResize(sr,ArraySize(sr)+1,32768);
    
    if (ArraySize(sr)>1)
      ArrayCopy(sr,sr,1,0,ArraySize(sr)-1);

    sr[0].Price               = tr[0];
    sr[0].Direction           = tmaSegmentDir;
    sr[0].Event               = BoolToEvent(IsEqual(sr[0].Direction,DirectionUp),NewRally,NewPullback);
    sr[0].Price.Count         = 0;
    sr[0].Price.High          = fmax(sr[0].Price.High,tr[1].High);
    sr[0].Price.Low           = fmin(sr[0].Price.Low,tr[1].Low);

    SetEvent(NewSegment,Nominal);
  }

//+------------------------------------------------------------------+
//| UpdateTick - Calc tick bounds and update tick history            |
//+------------------------------------------------------------------+
void CTickMA::UpdateTick(void)
  {
    if (fabs(tr[0].Open-Close[tmaSegmentBar])>=tmaTickAgg)
      NewTick();

    if (IsHigher(BoolToDouble(IsEqual(tmaSegmentBar,0),Close[0],High[tmaSegmentBar]),tr[0].High))
      SetEvent(NewHigh,Notify);

    if (IsLower(BoolToDouble(IsEqual(tmaSegmentBar,0),Close[0],Low[tmaSegmentBar]),tr[0].Low))
      SetEvent(NewLow,Notify);

    tr[0].Close          = Close[tmaSegmentBar];
    tr[0].Count++;
  }

//+------------------------------------------------------------------+
//| UpdateSegment - Calc segment bounds and update segment history   |
//+------------------------------------------------------------------+
void CTickMA::UpdateSegment(void)
  {
    if (Count(Segments)>1)
      sr[0].Event               = NoEvent;

    if (NewDirection(tmaSegmentDir,Direction(tr[0].Open-tr[1].Close)))
      NewSegment();

    if (IsHigher(tr[0].High,sr[0].Price.High))
      SetEvent(NewHigh,Nominal);

    if (IsLower(tr[0].Low,sr[0].Price.Low))
      SetEvent(NewLow,Nominal);

    if (Count(Segments)>1)
    {
      if (Event(NewHigh,Nominal)||Event(NewSegment))
        if (IsHigher(sr[0].Price.High,sr[1].Price.High,NoUpdate,Digits))
          SetEvent(NewHigh,Nominal);

      if (Event(NewLow,Nominal)||Event(NewSegment))
        if (IsLower(sr[0].Price.Low,sr[1].Price.Low,NoUpdate,Digits))
          SetEvent(NewLow,Nominal);
      }

    sr[0].Price.Close         = tr[0].Close;
    sr[0].Price.Count        += BoolToInt(Event(NewTick),1);
    
    SetEvent(BoolToEvent(NewAction(sr[0].Bias,Action(Direction(sr[0].Price.Close-sr[0].Price.Open),InDirection)),NewBias),Nominal);
    SetEvent(sr[0].Event,Nominal);
  }

//+------------------------------------------------------------------+
//| UpdateRange - Calc range bounds within regression Periods        |
//+------------------------------------------------------------------+
void CTickMA::UpdateRange(void)
  {
    double rangehigh      = Close[tmaSegmentBar];
    double rangelow       = Close[tmaSegmentBar];

    range.Event           = NoEvent;

    if (IsHigher(Close[tmaSegmentBar],range.High))
      range.Event         = NewExpansion;

    if (IsLower(Close[tmaSegmentBar],range.Low))
      range.Event         = NewExpansion;

    if (Event(NewTick))
    {
      for (int node=0;node<fmin(ArraySize(sr),tmaPeriods);node++)
      {
        rangehigh         = fmax(rangehigh,sr[node].Price.High);
        rangelow          = fmin(rangelow,sr[node].Price.Low);
      }

      if (IsChanged(range.High,rangehigh))
        range.Event       = NewContraction;

      if (IsChanged(range.Low,rangelow))
        range.Event       = NewContraction;

      range.Now           = range.High-range.Low;
      range.Mean          = fdiv(range.High+range.Low,2);
    }

    if (IsEqual(range.Event,NewExpansion))
    {
      if (NewDirection(range.Direction,BoolToInt(Event(NewHigh),DirectionUp,DirectionDown)))
        SetEvent(BoolToEvent(IsChanged(range.State,Reversal),NewReversal));

      if (IsEqual(range.State,Retrace))
        SetEvent(BoolToEvent(IsChanged(range.State,Breakout),NewBreakout));

      range.Retrace       = Close[tmaSegmentBar];
    }
    else
    {
      range.Retrace       = BoolToDouble(IsEqual(range.Direction,DirectionUp),
                              fmin(Close[tmaSegmentBar],range.Retrace),
                              fmax(Close[tmaSegmentBar],range.Retrace));

      if (IsChanged(range.State,(FractalState)BoolToInt(IsEqual(range.Direction,Direction(range.Retrace-range.Mean)),range.State,Retrace)))
        range.Event       = NewRetrace;
    }

    SetEvent(range.Event,Major);
  }

//+------------------------------------------------------------------+
//| UpdateSMA - Calc SMA bounds and simple SMA Regression            |
//+------------------------------------------------------------------+
void CTickMA::UpdateSMA(void)
  {
    CalcSMA();

    CalcFractal(sma.Open,Minor);    
    CalcFractal(sma.High,Minor);
    CalcFractal(sma.Low,Minor);
    CalcFractal(sma.Close,Minor);
    
    //-- Prep SMA variables
    sma.Event     = NoEvent;
    sma.Bias      = Action(sma.Close.Price[0]-sma.Open.Price[0]);
    
    //-- Handle convergences
    if (IsEqual(sma.High.Direction,sma.Low.Direction))
    {
      sma.Event   = BoolToEvent(NewDirection(sma.Direction,sma.High.Direction),BoolToEvent(IsEqual(sma.Direction,DirectionUp),sma.High.Event,sma.Low.Event));
      sma.State   = (FractalState)BoolToInt(IsEqual(sma.Direction,DirectionUp),sma.High.State,sma.Low.State);
    }
    else
    
    //-- Handle parabolics
    if (IsEqual(sma.High.Direction,DirectionUp))
    {
      sma.Event   = NewParabolic;
      sma.State   = (FractalState)BoolToInt(IsEqual(Direction(sma.Bias,InAction),DirectionUp),sma.High.State,sma.Low.State);
    }

    //-- Handle consolidations
    else
    {
      sma.Event   = NewContraction;
      sma.State   = (FractalState)BoolToInt(IsEqual(sma.Direction,DirectionUp),sma.High.State,sma.Low.State);
    }
    
//    if (Event(NewTick)) Print((string)Count(Ticks)+"|"+SegmentStr(0)+"|"+FractalStr(sma.High,2));
  }

//+------------------------------------------------------------------+
//| UpdatePoly - Calc poly regression by Periods and Degree          |
//+------------------------------------------------------------------+
void CTickMA::UpdatePoly(void)
  {
    CalcPoly(poly.Open,ptOpen);
    CalcPoly(poly.Close,ptClose);
  }

//+------------------------------------------------------------------+
//| UpdateLine - Calc linear regression from Poly Regression         |
//+------------------------------------------------------------------+
void CTickMA::UpdateLinear(void)
  {
    CalcLinear(poly.Open,line.Open.Price);
    CalcLinear(poly.Close,line.Close.Price);

    CalcFractal(line.Open,Major);
    CalcFractal(line.Close,Major);

    line.Direction             = line.Close.Direction;
    line.Event                 = NoEvent;

    if (Event(NewTick))
      line.Event               = BoolToEvent(IsChanged(line.Bias,Action(Direction(line.Close.Price[0]-line.Open.Price[0]))),NewBias);
      
    SetEvent(line.Event,Major);
  }

//+------------------------------------------------------------------+
//| TickMA Class Constructor                                         |
//+------------------------------------------------------------------+
CTickMA::CTickMA(int Periods, int Degree, double Aggregate)
  {
    tmaPeriods                 = Periods;
    tmaDegree                  = Degree;
    tmaSMAFast                 = 2;
    tmaSMASlow                 = 3;
    tmaSMAKeep                 = Periods;
    tmaTickAgg                 = point(Aggregate);
    tmaSegmentDir              = DirectionChange;    
    tmaSegmentBar              = Bars-1;

    ArrayResize(poly.Open,tmaPeriods);
    ArrayResize(poly.Close,tmaPeriods);

    ArrayResize(line.Open.Price,tmaPeriods);
    ArrayResize(line.Close.Price,tmaPeriods);

    NewTick();
    
    //-- Initialize Range
    range.Direction           = Direction(Close[tmaSegmentBar]-Close[tmaSegmentBar]);
    range.High                = High[tmaSegmentBar];
    range.Low                 = Low[tmaSegmentBar];
    range.Mean                = fdiv(range.High+range.Low,2,Digits);
    range.Retrace             = Close[tmaSegmentBar];
    range.State               = NoState;
    
    //-- Preload SMA Price arrays
    ArrayResize(sma.Open.Price,tmaSMAKeep);
    ArrayResize(sma.High.Price,tmaSMAKeep);
    ArrayResize(sma.Low.Price,tmaSMAKeep);
    ArrayResize(sma.Close.Price,tmaSMAKeep);

    InitFractal(sma.Open,Open[tmaSegmentBar]);
    InitFractal(sma.High,High[tmaSegmentBar]);
    InitFractal(sma.Low,Low[tmaSegmentBar]);
    InitFractal(sma.Close,Close[tmaSegmentBar]);

    //-- Preload History (Initialize)
    for (tmaSegmentBar=Bars-1;tmaSegmentBar>0;tmaSegmentBar--)
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

    if (Count(Segments)>tmaSMASlow)
      UpdateSMA();

    if (Count(Segments)>tmaPeriods)
    {
      UpdatePoly();
      UpdateLinear();
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

    return(text);
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

    return(text);
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
      Append(text,DirText(sr[Node].Direction),"|");
      Append(text,ActionText(sr[Node].Bias),"|");
      Append(text,EnumToString(sr[Node].Event),"|");

      Append(text,(string)sr[Node].Price.Count,"|");
      Append(text,DoubleToStr(sr[Node].Price.Open,Digits),"|");
      Append(text,DoubleToStr(sr[Node].Price.High,Digits),"|");
      Append(text,DoubleToStr(sr[Node].Price.Low,Digits),"|");
      Append(text,DoubleToStr(sr[Node].Price.Close,Digits),"|");
    }

    return(text);
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

    return(text);
  }

//+------------------------------------------------------------------+
//| SegmentTickStr - Returns formatted segment and related tick text |
//+------------------------------------------------------------------+
string CTickMA::SegmentTickStr(int Node)
  {
    string text  = "";

    if (IsEqual(ArraySize(sr)-1,Node))
      return (SegmentStr(0)+"|"+TickStr(1));

    return(text);
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

    return(text);
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns Master formatted Fractal text, prices       |
//+------------------------------------------------------------------+
string CTickMA::FractalStr(FractalRec &Fractal, int HistoryCount=0)
  {
    string       text  = "";

    Append(text,DirText(Fractal.Direction),"|");
    Append(text,ActionText(Fractal.Bias),"|");
    Append(text,EnumToString(Fractal.State),"|");
    Append(text,EnumToString(Fractal.Event),"|");
    Append(text,DoubleToStr(Fractal.LastPrice,Digits),"|");

    for (int node=0;node<HistoryCount;node++)
      Append(text,DoubleToStr(Fractal.Price[node],Digits),"|");

    for (FractalPoint fp=fpOrigin;fp<FractalPoints;fp++)
      Append(text,DoubleToStr(Fractal.Point[fp],Digits),"|");

    Append(text,BoolToStr(Fractal.Peg.IsPegged,"Pegged","Unpegged"),"|");
    Append(text,DoubleToStr(Fractal.Peg.Expansion,Digits),"|");
    Append(text,DoubleToStr(Fractal.Peg.Retrace,Digits),"|");
    Append(text,DoubleToStr(Fractal.Peg.Recovery,Digits),"|");

    return(text);
  }

//+------------------------------------------------------------------+
//| SMAStr - Returns Master formatted SMA text, prices, Fractal      |
//+------------------------------------------------------------------+
string CTickMA::SMAStr(int HistoryCount=0)
  {
    string text      = "SMA";

    Append(text,DirText(sma.Direction),"|");
    Append(text,ActionText(sma.Bias),"|");
    Append(text,EnumToString(sma.State),"|");
    Append(text,EnumToString(sma.Event),"|");
    Append(text,"Open|"+FractalStr(sma.Open,HistoryCount),"|");
    Append(text,"High|"+FractalStr(sma.High,HistoryCount),"|");
    Append(text,"Low|"+FractalStr(sma.Low,HistoryCount),"|");
    Append(text,"Close|"+FractalStr(sma.Close,HistoryCount),"|");

    return(text);
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
    Append(text,EnumToString(poly.Event),"|");
    Append(text,DoubleToStr(poly.High,Digits),"|");
    Append(text,DoubleToStr(poly.Low,Digits),"|");

    for (int node=0;node<tmaPeriods;node++)
    {
      Append(textopen,DoubleToStr(poly.Open[node],Digits),"|");
      Append(textclose,DoubleToStr(poly.Close[node],Digits),"|");
    }

    Append(text,textopen,"\n");
    Append(text,textclose,"\n");
    
    return(text);
  }