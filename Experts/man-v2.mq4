//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#define   clrBoxOff      C'60,60,60'
#define   clrBoxRedOff   C'42,0,0'
#define   clrBoxGreenOff C'0,42,0'
#define   NoQueue        false

#include <manual.mqh>
#include <Class\Fractal.mqh>
#include <Class\PipFractal.mqh>
#include <Class\Session.mqh>
#include <Class\Order.mqh>

  //-- Output Control
  enum DisplayTypes
  {
                   Display,
                   Log
  };

  //--- Indicators
  enum          SourceType
                {
                   Advisor,         // Application
                   PipMA,           // PipMA
                   Fractal,         // Fractal
                   Session,         // Session
                   SourceTypes      // None
                };

  //--- Action States
  enum          ActionState
                {
                   Bank,         //--- Profit management slider
                   Goal,         //--- Out-of-Band indcator
                   Yield,        //--- line of the last hard crest or trough
                   Go,           //--- Where it started, the first OOB line
                   Build,        //--- Pulback/Rally box - manage risk/increase volume
                   Risk,         //--- Intermediate support/resistance levels - cover or balance
                   Opportunity,  //--- First entry reversal alert
                   Chance,       //--- Recovery management slider
                   Mercy,        //--- retained prior intial breakout point, for "mercy" rallies/pullbacks
                   Stop,         //--- main support/resistance boundary;
                   Quit,         //--- Forward contrarian progress line; if inbounds, manage risk; oob - kill;
                   Kill,         //--- Risk Management slider
                   Keep          //--- When nothing statistically viable occurs
                 };

input string       EAHeader            = "";           //+------ App Config inputs ------+
input int          inpStall            = 6;            // Fractal Stall Factor in Periods
input int          inpShortTermTL      = 6;            // Short Term Trend Regression Periods
input YesNoType    inpShowMasterLines  = Yes;          // Show Master Lines
input YesNoType    inpShowBroken       = No;           // Show Broken/Unbroken Flags
input SourceType   inpComment          = SourceTypes;  // Show Indicator in Comment

input string       FractalHeader       = "";           //+------ Fractal Options ---------+
input int          inpRangeMin         = 60;           // Minimum fractal pip range
input int          inpRangeMax         = 120;          // Maximum fractal pip range
input YesNoType    inpShowFlags        = No;           // Show fractal event flags

input string       PipMAHeader         = "";           //+------ PipMA inputs ------+
input int          inpDegree           = 6;            // Degree of poly regression
input int          inpPeriods          = 200;          // Number of poly regression periods
input double       inpTolerance        = 0.5;          // Trend change tolerance (sensitivity)
input double       inpAggFactor        = 2.5;          // Tick Aggregate factor (1=1 PIP);
input int          inpIdleTime         = 50;           // Market idle time in Pips

input string       SessionHeader       = "";           //+---- Session Hours -------+
input int          inpAsiaOpen         = 1;            // Asian market open hour
input int          inpAsiaClose        = 10;           // Asian market close hour
input int          inpEuropeOpen       = 8;            // Europe market open hour`
input int          inpEuropeClose      = 18;           // Europe market close hour
input int          inpUSOpen           = 14;           // US market open hour
input int          inpUSClose          = 23;           // US market close hour
input int          inpGMTOffset        = 0;            // GMT Offset

  //-- General Operationals
  bool             PauseOn             = true;
  bool             PrintOn             = false;

  //--- Class Objects
  COrder          *order             = new COrder(Discount,Hold,Hold);
  CFractal        *f                 = new CFractal(inpRangeMax,inpRangeMin,inpShowFlags==Yes);
  CPipFractal     *pf                = new CPipFractal(inpDegree,inpPeriods,inpTolerance,inpAggFactor,inpIdleTime);
  CSession        *s[SessionTypes];

  struct           FiboPanel        //-- Distilled Fibo data
                   {
                     int             Direction;
                     string          Text[3];
                   };

  struct           FractalPanel
                   {
                     int             ActiveDir;
                     int             BreakoutDir;
                     int             Bias;
                     bool            Trigger;
                     string          Text[3];
                     int             Color[3];
                     FiboPanel       Fibo[3];
                   };

  struct           FractalMaster
                   {
                     SourceType      Source;
                     SessionType     Session;
                     int             Direction;
                     int             BreakoutDir;
                     int             Bias;
                     double          Weight;
                     bool            Hedge;
                     EventType       Event;
                     FractalState    State;
                     FractalDetail   Fibo[3];
                   };

  struct           PivotRec          //-- Price Consolidation Pivots
                   {
                     int             Direction;
                     int             Count;
                     double          Open;
                     double          Close;
                     double          High;
                     double          Low;
                   };

  struct           MicroLine
                   {
                     double          Line[];
                     double          Buffer[];
                     double          Slope;
                   };

  struct           MomentumDetail
                   {
                     int             Direction;
                     int             Bias;
                     double          Momentum;
                     bool            Trigger;
                     bool            Hedge;
                   };

  struct           MicroMaster     //-- Micro trend histogram
                   {
                     int             Direction;
                     int             Bias;
                     bool            Trigger[2];
                     MomentumDetail  FOC;            //-- FOC momentum
                     bool            GapAnomaly;     //-- anomaly trigger; fired once on occurrence
                     int             GapBias;        //-- anomaly found; testing for actionable viability
                     MomentumDetail  Slope;          //-- Slope aggregate
                     MicroLine       Open;           //-- Small Linear Regression Buffer (Opens)
                     MicroLine       Close;          //-- Small Linear Regression Buffer (Closes)
                   };

  struct           PivotSet
                   {
                     PivotRec        Lead;
                     PivotRec        Prior;
                   };

  struct           PivotMaster
                   {
                     int             Action;         //-- Consolidation Pivot Action
                     int             Direction;      //-- Tick Direction
                     int             Segment;        //-- Count of Consolidation Segments;
                     FractalState    State;          //-- {TBD} Master State
                     int             Bias;           //-- Master Bias (Action/Contrarian Hedge)
                     bool            Broken;         //-- Master broken flag;
                     EventType       Event;          //-- Last Event (Dir Change, Corr/Reco, et al.
                     bool            Peg;            //-- Hold Breakout/Reversal until pegged
                     double          Recovery[2];    //-- Master critical pivot recovery by action
                     double          Correction[2];  //-- Master critical pivot correction by action
                     PivotSet        Master;         //-- Micro Trend Pivots
                     PivotSet        Active;         //-- Active Term Legs 
                     PivotSet        Pivot;          //-- Consolidation Pivots Lead/Prior
                     PivotSet        Tick;           //-- Full Tick Lead/Prior
                   };

  struct           ActionMaster
                   {
//                     ActionState     State;
                     bool            Triggered;
                     bool            NewZone;
                     OrderSummary    Zone;
                   };

  //-- General Operational variables
  AccountMetrics Account;
                                   
  //--- Collections
  FractalMaster    fm[8];
  PivotMaster      pm;
  MicroMaster      mm;            //-- Micro Trend Histogram
  ActionMaster     am[2];

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (PauseOn)
      Pause(Message,AccountCompany()+" Event Trapper");
    else
      Print(Message);
  }

//+------------------------------------------------------------------+
//| ServerHour - returns the server hour adjusted for gmt            |
//+------------------------------------------------------------------+
int ServerHour(void)
  { 
    return (TimeHour(s[Daily].ServerTime()));
  }

