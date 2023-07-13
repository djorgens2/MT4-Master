//+------------------------------------------------------------------+
//|                                                      Fractal.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

const double fibonacci[11] = {0.00,0.236,0.382,0.500,0.618,0.764,1.0,1.618,2.618,4.236,8.236};
const string tag[12] = {"(o)","(tr)","(tm)","(p)","(b)","(r)","(e)","(d)","(c)","(iv)","(cv)","(l)"};
const string fp[7]   = {"(o)","(b)","(r)","(e)","(rt)","(rc)","(cl)"};

#define   format(f) BoolToDouble(f==InDecimal,1,BoolToDouble(f==InPercent,100))
#define   percent(p,f) fibonacci[p]*format(f)
#define   fext(b,r,e,f) fdiv(e-r,b-r)*format(f)
#define   fret(r,e,rt,f) fdiv(rt-e,r-e)*format(f)
#define   fprice(b,r,p) ((b-r)*fibonacci[p])+r

#include <Class\Event.mqh>

class CFractal : public CEvent
  {

protected:

  //--- Public fractal enums
  enum             FractalState       // Fractal States
                   {
                     NoState,         // No State Assignment
                     Rally,           // Advancing fractal
                     Pullback,        // Declining fractal
                     Retrace,         // Pegged retrace (>Rally||Pullack)
                     Correction,      // Fractal max stress point/Market Correction
                     Recovery,        // Trend resumption post-correction
                     Breakout,        // Fractal Breakout
                     Reversal,        // Fractal Reversal
                     Extension,       // Fibonacci Extension
                     Flatline,        // Horizontal Trade/Idle market
                     Consolidation,   // Consolidating Range
                     Parabolic,       // Parabolic Expansion
                     Channel,         // Congruent Price Channel
                     FractalStates
                   };
  
  enum             FractalPoint       // Fractal Price Points
                   {
                     fpOrigin,        // Origin
                     fpBase,          // Base
                     fpRoot,          // Root
                     fpExpansion,     // Expansion
                     fpRetrace,       // Retrace
                     fpRecovery,      // Recovery
                     fpClose,         // Close
                     FractalPoints    // All Points
                   };

  enum             FractalType        // Fractal Type
                   {
                     //-- Geometric Types
                     Origin,
                     Trend,
                     Term,
                     Prior,
                     Base,
                     Root,
                     Expansion,
                     //-- Linear Types
                     Divergent,
                     Convergent,
                     Inversion,
                     Conversion,
                     Lead,
                     FractalTypes     // None
                   };

  enum             FibonacciType
                   {
                     FiboRoot,
                     Fibo23,
                     Fibo38,
                     Fibo50,
                     Fibo61,
                     FiboCorrection,
                     Fibo100,
                     Fibo161,
                     Fibo261,
                     Fibo423,
                     Fibo823,
                     FibonacciTypes
                   };             

  //-- Canonical Fibonacci Record
  struct FibonacciRec
         {
           FractalState  State;                    //-- Action of Last Boundary strike
           EventType     Event;                    //-- Event related to State Changed tick cleared
           int           Lead;                     //-- Action of Last Boundary strike
           int           Bias;                     //-- Action of Close-Open
           FibonacciType Level;                    //-- Current Fibonacci Level
           double        Pivot;                    //-- Fibonacci Pivot from Last Event
           double        Percent[MeasureTypes];    //-- Actual Fibonacci Percents by Measure
         };

  //-- Canonical Fractal Rec
  struct FractalRec
         {
           FractalType   Type;                     //-- Type
           FractalState  State;                    //-- State
           int           Direction;                //-- Direction based on Last Breakout/Reversal (Trend)
           int           Bias;                     //-- Bias 
           EventType     Event;                    //-- Last Event; disposes on next tick
           FibonacciRec  Extension;                //-- Fibo Extension Rec
           FibonacciRec  Retrace;                  //-- Fibo Retrace Rec
           double        Fractal[FractalPoints];   //-- Fractal Points (Prices)
           datetime      Updated;                  //-- Last Update;
         };


private:

         int             fBar;
         int             fBars;
         int             fDirection;

         double          fbuf[];
         int             fbufBar;
         int             fbufDirection;

         double          fSupport;
         double          fResistance;
         double          fPivot;
         double          fHigh;
         double          fLow;
         double          fClose;
         
         string          fObjectStr;

         FractalType     fType;
         FractalRec      frec[FractalTypes];
         double          fpoint[FractalPoints];

         bool            NewState(FractalState &State, FibonacciType Level, FibonacciType Prior);
         bool            NewState(FractalState &State, FibonacciType Level, FibonacciType Prior, bool Reversing);
         bool            NewState(FractalState &State, FractalState Change, bool Force=false, bool Update=true);

         void            UpdateFibonacci(FibonacciRec &Extension, FibonacciRec &Retrace, double &Fractal[], bool Reset);
         void            UpdateTerm(void);
         void            UpdateTrend(void);
         void            UpdateOrigin(void);
         void            UpdateFractal(void);

         void            InitFractal(void);

         void            UpdateBuffer(void);
         void            ManageBuffer(void);

public:
                         CFractal(void);
                        ~CFractal();
                    
        void             Update(double Support, double Resistance, double Pivot, int Bar);

        EventType        Event(FractalType Type);
        EventType        Event(FractalState State);
        AlertType        Alert(FractalType Type);
        FibonacciType    Level(double Percent);
//        FractalState     State(int Direction, double Fibonacci);

        FractalRec       Fractal(FractalType Type) {return frec[Type];};
        void             Fractal(double &Buffer[]) {ArrayCopy(Buffer,fbuf);};

        double           Price(FibonacciType Level, FractalType Type, FractalState Method);
        double           Price(FibonacciType Level, double Root, double Reference, FractalState Method);

        string           BufferStr(int Node);
        string           FibonacciStr(FractalState Type, FibonacciRec &Fibonacci);
        string           PointStr(double &Fractal[]);
        string           FractalStr(FractalType Type);
  };

