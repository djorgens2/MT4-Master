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
                    double        fiboOrigin;
                    double        fiboTrend;
                    double        fiboTermHigh;
                    double        fiboTermLow;
                    double        fiboTermBase;
                    double        fiboTermRoot;

                    //--- Fibo price direction
                    int           fiboOriginDir;
                    int           fiboTerndDir;
                    int           fiboTermDir;
                    
                    //--- Fibo Events
                    bool          IsPegged;      //-- 50% retrace of total expansion after breakout
                    bool          IsReversing;   //-- 23% expansion after breakout (76% retrace)
                    bool          IsExpanding;   //-- 261% expansion (start new high/low metrics)
                    bool          HitTarget;     //-- 161% expansion acquired
                    bool          HitTargetMax;  //-- 423% expansion acquired; new fractal metrics;

private:

                    void LoadHistory(void);
                     
                    int           fBar;          //-- Current bar
                    int           fBars;         //-- Total bars
                    int           fSeed;         //-- History seed (default: 24 periods)
                     
                    CArrayDouble *fBuffer;
                    CEvent       *fEvent;
                     

public:
                    CFibonacci(int Seed=24);
                   ~CFibonacci(void);

  };

//+------------------------------------------------------------------+
//| LoadHistory - Prepopulate historical data and events             |
//+------------------------------------------------------------------+
void CFibonacci::LoadHistory(void)
  {
    int lhHighBar                    = iHighest(Symbol(),0,MODE_HIGH,fSeed,fBars-fSeed);
    int lhLowBar                     = iLowest(Symbol(),0,MODE_LOW,fSeed,fBars-fSeed);

    if (lhLowBar==lhHighBar)
    {
      fiboTermDir                    = Direction(Close[lhLowBar]-Open[lhHighBar]);
      fEvent.SetEvent(NewReversal);
    }
    else
      fiboTermDir                    = Direction(lhLowBar-lhHighBar);
    
    
    if (fiboTermDir==DirectionUp)
    {
      //-- Initialize uptrend
      fiboTermRoot                   = Low[lhLowBar];
      fiboTermBase                   = High[iHighest(Symbol(),0,MODE_HIGH,(fBars-lhLowBar)+1,lhLowBar+1)];
      fiboTermHigh                   = High[lhHighBar];
      
      //-- Test for breakout-in-progress; set accurate retrace
      if (lhHighBar-(fBars-fSeed)==0)
        fiboTermLow                  = Close[lhHighBar];
      else      
        fiboTermLow                  = Low[iLowest(Symbol(),0,MODE_LOW,lhHighBar-(fBars-fSeed),fBars-fSeed)];
    }
    else
    if (fiboTermDir==DirectionDown)
    {
      //-- Initialize downtrend
      fiboTermRoot                   = High[lhHighBar];
      fiboTermBase                   = Low[iLowest(Symbol(),0,MODE_LOW,(fBars-lhHighBar)+1,lhHighBar+1)];
      fiboTermLow                    = Low[lhLowBar];

      //-- Test for breakout-in-progress; set accurate retrace
      if (lhLowBar-(fBars-fSeed)==0)
        fiboTermHigh                 = Close[lhLowBar];
      else      
        fiboTermHigh                 = High[iHighest(Symbol(),0,MODE_HIGH,lhLowBar-(fBars-fSeed),fBars-fSeed)];
    }
    else
    {
      //-- Initialize outside reversal
    
    }
    
    Print("lb:"+IntegerToString(lhLowBar)+" hb:"+IntegerToString(lhHighBar)+" fseed agg:"+IntegerToString(fBars-fSeed)+" fBars:"+IntegerToString(fBars)+" fSeed:"+IntegerToString(fSeed));
    
    if (fiboTermDir==DirectionUp)
    {
      NewArrow(SYMBOL_ARROWDOWN,clrYellow,"lBase",fiboTermBase,iHighest(Symbol(),0,MODE_HIGH,(fBars-lhLowBar)+1,lhLowBar+1));
      NewArrow(SYMBOL_ARROWUP,clrYellow,"lRoot",fiboTermRoot,lhLowBar);
      NewArrow(SYMBOL_ARROWDOWN,clrYellow,"lExpansion",fiboTermHigh,lhHighBar);
      NewArrow(SYMBOL_ARROWUP,clrYellow,"lRetrace",fiboTermLow,BoolToInt(lhHighBar-(fBars-fSeed)==0,lhHighBar,iLowest(Symbol(),0,MODE_LOW,lhHighBar-(fBars-fSeed),fBars-fSeed)));
    }
    else
    if (fiboTermDir==DirectionDown)
    {
      NewArrow(SYMBOL_ARROWUP,clrRed,"lBase",fiboTermBase,iLowest(Symbol(),0,MODE_LOW,(fBars-lhHighBar)+1,lhHighBar+1));
      NewArrow(SYMBOL_ARROWDOWN,clrRed,"lRoot",fiboTermRoot,lhHighBar);
      NewArrow(SYMBOL_ARROWUP,clrRed,"lExpansion",fiboTermLow,lhLowBar);
      NewArrow(SYMBOL_ARROWDOWN,clrRed,"lRetrace",fiboTermHigh,BoolToInt(lhLowBar-(fBars-fSeed)==0,lhLowBar,iHighest(Symbol(),0,MODE_HIGH,lhLowBar-(fBars-fSeed),fBars-fSeed)));
    }
//    for (fBar=fBars;fBar<fBars-fSeed;fBar--)
//    {
//      fEvent.ClearEvents();
//      
//      if (IsHigher(High[fBar],fiboTermHigh))
//        fEvent.SetEvent(NewHigh);
//        
//      if (IsLower(Low[fBar],fiboTermLow))
//        fEvent.SetEvent(NewLow);
//        
//      if (fEvent[NewHigh]&&fEvent[NewLow])  //-- Handle outside reversal
//      {
//        if (NewDirection(fiboTermDir,Direction(Close[fBar]-Open[fBar])))
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
    
    //--- Initialize event flags
    IsPegged                         = false;
    IsReversing                      = false;
    IsExpanding                      = false;
    HitTarget                        = false;
    HitTargetMax                     = false;
    
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