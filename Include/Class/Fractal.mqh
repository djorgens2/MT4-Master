//+------------------------------------------------------------------+
//|                                                      Fractal.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
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
         double        TermBase;
         double        TermRoot;
         bool          Peg;
         bool          Reversal;
         bool          Breakout;
         bool          Retrace;
         bool          Correction;
         ReservedWords State;
         datetime      Updated;
       };
       
       struct OriginRec
       {
         int           Direction;           //--- Origin Direction
         int           Bar;                 //--- Origin Bar
         int           Age;                 //--- Origin Age
         double        High;                //--- Origin Short Root Price
         double        Low;                 //--- Origin Long Root Price
         ReservedWords State;               //--- Origin State
         bool          Correction;          //--- Origin Correction Indicator
         datetime      Updated;             //--- Origin Last Updated
       };

       FractalRec    f[RetraceTypes];
       FractalRec    fOrigin;               //--- Actual origin data
       OriginRec     dOrigin;               //--- Derived origin data

       CArrayDouble *fBuffer;


       //--- Input parameter conversions
       double        fRange;                //--- inpRange converted to points
       double        fRangeMin;             //--- inpRangeMin converted to points


       //--- Private fractal methods
       void          InitFractal();                          //--- initializes the fractal
       void          CalcFractal(void);                      //--- computes the fractal on the tick
       void          UpdateFractal(int Direction);           //--- Updates fractal leg direction changes
       void          InsertFractal(FractalRec &Fractal);     //--- inserts a new fractal leg

       double        Price(RetraceType Type, ReservedWords Measure=Now);            //--- Current retrace type price by measure
       
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
       RetraceType   fLegTrend;             //--- Most recent major leg
       RetraceType   fLegTerm;              //--- Most recent minor leg
       RetraceType   fDominantTrend;        //--- Current dominant trend; largest fractal leg
       RetraceType   fDominantTerm;         //--- Current dominant term; last leg greater tha RangeMax
       
       CEvent       *fEvents;

public:

       //--- Fractal constructor/destructor
                     CFractal(int Range, int MinRange);
                    ~CFractal(void);

       enum          FractalPoint
                     {
                       fpBase,
                       fpRoot,
                       fpExpansion,
                       fpRetrace,
                       fpRecovery,
                       FractalPoints
                     };

       //--- Fractal refresh methods
       void          Update(void);
       void          UpdateBuffer(double &Fractal[]);
       void          RefreshScreen(bool WithEvents=false);

       OriginRec     Origin(void) { dOrigin.Bar=fOrigin.Bar; return (dOrigin);};
       int           Direction(RetraceType Type=Expansion, bool Contrarian=false, int Format=InDirection);
       
       double        Price(RetraceType Type, FractalPoint Fractal);                                    //--- Returns the Price by Fractal Point
       double        Price(ReservedWords Type, FractalPoint Fractal);                                  //--- Returns the Origin by Fractal Point

       double        Range(RetraceType Type, ReservedWords Measure=Max, int Format=InPoints);          //--- For each retrace type
       
       double        Fibonacci(RetraceType Type, int Method, int Measure, int Format=InDecimal);       //--- For each retrace type
       double        Fibonacci(ReservedWords Type, int Method, int Measure, int Format=InDecimal);     //--- For Origin

       RetraceType   Next(RetraceType Type)            { return((RetraceType)fmin(Lead,Type+1)); }   //--- enum typecast for the Next element
       RetraceType   Previous(RetraceType Type)        { return((RetraceType)fmax(Trend,Type-1)); }    //--- enum typecast for the Prior element

       RetraceType   Dominant(RetraceType TimeRange)   { if (TimeRange == Trend) return (fDominantTrend); return (fDominantTerm); }
       RetraceType   Leg(int Measure=Now);

       bool          IsLeg(const RetraceType Type, RetraceType State);
       bool          IsDivergent(ReservedWords Type);       
       bool          IsReversal(RetraceType Type)      { if (this[Type].Reversal) return (true); return (false); }
       bool          IsBreakout(RetraceType Type)      { if (this[Type].Breakout) return (true); return (false); }

       bool          Event(const EventType Type)       { return (fEvents[Type]); }
       bool          Event(EventType Event, AlertLevelType AlertLevel)
                                                       { return (fEvents.Event(Event,AlertLevel));}              
       AlertLevelType HighAlert(void)                  { return (fEvents.HighAlert()); }                  //-- returns the max alert level for the tick                                              
       bool          ActiveEvent(void)                 { return (fEvents.ActiveEvent()); }
       string        ActiveEventText(const bool WithHeader=true)
                                                       { return  (fEvents.ActiveEventText(WithHeader));}  //-- returns the string of active events
       
       FractalRec operator[](const RetraceType Type) const { return(f[Type]); }
  };

