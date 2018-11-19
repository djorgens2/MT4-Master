//+------------------------------------------------------------------+
//|                                                    Fibonacci.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <stdutil.mqh>
#include <std_utility.mqh>
#include <Class/ArrayDouble.mqh>
#include <Class/Event.mqh>

//+------------------------------------------------------------------+
//| Event Class - Indicator stack used to flag a named event         |
//+------------------------------------------------------------------+
class CFibonacci
  {

protected:

                    //--- Fibo Elements
                    enum FiboElement
                    {
                      feBase,
                      feRoot,
                      feHigh,
                      feLow,
                      feRally,
                      fePullback,
                      FiboElements
                    };
                    
                    //--- Fibo points
                    struct FiboRec 
                    {
                      int         Direction;
                      double      Price[FiboElements];
                      int         Age[FiboElements];
                    };
                    
                    FiboRec       fRec[2];
                    
                    //--- Fibo Events

public:
                    enum FiboMode
                    {
                      Linear,
                      Geometric
                    };
                    
                    CFibonacci(int Seed=24);
                   ~CFibonacci(void);
                   
                    double Fibonacci(RetraceType Type, FiboMode Mode, int Method=Expansion, ReservedWords Measure=Now, int Format=InDecimal);

                    bool          IsPegged(RetraceType Type);      //-- 50% retrace of total expansion after breakout
                    bool          IsReversing(RetraceType Type);   //-- 23% expansion after breakout (76% retrace)
                    bool          IsExpanding(RetraceType Type);   //-- 261% expansion (start new high/low metrics)
                    bool          TargetHit(RetraceType Type);     //-- 161% expansion acquired
                    bool          TargetMax(RetraceType Type);     //-- 423% expansion acquired; new fractal metrics;

                    FiboRec   operator[](const RetraceType Type) const {return(fRec[Type]);}

private:

                    void LoadHistory(void);
                     
                    int           fBar;          //-- Current bar
                    int           fBars;         //-- Total bars
                    int           fSeed;         //-- History seed (default: 24 periods)
                     
                    CArrayDouble *fBuffer;
                    CEvent       *fEvent;
                     
  };

//+------------------------------------------------------------------+
//| LoadHistory - Prepopulate historical data and events             |
//+------------------------------------------------------------------+
void CFibonacci::LoadHistory(void)
  {
    int    lhStart                   = fBars-fSeed;
    int    lhFiboDir                 = DirectionNone;
    double lhHigh                    = High[fBars];
    double lhLow                     = Low[fBars];
    
    //-- Initialize starting Term Price:Age arrays
    ArrayInitialize(fRec[Term].Price,NoValue);
    ArrayInitialize(fRec[Term].Age,NoValue);
    
    //-- Calculate starting Term Expansion
    fRec[Term].Age[feHigh]           = iHighest(Symbol(),0,MODE_HIGH,fSeed,fBars-fSeed);
    fRec[Term].Age[feLow]            = iLowest(Symbol(),0,MODE_LOW,fSeed,fBars-fSeed);

    //-- Initialize starting Term direction
    if (fRec[Term].Age[feLow]==fRec[Term].Age[feHigh])         //-- Opening outside reversal test
      fRec[Term].Direction           = Direction(Close[fRec[Term].Age[feLow]]-Open[fRec[Term].Age[feHigh]]);  
    else
      fRec[Term].Direction           = Direction(fRec[Term].Age[feLow]-fRec[Term].Age[feHigh]);
    

//    //-- Initialize opening fibo points
//    if (fRec[Term].Direction==DirectionUp)        //-- Initialize uptrend
//    {
//      fRec[Term].Age[feBase]         = iHighest(Symbol(),0,MODE_HIGH,(fBars-fRec[Term].Age[feLow])+1,fRec[Term].Age[feLow]+1);
//      fRec[Term].Age[feRoot]         = fRec[Term].Age[feLow];
//      fRec[Term].Age[feLow]          = iLowest(Symbol(),0,MODE_LOW,fRec[Term].Age[feHigh]-(fBars-fSeed),fBars-fSeed);
//      fRec[Term].Age[feRally]        = iHighest(Symbol(),0,MODE_HIGH,fRec[Term].Age[feLow]-(fBars-fSeed),fBars-fSeed);
//      fRec[Term].Age[fePullback]     = iLowest(Symbol(),0,MODE_LOW,fRec[Term].Age[feRally]-(fBars-fSeed),fBars-fSeed);
//    }
//    else
//    if (fRec[Term].Direction==DirectionDown)      //-- Initialize downtrend
//    {
//      fRec[Term].Age[feBase]         = iLowest(Symbol(),0,MODE_LOW,(fBars-fRec[Term].Age[feHigh])+1,fRec[Term].Age[feHigh]+1);
//      fRec[Term].Age[feRoot]         = fRec[Term].Age[feHigh];
//      fRec[Term].Age[feHigh]         = iHighest(Symbol(),0,MODE_HIGH,fRec[Term].Age[feLow]-(fBars-fSeed),fBars-fSeed);
//      fRec[Term].Age[fePullback]     = iLowest(Symbol(),0,MODE_LOW,fRec[Term].Age[feHigh]-(fBars-fSeed)-1,fBars-fSeed);
//      Print ("Time PB:"+TimeToStr(Time[fRec[Term].Age[fePullback]])+" Age:"+IntegerToString(fRec[Term].Age[fePullback]));
//      fRec[Term].Age[feRally]        = iHighest(Symbol(),0,MODE_HIGH,fRec[Term].Age[fePullback]-(fBars-fSeed)-1,fBars-fSeed);
//    }
//    
//    lhFiboDir                        = fRec[Term].Direction;
//    
//    for (FiboElement elem=feBase;elem<FiboElements;elem++)
//    {
//      if (fRec[Term].Age[elem]-(fBars-fSeed)==0)             //-- Set retrace based on opening breakout pattern
//        fRec[Term].Price[feLow]      = Close[fRec[Term].Age[elem]];
//      else
//      if (lhFiboDir==DirectionUp)
//      {
//        fRec[Term].Price[elem]       = High[fRec[Term].Age[elem]];
//        NewArrow(SYMBOL_ARROWDOWN,DirColor(fRec[Term].Direction,clrYellow,clrRed),EnumToString(elem),fRec[Term].Price[elem],fRec[Term].Age[elem]);
//      }
//      else
//      {
//        fRec[Term].Price[elem]       = Low[fRec[Term].Age[elem]];
//        NewArrow(SYMBOL_ARROWUP,DirColor(fRec[Term].Direction,clrYellow,clrRed),EnumToString(elem),fRec[Term].Price[elem],fRec[Term].Age[elem]);
//      }
//      
//      lhFiboDir                     *= DirectionInverse;
//    }

    fRec[Trend]                      = fRec[Term];
    
    for (fBar=fBars-fSeed;fBar<fBars;fBar--)
      break;

    string rsComment;
    
    rsComment   = "Fibo Term: (b) "+DoubleToStr(fRec[Term].Price[feBase],Digits)
                  +" (r) "+DoubleToStr(fRec[Term].Price[feRoot],Digits)
                  +" (h) "+DoubleToStr(fRec[Term].Price[feHigh],Digits)
                  +" (l) "+DoubleToStr(fRec[Term].Price[feLow],Digits)
                  +" (c) "+DoubleToStr(Close[fBar],Digits)+"\n";

                  
    rsComment  += "(TmLE) Now: "+DoubleToStr(this.Fibonacci(Term,Linear,Now,InPercent),2)
                  +"%  Expansion: "+DoubleToStr(this.Fibonacci(Term,Linear,Max,InPercent),2)
                  +"%  Retrace: "+DoubleToStr(this.Fibonacci(Term,Linear,Min,InPercent),2)+"%\n";
                  
    rsComment  += "(TmGE) Now: "+DoubleToStr(this.Fibonacci(Term,Geometric,Now,InPercent),2)
                  +"%  Expansion: "+DoubleToStr(this.Fibonacci(Term,Geometric,Max,InPercent),2)
                  +"%  Retrace: "+DoubleToStr(this.Fibonacci(Term,Geometric,Min,InPercent),2)+"%";

    Comment(rsComment);

//    {
//      fEvent.ClearEvents();
//      
//      if (IsHigher(High[fBar],fRec[Term].High))
//        fEvent.SetEvent(NewHigh);
//        
//      if (IsLower(Low[fBar],fRec[Term].Low))
//        fEvent.SetEvent(NewLow);
//        
//      if (fEvent[NewHigh]&&fEvent[NewLow])  //-- Handle outside reversal
//      {
//        if (NewDirection(fRec[Term].Dir,Direction(Close[fBar]-Open[fBar])))
//          fEvent.SetEvent(NewReversal);
//        else
//          fEvent.SetEvent(NewBreakout);
//      }
//      else
//      if (fEvent[NewHigh])
//        if (
//      
//    }
  }

//+------------------------------------------------------------------+
//| Fibonacci Class Constructor                                      |
//+------------------------------------------------------------------+
CFibonacci::CFibonacci(int Seed=24)
  {
    //--- Initialize event class
    fEvent                           = new CEvent();
    fEvent.ClearEvents();
    
    //--- Initialize fibonacci buffer
    fBuffer                          = new CArrayDouble(Bars);
    fBuffer.Truncate                 = false;
    fBuffer.AutoExpand               = true;    
    fBuffer.SetPrecision(Digits);
    fBuffer.Initialize(0.00);

    //--- Initialize op vars
    fSeed                            = Seed;
    fBars                            = Bars-1;
    
    LoadHistory(); 
  }

//+------------------------------------------------------------------+
//| Fibonacci Class Destructor                                       |
//+------------------------------------------------------------------+
CFibonacci::~CFibonacci()
  {
    delete fEvent;
    delete fBuffer;
  }
  
//+------------------------------------------------------------------+
//| Fibonacci - Returns the Fibonacci calc based on measure type     |
//+------------------------------------------------------------------+
double CFibonacci::Fibonacci(RetraceType Type, FiboMode Mode, int Method=Expansion, ReservedWords Measure=Now, int Format=InDecimal)
  {
    int    fFormat            = BoolToInt(Format==InDecimal,1,100);

    double fExpansion         = BoolToDouble(fRec[Type].Direction==DirectionUp,fRec[Type].Price[feHigh],fRec[Type].Price[feLow]);
    double fRetrace           = BoolToDouble(Measure==Now,Close[fBar],BoolToDouble(fRec[Type].Direction==DirectionUp,fRec[Type].Price[feLow],fRec[Type].Price[feHigh]));
    double fBase              = BoolToDouble(Mode==Linear,fExpansion,fRec[Type].Price[feBase]);
    double fRoot              = fRec[Type].Price[feRoot];
        
//    switch (Method)
//    {
//      case InExpansion
//    }

Print ("Fibo Term: (b) "+DoubleToStr(fBase,Digits)
                  +" (r) "+DoubleToStr(fRoot,Digits)
                  +" (e) "+DoubleToStr(fExpansion,Digits)
                  +" (rt) "+DoubleToStr(fRetrace,Digits)
                  +" (c) "+DoubleToStr(Close[fBar],Digits)) ;

    return (fdiv(fabs(fExpansion-fRoot),fabs(fBase-fRoot))*fFormat);
  }