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
class CFractal : public CEvent
  {

private:

       struct COriginRec
       {
         int           Direction;           //--- Origin Direction
         int           Age;                 //--- Origin Age
         FractalState  State;               //--- Derived Origin State
         double        High;                //--- Origin Short Root Price
         double        Low;                 //--- Origin Long Root Price
       };

       COriginRec      dOrigin;             //--- Derived origin data
       FractalRec      f[FractalTypes];     //--- Fractal Array

       CArrayDouble   *fBuffer;

       //--- Private fractal methods
       void            InitFractal();                          //--- initializes the fractal

       void            InsertFractal(FractalRec &Fractal);     //--- inserts a new fractal leg

       void            UpdateFractal(int Direction);           //--- Updates fractal leg direction changes
       void            UpdateRetrace(FractalType Type, int Bar, double Price=0.00);   //--- Updates interior fractal changes

       void            CalcRetrace(void);                      //--- calculates retraces on the tick
       void            CalcFractal(void);                      //--- computes the fractal on the tick
       void            CalcOrigin(void);                       //--- calculates origin derivatives on the tick
       void            CalcState(FractalType Type, FractalState &State, double EventPrice=0.00);
              
       //--- Input parameter conversions
       double          fRange;                //--- inpRange converted to points
       double          fRangeMin;             //--- inpRangeMin converted to points

       //--- Fractal leg properties
       int             fDirection;            //--- Current fractal leg direction
       int             fBars;                 //--- Count of bars in the chart
       int             fBarNow;               //--- Currently executing bar id fractal leg direction
       int             fBarHigh;              //--- Fractal top
       int             fBarLow;               //--- Fractal bottom

       double          fRetrace;              //--- Current fractal leg retrace price
       double          fRecovery;             //--- Current fractal leg retrace price
       double          fExpansion;            //--- Holds Prior Expansion for Minor Breakout Resolution

       double          fEventPrice[EventTypes];
       FiboLevel       fEventFibo[FractalTypes];

       bool            fReversal;             //--- Reversal Flag
       bool            fBreakout;             //--- Breakout Flag

       FractalType     fLegNow;               //--- Current leg state
       FractalType     fLegMax;               //--- Most recent major leg
       FractalType     fLegMin;               //--- Most recent minor leg

       FractalType     fDominantTrend;        //--- Current dominant trend; largest fractal leg
       FractalType     fDominantTerm;         //--- Current dominant term; last leg greater than RangeMax
       
       bool            fShowFlags;

public:

       //--- Fractal constructor/destructor
                       CFractal(int Range, int MinRange, bool ShowEventFlags);
                      ~CFractal(void);

       //--- Fractal refresh methods
       void             Update(void);
       void             UpdateBuffer(double &Fractal[]);

       void             RefreshScreen(bool WithEvents=false, bool LogOutput=false);
       void             RefreshFlags(void);

       int              Direction(FractalType Type=Expansion, bool Contrarian=false, int Format=InDirection);       
       double           Price(FractalType Type, FractalPoint PointType);                                //--- Returns the Price by Fractal Point       
       double           Range(FractalType Type, MeasureType Measure=Max, int Format=InDecimal);         //--- Returns the range between supplied points

       double           Fibonacci(FractalType Type, int Method, MeasureType Measure, int Format=InDecimal);                 //--- For each retrace type
       double           Forecast(FractalType Type, int Method, FiboLevel Level=FiboRoot);

       FractalState     State(FractalType Type) {return((FractalState)BoolToInt(Type==Origin,dOrigin.State,f[Type].State)); } //--- State by Fractal Type
       FractalType      Next(FractalType Type, FractalType Fractal=Divergent)
                                                        {
                                                          if (Fractal==Divergent)  return((FractalType)fmax(Origin,Type+1));
                                                          if (Fractal==Convergent) return((FractalType)fmax(Origin,Type+2));
                                                          return (Type);
                                                        }                                                 //--- enum typecast for the Next element
       FractalType      Previous(FractalType Type, FractalType Fractal=Divergent)
                                                        {
                                                          if (Fractal==Divergent)  return((FractalType)fmax(Origin,Type-1));
                                                          if (Fractal==Convergent) return((FractalType)fmax(Origin,Type-2));
                                                          return (Type);
                                                        }                                                 //--- enum typecast for the Prior element
       FractalType      Dominant(FractalType TimeRange) { if (TimeRange == Trend) return (fDominantTrend); return (fDominantTerm); }
       FractalType      Idle(int Periods=6);
       FractalType      Leg(int Measure);
       FiboLevel        EventFibo(FractalType Type)     { return ((FiboLevel)(fEventFibo[Type]-1));};

       bool             Is(FractalType Type, int State);
       
       string           FractalStr(void);
       string           PriceStr(FractalType Type=FractalTypes);
       
       FractalRec operator[](const FractalType Type) const { return(f[Type]); }
  };

//+------------------------------------------------------------------+
//| CalcOrigin - computes origin derivatives                         |
//+------------------------------------------------------------------+
void CFractal::CalcOrigin(void)
  {
    fReversal                = false;
    fBreakout                = false;

    if (Is(Origin,Convergent))
      if (Event(NewDivergence,Major))
        if (Direction(Divergent)==DirectionUp)
          dOrigin.Low        = f[Expansion].Pivot;
        else
          dOrigin.High       = f[Expansion].Pivot;

    if (Event(NewReversal,Warning))
      if (Direction(Expansion)==DirectionUp)
        dOrigin.Low          = f[Root].Pivot;
      else
        dOrigin.High         = f[Root].Pivot;

    if (IsBetween(f[Expansion].Pivot,dOrigin.High,dOrigin.Low))
      CalcState(Origin,dOrigin.State);
    else
    {
      if (IsChanged(dOrigin.Direction,f[Expansion].Direction))
      {
        dOrigin.Age          = f[Expansion].Bar;
        fReversal            = true;
      }
      else
        if (Event(NewExpansion)&&!IsEqual(dOrigin.State,Reversal))
          fBreakout          = true;

      CalcState(Origin,dOrigin.State,BoolToDouble(fReversal,Price(Origin,fpBase),BoolToDouble(fBreakout&&Event(NewReversal),Price(Origin,fpBase),fExpansion)));
    }    
  }

