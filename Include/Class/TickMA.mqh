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

    struct OHLCRec
           {
             int          Count;
             double       Open;
             double       High;
             double       Low;
             double       Close;
           };

    struct RangeRec
           {
             int          Direction;
             FractalState State;
             EventType    Event;
             double       High;
             double       Low;
           };

    struct PolyRec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             OHLCRec      Price[];
           };

    struct SMARec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             OHLCRec      Fast;
             OHLCRec      Slow;
           };

    struct SegmentRec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             OHLCRec      Price;
           };

    void             CalcSMA(OHLCRec &SMA, int Factor);

    void             NewTick();
    void             NewSegment(void);

    void             UpdateTick(void);
    void             UpdateSegment(void);
    void             UpdateRange(void);

    int              trPeriods;
    int              trDegree;
    int              trSMASlow;
    int              trSMAFast;
    double           trTickAgg;
    
    //-- Aggregation Structures
    OHLCRec          tr[];            //-- Tick Record
    SegmentRec       sr[];            //-- Segment Record
    SMARec           sma;             //-- SMA Record
    RangeRec         rr;              //-- Range Record

public:

    void             Update(void);

    OHLCRec          Tick(int Node)     { return(tr[Node]); };
    SegmentRec       Segment(int Node)  { return(sr[Node]); };
    RangeRec         Range(void)        { return(rr); };
    SMARec           SMA(void)          { return(sma); };

    int              Ticks(void)        { return(ArraySize(tr)); };
    int              Segments(void)     { return(ArraySize(sr)); };

                     CTickMA(int RegrPeriods, int RegrDegree, int SMA, double AggrTick);
                    ~CTickMA();

    //-- Format strings
    string           TickStr(int Count=0);
    string           TickHistoryStr(int Count=0);
    string           SegmentStr(int Node);
    string           SegmentHistoryStr(int Count=0);
    string           SegmentTickStr(int Node);
  };

//+------------------------------------------------------------------+
//| CalcSMA - Computes the SMA of an OHLC array                      |
//+------------------------------------------------------------------+
void CTickMA::CalcSMA(OHLCRec &SMA, int Factor)
  {
    OHLCRec smainit       = {0,0.00,0.00,0.00,0.00};
    
    SMA                   = smainit;
    
    if (Segments()<Factor)
      return;

    for (int node=0;node<fmin(Segments(),Factor);node++)
    {
      SMA.Open           += sr[node].Price.Open;
      SMA.High           += sr[node].Price.High;
      SMA.Low            += sr[node].Price.Low;
      SMA.Close          += sr[node].Price.Close;
    }

    SMA.Open              = fdiv(SMA.Open,Factor);
    SMA.High              = fdiv(SMA.High,Factor);
    SMA.Low               = fdiv(SMA.Low,Factor);
    SMA.Close             = fdiv(SMA.Close,Factor);
  }

//+------------------------------------------------------------------+
//| UpdateRange - Calc range bounds within regression Periods        |
//+------------------------------------------------------------------+
void CTickMA::UpdateRange(void)
  {
    double rangehigh      = Close[0];
    double rangelow       = Close[0];

    bool   testhigh       = false;
    bool   testlow        = false;

    if (Event(NewTick))
    {
      for (int node=0;node<fmin(ArraySize(sr),trPeriods);node++)
      {
        rangehigh         = fmax(rangehigh,sr[node].Price.High);
        rangelow          = fmin(rangelow,sr[node].Price.Low);
      }

      testhigh            = IsChanged(rr.High,rangehigh);
      testlow             = IsChanged(rr.Low,rangelow);
    }
    else
    {
      testhigh            = IsHigher(Close[0],rr.High);
      testlow             = IsLower(Close[0],rr.Low);
    }

    SetEvent(BoolToEvent(testhigh||testlow,NewRange),Major);
  }

//+------------------------------------------------------------------+
//| NewSegment - inserts a new 0-Base segment aggregation record     |
//+------------------------------------------------------------------+
void CTickMA::NewSegment(void)
  {
    #define TickHold   1

    ArrayResize(sr,ArraySize(sr)+1,32768);

    if (ArraySize(sr)>1)
      ArrayCopy(sr,sr,1,0,ArraySize(sr)-1);
    else
    {
      sr[0].Direction         = Direction(sr[0].Price.Close-sr[0].Price.Open);
      sr[0].Bias              = Action(sr[0].Direction,InDirection);
    }

    sr[0].Event               = BoolToEvent(IsEqual(sr[0].Direction,DirectionUp),NewRally,NewPullback);
    sr[0].Price               = tr[1];
    sr[0].Price.Open          = Close[0];
    sr[0].Price.Count         = 0;

    if (ArraySize(sr)>1)
    {
      if (IsEqual(sr[1].Price.Count,TickHold))
      {
        sr[0].Price.High      = fmax(sr[0].Price.High,sr[1].Price.High);
        sr[0].Price.Low       = fmin(sr[0].Price.Low,sr[1].Price.Low);
      }

      if (NewDirection(sr[1].Direction,Direction(sr[1].Price.Close-sr[1].Price.Open)))
        SetEvent(NewDirection);

      sr[0].Direction         = sr[1].Direction;
    }

    SetEvent(NewSegment,Nominal);
    SetEvent(sr[0].Event,Nominal);
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
    tr[0].Open                = Close[0];
    tr[0].High                = Close[0];
    tr[0].Low                 = Close[0];
    tr[0].Close               = Close[0];

    SetEvent(NewTick);
  }

//+------------------------------------------------------------------+
//| UpdateSegment - Calc segment bounds and update segment history   |
//+------------------------------------------------------------------+
void CTickMA::UpdateSegment(void)
  {
    static int direction        = DirectionChange;

    if (Event(NewTick))
    {
      if (NewDirection(direction,Direction(tr[1].Close-tr[1].Open)))
        NewSegment();

      sr[0].Price.Count++;
    }

    if (ArraySize(sr)>0)
    {
      if (IsHigher(Close[0],sr[0].Price.High))
        SetEvent(NewHigh,Nominal);

      if (IsLower(Close[0],sr[0].Price.Low))
        SetEvent(NewLow,Nominal);
      
      sr[0].Price.Close         = Close[0];

//      if (Event(NewTick)||Event(NewHigh)||Event(NewLow))
//      {
//      }
//
      SetEvent(BoolToEvent(NewAction(sr[0].Bias,Action(Direction(sr[0].Price.Close-sr[0].Price.Open),InDirection)),NewBias),Nominal);
    }
        CalcSMA(sma.Fast,trSMAFast);
        CalcSMA(sma.Slow,trSMASlow);

  }

//+------------------------------------------------------------------+
//| UpdateTick - Calc tick bounds and update tick history            |
//+------------------------------------------------------------------+
void CTickMA::UpdateTick(void)
  {
    if (fabs(tr[0].Open-Close[0])>=trTickAgg)
      NewTick();

    if (IsHigher(Close[0],tr[0].High))
      SetEvent(NewHigh,Notify);

    if (IsLower(Close[0],tr[0].Low))
      SetEvent(NewLow,Notify);

    tr[0].Close          = Close[0];
    tr[0].Count++;
  }

//+------------------------------------------------------------------+
//| TickMA Class Constructor                                         |
//+------------------------------------------------------------------+
CTickMA::CTickMA(int RegrPeriods, int RegrDegree, int SMA, double AggrTick)
  {
    trPeriods               = RegrPeriods;
    trDegree                = RegrDegree;
    trSMASlow               = SMA;
    trSMAFast               = SMA-1;
    trTickAgg               = point(AggrTick);

    NewTick();
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
    int    count = fmin(Count,ArraySize(sr));

    if (ArraySize(sr)>Node)
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