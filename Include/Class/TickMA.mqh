//+------------------------------------------------------------------+
//|                                                       TickMA.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

#include <Class\Fractal.mqh>

#define Fast           2
#define Slow           3

class CTickMA : public CFractal
  {

private:

    enum   CountType
           {
             Ticks,
             Segments,
             Pivots
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
             EventType      Event;
             double         High;
             double         Low;
             double         Size;
             double         Mean;
             double         Support;
             double         Resistance;
           };

    struct SMARec
           {
             int            Direction;   //-- Expansion Direction
             int            Bias;        //-- Open/Close cross
             EventType      Event;       //-- Aggregate event
             FractalState   State;       //-- Aggregate state
             double         Open[];
             double         High[];
             double         Low[];
             double         Close[];
           };

    struct LinearRec
           {
             int            Direction;
             FractalState   State;
             EventType      Event;
             int            Bias;
             double         Head;
             double         Tail;
             double         Price[];
             double         FOC[MeasureTypes];
           };

    struct SegmentPivot
           {
             double         Support;
             double         Resistance;
             double         Active;
             double         Mean;
           };

    void             CalcSMA(void);
    void             CalcLinear(double &Buffer[]);

    void             NewTick();
    void             NewSegment(void);

    void             UpdateTick(void);
    void             UpdateSegment(void);
    void             UpdateRange(void);
    void             UpdateSMA(void);
    void             UpdateLinear(void);

    //-- User Configured Properties
    int              tmaPeriods;
    double           tmaTickAgg;

    //-- System Properties
    int              tmaDirection[FractalTypes];
    int              tmaBar;
    
    //-- Aggregation Structures
    TickRec          tr[];             //-- Tick Record
    SegmentRec       sr[];             //-- Segment Record
    RangeRec         range;            //-- Range Record
    SMARec           sma;              //-- SMA Master Record
    LinearRec        line;             //-- Linear Regr Record
    SegmentPivot     seg;              //-- Segment Pivots
    TickRec          tick;             //-- OHLC of incoming tick

public:
                     CTickMA(int Periods, double Aggregate, FractalType Show);
                    ~CTickMA();

    void             Update(void);

    //-- Data Collections
    TickRec          Tick(int Node=0)      {return(tr[Node]);};
    SegmentRec       Segment(int Node=0)   {return(sr[Node]);};
    RangeRec         Range(void)           {return(range);};
    SMARec           SMA(void)             {return(sma);};
    LinearRec        Linear(void)          {return(line);};
    SegmentPivot     Pivot(void)           {return(seg);};

    int              Count(CountType Type) {return(BoolToInt(IsEqual(Type,Ticks),ArraySize(tr),ArraySize(sr)));};
    int              Direction(double &Price[], int Speed=Fast) {return(Direction(Price[0]-Price[Speed-1]));};

    FractalRec       operator[](const FractalType Type)   {return Fractal(Type);};

    //-- Format strings
    string           TickStr(int Count=0);
    string           TickHistoryStr(int Count=0);
    string           SegmentStr(int Node);
    string           SegmentHistoryStr(int Count=0);
    string           SegmentTickStr(int Node);
    string           SMAStr(int Count=0);
    string           RangeStr(void);
    string           LinearStr(int Count=0);
    string           EventStr(EventType Type);
  };

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
//| CalcLinear - Calculate Linear Regression                         |
//+------------------------------------------------------------------+
void CTickMA::CalcLinear(double &Buffer[])
  {
    //--- Linear regression line
    double m[5]           = {0.00,0.00,0.00,0.00,0.00};   //--- slope
    double b              = 0.00;                         //--- y-intercept

    double sumx           = 0.00;
    double sumy           = 0.00;
    
    for (int idx=0;idx<tmaPeriods;idx++)
    {
      sumx += idx+1;
      sumy += fdiv(sma.High[idx]+sma.Low[idx],2);
      
      m[1] += (idx+1)*fdiv(sma.High[idx]+sma.Low[idx],2);            // Exy
      m[3] += pow(idx+1,2);                   // E(x^2)
    }
    
    m[2]    = fdiv(sumx*sumy,tmaPeriods);     // (Ex*Ey)/n
    m[4]    = fdiv(pow(sumx,2),tmaPeriods);   // [(Ex)^2]/n
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy-m[0]*sumx)/tmaPeriods;

    for (int idx=0;idx<tmaPeriods;idx++)
      Buffer[idx]    = (m[0]*(idx+1))+b;      //--- y=mx+b
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
      SetEvent(BoolToEvent(tr[0].Open>tr[1].Open,NewHigh,NewLow),Notify);

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
    sr[0].Event               = NewSegment;

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
            seg.Support      = seg.Active;
            seg.Active       = sr[0].High;

            SetEvent(NewRally,Nominal);
          }

      if (IsEqual(tmaDirection[Term],DirectionUp))
        seg.Active           = fmax(seg.Active,sr[0].High);

      SetEvent(NewHigh,Nominal);
      SetEvent(NewBoundary,Nominal);
    }

    if (IsLower(tr[0].Low,sr[0].Low))
    {
      if (Count(Segments)>1)
        if (IsLower(sr[0].Low,sr[1].Low,NoUpdate,Digits))
          if (NewDirection(tmaDirection[Term],DirectionDown))
          {
            seg.Resistance   = seg.Active;
            seg.Active       = sr[0].Low;

            SetEvent(NewPullback,Nominal);
          }

      if (IsEqual(tmaDirection[Term],DirectionDown))
        seg.Active           = fmin(seg.Active,sr[0].Low);

      SetEvent(NewLow,Nominal);
      SetEvent(NewBoundary,Nominal);
    }

    if (NewDirection(sr[0].Direction[Term],tmaDirection[Term]))
    {
      SetEvent(NewTerm,Nominal);
      SetEvent(NewFractal,Nominal);
    }

    if (!IsBetween(seg.Active,seg.Support,seg.Resistance,Digits))
      if (IsChanged(tmaDirection[Trend],tmaDirection[Term]))
      {
        SetEvent(NewTrend,Nominal);
        SetEvent(NewFractal,Warning);
      }

    sr[0].Close            = tr[0].Close;
    sr[0].Count           += BoolToInt(Event(NewTick),1);
    
    SetEvent(BoolToEvent(NewAction(sr[0].Bias,Action(Direction(sr[0].Close-sr[0].Open),InDirection)),NewBias),Nominal);

    sr[0].Event            = BoolToEvent(Event(NewTrend,Nominal),      NewTrend,
                             BoolToEvent(Event(NewTerm,Nominal),       NewTerm,
                             BoolToEvent(Event(NewSegment,Nominal),    NewSegment,
                             BoolToEvent(Event(NewPullback,Nominal),   NewPullback,
                             BoolToEvent(Event(NewRally,Nominal),      NewRally,
                             BoolToEvent(Event(NewLow,Nominal),        NewLow,
                             BoolToEvent(Event(NewHigh,Nominal),       NewHigh,
                             BoolToEvent(Event(NewBias,Nominal),       NewBias,NoEvent))))))));
  }

//+------------------------------------------------------------------+
//| UpdateRange - Calc range bounds within regression Periods        |
//+------------------------------------------------------------------+
void CTickMA::UpdateRange(void)
  {
    double rangehigh      = BoolToDouble(IsEqual(tmaBar,0),Close[tmaBar],High[tmaBar],Digits);
    double rangelow       = BoolToDouble(IsEqual(tmaBar,0),Close[tmaBar],Low[tmaBar],Digits);
    int    direction      = NoDirection;

    range.Event           = NoEvent;

    if (IsHigher(rangehigh,range.High))
      range.Event         = NewHigh;

    if (IsLower(rangelow,range.Low))
      range.Event         = NewLow;

    if (Event(NewTick))
    {
      for (int node=0;node<fmin(ArraySize(sr),tmaPeriods);node++)
      {
        rangehigh         = fmax(rangehigh,sr[node].High);
        rangelow          = fmin(rangelow,sr[node].Low);
      }

      if (IsChanged(range.High,rangehigh))
        SetEvent(NewContraction,Major);

      if (IsChanged(range.Low,rangelow))
        SetEvent(NewContraction,Major);

      range.Size          = range.High-range.Low;
      range.Mean          = fdiv(range.High+range.Low,2);
      range.Support       = Price(Fibo23,range.Low,range.High,Extension);
      range.Resistance    = Price(Fibo23,range.Low,range.High,Retrace);
    }

    SetEvent(range.Event,Notify);
  }

//+------------------------------------------------------------------+
//| UpdateSMA - Calc SMA bounds and simple SMA Regression            |
//+------------------------------------------------------------------+
void CTickMA::UpdateSMA(void)
  {
    FractalState state  = NoState;
    EventType    event  = NoEvent;

    CalcSMA();

    //-- Prep SMA variables
    int dirHigh      = Direction(sma.High[0]-sma.High[1]);
    int dirLow       = Direction(sma.Low[0]-sma.Low[1]);

    sma.Event        = NoEvent;
    sma.Bias         = Action(sma.Close[0]-sma.Open[0]);

    //-- Handle Flatlines
    if (IsEqual(dirHigh,NoDirection)&&IsEqual(dirLow,NoDirection))
    {
      event          = NewFlatline;
      state          = Flatline;
    }
    else

    //-- Handle convergences
    if (IsEqual(dirHigh,dirLow))
    {
      if (NewDirection(sma.Direction,dirHigh))
        event        = NewDirection;

      state          = Channel;
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
      event          = NewConsolidation;
      state          = Consolidation;
    }

    if (IsChanged(sma.State,(FractalState)BoolToInt(IsEqual(state,NoState),sma.State,state)))
    {
      sma.Event      = event;

      SetEvent(NewState,Minor);
      SetEvent(sma.Event,Minor);
    }
  }

//+------------------------------------------------------------------+
//| UpdateLinear - Calc linear regression from Poly Regression       |
//+------------------------------------------------------------------+
void CTickMA::UpdateLinear(void)
  {
    int    bias             = line.Bias;

    double maxFOC           = fabs(line.FOC[Max]);
    double minFOC           = fabs(line.FOC[Min]);
    double nowFOC           = fabs(line.FOC[Now]);
    
    line.Event              = NoEvent;

    CalcLinear(line.Price);

    //--- compute FOC metrics
    if (Event(NewTick)||Event(NewExpansion,Critical))
    {
      line.Head             = line.Price[0];
      line.Tail             = line.Price[tmaPeriods-1];
      line.FOC[Now]         = (atan(fdiv(pip(line.Head-line.Tail),tmaPeriods))*180)/M_PI;
      
      //-- Adverse Linear-Price Divergence
      if (Event(NewExpansion))
        if (!IsEqual(Direction(line.FOC[Now]),range.Direction))
          SetEvent(AdverseEvent,Critical);

      //-- Linear Directional Slope Change (Lead-Prior Node)
      if (NewDirection(line.Direction,Direction(line.Head-line.Price[1])))
      {
        maxFOC              = NoValue;
        line.Event          = NewDirection;
      }

      if (IsHigher(fabs(line.FOC[Now]),maxFOC,NoUpdate,3)||Event(NewExpansion,Critical))
      {
        bias                = Action(line.Direction);

        line.FOC[Min]       = line.FOC[Now];
        line.FOC[Max]       = line.FOC[Now];
        line.Event          = NewExpansion;
      }
      else
      if (IsLower(fabs(line.FOC[Now]),minFOC,NoUpdate,3))
      {
        bias                = Action(line.Direction,InDirection,InContrarian);

        line.FOC[Min]       = line.FOC[Now];        
        line.Event          = BoolToEvent(IsEqual(bias,OP_BUY),NewRally,NewPullback);
      }
      else 
        bias                = NoBias;

      if (IsChanged(line.Bias,bias))
        SetEvent(NewBias,Nominal);

      SetEvent(line.Event,Nominal);
    }
  }

//+------------------------------------------------------------------+
//| TickMA Class Constructor                                         |
//+------------------------------------------------------------------+
CTickMA::CTickMA(int Periods, double Aggregate, FractalType Show) : CFractal (Show)
  {
    tmaPeriods                 = Periods;
    tmaTickAgg                 = point(Aggregate);
    tmaBar                     = Bars-1;

    ArrayInitialize(tmaDirection,NewDirection);
    ArrayResize(line.Price,tmaPeriods);

    NewTick();
    NewSegment();
    
    //-- Initialize Range
    range.Direction           = Direction(Close[tmaBar]-Close[tmaBar]);
    range.High                = High[tmaBar];
    range.Low                 = Low[tmaBar];
    range.Mean                = fdiv(range.High+range.Low,2,Digits);
    
    //-- Preload SMA Price arrays
    ArrayResize(sma.Open,tmaPeriods);
    ArrayResize(sma.High,tmaPeriods+1);
    ArrayResize(sma.Low,tmaPeriods+1);
    ArrayResize(sma.Close,tmaPeriods);

    //-- Preload History (Initialize)
    seg.Support               = Low[tmaBar];
    seg.Resistance            = High[tmaBar];
    seg.Active                = Close[tmaBar];

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
    UpdateFractal(range.Low,range.High,range.Mean,tmaBar);
    UpdateRange();

    if (Count(Segments)>Slow)
    {
      UpdateSMA();

      if (Count(Segments)>tmaPeriods)
      {
        UpdateLinear();      
        UpdateFractal(range.Low,range.High,range.Mean,tmaBar);
      }
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
    Append(text,EnumToString(range.Event),"|");
    Append(text,DoubleToStr(range.High,Digits),"|");
    Append(text,DoubleToStr(range.Low,Digits),"|");
    Append(text,DoubleToStr(pip(range.Size),1),"|");
    Append(text,DoubleToStr(range.Mean,Digits),"|");
    Append(text,DoubleToStr(range.Support,Digits),"|");
    Append(text,DoubleToStr(range.Resistance,Digits),"|");

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
//| LinearStr - Returns formatted Linear Regression/FOC text & prices|
//+------------------------------------------------------------------+
string CTickMA::LinearStr(int Count=0)
  {
    string text      = "Line";

    Append(text,DirText(line.Direction),"|");
    Append(text,ActionText(line.Bias),"|");
    Append(text,EnumToString(line.Event),"|");
    Append(text,DoubleToStr(line.FOC[Min],Digits),"|");
    Append(text,DoubleToStr(line.FOC[Max],Digits),"|");
    Append(text,DoubleToStr(line.FOC[Now],Digits),"|");

    for (int node=0;node<Count;node++)
      Append(text,DoubleToStr(line.Price[node],Digits),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| EventStr - Returns text on all collections by supplied event     |
//+------------------------------------------------------------------+
string CTickMA::EventStr(EventType Type)
  {
    string text      = "|"+EnumToString(Type);

    Append(text,EnumToString(Alert(Type)),"|");
    
    if (Event(Type))
    {
      Append(text,EnumToString(sr[0].Event),"|");
      Append(text,EnumToString(sma.Event),"|");
      Append(text,EnumToString(range.Event),"|");
      Append(text,EnumToString(line.Event),"|");

      Append(text,EventStr(),"|");
    }      

    return text;
  }