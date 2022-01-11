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
#include <fractal_lib.mqh>

//+------------------------------------------------------------------+
//| PipFractal: Fractal Class derived from Poly(6) trend algorithm   |
//+------------------------------------------------------------------+
class CPipFractal : public CPipRegression
  {

    protected:
    
         enum       PipFractalType
                    {
                      pftOrigin     = (FractalType)Origin,     // Origin
                      pftTrend      = (FractalType)Trend,      // Trend
                      pftTerm       = (FractalType)Term,       // Term
                      PipFractalTypes                          // None
                    };

         //--- Fractal State Rec
         struct     StateRec
                    {
                      int              Direction;              //--- Consolidated Direction
                      int              Pivots;                 //--- Term pivot count
                      FractalType      Bearing;                //--- Trend Convergence/Divergence
                      FractalState     State[PipFractalTypes]; //--- Current States by Type
                      int              Action;                 //--- Current Term Action
                      double           Speed;                  //--- Term v. Origin traversal speed
                      string           Condition;              //--- Term Condition {0,1,2,D,C};
                      FractalType      Trap;                   //--- Trap Flag
                      int              Bias;                   //--- Consolidation Action
                    };
                
         //--- Fractal point data
         struct     PipFractalRec
                    {
                      int              Direction;              //--- fractal direction
                      int              Age[FractalPoints];     //--- Age in periods by fp
                      double           Price[FractalPoints];
                    };

         PipFractalRec pf[PipFractalTypes];                    //--- Fractal data
         StateRec      sr;                                     //--- State data


    private:
          //--- Data arrays
          double         pfMap[];
          int            pfPattern;                         //--- Test Key
          
          //--- Operational Bar variables
          int            pfBar;                             //--- Bar now processing
          int            pfBars;                            //--- Total Bars in Chart
          int            pfTicks;                           //--- Ticks in current direction
          int            pfHiBar;
          int            pfLoBar;
          
          //--- Operational flags
          bool           pfTerm161;                         //--- Term fibo 161 switch
          bool           pfReversal;                        //--- Set on Trend Reversals
          bool           pfBreakout;                        //--- Set on Trend Breakouts
          bool           pfInterior;
          

          //--- Display flag operationals
          int            pfTermIdx;
          int            pfTrendIdx;
          
          //--- Internal use methods
          void           ResetRetrace(FractalType Type, FractalPoint Price, EventType Event);
          void           ShiftRetrace(FractalType Type, int Bar, double Price);

          void           UpdateState(void);                         //--- Update Fractal States
          void           UpdateRetrace(FractalType Type);           //--- Update Retrace by Type
          void           UpdateTerm(int Direction, double Price);   //--- Updates Term Fractal on change
          void           UpdateTrend(void);                         //--- Updates Trend Fractal on change
          void           UpdateOrigin(void);                        //--- Updates Origin Fractal on change
          void           UpdateNodes(void);
          

    public:
                         CPipFractal(int Degree, int Periods, double Tolerance, double AggFactor, int IdleTime);
                        ~CPipFractal();
                             
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

          double         Price(FractalType Type, FractalPoint Measure=fpExpansion);
          double         Fibonacci(FractalType Type, int Method, int Measure, int Format=InDecimal);
          double         Forecast(FractalType Type, int Method, int Fibo);
          
          string         FractalStr(FractalType Type);
          string         FractalStr(void);

          void           RefreshScreen(void);
          void           ShowFiboArrow(void);

       PipFractalRec     operator[](const FractalType Type) const {return(pf[Type]);};
  };

//+------------------------------------------------------------------+
//| UpdateState - Computes Fractal state conditions                  |
//+------------------------------------------------------------------+
void CPipFractal::UpdateState(void)
  {
    int    usLastState      = sr.State[Origin];
    int    usLastPattern    = pfPattern;
    int    usLastTrap       = sr.Trap;
    
    if (Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo100))
      sr.Direction          = Direction(Term);

    //-- Compute States By Type
    if (Event(NewTrend))
      sr.State[Trend]       = (FractalState)BoolToInt(pfReversal,Reversal,Breakout);
          
    sr.State[Term]          = (FractalState)BoolToInt(Fibonacci(Term,Expansion,Max)>=1,
                                BoolToInt(IsEqual(Direction(pftTerm),Direction(pftTrend)),sr.State[Trend],Reversal),
                                BoolToInt(IsEqual(Direction(pftTerm),DirectionUp),Rally,Pullback));

    if (Fibonacci(Origin,Expansion,Min)<FiboPercent(Fibo23))
    {
      if (Fibonacci(Origin,Retrace,Now)<FiboPercent(Fibo23))
        sr.State[Origin]  = Recovery;

      if (Fibonacci(Origin,Expansion,Now)<FiboPercent(Fibo23))
        sr.State[Origin]  = Correction;
      
      if (Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo161)&&
          Fibonacci(Origin,Expansion,Min)<FiboPercent(FiboRoot))
        sr.State[Origin]  = Reversal;
    }
    else
    if (Fibonacci(Origin,Retrace,Max)>FiboPercent(Fibo23)||
       (Event(NewTerm)&&Direction(pftOrigin)!=Direction(pftTerm)))
      sr.State[Origin]    = Retrace;
    else
    if (IsEqual(Fibonacci(Origin,Retrace,Now),FiboPercent(FiboRoot),3))
      sr.State[Origin]    = Breakout;
    
    sr.Bearing              = (FractalType)BoolToInt(Direction(pftOrigin)==Direction(pftTrend),Convergent,Divergent);
    sr.Action               = Action(Direction(pftTerm));
    sr.Bias                 = BoolToInt(HistoryLoaded(),BoolToInt(IsEqual(FiboLevel(fdiv(FOC(Deviation),FOC(Max),3),Signed),0),
                                Action(Direction(Term),InDirection),
                                Action(Direction(Term),InDirection,InContrarian)),
                                Action(Direction(Tick)));
    sr.Speed                = fabs(fdiv(Price(Term,fpRoot)-Price(Term,fpExpansion),Price(Term,fpRoot)-Price(Term,fpExpansion),3));
    sr.Trap                 = (FractalType)BoolToInt(IsBetween(Fibonacci(Term,Expansion,Max),FiboPercent(Fibo100),FiboPercent(Fibo161)),pftTerm,NoValue);
    sr.Trap                 = (FractalType)BoolToInt(IsEqual(sr.Pivots,0)&&IsEqual(sr.State[Origin],Retrace),pftTrend,sr.Trap);
    sr.Condition            = BoolToStr(sr.Pivots<3,(string)sr.Pivots,BoolToStr(fmod(sr.Pivots,2)==0,"C","D"));
                                        
    pfPattern               = 0;
    
    for (FractalType type=0;type<(int)PipFractalTypes;type++)
      pfPattern           += sr.State[type]*(int)MathPow(10,type);
      
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
      //      "(o) "+EnumToString(sr.Type[Origin])+" (tr) "+EnumToString(sr.Type[Trend])+" (tm) "+EnumToString(sr.Type[Term])+"\n"+
      //             EnumToString(sr.Bearing)+" "+ActionText(sr.Action)+"("+(string)pfPivots+") "+BoolToStr(sr.Trap>NoValue,":Trap"),"Pattern Analysis");
//    if (IsChanged(usLastPattern,pfPattern))
//      Print(TimeToStr(Time[pfBar])+"|"+pfPattern);

    //if (pfBar==0&&Event(NewTrend))
    //  Pause("New Trend", "Event(NewTrend) Test");    
    //if (IsChanged(usLastState,pf[Origin].State))
    //  Pause("New Origin State: "+EnumToString(pf[Origin].State)+"\n"+
    //          StateText()+"\n"+
    //          pfPattern+": (o) "+EnumToString(pf[Origin].State)+" (tr) "+EnumToString(pf[Trend].State)+" (tm) "+EnumToString(pf[Term].State),
    //          "OriginState() Test");      
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns formatted fractal data by supplied type     |
//+------------------------------------------------------------------+
string CPipFractal::FractalStr(FractalType Type)
  {
    string fsText    = "";

    Append(fsText,"  "+EnumToString(Type)+": "+DirText(Direction(Type))+" (b) "+(string)pf[Type].Age[fpBase]+" (r) "+(string)pf[Type].Age[fpRoot]
                           +" (e) "+(string)pf[Type].Age[fpExpansion]+" (rt) "+(string)pf[Type].Age[fpRetrace]);
    Append(fsText,BoolToStr(pfBar>0," p:"+(string)pfBar+" @"+DoubleToStr(Close[pfBar],Digits)));

    Append(fsText,"  Points: (b) "+DoubleToStr(Price(Type,fpBase),Digits)+" (r) "+DoubleToStr(Price(Type,fpRoot),Digits)+" (e) "+DoubleToStr(Price(Type,fpExpansion),Digits)
                           +" (rt) "+DoubleToStr(Price(Type,fpRetrace),Digits)+" (rc) "+DoubleToStr(Price(Type,fpRecovery),Digits),"\n");
    Append(fsText,"  Retrace: "+DoubleToStr(Fibonacci(Type,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(Type,Retrace,Max,InPercent),1)
                           +"%  Forecast:"+DoubleToStr(Forecast(Type,Retrace,Fibo161),Digits),"\n");
    Append(fsText,"  Expansion: "+DoubleToStr(Fibonacci(Type,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(Type,Expansion,Max,InPercent),1)
                           +"%  Forecast:"+DoubleToStr(Forecast(Type,Expansion,Fibo161),Digits),"\n");

    return (fsText);
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns formatted Fractal data for all types        |
//+------------------------------------------------------------------+
string CPipFractal::FractalStr(void)
  {
    string fsText   = "";

    for (FractalType type=Origin;type<(int)PipFractalTypes;type++)
      Append(fsText,FractalStr(type),"\n\n");

    return (fsText);
  }

//+------------------------------------------------------------------+
//| ShiftRetrace - shifts geometric and sets linear retrace data     |
//+------------------------------------------------------------------+
void CPipFractal::ShiftRetrace(FractalType Type, int Bar, double Price)
  {
    for (FractalPoint point=fpBase;point<fpRecovery;point++)
      if (point<fpExpansion)
      {
        pf[Type].Age[point]         = pf[Type].Age[point+1];
        pf[Type].Price[point]       = pf[Type].Price[point+1];
      }
      else
      {
        pf[Type].Age[point]         = Bar;
        pf[Type].Price[point]       = Price;
      }
  }

//+------------------------------------------------------------------+
//| ResetRetrace - resets retrace data based on supplied type        |
//+------------------------------------------------------------------+
void CPipFractal::ResetRetrace(FractalType Type, FractalPoint Fractal, EventType Event)
  {
    for (FractalPoint point=Fractal;point<FractalPoints;point++)
    {
      pf[Type].Age[point]        = pfBar;
      pf[Type].Price[point]      = Price(Type,Fractal);
    }

    SetEvent(Event,(AlertLevel)BoolToInt(Type==Term,Minor,BoolToInt(Type==Trend,Major,Critical)));
  }

//+------------------------------------------------------------------+
//| UpdateRetrace - updates retrace data based on supplied type      |
//+------------------------------------------------------------------+
void CPipFractal::UpdateRetrace(FractalType Type)
  {
    if (IsChanged(pf[Type].Price[fpExpansion],BoolToDouble(Direction(Type)==DirectionUp,
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),Price(Type,fpExpansion)),
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),Price(Type,fpExpansion)),Digits)))
      ResetRetrace(Type,fpExpansion,NewExpansion);

    if (IsChanged(pf[Type].Price[fpRetrace],BoolToDouble(Direction(Type)==DirectionUp,
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),Price(Type,fpRetrace)),
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),Price(Type,fpRetrace)),Digits)))
      ResetRetrace(Type,fpRetrace,NewRetrace);

    if (IsChanged(pf[Type].Price[fpRecovery],BoolToDouble(Direction(Type)==DirectionUp,
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),Price(Type,fpRecovery)),
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),Price(Type,fpRecovery)),Digits)))
      ResetRetrace(Type,fpRecovery,NewRecovery);
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - updates Origin fractal data                       |
//+------------------------------------------------------------------+
void CPipFractal::UpdateOrigin(void)
  {
    if (Event(NewReversal))
      if (Direction(Origin)==DirectionNone)
        pf[Origin]                 = pf[Trend];
      else
      {
        pf[Origin].Price[BoolToInt(Direction(Origin)==Direction(Trend),fpRoot,fpBase)]  = Price(Trend,fpRoot);
        pf[Origin].Age[BoolToInt(Direction(Origin)==Direction(Trend),fpRoot,fpBase)]    = pf[Trend].Age[fpRoot];
      }
    else
    {
      if (NewDirection(pf[Origin].Direction,pf[Trend].Direction))
        ShiftRetrace(Origin,pfBar,Price(Origin,fpRoot));

      SetEvent(NewOrigin,Critical);
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - updates Trend fractal data                         |
//+------------------------------------------------------------------+
void CPipFractal::UpdateTrend(void)
  {
    double utNewBase                = Forecast(Term,Expansion,Fibo161);
    
    pfInterior                      = IsBetween(utNewBase,Low[pfLoBar],High[pfHiBar]);
    pfReversal                      = NewDirection(pf[Trend].Direction,Direction(Term));

    if (pfReversal) //-- Trend Reversal
    {
      pf[Trend].Age[fpBase]         = pfBar;
      pf[Trend].Price[fpBase]       = utNewBase;

      pf[Trend].Age[fpRoot]         = pf[Trend].Age[fpExpansion];
      pf[Trend].Price[fpRoot]       = Price(Trend,fpExpansion);
    }
    else            //-- Interior Breakout
    if (pfInterior)
    {
      pf[Trend].Age[fpBase]         = BoolToInt(Direction(Trend)==DirectionUp,pfHiBar,pfLoBar);
      pf[Trend].Price[fpBase]       = BoolToDouble(Direction(Trend)==DirectionUp,High[pfHiBar],Low[pfLoBar]);
    
      pf[Trend].Age[fpRoot]         = BoolToInt(Direction(Trend)==DirectionUp,pfLoBar,pfHiBar);
      pf[Trend].Price[fpRoot]       = BoolToDouble(Direction(Trend)==DirectionUp,Low[pfLoBar],High[pfHiBar]);
    }
    
    pf[Trend].Price[fpExpansion]    = Price(Term,fpExpansion);

    ResetRetrace(Trend,fpExpansion,BoolToEvent(pfReversal,NewReversal,BoolToEvent(pfInterior,NewExpansion,NewBreakout)));
        
    sr.Direction                    = Direction(Trend);
    sr.Pivots                       = 0;

    SetEvent(NewTrend,Major);
  }

//+------------------------------------------------------------------+
//| UpdateTerm - updates Term fractal data                           |
//+------------------------------------------------------------------+
void CPipFractal::UpdateTerm(int Direction, double Price)
  {
    if (NewDirection(pf[Term].Direction,Direction))
    {
      ShiftRetrace(Term,pfBar,Price);

      if (IsChanged(pfTerm161,false))
      {
        pfLoBar                       = BoolToInt(Direction(Term)==DirectionUp,pf[Term].Age[fpRoot],pfBar);
        pfHiBar                       = BoolToInt(Direction(Term)==DirectionUp,pfBar,pf[Term].Age[fpRoot]);
      }

      if (Direction(Term)==DirectionUp)
        pfLoBar                       = BoolToInt(Price(Term,fpRoot)<Low[pfLoBar],pf[Term].Age[fpRoot],pfLoBar);

      if (Direction(Term)==DirectionDown)
        pfHiBar                       = BoolToInt(Price(Term,fpRoot)>High[pfHiBar],pf[Term].Age[fpRoot],pfHiBar);

      sr.Pivots++;
      
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
    ClearEvent(NewTerm);
    ClearEvent(NewTrend);
    ClearEvent(NewOrigin);
    ClearEvent(NewBreakout);
    ClearEvent(NewReversal);
    ClearEvent(NewExpansion);
    ClearEvent(NewRetrace);
    ClearEvent(NewRecovery);

    //--- Update Tick Counter
    if (Event(NewTick))
    {
      if (IsChanged(unTickDir,Direction(Tick)))
        pfTicks                = 0;

      pfTicks++;
    }

    //--- Update Fractal Node Ages
    for (pfBars=pfBars;pfBars<Bars;pfBars++)
    {
      pfLoBar++;
      pfHiBar++;

      for (FractalType type=Origin;type<(int)PipFractalTypes;type++)
        for (FractalPoint point=fpBase;point<FractalPoints;point++)
          pf[type].Age[point]++;
    }
    
    //--- Handle Term direction changes
    if (pfBar>0&&pfMap[pfBar]>0.00)
      UpdateTerm(BoolToInt(IsEqual(pfMap[pfBar],High[pfBar]),DirectionUp,DirectionDown),pfMap[pfBar]);
    else
    if (Event(NewBoundary))
      if (IsEqual(FOC(Deviation),0.0,1))
        if (HistoryLoaded())
          UpdateTerm(BoolToInt(Event(NewHigh),DirectionUp,DirectionDown),Close[pfBar]);
        else UpdateTerm(BoolToInt(Close[pfBar]>pf[Term].Price[fpRoot],DirectionUp,DirectionDown),Close[pfBar]);
      else UpdateTerm(BoolToInt(Event(NewHigh),DirectionUp,DirectionDown),Close[pfBar]);

    UpdateRetrace(Term);

    if (Fibonacci(Term,Retrace,Max)>FiboPercent(Fibo161))
    {
      UpdateTerm(Direction(Term,InContrarian),Forecast(Term,Retrace,Fibo161));
      UpdateRetrace(Term);
    }

    //-- Manage Trend changes
    if (Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo161))
      if (IsChanged(pfTerm161,true))
        UpdateTrend();

    UpdateRetrace(Trend);
    
    //-- Manage Origin changes
    if (Event(NewReversal)||Fibonacci(Origin,Expansion,Now)<0.00)
      UpdateOrigin();
      
    UpdateRetrace(Origin);
    
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
    int    pfSeed      = 14;
    int    pfDir       = DirectionChange;
    
    int    pfLastHi    = NoValue;
    int    pfLastLo    = NoValue;

    //-- Initialize fibo graphics
    pfTermIdx          = 0;
    pfTrendIdx         = 0;

    //-- Initialize Operational variables
    pfBar              = 0;
    pfBars             = Bars;
    pfHiBar            = NoValue;
    pfLoBar            = NoValue;
    
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
    pf[Term].Direction             = pfDir;
    pf[Term].Age[fpRoot]           = BoolToInt(pfDir==DirectionUp,pfLoBar,pfHiBar);
    pf[Term].Age[fpExpansion]      = BoolToInt(pfDir==DirectionUp,pfHiBar,pfLoBar);
    pf[Term].Price[fpBase]         = BoolToDouble(pfDir==DirectionUp,High[pfHiBar],Low[pfLoBar]);
    pf[Term].Price[fpRoot]         = BoolToDouble(pfDir==DirectionUp,Low[pfLoBar],High[pfHiBar]);
    pf[Term].Price[fpExpansion]    = pf[Term].Price[fpBase];
    pf[Term].Price[fpRetrace]      = pf[Term].Price[fpBase];
    pf[Term].Price[fpRecovery]     = pf[Term].Price[fpBase];
    
    pf[Trend]                      = pf[Term];    
    pf[Origin].Direction           = DirectionNone;

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
    else CalcMA();

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
    else CalcMA();

    UpdateNodes();
  }

//+------------------------------------------------------------------+
//| Price - Returns the price of the specified measure               |
//+------------------------------------------------------------------+
double CPipFractal::Price(FractalType Type, FractalPoint Measure=fpExpansion)
  {
     switch (Measure)
     {
       case fpBase:       return(pf[Type].Price[fpBase]);
       case fpRoot:       return(pf[Type].Price[fpRoot]);
       case fpExpansion:  return(pf[Type].Price[fpExpansion]);
       case fpRetrace:    return(pf[Type].Price[fpRetrace]);
       case fpRecovery:   return(pf[Type].Price[fpRecovery]);
     }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//| Fibonacci - Returns fibo percent or Price for supplied params    |
//+------------------------------------------------------------------+
double CPipFractal::Fibonacci(FractalType Type, int Method, int Measure, int Format=InDecimal)
  {
    int fFormat   = 1;
    
    if (Format == InPercent)
      fFormat     = 100;
      
    switch (Method)
    {
      case Retrace:   switch (Measure)
                      {
                        case Now: return (fdiv(Close[pfBar]-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion),3)*fFormat);
                        case Max: return (fdiv(Price(Type,fpRetrace)-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion),3)*fFormat);
                        case Min: return (fdiv(Price(Type,fpRecovery)-Price(Type,fpExpansion),Price(Type,fpRoot)-Price(Type,fpExpansion),3)*fFormat);
                      }
                      break;
                       
      case Expansion: switch (Measure)
                      {
                        case Now: return (fdiv(Close[pfBar]-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot),3)*fFormat);
                        case Max: return (fdiv(BoolToDouble(IsEqual(Price(Type,fpExpansion),Price(Type,fpBase)),Price(Type,fpRecovery),Price(Type,fpExpansion))-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot),3)*fFormat);
                        case Min: return (fdiv(Price(Type,fpRetrace)-Price(Type,fpRoot),Price(Type,fpBase)-Price(Type,fpRoot),3)*fFormat);
                      }
    }
    
    return (NormalizeDouble(0.00,3));
  }