//+------------------------------------------------------------------+
//| RefreshFractalPanel - Refresh Fractal Area labels (v3-v4)        |
//+------------------------------------------------------------------+
void RefreshFractalPanel(int Row, FractalPanel &Panel)
  {
    for (int pane=0;pane<3;pane++)
    {
      UpdateLabel("lbvFA-HD"+(string)pane+":"+(string)Row,Panel.Text[pane],Panel.Color[pane],BoolToInt(pane==2,10,14));

      UpdateBox("bxfFA-"+(string)Row+":"+(string)pane,Color(Panel.Fibo[pane].Direction,IN_DARK_PANEL));
      UpdateLabel("lbvFA-H"+(string)Row+":"+(string)pane,center(Panel.Fibo[pane].Text[0],10),clrGoldenrod);
      UpdateLabel("lbvFA-E"+(string)Row+":"+(string)pane,center(Panel.Fibo[pane].Text[1],10),clrDarkGray,10);
      UpdateLabel("lbvFA-R"+(string)Row+":"+(string)pane,center(Panel.Fibo[pane].Text[2],10),clrDarkGray,10);
    }

    UpdateBox("bxfFA-Bias:"+(string)Row,Color(Direction(Panel.Bias,InAction),IN_DARK_PANEL));
    UpdateBox("bxfFA-Info:"+(string)Row,Color(Direction(Panel.Bias,InAction),IN_DARK_PANEL));
    
    UpdateDirection("lbvFA-ADir:"+(string)Row,Panel.ActiveDir,Color(Panel.ActiveDir),28);
    UpdateDirection("lbvFA-BDir:"+(string)Row,Panel.BreakoutDir,Color(Panel.BreakoutDir),12);

    UpdateLabel("lbvFA-Trigger:"+(string)Row,CharToStr(177),BoolToInt(Panel.Trigger,Color(Direction(Panel.Bias,InAction),IN_CHART_DIR),clrDarkGray),14,"Wingdings");
  }

//+------------------------------------------------------------------+  
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string text      = "----- Manual-v2 -----";
    
    Append(text,"History "+BoolToStr(pf.HistoryLoaded(),"Loaded","Loading...")+" ["+IntegerToString(pf.History(),5)+"]","\n");
    
    if (inpShowMasterLines==Yes)
    {
      UpdateLine("Master[Lead].High",pm.Master.Lead.High,STYLE_SOLID,Color(Direction(pm.Bias,InAction)));
      UpdateLine("Master[Lead].Low",pm.Master.Lead.Low,STYLE_SOLID,Color(Direction(pm.Bias,InAction)));
      UpdateLine("Master[Lead].Close",pm.Master.Lead.Close,STYLE_DOT,Color(Direction(pm.Bias,InAction)));
    }

    switch (inpComment)
    {
      case Advisor:   Comment(text+"\n"+MicroMasterStr());
                      break;
      case Fractal:   f.RefreshScreen(true);
                      break;
      case PipMA:     pf.RefreshScreen();
                      break;
      case Session:   s[Daily].RefreshScreen();
                      break;
    }

    //-- Session Open/Close Button Update
    for (SessionType session=Daily;session<SessionTypes;session++)
      if (ObjectGet("bxhAI-Session"+EnumToString(session),OBJPROP_BGCOLOR)==C'60,60,60'||s[session].Event(NewHour))
      {
        UpdateBox("bxhAI-Session"+EnumToString(session),Color(fm[session+4].Direction,IN_DARK_DIR));
        UpdateBox("bxbAI-OpenInd"+EnumToString(session),BoolToInt(s[session].IsOpen(),clrYellow,clrBoxOff));
      }
  }

//+------------------------------------------------------------------+
//| CalcLinearTrend - Calculate trend Line from Buffer return Slope  |
//+------------------------------------------------------------------+
double CalcLinearTrend(double &Buffer[], double &Line[])
  {
    //--- Linear regression line
    double m[5]      = {0.00,0.00,0.00,0.00,0.00};  //--- slope
    double b         = 0.00;                        //--- y-intercept
    
    double sumx      = 0.00;
    double sumy      = 0.00;
    
    for (int idx=0;idx<inpShortTermTL;idx++)
    {
      sumx += idx+1;
      sumy += Buffer[idx];
      
      m[1] += (idx+1)* Buffer[idx];  // Exy
      m[3] += pow(idx+1,2);         // E(x^2)
    }
    
    m[2]    = fdiv(sumx*sumy,inpShortTermTL);   // (Ex*Ey)/n
    m[4]    = fdiv(pow(sumx,2),inpShortTermTL); // [(Ex)^2]/n
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy-m[0]*sumx)/inpShortTermTL;
    
    for (int idx=0;idx<inpShortTermTL;idx++)
      Line[idx] = (m[0]*(idx+1))+b; //--- y=mx+b
      
    return (m[0]*(-1)); //-- inverted tail to head slope
  }

//+------------------------------------------------------------------+
//| CalcEvent - Returns Event conditionally based on Type/Level      |
//+------------------------------------------------------------------+
EventType CalcEvent(EventType Event, FractalType Type, AlertLevel Level)
  {
    switch (Level)
    {
      case Critical:   if (IsEqual(Type,Origin)) return(Event);
      case Major:      if (IsEqual(Type,Trend))  return(Event);
      case Minor:      if (IsEqual(Type,Term))   return(Event);
      case Nominal:    if (IsEqual(Type,Base))   return(Event);
    }
    
    return (NoEvent);
  }

//+------------------------------------------------------------------+
//| UpdateOrder - Updates order activity                             |
//+------------------------------------------------------------------+`
void UpdateOrder(void)
  {
    static int index[2]       = {0,0};
    
    order.Update(Account);
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      order.GetNode(action,order.Index(action),am[action].Zone);

      am[action].NewZone      = IsChanged(index[action],am[action].Zone.Index);
    }
    
    if (order.Fulfilled())
    {
//      Print(DoubleToStr(order[Net].Margin,1)+"%");
//      Print(DoubleToStr(order[OP_BUY].Lots,Account.LotPrecision)+" $"+DoubleToStr(order[OP_BUY].Value,0));
//      for (int node=0;node<order.Nodes(OP_BUY);node++)
//      Print("Zone: $"+DoubleToStr(order.Zone(OP_BUY,node).Value,2));
    }
  }

