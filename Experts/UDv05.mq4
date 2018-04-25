//+------------------------------------------------------------------+
//|                                                        ud-v5.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\SessionArray.mqh>

input string EAHeader                = "";    //+---- Application Options -------+
input double inpDailyTarget          = 3.6;   // Daily target

input string fractalHeader           = "";    //+------ Fractal Options ---------+
input int    inpRangeMin             = 60;    // Minimum fractal pip range
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpPeriodsLT            = 240;   // Long term regression periods

input string RegressionHeader        = "";    //+------ Regression Options ------+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpSmoothFactor         = 3;     // MA Smoothing factor
input double inpTolerance            = 0.5;   // Directional sensitivity
input int    inpPipPeriods           = 200;   // Trade analysis periods (PipMA)
input int    inpRegrPeriods          = 24;    // Trend analysis periods (RegrMA)

input string SessionHeader           = "";    //+---- Session Hours -------+
input int    inpAsiaOpen             = 1;     // Asian market open hour
input int    inpAsiaClose            = 10;    // Asian market close hour
input int    inpEuropeOpen           = 8;     // Europe market open hour
input int    inpEuropeClose          = 18;    // Europe market close hour
input int    inpUSOpen               = 14;    // US market open hour
input int    inpUSClose              = 23;    // US market close hour

//--- Class defs
  CFractal           *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CSessionArray      *session[SessionTypes];
  
  //--- Operational collections
  string              udEventDisplay[];
  bool                udActiveEvent;
  CEvent             *udEvents               = new CEvent();
  
void AddEvents(SessionType Type)
  {
    if (session[Type].ActiveEvent())
    {
      ArrayResize(udEventDisplay,ArraySize(udEventDisplay)+2);
      udEventDisplay[ArraySize(udEventDisplay)-2]   = "\n  "
        + EnumToString(Type)+" ("
        + BoolToStr(session[Type].SessionIsOpen(),proper(ActionText(session[Type].TradeBias())),"Off-Session")+")";
      udEventDisplay[ArraySize(udEventDisplay)-1]   = "\n     Events\n";
     
      for (EventType type=0;type<EventTypes;type++)
        if (session[Type].Event(type))
        {
          ArrayResize(udEventDisplay,ArraySize(udEventDisplay)+1);
          udEventDisplay[ArraySize(udEventDisplay)-1]   = "         "+EnumToString(type)+"\n";
        }

      ArrayResize(udEventDisplay,ArraySize(udEventDisplay)+1);
      udEventDisplay[ArraySize(udEventDisplay)-1]   = "      Data\n";
      
      ArrayResize(udEventDisplay,ArraySize(udEventDisplay)+1);
      udEventDisplay[ArraySize(udEventDisplay)-1]   = "         OHLC: "
          +DoubleToStr(session[Type].Active().TermHigh,Digits)+":"
          +DoubleToStr(session[Type].Active().TermLow,Digits)+"\n";
     
      udActiveEvent    = true;
    }
  }

string DisplayEvents(void)
  {
    string deEvents  = "";
    
    for (int event=0;event<ArraySize(udEventDisplay);event++)
      deEvents   += udEventDisplay[event];
      
    return (deEvents);
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    //--- Clear the session data array
    ArrayResize(udEventDisplay,1);
    udEventDisplay[0]            = "Session Data";
    udActiveEvent                = false;
    
    //--- Load the session data array
    for (SessionType type=Asia; type<SessionTypes; type++)
    {
      AddEvents(type);
              
      UpdateLabel("lbSess"+EnumToString(type),EnumToString(type),BoolToInt(session[type].SessionIsOpen(),clrYellow,clrDarkGray));
      UpdateDirection("lbDir"+EnumToString(type),session[type].Direction(Term),DirColor(session[type].Direction(Term)));
      UpdatePriceLabel("lbPipMAPivot",pfractal.Pivot(Price));
      UpdateLabel("lbEquity","Low:"+DoubleToStr(LotValue(OP_NO_ACTION,Lowest),1)+"  High:"+DoubleToStr(LotValue(OP_NO_ACTION,Highest),1));
//      UpdateLabel("lbState"+EnumToString(rsId),SessionNow[rsId].State,rsSessionColor,8,"Symbol");
    }
    
Comment("");
    if (udActiveEvent)
    {
      Comment(DisplayEvents());
      
//      if (udEvents[NewBreakout] || udEvents[NewReversal] || udEvents[NewRally] || udEvents[NewPullback])
//      if (udEvents.ActiveEvent())
//      if (session[US].ActiveEvent())
      if (udEvents[SessionOpen])
        Pause("Event Validation","Event Check");
    }
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {    
    udEvents.ClearEvents();
    
    fractal.Update();
    pfractal.Update();

    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      session[type].Update();
      
      if (session[type].ActiveEvent())
        for (EventType event=0;event<EventTypes;event++)
          if (session[type].Event(event))
            udEvents.SetEvent(event);
    }
//      session[Daily].Update();
  }

//+------------------------------------------------------------------+
//| CalcOrderPlan - Computes order limits/direction                  |
//+------------------------------------------------------------------+
void CalcOrderPlan(void)
  {
//    if (session[Daily].Event(NewDay))
//      Pause("New Day - What's the game plan?","NewDay()");
//    if (session[Asia].Event(SessionOpen))
//      Pause ("What''s the plan?","Asia Session Open");
  }

//+------------------------------------------------------------------+
//| CalcOrderMargin - Computes open order margins for risk management|
//+------------------------------------------------------------------+
void CalcOrderMargin(void)
  {

  }

//+------------------------------------------------------------------+
//| Execute - Acts on events to execute trades                       |
//+------------------------------------------------------------------+
void Execute(void)
  {
    int eAction;
    
    CalcOrderMargin();
    CalcOrderPlan();
    
//    if (pfractal.Event(NewLow))
//      if (
          
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
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
        
    session[Daily]      = new CSessionArray(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]       = new CSessionArray(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]     = new CSessionArray(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]         = new CSessionArray(US,inpUSOpen,inpUSClose);
    
    NewLabel("lbSessAsia","Asia",30,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessEurope","Europe",30,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessUS","US",30,29,clrDarkGray,SCREEN_LR);
    
    NewLabel("lbDirAsia","",10,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbDirEurope","",10,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbDirUS","",10,29,clrDarkGray,SCREEN_LR);

    NewLabel("lbStateAsia","",5,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbStateEurope","",5,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbStateUS","",5,29,clrDarkGray,SCREEN_LR);

    NewLabel("lbAlert","",5,5,clrDarkGray,SCREEN_LR);

    NewPriceLabel("lbPipMAPivot");
    NewLabel("lbEquity","",5,5,clrWhite,SCREEN_LL);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }