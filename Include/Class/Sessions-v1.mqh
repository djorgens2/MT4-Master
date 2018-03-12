//+------------------------------------------------------------------+
//|                                                  Sessions-v1.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <stdutil.mqh>
//+------------------------------------------------------------------+
//| Sessions - class to track and monitor session performance        |
//+------------------------------------------------------------------+
class CSessions
  {

protected:

             //-- Session Types
             enum SessionType
             {
               Asia,
               Europe,
               US,
               Daily,
               SessionTypes
             };

             struct SessionHours
             {
               int SessionOpen;
               int SessionMid;
               int SessionClose;
             };

             struct SessionInfo
             {
               double SessionHigh;
               double SessionLow;
               int    SessionDir;
               bool   Breakout;
               bool   Reversal;
             };

             //-- Session Levels
             SessionHours   slHours[SessionTypes];
             SessionInfo    slHistory[][SessionTypes];
             SessionInfo    slCurrent[SessionTypes];
    

private:

             //-- Event Operationals
             bool     Events[EventTypes];

             void    InitSessionHistory(void);
             void    InitSessions(void);
             void    PostHistory(SessionType Session);
             void    OpenSession(SessionType Session, int Bar=0);

             bool    Event(EventType Type)      {return (Events[Type]);}
             void    SetEvent(EventType Type)   {Events[Type] = true;}
             void    ClearEvent(EventType Type) {Events[Type] = false;}
             void    ClearEvents(void)          {ArrayInitialize(Events,false);}
             

public:
                     CSessions(void);
                    ~CSessions(void);

             void    SetSessionHours(SessionType Session, int HourOpen, int HourClose);
             bool    IsOpen(SessionType Session, int Bar=0);
             void    Update(int Bar=0);
  };

//+------------------------------------------------------------------+
//| OpenSession - Initializes session data on Session Open           |
//+------------------------------------------------------------------+
void CSessions::OpenSession(SessionType Session, int Bar=0)
  {
    slCurrent[Session].SessionHigh   = High[Bar];
    slCurrent[Session].SessionLow    = Low[Bar];
    slCurrent[Session].SessionDir    = DirectionNone;
    slCurrent[Session].Breakout      = false;
    slCurrent[Session].Reversal      = false;
  }

//+------------------------------------------------------------------+
//| InitSessions - Initializes session data for first use            |
//+------------------------------------------------------------------+
void CSessions::InitSessions(void)
  {
    for (SessionType session=0;session<SessionTypes;session++)
      OpenSession(session,Bars-1);
  }

//+------------------------------------------------------------------+
//| InitSessionHistory - Loads session history                       |
//+------------------------------------------------------------------+
void CSessions::InitSessionHistory(void)
  {
    InitSessions();
    
    for (int ishBar=Bars-1;ishBar>0;ishBar--)
      Update(ishBar);
  }

//+------------------------------------------------------------------+
//| Sessions Constructor                                             |
//+------------------------------------------------------------------+
CSessions::CSessions(void)
  {
    InitSessionHistory();
  }
  
//+------------------------------------------------------------------+
//| Sessions Destructor                                              |
//+------------------------------------------------------------------+
CSessions::~CSessions()
  {
  }

//+------------------------------------------------------------------+
//| SetSessionHours - Sets session trading hours                     |
//+------------------------------------------------------------------+
void CSessions::SetSessionHours(SessionType Session, int HourOpen, int HourClose)
  {
    slHours[Session].SessionOpen   = HourOpen;
    slHours[Session].SessionClose  = HourClose;
    slHours[Session].SessionMid    = (HourOpen+HourClose)/2;
    
    Print(EnumToString(Session)+":"+IntegerToString(slHours[Session].SessionOpen)+":"
                                   +IntegerToString(slHours[Session].SessionMid)+":"
                                   +IntegerToString(slHours[Session].SessionClose)
         );
  }

//+------------------------------------------------------------------+
//| IsOpen - returns true if the supplied session is open            |
//+------------------------------------------------------------------+
bool CSessions::IsOpen(SessionType Session, int Bar=0)
  {
    int soHour   = TimeHour(Time[Bar]);
    
    if (soHour>=slHours[Session].SessionOpen && soHour<slHours[Session].SessionClose)
      return (true);
      
    if (Session==Daily)
      return (true);
      
    return false;
  }

//+------------------------------------------------------------------+
//| Update - Updates session data                                    |
//+------------------------------------------------------------------+
void CSessions::Update(int Bar=0)
  {
    static int   uHour     = NoValue;
    SessionInfo  uSession;
    
    ClearEvents();
    
    for (SessionType session=Asia;session<SessionTypes;session++)
    {
      uSession             = slCurrent[session];
      
      if (IsOpen(session, Bar))
      {
        if (IsHigher(High[Bar],slCurrent[session].SessionHigh))
        {
          if (IsChanged(slCurrent[session].SessionDir,DirectionUp))
            SetEvent(NewDirection);
            
          SetEvent(NewHigh);
        }
        
        if (IsLower(Low[Bar],slCurrent[session].SessionLow))
        {
          if (IsChanged(slCurrent[session].SessionDir,DirectionDown))
            SetEvent(NewDirection);
            
          SetEvent(NewLow);
        }
      }

      if (IsChanged(uHour,TimeHour(Time[Bar])))
      {
        if (slHours[session].SessionClose==uHour)
          PostHistory(session);

        if (slHours[session].SessionOpen==uHour)
          OpenSession(session, Bar);
      }
    }
  }