//+------------------------------------------------------------------+
//| CalcState - Computes Fractal States based on events/fibo locales |
//+------------------------------------------------------------------+
void CFractal::CalcState(FractalType Type, FractalState &State, double EventPrice=0.00)
  {
    FractalState state                  = NoState;
    f[Type].Event                       = NoEvent;

    //-- Handle Reversals
    if (fReversal)
      switch (Type)
      {
        case Origin:
        case Base:    state             = Reversal;
                      fReversal         = false;
                      f[Prior].Peg      = false;
                      f[Root].Peg       = false;                      
                      break;
        case Trend:
        case Term:    if (IsBetween(Price(Base,fpBase),Price(Type,fpBase),Price(Type,fpRoot)))
                        f[Type].Trap    = true;
                      else
                        state           = Reversal;
                      break;
      }
    else

    //-- Handle Breakouts
    if (fBreakout)
      switch (Type)
      {
        case Origin:
        case Base:    state             = Breakout;
                      fBreakout         = false;
                      f[Prior].Peg      = false;
                      f[Root].Peg       = false;                      
                      break;
        case Trend:
        case Term:    if (IsBetween(Price(Base,fpBase),Price(Type,fpBase),Price(Type,fpRoot)))
                        f[Type].Trap    = true;
                      else
                        state           = Breakout;
                      break;
      }
    else

    //-- Handle Recovery on Max Expansion Fractals
    if (fabs(Price(Type,fpRoot)-Price(Type,fpExpansion))>fRange)
    {
      if (IsEqual(Type,Root)||IsEqual(Type,Prior))
        {
          //-- ???
        }
      else

      if (IsBetween(Type,Origin,Base))
        if (Price(Type,fpRetrace)>0.00)
          if (Fibonacci(Type,Recovery,Min)<Percent(Fibo23))
            if (Fibonacci(Type,Retrace,Min)<Percent(Fibo23))
            {
              state                     = Recovery;
              EventPrice                = Forecast(Type,Recovery);
            }
            else
            {
              state                     = Correction;
              EventPrice                = Forecast(Type,Correction);
            }
          else
            if (Fibonacci(Type,Retrace,Max)>Percent(Fibo23))
            {
              state                     = Retrace;
              EventPrice                = Forecast(Type,Retrace,Fibo23);
            }
    }
    else
    
    //-- Handle short term bias changes  //--- Need to rethink this
    if (IsEqual(f[fLegNow].Bar,0))
    {
      if (High[fBarNow]>High[fBarNow+1])
        state                           = Rally;

      if (Low[fBarNow]<Low[fBarNow+1])
        state                           = Pullback;
    }
    else
      state                             = (FractalState)BoolToInt(IsEqual(Direction(fLegNow),DirectionUp),Rally,Pullback);

    if (NewState(State,(FractalState)BoolToInt(IsEqual(state,NoState),State,state)))
    {
      //-- Set the event price of the new state
      fEventPrice[FractalEvent(State)]  = BoolToDouble(IsEqual(EventPrice,0.00),Close[fBarNow],EventPrice);
      f[Type].Event                     = FractalEvent(State);

      //-- Set New[Origin|Trend|Term] Event
      if (IsEqual(State,Reversal))
        SetEvent(FractalEvent(Type),FractalAlert(Type));

      SetEvent(FractalEvent(State),FractalAlert(Type));
    }

    //-- Test/Reset for Expansion Fibos/Events
    if (fBreakout||fReversal||Event(NewBreakout)||Event(NewReversal)||Event(NewDivergence))
      fEventFibo[Type]                  = fmax(Level(Fibonacci(Type,Expansion,Max))+1,Fibo161);

    if (Percent(fmin(fEventFibo[Type],Fibo823))<Fibonacci(Type,Expansion,Now))
    {
      fEventFibo[Type]++;
      f[Type].Event                   = BoolToEvent(IsChanged(f[Type].Event,NewFibonacci),NewFibonacci,f[Type].Event);

      SetEvent(f[Type].Event,FractalAlert(Type));
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
      f[type].Direction           = NoDirection;
      f[type].Bar                 = NoValue;
      f[type].Pivot               = 0.00;

      if (IsEqual(type,Expansion))
        SetEvent(NewExpansion);
      else
      {
        f[type].Peg               = false;
        f[type].State             = NoState;
      }
    }

    if (IsEqual(Bar,NoValue))
      return;

    f[Type].Direction             = Direction(Type);
    f[Type].Bar                   = Bar;
    f[Type].Pivot                 = Price;

    fRetrace                      = Price;
    fRecovery                     = Price;

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
    FractalType    typemax         = Expansion;
    FractalType    typemin         = Expansion;
    FractalType    lastmax         = fLegMax;
    
    //--- calc interior retraces    
    for (FractalType type=Expansion;type<FractalTypes;type++)
    {
      if (IsEqual(Direction(type),DirectionUp))
        if (IsEqual(f[type].Bar,NoValue))
          UpdateRetrace(type,fBarNow,High[fBarNow]);
        else
        if (IsHigher(High[fBarNow],f[type].Pivot))
          UpdateRetrace(type,fBarNow,High[fBarNow]);
      
      if (IsEqual(Direction(type),DirectionDown))
        if (IsEqual(f[type].Bar,NoValue))
          UpdateRetrace(type,fBarNow,Low[fBarNow]);
        else
        if (IsLower(Low[fBarNow],f[type].Pivot))
          UpdateRetrace(type,fBarNow,Low[fBarNow]);

      if (IsHigher(fabs(f[Previous(type)].Pivot-f[type].Pivot),fRange,NoUpdate))
      {
        if (type>Expansion)
          f[Previous(type)].Peg = true;

        typemax                 = type;
        typemin                 = type;
      }
      else
      if (IsBetween(fabs(f[Previous(type)].Pivot-f[type].Pivot),fRange,fRangeMin))
        typemin                 = type;

      if (IsEqual(f[type].Bar,fBarNow)||IsEqual(type,Lead))
      {
        if (IsChanged(fLegNow,type))
          SetEvent(NewBoundary,Nominal);

        if (IsEqual(Direction(fLegNow),DirectionUp))
          if (IsLower(Close[fBarNow],fRetrace))
            fRecovery           = fRetrace;
          else
            fRecovery           = fmax(fRecovery,Close[fBarNow]);

        if (IsEqual(Direction(fLegNow),DirectionDown))
          if (IsHigher(Close[fBarNow],fRetrace))
            fRecovery           = fRetrace;
          else
            fRecovery           = fmin(fRecovery,Close[fBarNow]);

        break;
      }
    }

    //--- Calc fractal change events
    if (IsChanged(fLegMin,typemin))
      SetEvent(NewBoundary,Minor);
      
    if (IsChanged(fLegMax,typemax))
    {
      SetEvent(NewBoundary,Major);

      if (IsEqual(fLegMax,Divergent))
        if (IsEqual(lastmax,Inversion))
          SetEvent(NewDivergence,Critical);
        else
          SetEvent(NewDivergence,Major);

      if (IsEqual(fLegMax,Convergent))
        if (IsEqual(lastmax,Conversion))
          SetEvent(NewConvergence,Critical);
        else
          SetEvent(NewConvergence,Major);
    }
  }

  
