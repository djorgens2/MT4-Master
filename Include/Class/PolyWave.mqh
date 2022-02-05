//+------------------------------------------------------------------+
//|                                                     PolyWave.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
class PolyWave : public PolyRegression
  {
private:

public:
                     PolyWave();
                    ~PolyWave();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PolyWave::PolyWave()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PolyWave::~PolyWave()
  {
  }
//+------------------------------------------------------------------+

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

     //--- Action States
     enum       ActionState
                {
                  Bank,         //--- Profit management slider
                  Goal,         //--- Out-of-Band indcator
                  Yield,        //--- line of the last hard crest or trough
                  Go,           //--- Where it started, the first OOB line
                  Build,        //--- Pulback/Rally box - manage risk/increase volume
                  Risk,         //--- Intermediate support/resistance levels - cover or balance
                  Opportunity,  //--- First entry reversal alert
                  Chance,       //--- Recovery management slider
                  Mercy,        //--- retained prior intial breakout point, for "mercy" rallies/pullbacks
                  Stop,         //--- main support/resistance boundary;
                  Quit,         //--- Forward contrarian progress line; if inbounds, manage risk; oob - kill;
                  Kill,         //--- Risk Management slider
                  Keep          //--- When nothing statistically viable occurs
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
                  double          Retrace;
                  int             Count;
                  bool            IsOpen;
                };

     //--- Crest/Trough analytics
     struct     WaveRec
                {
                  ReservedWords   State;
                  int             Action;
                  ActionState     ActionState[2];
                  WaveSegment     Active[2];
                  WaveSegment     Crest;
                  WaveSegment     Trough;
                  WaveSegment     Decay;           //-- Manage Non-Oscillatory Decay
                  int             CrestTotal;
                  int             TroughTotal;
                  bool            Breakout;
                  bool            Reversal;
                  bool            Retrace;
                  bool            Bank;
                  bool            Kill;
                };

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
       
       void             DrawWaveOverlays(void);
       ReservedWords    PolyState(void) { return(prPolyState); }
       ActionState      ActionState(const int Action) {return (prWave.ActionState[Action]); }
       double           ActionLine(const int Action, const ActionState Line) {return (prLine[Action][Line]); }
       
       //--- Wave methods
       bool             SegmentIsOpen(void) {return (prWave.Crest.IsOpen||prWave.Trough.IsOpen); }
       WaveRec          Wave(void) { return(prWave); }
       WaveSegment      WaveSegment(const int Segment);
       WaveSegment      ActiveWave(void) {return (prWave.Active[prWave.Action]); }
       WaveSegment      ActiveSegment(void);
       ReservedWords    WaveState(void) {return (prWave.State); } 

    virtual
       int              Direction(int Direction, bool Contrarian=false);
     
protected:

       //--- Protected methods
    virtual
       void             CalcMA(void);
       void             CalcWave(void);
       ReservedWords    CalcWaveState(void);
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
       
       bool             NewState(ReservedWords &State, ReservedWords ChangeState, bool Update=true);
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

       //--- private methods
       void             CalcPolyState(void);
       void             CalcPoly(void);
       void             CalcLines(const int Action, const bool Contrarian=false);
       void             CalcActionState(const int Action);
       
       //--- Wave methods
       void             OpenWave(WaveSegment &Segment);
       void             CloseWave(WaveSegment &Segment, int Action=NoValue);
       void             UpdateWave(WaveSegment &Segment);

       void             InitWaveSegment(WaveSegment &Segment);
       void             OpenDecaySegment(WaveSegment &Segment);
       void             InitWave(void);
       
       
       //--- Event Array
       CEvent          *prEvents;    //--- Event array

       WaveRec          prWave;
       WaveSegment      prLastSegment;
       double           prLine[2][Keep];
       
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
//| CalcWaveState - Calculates the state of wave                     |
//+------------------------------------------------------------------+
ReservedWords CPolyRegression::CalcWaveState(void)
  {
    if (prWave.Action==OP_BUY)
    {
      switch (ActiveWave().Type)
      {
        case Decay:    return (prWave.State);
        
        case Trough:   if (IsLower(Close[0],ActiveWave().Open,NoUpdate))
                         return (Reversal);

                       if (IsLower(Close[0],ActiveSegment().Open,NoUpdate))
                         return (Retrace);

                       return (Rally);

        case Crest:    //--- Handle straight line reversal into breakout on the tick
                       if (prWave.Reversal)
                         if (IsHigher(Close[0],prWave.Active[OP_SELL].Open,NoUpdate))
                         {
                           prWave.Breakout      = true;
                           prWave.Reversal      = false;
                           prWave.Retrace       = false;
                         }

                       if (IsLower(Close[0],ActiveWave().Open,NoUpdate))
                         return (Reversal);

                       if (IsHigher(Close[0],ActiveWave().High,NoUpdate))
                         if (prWave.Reversal)
                           return (Reversal);
                         else
                           return (Breakout);

                       if (prWave.Retrace)
                       {
                         if (IsLower(Close[0],ActiveWave().Low,NoUpdate))
                           return (Reversal);

                         if (IsLower(Close[0],ActiveSegment().Open,NoUpdate))
                           return (Pullback);

                         return (Recovery);
                       }

                       if (IsLower(Close[0],ActiveSegment().Open,NoUpdate))
                         return (Pullback);

                       if (prWave.Reversal)
                         return (Reversal);

                       return (Breakout);      
      }
    }

    if (prWave.Action==OP_SELL)
    {
      switch (ActiveWave().Type)
      {
        case Decay:    return (prWave.State);
      
        case Crest:    if (IsHigher(Close[0],ActiveWave().Open,NoUpdate))
                         return (Reversal);

                       if (IsHigher(Close[0],ActiveSegment().Open,NoUpdate))
                         return (Retrace);

                       return (Pullback);

        case Trough:   //--- Handle straight line reversal into breakout on the tick
                      if (prWave.Reversal)
                        if (IsLower(Close[0],prWave.Active[OP_BUY].Open,NoUpdate))
                        {
                          prWave.Breakout      = true;
                          prWave.Reversal      = false;
                          prWave.Retrace       = false;
                        }

                      if (IsHigher(Close[0],ActiveWave().Open,NoUpdate))
                        return (Reversal);

                      if (IsLower(Close[0],ActiveWave().Low,NoUpdate))
                        if (prWave.Reversal)
                          return (Reversal);
                        else
                          return (Breakout);

                      if (prWave.Retrace)
                      {
                        if (IsHigher(Close[0],ActiveWave().High,NoUpdate))
                          return (Reversal);

                        if (IsHigher(Close[0],ActiveSegment().Open,NoUpdate))
                          return (Rally);

                        return (Recovery);
                      }

                      if (IsHigher(Close[0],ActiveSegment().Open,NoUpdate))
                        return (Rally);

                      if (prWave.Reversal)
                        return (Reversal);

                      return (Breakout);
      }
    }

    return (NoState);
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
    Segment.Retrace          = Close[0];
    Segment.Count            = 0;
    Segment.IsOpen           = false;
  }

//+------------------------------------------------------------------+
//| InitWave - Initializes wave properties on first use              |
//+------------------------------------------------------------------+
void CPolyRegression::InitWave(void)
  {
    prWave.Action                    = NoValue;

    InitWaveSegment(prWave.Active[OP_BUY]);
    InitWaveSegment(prWave.Active[OP_SELL]);
    InitWaveSegment(prWave.Crest);
    InitWaveSegment(prWave.Trough);
    InitWaveSegment(prLastSegment);    

    prWave.CrestTotal                 = 0;
    prWave.TroughTotal                = 0;

    prWave.Crest.Type                 = Crest;
    prWave.Trough.Type                = Trough;
    prLastSegment.Type                = Default;
    
    prWave.Active[OP_BUY].Direction   = DirectionUp;
    prWave.Active[OP_SELL].Direction  = DirectionDown;
  }

//+------------------------------------------------------------------+
//| OpenDecaySegment - Initializes non-oscillation wave segment      |
//+------------------------------------------------------------------+
void CPolyRegression::OpenDecaySegment(WaveSegment &Segment)
  {
    if (!SegmentIsOpen())
    {
      prLastSegment                    = Segment;
      prWave.Decay.Count++;

      prWave.Decay                     = Segment;
      prWave.Decay.Type                = Decay;
      prWave.Decay.Retrace             = Close[0];
      prWave.Decay.IsOpen              = true;
      
      if (prWave.Decay.Direction==DirectionUp)
        prWave.Decay.Open              = prWave.Decay.Low;
      
      if (prWave.Decay.Direction==DirectionDown)
        prWave.Decay.Open              = prWave.Decay.High;
        
      SetEvent(NewWaveOpen);
    }
  }

//+------------------------------------------------------------------+
//| CloseWave - Closes the completed wave segment and updates state  |
//+------------------------------------------------------------------+
void CPolyRegression::CloseWave(WaveSegment &Segment, int Action=NoValue)
  {
    if (Segment.Type==Crest)
      if (Segment.Direction==DirectionUp)
        Action                         = OP_BUY;
      
    if (Segment.Type==Trough)
      if (Segment.Direction==DirectionDown)
        Action                         = OP_SELL;

    if (Action==NoValue)
    {
      //-- Manage rally/pullback; non-critical interior trading range
      if (prWave.Action==OP_BUY)
      {
        if (IsHigher(Segment.High,prWave.Active[OP_BUY].High))
          prWave.Breakout              = true;
        else
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
        if (IsLower(Segment.Low,prWave.Active[OP_SELL].Low))
          prWave.Breakout              = true;
        else
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
      prWave.Active[OP_BUY].IsOpen    = false;
      prWave.Active[OP_SELL].IsOpen   = false;
      prWave.Active[Action].IsOpen    = true;
    
      //-- New Action Manager Assignment
      SetEvent(NewWaveReversal);

      prWave.Active[OP_BUY].Count     = 0;
      prWave.Active[OP_SELL].Count    = 0;

      prWave.CrestTotal               = 0;
      prWave.TroughTotal              = 0;
      
      prWave.Decay.Count              = 0;
      prWave.Crest.Count              = 0;
      prWave.Trough.Count             = 0;
      
      if (prWave.Action==OP_BUY)
      {
        prWave.Active[OP_SELL].Low     = fmin(prWave.Active[OP_SELL].Low,Segment.Low);
        
        prWave.Active[OP_BUY].Open     = prWave.Active[OP_SELL].Low;
        prWave.Active[OP_BUY].High     = Segment.High;
        prWave.Active[OP_BUY].Low      = prWave.Active[OP_SELL].Low;
        prWave.Active[OP_BUY].Close    = Segment.Low;
        
        prWave.Active[OP_BUY].Count++;
        
        prWave.CrestTotal++;
        prWave.Crest.Count++;
      }

      if (prWave.Action==OP_SELL)
      {
        prWave.Active[OP_BUY].High     = fmax(prWave.Active[OP_BUY].High,Segment.High);

        prWave.Active[OP_SELL].Open    = prWave.Active[OP_BUY].High;
        prWave.Active[OP_SELL].High    = prWave.Active[OP_BUY].High;
        prWave.Active[OP_SELL].Low     = Segment.Low;
        prWave.Active[OP_SELL].Close   = Segment.High;

        prWave.Active[OP_SELL].Count++;
        
        prWave.TroughTotal++;
        prWave.Trough.Count++;
      }

      prWave.Active[Action].Type       = Segment.Type;
      prWave.Reversal                  = true;
      prWave.Retrace                   = false;
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

    if (IsChanged(Segment.IsOpen,false))
      //-- Prime the decay record
      OpenDecaySegment(Segment);
  
    else
      if (Action==NoValue)
      {
        //--- Axiom: It is highly improbable for a poly line to move crest to trough on a single tick
        //---        or vice-versa without first having passed through a pullback/rally state; This
        //---        condition may occur in an excessively volatile market; requires analysis -- Kill Switch?
        Print ("Axiom violation: Close executed on a previously closed wave segment");
        return;
      }

    SetEvent(NewWaveClose);
  }

//+------------------------------------------------------------------+
//| OpenWave - Starts a new wave segment                             |
//+------------------------------------------------------------------+
void CPolyRegression::OpenWave(WaveSegment &Segment)
  {
    if (IsChanged(prWave.Decay.IsOpen,false))
    {
      //=== Feathering opportunity?
    
    }
  
    InitWaveSegment(Segment);

    if (IsChanged(prLastSegment.Type,Segment.Type,NoUpdate))
    {
      prWave.Crest.Count                 = 0;
      prWave.Trough.Count                = 0;
    }
    else
      Segment.Count                      = prLastSegment.Count;

    if (Event(NewWaveReversal))
    {
      prWave.CrestTotal                  = 0;
      prWave.TroughTotal                 = 0;
      prWave.Active[prWave.Action].Count = 0;
    }

    if (Segment.Type==Crest)
      prWave.CrestTotal++;
      
    if (Segment.Type==Trough)
      prWave.TroughTotal++;

    prWave.Active[prWave.Action].Count++;
    prWave.Active[prWave.Action].Type    = Segment.Type;
    
    Segment.IsOpen                       = true;
    Segment.Count++;    

    SetEvent(NewWaveOpen);
  }

//+------------------------------------------------------------------+
//| UpdateWave - Updates wave data and state                         |
//+------------------------------------------------------------------+
void CPolyRegression::UpdateWave(WaveSegment &Segment)
  {
    //-- Update Crest Bounds and Retrace
    if (Segment.Type==Crest)
      if (IsHigher(Close[0],Segment.High))
        Segment.Retrace            = Close[0];
      else
      {
        Segment.Retrace            = fmin(Close[0],Segment.Retrace);
        Segment.Low                = fmin(Close[0],Segment.Low);
      }

    //-- Update Trough Bounds and Retrace              
    if (Segment.Type==Trough)
      if (IsLower(Close[0],Segment.Low))
        Segment.Retrace            = Close[0];
      else
      {
        Segment.Retrace            = fmax(Close[0],Segment.Retrace);
        Segment.High               = fmax(Close[0],Segment.High);
      }

    //-- Update Crest Decay Bounds, State and Retrace
    if (prLastSegment.Type==Crest)
      if (IsHigher(Close[0],prWave.Decay.High))
        prWave.Decay.Retrace       = Close[0];
      else
      {
        prWave.Decay.Retrace       = fmin(Close[0],prWave.Decay.Retrace);
        prWave.Decay.Low           = fmin(Close[0],prWave.Decay.Low);
      }      
    
    //-- Update Trough Decay Bounds, State and Retrace
    if (prLastSegment.Type==Trough)
      if (IsLower(Close[0],prWave.Decay.Low))
          prWave.Decay.Retrace     = Close[0];
      else
      {
        prWave.Decay.Retrace       = fmax(Close[0],prWave.Decay.Retrace);
        prWave.Decay.High          = fmax(Close[0],prWave.Decay.High);        
      }
    
    if (IsLower(Close[0],Segment.Open,NoUpdate))
      Segment.Direction            = DirectionDown;
      
    if (IsHigher(Close[0],Segment.Open,NoUpdate))
      Segment.Direction            = DirectionUp;

   if (IsHigher(Close[0],prWave.Active[OP_BUY].High,NoUpdate))
     if (Event(NewHigh))
       prWave.Active[OP_BUY].Retrace  = Close[0];

   if (IsLower(Close[0],prWave.Active[OP_SELL].Low,NoUpdate))
     if (Event(NewLow))
       prWave.Active[OP_SELL].Retrace  = Close[0];

    prWave.Active[OP_BUY].Retrace  = fmin(prWave.Active[OP_BUY].Retrace,Close[0]);
    prWave.Active[OP_SELL].Retrace = fmax(prWave.Active[OP_SELL].Retrace,Close[0]);;


    Segment.Close                  = Close[0];
  }

//+------------------------------------------------------------------+
//| CalcLines - Calculates price boundaries for the supplied action  |
//+------------------------------------------------------------------+
void CPolyRegression::CalcLines(const int Action, const bool Contrarian=false)
  {
    if (Contrarian)
    {
      switch (Action)
      {
        case OP_BUY:      prLine[Action][Go]           = prWave.Active[OP_SELL].Open;
                          prLine[Action][Opportunity]  = prWave.Active[OP_SELL].Close;
                          prLine[Action][Quit]         = prWave.Trough.Low;
                          prLine[Action][Mercy]        = fdiv(prLine[OP_BUY][Quit]+prLine[OP_BUY][Go],2,Digits);
                          prLine[Action][Kill]         = fdiv(prLine[Action][Opportunity]+prWave.Active[OP_BUY].Retrace,2,Digits);
                          prLine[OP_SELL][Risk]        = fmin(prWave.Active[OP_SELL].High,prLine[OP_SELL][Risk]);
                          break;

        case OP_SELL:     prLine[Action][Go]           = prWave.Active[OP_BUY].Open;
                          prLine[Action][Opportunity]  = prWave.Active[OP_BUY].Close;
                          prLine[Action][Quit]         = prWave.Crest.High;
                          prLine[Action][Mercy]        = fdiv(prLine[OP_SELL][Quit]+prLine[OP_SELL][Go],2,Digits);
                          prLine[Action][Kill]         = fdiv(prLine[Action][Opportunity]+prWave.Active[OP_SELL].Retrace,2,Digits);
                          prLine[OP_BUY][Risk]         = fmax(prLine[OP_BUY][Risk],prWave.Active[OP_BUY].Low);
                          break;
      }
      
      prLine[Action][Build]                            = prLine[Action][Opportunity];
    }
    else
      switch (Action)
      {
        case OP_BUY:      prLine[Action][Goal]         = prWave.Active[OP_BUY].High;
                          prLine[Action][Stop]         = prWave.Active[OP_BUY].Open;
                          prLine[Action][Yield]        = prWave.Active[OP_BUY].Close;
                          prLine[Action][Build]        = fmax(prLine[OP_BUY][Build],fdiv(prWave.Active[OP_SELL].Close+prWave.Active[OP_BUY].Low,2));
                          prLine[Action][Bank]         = fmax(prLine[OP_BUY][Yield],fdiv(prWave.Active[OP_SELL].Retrace+prLine[OP_BUY][Yield],2));

                          if (Event(NewWaveReversal))
                          {
                            prLine[OP_SELL][Chance]    = prLine[OP_SELL][Risk];
                            prLine[OP_BUY][Risk]       = prWave.Active[OP_SELL].Low;
                          }
                          break;

        case OP_SELL:     prLine[Action][Goal]         = prWave.Active[OP_SELL].Low;
                          prLine[Action][Stop]         = prWave.Active[OP_SELL].Open;
                          prLine[Action][Yield]        = prWave.Active[OP_SELL].Close;
                          prLine[Action][Build]        = fmin(prLine[OP_SELL][Build],fdiv(prWave.Active[OP_BUY].Close+prWave.Active[OP_SELL].High,2));
                          prLine[Action][Bank]         = fmin(prLine[OP_SELL][Yield],fdiv(prWave.Active[OP_BUY].Retrace+prLine[OP_SELL][Yield],2));

                          if (Event(NewWaveReversal))
                          {
                            prLine[OP_BUY][Chance]     = prLine[OP_BUY][Risk];
                            prLine[OP_SELL][Risk]      = prWave.Active[OP_BUY].High;
                          }
                          break;
      }      
  }

//+------------------------------------------------------------------+
//| CalcActionState - Calculates the state for a specific action     |
//+------------------------------------------------------------------+
void CPolyRegression::CalcActionState(const int Action)
  {
    ActionState casActionState   = prWave.ActionState[Action];
    
    if (Event(NewWaveClose))
      if (Action==prWave.Action)
        CalcLines(Action);
      else
        CalcLines(Action,InContrarian);

    //--- Handle Non-Contrarian States
    if (Action==prWave.Action)
    {
      //--- Interior states
      if (IsBetween(Close[0],prLine[Action][Stop],prLine[Action][Goal]))
      {
        //--- Reset profit flag
        prWave.Bank                              = false;
        
        //--- Hold Line -- the decision box ("pivot box" or "pivot range")
        if (prWave.ActionState[Action]==Keep)
        {
          if (Action==OP_BUY)
          {
            if (IsLower(Close[0],prLine[OP_BUY][Risk],NoUpdate))
              prWave.ActionState[OP_BUY]         = Risk;

            if (IsHigher(Close[0],prLine[OP_BUY][Build],NoUpdate))
              prWave.ActionState[OP_BUY]         = Build;
          }
              
          if (Action==OP_SELL)
          {
            if (IsHigher(Close[0],prLine[OP_SELL][Risk],NoUpdate))
              prWave.ActionState[OP_SELL]         = Risk;

            if (IsLower(Close[0],prLine[OP_SELL][Build],NoUpdate))
              prWave.ActionState[OP_SELL]         = Build;
          }
        }

        //--- Yield Line
        if (prWave.ActionState[Action]==Yield)
        {
          if (Action==OP_BUY)
            if (IsLower(Close[0],prLine[OP_BUY][Risk],NoUpdate))
              prWave.ActionState[OP_BUY]         = Risk;
            else
            if (IsLower(Close[0],prLine[OP_BUY][Build],NoUpdate))
              prWave.ActionState[OP_BUY]         = Keep;
            else
            if (ActiveSegment().Type==Trough)
              prWave.ActionState[OP_BUY]         = Build;
              
          if (Action==OP_SELL)
            if (IsHigher(Close[0],prLine[OP_SELL][Risk],NoUpdate))
              prWave.ActionState[OP_SELL]        = Risk;
            else
            if (IsHigher(Close[0],prLine[OP_SELL][Build],NoUpdate))
              prWave.ActionState[OP_SELL]        = Keep;
            else
            if (ActiveSegment().Type==Crest)
              prWave.ActionState[OP_SELL]        = Build;
        }

        //--- Goal Line
        if (prWave.ActionState[Action]==Goal)
        {
          if (Action==OP_BUY)
            if (IsLower(Close[0],prLine[OP_BUY][Bank],NoUpdate))
              prWave.ActionState[OP_BUY]         = Yield;
              
          if (Action==OP_SELL)
            if (IsHigher(Close[0],prLine[OP_SELL][Bank],NoUpdate))
              prWave.ActionState[OP_SELL]        = Yield;
        }
      }
      else

      //--- Out-of-Bounds states
      if (Action==OP_BUY)
        if (IsHigher(Close[0],prLine[OP_BUY][Goal],NoUpdate))
        {
          prWave.ActionState[OP_BUY]             = Goal;
          prWave.Bank                            = true;
        }
        else
        {
          prWave.ActionState[OP_BUY]             = Quit;  //--- Happens either in tight quarters or volatile snaps
          prWave.Kill                            = true;
        }
      else
      if (Action==OP_SELL)
        if (IsLower(Close[0],prLine[OP_SELL][Goal],NoUpdate))
        {
          prWave.ActionState[OP_SELL]            = Goal;
          prWave.Bank                            = true;
        }
        else
        {
          prWave.ActionState[OP_SELL]            = Quit;  //--- Happens either in tight quarters or volatile snaps
          prWave.Kill                            = true;
        }
    }
    else
    
    //--- Handle Contrarian States
    {
      //--- Interior states
      if (IsBetween(Close[0],prLine[Action][Go],prLine[Action][Quit]))
      {
        //--- Reset profit flag
        if (prWave.ActionState[Action]==Opportunity)
        {
          if (Action==OP_BUY)
            if (IsLower(Close[0],prLine[OP_BUY][Kill],NoUpdate))
              prWave.ActionState[OP_BUY]         = Quit;

          if (Action==OP_SELL)
            if (IsHigher(Close[0],prLine[OP_SELL][Kill],NoUpdate))
              prWave.ActionState[OP_SELL]        = Quit;
        }
        else
        {
          if (Action==OP_BUY)
            if (IsHigher(Close[0],prLine[OP_BUY][Opportunity],NoUpdate))
              if (IsChanged(prWave.Kill,false))
                prWave.ActionState[OP_BUY]       = Opportunity;
              else
                prWave.ActionState[OP_BUY]       = Build;

            
          if (Action==OP_SELL)
            if (IsLower(Close[0],prLine[OP_SELL][Opportunity],NoUpdate))
              if (IsChanged(prWave.Kill,false))
                prWave.ActionState[OP_SELL]      = Opportunity;
              else
                prWave.ActionState[OP_SELL]      = Build;
         } 
      }
      else

      //--- Out-of-Bounds states
      if (Action==OP_BUY)
        if (IsHigher(Close[0],prLine[OP_BUY][Go],NoUpdate))
        {
          prWave.ActionState[OP_BUY]             = Goal;   //--- Happens either in tight quarters or volatile snaps
          prWave.Bank                            = true;
        }
        else
        {
          prWave.ActionState[OP_BUY]             = Quit;
          prWave.Kill                            = true;
        }
      else
      if (Action==OP_SELL)
        if (IsLower(Close[0],prLine[OP_SELL][Go],NoUpdate))
        {
          prWave.ActionState[OP_SELL]            = Goal;   //--- Happens either in tight quarters or volatile snaps
          prWave.Bank                            = true;
        }
        else
        {
          prWave.ActionState[OP_SELL]            = Quit;
          prWave.Kill                            = true;
        }
      }
      
    if (IsChanged(casActionState,prWave.ActionState[Action]))
      SetEvent(NewActionState);
  }

//+------------------------------------------------------------------+
//| CalcWave - Manages Crest/Trough analytics points                 |
//+------------------------------------------------------------------+
void CPolyRegression::CalcWave(void)
  {
    ClearEvent(NewWaveOpen);
    ClearEvent(NewWaveClose);
    ClearEvent(NewWaveState);
    ClearEvent(NewWaveReversal);
    ClearEvent(NewActionState);

    switch (prPolyState)
    {
      case Pullback:   if (Event(NewPolyState))
                         CloseWave(prWave.Crest);

                       UpdateWave(prWave.Decay);
                       break;
                       
      case Rally:      if (Event(NewPolyState))
                         CloseWave(prWave.Trough);

                       UpdateWave(prWave.Decay);
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

      case NoState:    if (Event(NewHigh)&&prWave.Action!=OP_BUY)
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
    
    if (IsChanged(prWave.State,CalcWaveState()))
      SetEvent(NewWaveState);
      
    CalcActionState(OP_BUY);
    CalcActionState(OP_SELL);
  }

//+------------------------------------------------------------------+
//| CalcPolyState - computes the current Poly state                  |
//+------------------------------------------------------------------+
void CPolyRegression::CalcPolyState(void)
  {
    ReservedWords cpState          = NoState;
    
    if (prPolyState==NoState)
    {
      if (SegmentIsOpen())
      {
        if (ActiveSegment().Type==Crest)
        {
          cpState                  = Crest;
          prPolyCrest              = true;
          
          if (Direction(Polyline)==DirectionDown)
            SetEvent(NewPoly);
        }        

        if (ActiveSegment().Type==Trough)
        {
          cpState                  = Trough;
          prPolyTrough             = true;
          
          if (Direction(Polyline)==DirectionUp)
            SetEvent(NewPoly);
        }
      }
      else
        //-- Axiom: Under no circumstances should the PolyState be initialized on a closed segment
        Print("Axiom violation: PolyState initialization occurred on a closed segment.");
    }

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
       case Deviation:  return (Pip(prPricePolyDev));
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

//+------------------------------------------------------------------+
//| ActiveSegment - Returns the active wave segment                  |
//+------------------------------------------------------------------+
WaveSegment CPolyRegression::ActiveSegment(void)
  {
     if (prWave.Crest.IsOpen)
       return (prWave.Crest);
       
     if (prWave.Trough.IsOpen)
       return (prWave.Trough);
       
     return (prWave.Decay);
  }

//+------------------------------------------------------------------+
//| WaveSegment - Returns the requested wave segment                 |
//+------------------------------------------------------------------+
WaveSegment CPolyRegression::WaveSegment(const int Segment)
  {
    switch (Segment)
    {
      case OP_BUY:
      case OP_SELL:     return (prWave.Active[Segment]);
      case Crest:       return (prWave.Crest);
      case Trough:      return (prWave.Trough);
      case Decay:       return (prWave.Decay);
      case Last:        return (prLastSegment);
    }       
    
    return (ActiveSegment());
  }

//+------------------------------------------------------------------+
//| DrawWaveOverlays - Paint Crest/Trough lines                      |
//+------------------------------------------------------------------+
void CPolyRegression::DrawWaveOverlays(void)
  {
    static int           dsBarIndex  = 0;
    static int           dsEventIdx  = 0;
    static int           dsHourIdx   = 0;
    static int           dsLastIdx   = 0;
    
    static ReservedWords dsState     = Default;
        
    if (Event(NewCrest)||Event(NewTrough))
    {
      dsHourIdx                      = TimeHour(Time[0]);
      dsBarIndex                     = 0;
      dsState                        = (ReservedWords)BoolToInt(Event(NewCrest),Crest,Trough);
      dsEventIdx++;
    }

    if (dsState==Crest||dsState==Trough)
    {
      if (IsChanged(dsHourIdx,TimeHour(Time[0])))
      {
        dsBarIndex++;
        dsEventIdx++;
      }
    
      if (IsChanged(dsLastIdx,dsEventIdx))
      {
      
        NewRay("tlHL"+EnumToString(dsState)+(string)dsEventIdx,false);
        NewRay("tlOC"+EnumToString(dsState)+(string)dsEventIdx,false);

        UpdateRay("tlHL"+EnumToString(dsState)+(string)dsEventIdx,Close[0],0,Close[0],0,STYLE_SOLID,BoolToInt(dsState==Crest,clrYellow,clrRed));
        UpdateRay("tlOC"+EnumToString(dsState)+(string)dsEventIdx,Close[0],0,Close[0],0,STYLE_SOLID,clrNONE);
      
        ObjectSet("tlHL"+EnumToString(dsState)+(string)dsEventIdx,OBJPROP_WIDTH,2);
        ObjectSet("tlOC"+EnumToString(dsState)+(string)dsEventIdx,OBJPROP_WIDTH,12);
        ObjectSet("tlOC"+EnumToString(dsState)+(string)dsEventIdx,OBJPROP_BACK,true);
      }

      for (int carry=dsBarIndex;carry>NoValue;carry--)
      {
        if (IsBetween(this.WaveSegment(dsState).Open,High[carry],Low[0]))
          ObjectSet("tlOC"+EnumToString(dsState)+(string)(dsEventIdx-carry),OBJPROP_PRICE1,this.WaveSegment(dsState).Open);

        if (IsBetween(Close[0],High[carry],Low[carry]))
          ObjectSet("tlOC"+EnumToString(dsState)+(string)(dsEventIdx-carry),OBJPROP_PRICE2,Close[0]);

        ObjectSet("tlOC"+EnumToString(dsState)+(string)(dsEventIdx-carry),OBJPROP_COLOR,DirColor(this.WaveSegment(dsState).Direction,clrForestGreen,clrMaroon));
        ObjectSet("tlHL"+EnumToString(dsState)+(string)(dsEventIdx-carry),OBJPROP_PRICE1,fmin(High[carry],this.WaveSegment(dsState).High));
        ObjectSet("tlHL"+EnumToString(dsState)+(string)(dsEventIdx-carry),OBJPROP_PRICE2,fmax(Low[carry],this.WaveSegment(dsState).Low));
      }
    }

    dsState                          = prPolyState;

  }

//+------------------------------------------------------------------+
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool IsChanged(ActionState &Compare, ActionState Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }
