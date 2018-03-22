//+------------------------------------------------------------------+
//|                                                      Session.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <stdutil.mqh>
#include <Class/Event.mqh>

input string SessionHeader           = "";    //+---- Session Hours -------+
input int    inpNewDay               = 0;     // New day market open hour
input int    inpEndDay               = 0;     // End of day hour
input int    inpAsiaOpen             = 1;     // Asian market open hour
input int    inpAsiaClose            = 10;    // Asian market close hour
input int    inpEuropeOpen           = 8;     // Europe market open hour
input int    inpEuropeClose          = 18;    // Europe market close hour
input int    inpUSOpen               = 14;    // US market open hour
input int    inpUSClose              = 23;    // US market close hour

//+------------------------------------------------------------------+
//| CSession Class - Tracks session details                          |
//+------------------------------------------------------------------+
class CSession
  {

protected:

             //-- Directional Types
             enum DirectionType
             {
               Boundary,
               Session
             };

             //-- Session Types
             enum SessionType
             {
               Asia,
               Europe,
               US,
               Daily,
               SessionTypes
             };


private:

          //--- Private Class properties
             SessionType   sSessionType;
             bool          sSessionOpen;
             int           sSessionDir;
             int           sHourOpen;
             int           sHourClose;
             double        sOpen;
             double        sHigh;
             double        sLow;
             double        sClose;
             int           sBoundaryDir;
             double        sBoundaryHigh;
             double        sBoundaryLow;
             int           sBoundaryCount;
             bool          sBreakout;
             bool          sReversal;
             CEvent       *sEvent;

          //--- Private Class methods
             void    OpenSession(int Bar=0);
             void    CloseSession(int Bar=0);

public:

             CSession(SessionType Type, int HourOpen, int HourClose);
            ~CSession(void);

          //--- Class properties
             SessionType   Type(void)  {return (sSessionType);};

             double        Open(void)  {return (sOpen);};
             double        High(void)  {return (sHigh);};
             double        Low(void)   {return (sLow);};
             double        Close(void) {return (sClose);};

             double        Support(void);
             double        Resistance(void);

             int           Direction(DirectionType Type);
             int           BoundaryCount(void) {return(sBoundaryCount);};

          //--- Class conditionals
             bool          IsOpen(void)     {return (sSessionOpen);};
             bool          IsLocked(void)   {return (sClose>0.00);}; 
             bool          IsBreakout(void) {return (sBreakout);};
             bool          IsReversal(void) {return (sReversal);};

          //--- Class methods
             void    Update(int Bar=0);
             
             void    SetBoundary(int SessionDir, double Resistance, double Support);
             bool    SessionIsOpen(int Bar=0);

             bool operator[](const EventType Type) const { return(sEvent[Type]); };

  };

//+------------------------------------------------------------------+
//| SessionIsOpen - returns true if the this session is open         |
//+------------------------------------------------------------------+
bool CSession::SessionIsOpen(int Bar=0)
  {
    int    soHour   = TimeHour(Time[Bar]);

    if (soHour>=sHourOpen && soHour<sHourClose)
      return (true);

    if (sSessionType==Daily)
      return (true);

    return (false);
  }


//+------------------------------------------------------------------+
//| OpenSession - Sets the session details on session open           |
//+------------------------------------------------------------------+
CSession::OpenSession(int Bar=0)
  {
    sSessionOpen        = true;
    sOpen               = Open[Bar];
    sHigh               = High[Bar];
    sLow                = Low[Bar];    

    if (sSessionType==Daily)
      sEvent.SetEvent(NewDay);
    else
      sEvent.SetEvent(SessionOpen);
  }

//+------------------------------------------------------------------+
//| Close - Sets the final session details on session close          |
//+------------------------------------------------------------------+
CSession::CloseSession(int Bar=0)
  {
    sClose           = Close[Bar+1];
    sSessionOpen     = false;

    sEvent.SetEvent(SessionClose);
  }

