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
    fRec[Term].Direction             = NoDirection;
    
    ArrayInitialize(fRec[Term].Age,NoValue);
    ArrayInitialize(fRec[Term].Price,NoValue);
    
    fRec[Trend].Direction            = NoDirection;

    ArrayInitialize(fRec[Trend].Age,NoValue);
    ArrayInitialize(fRec[Trend].Price,NoValue);
    
    //-- Iterate thru seed to identify opening fractal
    for (fBar==fBars;fBar>fBars-fSeed;fBar--)
      Update();
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
//| Fibonacci Class Destructor                                       |
//+------------------------------------------------------------------+
CFibonacci::Update(void)
  {
    fEvent.ClearEvents();
   
    if (IsHigher(High[fBar],fRec[Term].High))
      fEvent.SetEvent(NewHigh);
     
    if (IsLower(Low[fBar],fRec[Term].Low))
      fEvent.SetEvent(NewLow);
     
    if (fEvent[NewHigh]&&fEvent[NewLow])  //-- Handle outside reversal
    {
      if (NewDirection(fRec[Term].Dir,Direction(Close[fBar]-Open[fBar])))
        fEvent.SetEvent(NewReversal);
      else
        fEvent.SetEvent(NewBreakout);
    }
    else
   if (fEvent[NewHigh])
     if (
   
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