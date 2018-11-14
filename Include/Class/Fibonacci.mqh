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

                    //--- Fibo points
                    struct FiboRec 
                    {
                      int         Direction;
                      double      High;          //-- Based on direction either retrace or expansion
                      double      Low;           //-- Based on direction either retrace or expansion
                      double      Base;          //-- Fibo Base point
                      double      Root;          //-- Fibo Root point
                      bool        IsPegged;      //-- 50% retrace of total expansion after breakout
                      bool        IsReversing;   //-- 23% expansion after breakout (76% retrace)
                      bool        IsExpanding;   //-- 261% expansion (start new high/low metrics)
                      bool        HitTarget;     //-- 161% expansion acquired
                      bool        HitTargetMax;  //-- 423% expansion acquired; new fractal metrics;
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
    int lhHighBar                    = iHighest(Symbol(),0,MODE_HIGH,fSeed,fBars-fSeed);
    int lhLowBar                     = iLowest(Symbol(),0,MODE_LOW,fSeed,fBars-fSeed);

    //-- Initialize opening term direction
    if (lhLowBar==lhHighBar)                      //-- Opening outside reversal test
      fRec[Term].Direction           = Direction(Close[lhLowBar]-Open[lhHighBar]);  
    else
      fRec[Term].Direction           = Direction(lhLowBar-lhHighBar);
    
    
    //-- Initialize opening fibo points
    if (fRec[Term].Direction==DirectionUp)        //-- Initialize uptrend
    {
      fRec[Term].Root                = Low[lhLowBar];
      fRec[Term].Base                = High[iHighest(Symbol(),0,MODE_HIGH,(fBars-lhLowBar)+1,lhLowBar+1)];
      fRec[Term].High                = High[lhHighBar];
      
      if (lhHighBar-(fBars-fSeed)==0)             //-- Set retrace based on opening breakout pattern
        fRec[Term].Low               = Close[lhHighBar];
      else      
        fRec[Term].Low               = Low[iLowest(Symbol(),0,MODE_LOW,lhHighBar-(fBars-fSeed),fBars-fSeed)];

      //--- Testing visuals - opening fibonacci
      NewArrow(SYMBOL_ARROWDOWN,clrYellow,"lBase",fRec[Term].Base,iHighest(Symbol(),0,MODE_HIGH,(fBars-lhLowBar)+1,lhLowBar+1));
      NewArrow(SYMBOL_ARROWUP,clrYellow,"lRoot",fRec[Term].Root,lhLowBar);
      NewArrow(SYMBOL_ARROWDOWN,clrYellow,"lExpansion",fRec[Term].High,lhHighBar);
      NewArrow(SYMBOL_ARROWUP,clrYellow,"lRetrace",fRec[Term].Low,BoolToInt(lhHighBar-(fBars-fSeed)==0,lhHighBar,iLowest(Symbol(),0,MODE_LOW,lhHighBar-(fBars-fSeed),fBars-fSeed)));
    }
    else
    if (fRec[Term].Direction==DirectionDown)      //-- Initialize downtrend
    {
      fRec[Term].Root                = High[lhHighBar];
      fRec[Term].Base                = Low[iLowest(Symbol(),0,MODE_LOW,(fBars-lhHighBar)+1,lhHighBar+1)];
      fRec[Term].Low                 = Low[lhLowBar];

      if (lhLowBar-(fBars-fSeed)==0)              //-- Set retrace based on opening breakout pattern
        fRec[Term].High              = Close[lhLowBar];
      else      
        fRec[Term].High              = High[iHighest(Symbol(),0,MODE_HIGH,lhLowBar-(fBars-fSeed),fBars-fSeed)];

      //--- Testing visuals - opening fibonacci
      NewArrow(SYMBOL_ARROWUP,clrRed,"lBase",fRec[Term].Base,iLowest(Symbol(),0,MODE_LOW,(fBars-lhHighBar)+1,lhHighBar+1));
      NewArrow(SYMBOL_ARROWDOWN,clrRed,"lRoot",fRec[Term].Root,lhHighBar);
      NewArrow(SYMBOL_ARROWUP,clrRed,"lExpansion",fRec[Term].Low,lhLowBar);
      NewArrow(SYMBOL_ARROWDOWN,clrRed,"lRetrace",fRec[Term].High,BoolToInt(lhLowBar-(fBars-fSeed)==0,lhLowBar,iHighest(Symbol(),0,MODE_HIGH,lhLowBar-(fBars-fSeed),fBars-fSeed)));
    }
    
    //--- Initialize event flags
    fRec[Term].IsPegged                         = false;
    fRec[Term].IsReversing                      = false;
    fRec[Term].IsExpanding                      = false;
    fRec[Term].HitTarget                        = false;
    fRec[Term].HitTargetMax                     = false;

    fRec[Trend]                      = fRec[Term];
    
    for (fBar=fBars-fSeed;fBar<fBars;fBar--)
      break;

    string rsComment;
    
    rsComment   = "Fibo Term: (b) "+DoubleToStr(fRec[Term].Base,Digits)
                  +" (r) "+DoubleToStr(fRec[Term].Root,Digits)
                  +" (h) "+DoubleToStr(fRec[Term].High,Digits)
                  +" (l) "+DoubleToStr(fRec[Term].Low,Digits)
                  +" (c) "+DoubleToStr(Close[fBar],Digits)+"%\n";

                  
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

    double fExpansion         = BoolToDouble(fRec[Type].Direction==DirectionUp,fRec[Type].High,fRec[Type].Low);
    double fRetrace           = BoolToDouble(Measure==Now,Close[fBar],BoolToDouble(fRec[Type].Direction==DirectionUp,fRec[Type].Low,fRec[Type].High));
    double fBase              = BoolToDouble(Mode==Linear,fExpansion,fRec[Type].Base);
    double fRoot              = fRec[Type].Root;
        
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