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
               int HourOpen;
               int MidSession;
               int HourClose;
             };

             //-- Session Data
             SessionHours    sdHours[SessionTypes];
             CSession       *sdOpen[SessionTypes];
             CSession       *sdSession[];
             CSession       *sdDaily[];

private:

             //-- Session Private Operational Variables
             int             spBar;
             
             //-- Session Methods
             void            NewSession(SessionType Type);
             void            CloseSession(SessionType Type);
             void            CloseDaily(void);
             void            LoadHistory(void);

          
public:
                     CSessions(int Bar);
                    ~CSessions(void);

             void    SetSessionHours(SessionType Session, int HourOpen, int HourClose);
             bool    IsSessionOpen(SessionType Session);
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
//| NewSession - Initializes session data on Session Open            |
//+------------------------------------------------------------------+
void CSessions::NewSession(SessionType Type)
  {
    ArrayResize(sdSession,(ArraySize(sdSession)+1));
    
    sdOpen[Type] = new CSession(Type,sdHours[Type].HourOpen,sdHours[Type].HourClose);

    sdSession[ArraySize(sdSession)-1] = GetPointer(sdSession[ArraySize(sdSession)-1]);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes a session object and ends future updates   |
//+------------------------------------------------------------------+
void CSessions::CloseSession(SessionType Type)
  {
  }

//+------------------------------------------------------------------+
//| CloseDaily - Closes daily and Opens new daily record updates     |
//+------------------------------------------------------------------+
void CSessions::CloseDaily(void)
  {
    
  }

//+------------------------------------------------------------------+
//| Sessions Constructor                                             |
//+------------------------------------------------------------------+
CSessions::CSessions(int Bar)
  {
    spBar    = Bar;
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
    sdHours[Session].HourOpen     = HourOpen;
    sdHours[Session].HourClose    = HourClose;
    sdHours[Session].MidSession   = (HourOpen+HourClose)/2;
    
    Print(EnumToString(Session)+":"+IntegerToString(sdHours[Session].HourOpen)+":"
                                   +IntegerToString(sdHours[Session].MidSession)+":"
                                   +IntegerToString(sdHours[Session].HourClose)
         );
  }

//+------------------------------------------------------------------+
//| IsSessionOpen - returns true if the supplied session is open     |
//+------------------------------------------------------------------+
bool CSessions::IsSessionOpen(SessionType Type)
  {
    int    soHour   = TimeHour(Time[spBar]);

    if (soHour>=sdHours[Type].HourOpen && soHour<sdHours[Type].HourClose)
      return (true);

    if (Type==Daily)
      return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| Update - Updates session data                                    |
//+------------------------------------------------------------------+
void CSessions::Update(void)
  {
    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      if (sdSession[type]==NULL)
        NewSession(type);
     
      sdOpen[type].Update(spBar);
    }
  }