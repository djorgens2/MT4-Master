//+------------------------------------------------------------------+
//|                                                       man-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                         Raw Order-Integration EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "3.01"
#property strict

#define debug true

#include <Class/Order.mqh>
#include <Class/Session.mqh>
#include <Class/TickMA.mqh>

#include <ordman.mqh>

//-- Class defs
//COrder                *order;
CSession              *s[SessionTypes];
CTickMA               *t;

FractalType show      = NoValue;

  //--- Show Fractal Event Flag
  enum ShowType
       {
         stNone   = NoValue,   // None
         stOrigin = Origin,    // Origin
         stTrend  = Trend,     // Trend
         stTerm   = Term       // Term
       };


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
  input ShowType         inpShowType         = stNone;        // Show TickMA Fractal Events


  //--- Session Config
  input string           sessHeader          = "";            // +--- Session Config -------+
  input int              inpAsiaOpen         = 1;             // Asia Session Opening Hour
  input int              inpAsiaClose        = 10;            // Asia Session Closing Hour
  input int              inpEuropeOpen       = 8;             // Europe Session Opening Hour
  input int              inpEuropeClose      = 18;            // Europe Session Closing Hour
  input int              inpUSOpen           = 14;            // US Session Opening Hour
  input int              inpUSClose          = 23;            // US Session Closing Hour
  input int              inpGMTOffset        = 0;             // Offset from GMT+3


  //--- Data Source Type
  enum    SourceType
          {
            Session,         //-- Session
            TickMA           //-- TickMA
          };

  //-- Strategy Types
  enum    StrategyType
          {
            Wait,            //-- Hold, wait for signal
            Manage,          //-- Maintain Margin, wait for profit oppty's
            Build,           //-- Increase Position
            Cover,           //-- Aggressive balancing on excessive drawdown
            Capture,         //-- Contrarian profit protection
            Mitigate,        //-- Risk management on pattern change
            Defer            //-- Defer to contrarian manager
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
            bool             Trigger;              //-- Trigger state
          };

  struct SignalNode
         {
           int              Bar;
           double           Price;
         };

  //-- Signals (Events) requiring Manager Action (Response)
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
            bool             Trigger;           //-- Trigger (Major Events)
            SourceType       Source;            //-- Signal Source (Session/TickMA)
            FractalType      Type;              //-- Source Fractal
            FractalState     Momentum;          //-- Triggered Pullback/Rally
            bool             ActiveEvent;       //-- True on Active Event (All Sources)
          };

  //-- Master Control Operationals
  struct  MasterRec
          {
            RoleType         Lead;              //-- Process Manager (Owner|Lead)
            RoleType         OnCall;            //-- Manager on deck while unassigned
          };


  //-- Data Collections
  MasterRec              master;
  ManagerRec             manager[RoleTypes];    //-- Manager Detail Data
  SignalRec              signal;
  SignalNode             signalFP[FractalPoints];
  double                 sigHistory[];

  //-- Internal EA Configuration
  string                 indSN               = "CPanel-v"+(string)inpIndSNVersion;
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
      
//      Pause("Tick: "+(string)fTick+"\n\n"+t.EventLogStr()+"\n\nSession:\n"+s[Daily].EventLogStr(),"Signal Event");
    }
  }

//+------------------------------------------------------------------+
//| DebugPrint - Prints debug/event data                             |
//+------------------------------------------------------------------+
void DebugPrint(void)
  {
    static int rangeDir  = NoDirection;
    
    if (debug)
    {
      if (signal.Alert>NoAlert)
      {
        string ftext  = EnumToString(signal.Source);
        
        Append(ftext,EnumToString(signal.Type),"|");
        Append(ftext,EnumToString(Fractal().State),"|");
        Append(ftext,(string)fTick,"|");
        Append(ftext,DoubleToString(Close[0],_Digits),"|");
        Append(ftext,EnumToString(signal.State),"|");
        Append(ftext,BoolToStr(signal.Trigger,"Fired","Idle"),"|");
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

        WriteSignal();
      }
    }
  }

