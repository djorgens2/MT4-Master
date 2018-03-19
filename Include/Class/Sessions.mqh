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
#include <Class/Event.mqh>
#include <Class/Session.mqh>

//+------------------------------------------------------------------+
//| Sessions - class to track and monitor session performance        |
//+------------------------------------------------------------------+
class CSessions
  {

protected:

             struct SessionHours
             {
               int SessionOpen;
               int SessionMid;
               int SessionClose;
             };


             //-- Session Data
             SessionHours    sdHours[SessionTypes];
             CSession       *sdOpen[SessionTypes];
             CSession       *sdSession[];
             CSession       *sdDaily[];

             //-- Global Event Data
             CEvent         *gevent;
             
             //--- Class operational variables
             bool            covHistoryLoaded;

private:

             //-- Session Private Operational Variables
             int             spBar;
             SessionType     spLastOpen[SessionTypes];
             
             //-- Session Methods
             void            OpenSession(SessionType Type);
             void            CloseSession(SessionType Type);
             void            LoadHistory(void);

          
public:
                     CSessions(int Bar);
                    ~CSessions(void);

             void    SetSessionHours(SessionType Session, int HourOpen, int HourClose);
             bool    IsOpen(SessionType Session);
             void    Update(void);
  };

//+------------------------------------------------------------------+
//| LoadHistory - Called after hours are configured; loads history   |
//+------------------------------------------------------------------+
void CSessions::LoadHistory(void)
  {
    for (spBar=spBar;spBar>0;spBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| OpenSession - Initializes session data on Session Open           |
//+------------------------------------------------------------------+
void CSessions::OpenSession(SessionType Type)
  {
    ArrayResize(sdSession,(ArraySize(sdSession)+1));
    
    sdSession[ArraySize(sdSession)-1] = new CSession(Type);
    sdSession[ArraySize(sdSession)-1].OpenSession(spBar);

    sdOpen[Type] = sdSession[ArraySize(sdSession)-1];
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes a session object and ends future updates   |
//+------------------------------------------------------------------+
void CSessions::CloseSession(SessionType Type)
  {
  }

//+------------------------------------------------------------------+
//| Sessions Constructor                                             |
//+------------------------------------------------------------------+
CSessions::CSessions(int Bar)
  {
    gevent       = new CEvent();
    
    ArrayInitialize(spLastOpen,false);
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
    sdHours[Session].SessionOpen   = HourOpen;
    sdHours[Session].SessionClose  = HourClose;
    sdHours[Session].SessionMid    = (HourOpen+HourClose)/2;
    
    Print(EnumToString(Session)+":"+IntegerToString(sdHours[Session].SessionOpen)+":"
                                   +IntegerToString(sdHours[Session].SessionMid)+":"
                                   +IntegerToString(sdHours[Session].SessionClose)
         );
  }

//+------------------------------------------------------------------+
//| IsOpen - returns true if the supplied session is open            |
//+------------------------------------------------------------------+
bool CSessions::IsOpen(SessionType Session)
  {
    bool   soOpen   = false;
    int    soHour   = TimeHour(Time[spBar]);

    if (soHour>=sdHours[Session].SessionOpen && soHour<sdHours[Session].SessionClose)
      soOpen                 = true;

    if (Session==Daily)
    {
      soOpen                 = true;
      
      if (soHour==inpNewDay)
        gevent.SetEvent(NewDay);
        
      CloseSession(Session);
    }

    if (IsChanged(soLastOpen,soOpen))
      if (soOpen)
        gevent.SetEvent(SessionOpen);
      else
        gevent.SetEvent(SessionClose);

    if (gevent[SessionOpen])
      UpdateSession(Session);
    return (soOpen);
  }

//+------------------------------------------------------------------+
//| Update - Updates session data                                    |
//+------------------------------------------------------------------+
void CSessions::Update(void)
  {
    gevent.ClearEvents();
    
    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      if (IsOpen(type))
        if (gevent[SessionOpen])
    }
  }