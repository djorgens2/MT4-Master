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
             //-- Session Record Definition
             struct SessionRec
             {
               int         TermDir;
               double      Open;
               double      High;
               double      Low;
               double      Close;
               int         BoundaryCount;
               TrendState  State;
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

             CSessionArray(SessionType Type, int HourOpen, int HourClose);
             CSessionArray(SessionType Type);
            ~CSessionArray();

             bool          SessionIsOpen(void);
             bool          Event(EventType Type) {return (sEvent[Type]);}
             bool          ActiveEvent(void)     {return (sEvent.ActiveEvent());}
             double        Support(void)         {return (sSupport);}
             double        Resistance(void)      {return (sResistance);}
             SessionRec    Active(void)          {return (srActive);}
             SessionRec    History(int Shift)    {return (srHistory[Shift]);}

             int           Direction(RetraceType Type);
             void          Update(void);
             
                    
private:

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;

             int           sTrendDir;
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
             bool NewDay(void);
  };

//+------------------------------------------------------------------+
//| NewDay - Sets the NewDay event based on the new day start hour   |
//+------------------------------------------------------------------+
bool CSessionArray::NewDay(void)
  {
     static int ndSaveHour  = 0;
     
     if (IsChanged(ndSaveHour,TimeHour(Time[sBar])))
       if (ndSaveHour==sHourOpen)
       {
         sEvent.SetEvent(NewDay);
         return (true);
       }
     
     return (false);
  }

//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSessionArray::OpenSession(void)
  {
     srActive.TermDir                = DirectionNone;
     srActive.Open                   = Open[sBar];
     srActive.High                   = High[sBar];
     srActive.Low                    = Low[sBar];
     srActive.Close                  = NoValue;
     srActive.BoundaryCount          = NoValue;
     srActive.State                  = NoState;
     
     sEvent.SetEvent(SessionOpen);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSessionArray::CloseSession(void)
  {
     srActive.Close                   = Close[sBar+1];

     sEvent.SetEvent(SessionClose);
     
     if (srActive.State==NoState)
     {
       if (srActive.TermDir==DirectionUp)
         srActive.State              = LongTerm;

       if (srActive.TermDir==DirectionDown)
         srActive.State              = ShortTerm;

       sTrendDir                     = srActive.TermDir;
     }
     
     sSessionIsOpen                  = false;
     sSupport                        = srActive.Low;
     sResistance                     = srActive.High;
     
     ArrayResize(srHistory,ArraySize(srHistory)+1);
     srHistory[ArraySize(srHistory)-1] = srActive;

     //--- Set Active to OffSession
     srActive.Open                   = Open[sBar];
     srActive.High                   = High[sBar];
     srActive.Low                    = Low[sBar];
     srActive.Close                  = NoValue;
  }

//+------------------------------------------------------------------+
//| LoadHistory - Loads history from the first session open          |
//+------------------------------------------------------------------+
void CSessionArray::LoadHistory(void)
  {
    sSupport               = NoValue;
    sResistance            = NoValue;
    
    sEvent                 = new CEvent();
    sEvent.ClearEvents();
    
    sBar                   = iBarShift(Symbol(),PERIOD_H1,StrToTime(TimeToStr(Time[Bars-24], TIME_DATE)+" "+lpad(IntegerToString(sHourOpen),"0",2)+":00"));
    sStartTime             = Time[sBar];
    
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
    
    LoadHistory();    
  }

//+------------------------------------------------------------------+
//| Session Class Constructor for daily                              |
//+------------------------------------------------------------------+
CSessionArray::CSessionArray(SessionType NewDay)
  {
    const int NewDayHour   = 0;
    
    //--- Init global session values
    sType                  = Daily;
    sTrendDir              = DirectionNone;
    sHourOpen              = NewDayHour;
    sHourClose             = NewDayHour;
    
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
    if (sType==Daily && NewDay())
      CloseSession();
    else
    
    //--- Handle Session Open
    if (this.SessionIsOpen())
    {
      if (IsChanged(sSessionIsOpen,this.SessionIsOpen()))
        OpenSession();
        
      //--- Test for session high
      if (IsHigher(High[sBar],srActive.High))
      {
        sEvent.SetEvent(NewHigh);
        sEvent.SetEvent(NewBoundary);
        
        if (IsChanged(srActive.TermDir,DirectionUp))
        {
          sEvent.SetEvent(NewDirection);
          sEvent.SetEvent(NewTerm);
        }
      }
        
      //--- Test for session low
      if (IsLower(Low[sBar],srActive.Low))
      {
        sEvent.SetEvent(NewLow);
        sEvent.SetEvent(NewBoundary);

        if (IsChanged(srActive.TermDir,DirectionDown))
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
    {
      //--- Handle Session Close
      if (IsChanged(sSessionIsOpen,this.SessionIsOpen()))
        CloseSession();
      else
      
      //--- Handle off session events
      {
        
      }
    }
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
      case Trend:   return (Direction(sResistance-sSupport));
      case Term:    return (srActive.TermDir);
      case Prior:   return (srHistory[ArraySize(srHistory)-1].TermDir);
    }
    
    return (DirectionNone);
  }