//+------------------------------------------------------------------+
//| Clear Remove arrows/flags/Labels based on supplied ObjectName    |
//+------------------------------------------------------------------+
void Clear(string Key)
  {
    //-- Clean Open Chart Objects
    int fObject             = 0;
    
    while (fObject<ObjectsTotal())
      if (InStr(ObjectName(fObject),Key))
        ObjectDelete(ObjectName(fObject));
      else fObject++;
  }


//+------------------------------------------------------------------+
//| AlertColor Set Color for Supplied Alert for flags, text, et al.  |
//+------------------------------------------------------------------+
color AlertColor(AlertType Type)
  {
    switch (Type)
    {
      case NoAlert:  return clrNONE;
      case Notify:   return clrForestGreen;
      case Nominal:  return clrLawnGreen;
      case Warning:  return clrYellow;
      case Minor:    return clrSandyBrown;
      case Major:    return clrChocolate;
      case Critical: return clrRed;
    }

    return clrWhite;
  }


//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static int     panelWinID   = NoValue;
    static int     signalWinID  = NoValue;
           string  text         = "";
    
    UpdateLabel("lbvSigSource", EnumToString(signal.Source)+" "+EnumToString(signal.Type)+" "+EnumToString(Fractal().State),
                                BoolToInt(Fractal().Pivot.Lead==Buyer,clrLawnGreen,clrRed),12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigFibo",   BoolToStr(IsBetween(Fractal().State,Rally,Correction),
                                  "Retrace x"+DoubleToStr(Fractal().Retrace.Percent[Max]*100,1)+"% "+
                                          "n"+DoubleToStr(Fractal().Retrace.Percent[Now]*100,1)+"%",
                                  "Extends x"+DoubleToStr(Fractal().Extension.Percent[Max]*100,1)+"% "+
                                          "n"+DoubleToStr(Fractal().Extension.Percent[Now]*100,1)+"%"),
                                BoolToInt(Fractal().Pivot.Bias==Buyer,clrLawnGreen,clrRed),12,"Noto Sans Mono CJK HK");
    //-- Update Control Panel (Application)
    if (IsChanged(panelWinID,ChartWindowFind(0,indSN)))
    {
      //-- Update Panel
      order.ConsoleAlert("Connected to "+indSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));
      
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
      UpdateLabel("pvEquity",DoubleToStr(order.Metrics().EquityClosed*100,1)+"%",Color(order[Net].Value),14,"Consolas");
      UpdateLabel("pvMargin",DoubleToString(order.Metrics().Margin*100,1)+"%",Color(order[Net].Lots),14,"Consolas");

      Comment(order.QueueStr()+order.OrderStr());
    }
  }


////+------------------------------------------------------------------+
////| Fractal - Returns the recommended Indicator Fractal record       |
////+------------------------------------------------------------------+
//FractalRec Fractal(void)
//  {
//    if (signal.Source==TickMA)
//      return t[signal.Type];
//      
//    return s[Daily][signal.Type];
//  }
//
//+------------------------------------------------------------------+
//| Fibonacci - Returns the recommended Indicator Fibonacci detail   |
//+------------------------------------------------------------------+
FractalRec Fractal(void)
  {
    if (signal.Source==TickMA)
      return t[signal.Type];
      
    return s[Daily][signal.Type];
  }

//+------------------------------------------------------------------+
//| ManagerChanged - Returns true on change in Operations Manager    |
//+------------------------------------------------------------------+
bool ManagerChanged(RoleType &Incumbent, RoleType Incoming)
  {
    if (IsEqual(Incoming,Incumbent))
      return false;
      
    Incumbent       = Incoming;

    return true;  
  }

