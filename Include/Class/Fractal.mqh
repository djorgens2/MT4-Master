//+------------------------------------------------------------------+
//|                                                      Fractal.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.04"
#property strict

#include <Class\ArrayDouble.mqh>
#include <Class\Event.mqh>
#include <stdutil.mqh>
#include <std_utility.mqh>
#include <fractal_lib.mqh>
//+------------------------------------------------------------------+
//| CFractal Class Methods and Properties                            |
//+------------------------------------------------------------------+
class CFractal
  {

private:

       struct FractalRec
       {
         int           Direction;
         int           Bar;
         double        Price;
         double        modRoot;
         bool          Peg;
         bool          Reversal;
         bool          Breakout;
         datetime      Updated;
       };
       
       struct OriginRec
       {
         int           Direction;           //--- Origin Direction
         int           Bar;                 //--- Origin Bar
         int           Age;                 //--- Origin Age
         double        High;                //--- Origin Short Root Price
         double        Low;                 //--- Origin Long Root Price
         bool          Peg;                 //--- Divergent Origin Peg
         ReservedWords State;               //--- Origin State
         bool          Correction;          //--- Origin Correction Indicator
         datetime      Updated;             //--- Origin Last Updated
       };

       OriginRec       dOrigin;               //--- Derived origin data
       FractalRec      f[FractalTypes];       //--- Fractal Array

       ReservedWords   fState;                //--- State of the fractal

       CArrayDouble   *fBuffer;

       //--- Input parameter conversions
       double          fRange;                //--- inpRange converted to points
       double          fRangeMin;             //--- inpRangeMin converted to points


       //--- Private fractal methods
       void            InitFractal();                          //--- initializes the fractal
       void            CalcFractal(void);                      //--- computes the fractal on the tick
       void            UpdateFractal(int Direction);           //--- Updates fractal leg direction changes
       void            InsertFractal(FractalRec &Fractal);     //--- inserts a new fractal leg
       
       void            CalcRetrace(void);                                             //--- calculates retraces on the tick
       void            UpdateRetrace(FractalType Type, int Bar, double Price=0.00);   //--- Updates interior fractal changes

       void            CalcOrigin(void);      //--- calculates origin derivatives on the tick

       void            CalcState(void);
              
       //--- Fractal leg properties
       int             fDirection;            //--- Current fractal leg direction
       int             fBars;                 //--- Count of bars in the chart
       int             fBarNow;               //--- Currently executing bar id fractal leg direction
       int             fBarHigh;              //--- Fractal top
       int             fBarLow;               //--- Fractal bottom
       double          fRetracePrice;         //--- Current fractal leg retrace price

       FractalType     fLegNow;               //--- Current leg state
       FractalType     fLegMax;               //--- Most recent major leg
       FractalType     fLegMin;               //--- Most recent minor leg
       FractalType     fDominantTrend;        //--- Current dominant trend; largest fractal leg
       FractalType     fDominantTerm;         //--- Current dominant term; last leg greater than RangeMax
       
       CEvent         *fEvents;
       bool            fShowFlags;

public:

       //--- Fractal constructor/destructor
                       CFractal(int Range, int MinRange);
                      ~CFractal(void);


       //--- Fractal refresh methods
       void             Update(void);
       void             UpdateBuffer(double &Fractal[]);
       void             RefreshScreen(bool WithEvents=false, bool LogOutput=false);

       OriginRec        Origin(void) {return (dOrigin); }
       int              Direction(FractalType Type=Expansion, bool Contrarian=false, int Format=InDirection);
       
       double           Price(FractalType Type, FractalPoint Fractal);                                    //--- Returns the Price by Fractal Point       
       double           Range(FractalType Type, ReservedWords Measure=Max, int Format=InDecimal);         //--- Returns the range between supplied points

       double           Fibonacci(FractalType Type, int Fractal, int Measure, int Format=InDecimal);      //--- For each retrace type

       ReservedWords    State(void)                     { return(fState); }                               //--- Main fractal State by Type

       FractalType      Next(FractalType Type)          { return((FractalType)fmin(Lead,Type+1)); }       //--- enum typecast for the Next element
       FractalType      Previous(FractalType Type, FractalType Measure=Divergent)
                                                        {
                                                          if (Measure==Divergent)  return((FractalType)fmax(Origin,Type-1));
                                                          if (Measure==Convergent) return((FractalType)fmax(Origin,Type-2));
                                                          return (Type);
                                                        }                                                 //--- enum typecast for the Prior element

       FractalType      Dominant(FractalType TimeRange) { if (TimeRange == Trend) return (fDominantTrend); return (fDominantTerm); }
       FractalType      Leg(int Measure);

       bool             IsRange(FractalType Type, ReservedWords Measure=Max);
       bool             IsRange(FractalType Type, FractalType Method);
       
       bool             IsReversal(FractalType Type)    { if (f[Type].Reversal) return (true); return (false); }
       bool             IsBreakout(FractalType Type)    { if (f[Type].Breakout) return (true); return (false); }

       bool             Event(const EventType Type)     { return (fEvents[Type]); }                        //-- Returns TF for supplied event
       bool             Event(EventType Event, AlertLevelType AlertLevel)
                                                        { return (fEvents.Event(Event,AlertLevel)); }      //-- Returns TF for supplied event/alert level
       void             ShowFlags(const bool Show)      { fShowFlags=Show; }                               //-- Sets the shows flags switch
       AlertLevelType   HighAlert(void)                 { return (fEvents.HighAlert()); }                  //-- returns the max alert level for the tick                                              
       bool             ActiveEvent(void)               { return (fEvents.ActiveEvent()); }
       string           ActiveEventText(const bool WithHeader=true)
                                                        { return  (fEvents.ActiveEventText(WithHeader)); } //-- returns the string of active events
       
       FractalRec operator[](const FractalType Type) const { return(f[Type]); }
  };

//+------------------------------------------------------------------+
//| CalcOrigin - computes origin derivatives                         |
//+------------------------------------------------------------------+
void CFractal::CalcOrigin(void)
  {
    ReservedWords coState    = dOrigin.State;    
    dOrigin.Bar              = f[Origin].Bar;

    if (IsRange(Origin,Convergent))
      if (Event(NewDivergence,Major))
        if (Direction(Divergent)==DirectionUp)
          dOrigin.Low        = f[Expansion].Price;
        else
          dOrigin.High       = f[Expansion].Price;

    if (Event(NewReversal))
      if (Direction(Expansion)==DirectionUp)
        dOrigin.Low        = f[Root].Price;
      else
        dOrigin.High       = f[Root].Price;

    if (Direction(Origin)==DirectionUp)
    {
      if (Price(Origin,fpRetrace)<Fibonacci(Origin,Forecast|Correction,Fibo23))
        dOrigin.Correction   = true;

      if (Price(Origin,fpRecovery)>Fibonacci(Origin,Forecast|Retrace,Fibo23))
        dOrigin.Correction   = false;
    }
        
    if (Direction(Origin)==DirectionDown)
    {
      if (Price(Origin,fpRetrace)>Fibonacci(Origin,Forecast|Correction,Fibo23))
        dOrigin.Correction   = true;

      if (Price(Origin,fpRecovery)<Fibonacci(Origin,Forecast|Retrace,Fibo23))
        dOrigin.Correction   = false;
    }
 
    if (IsBetween(f[Expansion].Price,dOrigin.High,dOrigin.Low))
      switch (fLegMax)
      {
        case Divergent:  if (f[Expansion].Direction == dOrigin.Direction)
                           dOrigin.State  = Retrace;
                         else
                           dOrigin.State  = Recovery;
                         break;

        case Convergent: if (f[Expansion].Direction == dOrigin.Direction)
                           dOrigin.State  = Resume;
                         else
                           dOrigin.State  = Retrace;

                         if (fLegMin!=fLegMax)
                           if (f[fLegMin].Direction == DirectionUp)
                             dOrigin.State  = Rally;
                           else
                             dOrigin.State  = Pullback;
      }
    else
    if (IsChanged(dOrigin.Direction,f[Expansion].Direction))
    {
      dOrigin.Age            = f[Expansion].Bar;
      dOrigin.State          = Reversal;
      dOrigin.Peg            = false;
      
      fEvents.SetEvent(NewOrigin,Critical);
    }
    else
    if (dOrigin.State!=Reversal)
      if (IsChanged(dOrigin.State,Breakout))
        dOrigin.Peg          = false;
      
    if (IsChanged(coState,dOrigin.State))
      fEvents.SetEvent(NewOriginState,fEvents.HighAlert());
  }
        
//+------------------------------------------------------------------+
//| CalcState - Computes Fractal States based on events/fibo locales |
//+------------------------------------------------------------------+
void CFractal::CalcState(void)
  {
        //--- Calc fractal state
    if (Event(NewReversal,Major))
      fState                            = Reversal;

    if (Event(NewBreakout,Major))
      fState                            = Breakout;

    switch (fState)
    {
      case Recovery:    if (Fibonacci(Root,Expansion,Now)>1-FiboPercent(Fibo23))
                        {
                          fState        = Correction;
                          fEvents.SetEvent(NewCorrection,Critical);
                        }
                        break;

      case Correction:  if (Fibonacci(Root,Expansion,Now)<FiboPercent(Fibo23))
                        {
                          fState        = Recovery;
                          fEvents.SetEvent(NewRecovery,Major);
                        }
                        break;

      case Breakout:
      case Reversal:    if (Fibonacci(Root,Expansion,Now)>FiboPercent(Fibo23))
                        {
                          fState        = Retrace;
                          fEvents.SetEvent(NewRetrace,Minor);
                        }

      default:          if (Fibonacci(Root,Expansion,Max)>1-FiboPercent(Fibo23))
                        {
                          fState        = Correction;
                          fEvents.SetEvent(NewCorrection,Major);
                        }
    }

    if (fShowFlags)
    {
      if (Event(NewCorrection))
        Flag("[fr3]New Correction",clrWhite,fShowFlags,fBarNow,Fibonacci(Base,Forecast|Correction,Fibo23));
      
      if (Event(NewOrigin))
        Flag("[fr3]New Origin",clrMagenta,fShowFlags,fBarNow,Fibonacci(Origin,Forecast|Expansion,Fibo100));

      if (Event(NewReversal)||Event(NewBreakout))
        Flag("[fr3]Breakout|Reversal",BoolToInt(Event(NewBreakout),clrRoyalBlue,clrDodgerBlue),fShowFlags,fBarNow,Fibonacci(Base,Forecast|Expansion,Fibo100));
      
      if (IsRange(Origin,Convergent))
        if (Event(NewDivergence,Major))
          Flag("[fr3]New Origin Root",clrYellow,fShowFlags,fBarNow,Price(Origin,fpExpansion)+(fRange*Direction(Divergent)));
    }
  }

//+------------------------------------------------------------------+
//| UpdateRetrace - Updates the fractal record                       |
//+------------------------------------------------------------------+
void CFractal::UpdateRetrace(FractalType Type, int Bar, double Price=0.00)
  {
    double     lastRangeMax       = 0.0;
    double     lastRangeMin       = fRange;
    
    for (FractalType type=Type;type<FractalTypes;type++)
    {    
      //--- Initialize retrace data by type
      f[type].Direction           = DirectionNone;
      f[type].Bar                 = NoValue;
      f[type].Price               = 0.00;
      f[type].Updated             = 0;

      if (type>Type||Bar==NoValue)
        f[type].modRoot           = 0.00;

      if (type!=Expansion)
      {
        f[type].Peg               = false;
        f[type].Breakout          = false;
        f[type].Reversal          = false;
      }
    }

    if (Bar==NoValue)
      return;

    f[Type].Direction             = Direction(Type);
    f[Type].Bar                   = Bar;
    f[Type].Price                 = Price;
    f[Type].Updated               = Time[Bar];
    
    fRetracePrice                 = Price;

    if (Type>Divergent)
      if (IsRange(Type,Min))
        f[Previous(Type,Convergent)].modRoot = Price(Type,fpOrigin);

    //--- Compute dominant legs
    for (FractalType type=Trend;type<=Lead;type++)
    {
      if (IsHigher(Range(type,Max),lastRangeMax))
        fDominantTrend            = type;

      if (IsHigher(Range(type,Max),lastRangeMin,NoUpdate))
        fDominantTerm             = type;      
    }              
  }
  
//+------------------------------------------------------------------+
//| CalcRetrace - calculates all interior retrace legs               |
//+------------------------------------------------------------------+
void CFractal::CalcRetrace(void)
  {
    FractalType    crStateMax      = Expansion;
    FractalType    crStateMin      = Expansion;
    FractalType    crLastLegMax    = fLegMax;

    //--- calc interior retraces    
    for (FractalType type=Expansion;type<FractalTypes;type++)
    {
      if (Direction(type) == DirectionUp)
        if (f[type].Bar == NoValue)
          UpdateRetrace(type,fBarNow,High[fBarNow]);
        else
        if (IsHigher(High[fBarNow],f[type].Price))
          UpdateRetrace(type,fBarNow,High[fBarNow]);
      
      if (Direction(type) == DirectionDown)
        if (f[type].Bar == NoValue)
          UpdateRetrace(type,fBarNow,Low[fBarNow]);
        else
        if (IsLower(Low[fBarNow],f[type].Price))
          UpdateRetrace(type,fBarNow,Low[fBarNow]);
          
      if (IsRange(type,Max))
      {
        crStateMax              = type;
        crStateMin              = type;
      }

      if (IsRange(type,Min))
        crStateMin              = type;

      if (f[type].Bar == fBarNow||type == Lead)
      {
        if (IsChanged(fLegNow,type))
          fEvents.SetEvent(NewFractal,Nominal);
        
        if (Direction(fLegNow) == DirectionUp)
          fRetracePrice         = fmin(fRetracePrice,Close[fBarNow]);

        if (Direction(fLegNow) == DirectionDown)
          fRetracePrice         = fmax(fRetracePrice,Close[fBarNow]);

        break;
      }     

      if (type>Expansion)
        if (IsHigher(fabs(f[Previous(type)].Price-f[type].Price),fRange,NoUpdate))
          f[Previous(type)].Peg = true;
    }

    //--- Calc fractal change events
    if (IsChanged(fLegMin,crStateMin))
      fEvents.SetEvent(NewFractal,Minor);
      
    if (IsChanged(fLegMax,crStateMax))
    {
      fEvents.SetEvent(NewFractal,Major);
      
      if (fLegMax==Divergent)
        if (crLastLegMax==Inversion)
          fEvents.SetEvent(NewDivergence,Critical);
        else
          fEvents.SetEvent(NewDivergence,Major);

      if (fLegMax==Convergent)
        if (crLastLegMax==Conversion)
          fEvents.SetEvent(NewConvergence,Critical);
        else
          fEvents.SetEvent(NewConvergence,Major);
    }
  }

  
//+------------------------------------------------------------------+
//| InsertFractal - inserts a new fractal node                       |
//+------------------------------------------------------------------+
void CFractal::InsertFractal(FractalRec &Fractal)
  {
    Fractal.Peg            = false;
    Fractal.Breakout       = false;
    Fractal.Reversal       = false;
        
    f[Origin]              = f[Trend];
    f[Trend]               = f[Term];
    f[Term]                = f[Prior];
    f[Prior]               = f[Base];
    f[Base]                = f[Root];
    f[Root]                = f[Expansion];
    f[Expansion]           = Fractal;
  }

//+------------------------------------------------------------------+
//| UpdateFractal - computes fractal legs and updates buffers        |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(int Direction)
  {
    f[Expansion].Peg           = false;
    
    InsertFractal(f[Divergent]);
    
    if (IsChanged(fDirection,Direction))
    {
      f[Expansion].Reversal    = true;

      fEvents.SetEvent(NewReversal,Major);
    }
    else
    {
      InsertFractal(f[Convergent]);
      
      f[Expansion].Breakout    = true;
      f[Root].Peg              = true;

      fEvents.SetEvent(NewBreakout,Major);
    }
  }

//+------------------------------------------------------------------+
//| InitFractal - initialize Root and Expansion fractal legs         |
//+------------------------------------------------------------------+
void CFractal::InitFractal(void)
  {
    if (High[fBarHigh]-Low[fBarLow]>=fRange)
    {  
      if (fBarHigh<fBarLow)
      {
        fDirection            = DirectionUp;
      
        f[Root].Bar           = fBarLow;
        f[Root].Price         = Low[fBarLow];
      
        f[Expansion].Bar      = fBarHigh;
        f[Expansion].Price    = High[fBarHigh];

        dOrigin.Low           = Low[fBarLow];
        dOrigin.High          = dOrigin.Low+fRange;
      }
    
      if (fBarHigh>fBarLow)
      {
        fDirection            = DirectionDown;

        f[Root].Bar           = fBarHigh;
        f[Root].Price         = High[fBarHigh];

        f[Expansion].Bar      = fBarLow;
        f[Expansion].Price    = Low[fBarLow];

        dOrigin.High          = High[fBarHigh];
        dOrigin.Low           = dOrigin.High-fRange;
      }
    
      dOrigin.Age             = 0;
      dOrigin.Direction       = fDirection;
      dOrigin.State           = Breakout;
      dOrigin.Updated         = Time[fBarNow];

      f[Root].Direction       = fDirection*DirectionInverse;
      f[Root].Updated         = Time[fBarNow];

      f[Expansion].Direction  = fDirection;
      f[Expansion].Updated    = Time[fBarNow];
      f[Expansion].Breakout   = true;
    
      fBuffer.SetValue(fBarLow,NormalizeDouble(Low[fBarLow],Digits));
      fBuffer.SetValue(fBarHigh,NormalizeDouble(High[fBarHigh],Digits));
    }
  }

    
//+------------------------------------------------------------------+
//| CalcFractal - computes fractal legs and updates buffers          |
//+------------------------------------------------------------------+
void CFractal::CalcFractal(void)
  {
    int    lastBarHigh    = fBarHigh;
    int    lastBarLow     = fBarLow;
    
    fEvents.ClearEvents();         //--- reset Events on the tick
    
    //--- identify new high or new low
    if (NormalizeDouble(High[fBarNow],Digits)>NormalizeDouble(High[fBarHigh],Digits))
      fBarHigh            = fBarNow;
          
    if (NormalizeDouble(Low[fBarNow],Digits)<NormalizeDouble(Low[fBarLow],Digits))
      fBarLow             = fBarNow;

    //--- Initialized on First Max Range; Expansion.Bar is never unset once Initialized
    if (f[Expansion].Bar==NoValue)
      InitFractal();
    else

    //--- Direction is known, process directional events
    {
      //--- Handle up-trends
      if (fDirection == DirectionUp)
      {
        //--- Check trend continuation
        if (fBarHigh == fBarNow)
        {            
          if (f[Expansion].Peg)
          {
            fBuffer.SetValue(f[Divergent].Bar,f[Divergent].Price);
            fBarLow            = f[Divergent].Bar;

            UpdateFractal(DirectionUp);
          }
          else
          if (lastBarHigh>fBarNow)
            fBuffer.SetValue(lastBarHigh,0.00);

          fBuffer.SetValue(fBarNow,High[fBarNow]);
        }
        else

        //--- Check trend change
        if (fBarLow == fBarNow)
        {
          fBuffer.SetValue(fBarNow,Low[fBarNow]);          
          UpdateFractal(DirectionDown);
        }
      }
      else

      //--- Handle down-trends
      if (fDirection == DirectionDown)
      {
        //--- Check trend continuation
        if (fBarLow == fBarNow)
        {
          if (f[Expansion].Peg)
          {
            fBuffer.SetValue(f[Divergent].Bar,f[Divergent].Price);
            fBarHigh         = f[Divergent].Bar;
            
            UpdateFractal(DirectionDown);
          }
          else
          if (lastBarLow>fBarNow)
            fBuffer.SetValue(lastBarLow,0.00);

          fBuffer.SetValue(fBarNow,Low[fBarNow]);
        }
        else

        //--- Check trend change
        if (fBarHigh == fBarNow)
        {
          fBuffer.SetValue(fBarNow,High[fBarNow]);

          UpdateFractal(DirectionUp);
        }
      }

      //--- Calc retrace and origin
      CalcRetrace();
      CalcOrigin();
      CalcState();
    }
  }
    
