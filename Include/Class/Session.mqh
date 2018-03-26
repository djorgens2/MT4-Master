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

//+------------------------------------------------------------------+
//| CSession Class - Tracks session details                          |
//+------------------------------------------------------------------+
class CSession
  {

protected:


private:

          //--- Private Class properties
             bool          sSessionOpen;
             int           sSessionDir;
             double        sOpen;
             double        sHigh;
             double        sLow;
             double        sClose;
             int           sBoundaryCount;
             bool          sBreakout;
             bool          sReversal;
             CEvent        sEvent;

          //--- Private Class methods

public:

             CSession(CEvent &Event);
            ~CSession(void);

          //--- Class properties
             double        Open(void)  {return (sOpen);};
             double        High(void)  {return (sHigh);};
             double        Low(void)   {return (sLow);};
             double        Close(void) {return (sClose);};

             int           BoundaryCount(void) {return(sBoundaryCount);};

          //--- Class conditionals
             bool          IsOpen(void)     {return (sSessionOpen);};
             bool          IsClosed(void)   {return (sClose>0.00);}; 

          //--- Class events
             void          Update(int Bar=0)
             bool          IsBreakout(void) {return (sBreakout);};
             bool          IsReversal(void) {return (sReversal);};

          //--- Class methods
             void    OpenSession(double Price);
             void    CloseSession(double Price);

  };

//+------------------------------------------------------------------+
//| Class Constructor - instantiates the CSession class object       |
//+------------------------------------------------------------------+
CSession::CSession(CEvent &Event)
  {
    sSessionOpen        = false;
    sSessionDir         = DirectionNone;
    sOpen               = NoValue;
    sHigh               = NoValue;
    sLow                = NoValue;
    sClose              = NoValue;
    sBoundaryCount      = NoValue;
    sBreakout           = false;
    sReversal           = false;
    sEvent              = GetPointer(Event);
  }

//+------------------------------------------------------------------+
//| Class Destructor - Destroys the CSession class object            |
//+------------------------------------------------------------------+
CSession::~CSession(void)
  {
    
  }

//+------------------------------------------------------------------+
//| OpenSession - Sets the session details on session open           |
//+------------------------------------------------------------------+
void CSession::OpenSession(double Price)
  {
    sSessionOpen        = true;
    sOpen               = Price;
    sHigh               = Price;
    sLow                = Price;
  }

//+------------------------------------------------------------------+
//| Close - Sets the final session details on session close          |
//+------------------------------------------------------------------+
void CSession::CloseSession(double Price)
  {
    sClose           = Price;
    sSessionOpen     = false;
  }

//+------------------------------------------------------------------+
//| Update - Updates session details on open sessions                |
//+------------------------------------------------------------------+
void CSession::Update(int Bar=0)
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
