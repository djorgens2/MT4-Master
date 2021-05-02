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

//-- Margin Model Configurations
enum                  MarginModel
                      {
                        Discount,
                        Premium,
                        FIFO
                      };
 
input string          AppHeader            = "";       //+---- Application Options -------+
input double          inpMarginTolerance   = 25.0;     // Margin drawdown factor
input double          inpAgingThreshold    = 5;        // Aging threshold in periods
input MarginModel     inpMarginModel       = Discount; // Account type margin handling
input YesNoType       inpShowWaveSegs      = Yes;      // Display wave segment overlays
input YesNoType       inpShowFiboFlags     = Yes;      // Display Fractal Fibo Events
input YesNoType       inpShowFiboArrows    = Yes;      // Display PipMA Fibo Events

input string          FractalHeader        = "";    //+------ Fractal Options ---------+
input int             inpRangeMin          = 60;    // Minimum fractal pip range
input int             inpRangeMax          = 120;   // Maximum fractal pip range

input string          RegressionHeader     = "";    //+------ Regression Options ------+
input int             inpDegree            = 6;     // Degree of poly regression
input int             inpSmoothFactor      = 3;     // MA Smoothing factor
input double          inpTolerance         = 0.5;   // Directional sensitivity
input double          inpAggFactor         = 1.0;   // Tick Aggregation factor (1=1p)
input int             inpPipPeriods        = 200;   // Trade analysis periods (PipMA)
input int             inpRegrPeriods       = 24;    // Trend analysis periods (RegrMA)

input string          SessionHeader        = "";    //+---- Session Hours -------+
input int             inpAsiaOpen          = 1;     // Asian market open hour
input int             inpAsiaClose         = 10;    // Asian market close hour
input int             inpEuropeOpen        = 8;     // Europe market open hour`
input int             inpEuropeClose       = 18;    // Europe market close hour
input int             inpUSOpen            = 14;    // US market open hour
input int             inpUSClose           = 23;    // US market close hour
input int             inpGMTOffset         = 0;     // GMT Offset

const color           AsiaColor            = clrForestGreen;    // Asia session box color
const color           EuropeColor          = clrFireBrick;      // Europe session box color
const color           USColor              = clrRoyalBlue;       // US session box color
const color           DailyColor           = clrDarkGray;       // US session box color

  //--- Class Objects
  CSession           *session[SessionTypes];
  CSession           *lead;
  CFractal           *fractal              = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal             = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,inpAggFactor,50);
  CEvent             *rsEvents             = new CEvent();
  
  //--- Enums and Structs
  enum                AccountMetric
                      {
                        eqPctOpen,
                        eqPctClosed,
                        eqPctVar,
                        eqBal,
                        acBal,
                        acSpread,
                        acMargin,
                        acMarginLong,
                        acMarginShort,
                        acEquity,
                        lotMarginRqmt,
                        lotSizeMin,
                        lotSizeMax,
                        lotPrecision
                      };
                      
  enum                ManagerState
                      {
                        msWait,
                        msManage,
                        msHold,
                        msAcquire,
                        msRisk,
                        msHalt,
                        ManagerStates
                      };

  enum                FractalState
                      {
                        fsAcquisition,
                        fsCorrection,
                        fsLiquidation,
                        fsCapture,
                        fsRelease,
                        fsReversal,
                        fsYield,
                        fsConfirmation,
                        fsProfit,
                        FractalStates
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

  //--- Fractal Array Types
  enum                FractalArrayType
                      {
                        fatMeso,
                        fatMacro,
                        fatDaily,
                        fatAsia,
                        fatEurope,
                        fatUS,
                        fatPipMA,
                        FractalArrayTypes
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
  struct              FractalDetail
                      {
                        string         Heading;
                        string         SubHead;
                        string         State;
                        color          HeadColor[3];
                        color          FiboColor[3];
                        int            ActiveDir;
                        int            BreakoutDir;
                        double         Expansion[3];
                        double         Retrace[3];
                      };
                     
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
                        int            State;                  //-- State relative to prior session
                        double         Ceiling;                //-- Last session trading high
                        double         Floor;                  //-- Last session trading low
                        double         Pitch;                  //-- On new fractal, track the pitch, static retention
                        bool           Alerts;                 //-- Noise reduction filter for alerts
                      };

  struct              OrderSummary 
                      {
                        int            Count;                  //-- Open Order Count
                        double         Lots;                   //-- Lots by Pos, Neg, Net
                        double         Value;                  //-- Order value by Pos, Neg, Net
                        double         Margin;                 //-- Margin% by Pos, Neg, Net
                        double         Equity;                 //-- Equity% by Pos, Neg, Net
                      };
  
  struct              FiboZone
                      {
                        double         Price[20];              //-- Relative Price (Fibo zone);
                        OrderSummary   Zone[20];
                      };
                        
  struct              OrderMaster
                      {
                        ManagerState   State;               //-- Trade State by Action
                        int            Level;
                        double         MarginTolerance;     //-- Max Margin by Action
                        FiboZone       Fibo;                //-- Aggregate order detail by fibo zone
                        OrderSummary   Summary;             //-- Order Summary by Action
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

  const int SegmentType[5]   = {OP_BUY,OP_SELL,Crest,Trough,Decay};

  //--- Display operationals
  string              rsShow              = "APP";
  SessionType         rsSession           = SessionTypes;
  FractalType         rsFractal           = FractalTypes;
  int                 rsWaveAction        = OP_BUY;
  int                 rsSegment           = NoValue;
  int                 rsFiboAction        = OP_NO_ACTION;
  bool                rsShowPitch         = false;
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
  
  //--- Order Manager operationals
  OrderMaster         om[2];
  OrderRequest        omQueue[];
  CArrayInteger      *omOrderKey;
  OrderSummary        omSummary[Total];     //-- Positional value by Loss, Net, Profit

  
  //--- PipMA Wave operationals
  double              pwSegMatrix[5][5];
  double              pwInterlace[];
  double              pwInterlacePivot[2];
  int                 pwInterlaceDir;
  int                 pwInterlaceBrkDir;
  CArrayDouble       *pwWork;

  //-- Fractal Combine
  FractalDetail       fdetail[FractalArrayTypes];
  
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
//| ManagerStateText - Returns the text for the supplied state       |
//+------------------------------------------------------------------+
string ManagerStateText(ManagerState State, string Detail="")
  {
    switch (State)
    {
      case msWait:     return ("Waiting"+Detail);
      case msManage:   return ("Managing"+Detail);
      case msHold:     return ("Holding"+Detail);
      case msAcquire:  return ("Acquisition"+Detail);
      case msRisk:     return ("At Risk"+Detail);
      case msHalt:     return ("Halted"+Detail);
      default:         return ("Invalid Manager State");
    }
  }
    
//+------------------------------------------------------------------+
//| SessionColor - Returns the color for session ranges              |
//+------------------------------------------------------------------+
color SessionColor(SessionType Type)
  {
    switch (Type)
    {
      case Asia:    return(AsiaColor);
      case Europe:  return(EuropeColor);
      case US:      return(USColor);
      case Daily:   return(DailyColor);
    }
    
    return (clrBlack);
  }

//+------------------------------------------------------------------+
//| RepaintOrder - Repaints a specific order line                    |
//+------------------------------------------------------------------+
void RepaintOrder(OrderRequest &Order, int Col, int Row)
  {
    string roLabel      = "lbvOQ-"+StringSubstr(ActionText(Col),0,1)+"-"+(string)Row;
    
    UpdateLabel(roLabel+"Key",LPad((string)Order.Key,"-",8),clrDarkGray,8,"Consolas");
    UpdateLabel(roLabel+"Status",EnumToString(Order.Status),clrDarkGray);
    UpdateLabel(roLabel+"Requestor",Order.Requestor,clrDarkGray);
    UpdateLabel(roLabel+"Price",DoubleToStr(Order.Price,Digits),clrDarkGray);
    UpdateLabel(roLabel+"Lots",DoubleToStr(OrderLotSize(Order.Lots),ordLotPrecision),clrDarkGray);
    UpdateLabel(roLabel+"Target",LPad(DoubleToStr(Order.Target,Digits)," ",7),clrDarkGray);
    UpdateLabel(roLabel+"Stop",LPad(DoubleToStr(Order.Stop,Digits)," ",7),clrDarkGray);
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
        roLabel       = "lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row;
        
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
    //-- Acct Info (AI) --
    for (SessionType type=0;type<SessionTypes;type++)
    {
      if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==C'60,60,60'||detail[type].NewFractal||session[type].Event(NewHour))
      {
        UpdateBox("bxhAI-Session"+EnumToString(type),Color(session[type].Fractal(ftTerm).Direction,IN_DARK_DIR));
        UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(session[type].IsOpen(),clrYellow,clrBoxOff));
      }
    }

    UpdateLabel("lbvAI-Bal","$"+LPad(DoubleToStr(Account(acBal),0)," ",10),Color(omSummary[Net].Equity),16,"Consolas");
    UpdateLabel("lbvAI-Eq","$"+LPad(NegLPad(Account(acEquity),0)," ",10),Color(omSummary[Net].Equity),16,"Consolas");
    UpdateLabel("lbvAI-EqBal","$"+LPad(DoubleToStr(Account(eqBal),0)," ",10),Color(omSummary[Net].Equity),16,"Consolas");
     
    UpdateLabel("lbvAI-Eq%",LPad(NegLPad(Account(eqPctClosed,InPercent),1)," ",6)+"%",Color(omSummary[Net].Equity),16);
    UpdateLabel("lbvAI-EqOpen%",LPad(NegLPad(Account(eqPctOpen,InPercent),1)," ",6)+"%",Color(omSummary[Net].Equity),12);
    UpdateLabel("lbvAI-EqVar%",LPad(NegLPad(Account(eqPctVar,InPercent),1)," ",6)+"%",Color(omSummary[Net].Equity),12);
    UpdateLabel("lbvAI-Spread",LPad(DoubleToStr(Account(acSpread,InPips),1)," ",5),Color(omSummary[Net].Equity),14);
    UpdateLabel("lbvAI-Margin",LPad(DoubleToStr(Account(acMargin,InPercent),1)+"%"," ",6),Color(omSummary[Net].Equity),14);
    
    UpdateDirection("lbvAI-OrderBias",Direction(omSummary[Net].Lots),Color(omSummary[Net].Lots),30);
    
    for (int action=0;action<=2;action++)
      if (action<=OP_SELL)
      {
//      UpdateLabel("lbhAI-"+proper(ActionText(action))+"Action",rcpKey,clrDarkGray,10);
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"#",LPad((string)om[action].Summary.Count," ",2),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"L",LPad(DoubleToStr(om[action].Summary.Lots,2)," ",6),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"V",LPad(DoubleToStr(om[action].Summary.Value,0)," ",10),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"M",LPad(DoubleToStr(om[action].Summary.Margin,1)," ",5),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"E",LPad(DoubleToStr(om[action].Summary.Equity,1)," ",5),clrDarkGray,10,"Consolas");
      }
      else
      {
//      UpdateLabel("lbhAI-NetAction",rcpKey,clrDarkGray,10);
        UpdateLabel("lbvAI-Net#",LPad((string)omSummary[Net].Count," ",2),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-NetL",LPad(DoubleToStr(omSummary[Net].Lots,2)," ",6),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-NetV",LPad(DoubleToStr(omSummary[Net].Value,0)," ",10),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-NetM",LPad(DoubleToStr(omSummary[Net].Margin,1)," ",5),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-NetE",LPad(DoubleToStr(omSummary[Net].Equity,1)," ",5),clrDarkGray,10,"Consolas");
      }

    //-- App Config (AC) --
    string rcpOptions   = "";
    
    if (rsSession!=SessionTypes)  Append(rcpOptions,EnumToString(rsSession));
    if (rsFractal!=FractalTypes)  Append(rcpOptions,StringSubstr(EnumToString(rsFractal),2));
    if (rsWaveAction>NoValue)     Append(rcpOptions,"Wave "+SegmentText[rsWaveAction]);
    if (rsSegment>NoValue)        Append(rcpOptions,"Segment "+SegmentText[rsSegment]);
    if (rsFiboAction>NoValue)     Append(rcpOptions,"Zone "+SegmentText[rsFiboAction]);
    
    if (StringLen(rcpOptions)>1)
      rcpOptions                  = "  Lines: "+rcpOptions;
    
    UpdateLabel("lbvAC-Trading",BoolToStr(TradingOn,"Open","Halt"),BoolToInt(TradingOn,clrYellow,clrRed));
    UpdateLabel("lbvAC-Options",proper(rsShow)+BoolToStr(rsShowPitch,"  Pitch")+rcpOptions,clrDarkGray);
    
    //-- Order Detail (OD) --
    int    fibo[2]   = {-Fibo823,-Fibo823};
    string field     = "";
    string keys[6]   = {"F","#","L","V","M","E"};
    
    for (int row=0;row<12;row++)
      for (int col=0;col<=OP_SELL;col++)
      {
        field  = "lbvOD-"+ActionText(col)+(string)row;
        
        for (int cols=0;cols<6;cols++)
          UpdateLabel(field+keys[cols],"");

        while (fibo[col]<=Fibo823 && om[col].Fibo.Zone[FiboExt(fibo[col])].Count==0)
          fibo[col]++;
      
        if (fibo[col]<=Fibo823)
        {
          color val = Color(om[col].Fibo.Zone[FiboExt(fibo[col])].Value);
          
          UpdateLabel(field+keys[0],LPad(DoubleToStr(FiboLevels[fabs(fibo[col])]*Direction(fibo[col])*100,1)," ",7),val);
          UpdateLabel(field+keys[1],LPad((string)om[col].Fibo.Zone[FiboExt(fibo[col])].Count," ",2),val,9,"Consolas");
          UpdateLabel(field+keys[2],LPad(DoubleToStr(om[col].Fibo.Zone[FiboExt(fibo[col])].Lots,ordLotPrecision)," ",6),val,9,"Consolas");
          UpdateLabel(field+keys[3],"$"+LPad(DoubleToStr(om[col].Fibo.Zone[FiboExt(fibo[col])].Value,0)," ",11),val,9,"Consolas");
          UpdateLabel(field+keys[4],LPad(DoubleToStr(om[col].Fibo.Zone[FiboExt(fibo[col])].Margin,1)," ",7),val,9,"Consolas");
          UpdateLabel(field+keys[5],LPad(DoubleToStr(om[col].Fibo.Zone[FiboExt(fibo[col])].Equity,1)," ",5),val,9,"Consolas");

          fibo[col]++;
        }
      }

    UpdateLabel("lbvOQ-LPlan",ManagerStateText(om[OP_BUY].State)+":"+DoubleToStr(FiboPercent(om[OP_BUY].Level,InPercent),1)+"%",clrDarkGray);
    UpdateLabel("lbvOQ-SPlan",ManagerStateText(om[OP_SELL].State)+":"+DoubleToStr(FiboPercent(om[OP_SELL].Level,InPercent),1)+"%",clrDarkGray);

    //-- Wave Action (WA) --
    if (ObjectGet("bxhWA-Long",OBJPROP_BGCOLOR)==clrBoxOff||pfractal.Event(NewWaveReversal))
    {
      UpdateBox("bxhWA-Long",clrBoxOff);
      UpdateBox("bxhWA-Short",clrBoxOff);
      
      if (pfractal.WaveSegment(OP_BUY).IsOpen)
        UpdateBox("bxhWA-Long",clrDarkGreen);        

      if (pfractal.WaveSegment(OP_SELL).IsOpen)
        UpdateBox("bxhWA-Short",clrMaroon);
    }

    for (ActionState row=Bank;row<Hold;row++)
      for (int col=OP_BUY;col<=OP_SELL;col++)
        UpdateLabel("lbvWA-"+(string)col+":"+(string)row,DoubleToStr(pfractal.ActionLine(col,row),Digits),Color(pfractal.ActionLine(col,row),IN_PROXIMITY));


    //-- Wave State (WS) --
    if (ObjectGet("bxhWS-Crest",OBJPROP_BGCOLOR)==clrBoxOff||pfractal.Event(NewWaveOpen))
    {
      UpdateBox("bxhWS-Long",clrBoxOff);
      UpdateBox("bxhWS-Short",clrBoxOff);
      UpdateBox("bxhWS-Crest",clrBoxOff);
      UpdateBox("bxhWS-Trough",clrBoxOff);
      UpdateBox("bxhWS-Decay",clrBoxOff);

      if (pfractal.WaveSegment(OP_BUY).IsOpen)
        UpdateBox("bxhWS-Long",clrDarkGreen);
      
      if (pfractal.WaveSegment(OP_SELL).IsOpen)
        UpdateBox("bxhWS-Short",clrMaroon);

      switch (pfractal.ActiveSegment().Type)
      {
        case Crest:     UpdateBox("bxhWS-Crest",clrDarkGreen);
                        break;
        case Trough:    UpdateBox("bxhWS-Trough",clrMaroon);
                        break;
        case Decay:     UpdateBox("bxhWS-Decay",BoolToInt(pfractal.WaveSegment(Last).Type==Crest,clrDarkGreen,clrMaroon));
                        if (pfractal.WaveSegment(Last).Type==Crest)
                          UpdateBox("bxhWS-Crest",Color(pfractal.WaveSegment(Last).Direction,IN_DARK_DIR));
                        else
                          UpdateBox("bxhWS-Trough",Color(pfractal.WaveSegment(Last).Direction,IN_DARK_DIR));
      }
    }

    string colHead[5]  = {"L","S","C","T","D"};

    for (int row=0;row<5;row++)
      for (int col=0;col<5;col++)
      {
        if (row==0)
          UpdateLabel("lbvWS-#"+colHead[col]+(string)row,(string)pfractal.WaveSegment(col).Count,Color(pfractal.WaveSegment(Last).Direction),14);
          
        UpdateLabel("lbvWS-"+colHead[col]+(string)row,DoubleToStr(pwSegMatrix[col][row],Digits),Color(pwSegMatrix[col][row],IN_PROXIMITY));
      }

    //-- Wave Bias (WB) --
    UpdateLabel("lbvWB-IntDev",NegLPad(Pip(Close[0]-pwInterlacePivot[Action(pwInterlaceBrkDir,InDirection)]),1),
                            Color(Close[0]-pwInterlacePivot[Action(pwInterlaceBrkDir,InDirection)]),20);
    
    UpdateLabel("lbvWB-IntPivot",DoubleToStr(pwInterlacePivot[Action(pwInterlaceBrkDir,InDirection)],Digits),clrDarkGray);
    UpdateDirection("lbvWB-IntBrkDir",pwInterlaceBrkDir,Color(pwInterlaceBrkDir),28);
    UpdateDirection("lbvWB-IntDir",pwInterlaceDir,Color(pwInterlaceDir),12);

    //-- Row Two --
    
    //-- Interlace Queue (IQ) --
    UpdateBox("bxhIQ",Color(pwInterlaceDir,IN_DARK_DIR));
    
    for (int row=0;row<25;row++)
      if (row<ArraySize(pwInterlace))
        UpdateLabel("lbvIQ"+(string)row,DoubleToStr(pwInterlace[row],Digits),Color(pwInterlace[row],IN_PROXIMITY));
      else
        UpdateLabel("lbvIQ"+(string)row,"");


    UpdateLabel("lbvWF-WaveState",EnumToString(pfractal.ActiveWave().Type)+" "
                      +BoolToStr(pfractal.ActiveSegment().Type==Decay,"Decay ")
                      +EnumToString(pfractal.WaveState()),DirColor(pfractal.ActiveWave().Direction));
                      

    UpdateLabel("lbvWF-LongState",EnumToString(pfractal.ActionState(OP_BUY)),DirColor(pfractal.ActiveSegment().Direction));                     
    UpdateLabel("lbvWF-ShortState",EnumToString(pfractal.ActionState(OP_SELL)),DirColor(pfractal.ActiveSegment().Direction));
        
    UpdateLabel("lbvWF-Retrace","Retrace",BoolToInt(pfractal.Wave().Retrace,clrYellow,clrDarkGray));
    UpdateLabel("lbvWF-Breakout","Breakout",BoolToInt(pfractal.Wave().Breakout,clrYellow,clrDarkGray));
    UpdateLabel("lbvWF-Reversal","Reversal",BoolToInt(pfractal.Wave().Reversal,clrYellow,clrDarkGray));
    UpdateLabel("lbvWF-Bank","Bank",BoolToInt(pfractal.Wave().Bank,clrYellow,clrDarkGray));
    UpdateLabel("lbvWF-Kill","Kill",BoolToInt(pfractal.Wave().Kill,clrYellow,clrDarkGray));
    
    //--- Fractal Area (FA) --
    string faVar[6]    = {"o","tr","tm","b","e","rt"};

    for (int row=0;row<7;row++)
    {
      for (int col=0;col<3;col++)
      {
        UpdateBox("bxfFA-"+BoolToStr(row==0,faVar[col+3],faVar[col])+":"+(string)row,fdetail[row].FiboColor[col]);
        UpdateLabel("lbvFA-"+BoolToStr(row==0,faVar[col+3],faVar[col])+":"+(string)row+"e",LPad(DoubleToStr(fdetail[row].Expansion[col]*100,1)," ",8),clrDarkGray,12,"Consolas");
        UpdateLabel("lbvFA-"+BoolToStr(row==0,faVar[col+3],faVar[col])+":"+(string)row+"rt",LPad(DoubleToStr(fdetail[row].Retrace[col]*100,1)," ",8),clrDarkGray,12,"Consolas");
      }

      UpdateLabel("lbvFA-H1:"+(string)row,fdetail[row].Heading,fdetail[row].HeadColor[0],14);
      UpdateLabel("lbvFA-H2:"+(string)row,fdetail[row].SubHead,fdetail[row].HeadColor[1],10);
      UpdateLabel("lbvFA-State:"+(string)row,fdetail[row].State,fdetail[row].HeadColor[2],14);

      UpdateDirection("lbvFA-ADir:"+(string)row,fdetail[row].ActiveDir,Color(fdetail[row].ActiveDir),28);
      UpdateDirection("lbvFA-BDir:"+(string)row,fdetail[row].BreakoutDir,Color(fdetail[row].BreakoutDir),12);
    }
  }

