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


input string       EAHeader            = "";    //+------ App Config inputs ------+
input int          inpTrigger          = 6;     // Open Order Trigger in Periods
input int          inpStall            = 6;     // Fractal Stall Factor in Periods
input YesNoType    inpShowMasterLines  = Yes;   // Show Master Lines
input YesNoType    inpShowBroken       = No;    // Show Broken/Unbroken Flags

input string       FractalHeader       = "";    //+------ Fractal Options ---------+
input int          inpRangeMin         = 60;    // Minimum fractal pip range
input int          inpRangeMax         = 120;   // Maximum fractal pip range

input string       PipMAHeader         = "";    //+------ PipMA inputs ------+
input int          inpDegree           = 6;     // Degree of poly regression
input int          inpPeriods          = 200;   // Number of poly regression periods
input double       inpTolerance        = 0.5;   // Trend change tolerance (sensitivity)
input double       inpAggFactor        = 2.5;   // Tick Aggregate factor (1=1 PIP);
input int          inpIdleTime         = 50;    // Market idle time in Pips

input string       SessionHeader       = "";    //+---- Session Hours -------+
input int          inpAsiaOpen         = 1;     // Asian market open hour
input int          inpAsiaClose        = 10;    // Asian market close hour
input int          inpEuropeOpen       = 8;     // Europe market open hour`
input int          inpEuropeClose      = 18;    // Europe market close hour
input int          inpUSOpen           = 14;    // US market open hour
input int          inpUSClose          = 23;    // US market close hour
input int          inpGMTOffset        = 0;     // GMT Offset

  //-- General Operationals
  bool             PauseOn             = true;
  bool             PrintOn             = false;

  //-- Enumerations  
  enum DisplayTypes
  {
    Display,
    Log
  };

  //--- Class Objects
  COrder          *order             = new COrder(Discount,Hold,Hold);
  CFractal        *f                 = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal     *pf                = new CPipFractal(inpDegree,inpPeriods,inpTolerance,inpAggFactor,inpIdleTime);
  CSession        *s[SessionTypes];

  struct           FractalMaster
                   {
                     FractalDetail   f[6];
                     FractalDetail   s[SessionTypes][3];
                     FractalDetail   pf[3];
                   };

  struct           FractalPanel
                   {
                     int             ActiveDir;
                     int             BreakoutDir;
                     bool            Trigger;
                     string          Text[3];
                     int             Color[3];
                     FractalDetail   Fibo[3];
                   };
                   
  //struct           LinearRegression  //-- Data structure for regression forecasts
  //                 {
  //                   int             Direction;
  //                   double          Base;
  //                   double          Step;
  //                   CArrayDouble    *Point[];
  //                   double          Forecast;
  //                 };

  struct           PivotRec          //-- Price Consolidation Pivots
                   {
                     int             Direction;
                     int             Count;
                     double          Open;
                     double          Close;
                     double          High;
                     double          Low;
                   };
  
  struct           PivotSet
                   {
                     PivotRec        Lead;
                     PivotRec        Prior;
                   };

  struct           PivotMaster
                   {
                     int             Action;      //-- Consolidation Pivot Action
                     int             Direction;   //-- Tick Direction
                     int             Segment;     //-- Count of Consolidation Segments;
                     int             State;       //-- {TBD} Master State
                     int             Bias;        //-- Master Bias (Action/Contrarian Hedge)
                     bool            Broken;      //-- Master broken flag;
                     double          Correction;  //-- Master critical pivot price
                     PivotSet        Master;      //-- Micro Trend Pivots
                     PivotSet        Active;      //-- Active Term Legs 
                     PivotSet        Pivot;       //-- Consolidation Pivots Lead/Prior
                     PivotSet        Tick;        //-- Full Tick Lead/Prior
                   };
                   
  struct           ActionMaster
                   {
                     ActionState     State;
                     bool            Triggered;
                     bool            NewZone;
                     OrderSummary    Zone;
                   };

  //-- General Operational variables
  int             SignalBias;  //-- anomaly found; testing for actionable viability

  AccountMetrics Account;
                                   
  //--- Collections
  FractalMaster    fm;
  PivotMaster      pm;
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
//| UpdateFiboPanel - Refresh Fractal Area labels (v2)               |
//+------------------------------------------------------------------+
void UpdateFiboPanel(int Row, FractalPanel &Panel)
  {
    for (int fibo=0;fibo<3;fibo++)
    {
      UpdateBox("bxfFA-"+(string)Row+":"+(string)fibo,Color(Panel.Fibo[fibo].Direction,IN_DARK_PANEL));
      UpdateLabel("lbvFA-H"+(string)Row+":"+(string)fibo,center(EnumToString(Panel.Fibo[fibo].Type),10),clrGoldenrod);
      UpdateLabel("lbvFA-E"+(string)Row+":"+(string)fibo,center(NegLPad(Panel.Fibo[fibo].Expansion.Now*100,1)+"%",10),clrDarkGray,10);
      UpdateLabel("lbvFA-R"+(string)Row+":"+(string)fibo,center(NegLPad(Panel.Fibo[fibo].Retrace.Now*100,1)+"%",10),clrDarkGray,10);
      UpdateLabel("lbvFA-HD"+(string)fibo+":"+(string)Row,Panel.Text[fibo],Panel.Color[fibo],BoolToInt(fibo==2,10,14));
    }

    UpdateDirection("lbvFA-ADir:"+(string)Row,Panel.ActiveDir,Color(Panel.ActiveDir),28);
    UpdateDirection("lbvFA-BDir:"+(string)Row,Panel.BreakoutDir,Color(Panel.BreakoutDir),12);

    UpdateLabel("lbvFA-Trig:"+(string)Row,CharToStr(177),BoolToInt(Panel.Trigger,Color(Panel.ActiveDir),clrDarkGray),14,"Wingdings");
  }

