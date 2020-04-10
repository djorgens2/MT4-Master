//+------------------------------------------------------------------+
//|                                                   dj-live-v8.mq4 |
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
#define   NoQueue        false

#include <manual.mqh>
#include <Class\Session.mqh>
#include <Class\PipFractal.mqh>
#include <Class\Fractal.mqh>
#include <Class\ArrayInteger.mqh>

  enum            MarginModel
                  {
                    Discount,
                    Premium,
                    FIFO
                  };
 
input string      AppHeader            = "";       //+---- Application Options -------+
input double      inpMarginTolerance   = 6.5;      // Margin drawdown factor 
input MarginModel inpMarginModel       = Discount; // Account type margin handling
input YesNoType   inpDisplayEvents     = Yes;      // Display event bar notes
input YesNoType   inpShowWaveSegs      = Yes;      // Display wave segment overlays

input string      FractalHeader        = "";    //+------ Fractal Options ---------+
input int         inpRangeMin          = 60;    // Minimum fractal pip range
input int         inpRangeMax          = 120;   // Maximum fractal pip range
input int         inpPeriodsLT         = 240;   // Long term regression periods

input string      RegressionHeader     = "";    //+------ Regression Options ------+
input int         inpDegree            = 6;     // Degree of poly regression
input int         inpSmoothFactor      = 3;     // MA Smoothing factor
input double      inpTolerance         = 0.5;   // Directional sensitivity
input int         inpPipPeriods        = 200;   // Trade analysis periods (PipMA)
input int         inpRegrPeriods       = 24;    // Trend analysis periods (RegrMA)

