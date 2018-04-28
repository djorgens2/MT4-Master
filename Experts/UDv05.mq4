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

//--- Display constants
enum DisplayConstants
{
  udDisplayEvents,      // Display setting for application comments
  udDisplayFractal,     // Display setting for fractal comments
  udDisplayPipMA        // Display setting for PipMA comments
};

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
  SessionType         udLeadSession;

  //--- Operational variables
  int                 udDisplay              = udDisplayEvents;
  
//+------------------------------------------------------------------+
//| AddEvents - Creates the text string to display events            |
//+------------------------------------------------------------------+
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
    }
  }

//+------------------------------------------------------------------+
//| DisplayEvents - Displays events and other session data           |
//+------------------------------------------------------------------+
void DisplayEvents(void)
  {
    string deEvents  = "";
    
    if (udDisplay == udDisplayEvents)
    {
      Comment("");

      for (int event=0;event<ArraySize(udEventDisplay);event++)
        deEvents   += udEventDisplay[event];
      
      if (udActiveEvent)
        Comment(deEvents);
    }
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
      UpdateLabel("lbState"+EnumToString(type),proper(DirText(session[type].Direction(Trend)))+" "+EnumToString(session[type].State()));

      UpdatePriceLabel("lbPipMAPivot",pfractal.Pivot(Price));
      UpdateLabel("lbEquity","Low:"+DoubleToStr(LotValue(OP_NO_ACTION,Lowest),1)+"  High:"+DoubleToStr(LotValue(OP_NO_ACTION,Highest),1));

      if (session[type].Event(SessionOpen))
        UpdateLabel("lbTradeBias",proper(ActionText(session[type].TradeBias())),clrWhite,12);
    }

    switch(udDisplay)
    {
      case udDisplayEvents:   DisplayEvents();
                              break;
      case udDisplayFractal:  fractal.RefreshScreen();
                              break;
      case udDisplayPipMA:    pfractal.RefreshScreen();
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
      {
        udActiveEvent    = true;

        for (EventType event=0;event<EventTypes;event++)
          if (session[type].Event(event))
            udEvents.SetEvent(event);
      }
            
      if (type<Daily)
        if (session[type].Event(SessionOpen))
          udLeadSession    = type;
    }
  }

//+------------------------------------------------------------------+
//| CalcOrderPlan - Computes order limits/direction                  |
//+------------------------------------------------------------------+
void CalcOrderPlan(void)
  {
    static ReservedWords dailystate = NoState;
    int    copFractalDir            = fractal.Direction(Expansion);
    
//    if (session[Daily].Event(NewDay))
//      Pause("New Day - What's the game plan?","NewDay()");
      
    if (session[Daily].Event(SessionOpen))
      Pause("New Daily Open - What's the game plan?","NewDay()");
      
    if (session[Daily].State()!=dailystate)
    {
//      Pause("Daily State Change","State() Check");
      dailystate = session[Daily].State();
    }

//    if (session[udLeadSession].Event(SessionOpen))
//      Pause ("What''s the plan?",EnumToString(udLeadSession)+" Session Open");
  }

//+------------------------------------------------------------------+
//| ExecuteTrades - Opens new trades based on the pipMA trigger      |
//+------------------------------------------------------------------+
void ExecuteTrades(void)
  {
//    Pause("New trade?","Trade Execution");
  }

//+------------------------------------------------------------------+
//| Execute - Acts on events to execute trades                       |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int eAction    = OP_NO_ACTION;
    
    CalcOrderPlan();
    
    if (pfractal.Event(NewLow))
      eAction    = OP_BUY;
    else
    if (pfractal.Event(NewHigh))
      eAction    = OP_SELL;
    else
    if (eAction>OP_NO_ACTION)
    {
      ExecuteTrades();
      eAction    = OP_NO_ACTION;
    }
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="SHOW")
    {
      if (Command[1]=="FRACTAL") udDisplay=udDisplayFractal;
      if (Command[1]=="FIBO")    udDisplay=udDisplayFractal;
      if (Command[1]=="FIB")     udDisplay=udDisplayFractal;
      if (Command[1]=="PIPMA")   udDisplay=udDisplayPipMA;
      if (Command[1]=="PIP")     udDisplay=udDisplayPipMA;
      if (Command[1]=="EVENTS")  udDisplay=udDisplayEvents;
      if (Command[1]=="EVENT")   udDisplay=udDisplayEvents;
      if (Command[1]=="EV")      udDisplay=udDisplayEvents;
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
        
    session[Daily]      = new CSessionArray(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]       = new CSessionArray(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]     = new CSessionArray(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]         = new CSessionArray(US,inpUSOpen,inpUSClose);
    
    NewLabel("lbSessDaily","Daily",105,62,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessAsia","Asia",105,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessEurope","Europe",105,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessUS","US",105,29,clrDarkGray,SCREEN_LR);
    
    NewLabel("lbDirDaily","",85,62,clrDarkGray,SCREEN_LR);
    NewLabel("lbDirAsia","",85,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbDirEurope","",85,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbDirUS","",85,29,clrDarkGray,SCREEN_LR);

    NewLabel("lbStateDaily","",5,62,clrDarkGray,SCREEN_LR);
    NewLabel("lbStateAsia","",5,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbStateEurope","",5,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbStateUS","",5,29,clrDarkGray,SCREEN_LR);

    NewLabel("lbTradeBias","",5,18,clrDarkGray,SCREEN_LR);
    
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
    delete udEvents;
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }