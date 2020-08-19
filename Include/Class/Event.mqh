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
       enum     AlertLevelType
                {
                  NoAlert,
                  Notify,
                  Warning,
                  Nominal,
                  Minor,
                  Major,
                  Critical
                };

       enum     EventType
                {
                  NoEvent,
                  NewDirection,
                  NewFractal,
                  NewPivot,
                  NewStdDev,
                  NewFOC,
                  NewState,
                  NewAction,
                  NewActionState,
                  NewProximityAlert,
                  NewBias,
                  NewRange,
                  NewDecay,
                  NewWaveOpen,
                  NewWaveClose,
                  NewWaveState,
                  NewWaveReversal,
                  NewTerm,
                  NewTrend,
                  NewOrigin,
                  NewDivergence,
                  NewConvergence,
                  NewExpansion,
                  NewContraction,
                  NewRetrace,
                  NewRecovery,
                  NewPoly,
                  NewPolyTrend,
                  NewPolyBoundary,
                  NewPolyState,
                  NewOriginState,
                  NewTrendState,
                  NewTermState,
                  NewHigh,
                  NewLow,
                  NewBoundary,
                  NewBreakout,
                  NewReversal,
                  NewRally,
                  NewPullback,
                  NewTrap,
                  NewCrest,
                  NewTrough,
                  NewCorrection,
                  NewIdle,
                  NewWane,
                  NewResume,
                  SessionOpen,
                  SessionClose,
                  NewDay,
                  NewHour,
                  EventTypes
                };
                
private:

      bool           eEvents[EventTypes];
      
      AlertLevelType eAlerts[EventTypes];
      AlertLevelType eMaxAlert;

public:
                     CEvent(){ClearEvents();};
                    ~CEvent(){};

      void           SetEvent(EventType Event, AlertLevelType AlertLevel=Notify);
      void           ClearEvent(EventType Event);
      void           ClearEvents(void);

      bool           Event(EventType Event, AlertLevelType AlertLevel)
                                                 {return (eAlerts[Event]==AlertLevel);}
      AlertLevelType AlertLevel(EventType Event) {return (eAlerts[Event]);}
      AlertLevelType HighAlert(void)             {return (eMaxAlert);}

      bool           ActiveEvent(void)           {return(!eEvents[NoEvent]);}
      string         ActiveEventText(bool WithHeader=true);
      
      //---  General use events
      bool           ProximityAlert(double Price, double Proximity);

      bool           operator[](const EventType Event) const {return(eEvents[Event]);}

  };

//+------------------------------------------------------------------+
//| SetEvent - Sets the triggering event to true                     |
//+------------------------------------------------------------------+
void CEvent::SetEvent(EventType Event, AlertLevelType AlertLevel=Notify)
  {
    if (Event==NoEvent)
      return;

    eEvents[NoEvent]         = false;
    eEvents[Event]           = true;
    eAlerts[Event]           = fmax(AlertLevel,eAlerts[Event]);
    eMaxAlert                = fmax(AlertLevel,eMaxAlert);
  }
  
//+------------------------------------------------------------------+
//| ClearEvent - Sets a specific event to false                      |
//+------------------------------------------------------------------+
void CEvent::ClearEvent(EventType Event)
  {
    if (Event==NoEvent)
      return;

    eEvents[NoEvent]         = true;
    eEvents[Event]           = false;
    eAlerts[Event]           = NoAlert;
    eMaxAlert                = NoAlert;
    
    for (EventType event=NewDirection;event<EventTypes;event++)
      if (eEvents[event])
      {
        eEvents[NoEvent]     = false;
        eMaxAlert            = fmax(eAlerts[event],eMaxAlert);
      }
  }
  
//+------------------------------------------------------------------+
//| ClearEvents - Initializes all events to false                    |
//+------------------------------------------------------------------+
void CEvent::ClearEvents(void)
  {
    ArrayInitialize(eEvents,false);    
    ArrayInitialize(eAlerts,NoAlert);
    
    eEvents[NoEvent]         = true;
    eMaxAlert                = NoAlert;
  }
  
//+------------------------------------------------------------------+
//| ActiveEvents - String of active events formatted for display     |
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
//| ProximityAlert - Returns a true when price in proximity          |
//+------------------------------------------------------------------+
bool CEvent::ProximityAlert(double Price, double Proximity)
  {
    if (IsBetween(Close[0],Price+Pip(Proximity,InPoints),Price-Pip(Proximity,InPoints),Digits))
    {      
      SetEvent(NewProximityAlert);
      return (true);
    }
    
    return (false);
  }
/*
//+------------------------------------------------------------------+
//| ProximityAlert - Returns a true when value (fibo) in proximity   |
//+------------------------------------------------------------------+
bool CEvent::ProximityAlert(double Basis, double Check, double Proximity, double Precision)
  {
    if (IsBetween(Basis,Check+Proximity,Check-Proximity,Precision))
    {      
      SetEvent(NewProximityAlert);
      return (true);
    }
    
    return (false);
  }
*/

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

