//+------------------------------------------------------------------+
//|                                                   dj-live-v7.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "7.00"
#property strict

#define   Always     true

#include <manual.mqh>
#include <Class\Session.mqh>
#include <Class\PipFractal.mqh>

  
input string    fractalHeader        = "";    //+------ Fractal Options ---------+
input int       inpRangeMin          = 60;    // Minimum fractal pip range
input int       inpRangeMax          = 120;   // Maximum fractal pip range
input int       inpPeriodsLT         = 240;   // Long term regression periods

input string    RegressionHeader     = "";    //+------ Regression Options ------+
input int       inpDegree            = 6;     // Degree of poly regression
input int       inpSmoothFactor      = 3;     // MA Smoothing factor
input double    inpTolerance         = 0.5;   // Directional sensitivity
input int       inpPipPeriods        = 200;   // Trade analysis periods (PipMA)
input int       inpRegrPeriods       = 24;    // Trend analysis periods (RegrMA)

input string    SessionHeader        = "";    //+---- Session Hours -------+
input int       inpAsiaOpen          = 1;     // Asian market open hour
input int       inpAsiaClose         = 10;    // Asian market close hour
input int       inpEuropeOpen        = 8;     // Europe market open hour
input int       inpEuropeClose       = 18;    // Europe market close hour
input int       inpUSOpen            = 14;    // US market open hour
input int       inpUSClose           = 23;    // US market close hour
input int       inpGMTOffset         = 0;     // GMT Offset


  //--- Class Objects
  CSession           *session[SessionTypes];
  CSession           *lead;
  CFractal           *fractal        = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal       = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,50,fractal);
  CEvent             *sEvent         = new CEvent();
  CEvent             *fEvent         = new CEvent();
  CEvent             *pfEvent        = new CEvent();
  CEvent             *toEvent        = new CEvent();
                        
  //--- Collection Objects
  struct              SessionDetail 
                      {
                        int            OpenDir;
                        int            ActiveDir;
                        int            OpenBias;
                        int            ActiveBias;
                        bool           Reversal;
                        int            FractalDir;
                        bool           NewFractal;
                        int            FractalHour;
                        int            HighHour;
                        int            LowHour;
                        double         ForecastHigh;
                        double         ForecastLow;
                        double         Entry[2];
                        double         Profit[2];
                        double         Risk[2];
                        bool           IsValid;
                        bool           Alerts;
                      };


  //--- Display operationals
  string              rsShow              = "APP";
  bool                PauseOn             = true;
  int                 PauseOnHour         = NoValue;
  bool                ScalperOn           = false;
  bool                LoggingOn           = false;
  bool                TradingOn           = true;
  bool                Alerts[EventTypes];
  
  //--- Session operationals
  SessionDetail       detail[SessionTypes];
  SessionDetail       history[SessionTypes];
  
  //--- Trade operationals
  bool                OrderTrigger         = false;
  int                 OrderAction          = OP_NO_ACTION;
  EventType           OrderEvent           = NoEvent;
  ReservedWords       OrderState           = NoState;
  int                 OrderStateDir        = DirectionNone;
  
  int                 SessionHour;
    
  double              toBoundarycrest      = 0.00;
  int                 toBoundaryDir        = DirectionNone;
  
  

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message, bool Force=false)
  {
    static string cpMessage   = "";
    
    if (PauseOn||Force)
      if (IsChanged(cpMessage,Message)||Force)
        Pause(Message,AccountCompany()+" Event Trapper");

    if (LoggingOn)
      Print(Message);
  }
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      session[type].Update();
      
      if (session[type].IsOpen())
        lead             = session[type];
    }
    
    fractal.Update();
    pfractal.Update();
  }

//+------------------------------------------------------------------+
//| ServerHour - returns the server hour adjused for gmt             |
//+------------------------------------------------------------------+
int ServerHour(void)
  { 
    return (TimeHour(session[Daily].ServerTime()));
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "";

    UpdateLabel("lbEQ",OrdersTotal(),clrLawnGreen,10);
    if (sEvent.EventAlert(NewReversal,Caution))
      UpdateDirection("lbState",OrderBias(),clrYellow);
    else
      UpdateDirection("lbState",OrderBias(),DirColor(OrderBias()));

    if (rsShow=="APP")
    {
      for (SessionType type=Daily;type<SessionTypes;type++)
        rsComment       += BoolToStr(lead.Type()==type,"-->")+EnumToString(type)
                           +BoolToStr(session[type].IsOpen()," ("+IntegerToString(session[type].SessionHour())+")"," Closed")
                           +"\n  Direction (Open/Active): "+DirText(detail[type].OpenDir)+"/"+DirText(detail[type].ActiveDir)
                           +"\n  Bias (Open/Active): "+ActionText(detail[type].OpenBias)+"/"+ActionText(detail[type].ActiveBias)
                           +"\n  State: "+BoolToStr(detail[type].IsValid,"OK","Invalid")
                           +"  "+BoolToStr(detail[type].Reversal,"Reversal",BoolToStr(detail[type].FractalDir==DirectionNone,"",DirText(detail[type].FractalDir)))
                           +"\n\n";

      Comment(rsComment);
    }
    
    if (rsShow=="FRACTAL")
      fractal.RefreshScreen();

    if (rsShow=="PIPMA")
      if (pfractal.HistoryLoaded())
        pfractal.RefreshScreen();

    if (rsShow=="DAILY")
      session[Daily].RefreshScreen();
      
    if (rsShow=="LEAD")
      lead.RefreshScreen();

    if (rsShow=="ASIA")
      session[Asia].RefreshScreen();

    if (rsShow=="EUROPE")
      session[Europe].RefreshScreen();

    if (rsShow=="US")
      session[US].RefreshScreen();

    sEvent.ClearEvents();
    rsComment    = "";
    
    for (EventType type=1;type<EventTypes;type++)
      if (Alerts[type]&&pfractal.Event(type))
      {
        rsComment   = "PipMA "+pfractal.ActiveEventText()+"\n";
        break;
      }

    for (EventType type=1;type<EventTypes;type++)
      if (Alerts[type]&&fractal.Event(type))
      {
        rsComment   = "Fractal "+fractal.ActiveEventText()+"\n";
        break;
      }

    for (SessionType show=Daily;show<SessionTypes;show++)
      if (detail[show].Alerts)
        for (EventType type=1;type<EventTypes;type++)
          if (Alerts[type]&&session[show].Event(type))
          {
            if (type==NewFractal)
            {
              if (!detail[show].NewFractal)
                sEvent.SetEvent(type);
                
              detail[show].FractalHour = ServerHour();
            }
            else
              sEvent.SetEvent(type);
          }

    if (sEvent.ActiveEvent())
    {
      Append(rsComment,"Processed "+sEvent.ActiveEventText(true)+"\n","\n");
    
      for (SessionType show=Daily;show<SessionTypes;show++)
        Append(rsComment,EnumToString(show)+" ("+BoolToStr(session[show].IsOpen(),
           "Open:"+IntegerToString(session[show].SessionHour()),
           "Closed")+")"+session[show].ActiveEventText(false)+"\n","\n");
    }

    if (StringLen(rsComment)>0)
      CallPause(rsComment);
  }

