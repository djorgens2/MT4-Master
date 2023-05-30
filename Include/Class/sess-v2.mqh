//+------------------------------------------------------------------+
//|                                                     CSession.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

#include <Class/Fractal.mqh>

class CSession : public CFractal
  {

protected:

         //-- Period Types
         enum PeriodType
         {
           PriorSession,  // Prior (Closed) Session
           ActiveSession, // Active (Open) Session
           OffSession,    // Off-Session
           PeriodTypes    // None
         };

         //-- Session Types
         enum SessionType
         {
           Daily,
           Asia,
           Europe,
           US,
           SessionTypes  // None
         };

         struct SessionRec
         {
           int           Direction;
           int           Bias;
           double        High;
           double        Low;
         };


private:

         //--- Panel Indicators
         string          indSN;

         //--- Private Class properties
         SessionType      sType;

         bool             sIsOpen;
         bool             sFlags;

         int              sHourOpen;
         int              sHourClose;
         int              sHourOffset;
         int              sBar;
         int              sBars;
         int              sDay;
         int              sHour;

         void             OpenSession(void);
         void             CloseSession(void);

         SessionRec       srec[PeriodTypes];
         
public:

                          CSession(SessionType Session, FractalType Type);
                         ~CSession();
                    
         void             Update(void);

         datetime         ServerTime(void);
         int              SessionHour();
         bool             IsOpen(void);

  };

//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSession::OpenSession(void)
  {
    //-- Update OffSession Record and Indicator Buffer      
    srec[OffSession]                      = srec[ActiveSession];
//    sOffMidBuffer.SetValue(sBar,Pivot(ActiveSession));

    //-- Set support/resistance (ActiveSession is OffSession data)
    srec[ActiveSession].Resistance        = fmax(srec[PriorSession].High,srec[OffSession].High);
    srec[ActiveSession].Support           = fmin(srec[PriorSession].Low,srec[OffSession].Low);
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];

    //<--- Check for offsession reversals
    if (IsHigher(srec[ActiveSession].High,srec[PriorSession].High,NoUpdate))
      if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp,NoUpdate))
        srec[ActiveSession].High          = fdiv(srec[PriorSession].High+High[sBar],2,Digits);

    if (IsLower(srec[ActiveSession].Low,srec[PriorSession].Low,NoUpdate))
      if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown,NoUpdate))
       srec[ActiveSession].Low            = fdiv(srec[PriorSession].Low+Low[sBar],2,Digits);

    SetEvent(SessionOpen,Notify);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {        
    //-- Update Prior Record, range history, and Indicator Buffer
    sSessionRange.Insert(0,srec[ActiveSession].High-srec[ActiveSession].Low);

    srec[PriorSession]                    = srec[ActiveSession];
    sPriorMidBuffer.SetValue(sBar,Pivot(PriorSession));

    //-- Reset Active Record
    srec[ActiveSession].Resistance        = srec[PriorSession].High;
    srec[ActiveSession].Support           = srec[PriorSession].Low;
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];

    SetEvent(SessionClose,Notify);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Session, FractalType Type)
  {
    for (sBar=Bars;sBar>0;sBar--)
      Update();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSession::~CSession()
  {
  }

//+------------------------------------------------------------------+
//| Update: Computes fractal using supplied fractal and price        |
//+------------------------------------------------------------------+
void CSession::Update(void)
  {
    //--- Clear events
    ClearEvents();

    //--- Test for New Day; Force close
    if (IsChanged(sDay,TimeDay(ServerTime())))
    {
      SetEvent(NewDay,Notify);
      
      if (IsChanged(sIsOpen,false))
        CloseSession();
    }
    
    if (IsChanged(sHour,TimeHour(ServerTime())))
      SetEvent(NewHour,Notify);

    //--- Calc events session open/close
    if (IsChanged(sIsOpen,IsOpen()))
      if (IsOpen())
        OpenSession();
      else
        CloseSession();
  }

//+------------------------------------------------------------------+
//| ServerTime - Returns the adjusted time based on server offset    |
//+------------------------------------------------------------------+
datetime CSession::ServerTime(void)
  {
    //-- Time is set to reflect 5:00pm New York as end of trading day
    
    return(Time[sBar]+(PERIOD_H1*60*sHourOffset));
  };

//+------------------------------------------------------------------+
//| SessionHour - Returns the hour of open session trading           |
//+------------------------------------------------------------------+
int CSession::SessionHour(void)
  {    
    return BoolToInt(IsOpen(),TimeHour(ServerTime())-sHourOpen+1,NoValue);
  }

//+------------------------------------------------------------------+
//| SessionIsOpen - Returns true if session is open for trade        |
//+------------------------------------------------------------------+
bool CSession::IsOpen(void)
  {
    if (TimeDayOfWeek(ServerTime())<6)
      if (TimeHour(ServerTime())>=sHourOpen && TimeHour(ServerTime())<sHourClose)
        return (true);
        
    return (false);
  }
