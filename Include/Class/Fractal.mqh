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

       FractalRec    f[RetraceTypes];
       FractalRec    fOrigin;               //--- Actual origin data
       OriginRec     dOrigin;               //--- Derived origin data
       ReservedWords fState;                //--- State of the fractal

       CArrayDouble *fBuffer;


       //--- Input parameter conversions
       double        fRange;                //--- inpRange converted to points
       double        fRangeMin;             //--- inpRangeMin converted to points


       //--- Private fractal methods
       void          InitFractal();                          //--- initializes the fractal
       void          CalcFractal(void);                      //--- computes the fractal on the tick
       void          UpdateFractal(int Direction);           //--- Updates fractal leg direction changes
       void          InsertFractal(FractalRec &Fractal);     //--- inserts a new fractal leg
       
       void          CalcRetrace(void);                                             //--- calculates retraces on the tick
       void          UpdateRetrace(RetraceType Type, int Bar, double Price=0.00);   //--- Updates interior fractal changes

       void          CalcOrigin(void);      //--- calculates origin derivatives on the tick
       
       //--- Fractal leg properties
       int           fDirection;            //--- Current fractal leg direction
       int           fBars;                 //--- Count of bars in the chart
       int           fBarNow;               //--- Currently executing bar id fractal leg direction
       int           fBarHigh;              //--- Fractal top
       int           fBarLow;               //--- Fractal bottom
       int           fBarDir;               //--- Bar direction (Rally/Pullback)
       double        fRetracePrice;         //--- Current fractal leg retrace price

       RetraceType   fLegNow;               //--- Current leg state
       RetraceType   fLegMax;               //--- Most recent major leg
       RetraceType   fLegMin;               //--- Most recent minor leg
       RetraceType   fDominantTrend;        //--- Current dominant trend; largest fractal leg
       RetraceType   fDominantTerm;         //--- Current dominant term; last leg greater than RangeMax
       
       CEvent       *fEvents;

public:

       //--- Fractal constructor/destructor
                     CFractal(int Range, int MinRange);
                    ~CFractal(void);

       enum          FractalPoint
                     {
                       fpOrigin,
                       fpBase,
                       fpRoot,
                       fpExpansion,
                       fpRetrace,
                       fpRecovery,
                       FractalPoints
                     };

       //--- Fractal refresh methods
       void           Update(void);
       void           UpdateBuffer(double &Fractal[]);
       void           RefreshScreen(bool WithEvents=false);

       OriginRec      Origin(void) {dOrigin.Bar=fOrigin.Bar; return (dOrigin);};
       int            Direction(RetraceType Type=Expansion, bool Contrarian=false, int Format=InDirection);
       int            BarDir(void) {return (fBarDir);};                                                 //--- Returns the immediate bar direction;
       
       double         Price(RetraceType Type, FractalPoint Fractal);                                    //--- Returns the Price by Fractal Point
       double         Price(ReservedWords Type, FractalPoint Fractal);                                  //--- Returns the Origin by Fractal Point
       double         Price(ReservedWords Type) {return (fRetracePrice);};                              //--- Returns the current Retrace Price
       
       double         Range(RetraceType Type, ReservedWords Measure=Max, int Format=InDecimal);         //--- Returns the range between supplied points

       double         Fibonacci(RetraceType Type, FractalPoint Fractal, int Measure, int Format=InDecimal);       //--- For each retrace type
       double         Fibonacci(ReservedWords Type, FractalPoint Fractal, int Measure, int Format=InDecimal);     //--- For Origin

       ReservedWords  State(ReservedWords Type) {if (Type==Origin) return(dOrigin.State);return(fState);};        //--- Main fractal State by Type

       RetraceType    Next(RetraceType Type)           { return((RetraceType)fmin(Lead,Type+1)); }      //--- enum typecast for the Next element
       RetraceType    Previous(RetraceType Type, RetraceType Leg=Divergent)
                                                       {
                                                         if (Leg==Divergent)  return((RetraceType)fmax(Trend,Type-1));
                                                         if (Leg==Convergent) return((RetraceType)fmax(Trend,Type-2));
                                                         return (Type);
                                                       }    //--- enum typecast for the Prior element

       RetraceType    Dominant(RetraceType TimeRange)  { if (TimeRange == Trend) return (fDominantTrend); return (fDominantTerm); }
       RetraceType    Leg(int Measure);

       bool           IsRange(RetraceType Type, ReservedWords Type=Max);
       bool           IsReversal(RetraceType Type)     { if (f[Type].Reversal) return (true); return (false); }
       bool           IsBreakout(RetraceType Type)     { if (f[Type].Breakout) return (true); return (false); }

       bool           Event(const EventType Type)      { return (fEvents[Type]); }
       bool           Event(EventType Event, AlertLevelType AlertLevel)
                                                       { return (fEvents.Event(Event,AlertLevel));}              
       AlertLevelType HighAlert(void)                  { return (fEvents.HighAlert()); }                  //-- returns the max alert level for the tick                                              
       bool           ActiveEvent(void)                { return (fEvents.ActiveEvent()); }
       string         ActiveEventText(const bool WithHeader=true)
                                                       { return  (fEvents.ActiveEventText(WithHeader));}  //-- returns the string of active events
       
       FractalRec operator[](const RetraceType Type) const { return(f[Type]); }
  };

//+------------------------------------------------------------------+
//| CalcOrigin - computes origin derivatives                         |
//+------------------------------------------------------------------+
void CFractal::CalcOrigin(void)
  {
    ReservedWords coState    = dOrigin.State;    
    
    if (IsRange(Convergent,Origin))
    {
      if (fEvents[NewDivergence])
        if (Direction(Divergent)==DirectionUp)
          dOrigin.Low        = f[Expansion].Price;
        else
          dOrigin.High       = f[Expansion].Price;
    }
    else
    {
      if (Fibonacci(Origin,fpRecovery,Now)>FiboPercent(Fibo50))
        if (IsChanged(dOrigin.Peg,true))
          if (dOrigin.Direction==DirectionUp)
            dOrigin.Low        = Price(Term,fpRoot);
          else
            dOrigin.High       = Price(Term,fpRoot);
    }

    if (this.Fibonacci(Origin,fpExpansion,Now)>1-FiboPercent(Fibo23))
      dOrigin.Correction     = false;

    if (this.Fibonacci(Origin,fpExpansion,Now)<FiboPercent(Fibo23))
      dOrigin.Correction     = true;

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
      
      fEvents.SetEvent(NewOrigin,Major);
      fEvents.SetEvent(NewReversal,Critical);
    }
    else
    if (dOrigin.State!=Reversal)
      if (IsChanged(dOrigin.State,Breakout))
      {
        dOrigin.Peg          = false;

        fEvents.SetEvent(NewOrigin,Major);
        fEvents.SetEvent(NewBreakout,Critical);
      }
      
    if (IsChanged(coState,dOrigin.State))
      fEvents.SetEvent(NewOriginState,fEvents.HighAlert());
  }
        
