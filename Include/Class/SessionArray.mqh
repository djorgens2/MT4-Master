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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSessionArray
  {

public:

             //-- Session Types`
             enum SessionType
             {
               Asia,
               Europe,
               US,
               Daily,
               SessionTypes
             };

             CSessionArray(SessionType Type, int HourOpen, int HourClose);
             CSessionArray(int NewDay);
            ~CSessionArray();

             bool          SessionIsOpen(void);
             bool          Event(EventType Type) {return (sEvent[Type]);}
             bool          ActiveEvent(void)     {return (sEvent.ActiveEvent());}
             double        Support(void)         {return (sSupport);}
             double        Resistance(void)      {return (sResistance);}

             int           Direction(RetraceType Type);
             void          Update(void);
             
                    
private:

             //--- Private Class properties
             struct SessionRec
             {
               int         sTermDir;
               double      sOpen;
               double      sHigh;
               double      sLow;
               double      sClose;
               int         sBoundaryCount;
               TrendState  sState;
             };

             SessionType   sType;
             
             bool          sSessionIsOpen;
             int           sPreviousHour;

             int           sTrendDir;
             bool          sTrendPeg;
             int           sHourOpen;
             int           sHourClose;
             int           sBar;
             
             datetime      sStartTime;
             
             double        sSupport;
             double        sResistance;

             //--- Private class collections
             SessionRec    srActive;
             SessionRec    srHistory[];
             CEvent       *sEvent;
             
             //--- Private Methods
             void OpenSession(void);
             void CloseSession(void);
             void LoadHistory(void);
  };

//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSessionArray::OpenSession(void)
  {
     srActive.sTermDir               = DirectionNone;
     srActive.sOpen                  = Open[sBar];
     srActive.sHigh                  = High[sBar];
     srActive.sLow                   = Low[sBar];
     srActive.sClose                 = NoValue;
     srActive.sBoundaryCount         = NoValue;
     srActive.sState                 = NoState;
     
     sEvent.SetEvent(SessionOpen);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSessionArray::CloseSession(void)
  {
     srActive.sClose                 = Close[sBar+1];

     sEvent.SetEvent(SessionClose);
     
     if (srActive.sState==NoState)
     {
       if (srActive.sTermDir==DirectionUp)
         srActive.sState             = LongTerm;

       if (srActive.sTermDir==DirectionDown)
         srActive.sState             = ShortTerm;

       sTrendDir                     = srActive.sTermDir;
     }
     
     sSupport                        = srActive.sLow;
     sResistance                     = srActive.sHigh;
     
     ArrayResize(srHistory,ArraySize(srHistory)+1);
     srHistory[ArraySize(srHistory)-1] = srActive;
  }

//+------------------------------------------------------------------+
//| Session Class Constructor for non-daily                          |
//+------------------------------------------------------------------+
void CSessionArray::LoadHistory(void)
  {
    sSupport               = NoValue;
    sResistance            = NoValue;
    
    sEvent                 = new CEvent();
    sEvent.ClearEvents();
    
    sBar                   = iBarShift(Symbol(),PERIOD_H1,StrToTime(TimeToStr(Time[Bars-24], TIME_DATE)+" "+lpad(IntegerToString(sHourOpen),"0",2)+":00"));
    sStartTime             = Time[sBar];
    sPreviousHour          = TimeHour(Time[sBar]);
    
    for (sBar=sBar;sBar>0;sBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| Session Class Constructor for non-daily                          |
//+------------------------------------------------------------------+
CSessionArray::CSessionArray(SessionType Type, int HourOpen, int HourClose)
  {
    //--- Init global session values
    sType                  = Type;
    sTrendDir              = DirectionNone;
    sHourOpen              = HourOpen;
    sHourClose             = HourClose;
    sPreviousHour          = HourOpen;
    
    LoadHistory();    
  }

//+------------------------------------------------------------------+
//| Session Class Constructor for daily                              |
//+------------------------------------------------------------------+
CSessionArray::CSessionArray(int NewDay)
  {
    //--- Init global session values
    sType                  = Daily;
    sTrendDir              = DirectionNone;
    sHourOpen              = NewDay;
    sHourClose             = NewDay;
    sPreviousHour          = NewDay;
    
    LoadHistory();
  }

//+------------------------------------------------------------------+
//| Session Class Destructor                                         |
//+------------------------------------------------------------------+
CSessionArray::~CSessionArray()
  {
    delete sEvent;
  }

//+------------------------------------------------------------------+
//| Update - Updates open session data and events                    |
//+------------------------------------------------------------------+
void CSessionArray::Update(void)
  {
    //--- Clear events
    sEvent.ClearEvents();
        
    //--- Handle New Day
    if (IsChanged(sPreviousHour,TimeHour(Time[sBar])))
      if (sPreviousHour==sHourNewDay)
        sEvent.SetEvent(NewDay);
        
    if (sType==Daily && sEvent[NewDay])
      CloseSession();
    else
    
    //--- Handle Session Open
    if (this.SessionIsOpen())
    {
      if (IsChanged(sSessionIsOpen,this.SessionIsOpen()))
        OpenSession();
        
      //--- Test for session high
      if (IsHigher(High[sBar],srActive.sHigh))
      {
        sEvent.SetEvent(NewHigh);
        sEvent.SetEvent(NewBoundary);
        
        if (IsChanged(srActive.sTermDir,DirectionUp))
        {
          sEvent.SetEvent(NewDirection);
          sEvent.SetEvent(NewTerm);
        }
      }
        
      //--- Test for session low
      if (IsLower(Low[sBar],srActive.sLow))
      {
        sEvent.SetEvent(NewLow);
        sEvent.SetEvent(NewBoundary);

        if (IsChanged(srActive.sTermDir,DirectionDown))
        {
          sEvent.SetEvent(NewDirection);
          sEvent.SetEvent(NewTerm);
        }
      }
      
      //--- Test for session trend changes
      if (sTrendDir!=DirectionNone)
      {
      }    
    }
    else

    //--- Handle Session Close
    if (IsChanged(sSessionIsOpen,this.SessionIsOpen()))
      CloseSession();    
  }
  
//+------------------------------------------------------------------+
//| SessionIsOpen - Returns true if session is open for trade        |
//+------------------------------------------------------------------+
bool CSessionArray::SessionIsOpen(void)
  {
    if (TimeHour(Time[sBar])>=sHourOpen && TimeHour(Time[sBar])<sHourClose)
      return (true);
        
    if (sType==Daily)
      return (true);
      
    return (false);
  }
  
//+------------------------------------------------------------------+
//| Direction - Returns the direction for the supplied type          |
//+------------------------------------------------------------------+
int CSessionArray::Direction(RetraceType Type)
  {    
    switch (Type)
    {
      case Trend:   return(Direction(sResistance-sSupport));
      case Term:    return(srActive.sTermDir);
    }
    
    return (DirectionNone);
  }