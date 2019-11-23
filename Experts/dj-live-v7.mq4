//+------------------------------------------------------------------+
//|                                                   dj-live-v7.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "7.00"
#property strict

#define   Always         true
#define   clrBoxOff      C'60,60,60'
#define   clrBoxRedOff   C'42,0,0'
#define   clrBoxGreenOff C'0,42,0'

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

  //--- Fractal Sources
  enum                ViewPoint
                      {
                        Macro,
                        Meso,
                        Micro,
                        ViewPoints
                      };
                      
  enum                FractalPoint
                      {
                        fpTarget,
                        fpYield,
                        fpLoad,
                        fpBounce,
                        fpRisk,
                        fpHalt,
                        FractalPoints
                      };

  //--- Recommendation Alerts
  enum                AnalystAlert
                      {
                        Papa161,         //-- Major reversal point approaching at the bre 161
                        Papa50,          //-- Major reversal point approaching at the bre 50
                        RiceTerrace,     //-- Major long term trend indicator identified by a series of continuation breakouts without reversal
                        PapaReversal,    //-- Major reversal pattern confirmed on divergence
                        CheckReversal,   //-- Major reversal pattern confirmed on a junior 261 check rally
                        EarlyFractal,    //-- May result in reversal; occurs on an early daily session fractal
                        SlantReversal,   //-- High probability of reversal; occurs between the 9th and 10th hour
                        YanksReversal,   //-- High probability of reversal; occurs between the 14th (Yanks) and 15th hour
                        Shananigans,     //-- Excessive volatility leading to a late session breakout or reversal; occurs 16th or 17th hour on a bounds extremity
                        AsianMidPitch,   //-- High probabilty of short term correction; occurs after a daily outer extremity rolls the Asian bellwether midpoint
                        ScissorKick,     //-- Excessive volatility where price tests of both daily outer extremities and comes to rest at the session midpoint
                        PoundKick,       //-- Excessive volatility where price fluctuates rapidly (anti-trend) then resumes the greater trend. Occurs early europe
                        SnapReversal,    //-- Reversal during an oscillatory state; typically indicates a long term term trend change;
                        AsianClose,      //-- Price direction change intraday; when the Asian session is about to close on an extremity;
                        RogueWave,       //-- Extreme reversal generally near a Fibonacci 50
                        TopHat,          //-- High probability of reversal; occurs near a Fibonacci 161
                        Riptide,         //-- Excessive volatility on the interior wave lines; hold on and follow the trend
                        TidalWave,       //-- Non-volatile steady wave growth lasting several hours or days;
                        MercyBounce,     //-- Recovering 50% fibo
                        SecondChance,    //-- Better than a mercy bounce; indicates the strong probability of reversal
                        AnalystAlerts
                      };
                      
  enum                SourceType
                      {
                        NoSource,
                        indFractal,
                        indPipMA,
                        indSession,
                        SourceTypes
                      };
  //--- Strategies
  enum                StrategyType
                      {
                        Load,
                        Spot,
                        FFE,
                        Capture,
                        Deposit,
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
                        bool           IsValid;
                        bool           Alerts;
                      };

  struct              ActionRequest
                      {
                        double          Price;
                        double          Lots;                      
                      };
                      
  struct              OrderManagerRec
                      {
                        ActionState     Plan;
                        ActionRequest   ShortAction[StrategyTypes];
                        ActionRequest   LongAction[StrategyTypes];
                        int             OrderTotal;
                        double          LotsTotal;
                        double          NetMargin;
                        double          EQProfit;
                        double          EQLoss;
                        double          EQNet;
                      };
                      
  struct              FractalAnalysis
                      {
                        SourceType      Source;                //--- the source of fibo data
                        int             Direction;             //--- the direction indicated by the source
                        int             BreakoutDir;           //--- the last breakout direction; contrary indicates reversing pattern
                        ReservedWords   State;                 //--- the state of the fractal provided by the source
                        FibonacciLevel  FiboLevel;             //--- the now expansion fibo level
                        int             FiboNetChange;         //--- the net change in a declining fibo pattern
                        bool            FiboChanged;           //--- indicates a fibo drop; prompts review of targets and risk
                        double          FiboRetrace;           //--- now retrace fibo reported by source
                        double          FiboExpansion;         //--- now expansion fibo reported by source
                        double          TargetStart;           //--- the price at which the source stated a target
                        double          MaxProximityToTarget;  //--- the max price nearest to the target; a positive value indicates target hit
                        RetraceType     Leg;                   //--- the papa fractal leg
                        bool            Peg;                   //--- peg occurs at expansion fibo50
                        bool            Risk;                  //--- risk occurs on risk mit
                        bool            Corrected;             //--- Correction occurs on correction mit
                        bool            Trap;                  //--- when a Meso breakout occurs
                      };

  const int SegmentType[5]   = {OP_BUY,OP_SELL,Crest,Trough,Decay};

  //--- Display operationals
  string              rsShow              = "APP";
  int                 rsAction            = OP_BUY;
  int                 rsSegment           = NoValue;
  bool                PauseOn             = true;
  int                 PauseOnHour         = NoValue;
  double              PauseOnPrice        = 0.00;
  bool                LoggingOn           = false;
  bool                TradingOn           = true;
  bool                Alerts[EventTypes];
  
  //--- Session operationals
  SessionDetail       detail[SessionTypes];
  
  //--- Trade operationals
  int                 SessionHour;
  
  //--- Order Manager operationals
  OrderManagerRec     om[2];
  double              omMatrix[5][5];
  double              omInterlace[];
  int                 omInterlaceDir;
  CArrayDouble       *omWork;
  
  double              pfExpansion[10];

  //--- Analyst operationals
  bool                anIssueQueue[AnalystAlerts];
  double              anFractal[ViewPoints][FractalPoints];
  double              anMaster[ViewPoints][SourceTypes][2][FractalPoints];
  FractalAnalysis     anFiboDetail[3];
  double              anBelwether[3];       //--- Asian market analysis
  ReservedWords       anBelwetherState;     //--- Asian market state


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
//| ServerHour - returns the server hour adjusted for gmt            |
//+------------------------------------------------------------------+
int ServerHour(void)
  { 
    return (TimeHour(session[Daily].ServerTime()));
  }

