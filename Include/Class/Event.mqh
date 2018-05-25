//+------------------------------------------------------------------+
//|                                                        Event.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <stdutil.mqh>

//+------------------------------------------------------------------+
//| Event Class - Indicator stack used to flag a named event         |
//+------------------------------------------------------------------+
class CEvent
  {
protected:
       enum     EventType
                {
                  NewDirection,
                  NewFractal,
                  NewFibonacci,
                  NewPivot,
                  NewPivotDirection,
                  NewOrigin,
                  NewOriginDirection,
                  NewMajor,
                  NewMinor,
                  TrendWane,
                  TrendResume,
                  NewState,
                  NewTerm,
                  NewTrend,
                  NewDivergence,
                  NewHigh,
                  NewLow,
                  NewBoundary,
                  NewAggregate,
                  NewBreakout,
                  NewReversal,
                  NewRally,
                  NewPullback,
                  NewRetrace,
                  SessionOpen,
                  SessionClose,
                  NewDay,
                  NoEvent,
                  EventTypes
                };
                
private:

      bool eEvents[EventTypes];

public:
                     CEvent(){};
                    ~CEvent(){};

      void           SetEvent(EventType Event)   {eEvents[Event]=true;}
      void           ClearEvent(EventType Event) {eEvents[Event]=false;}
      void           ClearEvents(void)           {ArrayInitialize(eEvents,false);}
      bool           ActiveEvent(void);

      bool           operator[](const EventType Event) const {return(eEvents[Event]);}

  };

bool CEvent::ActiveEvent(void)
  {
    bool aeEvent   = false;
    
    for (EventType event=NewDirection;event<EventTypes;event++)
      if (eEvents[event])
        return (true);
        
    return (false);
  }
  
//+------------------------------------------------------------------+
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool IsChanged(EventType &Compare, EventType Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }

