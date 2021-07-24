//+------------------------------------------------------------------+
//|                                                   PipFractal.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipRegression.mqh>

//+------------------------------------------------------------------+
//| PipFractal: Fractal Class derived from Poly(6) trend algorithm   |
//+------------------------------------------------------------------+
class CPipFractal : public CPipRegression
  {

    protected:
    
         enum       PipFractalType
                    {
                      pftOrigin,
                      pftTrend,
                      pftTerm,
                      PipFractalTypes
                    };

    
         //--- Fractal State Rec
         struct     StateRec
                    {
                      int              Direction;                //--- Consolidated Direction
                      RetraceType      Bearing;                  //--- Trend Convergence/Divergence
                      ReservedWords    Type[PipFractalTypes];    //--- Current States by Type
                      int              Action;                   //--- Current Term Action
                      double           Speed;                    //--- Term v. Origin traversal speed
                      string           Condition;                //--- Term Condition {0,1,2,D,C};
                      PipFractalType   Trap;                     //--- Trap Flag
                      int              Bias;                     //--- Consolidation Action
                      double           High;                     //--- Consolidation High
                      double           Low;                      //--- Consolidation Low
                    };


         //--- Fractal Age
         struct     FractalAgeRec
                    {
                      int              Expansion;
                      int              Root;
                    };
                
         //--- Fractal point data
         struct     PipFractalRec
                    {
                      FractalAgeRec    Age;                      //--- Age in periods
                      int              Direction;                //--- fractal direction
                      double           Base;                     //--- base fp
                      double           Root;                     //--- root fp
                      double           Expansion;                //--- expansion fp
                      double           Retrace;                  //--- retrace fp
                      double           Recovery;                 //--- recovery fp
                    };

         PipFractalRec pf[PipFractalTypes];
         StateRec      sr;


    private:
          //--- Data arrays
          double         pfMap[];
          int            pfPattern;                 //--- Test Key
          
          //--- Operational Bar variables
          int            pfBar;                             //--- Bar now processing
          int            pfBars;                            //--- Total Bars in Chart
          
          int            pfTicks;                           //--- Ticks in current direction
          int            pfPivots;                          //--- Term pivot count
          double         pfTermHi;                          //--- Term hi/lo root price
          double         pfTermLo;                          //--- Term hi/lo root price
          
          //--- Operational flags
          bool           pfTerm100;                         //--- Term fibo 100 switch
          bool           pfTerm161;                         //--- Term fibo 161 switch
          bool           pfReversal;                        //--- Set on Trend Reversals
          

          //--- Display flag operationals
          string         arrowName;
          int            arrowIdx;
          
          //--- Internal use methods
          void           UpdateState(void);                         //--- Update Fractal States
          void           UpdateRetrace(PipFractalType Type);        //--- Update Retrace by Type
          void           UpdateTerm(int Direction, double Price);   //--- Updates Term Fractal on change
          void           UpdateTrend(void);                         //--- Updates Trend Fractal on change
          void           UpdateOrigin(void);                        //--- Updates Origin Fractal on change
          void           UpdateNodes(void);
          

    public:
                         CPipFractal(int Degree, int Periods, double Tolerance, double AggFactor, int IdleTime);
                        ~CPipFractal();
                             
       PipFractalRec     operator[](const PipFractalType Type) const {return(pf[Type]);};

       virtual
          void           UpdateBuffer(double &MA[], double &PolyBuffer[], double &TrendBuffer[]);
       
       virtual
          void           Update(void);                      //--- Update method; updates fractal data
          
          //--- Fractal Properties
       virtual
          int            Direction(int Type, bool Contrarian=false);

          int            Count(const ReservedWords Measure);
          StateRec       State(void) const {return(sr);};
          string         StateText(void);

          double         Price(PipFractalType Type, int Measure=Expansion);
          double         Fibonacci(PipFractalType Type, int Method, int Measure, int Format=InDecimal);
          
          void           RefreshScreen(void);
          void           ShowFiboArrow(void);
  };

//+------------------------------------------------------------------+
//| UpdateState - Computes Fractal state conditions                  |
//+------------------------------------------------------------------+
void CPipFractal::UpdateState(void)
  {
    int    usLastState      = sr.Type[pftOrigin];
    int    usLastPattern    = pfPattern;
    int    usLastTrap       = sr.Trap;
    
    //-- Compute States By Type
    if (Event(NewTrend))
      sr.Type[pftTrend]     = BoolToWord(pfReversal,Reversal,Breakout);
          
    sr.Type[pftTerm]        = BoolToWord(Fibonacci(pftTerm,Expansion,Max)>=1,
                                BoolToWord(Direction(pftTerm)==Direction(pftTrend),sr.Type[pftTrend],Reversal),
                                BoolToWord(Direction(pftTerm)==DirectionUp,Rally,Pullback));

    if (Fibonacci(pftOrigin,Expansion,Min)<FiboPercent(Fibo23))
    {
      if (Fibonacci(pftOrigin,Retrace,Now)<FiboPercent(Fibo23))
        sr.Type[pftOrigin]  = Recovery;

      if (Fibonacci(pftOrigin,Expansion,Now)<FiboPercent(Fibo23))
        sr.Type[pftOrigin]  = Correction;
      
      if (Fibonacci(pftTerm,Expansion,Max)>FiboPercent(Fibo161)&&
          Fibonacci(pftOrigin,Expansion,Min)<FiboPercent(FiboRoot))
        sr.Type[pftOrigin]  = Reversal;
    }
    else
    if (Fibonacci(pftOrigin,Retrace,Max)>FiboPercent(Fibo23)||
       (Event(NewTerm)&&Direction(pftOrigin)!=Direction(pftTerm)))
      sr.Type[pftOrigin]    = Retrace;
    else
    if (IsEqual(Fibonacci(pftOrigin,Retrace,Now),FiboPercent(FiboRoot),3))
      sr.Type[pftOrigin]    = Breakout;
    
    sr.Bearing              = (RetraceType)BoolToInt(Direction(pftOrigin)==Direction(pftTrend),Convergent,Divergent);
    sr.Action               = Action(Direction(pftTerm));
    sr.Bias                 = Action(sr.Direction);
    sr.Speed                = fabs(fdiv(pf[pftTerm].Root-pf[pftTerm].Expansion,pf[pftTerm].Root-pf[pftTerm].Expansion,3));
    sr.Trap                 = (PipFractalType)BoolToInt(IsBetween(Fibonacci(pftTerm,Expansion,Max),FiboPercent(Fibo100),FiboPercent(Fibo161)),pftTerm,NoValue);
    sr.Trap                 = (PipFractalType)BoolToInt(pfPivots==0&&sr.Type[pftOrigin]==Retrace,pftTrend,sr.Trap);
    sr.Condition            = BoolToStr(pfPivots<3,(string)pfPivots,BoolToStr(fmod(pfPivots,2)==0,"C","D"));
                                        
    pfPattern               = 0;
    
    for (PipFractalType type=0;type<PipFractalTypes;type++)
      pfPattern           += sr.Type[type]*(int)MathPow(10,2*type);
      
//    Comment("Last: "+usLastPattern+" | Now: "+pfPattern);
    
    //if (pfBar==0&&IsChanged(usLastTrap,sr.Trap))
    //{
    //  if (sr.Trap==NoValue)
    //    Flag((string)pfPattern,clrWhite,Always,pfBar);
    //  else
    //    Flag((string)pfPattern,Color(Direction(pftTerm),IN_CHART_DIR),Always,pfBar);
    //  Comment("Trap: "+BoolToStr(sr.Trap==NoValue,"No Trap",EnumToString(sr.Trap)));
    //}
    //if (/*pfBar==0&&*/IsChanged(usLastPattern,pfPattern))
    //  Flag((string)pfPattern,Color(Direction(pftTerm),IN_CHART_DIR),Always,pfBar);
    if (pfBar==0)
      if (IsChanged(usLastPattern,pfPattern))
//      if (pfPattern==545351)
      {
        NewPriceTag("t"+(string)pfPattern+":"+(string)Bars,StateText(),BoolToInt(InStr(StateText(),"Unk:"),clrDarkGray,Color(Direction(pftTerm),IN_CHART_DIR)));
        UpdatePriceTag("t"+(string)pfPattern+":"+(string)Bars,0,Direction(pftTerm),0,0);
      }
      else
      if (IsChanged(usLastTrap,sr.Trap))
        if (sr.Trap==NoValue)
        {
          NewPriceTag("end"+(string)Bars,"[C]",clrRed);
          UpdatePriceTag("end"+(string)Bars,0,Direction(pftTerm),0,0);
        }
        else
        {
          NewPriceTag("trap"+(string)Bars,"[T]");
          UpdatePriceTag("trap"+(string)Bars,0,Direction(pftTerm),0,0);
        }
      //Pause("Pattern identified: "+(string)pfPattern+"\n"+StateText()+"\n"+
      //      "(o) "+EnumToString(sr.Type[pftOrigin])+" (tr) "+EnumToString(sr.Type[pftTrend])+" (tm) "+EnumToString(sr.Type[pftTerm])+"\n"+
      //             EnumToString(sr.Bearing)+" "+ActionText(sr.Action)+"("+(string)pfPivots+") "+BoolToStr(sr.Trap>NoValue,":Trap"),"Pattern Analysis");
//    if (IsChanged(usLastPattern,pfPattern))
//      Print(TimeToStr(Time[pfBar])+"|"+pfPattern);

    //if (pfBar==0&&Event(NewTrend))
    //  Pause("New Trend", "Event(NewTrend) Test");    
    //if (IsChanged(usLastState,pf[pftOrigin].State))
    //  Pause("New Origin State: "+EnumToString(pf[pftOrigin].State)+"\n"+
    //          StateText()+"\n"+
    //          pfPattern+": (o) "+EnumToString(pf[pftOrigin].State)+" (tr) "+EnumToString(pf[pftTrend].State)+" (tm) "+EnumToString(pf[pftTerm].State),
    //          "OriginState() Test");      
  }

//+------------------------------------------------------------------+
//| UpdateRetrace - updates retrace data based on supplied type      |
//+------------------------------------------------------------------+
void CPipFractal::UpdateRetrace(PipFractalType Type)
  {    
    if (IsChanged(pf[Type].Retrace,BoolToDouble(pf[Type].Direction==DirectionUp,
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),pf[Type].Retrace),
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),pf[Type].Retrace),Digits)))
    {
      pf[Type].Recovery = pf[Type].Retrace;

      SetEvent(NewRetrace,Minor);
    }
    else
      pf[Type].Recovery = BoolToDouble(pf[Type].Direction==DirectionUp,
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),pf[Type].Recovery),
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),pf[Type].Recovery),Digits);
                           
    if (IsChanged(pf[Type].Expansion,BoolToDouble(Direction(Type)==DirectionUp,
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),pf[Type].Expansion),
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),pf[Type].Expansion),Digits)))
    {
      pf[Type].Age.Expansion     = pfBar;
      pf[Type].Retrace           = pf[Type].Expansion;
      pf[Type].Recovery          = pf[Type].Expansion;

      SetEvent(NewExpansion,(AlertLevelType)BoolToInt(Type==pftTerm,Minor,BoolToInt(Type==pftTrend,Major,Critical)));
    }                           
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - updates Origin fractal data                       |
//+------------------------------------------------------------------+
void CPipFractal::UpdateOrigin(void)
  {
    if (pfReversal)
    {
      if (NewDirection(pf[pftOrigin].Direction,pf[pftTrend].Direction))
        SetEvent(NewOrigin,Critical);

      pf[pftOrigin].Root         = pf[pftTrend].Root;
    }
    
    pf[pftOrigin].Base           = pf[pftTrend].Expansion;
    pf[pftOrigin].Retrace        = pf[pftTerm].Expansion;
    pf[pftOrigin].Recovery       = pf[pftTerm].Expansion;
      
    pf[pftOrigin].Expansion      = BoolToDouble(Direction(pftOrigin)==DirectionUp,
                                     fmax(pf[pftOrigin].Expansion,pf[pftTrend].Expansion),
                                     fmin(pf[pftOrigin].Expansion,pf[pftTrend].Expansion),Digits);
  }

//+------------------------------------------------------------------+
//| UpdateTrend - updates Trend fractal data                         |
//+------------------------------------------------------------------+
void CPipFractal::UpdateTrend(void)
  {
    pfReversal                  = NewDirection(pf[pftTrend].Direction,pf[pftTerm].Direction);
    pfPivots                    = 0;
    
    pf[pftTrend].Age.Root       = pf[pftTrend].Age.Expansion;
    pf[pftTrend].Age.Expansion  = pfBar;
    pf[pftTrend].Base           = Fibonacci(pftTerm,Forecast|Expansion,Fibo161);
    pf[pftTrend].Root           = BoolToDouble(Direction(pftTrend)==DirectionUp,pfTermLo,pfTermHi,Digits);

    pf[pftTrend].Expansion      = pf[pftTerm].Expansion;
    pf[pftTrend].Retrace        = pf[pftTerm].Expansion;
    pf[pftTrend].Recovery       = pf[pftTerm].Expansion;
    
    sr.Direction                = Direction(pftTrend);

    if (sr.Direction==DirectionDown)
      sr.High                   = pfTermHi;
    else
      sr.Low                    = pfTermLo;

    SetEvent(NewTrend,Major);
  }

//+------------------------------------------------------------------+
//| UpdateTerm - updates Term fractal data                           |
//+------------------------------------------------------------------+
void CPipFractal::UpdateTerm(int Direction, double Price)
  {
//    ClearEvent(NewExpansion);  -- history load issue: Bar 1 on Expansion sets retrace to HIGH[pfBar]; s/b untouched.
    
    if (NewDirection(pf[pftTerm].Direction,Direction))
    {
      pf[pftTerm].Age.Root       = pf[pftTerm].Age.Expansion;
      pf[pftTerm].Base           = pf[pftTerm].Root;
      pf[pftTerm].Root           = pf[pftTerm].Expansion;
      pf[pftTerm].Expansion      = pf[pftTerm].Retrace;
      pf[pftTerm].Retrace        = pf[pftTerm].Recovery;
      pf[pftTerm].Recovery       = Price;
      
      if (IsChanged(pfTerm161,false))
      {
        pfTermHi                 = pf[pftTerm].Root;
        pfTermLo                 = pf[pftTerm].Root;
        
        SetEvent(NewOrigin,Major);
      }

      pfTermHi                   = fmax(pfTermHi,pf[pftTerm].Root);
      pfTermLo                   = fmin(pfTermLo,pf[pftTerm].Root);

      if (IsChanged(pfTerm100,false))
        if (sr.Direction==DirectionUp)
          sr.High                = pf[pftTerm].Root;
        else
          sr.Low                 = pf[pftTerm].Root;

      pfPivots++;
      
      SetEvent(NewTerm,Minor);
    }
  }

//+------------------------------------------------------------------+
//| UpdateNodes - updates fractal nodes                              |
//+------------------------------------------------------------------+
void CPipFractal::UpdateNodes(void)
  {
    static int unTickDir    = 0;
    
    //--- Clear fractal events
    ClearEvent(NewExpansion);
    ClearEvent(NewTerm);
    ClearEvent(NewTrend);
    ClearEvent(NewOrigin);

    //--- Update Tick Counter
    if (Event(NewTick))
    {
      if (IsChanged(unTickDir,Direction(Tick)))
        pfTicks                = 0;

      pfTicks++;
    }

    //--- Update Fractal Node Ages
    for (pfBars=pfBars;pfBars<Bars;pfBars++)
      for (PipFractalType type=pftOrigin;type<PipFractalTypes;type++)
      {
        pf[type].Age.Root++;
        pf[type].Age.Expansion++;
      }    

    //--- Handle Term direction changes
    if (pfBar>0&&pfMap[pfBar]>0.00)
      UpdateTerm(BoolToInt(IsEqual(pfMap[pfBar],High[pfBar]),DirectionUp,DirectionDown),pfMap[pfBar]);
    else
    if (Event(NewBoundary))
      if (IsEqual(FOC(Deviation),0.0,1))
        if (HistoryLoaded())
          UpdateTerm(BoolToInt(Event(NewHigh),DirectionUp,DirectionDown),Close[pfBar]);
        else UpdateTerm(BoolToInt(Close[pfBar]>pf[pftTerm].Root,DirectionUp,DirectionDown),Close[pfBar]);
      else UpdateTerm(BoolToInt(Event(NewHigh),DirectionUp,DirectionDown),Close[pfBar]);

    if (Fibonacci(pftTerm,Expansion,Max)>FiboPercent(Fibo100))
      if (IsChanged(pfTerm100,true))
        sr.Direction         = Direction(pftTerm);
      
    UpdateRetrace(pftTerm);
    
    //-- Manage Trend changes
    if (Fibonacci(pftTerm,Expansion,Max)>FiboPercent(Fibo161))
      if (IsChanged(pfTerm161,true))
        UpdateTrend();

    UpdateRetrace(pftTrend);    
    
    //-- Manage Origin changes
    if (EventAlert(NewOrigin,Major))
      UpdateOrigin();
      
    UpdateRetrace(pftOrigin);
    
    if (Event(NewExpansion)||Event(NewTerm))
    {
      ShowFiboArrow();
      UpdateState();
    }
  }

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPipFractal::CPipFractal(int Degree, int Periods, double Tolerance, double AggFactor, int IdleTime) : CPipRegression(Degree,Periods,Tolerance,AggFactor,IdleTime)
  {
    //-- Initialize fibo graphics
    arrowName          = "";
    arrowIdx           = 0;

    int    pfSeed      = 14;
    int    pfDir       = DirectionChange;
    
    int    pfLastHi    = NoValue;
    int    pfLastLo    = NoValue;
    int    pfHiBar     = NoValue;
    int    pfLoBar     = NoValue;

    pfBar              = 0;
    pfBars             = Bars;
    
    ArrayResize(pfMap,Bars);
    ArrayInitialize(pfMap,0.00);

    ObjectCreate("indFibo",OBJ_FIBO,0,0,0);
    ObjectSet("indFibo",OBJPROP_LEVELCOLOR,clrMaroon);
    
    //-- Build fractal map
    while (pfBar<Bars-pfSeed)
    {
      pfHiBar     = iHighest(Symbol(),Period(),MODE_HIGH,pfSeed,pfBar);
      pfLoBar     = iLowest(Symbol(),Period(),MODE_LOW,pfSeed,pfBar);
      
      if (NewDirection(pfDir,Direction(BoolToInt(pfHiBar==pfLoBar,pfDir,pfHiBar-pfLoBar),InDirection,false)))
      {
        if (pfDir==DirectionUp)
        {
          //-- Fixes outside reversals
          if (pfLastHi<iLowest(Symbol(),Period(),MODE_LOW,pfSeed+(pfBar-pfLastHi),pfLastHi))
            pfLoBar            = iLowest(Symbol(),Period(),MODE_LOW,pfSeed+(pfBar-pfLastHi),pfLastHi);
  
          pfMap[pfLoBar]       = Low[pfLoBar];
          pfLastLo             = pfLoBar;

          //-- Fixes inside reversals
          if (pfLastLo>NoValue&&pfLastHi>NoValue)
            if (iHighest(Symbol(),Period(),MODE_HIGH,pfLastLo-pfLastHi,pfLastHi)>pfLastHi)
            {
              pfMap[pfLastHi]  = 0.00;
              pfLastHi         = iHighest(Symbol(),Period(),MODE_HIGH,pfLastLo-pfLastHi,pfLastHi);
              pfMap[pfLastHi]  = High[pfLastHi];
            }
        }
        
        if (pfDir==DirectionDown)
        {
          //-- Fixes outside reversals
          if (pfLastLo<iHighest(Symbol(),Period(),MODE_HIGH,pfSeed+(pfBar-pfLastLo),pfLastLo))
            pfHiBar            = iHighest(Symbol(),Period(),MODE_HIGH,pfSeed+(pfBar-pfLastLo),pfLastLo);

          pfMap[pfHiBar]       = High[pfHiBar];
          pfLastHi             = pfHiBar;

          //-- Fixes inside reversals
          if (pfLastLo>NoValue&&pfLastHi>NoValue)
            if (iLowest(Symbol(),Period(),MODE_LOW,pfLastHi-pfLastLo,pfLastLo)>pfLastLo)
            {
              pfMap[pfLastLo]  = 0.00;
              pfLastLo         = iLowest(Symbol(),Period(),MODE_LOW,pfLastHi-pfLastLo,pfLastLo);
              pfMap[pfLastLo]  = Low[pfLastLo];
            }
        }
      }

      pfBar++;
    }

    //--- PipFractal Initialization
    pf[pftTerm].Direction          = pfDir;
    pf[pftTerm].Age.Root           = BoolToInt(pfDir==DirectionUp,pfLoBar,pfHiBar);
    pf[pftTerm].Age.Expansion      = BoolToInt(pfDir==DirectionUp,pfHiBar,pfLoBar);
    pf[pftTerm].Base               = BoolToDouble(pfDir==DirectionUp,High[pfHiBar],Low[pfLoBar]);
    pf[pftTerm].Root               = BoolToDouble(pfDir==DirectionUp,Low[pfLoBar],High[pfHiBar]);
    pf[pftTerm].Expansion          = pf[pftTerm].Base;
    pf[pftTerm].Retrace            = pf[pftTerm].Base;
    pf[pftTerm].Recovery           = pf[pftTerm].Base;
    
    pf[pftTrend]                   = pf[pftTerm];
    pf[pftOrigin]                  = pf[pftTerm];
    
    for (pfBar=Bars-1;pfBar>0;pfBar--)
      UpdateNodes();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPipFractal::~CPipFractal()
  {
  }

//+------------------------------------------------------------------+
//|  UpdateBuffer - Updates data and returns buffer                  |
//+------------------------------------------------------------------+
void CPipFractal::UpdateBuffer(double &MA[], double &PolyBuffer[], double &TrendBuffer[])
  {    
    if (HistoryLoaded())
      UpdateBuffer(PolyBuffer,TrendBuffer);
    else
    {
      CalcMA();
      CalcWave();
    }

    UpdateNodes();
    
    ArrayCopy(MA,maData,0,0,fmin(prPeriods,pipHistory.Count));
  }

//+------------------------------------------------------------------+
//| Update - Public interface to populate metrics                    |
//+------------------------------------------------------------------+
void CPipFractal::Update(void)
  {      
    if (HistoryLoaded())
    {
      UpdatePoly();
      UpdateTrendline();
    }
    else
    {
      CalcMA();
      CalcWave();      
    }

    UpdateNodes();
  }

//+------------------------------------------------------------------+
//| Price - Returns the price of the specified measure               |
//+------------------------------------------------------------------+
double CPipFractal::Price(PipFractalType Type, int Measure=Expansion)
  {
     switch (Measure)
     {
       case Base:       return(pf[Type].Base);
       case Root:       return(pf[Type].Root);
       case Expansion:  return(pf[Type].Expansion);
       case Retrace:    return(pf[Type].Retrace);
       case Recovery:   return(pf[Type].Recovery);
     }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//| Fibonacci - Returns fibo percent or Price for supplied params    |
//+------------------------------------------------------------------+
double CPipFractal::Fibonacci(PipFractalType Type, int Method, int Measure, int Format=InDecimal)
  {
    int fFormat   = 1;
    
    if (Format == InPercent)
      fFormat     = 100;
      
    switch (Method)
    {
      case Retrace:   switch (Measure)
                      {
                        case Now: return (fdiv(Close[0]-pf[Type].Expansion,pf[Type].Root-pf[Type].Expansion,3)*fFormat);
                        case Max: return (fdiv(pf[Type].Retrace-pf[Type].Expansion,pf[Type].Root-pf[Type].Expansion,3)*fFormat);
                        case Min: return (fdiv(pf[Type].Recovery-pf[Type].Expansion,pf[Type].Root-pf[Type].Expansion,3)*fFormat);
                      }
                      break;
                       
      case Expansion: switch (Measure)
                      {
                        case Now: return (fdiv(Close[0]-pf[Type].Root,pf[Type].Base-pf[Type].Root,3)*fFormat);
                        case Max: return (fdiv(BoolToDouble(IsEqual(pf[Type].Expansion,pf[Type].Base),pf[Type].Recovery,pf[Type].Expansion)-pf[Type].Root,pf[Type].Base-pf[Type].Root,3)*fFormat);
                        case Min: return (fdiv(pf[Type].Retrace-pf[Type].Root,pf[Type].Base-pf[Type].Root,3)*fFormat);
                      }

      case Forecast|Expansion:    return(NormalizeDouble(pf[Type].Root+((pf[Type].Base-pf[Type].Root)*FiboPercent(Measure)),Digits));
      case Forecast|Retrace:      return(NormalizeDouble(pf[Type].Expansion+((pf[Type].Root-pf[Type].Expansion)*FiboPercent(Measure)),Digits));
    }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//|  Direction - returns the direction for the supplied type         |
//+------------------------------------------------------------------+
int CPipFractal::Direction(int Type, bool Contrarian=false)
  {
    int dContrary     = 1;
    
    if (Contrarian)
      dContrary       = DirectionInverse;

    switch (Type)
    {
      case pftOrigin:
      case pftTrend:       
      case pftTerm:       return (pf[Type].Direction*dContrary);
      case PolyTrend:     return (prPolyTrendDir*dContrary);
      case Polyline:      return (prPolyDirection*dContrary);
      case Trendline:     return (trTrendlineDir*dContrary);
      case Pivot:         return (trPivotDir*dContrary);
      case StdDev:        return (trStdDevDir*dContrary);
      case Range:         return (ptrRangeDir*dContrary);
      case RangeHigh:     return (ptrRangeDirHigh*dContrary);
      case RangeLow:      return (ptrRangeDirLow*dContrary);
      case Boundary:      if ((ptrRangeAgeLow-ptrRangeAgeHigh)*dContrary>0) return (DirectionUp);
                          if ((ptrRangeAgeLow-ptrRangeAgeHigh)*dContrary<0) return (DirectionDown);
                          return (this.Direction(Range));
      case Aggregate:     return (BoolToInt(ptrRangeDirHigh==ptrRangeDirLow,ptrRangeDirHigh*dContrary,DirectionNone));
      case Tick:          return (ptrTickDir*dContrary);
    }
    
    return (DirectionNone);
  }

//+------------------------------------------------------------------+
//|  Count - returns the count for the supplied Type                 |
//+------------------------------------------------------------------+
int CPipFractal::Count(const ReservedWords Type)
  {
    switch (Type)
    {
      case Tick:          return (pfTicks);
      case Pivot:         return (pfPivots);
      case History:       return (pipHistory.Count);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| ShowFiboArrow - paints the pipMA fibo arrow                      |
//+------------------------------------------------------------------+
void CPipFractal::ShowFiboArrow(void)
  {
    uchar     sfaArrowCode      = SYMBOL_DASH;
    double    sfaExpansion      = Fibonacci(pftTerm,Expansion,Max);
           
    if (sfaExpansion>FiboPercent(Fibo823))
      sfaArrowCode              = SYMBOL_POINT4;
    else
    if (sfaExpansion>FiboPercent(Fibo423))
      sfaArrowCode              = SYMBOL_POINT3;
    else
    if (sfaExpansion>FiboPercent(Fibo261))
      sfaArrowCode              = SYMBOL_POINT2;
    else  
    if (sfaExpansion>FiboPercent(Fibo161))
      sfaArrowCode              = SYMBOL_POINT1;
    else
    if (sfaExpansion>FiboPercent(Fibo100))
      sfaArrowCode              = SYMBOL_CHECKSIGN;
    else
      sfaArrowCode              = SYMBOL_DASH;

    if (Event(NewTerm))
    {
      arrowName                 = NewArrow(sfaArrowCode,Color(pf[pftTerm].Direction,IN_CHART_DIR),DirText(pf[pftTerm].Direction)+(string)arrowIdx++,pf[pftTerm].Expansion,pfBar);
      NewRay("r:"+(string)arrowIdx,false);
    }

    if (Event(NewExpansion))
    {        
      UpdateRay("r:"+(string)arrowIdx,pf[pftTerm].Root,pf[pftTerm].Age.Root,pf[pftTerm].Expansion,pf[pftTerm].Age.Expansion,STYLE_SOLID,Color(pf[pftTerm].Direction,IN_DARK_DIR));

      if (pfBar==0) 
        UpdateArrow(arrowName,sfaArrowCode,Color(pf[pftTerm].Direction,IN_CHART_DIR),pf[pftTerm].Expansion,pfBar);

      ObjectSet("indFibo",OBJPROP_TIME1,Time[pf[pftTerm].Age.Root]);
      ObjectSet("indFibo",OBJPROP_PRICE1,Price(pftTerm,Base));
      ObjectSet("indFibo",OBJPROP_TIME2,Time[pf[pftTerm].Age.Expansion]);
      ObjectSet("indFibo",OBJPROP_PRICE2,Price(pftTerm,Root));
    }
  }

//+------------------------------------------------------------------+
//| StateText - Returns the composite fractal State text             |
//+------------------------------------------------------------------+
string CPipFractal::StateText(void)
  {
    string stState     = "";
    string stTermState = BoolToStr(Direction(pftTerm)==DirectionUp,"Rally","Pullback");
    string stTrap      = BoolToStr(sr.Trap==NoValue,"",
                           BoolToStr(Direction(pftTerm)==DirectionUp,"Bull","Bear")+
                           BoolToStr(MathMod(pfPivots,2)==0," Push"," Trap"));
  
    switch (pfPattern)
    {
      //-- Reversal
      case 525251: if (pfPivots==0) stState  = "Reversing";
                   if (pfPivots==1) stState  = "ATTENTION";
                   if (pfPivots==2) stState  = "Breakout";

                   Append(stState,stTrap);
                   break;
      case 525252: stState                   = "Reversal";
                   Append(stState,stTrap);
                   break;

      case 525253: if (pfPivots==0) stState  = "Breakout";
                     else           stState  = "Breaking";

                   Append(stState,stTrap);
                   break;
      case 525257: stState                   = "Reversing Correction";
                   Append(stState,stTermState);
                   break;
      case 525351: if (pfPivots==1) stState  = "Reversing";

                   Append(stState,stTrap);
                   break;
      case 525357: stState                   = "Reversing Correction";

                   Append(stState,stTermState);
                   break;

      //-- Breakout
      case 535251: if (pfPivots==1) stState  = "Reversing";

                   Append(stState,stTrap);
                   break;

      case 535257: stState                   = "Correction";

                   Append(stState,stTermState);
                   break;

      case 535351: if (pfPivots==0) stState  = "Breaking";
                   if (pfPivots==1) stState  = "ATTENTION";
                   if (pfPivots==2) stState  = "Breakout";
//                   if (pfPivots>2)  stState  = "Consolidated";

                   Append(stState,stTrap);
                   break;
      case 535352: if (pfPivots==0) stState  = "Reversal";
                     else           stState  = "Reversing";

                   Append(stState,stTrap);
                   break;
      case 535353: stState                   = "Breakout";

                   Append(stState,stTrap);
                   break;
      case 535357: stState                   = "ATTENTION";

                   Append(stState,stTermState);
                   break;
                   
      //-- Rally
      case 545251: if (pfPivots==0) stState  = "ATTENTION";
                   if (pfPivots==1) stState  = "Reversal";
                   if (pfPivots==2) stState  = "Recovery";

                   Append(stState,BoolToStr(sr.Bias==OP_BUY,"Long","Short"));
                   Append(stState,"Rally");
                   break;
      case 545253: stState                   = "Adverse Bear Reversal";
                   break;
      case 545351: if (pfPivots==0) stState  = "ATTENTION";
                   if (pfPivots==1) stState  = "Breakout";
                   if (pfPivots==2) stState  = "Recovery";
                   
                   Append(stState,BoolToStr(sr.Bias==OP_BUY,"Long","Short"));
                   Append(stState,"Rally");
                   break;

      //-- Pullback
      case 555251: if (pfPivots==0) stState  = "ATTENTION";
                   if (pfPivots==1) stState  = "Reversal";
                   if (pfPivots==2) stState  = "Recovery";

                   Append(stState,BoolToStr(sr.Bias==OP_BUY,"Long","Short"));
                   Append(stState,"Pullback");
                   break;
      case 555253: stState                   = "Adverse Bull Reversal";
                   break;
      case 555351: if (pfPivots==0) stState  = "ATTENTION";
                   if (pfPivots==1) stState  = "Breakout";
                   if (pfPivots==2) stState  = "Recovery";

                   Append(stState,BoolToStr(sr.Bias==OP_BUY,"Long","Short"));
                   Append(stState,"Pullback");
                   break;
    }

    if (StringLen(stState)>0) return (stState);    
    return ("Unk: "+(string)pfPattern+BoolToStr(sr.Trap>NoValue,":Trap")+":"+(string)sr.Condition);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Prints PipFractal metrics to comment             |
//+------------------------------------------------------------------+
void CPipFractal::RefreshScreen(void)
  { 
    Comment("\n*--- PipFractal ---*\n"
           +"  FOC: "+DirText(FOCDirection(trTrendlineTolerance))+" "+DoubleToStr(FOC(Now),1)+"/"+DoubleToStr(FOC(Deviation),1)
           +"  Pivot: "+DoubleToStr(Pip(Pivot(Deviation)),1)+"/"+DoubleToStr(Pip(Pivot(Max)),1)
           +"  Range: "+DoubleToStr(Pip(Range(Size)),1)+"\n"
           +"  Poly: "+EnumToString(prPolyState)+"  ("+DirText(Direction(Polyline))+"/"+DirText(Direction(PolyTrend))+")\n"
           +"  Std Dev: "+DoubleToStr(Pip(StdDev(Now)),1)
               +" x:"+DoubleToStr(fmax(Pip(StdDev(Positive)),fabs(Pip(StdDev(Negative)))),1)
               +" p:"+DoubleToStr(Pip(StdDev()),1)
               +" +"+DoubleToStr(Pip(StdDev(Positive)),1)
               +" "+DoubleToStr(Pip(StdDev(Negative)),1)+"\n\n"
           +"  Term: "+DirText(Direction(pftTerm))+" ["+(string)pf[pftTerm].Age.Root+":"+(string)pf[pftTerm].Age.Expansion+"]\n"
           +"     Base: "+DoubleToStr(pf[pftTerm].Base,Digits)+" Root: "+DoubleToStr(pf[pftTerm].Root,Digits)+" Expansion: "+DoubleToStr(pf[pftTerm].Expansion,Digits)+"\n"
           +"     Retrace: "+DoubleToStr(Fibonacci(pftTerm,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftTerm,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(pftTerm,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftTerm,Expansion,Max,InPercent),1)+"%\n\n"
           +"  Trend: "+DirText(Direction(pftTrend))+" ["+(string)pf[pftTrend].Age.Root+":"+(string)pf[pftTrend].Age.Expansion+"]\n"
           +"     Base: "+DoubleToStr(pf[pftTrend].Base,Digits)+" Root: "+DoubleToStr(pf[pftTrend].Root,Digits)+" Expansion: "+DoubleToStr(pf[pftTrend].Expansion,Digits)+"\n"
           +"     Retrace: "+DoubleToStr(Fibonacci(pftTrend,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftTrend,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(pftTrend,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftTrend,Expansion,Max,InPercent),1)+"%\n\n"
           +"  Origin: "+DirText(Direction(pftOrigin))+" ["+(string)pf[pftOrigin].Age.Root+":"+(string)pf[pftOrigin].Age.Expansion+"]\n"
           +"     Base: "+DoubleToStr(pf[pftOrigin].Base,Digits)+" Root: "+DoubleToStr(pf[pftOrigin].Root,Digits)+" Expansion: "+DoubleToStr(pf[pftOrigin].Expansion,Digits)+"\n"       
           +"     Retrace: "+DoubleToStr(Fibonacci(pftOrigin,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftOrigin,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(pftOrigin,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftOrigin,Expansion,Max,InPercent),1)+"%\n"
           +"\nPipMA Active "+ActiveEventText());
  }