//+------------------------------------------------------------------+
//| InsertFractal - inserts a new fractal node                       |
//+------------------------------------------------------------------+
void CFractal::InsertFractal(FractalRec &Fractal)
  {
    Fractal.Peg            = false;
    Fractal.Trap           = false;
        
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
      fReversal                = true;
    else
    {
      InsertFractal(f[Convergent]);
      
      f[Root].Peg              = true;
      fBreakout                = true;
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
        f[Root].Pivot         = Low[fBarLow];

        f[Expansion].Bar      = fBarHigh;
        f[Expansion].Pivot    = High[fBarHigh];

        dOrigin.Low           = Low[fBarLow];
        dOrigin.High          = dOrigin.Low+fRange;
      }

      if (fBarHigh>fBarLow)
      {
        fDirection            = DirectionDown;

        f[Root].Bar           = fBarHigh;
        f[Root].Pivot         = High[fBarHigh];

        f[Expansion].Bar      = fBarLow;
        f[Expansion].Pivot    = Low[fBarLow];

        dOrigin.High          = High[fBarHigh];
        dOrigin.Low           = dOrigin.High-fRange;
      }

      dOrigin.Age             = 0;
      dOrigin.Direction       = fDirection;

      f[Root].Direction       = Direction(fDirection,InDirection,InContrarian);
      f[Expansion].Direction  = fDirection;

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
    
    //--- reset Events on the tick
    ClearEvents();
    
    ArrayInitialize(fEventPrice,0.00);
    
    fReversal             = false;
    fBreakout             = false;
    fExpansion            = Price(Base,fpExpansion);

    //--- identify new high or new low
    if (NormalizeDouble(High[fBarNow],Digits)>NormalizeDouble(High[fBarHigh],Digits))
      fBarHigh            = fBarNow;
          
    if (NormalizeDouble(Low[fBarNow],Digits)<NormalizeDouble(Low[fBarLow],Digits))
      fBarLow             = fBarNow;

    //--- Initialized on First Max Range; Expansion.Bar is never unset once Initialized
    if (IsEqual(f[Expansion].Bar,NoValue))
      InitFractal();
    else

    //--- Handle directional events
    {
      //--- Handle uptrends
      if (IsEqual(fDirection,DirectionUp))
      {
        //--- Check trend continuation
        if (IsEqual(fBarHigh,fBarNow))
        {            
          if (f[Expansion].Peg)
          {
            fBuffer.SetValue(f[Divergent].Bar,f[Divergent].Pivot);
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
        if (IsEqual(fBarLow,fBarNow))
        {
          fBuffer.SetValue(fBarNow,Low[fBarNow]);
          UpdateFractal(DirectionDown);
        }
      }
      else

      //--- Handle down-trends
      if (IsEqual(fDirection,DirectionDown))
      {
        //--- Check trend continuation
        if (IsEqual(fBarLow,fBarNow))
        {
          if (f[Expansion].Peg)
          {
            fBuffer.SetValue(f[Divergent].Bar,f[Divergent].Pivot);
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
        if (IsEqual(fBarHigh,fBarNow))
        {
          fBuffer.SetValue(fBarNow,High[fBarNow]);

          UpdateFractal(DirectionUp);
        }
      }

      //--- Calc retrace & state
      CalcRetrace();

      for (FractalType type=Trend;type<FractalTypes;type++)
        if (f[type].Bar>NoValue)
          CalcState(type,f[type].State,BoolToDouble(fBreakout,fExpansion,BoolToDouble(fReversal,Price(Base,fpBase))));
    }
  }
    
//+------------------------------------------------------------------+
//| CFractal - class constructor                                     |
//+------------------------------------------------------------------+
CFractal::CFractal(int Range, int MinRange, bool ShowEventFlags)
  {
    fDirection              = NoDirection;
    fLegMax                 = Expansion;
    fLegMin                 = Expansion;

    fRange                  = point(Range);
    fRangeMin               = point(MinRange);

    fBarHigh                = Bars-1;
    fBarLow                 = Bars-1;
    fBars                   = Bars;

    fShowFlags              = ShowEventFlags;

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

    //-- Initialize Fibo Alerts
    ArrayInitialize(fEventFibo,Fibo161);

    f[Expansion].Peg        = false;

    dOrigin.Age             = NoValue;
    dOrigin.Direction       = NoDirection;

    //-- Load History
    for (fBarNow=Bars-1; fBarNow>0; fBarNow--)
    {
      CalcFractal();
      CalcOrigin();
      
      RefreshFlags();
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CFractal::~CFractal(void)
  {
    delete fBuffer;
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
    CalcOrigin();

    RefreshFlags();
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
//| Idle - Returns first idle Fractal Type based on supplied periods |
//+------------------------------------------------------------------+
FractalType CFractal::Idle(int Periods=6)
  {
    for (FractalType type=Lead;type>Origin;type--)
      if (f[type].Bar>=Periods)
        return (type);

    return (Origin);
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
      case Now:     return (fLegNow);
    }

    return (FractalTypes);
  }

//+------------------------------------------------------------------+
//| Is - True if Type is in supplied State                           |
//+------------------------------------------------------------------+
bool CFractal::Is(FractalType Type, int State)
  { 
    switch (Type)
    {
      case Origin:       switch (State)
                         {
                           case Divergent:     return (dOrigin.Direction!=f[Expansion].Direction);
                           case Convergent:    return (dOrigin.Direction==f[Expansion].Direction);
                           default:            return (true);
                         }
                         break;
      case FractalTypes: return (false);
      default:           switch (State)
                         {
                           case Divergent:     return (Direction(Type)!=f[Expansion].Direction);
                           case Convergent:    return (Direction(Type)==f[Expansion].Direction);
                           case Max:           return (fLegMax>=Type);
                           case Min:           return (fLegMin>=Type);
                         }
    }

    return (false);
  }

//+------------------------------------------------------------------+
//| Price - Returns the Price by Fractal Point                       |
//+------------------------------------------------------------------+
double CFractal::Price(FractalType Type, FractalPoint FP)
  {
    if (Type==Origin)
      switch (FP)
      {
        case fpOrigin:
        case fpRoot:      return (BoolToDouble(dOrigin.Direction==DirectionUp,dOrigin.Low,dOrigin.High,Digits));
        case fpBase:      return (BoolToDouble(dOrigin.Direction==DirectionUp,dOrigin.High,dOrigin.Low,Digits));
        case fpExpansion: return (BoolToDouble(Is(Origin,Divergent),Price(Origin,fpBase),f[Expansion].Pivot,Digits));
        case fpRetrace:   return (BoolToDouble(Is(Origin,Divergent),f[Expansion].Pivot,Price(Divergent,fpBase),Digits));
        case fpRecovery:  return (BoolToDouble(Is(Origin,Divergent),Price(Divergent,fpBase),Price(Convergent,fpBase),Digits));
      }
    else
    if (Type==Prior)  //-- Handle Invergent Geometric Fractals
    {
      switch (FP)
      {
        case fpOrigin:    return (BoolToDouble(IsEqual(f[Term].Pivot,0.00),f[Root].Pivot,f[Term].Pivot,Digits));
        case fpBase:      return (NormalizeDouble(f[Prior].Pivot,Digits));
        case fpRoot:      return (NormalizeDouble(f[Expansion].Pivot,Digits));
        case fpExpansion: return (NormalizeDouble(Price(Divergent,fpBase),Digits));
        case fpRetrace:   return (NormalizeDouble(Price(Convergent,fpBase),Digits));
        case fpRecovery:  return (NormalizeDouble(Price(Inversion,fpBase),Digits));
      }
    }
    else
    if (Type<=Base) //-- Handle Convergent Geometric Fractals
    {
      switch (FP)
      {
        case fpOrigin:    return (BoolToDouble(Type==Base,f[Prior].Pivot,Price(Trend,fpRoot),Digits));
        case fpBase:      switch (Type)
                          {
                            case Trend:   if (!IsEqual(f[Origin].Pivot,0.00)) return(NormalizeDouble(f[Origin].Pivot,Digits));
                            case Term:    if (!IsEqual(f[Term].Pivot,0.00))   return(NormalizeDouble(f[Term].Pivot,Digits));
                          }
                          return(NormalizeDouble(f[Base].Pivot,Digits));
        case fpRoot:      if (Direction(Type)==DirectionDown)
                          {
                            if (Type==Trend) return (NormalizeDouble(fmax(f[Trend].Pivot,fmax(f[Prior].Pivot,f[Root].Pivot)),Digits));
                            if (Type==Term)  return (NormalizeDouble(fmax(f[Prior].Pivot,f[Root].Pivot),Digits));
                          }
                          else
                          if (Direction(Type)==DirectionUp)
                          {
                            if (Type==Trend) return (BoolToDouble(IsEqual(f[Trend].Pivot,0,00),Price(Term,fpRoot),fmin(f[Trend].Pivot,Price(Term,fpRoot)),Digits));
                            if (Type==Term)  return (BoolToDouble(IsEqual(f[Prior].Pivot,0.00),f[Root].Pivot,fmin(f[Prior].Pivot,f[Root].Pivot),Digits));
                          }
                          return (NormalizeDouble(f[Root].Pivot,Digits));
        case fpExpansion: return (NormalizeDouble(f[Expansion].Pivot,Digits));
        case fpRetrace:   return (NormalizeDouble(Price(Divergent,fpBase),Digits));
        case fpRecovery:  return (NormalizeDouble(Price(Convergent,fpBase),Digits));
      }
    }
    else //-- Handle Linear Fractals
    {
      FractalType  type = Previous(Type);
      FractalPoint fp   = fpOrigin;
      
      int  next         = 0;
 
      while (fp<FractalPoints)
      {
        if (IsEqual(f[type].Bar,NoValue))
          next++;

        if (IsEqual(fp,FP))
          switch (next)
          {
            case 0:  return (NormalizeDouble(f[type].Pivot,Digits));
            case 1:  return (NormalizeDouble(fRetrace,Digits));
            case 2:  return (NormalizeDouble(fRecovery,Digits));
            default: return (NormalizeDouble(Close[fBarNow],Digits));
          }
          
        if (type<Lead)
          type++;
        else
          next         += BoolToInt(IsEqual(f[Lead].Bar,NoValue),0,1);

        fp++;
      }
    }

    return (NormalizeDouble(0.00,Digits));
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
      dDirection           = Direction(fDirection,InDirection,InContrarian);

    if (Contrarian)
      dDirection          *= Direction(fDirection,InDirection,InContrarian);

    if (Format==InAction)
      switch(dDirection)
      {
        case DirectionUp:    return (OP_BUY);
        case DirectionDown:  return (OP_SELL);
        case NoDirection:    return (NoAction);
      }

    return (dDirection);
  }

//+------------------------------------------------------------------+
//| Range - Returns the leg (Base-Root) Range for supplied Measure   |
//+------------------------------------------------------------------+
double CFractal::Range(FractalType Type, MeasureType Measure=Max, int Format=InDecimal)
  {
    double range            = 0.00;

    if (IsEqual(Price(Type,fpRoot),0.00,Digits)||IsEqual(Price(Type,fpExpansion),0.00,Digits))
      return (NormalizeDouble(0.00,Digits));

    switch (Measure)
    {
      case Now:      range  = Price(Type,fpRoot)-Close[fBarNow];
                     break;
      case Max:      range  = Price(Type,fpRoot)-Price(Type,fpExpansion);
                     break;
    }

    if (Format==InDecimal) return (NormalizeDouble(fabs(range),Digits));
    if (Format==InPips)    return (pip(fabs(range)));

    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Fibonacci - Calcuates fibo % for supplied type Type and Method   |
//+------------------------------------------------------------------+
double CFractal::Fibonacci(FractalType Type, int Method, MeasureType Measure, int Format=InDecimal)
  { 
    switch (Method)
    {
      case Expansion: switch (Measure)
                      {
                        case Now: return(fdiv(Close[fBarNow]-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot),8)*BoolToInt(Format==InDecimal,1,100));
                        case Max: return(fdiv(Price(Type,fpExpansion)-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot))*BoolToInt(Format==InDecimal,1,100));
                        case Min: return(fdiv(Price(Type,fpRetrace)-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot))*BoolToInt(Format==InDecimal,1,100));
                      }
                      break;

      case Retrace:   switch (Measure)
                      {
                        case Now: return(fdiv(Close[fBarNow]-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                        case Max: return(fdiv(Price(Type,fpRetrace)-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                        case Min: return(fdiv(Price(Type,fpRecovery)-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                      }
                      break;

      case Recovery:  switch (Measure)
                      {
                        case Now: return(fdiv(Price(Type,fpRoot)-Close[fBarNow],Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                        case Max: return(fdiv(Price(Type,fpRoot)-Price(Type,fpRecovery),Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));
                        case Min: return(fdiv(Price(Type,fpRoot)-Price(Type,fpRetrace),Price(Type,fpRoot)-Price(Type,fpExpansion))*BoolToInt(Format==InDecimal,1,100));                        
                      }
                      break;
    }  

    return (NormalizeDouble(0.00,3));
  }

//+------------------------------------------------------------------+
//| Forecast - Returns Forecast Price for supplied Fibo              |
//+------------------------------------------------------------------+
double CFractal::Forecast(FractalType Type, int Method, FiboLevel Level=FiboRoot)
  {
    switch (Method)
    {
      case Expansion:   return(NormalizeDouble(Price(Type,fpRoot)+((Price(Type,fpBase)-Price(Type,fpRoot))*Percent(Level)),Digits));
      case Retrace:     return(NormalizeDouble(Price(Type,fpExpansion)+((Price(Type,fpRoot)-Price(Type,fpExpansion))*Percent(Level)),Digits));
      case Correction:  return(NormalizeDouble(Price(Type,fpExpansion)+((Price(Type,fpRoot)-Price(Type,fpExpansion))*FiboCorrection),Digits));
      case Recovery:    return(NormalizeDouble(Price(Type,fpExpansion)+((Price(Type,fpRoot)-Price(Type,fpExpansion))*FiboRecovery),Digits));
    }

    return (NormalizeDouble(0.00,Digits));
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns formatted Fractal price                     |
//+------------------------------------------------------------------+
string CFractal::FractalStr(void)
  {
    string text    = "\n";

    for (FractalType type=Origin;type<FractalTypes;type++)
    {
      Append(text,EnumToString(type)+"/"+DirText(Direction(type))+":"+EnumToString(f[type].State));
      Append(text,DoubleToStr(f[type].Pivot,Digits)+"]","[");
    }

    Append(text,"\n","");

    return (text);
  }

//+------------------------------------------------------------------+
//| PriceStr - Returns formatted Fractal Points using Price()        |
//+------------------------------------------------------------------+
string CFractal::PriceStr(FractalType Type=FractalTypes)
  {
    string text    = "\n";
    
    for (FractalType type=Origin;type<FractalTypes;type++)
    {
      if (IsEqual(Type,FractalTypes)||IsEqual(type,Type))
      {      
        Append(text,EnumToString(type)+"/"+DirText(Direction(type)));
        Append(text,BoolToStr(IsEqual(fBarNow,0),"",IntegerToString(fBarNow,5,'-')+"]"),"[");
      
        for (FractalPoint fp=fpOrigin;fp<FractalPoints;fp++)
          Append(text,EnumToString(fp)+":"+DoubleToStr(Price(type,fp),Digits)+"]","[");

        if (Is(Type,Max))
        {
          Append(text,"Forecasts");
          Append(text,"Correction:"+DoubleToStr(Forecast(type,Recovery,Fibo23),Digits)+"]","[");          
          Append(text,"Recovery:"+DoubleToStr(Forecast(type,Retrace,Fibo23),Digits)+"]","[");          
        }

        Append(text,"\n","");
      }

      if (IsEqual(type,Type))
        break;
    }

    return (text);
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

    rsReport   += "\n  Origin:"+BoolToStr(f[Origin].Trap,"Trap")+"\n";
    rsReport   +="      (o): "+BoolToStr(dOrigin.Direction==DirectionUp,"Long","Short");

    Append(rsReport,BoolToStr(Is(Origin,Divergent),"Divergent","Convergent"));
    Append(rsReport,EnumToString(dOrigin.State));

    rsReport  +="  Bar: "+IntegerToString(f[Origin].Bar)
               +"  Age: "+IntegerToString(dOrigin.Age)+"\n";

    rsReport  +="             Fractal:";

    for (FractalPoint fp=fpOrigin;fp<FractalPoints;fp++)
      if (Price(Origin,fp)>0.00)
        Append(rsReport," ("+rsFP[fp]+"): "+DoubleToStr(Price(Origin,fp),Digits));

    rsReport  +="\n";
    rsReport  +="             Retrace: "+DoubleToString(Fibonacci(Origin,Retrace,Now,InPercent),1)+"%"
               +" "+DoubleToString(Fibonacci(Origin,Retrace,Max,InPercent),1)+"%"
               +"  Leg: (c) "+DoubleToString(fabs(pip(Price(Origin,fpExpansion)-Close[fBarNow])),1)
               +" (m) "+DoubleToString(fabs(pip(Price(Origin,fpExpansion)-Price(Origin,fpRetrace))),1)+"\n";

    rsReport  +="             Expansion: " +DoubleToString(Fibonacci(Origin,Expansion,Now,InPercent),1)+"%"
               +" "+DoubleToString(Fibonacci(Origin,Expansion,Max,InPercent),1)+"%"
               +"  Leg: (c) "+DoubleToString(fabs(pip(Price(Origin,fpRoot)-Close[fBarNow])),1)
               +" (a) "+DoubleToString(fabs(pip(Price(Origin,fpRoot)-Price(Origin,fpBase))),1)
               +" (m) "+DoubleToString(fabs(pip(Price(Origin,fpRoot)-Price(Origin,fpExpansion))),1)+"\n";
      
    for (FractalType type=Trend;type<=fLegNow;type++)
    {
      if (f[type].Bar>NoValue)
      {
        if (type == Dominant(Trend))
          rsReport  += "\n  Trend "+EnumToString(f[Trend].State)+":"+BoolToStr(f[Trend].Trap,"Trap")+"\n";
        else
        if (type == Dominant(Term))
          rsReport  += "\n  Term "+EnumToString(f[Term].State)+":"+BoolToStr(f[Term].Trap,"Trap")+"\n";
        else
        if (type == fLegNow)
          if (type < Lead)
            rsReport+= "\n  Lead:\n";

        rsReport    +="      ("+rsSeg[type]+"): "+BoolToStr(this.Direction(type)==DirectionUp,"Long","Short");

        Append(rsReport,BoolToStr(f[type].Peg,"Peg"));
        Append(rsReport,EnumToString(f[type].State));

        rsReport   +="  Bar: "+IntegerToString(f[type].Bar)+"\n";
        
        rsReport   +="             Fractal:";
        for (FractalPoint fp=fpOrigin;fp<FractalPoints;fp++)
          if (Price(type,fp)>0.00)
            Append(rsReport," ("+rsFP[fp]+"): "+DoubleToStr(Price(type,fp),Digits));
        
        rsReport  +="\n";
        rsReport  +="             Retrace: "+DoubleToString(Fibonacci(type,Retrace,Now,InPercent),1)+"%"
                   +" "+DoubleToString(Fibonacci(type,Retrace,Max,InPercent),1)+"%"
                   +"  Expansion: " +DoubleToString(Fibonacci(type,Expansion,Now,InPercent),1)+"%"
                   +" "+DoubleToString(Fibonacci(type,Expansion,Max,InPercent),1)+"%"
                   +"  Leg: (c) "+DoubleToString(Range(type,Now,InPips),1)+" (a) "+DoubleToString(Range(type,Max,InPips),1)+"\n";
      };
    }
    
    if (WithEvents)
      rsReport       += "\n\nFractal "+ActiveEventStr()+"\n";
    
    if (LogOutput)
    {
      Print (rsLastReport);
      Print (rsReport);
    }
    
    rsLastReport    = rsReport;

    Comment(rsReport);
  }

//+------------------------------------------------------------------+
//| RefreshFlags - Paints Fractal Event Flags                        |
//+------------------------------------------------------------------+
void CFractal::RefreshFlags(void)
  {
    bool  event[EventTypes];
    const color fractal[FractalTypes]   = {clrYellow,C'255,0,0',C'195,0,0',clrDarkGray,C'135,0,0',clrDarkGray,clrYellow,clrGoldenrod,clrSteelBlue,clrForestGreen,clrNavy,clrNONE};

    ArrayInitialize(event,false);
      
    for (FractalType type=Origin;type<FractalTypes;type++)
      if (f[type].Event!=NoEvent)
      {
        if (Event(FractalEvent(type)))
          if (Event(NewReversal)&&IsChanged(event[NewReversal],true))
            Flag("[fr3]["+IntegerToString(fBarNow,5,'-')+"]New "+EnumToString(type)+"[Reversal]",fractal[type],fBarNow,fEventPrice[NewReversal],fShowFlags,OBJ_ARROW_RIGHT_PRICE);

        if (IsEqual(State(type),Breakout))
          if (Event(NewBreakout)&&IsChanged(event[NewBreakout],true))
            Flag("[fr3]["+IntegerToString(fBarNow,5,'-')+"]New "+EnumToString(type)+"[Breakout]",fractal[type],fBarNow,fEventPrice[NewBreakout],fShowFlags,OBJ_ARROW_RIGHT_PRICE);

        if (IsEqual(State(type),Correction))
          if (Event(NewCorrection)&&IsChanged(event[NewCorrection],true))
             Flag("[fr3]["+IntegerToString(fBarNow,5,'-')+"]"+EnumToString(type)+"[Correction]",fractal[type],fBarNow,fEventPrice[NewCorrection],fShowFlags,OBJ_ARROW_RIGHT_PRICE);

//        if (Event(NewFibonacci))
//          if (f[type].Event==NewFibonacci)
//            Flag("[fr3]"+EnumToString(type)+" "+EnumToString(EventFibo(type)),fractal[type],fBarNow,Forecast(type,Expansion,EventFibo(type)),true);
//
        //if (IsEqual(State(type),Recovery))
        //  if (Event(NewRecovery)&&IsChanged(event[NewRecovery],true))
        //     Flag("[fr3]["+IntegerToString(fBarNow,5,'-')+"]"+EnumToString(type)+"[Recovery]",segment[type],fShowFlags,fBarNow,fEventPrice[NewRecovery]);
      }
  }
