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
                  NewHour,
                  NoEvent,
                  EventTypes
                };
                
private:

      bool eEvents[EventTypes];
      bool eActiveEvent;

public:
                     CEvent(){};
                    ~CEvent(){};

      void           SetEvent(EventType Event);
      void           ClearEvent(EventType Event);
      void           ClearEvents(void);
      bool           ActiveEvent(void)  {return(eActiveEvent);}

      bool           operator[](const EventType Event) const {return(eEvents[Event]);}

  };

//+------------------------------------------------------------------+
//| SetEvent - Sets the triggering event to true                     |
//+------------------------------------------------------------------+
void CEvent::SetEvent(EventType Event)
  {
    eEvents[Event] = true;
    eActiveEvent   = true;
  }
  
//+------------------------------------------------------------------+
//| ClearEvent - Sets a specific event to false                      |
//+------------------------------------------------------------------+
void CEvent::ClearEvent(EventType Event)
  {
    eActiveEvent   = false;
    eEvents[Event] = false;
    
    for (EventType event=NewDirection;event<EventTypes;event++)
      if (eEvents[event])
      {
        eActiveEvent   = true;
        break;
      }
  }
  
//+------------------------------------------------------------------+
//| ClearEvents - Initializes all events to false                    |
//+------------------------------------------------------------------+
void CEvent::ClearEvents(void)
  {
    ArrayInitialize(eEvents,false);
    eActiveEvent   = false;
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