//+------------------------------------------------------------------+
//| Manager - Returns the manager for the supplied Fractal           |
//+------------------------------------------------------------------+
RoleType Manager(void)
  {
    return (RoleType)BoolToInt(IsEqual(Fractal().State,Correction),Action(Fractal().Direction,InDirection,InContrarian),Action(Fractal().Direction));
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
        signal.Trigger        = true;
      }
      else
      if (Signal.Event(NewFibonacci))
      {
        signal.Type           = (FractalType)BoolToInt(Signal.Event(NewFibonacci,Critical),Origin,
                                             BoolToInt(Signal.Event(NewFibonacci,Major),Trend,Term));
        signal.Event          = NewFibonacci;
        signal.Trigger        = true;
      }
      else
      if (Signal.Event(NewLead))
      {
        signal.Event          = NewLead;
        signal.Trigger        = true;
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
    FractalState      prevState    = signal.State;

    SignalNode        sighi        = {0,0.00};
    SignalNode        siglo        = {0,0.00};

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
   
                 signalFP[fpRecovery].Bar    = 0;
               }
             }
             else
            
             if (prevState==Retrace)
             {
               signalFP[fpRecovery].Bar      = 0;
               signalFP[fpRecovery].Price    = signal.Price;
             }
           }
           else
           {
             signalFP[fpRecovery].Bar        = 0;
             signalFP[fpRecovery].Price      = signal.Price;
           }
        }
        else
      
        //-- Handle Retraces
        {
          if (signalFP[fpRecovery].Bar>NoValue)
          {
            if (prevState==Recovery)
            {
            signalFP[fpRetrace].Bar        = 0;
            signalFP[fpRetrace].Price      = signal.Price;
            }
            else

            if (signal.Direction==DirectionUp)
            {
              if (IsLower(signal.Price,signalFP[fpRetrace].Price))
              {
                signal.Lead                 = signal.Bias;
                signal.State                = Retrace;

                signalFP[fpRetrace].Bar     = 0;
              }
            }
            else
          
             if (signal.Direction==DirectionDown)
            {
              if (IsHigher(signal.Price,signalFP[fpRetrace].Price))
              {
                signal.Lead                 = signal.Bias;
                signal.State                = Retrace;

                signalFP[fpRetrace].Bar     = 0;
              }
            }          
            else
           
            if (prevState==Recovery)
            {
              signalFP[fpRetrace].Bar       = 0;
              signalFP[fpRetrace].Price     = signal.Price;
            }
          }
          else
          {
            signalFP[fpRetrace].Bar         = 0;
            signalFP[fpRetrace].Price       = signal.Price;
          }
        }
      }
      else

      //-- Handle Expansions
      {
        signal.State                        = (FractalState)BoolToInt(signal.State==Reversal,Reversal,Breakout);
        signal.Lead                         = signal.Bias;

        if (DirectionChanged(signal.Direction,BoolToInt(signal.Price>signalFP[fpBase].Price,DirectionUp,DirectionDown)))
        {
          signal.State                      = Reversal;

          signalFP[fpRetrace]               = signalFP[fpRecovery];
          signalFP[fpBase].Price            = signalFP[fpRoot].Price;
          signalFP[fpRoot].Price            = signalFP[fpExpansion].Price;
          
          Flag("sigBounds:"+(string)signal.Tick,Color(signal.Direction,IN_CHART_DIR),0,signal.Price,Always);
        }

        signalFP[fpRecovery].Bar            = NoValue;
        signalFP[fpRecovery].Price          = 0.00;
        signalFP[fpExpansion].Bar           = 0;
        signalFP[fpExpansion].Price         = signal.Price;
      }
    }
  }


//+------------------------------------------------------------------+
//| UpdateManager - Updates Manager data from Supplied Fractal       |
//+------------------------------------------------------------------+
void UpdateManager(void)
  {
    //-- Reset Manager Targets
    if (ManagerChanged(master.Lead,Manager()))
      if (master.Lead>Unassigned)
        ArrayInitialize(manager[master.Lead].Equity,order[master.Lead].Equity);

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      manager[role].DCA           = order.DCA(role);
      manager[role].Entry         = order.Entry(role);
      manager[role].Trigger       = signal.Trigger||manager[role].Trigger;
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
    signal.Trigger            = false;

    if (signal.ActiveEvent)
    {
      ArrayCopy(sigHistory,sigHistory,1,0,inpSigRetain-1);
      sigHistory[0]            = signal.Price;

      signal.Tick             = fTick;
      signal.Price            = Close[0];
      signal.Bias             = (RoleType)Action(signal.Price-sigHistory[0],InDirection);

       //string evT ="|TickMA|"+(string)signal.Tick;
       //string evS ="|Session|"+(string)signal.Tick;
       //for(EventType ev=1;ev<EventTypes;ev++)
       //{
       //  Append(evT,BoolToStr(t[ev],EnumToString(ev),"---"),"|");
       //  Append(evS,BoolToStr(s[Daily][ev],EnumToString(ev),"---"),"|");
       //  if (ev==NewSegment||ev==NewChannel)
       //  {
       //    Append(evT,"NoComp","|");
       //    Append(evS,"NoComp","|");
       //  }           
       //}
       //Print(evT);
       //Print(evS);
    }

    UpdateSignal(Session,s[Daily]);
    UpdateSignal(TickMA,t);
    UpdateSignal();
    UpdateManager();

    DebugPrint();
  }

//+------------------------------------------------------------------+
//| SetStrategy - Set Strategy for supplied Role                     |
//+------------------------------------------------------------------+
void SetStrategy(RoleType Role)
  {

    RoleType     contrarian = (RoleType)Action(Role,InAction,InContrarian);
    StrategyType strategy   = Wait;

//Wait             //-- Hold, wait for signal
//Manage,          //-- Manage Margin; Seek Profit
//Build,           //-- Increase Position
//Cover,           //-- Aggressive balancing on excessive drawdown
//Capture,         //-- Contrarian profit protection
//Mitigate,        //-- Risk management on pattern change
//Defer,           //-- Defer to contrarian manager
   
//       switch (Role)
//       {
//         case Buyer:   if (signal.EntryState==Pullback)
//                       {
//                         if (t.Linear().Head<Close[0])
//                           manager[Role].Strategy      = (StrategyType)BoolToInt(order[OP_SELL].Lots>0,Manage);
//                         else
//                           manager[Role].Strategy      = (StrategyType)BoolToInt(IsEqual(t.Linear().Direction,t.Range().Direction),Build);
//                       }
//
//                       if (signal.EntryState==Rally)
//                       {
//                       }
//                       //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
//                       break;
//
//         case Seller:  if (signal.EntryState==Rally)
//                         if (t.Linear().Head>Close[0])
//                           manager[Role].Strategy      = (StrategyType)BoolToInt(order[OP_SELL].Lots>0,Manage);
//                         else
//                           manager[Role].Strategy      = (StrategyType)BoolToInt(IsEqual(t.Linear().Direction,t.Range().Direction),Build);
//                      //Pause("Setting Profit Strategy\n Trigger: "+BoolToStr(signal.Crest>0,"High","Low"),"StrategyCheck()");
//       }
//
  }


//+------------------------------------------------------------------+
//| ManageFund - Fund Manager order processor                        |
//+------------------------------------------------------------------+
void ManageFund(RoleType Role)
  {
    //-- Position checks
    SetStrategy(Role);
    
    //-- Free Zone/Order Entry
    if (order.Free(Role)>order.Split(Role)||IsEqual(order.Entry(Role).Count,0))
    {
      OrderRequest  request  = order.BlankRequest(EnumToString(Role));

      request.Action         = Role;
      request.Requestor      = "Auto ("+request.Requestor+")";

      switch (Role)
      {
        case Buyer:          if (t[NewTick])
                               manager[Role].Trigger  = false;
                             break;

        case Seller:         if (t[NewTick])
                               manager[Role].Trigger  = false;
                               
                             switch (manager[Role].Strategy)
                             {
                               case Build:   if (t.Event(NewHigh,Nominal))
                                             {
                                               request.Type    = OP_SELL;
                                               request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
                                               request.Memo    = "Contrarian (In-Trend)";
                                             }
                                             break;

                               //case Manage:  if (t[NewLow])
                               //              {
                               //                request.Type    = OP_SELL;
                               //                request.Lots    = order.LotSize(OP_SELL)*t[Term].Retrace.Percent[Now];
                               //                request.Memo    = "Contrarian (In-Trend)";
                               //              }
                               //              break;
                             }
                             break;
      }

      if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
        if (order.Submitted(request))
          Print(order.RequestStr(request));
    }

    order.ProcessOrders(Role);
  }


//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(RoleType Role)
  {
    SetStrategy(Role);
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

    order.ProcessRequests();
  }