//+------------------------------------------------------------------+
//| UpdatePanel - Refresh Session Control Panel labels (v2)          |
//+------------------------------------------------------------------+
void UpdatePanel(void)
  {
    for (SessionType type=0;type<SessionTypes;type++)
    {
      if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==C'60,60,60'||s[type].Event(NewHour))
      {
        UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[type].Fractal(sftTerm).Direction,IN_DARK_DIR));
        UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s[type].IsOpen(),clrYellow,clrBoxOff));
      }
    }
  }

//+------------------------------------------------------------------+  
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "-- Manual-v2 --\n";
    
    for (int action=OP_BUY;action==OP_SELL;action++)
      if (am[action].Triggered)
        Append(rsComment,"Trigger["+ActionText(pm.Action)+"]","\n");

    if (inpShowMasterLines==Yes)
    {
      UpdateLine("Master[Lead].High",pm.Master.Lead.High,STYLE_SOLID,Color(Direction(pm.Bias,InAction)));
      UpdateLine("Master[Lead].Low",pm.Master.Lead.Low,STYLE_SOLID,Color(Direction(pm.Bias,InAction)));
      UpdateLine("Master[Lead].Close",pm.Master.Lead.Close,STYLE_DOT,Color(Direction(pm.Bias,InAction)));
    }

    UpdatePanel();

    if (PrintOn)
      PrintFractal();

    Comment(rsComment);
//    pf.RefreshScreen();
  }

//+------------------------------------------------------------------+
//| CalcLinearTrend                                                  |
//+------------------------------------------------------------------+
void CalcLinearTrend(double &Price[])
  {
    //--- Linear regression line
    double m[5]      = {0.00,0.00,0.00,0.00,0.00};  //--- slope
    double b         = 0.00;                        //--- y-intercept
    
    double sumx      = 0.00;
    double sumy      = 0.00;
    
    for (int idx=0;idx<inpTrigger;idx++)
    {
      sumx += idx+1;
      sumy += Price[idx];
      
      m[1] += (idx+1)* Price[idx];  // Exy
      m[3] += pow(idx+1,2);         // E(x^2)
    }
    
    m[2]    = fdiv(sumx*sumy,inpTrigger);   // (Ex*Ey)/n
    m[4]    = fdiv(pow(sumx,2),inpTrigger); // [(Ex)^2]/n
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy-m[0]*sumx)/inpTrigger;
    
    for (int idx=0;idx<inpTrigger;idx++)
      Price[idx] = (m[0]*(idx+1))+b; //--- y=mx+b
  }


//+------------------------------------------------------------------+
//| NewAction - Updates Action on change; filters OP_NO_ACTION       |
//+------------------------------------------------------------------+
bool NewAction(int &Change, int Compare, bool Update=true)
  {
    if (Compare==OP_NO_ACTION)
      return (false);
      
    if (IsChanged(Change,Compare,Update))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| NewDirection - Updates Direction on change;filters DirectionNone |
//+------------------------------------------------------------------+
bool NewDirection(int &Change, int Compare, bool Update=true)
  {
    if (Compare==DirectionNone)
      return (false);

    if (Change==DirectionNone)
      if (IsChanged(Change,Compare,Update))
        return (false);
    
    if (IsChanged(Change,Compare,Update))
      return (true);
      
    return (false);
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

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      s[type].Update();

      //-- Fractal Detail Update      
      ArrayInitialize(Panel.Color,clrDarkGray);
      
      Panel.Text[0] = EnumToString(type)+" "+proper(ActionText(s[type][ActiveSession].Bias))+
                  " "+BoolToStr(s[type][ActiveSession].Bias==Action(s[type][ActiveSession].Direction,InDirection),"Hold","Hedge");

      Panel.ActiveDir          = s[type].Fractal(sftTerm).Direction;
      Panel.BreakoutDir        = s[type].Fractal(sftTerm).BreakoutDir;
      Panel.Text[1]            = EnumToString(s[type].Fractal(sftTerm).State);
      Panel.Trigger            = s[type].Event(NewFractal)||s[type].Event(NewBias);
      
      if (s[type].IsOpen())
      {
        Panel.Color[0]         = clrWhite;
        
        if (ServerHour()>s[type].SessionHour(SessionClose)-3)
        {
          Panel.Text[2]        = "Late Session ("+IntegerToString(s[type].SessionHour())+")";
          Panel.Color[2]       = clrRed;
        }
        else
        if (s[type].SessionHour()>3)
        {
          Panel.Text[2]       = "Mid Session ("+IntegerToString(s[type].SessionHour())+")";
          Panel.Color[2]      = clrYellow;
        }
        else
        {
          Panel.Text[2]       = "Early Session ("+IntegerToString(s[type].SessionHour())+")";
          Panel.Color[2]      = clrLawnGreen;
        }
      }
      else
        Panel.Text[2]         = "Session Is Closed";

      if (s[type].Event(NewBreakout)||s[type].Event(NewReversal))
        Panel.Color[1]        = clrWhite;
      else
      if (s[type].Event(NewRally)||s[type].Event(NewPullback))
        Panel.Color[1]        = clrYellow;

      for (FractalType fibo=Origin;fibo<Prior;fibo++)
      {
        fm.s[type][fibo].Event             = BoolToEvent(Panel.Trigger,
                                              (EventType)Coalesce(BoolToDouble(s[type].Event(NewOrigin)&&IsEqual(fibo,Origin),NewFractal),
                                                                  BoolToDouble(s[type].Event(NewTrend)&&IsEqual(fibo,Trend),NewFractal),
                                                                  BoolToDouble(s[type].Event(NewTerm)&&IsEqual(fibo,Term),NewFractal),
                                                                  BoolToDouble(s[type].Event(NewFractal)&&IsEqual(fibo,Term),NewExpansion),
                                                                  BoolToDouble(s[type].Event(NewBias),NewBias)),NoEvent);
        fm.s[type][fibo].Type              = fibo;
        fm.s[type][fibo].Direction         = s[type].Fractal((SessionFractalType)fibo).Direction;
        fm.s[type][fibo].BreakoutDir       = s[type].Fractal((SessionFractalType)fibo).BreakoutDir;
        fm.s[type][fibo].State             = s[type].Fractal((SessionFractalType)fibo).State;
        fm.s[type][fibo].Bias              = s[type].Fractal((SessionFractalType)fibo).Bias;
        fm.s[type][fibo].Age               = s[type].Age();
        fm.s[type][fibo].Expansion.Min     = s[type].Expansion((SessionFractalType)fibo,Min,InDecimal);
        fm.s[type][fibo].Expansion.Max     = s[type].Expansion((SessionFractalType)fibo,Max,InDecimal);
        fm.s[type][fibo].Expansion.Now     = s[type].Expansion((SessionFractalType)fibo,Now,InDecimal);
        fm.s[type][fibo].Retrace.Min       = s[type].Retrace((SessionFractalType)fibo,Min,InDecimal);
        fm.s[type][fibo].Retrace.Max       = s[type].Retrace((SessionFractalType)fibo,Max,InDecimal);
        fm.s[type][fibo].Retrace.Now       = s[type].Retrace((SessionFractalType)fibo,Now,InDecimal);
        
        Panel.Fibo[fibo]                   = fm.s[type][fibo];
      }

      UpdateFiboPanel(type+4,Panel);
    }
  }

