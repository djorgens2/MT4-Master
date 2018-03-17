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
//|                                                                  |
//+------------------------------------------------------------------+
class CSession
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

private:

             SessionType sSessionPeriod;
             bool        sSessionOpen;
             int         sSessionDir;
             double      sOpen;
             double      sHigh;
             double      sLow;
             double      sClose;
             int         sBoundaryDir;
             double      sBoundaryHigh;
             double      sBoundaryLow;
             bool        sBoundary;
             bool        sBreakout;
             bool        sReversal;
             int         sReversalCount;
             
             CEvent      *event;

public:
                     CSession(SessionType Type);
                    ~CSession(void);

             void    OpenSession(int Bar=0);
             void    CloseSession(int Bar=0);
             void    UpdateSession(int Bar=0);
             void    SetBoundary(int SessionDir, double Resistance, double Support);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type)
  {
    sSessionPeriod   = Type;
    sSessionOpen     = false;
    sSessionDir      = DirectionNone;
    sOpen            = NoValue;
    sHigh            = NoValue;
    sLow             = NoValue;
    sClose           = NoValue;
    sBoundaryDir     = DirectionNone;
    sBoundaryHigh    = NoValue;
    sBoundaryLow     = NoValue;
    sBreakout        = false;
    sReversal        = false;
    sReversalCount   = NoValue;

    event            = new CEvent();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::~CSession(void)
  {
    delete event;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::OpenSession(int Bar=0)
  {
    sSessionOpen     = true;
    sOpen            = Open[Bar];
    sHigh            = High[Bar];
    sLow             = Low[Bar];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::CloseSession(int Bar=0)
  {
    sClose           = Close[Bar+1];
    sSessionOpen     = false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::UpdateSession(int Bar=0)
  {
    static int usBoundaryDir = DirectionNone;
    
    event.ClearEvents();
    
    if (this.sSessionOpen)
    {
      if (IsHigher(High[Bar],this.sHigh))
        event.SetEvent(NewHigh);

      if (IsLower(Low[Bar],this.sLow))
        event.SetEvent(NewLow);
        
      if (event[NewLow] || event[NewHigh])
      {
        event.SetEvent(NewBoundary);
        
        if (event[NewLow] && event[NewHigh])
          event.SetEvent(InsideReversal);
        else
        if (event[NewLow])
          sSessionDir       = DirectionDown;
        else
        if (event[NewHigh])
          sSessionDir       = DirectionUp;
        
        if (IsHigher(Close[Bar],sBoundaryHigh,NoUpdate))
          if (IsChanged(usBoundaryDir,DirectionUp))
            event.SetEvent(NewDirection);
        
        if (IsLower(Close[Bar],sBoundaryLow,NoUpdate))
          if (IsChanged(usBoundaryDir,DirectionDown))
            event.SetEvent(NewDirection);

        if (event[NewDirection])
        {
          sReversalCount++;
          
          if (IsEqual(sSessionDir,sBoundaryDir))
          {
            sBreakout      = true;
            event.SetEvent(NewBreakout);
          }
          else
          {
            sReversal      = true;
            event.SetEvent(NewReversal);
          }
        }
      }
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
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