//+------------------------------------------------------------------+
//| Class Constructor - instantiates the CSession class object       |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type, int HourOpen, int HourClose)
  {
    sSessionType        = Type;
    sSessionOpen        = false;
    sSessionDir         = DirectionNone;
    sHourOpen           = HourOpen;
    sHourClose          = HourClose;
    sOpen               = NoValue;
    sHigh               = NoValue;
    sLow                = NoValue;
    sClose              = NoValue;
    sBoundaryDir        = DirectionNone;
    sBoundaryHigh       = NoValue;
    sBoundaryLow        = NoValue;
    sBoundaryCount      = NoValue;
    sBreakout           = false;
    sReversal           = false;
    sEvent              = new CEvent();
  }

//+------------------------------------------------------------------+
//| Class Destructor - Destroys the CSession class object            |
//+------------------------------------------------------------------+
CSession::~CSession(void)
  {
    delete sEvent;
  }

//+------------------------------------------------------------------+
//| Update - Updates session details on open sessions                |
//+------------------------------------------------------------------+
CSession::Update(int Bar=0)
  {
    static int usBoundaryDir = DirectionNone;
    
    sEvent.ClearEvents();
    
    if (SessionIsOpen(Bar))
    {
      if (!IsOpen())
        OpenSession(Bar);
        
      if (IsHigher(High[Bar],sHigh))
        sEvent.SetEvent(NewHigh);

      if (IsLower(Low[Bar],sLow))
        sEvent.SetEvent(NewLow);
        
      if (sEvent[NewLow] || sEvent[NewHigh])
      {
        sEvent.SetEvent(NewBoundary);
        
        if (sEvent[NewLow] && sEvent[NewHigh])
          sEvent.SetEvent(InsideReversal);
        else
        if (sEvent[NewLow])
          sSessionDir       = DirectionDown;
        else
        if (sEvent[NewHigh])
          sSessionDir       = DirectionUp;
        
        if (IsHigher(Close[Bar],sBoundaryHigh,NoUpdate))
          if (IsChanged(usBoundaryDir,DirectionUp))
            sEvent.SetEvent(NewDirection);
        
        if (IsLower(Close[Bar],sBoundaryLow,NoUpdate))
          if (IsChanged(usBoundaryDir,DirectionDown))
            sEvent.SetEvent(NewDirection);

        if (sEvent[NewDirection])
        {
          sBoundaryCount++;
          
          if (IsEqual(sSessionDir,sBoundaryDir))
          {
            sBreakout      = true;
            sEvent.SetEvent(NewBreakout);
          }
          else
          {
            sReversal      = true;
            sEvent.SetEvent(NewReversal);
          }
        }
      }
    }
    else 
    
    if (IsOpen())
      CloseSession(Bar);
  }

//+------------------------------------------------------------------+
//| SetBoundary - Sets the resistance/support levels of the session  |
//+------------------------------------------------------------------+
CSession::SetBoundary(int BoundaryDir, double Resistance, double Support)
  {
    sBoundaryDir      = BoundaryDir;
    
    switch (sBoundaryDir)
    {
      case DirectionUp:     sBoundaryHigh  = Resistance;
                            sBoundaryLow   = Support;
                            break;
      
      case DirectionDown:   sBoundaryHigh  = Support;
                            sBoundaryLow   = Resistance;
                            break;
    }
  }

//+------------------------------------------------------------------+
//| Direction - Returns the direction for the supplied type          |
//+------------------------------------------------------------------+
int CSession::Direction(DirectionType Type)
  {    
    switch (Type)
    {
      case Boundary:   return(sBoundaryDir);
      case Session:    return(sSessionDir);
    }
    
    return (DirectionNone);
  }

//+------------------------------------------------------------------+
//| Support - Returns the support based on Boundary direction        |
//+------------------------------------------------------------------+
double CSession::Support(void)
  {    
    switch (Direction(Boundary))
    {
      case DirectionUp:   return(sBoundaryLow);
      case DirectionDown: return(sBoundaryHigh);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Resistance - Returns the resistance based on Boundary direction  |
//+------------------------------------------------------------------+
double CSession::Resistance(void)
  {    
    switch (Direction(Boundary))
    {
      case DirectionUp:   return(sBoundaryHigh);
      case DirectionDown: return(sBoundaryLow);
    }
    
    return (NoValue);
  }
