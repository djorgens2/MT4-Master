//+------------------------------------------------------------------+
//|                                                    Signal-v1.mq4 |
//|                            Copyright 2013-2024, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013-2024, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_separate_window

#property indicator_buffers 1
#property indicator_plots   1

//--- plot Signal Price
#property indicator_label1  "sigPrice"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <stdutil.mqh>
#include <Class/Fractal.mqh>

input int    inpRetention  = 240;
input string inpSigFile    = "sighist.csv";


  //--- Data Source Type
  enum    SourceType
          {
            Session,   // Session
            TickMA     // TickMA
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


  //-- Signals (Events) requiring Manager Action (Response)
  struct SignalRec
         {
           long             Tick;
           double           Price;
           SourceType       Source;
           FractalType      Type;
           FractalState     State;
           EventType        Event;
           AlertType        Alert;
           int              Direction;
           RoleType         Lead;
           RoleType         Bias;
           bool             Trigger;
           FractalState     EntryState;
           bool             ActiveEvent;
         };

  struct SignalFractal
         {
           int              Bar;
           double           Price;
         };
  int               sigWinID      = NoValue;
  double            sigBuffer[];
  double            sigHist[];

  SignalRec         sig,sr;
  SignalFractal     sigFractal[FractalPoints];


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdateLabel("lbvSigTick",(string)sr.Tick,clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigPrice",DoubleToString(sr.Price,_Digits),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigSource",EnumToString(sig.Source)+" "+
                               EnumToString(sig.Type)+" "+
                               EnumToString(sig.State),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigEvent",EnumToString(sig.Alert)+" "+
                               EventText(sig.Event),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigEntryState",EnumToString(sr.EntryState),clrDarkGray,12,"Noto Sans Mono CJK HK");
    
    UpdateDirection("lbvSigDirection",sr.Direction,Color(sr.Direction),16);
    UpdateDirection("lbvSigLead",Direction(sr.Lead,InAction),Color(Direction(sr.Lead,InAction)),16);
    UpdateDirection("lbvSigBias",Direction(sr.Bias,InAction),Color(Direction(sr.Bias,InAction)),16);

    UpdateLabel("lbvSigTrigger",BoolToStr(sig.Trigger,"FIRED","IDLE "),BoolToInt(sig.Trigger,clrWhite,clrBeige),8,"Noto Sans Mono CJK HK");
    UpdateBox("sig-"+(string)sigWinID+":Trigger",Color(sr.Direction,IN_DARK_DIR));
    UpdateBox("sig-"+(string)sigWinID+":FractalPoint",BoolToInt(sr.Lead==Buyer,C'0,42,0',C'42,0,0'));
    
    for (FractalPoint point=0;point<FractalPoints;point++)
    {
      UpdateRay("sig-"+(string)sigWinID+":"+EnumToString(point),30,
        BoolToDouble(sigFractal[point].Bar>NoValue,sigFractal[point].Price),-6);
        
      UpdateLabel("sigFP-"+(string)sigWinID+":"+EnumToString(point),EnumToString(point)+":"+
        DoubleToString(sigFractal[point].Bar,0)+"/"+DoubleToString(sigFractal[point].Price,_Digits),clrDarkGray,12,"Noto Sans Mono CJK HK");
    }

  };

//+------------------------------------------------------------------+
//| CalcSignalFractal - Updates the SignalFractal array              |
//+------------------------------------------------------------------+
void CalcSignalFractal(void)
  {
    FractalState      prevState    = sr.State;
    SignalFractal     sighi, siglo;

    //-- Dump first tick
    if (sr.Tick==0)
      return;

    sr.Price    = sig.Price;
    sr.Bias     = (RoleType)Action(sigHist[0]-sigHist[1],InDirection);
    sr.EntryState = (FractalState)BoolToInt(sig.EntryState>NoState,sig.EntryState,sr.EntryState);
    
    //-- Calc History hi/lo
    sighi.Price=sr.Price;
    siglo.Price=sr.Price;

    for (int bar=0;bar<ArraySize(sigHist);bar++)
      if (IsEqual(sigHist[bar],0.00))
        break;
      else
      {
        if (IsHigher(sigHist[bar],sighi.Price)) sighi.Bar=bar;
        if (IsLower(sigHist[bar],siglo.Price))  siglo.Bar=bar;
      }

    if (sigFractal[fpRoot].Price>sighi.Price) sigFractal[fpRoot]=sighi;
    if (sigFractal[fpRoot].Price<siglo.Price) sigFractal[fpRoot]=siglo;
    if (sigFractal[fpBase].Price>sighi.Price) sigFractal[fpBase]=sighi;
    if (sigFractal[fpBase].Price<siglo.Price) sigFractal[fpBase]=siglo;

    //-- Update FP array bars
    for (int point=0;point<FractalPoints;point++)
      if (sigFractal[point].Bar>NoValue)
        sigFractal[point].Bar++;

    //-- Handle Interior Alerts
    if (IsBetween(sr.Price,sigFractal[fpExpansion].Price,sigFractal[fpRoot].Price))
    {
      sr.State       = (FractalState)BoolToInt(sr.Bias==Buyer,Rally,Pullback);

      //-- Handle Recoveries
      if (IsEqual(sr.Direction,Direction(sr.Bias,InAction)))
      {
        if (sigFractal[fpRecovery].Bar>NoValue)
        {
           if (sr.Direction==DirectionUp)
           {
             if (IsHigher(sr.Price,sigFractal[fpRecovery].Price))
             {
               sr.Lead                 = sr.Bias;
               sr.State                = Recovery;
   
               sigFractal[fpRecovery].Bar     = 0;
             }
           }
           else
           
           if (sr.Direction==DirectionDown)
           {
             if (IsLower(sr.Price,sigFractal[fpRecovery].Price))
             {
               sr.Lead                 = sr.Bias;
               sr.State                = Recovery;
   
               sigFractal[fpRecovery].Bar     = 0;
             }
           }
           else
            
           if (prevState==Retrace)
           {
             sigFractal[fpRecovery].Bar     = 0;
             sigFractal[fpRecovery].Price   = sr.Price;
           }
         }
         else
         {
           sigFractal[fpRecovery].Bar     = 0;
           sigFractal[fpRecovery].Price   = sr.Price;
         }
      }
      else
      
      //-- Handle Retraces
      {
        if (sigFractal[fpRecovery].Bar>NoValue)
        {
          if (prevState==Recovery)
          {
            sigFractal[fpRetrace].Bar     = 0;
            sigFractal[fpRetrace].Price   = sr.Price;
          }
          else

          if (sr.Direction==DirectionUp)
          {
            if (IsLower(sr.Price,sigFractal[fpRetrace].Price))
            {
              sr.Lead                 = sr.Bias;
              sr.State                = Retrace;

              sigFractal[fpRetrace].Bar     = 0;
            }
          }
          else
          
          if (sr.Direction==DirectionDown)
          {
            if (IsHigher(sr.Price,sigFractal[fpRetrace].Price))
            {
              sr.Lead                 = sr.Bias;
              sr.State                = Retrace;

              sigFractal[fpRetrace].Bar     = 0;
            }
          }          
          else
           
          if (prevState==Recovery)
          {
            sigFractal[fpRetrace].Bar     = 0;
            sigFractal[fpRetrace].Price   = sr.Price;
          }
        }
        else
        {
          sigFractal[fpRetrace].Bar     = 0;
          sigFractal[fpRetrace].Price   = sr.Price;
        }
      }
    }
    else

    //-- Handle Expansions
    {
      sr.State                        = (FractalState)BoolToInt(sr.State==Reversal,Reversal,Breakout);
      sr.Lead                         = sr.Bias;

      if (DirectionChanged(sr.Direction,BoolToInt(sr.Price>sigFractal[fpBase].Price,DirectionUp,DirectionDown)))
      {
        sr.State                      = Reversal;

        sigFractal[fpRetrace].Bar     = sigFractal[fpRecovery].Bar;
        sigFractal[fpRetrace].Price   = sigFractal[fpRecovery].Price;
        sigFractal[fpBase].Price      = sigFractal[fpRoot].Price;
        sigFractal[fpRoot].Price      = sigFractal[fpExpansion].Price;
      }

      sigFractal[fpRecovery].Bar      = NoValue;
      sigFractal[fpRecovery].Price    = 0.00;
      sigFractal[fpExpansion].Bar     = 0;
      sigFractal[fpExpansion].Price   = sr.Price;
    }
  };

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
    int fhandle = FileOpen(inpSigFile,FILE_SHARE_READ|FILE_READ|FILE_BIN);

    if (fhandle>INVALID_HANDLE)
    {
      uint s   = FileReadStruct(fhandle,sig);

      if (IsChanged(sr.Tick,sig.Tick))
      {
        ArrayCopy(sigHist,sigHist,1,0,inpRetention-1);
        sigHist[0]    = sig.Price;
  
        CalcSignalFractal();
        
        RefreshScreen();
      }
    
      FileClose(fhandle);      
    }

    ArrayInitialize(sigBuffer,0.00);    
    ArrayCopy(sigBuffer,sigHist);
    
    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- Initialize Indicator
    IndicatorShortName("Signal-v1");
    sigWinID = ChartWindowFind(0,"Signal-v1");

    //--- Signal Panel Labels
    NewLabel("lbvSigTick","",85,5,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigPrice","",10,5,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigSource","",10,25,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigEvent","",10,45,clrDarkGray,SCREEN_UR,sigWinID);

    NewLabel("lbvSigDirection","",90,75,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigLead","",50,75,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigBias","",10,75,clrDarkGray,SCREEN_UR,sigWinID);

    NewLabel("lbvSigTrigger","Fired",158,100,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigEntryState","",10,109,clrDarkGray,SCREEN_UR,sigWinID);

    UpdateLabel("lbvSigTick","9999999999",clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigPrice","9.99999",clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigSource","Session Trend Retrace",clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigEvent","Critcal New Convergence",clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigTrigger","Fired",clrYellow,8,"Noto Sans Mono CJK HK");

    UpdateDirection("lbvSigDirection",sig.Direction,Color(sig.Direction),16);
    UpdateDirection("lbvSigLead",sig.Lead,Color(sig.Lead),16);
    UpdateDirection("lbvSigBias",sig.Bias,Color(sig.Bias),16);

    SetIndexBuffer(0,sigBuffer);
    SetIndexEmptyValue(0,0.00);

    ArrayResize(sigHist,inpRetention);
    
    DrawBox("sig-"+(string)sigWinID+":FractalPoint",210,108,205,140,C'0,42,0',BORDER_FLAT,SCREEN_UR,sigWinID);
    DrawBox("sig-"+(string)sigWinID+":Trigger",200,100,50,16,C'0,42,0',BORDER_FLAT,SCREEN_UR,sigWinID);
    
    for(FractalPoint point=0;point<FractalPoints;point++)
    {
      NewRay("sig-"+(string)sigWinID+":"+EnumToString(point),fpstyle[point],fpcolor[point],false,sigWinID);
      NewLabel("sigFP-"+(string)sigWinID+":"+EnumToString(point),"xx",10,125+(point*16),clrDarkGray,SCREEN_UR,sigWinID);

      sigFractal[point].Bar         = BoolToInt(IsBetween(point,fpBase,fpExpansion),0,NoValue);
      sigFractal[point].Price       = BoolToDouble(IsBetween(point,fpBase,fpExpansion),Close[0]);
    }

//    for(FractalPoint point=0;point<FractalPoints;point++)
//      Print(EnumToString(point)+":"+DoubleToString(sigFractal[point].Bar,0)+"/"+DoubleToString(sigFractal[point].Price,_Digits));
//
//    Pause("Signal","Init Check");

    sr.Tick                         = NoValue;
    sr.Direction                    = NoDirection;
    sr.Lead                         = NoAction;
    sr.Bias                         = NoAction;
    sr.State                        = NoValue;

    return(INIT_SUCCEEDED);
  }