//+------------------------------------------------------------------+
//| NewState - Returns true on change to a Fractal State             |
//+------------------------------------------------------------------+
bool CFractal::NewState(FractalState &State, FractalState Change, bool Force=false, bool Update=true)
  {
    if (Change==NoState)
      return(false);

    if (Change==Breakout)
      if (State==Reversal)
        return(false);

    //-- Outside Reversal Manager - force only on Direction Change
    if (Force&&Change==Reversal&&State==Reversal)
      return(true);

    if (State==Correction)
      if (Change==Reversal||Change==Breakout||Change==Recovery)
        return(IsChanged(State,Change,Update));
      else return(false);

    if (Change==Recovery)
      return (false);

    if (State==Retrace)
      if (Force||Change==Reversal||Change==Breakout||Change==Correction)
        return(IsChanged(State,Change,Update));
      else return(false);

    return(IsChanged(State,Change,Update));
  }

//+------------------------------------------------------------------+
//| NewState - Returns true on detected change of Fibonacci State    |
//+------------------------------------------------------------------+
bool CFractal::NewState(FractalState &State, FibonacciType Level, FibonacciType Prior, bool Reversing)
  {
//    FractalState state;

    return false;
  }

//+------------------------------------------------------------------+
//| UpdateFibonacci - Update Extension/Retrace using supplied Fractal|
//+------------------------------------------------------------------+
void CFractal::UpdateFibonacci(FibonacciRec &Extension,FibonacciRec &Retrace,double &Fractal[],bool Reset)
  {
    //-- Maintain high/low while managing history
    //double retrace   = BoolToDouble(Reset,Fractal[fpRetrace],
    //                     BoolToDouble(IsEqual(Direction(Fractal[fpExpansion]-Fractal[fpRoot]),DirectionUp),
    //                       fmin(Fractal[fpRetrace],Low[fBar]),
    //                       fmax(Fractal[fpRetrace],High[fBar]),Digits));
    //double expansion = BoolToDouble(Reset,Fractal[fpExpansion],
    //                     BoolToDouble(IsEqual(Direction(Fractal[fpExpansion]-Fractal[fpRoot]),DirectionUp),
    //                       High[fBar+1],Low[fBar]+1));

    Extension.Event   = NoEvent;
    Retrace.Event     = NoEvent;

    //-- Update Retrace
    Retrace.Percent[Now]      = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpClose],InDecimal);
    Retrace.Percent[Min]      = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpRecovery],InDecimal);
    Retrace.Percent[Max]      = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpRetrace],InDecimal);
    Retrace.Level             = (FibonacciType)BoolToInt(Reset,FiboRoot,Retrace.Level);
//    Retrace.Level             = (FibonacciType)BoolToInt(Reset,FiboRoot,Level(fret(Fractal[fpRoot],Fractal[fpExpansion],retrace,InDecimal)));
//    Retrace.Level             = (FibonacciType)BoolToInt(Reset,FiboRoot,Level(fret(Fractal[fpRoot],expansion,retrace,InDecimal))); //<--- for later?
//    Retrace.State             = State(Direction(Fractal[fpRoot]-Fractal[fpExpansion]),Retrace.Percent[Max]);

    if (IsHigher(Level(Retrace.Percent[Max]),Retrace.Level))
    {
      Retrace.Event           = NewFibonacci;
      Retrace.Pivot           = fprice(Fractal[fpRoot],Fractal[fpExpansion],Retrace.Level);
    }

    //-- Update Extension
    Extension.Percent[Now]   = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpClose],InDecimal);
    Extension.Percent[Min]   = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpRetrace],InDecimal);
    Extension.Percent[Max]   = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpExpansion],InDecimal);
    Extension.Level          = (FibonacciType)BoolToInt(Reset,FiboRoot,Extension.Level);
//    Extension.State          = State(Direction(Fractal[fpExpansion]-Fractal[fpRoot]),Extension.Percent[Max]);

    if (IsHigher(Level(Extension.Percent[Max]),Extension.Level))
    {
      Extension.Event        = NewFibonacci;
      Extension.Pivot        = fprice(Fractal[fpBase],Fractal[fpRoot],Extension.Level);
    }

    if (Extension.Percent[Max]>fibonacci[Fibo100])
      //if (IsBetween(fpo
      //else
      if (!IsBetween(Fractal[fpExpansion],fpoint[fpRoot],fpoint[fpExpansion]))
        if (Retrace.Level>FiboRoot)
        {
          Extension.Pivot  = BoolToDouble(IsBetween(fpoint[fpExpansion],fpoint[fpRoot],fpoint[fpBase]),Fractal[fpBase],fpoint[fpExpansion]);
          Extension.Event  = NewBreakout;

          Retrace.Level    = FiboRoot;
          Retrace.Pivot    = fpoint[fpExpansion];

          //if (fType==Trend)
          //  Flag(fObjectStr+"NewFibonacci-["+EnumToString(fType)+"]:Breakout"+TimeToStr(TimeCurrent()),Color(fType,frec[fType].Direction),fBar,Extension.Pivot,Always);
        }

    if (!IsEqual(fpoint[fpRoot],Fractal[fpRoot]))
      if (Extension.Percent[Max]>fibonacci[Fibo100])
        {
          Extension.Pivot  = Fractal[fpBase];
//          Extension.Pivot  = BoolToDouble(IsEqual(Direction(Fractal[fpExpansion]-Fractal[fpRoot]),DirectionUp),fResistance,fSupport,Digits);
          Extension.Event  = NewReversal;

          Retrace.Level    = FiboRoot;
          Retrace.Pivot    = Fractal[fpExpansion];

          //if (fType==Trend)
          //  Flag(fObjectStr+"NewFibonacci-["+EnumToString(fType)+"]:Reversal"+TimeToStr(TimeCurrent()),Color(fType,NewDirection),fBar,Extension.Pivot,Always);
        }

  }

//+------------------------------------------------------------------+
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CFractal::UpdateTerm(void)
  {
    //-- Hold copy for State comparisons
    fType    = Term;
    ArrayCopy(fpoint,frec[Term].Fractal);

    FractalState  state                 = NoState;

    int           direction             = Direction(BoolToInt(fClose<fSupport,DirectionDown,
                                                    BoolToInt(fClose>fResistance,DirectionUp,NoDirection)));
    frec[Term].Event                    = NoEvent;
    frec[Term].Fractal[fpClose]         = fClose;

    //--- Check for Term Reversals
    if (Event(NewBoundary))
      if (NewDirection(frec[Term].Direction,direction))
      {
        frec[Term].Fractal[fpOrigin]    = frec[Term].Fractal[fpRoot];
        //frec[Term].Fractal[fpBase]      = BoolToDouble(IsBetween(fClose,frec[Term].Fractal[fpRoot],frec[Term].Fractal[fpExpansion]),
        //                                  BoolToDouble(fClose<fSupport,fSupport,BoolToDouble(fClose>fResistance,fResistance)),frec[Term].Fractal[fpRoot]);
        frec[Term].Fractal[fpBase]      = BoolToDouble(IsEqual(direction,DirectionUp),fResistance,fSupport,Digits);  //<-- Better than ^^ but doesn't handle Triplet+ Period Reversals (see Quintuple issue"
        frec[Term].Fractal[fpRoot]      = frec[Term].Fractal[fpExpansion];

        SetEvent(NewTerm,Minor,frec[Term].Fractal[fpBase]);
      }

    //--- Check for Term Upper Boundary changes
    if (IsEqual(frec[Term].Direction,DirectionUp))
      if (IsHigher(fHigh,frec[Term].Fractal[fpExpansion]))
      {
        frec[Term].Fractal[fpRetrace]   = frec[Term].Fractal[fpExpansion];
        frec[Term].Fractal[fpRecovery]  = frec[Term].Fractal[fpExpansion];

        SetEvent(NewExpansion,Minor,frec[Term].Fractal[fpExpansion]);

        UpdateBuffer();
      }
      else 
      if (IsLower(fLow,frec[Term].Fractal[fpRetrace]))
        frec[Term].Fractal[fpRecovery]  = frec[Term].Fractal[fpRetrace];
      else
        frec[Term].Fractal[fpRecovery]  = fmax(fHigh,frec[Term].Fractal[fpRecovery]);
    else

    //--- Check for Term Lower Boundary changes
      if (IsLower(fClose,frec[Term].Fractal[fpExpansion]))
      {
        frec[Term].Fractal[fpRetrace]   = frec[Term].Fractal[fpExpansion];
        frec[Term].Fractal[fpRecovery]  = frec[Term].Fractal[fpExpansion];

        SetEvent(NewExpansion,Minor,frec[Term].Fractal[fpExpansion]);

        UpdateBuffer();
      }
      else
      if (IsHigher(fHigh,frec[Term].Fractal[fpRetrace]))
        frec[Term].Fractal[fpRecovery]  = frec[Term].Fractal[fpRetrace];
      else
        frec[Term].Fractal[fpRecovery]  = fmin(fLow,frec[Term].Fractal[fpRecovery]);

    UpdateFibonacci(frec[Term].Extension,frec[Term].Retrace,frec[Term].Fractal,Event(NewTerm));

//if (IsEqual(frec[Term].Extension.Event,NewBreakout))
//  Flag(fObjectStr+"NewFibonacci-["+EnumToString(fType)+"]:Breakout"+TimeToStr(TimeCurrent()),Color(fType,frec[fType].Direction),fBar,frec[Term].Extension.Pivot,Always);
//
if (IsEqual(frec[Term].Extension.Event,NewReversal))
  Flag(fObjectStr+"NewFibonacci-["+EnumToString(fType)+"]:Reversal"+TimeToStr(TimeCurrent()),Color(fType,NewDirection),fBar,frec[Term].Extension.Pivot,Always);

    //--- Check for term state changes
    if (Event(NewTerm))
      state                             = Reversal;
    else
    if (Event(NewExpansion,Minor))
      state                             = Breakout;
    else
    {
      if (frec[Term].Direction==DirectionUp)
        if (frec[Term].Fractal[fpRetrace]<Price(Fibo23,Term,Retrace))
          state                         = Pullback;

      if (frec[Term].Direction==DirectionDown)
        if (frec[Term].Fractal[fpRetrace]>Price(Fibo23,Term,Retrace))
          state                         = Rally;
    }

    if (NewState(frec[Term].State,state))
    {
      frec[Term].Event                  = Event(state);

      SetEvent(frec[Term].Event,Minor,BoolToDouble(state==Breakout,fpoint[fpExpansion],
                                      BoolToDouble(state==Reversal,fpoint[fpRoot],
                                      Price(Fibo23,Term,Retrace))));
      SetEvent(NewState,Minor,fClose);
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Updates trend fractal bounds and state             |
//+------------------------------------------------------------------+
void CFractal::UpdateTrend(void)
  {
    //-- Hold copy for State comparisons
    fType    = Trend;
    ArrayCopy(fpoint,frec[Trend].Fractal);

    FractalState state                  = NoState;
    
    //--- Set Common Fractal Points
    frec[Trend].Event                   = NoEvent;
    frec[Trend].Fractal[fpRetrace]      = frec[Term].Fractal[fpRetrace];
    frec[Trend].Fractal[fpRecovery]     = frec[Term].Fractal[fpRecovery];
    frec[Trend].Fractal[fpClose]        = frec[Term].Fractal[fpClose];

    //--- Handle Term Reversals 
    if (Event(NewTerm))        //--- After a term reversal
    {
      frec[Trend].Direction             = frec[Term].Direction;
      frec[Trend].Fractal[fpOrigin]     = frec[Term].Fractal[fpRoot];
      frec[Trend].Fractal[fpBase]       = frec[Term].Fractal[fpOrigin];
      frec[Trend].Fractal[fpRoot]       = frec[Term].Fractal[fpRoot];
    }

    //--- Handle Trend Interior States)
    if (IsBetween(frec[Term].Fractal[fpExpansion],frec[Trend].Fractal[fpRoot],frec[Trend].Fractal[fpBase]))
    {
      if (IsChanged(frec[Trend].Fractal[fpExpansion],frec[Term].Fractal[fpExpansion]))
        state                           = (FractalState)BoolToInt(IsEqual(frec[Trend].Direction,DirectionUp),Rally,Pullback);
      else
      if (frec[Trend].Extension.Level>1&&frec[Trend].Retrace.Level>1)
        state                           = (FractalState)BoolToInt(IsEqual(frec[Trend].Direction,DirectionUp),Pullback,Rally);
    }

    //--- Handle Trend Breakout/Reversal/Extension States)
    else
    {
      state                             = (FractalState)BoolToInt(NewDirection(frec[Origin].Direction,frec[Trend].Direction),Reversal,Breakout);

      if (IsChanged(frec[Trend].Fractal[fpExpansion],frec[Term].Fractal[fpExpansion]))
        SetEvent(NewExpansion,Major);
    }

    UpdateFibonacci(frec[Trend].Extension,frec[Trend].Retrace,frec[Trend].Fractal,Event(NewTerm));

//if (IsEqual(frec[fType].Extension.Event,NewBreakout))
//  Flag(fObjectStr+"NewFibonacci-["+EnumToString(fType)+"]:Breakout"+TimeToStr(TimeCurrent()),Color(fType,frec[fType].Direction),fBar,frec[fType].Extension.Pivot,Always);
//
if (IsEqual(frec[fType].Extension.Event,NewReversal))
  Flag(fObjectStr+"NewFibonacci-["+EnumToString(fType)+"]:Reversal"+TimeToStr(TimeCurrent()),Color(fType,NewDirection),fBar,frec[fType].Extension.Pivot,Always);

    if (NewState(frec[Trend].State,state,IsEqual(state,Reversal)))
    {
      frec[Trend].Event                 = Event(state);

      SetEvent(NewState,Major);
      SetEvent(frec[Trend].Event,Major,BoolToDouble(state==Breakout,fpoint[fpExpansion],
                                       BoolToDouble(state==Reversal,fpoint[fpRoot],
                                       Price(Fibo23,Trend,Retrace)))); //<-- needs work, need to trap the last fibo crossed
      SetEvent(BoolToEvent(Event(NewReversal,Major),NewTrend),Major,fpoint[fpRoot]);
    }
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - Updates origin fractal bounds and state           |
//+------------------------------------------------------------------+
void CFractal::UpdateOrigin(void)
  {
    //-- Hold copy for State comparisons
    fType    = Origin;
    ArrayCopy(fpoint,frec[Origin].Fractal);

    frec[Origin].Event                  = NoEvent;
    frec[Origin].Fractal[fpClose]       = frec[Term].Fractal[fpClose];

    if (Event(NewTrend))
    {
      frec[Origin]                      = frec[Trend];
      frec[Origin].Fractal[fpOrigin]    = fpoint[fpExpansion];
      frec[Origin].Fractal[fpRoot]      = fpoint[fpExpansion];

      SetEvent(BoolToEvent(Event(NewReversal,Major),NewOrigin),Critical);
    }

    if (IsChanged(frec[Origin].Fractal[fpExpansion],BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                          fmax(frec[Origin].Fractal[fpExpansion],frec[Trend].Fractal[fpExpansion]),
                                          fmin(frec[Origin].Fractal[fpExpansion],frec[Trend].Fractal[fpExpansion]),Digits)))
    {
      frec[Origin].Fractal[fpRetrace]   = frec[Origin].Fractal[fpExpansion];
      frec[Origin].Fractal[fpRecovery]  = frec[Origin].Fractal[fpExpansion];
    }                                                    
    else
    if (IsChanged(frec[Origin].Fractal[fpRetrace],BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                          fmin(frec[Origin].Fractal[fpRetrace],frec[Trend].Fractal[fpRetrace]),
                                          fmax(frec[Origin].Fractal[fpRetrace],frec[Trend].Fractal[fpRetrace]),Digits)))
      frec[Origin].Fractal[fpRecovery]  = frec[Origin].Fractal[fpRetrace];
    else
      frec[Origin].Fractal[fpRecovery]  = BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                          fmax(frec[Origin].Fractal[fpRecovery],frec[Trend].Fractal[fpRecovery]),
                                          fmin(frec[Origin].Fractal[fpRecovery],frec[Trend].Fractal[fpRecovery]),Digits);
      
    UpdateFibonacci(frec[Origin].Extension,frec[Origin].Retrace,frec[Origin].Fractal,Event(NewOrigin));

//    if (NewFractal(frec[Origin],prec,sBar,Event(NewOrigin),Always,Always))
//    {
////      Flag("[s6]"+EnumToString(sType)+":"+EnumToString(frec[Origin].Event),Color(frec[Origin].State),sBar,frec[Origin].Price,sShowFlags);
//
////      if (IsEqual(frec[Origin].State,Breakout)) Print(PivotStr(TimeToStr(BoolToDate(sBar>0,Time[sBar],TimeCurrent())),prec[0])+" "+EventStr());
//
//      if (NewState(frec[Origin].State,state,Event(NewOrigin)))
//      SetEvent(frec[Origin].Event,Critical);
//      SetEvent(NewState,Critical);
//    }
  }


//+------------------------------------------------------------------+
//| UpdateFractal - Check/Apply Corrections to Fractal before Update |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(void)
  {
    fLow      = BoolToDouble(fBar==0,Close[fBar],Low[fBar]);
    fHigh     = BoolToDouble(fBar==0,Close[fBar],High[fBar]);
    fClose    = BoolToDouble(frec[Term].Direction==DirectionUp,fHigh,fLow);

    if (IsEqual(frec[Term].Direction,NewDirection))
      InitFractal();
    else
    {
      //-- Handle Anomalies; set effective Fractal prices
      if (High[fBar]>fResistance)
      {
        if (Low[fBar]<fSupport)
        {
          //-- Handle Outside Reversal Anomalies (Historical only)
          if (Event(NewHigh)&&Event(NewLow))
          {
            fClose   = BoolToDouble(IsEqual(fDirection,DirectionUp),Low[fBar],High[fBar]);

            UpdateTerm();
            UpdateTrend();
            UpdateOrigin();

            fClose   = BoolToDouble(IsEqual(fDirection,DirectionUp),High[fBar],Low[fBar]);
          }
          else
        
          //-- Handle Hard Outside Anomaly Uptrend
          if (Event(NewHigh))
              fClose = High[fBar];
          else

          //-- Handle Hard Outside Anomaly Downtrend
          if (Event(NewLow))
            fClose = Low[fBar];
        }
        else

        //-- Handle Normal Uptrend Expansions
        if (Event(NewHigh))
          fClose   = fHigh;
      }
      else

      //-- Handle Normal Downtrend Expansions
      if (Low[fBar]<fSupport)
        if (Event(NewLow))
          fClose   = fLow;
        
      UpdateTerm();
      UpdateTrend();
      UpdateOrigin();
    }
  }

//+------------------------------------------------------------------+
//| InitFractal - Initialize Fractal history; ends on first NewTerm  |
//+------------------------------------------------------------------+
void CFractal::InitFractal(void)
  {
    //-- Maintain high/low while finding entry
    fHigh    = fmax(fHigh,High[fBar]);
    fLow     = fmin(fLow,Low[fBar]);

    if (fBar<Bars-1)
    {
      if (Event(NewHigh)&&Event(NewLow))
        return;

      for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
      {
        frec[type].Event       = Event(type);
        frec[type].State       = Breakout;
        frec[type].Updated     = TimeCurrent();

        frec[type].Fractal[fpRetrace]     = Close[fBar];
        frec[type].Fractal[fpRecovery]    = Close[fBar];
        frec[type].Fractal[fpClose]       = Close[fBar];

        if (Event(NewHigh))
        {
          frec[type].Direction   = DirectionUp;

          frec[type].Fractal[fpOrigin]    = fLow;
          frec[type].Fractal[fpBase]      = fResistance;
          frec[type].Fractal[fpRoot]      = fLow;
          frec[type].Fractal[fpExpansion] = fHigh;
        }

        if (Event(NewLow))
        {
          frec[type].Direction   = DirectionDown;

          frec[type].Fractal[fpOrigin]    = fHigh;
          frec[type].Fractal[fpBase]      = fSupport;
          frec[type].Fractal[fpRoot]      = fHigh;
          frec[type].Fractal[fpExpansion] = fLow;
        }
      }

      //-- Initialize Fractal Buffer
      fbuf[fBar+1]    = frec[Term].Fractal[fpRoot];
      fbuf[fBar]      = frec[Term].Fractal[fpExpansion];
      
      fbufBar         = fBar;
      fbufDirection   = frec[Term].Direction;
    }
  }

//+------------------------------------------------------------------+
//| UpdateBuffer - Apply changes to the Fractal Buffer               |
//+------------------------------------------------------------------+
void CFractal::UpdateBuffer(void)
  {
    if (IsEqual(frec[Term].Direction,fbufDirection))
    {
      fbuf[fbufBar]       = 0.00;
      fbufBar             = fBar;
      fbuf[fbufBar]       = frec[Term].Fractal[fpExpansion];
    }
    else  
    if (IsChanged(fbufBar,fBar))
    {
      fbuf[fbufBar]       = frec[Term].Fractal[fpExpansion];
      fbufDirection       = frec[Term].Direction;
    }
  }

//+------------------------------------------------------------------+
//| ManageBuffer - Buffer maintenance; add nodes; manage index       |
//+------------------------------------------------------------------+
void CFractal::ManageBuffer(void)
  {
    for (fBars=fBars;fBars<Bars;fBars++)
    {
      ArrayResize(fbuf,fBars,10);
      ArrayCopy(fbuf,fbuf,1,0,WHOLE_ARRAY);
        
      fbuf[0]                        = 0.00;
      fbufBar++;
    }

    //-- Push Buffer post Zero Bar after Outside Reversal Anomaly
    if (fBar<fbufBar)
      if (IsChanged(fbufDirection,frec[Term].Direction,NoUpdate))
        UpdateBuffer();
  }
  
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFractal::CFractal(void)
  {
    fBar                             = Bars-1;
    fBars                            = Bars;

    fHigh                            = High[fBar];
    fLow                             = Low[fBar];
    
    fObjectStr                       = "[fractal]";

    fbufBar                          = 0;
    fbufDirection                    = NewDirection;
    frec[Term].Direction             = NewDirection;
    
    ArrayResize(fbuf,Bars);
    ArrayInitialize(fbuf,0.00);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFractal::~CFractal()
  {
    RemoveChartObjects(fObjectStr);
  }

//+------------------------------------------------------------------+
//| Update - Updates fractal Term based on supplied values           |
//+------------------------------------------------------------------+
void CFractal::Update(double Support, double Resistance, double Pivot, int Bar)
  {
    fBar                         = Bar;
    fDirection                   = Direction(Close[Bar]-Pivot);

    fSupport                     = Support;
    fResistance                  = Resistance;
    fPivot                       = Pivot;

    ManageBuffer();
    UpdateFractal();    
  }

//+------------------------------------------------------------------+
//| Event(Type) - Returns the Event on change in Fractal Type        |
//+------------------------------------------------------------------+
EventType CFractal::Event(FractalType Type)
  {
    static const EventType event[FractalTypes]   = {NewOrigin,NewTrend,NewTerm,NewRetrace,NewBase,NewReversal,NewExpansion,
                                                    NewDivergence,NewConvergence,NewInversion,NewConversion,NewLead};
    return event[Type];
  }

//+------------------------------------------------------------------+
//| Event(State) - Returns the Event on change in Fractal State      |
//+------------------------------------------------------------------+
EventType CFractal::Event(FractalState State)
  {
    static const EventType event[FractalStates]  = {NoEvent,NewRally,NewPullback,NewRetrace,NewCorrection,NewRecovery,NewBreakout,NewReversal,
                                                    NewExtension,NewFlatline,NewConsolidation,NewParabolic,NewChannel};
    return event[State];
  }

//+------------------------------------------------------------------+
//| Alert - Returns Alert Level for supplied Fractal Type            |
//+------------------------------------------------------------------+
AlertType CFractal::Alert(FractalType Type)
  {
    static const AlertType alert[FractalTypes]  = {Critical,Major,Minor,Nominal,Warning,Nominal,Warning,
                                                    Notify,Notify,Notify,Notify,Notify};
    return alert[Type];
  }

//+------------------------------------------------------------------+
//| Level - Returns the FiboLevel based on extended fibonacci        |
//+------------------------------------------------------------------+
FibonacciType CFractal::Level(double Percent)
  {
    for (FibonacciType level=Fibo823;level>FiboRoot;level--)
      if (Percent>fibonacci[level])
        return (level);

    return (FiboRoot);
  }

//+------------------------------------------------------------------+
//| Price - Returns price for supplied Level/Type/State              |
//+------------------------------------------------------------------+
double CFractal::Price(FibonacciType Level, FractalType Type, FractalState Method)
  {
    switch (Method)
    {
      case Rally:       return Price(Fibo23,Type,Correction);
      case Pullback:    return Price(Fibo23,Type,Retrace);
      case Retrace:     return NormalizeDouble(frec[Type].Fractal[fpExpansion]-((frec[Type].Fractal[Base]-frec[Type].Fractal[fpRoot])*fibonacci[Level]),Digits);
      case Correction:  return NormalizeDouble(frec[Type].Fractal[fpRoot]+((frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot])*fibonacci[Level]),Digits);
      case Recovery:    return Price(Fibo23,Type,Retrace);
      case Extension:   return NormalizeDouble(frec[Type].Fractal[fpRoot]+((frec[Type].Fractal[fpBase]-frec[Type].Fractal[fpRoot])*fibonacci[Level]),Digits);
      default:          return NoValue;
    }
  }

//+------------------------------------------------------------------+
//| Price - Returns price from supplied level, Root/[Base|Expansion] |
//+------------------------------------------------------------------+
double CFractal::Price(FibonacciType Level, double Root, double Reference, FractalState Method)
  {
    switch (Method)
    {
      case Retrace:   return NormalizeDouble(Reference-((Reference-Root)*fibonacci[Level]),Digits);
      case Extension: return NormalizeDouble(Root+((Reference-Root)*fibonacci[Level]),Digits);
      default:        return NoValue;
    }
  }