//+------------------------------------------------------------------+
//| UpdateFractal                                                    |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {
    f.Update();
        
    FractalType  ufLeg             = f.Previous(f.Leg(Active));
    FractalPanel Panel;
 
    ArrayInitialize(Panel.Color,clrDarkGray);

    for (FractalType type=5;type>NoValue;type--)
    {
      fm.f[type].Type                 = ufLeg;
      fm.f[type].Direction            = f.Direction(ufLeg);
      fm.f[type].State                = BoolToWord(ufLeg==Origin,f.Origin().State,f.State());
      fm.f[type].Bias                 = BoolToInt(f.Fibonacci(ufLeg,Retrace,Max,InPercent)<FiboPercent(Fibo50),Action(f.Direction(ufLeg)),Action(f.Direction(ufLeg),InDirection,InContrarian));
      fm.f[type].Age                  = BoolToInt(ufLeg==Origin,f.Origin().Age,f[ufLeg].Bar);
      fm.f[type].Expansion.Min        = f.Fibonacci(ufLeg,Expansion,Min);
      fm.f[type].Expansion.Max        = f.Fibonacci(ufLeg,Expansion,Max);
      fm.f[type].Expansion.Now        = f.Fibonacci(ufLeg,Expansion,Now);
      fm.f[type].Retrace.Min          = f.Fibonacci(ufLeg,Retrace,Min);
      fm.f[type].Retrace.Max          = f.Fibonacci(ufLeg,Retrace,Max);
      fm.f[type].Retrace.Now          = f.Fibonacci(ufLeg,Retrace,Now);

      if (IsBetween(ufLeg,Origin,Term))
        fm.f[type].Event              = (EventType)Coalesce(BoolToDouble(f.Event(NewCorrection,Critical)&&IsEqual(ufLeg,Origin),NewCorrection),
                                                            BoolToDouble(f.Event(NewTrend)&&IsEqual(ufLeg,Trend),NewFractal),
                                                            BoolToDouble(f.Event(NewTerm)&&IsEqual(ufLeg,Term),NewFractal),
                                                            BoolToDouble(f.Event(NewOrigin)&&IsEqual(ufLeg,Origin),NewFractal),NoEvent);
      else
        fm.f[type].Event              = (EventType)Coalesce(BoolToDouble(f.Event(NewCorrection,Major)&&IsEqual(ufLeg,Divergent),NewCorrection),
                                                            BoolToDouble(f.Event(NewDivergence)&&IsEqual(ufLeg,Divergent),NewFractal),
                                                            BoolToDouble(f.Event(NewConvergence)&&IsEqual(ufLeg,Convergent),NewFractal),
                                                            BoolToDouble(f.Event(NewFractal)&&IsEqual(type,5),NewExpansion),NoEvent);
      
      Panel.Fibo[(int)fmod(type,3)]   = fm.f[type];
      
      if (IsEqual(ufLeg,Origin))
      {
        Panel.ActiveDir               = f.Direction();
        Panel.BreakoutDir             = f.Origin().Direction;
        Panel.Trigger                 = fm.f[type].Event>NoEvent;

        Panel.Text[0]                 = BoolToStr(f.Origin().Direction==DirectionUp,"Long","Short")+" "+EnumToString(f.Origin().State);
        Panel.Text[1]                 = EnumToString(f.State());
        Panel.Text[2]                 = BoolToStr(f.IsRange(Divergent,Origin),"Divergent","Convergent");
        

        Panel.Trigger                 = fm.f[type].Event>NoEvent;
        
        UpdateFiboPanel(3,Panel);
      };
      
      if (IsEqual(type,3))
      {
        Panel.ActiveDir               = f.Direction(Base);
        Panel.BreakoutDir             = f.Origin().Direction;
        Panel.Trigger                 = fm.f[type].Event>NoEvent;

        Panel.Text[0]                 = proper(DirText(f.Direction(Base)))+" "+BoolToStr(BarDir()==DirectionUp,"Rally","Pullback");
        Panel.Text[1]                 = EnumToString(fm.f[type].State);
        Panel.Text[2]                 = EnumToString(fm.f[type+1].Type)+" ("+(string)fm.f[type+1].Age+")";

        UpdateFiboPanel(2,Panel);
      }


      if (IsEqual(type,5))
        ufLeg                      = f.Previous(ufLeg);
      else
      if (IsEqual(type,4))
        ufLeg                      = f.Previous(ufLeg,Convergent);
      else
        ufLeg                      = f.Previous(type);
    }
  }

