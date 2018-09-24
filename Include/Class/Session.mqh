//+------------------------------------------------------------------+
//|                                                 SessionArray.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class/Event.mqh>
#include <Class/ArrayDouble.mqh>

//+------------------------------------------------------------------+
//| SessionArray Class - Collects session data, states, and events   |
//+------------------------------------------------------------------+
class CSession
  {

public:

             //-- Session Record Definition
             struct SessionRec
             {
               int            Direction;
               int            Age;
               ReservedWords  State;
               double         High;
               double         Low;
               double         Support;
               double         Resistance;
               double         Correction;
               double         Hedge;
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

             //-- Record Types
             enum RecordType
             {
               ActiveRec,
               OffsessionRec,
               PriorRec,
               OriginRec,
               TrendRec,
               TermRec,
               RecordTypes
             };
             
             CSession(SessionType Type, int HourOpen, int HourClose);
            ~CSession();

             SessionType   Type(void)                  {return (sType);}
             bool          IsOpen(void);
             
             bool          Event(EventType Type)       {return (sEvent[Type]);}
             bool          ActiveEvent(void)           {return (sEvent.ActiveEvent());}

             void          Update(void);
             void          Update(double &OffSessionBuffer[], double &PriorMidBuffer[]);

             double        ActiveMid(void);
             double        PriorMid(void);
             double        OffsessionMid(void);

             int           TradeBias(void);
             void          PrintSession(int Type);
             
             SessionRec    operator[](const int Type) const {return(srec[Type]);}
             
                                 
private:

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;

             int           sHourOpen;
             int           sHourClose;
             int           sBar;
             int           sBars;
             int           sBarDay;
             int           sBarHour;
             

             //--- Private class collections
             SessionRec    srec[6];
                          
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          UpdateSession(void);
             void          SetTrendState(ReservedWords State);
             void          CalcEvents(void);
             void          LoadHistory(void);
             void          UpdateBuffers(void);
  };

  
//+------------------------------------------------------------------+
//| SetTrendState - Sets trend state and updates support/resistance  |
//+------------------------------------------------------------------+
void CSession::SetTrendState(ReservedWords State)
  {
//    srTrend.State           = State;
//    
//    switch (State)
//    {
//      case Breakout:   
//      case Reversal:  srTrend.Age             = srActive.Age;
//    
//                      if (srTrend.TrendDir==DirectionUp)
//                      {
//                        srTrend.Support       = srTrend.Pullback;
//                        srTrend.Rally         = ActiveMid();
//                      }
//                      
//                      if (srTrend.TrendDir==DirectionDown)
//                      {
//                        srTrend.Resistance    = srTrend.Rally;
//                        srTrend.Pullback      = ActiveMid();
//                      }
//                      break;
//                      
//       case Rally:
//       case Pullback: if (srTrend.TrendDir==DirectionUp)
//                        srTrend.Rally         = ActiveMid();
//
//                      if (srTrend.TrendDir==DirectionDown)
//                        srTrend.Pullback      = ActiveMid();
//     }
  }
  
//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSession::OpenSession(void)
  {    
    //-- Update Offsession Record
    srec[OffsessionRec]                  = srec[ActiveRec];

    //-- Set support/resistance (ActiveRec is Offsession data)
    srec[ActiveRec].Resistance           = fmax(srec[ActiveRec].High,srec[PriorRec].High);
    srec[ActiveRec].Support              = fmin(srec[ActiveRec].Low,srec[PriorRec].Low);
    srec[ActiveRec].Hedge                = PriorMid();
    srec[ActiveRec].Correction           = ActiveMid();

    //-- Update indicator buffers
    sOffMidBuffer.SetValue(sBar,ActiveMid());
    sPriorMidBuffer.SetValue(sBar,PriorMid());

    //-- Reset Active Record
    srec[ActiveRec].High                 = High[sBar];
    srec[ActiveRec].Low                  = Low[sBar];
    
    PrintSession(PriorRec);

    //-- Set OpenSession flag
    sEvent.SetEvent(SessionOpen);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {
    //-- Update Offsession Record
    srec[PriorRec]                       = srec[ActiveRec];

//    srHistory[0]              = srActive;
//    
//    if (sEvent[NewTrend])
//      srActive.Age            = 0;
//
//    if (sEvent[NewBreakout])
//      SetTrendState(Breakout);
//    else
//    if (sEvent[NewReversal])
//      SetTrendState(Reversal);
//    else
//    if (sEvent[NewRally])
//      SetTrendState(Rally);
//    else
//    if (sEvent[NewPullback])
//      SetTrendState(Pullback);
//      
    srec[ActiveRec].Resistance       = srec[ActiveRec].High;
    srec[ActiveRec].Support          = srec[ActiveRec].Low;
//
    srec[ActiveRec].High        = High[sBar];
    srec[ActiveRec].Low         = Low[sBar];

//
//    srActive.Age++;
//    srTrend.Age++;
//    
      //--- Calc session close events
//
//        if (IsLower(ActiveMid(),srActive.PriorMid))
//          if (IsChanged(srTrend.TrendDir,DirectionDown))
//            sEvent.SetEvent(NewTrend);
//        
//        if (IsHigher(ActiveMid(),srActive.PriorMid))
//          if (IsChanged(srTrend.TrendDir,DirectionUp))
//            sEvent.SetEvent(NewTrend);
//            
//        if (srTrend.TrendDir==DirectionUp)
//          if (IsHigher(ActiveMid(),srTrend.Resistance))
//            if (IsChanged(srTrend.OriginDir,srTrend.TrendDir))
//              sEvent.SetEvent(NewReversal);
//            else
//              sEvent.SetEvent(NewBreakout);
//          else
//            sEvent.SetEvent(NewRally);
//
//        if (srTrend.TrendDir==DirectionDown)
//          if (IsLower(ActiveMid(),srTrend.Support))
//            if (IsChanged(srTrend.OriginDir,srTrend.TrendDir))
//              sEvent.SetEvent(NewReversal);
//            else
//              sEvent.SetEvent(NewBreakout);
//          else
//            sEvent.SetEvent(NewPullback);

      sEvent.SetEvent(SessionClose);
  }

//+------------------------------------------------------------------+
//| UpdateSession - Updates active pricing and sets range events     |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {
    //--- Test for session high
    if (IsHigher(High[sBar],srec[ActiveRec].High))
    {
      sEvent.SetEvent(NewHigh);
      sEvent.SetEvent(NewBoundary);

      if (IsChanged(srec[ActiveRec].Direction,DirectionUp))
      {
        sEvent.SetEvent(NewDirection);
        sEvent.SetEvent(NewTerm); //<---- here's where the term update happens
      }
    }
        
    //--- Test for session low
    if (IsLower(Low[sBar],srec[ActiveRec].Low))
    {
      sEvent.SetEvent(NewLow);
      sEvent.SetEvent(NewBoundary);

      if (IsChanged(srec[ActiveRec].Direction,DirectionDown))
      {
        sEvent.SetEvent(NewDirection);
        sEvent.SetEvent(NewTerm); //<---- here's where the term update happens
      }
    }

//      //--- Test boundary breakouts
//      if (sEvent[NewBoundary])
//      {
//        if (IsHigher(High[sBar],srActive.Resistance) || IsLower(Low[sBar],srActive.Support))
//        {
//          if (srActive.TermDir==srTrend.TrendDir)
//            if (IsChanged(srActive.State,Breakout))
//              sEvent.SetEvent(NewBreakout);
//          
//          if (srActive.TermDir!=srTrend.TrendDir)
//            if (IsChanged(srActive.State,Reversal))
//              sEvent.SetEvent(NewReversal);
//        }
//        else
//
//        //--- Test Rallys/Pullbacks
//        {
//          double cePivotPrice   = srActive.PriorMid;
//            
//          if (sSessionIsOpen)
//            cePivotPrice        = srActive.OffMid;
//
//          if (sEvent[NewHigh])
//            if (IsHigher(High[sBar],cePivotPrice,NoUpdate))
//            {
//              sEvent.SetEvent(NewState);
//              sEvent.SetEvent(NewRally);
//            }
//          
//          if (sEvent[NewLow])
//            if (IsLower(Low[sBar],cePivotPrice,NoUpdate))
//            {
//              sEvent.SetEvent(NewState);
//              sEvent.SetEvent(NewPullback);
//            }
//        }
//      }
  }

//+------------------------------------------------------------------+
//| CalcEvents - Updates active pricing and sets events              |
//+------------------------------------------------------------------+
void CSession::CalcEvents(void)
  {
    //--- Clear events
    sEvent.ClearEvents();

    //--- Test for New Day/New Hour
    if (IsChanged(sBarDay,TimeDay(Time[sBar])))
    {
      if (sSessionIsOpen)
        CloseSession();

      sEvent.SetEvent(NewDay);
    }
    
    if (IsChanged(sBarHour,TimeHour(Time[sBar])))
      sEvent.SetEvent(NewHour);

    //--- Calc events session open/close
    if (IsChanged(sSessionIsOpen,this.IsOpen()))
      if (sSessionIsOpen)
        OpenSession();
      else
        CloseSession();

    UpdateSession();
    
  }

//+------------------------------------------------------------------+
//| UpdateBuffers - updates indicator buffer values                  |
//+------------------------------------------------------------------+
void CSession::UpdateBuffers(void)
  {
    if (Bars<sBars)
      Print("History exception; need to reload");
    else
      for (sBars=sBars;sBars<Bars;sBars++)
      {
        sOffMidBuffer.Insert(0,0.00);
        sPriorMidBuffer.Insert(0,0.00);
      }
  }

//+------------------------------------------------------------------+
//| LoadHistory - Loads history from the first session open          |
//+------------------------------------------------------------------+
void CSession::LoadHistory(void)
  {    
    //--- Initialize period operationals
    sBar                             = Bars-1;
    sBars                            = Bars;
    sBarDay                          = NoValue;
    sBarHour                         = NoValue;

    //--- Initialize session records
    for (RecordType type=ActiveRec;type<RecordTypes;type++)
    {
      srec[type].Direction           = DirectionNone;
      srec[type].Age                 = 0;
      srec[type].State               = NoState;
      srec[type].High                = High[sBar];
      srec[type].Low                 = Low[sBar];
    }

    for(sBar=Bars-1;sBar>0;sBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| Session Class Constructor                                        |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type, int HourOpen, int HourClose)
  {
    //--- Init global session values
    sType                           = Type;
    sHourOpen                       = HourOpen;
    sHourClose                      = HourClose;
    sSessionIsOpen                  = false;
    
    sEvent                          = new CEvent();

    sOffMidBuffer                   = new CArrayDouble(Bars);
    sOffMidBuffer.Truncate          = false;
    sOffMidBuffer.AutoExpand        = true;    
    sOffMidBuffer.SetPrecision(Digits);
    sOffMidBuffer.Initialize(0.00);
    
    sPriorMidBuffer                 = new CArrayDouble(Bars);
    sPriorMidBuffer.Truncate        = false;
    sPriorMidBuffer.AutoExpand      = true;
    sPriorMidBuffer.SetPrecision(Digits);
    sPriorMidBuffer.Initialize(0.00);
    
    LoadHistory();    
  }

//+------------------------------------------------------------------+
//| Session Class Destructor                                         |
//+------------------------------------------------------------------+
CSession::~CSession()
  {
    delete sEvent;
    delete sOffMidBuffer;
    delete sPriorMidBuffer;
  }

//+------------------------------------------------------------------+
//| Update - Updates open session data and events                    |
//+------------------------------------------------------------------+
void CSession::Update(void)
  {
    UpdateBuffers();
    CalcEvents();
  }
  
//+------------------------------------------------------------------+
//| Update - Updates and returns buffer values                       |
//+------------------------------------------------------------------+
void CSession::Update(double &OffMidBuffer[], double &PriorMidBuffer[])
  {
    Update();
    
    sOffMidBuffer.Copy(OffMidBuffer);
    sPriorMidBuffer.Copy(PriorMidBuffer);
  }
  
//+------------------------------------------------------------------+
//| SessionIsOpen - Returns true if session is open for trade        |
//+------------------------------------------------------------------+
bool CSession::IsOpen(void)
  {
    if (TimeHour(Time[sBar])>=sHourOpen && TimeHour(Time[sBar])<sHourClose)
      return (true);
        
    return (false);
  }
  
//+------------------------------------------------------------------+
//| TradeBias - returns the trade bias based on Time Period          |
//+------------------------------------------------------------------+
int CSession::TradeBias(void)
  {    
    //if (sSessionIsOpen)
    //{
    //  if (IsHigher(srActive.OffMid,srActive.PriorMid,NoUpdate,Digits))
    //    return(OP_BUY);
    //  if (IsLower(srActive.OffMid,srActive.PriorMid,NoUpdate,Digits))
    //    return(OP_SELL);
    //}
    //else
    //{
    //  if (IsHigher(ActiveMid(),srActive.PriorMid,NoUpdate,Digits))
    //    return(OP_BUY);
    //  if (IsLower(ActiveMid(),srActive.PriorMid,NoUpdate,Digits))
    //    return(OP_SELL);
    //}
      
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| ActiveMid - returns the current active mid price (Fibo50)        |
//+------------------------------------------------------------------+
double CSession::ActiveMid(void)
  {
    return(fdiv(srec[ActiveRec].High+srec[ActiveRec].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| PriorMid - returns the prior session mid price (Fibo50)          |
//+------------------------------------------------------------------+
double CSession::PriorMid(void)
  {
    return(fdiv(srec[PriorRec].High+srec[PriorRec].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| OffsessionMid - returns the offsession mid price (Fibo50)        |
//+------------------------------------------------------------------+
double CSession::OffsessionMid(void)
  {
    return(fdiv(srec[OffsessionRec].High+srec[OffsessionRec].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| PrintSession - Prints Session Record details                     |
//+------------------------------------------------------------------+
void CSession::PrintSession(int Type)
  {  
    string psSessionInfo      = EnumToString(this.Type())+"|"
                              + BoolToStr(srec[Type].Direction==DirectionUp,"Long|","Short|")
                              + IntegerToString(srec[Type].Age)+"|"
                              + EnumToString(srec[Type].State)+"|"
                              + DoubleToStr(srec[Type].High,Digits)+"|"
                              + DoubleToStr(srec[Type].Low,Digits)+"|"
                              + DoubleToStr(srec[Type].Resistance,Digits)+"|"
                              + DoubleToStr(srec[Type].Support,Digits)+"|"
                              + DoubleToStr(srec[Type].Correction,Digits)+"|"
                              + DoubleToStr(srec[Type].Hedge,Digits);

    Print(psSessionInfo);
  }
