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
             ptOpen,
             ptHigh,
             ptLow,
             ptClose,
             PriceTypes
           };

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
             double       Mean;
             double       Retrace;
           };

    struct RegressionRec
           {
             int          Direction;
             int          Bias;
             EventType    Event;
             double       Open[];
             double       High;
             double       Low;
             double       Close[];
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
    void             CalcPoly(double &Poly[], PriceType Type);
    void             CalcLine(double &Source[], double &Target[]);

    void             NewTick();
    void             NewSegment(void);

    void             UpdateTick(void);
    void             UpdateSegment(void);
    void             UpdateRange(void);
    void             UpdatePoly(void);
    void             UpdateLine(void);

    int              trPeriods;
    int              trDegree;
    int              trSMASlow;
    int              trSMAFast;
    double           trTickAgg;
    
    //-- Aggregation Structures
    OHLCRec          tr[];          //-- Tick Record
    SegmentRec       sr[];          //-- Segment Record
    RangeRec         range;         //-- Range Record
    SMARec           sma;           //-- SMA Record
    RegressionRec    poly;          //-- Poly Regr Record
    RegressionRec    line;          //-- Linear Regr Record


public:

    void             Update(void);

    OHLCRec          Tick(int Node)     { return(tr[Node]); };
    SegmentRec       Segment(int Node)  { return(sr[Node]); };
    RangeRec         Range(void)        { return(range); };
    SMARec           SMA(void)          { return(sma); };
    RegressionRec    Poly(void)         { return(poly); };
    RegressionRec    Line(void)         { return(line); };

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
    string           PolyStr(void);
    string           RangeStr(void);
  };

//+------------------------------------------------------------------+
//| CalcSMA - Computes the SMA of an OHLC array                      |
//+------------------------------------------------------------------+
void CTickMA::CalcSMA(OHLCRec &SMA, int Factor)
  {
    OHLCRec smainit       = {0,0.00,0.00,0.00,0.00};
    
    SMA                   = smainit;
    
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

    sx[1]  = trPeriods+1;
    nn     = trDegree+1;

    //----------------------sx-------------
    for(mi=1;mi<=nn*2-2;mi++)
    {
      sum=0;

      for(n=0;n<=trPeriods;n++)
        sum+=pow(n,mi);

      sx[mi+1]=sum;
    }

    //----------------------syx-----------
    ArrayInitialize(b,0.00);

    for(mi=1;mi<=nn;mi++)
    {
      sum=0.00000;

      for(n=0;n<=trPeriods;n++)
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

    for(n=0;n<=trPeriods-1;n++)
    {
      sum=0;

      for(kk=1;kk<=trDegree;kk++)
        sum+=x[kk+1]*pow(n,kk);

      Poly[n]=x[1]+sum;
    }
  }

//+------------------------------------------------------------------+
//| CalcLine - Calculate Linear Regression                           |
//+------------------------------------------------------------------+
void CTickMA::CalcLine(double &Source[], double &Target[])
  {
    //--- Linear regression line
    double m[5]           = {0.00,0.00,0.00,0.00,0.00};   //--- slope
    double b              = 0.00;                         //--- y-intercept

    double sumx           = 0.00;
    double sumy           = 0.00;
    
    for (int idx=0;idx<trPeriods;idx++)
    {
      sumx += idx+1;
      sumy += Source[idx];
      
      m[1] += (idx+1)*Source[idx];            // Exy
      m[3] += pow(idx+1,2);                   // E(x^2)
    }
    
    m[2]    = fdiv(sumx*sumy,trPeriods);     // (Ex*Ey)/n
    m[4]    = fdiv(pow(sumx,2),trPeriods);   // [(Ex)^2]/n
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy-m[0]*sumx)/trPeriods;

    for (int idx=0;idx<trPeriods;idx++)
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
    tr[0].Open                = Close[0];
    tr[0].High                = Close[0];
    tr[0].Low                 = Close[0];
    tr[0].Close               = Close[0];

    SetEvent(NewTick);
  }