//+------------------------------------------------------------------+
//| FiboState - returns the state for the supplied fibo              |
//+------------------------------------------------------------------+
ReservedWords FiboState(FractalType Type)
  { 
    if (anFiboDetail[Type].Corrected)
      return (Correction);
      
    if (anFiboDetail[Type].Risk)
      return (AtRisk);
    
    if (anFiboDetail[Type].Peg)
      return (Peg);
      
    if (anFiboDetail[Type].Trap)
      return (Trap);

    return (NoState);
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

    if (pfractal.Event(NewWaveReversal))
    {
      UpdateLabel("lbh-1L","Long",clrDarkGray);
      UpdateLabel("lbh-1S","Short",clrDarkGray);
      
      UpdateBox("hdLong",clrBoxOff);
      UpdateBox("hdShort",clrBoxOff);
      
      UpdateBox("hdActionLong",clrBoxOff);
      UpdateBox("hdActionShort",clrBoxOff);
      
      if (pfractal.WaveSegment(OP_BUY).IsOpen)
      {
        UpdateLabel("lbh-1L","Long",clrWhite); 
        UpdateBox("hdLong",clrDarkGreen);        
        UpdateBox("hdActionLong",clrDarkGreen);
      }

      if (pfractal.WaveSegment(OP_SELL).IsOpen)
      {
        UpdateLabel("lbh-1S","Short",clrWhite); 
        UpdateBox("hdShort",clrMaroon);
        UpdateBox("hdActionShort",clrMaroon);
      }
    }
    
    if (pfractal.Event(NewWaveOpen))
    {
      UpdateLabel("lbh-1C","Crest",clrDarkGray);
      UpdateLabel("lbh-1T","Trough",clrDarkGray);
      UpdateLabel("lbh-1D","Decay "+EnumToString(pfractal.WaveSegment(Last).Type),clrDarkGray);

      UpdateBox("hdCrest",clrBoxOff);
      UpdateBox("hdTrough",clrBoxOff);
      UpdateBox("hdDecay",clrBoxOff);

      switch (pfractal.ActiveSegment().Type)
      {
        case Crest:     UpdateLabel("lbh-1C","Crest",clrWhite);
                        UpdateBox("hdCrest",clrDarkGreen);
                        break;
        case Trough:    UpdateLabel("lbh-1T","Trough",clrWhite);
                        UpdateBox("hdTrough",clrMaroon);
                        break;
        case Decay:     UpdateLabel("lbh-1D","Decay "+EnumToString(pfractal.WaveSegment(Last).Type),clrWhite);
                        UpdateBox("hdDecay",BoolToInt(pfractal.WaveSegment(Last).Type==Crest,clrDarkGreen,clrMaroon));
      }
    }
    
    UpdateLabel("lbWaveState",EnumToString(pfractal.ActiveWave().Type)+" "
                      +BoolToStr(pfractal.ActiveSegment().Type==Decay,"Decay ")
                      +EnumToString(pfractal.WaveState()),DirColor(pfractal.ActiveWave().Direction));
                      
    UpdateLabel("lbLongState",EnumToString(pfractal.ActionState(OP_BUY)),DirColor(pfractal.ActiveSegment().Direction));                     
    UpdateLabel("lbShortState",EnumToString(pfractal.ActionState(OP_SELL)),DirColor(pfractal.ActiveSegment().Direction));
    
    UpdateLabel("lbLongPlan","Waiting...",clrDarkGray);
    UpdateLabel("lbShortPlan","Waiting...",clrDarkGray);
    
    UpdateLabel("lbRetrace","Retrace",BoolToInt(pfractal.Wave().Retrace,clrYellow,clrDarkGray));
    UpdateLabel("lbBreakout","Breakout",BoolToInt(pfractal.Wave().Breakout,clrYellow,clrDarkGray));
    UpdateLabel("lbReversal","Reversal",BoolToInt(pfractal.Wave().Reversal,clrYellow,clrDarkGray));
    UpdateLabel("lbBank","Bank",BoolToInt(pfractal.Wave().Bank,clrYellow,clrDarkGray));
    UpdateLabel("lbKill","Kill",BoolToInt(pfractal.Wave().Kill,clrYellow,clrDarkGray));
    
    UpdateLabel("lbLongCount",(string)pfractal.WaveSegment(OP_BUY).Count,clrDarkGray);
    UpdateLabel("lbShortCount",(string)pfractal.WaveSegment(OP_SELL).Count,clrDarkGray);
    UpdateLabel("lbCrestCount",(string)pfractal.WaveSegment(Crest).Count+":"+(string)pfractal.Wave().CrestTotal,clrDarkGray);
    UpdateLabel("lbTroughCount",(string)pfractal.WaveSegment(Trough).Count+":"+(string)pfractal.Wave().TroughTotal,clrDarkGray);
    UpdateLabel("lbDecayCount",(string)pfractal.WaveSegment(Decay).Count,clrDarkGray);

    string colHead[5]  = {"L","S","C","T","D"};

    for (int row=0;row<5;row++)
      for (int col=0;col<5;col++)
        UpdateLabel("lb"+colHead[col]+(string)row,DoubleToStr(omMatrix[col][row],Digits),Color(omMatrix[col][row],IN_PROXIMITY));

    for (int row=0;row<25;row++)
      if (row<ArraySize(omInterlace))
        UpdateLabel("lbInterlace"+(string)row,DoubleToStr(omInterlace[row],Digits),Color(omInterlace[row],IN_PROXIMITY));
      else
        UpdateLabel("lbInterlace"+(string)row,"");

    for (ActionState row=Bank;row<Hold;row++)
      for (int col=OP_BUY;col<=OP_SELL;col++)
        UpdateLabel("lbPL"+(string)col+":"+(string)row,DoubleToStr(pfractal.ActionLine(col,row),Digits),Color(pfractal.ActionLine(col,row),IN_PROXIMITY));

    UpdateBox("hdInterlace",Color(omInterlaceDir,IN_DARK_DIR));
    UpdateLabel("lbLongNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(OP_BUY).Retrace-pfractal.WaveSegment(OP_BUY).High),1),clrRed);    
    UpdateLabel("lbShortNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(OP_SELL).Low-pfractal.WaveSegment(OP_SELL).Retrace),1),clrLawnGreen);    
    UpdateLabel("lbCrestNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Crest).Retrace-pfractal.WaveSegment(Crest).High),1),clrRed);
    UpdateLabel("lbTroughNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Trough).Low-pfractal.WaveSegment(Trough).Retrace),1),clrLawnGreen);    

    if (pfractal.WaveSegment(Last).Type==Crest)
      UpdateLabel("lbDecayNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Decay).Retrace-pfractal.WaveSegment(Decay).High),1),clrRed);

    if (pfractal.WaveSegment(Last).Type==Trough)
      UpdateLabel("lbDecayNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Decay).Low-pfractal.WaveSegment(Decay).Retrace),1),clrLawnGreen);
    
    string colFiboHead   = "";
    
    for (FractalPoint row=0;row<FractalPoints;row++)
      for (FractalType col=ftOrigin;col<ftPrior;col++)
      {
        UpdateLabel("lbAN"+(string)col+":"+(string)row,BoolToStr(IsEqual(anFractal[col][row],0.00),"  Viable",DoubleToStr(anFractal[col][row],Digits)),Color(anFractal[col][row],IN_PROXIMITY));
        
        if (row==0)
        {
          UpdateBox("hdAN"+StringSubstr(EnumToString(col),2),clrBoxRedOff);
          
          if (FiboState(col)==NoState)
            UpdateLabel("lbAN"+(string)col+":Flag","",clrYellow);
          else
          {
            switch (FiboState(col))
            {
              case Correction: colFiboHead = "Correct";
                               break;
              case AtRisk:     colFiboHead = " Risk ";
                               break;
              case Peg:        colFiboHead = "  Peg  ";
                               break;
              case Trap:       colFiboHead = " Trap ";
                               break;
            }
            
            UpdateLabel("lbAN"+(string)col+":Flag",colFiboHead,clrYellow);
            UpdateLabel("lbAN"+(string)col+":Source",StringSubstr(EnumToString(anFiboDetail[col].Source),3),clrDarkGray);
          }
        }
      }
  }

//+------------------------------------------------------------------+
//| ZeroLines - Set displayed lines to zero                          |
//+------------------------------------------------------------------+
void ZeroLines(void)
  {
    static int zlAction       = OP_NO_ACTION;
    static int zlActionWave   = OP_NO_ACTION;
    
    if (IsChanged(zlAction,rsAction)||IsChanged(zlActionWave,pfractal.Wave().Action))
    {
      UpdateLine("lnOpen",0.00);
      UpdateLine("lnHigh",0.00);
      UpdateLine("lnLow",0.00);
      UpdateLine("lnClose",0.00);
      UpdateLine("lnRetrace",0.00);

      UpdateLine("lnBank",0.00);
      UpdateLine("lnGoal",0.00);
      UpdateLine("lnYield",0.00);
      UpdateLine("lnBuild",0.00);
      UpdateLine("lnGo",0.00);
      UpdateLine("lnStop",0.00);
      UpdateLine("lnRisk",0.00);
      UpdateLine("lnMercy",0.00);
      UpdateLine("lnChance",0.00);
      UpdateLine("lnOpportunity",0.00);
      UpdateLine("lnHalt",0.00);
      UpdateLine("lnKill",0.00);
    }
  }

//+------------------------------------------------------------------+
//| ShowLines - Show lines for the supplied segment                  |
//+------------------------------------------------------------------+
void ShowLines(void)
  { 
    ZeroLines();
    
    if (rsAction==OP_NO_ACTION)
      return;

    if (rsSegment>NoValue)
    {
      UpdateLine("lnOpen",pfractal.WaveSegment(SegmentType[rsSegment]).Open,STYLE_SOLID,clrYellow);
      UpdateLine("lnHigh",pfractal.WaveSegment(SegmentType[rsSegment]).High,STYLE_SOLID,clrLawnGreen);
      UpdateLine("lnLow",pfractal.WaveSegment(SegmentType[rsSegment]).Low,STYLE_SOLID,clrRed);
      UpdateLine("lnClose",pfractal.WaveSegment(SegmentType[rsSegment]).Close,STYLE_SOLID,clrSteelBlue);
      UpdateLine("lnRetrace",pfractal.WaveSegment(SegmentType[rsSegment]).Retrace,STYLE_DOT,clrSteelBlue);
    }
    else
    if (pfractal.Wave().Action==rsAction)
    {
      UpdateLine("lnBank",pfractal.ActionLine(rsAction,Bank),STYLE_DOT,clrGoldenrod);
      UpdateLine("lnGoal",pfractal.ActionLine(rsAction,Goal),STYLE_DOT,clrLawnGreen);
      UpdateLine("lnGo",pfractal.ActionLine(rsAction,Go),STYLE_SOLID,clrYellow);
      UpdateLine("lnChance",pfractal.ActionLine(rsAction,Chance),STYLE_DOT,clrSteelBlue);
      UpdateLine("lnYield",pfractal.ActionLine(rsAction,Yield),STYLE_SOLID,clrGoldenrod);
      UpdateLine("lnBuild",pfractal.ActionLine(rsAction,Build),STYLE_SOLID,clrLawnGreen);
      UpdateLine("lnRisk",pfractal.ActionLine(rsAction,Risk),STYLE_DOT,clrOrangeRed);
      UpdateLine("lnStop",pfractal.ActionLine(rsAction,Stop),STYLE_SOLID,clrRed);
    }
    else
    {
      UpdateLine("lnGo",pfractal.ActionLine(rsAction,Go),STYLE_SOLID,clrYellow);
      UpdateLine("lnMercy",pfractal.ActionLine(rsAction,Mercy),STYLE_DOT,clrSteelBlue);      
      UpdateLine("lnOpportunity",pfractal.ActionLine(rsAction,Opportunity),STYLE_SOLID,clrSteelBlue);
      UpdateLine("lnRisk",pfractal.ActionLine(rsAction,Risk),STYLE_DOT,clrOrangeRed);
      UpdateLine("lnHalt",pfractal.ActionLine(rsAction,Halt),STYLE_DOT,clrOrangeRed);
      UpdateLine("lnStop",pfractal.ActionLine(rsAction,Stop),STYLE_SOLID,clrRed);
      UpdateLine("lnKill",pfractal.ActionLine(rsAction,Kill),STYLE_DOT,clrMaroon);
    }
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

    ShowLines();

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
      fractal.RefreshScreen(true);
    else
    if (rsShow=="PIPMA")
    {
      if (pfractal.HistoryLoaded())
        pfractal.RefreshScreen();
      else
        Comment("PipMA is loading history...");
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
//| PriceRating - Returns the proximity to close price rating        |
//+------------------------------------------------------------------+
int PriceRating(double Price, double Max=6.0, double Min=3.0, double Mean=0.2)
  {
    if (Close[0]>Price+point(Max))   return(3);
    if (Close[0]>Price+point(Min))   return(2);
    if (Close[0]>Price+point(Mean))  return(1);
    if (Close[0]>Price-point(Mean))  return(0);
    if (Close[0]>Price-point(Min))   return(-1);
    if (Close[0]>Price-point(Max))   return(-2);

    return (-3);
  }

//+------------------------------------------------------------------+
//| ProcessSession - Process and consolidate Session data **FIRST**  |
//+------------------------------------------------------------------+
void ProcessSession(void)
  {
    bool cseIsValid;
    
    sEvent.ClearEvents();
    
    //-- Set General Notification Events
    if (session[Daily].Event(NewDay))
    {
      //--- Reset Session Detail for this trading day
      for (SessionType type=Daily;type<SessionTypes;type++)
      {
        detail[type].FractalDir      = DirectionNone;
        detail[type].NewFractal      = false;
        detail[type].Reversal        = false;
        detail[type].HighHour        = ServerHour();
        detail[type].LowHour         = ServerHour();
      }
    
      sEvent.SetEvent(NewDay);
    }
      
    if (session[Daily].Event(NewHour))
    {
      for (SessionType type=Daily;type<SessionTypes;type++)
        detail[type].NewFractal      = false;    

      sEvent.SetEvent(NewHour);
    }
      
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      //-- Set Session Notification Events
      if (session[type].Event(SessionOpen))
      {
        if (NewDirection(detail[type].OpenDir,Direction(session[type].Pivot(OffSession)-session[type].Pivot(PriorSession))))
          sEvent.SetEvent(NewPivot,Major);
      
        if (NewBias(detail[type].OpenBias,session[type].Bias()))
          sEvent.SetEvent(NewBias);

        sEvent.SetEvent(SessionOpen);
      }
        
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
//| ProcessPipMA - Process PipMA data and prepare recommendations    |
//+------------------------------------------------------------------+
void ProcessPipMA(void)
  {
    double ppmaPrice[5];
    
    if (pfractal.EventAlert(NewFractal,Minor))
      sEvent.SetEvent(NewFractal,Minor);

    if (pfractal.EventAlert(NewFractal,Major))
      sEvent.SetEvent(NewFractal,Major);
      
    if (pfractal.HistoryLoaded())
    {
      //--- do stuff?
    }

    //--- Load fibo matrix
    for (FibonacciLevel fibo=0;fibo<=Fibo823;fibo++)
    {
      pfExpansion[fibo]       = FiboPrice(fibo,pfractal[Term].Base,pfractal[Term].Root,Expansion);
      Print(DoubleToStr(pfExpansion[fibo],Digits));
    }

    //--- Extract and Process tick interlace data
    omWork.Clear();
    
    //-- Extract the equalization matrix
    for (int seg=0;seg<5;seg++)
    {
      ppmaPrice[0]            = pfractal.WaveSegment(SegmentType[seg]).Open;
      ppmaPrice[1]            = pfractal.WaveSegment(SegmentType[seg]).High;
      ppmaPrice[2]            = pfractal.WaveSegment(SegmentType[seg]).Low;
      ppmaPrice[3]            = pfractal.WaveSegment(SegmentType[seg]).Close;
      ppmaPrice[4]            = pfractal.WaveSegment(SegmentType[seg]).Retrace;
      
      ArraySort(ppmaPrice,WHOLE_ARRAY,0,MODE_DESCEND);
      
      for (int copy=0;copy<5;copy++)
      {
        omMatrix[seg][copy]   = ppmaPrice[copy];
        omWork.Add(ppmaPrice[copy]);
      }
    }
    
    omWork.CopyFiltered(omInterlace,false,false,MODE_DESCEND);
    omInterlaceDir = BoolToInt(fdiv(omInterlace[0]+omInterlace[ArraySize(omInterlace)-1],2,Digits)<Close[0],DirectionUp,DirectionDown);
    
    pfractal.DrawStateLines();
    pfractal.ShowFiboArrow();
  }

//+------------------------------------------------------------------+
//| ProcessFractal - Process and prepare fractal data                |
//+------------------------------------------------------------------+
void ProcessFractal(void)
  {
    if (fractal.Event(NewFractal))
      sEvent.SetEvent(NewFractal,Critical);

    for (FractalType type=ftOrigin;type<ftPrior;type++)
    {                        
      anFiboDetail[type].Direction       = session[Daily].Fractal(type).Direction;
      anFiboDetail[type].BreakoutDir     = session[Daily].Fractal(type).BreakoutDir;
      anFiboDetail[type].State           = session[Daily].Fractal(type).State;
      anFiboDetail[type].Source          = NoSource;
      
      anFiboDetail[type].FiboRetrace     = session[Daily].Fibonacci(type).RetraceNow;
      anFiboDetail[type].FiboExpansion   = session[Daily].Fibonacci(type).ExpansionNow;
      
      if (IsLower(Fibo100,anFiboDetail[type].FiboLevel))
      {
        //--- Monitor risk and reload points
        if (anFiboDetail[type].FiboLevel==Fibo50)
          anFiboDetail[type].Peg         = true;
 
        if (anFiboDetail[type].FiboLevel==Fibo23)
        {
          anFiboDetail[type].Risk        = true;
          anFractal[type][fpYield]       = session[Daily].Fibonacci(type).Expansion[Fibo50];
          anFractal[type][fpTarget]      = session[Daily].Fibonacci(type).Retrace[Fibo23];
        }
        
        if (anFiboDetail[type].FiboLevel==FiboRoot)
        {
          anFiboDetail[type].Corrected   = true;
          anFractal[type][fpYield]       = session[Daily].Fibonacci(type).Expansion[Fibo23];
          anFractal[type][fpTarget]      = session[Daily].Fibonacci(type).Retrace[Fibo38];
        }
      }

      if (FiboLevel(session[Daily].Fibonacci(type).ExpansionNow)==Fibo100)
      {
        if (anFiboDetail[type].Direction!=anFiboDetail[type].BreakoutDir)
          anFiboDetail[type].Trap        = true;

        anFiboDetail[type].FiboLevel     = Fibo100;
        
        if (anFiboDetail[type].Corrected)
        {
          //--- hmm, what to do? Need a case study
        }
        else
        if (anFiboDetail[type].Risk)
        {
          //--- hmm, what to do? Set short Yield/Targets?
        }
        else
        if (anFiboDetail[type].Peg)
        {
          //--- hmm, what to do?  Mark strategy FFE?
        }
        else
        {
          anFractal[type][fpTarget]      = session[Daily].Fibonacci(type).Expansion[Fibo161];
          anFractal[type][fpYield]       = session[Daily].Fibonacci(type).Expansion[Fibo100];
          anFractal[type][fpLoad]        = session[Daily].Fibonacci(type).Expansion[Fibo61];
          anFractal[type][fpBounce]      = session[Daily].Fibonacci(type).Expansion[Fibo50];
          anFractal[type][fpRisk]        = session[Daily].Fibonacci(type).Expansion[Fibo38];
          anFractal[type][fpHalt]        = session[Daily].Fibonacci(type).Expansion[FiboRoot];
          anFiboDetail[type].Source      = indSession;
        }
      }
      else
      if (IsLower(FiboLevels[Fibo161],anFiboDetail[type].FiboExpansion,NoUpdate))
      {
        //-- Less viable alternative - caused by severely expanding market; hmmm... should the short term continue?
        anFractal[type][fpTarget]        = pfExpansion[Fibo161];
        anFractal[type][fpYield]         = pfExpansion[Fibo100];
        anFractal[type][fpLoad]          = pfExpansion[Fibo50];
        anFractal[type][fpBounce]        = pfExpansion[FiboRoot];
        anFractal[type][fpRisk]          = pfExpansion[FiboRoot];
        anFractal[type][fpHalt]          = pfExpansion[FiboRoot];
        anFiboDetail[type].Source        = indPipMA;
      }
      else
      if (IsLower(FiboLevels[Fibo50],anFiboDetail[type].FiboExpansion,NoUpdate))
      {
        //-- Less viable alternative - could be due to severely contracting/expanding markets
        if (type==ftOrigin)
        {
          //--- Find the best Origin candidate
          if (session[Daily].Fractal(ftOrigin).State==Correction)
            if (IsLower(FiboLevels[Fibo50],anFiboDetail[type].FiboExpansion,NoUpdate))
            {
              anFractal[type][fpTarget]  = session[Daily].Fibonacci(type).Expansion[Fibo100];
              anFractal[type][fpYield]   = session[Daily].Fibonacci(type).Retrace[Fibo23];
              anFractal[type][fpLoad]    = session[Daily].Fibonacci(type).Expansion[Fibo50];
              anFractal[type][fpBounce]  = session[Daily].Fibonacci(type).Expansion[Fibo50];
              anFractal[type][fpRisk]    = session[Daily].Fibonacci(type).Expansion[Fibo38];
              anFractal[type][fpHalt]    = session[Daily].Fibonacci(type).Expansion[Fibo23];
              anFiboDetail[type].Source  = indSession;
            }
            
          //--- Consider using Papa Fractal
          
        }
      }
      else
      {
        Print("Bad Fibo Data: "+EnumToString(type));
          
      }

      switch (type)
      {
        case ftOrigin:     //--- Macro Configuration/Corrections
                           anFiboDetail[type].Leg           = fractal.State(Max);
        
                           if (fractal.IsDivergent())
                             anFiboDetail[type].Trap        = false;
                           
                           if (session[Daily].Fractal(type).State==Correction)
                           {
                             anFiboDetail[type].Corrected   = true;
          
                             //--- do correction stuff and revalidation
                           }
                           break;

         case ftTrend:     //--- Meso Configuration/Corrections
                           break;

         case ftTerm:      //--- Micro Configuration/Corrections
                           if (IsLower(FiboLevel(Fibo23),anFiboDetail[type].FiboExpansion,NoUpdate))
                             anFiboDetail[type].Corrected     = true;

                           break;
      }
    }
  }

//+------------------------------------------------------------------+
//| SetDailyPlan - Review and analyze daily objectives               |
//+------------------------------------------------------------------+
void SetDailyPlan(void)
  {

  }

//+------------------------------------------------------------------+
//|  SetHourlyPlan - Updates the daily plan based on new data        |
//+------------------------------------------------------------------+
void SetHourlyPlan(void)
  {
  
    return;
  }

//+------------------------------------------------------------------+
//| Publish - Consolidate and publish data processed                 |
//+------------------------------------------------------------------+
void Publish(void)
  {
    anIssueQueue[SecondChance]  = sEvent.ProximityAlert(pfractal.ActionLine(OP_BUY,Chance),5);
    anIssueQueue[SecondChance]  = sEvent.ProximityAlert(pfractal.ActionLine(OP_SELL,Chance),5);
    
  
    return;
  }

//+------------------------------------------------------------------+
//| AnalyzeFractalEvents - Analyze fractal combine and assess plan   |
//+------------------------------------------------------------------+
void AnalyzeFractalEvents(void)
  {
    return;
  }

//+------------------------------------------------------------------+
//| SetFiboSource - Identify best source for the supplied viewpoint  |
//+------------------------------------------------------------------+
void SetFiboSource(ViewPoint View)
  {
    FractalType vpSource    = NoValue;
    
    switch (View)
    {
      case Macro:  
                  break;
      case Meso:  
                  break;
      case Micro:  
                  break;
    };
  }

//+------------------------------------------------------------------+
//| AnalyzeData - Verify health and safety of open positions         |
//+------------------------------------------------------------------+
void AnalyzeData(void)
  {
    //--- Analyze an prepare data
    ProcessSession();
    ProcessPipMA();

    for (ViewPoint view=Macro;view<ViewPoints;view++)
      if (anFiboDetail[view].Source==NoSource)
        SetFiboSource(view);

    ProcessFractal();

    if (sEvent[NewDay])
      SetDailyPlan();
      
    if (sEvent[NewHour])
      SetHourlyPlan();
    
    if (sEvent[NewFractal])
      AnalyzeFractalEvents();

    Publish();
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
//| SetStrategy - Configures the order manager trading strategy      |
//+------------------------------------------------------------------+
void SetStrategy(const int Action, StrategyType Strategy, ActionState Plan)
  {
//    om[Action].Strategy         = Strategy;
    om[Action].Plan             = Plan;
  }

//+------------------------------------------------------------------+
//| OrderApproved - Performs health and sanity checks for approval   |
//+------------------------------------------------------------------+
bool OrderApproved(int Action)
  {
    if (TradingOn)
      return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| OrderProcessed - Executes orders from the order manager          |
//+------------------------------------------------------------------+
bool OrderProcessed(int Action)
  {
//    if (OpenOrder(Action,EnumToString(om[Action].Strategy)+":"+EnumToString(om[Action].Plan)))
//      return (true);
//    
    return (false);
  }

//+------------------------------------------------------------------+
//| Scalper - Contrarian Model Short Term by Action                  |
//+------------------------------------------------------------------+
void Scalper(const int Action)
  {
    switch (Action)
    {
    }
  }

//+------------------------------------------------------------------+
//| ShortManagement - Manages short order positions, profit and risk |
//+------------------------------------------------------------------+
void ShortManagement(void)
  {
//    SetStrategy(OP_SELL,Scalp,Build);
  }

//+------------------------------------------------------------------+
//| OrderManagement - Manages the order cycle                        |
//+------------------------------------------------------------------+
void OrderManagement(void)
  {
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      //switch (om[action].Strategy)
      //{
      //  case Scalp:  Scalper(action);
      //               break;
      //}
    }
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (PauseOnHour>NoValue)
      if (sEvent[NewHour])
        if (ServerHour()==PauseOnHour)
          CallPause("Pause requested on Server Hour "+IntegerToString(PauseOnHour),Always);
    
    if (PauseOnPrice!=0.00)
      if ((PauseOnPrice>NoValue&&Close[0]>PauseOnPrice)||(PauseOnPrice<NoValue&&Close[0]<fabs(PauseOnPrice)))
      {
        CallPause("Pause requested at price "+DoubleToString(fabs(PauseOnPrice),Digits),Always);
        PauseOnPrice  = 0.00;
      }
       
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
      if (Command[1]=="PRICE")
        PauseOnPrice                   = StringToDouble(Command[2]);
      else
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
         if (Command[2]=="CREST")
           rsSegment                   = 2;
         else
         if (Command[2]=="TROUGH")
           rsSegment                   = 3;
         else
         if (Command[2]=="DECAY")
           rsSegment                   = 4;
         else
         if (Command[2]=="BUY"||Command[2]=="LONG")
         {
           rsAction                    = OP_BUY;
           rsSegment                   = NoValue;

           if (Command[3]=="SEG")
           {
             rsSegment                 = OP_BUY;
             rsAction                  = OP_CLOSE;
           }
         }
         else
         if (Command[2]=="SELL"||Command[2]=="SHORT")
         {
           rsAction                    = OP_SELL;
           rsSegment                   = NoValue;

           if (Command[3]=="SEG")
           {
             rsSegment                 = OP_SELL;
             rsAction                  = OP_CLOSE;
           }
         }
         else
         {
           rsSegment                   = NoValue;
           rsAction                    = OP_NO_ACTION;
         }
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
    
    AnalyzeData();

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
    
    omWork                = new CArrayDouble(0);
    omWork.Truncate       = false;
    omWork.AutoExpand     = true;    
    omWork.SetPrecision(Digits);
    omWork.Initialize(0.00);
    
    session[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
 
    NewLine("lnOpen");
    NewLine("lnHigh");
    NewLine("lnLow");
    NewLine("lnClose");
    NewLine("lnRetrace");

    NewLine("lnBank");
    NewLine("lnYield");
    NewLine("lnGoal");
    NewLine("lnHalt");
    NewLine("lnRisk");
    NewLine("lnBuild");
    NewLine("lnGo");
    NewLine("lnStop");
    NewLine("lnChance");
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
//      om[action].Plan           = Halt;
      om[action].OrderTotal     = 0;
      om[action].LotsTotal      = 0.00;
      om[action].NetMargin      = 0.00;
      om[action].EQProfit       = 0.00;
      om[action].EQLoss         = 0.00;
    }

    //--- Initialize Fibo Management
    for (FractalType type=ftOrigin;type<ftPrior;type++)
      anFiboDetail[type].Source = NoSource;
      
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
    delete omWork;
  }