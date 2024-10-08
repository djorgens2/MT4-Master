//+------------------------------------------------------------------+
//|                                                        Event.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property version   "1.10"
#property strict

#include <stdutil.mqh>

//+------------------------------------------------------------------+
//| Event Class - Indicator stack used to flag a named event         |
//+------------------------------------------------------------------+
class CEvent
  {
protected:
       enum     AlertType
                {
                  NoAlert,
                  Notify,
                  Nominal,
                  Warning,
                  Minor,
                  Major,
                  Critical,
                  AlertTypes
                };

       enum     EventType
                {
                  NoEvent,
                  AdverseEvent,  //-- Very bad event
                  NewHigh,
                  NewLow,
                  NewBoundary,
                  NewDirection,  //-- Directional change
                  NewState,
                  NewBias,
                  NewTick,       //-- Tick level event; aggregate or trade
                  NewSegment,    //-- Segment level event; aggregate of Ticks
                  NewContraction,
                  NewFractal,    //-- Fractal Direction change
                  NewFibonacci,  //-- Fibonacci Level change only
                  NewOrigin,
                  NewTrend,
                  NewTerm,
                  NewLead,
                  NewExpansion,
                  NewDivergence,
                  NewConvergence,
                  NewRally,
                  NewPullback,
                  NewRetrace,
                  NewCorrection,
                  NewRecovery,
                  NewBreakout,
                  NewReversal,
                  NewExtension,
                  NewFlatline,
                  NewConsolidation,
                  NewParabolic,  //-- Expanding, Multidirectional (parabolic) event
                  NewChannel,
                  CrossCheck,
                  Exception,
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
                       AlertType     Alert;
                       double        Price;
                     };

      bool           eEvent[EventTypes];
      AlertType      eAlert[EventTypes];
      AlertType      eMaxAlert;
      EventType      eMaxEvent;
      EventLog       eLog[];

public:
                     CEvent(){ClearEvents();};
                    ~CEvent(){};

      void           SetEvent(EventType Event, AlertType Alert=Notify, double Price=NoValue);
      void           ClearEvent(EventType Event);
      void           ClearEvents(void);

      EventLog       LastEvent(void)                             {return eLog[0];};
      EventType      MaxEvent(void)                              {return eMaxEvent;};
      AlertType      MaxAlert(void)                              {return eMaxAlert;};
      AlertType      Alert(EventType Event)                      {return eAlert[Event];};
      
      EventLog       Log(EventType Event);
      bool           Logged(EventType Event, AlertType Alert=NoAlert);

      //---  General use events
      bool           Event(EventType Event)                      {return eEvent[Event];};
      bool           Event(EventType Event, AlertType Alert)     {return eAlert[Event]==Alert&&Alert>NoAlert;};
      bool           ActiveEvent(void)                           {return !eEvent[NoEvent];};

      string         ActiveEventStr(bool WithHeader=true);
      string         EventStr(void);
      string         EventStr(EventType Begin, EventType End);
      string         EventLogStr(EventType Type=NoEvent);
      
      bool           operator[](const EventType Event)           {return eEvent[Event];};
      bool           operator[](const AlertType Alert)           {return Alert==eMaxAlert;};
  };

//+------------------------------------------------------------------+
//| SetEvent - Sets the triggering event to true                     |
//+------------------------------------------------------------------+
void CEvent::SetEvent(EventType Event, AlertType Alert=Notify, double Price=NoValue)
  {
    if (IsEqual(Event,NoEvent))
      return;

    eEvent[NoEvent]         = false;
    eEvent[Event]           = true;
    eAlert[Event]           = fmax(Alert,eAlert[Event]);

    if (IsHigher(Alert,eMaxAlert))
      eMaxEvent             = Event;

    if (IsEqual(eMaxAlert,Alert))
      eMaxEvent             = fmax(eMaxEvent,Event);

    ArrayCopy(eLog,eLog,1,0,WHOLE_ARRAY);
    
    eLog[0].Event           = Event;
    eLog[0].Alert           = Alert;
    eLog[0].Price           = BoolToDouble(IsEqual(Price,NoValue),Close[0],Price);
  }

//+------------------------------------------------------------------+
//| ClearEvent - Sets a specific event to false                      |
//+------------------------------------------------------------------+
void CEvent::ClearEvent(EventType Event)
  {
    if (Event==NoEvent)
      return;

    eEvent[NoEvent]         = true;
    eEvent[Event]           = false;
    eAlert[Event]           = NoAlert;

    eMaxAlert               = NoAlert;
    eMaxEvent               = NoEvent;

    for (EventType event=NoEvent;event<EventTypes;event++)
      if (eEvent[event])
      {
        eEvent[NoEvent]     = false;
        eMaxAlert           = fmax(eAlert[event],eMaxAlert);

        if (IsEqual(eMaxAlert,eAlert[event]))
          eMaxEvent         = fmax(eMaxEvent,Event);
      }
  }

//+------------------------------------------------------------------+
//| ClearEvents - Initializes all events to false                    |
//+------------------------------------------------------------------+
void CEvent::ClearEvents(void)
  {
    ArrayInitialize(eEvent,false);    
    ArrayInitialize(eAlert,NoAlert);
    ArrayResize(eLog,0,100);

    eEvent[NoEvent]         = true;
    eMaxAlert               = NoAlert;
    eMaxEvent               = NoEvent;
  }

//+------------------------------------------------------------------+
//| Log - Returns Log Entry for supplied EventType                   |
//+------------------------------------------------------------------+
EventLog CEvent::Log(EventType Event)
  {
    EventLog eventlog    = {NoEvent,NoAlert,NoValue};
    
    if (eEvent[Event])
      for (int node=0;node<ArraySize(eLog);node++)
        if (IsEqual(eLog[node].Event,Event))
          return eLog[node];
        
    return eventlog;
  }

//+------------------------------------------------------------------+
//| Logged - Returns true if Event logged for the supplied alert     |
//+------------------------------------------------------------------+
bool CEvent::Logged(EventType Event, AlertType Alert=NoAlert)
  {
    if (eEvent[Event])
      for (int node=0;node<ArraySize(eLog);node++)
        if (IsEqual(eLog[node].Event,Event))
          if (IsEqual(eLog[node].Alert,Alert))
            return true;
        
    return false;
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
        if (eEvent[event])
          Append(text,EnumToString(eAlert[event])+":"+EnumToString(event),"\n");
    }
    else Append(text, "No Active Events", "\n");
    
    return text;
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
        if (eEvent[event])
          Append(text, EnumToString(eAlert[event])+":"+EnumToString(event),"|");
    }
    else Append(text,"No Active Events");
    
    return text;
  }

//+------------------------------------------------------------------+
//| EventStr - String of active events formatted for Log             |
//+------------------------------------------------------------------+
string CEvent::EventStr(EventType Begin, EventType End)
  {
    string text   = "";

    Append(text,EnumToString(MaxAlert()),"|");
    Append(text,EnumToString(Begin),"|");
    
    for (EventType event=Begin;event<End;event++)
      Append(text,EnumToString(eAlert[event]),"|");

    Append(text,EnumToString(End),"|");
    
    return text;
  }

//+------------------------------------------------------------------+
//| EventLogStr - returns the event log in order of execution        |
//+------------------------------------------------------------------+
string CEvent::EventLogStr(EventType Type=NoEvent)
  {
    string text   = "";

    if (ActiveEvent())
      for (int node=0;node<ArraySize(eLog);node++)
        if (Type==NoEvent||Type==eLog[node].Event)
        {
          Append(text,EnumToString(eLog[node].Alert),"\n");
          Append(text,EnumToString(eLog[node].Event));
          Append(text,DoubleToStr(eLog[node].Price,Digits),"@");
        }
    
    return text;
  }

//+------------------------------------------------------------------+
//| EventText - String of active events formatted for Log            |
//+------------------------------------------------------------------+
string EventText(EventType Event)
  {
    const string text[EventTypes] =
                 {
                   "No Event",
                   "Adverse Event",
                   "New High",
                   "New Low",
                   "New Boundary",
                   "New Direction",
                   "New State",
                   "New Bias",
                   "New Tick",
                   "New Segment",
                   "New Contraction",
                   "New Fractal",
                   "New Fibonacci",
                   "New Origin",
                   "New Trend",
                   "New Term",
                   "New Lead",
                   "New Expansion",
                   "New Divergence",
                   "New Convergence",
                   "New Rally",
                   "New Pullback",
                   "New Retrace",
                   "New Correction",
                   "New Recovery",
                   "New Breakout",
                   "New Reversal",
                   "New Extension",
                   "New Flatline",
                   "New Consolidation",
                   "New Parabolic",
                   "New Channel",
                   "Cross Check",
                   "Exception",
                   "Session Open",
                   "Session Close",
                   "New Day",
                   "New Hour"
                 };

    return text[Event];
  }

//+------------------------------------------------------------------+
//| BoolToEvent - Returns event based on supplied condition          |
//+------------------------------------------------------------------+
EventType BoolToEvent(bool IsTrue, EventType TrueValue, EventType FalseValue=NoEvent)
  {
    if (IsTrue)
      return TrueValue;

    return FalseValue;
  }

//+------------------------------------------------------------------+
//| BoolToAlert - Returns supplied AlertLevel based on Condition     |
//+------------------------------------------------------------------+
AlertType BoolToAlert(bool IsTrue, AlertType TrueValue, AlertType FalseValue=NoAlert)
  {
    if (IsTrue)
      return TrueValue;

    return FalseValue;
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(EventType &Check, EventType Compare, bool Update=true)
  {
    if (Check==Compare)
      return false;
   
    if (Update) 
      Check   = Compare;
  
    return true;
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(AlertType &Check, AlertType Compare, bool Update=true)
  {
    if (Check==Compare)
      return false;
   
    if (Update) 
      Check   = Compare;
  
    return true;
  }

//+------------------------------------------------------------------+
//| IsHigher - Returns true on higher FibonacciType                  |
//+------------------------------------------------------------------+
bool IsHigher(EventType Check, EventType &Change, bool Update=true)
  {
    if (Check>Change)
      return (IsChanged(Change,Check,Update));

    return (false);
  }

//+------------------------------------------------------------------+
//| IsHigher - Returns true on higher FibonacciType                  |
//+------------------------------------------------------------------+
bool IsHigher(AlertType Check, AlertType &Change, bool Update=true)
  {
    if (Check>Change)
      return (IsChanged(Change,Check,Update));

    return (false);
  }