input string      SessionHeader        = "";    //+---- Session Hours -------+
input int         inpAsiaOpen          = 1;     // Asian market open hour
input int         inpAsiaClose         = 10;    // Asian market close hour
input int         inpEuropeOpen        = 8;     // Europe market open hour`
input int         inpEuropeClose       = 18;    // Europe market close hour
input int         inpUSOpen            = 14;    // US market open hour
input int         inpUSClose           = 23;    // US market close hour
input int         inpGMTOffset         = 0;     // GMT Offset


  //--- Class Objects
  CSession           *session[SessionTypes];
  CSession           *lead;
  CFractal           *fractal        = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal       = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,50);
  CEvent             *sEvent         = new CEvent();
  CEvent             *rsEvents       = new CEvent();
  
  //--- Fractal Sources
  enum                ViewPoint
                      {
                        Macro,
                        Meso,
                        Micro,
                        ViewPoints
                      };
                      
  //--- Technical Fractal Patterns
  enum                Pattern
                      {
                        TrendConvergent,
                        TrendDivergent,
                        TermConvergent,
                        TermDivergent
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

  //--- Major session fractal points                      
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

                      
  //--- Indicator (Data Source) types
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
         YanksGrab,     //-- Occurs on converging Asian/Daily Term reversing sessions while the Asian market is closed and US is the lead session
         Revolution,    //-- Occurs on converging Asian/Daily Trend reversing sessions while the US is the lead session
         TeaBreak,      //-- Occurs on converging Asian/Daily reversing sessions while the Asian market is closed and EU is the lead session
         Kamikaze,      //-- Occurs on converging Asian/Daily reversing sessions while the Asian market is open
         StrategyTypes
       };
       
  //--- Strategy text translations
  const string StrategyText[StrategyTypes] =
                      {
                        "No Strategy",
                        "Check",
                        "(ad) Asian Screw",
                        "(acr) U-Turn",
                        "(atc) Torpedo",
                        "(acr) Slant",
                        "(acr) Reversi",
                        "(ucr) Yanks Grab",
                        "(utc) Revolution",
                        "(bcr) Tea Break",
                        "(acr) Kamikaze"
                      };
                      
  //-- Pattern Text
  const string PatternText[4] =
                      {
                        "Trend Convergent",
                        "Trend Divergent",
                        "Term Convergent",
                        "Term Divergent"
                      };
                       
  //--- Collection Objects
  struct              SessionDetail 
                      {
                        int            ActiveDir;              //-- Active direction for monitoring changes
                        int            ActiveBias;             //-- Active Bias for monitoring changes
                        bool           Reversal;               //-- Used to identify outside reversal sessions
                        int            FractalDir;             //-- Used to identify breakout and reversal direction
                        bool           NewFractal;             //-- Noise reduction filter on fractal expansion
                        int            FractalHour;            //-- Last fractal hour within a day (NoValue==No Fractal)
                        int            FractalAge;             //-- Fractal age by session after a new fractal
                        double         BiasPivot[2];           //-- Most recent fractal pivot by Action
                        double         FractalPivot[2];        //-- Most recent fractal pivot by Action
                        int            HighHour;               //-- Daily high hour
                        int            LowHour;                //-- Daily low hour
                        double         Ceiling;                //-- Last session trading high
                        double         Floor;                  //-- Last session trading low
                        double         Pivot;                  //-- Last session pivot
                        double         Pitch;                  //-- On new fractal, track the pitch, static retention
                        bool           Alerts;                 //-- Noise reduction filter for alerts
                      };

  struct              OrderFiboData 
                      {
                        double         Price;                //-- Fibo pivot
                        double         Lots;                 //-- Most recent open price
                        double         Margin;               //-- Most recent profit price by Action
                        double         PivotDCA;             //-- Most recent DCA price by Action
                        double         NetValue;             //-- Position net value
                        bool           Trigger;              //-- Triggered fractal
                      };
                        
  struct              OrderDetail 
                      {
                        double         PivotOpen;            //-- Most recent open price
                        double         PivotProfit;          //-- Most recent profit price by Action
                        double         PivotDCA;             //-- Most recent DCA price by Action
                        double         PivotExit;            //-- Top of wane; Bottom of rise;
                        int            FiboLevelMin;         //-- Lowest fibo sequence off pivot
                        int            FiboLevelMax;         //-- Highest fibo sequence off pivot
                        OrderFiboData  FiboDetail[20];       //-- Detail order value by Fibo Level
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
  OrderDetail         fdetail[2];
  
  //--- Trade operationals
  
  //--- Order Manager operationals
  int                 omAction;
  OrderRequest        omQueue[];
  CArrayInteger      *omOrderKey;
  double              omMatrix[5][5];
  double              omInterlace[];
  double              omInterlacePivot[2];
  int                 omInterlaceDir;
  int                 omInterlaceBrkDir;
  double              omFractalPivot;
  AlertLevelType      omFractalAlert;
  CArrayDouble       *omWork;
  
  double              pfExpansion[10];
  int                 pfAction            = OP_NO_ACTION;

  //--- Analyst operationals
  StrategyType        anStrategy;
  Pattern             anPattern;
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
    UpdateLabel(roLabel+"Lots",DoubleToStr(LotSize(Order.Lots),ordLotPrecision),clrDarkGray);
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
    static bool rcpInitializeOnce[SessionTypes] = {true,true,true,true};

    if (sEvent.EventAlert(NewReversal,Warning))
      UpdateDirection("lbState",Direction(lead[ActiveSession].Bias,InAction),clrYellow,24);
    else
      UpdateDirection("lbState",Direction(lead[ActiveSession].Bias,InAction),Color(Direction(lead[ActiveSession].Bias,IN_ACTION)),24);

    UpdateLabel("lbAN-Strategy",StrategyText[anStrategy],clrDarkGray);
    UpdateLabel("lbAN:State",PatternText[anPattern]);
    
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
      
    string f1Head[7]  = {"Age","Bias","Long","Short"};
    string f2Val;

    for (SessionType type=0;type<SessionTypes;type++)
    {
      if (IsChanged(rcpInitializeOnce[type],false))
        UpdateBox("hdF"+EnumToString(type),Color(session[type].Fractal(ftTerm).Direction,IN_DARK_DIR));
      else
      if (detail[type].NewFractal)
        UpdateBox("hdF"+EnumToString(type),Color(detail[type].FractalDir,IN_DARK_DIR));

      for (int row=0;row<4;row++)
      {
        f2Val         = "lbF-"+f1Head[row]+":"+EnumToString(type);
        
        if (row==0)
          UpdateLabel(f2Val,(string)detail[type].FractalAge,clrDarkGray);
        else
          switch (row)
          {
            case 1:  UpdateLabel(f2Val+"-Diff",NegLPad(Pip(Close[0]-detail[type].BiasPivot[session[type][ActiveSession].Bias]),1),Color(Close[0]-detail[type].BiasPivot[session[type][ActiveSession].Bias]),12,"Consolas");
                     UpdateLabel(f2Val+"-Pivot",DoubleToStr(detail[type].BiasPivot[session[type][ActiveSession].Bias],Digits),Color(Close[0]-detail[type].BiasPivot[session[type][ActiveSession].Bias]));
                     break;
            case 2:  UpdateLabel(f2Val+"-Diff",NegLPad(Pip(Close[0]-detail[type].FractalPivot[OP_BUY]),1),Color(Close[0]-detail[type].FractalPivot[OP_BUY]),12,"Consolas");
                     UpdateLabel(f2Val+"-Pivot",DoubleToStr(detail[type].FractalPivot[OP_BUY],Digits),Color(Close[0]-detail[type].FractalPivot[OP_BUY]));
                     break;
            case 3:  UpdateLabel(f2Val+"-Diff",NegLPad(Pip(Close[0]-detail[type].FractalPivot[OP_SELL]),1),Color(Close[0]-detail[type].FractalPivot[OP_SELL]),12,"Consolas");
                     UpdateLabel(f2Val+"-Pivot",DoubleToStr(detail[type].FractalPivot[OP_SELL],Digits),Color(Close[0]-detail[type].FractalPivot[OP_SELL]));
                     break;
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
//| RefreshPitchLabels - sets the session type pitch labels          |
//+------------------------------------------------------------------+
void RefreshPitchLabels(void)
  {
    const color SessionColor[SessionTypes] =  {C'64,64,0',C'0,32,0',C'48,0,0',C'0,0,56'};
  
    if (sEvent[NewFractal]||sEvent[NewHour])
      for (SessionType type=0;type<SessionTypes;type++)
      {
        ObjectSet("plb"+EnumToString(type),OBJPROP_COLOR,SessionColor[type]);
        ObjectSet("plb"+EnumToString(type),OBJPROP_PRICE1,detail[type].Pitch);
        ObjectSet("plb"+EnumToString(type),OBJPROP_TIME1,Time[Bar]+(Period()*600));
      }
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "";
    string rsEvent     = "";

    ShowLines();
//    RefreshPitchLabels();
    
    rsComment          = "--BIAS--\n"+
                         "  Origin:  "+ActionText(session[Daily].Fractal(ftOrigin).Bias)+"\n"+
                         "  Trend:   "+ActionText(session[Daily].Fractal(ftTrend).Bias)+"\n"+
                         "  Term:    "+ActionText(session[Daily].Fractal(ftTerm).Bias)+"\n"+
                         "  Active:  "+ActionText(session[Daily][ActiveSession].Bias);
    if (inpShowWaveSegs==Yes)
    {
      pfractal.DrawWaveOverlays();
     
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
    
    if (SourceAlerts[indSession])
      for (SessionType show=Daily;show<SessionTypes;show++)
        if (detail[show].Alerts)
          for (EventType type=1;type<EventTypes;type++)
            if (Alerts[type]&&session[show].Event(type))
            {
              if (type==NewFractal)
              {
                if (detail[show].NewFractal)
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
//| UpdateOrders - Updates order detail stats by action              |
//+------------------------------------------------------------------+
void UpdateOrders(void)
  {

/*  
  struct              OrderFiboData 
                      {
                        double         Price;                //-- Fibo pivot
                        double         Lots;                 //-- Most recent open price
                        double         Margin;               //-- Most recent profit price by Action
                        double         PivotDCA;             //-- Most recent DCA price by Action
                        double         NetValue;             //-- Position net value
                        bool           Trigger;              //-- Triggered fractal
                      };
                        
  struct              OrderDetail 
                      {
                        double         PivotOpen;            //-- Most recent open price
                        double         PivotProfit;          //-- Most recent profit price by Action
                        double         PivotDCA;             //-- Most recent DCA price by Action
                        double         PivotExit;            //-- Top of wane; Bottom of rise;
                        OrderFiboData  FiboDetail[20];       //-- Detail order value by Fibo Level
                      };
*/
    int uoAction                       = OP_NO_ACTION;
    
    for (int ord=0;ord<ArraySize(ordClose);ord++)
      fdetail[ordClose[ord].Action].PivotProfit  = ordClose[ord].Price;
      
    if (detail[Daily].NewFractal)
    {
      uoAction                         = Action(detail[Daily].FractalDir,InDirection,InContrarian);
      
      for (int fibo=-Fibo823;fibo<Fibo823;fibo++)
        fdetail[uoAction].FiboDetail[FiboLevel(FiboExt(fibo))].Price
                                       = detail[Daily].FractalPivot[uoAction]+Pip(FiboLevels[fibo]*100,InPoints);
                                       
        Print ((string)FiboExt(fibo)+":"+DoubleToStr(fdetail[uoAction].FiboDetail[FiboLevel(FiboExt(fibo))].Price,Digits));
      }
  }

//+------------------------------------------------------------------+
//| UpdateSession - Process and consolidate Session data **FIRST**   |
//+------------------------------------------------------------------+
void UpdateSession(void)
  {    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      session[type].Update();
      
      if (session[type].IsOpen())
        lead             = session[type];

      if (session[type].Event(NewDay))
      {
        detail[type].FractalDir      = DirectionNone;
        detail[type].Reversal        = false;
        detail[type].HighHour        = ServerHour();
        detail[type].LowHour         = ServerHour();
        detail[type].FractalHour     = NoValue;

        sEvent.SetEvent(NewDay);    
      }
    
      //-- Clear event flags
      detail[type].ActiveDir         = Direction(session[type].Pivot(ActiveSession)-session[type].Pivot(PriorSession));
      detail[type].NewFractal        = false;
      detail[type].FractalAge        = session[type].Age();

      //-- Set Session Notification Events
      if (session[type].Event(SessionOpen))
      {          
        detail[type].Ceiling         = session[type][PriorSession].High;
        detail[type].Floor           = session[type][PriorSession].Low;
        detail[type].Pivot           = session[type].Pivot(PriorSession);
        
        sEvent.SetEvent(SessionOpen);
      }
        
      if (session[type].Event(NewHour))
        sEvent.SetEvent(NewHour);

      //-- Evaluate and Set Session Fractal Events
      if (session[type].Event(NewFractal))
      {
        detail[type].Pitch           = fdiv(session[type][ActiveSession].High+session[type][ActiveSession].Low,2);

        if (NewDirection(detail[type].FractalDir,session[type].Fractal(ftTerm).Direction))
          detail[type].Reversal      = true;

        if (IsChanged(detail[type].FractalHour,ServerHour()))
        {
          detail[type].NewFractal    = true;
          detail[type].FractalPivot[Action(detail[type].FractalDir,InDirection)] = Close[0];
        }
        
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
        detail[type].HighHour        = ServerHour();
        sEvent.SetEvent(NewHigh);
      }

      if (session[type].Event(NewLow))
      {
        detail[type].LowHour         = ServerHour();
        sEvent.SetEvent(NewLow);
      }

      if (session[type].Event(NewBias))
        detail[type].BiasPivot[session[type][ActiveSession].Bias] = Close[0];
    }
  }

//+------------------------------------------------------------------+
//| UpdatePipMA - Process PipMA data and prepare recommendations     |
//+------------------------------------------------------------------+
void UpdatePipMA(void)
  {
    double ppmaPrice[5];
    
    pfractal.Update();
    
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

//    pfractal.ShowFiboArrow();
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Process and prepare fractal data                 |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {
    fractal.Update();
    
    if (fractal.Event(NewFractal))
    {
      omFractalPivot                     = Close[0];
      omFractalAlert                     = fractal.HighAlert() ; 
    }

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
//| OrderApproved - Performs health and sanity checks for approval   |
//+------------------------------------------------------------------+
bool OrderApproved(OrderRequest &Order)
  {
    double oaLots[6]                           = {0.00,0.00,0.00,0.00,0.00,0.00};
    double oaMargin                            = 0.00;
    double oaMarginReq                         = BoolToDouble(Symbol()=="USDJPY",(ordAcctLotSize*ordAcctMinLot)/AccountLeverage(),
                                                              ((ordAcctLotSize*ordAcctMinLot)*Close[0])/AccountLeverage())*100;
    
    if (TradingOn)
    {      
      oaLots[OP_BUY]                           = LotCount(OP_BUY);
      oaLots[OP_SELL]                          = LotCount(OP_SELL);
      oaLots[Action(Order.Action,InAction)]   += LotSize(Order.Lots);

      if (Order.Status==Pending)
      {
        for (int ord=0;ord<ArraySize(omQueue);ord++)
          if (omQueue[ord].Status==Pending)
            oaLots[omQueue[ord].Action]       += LotSize(omQueue[ord].Lots);

        oaLots[Action(Order.Action,InAction)] += oaLots[Order.Action];
      }
      
      switch (inpMarginModel)
      {
        case Discount:       //-- FX Choice                             
                             oaMargin = (((fdiv(fmin(oaLots[OP_BUY],oaLots[OP_SELL]),2,ordLotPrecision)+fabs(oaLots[OP_BUY]-oaLots[OP_SELL]))*oaMarginReq)/AccountEquity())*100;
                             break;
        case Premium:        //-- FXCM
                             oaMargin = ((fmax(oaLots[OP_BUY],oaLots[OP_SELL])*oaMarginReq)/AccountEquity())*100;
                             break;
        case FIFO:           //-- Forex.com
                             oaMargin = ((oaLots[Action(Order.Action,InAction)]*oaMarginReq)/AccountEquity())*100;
                             break;        
      }

      if (oaMargin<=(ordEQMaxRisk+inpMarginTolerance))
      {
        Order.Status         = Approved;
        return (true);
      }
      else
        Order.Memo           = "Margin limit exceeded. ("+DoubleToStr(oaMargin,1)+")";
    }
    else
      Order.Memo             = "Trading is not enabled.";

    Order.Status             = Declined;
    return (false);
  }

//+------------------------------------------------------------------+
//| OrderProcessed - Executes orders from the order manager          |
//+------------------------------------------------------------------+
bool OrderProcessed(OrderRequest &Order)
  {
    if (OpenOrder(Action(Order.Action,InAction),Order.Requestor+":"+Order.Memo,LotSize(Order.Lots)))
    {
      UpdateTicket(ordOpen.Ticket,Order.Target,Order.Stop);

      Order.Key                      = ordOpen.Ticket;
      Order.Price                    = ordOpen.Price;
      Order.Lots                     = LotSize(Order.Lots);
      
      fdetail[Order.Action].PivotOpen  = Order.Price;
      
      return (true);
    }
    
    Order.Memo                       = ordOpen.Reason;
    
    return (false);
  }
  
//+------------------------------------------------------------------+
//| OrderCancel - Cancels pending orders by Action                   |
//+------------------------------------------------------------------+
void OrderCancel(int Action, string Reason="")
  {
    for (int request=0;request<ArraySize(omQueue);request++)
      if (omQueue[request].Status==Pending)
        if (omQueue[request].Action==Action||((Action==OP_BUY||Action==OP_SELL)&&(Action(omQueue[request].Action,InAction)==Action)))
        {
          omQueue[request].Status   = Canceled;
          omQueue[request].Expiry   = Time[0]+(Period()*60);

          if (Reason!="")
            omQueue[request].Memo        = Reason;
              
          RefreshOrders();
        }
  }

//+------------------------------------------------------------------+
//| OrderCancel - Cancels pending orders by Request                  |
//+------------------------------------------------------------------+
void OrderCancel(OrderRequest &Order, string Reason="")
  {
    if (Order.Status==Pending)
    {
      Order.Status            = Canceled;
      Order.Expiry            = Time[0]+(Period()*60);
      
      if (Reason!="")
        Order.Memo            = Reason;
              
      RefreshOrders();
    }
  }

//+------------------------------------------------------------------+
//| OrderSubmit - Manages short order positions, profit and risk     |
//+------------------------------------------------------------------+
void OrderSubmit(OrderRequest &Order, bool QueueOrders)
  {
    while (OrderApproved(Order))
    {
      Order.Key                = omOrderKey.Count;
      Order.Status             = Pending;
    
      omOrderKey.Add(ArraySize(omQueue));
      ArrayResize(omQueue,omOrderKey[Order.Key]+1);
      omQueue[Order.Key]     = Order;
      
      if (QueueOrders)
        Order.Price         += Pip(ordEQLotFactor,InDecimal)*Direction(Order.Action,IN_ACTION,Order.Action==OP_BUYLIMIT||Order.Action==OP_SELLLIMIT);
      else break;
    }

    RefreshOrders();
  }
   
//+------------------------------------------------------------------+
//| OrderProcessing - Manages the order cycle                        |
//+------------------------------------------------------------------+
void OrderProcessing(void)
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
                                  omQueue[request].Status    = Immediate;
                                break;
          case OP_BUYLIMIT:     if (Ask<=omQueue[request].Price)
                                  omQueue[request].Status    = Immediate;
                                break;
          case OP_SELL:         omQueue[request].Status      = Immediate;
                                break;
          case OP_SELLSTOP:     if (Bid<=omQueue[request].Price)
                                  omQueue[request].Status    = Immediate;
                                break;
          case OP_SELLLIMIT:    if (Bid>=omQueue[request].Price)
                                  omQueue[request].Status    = Immediate;
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
      {
        omRefreshQueue                   = true;
        omQueue[request].Expiry          = Time[0]+(Period()*60);
      }
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
            UpdateBarNote(usBarNote,session[Asia][ActiveSession].High,clrWhite);
          
          if (session[Asia].Event(NewLow)&&usLiveEventDir==DirectionDown)
            UpdateBarNote(usBarNote,session[Asia][ActiveSession].Low,clrWhite);
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
    if (session[Daily].Event(NewTerm)||session[Asia].Event(NewTerm))
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
    //-- Short term rally/pullback -- look for contrarian openings
    static bool tcConvergent   = false;

    anPattern     = TermConvergent;
    
    if (IsChanged(tcConvergent,CheckConvergence(tcConvergent)))
    {
      //-- Handle new convergence
      switch (lead.Type())
      {
        case Asia:    
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

    anPattern     = TermDivergent;
        
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
    
    anPattern     = TrendConvergent;
    
    if (IsChanged(tcConvergent,CheckConvergence(tcConvergent)))
    {
      //-- Handle new convergence
      switch (lead.Type())
      {
        case Asia:    
        case Europe:  if (session[Asia].IsOpen())
                        return (Torpedo);
                      return (TeaBreak);
        case US:      return (Revolution);
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

    anPattern     = TrendDivergent;

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
  }  
  
//+------------------------------------------------------------------+
//| Balance - Manages short order positions, profit and risk         |
//+------------------------------------------------------------------+
void Balance(EventType Event, SessionType Session=Daily)
  {
    switch (Event)
    {
      case NewWaveReversal:  //NewBarNote("Reversal(w)",Color(pfAction,IN_CHART_ACTION));
                             break;
      case NewReversal:      NewBarNote("Reversal("+EnumToString(Session)+")",Color(pfAction,IN_CHART_ACTION));
                             break;
      case NewFractal:       NewBarNote("Fractal("+EnumToString(Session)+")",Color(detail[Daily].FractalDir,IN_CHART_DIR));
                             break;
      case NewBias:          NewBarNote("Bias("+EnumToString(Session)+")",Color(detail[Daily].FractalDir,IN_CHART_DIR));
                             break;
      case NewOrigin:        NewBarNote("Origin ("+EnumToString(Session)+")",Color(detail[Daily].FractalDir,IN_CHART_DIR));
                             break;
    };
  }

//+------------------------------------------------------------------+
//| ShortManagement - Manages short order positions, profit and risk |
//+------------------------------------------------------------------+
void ShortManagement(void)
  {
    static OrderRequest smRequest = {0,OP_NO_ACTION,"Mgr:Short",0,0,0,0,"",0,NoStatus};
    static ActionState  smState   = Halt;
    static bool         smOpTrig  = false;
    
    if (pfractal.Event(NewWaveOpen))
      smOpTrig                                = true;

    if (IsChanged(smState,pfractal.ActionState(OP_SELL)))
      switch (smState)
      {
        case Opportunity: if (IsChanged(smOpTrig,false))
                          {
                            smRequest.Action    = OP_SELL;
                            smRequest.Memo      = "Opportunity";
                            smRequest.Expiry    = Time[0]+(Period()*60);
                            OrderSubmit(smRequest,NoQueue);
                          }
      }
      
//      Pause("Action State changed to "+EnumToString(smState),"Short Manager Action Change");
//    //--- First: Check for balancing events
//    if (pfractal.Event(NewWaveReversal))
//      Balance(NewWaveReversal);
//      
    if (session[Daily].Event(NewBias))
      Balance(NewBias);

//    if (detail[Asia].NewBias)
//      Balance(NewBias,Asia);
//
//    if (detail[Daily].NewFractal)
//      Balance(NewFractal);
//
//    if (session[Daily].Event(NewOrigin))
//      Balance(NewOrigin);
    
      if (fractal.Event(NewFractal));
      
  }

//+------------------------------------------------------------------+
//| LongManagement - Manages long order positions, profit and risk   |
//+------------------------------------------------------------------+
void LongManagement(void)
  {

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

    LongManagement();
    ShortManagement();
    OrderProcessing();
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

    if (ActionCode(Order[2])==OP_NO_ACTION)
    {
      Print("Error: Bad Action Type on order request");
      return;
    }

    if (Order[1]=="CANCEL")
      OrderCancel(ActionCode(Order[2]),Order[3]);
    else
    if (Order[1]=="OPEN"||Order[1]=="QUEUE")
    {
      lmoRequest.Action           = ActionCode(Order[2]);
      lmoRequest.Price            = StringToDouble(Order[3]);
      lmoRequest.Lots             = StringToDouble(Order[4]);
      lmoRequest.Target           = StringToDouble(Order[5]);
      lmoRequest.Stop             = StringToDouble(Order[6]);
      lmoRequest.Expiry           = Time[0]+(Period()*StrToInteger(Order[7])*60);
      lmoRequest.Memo             = Order[8];

      OrderSubmit(lmoRequest,Order[1]=="QUEUE");
    }
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
      if (Command[1]=="ALERTS")
        ArrayInitialize(Alerts,false);
      else
      if (Command[1]=="ALL")  
      {
        SourceAlerts[indPipMA]         = false;
        SourceAlerts[indFractal]       = false;
        SourceAlerts[indSession]       = false;
      
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
      if (Command[1]=="ALERTS")
        ArrayInitialize(Alerts,true);
      else
      if (Command[1]=="ALL")
      {
        SourceAlerts[indPipMA]         = true;
        SourceAlerts[indFractal]       = true;
        SourceAlerts[indSession]       = true;
      
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

    //--- Update, analyze & prepare data
    UpdateOrders();
    UpdateSession();
    UpdatePipMA();
    UpdateFractal();    

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

    for (SessionType type=0;type<SessionTypes;type++)
      NewPriceLabel("plb"+EnumToString(type));

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
      detail[type].ActiveDir              = DirectionNone;
      detail[type].ActiveBias             = OP_NO_ACTION;
      detail[type].FractalDir             = DirectionNone;
      detail[type].FractalHour            = NoValue;
      detail[type].FractalAge             = NoValue;
      detail[type].FractalPivot[OP_SELL]  = session[type][PriorSession].Low;
      detail[type].FractalPivot[OP_BUY]   = session[type][PriorSession].High;
      detail[type].BiasPivot[OP_BUY]      = Close[0];
      detail[type].BiasPivot[OP_SELL]     = Close[0];
      detail[type].Reversal               = false;
      detail[type].Alerts                 = true;
    }

    ArrayInitialize(omInterlacePivot,Close[0]);
    
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