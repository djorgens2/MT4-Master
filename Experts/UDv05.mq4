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
input int    inpNewDay               = 0;     // New day market open hour
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
  string              udEvents[];
  bool                udActiveEvent;
  
  //--- Operational variables
  int                 udPlan                 = OP_NO_ACTION;

void ClearSessionInfo(void)
  {
    ArrayResize(udEvents,1);
    udEvents[0]                  = "Session Data";
    udActiveEvent                = false;
  }

void AddEvents(SessionType Type)
  {
    if (session[Type].ActiveEvent())
    {
      ArrayResize(udEvents,ArraySize(udEvents)+2);
      udEvents[ArraySize(udEvents)-2]   = "\n  "+EnumToString(Type)+BoolToStr(session[Type].SessionIsOpen(),""," (Off-Session)");
      udEvents[ArraySize(udEvents)-1]   = "\n     Events\n";
     
      for (EventType type=0;type<EventTypes;type++)
        if (session[Type].Event(type))
        {
          ArrayResize(udEvents,ArraySize(udEvents)+1);
          udEvents[ArraySize(udEvents)-1]   = "         "+EnumToString(type)+"\n";
        }

      ArrayResize(udEvents,ArraySize(udEvents)+1);
      udEvents[ArraySize(udEvents)-1]   = "      Data\n";
      
      ArrayResize(udEvents,ArraySize(udEvents)+1);
      udEvents[ArraySize(udEvents)-1]   = "         OHLC: "
          +DoubleToStr(session[Type].Active().Open,Digits)+":"
          +DoubleToStr(session[Type].Active().High,Digits)+":"
          +DoubleToStr(session[Type].Active().Low,Digits)+":"
          +BoolToStr(IsEqual(session[Type].Active().Close,NoValue),"Pending",DoubleToStr(session[Type].Active().Close,Digits))+"\n";
     
      udActiveEvent    = true;
    }
  }

string DisplayEvents(void)
  {
    string deEvents  = "";
    
    for (int event=0;event<ArraySize(udEvents);event++)
      deEvents   += udEvents[event];
      
    return (deEvents);
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    ClearSessionInfo();
    
    for (SessionType type=Asia; type<SessionTypes; type++)
    {
      AddEvents(type);
              
      UpdateLabel("lbSess"+EnumToString(type),EnumToString(type),BoolToInt(session[type].SessionIsOpen(),clrYellow,clrDarkGray));
      UpdateDirection("lbDir"+EnumToString(type),session[type].Direction(Term),DirColor(session[type].Direction(Term)));
      UpdatePriceLabel("lblPipMAPivot",pfractal.Pivot(Price));
      UpdateLabel("lblPlan",ActionText(udPlan)+" ("+ActionText(Action(pfractal.Direction(Pivot)))+")");
      UpdateLabel("lblEquity","Low:"+DoubleToStr(LotValue(OP_NO_ACTION,Lowest),1)+"  High:"+DoubleToStr(LotValue(OP_NO_ACTION,Highest),1));
//      UpdateLabel("lbState"+EnumToString(rsId),SessionNow[rsId].State,rsSessionColor,8,"Symbol");
    }
    
//    if (udActiveEvent)
      Comment(DisplayEvents());
      //Pause(DisplayEvents(),"Event() Issue");
//    if (session[T.Event(NewHigh))
//      UpdateLabel("lbAlert","New High",clrLawnGreen,14);
//    else
//    if (session.Event(NewLow)))
//      UpdateLabel("lbAlert","New Low",clrRed,14);
//    else
//      UpdateLabel("lbAlert","",clrBlack,14);
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    static int    gdPivotDir   = DirectionNone;
    static double gdPivotPrice = 0.00;
    
    fractal.Update();
    pfractal.Update();

    for (SessionType type=Asia;type<SessionTypes;type++)
      session[type].Update();
  }

//+------------------------------------------------------------------+
//| CalcDailyPlan                                                    |
//+------------------------------------------------------------------+
void CalcDailyPlan(void)
  {
    Pause("New Day - What's the game plan?","NewDay()");
    
  }

//+------------------------------------------------------------------+
//| CalcDailyPlan                                                    |
//+------------------------------------------------------------------+
void ManageTrades(void)
  {
    if (LotCount()==0)
    {
      if (udPlan==Action(pfractal.Direction(Pivot)))
        OpenOrder(udPlan,"Opening Trade");
    }
  }

//+------------------------------------------------------------------+
//| Execute - Acts on events to execute trades                       |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (session[Daily].Event(NewDay))
      CalcDailyPlan();
          
    if (pfractal.Event(NewPivot))
      Pause("We have a new pipMA Pivot","NewPivot()");
    
    if (pfractal.Event(NewPivotDirection))
    {
      Pause("We have a new pipMA Pivot Direction","NewPivot()");
      ManageTrades();
    }

  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PLAN")
    {
      udPlan       = ActionCode(Command[1]);
//      UpdateLabel("lblPlan",ActionText(udPlan)+" ... "+pfractal.Pivot(Direction)); //" ("+ActionText(Action(pfractal.Pivot(Direction)))+")");
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
        
    session[Daily]      = new CSessionArray(Daily);
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

    NewPriceLabel("lblPipMAPivot");
    NewLabel("lblPlan","",5,16,clrWhite,SCREEN_LL);
    NewLabel("lblEquity","",5,5,clrWhite,SCREEN_LL);
    
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