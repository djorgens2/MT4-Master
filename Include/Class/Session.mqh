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

             SessionType SessionPeriod;
             int         DirectionalMin;
             double      PriceOpen;
             double      PriceHigh;
             double      PriceLow;
             double      PriceClose;
             int         SessionDir;
             bool        Breakout;
             bool        Reversal;
             int         ReversalCount;
             bool        SessionOpen;

public:
                     CSession(SessionType Type, int DirectionalMin);
                    ~CSession(void);

             void    OpenSession(int Bar=0);
             void    CloseSession(void);
             void    UpdateSession(int Bar=0);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type, int DirectionalMin)
  {
    SessionPeriod   = Type;
    PriceOpen       = NoValue;
    PriceHigh       = NoValue;
    PriceLow        = NoValue;
    PriceClose      = NoValue;
    SessionDir      = DirectionNone;
    Breakout        = false;
    Reversal        = false;
    ReversalCount   = NoValue;;
    SessionOpen     = false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::~CSession(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::OpenSession(int Bar=0)
  {
    PriceOpen       = Open[Bar];
    PriceHigh       = High[Bar];
    PriceLow        = Low[Bar];
    PriceClose      = Close[Bar];
    SessionDir      = DirectionNone;
    Breakout        = false;
    Reversal        = false;
    ReversalCount   = 0;
    SessionOpen     = true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::CloseSession(void)
  {
    SessionOpen     = false;
  }

