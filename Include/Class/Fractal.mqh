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
const int fpstyle[7]   = {STYLE_DOT,STYLE_SOLID,STYLE_SOLID,STYLE_SOLID,STYLE_DOT,STYLE_DOT,STYLE_SOLID};
const int fpcolor[7]   = {clrDarkGray,clrYellow,clrRed,clrLawnGreen,clrGoldenrod,clrSteelBlue,clrDarkGray};

#define   format(f) BoolToDouble(f==InDecimal,1,BoolToDouble(f==InPercent,100))
#define   fext(b,r,e,f) fdiv(e-r,b-r)*format(f)
#define   fret(r,e,rt,f) fdiv(rt-e,r-e)*format(f)
#define   fprice(b,r,p) ((b-r)*fibonacci[p])+r

#include <Class/Event.mqh>

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
                     Origin,
                     Trend,
                     Term,
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

  //-- Bar Record
  struct BarRec
         {
           int           Bar;                      //-- Bar matching visible Chart Bar
           double        Open;                     //-- History Open
           double        High;                     //-- History High
           double        Low;                      //-- History Low
           double        Close;                    //-- History Close
           datetime      Time;                     //-- History Time
         };

  //-- Pivot Record
  struct PivotRec
         {
           EventType     Event;                    //-- Pivot Event
           int           Direction;                //-- Opening Pivot Direction
           int           Lead;                     //-- Action of last Boundary Hit
           int           Bias;                     //-- Bias
           bool          Hedge;                    //-- Hedge Flag (Lead!=Bias)
           FibonacciType Level;                    //-- Fibonacci Level that triggered the event
           double        Price;                    //-- Last Event Pivot (Fibonacci)
           double        Open;                     //-- Close price at time of Event
           double        High;                     //-- Pivot High
           double        Low;                      //-- Pivot Low
         };

  //-- Fibonacci Record
  struct FibonacciRec
         {
           EventType     Event;                    //-- Event related to State Changed tick cleared
           FibonacciType Level;                    //-- Current Fibonacci Level
           double        Price;                    //-- Fibonacci Pivot from Last Event
           double        Percent[MeasureTypes];    //-- Actual Fibonacci Percents by Measure
         };

  //-- Fractal Record
  struct FractalRec
         {
           FractalType   Type;                     //-- Type
           FractalState  State;                    //-- State
           int           Direction;                //-- Direction based on Last Breakout/Reversal (Trend)
           EventType     Event;                    //-- Last Event; disposes on next tick
           PivotRec      Pivot;                    //-- Last Fibonacci Event Pivot
           FibonacciRec  Extension;                //-- Fibo Extension Rec
           FibonacciRec  Retrace;                  //-- Fibo Retrace Rec
           double        Point[FractalPoints];     //-- Fractal Points (Prices)
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
         int             fPeriod;

         BarRec          fPrice;
         double          fOpen[];
         double          fHigh[];
         double          fLow[];
         double          fClose[];
         datetime        fTime[];

         string          fObjectStr;
         FractalType     fShowFlags;

         FractalRec      frec[FractalTypes];
         double          fpoint[FractalPoints];

         bool            FibonacciChanged(FractalType Type, FractalRec &Fractal);

         void            InitPivot(FractalType Type, PivotRec &Pivot, EventLog &Log);
         void            InitFractal(void);

         void            UpdateFibonacci(FractalType Type,FibonacciRec &Extension, FibonacciRec &Retrace, double &Fractal[], bool Reset);
         void            UpdatePivot(FractalType, PivotRec &Pivot);
         void            UpdateFractal(FractalType Type, double Support, double Resistance);
         void            ManageFractal(void);

         void            UpdateBuffer(void);
         void            ManageBuffer(void);


public:
                         CFractal(FractalType ShowFlags);
                        ~CFractal();
                    
        void             UpdateFractal(double Support, double Resistance, double Pivot, int Bar);
        int              InitHistory(int TimeFrame, int MaxBars=144000);

        void             Flag(FractalType Type, bool FlagEvent=false);
        void             SetDisplayOptions(FractalType Type)  {fShowFlags=Type;};

        EventType        Event(FractalType Type);
        EventType        Event(FractalState State);
        AlertType        Alert(FractalType Type);
        FractalState     State(EventType Event);
        FibonacciType    Level(double Percent);
        PivotRec         Pivot(FractalType Type) {return frec[Type].Pivot;};

        BarRec           Price(int Bar);
        double           Price(FibonacciType Level, FractalType Type, FractalState Method);
        double           Price(FibonacciType Level, double Root, double Reference, FractalState Method);
        double           Percent(FibonacciType Level, int Format=InDecimal) {return fibonacci[Level]*format(Format);};
        
        void             CopyBuffer(double &Buffer[])           {ArrayCopy(Buffer,fbuf);};
        FractalRec       operator[](const FractalType Type)  {return frec[Type];};


        string           BufferStr(int Node);
        string           PointStr(double &Fractal[]);
        string           FibonacciStr(FibonacciRec &Fibonacci);
        string           PivotStr(PivotRec &Pivot);
        string           FractalStr(FractalType Type);
        string           DisplayStr(FractalState State, FibonacciRec &Fractal);
        string           DisplayStr(void);
        void             PrintHistory(void);
  };

//+------------------------------------------------------------------+
//| Flag - Creates a Flag on Fibonacci Events                        |
//+------------------------------------------------------------------+
void CFractal::Flag(FractalType Type, bool FlagEvent=false)
  {
    string name    = fObjectStr+EnumToString(Type)+":"+StringSubstr(EnumToString(frec[Type].Event),3);

    if (FlagEvent)
      if (fPrice.Bar<Bars-1)
        if (IsEqual(frec[Type].State,Extension))
          Flag(name+" ["+DoubleToStr(Percent(frec[Type].Extension.Level,InPercent),1)+"%]",Color(Type,NewDirection),fPrice.Bar,frec[Type].Pivot.Price,FlagEvent);
        else
        if (IsEqual(frec[Type].State,Reversal))
          Flag(name,Color(frec[Type].Direction),fPrice.Bar,frec[Type].Pivot.Price,FlagEvent);
        else
        if (IsEqual(frec[Type].State,Breakout))
          Flag(name,Color(Type,NewDirection),fPrice.Bar,frec[Type].Pivot.Price,FlagEvent);
        else
        if (IsEqual(frec[Type].State,Recovery))
          Flag(name,clrSteelBlue,fPrice.Bar,frec[Type].Pivot.Price,FlagEvent);
        else
        if (IsEqual(frec[Type].State,Correction))
          Flag(name,clrWhite,fPrice.Bar,frec[Type].Pivot.Price,FlagEvent);
        else
          Flag(name+" ["+DoubleToStr(Percent(frec[Type].Retrace.Level,InPercent),1)+"%]",clrDarkGray,fPrice.Bar,frec[Type].Pivot.Price,FlagEvent);
  }

//+------------------------------------------------------------------+
//| FibonacciChanged - Returns true on change to Fibonacci State     |
//+------------------------------------------------------------------+
bool CFractal::FibonacciChanged(FractalType Type, FractalRec &Fractal)
  {
    if (IsBetween(Fractal.Extension.Event,NewRally,NewExtension))
    {
      if (IsChanged(Fractal.State,State(Fractal.Extension.Event)))
        SetEvent(NewState,Alert(Type),fPrice.Close);

      Fractal.Event        = Fractal.Extension.Event;
      Fractal.Pivot.Price  = Fractal.Extension.Price;
      
      return true;
    }

    if (IsBetween(Fractal.Retrace.Event,NewRally,NewExtension))
    {
      if (IsChanged(Fractal.State,State(Fractal.Retrace.Event)))
        SetEvent(NewState,Alert(Type),fPrice.Close);

      Fractal.Event        = Fractal.Retrace.Event;
      Fractal.Pivot.Price  = Fractal.Retrace.Price;

      return true;
    }

    return false;
  }

//+------------------------------------------------------------------+
//| InitPivot - Initializes Pivot from Last Event                    |
//+------------------------------------------------------------------+
void CFractal::InitPivot(FractalType Type, PivotRec &Pivot, EventLog &Log)
  {
    int direction    = Pivot.Direction;

    Pivot.Event      = Log.Event;
    Pivot.Direction  = BoolToInt(this[NewHigh],DirectionUp,BoolToInt(this[NewLow],DirectionDown,direction));
    Pivot.Price      = Log.Price;
    Pivot.Level      = (FibonacciType)BoolToInt(Event(NewExtension,Alert(Type))||Event(NewBreakout,Alert(Type)),frec[Type].Extension.Level,frec[Type].Retrace.Level);
    Pivot.Open       = fPrice.Close;
    Pivot.High       = fmax(fPrice.Close,Pivot.Price);
    Pivot.Low        = fmin(fPrice.Close,Pivot.Price);
    Pivot.Lead       = Action(Pivot.Direction);
    Pivot.Bias       = Pivot.Lead;
  }

//+------------------------------------------------------------------+
//| InitFractal - Initialize Fractal history; ends on first NewTerm  |
//+------------------------------------------------------------------+
void CFractal::InitFractal(void)
  {
    FractalRec rec;
    EventLog   event;
    int        root;

    if (fPrice.High>fResistance&&fPrice.Low<fSupport)
      return;
    else
    if (fPrice.High>fResistance)
    {
      fPrice.Close               = fPrice.High;

      rec.Direction              = DirectionUp;
      rec.Point[fpOrigin]        = fResistance;
      rec.Point[fpBase]          = fResistance;
      rec.Point[fpRoot]          = fSupport;
      
      root = BoolToInt(IsEqual(Low[iLowest(NULL,Period(),MODE_LOW,WHOLE_ARRAY,fPrice.Bar)],fSupport),iLowest(NULL,Period(),MODE_LOW,WHOLE_ARRAY,fPrice.Bar),Bars-2);
    }
    else
    if (fPrice.Low<fSupport)
    {
      fPrice.Close               = fPrice.Low;

      rec.Direction              = DirectionDown;
      rec.Point[fpOrigin]        = fSupport;
      rec.Point[fpBase]          = fSupport;
      rec.Point[fpRoot]          = fResistance;
      
      root = BoolToInt(IsEqual(High[iHighest(NULL,Period(),MODE_HIGH,WHOLE_ARRAY,fPrice.Bar)],fResistance),iHighest(NULL,Period(),MODE_HIGH,WHOLE_ARRAY,fPrice.Bar),Bars-2);
    }
    else return;

    rec.State                    = Reversal;
    rec.Point[fpExpansion]       = fPrice.Close;
    rec.Point[fpRetrace]         = fPrice.Close;
    rec.Point[fpRecovery]        = fPrice.Close;
    rec.Point[fpClose]           = fPrice.Close;
    
    event.Event                  = NewReversal;
    event.Price                  = rec.Point[fpBase];
    
    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
    {
      InitPivot(type,rec.Pivot,event);
      UpdateFibonacci(type,rec.Extension,rec.Retrace,rec.Point,Always);

      rec.Event                  = Event(type);
      frec[type]                 = rec;
    }

    //-- Initialize Fractal Buffer
    fbufBar                      = fPrice.Bar;
    fbufDirection                = frec[Term].Direction;

    fbuf[root]                   = frec[Term].Point[fpRoot];
    fbuf[fbufBar]                = frec[Term].Point[fpExpansion];
  }

//+------------------------------------------------------------------+
//| UpdateFibonacci - Update Extension/Retrace using supplied Fractal|
//+------------------------------------------------------------------+
void CFractal::UpdateFibonacci(FractalType Type, FibonacciRec &Extension,FibonacciRec &Retrace,double &Fractal[],bool Reset)
  {
    Extension.Event   = NoEvent;
    Retrace.Event     = NoEvent;

    //-- Handle Fractal Resets
    if (Reset)
    {
      //-- Reset Extension
      ArrayInitialize(Extension.Percent,fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpExpansion],InDecimal));
      Extension.Level            = Level(Extension.Percent[Max]);
      Extension.Price            = Fractal[fpBase];
      Extension.Event            = BoolToEvent(IsEqual(Fractal[fpRoot],fpoint[fpRoot]),NewBreakout,NewReversal);
    }
    else

    //-- Handle Interior Fractal Calcs
    {
      //-- Update Extension
      Extension.Percent[Now]     = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpClose],InDecimal);
      Extension.Percent[Min]     = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpRetrace],InDecimal);
      Extension.Percent[Max]     = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpExpansion],InDecimal);

      if (IsHigher(Level(Extension.Percent[Max]),Extension.Level))
      {
        Extension.Event          = NewExtension;
        Extension.Price          = fprice(Fractal[fpBase],Fractal[fpRoot],Extension.Level);
      }

      //-- Handle New Extension
      if (IsEqual(Extension.Percent[Min],Extension.Percent[Max],3))
        if (Retrace.Level>FiboRoot)
        {
          Extension.Price        = BoolToDouble(IsBetween(fpoint[fpExpansion],fpoint[fpRoot],fpoint[fpBase]),Fractal[fpBase],fpoint[fpExpansion]);
          Extension.Event        = NewBreakout;
        }
    }
    
    //-- Reset Retrace
    if (Extension.Event>NoEvent)
    {
      ArrayInitialize(Retrace.Percent,0.00);
      Retrace.Level              = FiboRoot;
    }
    else
    
    //-- Update Retrace
    {
      FibonacciType min          = Level(Retrace.Percent[Min]);

      Retrace.Percent[Now]       = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpClose],InDecimal);
      Retrace.Percent[Min]       = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpRecovery],InDecimal);
      Retrace.Percent[Max]       = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpRetrace],InDecimal);

      if (IsHigher(Level(Retrace.Percent[Max]),Retrace.Level))
      {
        if (IsEqual(Retrace.Level,FiboCorrection))
          Retrace.Event          = NewCorrection;
        else
        if (IsBetween(Retrace.Level,Fibo50,Fibo61))
          Retrace.Event          = NewRetrace;
        else
        if (IsBetween(Retrace.Level,Fibo23,Fibo38))
          Retrace.Event          = BoolToEvent(IsEqual(Direction(Fractal[fpBase]-Fractal[fpRoot]),DirectionUp),NewPullback,NewRally);

        Retrace.Price            = fprice(Fractal[fpRoot],Fractal[fpExpansion],Retrace.Level);
      }

      if (Retrace.Percent[Max]>fibonacci[FiboCorrection])
        if (IsLower(Level(Retrace.Percent[Min]),min))
          if (Retrace.Percent[Min]<fibonacci[Fibo23])
          {
            Retrace.Event        = NewRecovery;
            Retrace.Price        = fprice(Fractal[fpRoot],Fractal[fpExpansion],Fibo23);
          }
    }

    SetEvent(Extension.Event,Alert(Type),Extension.Price);
    SetEvent(Retrace.Event,Alert(Type),Retrace.Price);
  }

//+------------------------------------------------------------------+
//| UpdatePivot - Updates Pivot on the Tick                          |
//+------------------------------------------------------------------+
void CFractal::UpdatePivot(FractalType Type, PivotRec &Pivot)
  {
    Pivot.Event      = NoEvent;

    if (ActionChanged(Pivot.Bias,Action(fPrice.Close-Pivot.Price)))
      Pivot.Event    = NewBias;

    if (IsHigher(fPrice.Close,Pivot.High))
      if (ActionChanged(Pivot.Lead,OP_BUY))
        Pivot.Event  = NewLead;

    if (IsLower(fPrice.Close,Pivot.Low))
      if (ActionChanged(Pivot.Lead,OP_SELL))
        Pivot.Event  = NewLead;

    Pivot.Hedge      = !IsEqual(Pivot.Lead,Pivot.Bias);

    SetEvent(Pivot.Event,Alert(Type),fPrice.Close);
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Updates fractal by Type                          |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(FractalType Type, double Support, double Resistance)
  {
    int direction                           = Direction(BoolToInt(fPrice.Close<Support,DirectionDown,
                                                        BoolToInt(fPrice.Close>Resistance,DirectionUp,NoDirection)));

    //-- Hold copy for State comparisons
    ArrayCopy(fpoint,frec[Type].Point);

    frec[Type].Event                        = NoEvent;
    frec[Type].Point[fpClose]               = fPrice.Close;

    //--- Handle Reversals
    if (DirectionChanged(frec[Type].Direction,direction))
    {
      frec[Type].Point[fpOrigin]            = frec[Type].Point[fpRoot];
      frec[Type].Point[fpBase]              = BoolToDouble(IsEqual(direction,DirectionUp),Resistance,Support,Digits);
      frec[Type].Point[fpRoot]              = frec[Type].Point[fpExpansion];

      //-- Handle *Special* Reversals
      if (Type==Trend)
        if (!IsEqual(frec[Origin].Direction,direction))
        {
          frec[Origin].Point[fpOrigin]      = frec[Origin].Point[fpRoot];
          frec[Origin].Point[fpRoot]        = fpoint[fpRoot];
          frec[Origin].Point[fpBase]        = fpoint[fpExpansion];
          frec[Origin].Point[fpExpansion]   = fpoint[fpExpansion];
          frec[Origin].Point[fpRetrace]     = fPrice.Close;
          frec[Origin].Point[fpRecovery]    = fPrice.Close;
          frec[Origin].Extension.Level      = Fibo100;
        }

      SetEvent(Event(Type),Alert(Type),frec[Type].Point[fpBase]);
      SetEvent(NewFractal,Alert(Type),frec[Type].Point[fpBase]);
    }
    else
    
    //-- Handle *Special* Breakouts
    if (IsEqual(frec[Type].Direction,direction))
      if (Type==Trend)
        if (IsChanged(frec[Trend].Point[fpBase],frec[Term].Point[fpOrigin]))
        {
          fpoint[fpExpansion]               = frec[Term].Point[fpOrigin];

          frec[Trend].Point[fpOrigin]       = frec[Trend].Point[fpRoot];
          frec[Trend].Point[fpRoot]         = frec[Term].Point[fpRoot];
          frec[Trend].Point[fpExpansion]    = fpoint[fpExpansion];
          frec[Trend].Point[fpRetrace]      = fpoint[fpExpansion];
          frec[Trend].Point[fpRecovery]     = fpoint[fpExpansion];

          SetEvent(AdverseEvent,Major,fPrice.Close);
        }

    //--- Check for Upper Boundary changes
    if (IsEqual(frec[Type].Direction,DirectionUp))
      if (IsHigher(fPrice.High,frec[Type].Point[fpExpansion]))
      {
        frec[Type].Point[fpRetrace]         = frec[Type].Point[fpExpansion];
        frec[Type].Point[fpRecovery]        = frec[Type].Point[fpExpansion];

        SetEvent(NewExpansion,Alert(Type),frec[Type].Point[fpExpansion]);
      }
      else 
      if (IsLower(BoolToDouble(IsEqual(fBar,0),fPrice.Close,fPrice.Low),frec[Type].Point[fpRetrace]))
        frec[Type].Point[fpRecovery]        = frec[Type].Point[fpRetrace];
      else
        frec[Type].Point[fpRecovery]        = fmax(BoolToDouble(IsEqual(fBar,0),fPrice.Close,fPrice.High),frec[Type].Point[fpRecovery]);
    else

    //--- Check for Lower Boundary changes
      if (IsLower(fPrice.Close,frec[Type].Point[fpExpansion]))
      {
        frec[Type].Point[fpRetrace]         = frec[Type].Point[fpExpansion];
        frec[Type].Point[fpRecovery]        = frec[Type].Point[fpExpansion];

        SetEvent(NewExpansion,Alert(Type),frec[Type].Point[fpExpansion]);
      }
      else
      if (IsHigher(BoolToDouble(IsEqual(fBar,0),fPrice.Close,fPrice.High),frec[Type].Point[fpRetrace]))
        frec[Type].Point[fpRecovery]        = frec[Type].Point[fpRetrace];
      else
        frec[Type].Point[fpRecovery]        = fmin(BoolToDouble(IsEqual(fBar,0),fPrice.Close,fPrice.Low),frec[Type].Point[fpRecovery]);

    UpdateFibonacci(Type,frec[Type].Extension,frec[Type].Retrace,frec[Type].Point,!IsEqual(fpoint[fpRoot],frec[Type].Point[fpRoot]));
    UpdatePivot(Type,frec[Type].Pivot);
    
    if (Event(NewLead,Alert(Type)))
      SetEvent(BoolToEvent(IsEqual(frec[Type].Direction,BoolToInt(Event(NewHigh),DirectionUp,DirectionDown)),NewConvergence,NewDivergence),Alert(Type),fPrice.Close);

    if (FibonacciChanged(Type,frec[Type]))
    {
      SetEvent(NewFibonacci,Alert(Type),frec[Type].Pivot.Price);
      InitPivot(Type,frec[Type].Pivot,LastEvent());
      Flag(Type,Type==fShowFlags);
    }
  }

//+------------------------------------------------------------------+
//| ManageFractal - Apply Historical Fractal Corrections then Update |
//+------------------------------------------------------------------+
void CFractal::ManageFractal(void)
  {
    //-- Handle Anomalies; set effective Fractal prices
    if (fPrice.High>fResistance)
    {
      if (fPrice.Low<fSupport)
      {
        //-- Handle Historical Outside Reversal Anomalies
        if (Event(NewHigh)&&Event(NewLow))
        {
          fPrice.Close   = BoolToDouble(IsEqual(fDirection,DirectionUp),fPrice.Low,fPrice.High);

          UpdateFractal(Term,fSupport,fResistance);
          UpdateFractal(Trend,fmin(frec[Term].Point[fpOrigin],frec[Term].Point[fpRoot]),fmax(frec[Term].Point[fpOrigin],frec[Term].Point[fpRoot]));
          UpdateFractal(Origin,fmin(frec[Origin].Point[fpRoot],frec[Origin].Point[fpBase]),fmax(frec[Origin].Point[fpRoot],frec[Origin].Point[fpBase]));
          UpdateBuffer();

          fPrice.Close   = BoolToDouble(IsEqual(fDirection,DirectionUp),fPrice.High,fPrice.Low);
        }
        else
        
        //-- Handle Hard Outside Anomaly Uptrend
        if (Event(NewHigh))
          fPrice.Close = fPrice.High;
        else

        //-- Handle Hard Outside Anomaly Downtrend
        if (Event(NewLow))
          fPrice.Close = fPrice.Low;
      }
      else

      //-- Handle Normal Uptrend Expansions
      if (Event(NewHigh))
        fPrice.Close   = BoolToDouble(IsEqual(fBar,0),fPrice.Close,fPrice.High);
    }
    else

    //-- Handle Normal Downtrend Expansions
    if (fPrice.Low<fSupport)
      if (Event(NewLow))
        fPrice.Close   = BoolToDouble(IsEqual(fBar,0),fPrice.Close,fPrice.Low);

    UpdateFractal(Term,fSupport,fResistance);
    UpdateFractal(Trend,fmin(frec[Term].Point[fpOrigin],frec[Term].Point[fpRoot]),fmax(frec[Term].Point[fpOrigin],frec[Term].Point[fpRoot]));
    UpdateFractal(Origin,fmin(frec[Origin].Point[fpRoot],frec[Origin].Point[fpBase]),fmax(frec[Origin].Point[fpRoot],frec[Origin].Point[fpBase]));
    UpdateBuffer();
  }

//+------------------------------------------------------------------+
//| UpdateBuffer - Apply changes to the Fractal Buffer               |
//+------------------------------------------------------------------+
void CFractal::UpdateBuffer(void)
  {
    if (Event(NewExpansion))
      if (IsEqual(frec[Term].Direction,fbufDirection))
      {
        fbuf[fbufBar]       = 0.00;
        fbufBar             = fPrice.Bar;
        fbuf[fbufBar]       = frec[Term].Point[fpExpansion];
      }
      else  
      if (IsChanged(fbufBar,fPrice.Bar))
      {
        fbuf[fbufBar]       = frec[Term].Point[fpExpansion];
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
    if (fPrice.Bar<fbufBar)
      if (IsChanged(fbufDirection,frec[Term].Direction,NoUpdate))
        UpdateBuffer();
  }
  
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFractal::CFractal(FractalType ShowFlags)
  {
    fBars                            = Bars;
    fbufBar                          = 0;
    fbufDirection                    = NewDirection;
    frec[Term].Direction             = NewDirection;
    
    fObjectStr                       = "[fractal]";
    fShowFlags                       = ShowFlags;

    ArraySetAsSeries(fOpen,true);
    ArraySetAsSeries(fHigh,true);
    ArraySetAsSeries(fLow,true);
    ArraySetAsSeries(fClose,true);
    ArraySetAsSeries(fTime,true);

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
//| UpdateFractal - Applies supplied values to the Term Fractal      |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(double Support, double Resistance, double Pivot, int Bar)
  {
    fSupport                = Support;
    fResistance             = Resistance;
    fPrice                  = Price(Bar);

    fBar                    = Bar;
    fDirection              = Direction(fPrice.Close-Pivot);

    if (IsEqual(frec[Term].Direction,NewDirection))
      InitFractal();
    else
    {
      ManageBuffer();
      ManageFractal();
    }
  }

//+------------------------------------------------------------------+
//| InitHistory - Sets the History Array and Configuration           |
//+------------------------------------------------------------------+
int CFractal::InitHistory(int TimeFrame, int MaxBars=144000)
  {
    int bars                = CopyTime(NULL,TimeFrame,Time[0],MaxBars,fTime);

    fPeriod                 = TimeFrame;
  
    CopyOpen(NULL,TimeFrame,fTime[0],bars,fOpen);
    CopyHigh(NULL,TimeFrame,fTime[0],bars,fHigh);
    CopyLow(NULL,TimeFrame,fTime[0],bars,fLow);
    CopyClose(NULL,TimeFrame,fTime[0],bars,fClose);
    
    return bars;
  }

//+------------------------------------------------------------------+
//| Event(Type) - Returns the Event on change in Fractal Type        |
//+------------------------------------------------------------------+
EventType CFractal::Event(FractalType Type)
  {
    static const EventType event[FractalTypes]   = {NewOrigin,NewTrend,NewTerm,NewLead};

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
    static const AlertType alert[FractalTypes]  = {Critical,Major,Minor,Nominal};

    return alert[Type];
  }

//+------------------------------------------------------------------+
//| State - Returns the Fractal State of the supplied Event          |
//+------------------------------------------------------------------+
FractalState CFractal::State(EventType Event)
  {
    switch(Event)
    {
      case NewRally:       return Rally;
      case NewPullback:    return Pullback;
      case NewRetrace:     return Retrace;
      case NewCorrection:  return Correction;
      case NewRecovery:    return Recovery;
      case NewBreakout:    return Breakout;
      case NewReversal:    return Reversal;
      case NewExtension:   return Extension;
    }

    return NoState;
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
//| Price - Returns Price data for supplied Bar                      |
//+------------------------------------------------------------------+
BarRec CFractal::Price(int Bar)
  {
    BarRec rec;

    if (IsEqual(Bar,0))
    {
      rec.Bar       = 0;
      rec.Open      = Open[0];
      rec.High      = High[0];
      rec.Low       = Low[0];
      rec.Close     = Close[0];
      rec.Time      = Time[0];

      return rec;
    }

    rec.Bar         = iBarShift(NULL,Period(),fTime[Bar]);
    rec.Open        = fOpen[Bar];
    rec.High        = fHigh[Bar];
    rec.Low         = fLow[Bar];
    rec.Close       = fClose[Bar];
    rec.Time        = fTime[Bar];

    return rec;
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
      case Retrace:     return NormalizeDouble(frec[Type].Point[fpExpansion]-((frec[Type].Point[fpBase]-frec[Type].Point[fpRoot])*fibonacci[Level]),Digits);
      case Correction:  return NormalizeDouble(frec[Type].Point[fpRoot]+((frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot])*fibonacci[Level]),Digits);
      case Recovery:    return Price(Fibo23,Type,Retrace);
      case Extension:   return NormalizeDouble(frec[Type].Point[fpRoot]+((frec[Type].Point[fpBase]-frec[Type].Point[fpRoot])*fibonacci[Level]),Digits);
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
string CFractal::FibonacciStr(FibonacciRec &Fibonacci)
  {
    string text    = "";

    Append(text,EnumToString(Fibonacci.Event));
    Append(text,EnumToString(Fibonacci.Level),"|");
    Append(text,DoubleToStr(Fibonacci.Price,Digits),"|");
    
    for (MeasureType measure=0;measure<MeasureTypes;measure++)
      Append(text,DoubleToStr(Fibonacci.Percent[measure]*100,1),"|");
    
    return text;
  }

//+------------------------------------------------------------------+
//| PivotStr - Returns formatted text for supplied Pivot             |
//+------------------------------------------------------------------+
string CFractal::PivotStr(PivotRec &Pivot)
  {
    string text    = "";

    Append(text,EnumToString(Pivot.Event));
    Append(text,DirText(Pivot.Direction),"|");
    Append(text,ActionText(Pivot.Lead),"|");
    Append(text,ActionText(Pivot.Bias),"|");
    Append(text,BoolToStr(Pivot.Hedge,"Hedge","No Hedge"),"|");
    Append(text,EnumToString(Pivot.Level));
    Append(text,DoubleToStr(Pivot.Price,Digits),"|");
    Append(text,DoubleToStr(Pivot.Open,Digits),"|");
    Append(text,DoubleToStr(Pivot.High,Digits),"|");
    Append(text,DoubleToStr(Pivot.Low,Digits),"|");

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
    Append(text,PivotStr(frec[Type].Pivot),"|");
    Append(text,FibonacciStr(frec[Type].Extension),"|");
    Append(text,FibonacciStr(frec[Type].Retrace),"|");
    Append(text,PointStr(frec[Type].Point),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| PrintHistory - Dumps formatted history to the logfile            |
//+------------------------------------------------------------------+
void CFractal::PrintHistory(void)
  {
    for (int bar=ArraySize(fOpen);bar>0;bar--)
      Print((string)bar+"|"+
             TimeToStr(fTime[bar])+"|"+
             DoubleToStr(fOpen[bar],Digits)+"|"+
             DoubleToStr(fHigh[bar],Digits)+"|"+
             DoubleToStr(fLow[bar],Digits)+"|"+
             DoubleToStr(fClose[bar],Digits)
           );
  }


//-- General purpose functions

//+------------------------------------------------------------------+
//| DisplayStr - returns Fractal/Fibo data formatted for Comment     |
//+------------------------------------------------------------------+
string CFractal::DisplayStr(FractalState State, FibonacciRec &Fibonacci)
  {
    string text   = "   ";

    Append(text,StringSubstr(EnumToString(State),0,3)+" [");
    Append(text,StringSubstr(EnumToString(Fibonacci.Level),4)+" ]:");
    Append(text,DoubleToStr(Fibonacci.Price,Digits));

    Append(text,DoubleToStr(Fibonacci.Percent[Now]*100,1)+"%");
    Append(text,DoubleToStr(Fibonacci.Percent[Min]*100,1)+"%");
    Append(text,DoubleToStr(Fibonacci.Percent[Max]*100,1)+"%");

    return text;
  }


//+------------------------------------------------------------------+
//| DisplayStr - returns Fractal/Fibo data formatted for Comment     |
//+------------------------------------------------------------------+
string CFractal::DisplayStr(void)
  {
    string text    = "";

    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
    {
      Append(text,"------- Fractal ["+EnumToString(type)+"] ------------------------","\n\n");
      Append(text," "+DirText(frec[type].Direction),"\n");
      Append(text,EnumToString(frec[type].State));
      Append(text,"["+ActionText(frec[type].Pivot.Lead)+"]");
      Append(text,BoolToStr(frec[type].Pivot.Hedge,"Hedge"));
      Append(text,BoolToStr(IsEqual(frec[type].Event,NoEvent),""," **"+EventText(frec[type].Event)));
      Append(text,DisplayStr(Extension,frec[type].Extension),"\n");
      Append(text,DisplayStr(Retrace,frec[type].Retrace),"\n");
    }
    
    return text;
  }

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

//+------------------------------------------------------------------+
//| IsLower - Returns true on lower FibonacciType                    |
//+------------------------------------------------------------------+
bool IsLower(FibonacciType Check, FibonacciType &Change, bool Update=true)
  {
    if (Check<Change)
      return (IsChanged(Change,Check,Update));

    return false;
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