//+------------------------------------------------------------------+
//| Forecast - Returns Forecast Price for supplied Fibo              |
//+------------------------------------------------------------------+
double CPipFractal::Forecast(FractalType Type, int Method, int Fibo)
  {
    switch (Method)
    {
      case Expansion:    return(NormalizeDouble(Price(Type,fpRoot)+((Price(Type,fpBase)-Price(Type,fpRoot))*FiboPercent(Fibo)),Digits));
      case Retrace:      return(NormalizeDouble(Price(Type,fpExpansion)+((Price(Type,fpRoot)-Price(Type,fpExpansion))*FiboPercent(Fibo)),Digits));
    }
    
    return (NormalizeDouble(0.00,Digits));
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
      case Origin:
      case Trend:       
      case Term:          return (pf[Type].Direction*dContrary);
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
    double    sfaExpansion      = Fibonacci(Term,Expansion,Max);
    int       sfaObject         = 0;

           
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
      pfTermIdx++;
      NewRay("[r(tm)]:"+(string)pfTermIdx,false);
    }

    if (Event(NewTrend))
    {
      while (sfaObject<ObjectsTotal())
        if (InStr(ObjectName(sfaObject),"[r(tm)]:"))
          ObjectDelete(ObjectName(sfaObject));
        else sfaObject++;

      if (!pfReversal&&pfInterior)
      {
        NewRay("[r(tr)]:"+(string)pfTrendIdx++,false);
        UpdateRay("[r(tr)]:"+(string)(pfTrendIdx-1),Price(Trend,fpRoot),pf[Trend].Age[fpRoot],Price(Trend,fpBase),pf[Trend].Age[fpBase],STYLE_SOLID,Color(Direction(Trend),IN_DARK_DIR,InContrarian));
      }

      if (pfReversal||pfInterior)
        NewRay("[r(tr)]:"+(string)pfTrendIdx++,false);
    }

    if (Event(NewExpansion)||Event(NewTerm))
    {
      UpdateArrow("fp(tm)]:"+(string)pfTermIdx,sfaArrowCode,Color(pf[Term].Direction,IN_CHART_DIR),pf[Term].Age[fpExpansion],Price(Term,fpExpansion));
      UpdateRay("[r(tm)]:"+(string)pfTermIdx,Price(Term,fpRoot),pf[Term].Age[fpRoot],Price(Term,fpExpansion),pf[Term].Age[fpExpansion],STYLE_DOT,Color(Direction(Term),IN_DARK_DIR));
      UpdateRay("[r(tr)]:"+(string)(pfTrendIdx-1),Price(Trend,fpRoot),pf[Trend].Age[fpRoot],Price(Trend,fpExpansion),pf[Trend].Age[fpExpansion],STYLE_SOLID,Color(Direction(Trend),IN_DARK_DIR));

      ObjectSet("indFibo",OBJPROP_TIME1,Time[pf[Term].Age[fpRoot]]);
      ObjectSet("indFibo",OBJPROP_PRICE1,Price(Term,fpBase));
      ObjectSet("indFibo",OBJPROP_TIME2,Time[pf[Term].Age[fpExpansion]]);
      ObjectSet("indFibo",OBJPROP_PRICE2,Price(Term,fpRoot));
    }
  }

//+------------------------------------------------------------------+
//| StateText - Returns the composite fractal State text             |
//+------------------------------------------------------------------+
string CPipFractal::StateText(void)
  {
    string stState     = "";
    string stTermState = BoolToStr(Direction(Term)==DirectionUp,"Rally","Pullback");
    string stTrap      = BoolToStr(sr.Trap==NoValue,"",
                           BoolToStr(Direction(Term)==DirectionUp,"Bull","Bear")+
                           BoolToStr(MathMod(sr.Pivots,2)==0," Push"," Trap"));
  
    switch (pfPattern)
    {
      //-- Reversal
      case 883: if (sr.Pivots==0) stState  = "Reversing";
                   if (sr.Pivots==1) stState  = "ATTENTION";
                   if (sr.Pivots==2) stState  = "Breakout";

                   Append(stState,stTrap);
                   break;
      case 888: stState                   = "Reversal";
                   Append(stState,stTrap);
                   break;

      case 887: if (sr.Pivots==0) stState  = "Breakout";
                     else           stState  = "Breaking";

                   Append(stState,stTrap);
                   break;
      case 885: stState                   = "Reversing Correction";
                   Append(stState,stTermState);
                   break;
      case 873: if (sr.Pivots==1) stState  = "Reversing";

                   Append(stState,stTrap);
                   break;
      case 875: stState                   = "Reversing Correction";

                   Append(stState,stTermState);
                   break;

      //-- Breakout
      case 783: if (sr.Pivots==1) stState  = "Reversing";

                   Append(stState,stTrap);
                   break;

      case 785: stState                   = "Correction";

                   Append(stState,stTermState);
                   break;

      case 773: if (sr.Pivots==0) stState  = "Breaking";
                   if (sr.Pivots==1) stState  = "ATTENTION";
                   if (sr.Pivots==2) stState  = "Breakout";
//                   if (pfPivots>2)  stState  = "Consolidated";

                   Append(stState,stTrap);
                   break;
      case 778: if (sr.Pivots==0) stState  = "Reversal";
                     else           stState  = "Reversing";

                   Append(stState,stTrap);
                   break;
      case 777: stState                   = "Breakout";

                   Append(stState,stTrap);
                   break;
      case 775: stState                   = "ATTENTION";

                   Append(stState,stTermState);
                   break;
                   
      //-- Rally
      case 138: if (sr.Pivots==0) stState  = "ATTENTION";
                   if (sr.Pivots==1) stState  = "Reversal";
                   if (sr.Pivots==2) stState  = "Recovery";

                   Append(stState,BoolToStr(sr.Direction==DirectionUp,"Long","Short"));
                   Append(stState,"Rally");
                   break;
      case 187: stState                   = "Adverse Bear Reversal";
                   break;
      case 173: if (sr.Pivots==0) stState  = "ATTENTION";
                   if (sr.Pivots==1) stState  = "Breakout";
                   if (sr.Pivots==2) stState  = "Recovery";
                   
                   Append(stState,BoolToStr(sr.Direction==DirectionUp,"Long","Short"));
                   Append(stState,"Rally");
                   break;

      //-- Pullback
      case 283: if (sr.Pivots==0) stState  = "ATTENTION";
                   if (sr.Pivots==1) stState  = "Reversal";
                   if (sr.Pivots==2) stState  = "Recovery";

                   Append(stState,BoolToStr(sr.Direction==DirectionUp,"Long","Short"));
                   Append(stState,"Pullback");
                   break;
      case 287: stState                   = "Adverse Bull Reversal";
                   break;
      case 273: if (sr.Pivots==0) stState  = "ATTENTION";
                   if (sr.Pivots==1) stState  = "Breakout";
                   if (sr.Pivots==2) stState  = "Recovery";

                   Append(stState,BoolToStr(sr.Direction==DirectionUp,"Long","Short"));
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
    Comment("\n*--- PipMA Fractal ---*\n"
           +"  FOC: "+DirText(FOCDirection(trTrendlineTolerance))+" "+DoubleToStr(FOC(Now),1)+"/"+DoubleToStr(FOC(Deviation),1)
           +"  Pivot: "+DoubleToStr(pip(Pivot(Deviation)),1)+"/"+DoubleToStr(pip(Pivot(Max)),1)
           +"  Range: "+DoubleToStr(pip(Range(Size)),1)+"\n"
           +"  Poly: "+EnumToString(prPolyState)+"  ("+DirText(Direction(Polyline))+"/"+DirText(Direction(PolyTrend))+")\n"
           +"  Std Dev: "+DoubleToStr(pip(StdDev(Now)),1)
               +" x:"+DoubleToStr(fmax(pip(StdDev(Positive)),fabs(pip(StdDev(Negative)))),1)
               +" p:"+DoubleToStr(pip(StdDev()),1)
               +" +"+DoubleToStr(pip(StdDev(Positive)),1)
               +" "+DoubleToStr(pip(StdDev(Negative)),1)+"\n\n"
           +FractalStr()+"\n"
           +"\n  PipMA Active "+ActiveEventText());
  }