//+------------------------------------------------------------------+
//| NewSegment - inserts a new 0-Base segment aggregation record     |
//+------------------------------------------------------------------+
void CTickMA::NewSegment(void)
  {
    #define TickHold   1

    ArrayResize(sr,ArraySize(sr)+1,32768);
    ArrayCopy(sr,sr,1,0,ArraySize(sr)-1);

    sr[0].Direction           = Direction(sr[0].Price.Close-sr[0].Price.Open);
    sr[0].Bias                = Action(sr[0].Direction,InDirection);
    sr[0].Event               = BoolToEvent(IsEqual(sr[0].Direction,DirectionUp),NewRally,NewPullback);
    sr[0].Price               = tr[1];
    sr[0].Price.Open          = Close[0];
    sr[0].Price.Count         = 0;

    if (IsEqual(sr[1].Price.Count,TickHold))
    {
      sr[0].Price.High      = fmax(sr[0].Price.High,sr[1].Price.High);
      sr[0].Price.Low       = fmin(sr[0].Price.Low,sr[1].Price.Low);
    }

    if (NewDirection(sr[1].Direction,sr[0].Direction))
      SetEvent(NewDirection);

    SetEvent(NewSegment,Nominal);
    SetEvent(sr[0].Event,Nominal);
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

    if (IsHigher(Close[0],sr[0].Price.High))
      SetEvent(NewHigh,Nominal);

    if (IsLower(Close[0],sr[0].Price.Low))
      SetEvent(NewLow,Nominal);
      
    sr[0].Price.Close         = Close[0];

    CalcSMA(sma.Fast,trSMAFast);
    CalcSMA(sma.Slow,trSMASlow);
    
    SetEvent(BoolToEvent(NewAction(sr[0].Bias,Action(Direction(sr[0].Price.Close-sr[0].Price.Open),InDirection)),NewBias),Nominal);
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
//| UpdateRange - Calc range bounds within regression Periods        |
//+------------------------------------------------------------------+
void CTickMA::UpdateRange(void)
  {
    double rangehigh      = Close[0];
    double rangelow       = Close[0];

    range.Event           = NoEvent;

    if (IsHigher(Close[0],range.High))
      range.Event         = NewExpansion;
    else
    if (IsLower(Close[0],range.Low))
      range.Event         = NewExpansion;
    else
    if (Event(NewTick))
    {
      for (int node=0;node<fmin(ArraySize(sr),trPeriods);node++)
      {
        rangehigh         = fmax(rangehigh,sr[node].Price.High);
        rangelow          = fmin(rangelow,sr[node].Price.Low);
      }

      if (IsChanged(range.High,rangehigh))
        range.Event       = NewContraction;

      if (IsChanged(range.Low,rangelow))
        range.Event       = NewContraction;
    }

    if (IsEqual(range.Event,NewExpansion))
    {
      if (NewDirection(range.Direction,BoolToInt(Event(NewHigh),DirectionUp,DirectionDown)))
        SetEvent(BoolToEvent(IsChanged(range.State,Reversal),NewReversal));

      if (IsEqual(range.State,Retrace))
        SetEvent(BoolToEvent(IsChanged(range.State,Breakout),NewBreakout));

      range.Retrace       = Close[0];
      range.Mean          = fdiv(range.High+range.Low,2);
    }
    else
    {
      range.Retrace       = BoolToDouble(IsEqual(range.Direction,DirectionUp),
                              fmin(Close[0],range.Retrace),
                              fmax(Close[0],range.Retrace));
      range.Mean          = fdiv(range.High+range.Low,2);

      if (IsChanged(range.State,(FractalState)BoolToInt(IsEqual(range.Direction,Direction(range.Retrace-range.Mean)),range.State,Retrace)))
        range.Event       = NewRetrace;
    }

    SetEvent(range.Event,Major);
  }

//+------------------------------------------------------------------+
//| UpdateLinear - Calc linear regression from Poly Regression       |
//+------------------------------------------------------------------+
void CTickMA::UpdateLine(void)
  {
    CalcLine(poly.Open,line.Open);
    CalcLine(poly.Close,line.Close);
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
//| TickMA Class Constructor                                         |
//+------------------------------------------------------------------+
CTickMA::CTickMA(int RegrPeriods, int RegrDegree, int SMA, double AggrTick)
  {
    trPeriods               = RegrPeriods;
    trDegree                = RegrDegree;
    trSMASlow               = SMA;
    trSMAFast               = SMA-1;
    trTickAgg               = point(AggrTick);

    ArrayResize(sr,trPeriods+trDegree);

    ArrayResize(poly.Open,trPeriods);
    ArrayResize(poly.Close,trPeriods);
    
    ArrayResize(line.Open,trPeriods);
    ArrayResize(line.Close,trPeriods);

    //-- Preload Segments (Initialize)
    for (int node=0;node<trPeriods+trDegree;node++)
    {
      sr[node].Price.Open      = Open[node];
      sr[node].Price.High      = High[node];
      sr[node].Price.Low       = Low[node];
      sr[node].Price.Close     = Close[node];
    }
    
    //-- Preload Range (Initialize)
    range.Direction            = Direction(iLowest(Symbol(),Period(),MODE_LOW,trPeriods)-
                                           iHighest(Symbol(),Period(),MODE_HIGH,trPeriods));
    range.High                 = High[iHighest(Symbol(),Period(),MODE_HIGH,trPeriods)];
    range.Low                  = Low[iLowest(Symbol(),Period(),MODE_LOW,trPeriods)];
    range.Mean                 = fdiv(range.High+range.Low,2);
    range.Retrace              = BoolToDouble(IsEqual(range.Direction,DirectionUp),
                                    Low[iLowest(Symbol(),Period(),MODE_LOW,iHighest(Symbol(),Period(),MODE_HIGH,trPeriods))],
                                    High[iHighest(Symbol(),Period(),MODE_HIGH,iLowest(Symbol(),Period(),MODE_LOW,trPeriods))]);
    range.State                = (FractalState)BoolToInt(IsEqual(range.Direction,Direction(range.Retrace-range.Mean)),Breakout,Retrace);
    
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
    UpdatePoly();
    UpdateLine();
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

    if (Segments()>Node)
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

    for (int node=0;node<trPeriods;node++)
    {
      Append(textopen,DoubleToStr(poly.Open[node],Digits),"|");
      Append(textclose,DoubleToStr(poly.Close[node],Digits),"|");
    }

    Append(text,textopen,"\n");
    Append(text,textclose,"\n");
    
    return(text);
  }