//+------------------------------------------------------------------+
//| NewDirection - Updates Direction based on an actual change       |
//+------------------------------------------------------------------+
bool NewDirection(int &Now, int New)
  {    
    if (New==DirectionNone)
      return (false);
      
    if (Now==DirectionNone)
      Now             = New;
      
    if (IsChanged(Now,New))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| NewBias - Updates Trade Bias based on an actual change           |
//+------------------------------------------------------------------+
bool NewBias(int &Now, int New)
  {    
    if (New==OP_NO_ACTION)
      return (false);
      
    if (IsChanged(Now,New))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| CheckSessionEvents - updates trading strategy on session events  |
//+------------------------------------------------------------------+
void CheckSessionEvents(void)
  {          
    bool cseIsValid;
    
    sEvent.ClearEvents();
    
    //-- Set General Notification Events
    if (session[Daily].Event(NewDay))
      sEvent.SetEvent(NewDay);
      
    if (session[Daily].Event(NewHour))
      sEvent.SetEvent(NewHour);
      
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      //-- Set Session Notification Events
      if (session[type].Event(SessionOpen))
        sEvent.SetEvent(SessionOpen);
        
      //-- Evaluate and Set Session Fractal Events
      if (session[type].Event(NewOriginState))
        sEvent.SetEvent(NewOriginState,session[type].AlertLevel(NewOriginState));

      if (session[type].Event(NewFractal))
      {
        detail[type].NewFractal       = true;

        if (type==Daily)
        {
          sEvent.SetEvent(NewFractal,Major);
          
//          if (
        }
        else
          sEvent.SetEvent(NewFractal,Minor);
      }
          
      if (session[type].Event(NewTerm))
        sEvent.SetEvent(NewTerm,session[type].AlertLevel(NewTerm));
        
      if (session[type].Event(NewTrend))
        sEvent.SetEvent(NewTrend,session[type].AlertLevel(NewTrend));

      if (session[type].Event(NewOrigin))
        sEvent.SetEvent(NewOrigin,session[type].AlertLevel(NewOrigin));
        
      if (session[type].Event(NewState))
        sEvent.SetEvent(NewState,Nominal);       

      //--- Session detail operational checks
      if (session[type].Event(NewHigh))
        detail[type].HighHour       = ServerHour();

      if (session[type].Event(NewLow))
        detail[type].LowHour        = ServerHour();

      if (NewDirection(detail[type].ActiveDir,Direction(session[type].Pivot(ActiveSession)-session[type].Pivot(PriorSession))))
        sEvent.SetEvent(NewPivot,Major);

      if (NewBias(detail[type].ActiveBias,session[type].Bias()))
        sEvent.SetEvent(NewBias,Minor);
        
      if (NewDirection(detail[type].FractalDir,session[type].Fractal(ftTerm).Direction))
        detail[type].Reversal      = true;
      
      cseIsValid                   = detail[type].IsValid;

      if (detail[type].ActiveDir==detail[type].OpenDir)
        if (detail[type].ActiveBias==detail[type].OpenBias)
          if (detail[type].ActiveDir==Direction(detail[type].ActiveBias,InAction))
            cseIsValid             = true;

      if (IsChanged(detail[type].IsValid,cseIsValid))
        sEvent.SetEvent(NewAction,Major);
    }    
  }
  
//+------------------------------------------------------------------+
//| CheckFractalEvents - Sets alerts for relevant Fractal events     |
//+------------------------------------------------------------------+
void CheckFractalEvents(void)
  {    
    fEvent.ClearEvents();

    if (fractal.ActiveEvent())
    {
      if (fractal.EventAlert(NewOrigin,Major))
        fEvent.SetEvent(NewOrigin,Major);

      if (fractal.EventAlert(NewRetrace,Major))
        fEvent.SetEvent(NewRetrace,Major);

      if (fractal.EventAlert(NewCorrection,Major))
        fEvent.SetEvent(NewCorrection,Major);

      if (fractal.EventAlert(NewResume,Major))
        fEvent.SetEvent(NewResume,Major);

      if (fractal.EventAlert(NewReversal,Major))
        fEvent.SetEvent(NewReversal,Major);

      if (fractal.EventAlert(NewBreakout,Major))
        fEvent.SetEvent(NewBreakout,Major);

      if (fractal.EventAlert(NewFibonacci,Major))
        fEvent.SetEvent(NewFibonacci,Major);

      if (fractal.EventAlert(NewFibonacci,Minor))
        fEvent.SetEvent(NewFibonacci,Minor);
    }
  }

//+------------------------------------------------------------------+
//| Draw - Paint Crest/Trough lines                                  |
//+------------------------------------------------------------------+
void Draw(EventType Event, bool NewEvent=true, int BarIndex=0)
  {
    static    int crestidx          = 0;
    static    int troughidx         = 0;
    
    static double crest[4];
    static double trough[4];

    if (NewEvent)
    {
      if (BarIndex==0)
      {
        ArrayInitialize(crest,Close[0]);
        ArrayInitialize(trough,Close[0]);
      }
        
      switch (Event)
      {
        case NewCrest:  toEvent.SetEvent(NewCrest);
                        crestidx++;
                       
                        ObjectCreate("lnCrestHL"+IntegerToString(crestidx),OBJ_TREND,0,Time[0],crest[1],Time[0],crest[2]);
                        ObjectCreate("lnCrestOC"+IntegerToString(crestidx),OBJ_TREND,0,Time[0],fmin(High[0],crest[0]),Time[0],Close[0]);
                     
                        ObjectSet("lnCrestHL"+IntegerToString(crestidx),OBJPROP_COLOR,clrYellow);
                        ObjectSet("lnCrestHL"+IntegerToString(crestidx),OBJPROP_RAY,false);
                        ObjectSet("lnCrestOC"+IntegerToString(crestidx),OBJPROP_RAY,false);
                        ObjectSet("lnCrestHL"+IntegerToString(crestidx),OBJPROP_WIDTH,2);
                        ObjectSet("lnCrestOC"+IntegerToString(crestidx),OBJPROP_WIDTH,12);
                        ObjectSet("lnCrestOC"+IntegerToString(crestidx),OBJPROP_BACK,true);
                        
                        if (IsLower(High[0],crest[0],NoUpdate))
                        {
                          NewPriceLabel("lnCrestAnom"+IntegerToString(crestidx),Close[0]);
                          UpdatePriceLabel("lnCrestAnom"+IntegerToString(crestidx),Close[0],clrYellow);
                        }

                        break;
                        
        case NewTrough: toEvent.SetEvent(NewTrough);
                        troughidx++;

                        ObjectCreate("lnTroughHL"+IntegerToString(troughidx),OBJ_TREND,0,Time[0],trough[1],Time[0],trough[2]);
                        ObjectCreate("lnTroughOC"+IntegerToString(troughidx),OBJ_TREND,0,Time[0],fmax(Low[0],trough[0]),Time[0],Close[0]);

                        ObjectSet("lnTroughHL"+IntegerToString(troughidx),OBJPROP_COLOR,clrRed);
                        ObjectSet("lnTroughHL"+IntegerToString(troughidx),OBJPROP_RAY,false);
                        ObjectSet("lnTroughOC"+IntegerToString(troughidx),OBJPROP_RAY,false);
                        ObjectSet("lnTroughHL"+IntegerToString(troughidx),OBJPROP_WIDTH,2);
                        ObjectSet("lnTroughOC"+IntegerToString(troughidx),OBJPROP_WIDTH,12);
                        ObjectSet("lnTroughOC"+IntegerToString(troughidx),OBJPROP_BACK,true);

                        if (IsHigher(Low[0],trough[0],NoUpdate))
                          NewPriceLabel("lnTroughAnom"+IntegerToString(troughidx),Close[0]);
      }
    }  

    for (int carry=BarIndex;carry>NoValue;carry--)
    {
      if (IsBetween(Close[0],High[carry],Low[carry]))
        switch (Event)
        {
          case NewCrest:  IsHigher(Close[0],crest[1]);
                          IsLower(Close[0],crest[2]);

                          ObjectSet("lnCrestHL"+IntegerToString(crestidx-carry),OBJPROP_PRICE1,fmin(High[carry],crest[1]));
                          ObjectSet("lnCrestHL"+IntegerToString(crestidx-carry),OBJPROP_PRICE2,fmax(Low[carry],crest[2]));
                          ObjectSet("lnCrestOC"+IntegerToString(crestidx-carry),OBJPROP_PRICE2,Close[0]);

                          break;

          case NewTrough: IsHigher(Close[0],trough[1]);
                          IsLower(Close[0],trough[2]);

                          ObjectSet("lnTroughHL"+IntegerToString(troughidx-carry),OBJPROP_PRICE1,fmin(High[carry],trough[1]));
                          ObjectSet("lnTroughHL"+IntegerToString(troughidx-carry),OBJPROP_PRICE2,fmax(Low[carry],trough[2]));
                          ObjectSet("lnTroughOC"+IntegerToString(troughidx-carry),OBJPROP_PRICE2,Close[0]);
        }
        
      if (Event==NewCrest)
        if (IsHigher(Close[0],crest[0],NoUpdate))
          ObjectSet("lnCrestOC"+IntegerToString(crestidx-carry),OBJPROP_COLOR,clrForestGreen);
        else
          ObjectSet("lnCrestOC"+IntegerToString(crestidx-carry),OBJPROP_COLOR,clrMaroon);

      if (Event==NewTrough)
        if (IsHigher(Close[0],trough[0],NoUpdate))
          ObjectSet("lnTroughOC"+IntegerToString(troughidx-carry),OBJPROP_COLOR,clrForestGreen);
        else
          ObjectSet("lnTroughOC"+IntegerToString(troughidx-carry),OBJPROP_COLOR,clrMaroon);
    }    
  }

//+------------------------------------------------------------------+
//| CheckPipMAEvents - Sets alerts for relevant PipMA events         |
//+------------------------------------------------------------------+
void CheckPipMAEvents(void)
  {    
    static int cpBarIndex   = 0;

    pfEvent.ClearEvents();

    for (EventType pf=1;pf<EventTypes;pf++)
    switch (pf)
    {
      case NewCrest:       
      case NewTrough:      if (pfractal.Event(pf))
                             Draw(pf);
                           else
                           if (toEvent[pf])
                             if (pfractal.PolyState()==Crest||pfractal.PolyState()==Trough)
                             {
                               if (sEvent[NewHour]) cpBarIndex++;
                               Draw(pf,sEvent[NewHour],cpBarIndex);
                             }
                             else
                             {
                               toEvent.ClearEvent(pf);
                               cpBarIndex   = 0;
                             }
      case NewFibonacci:
      case NewHigh:
      case NewLow:
      case NewPoly:
      case NewPolyBoundary:
      case NewPolyTrend:
      case NewPolyState:    if (pfractal.Event(pf)) pfEvent.SetEvent(pf);
                            break;
    }
  }

//+------------------------------------------------------------------+
//| SetOrderAction - updates session detail on a new order event     |
//+------------------------------------------------------------------+
void SetOrderAction(int Action, EventType Event)
  {
    OrderAction                    = Action;
    OrderEvent                     = Event;      
    OrderTrigger                   = true;

//    PauseOn                        = true;

    UpdateLabel("lbTrigger","Fired "+ActionText(OrderAction)+" on Event "+EnumToString(Event),clrYellow);
  }

//+------------------------------------------------------------------+
//| ClearOrderAction - validates OrderTrigger and clears if needed   |
//+------------------------------------------------------------------+
void ClearOrderAction(void)
  {
    OrderTrigger                   = false;
    OrderAction                    = OP_NO_ACTION;
    OrderEvent                     = NoEvent;

    UpdateLabel("lbTrigger","Waiting",clrLightGray);
  }

//+------------------------------------------------------------------+
//| OrderApproved - Performs health and sanity checks for approval   |
//+------------------------------------------------------------------+
bool OrderApproved(int Action)
  {
    if (TradingOn)
      return (true);

    ClearOrderAction();

    return (false);
  }

//+------------------------------------------------------------------+
//| OrderBias - Trade direction/action all factors considered        |
//+------------------------------------------------------------------+
int OrderBias(int Measure=InDirection)
  {
    static int odDirection      = DirectionNone;
    
    if (ServerHour()>3)
      odDirection               = Direction(detail[Daily].HighHour-detail[Daily].LowHour);
      
    return (odDirection);
   
   if (lead.SessionHour()>4)
     if ((lead[ActiveSession].Direction!=Direction(Close[0]-lead.Pivot(ActiveSession))))
       sEvent.SetEvent(NewReversal,Caution);    
  
    if (sEvent.EventAlert(NewReversal,Caution))
      return(Direction(lead[ActiveSession].Direction,InDirection,Contrarian));

    return (lead[ActiveSession].Direction);
  }

//+------------------------------------------------------------------+
//| ManageOrderEvents - Check events when activated by order event   |
//+------------------------------------------------------------------+
void ManageOrderEvents(void)
  {
    if (pfEvent[NewCrest])
    {
      SetEquityHold(OP_BUY);
      SetOrderAction(OP_SELL,NewCrest);
    }
    
    if (pfEvent[NewTrough])
    {
      SetEquityHold(OP_SELL);
      SetOrderAction(OP_BUY,NewTrough);
    }
    
    if (OrderTrigger)
      if (pfEvent[NewPoly])
        if (OrderApproved(OrderAction))
        {
          if (OpenOrder(OrderAction,EnumToString(OrderEvent)))
            ClearOrderAction();
            
          SetEquityHold();
        }
            
//     if (OrderClosed()||OrderFulfilled())
//       Pause ("Order Closed/Opened","Order Event");
  }
  
//+------------------------------------------------------------------+
//| ManageRiskEvents - Check events when activated by risk scenarios |
//+------------------------------------------------------------------+
void ManageRiskEvents(void)
  {
    //-- 1. Calculate risk level (0%-MinEQ=Healthy; to MinEQ*2=Working; to MinEQ*4=At Risk; >Adverse
    //-- 2. Calculate risk sliders Net EQ, Net Action Neg, Net Position Neg

  }

//+------------------------------------------------------------------+
//| SetNewDayPlan - Prepare the daily strategy                       |
//+------------------------------------------------------------------+
void SetNewDayPlan(void)
  {
    ArrayCopy(history,detail);
    
    //--- Reset Session Detail for this trading day
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      detail[type].FractalDir      = DirectionNone;
      detail[type].NewFractal      = false;
      detail[type].Reversal        = false;
      detail[type].HighHour        = ServerHour();
      detail[type].LowHour         = ServerHour();
    }
  }

