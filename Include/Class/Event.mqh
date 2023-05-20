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
                  Critical,
                  AlertLevels
                };

       enum     EventType
                {
                  NoEvent,
                  AdverseEvent,  //-- Very bad event
                  NewHigh,
                  NewLow,
                  NewBoundary,
                  NewDirection,  //-- Directional change; Nano thru Macro
                  NewState,
                  NewAction,
                  NewBias,
                  NewTick,       //-- Tick level event; aggregate or trade
                  NewSegment,    //-- Segment level event; aggregate of Ticks
                  NewPivot,
                  NewFractal,    //-- Fractal Direction change
                  NewContraction,
                  NewFibonacci,  //-- Fibonacci Level change only
                  NewOrigin,
                  NewTrend,
                  NewTerm,
                  NewBase,
                  NewExpansion,
                  NewDivergence,
                  NewConvergence,
                  NewInversion,
                  NewConversion,
                  NewLead,
                  NewRally,
                  NewPullback,
                  NewRetrace,
                  NewCorrection,
                  NewRecovery,
                  NewBreakout,
                  NewReversal,
                  NewFlatline,
                  NewConsolidation,
                  NewParabolic,  //-- Expanding, Multidirectional (parabolic) event
                  NewChannel,
                  SessionOpen,
                  SessionClose,
                  NewDay,
                  NewHour,
                  EventTypes
                };

private:

      struct         EventLog
                     {
                       EventType     Event;
                       AlertLevel    Alert;
                     };

      bool           eEvents[EventTypes];
      
      EventType      eLastEvent;
      AlertLevel     eAlerts[EventTypes];
      AlertLevel     eMaxAlert;
      EventLog       eEventLog[];

public:
                     CEvent(){ClearEvents();};
                    ~CEvent(){};

      void           SetEvent(EventType Event, AlertLevel Level=Notify);
      void           ClearEvent(EventType Event);
      void           ClearEvents(void);

      AlertLevel     HighAlert(void)                   {return (eMaxAlert);}
      AlertLevel     EventLevel(EventType Event)       {return (eAlerts[Event]);}

      //---  General use events
      bool           Event(EventType Event)            {return (eEvents[Event]);}
      bool           Event(EventType Event, AlertLevel Level)
                                                       {return (eAlerts[Event]==Level&&Level>NoAlert);}
      bool           ActiveEvent(void)                 {return (!eEvents[NoEvent]);}
      EventType      LastEvent(void)                   {return (eLastEvent);};

      string         ActiveEventStr(bool WithHeader=true);
      string         EventStr(void);
      
      bool           operator[](const EventType Event)  {return(eEvents[Event]);}
      bool           operator[](const AlertLevel Level) {return(Level==eMaxAlert);}
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
    
    for (EventType event=NoEvent;event<EventTypes;event++)
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
//| ActiveEventStr - String of active events formatted for display   |
//+------------------------------------------------------------------+
string CEvent::ActiveEventStr(bool WithHeader=true)
  {
    string text   = "\n------------------------------";
    
    if (WithHeader)
      text        = Symbol()+" Events"+text;
    
    if (this.ActiveEvent())
    {
      for (EventType event=NoEvent;event<EventTypes;event++)
        if (eEvents[event])
          Append(text,EnumToString(eAlerts[event])+":"+EnumToString(event),"\n");
    }
    else Append(text, "No Active Events", "\n");
    
    return (text);
  }

//+------------------------------------------------------------------+
//| EventStr - String of active events formatted for Log             |
//+------------------------------------------------------------------+
string CEvent::EventStr(void)
  {
    string text   = "";
    
    if (this.ActiveEvent())
    {
      for (EventType event=NoEvent;event<EventTypes;event++)
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
    if (Compare==NoEvent)
      return (false);

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
               "Adverse Event",
               "New High",
               "New Low",
               "New Boundary",
               "New Direction",
               "New State",
               "New Action",
               "New Bias",
               "New Tick",
               "New Segment",
               "New Pivot",
               "New Fractal",
               "New Contraction",
               "New Fibonacci",
               "New Origin",
               "New Trend",
               "New Term",
               "New Base",
               "New Expansion",
               "New Divergence",
               "New Convergence",
               "New Inversion",
               "New Conversion",
               "New Lead",
               "New Rally",
               "New Pullback",
               "New Retrace",
               "New Correction",
               "New Recovery",
               "New Breakout",
               "New Reversal",
               "New Flatline",
               "New Consolidation",
               "New Parabolic",
               "New Channel",
               "Session Open",
               "Session Close",
               "New Day",
               "New Hour"
             };