void UpdateFractalScreen(void)
  {
    if (inpShowType>NoValue)
    {
      UpdateRay(objectstr+"lnS_Origin:"+EnumToString(show),inpPeriods,t[show].Point[fpOrigin],-8);
      UpdateRay(objectstr+"lnS_Base:"+EnumToString(show),inpPeriods,t[show].Point[fpBase],-8);
      UpdateRay(objectstr+"lnS_Root:"+EnumToString(show),inpPeriods,t[show].Point[fpRoot],-8,0,
                             BoolToInt(IsEqual(t[show].Direction,DirectionUp),clrRed,clrLawnGreen));
      UpdateRay(objectstr+"lnS_Expansion:"+EnumToString(show),inpPeriods,t[show].Point[fpExpansion],-8,0,
                             BoolToInt(IsEqual(t[show].Direction,DirectionUp),clrLawnGreen,clrRed));
      UpdateRay(objectstr+"lnS_Retrace:"+EnumToString(show),inpPeriods,t[show].Point[fpRetrace],-8,0);
      UpdateRay(objectstr+"lnS_Recovery:"+EnumToString(show),inpPeriods,t[show].Point[fpRecovery],-8,0);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        UpdateRay(objectstr+"lnS_"+EnumToString(fibo)+":"+EnumToString(show),inpPeriods,t.Price(fibo,show,Extension),-8,0,Color(t[show].Direction,IN_DARK_DIR));
        UpdateText(objectstr+"lnT_"+EnumToString(fibo)+":"+EnumToString(show),"",t.Price(fibo,show,Extension),-5,Color(t[show].Direction,IN_DARK_DIR));
      }

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        UpdateText(objectstr+"lnT_"+fp[point]+":"+EnumToString(show),"",t[show].Point[point],-7);
    }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {  
    ProcessComFile();

    UpdateMaster();

    Execute();

    RefreshScreen();
    
    UpdateFractalScreen();
    if (signal.Tick==33) Pause("Signal 33\n\n"+t.ActiveEventStr()+"\n"+s[Daily].ActiveEventStr()+"\n"+t.DisplayStr(),"Tick Check");
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
    t                    = new CTickMA(inpPeriods,inpAgg,(FractalType)inpShowType);

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
    for(FractalPoint point=0;point<FractalPoints;point++)
    {
      signalFP[point].Bar         = BoolToInt(IsBetween(point,fpBase,fpExpansion),0,NoValue);
      signalFP[point].Price       = BoolToDouble(IsBetween(point,fpBase,fpExpansion),Close[0]);
    }

    signal.Tick              = NoValue;
    signal.Price             = Close[0];
    signal.Direction         = NoDirection;
    signal.Lead              = NoAction;
    signal.Bias              = NoAction;
    signal.State             = NoValue;
  }

//+------------------------------------------------------------------+
//| InitMaster - Sets the startup values on the Manager Master       |
//+------------------------------------------------------------------+
void InitMaster(void)
  {
    master.Lead       = Unassigned;
    master.OnCall     = Unassigned;
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
    if (inpShowType>NoValue)
    {
      show             = (FractalType)inpShowType;

      NewRay(objectstr+"lnS_Origin:"+EnumToString(show),STYLE_DOT,clrWhite,Never);
      NewRay(objectstr+"lnS_Base:"+EnumToString(show),STYLE_SOLID,clrYellow,Never);
      NewRay(objectstr+"lnS_Root:"+EnumToString(show),STYLE_SOLID,clrDarkGray,Never);
      NewRay(objectstr+"lnS_Expansion:"+EnumToString(show),STYLE_SOLID,clrDarkGray,Never);
      NewRay(objectstr+"lnS_Retrace:"+EnumToString(show),STYLE_DOT,clrGoldenrod,Never);
      NewRay(objectstr+"lnS_Recovery:"+EnumToString(show),STYLE_DOT,clrSteelBlue,Never);

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        NewText(objectstr+"lnT_"+fp[point]+":"+EnumToString(show),fp[point]);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        NewRay(objectstr+"lnS_"+EnumToString(fibo)+":"+EnumToString(show),STYLE_DOT,clrDarkGray,Never);
        NewText(objectstr+"lnT_"+EnumToString(fibo)+":"+EnumToString(show),DoubleToStr(fibonacci[fibo]*100,1)+"%");
      }
    }

    if (debug)
    {
      dHandle = FileOpen("debug-man-v2.psv",FILE_TXT|FILE_WRITE);
      WriteSignal();
    }

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