//+------------------------------------------------------------------+
//| SetHourlyPlan - sets session hold/hedge detail by type hourly    |
//+------------------------------------------------------------------+
void SetHourlyPlan(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      detail[type].NewFractal      = false;
    }  
  }

//+------------------------------------------------------------------+
//| SetOpenPlan - sets session hold/hedge detail by type on open     |
//+------------------------------------------------------------------+
void SetOpenPlan(SessionType Type)
  {
    if (NewDirection(detail[Type].OpenDir,Direction(session[Type].Pivot(OffSession)-session[Type].Pivot(PriorSession))))
      sEvent.SetEvent(NewPivot,Major);
      
    if (NewBias(detail[Type].OpenBias,session[Type].Bias()))
      sEvent.SetEvent(NewBias);
  }

//+------------------------------------------------------------------+
//| AnalyzeData - Verify health and safety of open positions         |
//+------------------------------------------------------------------+
void AnalyzeData(void)
  {
    if (sEvent[NewDay])
      SetNewDayPlan();
      
    if (sEvent[NewHour])
      SetHourlyPlan();
      
    if (sEvent[SessionOpen])
      SetOpenPlan(lead.Type());
      

  }

//+------------------------------------------------------------------+
//| Scalper                                                          |
//+------------------------------------------------------------------+
void Scalper(void)
  {
    static int sActionHigh   = OP_NO_ACTION;
    static int sActionLow    = OP_NO_ACTION;

    if (sEvent[NewDay])
    {
      sActionHigh            = OP_NO_ACTION;
      sActionLow             = OP_NO_ACTION;
    }
    
    if (IsBetween(detail[Daily].HighHour,9,11))
      sActionHigh            = OP_SELL;

    if (IsBetween(detail[Daily].LowHour,9,11))
      sActionLow             = OP_BUY;

    if (ScalperOn)
    {        
      if (sActionHigh==OP_SELL)
        if (pfractal.Event(NewCrest))
          if (OpenOrder(sActionHigh,"Scalper"))
            sActionHigh        = OP_NO_ACTION;
    
      if (sActionLow==OP_BUY)
        if (pfractal.Event(NewTrough))
          if (OpenOrder(sActionHigh,"Scalper"))
            sActionLow         = OP_NO_ACTION; 
          
      if (ServerHour()>11)
        if (EquityPercent(Now)<0.00)
          CloseOrders(CloseAll);   

      if (ServerHour()>15)
      {
        CloseOrders(CloseAll);
        sActionHigh             = OP_NO_ACTION;
        sActionLow              = OP_NO_ACTION;
      }
    }
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    CheckSessionEvents();
    CheckFractalEvents();
    CheckPipMAEvents();

    if (PauseOnHour>NoValue)
      if (sEvent[NewHour])
        if (ServerHour()==PauseOnHour)
          CallPause("Pause requested on Server Hour "+IntegerToString(PauseOnHour),Always);
      

    Scalper();

    AnalyzeData();
    
    ManageOrderEvents();
    ManageRiskEvents();

  }