//+------------------------------------------------------------------+
//| UpdateRetrace - Updates the fractal record                       |
//+------------------------------------------------------------------+
void CFractal::UpdateRetrace(RetraceType Type, int Bar, double Price=0.00)
  {
    double     lastRangeMax      = 0.0;
    double     lastRangeMin      = fRange;
    
    for (RetraceType type=Type;type<RetraceTypes;type++)
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

    f[Type].Direction             = this.Direction(Type);
    f[Type].Bar                   = Bar;
    f[Type].Price                 = Price;
    f[Type].Updated               = Time[Bar];
    
    fRetracePrice                 = Price;

    if (Type>Divergent)
      if (IsRange(Type,Min))
        f[Previous(Type,Convergent)].modRoot = Price(Type,fpOrigin);

    //--- Compute dominant legs
    for (RetraceType type=Trend;type<=Lead;type++)
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
    RetraceType   crStateMax      = Expansion;
    RetraceType   crStateMin      = Expansion;
    ReservedWords crState         = fState;

    //--- calc interior retraces    
    for (RetraceType type=Expansion;type<RetraceTypes;type++)
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
        
        if (this.Direction(fLegNow) == DirectionUp)
          fRetracePrice         = fmin(fRetracePrice,Close[fBarNow]);

        if (this.Direction(fLegNow) == DirectionDown)
          fRetracePrice         = fmax(fRetracePrice,Close[fBarNow]);

        break;
      }     

      if (type>Expansion)
        if (IsHigher(fabs(f[Previous(type)].Price-f[type].Price),fRange,NoUpdate))
          f[Previous(type)].Peg = true;
    }

    //--- Calc fractal state
    if (fEvents.Event(NewReversal,Major))
      fState                            = Reversal;

    if (fEvents.Event(NewBreakout,Major))
      fState                            = Breakout;

    switch (fState)
    {
      case Recovery:    if (Fibonacci(Root,fpExpansion,Now)>1-FiboPercent(Fibo23))
                        {
                          fState        = Correction;
                          fEvents.SetEvent(NewCorrection,Critical);
                        }
                        break;
                        
      case Correction:  if (Fibonacci(Root,fpExpansion,Now)<FiboPercent(Fibo23))
                        {
                          fState        = Recovery;
                          fEvents.SetEvent(NewRecovery,Major);
                        }
                        break;

      case Breakout:
      case Reversal:    if (Fibonacci(Root,fpExpansion,Now)>FiboPercent(Fibo23))
                        {
                          fState        = Retrace;
                          fEvents.SetEvent(NewRetrace,Minor);
                        }

      default:          if (Fibonacci(Root,fpExpansion,Max)>1-FiboPercent(Fibo23))
                        {
                          fState        = Correction;
                          fEvents.SetEvent(NewCorrection,Critical);
                        }                        
    }
    
    if (Event(NewCorrection))
      Flag("corr"+(string)fBarNow,clrWhite,true,fBarNow);

    //--- Calc fractal change events
    if (IsChanged(fLegMin,crStateMin))
      fEvents.SetEvent(NewFractal,Minor);
      
    if (IsChanged(fLegMax,crStateMax))
    {
      fEvents.SetEvent(NewFractal,Major);
      
      if (fLegMax==Divergent)
        fEvents.SetEvent(NewDivergence,Major);

      if (fLegMax==Convergent)
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
        
    fOrigin                = f[Trend];
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
    
    if (fBarNow<Bars-1)
    {
      if (NormalizeDouble(Close[fBarNow],Digits)>NormalizeDouble(High[fBarNow+1],Digits))
        fBarDir             = DirectionUp;
        
      if (NormalizeDouble(Close[fBarNow],Digits)<NormalizeDouble(Low[fBarNow+1],Digits))
        fBarDir             = DirectionDown;
    }

    //--- Handle initialization; Expansion, once set, is never unset
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
    fBuffer                 = new CArrayDouble(Bars);
    fBuffer.Initialize(0.00);
    fBuffer.AutoExpand      = true;
    
    f[Expansion].Peg        = false;
    f[Expansion].Breakout   = false;
    f[Expansion].Reversal   = false;

    dOrigin.Age             = NoValue;
    dOrigin.Peg             = false;
    dOrigin.Direction       = DirectionNone;

    for (RetraceType Type=Trend;Type<RetraceTypes;Type++)
      UpdateRetrace(Type,NoValue);

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
    
      for (RetraceType type=Trend;type<RetraceTypes;type++)
        if (f[type].Bar>NoValue)
          f[type].Bar++;
              
      if (fOrigin.Bar>NoValue)
        fOrigin.Bar++;

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
RetraceType CFractal::Leg(int Measure)
  {
    switch (Measure)
    {
      case Min:     return (fLegMin);
      case Max:     return (fLegMax);
      case Active:  return (fLegNow);
    }
    
    return (RetraceTypes);
  }

//+------------------------------------------------------------------+
//| IsRange - Returns true if Frectal meets the Supplied Measure     |
//+------------------------------------------------------------------+
bool CFractal::IsRange(RetraceType Type, ReservedWords Measure=Max)
  { 
    if (Measure==Origin)
    { 
      if (Type==Divergent)    return (dOrigin.Direction!=f[Expansion].Direction);
      if (Type==Convergent)   return (dOrigin.Direction==f[Expansion].Direction);
      
      return (false);
    }

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
//| Price - Returns the Origin Price by Fractal Point                |
//+------------------------------------------------------------------+
double CFractal::Price(ReservedWords Type, FractalPoint Fractal)
  {
    if (Type==Origin)
      switch (Fractal)
      {
        case fpBase:      return (BoolToDouble(dOrigin.Direction==DirectionUp,dOrigin.High,dOrigin.Low,Digits));
        case fpRoot:      return (BoolToDouble(dOrigin.Direction==DirectionUp,dOrigin.Low,dOrigin.High,Digits));
        case fpExpansion: return (BoolToDouble(IsRange(Divergent,Origin),Price(Origin,fpBase),f[Expansion].Price,Digits));
        case fpRetrace:   return (BoolToDouble(IsRange(Divergent,Origin),f[Expansion].Price,Price(Divergent,fpBase),Digits));
        case fpRecovery:  return (BoolToDouble(IsRange(Divergent,Origin),Price(Divergent,fpBase),Price(Convergent,fpBase),Digits));
      };
  
    return (NoValue);
  };

//+------------------------------------------------------------------+
//| Price - Returns the Price by Fractal Point                       |
//+------------------------------------------------------------------+
double CFractal::Price(RetraceType Type, FractalPoint Fractal)
  {
    FractalPoint pfp = fpOrigin;
  
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
        case fpBase:      return (BoolToDouble(Type==Trend,BoolToDouble(IsEqual(fOrigin.Price,0.00),Price(Origin,fpBase),fOrigin.Price),f[Type].Price,Digits));
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
      for (RetraceType type=Previous(Type);type<RetraceTypes;type++)
      {
        if (pfp==Fractal)
          if (f[type].Bar>NoValue)
            return (NormalizeDouble(f[type].Price,Digits));
          else break;

        pfp++;
        
//        if (IsEqual(f[type].Price,fRetracePrice)||IsEqual(f[type].Bar,NoValue))
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
int CFractal::Direction(RetraceType Type=Expansion, bool Contrarian=false, int Format=InDirection)
  {
    int dDirection = fDirection;

    if (IsEqual(fmod(Type,2),0.00))
      dDirection   = fDirection*DirectionInverse;

    if (Contrarian||Type==Trend)
      dDirection  *= DirectionInverse;
      
    if (Format==InAction)
      switch(dDirection)
      {
        case DirectionUp:    return (OP_BUY);
        case DirectionDown:  return (OP_SELL);
        case DirectionNone:  return (NoValue);
      }
    
    return (dDirection);
  }

//+------------------------------------------------------------------+
//| Range - Returns the leg (Base-Root) Range for supplied Measure   |
//+------------------------------------------------------------------+
double CFractal::Range(RetraceType Type, ReservedWords Measure=Max, int Format=InDecimal)
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
//| Fibonacci - Calcuates fibo % for the Origin Type and Method      |
//+------------------------------------------------------------------+
double CFractal::Fibonacci(ReservedWords Type, FractalPoint Fractal, int Measure, int Format=InDecimal)
  {
    double fibonacci     = 0.00;

    if (IsEqual(Price(Type,Fractal),0.00))
      return (NormalizeDouble(0.00,Digits));

    if (Type == Origin)
      switch (Fractal)
      {
        case fpExpansion: switch (Measure)
                          {
                            case Now: fibonacci = fdiv(Close[fBarNow]-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot));
                                      break;

                            case Max: fibonacci = fdiv(Price(Type,fpExpansion)-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot));
                                      break;
                          }
                          break;

        case fpRetrace:   switch (Measure)
                          {
                            case Now: fibonacci = fdiv(Close[fBarNow]-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion));
                                      break;

                            case Max: fibonacci = fdiv(Price(Type,fpRetrace)-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion));
                                      break;
                          }
                          break;

        case fpRecovery:  switch (Measure)
                          {
                            case Now: fibonacci = fdiv(Close[fBarNow]-Price(Type,fpRetrace),Price(Type,fpRetrace)-Price(Type,fpExpansion));
                                      break;

                            case Max: fibonacci = fdiv(Price(Type,fpRecovery)-Price(Type,fpRetrace),Price(Type,fpRetrace)-Price(Type,fpExpansion));
                                      break;
                          }
                          break;
        }  

    if (Format == InPercent)
      return (NormalizeDouble(fabs(fibonacci)*100,3));
    
    return (NormalizeDouble(fabs(fibonacci),3));
  }