//+------------------------------------------------------------------+
//| BufferStr - Returns formatted Buffer data for supplied Period    |
//+------------------------------------------------------------------+
string CFractal::BufferStr(int Node)
  {  
    string text            = "Fractal";

    Append(text,(string)Node,"|");
    Append(text,TimeToStr(Time[Node]),"|");
    Append(text,DoubleToStr(fbuf[Node],Digits),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| PointStr - Returns formatted Points for supplied Fractal         |
//+------------------------------------------------------------------+
string CFractal::PointStr(double &Fractal[])
  {
    string text    = "";

    for (int point=0;point<FractalPoints;point++)
      Append(text,DoubleToStr(Fractal[point],Digits),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| FibonacciStr - Returns formatted text for supplied Fibonacci     |
//+------------------------------------------------------------------+
string CFractal::FibonacciStr(FractalState Type, FibonacciRec &Fibonacci)
  {
    string text    = "";

    Append(text,EnumToString(Type));
    Append(text,ActionText(Fibonacci.Lead),"|");
    Append(text,ActionText(Fibonacci.Bias),"|");
    Append(text,EnumToString(Fibonacci.Level),"|");
    Append(text,DoubleToStr(Fibonacci.Pivot,Digits),"|");
    
    for (MeasureType measure=0;measure<MeasureTypes;measure++)
      Append(text,DoubleToStr(Fibonacci.Percent[measure]*100,1),"|");
    
    return text;
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns formatted Fractal prices by supplied Type   |
//+------------------------------------------------------------------+
string CFractal::FractalStr(FractalType Type)
  {
    string text    = "";

    Append(text,EnumToString(Type));
    Append(text,DirText(frec[Type].Direction),"|");
    Append(text,EnumToString(frec[Type].State),"|");
    Append(text,EnumToString(frec[Type].Event),"|");
    Append(text,PointStr(frec[Type].Fractal),"|");
    Append(text,TimeToStr(frec[Type].Updated),"|");
    Append(text,FibonacciStr(Extension,frec[Type].Extension),"|");
    Append(text,FibonacciStr(Retrace,frec[Type].Retrace),"|");

    return text;
  }
  

//-- General purpose functions

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(FractalType &Check, FractalType Compare, bool Update=true)
  {
    if (Check==Compare)
      return false;
   
    if (Update) 
      Check   = Compare;
  
    return true;
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(FractalState &Check, FractalState Compare, bool Update=true)
  {
    if (Check==Compare)
      return false;
   
    if (Update) 
      Check   = Compare;
  
    return true;
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(FibonacciType &Check, FibonacciType Compare, bool Update=true)
  {
    if (Check==Compare)
      return false;
   
    if (Update) 
      Check   = Compare;
  
    return true;
  }

//+------------------------------------------------------------------+
//| IsHigher - Returns true on higher FibonacciType                  |
//+------------------------------------------------------------------+
bool IsHigher(FibonacciType Check, FibonacciType &Change, bool Update=true)
  {
    if (Check>Change)
      return (IsChanged(Change,Check,Update));

    return (false);
  }

bool IsEqual(FractalType Source, FractalType Compare)     {return Source==Compare;};
bool IsEqual(FractalState Source, FractalState Compare)   {return Source==Compare;};
bool IsEqual(FibonacciType Source, FibonacciType Compare) {return Source==Compare;};
 
int Bias(int Direction, FractalState State)
  {
    switch (State)
    {
      case Parabolic:       // Parabolic Expansion
      case Channel:         // Congruent Price Channel
      case Recovery:
      case Breakout:
      case Reversal:
      case Extension:   return Action(Direction);
      case Rally:       return OP_BUY;
      case Pullback:    return OP_SELL;
      case Retrace:
      case Correction:  return Action(Direction,InDirection,InContrarian);
    }

    return NoBias;
  }

color Color(FractalType Type, int Direction=DirectionUp)
  {
    switch (Direction)
    {
      case NoDirection:    switch(Type)
                           {
                             case Origin: return C'64,128,250';
                             case Trend:  return C'64,128,200';
                             case Term:   return C'64,128,150';
                           }
      case DirectionUp:    switch(Type)
                           {
                             case Origin: return C'00,250,00';
                             case Trend:  return C'00,200,00';
                             case Term:   return C'00,150,00';
                           }
      case DirectionDown:  switch(Type)
                           {
                             case Origin: return C'250,00,00';
                             case Trend:  return C'200,00,00';
                             case Term:   return C'150,00,00';
                           }
      case NewDirection:   switch(Type)
                           {
                             case Origin: return C'250,250,00';
                             case Trend:  return C'200,200,00';
                             case Term:   return C'150,150,00';
                           }
    }
    
    return clrDarkGray;
  }