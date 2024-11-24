//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                         Raw Order-Integration EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "2.12"
#property strict

#define debug false

#define NetZero      0
#define NetLong      1
#define NetShort    -1

#include <Class/Order.mqh>
#include <Class/Session.mqh>
#include <Class/TickMA.mqh>

#include <ordman.mqh>

  //-- Class defs
  CSession              *s[SessionTypes];
  CTickMA               *t;

  //--- EA Config
  input string           appHeader           = "";            // +--- Application Config ---+
  input BrokerModel      inpBrokerModel      = Discount;      // Broker Model
  input string           inpComFile          = "manual.csv";  // Command File
  input string           inpSigOutFile       = "mv2-sig.bin"; // Signal Output File
  input string           inpLogFile          = "";            // Log File for Processed Commands
  input int              inpIndSNVersion     = 2;             // Control Panel Version

  //--- Order Config
  input string           ordHeader           = "";            // +------ Order Options ------+
  input double           inpMinTarget        = 5.0;           // Equity% Target
  input double           inpMinProfit        = 0.8;           // Minimum take profit%
  input double           inpMaxRisk          = 50.0;          // Maximum Risk%
  input double           inpMaxMargin        = 60.0;          // Maximum Open Margin
  input double           inpLotScale         = 2.00;          // Scaling Lotsize Balance Risk%
  input double           inpLotSize          = 0.00;          // Lotsize Override
  input int              inpDefaultStop      = 50;            // Default Stop Loss (pips)
  input int              inpDefaultTarget    = 50;            // Default Take Profit (pips)
  input double           inpZoneStep         = 2.5;           // Zone Step (pips)
  input double           inpMaxZoneMargin    = 5.0;           // Max Zone Margin

  //--- Regression Config
  input string           regrHeader          = "";            // +--- Regression Config ----+
  input int              inpPeriods          = 80;            // Retention
  input double           inpAgg              = 2.5;           // Tick Aggregation
  input int              inpSigRetain        = 240;           // Signal History Retention Count
  input YesNoType        inpShowFibo         = No;            // Show Active Fibonacci Lines


  //--- Session Config
  input string           sessHeader          = "";            // +--- Session Config -------+
  input int              inpAsiaOpen         = 1;             // Asia Session Opening Hour
  input int              inpAsiaClose        = 10;            // Asia Session Closing Hour
  input int              inpEuropeOpen       = 8;             // Europe Session Opening Hour
  input int              inpEuropeClose      = 18;            // Europe Session Closing Hour
  input int              inpUSOpen           = 14;            // US Session Opening Hour
  input int              inpUSClose          = 23;            // US Session Closing Hour
  input int              inpGMTOffset        = 0;             // Offset from GMT+3


  //-- Strategy Types
  enum    StrategyType
          {
            Wait,            //-- Hold, wait for signal
            Build,           //-- Increase Position
            Manage,          //-- Maintain Margin, wait for profit oppty's
            Protect,         //-- Maintain Profit, wait for profit oppty's
            Hedge,           //-- Aggressive balancing on excessive drawdown
            Capture,         //-- Contrarian profit protection
            Mitigate,        //-- Risk management on pattern change
            Spot             //-- Contrarian Build Marker
          };


  //--- Data Source Type
  enum    SourceType
          {
            Session,         //-- Session
            TickMA           //-- TickMA
          };

  //--- SegmentState
  enum    SegmentState
          {
            HigherHigh,
            LowerLow,
            LowerHigh,
            HigherLow
          };

  struct SignalFractal
         {
           SourceType        Source;            //-- Source Indicator
           FractalType       Type;              //-- Origin, Trend, Term, Lead
         };


  struct SignalBar
         {
           int              Bar;
           double           Price;
         };

  struct SignalSegment
         {
           int               Direction;         //-- Direction Signaled
           SegmentState      State;
           RoleType          Lead;              //-- Calculated Signal Lead
           RoleType          Bias;              //-- Calculated Signal Bias
           double            Open;
           double            High;
           double            Low;
           double            Close;
         };
         
  //-- Signals (Events) requesting Manager Action (Response)
  struct  SignalRec
          {
            long             Tick;              //-- Tick Signaled by Event 
            int              Direction;         //-- Signal Direction
            FractalState     State;             //-- State of the Signal
            EventType        Event;             //-- Highest Event
            AlertType        Alert;             //-- Highest Alert Level
            double           Price;             //-- Signal price (gen. Close[0])
            SignalSegment    Segment;           //-- Active Segment Range
            double           Support;
            double           Resistance;
            bool             Checkpoint;        //-- Trigger (Fractal/Fibo/Lead Events)
            int              HedgeCount;        //-- Active Hedge Count; All Fractals
            double           Strength;          //-- % of Success derived from Fractals
            bool             ActiveEvent;       //-- True on Active Event (All Sources)
            AlertType        BoundaryAlert;     //-- Event Alert Type
            SignalFractal    Fractal;           //-- Fractal in Use;
            SignalFractal    Pivot;             //-- Fibonacci Pivot in Use;
          };

  struct SegmentTrigger
         {
           SignalSegment     Segment;
           long              Tick;
           bool              Active;
         };

  //-- Manager Config by Role
  struct  ManagerRec
          {
            StrategyType     Strategy;             //-- Role Responsibility/Strategy
            OrderSummary     Entry;                //-- Role Entry Zone Summary
            double           Equity[MeasureTypes]; //-- Fund Stats
            double           DCA;                  //-- Role DCA
            double           TakeProfit;           //-- Take Profit
            double           StopLoss;             //-- Stop Loss
            bool             Hold;                 //-- Hold Role Profit
            int              Strength;
            bool             Hedge;
          };

  //-- Master Control Operationals
  struct  MasterRec
          {
            RoleType         Lead;              //-- Process Manager (Owner|Lead)
            RoleType         OnCall;            //-- Manager on deck while unassigned
            double           HedgeLotSize;      //-- Fixed Hedge Lot Size
          };
          
  //-- Data Collections
  MasterRec              master;
  ManagerRec             manager[RoleTypes];    //-- Manager Detail Data
  SignalRec              signal;
  SignalBar              sigFP[FractalPoints];
  double                 sigHistory[];
  double                 sigFibonacci[];
  SegmentTrigger         trigger[FractalPoints];

  //-- Internal EA Configuration
  string                 indPanelSN          = "CPanel-v"+(string)inpIndSNVersion;
  string                 indSignalSN         = "Signal-v1";
  string                 objectstr           = "[mv2]";
  
  int                    dHandle;

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(SegmentState &Check, SegmentState Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
   
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| WriteSignal- Creates, maintains and writes Signal History        |
//+------------------------------------------------------------------+
void WriteSignal(void)
  {
    int sigHandle = FileOpen(inpSigOutFile,FILE_BIN|FILE_WRITE);

    if (sigHandle>INVALID_HANDLE)
    {
      FileWriteStruct(sigHandle,signal);
      FileWriteArray(sigHandle,sigFP);
      FileFlush(sigHandle);
      FileClose(sigHandle);
    }
  }

//+------------------------------------------------------------------+
//| DebugPrint - Prints debug/event data                             |
//+------------------------------------------------------------------+
void DebugPrint(void)
  {
    static int rangeDir    = NoDirection;
    static int fractalDir  = NoDirection;
    
    if (debug)
    {
      if (signal.Alert>NoAlert)
      {
        string ftext       = EnumToString(manager[Buyer].Strategy);
        
        Append(ftext,EnumToString(manager[Seller].Strategy),"|");
        Append(ftext,EnumToString(signal.Fractal.Source),"|");
        Append(ftext,EnumToString(signal.Fractal.Type),"|");
        Append(ftext,EnumToString(Fractal().State),"|");

        Append(ftext,EnumToString(signal.Pivot.Source),"|");
        Append(ftext,EnumToString(signal.Pivot.Type),"|");
        Append(ftext,EnumToString(Pivot(signal.Pivot.Source,signal.Pivot.Type).Event),"|");
        Append(ftext,DirText(Pivot(signal.Pivot.Source,signal.Pivot.Type).Direction),"|");
        Append(ftext,ActionText(Pivot(signal.Pivot.Source,signal.Pivot.Type).Lead),"|");
        Append(ftext,ActionText(Pivot(signal.Pivot.Source,signal.Pivot.Type).Bias),"|");
        Append(ftext,StringSubstr(EnumToString(Pivot(signal.Pivot.Source,signal.Pivot.Type).Level),4),"|");
        Append(ftext,DoubleToString(Pivot(signal.Pivot.Source,signal.Pivot.Type).Price,Digits),"|");
        Append(ftext,DoubleToString(Pivot(signal.Pivot.Source,signal.Pivot.Type).Open,Digits),"|");
        Append(ftext,DoubleToString(Pivot(signal.Pivot.Source,signal.Pivot.Type).High,Digits),"|");
        Append(ftext,DoubleToString(Pivot(signal.Pivot.Source,signal.Pivot.Type).Low,Digits),"|");

        int direction = BoolToInt(Fractal().State==Correction,Direction(Fractal().Direction,InDirection,InContrarian),Fractal().Direction);

        Append(ftext,BoolToStr(IsChanged(fractalDir,direction)||signal.Event==NewFractal,DirText(direction),"------"),"|");
        Append(ftext,EnumToString(signal.Segment.State),"|");
        Append(ftext,(string)fTick,"|");
        Append(ftext,TimeToStr(TimeCurrent()),"|");
        Append(ftext,DoubleToString(Close[0],_Digits),"|");
        Append(ftext,EnumToString(signal.State),"|");
        Append(ftext,BoolToStr(signal.Checkpoint,"Active","Idle"),"|");
        Append(ftext,BoolToStr(sigFP[fpRecovery].Price==Close[0],BoolToStr(signal.Segment.Direction==DirectionUp,"Sell","Buy"),"Idle"),"|");

        Append(ftext,BoolToStr(IsChanged(rangeDir,signal.Segment.Direction),DirText(signal.Segment.Direction),"------"),"|");
        Append(ftext,BoolToStr(s[Daily].ActiveEvent(),EnumToString(s[Daily].MaxAlert()),"Idle"),"|");
        Append(ftext,BoolToStr(t.ActiveEvent(),EnumToString(t.MaxAlert()),"Idle"),"|");
        Append(ftext,EnumToString(signal.Alert),"|");
        Append(ftext,DoubleToStr(signal.Strength*100,1),"|");

        for (EventType type=1;type<EventTypes;type++)
          switch (type)
          {
            case NewSegment: Append(ftext,EnumToString(Alert(type)),"|");
                             Append(ftext,BoolToStr(t.Logged(NewLead,Nominal),"Nominal",
                                          BoolToStr(t.Logged(NewLead,Warning),"Warning","NoAlert")),"|");
                             break;
            case NewLead:    {
                               AlertType alert    = (AlertType)BoolToInt(s[Daily].Event(NewLead,Nominal),Nominal);
                                         alert    = (AlertType)BoolToInt(t.Alert(NewLead)>Nominal,t.Alert(NewLead),alert);
                               Append(ftext,EnumToString(Alert(type)),"|");
                             }
                             break;
            case NewChannel: Append(ftext,EnumToString(Alert(type)),"|");
                             Append(ftext,BoolToStr(t.Logged(NewLead,Notify),"Notify","NoAlert"),"|");
                             break;
            case Exception:  Append(ftext,BoolToStr(IsEqual(signal.Event,Exception),"Critical","NoAlert"),"|");
                             break;
            default:         Append(ftext,EnumToString(Alert(type)),"|");
          }

        FileWrite(dHandle,ftext);
        FileFlush(dHandle);
      }
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static int     panelWinID   = NoValue;
           int     signalWinID  = ChartWindowFind(0,indSignalSN);
           int     line         = 0;

    if (signalWinID>NoValue)
    {
      UpdateLabel("lbvSigSource", EnumToString(signal.Fractal.Source)+" "+EnumToString(signal.Fractal.Type)+" "+EnumToString(Fractal().State),
                                  BoolToInt(Fractal().Pivot.Lead==Buyer,clrLawnGreen,clrRed),12,"Noto Sans Mono CJK HK");
      UpdateLabel("lbvSigFibo",   BoolToStr(IsBetween(Fractal().State,Rally,Correction),
                                    "Retrace x"+DoubleToStr(Fractal().Retrace.Percent[Max]*100,1)+"% "+
                                            "n"+DoubleToStr(Fractal().Retrace.Percent[Now]*100,1)+"%",
                                    "Extends x"+DoubleToStr(Fractal().Extension.Percent[Max]*100,1)+"% "+
                                            "n"+DoubleToStr(Fractal().Extension.Percent[Now]*100,1)+"%"),
                                  BoolToInt(Fractal().Pivot.Bias==Buyer,clrLawnGreen,clrRed),12,"Noto Sans Mono CJK HK");

      UpdateLabel("lbvTick",(string)fTick,BoolToInt(signal.Alert>NoAlert,clrYellow,clrDarkGray),12,"Noto Sans Mono CJK HK");
    }

      for (int action=Buyer;IsBetween(action,Buyer,Seller);action++)
        UpdateLabel("lbvOC-"+ActionText(action)+"-Hold",CharToStr(176),clrDarkGray,11,"Wingdings");

    //-- Update Control Panel (Application)
    if (IsChanged(panelWinID,ChartWindowFind(0,indPanelSN)))
    {
      //-- Update Panel
      order.ConsoleAlert("Connected to "+indPanelSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));
      
      //-- Hide non-Panel elements
      UpdateLabel("pvBalance","",clrNONE,1);
      UpdateLabel("pvProfitLoss","",clrNONE,1);
      UpdateLabel("pvNetEquity","",clrNONE,1);
      UpdateLabel("pvEquity","",clrNONE,1);
      UpdateLabel("pvMargin","",clrNONE,1);

      Comment("");
    }

    if (IsEqual(panelWinID,NoValue))
    {
      UpdateLabel("pvBalance","$"+dollar(order.Metrics().Balance,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvProfitLoss","$"+dollar(order.Metrics().Equity,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvNetEquity","$"+dollar(order.Metrics().EquityBalance,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvEquity",DoubleToStr(order.Metrics().EquityClosed*100,1)+"%",Color(order[Net].Value),12,"Consolas");
      UpdateLabel("pvMargin",DoubleToString(order.Metrics().Margin*100,1)+"%",Color(order[Net].Lots),12,"Consolas");

      Comment(order.QueueStr()+order.OrderStr());
    }

    UpdateLabel("pvStratLead",EnumToString(master.Lead)+": "+EnumToString(manager[master.Lead].Strategy),clrGoldenrod,9,"Tahoma");
    UpdateLabel("pvStratOnCall",EnumToString(master.OnCall)+": "+EnumToString(manager[master.OnCall].Strategy),clrDarkGray,9,"Tahoma");
    UpdateLabel("pvSource",EnumToString(signal.Fractal.Source)+" "+EnumToString(signal.Fractal.Type)+" "+
                   EnumToString(Fractal().State),Color(Fractal().Direction),9,"Tahoma");
    UpdateLabel("pvPivot",EnumToString(signal.Pivot.Source)+" "+EnumToString(signal.Pivot.Type)+" "+
                   ActionText(Pivot(signal.Pivot.Source,signal.Pivot.Type).Lead),
                   Color(Direction(Pivot(signal.Pivot.Source,signal.Pivot.Type).Bias),InAction),9,"Tahoma");

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
      UpdateLabel("lbvOC-"+ActionText(role)+"-Strategy",EnumToString(manager[role].Strategy),clrDarkGray);


    UpdateRay("SigLo",-9,signal.Support,-13);
    UpdateRay("SigHi",-9,signal.Resistance,-13);
    UpdateText("SigSupport","Support",signal.Support,-11);
    UpdateText("SigResistance","Resist",signal.Resistance,-11);

    UpdateDirection("SegDir",signal.Segment.Direction,Color(signal.Segment.Direction),12);
    UpdateLabel("SegState",EnumToString(signal.Segment.State),Color(signal.Segment.Direction),9);

    if (inpShowFibo==Yes)
    {
      double price;
       
      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        price = fprice(Fractal().Point[fpBase],Fractal().Point[fpRoot],fibo);
        UpdateRay(objectstr+"lnS_"+EnumToString(fibo),inpPeriods,price,-8,0,Color(Fractal().Direction,IN_DARK_DIR));
        UpdateText(objectstr+"lnT_"+EnumToString(fibo),"",price,-5,Color(Fractal().Direction,IN_DARK_DIR));
      }

      for (FractalPoint point=fpOrigin;IsBetween(point,fpOrigin,fpRecovery);point++)
      {
        UpdateRay(objectstr+"lnS_"+fp[point],inpPeriods,Fractal().Point[point],-8);
        UpdateText(objectstr+"lnT_"+fp[point],"",Fractal().Point[point],-7);

        UpdateLabel("sigpiv-"+(string)point,"");
        UpdateLabel("sigpiv-"+(string)point+":H:","");
        UpdateLabel("sigpiv-"+(string)point+":O:","");
        UpdateLabel("sigpiv-"+(string)point+":L:","");
        UpdateLabel("sigpiv-"+(string)point+":Dir","");

        if (trigger[point].Active)
        {
          UpdateLabel("sigpiv-"+(string)line,center(StringSubstr(EnumToString(point),2),9),clrGoldenrod,9,"Tahoma");
          UpdateLabel("sigpiv-"+(string)line+":H:","H: "+DoubleToStr(trigger[point].Segment.High,Digits),
                         BoolToInt(trigger[point].Segment.Lead==Buyer,clrYellow,clrForestGreen),8,"Noto Sans Mono CJK HK");
          UpdateLabel("sigpiv-"+(string)line+":O:","O: "+DoubleToStr(trigger[point].Segment.Open,Digits),
                         BoolToInt(trigger[point].Segment.Bias==Buyer,clrLawnGreen,clrRed),8,"Noto Sans Mono CJK HK");
          UpdateLabel("sigpiv-"+(string)line+":L:","L: "+DoubleToStr(trigger[point].Segment.Low,Digits),
                         BoolToInt(trigger[point].Segment.Lead==Buyer,clrFireBrick,clrYellow),8,"Noto Sans Mono CJK HK");
          UpdateDirection("sigpiv-"+(string)line+":Dir",trigger[point].Segment.Direction,Color(trigger[point].Segment.Direction),18);
          line++;
        }
      }
    }
  }

//+------------------------------------------------------------------+
//| Alert - Returns the max Alert for supplied Event                 |
//+------------------------------------------------------------------+
AlertType Alert(EventType Event)
  {
    return fmax(s[Daily].Alert(Event),t.Alert(Event));
  }

//+------------------------------------------------------------------+
//| Pivot - Returns the active Pivot record                          |
//+------------------------------------------------------------------+
PivotRec Pivot(SourceType Source, FractalType Type)
  {
    if (Source==TickMA)
      return t.Pivot(Type);

    return s[Daily].Pivot(Type);
  }


//+------------------------------------------------------------------+
//| Pivot - Returns the active Pivot record                          |
//+------------------------------------------------------------------+
PivotRec Pivot(void)
  {
    if (signal.Fractal.Source==TickMA)
      return t.Pivot(signal.Fractal.Type);

    return s[Daily].Pivot(signal.Fractal.Type);
  }

//+------------------------------------------------------------------+
//| Fractal - Returns the active Fractal record                      |
//+------------------------------------------------------------------+
FractalRec Fractal(void)
  {
    if (signal.Fractal.Source==TickMA)
      return t[signal.Fractal.Type];

    return s[Daily][signal.Fractal.Type];
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Fractal data from Supplied Fractal        |
//+------------------------------------------------------------------+
void UpdateSignal(SourceType Source, CFractal &Signal)
  {
    if (Signal.ActiveEvent())
    {
      signal.Event                       = BoolToEvent(IsBetween(signal.Event,NewFractal,NewLead),signal.Event,Exception);

      if (Signal.Event(NewFractal))
      {
        signal.Fractal.Source            = Source;
        signal.Fractal.Type              = (FractalType)BoolToInt(Signal.Event(NewFractal,Critical),Origin,
                                                        BoolToInt(Signal.Event(NewFractal,Major),Trend,Term));
        signal.Event                     = NewFractal;
        signal.Checkpoint                = true;
      }
      else
      if (Signal.Event(NewFibonacci))
      {
        signal.Pivot.Source              = Source;
        signal.Pivot.Type                = (FractalType)BoolToInt(Signal.Event(NewFibonacci,Critical),Origin,
                                                        BoolToInt(Signal.Event(NewFibonacci,Major),Trend,Term));
        signal.Event                     = NewFibonacci;
        signal.Checkpoint                = true;
      }
      else
      if (Signal.Event(NewLead))
      {
        signal.Event                    = NewLead;
        signal.Checkpoint               = true;
      }
      else
      if (signal.Event==Exception)
        if (Signal.Event(NewBoundary))
          if (Signal.Event(NewDirection))           signal.Event = NewDirection;
          else
          if (IsEqual(Signal.MaxAlert(),Notify))    signal.Event = NewTick;
          else
          if (IsEqual(Signal.MaxAlert(),Nominal))   signal.Event = NewSegment;
          else
          if (Signal.Event(CrossCheck))             signal.Event = CrossCheck;
          else
          if (Signal.Event(NewBias))                signal.Event = NewBias;
          else
          if (Signal.Event(NewExpansion))           signal.Event = NewExpansion;
          else                                      signal.Event = NewBoundary;
        else
          if (Signal.Event(CrossCheck))             signal.Event = CrossCheck;
          else
          if (Signal.Event(NewBias))                signal.Event = NewBias;
          else
          if (Signal.Event(SessionClose))           signal.Event = SessionClose;
          else
          if (Signal.Event(SessionOpen))            signal.Event = SessionOpen;
          else
          if (Signal.Event(NewDay))                 signal.Event = NewDay;
          else
          if (Signal.Event(NewHour))                signal.Event = NewHour;
    }

    for (FractalType fractal=Origin;IsBetween(fractal,Origin,Term);fractal++)
    {
      signal.HedgeCount                += BoolToInt(Signal[fractal].Pivot.Hedge,1);

      manager[Action(Direction(Signal[fractal].Direction,InDirection,Signal[fractal].State==Correction))].Strength++;
      manager[Action(Direction(Signal[fractal].Pivot.Lead,InAction,Signal[fractal].Pivot.Hedge))].Strength++;
    }
  }


//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal Price Arrays                       |
//+------------------------------------------------------------------+
void UpdateSignal(void)
  {
    SignalBar         sighi        = {0,0.00};
    SignalBar         siglo        = {0,0.00};
    SegmentState      state        = signal.Segment.State;
    
    signal.Tick                    = fTick;
    signal.Price                   = Close[0];
    signal.BoundaryAlert           = fmax(s[Daily].Alert(NewBoundary),t.Alert(NewBoundary));
    signal.Strength                = fdiv(fmax(manager[Buyer].Strength,manager[Seller].Strength),
                                          manager[Buyer].Strength+manager[Seller].Strength,3)*
                                          Direction(manager[Buyer].Strength-manager[Seller].Strength);

    signal.Segment.High             = fmax(signal.Price,signal.Segment.High);
    signal.Segment.Low              = fmin(signal.Price,signal.Segment.Low);

    if (ArraySize(sigHistory)>0)
      signal.Segment.Bias           = (RoleType)Action(signal.Price-sigHistory[0],InDirection);

    if (signal.BoundaryAlert>Notify)
    {
      ArrayCopy(sigHistory,sigHistory,1,0,inpSigRetain-1);
      sigHistory[0]                = signal.Price;

      //-- Calc History hi/lo
      sighi.Price                  = signal.Price;
      siglo.Price                  = signal.Price;

      for (int bar=0;bar<ArraySize(sigHistory);bar++)
        if (IsEqual(sigHistory[bar],0.00))
          break;
        else
        {
          if (IsHigher(sigHistory[bar],sighi.Price)) sighi.Bar=bar;
          if (IsLower(sigHistory[bar],siglo.Price))  siglo.Bar=bar;
        }

      //-- Make boundary corrections
      if (sigFP[fpRoot].Price>sighi.Price) sigFP[fpRoot]=sighi;
      if (sigFP[fpRoot].Price<siglo.Price) sigFP[fpRoot]=siglo;
      if (sigFP[fpBase].Price>sighi.Price) sigFP[fpBase]=sighi;
      if (sigFP[fpBase].Price<siglo.Price) sigFP[fpBase]=siglo;

      if (!IsBetween(sigFP[fpRetrace].Price,sighi.Price,siglo.Price)||sigFP[fpRetrace].Price==sigFP[fpRoot].Price)
      {
        sigFP[fpRetrace].Bar    = NoValue;
        sigFP[fpRetrace].Price  = 0.00;
      }
      
      //-- Update Fractal Point Bars
      for (int point=0;point<FractalPoints;point++)
        if (sigFP[point].Bar>NoValue)
          sigFP[point].Bar++;

      //-- Handle Interior Alerts
      if (IsBetween(signal.Price,sigFP[fpExpansion].Price,sigFP[fpRoot].Price))
      {
        signal.State                         = (FractalState)BoolToInt(signal.Segment.Bias==Buyer,Rally,Pullback);

        //-- Handle Recoveries
        if (IsEqual(signal.Segment.Direction,Direction(signal.Segment.Bias,InAction)))
        {
          if (sigFP[fpRecovery].Bar>NoValue)
          {
             if (signal.Segment.Direction==DirectionUp)
             {
               if (IsHigher(signal.Price,sigFP[fpRecovery].Price))
               {
                 signal.Segment.Lead         = Buyer;
                 signal.State                = Recovery;

                 sigFP[fpRecovery].Bar       = 0;
               }
             }
             else
 
             if (signal.Segment.Direction==DirectionDown)
             {
               if (IsLower(signal.Price,sigFP[fpRecovery].Price))
               {
                 signal.Segment.Lead         = Seller;
                 signal.State                = Recovery;

                 sigFP[fpRecovery].Bar       = 0;
               }
             }
           }
           else

           //-- New Recoveries
           {
             signal.Segment.Lead             = signal.Segment.Bias;
             signal.State                    = Recovery;

             sigFP[fpRecovery].Bar           = 0;
             sigFP[fpRecovery].Price         = signal.Price;
             
             if (sigFP[fpRetrace].Bar>sigFP[fpExpansion].Bar)
             {
               sigFP[fpRetrace].Bar          = 1;
               sigFP[fpRetrace].Price        = sigHistory[1];
             } 
           }
        }
        else
      
        //-- Handle Retraces
        {
          signal.State                       = (FractalState)BoolToInt(signal.Segment.Lead==Buyer,Rally,Pullback);

          if (IsEqual(sigFP[fpRetrace].Bar,NoValue))
          {
            sigFP[fpRetrace].Bar             = 0;
            sigFP[fpRetrace].Price           = signal.Price;
          }

          if (signal.Segment.Direction==DirectionUp)
            if (IsLower(signal.Price,sigFP[fpRetrace].Price))
            {
              signal.Segment.Lead            = Seller;
              signal.State                   = Retrace;
              sigFP[fpRetrace].Bar           = 0;
            }
          
          if (signal.Segment.Direction==DirectionDown)
            if (IsHigher(signal.Price,sigFP[fpRetrace].Price))
            {
              signal.Segment.Lead            = Buyer;
              signal.State                   = Retrace;
              sigFP[fpRetrace].Bar           = 0;
            }
        }
      }
      else

      //-- Handle Expansions
      {
        signal.Segment.Lead                  = signal.Segment.Bias;
        signal.State                         = (FractalState)BoolToInt(signal.State==Reversal,Reversal,Breakout);
        
        //-- Handle Reversals
        if (DirectionChanged(signal.Segment.Direction,BoolToInt(signal.Price>sigFP[fpBase].Price,DirectionUp,DirectionDown)))
        {
          signal.State                       = Reversal;
          signal.Checkpoint                  = true;

          sigFP[fpRetrace]                   = sigFP[fpRecovery];
          sigFP[fpBase]                      = sigFP[fpRoot];
          sigFP[fpRoot]                      = sigFP[fpExpansion];

          //-- Active Range
          switch (signal.Segment.Direction)
          {
            case DirectionUp:
                      signal.Segment.State   = (SegmentState)BoolToInt(signal.Price>signal.Resistance,HigherHigh,LowerHigh);
                      signal.Support         = signal.Segment.Low;
                      break;

            case DirectionDown:
                      signal.Segment.State   = (SegmentState)BoolToInt(signal.Price<signal.Support,LowerLow,HigherLow);
                      signal.Resistance      = signal.Segment.High;
                      break;
          }

          signal.Segment.Close               = signal.Price;

          PrintSigPiv(signal.Segment,debug);
          
          signal.Segment.Open                = signal.Price;
          signal.Segment.High                = signal.Price;
          signal.Segment.Low                 = signal.Price;
          signal.Segment.Close               = NoValue;
        }
  
        sigFP[fpRecovery].Bar                = NoValue;
        sigFP[fpRecovery].Price              = 0.00;
        sigFP[fpExpansion].Bar               = 0;
        sigFP[fpExpansion].Price             = signal.Price;

        if (!IsBetween(sigFP[fpRetrace].Price,sigFP[fpRoot].Price,sigFP[fpExpansion].Price))
        {
          sigFP[fpRetrace].Bar               = NoValue;
          sigFP[fpRetrace].Price             = 0.00;
        }
      }
    }

    if (signal.Price>signal.Resistance)
      signal.Segment.State                    = HigherHigh;

    if (signal.Price<signal.Support)
      signal.Segment.State                    = LowerLow;
    
    if (IsChanged(state,signal.Segment.State))
    {
      if (IsBetween(signal.Segment.State,HigherHigh,LowerLow))
        if (DirectionChanged(signal.Direction,signal.Segment.Direction))
          ArrayResize(sigFibonacci,0,24);
        
      Flag("segstate:"+(string)fTick+"-"+EnumToString(state),BoolToInt(signal.Segment.State>LowerLow,
        Color(signal.Segment.Direction,IN_DARK_DIR),
        Color(signal.Segment.Direction,IN_CHART_DIR)));

//      Pause("Tick "+(string)fTick+": "+EnumToString(signal.Segment.State),"Segment State Change");
    }

    if (signal.Event==NewFibonacci)
    {
      ArrayResize(sigFibonacci,ArraySize(sigFibonacci)+1,24);
      sigFibonacci[ArraySize(sigFibonacci)-1]    =  Pivot(signal.Pivot.Source,signal.Pivot.Type).Price;
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrigger - Updates trigger detail by proximity to FP        |
//+------------------------------------------------------------------+
void UpdateTrigger(void)
  {
    static double close;

    if (ArraySize(sigHistory)>0)
      for (FractalPoint point=fpOrigin;point<FractalPoints;point++)
        if (sigHistory[0]==sigFP[point].Price)
        {
          if (IsChanged(trigger[point].Active,true))
          {
            trigger[point].Segment.Direction    = signal.Segment.Direction;
            trigger[point].Segment.Lead         = (RoleType)Action(signal.Segment.Direction,InDirection);
            trigger[point].Segment.Bias         = trigger[point].Segment.Lead;

            trigger[point].Segment.Open         = Close[0];
            trigger[point].Segment.High         = Close[0];
            trigger[point].Segment.Low          = Close[0];

            trigger[point].Tick                 = fTick;
          }

          if (IsHigher(Close[0],trigger[point].Segment.High))
            trigger[point].Segment.Lead         = Buyer;
            
          if (IsLower(Close[0],trigger[point].Segment.Low))
            trigger[point].Segment.Lead         = Seller;

          RoleChanged(trigger[point].Segment.Bias,Close[0]-trigger[point].Segment.Open,InDirection);
        }
        else
        {
          trigger[point].Segment.Close          = close;

          if (trigger[point].Tick>NoValue)
            if (IsChanged(trigger[point].Active,false))
              PrintSigPiv(trigger[point].Segment,trigger[point].Tick,EnumToString(point),debug);
        }

    close = Close[0];
  }

//+------------------------------------------------------------------+
//| PrintSigPiv - Prints signal pivot data to the log                |
//+------------------------------------------------------------------+
void PrintSigPiv(SignalSegment &Segment, long Tick, string Text="", bool Flag=false)
  {
    if (Flag)
    {
      double min  = 99999;
      double max  = 0.00;

      string text   ="|sigpiv";
      string ftext  = "";

      Append(text,(string)Tick,"|");
      Append(text,Text,"|");
      Append(text,DoubleToStr(Segment.Open,Digits),"|");
      Append(text,DoubleToStr(Segment.High,Digits),"|");
      Append(text,DoubleToStr(Segment.Low,Digits),"|");
      Append(text,DoubleToStr(Segment.Close,Digits),"|");
      Append(text,DoubleToStr(signal.Resistance,Digits),"|");
      Append(text,DoubleToStr(signal.Support,Digits),"|");

      for (int fibo=0;fibo<ArraySize(sigFibonacci);fibo++)
      {
        min  = fmin(min,sigFibonacci[fibo]);
        max  = fmax(max,sigFibonacci[fibo]);
        Append(ftext,DoubleToStr(sigFibonacci[fibo],Digits),"|");
      }
      if (min<99999)
      {
        Append(text,DoubleToStr(min,Digits),"|");
        Append(text,DoubleToStr(max,Digits),"|");
        Append(text,ftext,"|");
      }
    
      Print(text);
    }
  }

//+------------------------------------------------------------------+
//| UpdateManager - Updates Manager data from Supplied Fractal       |
//+------------------------------------------------------------------+
void UpdateManager(void)
  {
    static int direction          = DirectionPending;

    //-- Reset Manager Targets
    if (ManagerChanged())
      if (master.Lead>Unassigned)
        ArrayInitialize(manager[master.Lead].Equity,order[master.Lead].Equity);

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      manager[role].DCA           = order.DCA(role);
      manager[role].Entry         = order.Entry(role);
      manager[role].Equity[Now]   = order[role].Equity;
      manager[role].Equity[Min]   = fmin(order[role].Equity,manager[role].Equity[Min]);
      manager[role].Equity[Max]   = fmax(order[role].Equity,manager[role].Equity[Max]);
    }

    if (DirectionChanged(direction,BoolToInt(manager[Buyer].Strength==0,DirectionDown,
                                   BoolToInt(manager[Seller].Strength==0,DirectionUp,direction))))
      Flag("ManagerDirection",clrYellow,0,0,debug);
  }
  

//+------------------------------------------------------------------+
//| UpdateMaster - Updates Master/Manager data                       |
//+------------------------------------------------------------------+
void UpdateMaster(void)
  {
    //-- Update Classes
//    order.Update(BoolToDouble(inpBaseCurrency=="XRPUSD",iClose(inpBaseCurrency,0,0),1));
    order.Update();

    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();

    t.Update();

    //-- Signal Set Up
    signal.Alert              = fmax(s[Daily].MaxAlert(),t.MaxAlert());
    signal.Event              = NoEvent;
    signal.ActiveEvent        = s[Daily].ActiveEvent()||t.ActiveEvent();
    signal.Checkpoint         = false;
    signal.HedgeCount         = 0;
    
    //-- Manager Set Up
    manager[Buyer].Strength   = 0;
    manager[Seller].Strength  = 0;

    UpdateSignal(Session,s[Daily]);
    UpdateSignal(TickMA,t);
    UpdateSignal();
    UpdateTrigger();
    UpdateManager();

    if (signal.Checkpoint)
      if (signal.Event==NewFractal)
        Flag("["+(string)fTick+"]ckpt-"+EnumToString(signal.Event)+":"+EnumToString(signal.Fractal.Source)+":"+EnumToString(signal.Fractal.Type),clrMagenta,0,0,debug);
      else
      if (signal.Event==NewFibonacci)
        Flag("["+(string)fTick+"]ckpt-"+EnumToString(signal.Pivot.Source)+" "+EnumToString(signal.Pivot.Type)+":"+
          EnumToString(Pivot(signal.Pivot.Source,signal.Pivot.Type).Level),Color(signal.Pivot.Type),0,0,debug);
      //else
      //if (signal.Event==NewLead)
      //  Arrow("["+(string)fTick+"]ckpt-"+EnumToString(signal.Event),ArrowDash,Color(t.Segment().Direction[Lead],IN_CHART_DIR));

    DebugPrint();
  }

//+------------------------------------------------------------------+
//| ManagerChanged - Returns true on change in Operations Manager    |
//+------------------------------------------------------------------+
bool ManagerChanged(void)
  {
    RoleType incoming     = (RoleType)BoolToInt(IsEqual(Fractal().State,Correction),
                                        Action(Fractal().Direction,InDirection,InContrarian),
                                        Action(Fractal().Direction));
    RoleType incumbent    = (RoleType)BoolToInt(IsEqual(master.Lead,Unassigned),Action(incoming,InAction,InContrarian),master.Lead);
    
    if (IsEqual(incoming,incumbent))
      return false;

    master.OnCall         = incumbent;
    master.Lead           = incoming;

    return true;
  }

//+------------------------------------------------------------------+
//| StrategyChanged - Returns true on change in Strategy             |
//+------------------------------------------------------------------+
bool StrategyChanged(RoleType Role, SegmentState State)
  {
    static SegmentState state     = NoValue;
    
    if (IsBetween(Role,Buyer,Seller))
      if (!IsEqual(state,State))
      {
        StrategyType strategy    = Strategy(Role,State);

        if (IsEqual(manager[Role].Strategy,strategy))
          return false;

        manager[Role].Strategy   = strategy;
        return true;
      }

    return false;
  }

//+------------------------------------------------------------------+
//| Strategy - Returns Strategy for supplied Role/Event              |
//+------------------------------------------------------------------+
StrategyType Strategy(RoleType Role, SegmentState State)
  {
    if (IsEqual(order[Role].Lots,0.00))
      if (Role==master.Lead)
        switch (Role)
        {
          case Buyer:     return (StrategyType)BoolToInt(State==HigherLow,Build,
                                               BoolToInt(State==LowerLow,Spot));
          case Seller:    return (StrategyType)BoolToInt(State==LowerHigh,Build,
                                               BoolToInt(State==HigherHigh,Spot));
          default:        return Wait;
        }
      else
      if (Role==master.OnCall)
        switch (Role)
        {
          case Buyer:     return (StrategyType)BoolToInt(State==HigherLow,Spot,
                                               BoolToInt(State==LowerLow&&order[master.Lead].Lots>0.00,Capture));
          case Seller:    return (StrategyType)BoolToInt(State==LowerHigh,Spot,
                                               BoolToInt(State==HigherHigh&&order[master.Lead].Lots>0.00,Capture));
          default:        return Wait;
        }
      else                return Wait;
    else
    if (Role==master.Lead)
      switch (Role)
      {
        case Buyer:       return (StrategyType)BoolToInt(State==HigherHigh,Manage,
                                               BoolToInt(State==LowerLow,Mitigate,
                                               BoolToInt(State==LowerHigh,Protect,
                                               BoolToInt(State==HigherLow,Build))));
        case Seller:      return (StrategyType)BoolToInt(State==HigherHigh,Mitigate,
                                               BoolToInt(State==LowerLow,Manage,
                                               BoolToInt(State==LowerHigh,Build,
                                               BoolToInt(State==HigherLow,Protect))));
        default:          return Wait;
      }
    else
    if (Role==master.OnCall)
    {
      int basis      = Direction(order[Net].Lots);

      switch (Role)
      {
        case Buyer:       return (StrategyType)BoolToInt(State==HigherHigh,(BoolToInt(basis==NetShort,Hedge,Protect)),
                                               BoolToInt(State==LowerLow,Mitigate,
                                               BoolToInt(State==LowerHigh,(BoolToInt(basis==NetShort,Wait,Protect)),
                                               BoolToInt(State==HigherLow,(BoolToInt(basis==NetZero,Spot,
                                               BoolToInt(basis==NetShort,Capture)))))));
        case Seller:      return (StrategyType)BoolToInt(State==LowerLow,(BoolToInt(basis==NetLong,Hedge,Protect)),
                                               BoolToInt(State==HigherHigh,Mitigate,
                                               BoolToInt(State==HigherLow,(BoolToInt(basis==NetLong,Wait,Protect)),
                                               BoolToInt(State==LowerHigh,(BoolToInt(basis==NetZero,Spot,
                                               BoolToInt(basis==NetLong,Capture)))))));
        default:          return Wait;
      }
    }

    return Wait;
  }

//+------------------------------------------------------------------+
//| ManageFund - Fund Manager order processor                        |
//+------------------------------------------------------------------+
void ManageFund(void)
  {
    //-- Position checks
    StrategyChanged(master.Lead,signal.Segment.State);
    
    //-- Free Zone/Order Entry
//    if (order.Free(Role)>order.Split(Role)||IsEqual(order.Entry(Role).Count,0))
//    {
//      OrderRequest  request  = order.BlankRequest(EnumToString(Role));
//
//      request.Action         = Role;
//      request.Requestor      = "Auto ("+request.Requestor+")";
//
//      switch (Role)
//      {
//        case Buyer:          if (t[NewTick])
//                               manager[Role].Trigger  = false;
//                             break;
//
//        case Seller:         if (t[NewTick])
//                               manager[Role].Trigger  = false;
//                               
//                             switch (manager[Role].Strategy)
//                             {
//                               case Build:   if (t.Event(NewHigh,Nominal))
//                                             {
//                                               request.Type    = OP_SELL;
//                                               request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
//                                               request.Memo    = "Contrarian (In-Trend)";
//                                             }
//                                             break;
//
//                               //case Manage:  if (t[NewLow])
//                               //              {
//                               //                request.Type    = OP_SELL;
//                               //                request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
//                               //                request.Memo    = "Contrarian (In-Trend)";
//                               //              }
//                               //              break;
//                             }
//                             break;
//      }
//
//      if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
//        if (order.Submitted(request))
//          Print(order.RequestStr(request));
//    }

    order.ProcessOrders(master.Lead);

    ManageRisk(master.OnCall);
  }


//+------------------------------------------------------------------+
//| ExecuteSpot - Spots are contrarian, pre-build order placement    |
//+------------------------------------------------------------------+
void ExecuteSpot(RoleType Role)
  {
    OrderRequest request   = order.BlankRequest("Spot/"+EnumToString(Role));
    
    int    direction       = Direction(Role,InAction);
    double price           = ParseEntryPrice(Role,BoolToStr(Role==Buyer,"-")+DoubleToStr(order.Config(Role).ZoneSize,1)+"P");
    
    if (order.Free(Role,price)>order.Split(Role))
      //-- Handle Convergences
//      if (Fractal(Term).Direction==direction)
      {
        if (t.Segment().Bias==Role)
          {
            request.Type    = ActionCode(EnumToString(Role),price);
            request.Action  = Role;
            request.Lots    = order.Free(Role);
            request.Price   = price;
            request.Memo    = "[mv2] Auto Spot ("+(string)fTick+")";
            
            if (order.Submitted(request))
            {
              Print(order.RequestStr(request));
              order.SetSlider(request.Type,0.00002);
            }
            else
              Print("Order Not Submitted! \n\n"+order.RequestStr(request));
          }
      }
      else
      
      //-- Handle Divergences
      {
      }
  }

//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(RoleType Role)
  {
//    static double op,cl,hi,lo;
//    static bool   spot     = false;
//
    bool   changed = StrategyChanged(Role,signal.Segment.State);
    
//    if (changed) Pause("Strategy change for the risk manager to "+EnumToString(manager[Role].Strategy),"Risk Manager");
              
    switch (manager[Role].Strategy)
    {
      case Spot: 
//                 if (changed)
//                 {
//                   hi = Close[0];
//                   lo = Close[0];
//                   op = Close[0];
//                   
//                   spot = true;
//
//                   Flag("spot",Color(Direction(Role,InAction)));
//                 }
//
//                 hi = fmax(hi,Close[0]);
//                 lo = fmin(lo,Close[0]);
//
//                 UpdateLine("SpotHi",hi,STYLE_DOT,clrLawnGreen);
//                 UpdateLine("SpotLo",lo,STYLE_DOT,clrRed);
//                 ExecuteSpot(Role);
                 break;

//      default:   if (IsChanged(spot,false))
//                 {
//                   cl = Close[0];
//
//                   Flag("spothi",clrForestGreen,0,hi);
//                   Flag("spotlo",clrMaroon,0,lo);
//
//                   Print("|Spot|"+DoubleToStr(op,Digits)+"|"+DoubleToStr(hi,Digits)+"|"+DoubleToStr(lo,Digits)+"|"+DoubleToStr(cl,Digits));
//
//                   UpdateLine("SpotHi",0,STYLE_DOT,clrLawnGreen);
//                   UpdateLine("SpotLo",0,STYLE_DOT,clrRed);
//                 }
    };
    
    order.ProcessOrders(Role);
  }


//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Handle Active Management
   if (IsBetween(master.Lead,Buyer,Seller))
     ManageFund();
   else

   //-- Handle Unassigned Manager
   {
     ManageRisk(Buyer);
     ManageRisk(Seller);
   }

    order.ProcessRequests();
  }


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  { 
    ProcessComFile();

    UpdateMaster();
    WriteSignal();

    Execute();

    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| ScreenConfig Sets up display alternative in-lieu of CPanel       |
//+------------------------------------------------------------------+
void ScreenConfig(void)
  {
    NewLabel("pvBalance","",80,10,clrLightGray,SCREEN_UR);
    NewLabel("pvProfitLoss","",80,26,clrLightGray,SCREEN_UR);
    NewLabel("pvNetEquity","",80,42,clrLightGray,SCREEN_UR);
    NewLabel("pvEquity","",10,10,clrLightGray,SCREEN_UR);
    NewLabel("pvMargin","",10,42,clrLightGray,SCREEN_UR);
    NewLabel("pvStratLead","",10,64,clrDarkGray,SCREEN_UR);
    NewLabel("pvStratOnCall","",10,80,clrDarkGray,SCREEN_UR);
    NewLabel("pvSource","",10,96,clrDarkGray,SCREEN_UR);
    NewLabel("pvPivot","",10,112,clrNONE,SCREEN_UR);
    
    NewRay("SigHi",STYLE_SOLID,clrYellow,Never);
    NewRay("SigLo",STYLE_SOLID,clrRed,Never);
    NewText("SigSupport","s");
    NewText("SigResistance","r");
    NewLabel("SegDir","^",10,127,clrDarkGray,SCREEN_UR);
    NewLabel("SegState","xxx",30,128,clrDarkGray,SCREEN_UR);
  }

//+------------------------------------------------------------------+
//| OrderConfig Order class initialization function                  |
//+------------------------------------------------------------------+
void OrderConfig(void)
  {
    order = new COrder(inpBrokerModel);
    order.Enable("System Enabled "+TimeToString(TimeCurrent()));

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      if (order[action].Lots>0)
        order.Disable(action,"Open "+proper(ActionText(action))+" Positions; Preparing execution plan");
      else
        order.Enable(action,"Action Enabled "+TimeToString(TimeCurrent()));

      //-- Order Config
      order.ConfigureFund(action,inpMinTarget,inpMinProfit);
      order.ConfigureRisk(action,inpMaxRisk,inpMaxMargin,inpLotScale,inpLotSize);
      order.ConfigureZone(action,inpZoneStep,inpMaxZoneMargin);

      order.SetDefaultStop(action,0.00,inpDefaultStop,false);
      order.SetDefaultTarget(action,0.00,inpDefaultTarget,false);
    }
  }

//+------------------------------------------------------------------+
//| IndicatorConfig - Class initialization/construction function     |
//+------------------------------------------------------------------+
void IndicatorConfig(void)
  {
    //-- Initialize TickMA
    t                    = new CTickMA(inpPeriods,inpAgg,NoValue);

    //-- Initialize Session
    s[Daily]             = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]              = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]            = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]                = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
  }

//+------------------------------------------------------------------+
//| SignalConfig Signal setup and config function                    |
//+------------------------------------------------------------------+
void SignalConfig(void)
  {
    SignalSegment segInit      = {NoDirection,NoValue,NoAction,NoAction,NoValue,NoValue,NoValue,NoValue};

    for(FractalPoint point=0;point<FractalPoints;point++)
    {
      trigger[point].Active    = false;
      trigger[point].Tick      = NoValue;
      trigger[point].Segment   = segInit;

      sigFP[point].Bar         = BoolToInt(IsBetween(point,fpBase,fpExpansion),0,NoValue);
      sigFP[point].Price       = BoolToDouble(IsBetween(point,fpBase,fpExpansion),Close[0]);
    }

    signal.Tick                = NoValue;
    signal.Direction           = Fractal().Direction;
    signal.State               = Breakout;
    signal.Price               = Close[0];
    signal.Support             = NoValue;
    signal.Resistance          = NoValue;
    signal.Segment             = segInit;

    //-- Set Operational Fractal
    double retrace             = 0.00;
    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
    {
      if (IsHigher(s[Daily][type].Retrace.Percent[Max],retrace,3))
      {
        signal.Fractal.Type    = type;
        signal.Fractal.Source  = Session;
      }

      if (IsHigher(t[type].Retrace.Percent[Max],retrace,3))
      {
        signal.Fractal.Type    = type;
        signal.Fractal.Source  = TickMA;
      }
    }
  }

//+------------------------------------------------------------------+
//| InitMaster - Sets the startup values on the Manager Master       |
//+------------------------------------------------------------------+
void InitMaster(void)
  {
    master.Lead                = Unassigned;
    master.OnCall              = Unassigned;
    master.HedgeLotSize        = 0.00;
    
    manager[Buyer].Strategy    = Wait;
    manager[Seller].Strategy   = Wait;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ScreenConfig();
    OrderConfig();
    IndicatorConfig();
    SignalConfig();
    ManualConfig(inpComFile,inpLogFile);

    InitMaster();

    //-- Fibonacci Display Option
    if (inpShowFibo==Yes)
    {
      for (FractalPoint point=fpOrigin;IsBetween(point,fpOrigin,fpRecovery);point++)
      {
        NewRay(objectstr+"lnS_"+fp[point],fpstyle[point],fpcolor[point],Never);
        NewText(objectstr+"lnT_"+fp[point],fp[point]);
      }

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        NewRay(objectstr+"lnS_"+EnumToString(fibo),STYLE_DOT,clrDarkGray,Never);
        NewText(objectstr+"lnT_"+EnumToString(fibo),DoubleToStr(fibonacci[fibo]*100,1)+"%");
      }
    }

    if (debug)
      dHandle = FileOpen("debug-man-v2.psv",FILE_TXT|FILE_WRITE);

    WriteSignal();

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete order;
    delete t;

    for (SessionType type=Daily;type<SessionTypes;type++)
      delete s[type];

    if (debug)
      if (dHandle>INVALID_HANDLE)
      {
        FileFlush(dHandle);
        FileClose(dHandle);
      }

    if (fHandle>INVALID_HANDLE)
      FileClose(fHandle);

    if (logHandle>INVALID_HANDLE)
    {
      FileFlush(logHandle);
      FileClose(logHandle);
    }
  }
