//+------------------------------------------------------------------+
//|                                                   dj-live-v8.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "8.00"
#property strict

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
input YesNoType   inpShowWaveSegs      = Yes;      // Display wave segment overlays
input YesNoType   inpShowFiboFlags     = Yes;      // Display Fractal Fibo Events

input string      FractalHeader        = "";    //+------ Fractal Options ---------+
input int         inpRangeMin          = 60;    // Minimum fractal pip range
input int         inpRangeMax          = 120;   // Maximum fractal pip range

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
  CEvent             *rsEvents       = new CEvent();
  
  //--- Position Actions
  enum                ActionType
                      {
                        Idle,
                        Recover,
                        Deposit,
                        Create,
                        Retain,
                        ActionTypes
                      };

  //--- Major session fractal points
  enum                FibonacciPoint
                      {
                        fpTarget,
                        fpYield,
                        fpLoad,
                        fpBalance,
                        fpRisk,
                        fpHalt,
                        FibonacciPoints
                      };

  enum                FractalElement
                      {
                        feOrigin,
                        feTrend,
                        feTerm,
                        fePrior,
                        feRoot,
                        feBase,
                        feExpansion,
                        feMajor,
                        feMinor,
                        feRetrace,
                        FractalElements
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

  //--- Indicator (Data Source) types
  enum                SourceType
                      {
                        indFractal,
                        indPipMA,
                        indSession,
                        SourceTypes
                      };

  //-- Pattern Text
  const string PatternText[4] =
                      {
                        "Trend Convergent",
                        "Trend Divergent",
                        "Term Convergent",
                        "Term Divergent"
                      };
                       
  //-- Segment Text
  const string SegmentText[5] =
                      {
                        "Long",
                        "Short",
                        "Crest",
                        "Trough",
                        "Decay"
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
                        int            Zone;                   //-- Action relative to prior session
                        double         Ceiling;                //-- Last session trading high
                        double         Floor;                  //-- Last session trading low
                        double         Pivot;                  //-- Last session pivot
                        double         Pitch;                  //-- On new fractal, track the pitch, static retention
                        bool           Alerts;                 //-- Noise reduction filter for alerts
                      };

  struct              OrderDetail 
                      {
                        double         Lots;                 //-- Lots by Pos, Neg, Net
                        double         Margin;               //-- Margin by Pos, Neg, Net
                        double         Equity;               //-- Equity by Pos, Neg, Net
                        double         Value;                //-- Order value by Pos, Neg, Net
                      };

  struct              ZoneDetail 
                      {
                        int            Ticket;               //-- Order Ticket# (Non-Aggregate)/Count (Aggregate);
                        double         Price;                //-- Order Open Price/Fibo pivot
                        double         Lots;                 //-- Order Lots/Zone Lots
                        double         Margin;               //-- Order Margin (Raw)/Zone Margin (Aggregate);
                        double         Value;                //-- Order net value/Zone Value (Aggregate);
                        int            ActiveDir;            //-- Action Flag/Triggered fractal
                      };
                        
  struct              OrderMaster
                      {
                        bool           Trigger;              //-- Conditional order trigger
                        ActionType     Action;               //-- Positional Strategy
                        double         OrderOpen;            //-- Most recent open price
                        double         OrderClose;           //-- Most recent close price
                        double         DCA;                  //-- Most recent DCA price
                        double         Entry;                //-- Manager entry pivot
                        double         Exit;                 //-- Manager exit pivot
                        double         Support;              //-- Manager entry pivot
                        double         Resistance;           //-- Manager exit pivot
                        double         Target;               //-- Order Take Profit target pivot
                        int            Fibo;                 //-- The current Fibo Level
                        ZoneDetail     Zone[20];             //-- Aggregate order detail by zone
                        ZoneDetail     Line[];               //-- Line item order detail by action
                        OrderDetail    Detail[Total];        //-- Positional value by Pos, Neg, Net
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
  FractalType         rsFractal           = FractalTypes;
  int                 rsWaveAction        = OP_BUY;
  int                 rsSegment           = NoValue;
  int                 rsZone              = OP_NO_ACTION;
  bool                rsShowFlags         = false;
    
  //--- Operational config elements
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
  SessionType         master;
  int                 sFractalBias        = 0;
  int                 sFractalChange      = 0;
  Pattern             sFractalPattern;
  SessionType         sFractalSession     = SessionTypes;
  
  //--- PipFractal operationals
  double              pfExpansion[10];
  int                 pfAction            = OP_NO_ACTION;
  
  //--- Order Manager operationals
  OrderRequest        omQueue[];
  CArrayInteger      *omOrderKey;
  OrderMaster         omMaster[2];
  OrderDetail         omTotal;
  
  //--- Analyst operationals
  double              anMatrix[5][5];
  double              anInterlace[];
  double              anInterlacePivot[2];
  int                 anInterlaceDir;
  int                 anInterlaceBrkDir;
  CArrayDouble       *anWork;
    
  double              anFractal[3][FibonacciPoints];
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
//| IsChanged - Detects changes to fractal types                     |
//+------------------------------------------------------------------+
bool IsChanged(FractalType &Compare, FractalType Value)
  {
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
    UpdateLabel(roLabel+"Lots",DoubleToStr(OrderLotSize(Order.Lots),ordLotPrecision),clrDarkGray);
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
    string rcpOptions   = "";
    
    if (rsSession!=SessionTypes)  Append(rcpOptions,EnumToString(rsSession));
    if (rsFractal!=FractalTypes)  Append(rcpOptions,StringSubstr(EnumToString(rsFractal),2));
    if (rsWaveAction>NoValue)     Append(rcpOptions,"Wave "+SegmentText[rsWaveAction]);
    if (rsSegment>NoValue)        Append(rcpOptions,"Segment "+SegmentText[rsSegment]);
    if (rsZone>NoValue)           Append(rcpOptions,"Zone "+SegmentText[rsZone]);
    
    if (StringLen(rcpOptions)>1)
      rcpOptions                  = "  Lines: "+rcpOptions;
    
    UpdateDirection("lbState",Direction(lead[ActiveSession].Bias,InAction),Color(Direction(lead[ActiveSession].Bias,IN_ACTION)),24);

    UpdateLabel("lbAN-Options",rsShow+rcpOptions,clrDarkGray);
    UpdateLabel("lbAN-Strategy",PatternText[sFractalPattern]+" ("+EnumToString(sFractalSession)+")  "+(string)sFractalBias+":"+(string)sFractalChange,clrDarkGray);
    UpdateLabel("lbAN:State",PatternText[sFractalPattern]);
    
    UpdateLabel("lbPlanBUY",EnumToString(pfractal.Wave().State),BoolToInt(omMaster[OP_BUY].Trigger,clrYellow,clrDarkGray));
    UpdateLabel("lbPlanSELL",EnumToString(pfractal.Wave().State),BoolToInt(omMaster[OP_SELL].Trigger,clrYellow,clrDarkGray));
        
    if (ObjectGet("hdLong",OBJPROP_BGCOLOR)==clrBoxOff||pfractal.Event(NewWaveReversal))
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
    
    if (ObjectGet("hdCrest",OBJPROP_BGCOLOR)==clrBoxOff||pfractal.Event(NewWaveOpen))
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
                      
    UpdateLabel("lbIntDev",NegLPad(Pip(Close[0]-anInterlacePivot[Action(anInterlaceBrkDir,InDirection)]),1),
                            Color(Close[0]-anInterlacePivot[Action(anInterlaceBrkDir,InDirection)]),20);
    
    UpdateLabel("lbIntPivot",DoubleToStr(anInterlacePivot[Action(anInterlaceBrkDir,InDirection)],Digits),clrDarkGray);
    UpdateDirection("lbIntBrkDir",anInterlaceBrkDir,Color(anInterlaceBrkDir),28);
    UpdateDirection("lbIntDir",anInterlaceDir,Color(anInterlaceDir),12);

    UpdateLabel("lbLongState",EnumToString(pfractal.ActionState(OP_BUY)),DirColor(pfractal.ActiveSegment().Direction));                     
    UpdateLabel("lbShortState",EnumToString(pfractal.ActionState(OP_SELL)),DirColor(pfractal.ActiveSegment().Direction));
        
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
        UpdateLabel("lb"+colHead[col]+(string)row,DoubleToStr(anMatrix[col][row],Digits),Color(anMatrix[col][row],IN_PROXIMITY));

    for (int row=0;row<25;row++)
      if (row<ArraySize(anInterlace))
        UpdateLabel("lbInterlace"+(string)row,DoubleToStr(anInterlace[row],Digits),Color(anInterlace[row],IN_PROXIMITY));
      else
        UpdateLabel("lbInterlace"+(string)row,"");

    for (ActionState row=Bank;row<Hold;row++)
      for (int col=OP_BUY;col<=OP_SELL;col++)
        UpdateLabel("lbPL"+(string)col+":"+(string)row,DoubleToStr(pfractal.ActionLine(col,row),Digits),Color(pfractal.ActionLine(col,row),IN_PROXIMITY));

    UpdateBox("hdInterlace",Color(anInterlaceDir,IN_DARK_DIR));
    UpdateLabel("lbLongNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(OP_BUY).Retrace-pfractal.WaveSegment(OP_BUY).High),1),clrRed);    
    UpdateLabel("lbShortNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(OP_SELL).Low-pfractal.WaveSegment(OP_SELL).Retrace),1),clrLawnGreen);    
    UpdateLabel("lbCrestNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Crest).Retrace-pfractal.WaveSegment(Crest).High),1),clrRed);
    UpdateLabel("lbTroughNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Trough).Low-pfractal.WaveSegment(Trough).Retrace),1),clrLawnGreen);    

    if (pfractal.WaveSegment(Last).Type==Crest)
      UpdateLabel("lbDecayNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Decay).Retrace-pfractal.WaveSegment(Decay).High),1),clrRed);

    if (pfractal.WaveSegment(Last).Type==Trough)
      UpdateLabel("lbDecayNetRetrace",DoubleToStr(Pip(pfractal.WaveSegment(Decay).Low-pfractal.WaveSegment(Decay).Retrace),1),clrLawnGreen);
    
    string colFiboHead   = "";
    
    for (FibonacciPoint row=0;row<FibonacciPoints;row++)
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
      if (ObjectGet("hdF"+EnumToString(type),OBJPROP_BGCOLOR)==C'60,60,60'||detail[type].NewFractal||session[type].Event(NewHour))
      {
        UpdateBox("hdF"+EnumToString(type),Color(session[type].Fractal(ftTerm).Direction,IN_DARK_DIR));
        UpdateBox("hdB"+EnumToString(type),BoolToInt(session[type].IsOpen(),clrYellow,clrBoxOff));
      }
        
      for (int row=0;row<4;row++)
      {
        f2Val         = "lbF-"+f1Head[row]+":"+EnumToString(type);
        
        if (row==0)
          UpdateLabel(f2Val,(string)detail[type].FractalAge+"/"+ActionText(detail[type].Zone),clrDarkGray);
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
    
    int    fibo[2]   = {-Fibo823,-Fibo823};
    string field     = "";
    string keys[5]   = {"F","#","L","V","M"};
    
    UpdateLabel("lbSum-Bal","$"+LPad(DoubleToStr(AccountBalance()+AccountCredit(),0)," ",10),Color(omTotal.Equity),15,"Consolas");
    UpdateLabel("lbSum-Eq","$"+LPad(NegLPad(omTotal.Value,0)," ",10),Color(omTotal.Equity),15,"Consolas");
    UpdateLabel("lbSum-EqBal","$"+LPad(DoubleToStr(AccountEquity(),0)," ",10),Color(omTotal.Equity),15,"Consolas");
    UpdateLabel("lbSum-NetMarg",LPad(DoubleToStr(omTotal.Margin*100,1)," ",5)+"%",Color(omTotal.Equity),13,"Consolas");
    UpdateLabel("lbSum-NetLots",LPad(DoubleToStr(omTotal.Lots,ordLotPrecision)," ",7),Color(omTotal.Lots),13,"Consolas");
     
    UpdateLabel("lbSum-Eq%",LPad(NegLPad(omTotal.Equity*100,1)," ",6)+"%",Color(omTotal.Equity),13,"Consolas");
    UpdateLabel("lbSum-Spread",LPad(DoubleToStr(Pip(Ask-Bid),1)," ",5),Color(omTotal.Equity),13,"Consolas");
    
    for (int row=0;row<12;row++)
      for (int col=0;col<=OP_SELL;col++)
      {
        field  = "lbO-"+ActionText(col)+(string)row;
        
        for (int cols=0;cols<5;cols++)
          UpdateLabel(field+keys[cols],"");

        while (fibo[col]<=Fibo823 && omMaster[col].Zone[FiboExt(fibo[col])].Ticket==0)
          fibo[col]++;
      
        if (fibo[col]<=Fibo823)
        {
          color val = Color(omMaster[col].Zone[FiboExt(fibo[col])].Value);
          
          UpdateLabel(field+keys[0],LPad(DoubleToStr(FiboLevels[fabs(fibo[col])]*Direction(fibo[col])*100,1)+"%"," ",7),val);
          UpdateLabel(field+keys[1],LPad((string)omMaster[col].Zone[FiboExt(fibo[col])].Ticket," ",2),val,9,"Consolas");
          UpdateLabel(field+keys[2],LPad(DoubleToStr(omMaster[col].Zone[FiboExt(fibo[col])].Lots,ordLotPrecision)," ",6),val,9,"Consolas");
          UpdateLabel(field+keys[3],"$"+LPad(DoubleToStr(omMaster[col].Zone[FiboExt(fibo[col])].Value,0)," ",11),val,9,"Consolas");
          UpdateLabel(field+keys[4],LPad(DoubleToStr(omMaster[col].Zone[FiboExt(fibo[col])].Margin,1)," ",7),val,9,"Consolas");

          fibo[col]++;
        }
      }
  }

//+------------------------------------------------------------------+
//| ShowZoneLines - Diaplay zone lines                               |
//+------------------------------------------------------------------+
void ShowZoneLines(void)
  {
    static int szlZone       = OP_NO_ACTION;

    if (IsChanged(szlZone,rsZone)||detail[Daily].NewFractal)
      for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
        UpdateLine("lnZone:"+DoubleToStr(FiboLevels[fabs(fibo)]*Direction(fibo)*100,1),
          omMaster[rsZone].Zone[FiboExt(fibo)].Price,
          BoolToInt(omMaster[szlZone].Zone[FiboExt(fibo)].ActiveDir==DirectionNone,STYLE_DOT,STYLE_SOLID),
          BoolToInt(fibo==0,clrYellow,Color(fibo,IN_DARK_DIR)));
          
    UpdatePriceLabel("lbSEntry",omMaster[szlZone].Entry);
    UpdatePriceLabel("lbSExit",omMaster[szlZone].Exit);
  }
  
//+------------------------------------------------------------------+
//| ZeroPriceTags - Resets price tags to zero                        |
//+------------------------------------------------------------------+
void ZeroPriceTags(void)
  {
      UpdatePriceLabel("plbInterlaceHigh",0.00,clrYellow);
      UpdatePriceLabel("plbInterlaceLow",0.00,clrYellow);
    
      UpdatePriceLabel("plbInterlacePivotActive",0.00,clrDarkGray);
      UpdatePriceLabel("plbInterlacePivotInactive",0.00,clrDarkGray);
  }

//+------------------------------------------------------------------+
//| ZeroLines - Set displayed lines to zero                          |
//+------------------------------------------------------------------+
void ZeroLines(void)
  {
    static int         zlAction       = OP_NO_ACTION;
    static int         zlZone         = OP_NO_ACTION;
    static SessionType zlSession      = SessionTypes;
    static FractalType zlFractal      = FractalTypes;
    
    if (IsChanged(zlSession,rsSession)||IsChanged(zlFractal,rsFractal))
    {
      rsWaveAction                    = OP_NO_ACTION;
      
      ZeroPriceTags();
      
      UpdateLine("lnActive",0.00);
      UpdateLine("lnPrior",0.00);
      UpdateLine("lnOffSession",0.00);
      UpdateLine("lnCeiling",0.00);
      UpdateLine("lnFloor",0.00);
      UpdateLine("lnPivot",0.00);
      
      UpdateLine("lnHigh",0.00);
      UpdateLine("lnLow",0.00);
      UpdateLine("lnSupport",0.00);
      UpdateLine("lnResistance",0.00);
      UpdateLine("lnCorrectionHi",0.00);
      UpdateLine("lnCorrectionLo",0.00);
    }

    if (IsChanged(zlAction,rsWaveAction)||pfractal.Event(NewWaveReversal))
    {
      ZeroPriceTags();

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
      
      UpdatePriceLabel("plbInterlaceHigh",0.00);
      UpdatePriceLabel("plbInterlaceLow",0.00);
      UpdatePriceLabel("plbInterlacePivotActive",0.00);
      UpdatePriceLabel("plbInterlacePivotInactive",0.00);
    }
    
    if (IsChanged(zlZone,rsZone))
    {
      ZeroPriceTags();

      for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
        UpdateLine("lnZone:"+DoubleToStr(FiboLevels[fabs(fibo)]*Direction(fibo)*100,1),0.00);

      UpdatePriceLabel("lbSEntry",0.00);
      UpdatePriceLabel("lbSExit",0.0);
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
      
      if (rsFractal!=FractalTypes)
      {
        UpdateLine("lnSupport",session[rsSession].Fractal(rsFractal).Support,STYLE_SOLID,clrRed);
        UpdateLine("lnResistance",session[rsSession].Fractal(rsFractal).Resistance,STYLE_SOLID,clrLawnGreen);
        UpdateLine("lnLow",session[rsSession].Fractal(rsFractal).Low,STYLE_DOT,clrFireBrick);
        UpdateLine("lnHigh",session[rsSession].Fractal(rsFractal).High,STYLE_DOT,clrForestGreen);
      
        UpdateLine("lnCorrectionHi",session[rsSession].Fractal(ftCorrection).High,STYLE_DASH,clrWhite);
        UpdateLine("lnCorrectionLo",session[rsSession].Fractal(ftCorrection).Low,STYLE_DASH,clrWhite);
      }
      else
      {
        UpdateLine("lnPrior",session[rsSession].Pivot(PriorSession),STYLE_DOT,Color(session[rsSession].Pivot(PriorSession),IN_PROXIMITY));
        UpdateLine("lnOffSession",session[rsSession].Pivot(OffSession),STYLE_SOLID,clrGoldenrod);

        UpdateLine("lnCeiling",detail[Asia].Ceiling,STYLE_DOT,clrDarkGreen);
        UpdateLine("lnFloor",detail[Asia].Floor,STYLE_DOT,clrMaroon);
        UpdateLine("lnPivot",detail[Asia].Pivot,STYLE_DOT,clrDarkBlue);
      }
    }
    else    
    if (rsZone==OP_NO_ACTION)
    {
      UpdatePriceLabel("plbInterlaceHigh",anInterlace[0],clrYellow);
      UpdatePriceLabel("plbInterlaceLow",anInterlace[ArraySize(anInterlace)-1],clrYellow);
    
      if (anInterlaceBrkDir==DirectionUp)
      {
        UpdatePriceLabel("plbInterlacePivotActive",anInterlacePivot[OP_BUY],clrLawnGreen);
        UpdatePriceLabel("plbInterlacePivotInactive",anInterlacePivot[OP_SELL],clrDarkGray);
      }
      else
      if (anInterlaceBrkDir==DirectionDown)
      {
        UpdatePriceLabel("plbInterlacePivotActive",anInterlacePivot[OP_SELL],clrRed);
        UpdatePriceLabel("plbInterlacePivotInactive",anInterlacePivot[OP_BUY],clrDarkGray);
      }
      else
      {
        UpdatePriceLabel("plbInterlacePivotActive",0.00,clrDarkGray);
        UpdatePriceLabel("plbInterlacePivotInactive",0.00,clrDarkGray);
      }

    
      if (rsSegment>NoValue)
      {
        UpdateLine("lnOpen",pfractal.WaveSegment(SegmentType[rsSegment]).Open,STYLE_SOLID,clrYellow);
        UpdateLine("lnHigh",pfractal.WaveSegment(SegmentType[rsSegment]).High,STYLE_SOLID,clrLawnGreen);
        UpdateLine("lnLow",pfractal.WaveSegment(SegmentType[rsSegment]).Low,STYLE_SOLID,clrRed);
        UpdateLine("lnClose",pfractal.WaveSegment(SegmentType[rsSegment]).Close,STYLE_SOLID,clrSteelBlue);
        UpdateLine("lnRetrace",pfractal.WaveSegment(SegmentType[rsSegment]).Retrace,STYLE_DOT,clrSteelBlue);
      }
      else
      if (rsWaveAction!=OP_NO_ACTION)
        if (pfractal.Wave().Action==rsWaveAction)
        {
          UpdateLine("lnBank",pfractal.ActionLine(rsWaveAction,Bank),STYLE_DOT,clrGoldenrod);
          UpdateLine("lnGoal",pfractal.ActionLine(rsWaveAction,Goal),STYLE_DOT,clrLawnGreen);
          UpdateLine("lnGo",pfractal.ActionLine(rsWaveAction,Go),STYLE_SOLID,clrYellow);
          UpdateLine("lnChance",pfractal.ActionLine(rsWaveAction,Chance),STYLE_DOT,clrSteelBlue);
          UpdateLine("lnYield",pfractal.ActionLine(rsWaveAction,Yield),STYLE_SOLID,clrGoldenrod);
          UpdateLine("lnBuild",pfractal.ActionLine(rsWaveAction,Build),STYLE_SOLID,clrLawnGreen);
          UpdateLine("lnRisk",pfractal.ActionLine(rsWaveAction,Risk),STYLE_DOT,clrOrangeRed);
          UpdateLine("lnStop",pfractal.ActionLine(rsWaveAction,Stop),STYLE_SOLID,clrRed);
        }
        else
        {
          UpdateLine("lnGo",pfractal.ActionLine(rsWaveAction,Go),STYLE_SOLID,clrYellow);
          UpdateLine("lnMercy",pfractal.ActionLine(rsWaveAction,Mercy),STYLE_DOT,clrSteelBlue);      
          UpdateLine("lnOpportunity",pfractal.ActionLine(rsWaveAction,Opportunity),STYLE_SOLID,clrSteelBlue);
          UpdateLine("lnRisk",pfractal.ActionLine(rsWaveAction,Risk),STYLE_DOT,clrOrangeRed);
          UpdateLine("lnHalt",pfractal.ActionLine(rsWaveAction,Halt),STYLE_DOT,clrOrangeRed);
          UpdateLine("lnStop",pfractal.ActionLine(rsWaveAction,Stop),STYLE_SOLID,clrRed);
          UpdateLine("lnKill",pfractal.ActionLine(rsWaveAction,Kill),STYLE_DOT,clrMaroon);
        }
    }
    else ShowZoneLines();
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "";
    string rsEvent     = "";

    ShowLines();

    rsComment          = "--BIAS--\n"+
                         "  Origin:  "+ActionText(session[Daily].Fractal(ftOrigin).Bias)+"\n"+
                         "  Trend:   "+ActionText(session[Daily].Fractal(ftTrend).Bias)+"\n"+
                         "  Term:    "+ActionText(session[Daily].Fractal(ftTerm).Bias)+"\n"+
                         "  Active:  "+ActionText(session[Daily][ActiveSession].Bias);

    if (inpShowWaveSegs==Yes)
      pfractal.DrawWaveOverlays();

    //--- Show Pipma Alerts
    if (SourceAlerts[indPipMA] && !PauseOnHistory)
      for (EventType type=1;type<EventTypes;type++)
        if (Alerts[type]&&pfractal.Event(type))
        {
          rsEvent   = "PipMA "+pfractal.ActiveEventText()+"\n";
          break;
        }

    //--- Show Fractal Alerts
    if (SourceAlerts[indFractal])
      for (EventType type=1;type<EventTypes;type++)
        if (Alerts[type]&&fractal.Event(type))
        {
          rsEvent   = "Fractal "+fractal.ActiveEventText()+"\n";
          break;
        }

    rsEvents.ClearEvents();
    
    //--- Show Session Alerts
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
//| OrderMargin                                                      |
//+------------------------------------------------------------------+
double OrderMargin(double Lots, int Format=InPercent)
  {
    double omMarginPerLot     = (ordAcctLotSize*ordAcctMinLot)/AccountLeverage();   //--- Initialize for JPY
    double omMarginRqmt       = 0.00;

    if (IsEqual(AccountEquity(),0.00,2))
      return (omMarginRqmt);

    if (Symbol()!="USDJPY")
      omMarginPerLot          = ((ordAcctLotSize*ordAcctMinLot)*Close[0])/AccountLeverage();
       
    omMarginRqmt              = (Lots/ordAcctMinLot)*omMarginPerLot;
  
    switch (Format)
    {
      case InPercent: return (NormalizeDouble(omMarginRqmt/AccountEquity()*100,1));
      case InDollar:  return (NormalizeDouble(omMarginRqmt,2));
      default:        Print("Order Margin: Invalid format code supplied");
    }
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| UpdateOrders - Updates order detail stats by action              |
//+------------------------------------------------------------------+
void UpdateOrders(void)
  {
    double uoPriceBase[2]                    = {0.00,0.00};

    //-- Margin calculation measures
    double uoMLots[2]                        = {0.00,0.00};   //-- Total Open Lots {OP_BUY/OP_SELL}
    double uoMBurden                         = 0.00;          //-- Lots Basis for Margin Req. Calculation
    double uoMDominant                       = 0.00;          //-- Dominant margin calc factor
    double uoMMinority                       = 0.00;          //-- Minority margin calc factor
    
    //-- Set the Order Close pivot
    for (int ord=0;ord<ArraySize(ordClose);ord++)
      omMaster[ordClose[ord].Action].OrderClose = ordClose[ord].Price;
      
    //-- Set zone details on NewFractal
    if (detail[Daily].NewFractal)
      for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
      {
        omMaster[Action(detail[Daily].FractalDir,InDirection,InContrarian)].Zone[FiboExt(fibo)].Price   = 
              detail[Daily].FractalPivot[Action(detail[Daily].FractalDir,InDirection)]+(Pip(FiboLevels[fabs(fibo)]*100*Direction(fibo),InPoints));

        omMaster[Action(detail[Daily].FractalDir,InDirection,InContrarian)].Zone[FiboExt(fibo)].ActiveDir = DirectionNone;
      }
    
    //-- Update zone details on NewFractal
    ArrayResize(omMaster[OP_BUY].Line,0);
    ArrayResize(omMaster[OP_SELL].Line,0);
    
    //-- Order analysis and aggregation
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      for (int pos=0;pos<Total;pos++)
      {
        omMaster[action].Detail[pos].Lots    = 0.00;
        omMaster[action].Detail[pos].Margin  = 0.00;
        omMaster[action].Detail[pos].Equity  = 0.00;
        omMaster[action].Detail[pos].Value   = 0.00;
      }

      //-- Populate Order Array
      for (int ord=0;ord<OrdersTotal();ord++)
        if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
          if (OrderType()==action)
          {
            //-- Aggregate order position Pos, Neg, Net
            ArrayResize(omMaster[action].Line,ArraySize(omMaster[action].Line)+1);

            omMaster[action].Line[ArraySize(omMaster[action].Line)-1].Ticket  = OrderTicket();
            omMaster[action].Line[ArraySize(omMaster[action].Line)-1].Price   = OrderOpenPrice();
            omMaster[action].Line[ArraySize(omMaster[action].Line)-1].Lots    = OrderLots();
            omMaster[action].Line[ArraySize(omMaster[action].Line)-1].Margin  = OrderMargin(OrderLots());
            omMaster[action].Line[ArraySize(omMaster[action].Line)-1].Value   = OrderProfit();

            uoMLots[action]                 += OrderLots();
          }
    }

    switch (inpMarginModel)
    {
       case Discount:     uoMBurden          = fabs(uoMLots[OP_BUY]-uoMLots[OP_SELL])+fdiv(fmin(uoMLots[OP_BUY],uoMLots[OP_SELL]),2);
       
                          if (IsEqual(fmin(uoMLots[OP_BUY],uoMLots[OP_SELL]),0.00))
                            uoMDominant      = 1;
                          else
                          {
                            uoMDominant      = fdiv(fmax(uoMLots[OP_BUY],uoMLots[OP_SELL]),(uoMLots[OP_BUY]+uoMLots[OP_SELL]),2);
                            uoMMinority      = fdiv(fmin(uoMLots[OP_BUY],uoMLots[OP_SELL]),(uoMLots[OP_BUY]+uoMLots[OP_SELL]),2);;
                          }
                          break;
                          
       case Premium:      uoMBurden          = fmax(uoMLots[OP_BUY],uoMLots[OP_SELL]);
                          uoMDominant        = 1;
                          uoMMinority        = fdiv(fmin(uoMLots[OP_BUY],uoMLots[OP_SELL]),uoMBurden);
                          break;

       case FIFO:         uoMBurden          = fmax(uoMLots[OP_BUY],uoMLots[OP_SELL]);
                          uoMDominant        = uoMBurden;
    }

    //-- Calc order summary
    omTotal.Lots                             = uoMLots[OP_BUY]-uoMLots[OP_SELL];
    omTotal.Value                            = AccountEquity()-(AccountBalance()+AccountCredit());
    omTotal.Equity                           = fdiv(omTotal.Value,(AccountBalance()+AccountCredit()),3);
    omTotal.Margin                           = fdiv(AccountMargin(),AccountEquity(),3);

    //-- Calculate zone values and margins
    for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
    {
      for (int action=OP_BUY;action<=OP_SELL;action++)
      {
        omMaster[action].Zone[FiboExt(fibo)].Ticket     =  0;
        omMaster[action].Zone[FiboExt(fibo)].Lots       =  0.00;
        omMaster[action].Zone[FiboExt(fibo)].Value      =  0.00;
        omMaster[action].Zone[FiboExt(fibo)].Margin     =  0.00;
        
        //-- Calculate fibo price and zone
        if (Close[0]>uoPriceBase[action])
          if (Close[0]<=omMaster[action].Zone[FiboExt(fibo)].Price)
          {
            if (omMaster[action].Fibo>fibo)
            {
              omMaster[action].Fibo                            = fibo-1;
              omMaster[action].Zone[FiboExt(fibo-1)].ActiveDir = DirectionUp;
              Print(ActionText(action)+" Fibo:"+(string)fibo+" "+(string)omMaster[action].Fibo+" (f):"+DoubleToStr(FiboPercent(FiboExt(fibo)),3)+"%"
                   +" (c): "+DoubleToStr(Close[0],Digits)
                   +" (b): "+DoubleToStr(uoPriceBase[action],Digits)
                   +" (z): "+DoubleToStr(omMaster[action].Zone[FiboExt(fibo)].Price,Digits));
            }
            else
            if (omMaster[action].Fibo<fibo)
            {
              omMaster[action].Fibo                            = fibo;
              omMaster[action].Zone[FiboExt(fibo)].ActiveDir   = DirectionDown;
              Print(ActionText(action)+" Fibo:"+(string)fibo+" "+(string)omMaster[action].Fibo+" (f):"+DoubleToStr(FiboPercent(FiboExt(fibo)),3)+"%"
                   +" (c): "+DoubleToStr(Close[0],Digits)
                   +" (b): "+DoubleToStr(uoPriceBase[action],Digits)
                   +" (z): "+DoubleToStr(omMaster[action].Zone[FiboExt(fibo)].Price,Digits));
            }
          }

        for (int ord=0;ord<ArraySize(omMaster[action].Line);ord++)
        {
          if (IsLower(0.00,omMaster[action].Line[ord].Value,NoUpdate))
          {
            omMaster[action].Detail[Loss].Lots      += OrderLots();
            omMaster[action].Detail[Loss].Margin    += OrderMargin(OrderLots());
            omMaster[action].Detail[Loss].Value     += OrderProfit();

            omMaster[action].Detail[Net].Lots       -= OrderLots();
          }
          else
          {
            omMaster[action].Detail[Profit].Lots    += OrderLots();
            omMaster[action].Detail[Profit].Margin  += OrderMargin(OrderLots());
            omMaster[action].Detail[Profit].Value   += OrderProfit();
        
            omMaster[action].Detail[Net].Lots       += OrderLots();
          }

          omMaster[action].Detail[Net].Margin       += OrderMargin(omMaster[action].Detail[0].Lots);
          omMaster[action].Detail[Net].Value        += OrderProfit();

          //-- Aggregate order distribution across zone
          if (OrderOpenPrice()>uoPriceBase[action])
            if (OrderOpenPrice()<=omMaster[action].Zone[FiboExt(fibo)].Price)
            {
              omMaster[action].Zone[FiboExt(fibo)].Ticket++;
                  omMaster[action].Zone[FiboExt(fibo)].Lots  +=  OrderLots();
                  omMaster[action].Zone[FiboExt(fibo)].Value +=  OrderProfit();
                }
            }

        //-- Compute zone margin
        if (omMaster[action].Zone[FiboExt(fibo)].Ticket>0)
        {
          switch (inpMarginModel)
          {
            case Discount:  if (IsEqual(uoMLots[action],fmax(uoMLots[OP_BUY],uoMLots[OP_SELL]),ordLotPrecision))
                              omMaster[action].Zone[FiboExt(fibo)].Margin  = 
                                OrderMargin(fdiv(omMaster[action].Zone[FiboExt(fibo)].Lots,uoMLots[action],ordLotPrecision)*(uoMDominant*uoMBurden));
                            else
                              omMaster[action].Zone[FiboExt(fibo)].Margin  = 
                                OrderMargin(fdiv(omMaster[action].Zone[FiboExt(fibo)].Lots,uoMLots[action],ordLotPrecision)*(uoMMinority*uoMBurden));
                            break;
            
            case Premium:   if (IsEqual(uoMLots[action],fmax(uoMLots[OP_BUY],uoMLots[OP_SELL]),ordLotPrecision))
                              omMaster[action].Zone[FiboExt(fibo)].Margin  = 
                                OrderMargin(uoMLots[action]*uoMDominant);
                            else
                              omMaster[action].Zone[FiboExt(fibo)].Margin  = 
                                OrderMargin(uoMLots[action]*uoMMinority);
                            break;
                            
            case FIFO:      OrderMargin(omMaster[action].Zone[FiboExt(fibo)].Margin  = uoMLots[action]);
                            break;
          }
        }

        uoPriceBase[action] = omMaster[action].Zone[FiboExt(fibo)].Price;
      }
    }
    
    if (OrdersTotal()!=ArraySize(omMaster[OP_BUY].Line)+ArraySize(omMaster[OP_SELL].Line))
      Pause("OOB Detected:/nLong:"+(string)ArraySize(omMaster[OP_BUY].Line)+
                         "/nShort:"+(string)ArraySize(omMaster[OP_SELL].Line)+
                         "/nTotal:"+(string)OrdersTotal(),
            "Counting Error");
  }

//+------------------------------------------------------------------+
//| CalcFractalBias - computes the fractal bias and change           |
//+------------------------------------------------------------------+
void CalcFractalBias(SessionType Type)
  {
    int ufbFractalBias               = 0;
    
    for (SessionType bias=Daily;bias<SessionTypes;bias++)
      if (bias==Daily)
        if (session[bias].Event(NewFractal))
          master                     = lead.Type();
        else
        {
          //-- do something?
        }
      else
      if (session[bias].Fractal(ftTerm).Direction==session[Daily].Fractal(ftTerm).Direction)
        ufbFractalBias              += session[Daily].Fractal(ftTerm).Direction;

    sFractalChange                  += session[Type].Fractal(ftTerm).Direction;
    sFractalBias                     = ufbFractalBias;
    sFractalSession                  = Type;
    
    if (fabs(sFractalBias)==3)
      if (session[Daily].Fractal(ftTrend).Direction==session[Daily].Fractal(ftTerm).Direction)
        sFractalPattern              = TrendConvergent;
      else
        sFractalPattern              = TermConvergent;
    else
    {
      if (session[Daily].Fractal(ftTrend).Direction==session[Daily].Fractal(ftTerm).Direction)
        sFractalPattern              = TrendDivergent;
      else
        sFractalPattern              = TermDivergent;

      //---Verification
      if (fabs(sFractalChange)+fabs(sFractalBias)==3)
        return;

//      if (Direction(sFractalChange)==Direction(sFractalBias))
//        NewArrow(BoolToInt(sFractalBias>=0,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),Color(sFractalBias,IN_CHART_DIR),"Fractal");

      Pause("Error: Bias Differential","Fractal Bias/Change Error");
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
      
      //-- Set tick level details and event flags
      detail[type].ActiveDir         = Direction(session[type].Pivot(ActiveSession)-session[type].Pivot(PriorSession));
      detail[type].NewFractal        = false;
      detail[type].FractalAge        = session[type].Age();

      //-- Set Session NewDay details
      if (session[type].Event(NewDay))
      {
        detail[type].FractalDir      = DirectionNone;
        detail[type].Reversal        = false;
        detail[type].HighHour        = ServerHour();
        detail[type].LowHour         = ServerHour();
        detail[type].FractalHour     = NoValue;
        
        if (type==Daily)
          sFractalChange             = 0;
      }

      //-- Set Session open details
      if (session[type].IsOpen())
        lead                         = session[type];

      if (session[type].Event(SessionOpen))
      {          
        detail[type].Ceiling         = session[type][PriorSession].High;
        detail[type].Floor           = session[type][PriorSession].Low;
        detail[type].Pivot           = session[type].Pivot(PriorSession);
      }

      //-- Set Session details and Fractal events
      if (session[type].Event(NewFractal))
      {
        detail[type].Pitch           = fdiv(session[type][ActiveSession].High+session[type][ActiveSession].Low,2);

        if (session[type].Event(NewReversal))
          CalcFractalBias(type);

        if (NewDirection(detail[type].FractalDir,session[type].Fractal(ftTerm).Direction))
          detail[type].Reversal      = true;
        
        if (IsChanged(detail[type].FractalHour,ServerHour()))
        {
          detail[type].NewFractal    = true;
          detail[type].FractalPivot[Action(detail[type].FractalDir,InDirection)] = Close[0];
        }
      }

      if (IsHigher(Close[0],session[type][PriorSession].High,NoUpdate))
        detail[type].Zone            = OP_BUY;
      else
      if (IsLower(Close[0],session[type][PriorSession].Low,NoUpdate))
        detail[type].Zone            = OP_SELL;
      else
      {
        detail[type].Zone            = OP_RISK;

        if (session[type].Fractal(ftTerm).Direction==DirectionUp)
          if (IsHigher(Close[0],detail[type].Pitch,NoUpdate))
            detail[type].Zone        = OP_HEDGE;

        if (session[type].Fractal(ftTerm).Direction==DirectionDown)
          if (IsLower(Close[0],detail[type].Pitch,NoUpdate))
            detail[type].Zone        = OP_HEDGE;
      }

      //--- Session detail operational checks
      if (session[type].Event(NewHigh))
        detail[type].HighHour        = ServerHour();

      if (session[type].Event(NewLow))
        detail[type].LowHour         = ServerHour();

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
    
    if (pfractal.HistoryLoaded())
      if (pfractal.Event(NewWaveReversal))
        pfAction                       = pfractal.Wave().Action;
        
    //--- Load fibo matrix
    for (FibonacciLevel fibo=0;fibo<=Fibo823;fibo++)
      pfExpansion[fibo]                = FiboPrice(fibo,pfractal[Term].Base,pfractal[Term].Root,Expansion);
 
    //--- Extract and Process tick interlace data
    anWork.Clear();
    
    //-- Extract the equalization matrix
    for (int seg=0;seg<5;seg++)
    {
      ppmaPrice[0]                     = pfractal.WaveSegment(SegmentType[seg]).Open;
      ppmaPrice[1]                     = pfractal.WaveSegment(SegmentType[seg]).High;
      ppmaPrice[2]                     = pfractal.WaveSegment(SegmentType[seg]).Low;
      ppmaPrice[3]                     = pfractal.WaveSegment(SegmentType[seg]).Close;
      ppmaPrice[4]                     = pfractal.WaveSegment(SegmentType[seg]).Retrace;
      
      ArraySort(ppmaPrice,WHOLE_ARRAY,0,MODE_DESCEND);
      
      for (int copy=0;copy<5;copy++)
      {
        anMatrix[seg][copy]            = ppmaPrice[copy];
        anWork.Add(ppmaPrice[copy]);
      }
    }
    
    anWork.CopyFiltered(anInterlace,false,false,MODE_DESCEND);
    anInterlaceDir                     = BoolToInt(fdiv(anInterlace[0]+anInterlace[ArraySize(anInterlace)-1],2,Digits)<Close[0],DirectionUp,DirectionDown);

    if (IsEqual(Close[0],anInterlace[0]))
      if (NewDirection(anInterlaceBrkDir,DirectionUp))
        anInterlacePivot[OP_BUY]       = Close[0];

    if (IsEqual(Close[0],anInterlace[ArraySize(anInterlace)-1]))
      if (NewDirection(anInterlaceBrkDir,DirectionDown))
        anInterlacePivot[OP_SELL]      = Close[0];

//    pfractal.ShowFiboArrow();
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Update Main Fractal data                         |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {    
    static FibonacciLevel ufExpand[4]  = {Fibo161,Fibo161,Fibo161,Fibo161};

    fractal.Update();
    
    if (fractal.Event(NewFractal,Major))
    {
      Flag("Major",clrWhite,rsShowFlags);
      
      if (fractal.IsDivergent())
        ArrayInitialize(ufExpand,Fibo161);
    }
    else
    {
      //--Origin Fibo Flags
      if (FiboLevels[ufExpand[3]]<fractal.Fibonacci(Origin,Expansion,Now))
      {
        Flag("Origin "+EnumToString(ufExpand[3]),clrRed,rsShowFlags);
        ufExpand[3]++;
      }

      //-- Base Fibo Flags
      if (FiboLevels[ufExpand[2]]<fractal.Fibonacci(Base,Expansion,Now))
      {
        Flag("Base "+EnumToString(ufExpand[2]),clrGray,rsShowFlags);
        ufExpand[2]++;
      }

      //-- Trend/Term Fibo Flags
      for (RetraceType fibo=Trend;fibo<=Term;fibo++)
        if (FiboLevels[ufExpand[fibo]]<fractal.Fibonacci(fibo,Expansion,Now))
        {
          Flag(EnumToString(fibo)+" "+EnumToString(ufExpand[fibo]),BoolToInt(fibo==Trend,clrYellow,clrGoldenrod),rsShowFlags);
          ufExpand[fibo]++;
        }
    }
  }
  
//+------------------------------------------------------------------+
//| CalcFractal - Process and prepare fractal data                   |
//+------------------------------------------------------------------+
void CalcFractal(void)
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
      oaLots[Action(Order.Action,InAction)]   += OrderLotSize(Order.Lots);

      if (Order.Status==Pending)
      {
        for (int ord=0;ord<ArraySize(omQueue);ord++)
          if (omQueue[ord].Status==Pending)
            oaLots[omQueue[ord].Action]       += OrderLotSize(omQueue[ord].Lots);

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
        Order.Memo           = "Margin ("+DoubleToStr(oaMargin,1)+")";
    }
    else
      Order.Memo             = "Trade disabled.";

    Order.Status             = Declined;
    return (false);
  }

//+------------------------------------------------------------------+
//| OrderProcessed - Executes orders from the order manager          |
//+------------------------------------------------------------------+
bool OrderProcessed(OrderRequest &Order)
  {
    if (OpenOrder(Action(Order.Action,InAction),Order.Requestor+":"+Order.Memo,OrderLotSize(Order.Lots)))
    {
      UpdateTicket(ordOpen.Ticket,Order.Target,Order.Stop);

      Order.Action                     = ordOpen.Action;
      Order.Key                        = ordOpen.Ticket;
      Order.Price                      = ordOpen.Price;
      Order.Lots                       = ordOpen.Lots;
      
      omMaster[Order.Action].OrderOpen = Order.Price;
      
      return (true);
    }
    
    Order.Memo                         = ordOpen.Reason;
    
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
//| OrderLotSize - Computes Order lot size for the action zone       |
//+------------------------------------------------------------------+
double OrderLotSize(double Lots=0.00, double Risk=0.00)
  {
    if (Risk==0.00)
      Risk            = ordEQLotFactor;

    if (NormalizeDouble(inpLotSize,ordLotPrecision) == 0.00)
    {
      if(NormalizeDouble(Lots,ordLotPrecision)>0.00)
        if (NormalizeDouble(Lots,ordLotPrecision)==0.00)
          return (ordAcctMinLot);
        else
        if(Lots>ordAcctMaxLot)
          return (ordAcctMaxLot);
        else
          return(NormalizeDouble(Lots,ordLotPrecision));
    }
    else
      Lots = NormalizeDouble(inpLotSize,ordLotPrecision);

    Lots = fmin((ordEQBase*(Risk/100))/MarketInfo(Symbol(),MODE_MARGINREQUIRED),ordAcctMaxLot);
    
    return(fmax(NormalizeDouble(Lots,ordLotPrecision),ordAcctMinLot));
  }

//+------------------------------------------------------------------+
//| OrderClose - Closes orders based on closure strategy             |
//+------------------------------------------------------------------+
bool OrderClose(int Action, CloseOptions Option)
  {
    int       ocTicket        = NoValue;
    double    ocValue         = 0.00;
/*
    for (int ord=0;ord<ocOrders;ord++)
      if (OrderSelect(ticket[ord],SELECT_BY_TICKET,MODE_TRADES))
        if (Action=OrderType())
          switch (Option)
          {
            case CloseMin:    if (ocTicket==NoValue)
                              { 
                                ocTicket   = OrderTicket();
                                ocValue    = OrderProfit();
                              }
                              else
                              if (IsLower(OrderProfit(),ocValue))
                                ocTicket   = OrderTicket();
                                
                              break;
                              
            case CloseMax:    if (ocTicket==NoValue)
                              { 
                                ocTicket   = OrderTicket();
                                ocValue    = OrderProfit();
                              }
                              else
                              if (IsHigher(OrderProfit(),ocValue))
                                ocTicket   = OrderTicket();
                              
                              break;
            
            case CloseAll:    CloseOrder(ticket[ord],true);
                              break;

            case CloseHalf:   CloseOrder(ticket[ord],true,HalfLot(OrderLots()));
                              break;

            case CloseProfit: if (OrderProfit()>0.00)
                                CloseOrder(ticket[ord],true);
                              break;

            case CloseLoss:   if (OrderProfit()<0.00)
                                CloseOrder(ticket[ord],true);
                              break;
          }
*/          
    return(false);

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
//| ShortManagement - Manages short order positions, profit and risk |
//+------------------------------------------------------------------+
void ShortManagement(void)
  {
    static ActionState  smState   = Halt;
    static bool         smProfit  = false;
    static bool         smLoss    = false;
    OrderRequest        smRequest = {0,OP_SELL,"Mgr:Short",0,0,0,0,"",0,NoStatus};
    
    //-- Manage Locks
    if (anFiboDetail[ftTrend].Direction==DirectionDown)
      if (IsHigher(FiboLevels[Fibo50],anFiboDetail[Trend].RetraceMax,NoUpdate))
        SetEquityHold(OP_SELL);
      else
      if (anFiboDetail[ftTerm].Direction==DirectionDown)
        SetEquityHold(OP_SELL);
      else
        SetEquityHold(OP_NO_ACTION);

    //-- Process Short Order Entry Events
    if (pfractal.Event(NewWaveOpen))
    {
      switch (pfractal.ActiveSegment().Type)
      {
        case Crest:  if (IsChanged(omMaster[OP_SELL].Trigger,false))
                     {
                       //-- May require defensive action
                     }

                     smLoss         = true;
                     break;

        case Trough: //if (IsChanged(omMaster[OP_SELL].Trigger,false)) //-- FFE?
                     {
                       //-- Position management
                     }
                     
                     smProfit        = true;
                     break;

        case Decay:  switch (pfractal.WaveSegment(Last).Type)
                     {
                       case Crest:  switch (pfractal.WaveSegment(Last).Direction)
                                    {
                                      case DirectionUp:
                                                     omMaster[OP_SELL].Resistance = fdiv(pfractal.WaveSegment(Last).High+pfractal.WaveSegment(Last).Low,2,Digits);
                                                     omMaster[OP_SELL].Entry      = fmax(pfractal.WaveSegment(Last).Open,pfractal.WaveSegment(Last).Close);
                                                     break;

                                      case DirectionDown:
                                                     smRequest.Memo               = "Rally";

                                                     omMaster[OP_SELL].Entry      = fdiv(pfractal.WaveSegment(Last).High+pfractal.WaveSegment(Last).Low,2,Digits);
                                                     omMaster[OP_SELL].Trigger    = true;
                                                     break;
                                    }
                                    break;

                       case Trough: switch (pfractal.WaveSegment(Last).Direction)
                                    {
                                      case DirectionUp:
                                                     omMaster[OP_SELL].Exit       = fdiv(pfractal.WaveSegment(Last).High+pfractal.WaveSegment(Last).Low,2,Digits);
                                                     break;
                                      case DirectionDown:
                                                     omMaster[OP_SELL].Support    = fdiv(pfractal.WaveSegment(Last).High+pfractal.WaveSegment(Last).Low,2,Digits);
                                                     omMaster[OP_SELL].Target     = fmin(pfractal.WaveSegment(Last).Open,pfractal.WaveSegment(Last).Close);
                                                     break;
                                    }
                                    break;
                     }
      }
    }

    //-- Entry Triggers
    if (IsHigher(Close[0],omMaster[OP_SELL].Entry,NoUpdate))
      if (pfractal.Direction(Tick)==DirectionDown)
        if (IsChanged(omMaster[OP_SELL].Trigger,false))
        {
          smRequest.Expiry    = Time[0]+(Period()*60);
          OrderSubmit(smRequest,NoQueue);
        }

    //-- Profit Triggers
    if (IsLower(Close[0],omMaster[OP_SELL].Target,NoUpdate))
      if (smProfit)
        if (pfractal.ActiveSegment().Type == Decay)
          if (pfractal.Direction(Tick)==DirectionUp)
          {
//            Pause("Profit","Trigger");
            smProfit = false;
          }
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
      if (session[Daily].Event(NewHour))
        if (ServerHour()==PauseOnHour)
          CallPause("Pause requested on Server Hour "+IntegerToString(PauseOnHour),Always);
    
    if (PauseOnPrice!=0.00)
      if ((PauseOnPrice>NoValue&&Close[0]>PauseOnPrice)||(PauseOnPrice<NoValue&&Close[0]<fabs(PauseOnPrice)))
      {
        CallPause("Pause requested at price "+DoubleToString(fabs(PauseOnPrice),Digits),Always);
        PauseOnPrice  = 0.00;
      }
       
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
//| GetSessionType - Converts text to Type                           |
//+------------------------------------------------------------------+
SessionType GetSessionType(string &Type)
  {
    if (Type=="DAILY")  return(Daily);
    if (Type=="ASIA")   return(Asia);
    if (Type=="US")     return(US);
    if (Type=="EUROPE") return(Europe);

    return (SessionTypes);
  }
  
//+------------------------------------------------------------------+
//| GetFractalType - Converts text to Type                           |
//+------------------------------------------------------------------+
FractalType GetFractalType(string &Type)
  {
    if (Type=="ORIG"||Type=="ORIGIN")  return(ftOrigin);
    if (Type=="TREND")                 return(ftTrend);
    if (Type=="TERM")                  return(ftTerm);
    if (Type=="PRIOR")                 return(ftPrior);

    if (Type=="CORR"||Type=="CORRECT"||Type=="CORRECTION")
                                       return(ftCorrection);

    return (FractalTypes);
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
        rsSession                      = SessionTypes;
        rsFractal                      = FractalTypes;
        rsZone                         = OP_NO_ACTION;
         
        if (GetSessionType(Command[2])==SessionTypes)
        {
          if (Command[2]=="CREST")
            rsSegment                  = 2;
          else
          if (Command[2]=="TROUGH")
            rsSegment                  = 3;
          else
          if (Command[2]=="DECAY")
            rsSegment                  = 4;
          else
          if (Command[2]=="BUY"||Command[2]=="LONG")
          {
            rsWaveAction               = OP_BUY;
            rsSegment                  = NoValue;

            if (Command[3]=="SEG")
            {
              rsSegment                = OP_BUY;
              rsWaveAction             = OP_CLOSE;
            }
            if (Command[3]=="ZONE")
            {   
              rsZone                   = OP_BUY;
              rsWaveAction             = OP_NO_ACTION;
            }
          }
          else
          if (Command[2]=="SELL"||Command[2]=="SHORT")
          {
            rsWaveAction               = OP_SELL;
            rsSegment                  = NoValue;

            if (Command[3]=="SEG")
            {
              rsSegment                = OP_SELL;
              rsWaveAction             = OP_CLOSE;
            }
            if (Command[3]=="ZONE")
            {
              rsZone                   = OP_SELL;
              rsWaveAction             = OP_NO_ACTION;
            }
          }
          else
          {
            rsSegment                  = NoValue;
            rsWaveAction               = OP_NO_ACTION;
            rsZone                     = OP_NO_ACTION;
          }
        }
        else
        {
          rsSession                    = GetSessionType(Command[2]);
          rsFractal                    = GetFractalType(Command[3]);
        }
      }
      else
      if (StringSubstr(Command[1],0,4)=="FLAG")
        
//        if (Command[1]=="PIPMA")
//          SourceAlerts[indPipMA]         = false;
//        else
//        if (Command[1]=="SESSION")
//          SourceAlerts[indSession]       = false;
       if (Command[2]=="FRACTAL")
          rsShowFlags                      = Always;
        else
          rsShowFlags                      = false;      
      else
        rsShow                         = Command[1];

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
    UpdateSession();
    UpdateFractal();
    UpdatePipMA();
    CalcFractal();    
    UpdateOrders();

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
    
    anWork                = new CArrayDouble(0);
    anWork.Truncate       = false;
    anWork.AutoExpand     = true;    
    anWork.SetPrecision(Digits);
    anWork.Initialize(0.00);
    
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
    
    NewPriceLabel("lbSEntry");
    NewPriceLabel("lbSExit");

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
    
    NewLine("lnSupport");
    NewLine("lnResistance");
    NewLine("lnCorrectionHi");
    NewLine("lnCorrectionLo");

    if (inpShowFiboFlags==Yes)
      rsShowFlags                         = Always;
      
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
      detail[type].FractalDir             = session[type].Fractal(ftTerm).Direction;
    }

    CalcFractalBias(Daily);

    detail[Daily].FractalPivot[OP_BUY]    = fmax(session[Daily].Fractal(ftTerm).Resistance,session[Daily].Fractal(ftTerm).High);
    detail[Daily].FractalPivot[OP_SELL]   = fmin(session[Daily].Fractal(ftTerm).Support,session[Daily].Fractal(ftTerm).Low);

    ArrayInitialize(anInterlacePivot,Close[0]);
    
    //--- Initialize Fibo Management
    for (FractalType type=ftOrigin;type<FractalTypes;type++)
      anFiboDetail[type].Session = Daily;

    for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
    {
      NewLine("lnZone:"+DoubleToStr(FiboLevels[fabs(fibo)]*Direction(fibo)*100,1));
      omMaster[OP_BUY].Zone[FiboExt(fibo)].Price      = detail[Daily].FractalPivot[OP_SELL]+(Pip(FiboLevels[fabs(fibo)]*100*Direction(fibo),InPoints));
      omMaster[OP_BUY].Zone[FiboExt(fibo)].ActiveDir  = DirectionNone;
      omMaster[OP_SELL].Zone[FiboExt(fibo)].Price     = detail[Daily].FractalPivot[OP_BUY]+(Pip(FiboLevels[fabs(fibo)]*100*Direction(fibo),InPoints));
      omMaster[OP_SELL].Zone[FiboExt(fibo)].ActiveDir = DirectionNone;
    }
    
    UpdateOrders();
    RefreshOrders();

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
    delete rsEvents;
    delete anWork;
    delete omOrderKey;
  }