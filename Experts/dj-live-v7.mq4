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
  CEvent             *toEvent        = new CEvent();


  //--- Recommendation Alerts
  enum                AnalystAlert
                      {
                        Papa161,         //-- Major reversal point approaching at the bre 161
                        Papa50,          //-- Major reversal point approaching at the bre 50
                        PapaReversal,    //-- Major reversal pattern confirmed on divergence
                        EarlyFractal,    //-- May result in reversal; occurs on an early daily session fractal
                        SlantReversal,   //-- High probability of reversal; occurs between the 9th and 10th hour
                        YanksReversal,   //-- High probability of reversal; occurs between the 14th (Yanks) and 15th hour
                        Shsnanigans,     //-- Excessive volatility leading to a late session breakout or reversal; occurs 16th or 17th hour on a bounds extremity
                        MidEasternYaw,   //-- High probabilty of short term correction; occurs after a daily outer extremity rolls the Asian bellwether midpoint
                        ScissorKick,     //-- Excessive volatility where price tests of both daily outer extremities and comes to rest at the session midpoint
                        PoundKick,       //-- Excessive volatility where price fluctuates rapidly (anti-trend) then resumes the greater trend. Occurs early europe
                        SnapReversal,    //-- Reversal during an oscillatory state; typically indicates a long term term trend change;
                        AsianClose,      //-- Price direction change intraday; when the Asian session is about to close on an extremity;
                        RogueWave,       //-- Extreme reversal generally near a Fibonacci 50
                        HatsOff,         //-- High probability of reversal; occurs near a Fibonacci 161
                        Riptide,         //-- Excessive volatility on the interior wave lines; hold on and follow the trend
                        TidalWave        //-- Non-volatile steady wave growth lasting several hours or days;
                      };
                      
  //--- Order Statuses
  enum                OrderState
                      {
                        Waiting,
                        Pending,
                        Requested,
                        Approved,
                        Rejected,
                        Fulfilled,
                        OrderStates
                      };
                      
  //--- Strategies
  enum                StrategyType
                      {
                        Stop,
                        Scalp,
                        Spot,
                        FFE,
                        StrategyTypes
                      };
                       
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

  struct              OrderManagerRec
                      {
                        StrategyType    Strategy;
                        ActionState     Plan;
                        OrderState      OrderStatus;
                        EventType       OrderEvent;
                        int             OrderCount;
                        double          LotCount;
                        double          NetMargin;
                        double          EQProfit;
                        double          EQLoss;
                        double          ClosedProfit;
                        double          ClosedLoss;
                      };

  //--- Display operationals
  string              rsShow              = "APP";
  int                 rsAction            = OP_BUY;  
  bool                PauseOn             = true;
  int                 PauseOnHour         = NoValue;
  bool                LoggingOn           = false;
  bool                TradingOn           = true;
  bool                Alerts[EventTypes];
  
  //--- Session operationals
  SessionDetail       detail[SessionTypes];
  SessionDetail       history[SessionTypes];
  
  //--- Trade operationals
  int                 SessionHour;
  
  OrderManagerRec     om[2];
   
  

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
//| RefreshControlPanel - Repaints the control panel display area    |
//+------------------------------------------------------------------+
void RefreshControlPanel(void)
  {
    if (sEvent.EventAlert(NewReversal,Warning))
      UpdateDirection("lbState",OrderBias(),clrYellow,24);
    else
      UpdateDirection("lbState",OrderBias(),DirColor(OrderBias()),24);
      
    UpdateLabel("lbh-1D","Long",BoolToInt(pfractal.ActiveWave().Type==Crest,clrLawnGreen,clrWhite));
    UpdateLabel("lbh-1E","Short",BoolToInt(pfractal.ActiveWave().Type==Trough,clrRed,clrWhite));
    UpdateLabel("lbh-1F","Crest",BoolToInt(pfractal.ActiveSegment().Type==Crest,clrLawnGreen,BoolToInt(pfractal.WaveSegment(Crest).IsOpen,clrYellow,clrWhite)));
    UpdateLabel("lbh-1G","Trough",BoolToInt(pfractal.ActiveSegment().Type==Trough,clrRed,BoolToInt(pfractal.WaveSegment(Trough).IsOpen,clrYellow,clrWhite)));
    UpdateLabel("lbh-1H","Decay",BoolToInt(pfractal.WaveSegment(Decay).IsOpen,BoolToInt(pfractal.WaveSegment(Last).Type==Crest,clrLawnGreen,clrRed),clrWhite));

    UpdateLabel("lbLastSegment",EnumToString(pfractal.WaveSegment(Last).Type),clrDarkGray);
    UpdateLabel("lbWaveState",EnumToString(pfractal.ActiveWave().Type)+" "
                      +BoolToStr(pfractal.ActiveSegment().Type==Decay,"Decay ")
                      +EnumToString(pfractal.WaveState()),DirColor(pfractal.ActiveWave().Direction));
                      
    UpdateLabel("lbLongState",EnumToString(pfractal.ActionState(OP_BUY)),DirColor(pfractal.ActiveSegment().Direction));
    UpdateLabel("lbLongOrder",BoolToStr(om[OP_BUY].OrderStatus==Waiting,"Waiting","Order "+EnumToString(om[OP_BUY].OrderStatus)+
                       " on "+EnumToString(om[OP_BUY].OrderEvent)),
                       BoolToInt(om[OP_BUY].OrderStatus==Waiting,clrDarkGray,clrYellow));
                       
    UpdateLabel("lbShortState",EnumToString(pfractal.ActionState(OP_SELL)),DirColor(pfractal.ActiveSegment().Direction));
    UpdateLabel("lbShortOrder",BoolToStr(om[OP_SELL].OrderStatus==Waiting,"Waiting","Order "+EnumToString(om[OP_SELL].OrderStatus)+
                       " on "+EnumToString(om[OP_SELL].OrderEvent)),
                       BoolToInt(om[OP_SELL].OrderStatus==Waiting,clrDarkGray,clrYellow));
    
    UpdateLabel("lbLongPlan",EnumToString(om[OP_BUY].Strategy)+":"+EnumToString(om[OP_BUY].Plan),clrDarkGray);
    UpdateLabel("lbShortPlan",EnumToString(om[OP_SELL].Strategy)+":"+EnumToString(om[OP_SELL].Plan),clrDarkGray);
    
    UpdateLabel("lbRetrace","Retrace",BoolToInt(pfractal.Wave().Retrace,clrYellow,clrDarkGray));
    UpdateLabel("lbBreakout","Breakout",BoolToInt(pfractal.Wave().Breakout,clrYellow,clrDarkGray));
    UpdateLabel("lbReversal","Reversal",BoolToInt(pfractal.Wave().Reversal,clrYellow,clrDarkGray));
    
    UpdateLabel("lbLongCount",(string)pfractal.WaveSegment(OP_BUY).Count,clrDarkGray);
    UpdateLabel("lbShortCount",(string)pfractal.WaveSegment(OP_SELL).Count,clrDarkGray);
    UpdateLabel("lbCrestCount",(string)pfractal.WaveSegment(Crest).Count+":"+(string)pfractal.Wave().CrestTotal,clrDarkGray);
    UpdateLabel("lbTroughCount",(string)pfractal.WaveSegment(Trough).Count+":"+(string)pfractal.Wave().TroughTotal,clrDarkGray);
    UpdateLabel("lbDecayCount",(string)pfractal.WaveSegment(Decay).Count,clrDarkGray);    

    UpdateLabel("lbCrestOpen",DoubleToStr(pfractal.WaveSegment(Crest).Open,Digits),Color(pfractal.WaveSegment(Crest).Open,IN_PROXIMITY));
    UpdateLabel("lbTroughOpen",DoubleToStr(pfractal.WaveSegment(Trough).Open,Digits),Color(pfractal.WaveSegment(Trough).Open,IN_PROXIMITY));
    UpdateLabel("lbDecayOpen",DoubleToStr(pfractal.WaveSegment(Decay).Open,Digits),Color(pfractal.WaveSegment(Decay).Open,IN_PROXIMITY));

    UpdateLabel("lbCrestHigh",DoubleToStr(pfractal.WaveSegment(Crest).High,Digits),Color(pfractal.WaveSegment(Crest).High,IN_PROXIMITY));
    UpdateLabel("lbTroughHigh",DoubleToStr(pfractal.WaveSegment(Trough).High,Digits),Color(pfractal.WaveSegment(Trough).High,IN_PROXIMITY));
    UpdateLabel("lbDecayHigh",DoubleToStr(pfractal.WaveSegment(Decay).High,Digits),Color(pfractal.WaveSegment(Decay).High,IN_PROXIMITY));

    UpdateLabel("lbCrestLow",DoubleToStr(pfractal.WaveSegment(Crest).Low,Digits),Color(pfractal.WaveSegment(Crest).Low,IN_PROXIMITY));
    UpdateLabel("lbTroughLow",DoubleToStr(pfractal.WaveSegment(Trough).Low,Digits),Color(pfractal.WaveSegment(Trough).Low,IN_PROXIMITY));
    UpdateLabel("lbDecayLow",DoubleToStr(pfractal.WaveSegment(Decay).Low,Digits),Color(pfractal.WaveSegment(Decay).Low,IN_PROXIMITY));

    UpdateLabel("lbCrestClose",DoubleToStr(pfractal.WaveSegment(Crest).Close,Digits),Color(fdiv(pfractal.WaveSegment(Crest).Low+pfractal.WaveSegment(Crest).Retrace,2),IN_PROXIMITY));
    UpdateLabel("lbTroughClose",DoubleToStr(pfractal.WaveSegment(Trough).Close,Digits),Color(fdiv(pfractal.WaveSegment(Trough).Low+pfractal.WaveSegment(Trough).Retrace,2),IN_PROXIMITY));
    UpdateLabel("lbDecayClose",DoubleToStr(pfractal.WaveSegment(Decay).Close,Digits),Color(fdiv(pfractal.WaveSegment(Decay).Low+pfractal.WaveSegment(Decay).Retrace,2),IN_PROXIMITY));

    UpdateLabel("lbCrestRetrace",DoubleToStr(pfractal.WaveSegment(Crest).Retrace,Digits),Color(fdiv(pfractal.WaveSegment(Crest).Low+pfractal.WaveSegment(Crest).Retrace,2),IN_PROXIMITY));
    UpdateLabel("lbTroughRetrace",DoubleToStr(pfractal.WaveSegment(Trough).Retrace,Digits),Color(fdiv(pfractal.WaveSegment(Crest).Low+pfractal.WaveSegment(Crest).Retrace,2),IN_PROXIMITY));
    UpdateLabel("lbDecayRetrace",DoubleToStr(pfractal.WaveSegment(Decay).Retrace,Digits),Color(fdiv(pfractal.WaveSegment(Crest).Low+pfractal.WaveSegment(Crest).Retrace,2),IN_PROXIMITY));

    UpdateLabel("lbCrestNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Crest).Retrace-pfractal.WaveSegment(Crest).High),1),clrRed);
    UpdateLabel("lbTroughNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Trough).Low-pfractal.WaveSegment(Trough).Retrace),1),clrLawnGreen);    

    if (pfractal.WaveSegment(Last).Type==Crest)
      UpdateLabel("lbDecayNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Decay).Retrace-pfractal.WaveSegment(Decay).High),1),clrRed);

    if (pfractal.WaveSegment(Last).Type==Trough)
      UpdateLabel("lbDecayNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Decay).Low-pfractal.WaveSegment(Decay).Retrace),1),clrLawnGreen);
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "";
    string rsEvent     = "";
        
    for (SessionType type=Daily;type<SessionTypes;type++)
        rsComment       += BoolToStr(lead.Type()==type,"-->")+EnumToString(type)
                           +BoolToStr(session[type].IsOpen()," ("+IntegerToString(session[type].SessionHour())+")"," Closed")
                           +"\n  Direction (Open/Active): "+DirText(detail[type].OpenDir)+"/"+DirText(detail[type].ActiveDir)
                           +"\n  Bias (Open/Active): "+ActionText(detail[type].OpenBias)+"/"+ActionText(detail[type].ActiveBias)
                           +"\n  State: "+BoolToStr(detail[type].IsValid,"OK","Invalid")
                           +"  "+BoolToStr(detail[type].Reversal,"Reversal",BoolToStr(detail[type].FractalDir==DirectionNone,"",DirText(detail[type].FractalDir)))
                           +"\n\n";

    if (pfractal.Wave().Action==rsAction)
    {
      UpdateLine("lnRecovery",0.00,STYLE_DOT,clrLawnGreen);
      UpdateLine("lnMercy",0.00,STYLE_DOT,clrSteelBlue);
      UpdateLine("lnOpportunity",0.00,STYLE_SOLID,clrSteelBlue);
      UpdateLine("lnKill",0.00,STYLE_DOT,clrOrangeRed);

      UpdateLine("lnProfit",pfractal.ActionLine(rsAction).Profit,STYLE_DOT,clrLawnGreen);
      UpdateLine("lnClose",pfractal.ActionLine(rsAction).Close,STYLE_DASH,clrSteelBlue);
      UpdateLine("lnRisk",pfractal.ActionLine(rsAction).Risk,STYLE_DOT,clrOrangeRed);
      UpdateLine("lnBuild",pfractal.ActionLine(rsAction).Build,STYLE_DASH,clrLawnGreen);
      UpdateLine("lnGo",pfractal.ActionLine(rsAction).Go,STYLE_SOLID,clrYellow);
      UpdateLine("lnDoom",pfractal.ActionLine(rsAction).Doom,STYLE_SOLID,clrOrangeRed);
    }
    else
    {
      UpdateLine("lnProfit",0.00,STYLE_DOT,clrLawnGreen);
      UpdateLine("lnClose",0.00,STYLE_DASH,clrSteelBlue);
      UpdateLine("lnBuild",0.00,STYLE_DASH,clrLawnGreen);

      UpdateLine("lnRisk",pfractal.ActionLine(rsAction).Risk,STYLE_DOT,clrOrangeRed);
      UpdateLine("lnGo",pfractal.ActionLine(rsAction).Go,STYLE_SOLID,clrYellow);
      UpdateLine("lnDoom",pfractal.ActionLine(rsAction).Doom,STYLE_SOLID,clrOrangeRed);
      UpdateLine("lnRecovery",pfractal.ActionLine(rsAction).Recovery,STYLE_DOT,clrLawnGreen);
      UpdateLine("lnMercy",pfractal.ActionLine(rsAction).Mercy,STYLE_DOT,clrSteelBlue);      
      UpdateLine("lnOpportunity",pfractal.ActionLine(rsAction).Opportunity,STYLE_SOLID,clrSteelBlue);
      UpdateLine("lnKill",pfractal.ActionLine(rsAction).Kill,STYLE_DASH,clrOrangeRed);
    }

    pfractal.ActionState(OP_SELL);
    pfractal.ActionState(OP_BUY);

    sEvent.ClearEvents();
    
    for (EventType type=1;type<EventTypes;type++)
      if (Alerts[type]&&pfractal.Event(type))
      {
        rsEvent   = "PipMA "+pfractal.ActiveEventText()+"\n";
        break;
      }

    for (EventType type=1;type<EventTypes;type++)
      if (Alerts[type]&&fractal.Event(type))
      {
        rsEvent   = "Fractal "+fractal.ActiveEventText()+"\n";
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
      Append(rsEvent,"Processed "+sEvent.ActiveEventText(true)+"\n","\n");
    
      for (SessionType show=Daily;show<SessionTypes;show++)
        Append(rsEvent,EnumToString(show)+" ("+BoolToStr(session[show].IsOpen(),
           "Open:"+IntegerToString(session[show].SessionHour()),
           "Closed")+")"+session[show].ActiveEventText(false)+"\n","\n");
    }

    if (StringLen(rsEvent)>0)
      if (rsShow=="ALERTS")
        Comment(rsEvent);
      else
        CallPause(rsEvent,Always);

    if (rsShow=="FRACTAL")
      fractal.RefreshScreen();
    else
    if (rsShow=="PIPMA")
    {
      if (pfractal.HistoryLoaded())
        pfractal.RefreshScreen();
    }
    else
    if (rsShow=="DAILY")
      session[Daily].RefreshScreen();
    else
    if (rsShow=="LEAD")
      lead.RefreshScreen();
    else
    if (rsShow=="ASIA")
      session[Asia].RefreshScreen();
    else
    if (rsShow=="EUROPE")
      session[Europe].RefreshScreen();
    else
    if (rsShow=="US")
      session[US].RefreshScreen();
    else
    if (rsShow=="APP")
      Comment(rsComment);

    RefreshControlPanel();
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
      if (session[type].Event(NewFractal))
      {
        detail[type].NewFractal       = true;

        if (type==Daily)
          sEvent.SetEvent(NewFractal,Major);
        else
          sEvent.SetEvent(NewFractal,Minor);
      }

      if (session[type].Event(NewOriginState))
        sEvent.SetEvent(NewOriginState,session[type].AlertLevel(NewOriginState));

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
        if (IsLower(Close[0],crest[0],NoUpdate))
          ObjectSet("lnCrestOC"+IntegerToString(crestidx-carry),OBJPROP_COLOR,clrMaroon);
        else
          ObjectSet("lnCrestOC"+IntegerToString(crestidx-carry),OBJPROP_COLOR,clrForestGreen);

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
    static int    cpBarIndex   = 0;

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
                             
      case NewAction:      if (pfractal.Event(NewAction))
                           {
//                             if (pfractal.ActionState(OP_BUY)==Opportunity)
//                               Flag("Long-Oppty:",clrYellow);
//                             if (pfractal.ActionState(OP_SELL)==Opportunity)
//                               Flag("Short-Oppty:",clrRed);
                           }
      case NewFibonacci:
      case NewHigh:
      case NewLow:
      case NewPoly:
      case NewPolyBoundary:
      case NewPolyTrend:
      case NewPolyState:    if (pfractal.Event(pf)) sEvent.SetEvent(pf);
                            break;
    }
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
       sEvent.SetEvent(NewReversal,Warning);    
  
    if (sEvent.EventAlert(NewReversal,Warning))
      return(Direction(lead[ActiveSession].Direction,InDirection,Contrarian));

    return (lead[ActiveSession].Direction);
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
//| SetStrategy - Configures the order manager trading strategy      |
//+------------------------------------------------------------------+
void SetStrategy(const int Action, StrategyType Strategy, ActionState Plan)
  {
    om[Action].Strategy         = Strategy;
    om[Action].Plan             = Plan;
  }

//+------------------------------------------------------------------+
//| SetOrderStatus - updates session detail on a new order event     |
//+------------------------------------------------------------------+
void SetOrderStatus(int Action, OrderState OrderStatus, EventType Event=NoEvent)
  {
    switch (OrderStatus)
    {
      case Waiting:    om[Action].OrderStatus         = Waiting;
                       om[Action].OrderEvent          = NoEvent;
                       break;
    
      case Pending:    om[Action].OrderStatus         = OrderStatus;
                       om[Action].OrderEvent          = Event;
                       break;

      case Requested:  if (om[Action].OrderStatus==Pending)
                         om[Action].OrderStatus       = Requested;
                       break;

      case Approved:   if (om[Action].OrderStatus==Requested)
                         om[Action].OrderStatus       = Approved;
                       break;

      case Rejected:   om[Action].OrderStatus         = Rejected;
                       break;
                       
      case Fulfilled:     
                       break;
    }
  }

//+------------------------------------------------------------------+
//| OrderApproved - Performs health and sanity checks for approval   |
//+------------------------------------------------------------------+
bool OrderApproved(int Action)
  {
    if (TradingOn)
    {
      SetOrderStatus(Action,Approved);
      return (true);
    }
    return (false);
  }

//+------------------------------------------------------------------+
//| OrderProcessed - Executes orders from the order manager          |
//+------------------------------------------------------------------+
bool OrderProcessed(int Action)
  {
    if (OpenOrder(Action,EnumToString(om[Action].Strategy)+":"+EnumToString(om[Action].Plan)+"("+EnumToString(om[Action].OrderEvent)+")"))
    {
      SetOrderStatus(Action,Fulfilled);
      return (true);
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| OrderStatus - Returns the order status for the supplied action   |
//+------------------------------------------------------------------+
OrderState OrderStatus(const int Action)
  {
    return (om[Action].OrderStatus);
  }

//+------------------------------------------------------------------+
//| Scalper - Contrarian Model Short Term by Action                  |
//+------------------------------------------------------------------+
void Scalper(const int Action)
  {
    switch (Action)
    {
      case OP_SELL:   if (OrderStatus(OP_SELL)==Waiting)
                        if (sEvent[NewCrest])
                          SetOrderStatus(OP_SELL,Pending,NewCrest);

                      if (OrderStatus(OP_SELL)==Pending)
                        if (pfractal.ActiveSegment().Direction==DirectionDown)
                          SetOrderStatus(OP_SELL,Requested);
    }
  }

//+------------------------------------------------------------------+
//| ShortManagement - Manages short order positions, profit and risk |
//+------------------------------------------------------------------+
void ShortManagement(void)
  {
    SetStrategy(OP_SELL,Scalp,Build);
  }

//+------------------------------------------------------------------+
//| OrderManagement - Manages the order cycle                        |
//+------------------------------------------------------------------+
void OrderManagement(void)
  {
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      switch (om[action].Strategy)
      {
        case Scalp:  Scalper(action);
                     break;
      }
      
      if (om[action].OrderStatus==Requested)
        if (OrderApproved(action))
          if (OrderProcessed(action))
            SetOrderStatus(action,Waiting);
          else
            SetOrderStatus(action,Rejected);
    }
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    CheckSessionEvents();
    CheckPipMAEvents();

    if (PauseOnHour>NoValue)
      if (sEvent[NewHour])
        if (ServerHour()==PauseOnHour)
          CallPause("Pause requested on Server Hour "+IntegerToString(PauseOnHour),Always);
      

    AnalyzeData();
    
    ShortManagement();
    OrderManagement();
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
      if (Command[1]=="LINES")
      {
        if (Command[2]=="BUY"||Command[2]=="LONG")
          rsAction                     = OP_BUY;
        else
        if (Command[2]=="SELL"||Command[2]=="SHORT")
          rsAction                     = OP_SELL;
       }
     else
       rsShow                          = Command[1];

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
      if (AlertKey(Command[1])==EventTypes)
        Command[1]                    += " is invalid and not ";
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
      if (AlertKey(Command[1])==EventTypes)
        Command[1]                    += " is invalid and not ";
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
 
    NewLine("lnProfit");
    NewLine("lnDoom");
    NewLine("lnClose");
    NewLine("lnRisk");
    NewLine("lnBuild");
    NewLine("lnGo");
    NewLine("lnRecovery");
    NewLine("lnMercy");
    NewLine("lnOpportunity");
    NewLine("lnKill");

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

    //--- Initialize Order Management
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      om[action].Strategy       = Stop;
      om[action].Plan           = Halt;
      om[action].OrderStatus    = Waiting;
      om[action].OrderCount     = 0;
      om[action].LotCount       = 0.00;
      om[action].NetMargin      = 0.00;
      om[action].EQProfit       = 0.00;
      om[action].EQLoss         = 0.00;
      om[action].ClosedProfit   = 0.00;
      om[action].ClosedLoss     = 0.00;
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
    delete toEvent;
  }