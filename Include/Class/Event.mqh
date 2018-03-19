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
                  NewOrigin,
                  NewMajor,
                  NewMinor,
                  TrendWane,
                  TrendNone,
                  TrendResume,
                  NewTerm,
                  NewTrend,
                  NewHigh,
                  NewLow,
                  NewBoundary,
                  NewAggregate,
                  NewBreakout,
                  NewReversal,
                  InsideReversal,
                  SessionOpen,
                  SessionClose,
                  NewDay,
                  EventTypes
                };
                
private:

      bool Events[EventTypes];

public:
                     CEvent(){};
                    ~CEvent(){};

      void           SetEvent(EventType Event)   {Events[Event]=true;}
      void           ClearEvent(EventType Event) {Events[Event]=false;}
      void           ClearEvents(void)           {ArrayInitialize(Events,false);}

      bool           operator[](const EventType Event) const {return(Events[Event]);}

  };