//+------------------------------------------------------------------+
//| SetBroken - Return Price and Set Broken State for supplied Pivot |
//+------------------------------------------------------------------+
void SetBroken(PivotRec &Pivot)
  {
    if (Pivot.Direction==DirectionNone)
      return;

    if (pf.Event(NewTick))
      if (pm.Segment==0)
        if (IsEqual(Pivot.Low,Close[0],Digits)||IsEqual(Pivot.High,Close[0],Digits))
          if (Pivot.Direction==pm.Direction)
          {
            if (IsChanged(pm.Broken,false))
            {
              Flag("Unbroken",clrWhite,inpShowBroken==Yes);
              pm.Correction     = (Close[0]);
            }
          }
          else
            if (IsChanged(pm.Broken,true))
            {
              Flag("Broken",Color(pm.Direction),inpShowBroken==Yes);
              pm.Correction     = (Close[0]);
            }
  }

//+------------------------------------------------------------------+
//| SetTrigger - tests for and maintains trigger states              |
//+------------------------------------------------------------------+
void SetTrigger(void)
  {
    am[OP_BUY].Triggered            = false;
    am[OP_SELL].Triggered           = false;
    
    if (Close[0]<pm.Tick.Lead.Close)
      if (Close[0]>fmin(pm.Tick.Lead.Low,pm.Tick.Prior.Low))
        am[OP_BUY].Triggered        = true;

    if (Close[0]>pm.Tick.Lead.Close)
      if (Close[0]<fmax(pm.Tick.Lead.High,pm.Tick.Prior.High))
        am[OP_SELL].Triggered       = true;
  }