//+------------------------------------------------------------------+
//| Price - Returns the price relative to the data point root        |
//+------------------------------------------------------------------+
double CFractal::Price(RetraceType Type, ReservedWords Measure=Now)
  {
    switch (Measure)
    {
      case Top:       switch(Type)
                      {
                        case Trend:  return (NormalizeDouble(fmax(this.Price(Trend,Previous),fmax(f[Trend].Price,this.Price(Term,Top))),Digits));
                        case Term:   return (NormalizeDouble(fmax(f[Term].Price,this.Price(Prior,Top)),Digits));
                        case Prior:  if (f[Prior].Direction == DirectionUp)
                                       return (NormalizeDouble(fmax(f[Prior].Price,f[Root].Price),Digits));
                                     if (f[Prior].Direction == DirectionDown)
                                       return (NormalizeDouble(fmax(f[Base].Price,f[Expansion].Price),Digits));
                                     return (NormalizeDouble(0.00,Digits));
                        case Base:
                        case Root:   return (NormalizeDouble(fmax(f[Root].Price,f[Expansion].Price),Digits));
                        default:     return (NormalizeDouble(fmax(this.Price(Type),this.Price(Type,Previous)),Digits));
                      }
                      break;
                   
      case Bottom:    switch(Type)
                      {
                        case Trend:  return (NormalizeDouble(fmin(this.Price(Trend,Previous),fmin(f[Trend].Price,this.Price(Term,Bottom))),Digits));
                        case Term:   return (NormalizeDouble(fmin(f[Term].Price,this.Price(Prior,Bottom)),Digits));
                        case Prior:  if (f[Prior].Direction == DirectionUp)
                                       return (NormalizeDouble(fmin(f[Base].Price,f[Expansion].Price),Digits));
                                     if (f[Prior].Direction == DirectionDown)
                                       return (NormalizeDouble(fmin(f[Prior].Price,f[Root].Price),Digits));
                                     return (NormalizeDouble(0.00,Digits));
                        case Base:
                        case Root:   return (NormalizeDouble(fmin(f[Root].Price,f[Expansion].Price),Digits));
                        default:     return (NormalizeDouble(fmin(this.Price(Type),this.Price(Type,Previous)),Digits));
                      }
                      break;
                   
      case Previous:  if (Type == Trend)
                        return (BoolToDouble(IsEqual(fOrigin.Price,0.00),Price(Origin,fpBase),NormalizeDouble(fOrigin.Price,Digits)));

                      return(NormalizeDouble(f[Previous(Type)].Price,Digits));
                    
      case Now:       if (IsEqual(f[Type].Price,0.00))
                        if (IsEqual(this.Price(Type,Previous),0.00))
                          return (NormalizeDouble(0.00,Digits));
                        else
                          return (NormalizeDouble(fRetracePrice,Digits));
                      else
                        return (NormalizeDouble(f[Type].Price,Digits));

      case Next:      if (Type == fLegNow)
                        return(NormalizeDouble(fRetracePrice,Digits));

                      return(NormalizeDouble(f[Next(Type)].Price,Digits));
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| CalcOrigin - computes origin derivatives                         |
//+------------------------------------------------------------------+
void CFractal::CalcOrigin(void)
  {
    ReservedWords coState    = dOrigin.State;    
    
    if (fEvents[NewDivergence])
      if (!IsDivergent(Origin))
        if (Direction(Divergent)==DirectionUp)
          dOrigin.Low        = f[Expansion].Price;
        else
          dOrigin.High       = f[Expansion].Price;

    if (this.Fibonacci(Origin,Expansion,Now)>1-FiboPercent(Fibo23))
      dOrigin.Correction     = false;

    if (this.Fibonacci(Origin,Expansion,Now)<FiboPercent(Fibo23))
      dOrigin.Correction     = true;

    if (IsBetween(f[Expansion].Price,dOrigin.High,dOrigin.Low))
      switch (fLegTrend)
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

                         if (fLegTerm!=fLegTrend)
                           if (f[fLegTerm].Direction == DirectionUp)
                             dOrigin.State  = Rally;
                           else
                             dOrigin.State  = Pullback;
      }
    else
    if (IsChanged(dOrigin.Direction,f[Expansion].Direction))
    {
      dOrigin.Age            = f[Expansion].Bar;
      dOrigin.State          = Reversal;
      
      fEvents.SetEvent(NewOrigin,Major);
      fEvents.SetEvent(NewReversal,Critical);
    }
    else
    if (dOrigin.State!=Reversal)
      if (IsChanged(dOrigin.State,Breakout))
      {
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
    double     lastRangeTrend     = 0.0;
    double     lastRangeTerm      = fRange;
    FractalRec lastFractal        = f[Type];
    
    for (RetraceType type=Type;type<RetraceTypes;type++)
    {    
      //--- Initialize retrace data by type
      f[type].Direction           = DirectionNone;
      f[type].Bar                 = NoValue;
      f[type].Price               = 0.00;
      f[type].TermBase            = 0.00;
      f[type].TermRoot            = 0.00;
      f[type].Updated             = 0;

      if (type!=Expansion)
      {
        f[type].Peg               = false;
        f[type].Breakout          = false;
        f[type].Reversal          = false;
        f[type].Retrace           = false;        
        f[type].Correction        = false;        
      }
    }
    
    if (Bar == NoValue)
      return;
      
    f[Type].Direction             = this.Direction(Type);
    f[Type].Bar                   = Bar;
    f[Type].Price                 = Price;
    f[Type].TermBase              = BoolToDouble(Type==Expansion,0.00,lastFractal.TermBase);
    f[Type].TermRoot              = BoolToDouble(Type==Expansion,0.00,lastFractal.TermRoot);
    f[Type].Updated               = Time[Bar];
    
    fRetracePrice                 = Price;

    if (Type>Divergent)
      if (!IsLeg(Type,Divergent))
      {
        f[Previous(Type)].TermBase   = f[Previous(Type)].Price;
        f[Previous(Type)].TermRoot   = Price;
      }
      
    //--- Compute dominant legs
    for (RetraceType leg=Trend;leg<=Lead;leg++)
    {
      if (IsHigher(fabs(this.Price(leg,Previous)-this.Price(leg)),lastRangeTrend))
        fDominantTrend            = leg;

      if (IsHigher(fabs(this.Price(leg,Previous)-this.Price(leg)),lastRangeTerm,NoUpdate))
        fDominantTerm             = leg;      
    }              
  }
  
//+------------------------------------------------------------------+
//| CalcRetrace - calculates all interior retrace legs               |
//+------------------------------------------------------------------+
void CFractal::CalcRetrace(void)
  {
    RetraceType crStateTrend    = Expansion;
    RetraceType crStateTerm     = Expansion;

    //--- calc interior retraces    
    for (RetraceType type=Expansion;type<RetraceTypes;type++)
    {
      if (this.Direction(type) == DirectionUp)
        if (f[type].Bar == NoValue)
          UpdateRetrace(type,fBarNow,High[fBarNow]);
        else
        if (IsHigher(High[fBarNow],f[type].Price))
          UpdateRetrace(type,fBarNow,High[fBarNow]);
      
      if (this.Direction(type) == DirectionDown)
        if (f[type].Bar == NoValue)
          UpdateRetrace(type,fBarNow,Low[fBarNow]);
        else
        if (IsLower(Low[fBarNow],f[type].Price))
          UpdateRetrace(type,fBarNow,Low[fBarNow]);
          
      if (IsLeg(type,Trend))
      {
        crStateTrend            = type;
        crStateTerm             = type;
        
        if (this.Fibonacci(type,Expansion,Now)<FiboPercent(Fibo23))
          if (IsChanged(f[type].Correction,true))
          {
            f[type].State       = Correction;
            fEvents.SetEvent(NewCorrection,Major);
          }

        if (this.Fibonacci(type,Retrace,Now)>FiboPercent(Fibo50))
          if (IsChanged(f[type].Retrace,true))
          {
            f[type].State       = Retrace;
            fEvents.SetEvent(NewRetrace,Major);
          }

        if (this.Fibonacci(type,Expansion,Now)>=1-FiboPercent(Fibo23))
        {
          if (IsChanged(f[type].Correction,false))
          {
            f[type].Retrace     = false;
            f[type].State       = Recovery;

            fEvents.SetEvent(NewRecovery,Major);
          }

          if (IsChanged(f[type].Retrace,false))
          {
            f[type].State       = Resume;
            fEvents.SetEvent(NewResume,Major);
          }
        }
      }
      
      if (IsLeg(type,Term))
        crStateTerm            = type;

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

    //--- Calc fractal change events
    if (IsChanged(fLegTerm,crStateTerm))
      fEvents.SetEvent(NewFractal,Minor);
      
    if (IsChanged(fLegTrend,crStateTrend))
    {
      fEvents.SetEvent(NewFractal,Major);
      
      if (IsLeg(Divergent,Trend))
        fEvents.SetEvent(NewDivergence,Major);

      if (IsLeg(Convergent,Trend))
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
    Fractal.Retrace        = false;
    Fractal.Correction     = false;
        
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
    fLegTrend               = Expansion;
    fLegTerm                = Expansion;

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
    f[Expansion].Retrace    = false;
    f[Expansion].Correction = false;

    dOrigin.Age             = NoValue;
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
//| Leg - Returns the Fractal Leg based on the supplied measure      |
//+------------------------------------------------------------------+
RetraceType CFractal::Leg(int Measure=Now)
  {
    switch(Measure)
    {
      case Now:      return(fLegNow);     //-- Current leg
      case Trend:    return(fLegTrend);   //-- Major leg
      case Term:     return(fLegTerm);    //-- Minor leg
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| IsDivergent - Returns true if Divergent [Origin|Retrace]         |
//+------------------------------------------------------------------+
bool CFractal::IsDivergent(ReservedWords Type)
  { 
    if (Type==Origin)
      if (dOrigin.Direction==f[Expansion].Direction)
        return (false);
      else
        return (true);
      
    if (IsLeg(Divergent,Trend))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| Price - Returns the Origin Price by Fractal Point                |
//+------------------------------------------------------------------+
double CFractal::Price(ReservedWords Type, FractalPoint Fractal)
  {
    if (Type==Origin)
      if (Fractal==fpBase)
        return (BoolToDouble(dOrigin.Direction==DirectionUp,dOrigin.High,dOrigin.Low,Digits));
      else
      if (Fractal==fpRoot)
        return (BoolToDouble(dOrigin.Direction==DirectionUp,dOrigin.Low,dOrigin.High,Digits));
      else
      if (dOrigin.Direction==f[Expansion].Direction)
        switch (Fractal)
        {
          case fpExpansion: return (NormalizeDouble(f[Expansion].Price,Digits));
          
          case fpRetrace:   if (IsEqual(f[Expansion].Price,fRetracePrice))
                              return (NormalizeDouble(0.00,Digits));
                            else
                            if (IsEqual(f[Divergent].Price,0.00))
                              return (NormalizeDouble(fRetracePrice,Digits));
                            else
                              return (NormalizeDouble(f[Divergent].Price,Digits));

          case fpRecovery:  if (IsEqual(f[Divergent].Price,0.00)
                            ||  IsEqual(f[Divergent].Price,fRetracePrice)
                            ||  IsEqual(f[Convergent].Price,fRetracePrice))
                              return (NormalizeDouble(0.00,Digits));
                            else
                            if (IsEqual(f[Convergent].Price,0.00))
                              return (NormalizeDouble(fRetracePrice,Digits));
                            else
                              return (NormalizeDouble(f[Convergent].Price,Digits));
        }
      else
        switch (Fractal)
        {
          case fpExpansion: return (NormalizeDouble(f[Root].Price,Digits));
          
          case fpRetrace:   return (NormalizeDouble(f[Expansion].Price,Digits));
          
          case fpRecovery:  if (IsEqual(f[Expansion].Price,fRetracePrice))
                              return (NormalizeDouble(0.00,Digits));
                            else
                            if (IsEqual(f[Divergent].Price,0.00))
                              return (NormalizeDouble(fRetracePrice,Digits));
                            else
                              return (NormalizeDouble(f[Divergent].Price,Digits));
        };
  
    return (NoValue);
  };

//+------------------------------------------------------------------+
//| Price - Returns the Price by Fractal Point                       |
//+------------------------------------------------------------------+
double CFractal::Price(RetraceType Type, FractalPoint Fractal)
  {
    RetraceType Node     = Type;
    
    if (Type==Prior)  //-- Handle Invergent Geometric Fibos
    {
      switch (Fractal)
      {
        case fpBase:      return (NormalizeDouble(f[Prior].Price,Digits));
        case fpRoot:      return (NormalizeDouble(f[Base].Price,Digits));
        case fpExpansion: return (NormalizeDouble(f[Root].Price,Digits));
        case fpRetrace:   return (NormalizeDouble(f[Expansion].Price,Digits));
        case fpRecovery:  if (IsEqual(f[Expansion].Price,fRetracePrice))
                            return (NormalizeDouble(0.00,Digits));
                          else
                          if (IsEqual(f[Divergent].Price,0.00))
                            return (NormalizeDouble(fRetracePrice,Digits));
                          else
                            return (NormalizeDouble(f[Divergent].Price,Digits));
      };
    }
    else
    if (Type<=Base)   //-- Handle Convergent Geometric Fractals
    {
      switch (Fractal)
      {
        case fpBase:      return (BoolToDouble(Type==Trend,Price(Trend,Previous),f[Type].Price,Digits));
        case fpRoot:      return (BoolToDouble(Direction(Type)==DirectionUp,Price(Type,Bottom),Price(Type,Top),Digits));
        case fpExpansion: return (NormalizeDouble(f[Expansion].Price,Digits));
        case fpRetrace:   return (NormalizeDouble(f[Divergent].Price,Digits));
        case fpRecovery:  return (NormalizeDouble(f[Convergent].Price,Digits));
      };
    }
    else              //-- Handle Linear Fractals
    {
      for (FractalPoint fp=fpBase;fp<FractalPoints;fp++)
      {
        if (fp==Fractal)        
          switch (fp)
          {
            case fpExpansion: if (f[Node].Price>0.00)           return (NormalizeDouble(f[Node].Price,Digits));
            case fpRoot:      if (f[Node].TermRoot>0.00)        return (NormalizeDouble(f[Node].TermRoot,Digits));
            case fpBase:      if (f[Node].TermBase>0.00)        return (NormalizeDouble(f[Node].TermBase,Digits));
            case fpRetrace:   
            case fpRecovery:  if (f[Type].Price>0.00)           return (NormalizeDouble(f[Type].Price,Digits));
                              if (f[Previous(Type)].Price>0.00) return (NormalizeDouble(fRetracePrice,Digits));
                              return (NormalizeDouble(0.00,Digits));
           }
        
          Type                = Next(Type);
      }
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
//| Range - Returns the leg length for the supplied type             |
//+------------------------------------------------------------------+
double CFractal::Range(RetraceType Type, ReservedWords Measure=Max, int Format=InPoints)
  {
    double range   = 0.00;
    
    switch (Measure)
    {
      case Now:    if (this.Direction(Type) == DirectionUp)
                     if (this.Price(Type,Bottom)>0.0)
                       range  = Close[fBarNow]-this.Price(Type,Bottom);

                   if (this.Direction(Type) == DirectionDown)
                     if (this.Price(Type,Top)>0.0)
                       range  = this.Price(Type,Top)-Close[fBarNow];
                   break;

      case Max:    if (Type == Trend)
                     range    = this.Price(Trend,Top)-this.Price(Trend,Bottom);
                   else
                   {
                     if (this.Direction(Type) == DirectionUp)
                       range  = this.Price(Type)-this.Price(Type,Bottom);
                     if (this.Direction(Type) == DirectionDown)
                       range  = this.Price(Type,Top)-this.Price(Type);
                   }
    }

    if (Format == InPips)
      return (Pip(range));
      
    if (Format == InPoints)
      return (NormalizeDouble(range,Digits));
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| IsLeg - Returns true if the leg state matches the leg length     |
//+------------------------------------------------------------------+
bool CFractal::IsLeg(RetraceType Type, RetraceType State)
  {
    if (f[Type].Bar>NoValue)
      if (IsHigher(this.Range(Type),fRange,false))
        return (State==Trend);
      else
      if (IsHigher(this.Range(Type),fRangeMin,false))
        return (State==Term);
      else    
        return (State==Divergent);

    return (false);
  }

//+------------------------------------------------------------------+
//| Fibonacci - Calcuates fibo % for the Origin Type and Method      |
//+------------------------------------------------------------------+
double CFractal::Fibonacci(ReservedWords Type, int Method, int Measure, int Format=InDecimal)
  {
    double fibonacci     = 0.00;

    if (dOrigin.Age == NoValue)
      return (0.00);

    if (Type == Origin)
      switch (Method)
      {
        case Retrace:   switch (Measure)
                        {
                          case Now: fibonacci   = fdiv(Price(Origin,fpExpansion)-Close[fBarNow],Price(Origin,fpBase)-Price(Origin,fpRoot));
                                    break;
                          
                          case Max: if (IsDivergent(Retrace)||IsDivergent(Origin))
                                      fibonacci   = fdiv(Price(Origin,fpBase)-Price(Origin,fpRetrace),Price(Origin,fpBase)-Price(Origin,fpRoot));
                                    else
                                      fibonacci   = fdiv(Price(Origin,fpExpansion)-Price(Origin,fpRetrace),Price(Origin,fpBase)-Price(Origin,fpRoot));
                                    break;
                        }
                        break;

        case Expansion: switch (Measure)
                        {
                          case Now: fibonacci   = fdiv(Price(Origin,fpRoot)-Close[fBarNow],Price(Origin,fpBase)-Price(Origin,fpRoot));
                                    break;
                            
                          case Max: if (IsDivergent(Retrace)||IsDivergent(Origin))
                                      fibonacci = fdiv(Price(Origin,fpRoot)-Price(Origin,fpRecovery),Price(Origin,fpBase)-Price(Origin,fpRoot));
                                    else
                                      fibonacci = fdiv(Price(Origin,fpRoot)-Price(Origin,fpExpansion),Price(Origin,fpBase)-Price(Origin,fpRoot));
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
double CFractal::Fibonacci(RetraceType Type, int Method, int Measure, int Format=InDecimal)
  {
    double fibonacci  = 0.00;

    if (Type > this.Leg(Now))
      return (0.00);
      
    switch (Method)
    {
      case Retrace:     switch (Measure)
                        {
                          case Now:  if (this.Direction(Expansion) == DirectionUp)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Previous)-Close[fBarNow],this.Price(Trend,Previous)-this.Price(Trend,Bottom),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   
                                         case Convergent:
                                         case Conversion:  fibonacci = fdiv(f[Type].Price-Close[fBarNow],f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         default:          fibonacci = fdiv(f[Type].Price-Close[fBarNow],f[Type].Price-this.Price(Type,Top),3);
                                                           break;
                                       }
                                     
                                     if (this.Direction(Expansion) == DirectionDown)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Previous)-Close[fBarNow],this.Price(Trend,Previous)-this.Price(Trend,Top),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   
                                         case Convergent:
                                         case Conversion:  fibonacci = fdiv(f[Type].Price-Close[fBarNow],f[Type].Price-this.Price(Type,Top),3);
                                                           break;

                                         default:          fibonacci = fdiv(f[Type].Price-Close[fBarNow],f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;
                                       }
                                     break;
                                     
                          case Max:  if (this.Direction(Expansion) == DirectionUp)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Previous)-this.Price(Divergent),this.Price(Trend,Previous)-this.Price(Trend,Bottom),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   fibonacci = fdiv(f[Type].Price-this.Price(Divergent),f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         case Convergent:
                                         case Conversion:  fibonacci = fdiv(f[Type].Price-this.Price(Next(Type),Bottom),f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         case Prior:
                                         case Root:        if (this.Price(Convergent)>0.00)
                                                             fibonacci = fdiv(f[Type].Price-this.Price(Convergent),f[Type].Price-f[Expansion].Price,3);
                                                           else
                                                             fibonacci = FiboPercent(Fibo100);
                                                           break;
                                                           
                                         default:          fibonacci = fdiv(f[Type].Price-this.Price(Next(Type),Top),f[Type].Price-this.Price(Type,Top),3);
                                                           break;
                                       }
                                     else

                                     if (this.Direction(Expansion) == DirectionDown)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Previous)-this.Price(Divergent),this.Price(Trend,Previous)-this.Price(Trend,Top),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   fibonacci = fdiv(f[Type].Price-this.Price(Divergent),f[Type].Price-this.Price(Type,Top),3);
                                                           break;

                                         case Convergent:
                                         case Conversion:  fibonacci = fdiv(f[Type].Price-this.Price(Next(Type),Top),f[Type].Price-this.Price(Type,Top),3);
                                                           break;

                                         case Prior:
                                         case Root:        if (this.Price(Convergent)>0.00)
                                                             fibonacci = fdiv(f[Type].Price-this.Price(Convergent),f[Type].Price-f[Expansion].Price,3);
                                                           else
                                                             fibonacci = FiboPercent(Fibo100);
                                                           break;
                                                           
                                         default:          fibonacci = fdiv(f[Type].Price-this.Price(Next(Type),Bottom),f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;
                                       }
                        }
                        break;

      case Expansion:   switch (Measure)
                        {
                          case Now:  if (this.Direction(Expansion) == DirectionUp)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(Close[fBarNow]-this.Price(Trend,Bottom),this.Price(Trend,Previous)-this.Price(Trend,Bottom),3);
                                                           break;
                                         case Term:
                                         case Base:
                                         case Expansion:   fibonacci = fdiv(Close[fBarNow]-this.Price(Type,Bottom),this.Price(Type)-this.Price(Type,Bottom),3);
                                                           break;

                                         case Prior:
                                         case Root:        fibonacci = fdiv(f[Expansion].Price-Close[fBarNow],f[Expansion].Price-f[Type].Price,3);
                                                           break;

                                         default:          fibonacci = fdiv(this.Range(Type,Now),this.Range(Previous(Type),Max),3);
                                                           break;
                                       }
                                     
                                     if (this.Direction(Expansion) == DirectionDown)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Top)-Close[fBarNow],this.Price(Trend,Top)-this.Price(Trend,Previous),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   fibonacci = fdiv(this.Price(Type,Top)-Close[fBarNow],this.Price(Type,Top)-this.Price(Type),3);
                                                           break;
                                         case Prior:
                                         case Root:        fibonacci = fdiv(Close[fBarNow]-f[Expansion].Price,f[Type].Price-f[Expansion].Price,3);
                                                           break;

                                         default:          fibonacci = fdiv(this.Range(Type,Now),this.Range(Previous(Type),Max),3);
                                                           break;
                                       }
                                     break;
                                     
                          case Max:  if (this.Direction(Expansion) == DirectionUp)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(f[Expansion].Price-this.Price(Trend,Bottom),this.Price(Trend,Previous)-this.Price(Trend,Bottom),3);
                                                           break;
                                         case Term:
                                         case Base:        fibonacci = fdiv(f[Expansion].Price-this.Price(Type,Bottom),f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         case Expansion:   if (this.Price(Convergent)>0.00)
                                                             fibonacci = fdiv(f[Root].Price-this.Price(Convergent),f[Root].Price-f[Expansion].Price,3);
                                                           else
                                                             fibonacci = FiboPercent(Fibo100);
                                                           break;

                                         case Prior:       fibonacci = fdiv(f[Expansion].Price-f[Root].Price,f[Expansion].Price-f[Prior].Price,3);
                                                           break;

                                         case Root:        fibonacci = fdiv(f[Expansion].Price-this.Price(Divergent),f[Expansion].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         default:          fibonacci = fdiv(this.Range(Type),this.Range(Previous(Type)),3);
                                                           break;
                                       }

                                     if (this.Direction(Expansion) == DirectionDown)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Top)-f[Expansion].Price,this.Price(Trend,Top)-this.Price(Trend,Previous),3);
                                                           break;
                                         case Term:
                                         case Base:        fibonacci = fdiv(this.Price(Type,Top)-f[Expansion].Price,this.Price(Type,Top)-f[Type].Price,3);
                                                           break;

                                         case Expansion:   if (this.Price(Convergent)>0.00)
                                                             fibonacci = fdiv(f[Root].Price-this.Price(Convergent),f[Root].Price-f[Expansion].Price,3);
                                                           else
                                                             fibonacci = FiboPercent(Fibo100);
                                                           break;

                                         case Prior:       fibonacci = fdiv(f[Root].Price-f[Expansion].Price,f[Prior].Price-f[Expansion].Price,3);
                                                           break;

                                         case Root:        fibonacci = fdiv(f[Expansion].Price-this.Price(Divergent),f[Expansion].Price-this.Price(Type,Top),3);
                                                           break;

                                         default:          fibonacci = fdiv(this.Range(Type),this.Range(Previous(Type)),3);
                                                           break;
                                       }
                        }
    }
    
    if (Format == InPercent)
      return (NormalizeDouble(fibonacci*100,3));
    
    return (NormalizeDouble(fibonacci,3));
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints screen objects, data                    |
//+------------------------------------------------------------------+
void CFractal::RefreshScreen(bool WithEvents=false)
  {
    string           rsReport    = "";
    const  string    rsSeg[RetraceTypes] = {"tr","tm","p","b","r","e","d","c","iv","cv","a"};
    
//    if (dOrigin.Bar == NoValue)
//      rsReport   += "\n  Origin: No Long Term Data\n";
//     
//    else
    {
      rsReport   += "\n  Origin:\n";
      rsReport   +="      (o): "+BoolToStr(dOrigin.Direction==DirectionUp,"Long","Short");

      Append(rsReport,EnumToString(dOrigin.State));
      Append(rsReport,BoolToStr(dOrigin.Correction,"Correction"));

      rsReport  +="  Bar: "+IntegerToString(dOrigin.Bar)
                 +"  Age: "+IntegerToString(dOrigin.Age)
                 +"  (b): "+DoubleToStr(Price(Origin,fpBase),Digits)
                 +"  (r): "+DoubleToStr(Price(Origin,fpRoot),Digits)
                 +"  (e): "+DoubleToStr(Price(Origin,fpExpansion),Digits)+"\n";
                 
      rsReport  +="             Retrace: "+DoubleToString(this.Fibonacci(Origin,Retrace,Now,InPercent),1)+"%"
                 +" "+DoubleToString(this.Fibonacci(Origin,Retrace,Max,InPercent),1)+"%"
                 +"  Leg: (c) "+DoubleToString(fabs(Pip(Price(Origin,fpExpansion)-Close[fBarNow])),1)
                 +" (m) "+DoubleToString(fabs(Pip(Price(Origin,fpExpansion)-Price(Origin,fpRetrace))),1)+"\n";

      rsReport  +="             Expansion: " +DoubleToString(this.Fibonacci(Origin,Expansion,Now,InPercent),1)+"%"
                 +" "+DoubleToString(this.Fibonacci(Origin,Expansion,Max,InPercent),1)+"%"
                 +"  Leg: (c) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Close[fBarNow])),1)
                 +" (a) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Price(Origin,fpRecovery))),1)
                 +" (m) "+DoubleToString(fabs(Pip(Price(Origin,fpRoot)-Price(Origin,fpExpansion))),1)+"\n";
    }
      
    for (RetraceType type=Trend;type<=this.Leg(Now);type++)
    {
      if (this[type].Bar>NoValue)
      {
        if (type == this.Dominant(Trend))
          rsReport  += "\n  Trend:\n";
        else
        if (type == this.Dominant(Term))
          rsReport  += "\n  Term "+BoolToStr(fBarDir==DirectionUp,"Rally","Pullback")+":\n";
        else
        if (type == this.Leg(Now))
          if (type < Lead)
            rsReport+= "\n  Lead:\n";

        rsReport    +="      ("+rsSeg[type]+"): "+BoolToStr(this.Direction(type)==DirectionUp,"Long","Short");

        Append(rsReport,BoolToStr(this[type].Peg,"Peg"));
        Append(rsReport,BoolToStr(this[type].Breakout,"Breakout"));
        Append(rsReport,BoolToStr(this[type].Reversal,"Reversal"));
        Append(rsReport,BoolToStr(this[type].Correction,"Correction"));

        if (type==Trend)
        {
          rsReport   +="  Bar: "+BoolToStr(fOrigin.Bar==NoValue,IntegerToString(dOrigin.Age),IntegerToString(fOrigin.Bar));
          rsReport   +="  Top: "+DoubleToStr(this.Price(type,Top),Digits)
                      +"  Bottom: "+DoubleToStr(this.Price(type,Bottom),Digits)
                      +"  Price: "+DoubleToStr(Price(Trend,Previous),Digits)+"\n";
        }
        else
        {
          rsReport   +="  Bar: "+IntegerToString(this[type].Bar);
          rsReport   +="  (b): "+DoubleToStr(Price(type,fpBase),Digits)
                      +"  (r): "+DoubleToStr(Price(type,fpRoot),Digits)
                      +"  (e): "+DoubleToStr(Price(type,fpExpansion),Digits)+"\n";
                      
          if (f[type].TermBase>0.00)
            rsReport +="             Minor: (mb): "+DoubleToStr(f[type].TermBase,Digits)
                      +"  (mr): "+DoubleToStr(f[type].TermRoot,Digits)+"\n";
        }
        
        rsReport     +="             Retrace: "+DoubleToString(this.Fibonacci(type,Retrace,Now,InPercent),1)+"%"
                      +" "+DoubleToString(this.Fibonacci(type,Retrace,Max,InPercent),1)+"%"
                      +"  Expansion: " +DoubleToString(this.Fibonacci(type,Expansion,Now,InPercent),1)+"%"
                      +" "+DoubleToString(this.Fibonacci(type,Expansion,Max,InPercent),1)+"%"
                      +"  Leg: (c) "+DoubleToString(this.Range(type,Now,InPips),1)+" (a) "+DoubleToString(this.Range(type,Max,InPips),1)+"\n";
      };
    }
    
    if (WithEvents)
      rsReport       += "\n\nFractal "+ActiveEventText()+"\n";
    
    Comment(rsReport);
  }