//+------------------------------------------------------------------+
//| UpdateSession                                                    |
//+------------------------------------------------------------------+
void UpdateSession(void)
  {
    FractalPanel Panel;

    for (SessionType session=Daily;session<SessionTypes;session++)
    {
      s[session].Update();

      EventType    event   = (EventType)BoolToInt(s[session].Event(NewCorrection),NewCorrection,
                                        BoolToInt(s[session].Event(NewReversal),NewReversal,
                                        BoolToInt(s[session].Event(NewBreakout),NewBreakout,
                                        BoolToInt(s[session].Event(NewRecovery),NewRecovery,
                                        BoolToInt(s[session].Event(NewBias),NewBias,NoEvent)))));

      for (FractalType type=Origin;type<Prior;type++)
      {
        fm[session+4].Fibo[type].Type           = type;
        fm[session+4].Fibo[type].State          = s[session][ActiveSession].State;
        fm[session+4].Fibo[type].Direction      = s[session].Fractal((SessionFractalType)type).Direction;
        fm[session+4].Fibo[type].BreakoutDir    = s[session].Fractal((SessionFractalType)type).BreakoutDir;
        fm[session+4].Fibo[type].Bias           = s[session].Fractal((SessionFractalType)type).Bias;
        fm[session+4].Fibo[type].Age            = s[session].Age();
        fm[session+4].Fibo[type].Event          = CalcEvent(event,type,s[session].AlertLevel(event));
        fm[session+4].Fibo[type].Expansion.Min  = s[session].Expansion((SessionFractalType)type,Min,InDecimal);
        fm[session+4].Fibo[type].Expansion.Max  = s[session].Expansion((SessionFractalType)type,Max,InDecimal);
        fm[session+4].Fibo[type].Expansion.Now  = s[session].Expansion((SessionFractalType)type,Now,InDecimal);
        fm[session+4].Fibo[type].Retrace.Min    = s[session].Retrace((SessionFractalType)type,Min,InDecimal);
        fm[session+4].Fibo[type].Retrace.Max    = s[session].Retrace((SessionFractalType)type,Max,InDecimal);
        fm[session+4].Fibo[type].Retrace.Now    = s[session].Retrace((SessionFractalType)type,Now,InDecimal);
        //Fractal Points (?)
        
        Panel.Fibo[type].Direction              = fm[session+4].Fibo[type].Direction;
        Panel.Fibo[type].Text[0]                = EnumToString(fm[session+4].Fibo[type].Type);
        Panel.Fibo[type].Text[1]                = DoubleToStr(fm[session+4].Fibo[type].Expansion.Now*100,1)+"%";
        Panel.Fibo[type].Text[2]                = DoubleToStr(fm[session+4].Fibo[type].Retrace.Now*100,1)+"%";
      }

      fm[session+4].Source                      = Session;
      fm[session+4].Session                     = session;
      fm[session+4].Direction                   = s[session].Fractal(sftTerm).Direction;
      fm[session+4].BreakoutDir                 = s[session].Fractal(sftTerm).BreakoutDir;
      fm[session+4].Bias                        = s[session][ActiveSession].Bias;
      //-- Weight
      fm[session+4].Hedge                       = !IsEqual(s[session][ActiveSession].Bias,Action(s[session][ActiveSession].Direction,InDirection));
      fm[session+4].Event                       = event;
      fm[session+4].State                       = s[session][ActiveSession].State;

      //-- Fractal Detail Update
      ArrayInitialize(Panel.Color,clrDarkGray);
      
      Panel.ActiveDir          = fm[session+4].Direction;
      Panel.BreakoutDir        = fm[session+4].BreakoutDir;
      Panel.Bias               = fm[session+4].Bias;
      Panel.Trigger            = !IsEqual(event,NoEvent);

      Panel.Text[0]            = EnumToString(session)+" "+proper(ActionText(s[session][ActiveSession].Bias))+" "+BoolToStr(fm[session+4].Hedge,"Hold","Hedge");
      Panel.Text[1]            = EnumToString(s[session][ActiveSession].State);
      
      if (s[session].IsOpen())
      {
        Panel.Color[0]         = clrWhite;
        Panel.Color[1]         = BoolToInt(s[session].Event(NewBreakout)||s[session].Event(NewReversal),clrWhite,
                                 BoolToInt(s[session].Event(NewRally)||s[session].Event(NewPullback),clrYellow,clrDarkGray));

        Panel.Text[2]          = BoolToStr(ServerHour()>s[session].SessionHour(SessionClose)-3,"Late",
                                 BoolToStr(s[session].SessionHour()>3,"Mid","Early"));
        Panel.Color[2]         = BoolToInt(ServerHour()>s[session].SessionHour(SessionClose)-3,clrRed,
                                 BoolToInt(s[session].SessionHour()>3,clrYellow,clrLawnGreen));
                                 
        Append(Panel.Text[2],"Session ("+IntegerToString(s[session].SessionHour())+")");
      }
      else Panel.Text[2]       = "Session Is Closed";

      RefreshFractalPanel(session+4,Panel);
    }
  }

//+------------------------------------------------------------------+
//| UpdateFractal                                                    |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {
    static int barbias       = OP_NO_ACTION;
    static int barbiasdir    = DirectionNone;
    
    f.Update();

    FractalPanel Panel;
    EventType    event;
    FractalType  leg         = f.Previous(f.Leg(Now));
     
    for (int fractal=2;fractal<4;fractal++)
    {
      if (IsEqual(fractal,2))
      {
        event                = (EventType)BoolToInt(f.Event(NewCorrection,Nominal),NewCorrection,
                                                   BoolToInt(f.Event(NewReversal,Nominal),NewReversal,
                                                   BoolToInt(f.Event(NewBreakout,Nominal),NewBreakout,
                                                   BoolToInt(f.Event(NewRecovery,Nominal),NewRecovery,
                                                   BoolToInt(f.Event(NewExpansion),NewExpansion,
                                                   BoolToInt(f.Event(NewBoundary,Major),NewBoundary,NoEvent))))));
        if (!IsBetween(Close[0],High[1],Low[1]))
          if (IsChanged(barbiasdir,Direction(Close[0]-High[1])))
          {
            barbias              = Action(barbiasdir,InDirection);
            event                = (EventType)BoolToInt(IsEqual(event,NoEvent),NewBias);
          }
      }
      else
      {
        leg                  = Term;
        event                = (EventType)BoolToInt(f.Event(NewCorrection),NewCorrection,
                                                   BoolToInt(f.Event(NewReversal),NewReversal,
                                                   BoolToInt(f.Event(NewBreakout),NewBreakout,
                                                   BoolToInt(f.Event(NewRecovery),NewRecovery,NoEvent))));
      }

      for (int node=2;node>NoValue;node--)
      {
        fm[fractal].Fibo[node].Type               = leg;
        fm[fractal].Fibo[node].State              = f.State(leg);
        fm[fractal].Fibo[node].Age                = f[leg].Bar;
        fm[fractal].Fibo[node].Event              = CalcEvent(event,leg,f.AlertLevel(event));
        fm[fractal].Fibo[node].Expansion.Min      = f.Fibonacci(leg,Expansion,Min);
        fm[fractal].Fibo[node].Expansion.Max      = f.Fibonacci(leg,Expansion,Max);
        fm[fractal].Fibo[node].Expansion.Now      = f.Fibonacci(leg,Expansion,Now);
        fm[fractal].Fibo[node].Retrace.Min        = f.Fibonacci(leg,Retrace,Min);
        fm[fractal].Fibo[node].Retrace.Max        = f.Fibonacci(leg,Retrace,Max);
        fm[fractal].Fibo[node].Retrace.Now        = f.Fibonacci(leg,Retrace,Now);
        //Fractal Points (?)

        if (IsEqual(leg,Origin))
        {
          fm[fractal].Fibo[node].Direction        = f.Direction(Expansion);
          fm[fractal].Fibo[node].BreakoutDir      = f.Direction(leg);
          
          //-- doesn't work, waiting on fibo 'zone' change logic; +1=buy; -1=Sell ... something like that...
          fm[fractal].Fibo[node].Bias             = BoolToInt(f.Fibonacci(Origin,Retrace,Max)>FiboPercent(Fibo50),
                                                      Action(f.Direction(leg),InDirection,InContrarian),Action(f.Direction(leg)));
        }
        else
        {
          fm[fractal].Fibo[node].Direction        = f.Direction(leg);
          fm[fractal].Fibo[node].BreakoutDir      = f.Direction(Expansion);

          if (leg>Expansion)
            fm[fractal].Fibo[node].Bias           = BoolToInt(IsEqual(f.State(leg),Rally),OP_BUY,
                                                      BoolToInt(IsEqual(f.State(leg),Pullback),OP_SELL,Action(f.Direction(leg))));
          else
            fm[fractal].Fibo[node].Bias           = BoolToInt(f.Is(Divergent,Max),Action(f.Direction(leg),InDirection,InContrarian),
                                                      Action(f.Direction(leg)));
        }

        Panel.Fibo[node].Direction                = fm[fractal].Fibo[node].Direction;
        Panel.Fibo[node].Text[0]                  = EnumToString(fm[fractal].Fibo[node].Type);
        Panel.Fibo[node].Text[1]                  = DoubleToStr(fm[fractal].Fibo[node].Expansion.Now*100,1)+"%";
        Panel.Fibo[node].Text[2]                  = DoubleToStr(fm[fractal].Fibo[node].Retrace.Now*100,1)+"%";

        if (IsEqual(fractal,2))
          leg   = (FractalType)BoolToInt(IsEqual(node,2),f.Previous(leg),BoolToInt(IsEqual(node,1),f.Previous(leg,Convergent),f.Previous(leg)));
        else
          leg   = (FractalType)f.Previous(leg);
      }

      fm[fractal].Source             = Fractal;
      fm[fractal].Session            = Daily;
      fm[fractal].Event              = event;

      if (IsEqual(leg,Origin))
      {
        fm[fractal].Direction        = fm[fractal].Fibo[Origin].Direction;
        fm[fractal].BreakoutDir      = fm[fractal].Fibo[Origin].BreakoutDir;
        fm[fractal].Bias             = fm[fractal].Fibo[Origin].Bias;
        //-- Weight
        fm[fractal].State            = (FractalState)BoolToInt(IsEqual(f.State(Base),Correction),Correction,fm[fractal].Fibo[Origin].State);
        fm[fractal].Hedge            = !IsEqual(fm[fractal].Direction,fm[fractal].BreakoutDir)||IsEqual(fm[fractal].State,Correction);
      }
      else
      {
        fm[fractal].Direction       = f.Direction(f.Leg(Max));
        fm[fractal].BreakoutDir     = f.Direction(Expansion);
        fm[fractal].Bias            = barbias;
        //-- Weight
        fm[fractal].Hedge           = !IsEqual(fm[fractal].Direction,Direction(barbias,InAction));
        fm[fractal].State           = fm[fractal].Fibo[0].State;
      }

      //-- Publish Panel
      ArrayInitialize(Panel.Color,clrDarkGray);

      Panel.ActiveDir               = fm[fractal].Direction;
      Panel.BreakoutDir             = fm[fractal].BreakoutDir;
      Panel.Bias                    = fm[fractal].Bias;
      Panel.Trigger                 = event>NoEvent;

      Panel.Text[0]                 = BoolToStr(IsEqual(fm[fractal].Direction,DirectionUp),"Buy","Sell")+" "+BoolToStr(fm[fractal].Hedge,"Hedge","Hold");
      Panel.Text[1]                 = EnumToString(fm[fractal].State);
      Panel.Text[2]                 = BoolToStr(IsEqual(fractal,2),
                                         EnumToString(fm[fractal].Fibo[1].Type)+" ("+(string)fm[fractal].Fibo[1].Age+")",
                                         BoolToStr(f.Is(Origin,Divergent),"Divergent","Convergent")+" ("+(string)fm[2].Fibo[0].Age+")");

      RefreshFractalPanel(fractal,Panel);
    }
  }

//+------------------------------------------------------------------+
//| CalcPivotMicro - Computes PipMA Linear Regression micro measures |
//+------------------------------------------------------------------+
void CalcPivotMicro(void)
  {
    string opentext     = "";
    string closetext    = "";

    int course          = 0;

    if (pf.Event(NewTick))
    {
      for (int position=inpShortTermTL-1;position>0;position--)
      {
        mm.Open.Buffer[position]  = mm.Open.Buffer[position-1];
        mm.Close.Buffer[position] = mm.Close.Buffer[position-1];
      }

      mm.Open.Buffer[0]           = pm.Tick.Prior.Open;
      mm.Close.Buffer[0]          = pm.Tick.Prior.Close;

      mm.Open.Slope               = CalcLinearTrend(mm.Open.Buffer,mm.Open.Line);
      mm.Close.Slope              = CalcLinearTrend(mm.Close.Buffer,mm.Close.Line);
    
      NewDirection(mm.Direction,Direction(mm.Open.Buffer[0]-mm.Open.Buffer[inpShortTermTL-1]));
      NewAction(mm.Bias,Action(Direction(mm.Close.Buffer[0]-mm.Open.Buffer[0]),InDirection));

      //-- Load Panel-v3/4 Pipe
      ObjectSetString(0,"lbv-Open",OBJPROP_TEXT,DoubleToStr(mm.Open.Buffer[0],Digits)+";"+DoubleToStr(mm.Open.Buffer[inpShortTermTL-1],Digits));
      ObjectSetString(0,"lbv-Close",OBJPROP_TEXT,DoubleToStr(mm.Close.Buffer[0],Digits)+";"+DoubleToStr(mm.Close.Buffer[inpShortTermTL-1],Digits));

      if (pf.HistoryLoaded())
        mm.FOC.Momentum           = BoolToInt(IsEqual(pf.FOC(Now),pf.FOC(Min)),Direction(pf.FOC(Now),InContrarian),Direction(pf.FOC(Now)));
      else
      if (pf.Count(History)>inpShortTermTL)
        mm.FOC.Momentum           = mm.Direction;
      else
        mm.FOC.Momentum           = pm.Tick.Prior.Direction;
    }
  }

//+------------------------------------------------------------------+
//| CalcPivotState - Compute Broken/Unbroken State for supplied Pivot|
//+------------------------------------------------------------------+
void CalcPivotState(PivotRec &Pivot)
  {
    FractalState state    = NoState;
    
    pm.Event              = NoEvent;

    if (Pivot.Direction==DirectionNone)
      return;

    if (pf.Event(NewTick))
    {
      if (pm.Segment==0)
        if (IsEqual(Pivot.Low,Close[0],Digits)||IsEqual(Pivot.High,Close[0],Digits))
          if (Pivot.Direction==pm.Direction)
          {
            if (IsChanged(pm.Broken,false))
            {
              Flag("Unbroken",clrWhite,IsEqual(inpShowBroken,Yes));
              pm.Recovery[Action(Pivot.Direction,InDirection)]    = Close[0];
              pm.Event                                            = NewRecovery;
            }
          }
          else
            if (IsChanged(pm.Broken,true))
            {
              Flag("Broken",Color(pm.Direction),IsEqual(inpShowBroken,Yes));
              pm.Correction[Action(Pivot.Direction,InDirection)]  = Close[0];
              pm.Event                                            = NewCorrection;
            }

       if (IsEqual(pm.State,Breakout)||IsEqual(pm.State,Reversal))
         pm.Peg  = (IsEqual(Pivot.Direction,DirectionUp)&&IsHigher(Close[0],Pivot.Close,NoUpdate))||
                   (IsEqual(Pivot.Direction,DirectionDown)&&IsLower(Close[0],Pivot.Close,NoUpdate));

       state     = (FractalState)BoolToInt(IsEqual(pm.Event,NewReversal),Reversal,
                      BoolToInt(IsEqual(pm.Event,NewBreakout),Breakout,
                      BoolToInt(IsEqual(pm.Event,NewCorrection),Correction,
                      BoolToInt(IsEqual(pm.Event,NewRecovery),Recovery,
                      BoolToInt(pm.Peg,BoolToInt(IsHigher(Close[0],Pivot.Close,NoUpdate),Rally,Pullback))))));
     }
     
    if (IsChanged(pm.State,(FractalState)BoolToInt(IsEqual(state,NoState),pm.State,state)))
    {}
  }

//+------------------------------------------------------------------+
//| CalcPivotTrigger - tests for and maintains trigger states        |
//+------------------------------------------------------------------+
void CalcPivotTrigger(void)
  {  
    ArrayInitialize(mm.Trigger,false);
    
    if (Close[0]<pm.Tick.Lead.Close)
      if (Close[0]>fmin(pm.Tick.Lead.Low,pm.Tick.Prior.Low))
        mm.Trigger[OP_BUY]        = true;

    if (Close[0]>pm.Tick.Lead.Close)
      if (Close[0]<fmax(pm.Tick.Lead.High,pm.Tick.Prior.High))
        mm.Trigger[OP_SELL ]      = true;
  }

//+------------------------------------------------------------------+
//| PivotBias - Returns the computed Bias in Action                  |
//+------------------------------------------------------------------+
int PivotBias(ReservedWords Type, bool Contrarian=false)
  {
    int biasdir   = DirectionNone;
    
    switch (Type)
    {
      case Tick:    if (IsLower(pm.Tick.Lead.Low,pm.Tick.Prior.Low,NoUpdate)) biasdir=DirectionDown;
                    if (IsHigher(pm.Tick.Lead.High,pm.Tick.Prior.High,NoUpdate)) biasdir=DirectionUp;
                    break;

      case Pivot:   if (pm.Segment==0)
                    {
                      biasdir = pm.Pivot.Lead.Direction;
      
                      if (IsLower(pm.Tick.Lead.Low,pm.Pivot.Lead.Low,NoUpdate)) biasdir=DirectionDown;
                      if (IsHigher(pm.Tick.Lead.High,pm.Pivot.Lead.High,NoUpdate)) biasdir=DirectionUp;
                    }
                    else
                    {
                      biasdir = pm.Pivot.Prior.Direction;
      
                      if (IsLower(pm.Tick.Lead.Low,pm.Pivot.Prior.Low,NoUpdate)) biasdir=DirectionDown;
                      if (IsHigher(pm.Tick.Lead.High,pm.Pivot.Prior.High,NoUpdate)) biasdir=DirectionUp;
                    }
                    break;
                    
      case Active:  biasdir = BoolToInt(pm.Active.Lead.Count>pm.Active.Prior.Count,pm.Active.Lead.Direction,pm.Active.Prior.Direction);
                    break;
                    
      case Master:  biasdir = BoolToInt(pm.Segment==0,pm.Pivot.Lead.Direction,pm.Pivot.Prior.Direction);
    };
    
    return (Action(biasdir,InDirection,Contrarian));
  }

//+------------------------------------------------------------------+
//| Flush - returns default initial pivot rec                        |
//+------------------------------------------------------------------+
PivotRec Flush(int Direction=DirectionNone, int Count=0)
  {
    PivotRec Default;
    
    Default.Direction      = Direction;
    Default.Count          = Count;
    
    Default.High           = Close[0];
    Default.Low            = Close[0];
    Default.Open           = Close[0];
    Default.Close          = BoolToDouble(Direction==DirectionNone,Close[0],NoValue);
    
    return (Default);
  }

//+------------------------------------------------------------------+
//| NewPivot - Copies current to prior; inits new pivot              |
//+------------------------------------------------------------------+
void NewPivot(PivotSet &Pivot, PivotRec &Copy, bool Reset=true)
  {    
    Pivot.Lead.Count        = BoolToInt(Reset,1,Pivot.Lead.Count);
    Pivot.Prior             = Pivot.Lead;
    Pivot.Lead              = Copy;
    Pivot.Lead.Close        = NoValue;
  }

//+------------------------------------------------------------------+
//| UpdatePivot - Sets New Highs, Lows, and Conditional Close        |
//+------------------------------------------------------------------+
void UpdatePivot(PivotRec &Pivot, bool UpdateClose=true)
  {
    if (IsHigher(Close[0],Pivot.High))
      if (UpdateClose)
        Pivot.Close        = Close[0];

    if (IsLower(Close[0],Pivot.Low))
      if (UpdateClose)
        Pivot.Close        = Close[0];
  }

//+------------------------------------------------------------------+
//| UpdatePipMA                                                      |
//+------------------------------------------------------------------+
void UpdatePipMA(void)
  {
    #define TickReset   1

    FractalPanel Panel;
    EventType    event      = NoEvent;
    int          fractal    = 0;

    pf.Update();

    if (pf.Event(NewTick))
    {
      //-- Set Triggers (Pre-Update)
      CalcPivotTrigger();
      
      //-- Process Tick Segment
      if (pm.Tick.Lead.Direction==pf.Direction(Tick))
        if (NewDirection(pm.Tick.Lead.Direction,Direction(pm.Tick.Lead.Close-pm.Tick.Lead.Open)))
          NewPivot(pm.Tick,Flush(pm.Tick.Lead.Direction,TickReset));
        else
          NewPivot(pm.Tick,Flush(pf.Direction(Tick),++pm.Tick.Lead.Count),false);
      else
        if (NewDirection(pm.Tick.Lead.Direction,pf.Direction(Tick)))
          NewPivot(pm.Tick,Flush(pf.Direction(Tick),TickReset));
          
      mm.GapBias         = BoolToInt(pm.Tick.Lead.Direction==pf.Direction(Tick),OP_NO_ACTION,Action(pm.Tick.Lead.Direction,InDirection,InContrarian));
      mm.GapAnomaly      = !IsEqual(mm.GapBias,OP_NO_ACTION);
      
      //-- Process Active Segment
      if (pm.Tick.Prior.Count==TickReset)
      {
        pm.Action                 = Action(pf.Direction(Tick));
        pm.Direction              = pf.Direction(Tick);
        pm.Segment                = BoolToInt(pm.Active.Lead.Count==pm.Active.Prior.Count,++pm.Segment,0);
        
        NewPivot(pm.Active,pm.Tick.Prior,false);
      }

      pm.Active.Lead.Count        = pm.Tick.Prior.Count;
      pm.Active.Lead.Close        = pm.Tick.Prior.Open;
    }

    //-- Process Pivot/Master Segments
    if (pm.Segment>0)
    {
      //-- Open for potential new Pivot; (if) retire prior Pivot
      if (pf.Event(NewTick))
        if (pm.Segment==TickReset)
          if (pm.Pivot.Lead.Close>NoValue)
            NewPivot(pm.Pivot,pm.Active.Prior,false);
          else
            pm.Pivot.Lead         = pm.Active.Prior;

      pm.Pivot.Lead.Direction     = pm.Active.Lead.Direction;
      pm.Pivot.Lead.High          = BoolToDouble(pm.Pivot.Lead.Direction==DirectionUp,pm.Pivot.Lead.High,fmax(pm.Pivot.Lead.High,pm.Active.Lead.High));
      pm.Pivot.Lead.Low           = BoolToDouble(pm.Pivot.Lead.Direction==DirectionUp,fmin(pm.Pivot.Lead.Low,pm.Active.Lead.Low),pm.Pivot.Lead.Low);

      //-- Consolidation Breakout; Close Pivot
      if (pm.Active.Lead.Count>pm.Active.Prior.Count)
      {
        pm.Pivot.Lead.Close       = pm.Tick.Prior.Close;
        pm.Pivot.Lead.High        = fmax(pm.Pivot.Lead.High,pm.Pivot.Lead.Close);
        pm.Pivot.Lead.Low         = fmin(pm.Pivot.Lead.Low,pm.Pivot.Lead.Close);

        pm.Segment                = 0;
        pm.Peg                    = false;

        //-- Check for Bias Change
        if (NewAction(pm.Bias,PivotBias(Master)))
        {
          pm.Event                = NewReversal;
          NewPivot(pm.Master,pm.Active.Lead);
        }
        else pm.Event             = (EventType)BoolToInt(IsEqual(pm.State,Reversal),NewReversal,NewBreakout);
      }
    }

    //-- Manage Leg Data
    UpdatePivot(pm.Tick.Lead);
    UpdatePivot(pm.Active.Lead,NoUpdate);
    UpdatePivot(pm.Master.Lead,NoUpdate);

    //-- Manage Master Segments
    if (pf.Event(NewTick))
      if (IsEqual(Action(pm.Direction),pm.Bias))
        pm.Master.Lead.Close      = pm.Active.Lead.Close;

    CalcPivotState(pm.Master.Lead);
    CalcPivotMicro();
    
    //-- Consolidate Pivot Data
    fractal                             = 0;
    event                               = BoolToEvent(mm.Trigger[OP_BUY],NewPullback,
                                            BoolToEvent(mm.Trigger[OP_SELL],NewRally,
                                            BoolToEvent(mm.GapAnomaly,NewTrap,pm.Event)));
    //-- Load FOC Regression Fibs
    fm[fractal].Fibo[0].Type            = Base;
    fm[fractal].Fibo[0].State           = pm.State;
    fm[fractal].Fibo[0].Direction       = Direction(mm.FOC.Momentum);
    fm[fractal].Fibo[0].BreakoutDir     = pf.FOCDirection(inpTolerance);
    fm[fractal].Fibo[0].Bias            = PivotBias(Tick);
    fm[fractal].Fibo[0].Age             = 0;
    fm[fractal].Fibo[0].Event           = event;
    
    //-- Load Master Pivot Fibs
    fm[fractal].Fibo[1].Type            = Expansion;
    fm[fractal].Fibo[1].State           = pm.State;
    fm[fractal].Fibo[1].Direction       = pm.Master.Lead.Direction;
    fm[fractal].Fibo[1].BreakoutDir     = pm.Master.Lead.Direction;
    fm[fractal].Fibo[1].Bias            = PivotBias(Master);
    fm[fractal].Fibo[1].Age             = 0;
    fm[fractal].Fibo[1].Event           = pm.Event;

    //-- Load Histogram Fibs
    fm[fractal].Fibo[2].Type            = Lead;
//    fm[fractal].Fibo[2].State           = ;
    fm[fractal].Fibo[2].Direction       = pm.Master.Lead.Direction;
    fm[fractal].Fibo[2].BreakoutDir     = pm.Master.Lead.Direction;
    fm[fractal].Fibo[2].Bias            = PivotBias(Master);
    fm[fractal].Fibo[2].Age             = 0;
    fm[fractal].Fibo[2].Event           = pm.Event;

    //-- Load Micro Aggregate Fibs
    fm[fractal].Source                  = PipMA;
    fm[fractal].Session                 = Daily;
    fm[fractal].Direction               = mm.Direction;
    fm[fractal].BreakoutDir             = BoolToInt(IsEqual(pm.Master.Lead.Direction,DirectionNone),mm.Direction,pm.Master.Lead.Direction);
    fm[fractal].Event                   = event;
    fm[fractal].State                   = pm.State;
    fm[fractal].Bias                    = mm.Bias;
//    fm[fractal].Weight                  = ;
    fm[fractal].Hedge                   = !IsEqual(Direction(mm.FOC.Momentum),Direction(PivotBias(Tick),InAction));
    
    //-- Update Micro Fibo Panel
    ArrayInitialize(Panel.Color,clrDarkGray);

    Panel.ActiveDir               = fm[fractal].Direction;
    Panel.BreakoutDir             = fm[fractal].BreakoutDir;
    Panel.Bias                    = fm[fractal].Bias;
    Panel.Trigger                 = event>NoEvent;
    Panel.Text[0]                 = proper(ActionText(Action(fm[fractal].Direction,InDirection)))+" "+BoolToStr(pm.Broken,"Hedge","Hold");
    Panel.Text[1]                 = EnumToString(fm[fractal].Fibo[0].State);
    Panel.Text[2]                 = BoolToStr(IsEqual(event,NewPullback),"Buy Triggered",
                                      BoolToStr(IsEqual(event,NewRally),"Sell Triggered",
                                      BoolToStr(IsEqual(event,NewTrap),"Gap Anomaly Triggered",
                                      BoolToStr(Panel.Trigger,EnumToString(event),""))));

    Panel.Fibo[0].Direction       = fm[fractal].Direction;
    Panel.Fibo[0].Text[0]         = BoolToStr(pf.HistoryLoaded(),"Regression",BoolToStr(pf.Count(History)<inpShortTermTL,"Lead","Tick"));
    Panel.Fibo[0].Text[1]         = proper(ActionText(Action(fm[fractal].Direction,InDirection)));
//    Panel.Fibo[0].Text[2]         = DoubleToString(pm.Micro.Fibo.Now*100,1)+"%";

    Panel.Fibo[1].Direction       = fm[fractal].Fibo[1].Direction;
    Panel.Fibo[1].Text[0]         = "Master";
    Panel.Fibo[1].Text[1]         = DoubleToStr(pm.Master.Lead.High,Digits);
    Panel.Fibo[1].Text[2]         = DoubleToStr(pm.Master.Lead.Low,Digits);

    Panel.Fibo[2].Direction       = mm.Direction;
    Panel.Fibo[2].Text[0]         = "Histogram";
    Panel.Fibo[2].Text[1]         = BoolToStr(pf.Count(History)<inpShortTermTL,"Loading",DoubleToStr(mm.Open.Buffer[inpShortTermTL-1],Digits));
    Panel.Fibo[2].Text[2]         = BoolToStr(pf.Count(History)<inpShortTermTL," ["+IntegerToString(pf.Count(History)-inpShortTermTL-1,4)+" ]",DoubleToStr(mm.Close.Buffer[inpShortTermTL-1],Digits));

    RefreshFractalPanel(fractal,Panel);

    //-- Load Fractal Data
    fractal             = 1;
    event               = (EventType)BoolToInt(pf.Event(NewReversal),NewReversal,
                                     BoolToInt(pf.Event(NewBreakout),NewBreakout,
                                     BoolToInt(pf.Event(NewTerm),NewReversal,
                                     BoolToInt(pf.Event(NewExpansion),NewExpansion,NoEvent))));

    for (FractalType type=Origin;type<(int)PipFractalTypes;type++)
    {
      fm[fractal].Fibo[type].Type            = type;
      fm[fractal].Fibo[type].Direction       = pf.Direction(type);
      fm[fractal].Fibo[type].BreakoutDir     = BoolToInt(IsEqual(type,Origin),pf.Direction(Origin),pf.Direction(Trend));
      fm[fractal].Fibo[type].State           = pf.State().State[type];
      fm[fractal].Fibo[type].Bias            = 0; //-- Based on fractal momentum
      fm[fractal].Fibo[type].Age             = pf[type].Age[fpExpansion];

      if (event>NoEvent)
        fm[fractal].Fibo[type].Event         = (EventType)BoolToInt(IsEqual(event,Critical)&&IsEqual(type,Origin),event,
                                                          BoolToInt(IsEqual(event,Major)&&IsEqual(type,Trend),event,
                                                          BoolToInt(IsEqual(event,Minor)&&IsEqual(type,Term),event,NoEvent)));

      fm[fractal].Fibo[type].Expansion.Min   = pf.Fibonacci(type,Expansion,Min);
      fm[fractal].Fibo[type].Expansion.Max   = pf.Fibonacci(type,Expansion,Max);
      fm[fractal].Fibo[type].Expansion.Now   = pf.Fibonacci(type,Expansion,Now);
      fm[fractal].Fibo[type].Retrace.Min     = pf.Fibonacci(type,Retrace,Min);
      fm[fractal].Fibo[type].Retrace.Max     = pf.Fibonacci(type,Retrace,Max);
      fm[fractal].Fibo[type].Retrace.Now     = pf.Fibonacci(type,Retrace,Now);
      
      Panel.Fibo[type].Direction             = fm[fractal].Fibo[type].Direction;

      Panel.Fibo[type].Text[0]               = EnumToString(type);
      Panel.Fibo[type].Text[1]               = DoubleToStr(fm[fractal].Fibo[type].Expansion.Now*100,1)+"%";
      Panel.Fibo[type].Text[2]               = DoubleToStr(fm[fractal].Fibo[type].Retrace.Now*100,1)+"%";
    }

    //-- Update pipMA Fractal Panel
    fm[fractal].Source            = PipMA;
    fm[fractal].Session           = Daily;
    fm[fractal].Direction         = pf.Direction(Term);
    fm[fractal].BreakoutDir       = pf.Direction(Trend);
    fm[fractal].Bias              = Action(Direction(mm.FOC.Momentum,InDirection));
    //fm[fractal].Weight            = 
    fm[fractal].Hedge             = !IsEqual(pf.Direction(Term),pf.Direction(Trend));
    fm[fractal].State             = pf.State().State[Origin];
    fm[fractal].Event             = event;

    //-- Publish Panel
    ArrayInitialize(Panel.Color,clrDarkGray);

    Panel.ActiveDir               = fm[fractal].Direction;
    Panel.BreakoutDir             = fm[fractal].BreakoutDir;
    Panel.Bias                    = fm[fractal].Bias;
    Panel.Trigger                 = event>NoEvent;

    Panel.Text[0]                 = proper(ActionText(fm[fractal].Bias))+" "+BoolToStr(fm[fractal].Hedge,"Hedge","Hold");
    Panel.Text[1]                 = EnumToString(fm[fractal].State);
    Panel.Text[2]                 = pf.StateText();

    RefreshFractalPanel(fractal,Panel);

    //-- Prints (Testing)
    if (pf.Event(NewTick))
    {
//      CallPause("History["+(string)+pf.Count(History)+"|\n|"+PivotStr("Master[Lead]",pm.Master.Lead));
//      PrintRec(Display);
//      Print(PivotStr("Tick[Prior]",pm.Tick.Prior));
//      Print(PivotStr("Tick[Lead]",pm.Tick.Lead));
        //if (pm.Tick.Lead.Count==TickReset)
        //{
        //  Print("Consolidation: "+(string)pm.Segment);
        //Print(PivotStr("Active[Lead]|"+(string)pm.Segment+"|",pm.Active.Lead));
        //Print(PivotStr("Active[Prior]|"+(string)pm.Segment+"|",pm.Active.Prior));
        //}
      //Print(PivotStr("Pivot[Prior]|"+(string)pm.Segment+"|",pm.Pivot.Prior));
      //Print(PivotStr("Pivot[Lead]|"+(string)pm.Segment+"|",pm.Pivot.Lead));
      //if (pm.Master.Lead.Correction>0.00)
      //Print(PivotStr("Master[Lead]|"+ActionText(pm.Bias)+"|",pm.Master.Lead));
//      Print(PivotStr("Master[Prior]|"+ActionText(pm.Bias)+"|",pm.Master.Prior));
    }
  }

//+------------------------------------------------------------------+
//| ManageShort - Short Order Processing and Management              |
//+------------------------------------------------------------------+
void ManageLong(void)
  {
  }

//+------------------------------------------------------------------+
//| ManageShort - Short Order Processing and Management              |
//+------------------------------------------------------------------+
void ManageShort(void)
  {
    static int tick = 0;
    
    OrderRequest request       = order.BlankRequest();
    
    tick++;
    
    if (IsEqual(tick,4))
    {
      request.Pend.Type        = OP_SELLSTOP;
      request.Pend.Limit       = 17.75;
      request.Pend.Step        = 2;
      request.Pend.Cancel      = 18.20;
      request.Memo             = "Testing Sell Limit";
      request.Type             = OP_SELLLIMIT;
      request.TakeProfit       = 17.50;
      request.Price            = 18.10;
      request.Expiry           = TimeCurrent()+(Period()*(60*120));
    }
    
    if (IsEqual(tick,4))
    {
      if (order.Submitted(request))
        Print("Request ["+IntegerToString(request.Key,10)+"]");
      else
      {
        Print(order.RequestStr(request));

        for (QueueStatus status=Pending;status<=Expired;status++)
          if (order[status].Type[OP_SELLLIMIT].Count>0)
            Print(EnumToString(status)+"["+IntegerToString(order[status].Type[OP_SELLLIMIT].Count,5,'-')+"]");
      }
      order.PrintSnapshotStr();
    }

    //-- Review/Assess Fractal Indicator events
      //--1. Micro Triggers
      //--2. Micro Bias
      //--3. Papa Fractal forecasts
      //--4. Jr. Locale state/bias
      //--5. Session Hours/ages/[Lead|Daily] Fibo
      
    //-- Review open order position
    for (int node=0;node<order.Nodes(OP_SELL);node++);
//      Print("Zone ["+IntegerToString(order.Zone(OP_SELL,node).Index,3)+"]$"+
            //" Lots ["+DoubleToStr(order.Zone(OP_SELL,node).Lots,Account.LotPrecision)+"]"+
            //" Margin ["+DoubleToStr(order.Zone(OP_SELL,node).Margin,1)+"%]"+
            //" Equity ["+DoubleToStr(order.Zone(OP_SELL,node).Equity,1)+"%]");

    if (am[OP_SELL].NewZone)
    {
      //-- Check DCA
      //-- Manage Stops/Targets
      //-- Rate Order Position (Recapture/Capture/Hedge/Build)
      //-- Check current Zone for needed open order modifications
      //-- Update open order states
//      if (order.Account.DCA[OP_SELL])
    }

    //-- Review/Resolve(alert) request queue Errors/Pending/Fulfilled
    for (QueueStatus status=Pending;status<=Fulfilled;status++)
      if (order[status].Type[OP_SELL].Count>0)
        switch (status)
        {
          case Pending:     //-- Review Pending
                            break;
          case Canceled:    //-- Confirm Canceled/Cancel Pending
                            break;
          case Declined:    //-- Review/Resubmit Declined
                            break;
          case Rejected:    //-- Review Rejected
                            break;
          case Expired:     //-- Review/Resubmit Expirations
                            break;
          case Fulfilled:   //-- Review Fulfillments/Splits
                            break;
    }
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    int batch[];

    ManageLong();
    ManageShort();

    order.Execute(batch,true);

    if (pf.Event(NewTick))
    {
      Print("Momentum|"+DoubleToStr(mm.Open.Slope+mm.Close.Slope)+
            "|"+DoubleToStr(mm.Open.Slope)+
            "|"+DoubleToStr(mm.Close.Slope)+
            "|"+DoubleToStr(mm.Open.Line[0],Digits)+
            "|"+DoubleToStr(mm.Close.Line[0],Digits));
      //Pause("Micro.Direction ["+DirText(mm.Direction,3)+"]\n"+MicroMasterStr()
      //                        +"\n\nPipMA(Origin)\n"+pf.FractalStr(Origin)+"\n\nPipMA(Trend)\n"+pf.FractalStr(Trend)
      //                        +"\n\nPipMA(Term)\n"+pf.FractalStr(Term),"Tick Change");

      //for (int node=0;node<8;node++)
      //  Print("|"+FractalMasterStr(fm[node]));
    }
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PAUSE")
      PauseOn                     = true;

    if (Command[0]=="PLAY")
      PauseOn                     = false;

    if (Command[0]=="PRINT")
    {
      if (Command[1]=="ON")
        PrintOn                   = true;

      if (Command[1]=="OFF")
        PrintOn                   = false;
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

    UpdateSession();
    UpdateFractal();
    UpdatePipMA();
    UpdateOrder();

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
    ArrayResize(mm.Open.Buffer,inpShortTermTL);
    ArrayResize(mm.Close.Buffer,inpShortTermTL);
    ArrayResize(mm.Open.Line,inpShortTermTL);
    ArrayResize(mm.Close.Line,inpShortTermTL);

    NewLabel("lbv-Open","",5,11,clrNONE,SCREEN_LR);
    NewLabel("lbv-Close","",5,22,clrNONE,SCREEN_LR);
    NewLabel("lbv-Open[1]","",5,44,clrNONE,SCREEN_LR);
    NewLabel("lbv-Close[2]","",5,33,clrNONE,SCREEN_LR);

    s[Daily]                      = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]                       = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]                     = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]                         = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    ManualInit();

    //-- Init Pivot Master Record
    pm.Action                     = OP_NO_ACTION;
    pm.Direction                  = DirectionNone;
    pm.Bias                       = OP_NO_ACTION;
    pm.Segment                    = 0;

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      pm.Recovery[action]         = 0.00;
      pm.Correction[action]       = 0.00;
    }

    pm.Tick.Lead                  = Flush();
    NewPivot(pm.Tick,Flush());

    pm.Active                     = pm.Tick;
    pm.Pivot                      = pm.Tick;
    pm.Master                     = pm.Tick;

    if (inpShowMasterLines==Yes)
    {
      NewLine("Master[Lead].High");
      NewLine("Master[Lead].Low");
      NewLine("Master[Lead].Close");
    }

    order.Enable();

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      order.Enable(action);
      order.SetEquityTargets(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetZoneStep(action,2.5,60.0);
    }

    Print(order.MasterStr(OP_BUY));

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    delete (order);
    delete f;
    delete pf;
    
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete s[type];
  }

//+------------------------------------------------------------------+
//| MicroMasterStr - Returns a formatted Micro Master string         |
//+------------------------------------------------------------------+
string MicroMasterStr(void)
  {
    string text        = "";
    
    Append(text,"Pivot "+proper(DirText(mm.Direction))+" ["+proper(ActionText(mm.Bias))+"]");
    Append(text,"Triggers ["+BoolToStr(mm.Trigger[OP_BUY],"Buy",
                            BoolToStr(mm.Trigger[OP_SELL],"Sell","Idle"))+"]");
    Append(text,BoolToStr(IsEqual(mm.GapBias,OP_NO_ACTION),"","Gap ["+BoolToStr(mm.GapAnomaly,"Active","Idle")+" "+proper(ActionText(mm.GapBias))+"]"),"\n");
    Append(text,"Buffer Open [tail:"+DoubleToStr(mm.Open.Buffer[inpShortTermTL-1],Digits)+" head:"+DoubleToStr(mm.Open.Buffer[0],Digits)+"]","\n");
    Append(text,"Close [tail:"+DoubleToStr(mm.Close.Buffer[inpShortTermTL-1],Digits)+" head:"+DoubleToStr(mm.Close.Buffer[0],Digits)+"]");
    Append(text,"Line Open [tail:"+DoubleToStr(mm.Open.Line[inpShortTermTL-1],Digits)+" head:"+DoubleToStr(mm.Open.Line[0],Digits)+" s:"+DoubleToStr(mm.Open.Slope,Digits)+"]","\n");
    Append(text,"Close [tail:"+DoubleToStr(mm.Close.Line[inpShortTermTL-1],Digits)+" head:"+DoubleToStr(mm.Close.Line[0],Digits)+" s:"+DoubleToStr(mm.Close.Slope,Digits)+"]");
    Append(text,"FOC [now:"+DoubleToStr(pf.FOC(Now),1),"\n");
    Append(text,"min:"+DoubleToStr(pf.FOC(Min),1));
    Append(text,"max:"+DoubleToStr(pf.FOC(Max),1)+"]");
    Append(text,"Momentum FOC "+proper(DirText(mm.Direction))+" ["+IntegerToString(Direction(mm.FOC.Momentum),3)+"]","\n");
    Append(text,"Slope "+proper(DirText(Direction(mm.Open.Slope+mm.Close.Slope)))+" ["+DoubleToStr(mm.Open.Slope+mm.Close.Slope,3)+"]");
    
    return (text);
  }

//+------------------------------------------------------------------+
//| FractalDetailStr - Returns a formatted Fractal Rec string        |
//+------------------------------------------------------------------+
string FractalDetailStr(FractalDetail &Detail)
  {
    string text    = "";

    Append(text,EnumToString(Detail.Type),"|");
    Append(text,DirText(Detail.Direction),"|");
    Append(text,EnumToString(Detail.State),"|");
    Append(text,ActionText(Detail.Bias),"|");
    Append(text,(string)Detail.Age,"|");

    Append(text,DoubleToStr(Detail.Expansion.Now*100,1)+"%","|");
    Append(text,DoubleToStr(Detail.Expansion.Min*100,1)+"%","|");
    Append(text,DoubleToStr(Detail.Expansion.Max*100,1)+"%","|");
    Append(text,DirText(Detail.Expansion.ActiveDir),"|");
    Append(text,EnumToString(Detail.Expansion.Event),"|");
    Append(text,DoubleToStr(FiboPercent(Detail.Expansion.Level),1),"|");
    Append(text,DoubleToStr(Detail.Expansion.High,Digits),"|");
    Append(text,DoubleToStr(Detail.Expansion.Low,Digits),"|");
    Append(text,(string)Detail.Expansion.Momentum,"|");

    Append(text,DoubleToStr(Detail.Retrace.Now*100,1)+"%","|");
    Append(text,DoubleToStr(Detail.Retrace.Min*100,1)+"%","|");
    Append(text,DoubleToStr(Detail.Retrace.Max*100,1)+"%","|");
    Append(text,DirText(Detail.Retrace.ActiveDir),"|");
    Append(text,EnumToString(Detail.Retrace.Event),"|");
    Append(text,DoubleToStr(FiboPercent(Detail.Retrace.Level),1),"|");
    Append(text,(string)Detail.Retrace.Momentum,"|");
    Append(text,DoubleToStr(Detail.Retrace.High,Digits),"|");
    Append(text,DoubleToStr(Detail.Retrace.Low,Digits),"|");

    return (text);
  }

//+------------------------------------------------------------------+
//| FractalMasterStr - Returns formatted Fractal Summary             |
//+------------------------------------------------------------------+
string FractalMasterStr(FractalMaster &Master)
  {
    string text    = "";

    Append(text,EnumToString(Master.Source),"|");
    Append(text,BoolToStr(IsEqual(Master.Session,SessionTypes),"Error",EnumToString(Master.Session)),"|");
    Append(text,DirText(Master.Direction),"|");
    Append(text,DirText(Master.BreakoutDir),"|");
    Append(text,EnumToString(Master.Event),"|");
    Append(text,ActionText(Master.Bias),"|");
//    Append(text,Weight;
    Append(text,BoolToStr(Master.Hedge,"Hedge","Hold"),"|");
    Append(text,EnumToString(Master.State),"|");

    for (int fibo=0;fibo<3;fibo++)
      Append(text,FractalDetailStr(Master.Fibo[fibo]),"|");

    return (text);
  }

//+------------------------------------------------------------------+
//| PivotStr                                                         |
//+------------------------------------------------------------------+
string PivotStr(string Type, PivotRec &Pivot)
  {
    string prText        = "|"+Type;
    
    Append(prText,DirText(Pivot.Direction),"|");
    Append(prText,(string)Pivot.Count,"|");
    Append(prText,DoubleToStr(Pivot.Open,Digits),"|");
    Append(prText,DoubleToStr(Pivot.High,Digits),"|");
    Append(prText,DoubleToStr(Pivot.Low,Digits),"|");
    Append(prText,DoubleToStr(Pivot.Close,Digits),"|");

    return(prText);
  }

//+------------------------------------------------------------------+  
//| PrintRec - Formasts and sends pivots to supplied output          |
//+------------------------------------------------------------------+
void PrintRec(DisplayTypes Output)
  {
    string prDisplay    = "";
    
    switch (Output)
    {
      case Log:       Print("|Record|"+ActionText(pm.Action)+"|"+DirText(pm.Direction)+"|"+ActionText(pm.Bias)+"|"+(string)pm.Segment+"|"+(string)pf.Count(Tick));
                      //Append(prText,BoolToStr(Pivot.Broken,"BROKEN","UNBROKEN"),"|");
                      //Append(prText,DoubleToStr(Pivot.Correction,Digits),"|");
                      //Append(prText,DoubleToStr(Pivot.Resume,Digits),"|");
                      Print(PivotStr("Master[Lead]",pm.Master.Lead));
                      Print(PivotStr("Master[Prior]",pm.Master.Prior));
                      Print(PivotStr("Active[Lead]",pm.Active.Lead));
                      Print(PivotStr("Active[Prior]",pm.Active.Prior));
                      Print(PivotStr("Pivot[Lead]",pm.Pivot.Lead));
                      Print(PivotStr("Pivot[Prior]",pm.Pivot.Prior));
                      Print(PivotStr("Tick[Lead]",pm.Tick.Lead));
                      Print(PivotStr("Tick[Prior]",pm.Tick.Prior));
                      break;
      case Display:   prDisplay    = "|Record|"+ActionText(pm.Action)+"|"+DirText(pm.Direction)+"|"+ActionText(pm.Bias)+"|"+(string)pm.Segment+"|"+(string)pf.Count(Tick)+"\n";
                      prDisplay   += PivotStr("Master[Lead]",pm.Master.Lead)+"\n";
                      prDisplay   += PivotStr("Master[Prior]",pm.Master.Prior)+"\n";
                      prDisplay   += PivotStr("Active[Lead]",pm.Active.Lead)+"\n";
                      prDisplay   += PivotStr("Active[Prior]",pm.Active.Prior)+"\n";
                      prDisplay   += PivotStr("Pivot[Lead]",pm.Pivot.Lead)+"\n";
                      prDisplay   += PivotStr("Pivot[Prior]",pm.Pivot.Prior)+"\n";
                      prDisplay   += PivotStr("Tick[Lead]",pm.Tick.Lead)+"\n";
                      prDisplay   += PivotStr("Tick[Prior]",pm.Tick.Prior)+"\n";
                      CallPause(prDisplay);
                      break;
    }
  }