//+------------------------------------------------------------------+
//| PivotBias - Returns the computed Bias in Action                  |
//+------------------------------------------------------------------+
int PivotBias(ReservedWords Type, bool Contrarian=false)
  {
    int tbDirection             = DirectionNone;
    
    switch (Type)
    {
      case Tick:    if (IsLower(pm.Tick.Lead.Low,pm.Tick.Prior.Low,NoUpdate)) tbDirection=DirectionDown;
                    if (IsHigher(pm.Tick.Lead.High,pm.Tick.Prior.High,NoUpdate)) tbDirection=DirectionUp;
                    break;

      case Pivot:   if (pm.Segment==0)
                    {
                      tbDirection = pm.Pivot.Lead.Direction;
      
                      if (IsLower(pm.Tick.Lead.Low,pm.Pivot.Lead.Low,NoUpdate)) tbDirection=DirectionDown;
                      if (IsHigher(pm.Tick.Lead.High,pm.Pivot.Lead.High,NoUpdate)) tbDirection=DirectionUp;
                    }
                    else
                    {
                      tbDirection = pm.Pivot.Prior.Direction;
      
                      if (IsLower(pm.Tick.Lead.Low,pm.Pivot.Prior.Low,NoUpdate)) tbDirection=DirectionDown;
                      if (IsHigher(pm.Tick.Lead.High,pm.Pivot.Prior.High,NoUpdate)) tbDirection=DirectionUp;
                    }
                    break;
                    
      case Active:  tbDirection = BoolToInt(pm.Active.Lead.Count>pm.Active.Prior.Count,pm.Active.Lead.Direction,pm.Active.Prior.Direction);
                    break;
                    
      case Master:  tbDirection = BoolToInt(pm.Segment==0,pm.Pivot.Lead.Direction,pm.Pivot.Prior.Direction);
    };
    
    return (Action(tbDirection,InDirection,Contrarian));
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
    Pivot.Lead.Count       = BoolToInt(Reset,1,Pivot.Lead.Count);
    Pivot.Prior            = Pivot.Lead;
    Pivot.Lead             = Copy;
    Pivot.Lead.Close       = NoValue;
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
    
    pf.Update();

    if (pf.Event(NewTick))
    {
      //-- Set Triggers (Pre-Update)
      SetTrigger();
      
      //-- Process Tick Segment
      if (pm.Tick.Lead.Direction==pf.Direction(Tick))
        if (NewDirection(pm.Tick.Lead.Direction,Direction(pm.Tick.Lead.Close-pm.Tick.Lead.Open)))
          NewPivot(pm.Tick,Flush(pm.Tick.Lead.Direction,TickReset));
        else
          NewPivot(pm.Tick,Flush(pf.Direction(Tick),++pm.Tick.Lead.Count),false);
      else
        if (NewDirection(pm.Tick.Lead.Direction,pf.Direction(Tick)))
          NewPivot(pm.Tick,Flush(pf.Direction(Tick),TickReset));
          
      SignalBias = BoolToInt(pm.Tick.Lead.Direction==pf.Direction(Tick),OP_NO_ACTION,Action(pm.Tick.Lead.Direction,InDirection,InContrarian));
      
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

        //-- Check for Bias Change
        if (NewAction(pm.Bias,PivotBias(Master)))
          NewPivot(pm.Master,pm.Active.Lead);
      }
    }

//    if (pm.SignalBias!=OP_NO_ACTION)
//      Print("Special|"+(string)pf.Count(History)+"|"+PivotStr("Tick[Lead]",pm.Tick.Lead));    

    //-- Manage Leg Data
    UpdatePivot(pm.Tick.Lead);
    UpdatePivot(pm.Active.Lead,NoUpdate);
    UpdatePivot(pm.Master.Lead,NoUpdate);

    //-- Manage Master Segments
    if (pf.Event(NewTick))
      if (Action(pm.Direction)==pm.Bias)
        pm.Master.Lead.Close      = pm.Active.Lead.Close;

    SetBroken(pm.Master.Lead);
    
    FractalPanel Panel;

    //-- Load Fractal Data
    for (FractalType type=Origin;type<(int)PipFractalTypes;type++)
    {
      fm.pf[type].Type            = type;
      fm.pf[type].Direction       = pf.Direction(type);
      fm.pf[type].State           = NoState;
      fm.pf[type].Bias            = OP_NO_ACTION;
      fm.pf[type].Age             = pf[type].Age[fpExpansion];
      fm.pf[type].Expansion.Min   = pf.Fibonacci(type,Expansion,Min);
      fm.pf[type].Expansion.Max   = pf.Fibonacci(type,Expansion,Max);
      fm.pf[type].Expansion.Now   = pf.Fibonacci(type,Expansion,Now);
      fm.pf[type].Retrace.Min     = pf.Fibonacci(type,Retrace,Min);
      fm.pf[type].Retrace.Max     = pf.Fibonacci(type,Retrace,Max);
      fm.pf[type].Retrace.Now     = pf.Fibonacci(type,Retrace,Now);
      
      Panel.Fibo[type]            = fm.pf[type];
    }
    
    //-- Update pipMA Fractal Panel    
    Panel.ActiveDir               = pf.Direction(Term);
    Panel.BreakoutDir             = pf.Direction(Trend);
    Panel.Trigger                 = false;
    
    Panel.Text[0]                 = EnumToString(pf.State().Bearing)+" "+proper(ActionText(pf.State().Bias));
    Panel.Text[1]                 = EnumToString(pf.State().Type[Origin]);
    Panel.Text[2]                 = pf.StateText();
    
    ArrayInitialize(Panel.Color,clrDarkGray);
    
    UpdateFiboPanel(1,Panel);
    
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
//| ManageOrders                                                     |
//+------------------------------------------------------------------+
void ManageLong(int &Batch[])
  {
  }

//+------------------------------------------------------------------+
//| ManageOrders                                                     |
//+------------------------------------------------------------------+
void ManageShort(int &Batch[])
  {
    static int tick = 0;
    
    OrderRequest request       = order.BlankRequest();
    
    tick++;
    
    if (IsBetween(tick,4,8))
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      request.Memo             = "Testing Sell Limit";
      request.Type             = OP_SELLLIMIT;
      request.TakeProfit       = 18.12;
      request.Price            = 18.14;
      request.Expiry           = TimeCurrent()+(Period()*(60*12));
    }
    
    if (tick<8)
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
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    int batch[];
    
    ManageLong(batch);
    ManageShort(batch);

    order.Execute(batch,true);
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
//| FractalStr - Returns a formatted Fractal Rec string              |
//+------------------------------------------------------------------+
string FractalStr(FractalDetail &Fractal)
  {
    string fsText    = "";
    
    Append(fsText,EnumToString(Fractal.Type));
    Append(fsText,DirText(Fractal.Direction));
    Append(fsText,EnumToString(Fractal.State));
    Append(fsText,ActionText(Fractal.Bias));
    Append(fsText,(string)Fractal.Age);
    Append(fsText,"(e) "+DoubleToStr(Fractal.Expansion.Now*100,1)+"%");
    Append(fsText," [<"+DoubleToStr(Fractal.Expansion.Min*100,1)+"%");
    Append(fsText," >"+DoubleToStr(Fractal.Expansion.Max*100,1)+"%]");
    Append(fsText,"(rt) "+DoubleToStr(Fractal.Retrace.Now*100,1)+"%");
    Append(fsText," [<"+DoubleToStr(Fractal.Retrace.Min*100,1)+"%");
    Append(fsText," >"+DoubleToStr(Fractal.Retrace.Max*100,1)+"%]");

    return (fsText);
  }

//+------------------------------------------------------------------+
//| PrintFractal - Prints the Fractal Master                         |
//+------------------------------------------------------------------+
void PrintFractal(void)
  {
    string text    = "\n//--- Fractal ---//";
    
    for (int fractal=0;fractal<6;fractal++)
      Append(text,FractalStr(fm.f[fractal]),"\n");

    Append(text,"\n//--- PipFractal ---//","\n");
    
    for (int fractal=0;fractal<3;fractal++)
      Append(text,FractalStr(fm.pf[fractal]),"\n");

    Print(text);
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
 