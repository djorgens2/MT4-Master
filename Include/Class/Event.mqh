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
//|                                                                  |
//+------------------------------------------------------------------+
class CEvent
  {
protected:
       enum     EventType
                {
                  NewDirection,
                  NewFractal,
                  NewPivot,
                  NewPivotDirection,
                  NewOrigin,
                  NewOriginDirection,
                  NewMajor,
                  NewMinor,
                  TrendWane,
                  TrendNone,
                  TrendResume,
                  NewTerm,
                  NewTrend,
                  NewOffSessionPivot,
                  NewHigh,
                  NewLow,
                  NewBoundary,
                  NewAggregate,
                  NewBreakout,
                  NewReversal,
                  NewRally,
                  NewPullback,
                  SessionOpen,
                  SessionClose,
                  NewDay,
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