//+------------------------------------------------------------------+
//| CFractal - class constructor                                     |
//+------------------------------------------------------------------+
CFractal::CFractal(int Range, int MinRange)
  {
    fDirection              = DirectionNone;
    fLegMax                 = Expansion;
    fLegMin                 = Expansion;

    fRange                  = Pip(Range,InPoints);
    fRangeMin               = Pip(MinRange,InPoints);
    
    fBarHigh                = Bars-1;
    fBarLow                 = Bars-1;
    fBars                   = Bars;

    fEvents                 = new CEvent();
    fShowFlags              = true;   //-- Initialized forces history labels -- think about this...
    
    //-- Clean Open Chart Objects
    int fObject             = 0;
    
    while (fObject<ObjectsTotal())
      if (StringSubstr(ObjectName(fObject),0,5)=="[fr3]")
        ObjectDelete(ObjectName(fObject));
      else fObject++;
    
    //-- Initialize Chart Buffer
    fBuffer                 = new CArrayDouble(Bars);
    fBuffer.Initialize(0.00);
    fBuffer.AutoExpand      = true;
    
    //-- Initialize Fractal Nodes
    UpdateRetrace(Origin,NoValue);

    f[Expansion].Peg        = false;
    f[Expansion].Breakout   = false;
    f[Expansion].Reversal   = false;

    dOrigin.Age             = NoValue;
    dOrigin.Peg             = false;
    dOrigin.Direction       = DirectionNone;

    //-- Load History
    for (fBarNow=Bars-1; fBarNow>0; fBarNow--)
      CalcFractal();
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CFractal::~CFractal(void)
  {
    delete fBuffer;
    delete fEvents;
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFractal::Update(void)
  {
    for (fBars=fBars;fBars<Bars;fBars++)
    {
      fBarHigh++;
      fBarLow++;
    
      for (FractalType type=Trend;type<FractalTypes;type++)
        if (f[type].Bar>NoValue)
          f[type].Bar++;
              
      if (f[Origin].Bar>NoValue)
        f[Origin].Bar++;

      dOrigin.Age++;
    
      fBuffer.Insert(0,0.00);
    }
    
    CalcFractal();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFractal::UpdateBuffer(double &Fractal[])
  {
    Update();
    
    fBuffer.Copy(Fractal);
  }

//+------------------------------------------------------------------+
//| Leg - Returns the leg based on the supplied measure              |
//+------------------------------------------------------------------+
FractalType CFractal::Leg(int Measure)
  {
    switch (Measure)
    {
      case Min:     return (fLegMin);
      case Max:     return (fLegMax);
      case Active:  return (fLegNow);
    }
    
    return (FractalTypes);
  }

//+------------------------------------------------------------------+
//| IsRange - Returns true if Frectal meets the Supplied Measure     |
//+------------------------------------------------------------------+
bool CFractal::IsRange(FractalType Type, FractalType Method)
  { 
    switch (Method)
    {
      case Divergent:          return (dOrigin.Direction!=f[Expansion].Direction);
      case Convergent:         return (dOrigin.Direction==f[Expansion].Direction);
    }
      
    return (false);
  }

//+------------------------------------------------------------------+
//| IsRange - Returns true if Frectal meets the Supplied Measure     |
//+------------------------------------------------------------------+
bool CFractal::IsRange(FractalType Type, ReservedWords Measure=Max)
  { 
    if (IsBetween(Type,Trend,Expansion,0))
      return(Measure==Max);
    else
    {
      if (Measure==Max)
        if (!IsEqual(Price(Type,fpBase),0.00,Digits))
          return (IsHigher(fabs(Price(Type,fpBase)-Price(Type,fpOrigin)),fRange,NoUpdate));

      if (Measure==Min)
        if (!IsEqual(Price(Type,fpBase),0.00,Digits))
          return (IsBetween(fabs(Price(Type,fpBase)-Price(Type,fpOrigin)),fRange,fRangeMin,NoUpdate));
    }
      
    return (false);
  }

//+------------------------------------------------------------------+
//| Price - Returns the Price by Fractal Point                       |
//+------------------------------------------------------------------+
double CFractal::Price(FractalType Type, FractalPoint Fractal)
  {
    FractalPoint pfp = fpOrigin;
  
    if (Type==Origin)
      switch (Fractal)
      {
        case fpBase:      return (BoolToDouble(dOrigin.Direction==DirectionUp,dOrigin.High,dOrigin.Low,Digits));
        case fpRoot:      return (BoolToDouble(dOrigin.Direction==DirectionUp,dOrigin.Low,dOrigin.High,Digits));
        case fpExpansion: return (BoolToDouble(IsRange(Origin,Divergent),Price(Origin,fpBase),f[Expansion].Price,Digits));
        case fpRetrace:   return (BoolToDouble(IsRange(Origin,Divergent),f[Expansion].Price,Price(Divergent,fpBase),Digits));
        case fpRecovery:  return (BoolToDouble(IsRange(Origin,Divergent),Price(Divergent,fpBase),Price(Convergent,fpBase),Digits));
      }
    else
    if (Type==Prior)  //-- Handle Invergent Geometric Fractals
    {
      switch (Fractal)
      {
        case fpOrigin:    return (NormalizeDouble(f[Term].Price,Digits));
        case fpBase:      return (NormalizeDouble(f[Prior].Price,Digits));
        case fpRoot:      return (NormalizeDouble(f[Expansion].Price,Digits));
        case fpExpansion: return (NormalizeDouble(Price(Divergent,fpBase),Digits));
        case fpRetrace:   return (NormalizeDouble(Price(Convergent,fpBase),Digits));
        case fpRecovery:  return (NormalizeDouble(Price(Inversion,fpBase),Digits));
      };
    }
    else
    if (Type<=Base) //-- Handle Convergent Geometric Fractals
    {
      switch (Fractal)
      {
        case fpOrigin:    return (BoolToDouble(Type==Base,f[Prior].Price,Price(Trend,fpRoot),Digits));
        case fpBase:      return (BoolToDouble(Type==Trend,BoolToDouble(IsEqual(f[Origin].Price,0.00),Price(Origin,fpBase),f[Origin].Price),f[Type].Price,Digits));
        case fpRoot:      if (Direction(Type)==DirectionDown)
                          {
                            if (Type==Trend) return (NormalizeDouble(fmax(f[Trend].Price,fmax(f[Prior].Price,f[Root].Price)),Digits));
                            if (Type==Term)  return (NormalizeDouble(fmax(f[Prior].Price,f[Root].Price),Digits));
                          }
                          else
                          if (Direction(Type)==DirectionUp)
                          {
                            if (Type==Trend) return (BoolToDouble(IsEqual(f[Trend].Price,0,00),Price(Term,fpRoot),fmin(f[Trend].Price,Price(Term,fpRoot)),Digits));
                            if (Type==Term)  return (BoolToDouble(IsEqual(f[Prior].Price,0.00),f[Root].Price,fmin(f[Prior].Price,f[Root].Price),Digits));
                          };
                          return (NormalizeDouble(f[Root].Price,Digits));
        case fpExpansion: return (NormalizeDouble(f[Expansion].Price,Digits));
        case fpRetrace:   return (NormalizeDouble(Price(Divergent,fpBase),Digits));
        case fpRecovery:  return (NormalizeDouble(Price(Convergent,fpBase),Digits));
      };
    }
    else //-- Handle Linear Fractals
    {    
      for (FractalType type=Previous(Type);type<FractalTypes;type++)
      {
        if (pfp==Fractal)
          if (f[type].Bar>NoValue)
            return (NormalizeDouble(f[type].Price,Digits));
          else break;

        pfp++;
        
        if (IsEqual(f[type].Bar,NoValue))
          return (NormalizeDouble(0.00,Digits));
      }

      return (BoolToDouble(pfp==Fractal,fRetracePrice,0.00,Digits));
    };

    return (NoValue);
  };
  
//+------------------------------------------------------------------+
//| Direction - Returns the direction for the supplied type          |
//+------------------------------------------------------------------+
int CFractal::Direction(FractalType Type=Expansion, bool Contrarian=false, int Format=InDirection)
  {
    int dDirection         = fDirection;

    if (Type==Origin)
      dDirection           = dOrigin.Direction;
    else
    if (Type==Trend)
      dDirection           = fDirection;
    else
    if (fmod(Type,2)>0.00)
      dDirection           = fDirection*DirectionInverse;

    if (Contrarian)
      dDirection          *= DirectionInverse;
      
    if (Format==InAction)
      switch(dDirection)
      {
        case DirectionUp:    return (OP_BUY);
        case DirectionDown:  return (OP_SELL);
        case DirectionNone:  return (OP_NO_ACTION);
      }
    
    return (dDirection);
  }

//+------------------------------------------------------------------+
//| Range - Returns the leg (Base-Root) Range for supplied Measure   |
//+------------------------------------------------------------------+
double CFractal::Range(FractalType Type, ReservedWords Measure=Max, int Format=InDecimal)
  {
    double rRange         = 0.00;
    
    if (IsEqual(Price(Type,fpBase),0.00,Digits))
      return (NormalizeDouble(0.00,Digits));
      
    switch (Measure)
    {
      case Retrace:  rRange = Price(Type,fpBase)-Price(Type,fpRoot);
                     break;
      case Now:      rRange = Price(Type,fpOrigin)-Close[fBarNow];
                     break;
      case Max:      rRange = Price(Type,fpOrigin)-Price(Type,fpBase);
                     break;
      case Recovery: if (Direction(Type)==DirectionUp)
                       rRange = Price(Type,fpOrigin)-fmax(Price(Type,fpBase),fmax(Price(Type,fpExpansion),Price(Type,fpRecovery)));

                     if (Direction(Type)==DirectionDown)
                       rRange = Price(Type,fpOrigin)-fmin(Price(Type,fpBase),
                         fmin(BoolToDouble(IsEqual(Price(Type,fpExpansion),0.00),Price(Type,fpBase),Price(Type,fpExpansion)),
                              BoolToDouble(IsEqual(Price(Type,fpRecovery),0.00),Price(Type,fpBase),Price(Type,fpRecovery))));
                     
                     break;
    }

    if (Format==InDecimal) return (NormalizeDouble(fabs(rRange),Digits));
    if (Format==InPips)    return (Pip(fabs(rRange)));
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Fibonacci - Calcuates fibo % for supplied type Type and Method   |
//+------------------------------------------------------------------+
double CFractal::Fibonacci(FractalType Type, int Method, int Measure, int Format=InDecimal)
  {
    if (IsEqual(Price(Type,fpExpansion),0.00))
      return (NormalizeDouble(0.00,3));
      
    switch (Method)
    {
      case Expansion:   switch (Measure)
                        {
                          case Now: return(fdiv(Close[fBarNow]-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot))*BoolToInt(Format==InDecimal,1,100));
                          case Max: return(fdiv(Price(Type,fpExpansion)-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot))*BoolToInt(Format==InDecimal,1,100));
                          case Min: if (IsEqual(Price(Type,fpRetrace),0.00))
                                      break;
                                    return(fdiv(Price(Type,fpRetrace)-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot))*BoolToInt(Format==InDecimal,1,100));
                        }
                        break;

      case Retrace:     switch (Measure)
                        {
                          case Now: return(fdiv(Close[fBarNow]-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                          case Max: return(fdiv(Price(Type,fpRetrace)-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                          case Min: if (IsEqual(Price(Type,fpRecovery),0.00))
                                      break;
                                    return(fdiv(Price(Type,fpRecovery)-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                        }
                        break;

      case Recovery:    switch (Measure)
                        {
                          case Now: return(fdiv(Close[fBarNow]-Price(Type,fpRetrace),Price(Type,fpRetrace)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                          case Max: return(fdiv(Price(Type,fpRecovery)-Price(Type,fpRetrace),Price(Type,fpRetrace)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                        }
                        break;

      case Forecast|Correction:     return(NormalizeDouble(Price(Type,fpRoot)-((Price(Type,fpRoot)-Price(Type,fpExpansion))*FiboPercent(Measure)),Digits));
      case Forecast|Expansion:      return(NormalizeDouble(Price(Type,fpRoot)+((Price(Type,fpBase)-Price(Type,fpRoot))*FiboPercent(Measure)),Digits));
      case Forecast|Retrace:        return(NormalizeDouble(Price(Type,fpExpansion)+((Price(Type,fpRoot)-Price(Type,fpExpansion))*FiboPercent(Measure)),Digits));
    }  

    return (NormalizeDouble(0.00,3));
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints screen objects, data                    |
//+------------------------------------------------------------------+
void CFractal::RefreshScreen(bool WithEvents=false, bool LogOutput=false)
  {
    string           rsReport        = "";
    static string    rsLastReport    = "";
    const  string    rsSeg[FractalTypes] = {"o","tr","tm","p","b","r","e","d","c","iv","cv","lead"};
    const  string    rsFP[FractalPoints] = {"o","b","r","e","rt","rc"};
    
    rsReport   += "\n  Origin:\n";
    rsReport   +="      (o): "+BoolToStr(dOrigin.Direction==DirectionUp,"Long","Short");

    Append(rsReport,BoolToStr(IsRange(Origin,Divergent),"Divergent","Convergent"));
    Append(rsReport,EnumToString(dOrigin.State));
    Append(rsReport,BoolToStr(dOrigin.Correction,"Correction"));

    rsReport  +="  Bar: "+IntegerToString(dOrigin.Bar)
               +"  Age: "+IntegerToString(dOrigin.Age)+"\n";
    
    rsReport  +="             Fractal:";
    for (FractalPoint fp=fpOrigin;fp<FractalPoints;fp++)
      if (Price(Origin,fp)>0.00)
        Append(rsReport," ("+rsFP[fp]+"): "+DoubleToStr(Price(Origin,fp),Digits));

    rsReport  +="\n";
               
    rsReport  +="             Retrace: "+DoubleToString(Fibonacci(Origin,Retrace,Now,InPercent),1)+"%"
               +" "+DoubleToString(Fibonacci(Origin,Retrace,Max,InPercent),1)+"%"
               +"  Leg: (c) "+DoubleToString(fabs(Pip(Price(Origin,fpExpansion)-Close[fBarNow])),1)
               +" (m) "+DoubleToString(fabs(Pip(Price(Origin,fpExpansion)-Price(Origin,fpRetrace))),1)+"\n";

    rsReport  +="             Expansion: " +DoubleToString(Fibonacci(Origin,Expansion,Now,InPercent),1)+"%"
               +" "+DoubleToString(Fibonacci(Origin,Expansion,Max,InPercent),1)+"%"
               +"  Leg: (c) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Close[fBarNow])),1)
               +" (a) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Price(Origin,fpBase))),1)
               +" (m) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Price(Origin,fpExpansion))),1)+"\n";
      
    for (FractalType type=Trend;type<=fLegNow;type++)
    {
      if (f[type].Bar>NoValue)
      {
        if (type == Dominant(Trend))
          rsReport  += "\n  Trend "+EnumToString(fState)+":\n";
        else
        if (type == Dominant(Term))
          rsReport  += "\n  Term "+BoolToStr(BarDir()==DirectionUp,"Rally","Pullback")+":\n";
        else
        if (type == fLegNow)
          if (type < Lead)
            rsReport+= "\n  Lead:\n";

        rsReport    +="      ("+rsSeg[type]+"): "+BoolToStr(this.Direction(type)==DirectionUp,"Long","Short");

        Append(rsReport,BoolToStr(f[type].Peg,"Peg"));
        Append(rsReport,BoolToStr(f[type].Breakout,"Breakout"));
        Append(rsReport,BoolToStr(f[type].Reversal,"Reversal"));

        rsReport   +="  Bar: "+IntegerToString(f[type].Bar)+"\n";
        
        rsReport   +="             Fractal:";
        for (FractalPoint fp=fpOrigin;fp<FractalPoints;fp++)
          if (Price(type,fp)>0.00)
            Append(rsReport," ("+rsFP[fp]+"): "+DoubleToStr(Price(type,fp),Digits));
        
        if (f[type].modRoot>0.00)
          Append(rsReport," (mr): "+DoubleToStr(f[type].modRoot,Digits));

        rsReport  +="\n";
        
        rsReport  +="             Retrace: "+DoubleToString(Fibonacci(type,Retrace,Now,InPercent),1)+"%"
                   +" "+DoubleToString(Fibonacci(type,Retrace,Max,InPercent),1)+"%"
                   +"  Expansion: " +DoubleToString(Fibonacci(type,Expansion,Now,InPercent),1)+"%"
                   +" "+DoubleToString(Fibonacci(type,Expansion,Max,InPercent),1)+"%"
                   +"  Leg: (c) "+DoubleToString(Range(type,Now,InPips),1)+" (a) "+DoubleToString(Range(type,Max,InPips),1)+"\n";
      };
    }
    
    if (WithEvents)
      rsReport       += "\n\nFractal "+ActiveEventText()+"\n";
    
    if (LogOutput)
    {
      Print (rsLastReport);
      Print (rsReport);
    }
    
    rsLastReport    = rsReport;
    
    Comment(rsReport);
  }