//+------------------------------------------------------------------+
//| ShowZoneLines - Display zone lines                               |
//+------------------------------------------------------------------+
void ShowZoneLines(void)
  {
    static int szlZone       = OP_NO_ACTION;

    if (IsChanged(szlZone,rsFiboAction)||detail[Daily].NewFractal)
      for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
        UpdateLine("lnZone:"+DoubleToStr(FiboLevels[fabs(fibo)]*Direction(fibo)*100,1),
          om[rsFiboAction].Fibo.Price[FiboExt(fibo)],STYLE_SOLID,
          BoolToInt(fibo==0,clrYellow,Color(fibo,IN_DARK_DIR)));
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
    }
    
    if (IsChanged(zlZone,rsFiboAction))
    {
      ZeroPriceTags();

      for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
        UpdateLine("lnZone:"+DoubleToStr(FiboLevels[fabs(fibo)]*Direction(fibo)*100,1),0.00);
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

        UpdateLine("lnCeiling",detail[rsSession].Ceiling,STYLE_DOT,clrDarkGreen);
        UpdateLine("lnFloor",detail[rsSession].Floor,STYLE_DOT,clrMaroon);
      }
    }
    else    
    if (rsFiboAction>OP_NO_ACTION)
      ShowZoneLines();
    else
    {
      if (rsWaveAction>OP_NO_ACTION)
      {
        UpdatePriceLabel("plbInterlaceHigh",pwInterlace[0],clrYellow);
        UpdatePriceLabel("plbInterlaceLow",pwInterlace[ArraySize(pwInterlace)-1],clrYellow);
    
        if (pwInterlaceBrkDir==DirectionUp)
        {
          UpdatePriceLabel("plbInterlacePivotActive",pwInterlacePivot[OP_BUY],clrLawnGreen);
          UpdatePriceLabel("plbInterlacePivotInactive",pwInterlacePivot[OP_SELL],clrDarkGray);
        }
        else
        if (pwInterlaceBrkDir==DirectionDown)
        {
          UpdatePriceLabel("plbInterlacePivotActive",pwInterlacePivot[OP_SELL],clrRed);
         UpdatePriceLabel("plbInterlacePivotInactive",pwInterlacePivot[OP_BUY],clrDarkGray);
        }
        else
        {
          UpdatePriceLabel("plbInterlacePivotActive",0.00,clrDarkGray);
          UpdatePriceLabel("plbInterlacePivotInactive",0.00,clrDarkGray);
        }
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
      
    if (rsShowPitch)
      for (SessionType show=Daily;show<SessionTypes;show++)
        UpdatePriceLabel("plbPitch"+EnumToString(show),detail[show].Pitch,SessionColor(show));

    //--- Show Pipma Alerts
    if (SourceAlerts[indPipMA] && !PauseOnHistory)
      for (EventType type=1;type<EventTypes;type++)
        if (Alerts[type]&&pfractal.Event(type))
        {
          Append(rsEvent,"PipMA "+pfractal.ActiveEventText()+"\n","\n");
          break;
        }

    //--- Show Fractal Alerts
    if (SourceAlerts[indFractal])
      for (EventType type=1;type<EventTypes;type++)
        if (Alerts[type]&&fractal.Event(type))
        {
          Append(rsEvent,"Fractal "+fractal.ActiveEventText()+"\n","\n");
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
//| FindZone - Returns Fibo Zone based on Action, Price, Fibo Array  |
//+------------------------------------------------------------------+
int FindZone(int Action, FiboZone &Fibo, double Price)
  {
    switch (Action)
    {
      case OP_BUY:     for (int fibo=Fibo823;fibo>-Fibo823;fibo--)
                         if (IsLower(Fibo.Price[FiboExt(fibo)],Price,NoUpdate))
                           return FiboExt(fibo);
                       break;
   
      case OP_SELL:    for (int fibo=-Fibo823;fibo<Fibo823;fibo++)
                         if (IsHigher(Fibo.Price[FiboExt(fibo)],Price,NoUpdate))
                           return FiboExt(fibo);
                       break;   
    }

    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Account - returns the value for the requested metric             |
//+------------------------------------------------------------------+
double Account(AccountMetric Metric, int Format=InDecimal)
  {
    int    aPrecision      = 0;
    double aMetric         = 0.00;
    
    switch (Metric)
    {
      case eqPctOpen:      aMetric = (AccountEquity()-(AccountBalance()+AccountCredit()))/AccountEquity();
                                     aPrecision       = 3;
                                     break;
      case eqPctClosed:    aMetric = (AccountEquity()-(AccountBalance()+AccountCredit()))/(AccountBalance()+AccountCredit());
                                     aPrecision       = 3;
                                     break;
      case eqPctVar:       aMetric = Account(eqPctOpen)-Account(eqPctClosed);
                                     aPrecision       = 3;
                                     break;
      case eqBal:          aMetric = AccountEquity();
                                     break;
      case acBal:          aMetric = AccountBalance()+AccountCredit();
                                     break;
      case acSpread:       aMetric = Ask-Bid;
                                     aPrecision       = Digits;
                                     
                                     if (Format==InPips)
                                     {
                                       aMetric = Pip(aMetric);
                                       aPrecision     = 1;
                                     }
                                     break;
      case acEquity:       aMetric = Account(eqBal)-Account(acBal);
                                     break;
      case acMargin:       aMetric = AccountMargin()/AccountEquity();
                                     aPrecision       = 1;
                                     break;
      case lotMarginRqmt:  aMetric = BoolToDouble(Symbol()=="USDJPY",(MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)),
                                      (MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)*Close[0]))/AccountLeverage();
                                     aPrecision       = 2;
                                     break;
      case lotSizeMin:     aMetric = MarketInfo(Symbol(),MODE_MINLOT);
                                     aPrecision       = 2;
                                     break;
      case lotSizeMax:     aMetric = MarketInfo(Symbol(),MODE_MINLOT);
                                     break;
      case lotPrecision:   aMetric = BoolToInt(ordAcctMinLot==0.01,2,1);
    }

    switch (Format)
    {
      case InDecimal:     break;
      case InPercent:     aMetric*=100;
    }
    
    return (NormalizeDouble(aMetric,aPrecision));
  }

//+------------------------------------------------------------------+
//| OrderMargin                                                      |
//+------------------------------------------------------------------+
double Order(double Value, AccountMetric Metric, int Format=InPercent)
  {
    switch (Metric)
    {
      case acMargin:       switch (Format)
                           {
                             case InDecimal: return (NormalizeDouble(fdiv(Value,Account(lotSizeMin))*Account(lotMarginRqmt)/Account(eqBal),3));
                             case InPercent: return (NormalizeDouble(fdiv(Value,Account(lotSizeMin))*Account(lotMarginRqmt)/Account(eqBal)*100,1));
                             case InDollar:  return (NormalizeDouble(Value*Account(lotMarginRqmt),2));
                           }
                           break;
      case acMarginLong:   if (inpMarginModel==Discount) //-- Shared burden on trunk; majority burden on excess variance
                             return (Order(BoolToDouble(omSummary[Net].Lots>0,omSummary[Net].Lots)+
                               fdiv(fmin(om[OP_BUY].Summary.Lots,om[OP_SELL].Summary.Lots),4),acMargin,Format));
                           return (Order(om[OP_BUY].Summary.Lots,acMargin,Format));
                           break;
      case acMarginShort:  if (inpMarginModel==Discount) //-- Shared burden on trunk; majority burden on excess variance
                             return (Order(BoolToDouble(omSummary[Net].Lots<0,fabs(omSummary[Net].Lots))+
                               fdiv(fmin(om[OP_BUY].Summary.Lots,om[OP_SELL].Summary.Lots),4),acMargin,Format));
                           return (Order(om[OP_SELL].Summary.Lots,acMargin,Format));
                           break;
      case acEquity:       switch (Format)
                           {
                             case InDecimal: return (NormalizeDouble(fdiv(Value,Account(eqBal)),3));
                             case InPercent: return (NormalizeDouble(fdiv(Value,Account(eqBal)),3)*100);
                             case InDollar:  return (NormalizeDouble(Value,2));
                           }
                           break;
    };
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| UpdateOrders - Updates order detail stats by action              |
//+------------------------------------------------------------------+
void UpdateOrders(void)
  {
    AccountMetric uoAccountMetric                        = acMarginLong;
    
    //-- Set zone details on NewFractal
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      om[action].Summary.Count                = 0;
      om[action].Summary.Lots                 = 0.00;
      om[action].Summary.Value                = 0.00;
      om[action].Summary.Margin               = 0.00;
      om[action].Summary.Equity               = 0.00;     
      
      for (int pos=0;pos<Total;pos++)
      {
        omSummary[pos].Count                  = 0;
        omSummary[pos].Lots                   = 0.00;
        omSummary[pos].Value                  = 0.00;
        omSummary[pos].Margin                 = 0.00;
        omSummary[pos].Equity                 = 0.00;
      }
    
      for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
      {
        om[action].Fibo.Zone[FiboExt(fibo)].Count  = 0;
        om[action].Fibo.Zone[FiboExt(fibo)].Lots   = 0.00;
        om[action].Fibo.Zone[FiboExt(fibo)].Value  = 0.00;
        om[action].Fibo.Zone[FiboExt(fibo)].Margin = 0.00;
        om[action].Fibo.Zone[FiboExt(fibo)].Equity = 0.00;
  
        if (detail[Daily].NewFractal)
          om[Action(detail[Daily].FractalDir,InDirection,InContrarian)].Fibo.Price[FiboExt(fibo)]   = 
            detail[Daily].FractalPivot[Action(detail[Daily].FractalDir,InDirection)]+(Pip(FiboLevels[fabs(fibo)]*100*Direction(fibo),InPoints));
      }
    }
        
    //-- Order preliminary aggregation
    for (int action=OP_BUY;action<=OP_SELL;action++)
      for (int ord=0;ord<OrdersTotal();ord++)
        if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
          if (OrderType()==action)
          {
            //-- Agg By Action
            om[action].Summary.Count++;
            om[action].Summary.Lots        += OrderLots();
            om[action].Summary.Value       += OrderProfit();

            //-- Agg By P/L
            if (NormalizeDouble(OrderProfit(),2)<0.00)
            {
              omSummary[Loss].Count++;
              omSummary[Loss].Lots         += OrderLots();
              omSummary[Loss].Value        += OrderProfit();
            }
            else
            {
              omSummary[Profit].Count++;
              omSummary[Profit].Lots       += OrderLots();
              omSummary[Profit].Value      += OrderProfit();
            }
            
            //-- Agg By Fibo
            om[action].Fibo.Zone[FindZone(action,om[action].Fibo,OrderOpenPrice())].Count++;
            om[action].Fibo.Zone[FindZone(action,om[action].Fibo,OrderOpenPrice())].Lots    += OrderLots();
            om[action].Fibo.Zone[FindZone(action,om[action].Fibo,OrderOpenPrice())].Value   += OrderProfit();            
          }

    //-- Compute interim Net Values req'd by Equity/Margin calcs
    omSummary[Net].Lots                     = om[OP_BUY].Summary.Lots-om[OP_SELL].Summary.Lots;
    omSummary[Net].Value                    = om[OP_BUY].Summary.Value+om[OP_SELL].Summary.Value;

    //-- Calculate zone values and margins
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
      {
        om[action].Fibo.Zone[FiboExt(fibo)].Margin = Order(om[action].Fibo.Zone[FiboExt(fibo)].Lots,uoAccountMetric,InPercent)*
                                                       fdiv(om[action].Fibo.Zone[FiboExt(fibo)].Lots,om[action].Summary.Lots,1);
        om[action].Fibo.Zone[FiboExt(fibo)].Equity = Order(om[action].Fibo.Zone[FiboExt(fibo)].Value,acEquity,InPercent);
      }
      
      //-- Calc Action Aggregates
      om[action].Summary.Equity             = Order(om[action].Summary.Value,acEquity,InPercent);
      om[action].Summary.Margin             = Order(om[action].Summary.Lots,uoAccountMetric,InPercent);
      
      uoAccountMetric                       = acMarginShort;
    }

    //-- Calc P/L Aggregates
    omSummary[Profit].Equity                = Order(omSummary[Profit].Value,acEquity,InPercent);
    omSummary[Profit].Margin                = Order(omSummary[Profit].Lots,acMargin,InPercent);

    omSummary[Loss].Equity                  = Order(omSummary[Loss].Value,acEquity,InPercent);
    omSummary[Loss].Margin                  = Order(omSummary[Loss].Lots,acMargin,InPercent);

    //-- Calc Net Aggregates
    omSummary[Net].Equity                   = Order(omSummary[Net].Value,acEquity,InPercent);
    omSummary[Net].Margin                   = Order(omSummary[Net].Lots,acMargin,InPercent);
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

      CallPause("Error: Bias Differential: Fractal Bias/Change Error");
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
      
      //-- Fractal Detail Update
      int faType       = type+2;
      
      ArrayInitialize(fdetail[faType].HeadColor,clrDarkGray);
      
      fdetail[faType].Heading = EnumToString(type)+" "+proper(ActionText(session[type][ActiveSession].Bias))+
                  " "+BoolToStr(session[type][ActiveSession].Bias==Action(session[type][ActiveSession].Direction,InDirection),"Hold","Hedge");

      fdetail[faType].ActiveDir        = session[type][ActiveSession].Direction;
      fdetail[faType].BreakoutDir      = session[type][ActiveSession].BreakoutDir;
      fdetail[faType].State            = EnumToString(session[type][ActiveSession].State);
      
      if (session[type].IsOpen())
      {
        fdetail[faType].HeadColor[0]   = clrWhite;
        
        if (ServerHour()>session[type].SessionHour(SessionClose)-3)
        {
          fdetail[faType].SubHead      = "Late Session ("+IntegerToString(session[type].SessionHour())+")";
          fdetail[faType].HeadColor[1] = clrRed;
        }
        else
        if (session[type].SessionHour()>3)
        {
          fdetail[faType].SubHead      = "Mid Session ("+IntegerToString(session[type].SessionHour())+")";
          fdetail[faType].HeadColor[1] = clrYellow;
        }
        else
        {
          fdetail[faType].SubHead      = "Early Session ("+IntegerToString(session[type].SessionHour())+")";
          fdetail[faType].HeadColor[1] = clrLawnGreen;
        }
      }
      else
        fdetail[faType].SubHead        = "Session Is Closed";

      if (session[type].Event(NewBreakout) || session[type].Event(NewReversal))
        fdetail[faType].HeadColor[2]   = clrWhite;
      else
      if (session[type].Event(NewRally) || session[type].Event(NewPullback))
        fdetail[faType].HeadColor[2]   = clrYellow;

      for (FractalType fibo=ftOrigin;fibo<ftPrior;fibo++)
      {
        fdetail[faType].Expansion[fibo] = session[type].Expansion(fibo,Now,InDecimal);
        fdetail[faType].Retrace[fibo]   = session[type].Retrace(fibo,Now,InDecimal);
        fdetail[faType].FiboColor[fibo] = (color)BoolToInt(session[type].Fractal(fibo).Direction==DirectionUp,C'0,42,0',C'42,0,0');
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
    double upmaPrice[5];
    
    pfractal.Update();
 
    //--- Extract and Process wave segment data
    pwWork.Clear();
    
    //-- Extract the wave segment matrices
    for (int seg=0;seg<5;seg++)
    {
      upmaPrice[0]                     = pfractal.WaveSegment(SegmentType[seg]).Open;
      upmaPrice[1]                     = pfractal.WaveSegment(SegmentType[seg]).High;
      upmaPrice[2]                     = pfractal.WaveSegment(SegmentType[seg]).Low;
      upmaPrice[3]                     = pfractal.WaveSegment(SegmentType[seg]).Close;
      upmaPrice[4]                     = pfractal.WaveSegment(SegmentType[seg]).Retrace;
      
      ArraySort(upmaPrice,WHOLE_ARRAY,0,MODE_DESCEND);
      
      for (int copy=0;copy<5;copy++)
      {
        pwSegMatrix[seg][copy]         = upmaPrice[copy];
        pwWork.Add(upmaPrice[copy]);
      }
    }
    
    //--- Update Inerlace Queue
    pwWork.CopyFiltered(pwInterlace,false,false,MODE_DESCEND);
    pwInterlaceDir                     = BoolToInt(fdiv(pwInterlace[0]+pwInterlace[ArraySize(pwInterlace)-1],2,Digits)<Close[0],DirectionUp,DirectionDown);

    if (IsEqual(Close[0],pwInterlace[0]))
      if (NewDirection(pwInterlaceBrkDir,DirectionUp))
        pwInterlacePivot[OP_BUY]       = Close[0];

    if (IsEqual(Close[0],pwInterlace[ArraySize(pwInterlace)-1]))
      if (NewDirection(pwInterlaceBrkDir,DirectionDown))
        pwInterlacePivot[OP_SELL]      = Close[0];

    //-- Update CPanel Values (Micro)
    ArrayInitialize(fdetail[fatPipMA].HeadColor,clrDarkGray);
    
    fdetail[fatPipMA].Heading          = EnumToString(pfractal.State().Bearing)+" "+proper(ActionText(pfractal.State().Bias));
    fdetail[fatPipMA].SubHead          = pfractal.StateText();
    
    fdetail[fatPipMA].State            = EnumToString(pfractal.State().Type[pftOrigin]);

    fdetail[fatPipMA].ActiveDir        = pfractal.Direction(pftTerm);
    fdetail[fatPipMA].BreakoutDir      = pfractal.Direction(pftTrend);

    fdetail[fatPipMA].Expansion[0]     = pfractal.Fibonacci(pftOrigin,Expansion,Now);
    fdetail[fatPipMA].Expansion[1]     = pfractal.Fibonacci(pftTrend,Expansion,Now);
    fdetail[fatPipMA].Expansion[2]     = pfractal.Fibonacci(pftTerm,Expansion,Now);
    
    fdetail[fatPipMA].FiboColor[0]     = Color(pfractal.Direction(pftOrigin),IN_DARK_PANEL);
    fdetail[fatPipMA].FiboColor[1]     = Color(pfractal.Direction(pftTrend),IN_DARK_PANEL);
    fdetail[fatPipMA].FiboColor[2]     = Color(pfractal.Direction(pftTerm),IN_DARK_PANEL);

    fdetail[fatPipMA].Retrace[0]       = pfractal.Fibonacci(pftOrigin,Retrace,Now);
    fdetail[fatPipMA].Retrace[1]       = pfractal.Fibonacci(pftTrend,Retrace,Now);
    fdetail[fatPipMA].Retrace[2]       = pfractal.Fibonacci(pftTerm,Retrace,Now);
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Update Macro Fractal data                        |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {    
    static FibonacciLevel ufExpand[4]  = {Fibo161,Fibo161,Fibo161,Fibo161};

    fractal.Update();
    
    if (fractal.Event(NewFractal,Major))
    {
      Flag("Major",clrWhite,rsShowFlags);
      
      if (fractal.IsRange(Divergent))
        ArrayInitialize(ufExpand,Fibo161);
    }
    else
    {
      //--Origin Fibo Flags
      if (FiboLevels[ufExpand[3]]<fractal.Fibonacci(Origin,fpExpansion,Now))
      {
        Flag("Origin "+EnumToString(ufExpand[3]),clrRed,rsShowFlags);
        ufExpand[3]++;
      }

      //-- Base Fibo Flags
      if (FiboLevels[ufExpand[2]]<fractal.Fibonacci(Base,fpExpansion,Now))
      {
        Flag("Base "+EnumToString(ufExpand[2]),clrGray,rsShowFlags);
        ufExpand[2]++;
      }

      //-- Trend/Term Fibo Flags
      for (RetraceType fibo=Trend;fibo<=Term;fibo++)
        if (FiboLevels[ufExpand[fibo]]<fractal.Fibonacci(fibo,fpExpansion,Now))
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
    //-- Update Fractal Matrix (Meso)
    ArrayInitialize(fdetail[fatMeso].HeadColor,Color(fractal.Direction(Expansion)));
    ArrayInitialize(fdetail[fatMeso].FiboColor,BoolToInt(fractal.Direction(Expansion)==DirectionUp,C'0,42,0',C'42,0,0'));
    
    for (RetraceType type=fractal.Leg(Active);type>Root;type--)
      if (fractal[type].Bar>inpAgingThreshold)
      {
        fdetail[fatMeso].SubHead        = EnumToString(type)+" ("+(string)fractal[type].Bar+")";

        if (fractal.Direction(type)==fractal.Direction(Expansion))
          fdetail[fatMeso].HeadColor[1] = clrYellow;
        break;
      }
    
    fdetail[fatMeso].Heading            = proper(DirText(fractal.Direction(Base)))+" "+BoolToStr(fractal.BarDir()==DirectionUp,"Rally","Pullback");
    fdetail[fatMeso].State              = EnumToString(fractal.State(Active));

    if (fractal.State(Active)==Correction)
      fdetail[fatMeso].HeadColor[2]     = Color(fractal.Direction(Expansion),IN_DIRECTION,Contrarian);
      
    if (fractal.State(Active)==Retrace)
      fdetail[fatMeso].HeadColor[2]     = clrYellow;

    fdetail[fatMeso].ActiveDir          = fractal.Direction(Base);
    fdetail[fatMeso].BreakoutDir        = fractal.Origin().Direction;
    fdetail[fatMeso].FiboColor[2]       = (color)BoolToInt(fractal.Direction(fractal.Leg(Min))==DirectionUp,C'0,42,0',C'42,0,0');

    fdetail[fatMeso].Expansion[0]       = fractal.Fibonacci(Base,fpExpansion,Max);
    fdetail[fatMeso].Expansion[1]       = fractal.Fibonacci(Base,fpExpansion,Now);
    fdetail[fatMeso].Expansion[2]       = fractal.Fibonacci(fractal.Previous(fractal.Leg(Min),Convergent),fpExpansion,Now);

    fdetail[fatMeso].Retrace[0]         = fractal.Fibonacci(Base,fpRetrace,Max);
    fdetail[fatMeso].Retrace[1]         = fractal.Fibonacci(Base,fpRetrace,Now);
    fdetail[fatMeso].Retrace[2]         = fractal.Fibonacci(fractal.Previous(fractal.Leg(Min),Convergent),fpRetrace,Now);

    //-- Update CPanel Values (Macro)
    ArrayInitialize(fdetail[fatMacro].HeadColor,Color(fractal.Origin().Direction));
    ArrayInitialize(fdetail[fatMacro].FiboColor,BoolToInt(fractal.Direction(Expansion)==DirectionUp,C'0,42,0',C'42,0,0'));    
    
    fdetail[fatMacro].Heading           = BoolToStr(fractal.Origin().Direction==DirectionUp,"Long","Short")+" "+EnumToString(fractal.Origin().State);
    Append(fdetail[fatMacro].Heading,BoolToStr(fractal.Origin().Correction,"Correction"));
    fdetail[fatMacro].SubHead           = BoolToStr(fractal.IsRange(Divergent,Origin),"Divergent","Convergent");
    
    if (fractal.IsRange(Divergent))
      fdetail[fatMacro].HeadColor[1]    = clrYellow;

    fdetail[fatMacro].State             = EnumToString(fractal.State(Origin));

    if (fractal.State(Origin)==Correction)
      fdetail[fatMacro].HeadColor[2]    = Color(fractal.Origin().Direction,IN_DIRECTION,Contrarian);
      
    if (fractal.State(Origin)==Retrace)
      fdetail[fatMacro].HeadColor[2]    = clrYellow;

    fdetail[fatMacro].ActiveDir         = fractal.Direction();
    fdetail[fatMacro].BreakoutDir       = fractal.Origin().Direction;
    fdetail[fatMacro].FiboColor[0]      = (color)BoolToInt(fractal.Origin().Direction==DirectionUp,C'0,42,0',C'42,0,0');

    fdetail[fatMacro].Expansion[0]      = fractal.Fibonacci(Origin,fpExpansion,Now);
    fdetail[fatMacro].Expansion[1]      = fractal.Fibonacci(Trend,fpExpansion,Now);
    fdetail[fatMacro].Expansion[2]      = fractal.Fibonacci(Term,fpExpansion,Now);

    fdetail[fatMacro].Retrace[0]        = fractal.Fibonacci(Origin,fpRetrace,Now);
    fdetail[fatMacro].Retrace[1]        = fractal.Fibonacci(Trend,fpRetrace,Now);
    fdetail[fatMacro].Retrace[2]        = fractal.Fibonacci(Term,fpRetrace,Now);
  }

//+------------------------------------------------------------------+
//| OrderApproved - Performs health and sanity checks for approval   |
//+------------------------------------------------------------------+
bool OrderApproved(OrderRequest &Order)
  {
    double oaLots[6]                           = {0.00,0.00,0.00,0.00,0.00,0.00};
    
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
      
      if (IsLower(Order(oaLots[Action(Order.Action,InAction)],acMargin,InPercent),om[Action(Order.Action,InAction)].MarginTolerance,NoUpdate))
      {
        Order.Status         = Approved;
        return (true);
      }
      else
        Order.Memo           = "Margin-"+DoubleToStr(Order(oaLots[Action(Order.Action,InAction)],acMargin,InPercent),1)+"%";
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

      Order.Action           = ordOpen.Action;
      Order.Key              = ordOpen.Ticket;
      Order.Price            = ordOpen.Price;
      Order.Lots             = ordOpen.Lots;
      
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
        if (omQueue[request].Action==Action||((Action==OP_BUY||Action==OP_SELL)&&(Action(omQueue[request].Action,InAction)==Action)))
        {
          omQueue[request].Status   = Canceled;
          omQueue[request].Expiry   = Time[0]+(Period()*60);

          if (Reason!="")
            omQueue[request].Memo   = Reason;
              
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
      Order.Status           = Canceled;
      Order.Expiry           = Time[0]+(Period()*60);
      
      if (Reason!="")
        Order.Memo           = Reason;
              
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
//| OrderSubmit - Creates orders, assigns key in the OM Queue        |
//+------------------------------------------------------------------+
void OrderSubmit(OrderRequest &Order, bool QueueOrders)
  {
    while (OrderApproved(Order))
    {
      Order.Key              = omOrderKey.Count;
      Order.Status           = Pending;
    
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
    OrderRequest   smRequest = {0,OP_SELL,"Mgr:Short",0,0,0,0,"",0,NoStatus};

//    if (pfractal.Event(NewExpansion)||pfractal.Event(NewTerm))
//      if (pfractal.Direction(pftTerm)==DirectionDown)
//        om[].Spotter[OP_SELL]   = false;
//      else
//      if (IsChanged(om[].Spotter[OP_SELL],true))
//      {
//        smRequest.Lots            = OrderLotSize(0.00,fdiv(ordEQLotFactor,2));
//        smRequest.Memo            = "Spotter";
//        smRequest.Expiry          = Time[0]+(Period()*(60*2));
//        OrderSubmit(smRequest,NoQueue);
//   
//        om[].Level[OP_SELL]   = FiboLevel(pfractal.Fibonacci(pftTerm,Expansion,Now));   
//      }
//      else
//      if (IsChanged(om[].Level[OP_SELL],FiboLevel(pfractal.Fibonacci(pftTerm,Expansion,Now))))
//      {
//        smRequest.Memo            = "Rally";
//        smRequest.Expiry          = Time[0]+(Period()*(60*2));
//        OrderSubmit(smRequest,NoQueue);
//      }
  }
  
//+------------------------------------------------------------------+
//| LongManagement - Manages long order positions, profit and risk   |
//+------------------------------------------------------------------+
void LongManagement(void)
  {
    OrderRequest   lmRequest = {0,OP_BUY,"Mgr:Long",0,0,0,0,"",0,NoStatus};

//    if (pfractal.Event(NewExpansion)||pfractal.Event(NewTerm))
//      if (pfractal.Direction(pftTerm)==DirectionUp)
//        om[].Spotter[OP_BUY]    = false;
//      else
//      if (IsChanged(om[].Spotter[OP_BUY],true))
//      {
//        lmRequest.Lots              = OrderLotSize(0.00,fdiv(ordEQLotFactor,2));
//        lmRequest.Expiry            = Time[0]+(Period()*(60*2));
//        lmRequest.Memo              = "Spotter";
//        OrderSubmit(lmRequest,NoQueue);
//        
//        om[].Level[OP_BUY]      = FiboLevel(pfractal.Fibonacci(pftTerm,Expansion,Now));
//      }
//      else
//      if (IsChanged(om[].Level[OP_BUY],FiboLevel(pfractal.Fibonacci(pftTerm,Expansion,Now))))
//      {
//        lmRequest.Memo              = "Pullback";
//        lmRequest.Expiry            = Time[0]+(Period()*(60*2));
//        OrderSubmit(lmRequest,NoQueue);
//      }
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
    if (Command[0]=="ORDER ")
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
        rsFiboAction                   = OP_NO_ACTION;
         
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
              rsFiboAction             = OP_BUY;
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
              rsFiboAction             = OP_SELL;
              rsWaveAction             = OP_NO_ACTION;
            }
          }
          else
          {
            rsSegment                  = NoValue;
            rsWaveAction               = OP_NO_ACTION;
            rsFiboAction               = OP_NO_ACTION;
          }
        }
        else
        {
          rsSession                    = GetSessionType(Command[2]);
          rsFractal                    = GetFractalType(Command[3]);
        }
      }
      else
      if (Command[1]=="PITCH")
      {
        if (IsChanged(rsShowPitch,Command[2]=="ON"))
          for (SessionType type=Daily;type<SessionTypes;type++)
            UpdatePriceLabel("plbPitch"+EnumToString(type),0.00);
      }
      else
      if (StringSubstr(Command[1],0,4)=="FLAG")
        
//        if (Command[1]=="PIPMA")
//          SourceAlerts[indPipMA]         = false;
//        else
//        if (Command[1]=="SESSION")
//          SourceAlerts[indSession]       = false;
       if (Command[2]=="FRACTAL")
          rsShowFlags                  = Always;
        else
          rsShowFlags                  = false;
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
         detail[alert].Alerts          = true;
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
    
    pwWork                = new CArrayDouble(0);
    pwWork.Truncate       = false;
    pwWork.AutoExpand     = true;    
    pwWork.SetPrecision(Digits);
    pwWork.Initialize(0.00);
    
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
      session[type].Update();
      
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
      detail[type].Ceiling                = session[type][PriorSession].High;
      detail[type].Floor                  = session[type][PriorSession].Low;
      
      if (session[type].IsOpen())
        detail[type].Pitch                = fdiv(session[type][ActiveSession].High+session[type][ActiveSession].Low,2);
      else
      if (session[type].Fractal(ftTerm).Direction==DirectionUp)
        detail[type].Pitch                = fdiv(session[type].Fractal(ftTerm).High+session[type][PriorSession].Low,2);
      else
      if (session[type].Fractal(ftTerm).Direction==DirectionDown)
        detail[type].Pitch                = fdiv(session[type][PriorSession].High+session[type].Fractal(ftTerm).Low,2);
      else
        detail[type].Pitch                = session[type].Pivot(ActiveSession);

      NewPriceLabel("plbPitch"+EnumToString(type));
    }

    UpdateSession();
    CalcFractalBias(Daily);

    detail[Daily].FractalPivot[OP_BUY]    = fmax(session[Daily].Fractal(ftTerm).Resistance,session[Daily].Fractal(ftTerm).High);
    detail[Daily].FractalPivot[OP_SELL]   = fmin(session[Daily].Fractal(ftTerm).Support,session[Daily].Fractal(ftTerm).Low);

    ArrayInitialize(pwInterlacePivot,Close[0]);
    
    //--- Initialize Fibo Management
    for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
    {
      NewLine("lnZone:"+DoubleToStr(FiboLevels[fabs(fibo)]*Direction(fibo)*100,1));
      om[OP_BUY].Fibo.Price[FiboExt(fibo)]  = detail[Daily].FractalPivot[OP_SELL]+(Pip(FiboLevels[fabs(fibo)]*100*Direction(fibo),InPoints));
      om[OP_SELL].Fibo.Price[FiboExt(fibo)] = detail[Daily].FractalPivot[OP_BUY]+(Pip(FiboLevels[fabs(fibo)]*100*Direction(fibo),InPoints));
    }
    
    //--- Initialize Order Directives
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      om[action].MarginTolerance   = inpMarginTolerance;
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
    delete pwWork;
    delete omOrderKey;
  }