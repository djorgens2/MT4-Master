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

             SessionType   sSessionType;
             bool          sSessionOpen;
             int           sSessionDir;
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

public:

                     CSession(SessionType Type);
                    ~CSession(void);

          //--- Class properties
             SessionType   Type(void) {return (sSessionType);};
             bool          IsOpen(void) {return (sSessionOpen);};
             int           Direction(DirectionType Type);
             double        Open(void) {return (sOpen);};
             double        High(void) {return (sHigh);};
             double        Low(void) {return (sLow);};
             double        Close(void) {return (sClose);};
             double        Support(void);
             double        Resistance(void);
             bool          IsBreakout(void) {return (sBreakout);};
             bool          IsReversal(void) {return (sReversal);};
             int           BoundaryCount(void) {return(sBoundaryCount);};

          //--- Class methods
             void    OpenSession(int Bar=0);
             void    CloseSession(int Bar=0);
             void    Update(int Bar=0);
             
             void    SetBoundary(int SessionDir, double Resistance, double Support);

             bool operator[](const EventType Type) const { return(sEvent[Type]); };

  };

//+------------------------------------------------------------------+
//| Class Constructor - instantiates the CSession class object       |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type)
  {
    sSessionType        = Type;
    sSessionOpen        = false;
    sSessionDir         = DirectionNone;
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
//| Open - Sets the session details on session open                  |
//+------------------------------------------------------------------+
CSession::OpenSession(int Bar=0)
  {
    sSessionOpen     = true;
    sOpen            = Open[Bar];
    sHigh            = High[Bar];
    sLow             = Low[Bar];
  }

//+------------------------------------------------------------------+
//| Close - Sets the final session details on session close          |
//+------------------------------------------------------------------+
CSession::CloseSession(int Bar=0)
  {
    sClose           = Close[Bar+1];
    sSessionOpen     = false;
  }

//+------------------------------------------------------------------+
//| Update - Updates session details on open sessions                |
//+------------------------------------------------------------------+
CSession::Update(int Bar=0)
  {
    static int usBoundaryDir = DirectionNone;
    
    sEvent.ClearEvents();
    
    if (this.sSessionOpen)
    {
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
