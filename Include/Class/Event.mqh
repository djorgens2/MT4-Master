//+------------------------------------------------------------------+
//|                                                        Event.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property version   "1.10"
#property strict

#include <std_utility.mqh>

//+------------------------------------------------------------------+
//| Event Class - Indicator stack used to flag a named event         |
//+------------------------------------------------------------------+
class CEvent
  {
protected:
       enum     AlertLevel
                {
                  NoAlert,
                  Notify,
                  Nominal,
                  Warning,
                  Minor,
                  Major,
                  Critical
                };

       enum     EventType
                {
                  NoEvent,
                  NewDirection,
                  NewSegment,
                  NewTick,
                  NewFractal,
                  NewFibonacci,
                  NewPivot,
                  NewStdDev,
                  NewFOC,
                  NewState,
                  NewAction,
                  NewActionState,
                  NewBias,
                  NewRange,
                  NewOrigin,
                  NewTrend,
                  NewTerm,
                  NewBase,
                  NewDivergence,
                  NewConvergence,
                  NewExpansion,
                  NewContraction,
                  NewRetrace,
                  NewCorrection,
                  NewRecovery,
                  NewPoly,
                  NewPolyTrend,
                  NewPolyBoundary,
                  NewPolyState,
                  NewHigh,
                  NewLow,
                  NewBoundary,
                  NewBreakout,
                  NewReversal,
                  NewRally,
                  NewPullback,
                  NewTrap,
                  NewIdle,
                  NewWax,
                  NewWane,
                  SessionOpen,
                  SessionClose,
                  NewDay,
                  NewHour,
                  EventTypes
                };

private:

      bool           eEvents[EventTypes];
      
      EventType      eLastEvent;
      AlertLevel     eAlerts[EventTypes];
      AlertLevel     eMaxAlert;

public:
                     CEvent(){ClearEvents();};
                    ~CEvent(){};

      void           SetEvent(EventType Event, AlertLevel Level=Notify);
      void           ClearEvent(EventType Event);
      void           ClearEvents(void);

      AlertLevel     AlertLevel(EventType Event)       {return (eAlerts[Event]);}
      AlertLevel     HighAlert(void)                   {return (eMaxAlert);}

      string         ActiveEventText(bool WithHeader=true);
      string         EventStr(void);
      
      //---  General use events
      bool           Event(EventType Event)            {return (eEvents[Event]);}
      bool           Event(EventType Event, AlertLevel Level)
                                                       {return (eAlerts[Event]==Level);}
      bool           ActiveEvent(void)                 {return (!eEvents[NoEvent]);}
      EventType      LastEvent(void)                   {return (eLastEvent);};

      bool           operator[](const EventType Event) {return(eEvents[Event]);}
  };

//+------------------------------------------------------------------+
//| SetEvent - Sets the triggering event to true                     |
//+------------------------------------------------------------------+
void CEvent::SetEvent(EventType Event, AlertLevel Level=Notify)
  {
    if (IsEqual(Event,NoEvent))
      return;

    eEvents[NoEvent]        = false;
    eEvents[Event]          = true;
    eAlerts[Event]          = fmax(Level,eAlerts[Event]);
    eMaxAlert               = fmax(Level,eMaxAlert);
    eLastEvent              = Event;
  }
  
//+------------------------------------------------------------------+
//| ClearEvent - Sets a specific event to false                      |
//+------------------------------------------------------------------+
void CEvent::ClearEvent(EventType Event)
  {
    if (Event==NoEvent)
      return;

    eEvents[NoEvent]        = true;
    eEvents[Event]          = false;
    eAlerts[Event]          = NoAlert;
    eMaxAlert               = NoAlert;
    
    for (EventType event=NewDirection;event<EventTypes;event++)
      if (eEvents[event])
      {
        eEvents[NoEvent]    = false;
        eMaxAlert           = fmax(eAlerts[event],eMaxAlert);
      }
  }
  
//+------------------------------------------------------------------+
//| ClearEvents - Initializes all events to false                    |
//+------------------------------------------------------------------+
void CEvent::ClearEvents(void)
  {
    ArrayInitialize(eEvents,false);    
    ArrayInitialize(eAlerts,NoAlert);
    
    eEvents[NoEvent]        = true;
    eMaxAlert               = NoAlert;
    eLastEvent              = NoEvent;
  }
  
//+------------------------------------------------------------------+
//| ActiveEventText - String of active events formatted for display  |
//+------------------------------------------------------------------+
string CEvent::ActiveEventText(bool WithHeader=true)
  {
    string aeActiveEvents   = "\n------------------------------";
    
    if (WithHeader)
      aeActiveEvents        = Symbol()+" Events"+aeActiveEvents;
    
    if (this.ActiveEvent())
    {
      for (EventType event=NewDirection;event<EventTypes;event++)
        if (eEvents[event])
          Append(aeActiveEvents, EnumToString(eAlerts[event])+":"+EnumToString(event), "\n");
    }
    else Append(aeActiveEvents, "No Active Events", "\n");
    
    return (aeActiveEvents);
  }

//+------------------------------------------------------------------+
//| EventStr - String of active events formatted for Log             |
//+------------------------------------------------------------------+
string CEvent::EventStr(void)
  {
    string text   = "";
    
    if (this.ActiveEvent())
    {
      for (EventType event=NewDirection;event<EventTypes;event++)
        if (eEvents[event])
          Append(text, EnumToString(eAlerts[event])+":"+EnumToString(event),"|");
    }
    else Append(text,"No Active Events");
    
    return (text);
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

//+------------------------------------------------------------------+
//| BoolToEvent - Returns a TF event based on supplied condition     |
//+------------------------------------------------------------------+
EventType BoolToEvent(bool IsTrue, EventType TrueValue, EventType FalseValue=NoEvent)
  {
    if (IsTrue)
      return (TrueValue);

    return (FalseValue);
  }

//+------------------------------------------------------------------+
//| IsEqual - Compares events to determine equivalence               |
//+------------------------------------------------------------------+
bool IsEqual(EventType Event1, EventType Event2)
  {
    return (Event1==Event2);
  }
  
const string EventText[EventTypes] =
             {
               "No Event",
               "New Direction",
               "New Segment",
               "New Tick",
               "New Fractal",
               "New Fibonacci",
               "New Pivot",
               "New Std Dev",
               "New FOC",
               "New State",
               "New Action",
               "New Action State",
               "New Bias",
               "New Range",
               "New Origin",
               "New Trend",
               "New Term",
               "New Base",
               "New Divergence",
               "New Convergence",
               "New Expansion",
               "New Contraction",
               "New Retrace",
               "New Correction",
               "New Recovery",
               "New Poly",
               "New Poly Trend",
               "New Poly Boundary",
               "New Poly State",
               "New High",
               "New Low",
               "New Boundary",
               "New Breakout",
               "New Reversal",
               "New Rally",
               "New Pullback",
               "New Trap",
               "New Idle",
               "New Wax",
               "New Wane",
               "Session Open",
               "Session Close",
               "New Day",
               "New Hour"
             };