//+------------------------------------------------------------------+
//| AlertKey - Matches alert text and returns the enum               |
//+------------------------------------------------------------------+
EventType AlertKey(string Event)
  {
    string akType;
    
    for (EventType type=1;type<EventTypes;type++)
    {
      akType           = EnumToString(type);

      if (StringToUpper(akType))
        if (akType==Event)
          return (type);
    }    
    
    return(EventTypes);
  }


//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PAUSE")
    {
      PauseOn                          = true;

      if (Command[1]=="")
        PauseOnHour                    = NoValue;
      else
        PauseOnHour                    = (int)StringToInteger(Command[1]);
    }
      
    if (Command[0]=="PLAY")
      PauseOn                          = false;
    
    if (Command[0]=="SHOW")
      rsShow                           = Command[1];

    if (Command[0]=="DISABLE")
    {
      if (Command[1]=="ASIA")   detail[Asia].Alerts    = false;
      else      
      if (Command[1]=="EUROPE") detail[Europe].Alerts  = false;
      else      
      if (Command[1]=="US")     detail[US].Alerts      = false;
      else      
      if (Command[1]=="DAILY")  detail[Daily].Alerts   = false;
      else      
      if (StringSubstr(Command[1],0,5)=="SCALP")
         ScalperOn                     = false;
      else
      if (StringSubstr(Command[1],0,3)=="LOG")
        LoggingOn                      = false;
      else      
      if (StringSubstr(Command[1],0,4)=="TRAD")
        TradingOn                      = false;
      else
      if (Command[1]=="ALL")  
      {
        ArrayInitialize(Alerts,false);

        for (int alert=Daily;alert<SessionTypes;alert++)
         detail[alert].Alerts          = false;
      }   
      else
      {
        Alerts[AlertKey(Command[1])]   = false;
        Command[1]                     = EnumToString(EventType(AlertKey(Command[1])));
      }
      
      Print("Alerts for "+Command[1]+" disabled.");
    }

    if (Command[0]=="ENABLE")
    {
      if (Command[1]=="ASIA")   detail[Asia].Alerts    = true;
      else
      if (Command[1]=="EUROPE") detail[Europe].Alerts  = true;
      else
      if (Command[1]=="US")     detail[US].Alerts      = true;
      else
      if (Command[1]=="DAILY")  detail[Daily].Alerts   = true;
      else
      if (StringSubstr(Command[1],0,5)=="SCALP")
         ScalperOn                     = true;
      else
      if (StringSubstr(Command[1],0,3)=="LOG")
        LoggingOn                      = true;
      else      
      if (StringSubstr(Command[1],0,4)=="TRAD")
        TradingOn                      = true;
      else
      if (Command[1]=="ALL")
      {
        ArrayInitialize(Alerts,true);

        for (int alert=Daily;alert<SessionTypes;alert++)
         detail[alert].Alerts        = true;
      }
      else
      {
        Alerts[AlertKey(Command[1])]   = true;
        Command[1]                     = EnumToString(EventType(AlertKey(Command[1])));
      }
      
      Print("Alerts for "+Command[1]+" enabled.");
    }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string     otParams[];
  
    InitializeTick();

    GetManualRequest();

    while (AppCommand(otParams,6))
      ExecAppCommands(otParams);

    OrderMonitor();
    GetData();

    RefreshScreen();
    
    if (AutoTrade())
      Execute();
    
    ReconcileTick();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ManualInit();
    
    session[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
    
    NewLabel("lbTrigger","Waiting",15,5,clrLightGray,SCREEN_LL);
    NewLabel("lbState","",5,5,clrNONE,SCREEN_LL);
    
    ArrayInitialize(Alerts,true);

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      detail[type].OpenDir      = DirectionNone;
      detail[type].ActiveDir    = DirectionNone;
      detail[type].OpenBias     = OP_NO_ACTION;
      detail[type].ActiveBias   = OP_NO_ACTION;
      detail[type].IsValid      = false;
      detail[type].FractalDir   = DirectionNone;
      detail[type].Reversal     = false;
      detail[type].Alerts       = true;
    }

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete session[type];
      
    delete fractal;
    delete pfractal;
    delete sEvent;
    delete fEvent;
    delete pfEvent;
    delete toEvent;
  }