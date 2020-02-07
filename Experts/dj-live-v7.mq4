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
#include <Class\Fractal.mqh>
#include <Class\ArrayInteger.mqh>

  
input string    AppHeader            = "";    //+---- Application Options -------+
input YesNoType inpDisplayEvents     = Yes;   // Display event bar notes

input string    FractalHeader        = "";    //+------ Fractal Options ---------+
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
input int       inpEuropeOpen        = 8;     // Europe market open hour`
input int       inpEuropeClose       = 18;    // Europe market close hour
input int       inpUSOpen            = 14;    // US market open hour
input int       inpUSClose           = 23;    // US market close hour
input int       inpGMTOffset         = 0;     // GMT Offset


  //--- Class Objects
  CSession           *session[SessionTypes];
  CSession           *lead;
  CFractal           *fractal        = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal       = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,50);
  CEvent             *sEvent         = new CEvent();
  CEvent             *rsEvents       = new CEvent();
  
  //--- Recommendation Alerts
  enum                ReasonType
                      {
                        BalancePoint,         //-- Lot balancing at the Asian bellwether midpoint                      
                        DivergencePoint,      //-- Indicator divergence point; rally/pullback pattern confirmed on divergence                        
                        FractalBalance,       //-- Major retrace/reversal point approaching at the bre 50/61 Fibo
                        FractalMajor,         //-- Major target/reversal point approaching at the bre 161
                        FractalCorrection,    //-- Fractal Expansion <= 23 Fibo
                        CheckPoint,           //-- Fractal 100% Check Point Price (**Important: High reversal potential at PipMA 261 check)
                        SlantReversal,        //-- High probability of reversal; occurs between the 9th and 10th hour
                        YanksReversal,        //-- High probability of reversal; occurs between the 14th (Yanks) and 15th hour
                        AsianDriver,          //-- When Asian session is driving fractal expansion; instructs managers to hold 'til Asian close
                        MercyBounce,          //-- Recovering 50% fibo found in micro wave pattern management
                        SecondChance,         //-- Better than a mercy bounce; indicates the strong probability of reversal
                        ReasonTypes
                      };
                      
  //--- Fractal Sources
  enum                ViewPoint
                      {
                        Macro,
                        Meso,
                        Micro,
                        ViewPoints
                      };
                      
  //--- Order Statuses
  enum                OrderStatus
                      {
                        NoStatus,
                        Pending,
                        Immediate,
                        Canceled,
                        Approved,
                        Declined,
                        Rejected,
                        Fulfilled,
                        Expired,
                        Closed,
                        OrderStates
                      };
                      
  enum                FractalPoint
                      {
                        fpTarget,
                        fpYield,
                        fpLoad,
                        fpBalance,
                        fpRisk,
                        fpHalt,
                        FractalPoints
                      };

                      
  enum                SourceType
                      {
                        NoSource,
                        indFractal,
                        indPipMA,
                        indSession,
                        SourceTypes
                      };

  //--- Strategy Types
  enum StrategyType
       {
         NoStrategy,
         Check,         //-- Catch all for missing patterns
         AsianScrew,    //-- Occurs on a counter trend reversal after the Asia close         
         UTurn,         //-- Reliable u-turn detection, occurs on converging reversing Terms on a soft breakout
         Torpedo,       //-- Reliable reversal detection, occurs on converging reversing Terms that had strong retraces
         Slant,         //-- Slant Reversal occurs on an outside Asian reversal
         Reversi,       //-- Slant Reversal occurs on an open session Asian reversal
         YanksGrab,     //-- Occurs on converging Asian/Daily reversing sessions while the Asian market is closed and US is the lead session
         TeaBreak,      //-- Occurs on converging Asian/Daily reversing sessions while the Asian market is closed and EU is the lead session
         Kamikaze,      //-- Occurs on converging Asian/Daily reversing sessions while the Asian market is open
         StrategyTypes
       };
       
  //--- Strategy Action
  enum                StrategyAction
                      {
                        NonFractalRecovery,
                        NonFractalCapture,
                        FFE,
                        Spot,
//                        Build,
//                        Hold,
//                        Halt,
                        StrategyActions
                      };

    const string StrategyText[StrategyTypes] =
                      {
                        "No Strategy",
                        "Check",
                        "(d) Asian Screw",
                        "(acr) U-Turn",
                        "(acr) Torpedo",
                        "(cr) Slant",
                        "(cr) Reversi",
                        "(cr) Yanks Grab",
                        "(cr) Tea Break",
                        "(acr) Kamikaze"
                      };
                       
  //--- Collection Objects
  struct              SessionDetail 
                      {
                        int            OpenDir;                //-- Direction on open as compared with the prior pivot
                        int            ActiveDir;              //-- The live direction as it changes throughout a day
                        int            OpenBias;               //-- Bias as compared with offsession pivot
                        int            ActiveBias;             //-- The live Bias as it changes throughout a day
                        bool           Reversal;               //-- Used to identify outside reversal sessions
                        int            FractalDir;             //-- Used to identify breakout and reversal direction
                        bool           NewFractal;             //-- Noise reduction filter on fractal expansion
                        int            FractalHour;            //-- Fractal aging for sessions add a new fractal
                        int            HighHour;               //-- Daily high hour
                        int            LowHour;                //-- Daily low hour
                        double         Ceiling;                //-- Last session trading high
                        double         Floor;                  //-- Last session trading low
                        double         Pivot;                  //-- Last session pivot
                        bool           IsValid;                //-- Are the open v. bias measures align?
                        bool           Alerts;                 //-- Noise reduction filter for alerts
                      };

  struct              OrderRequest
                      {
                        int             Key;
                        int             Action;
                        string          Requestor;
                        double          Price;
                        double          Lots;
                        double          Target;
                        double          Stop;
                        string          Memo;
                        datetime        Expiry;
                        OrderStatus     Status;
                      };
                      
  struct              ActiveMatrixRec
                      {
                        int             Action;
                        double          Price;
                        ReasonType      Reason;
                        SourceType      Source;
                      };
                      
  struct              FractalAnalysis
                      {
                        SessionType     Session;               //--- the session fibo data was collected from
                        int             Direction;             //--- the direction indicated by the source
                        int             BreakoutDir;           //--- the last breakout direction; contrary indicates reversing pattern
                        ReservedWords   State;                 //--- the state of the fractal provided by the source
                        ActionState     FiboActionState;       //--- the derived proposed action plan for this fractal
                        FibonacciLevel  FiboLevel;             //--- the now expansion fibo level
                        int             FiboNetChange;         //--- the net change in a declining fibo pattern
                        bool            FiboChanged;           //--- indicates a fibo drop; prompts review of targets and risk
                        double          RetraceNow;            //--- now retrace fibo reported by source
                        double          RetraceMax;            //--- max retrace fibo reported by source
                        double          ExpansionNow;          //--- now expansion fibo reported by source
                        double          ExpansionMax;          //--- max expansion fibo reported by source
                        double          TargetStart;           //--- the price at which the source stated a target
                        double          MaxProximityToTarget;  //--- the max price nearest to the target; a positive value indicates target hit
                        RetraceType     FractalLeg;            //--- the papa fractal leg
                        bool            Peg;                   //--- peg occurs at expansion fibo50
                        bool            Risk;                  //--- risk occurs on risk mit
                        bool            Corrected;             //--- Correction occurs on correction mit
                        bool            Trap;                  //--- when a Meso breakout occurs
                      };

  const int SegmentType[5]   = {OP_BUY,OP_SELL,Crest,Trough,Decay};

  //--- Display operationals
  string              rsShow              = "APP";
  SessionType         rsSession           = SessionTypes;
  int                 rsAction            = OP_BUY;
  int                 rsSegment           = NoValue;
    
  bool                PauseOn             = true;
  bool                PauseOnHistory      = false;
  int                 PauseOnHour         = NoValue;
  double              PauseOnPrice        = 0.00;
  bool                LoggingOn           = false;
  bool                TradingOn           = true;

  bool                Alerts[EventTypes];
  bool                SourceAlerts[SourceTypes];
  
  //--- Session operationals
  SessionDetail       detail[SessionTypes];
  
  //--- Trade operationals
  int                 SessionHour;
  
  //--- Order Manager operationals
  int                 omAction;
  OrderRequest        omQueue[];
  CArrayInteger      *omOrderKey;
  double              omMatrix[5][5];
  double              omInterlace[];
  double              omInterlacePivot[2];
  int                 omInterlaceDir;
  int                 omInterlaceBrkDir;
  CArrayDouble       *omWork;
  
  double              pfExpansion[10];
  int                 pfAction            = OP_NO_ACTION;

  //--- Analyst operationals
  StrategyType        anStrategy;
  double              anFractal[ViewPoints][FractalPoints];
  FractalAnalysis     anFiboDetail[FractalTypes];

