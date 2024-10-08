//+------------------------------------------------------------------+
//|                                                       man-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                         Raw Order-Integration EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "3.01"
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
  input string           inpSigOutFile       = "";            // Signal Output File
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
            Spot
          };


  //--- Data Source Type
  enum    SourceType
          {
            Session,         //-- Session
            TickMA           //-- TickMA
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
          };

  struct SignalTrigger
         {
           int               Direction;
           int               Count;
           double            Price;
         };

  struct SignalPivot
         {
           EventType        Event;
           SignalTrigger    High;
           SignalTrigger    Low;
         };
         
  struct SignalNode
         {
           int              Bar;
           double           Price;
         };

  //-- Signals (Events) requesting Manager Action (Response)
  struct  SignalRec
          {
            long             Tick;              //-- Tick Signaled by Event 
            EventType        Event;             //-- Highest Event
            AlertType        Alert;             //-- Highest Alert Level
            FractalState     State;             //-- State of the Signal
            int              Direction;         //-- Direction Signaled
            RoleType         Lead;              //-- Calculated Signal Lead
            RoleType         Bias;              //-- Calculated Signal Bias
            double           Price;             //-- Event Price
            bool             Checkpoint;        //-- Trigger (Fractal/Fibo/Lead Events)
            SourceType       Source;            //-- Signal Source (Session/TickMA)
            FractalType      Type;              //-- Source Fractal
            FractalState     Momentum;          //-- Triggered Pullback/Rally
            bool             ActiveEvent;       //-- True on Active Event (All Sources)
            SignalPivot      Boundary;          //-- Signal Boundary Events
            SignalPivot      Recovery;          //-- Recovery Events
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
  SignalNode             signalFP[FractalPoints];
  double                 sigHistory[];


  //-- Internal EA Configuration
  string                 indPanelSN          = "CPanel-v"+(string)inpIndSNVersion;
  string                 indSignalSN         = "Signal-v1";
  string                 objectstr           = "[mv3]";
  
  int                    dHandle;


//+------------------------------------------------------------------+
//| WriteSignal- Creates, maintains and writes Signal History        |
//+------------------------------------------------------------------+
void WriteSignal(void)
  {
    int sigHandle = FileOpen(inpSigOutFile,FILE_BIN|FILE_WRITE);

    if (sigHandle>INVALID_HANDLE)
    {
      FileWriteStruct(sigHandle,signal);
      FileWriteArray(sigHandle,signalFP);
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
        Append(ftext,EnumToString(signal.Source),"|");
        Append(ftext,EnumToString(signal.Type),"|");
        Append(ftext,EnumToString(Fractal(signal.Type).State),"|");
        Append(ftext,BoolToStr(IsChanged(fractalDir,Fractal(signal.Type).Direction),DirText(Fractal(signal.Type).Direction),"------"),"|");
        Append(ftext,BoolToStr(signal.Boundary.Event>NoEvent,EnumToString(signal.Boundary.Event),"------"),"|");
        Append(ftext,(string)fTick,"|");
        Append(ftext,DoubleToString(Close[0],_Digits),"|");
        Append(ftext,EnumToString(signal.State),"|");
        Append(ftext,BoolToStr(signal.Checkpoint,"Active","Idle"),"|");
        Append(ftext,BoolToStr(signal.Recovery.Event>NoEvent,BoolToStr(signal.Direction==DirectionUp,"Sell","Buy"),"Idle"),"|");
        Append(ftext,BoolToStr(IsChanged(rangeDir,signal.Direction),DirText(signal.Direction),"------"),"|");
        Append(ftext,BoolToStr(s[Daily].ActiveEvent(),EnumToString(s[Daily].MaxAlert()),"Idle"),"|");
        Append(ftext,BoolToStr(t.ActiveEvent(),EnumToString(t.MaxAlert()),"Idle"),"|");
        Append(ftext,TimeToStr(TimeCurrent()),"|");
        Append(ftext,EnumToString(signal.Alert),"|");
        Append(ftext,BoolToStr(signal.Momentum>NoValue,EnumToString(signal.Momentum),"------"),"|");

        for (EventType type=1;type<EventTypes;type++)
          switch (type)
          {
            case NewSegment: Append(ftext,EnumToString(fmax(s[Daily].Alert(type),t.Alert(type))),"|");
                             Append(ftext,BoolToStr(t.Logged(NewLead,Nominal),"Nominal",
                                         BoolToStr(t.Logged(NewLead,Warning),"Warning","NoAlert")),"|");
                             break;
            case NewChannel: Append(ftext,EnumToString(fmax(s[Daily].Alert(type),t.Alert(type))),"|");
                             Append(ftext,BoolToStr(t.Logged(NewLead,Notify),"Notify","NoAlert"),"|");
                             break;
            case Exception:  Append(ftext,BoolToStr(IsEqual(signal.Event,Exception),"Critical","NoAlert"),"|");
                             break;
            default:         Append(ftext,EnumToString(fmax(s[Daily].Alert(type),t.Alert(type))),"|");
          }

        FileWrite(dHandle,ftext);
        FileFlush(dHandle);
      }
    }
  }

//+------------------------------------------------------------------+
//| StrategyCode - returns strategy code from parsed text            |
//+------------------------------------------------------------------+
StrategyType StrategyCode(string Strategy)
  {
    if (trim(Strategy)=="WAIT")           return (Wait);
    if (trim(Strategy)=="BUILD")          return (Build);
    if (trim(Strategy)=="MANAGE")         return (Manage);
    if (trim(Strategy)=="PROTECT")        return (Protect);
    if (trim(Strategy)=="HEDGE")          return (Hedge);
    if (trim(Strategy)=="CAPTURE")        return (Capture);
    if (trim(Strategy)=="MITIGATE")       return (Mitigate);
    if (trim(Strategy)=="SPOT")           return (Spot);

    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static int     panelWinID   = NoValue;
           int     signalWinID  = ChartWindowFind(0,indSignalSN);

    if (signalWinID>NoValue)
    {
      UpdateLabel("lbvSigSource", EnumToString(signal.Source)+" "+EnumToString(signal.Type)+" "+EnumToString(Fractal(signal.Type).State),
                                  BoolToInt(Fractal(signal.Type).Pivot.Lead==Buyer,clrLawnGreen,clrRed),12,"Noto Sans Mono CJK HK");
      UpdateLabel("lbvSigFibo",   BoolToStr(IsBetween(Fractal(signal.Type).State,Rally,Correction),
                                    "Retrace x"+DoubleToStr(Fractal(signal.Type).Retrace.Percent[Max]*100,1)+"% "+
                                            "n"+DoubleToStr(Fractal(signal.Type).Retrace.Percent[Now]*100,1)+"%",
                                    "Extends x"+DoubleToStr(Fractal(signal.Type).Extension.Percent[Max]*100,1)+"% "+
                                            "n"+DoubleToStr(Fractal(signal.Type).Extension.Percent[Now]*100,1)+"%"),
                                  BoolToInt(Fractal(signal.Type).Pivot.Bias==Buyer,clrLawnGreen,clrRed),12,"Noto Sans Mono CJK HK");
    }

    if (signal.Recovery.Event>NoEvent)
    {
      switch (signal.Direction)
      {
        case DirectionUp:    UpdateLabel("lbvOC-BUY-Hold",CharToStr(176),clrYellow,11,"Wingdings");

                             if (debug)
                             if (IsBetween(signal.Recovery.Event,NewLow,NewHigh))
                               if (signal.Recovery.Event==NewHigh)
                                 Arrow("RecoPullback"+(string)fTick+":"+(string)signal.Recovery.High.Count,ArrowCheck,
                                   BoolToInt(signal.Recovery.Event==NewHigh,clrLawnGreen,clrYellow));
                             break;

        case DirectionDown:  UpdateLabel("lbvOC-SELL-Hold",CharToStr(176),clrYellow,11,"Wingdings");
                             
                             if (debug)
                             if (IsBetween(signal.Recovery.Event,NewLow,NewHigh))
                               if (signal.Recovery.Event==NewLow)
                                 Arrow("RecoPullback"+(string)fTick+":"+(string)signal.Recovery.Low.Count,ArrowStop,
                                   BoolToInt(signal.Recovery.Event==NewHigh,clrMagenta,clrRed));
                             break;
      }
    }
    else
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

    }

    if (IsEqual(panelWinID,NoValue))
    {
      UpdateLabel("pvBalance","$"+dollar(order.Metrics().Balance,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvProfitLoss","$"+dollar(order.Metrics().Equity,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvNetEquity","$"+dollar(order.Metrics().EquityBalance,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvEquity",DoubleToStr(order.Metrics().EquityClosed*100,1)+"%",Color(order[Net].Value),12,"Consolas");
      UpdateLabel("pvMargin",DoubleToString(order.Metrics().Margin*100,1)+"%",Color(order[Net].Lots),12,"Consolas");
      UpdateLabel("pvStratLead",EnumToString(master.Lead)+": "+EnumToString(manager[master.Lead].Strategy),clrGoldenrod,9,"Tahoma");
      UpdateLabel("pvStratOnCall",EnumToString(master.OnCall)+": "+EnumToString(manager[master.OnCall].Strategy),clrDarkGray,9,"Tahoma");

      Comment(order.QueueStr()+order.OrderStr());
    }

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
      UpdateLabel("lbvOC-"+ActionText(role)+"-Strategy",EnumToString(manager[role].Strategy),clrDarkGray);

    if (inpShowFibo==Yes)
    {
      double price;
       
      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        price = fprice(Fractal(signal.Type).Point[fpBase],Fractal(signal.Type).Point[fpRoot],fibo);
        UpdateRay(objectstr+"lnS_"+EnumToString(fibo),inpPeriods,price,-8,0,Color(Fractal(signal.Type).Direction,IN_DARK_DIR));
        UpdateText(objectstr+"lnT_"+EnumToString(fibo),"",price,-5,Color(Fractal(signal.Type).Direction,IN_DARK_DIR));
      }

      for (FractalPoint point=fpOrigin;IsBetween(point,fpOrigin,fpRecovery);point++)
      {
        UpdateRay(objectstr+"lnS_"+fp[point],inpPeriods,Fractal(signal.Type).Point[point],-8);
        UpdateText(objectstr+"lnT_"+fp[point],"",Fractal(signal.Type).Point[point],-7);
      }
    }
  }

//+------------------------------------------------------------------+
//| Pivot - Returns the active Pivot record                          |
//+------------------------------------------------------------------+
PivotRec Pivot(void)
  {
    if (signal.Source==TickMA)
      return t.Pivot(signal.Type);

    return s[Daily].Pivot(signal.Type);
  }

//+------------------------------------------------------------------+
//| Fractal - Returns the active Fractal record                      |
//+------------------------------------------------------------------+
FractalRec Fractal(FractalType Type)
  {
    if (signal.Source==TickMA)
      return t[Type];

    return s[Daily][Type];
  }

//+------------------------------------------------------------------+
//| ManagerChanged - Returns true on change in Operations Manager    |
//+------------------------------------------------------------------+
bool ManagerChanged(void)
  {
    RoleType incoming     = (RoleType)BoolToInt(IsEqual(Fractal(signal.Type).State,Correction),
                                        Action(Fractal(signal.Type).Direction,InDirection,InContrarian),
                                        Action(Fractal(signal.Type).Direction));
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
bool StrategyChanged(RoleType Role, EventType Event)
  {
    if (IsBetween(Role,Buyer,Seller))
      if (Event>NoEvent)
      {
        StrategyType strategy    = Strategy(Role,Event);

        if (IsEqual(manager[Role].Strategy,strategy))
          return false;

        manager[Role].Strategy   = strategy;
        return true;
      }

    return false;
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Fractal data from Supplied Fractal        |
//+------------------------------------------------------------------+
void UpdateSignal(SourceType Source, CFractal &Signal)
  {
    if (Signal.ActiveEvent())
    {
      signal.Event            = Exception;

      if (Signal.Event(NewFractal))
      {
        signal.Source         = Source;
        signal.Type           = (FractalType)BoolToInt(Signal.Event(NewFractal,Critical),Origin,
                                             BoolToInt(Signal.Event(NewFractal,Major),Trend,Term));
        signal.Event          = NewFractal;
        signal.Checkpoint     = true;
      }
      else
      if (Signal.Event(NewFibonacci))
      {
        signal.Type           = (FractalType)BoolToInt(Signal.Event(NewFibonacci,Critical),Origin,
                                             BoolToInt(Signal.Event(NewFibonacci,Major),Trend,Term));
        signal.Event          = NewFibonacci;
        signal.Checkpoint     = true;
      }
      else
      if (Signal.Event(NewLead))
      {
        signal.Event          = NewLead;
        signal.Checkpoint     = true;
      }
      else
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
        
      signal.Momentum   = (FractalState)BoolToInt(Signal[NewPullback],Pullback,BoolToInt(Signal[NewRally],Rally,NoValue));
    }
  }


//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal Price Arrays                       |
//+------------------------------------------------------------------+
void UpdateSignal(void)
  {    
    SignalNode        sighi        = {0,0.00};
    SignalNode        siglo        = {0,0.00};

    signal.Recovery.Event          = NoEvent;
    signal.Boundary.Event          = NoEvent;

    if (signal.ActiveEvent&&signal.Tick>0)
    {
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
      if (signalFP[fpRoot].Price>sighi.Price) signalFP[fpRoot]=sighi;
      if (signalFP[fpRoot].Price<siglo.Price) signalFP[fpRoot]=siglo;
      if (signalFP[fpBase].Price>sighi.Price) signalFP[fpBase]=sighi;
      if (signalFP[fpBase].Price<siglo.Price) signalFP[fpBase]=siglo;

      //-- Update FP array bars
      for (int point=0;point<FractalPoints;point++)
        if (signalFP[point].Bar>NoValue)
          signalFP[point].Bar++;

      //-- Handle Interior Alerts
      if (IsBetween(signal.Price,signalFP[fpExpansion].Price,signalFP[fpRoot].Price))
      {
        signal.State                         = (FractalState)BoolToInt(signal.Bias==Buyer,Rally,Pullback);

        //-- Handle Recoveries
        if (IsEqual(signal.Direction,Direction(signal.Bias,InAction)))
        {
          if (signalFP[fpRecovery].Bar>NoValue)
          {
             if (signal.Direction==DirectionUp)
             {
               if (IsHigher(signal.Price,signalFP[fpRecovery].Price))
               {
                 signal.Lead                 = signal.Bias;
                 signal.State                = Recovery;

                 signal.Recovery.Event       = NewRally;
                 signal.Recovery.High.Price  = signal.Price;

                 signalFP[fpRecovery].Bar    = 0;
               }
             }
             else
 
             if (signal.Direction==DirectionDown)
             {
               if (IsLower(signal.Price,signalFP[fpRecovery].Price))
               {
                 signal.Lead                 = signal.Bias;
                 signal.State                = Recovery;

                 signal.Recovery.Event       = NewPullback;
                 signal.Recovery.Low.Price   = signal.Price;
   
                 signalFP[fpRecovery].Bar    = 0;
               }
             }
           }
           else

           //-- New Recoveries
           {
             signal.Lead                     = signal.Bias;
             signal.State                    = Recovery;

             signalFP[fpRecovery].Bar        = 0;
             signalFP[fpRecovery].Price      = signal.Price;
             
             if (signalFP[fpRetrace].Bar>signalFP[fpExpansion].Bar)
             {
               signalFP[fpRetrace].Bar       = 1;
               signalFP[fpRetrace].Price     = sigHistory[0];
             }
 
             if (signal.Direction==DirectionUp)
             {
               signal.Recovery.Event         = BoolToEvent(IsLower(signal.Price,signal.Recovery.High.Price),NewLow,NewHigh);
               signal.Recovery.High.Count    = BoolToInt(IsChanged(signal.Recovery.High.Direction,
                                               BoolToInt(signal.Recovery.Event==NewHigh,DirectionUp,DirectionDown)),1,++signal.Recovery.High.Count);
               signal.Recovery.High.Price    = signal.Price;
             }
 
             if (signal.Direction==DirectionDown)
             {
               signal.Recovery.Event         = BoolToEvent(IsHigher(signal.Price,signal.Recovery.Low.Price),NewHigh,NewLow);
               signal.Recovery.Low.Count     = BoolToInt(IsChanged(signal.Recovery.Low.Direction,
                                               BoolToInt(signal.Recovery.Event==NewLow,DirectionDown,DirectionUp)),1,++signal.Recovery.Low.Count);
               signal.Recovery.Low.Price     = signal.Price;
             }
           }
        }
        else
      
        //-- Handle Retraces
        {
          signal.Lead                        = signal.Bias;
          signal.State                       = (FractalState)BoolToInt(signal.Lead==Buyer,Rally,Pullback);

          if (IsEqual(signalFP[fpRetrace].Bar,NoValue))
          {
            signalFP[fpRetrace].Bar         = 0;
            signalFP[fpRetrace].Price       = signal.Price;
          }

          if (signal.Direction==DirectionUp)
            if (IsLower(signal.Price,signalFP[fpRetrace].Price))
            {
              signal.State                = Retrace;
              signalFP[fpRetrace].Bar     = 0;
            }
          
          if (signal.Direction==DirectionDown)
            if (IsHigher(signal.Price,signalFP[fpRetrace].Price))
            {
              signal.State                = Retrace;
              signalFP[fpRetrace].Bar     = 0;
            }
        }
      }
      else

      //-- Handle Expansions
      {
        signal.State                         = (FractalState)BoolToInt(signal.State==Reversal,Reversal,Breakout);
        signal.Lead                          = signal.Bias;

        if (DirectionChanged(signal.Direction,BoolToInt(signal.Price>signalFP[fpBase].Price,DirectionUp,DirectionDown)))
        {
          signal.State                       = Reversal;
          signal.Checkpoint                  = true;

          signalFP[fpRetrace]                = signalFP[fpRecovery];
          signalFP[fpBase]                   = signalFP[fpRoot];
          signalFP[fpRoot]                   = signalFP[fpExpansion];

          //-- Test Boundaries
          switch (signal.Direction)
          {
            case DirectionUp:
                  signal.Boundary.Event      = BoolToEvent(IsHigher(signal.Price,signal.Boundary.High.Price),NewHigh,NewRally);
                  signal.Boundary.High.Count = BoolToInt(IsChanged(signal.Boundary.High.Direction,
                                               BoolToInt(signal.Boundary.Event==NewHigh,DirectionUp,DirectionDown)),1,++signal.Boundary.High.Count);
                  signal.Boundary.High.Price = signal.Price;
                  Flag("sigHi-"+(string)fTick+":"+(string)signal.Boundary.High.Count,
                     BoolToInt(signal.Boundary.Event==NewHigh,clrLawnGreen,clrForestGreen),0,0,debug);
                  break;

            case DirectionDown:
                  signal.Boundary.Event      = BoolToEvent(IsLower(signal.Price,signal.Boundary.Low.Price),NewLow,NewPullback);
                  signal.Boundary.Low.Count  = BoolToInt(IsChanged(signal.Boundary.Low.Direction,
                                               BoolToInt(signal.Boundary.Event==NewLow,DirectionDown,DirectionUp)),1,++signal.Boundary.Low.Count);
                  signal.Boundary.Low.Price  = signal.Price;
                  Flag("sigLo-"+(string)fTick+":"+(string)signal.Boundary.Low.Count,
                     BoolToInt(signal.Boundary.Event==NewLow,clrRed,clrMaroon),0,0,debug);
          }
        }

        signalFP[fpRecovery].Bar             = NoValue;
        signalFP[fpRecovery].Price           = 0.00;
        signalFP[fpExpansion].Bar            = 0;
        signalFP[fpExpansion].Price          = signal.Price;
        
        if (!IsBetween(signalFP[fpRetrace].Price,signalFP[fpRoot].Price,signalFP[fpExpansion].Price))
        {
          signalFP[fpRetrace].Bar            = NoValue;
          signalFP[fpRetrace].Price          = 0.00;
        }
      }
    }
  }


//+------------------------------------------------------------------+
//| UpdateManager - Updates Manager data from Supplied Fractal       |
//+------------------------------------------------------------------+
void UpdateManager(void)
  {
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
    signal.Event              = fmax(s[Daily].MaxEvent(),t.MaxEvent());
    signal.ActiveEvent        = signal.Event>NoEvent;
    signal.Checkpoint         = false;

    if (signal.ActiveEvent)
    {
      ArrayCopy(sigHistory,sigHistory,1,0,inpSigRetain-1);
      sigHistory[0]            = signal.Price;

      signal.Tick             = fTick;
      signal.Price            = Close[0];
      signal.Bias             = (RoleType)Action(signal.Price-sigHistory[0],InDirection);
    }

    UpdateSignal(Session,s[Daily]);
    UpdateSignal(TickMA,t);
    UpdateSignal();
    UpdateManager();

    DebugPrint();
  }

//+------------------------------------------------------------------+
//| Strategy - Returns Strategy for supplied Role                    |
//+------------------------------------------------------------------+
StrategyType Strategy(RoleType Role, EventType Event)
  {
    if (IsEqual(order[Role].Lots,0.00))
      if (Role==master.Lead)
        switch (Role)
        {
          case Buyer:     return (StrategyType)BoolToInt(Event==NewPullback,Build);
          case Seller:    return (StrategyType)BoolToInt(Event==NewRally,Build);
          default:        return Wait;
        }
      else
      if (Role==master.OnCall)
        switch (Role)
        {
          case Buyer:     return (StrategyType)BoolToInt(Event==NewPullback,Spot);
          case Seller:    return (StrategyType)BoolToInt(Event==NewRally,Spot);
          default:        return Wait;
        }
      else                return Wait;
    else
    if (Role==master.Lead)
      switch (Role)
      {
        case Buyer:       return (StrategyType)BoolToInt(Event==NewHigh,Manage,
                                        BoolToInt(Event==NewLow,Mitigate,
                                        BoolToInt(Event==NewRally,Protect,
                                        BoolToInt(Event==NewLow,Build))));
        case Seller:      return (StrategyType)BoolToInt(Event==NewHigh,Mitigate,
                                        BoolToInt(Event==NewLow,Manage,
                                        BoolToInt(Event==NewRally,Build,
                                        BoolToInt(Event==NewLow,Protect))));
        default:   return Wait;
      }
    else
    if (Role==master.OnCall)
    {
      int basis      = Direction(order[Net].Lots);

      switch (Role)
      {
        case Buyer:       return (StrategyType)BoolToInt(Event==NewHigh,(BoolToInt(basis==NetShort,Hedge,Protect)),
                                        BoolToInt(Event==NewLow,Mitigate,
                                        BoolToInt(Event==NewRally,(BoolToInt(basis==NetShort,Wait,Protect)),
                                        BoolToInt(Event==NewPullback,(BoolToInt(basis==NetZero,Spot,(BoolToInt(basis==NetShort,Capture))))))));
        case Seller:      return (StrategyType)BoolToInt(Event==NewLow,(BoolToInt(basis==NetLong,Hedge,Protect)),
                                        BoolToInt(Event==NewHigh,Mitigate,
                                        BoolToInt(Event==NewPullback,(BoolToInt(basis==NetLong,Wait,Protect)),
                                        BoolToInt(Event==NewRally,(BoolToInt(basis==NetZero,Spot,(BoolToInt(basis==NetLong,Capture))))))));
        default:          return Wait;
      }
    }

    return Wait;
  }

//+------------------------------------------------------------------+
//| ManageFund - Fund Manager order processor                        |
//+------------------------------------------------------------------+
void ManageFund(RoleType Role)
  {
    //-- Position checks
    StrategyChanged(Role,signal.Boundary.Event);
    
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

    order.ProcessOrders(Role);
  }


//+------------------------------------------------------------------+
//| ExecuteSpot - Spots are contrarian, pre-build order placement    |
//+------------------------------------------------------------------+
void ExecuteSpot(RoleType Role)
  {
    OrderRequest request   = order.BlankRequest("Spot/"+EnumToString(Role));
    
    int    direction       = Direction(Role,InAction);
    double price           = ParseEntryPrice(Role,BoolToStr(Role==Buyer,"-")+DoubleToStr(order.Config(Role).ZoneStep,1)+"P");
    
    if (order.Free(Role,price)>order.Split(Role))
      //-- Handle Convergences
      if (Fractal(Term).Direction==direction)      {
        if (t.Segment().Bias==Role)
          {
            request.Type    = ActionCode(EnumToString(Role),price);
            request.Lots    = order.Free(Role);
            request.Price   = price;
            request.Memo    = "[mv3] Auto Spot";
            
            if (order.Submitted(request))
              Print(order.RequestStr(request));
            else
              Print("Order Not Submitted! \n\n"+order.RequestStr(request));
          };
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
    static double open     = 0.00;
    static int    series   = 0;

    if (StrategyChanged(Role,signal.Boundary.Event))
      if (manager[Role].Strategy==Spot)
      {
        open               = Close[0];
        series++;
      }
        
    switch (manager[Role].Strategy)
    {
      case Spot:  ExecuteSpot(Role);
    };
    
    //if (manager[Role].Strategy==Spot)
    //  Print("|Spot|"+(string)fTick+"|"+(string)series+"|"+DoubleToStr(open,Digits)+"|"+ActionText(Role)+"|"+DoubleToStr(Close[0],Digits));

    order.ProcessOrders(Role);
  }


//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Handle Active Management
   if (IsBetween(master.Lead,Buyer,Seller))
   {
     ManageFund(master.Lead);
     ManageRisk((RoleType)Action(master.Lead,InAction,InContrarian));
    }
   else

   //-- Handle Unassigned Manager
   {
     ManageRisk(Buyer);
     ManageRisk(Seller);
   }

    order.ProcessRequests(0.00002);
  }


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  { 
    ProcessComFile();

    UpdateMaster();
    WriteSignal();

//    if (sigBoundary.Event>NoEvent)
    switch ((int)fTick)
    {
      case 4097:    //--Sell
      case 18167:   //--Sell
      case 36029:   //--Sell
      case 85079:   //--Sell
      case 97841:   //--Buy
      case 106247:  //--Buy
      case 179942:  //--Buy
      case 191936:  //--Buy
      case 238624:  //--Buy
      case 256666:  //--Buy
      case 263178:  //--Buy
      case 310228:  //--Buy
      case 330244:  //--Buy
      case 334574:  //--Buy
      case 360198:  //--Buy
      case 376830:  //--Sell
      case 382718:  //--Buy
      case 392581:  //--Buy
      case 415594:  //--Buy
      case 423432:  //--Sell
      case 430220:  //--Sell
      case 445363:  //--Sell
      case 468585:  //--Sell
      case 483794:  //--Sell
      case 500984:  //--Sell
      case 505123:  //--Sell
      case 578305:  //--Sell
      case 587002:  //--Buy
      case 593664:  //--Buy
      case 600568:  //--Buy
      case 608184:  //--Buy
      case 622145:  //--Buy
      case 638216:  //--Buy
      case 660397:  //--Sell
      case 668377:  //--Sell
      case 677236:  //--Sell
      case 691235:  //--Sell
      case 698943:  //--Sell
      case 739034:  //--Buy
      case 755245:  //--Buy
      case 757894:  //--Sell
      case 766217:  //--Buy
                    //Pause("Signal test: "+DirText(signal.Direction)+" Spot "+proper(ActionText(master.OnCall))+"er: "+EnumToString(signal.Recovery.Event)+" on "+(string)fTick,"Signal Test()");
                    //Pause("Signal test: "+DirText(signal.Direction)+" Boundary Hit: "+EnumToString(signal.Recovery.Event)+" on "+(string)fTick,"Signal Test()");
                    //Arrow("recoLow-NewHigh:"+(string)fTick,ArrowDash,clrYellow);
                    break;
    }

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
    SignalTrigger trigger   = {NoDirection,NoValue,0.00};
    trigger.Price           = Close[0];
    
    for(FractalPoint point=0;point<FractalPoints;point++)
    {
      signalFP[point].Bar      = BoolToInt(IsBetween(point,fpBase,fpExpansion),0,NoValue);
      signalFP[point].Price    = BoolToDouble(IsBetween(point,fpBase,fpExpansion),Close[0]);
    }

    signal.Tick                = NoValue;
    signal.Price               = Close[0];
    signal.Direction           = NoDirection;
    signal.Lead                = NoAction;
    signal.Bias                = NoAction;
    signal.State               = NoValue;
    
    NewPriceLabel("sigHi");
    NewPriceLabel("sigLo");
    
    signal.Boundary.High       = trigger;
    signal.Boundary.Low        = trigger;
    
    signal.Recovery.High       = trigger;
    signal.Recovery.Low        = trigger;
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
