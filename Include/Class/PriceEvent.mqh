//+------------------------------------------------------------------+
//|                                                   PriceEvent.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <stdutil.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPriceEvent
  {

private:

       struct         EventHistory
                      {
                        double Base;
                        double Root;
                        double Expansion;
                        double Retrace;
                        double Fibonacci;
                        bool   Trap;
                      };

       void           UpdateEvent(double EventFibonacci);
       void           AddHistory(double TermBase, double TermRoot, double EventFibonacci);

       int            peDirection;   // Direction of this price event object

       double         peTrendBase;
       double         peTrendRoot;
       double         peRetrace;
       double         peExpansion;
       double         peFibonacci;
       datetime       peUpdated;

       bool           pePegged;
       bool           peConfirmed;
       bool           peBroken;
              
       int            peCount;

       EventHistory   peHistory[];

public:

                      CPriceEvent(int EventDirection, double TrendBase, double TermBase, double EventRoot, double EventFibonacci);
                     ~CPriceEvent(void);

       void           Update(int TermDirection, double EventRoot, double EventFibonacci);            
       int            Direction(bool Contrarian=false) {if (Contrarian) return (peDirection*DirectionInverse); return (peDirection); }
       double         Fibonacci(RetraceType Type=Term, int Method=Retrace, int Measure=Now);


       double         Price(RetraceType EventType, int PriceType);
       int            Count(void)       { return (peCount+1); }
       datetime       Updated(void)     { return (peUpdated); }

       bool           IsPegged(void)    { return (pePegged); }
       bool           IsConfirmed(void) { return (peConfirmed); }
       bool           IsTrap(int Event) { return (peHistory[peCount].Trap); }
                    
  };
  
//+------------------------------------------------------------------+
//| AddHistory - store major fibo events occuring within this event  |
//+------------------------------------------------------------------+
void CPriceEvent::AddHistory(double TermBase, double TermRoot, double EventFibonacci)
  {
    if (this.IsPegged())
    {
      ArrayResize(peHistory,++peCount+1);
      
      peHistory[peCount].Base       = TermBase;
      peHistory[peCount].Root       = TermRoot;
      peHistory[peCount].Fibonacci  = EventFibonacci;

      peHistory[peCount].Expansion  = Close[0];
      peHistory[peCount].Retrace    = Close[0];

      peHistory[peCount].Trap       = false;

      peConfirmed                   = false;
      pePegged                      = false;
    }
  }

