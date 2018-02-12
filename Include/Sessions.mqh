//+------------------------------------------------------------------+
//|                                                     Sessions.mqh |
//|                                 Copyright 2017, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Dennis Jorgenson"
#property link      ""
#property strict

#include <std_utility.mqh>
#include <stdutil.mqh>

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input string SessionHeader           = "";        //+---- Session Hours -------+
input int    NewDay                  = 0;         // New Day
input int    AsiaOpen                = 1;         // Asia Open
input int    AsiaClose               = 10;        // Asia Close
input int    EuropeOpen              = 8;         // Europe Open
input int    EuropeClose             = 18;        // Europe Close
input int    USOpen                  = 14;        // US Open
input int    USClose                 = 23;        // US Close

//+------------------------------------------------------------------+
//| Types                                                            |
//+------------------------------------------------------------------+
  enum SessionType
  {
    Asia,
    Europe,
    US,
    SessionTypes
  };
       
  enum SessionState
  {
    dnConsCont = 57,   // Downside Consolidation Continuation
    upConsCont = 59,   // Upside Consolidation Continuation
    upBrkCons  = 61,   // Upside Breakout from Consolidation
    dnBrkCons  = 63,   // Downside Breakout from Consolidation
    upTrCont   = 74,   // Upside Trend Continuation
    dnTrCont   = 75,   // Downside Trend Continuation
    dnRev      = 76,   // Downside Reversal
    upRev      = 77,   // Upside Reversal
    opSession  = 82,   // Session Open
    upSession  = 199,  // Session High
    dnSession  = 200   // Session Low
  };
       
  struct SessionRec
  {
    double       SessionOpen;
    double       SessionHigh;
    double       SessionLow;
    int          SessionDir;
    bool         Active;
    bool         Breakout;
    bool         Reversal;
  };
  
//+------------------------------------------------------------------+
//| Record Pointers                                                  |
//+------------------------------------------------------------------+
  SessionRec            SessionNow[SessionTypes];
  SessionRec            SessionHistory[SessionTypes];
  SessionRec            LastSession;
  SessionType           LeadSession;

//+------------------------------------------------------------------+
//| Indicators                                                       |
//+------------------------------------------------------------------+
  bool       opNewDay          = false;
  bool       opSessionOpen     = false;
  bool       opSessionClose    = false;
  bool       opNewSessionHigh  = false;
  bool       opNewSessionLow   = false;
  bool       opMultipleAlert   = false;
  
//+------------------------------------------------------------------+
//| RefreshSession                                                   |
//+------------------------------------------------------------------+
void RefreshSession(void)
  {
    int      rsSessionColor;
    string   rsComment        = "";
    
    for (SessionType rsId=Asia; rsId<SessionTypes; rsId++)
    {
      rsSessionColor             = clrDarkGray;
      
      if (SessionNow[rsId].Active)
        rsSessionColor           = clrYellow;

      UpdateLabel("lbSess"+EnumToString(rsId),EnumToString(rsId),rsSessionColor);
      UpdateDirection("lbArrow"+EnumToString(rsId),SessionNow[rsId].SessionDir,DirColor(SessionNow[rsId].SessionDir));
      
      if (rsId==Asia)    rsSessionColor = clrForestGreen;
      if (rsId==Europe)  rsSessionColor = clrFireBrick;
      if (rsId==US)      rsSessionColor = clrDarkBlue;

      UpdatePriceLabel("plb"+EnumToString(rsId)+"High",SessionNow[rsId].SessionHigh,rsSessionColor);
      UpdatePriceLabel("plb"+EnumToString(rsId)+"Low",SessionNow[rsId].SessionLow,rsSessionColor);
    }
    
    Comment(rsComment);
    
    UpdatePriceLabel("plbPrevHigh",LastSession.SessionHigh,clrYellow);
    UpdatePriceLabel("plbPrevLow",LastSession.SessionLow,clrYellow);
    
    if (opNewSessionHigh)
      UpdateLabel("lbAlert","New High",clrLawnGreen,14);
    else
      if (opNewSessionLow)
        UpdateLabel("lbAlert","New Low",clrRed,14);
      else
        UpdateLabel("lbAlert","",clrBlack,14);      
  }
  
//+------------------------------------------------------------------+
//| PriorSession                                                     |
//+------------------------------------------------------------------+
SessionType PriorSession(SessionType Id)
  {
    if (Id == Asia)
      return (US);
    
    return (--Id);
  }
  
//+------------------------------------------------------------------+
//| NextSession                                                      |
//+------------------------------------------------------------------+
SessionType NextSession(SessionType Id)
  {
    if (Id == US)
      return (Asia);
    
    return (++Id);
  }
  
//+------------------------------------------------------------------+
//| CloseSession                                                     |
//+------------------------------------------------------------------+
void CloseSession(SessionType Id)
  {
    SessionNow[Id].Active           = false;
    SessionHistory[Id]              = SessionNow[Id];

    LastSession                     = SessionNow[Id];

    opSessionClose                  = true;
  }
  
//+------------------------------------------------------------------+
//| OpenSession                                                      |
//+------------------------------------------------------------------+
void OpenSession(SessionType Id, int Bar=0)
  {
    SessionNow[Id].SessionOpen      = Open[Bar];
    SessionNow[Id].SessionHigh      = High[Bar];
    SessionNow[Id].SessionLow       = Low[Bar];
    SessionNow[Id].SessionDir       = DirectionNone;
    SessionNow[Id].Active           = true;
    SessionNow[Id].Breakout         = false;
    SessionNow[Id].Reversal         = false;
    
    LastSession                     = SessionNow[PriorSession(Id)];
    LeadSession                     = Id;

    opSessionOpen                   = true;
  }

//+------------------------------------------------------------------+
//| UpdateSessions                                                   |
//+------------------------------------------------------------------+
void UpdateSessions(int Bar=0)
  {
    static int usHour           = NoValue;
           int usLastSessionDir = DirectionNone;
           int usNewSessionDir  = DirectionNone;
    
    //--- Reset tick events
    opNewDay                    = false;
    opSessionOpen               = false;
    opSessionClose              = false;
    opNewSessionHigh            = false;
    opNewSessionLow             = false;
    opMultipleAlert             = false;
    
    if (IsChanged(usHour,TimeHour(Time[Bar])))
    {
      if (usHour==NewDay)       opNewDay       = true;
      if (usHour==AsiaOpen)     OpenSession(Asia,Bar);
      if (usHour==EuropeOpen)   OpenSession(Europe,Bar);
      if (usHour==AsiaClose)    CloseSession(Asia);
      if (usHour==USOpen)       OpenSession(US,Bar);
      if (usHour==EuropeClose)  CloseSession(Europe);
      if (usHour==USClose)      CloseSession(US);
    }
    
    for (SessionType usId=Asia; usId<SessionTypes; usId++)
      if (SessionNow[usId].Active)
      {
        usNewSessionDir                  = SessionNow[usId].SessionDir;
        usLastSessionDir                 = SessionNow[usId].SessionDir;
      
        if (IsHigher(High[Bar],SessionNow[usId].SessionHigh))
        {
          opNewSessionHigh               = true;

          if (IsHigher(SessionNow[usId].SessionHigh,LastSession.SessionHigh,NoUpdate))
            usNewSessionDir              = DirectionUp;
        }

        if (IsLower(Low[Bar],SessionNow[usId].SessionLow))
        {
          opNewSessionLow                = true;

          if (IsLower(SessionNow[usId].SessionLow,LastSession.SessionLow,NoUpdate))
            usNewSessionDir              = DirectionDown;
        }
        
        if (IsChanged(SessionNow[usId].SessionDir, usNewSessionDir))
        {
          if (usId==LeadSession)
          {
            if (usLastSessionDir == DirectionNone)
              SessionNow[usId].Breakout    = true;
            else
            if (usLastSessionDir != usNewSessionDir)
              SessionNow[usId].Reversal    = true;
          }
          else
          if (IsHigher(SessionNow[usId].SessionHigh,SessionNow[PriorSession(usId)].SessionHigh,NoUpdate) ||
              IsLower(SessionNow[usId].SessionLow,SessionNow[PriorSession(usId)].SessionLow,NoUpdate))
          {
            opMultipleAlert                = true;
            
            if (usLastSessionDir == DirectionNone)
              SessionNow[usId].Breakout    = true;
            else
            if (usLastSessionDir != usNewSessionDir)
              SessionNow[usId].Reversal    = true;
          }
        }
      }
      
    RefreshSession();
  }
  
//+------------------------------------------------------------------+
//| InitSessions                                                     |
//+------------------------------------------------------------------+
void InitSessions(void)
  {
    NewLabel("lbSessAsia","Asia",20,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessEurope","Europe",20,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessUS","US",20,29,clrDarkGray,SCREEN_LR);
    
    NewLabel("lbArrowAsia","",5,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbArrowEurope","",5,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbArrowUS","",5,29,clrDarkGray,SCREEN_LR);

    NewLabel("lbAlert","",5,5,clrDarkGray,SCREEN_LR);
    
    NewPriceLabel("plbAsiaHigh");
    NewPriceLabel("plbAsiaLow");
    NewPriceLabel("plbEuropeHigh");
    NewPriceLabel("plbEuropeLow");
    NewPriceLabel("plbUSHigh");
    NewPriceLabel("plbUSLow");
    NewPriceLabel("plbPrevHigh");
    NewPriceLabel("plbPrevLow");

    for (int isBar=60; isBar>0; isBar--)
      UpdateSessions(isBar);
  }