//+------------------------------------------------------------------+
//| Trim - on of several function overloads to extract enum text     |
//+------------------------------------------------------------------+
string Trim(FractalType Type)
  {
    return(StringSubstr(EnumToString(Type),2));
  }

//+------------------------------------------------------------------+
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool IsChanged(OrderStatus &Compare, OrderStatus Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool IsChanged(StrategyType &Compare, StrategyType Value)
  {
    if (Value==NoStrategy)
      return (false);
      
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message, bool Force=false)
  {
    static string cpMessage   = "";

    if (PauseOnHistory)
      return;

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
//| RepaintOrder - Repaints a specific order line                    |
//+------------------------------------------------------------------+
void RepaintOrder(OrderRequest &Order, int Col, int Row)
  {
    string roLabel      = "lb-OM"+StringSubstr(ActionText(Col),0,1)+"-"+(string)Row;
    
    UpdateLabel(roLabel+"Key",LPad((string)Order.Key,"-",8),clrDarkGray,8,"Consolas");
    UpdateLabel(roLabel+"Status",EnumToString(Order.Status),clrDarkGray);
    UpdateLabel(roLabel+"Requestor",Order.Requestor,clrDarkGray);
    UpdateLabel(roLabel+"Price",DoubleToStr(Order.Price,Digits),clrDarkGray);
    UpdateLabel(roLabel+"Lots",DoubleToStr(Order.Lots,2),clrDarkGray);
    UpdateLabel(roLabel+"Target",DoubleToStr(Order.Target,Digits),clrDarkGray);
    UpdateLabel(roLabel+"Stop",DoubleToStr(Order.Stop,Digits),clrDarkGray);
    UpdateLabel(roLabel+"Expiry",TimeToStr(Order.Expiry),clrDarkGray);
    UpdateLabel(roLabel+"Memo",Order.Memo,clrDarkGray);
    
    if (InStr(ActionText(Order.Action),"LIMIT"))
      UpdateLabel(roLabel+"Type","Limit",clrDarkGray);
    else
    if (InStr(ActionText(Order.Action),"STOP"))
      UpdateLabel(roLabel+"Type","Stop",clrDarkGray);
    else
      UpdateLabel(roLabel+"Type","Market",clrDarkGray);
  }
  
//+------------------------------------------------------------------+
//| RefreshOrders - Repaints the order control panel display area    |
//+------------------------------------------------------------------+
void RefreshOrders(void)
  {
    string roLabel      = "";
    int    roLong       = 0;
    int    roShort      = 0;
    
    for (int col=0;col<2;col++)
      for (int row=0;row<25;row++)
      {
        roLabel       = "lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row;
        
        UpdateLabel(roLabel+"Key","");
        UpdateLabel(roLabel+"Status","");
        UpdateLabel(roLabel+"Requestor","");
        UpdateLabel(roLabel+"Type","");
        UpdateLabel(roLabel+"Price","");
        UpdateLabel(roLabel+"Lots","");
        UpdateLabel(roLabel+"Target","");
        UpdateLabel(roLabel+"Stop","");
        UpdateLabel(roLabel+"Expiry","");
        UpdateLabel(roLabel+"Memo","");
      }
     
    for (int ord=0;ord<ArraySize(omQueue);ord++)
    {
      if (Action(omQueue[ord].Action,InAction)==OP_BUY)
        if (omQueue[ord].Status==Pending||omQueue[ord].Expiry>Time[0]-(Period()*60))
          RepaintOrder(omQueue[ord],OP_BUY,roLong++);

      if (Action(omQueue[ord].Action,InAction)==OP_SELL)
        if (omQueue[ord].Status==Pending||omQueue[ord].Expiry>Time[0]-(Period()*60))
          RepaintOrder(omQueue[ord],OP_SELL,roShort++);
    }
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

    UpdateLabel("lbAN-Strategy",StrategyText[anStrategy],clrDarkGray);
    
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
                        if (pfractal.WaveSegment(Last).Type==Crest)
                          UpdateBox("hdCrest",Color(pfractal.WaveSegment(Last).Direction,IN_DARK_DIR));
                        else
                          UpdateBox("hdTrough",Color(pfractal.WaveSegment(Last).Direction,IN_DARK_DIR));
      }
    }
    
    UpdateLabel("lbWaveState",EnumToString(pfractal.ActiveWave().Type)+" "
                      +BoolToStr(pfractal.ActiveSegment().Type==Decay,"Decay ")
                      +EnumToString(pfractal.WaveState()),DirColor(pfractal.ActiveWave().Direction));
                      
    UpdateLabel("lbIntDev",NegLPad(Pip(Close[0]-omInterlacePivot[Action(omInterlaceBrkDir,InDirection)]),1),
                            Color(Close[0]-omInterlacePivot[Action(omInterlaceBrkDir,InDirection)]),20);
    
    UpdateLabel("lbIntPivot",DoubleToStr(omInterlacePivot[Action(omInterlaceBrkDir,InDirection)],Digits),clrDarkGray);
    UpdateDirection("lbIntBrkDir",omInterlaceBrkDir,Color(omInterlaceBrkDir),28);
    UpdateDirection("lbIntDir",omInterlaceDir,Color(omInterlaceDir),12);

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
        UpdateLabel("lbAN"+(string)col+":(e)",LPad(DoubleToStr(anFiboDetail[col].ExpansionNow*100,1)," ",6),clrDarkGray,8,"Consolas");
        UpdateLabel("lbAN"+(string)col+":(r)",LPad(DoubleToStr(anFiboDetail[col].RetraceNow*100,1)," ",6),clrDarkGray,8,"Consolas");
            
        if (row==0)
        {
          UpdateBox("hdAN"+StringSubstr(EnumToString(col),2),Color(anFiboDetail[col].Direction,IN_DARK_DIR));
          
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
    
    if (rsSession!=SessionTypes)
    {
      rsAction                = OP_NO_ACTION;
      
      UpdateLine("lnActive",0.00);
      UpdateLine("lnPrior",0.00);
      UpdateLine("lnOffSession",0.00);
      UpdateLine("lnCeiling",0.00);
      UpdateLine("lnFloor",0.00);
      UpdateLine("lnPivot",0.00);
    }

    if (IsChanged(zlAction,rsAction)||pfractal.Event(NewWaveReversal))
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
    
    if (rsSession!=SessionTypes)
    {
      UpdateLine("lnActive",session[rsSession].Pivot(ActiveSession),STYLE_SOLID,clrSteelBlue);
      UpdateLine("lnPrior",session[rsSession].Pivot(PriorSession),STYLE_DOT,Color(session[rsSession].Pivot(PriorSession),IN_PROXIMITY));
      UpdateLine("lnOffSession",session[rsSession].Pivot(OffSession),STYLE_SOLID,clrGoldenrod);

      UpdateLine("lnCeiling",detail[Asia].Ceiling,STYLE_DOT,clrDarkGreen);
      UpdateLine("lnFloor",detail[Asia].Floor,STYLE_DOT,clrMaroon);
      UpdateLine("lnPivot",detail[Asia].Pivot,STYLE_DOT,clrDarkBlue);

      return;
    }
    
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
    
    UpdatePriceLabel("plbInterlaceHigh",omInterlace[0],clrYellow);
    UpdatePriceLabel("plbInterlaceLow",omInterlace[ArraySize(omInterlace)-1],clrYellow);
    
    if (omAction==OP_NO_ACTION)
    {
      UpdatePriceLabel("plbInterlacePivotActive",omInterlacePivot[OP_BUY],clrDarkGray);
      UpdatePriceLabel("plbInterlacePivotInactive",omInterlacePivot[OP_SELL],clrDarkGray);
    }
    else
    if (omAction==OP_BUY)
    {
      UpdatePriceLabel("plbInterlacePivotActive",omInterlacePivot[OP_BUY],clrLawnGreen);
      UpdatePriceLabel("plbInterlacePivotInactive",omInterlacePivot[OP_SELL],clrMaroon);
    }
    else
    {
      UpdatePriceLabel("plbInterlacePivotActive",omInterlacePivot[OP_BUY],clrForestGreen);
      UpdatePriceLabel("plbInterlacePivotInactive",omInterlacePivot[OP_SELL],clrRed);
    }
    
    if (SourceAlerts[indPipMA])
      for (EventType type=1;type<EventTypes;type++)
        if (Alerts[type]&&pfractal.Event(type))
        {
          rsEvent   = "PipMA "+pfractal.ActiveEventText()+"\n";
          break;
        }

    if (SourceAlerts[indFractal])
      for (EventType type=1;type<EventTypes;type++)
        if (Alerts[type]&&fractal.Event(type))
        {
          rsEvent   = "Fractal "+fractal.ActiveEventText()+"\n";
          break;
        }

    rsEvents.ClearEvents();
    
    for (SessionType show=Daily;show<SessionTypes;show++)
      if (detail[show].Alerts)
        for (EventType type=1;type<EventTypes;type++)
          if (Alerts[type]&&session[show].Event(type))
          {
            if (type==NewFractal)
            {
              if (!detail[show].NewFractal)
                rsEvents.SetEvent(type);
                
              detail[show].FractalHour = ServerHour();
            }
            else
              rsEvents.SetEvent(type);
          }

    if (rsEvents.ActiveEvent())
    {
      Append(rsEvent,"Processed "+rsEvents.ActiveEventText(true)+"\n","\n");
    
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
        detail[type].FractalHour     = NoValue;
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
          
        detail[type].Ceiling          = session[type][PriorSession].High;
        detail[type].Floor            = session[type][PriorSession].Low;
        detail[type].Pivot            = session[type].Pivot(PriorSession);
        
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
      {
        detail[type].HighHour       = ServerHour();
        sEvent.SetEvent(NewHigh);
      }

      if (session[type].Event(NewLow))
      {
        detail[type].LowHour        = ServerHour();
        sEvent.SetEvent(NewLow);
      }

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

      detail[type].IsValid         = cseIsValid;
//      if (IsChanged(detail[type].IsValid,cseIsValid))
//        sEvent.SetEvent(NewAction,Major);
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
      if (pfractal.Event(NewWaveReversal))
        pfAction              = pfractal.Wave().Action;
        
    //--- Load fibo matrix
    for (FibonacciLevel fibo=0;fibo<=Fibo823;fibo++)
      pfExpansion[fibo]       = FiboPrice(fibo,pfractal[Term].Base,pfractal[Term].Root,Expansion);
 
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
    omInterlaceDir      = BoolToInt(fdiv(omInterlace[0]+omInterlace[ArraySize(omInterlace)-1],2,Digits)<Close[0],DirectionUp,DirectionDown);

    if (IsEqual(Close[0],omInterlace[0]))
      if (NewDirection(omInterlaceBrkDir,DirectionUp))
      {
        omAction                   = OP_BUY;
        omInterlacePivot[omAction] = Close[0];
      }

    if (IsEqual(Close[0],omInterlace[ArraySize(omInterlace)-1]))
      if (NewDirection(omInterlaceBrkDir,DirectionDown))
      {
        omAction                   = OP_SELL;
        omInterlacePivot[omAction] = Close[0];
      }

    pfractal.DrawStateLines();
//    pfractal.ShowFiboArrow();
  }

//+------------------------------------------------------------------+
//| ProcessFractal - Process and prepare fractal data                |
//+------------------------------------------------------------------+
void ProcessFractal(void)
  {
    //--- Process Session Fractal data
    for (FractalType type=ftOrigin;type<FractalTypes;type++)
    {
      if (type==ftPrior)
        continue;
        
      if (type==ftCorrection)
        if (anFiboDetail[type].Session==Daily)
          anFiboDetail[type].Session     = Asia;
                                     
      anFiboDetail[type].Direction       = session[anFiboDetail[type].Session].Fractal(type).Direction;
      anFiboDetail[type].BreakoutDir     = session[anFiboDetail[type].Session].Fractal(type).BreakoutDir;
      anFiboDetail[type].State           = session[anFiboDetail[type].Session].Fractal(type).State;
      anFiboDetail[type].RetraceNow      = session[anFiboDetail[type].Session].Fibonacci(type).RetraceNow;
      anFiboDetail[type].RetraceMax      = session[anFiboDetail[type].Session].Fibonacci(type).RetraceMax;
      anFiboDetail[type].ExpansionNow    = session[anFiboDetail[type].Session].Fibonacci(type).ExpansionNow;
      anFiboDetail[type].ExpansionMax    = session[anFiboDetail[type].Session].Fibonacci(type).ExpansionMax;
    }

    for (FractalType type=ftOrigin;type<ftPrior;type++)
    {
      anFractal[type][fpTarget]          = session[Daily].Fibonacci(type).Expansion[Fibo161];
      anFractal[type][fpYield]           = session[Daily].Fibonacci(type).Expansion[Fibo100];
      anFractal[type][fpLoad]            = session[Daily].Fibonacci(type).Expansion[Fibo61];
      anFractal[type][fpBalance]         = session[Daily].Fibonacci(type).Expansion[Fibo50];
      anFractal[type][fpRisk]            = session[Daily].Fibonacci(type).Expansion[Fibo38];
      anFractal[type][fpHalt]            = session[Daily].Fibonacci(type).Expansion[FiboRoot];
    
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
        else
          anFiboDetail[type].Trap        = false;

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
        
        anFiboDetail[type].Corrected     = false;
        anFiboDetail[type].Risk          = false;
        anFiboDetail[type].Peg           = false;
      }
    }
  }

//+------------------------------------------------------------------+
//| Publish - Final consolidation; publish active matrix             |
//+------------------------------------------------------------------+
void Publish(void)
  {
//    anIssueQueue[SecondChance]  = sEvent.ProximityAlert(pfractal.ActionLine(OP_BUY,Chance),5);
//    anIssueQueue[SecondChance]  = sEvent.ProximityAlert(pfractal.ActionLine(OP_SELL,Chance),5);
// BalancePoint,         //-- Lot balancing at the Asian bellwether midpoint                      
// DivergencePoint,      //-- Indicator divergence point; rally/pullback pattern confirmed on divergence                        
// FractalBalance,       //-- Major retrace/reversal point approaching at the bre 50/61 Fibo
// FractalMajor,         //-- Major target/reversal point approaching at the bre 161
// FractalCorrection,    //-- Fractal Expansion <= 23 Fibo
// CheckPoint,           //-- Fractal 100% Check Point Price (**Important: High reversal potential at PipMA 261 check)
// SlantReversal,        //-- High probability of reversal; occurs between the 9th and 10th hour
// YanksReversal,        //-- High probability of reversal; occurs between the 14th (Yanks) and 15th hour
// AsianDriver,          //-- When Asian session is driving fractal expansion; instructs managers to hold 'til Asian close
// YanksDriver,          //-- When US session is driving fractal expansion; instructs managers to hold 'til US close
// MercyBounce,          //-- Recovering 50% fibo found in micro wave pattern management
// SecondChance,         //-- Better than a mercy bounce; indicates the strong probability of reversal
// ReasonTypes

  
    return;
  }

//+------------------------------------------------------------------+
//| AnalyzeData - Verify health and safety of open positions         |
//+------------------------------------------------------------------+
void AnalyzeData(void)
  {
    //--- Analyze an prepare data
    ProcessSession();
    ProcessPipMA();
    ProcessFractal();

    Publish();
  }

//+------------------------------------------------------------------+
//| OrderBias - Trade direction/action all factors considered        |
//+------------------------------------------------------------------+
int OrderBias(int Measure=InDirection)
  {
    if (ServerHour()<4)
      return(session[Daily][ActiveSession].Direction);
    
    if (ServerHour()>14)
      return(session[US][ActiveSession].Direction);

    if (ServerHour()>10)
      return(session[Europe][ActiveSession].Direction);

    return(lead[ActiveSession].Direction);
  }

//+------------------------------------------------------------------+
//| OrderApproved - Performs health and sanity checks for approval   |
//+------------------------------------------------------------------+
bool OrderApproved(OrderRequest &Order)
  {
    if (TradingOn)
    {
      Order.Status      = Approved;
      return (true);
    }

    Order.Status        = Declined;
    return (false);
  }

//+------------------------------------------------------------------+
//| OrderProcessed - Executes orders from the order manager          |
//+------------------------------------------------------------------+
bool OrderProcessed(OrderRequest &Order)
  {
    if (OpenOrder(Order.Action,Order.Requestor+":"+Order.Memo,Order.Lots))
    {
      UpdateTicket(ordOpen.Ticket,Order.Target,Order.Stop);

      Order.Key              = ordOpen.Ticket;
      Order.Price            = ordOpen.Price;

      return (true);
    }
    
    Order.Memo               = ordOpen.Reason;
    
    return (false);
  }
  
//+------------------------------------------------------------------+
//| OrderCancel - Cancels pending orders by Action                   |
//+------------------------------------------------------------------+
void OrderCancel(int Action, string Reason="")
  {
    for (int request=0;request<ArraySize(omQueue);request++)
      if (omQueue[request].Status==Pending)
        if (Action(omQueue[request].Action,InAction)==Action)
        {
          omQueue[request].Status   = Canceled;
          
          if (Reason!="")
            omQueue[request].Memo   = Reason;
        }
          
    RefreshOrders();
  }

//+------------------------------------------------------------------+
//| OrderSubmit - Manages short order positions, profit and risk     |
//+------------------------------------------------------------------+
void OrderSubmit(OrderRequest &Order)
  {
    Order.Key                = omOrderKey.Count;
    Order.Status             = Pending;

    if (!TradingOn)
    {
      Order.Status           = Declined;
      Order.Memo             = "Trading is not enabled.";
    }
    
    omOrderKey.Add(ArraySize(omQueue));
    ArrayResize(omQueue,omOrderKey[Order.Key]+1);
    omQueue[Order.Key]       = Order;

    RefreshOrders();
  }
   
//+------------------------------------------------------------------+
//| OrderManagement - Manages the order cycle                        |
//+------------------------------------------------------------------+
void OrderManagement(void)
  {
    OrderStatus  omState                  = NoStatus;
    bool         omRefreshQueue           = false;

    for (int request=0;request<ArraySize(omQueue);request++)
    {
      omState                            = omQueue[request].Status;
      
      if (omQueue[request].Status==Fulfilled)
        if (OrderSelect(omQueue[request].Key,SELECT_BY_TICKET,MODE_HISTORY))
          if (OrderCloseTime()>0)
            omQueue[request].Status      = Closed;
          
      if (omQueue[request].Status==Pending)
      {
        switch(omQueue[request].Action)
        {
          case OP_BUY:          omQueue[request].Status      = Immediate;
                                break;
          case OP_BUYSTOP:      if (Ask>=omQueue[request].Price)
                                {
                                  omQueue[request].Action    = OP_BUY;
                                  omQueue[request].Status    = Immediate;
                                }
                                break;
          case OP_BUYLIMIT:     if (Ask<=omQueue[request].Price)
                                {
                                  omQueue[request].Action    = OP_BUY;
                                  omQueue[request].Status    = Immediate;
                                }
                                break;
          case OP_SELL:         omQueue[request].Status      = Immediate;
                                break;
          case OP_SELLSTOP:     if (Bid<=omQueue[request].Price)
                                {
                                  omQueue[request].Action    = OP_SELL;
                                  omQueue[request].Status    = Immediate;
                                }
                                break;
          case OP_SELLLIMIT:    if (Bid>=omQueue[request].Price)
                                {
                                  omQueue[request].Action    = OP_SELL;
                                  omQueue[request].Status    = Immediate;
                                }
                                break;
        }
        
        if (Time[0]>omQueue[request].Expiry)
          omQueue[request].Status        = Expired;
      }

      if (omQueue[request].Status==Immediate)
        if (OrderApproved(omQueue[request]))
          if (OrderProcessed(omQueue[request]))
            omQueue[request].Status      = Fulfilled;
          else
            omQueue[request].Status      = Rejected;

      if (IsChanged(omState,omQueue[request].Status))
        omRefreshQueue                   = true;
    }

    if (omRefreshQueue)
      RefreshOrders();    
  }

//+------------------------------------------------------------------+
//| UpdateStrategy - Sets strategy up and handles visuals            |
//+------------------------------------------------------------------+
void UpdateStrategy(StrategyType Strategy)
  {
    static string usBarNote              = "";
    color         usColor                = clrDarkGray;
    static int    usLiveEventDir         = DirectionNone;

    if (Strategy==NoStrategy)
    {
      if (inpDisplayEvents==Yes)
        if (session[Asia].IsOpen())
        {
          if (session[Asia].Event(NewHigh)&&usLiveEventDir==DirectionUp)
            UpdateBarNote(usBarNote,session[Asia].Fractal(ftTerm).High,clrWhite);
          
          if (session[Asia].Event(NewLow)&&usLiveEventDir==DirectionDown)
            UpdateBarNote(usBarNote,session[Asia].Fractal(ftTerm).Low,clrWhite);
        }
        else
        {
          usBarNote                      = "";
          usLiveEventDir                 = DirectionNone;
        }
    }
    else
    {
      if (IsChanged(anStrategy,Strategy))
        if (inpDisplayEvents==Yes)
        {
          switch (Strategy)
          {
            case AsianScrew:   usColor   = clrYellow;
                               break;
            case YanksGrab:    usColor   = clrDodgerBlue;
                               break;
            case TeaBreak:     usColor   = clrMagenta;
                               break;
            default:           usColor   = Color(session[Asia].Fractal(ftTerm).Direction,IN_CHART_DIR);
            
          }

          usBarNote          = NewBarNote(StrategyText[Strategy],usColor);
          usLiveEventDir     = session[Asia].Fractal(ftTerm).Direction;
        }
    }
  }

//+------------------------------------------------------------------+
//| CheckConvergence - Returns true if on true price convergence     |
//+------------------------------------------------------------------+
bool CheckConvergence(bool &Check)
  {
    if (sEvent[NewTerm])
      Check                   = false;
      
    if (session[Asia].Fractal(ftTerm).Direction==DirectionUp)
      if (IsEqual(session[Daily].Fractal(ftTerm).High,session[Asia].Fractal(ftTerm).High,NoUpdate))
        return (true);
        
    if (session[Asia].Fractal(ftTerm).Direction==DirectionDown)
      if (IsEqual(session[Daily].Fractal(ftTerm).Low,session[Asia].Fractal(ftTerm).Low,NoUpdate))
        return (true);

    return (Check);
  }

//+------------------------------------------------------------------+
//| TermConvergence - Returns Term Convergent strategies             |
//+------------------------------------------------------------------+
StrategyType TermConvergence(void)
  {
    static bool tcConvergent   = false;
    
    UpdateLabel("lbAN:State","Term Convergent");
    
    if (IsChanged(tcConvergent,CheckConvergence(tcConvergent)))
    {
      //-- Handle new convergence
      switch (lead.Type())
      {
        case Asia:    return (Torpedo);
        case Europe:  if (session[Asia].IsOpen())
                        return (Kamikaze);
                      return (Slant);
        case US:      return (YanksGrab);
      }        
    }
    else
    {
      //-- Handle existing convergence
    }

    return (NoStrategy);
  }

//+------------------------------------------------------------------+
//| TermDivergence - Returns Term Divergent strategies               |
//+------------------------------------------------------------------+
StrategyType TermDivergence(void)
  {
    static bool tdDivergent    = false;

    UpdateLabel("lbAN:State","Term Divergent");
        
    if (IsChanged(tdDivergent,CheckConvergence(tdDivergent)))
    {
        //-- Handle new divergence
    }
    else
    {
      //-- Handle existing divergence
      return (AsianScrew);
    }

    return (NoStrategy);
  }

//+------------------------------------------------------------------+
//| TrendConvergence - Returns Trend Convergent strategies           |
//+------------------------------------------------------------------+
StrategyType TrendConvergence(void)
  {
    static bool tcConvergent   = false;
    
    UpdateLabel("lbAN:State","Trend Convergent");
    
    if (IsChanged(tcConvergent,CheckConvergence(tcConvergent)))
    {
      //-- Handle new convergence
      switch (lead.Type())
      {
        case Asia:    return (Kamikaze);
        case Europe:  return (TeaBreak);
        case US:      return (YanksGrab);
      }        
    }
    else
    {
      //-- Handle existing convergence
    }

    return (NoStrategy);  
  }

//+------------------------------------------------------------------+
//| TrendDivergence - Returns Trend Divergent strategies             |
//+------------------------------------------------------------------+
StrategyType TrendDivergence(void)
  {
    static bool tdDivergent    = false;

    UpdateLabel("lbAN:State","Trend Divergent");

    if (IsChanged(tdDivergent,CheckConvergence(tdDivergent)))
    {
      //-- Handle new divergence
    }
    else
    {
      //-- Handle existing divergence
      return (AsianScrew);
    }
  
    return (NoStrategy);
  }

//+------------------------------------------------------------------+
//| SetStrategy - Complete analysis of the market and set strategy   |
//+------------------------------------------------------------------+
void SetStrategy(void)
  {
    StrategyType   ssStrategy   = NoStrategy;

    if (session[Daily].Fractal(ftTrend).Direction==session[Daily].Fractal(ftTerm).Direction)
      if (session[Daily].Fractal(ftTerm).Direction==session[Asia].Fractal(ftTerm).Direction)
        ssStrategy              = TrendConvergence();
      else
        ssStrategy              = TrendDivergence();
    else
      if (session[Daily].Fractal(ftTerm).Direction==session[Asia].Fractal(ftTerm).Direction)
        ssStrategy              = TermConvergence();
      else
        ssStrategy              = TermDivergence();
        
    UpdateStrategy(ssStrategy);

//    if (session[Daily].Event(NewTerm))
//      if (session[Asia].Event(NewTerm))
//        ssEvent                 = NewReversal;
//      else
//        ssEvent                 = NewBreakout;
//    else
//    if (session[Asia].Event(NewTerm))
//      if (session[Daily].Fractal(ftTerm).Direction==session[Asia].Fractal(ftTerm).Direction)
//        ssEvent                 = NewConvergence;
//      else
//        if (IsChanged(ssConvergent,false))
//          ssEvent               = NewDivergence;
//        else
//          ssEvent               = NewReversal;
//
//    if (session[Daily].Fractal(ftTerm).Direction==session[Asia].Fractal(ftTerm).Direction)
//        if (IsChanged(ssConvergent,true))
//          ssEvent               = NewFractal;
//        
//
//    switch (ssEvent)
//    {
//      case NewReversal:     if (session[Asia].IsOpen())
//                              UpdateStrategy(Torpedo);
//                            else
//                            if (lead.Type()==Europe)
//                              UpdateStrategy(UTurn);
//                            else
//                              UpdateStrategy(Check);
//                            break;
//
//      case NewBreakout:     if (session[Asia].IsOpen())
//                              UpdateStrategy(Kamikaze);
//                            else
//                            if (lead.Type()==Europe)
//                              UpdateStrategy(TeaBreak);
//                            else
//                              UpdateStrategy(YanksGrab);
//                            break;
//                            
//      case NewConvergence:  if (session[Asia].IsOpen())
//                              UpdateStrategy(Reversi);
//                            else
//                              UpdateStrategy(Slant);
//                            break;
//      case NewDivergence:   UpdateStrategy(AsianScrew);
//                            break;
//
//      case NewFractal:      if (session[Asia].IsOpen())
//                              if (session[Daily].Fractal(ftTrend).Direction==session[Daily].Fractal(ftTerm).Direction)
//                                UpdateStrategy(Torpedo);
//                              else
//                                UpdateStrategy(Kamikaze);
//                            else
//                              UpdateStrategy(TeaBreak);
//                            break;
//
//      default:              UpdateStrategy(NoStrategy);
//                            break;
//                            
//    }
  }  
  
//+------------------------------------------------------------------+
//| ShortManagement - Manages short order positions, profit and risk |
//+------------------------------------------------------------------+
void ShortManagement(void)
  {

  }

//+------------------------------------------------------------------+
//| LongManagement - Manages long order positions, profit and risk   |
//+------------------------------------------------------------------+
void LongManagement(void)
  {

  }

//+------------------------------------------------------------------+
//| AssignActionManager - Assigns Action Manager and sets bounds     |
//+------------------------------------------------------------------+
void AssignActionManager(void)
  {
    static int aamManager    = OP_NO_ACTION;

  //--- Strategy Action
  //enum                StrategyAction
  //                    {
  //                      Capture,
  //                      FFE,
  //                      Spot,
  //                      Build,
  //                      Hold,
  //                      Halt,
  //                      StrategyActions
  //                    };

    if (IsChanged(aamManager,pfAction))
      switch (aamManager)
      {
        case OP_BUY:   
                       break;
        case OP_SELL:  
                       break;
        default:       
                       break;
      }
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (PauseOnHistory)
      if (pfractal.HistoryLoaded())
      {
        PauseOnHistory        = false;
        CallPause("PipMA History is now loaded",Always);
      }

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
       
    SetStrategy();

    AssignActionManager();
    
    LongManagement();
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
//| LoadManualOrder - Loads manual orders from the command interface |
//+------------------------------------------------------------------+
void LoadManualOrder(string &Order[])
  {
    static OrderRequest lmoRequest = {0,OP_NO_ACTION,"Manual",0,0,0,0,"",0,NoStatus};
    
    if (Order[1]=="REFRESH")
    {
      RefreshOrders();
      return;
    }
    if (ActionCode(Order[1])==OP_NO_ACTION)
    {
      Print("Error: Bad Action Type on order request");
      return;
    }
    
    if (Order[2]=="MARKET")
      Order[2]                    = "";
      
    lmoRequest.Action             = ActionCode(Order[1]+Order[2]);
    lmoRequest.Price              = StringToDouble(Order[3]);
    lmoRequest.Lots               = LotSize(StringToDouble(Order[4]));
    lmoRequest.Target             = StringToDouble(Order[5]);
    lmoRequest.Stop               = StringToDouble(Order[6]);
    lmoRequest.Expiry             = Time[0]+(Period()*StrToInteger(Order[7])*60);
    lmoRequest.Memo               = Order[8];

    OrderSubmit(lmoRequest);
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="ORDER")
      LoadManualOrder(Command);
      
    if (Command[0]=="PAUSE")
    {
      PauseOn                          = true;
      if (Command[1]=="HISTORY")
        PauseOnHistory                 = true;
      else
      if (Command[1]=="PRICE")
        PauseOnPrice                   = StringToDouble(Command[2]);
      else
      if (Command[1]=="")
        PauseOnHour                    = NoValue;
      else
      {
        PauseOnHour                    = (int)StringToInteger(Command[1]);
        Print("Pause on hour "+Command[1]+" enabled.");
      }
    }
      
    if (Command[0]=="PLAY")
      PauseOn                          = false;
    
    if (Command[0]=="SHOW")
      if (Command[1]=="LINES")
      {
         rsSession                     = SessionTypes;
         
         if (Command[2]=="DAILY")
           rsSession                   = Daily;
         else         
         if (Command[2]=="ASIA")
           rsSession                   = Asia;
         else         
         if (Command[2]=="US")
           rsSession                   = US;
         else         
         if (Command[2]=="EUROPE")
           rsSession                   = Europe;
         else         
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
      if (Command[1]=="PIPMA")
        SourceAlerts[indPipMA]         = false;
      else
      if (Command[1]=="FRACTAL")
        SourceAlerts[indFractal]       = false;
      else
      if (Command[1]=="SESSION")
        SourceAlerts[indSession]       = false;
      else
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
      if (Command[1]=="PIPMA")
        SourceAlerts[indPipMA]         = true;
      else
      if (Command[1]=="FRACTAL")
        SourceAlerts[indFractal]       = true;
      else
      if (Command[1]=="SESSION")
        SourceAlerts[indSession]       = true;
      else    
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

    while (AppCommand(otParams,9))
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
    
    omOrderKey            = new CArrayInteger(0);
    omOrderKey.Truncate   = false;
    omOrderKey.AutoExpand = true;    
    omOrderKey.Initialize(0.00);

    session[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
    
    NewPriceLabel("plbInterlaceHigh");
    NewPriceLabel("plbInterlaceLow");
    NewPriceLabel("plbInterlacePivotActive");
    NewPriceLabel("plbInterlacePivotInactive");

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
    
    NewLine("lnActive");
    NewLine("lnPrior");
    NewLine("lnOffSession");
    NewLine("lnCeiling");
    NewLine("lnFloor");
    NewLine("lnPivot");
    

    ArrayInitialize(Alerts,true);
    ArrayInitialize(SourceAlerts,true);

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

    //--- Initialize Fibo Management
    for (FractalType type=ftOrigin;type<FractalTypes;type++)
      anFiboDetail[type].Session = Daily;
      
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
    delete rsEvents;
    delete omWork;
    delete omOrderKey;
  }