//+------------------------------------------------------------------+
//| UpdateEvent - Updates trend continuation data                    |
//+------------------------------------------------------------------+
void CPriceEvent::UpdateEvent(double EventFibonacci)
  { 
    peHistory[peCount].Fibonacci    = EventFibonacci;

    peHistory[peCount].Expansion    = Close[0];
    peHistory[peCount].Retrace      = Close[0];

    switch (this.Direction())
    {
      case DirectionUp:    if (IsHigher(Close[0],peExpansion))
                           {
                             peRetrace    = Close[0];
                             peUpdated    = Time[0];
                             peConfirmed  = pePegged;
                           }
                           break;
                               
      case DirectionDown:  if (IsLower(Close[0],peExpansion))
                           {
                             peRetrace    = Close[0];
                             peUpdated    = Time[0];
                             peConfirmed  = pePegged;
                           }
                           break;
    }
  }

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPriceEvent::CPriceEvent(int EventDirection, double TrendBase, double TermBase, double EventRoot, double EventFibonacci)
  {
    peDirection  = EventDirection;
    peTrendBase  = TrendBase;
    peTrendRoot  = EventRoot;

    peExpansion  = Close[0];
    peRetrace    = Close[0];
    peUpdated    = Time[0];

    peCount      = NoValue;

    pePegged     = true;
    peBroken     = false;
        
    AddHistory(TermBase, EventRoot, EventFibonacci);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPriceEvent::~CPriceEvent(void)
  {
  }


//+------------------------------------------------------------------+
//| EventPrice - public interface to return key event values         |
//+------------------------------------------------------------------+
double CPriceEvent::Price(RetraceType EventType, int PriceType)
  {
    //--- Currently supports Current Event only; could be expanded to include historical events;
    if (EventType == Term)
      switch (PriceType)
      {
        case Base:       return (NormalizeDouble(peHistory[peCount].Base,Digits));
        case Root:       return (NormalizeDouble(peHistory[peCount].Root,Digits));
        case Expansion:  return (NormalizeDouble(peHistory[peCount].Expansion,Digits));
        case Retrace:    return (NormalizeDouble(peHistory[peCount].Retrace,Digits));
      }
    
    if (EventType == Trend)
      switch (PriceType)
      {
        case Base:       return (NormalizeDouble(peTrendBase,Digits));
        case Root:       return (NormalizeDouble(peTrendRoot,Digits));
        case Expansion:  return (NormalizeDouble(peExpansion,Digits));
        case Retrace:    return (NormalizeDouble(peRetrace,Digits));
      }

    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| Fibonacci - returns event level term/trend fibo %                |
//+------------------------------------------------------------------+
double CPriceEvent::Fibonacci(RetraceType Type=Term, int Method=Retrace, int Measure=Now)
  {
    double efRange      = 0.00;
    
    if (Type == Term)
    {      
      if (Method == Expansion)
      {
        efRange           = peHistory[peCount].Root-peHistory[peCount].Base;

        switch (Measure)
        {
          case Now: return (fdiv(peHistory[peCount].Root-Close[0],efRange,3)); 
          case Max: return (fdiv(peHistory[peCount].Root-peHistory[peCount].Expansion,efRange,3)); 
        }
      }

      if (Method == Retrace)
      {
        efRange           = peHistory[peCount].Expansion-peHistory[peCount].Root;
        
        switch (Measure)
        {
          case Now: return (fdiv(peHistory[peCount].Expansion-Close[0],efRange,3)); 
          case Max: return (fdiv(peHistory[peCount].Expansion-peHistory[peCount].Retrace,efRange,3));
        }
      }
    }
      
    if (Type == Trend)
    {
      if (Method == Expansion)
      {  
        efRange           = peTrendRoot-peTrendBase;

        switch (Measure)
        {
          case Now: return (fdiv(peTrendRoot-Close[0],efRange,3));  
          case Max: return (fdiv(peTrendRoot-peExpansion,efRange,3));
        }
      }

      if (Method == Retrace)
      {
        efRange           = peExpansion-peTrendRoot;  //---- Revisit retrace calc;
        
        switch (Measure)
        {
          case Now: return (fdiv(peExpansion-Close[0],efRange,3));  
          case Max: return (fdiv(peExpansion-peRetrace,efRange,3));
        }
      }
    }
    
    return (NoValue);
  }
  
  
//+------------------------------------------------------------------+
//| Update - updates Event data                                      |
//+------------------------------------------------------------------+
void CPriceEvent::Update(int TermDirection, double TermRoot, double EventFibonacci)
  {
    double uEventFibonacci  = FiboPercent(Fibo161);
    double uLastExpansion   = peExpansion;
    
    peFibonacci             = EventFibonacci;
    
    if (TermDirection != this.Direction())
      pePegged              = true;

    switch (this.Direction())
    {
      case DirectionUp:     if (IsHigher(Close[0],peHistory[peCount].Expansion))
                              UpdateEvent(EventFibonacci);
                            break;
                               
      case DirectionDown:   if (IsLower(Close[0],peHistory[peCount].Expansion))
                              UpdateEvent(EventFibonacci);
                            break;
    }

    if (IsHigher(EventFibonacci,uEventFibonacci))
      AddHistory(uLastExpansion,TermRoot,EventFibonacci);
      
    switch (this.Direction())
    {
      case DirectionUp:     if (IsLower(Close[0],peHistory[peCount].Retrace))
                            {
                              peRetrace                  = Close[0];
                              
                              if (IsLower(Close[0],peHistory[peCount].Root,NoUpdate))
                                peHistory[peCount].Trap  = true;

                              if (IsLower(Close[0],peTrendRoot,NoUpdate))
                                peBroken                 = true;
                            }
                            break;

      case DirectionDown:   if (IsHigher(Close[0],peHistory[peCount].Retrace))
                            {
                              peRetrace                  = Close[0];
                              
                              if (IsHigher(Close[0],peHistory[peCount].Root,NoUpdate))
                                peHistory[peCount].Trap  = true;

                              if (IsHigher(Close[0],peTrendRoot,NoUpdate))
                                peBroken                 = true;
                            }
                            break;
    }
  }