//+------------------------------------------------------------------+
//| Fibonacci - Calcuates fibo % for supplied type Type and Method   |
//+------------------------------------------------------------------+
double CFractal::Fibonacci(RetraceType Type, FractalPoint Fractal, int Measure, int Format=InDecimal)
  {
    double fibonacci     = 0.00;

    if (IsEqual(Price(Type,Fractal),0.00))
      return (NormalizeDouble(0.00,Digits));
      
    switch (Fractal)
    {
      case fpExpansion: switch (Measure)
                        {
                          case Now: fibonacci = fdiv(Close[fBarNow]-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot));
                                    break;

                          case Max: fibonacci = fdiv(Price(Type,fpExpansion)-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot));
                                    break;
                        }
                        break;

      case fpRetrace:   switch (Measure)
                        {
                          case Now: fibonacci = fdiv(Close[fBarNow]-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion));
                                    break;

                          case Max: fibonacci = fdiv(Price(Type,fpRetrace)-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion));
                                    break;
                        }
                        break;

      case fpRecovery:  switch (Measure)
                        {
                          case Now: fibonacci = fdiv(Close[fBarNow]-Price(Type,fpRetrace),Price(Type,fpRetrace)-Price(Type,fpExpansion));
                                    break;

                          case Max: fibonacci = fdiv(Price(Type,fpRecovery)-Price(Type,fpRetrace),Price(Type,fpRetrace)-Price(Type,fpExpansion));
                                    break;
                        }
                        break;
    }  

    if (Format == InPercent)
      return (NormalizeDouble(fabs(fibonacci)*100,3));
    
    return (NormalizeDouble(fabs(fibonacci),3));
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints screen objects, data                    |
//+------------------------------------------------------------------+
void CFractal::RefreshScreen(bool WithEvents=false)
  {
    string           rsReport    = "";
    const  string    rsSeg[RetraceTypes] = {"tr","tm","p","b","r","e","d","c","iv","cv","lead"};
    const  string    rsFP[FractalPoints] = {"o","b","r","e","rt","rc"};
    
    rsReport   += "\n  Origin:\n";
    rsReport   +="      (o): "+BoolToStr(dOrigin.Direction==DirectionUp,"Long","Short");

    Append(rsReport,BoolToStr(IsRange(Divergent,Origin),"Divergent","Convergent"));
    Append(rsReport,EnumToString(dOrigin.State));
    Append(rsReport,BoolToStr(dOrigin.Correction,"Correction"));

    rsReport  +="  Bar: "+IntegerToString(dOrigin.Bar)
               +"  Age: "+IntegerToString(dOrigin.Age)+"\n";
    
    rsReport  +="             Fractal:";
    for (FractalPoint fp=fpOrigin;fp<FractalPoints;fp++)
      if (Price(Origin,fp)>0.00)
        Append(rsReport," ("+rsFP[fp]+"): "+DoubleToStr(Price(Origin,fp),Digits));

    rsReport  +="\n";
               
    rsReport  +="             Retrace: "+DoubleToString(Fibonacci(Origin,fpRetrace,Now,InPercent),1)+"%"
               +" "+DoubleToString(Fibonacci(Origin,fpRetrace,Max,InPercent),1)+"%"
               +"  Leg: (c) "+DoubleToString(fabs(Pip(Price(Origin,fpExpansion)-Close[fBarNow])),1)
               +" (m) "+DoubleToString(fabs(Pip(Price(Origin,fpExpansion)-Price(Origin,fpRetrace))),1)+"\n";

    rsReport  +="             Expansion: " +DoubleToString(Fibonacci(Origin,fpExpansion,Now,InPercent),1)+"%"
               +" "+DoubleToString(Fibonacci(Origin,fpExpansion,Max,InPercent),1)+"%"
               +"  Leg: (c) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Close[fBarNow])),1)
               +" (a) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Price(Origin,fpBase))),1)
               +" (m) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Price(Origin,fpExpansion))),1)+"\n";
      
    for (RetraceType type=Trend;type<=fLegNow;type++)
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
        
        rsReport  +="             Retrace: "+DoubleToString(Fibonacci(type,fpRetrace,Now,InPercent),1)+"%"
                   +" "+DoubleToString(Fibonacci(type,fpRetrace,Max,InPercent),1)+"%"
                   +"  Expansion: " +DoubleToString(Fibonacci(type,fpExpansion,Now,InPercent),1)+"%"
                   +" "+DoubleToString(Fibonacci(type,fpExpansion,Max,InPercent),1)+"%"
                   +"  Leg: (c) "+DoubleToString(Range(type,Now,InPips),1)+" (a) "+DoubleToString(Range(type,Max,InPips),1)+"\n";
      };
    }
    
    if (WithEvents)
      rsReport       += "\n\nFractal "+ActiveEventText()+"\n";
    
    Comment(rsReport);
  }