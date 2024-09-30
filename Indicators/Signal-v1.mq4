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
input string inpSigFile    = "signal.bin";


  //--- Data Source Type
  enum    SourceType
          {
            Session,   // Session
            TickMA     // TickMA
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

  struct  SignalFractal
          {
            int              Bar;
            double           Price;
          };

  int               sigWinID      = NoValue;
  double            sigBuffer[];
  double            sigHist[];

  SignalRec         sig;
  SignalFractal     sigfp[FractalPoints];


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdateLabel("lbvSigTick",(string)sig.Tick,clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigPrice",DoubleToString(sig.Price,_Digits),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigEvent",EnumToString(sig.Alert)+" "+
                               EventText(sig.Event),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigState",EnumToString(sig.State),clrDarkGray,12,"Noto Sans Mono CJK HK");
    
    UpdateDirection("lbvSigDirection",sig.Direction,Color(sig.Direction),16);
    UpdateDirection("lbvSigLead",Direction(sig.Lead,InAction),Color(Direction(sig.Lead,InAction)),16);
    UpdateDirection("lbvSigBias",Direction(sig.Bias,InAction),Color(Direction(sig.Bias,InAction)),16);

    UpdateLabel("lbvSigTrigger",BoolToStr(sig.Recovery.Event>NoEvent,"FIRED","IDLE "),BoolToInt(sig.Recovery.Event>NoEvent,clrWhite,clrDarkGray),8,"Noto Sans Mono CJK HK");
    UpdateBox("sig-"+(string)sigWinID+":Trigger",Color(sig.Direction,IN_DARK_DIR));
    UpdateBox("sig-"+(string)sigWinID+":FractalPoint",BoolToInt(sig.Lead==Buyer,C'0,42,0',C'42,0,0'));
    
    for (FractalPoint point=0;point<FractalPoints;point++)
    {
      UpdateRay("sig-"+(string)sigWinID+":"+EnumToString(point),inpRetention,
        BoolToDouble(sigfp[point].Bar>NoValue,sigfp[point].Price),-6);
        
      UpdateLabel("sigFP-"+(string)sigWinID+":"+EnumToString(point),EnumToString(point)+":"+
        DoubleToString(sigfp[point].Bar,0)+"/"+DoubleToString(sigfp[point].Price,_Digits),clrDarkGray,12,"Noto Sans Mono CJK HK");
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
    static long lastTick = NoValue;
    static long tick     = lastTick;

    int fhandle = FileOpen(inpSigFile,FILE_SHARE_READ|FILE_READ|FILE_BIN);
    
    tick++;

    if (fhandle>INVALID_HANDLE)
    {
      uint s   = FileReadStruct(fhandle,sig);
      uint h;   

      for(FractalPoint point=0;point<FractalPoints;point++)
        h = FileReadStruct(fhandle,sigfp[point]);
        
      if (IsChanged(lastTick,sig.Tick))
      {
        ArrayCopy(sigHist,sigHist,1,0,inpRetention-1);
        sigHist[0]    = sig.Price;
          
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
    NewLabel("lbvTick","",152,2,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigTick","",82,2,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigPrice","",10,2,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigSource","",10,20,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigFibo","",10,38,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigEvent","",10,56,clrDarkGray,SCREEN_UR,sigWinID);

    NewLabel("lbvSigDirection","",90,78,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigLead","",50,78,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigBias","",10,78,clrDarkGray,SCREEN_UR,sigWinID);

    NewLabel("lbvSigTrigger","Fired",158,100,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigState","",10,109,clrDarkGray,SCREEN_UR,sigWinID);

    UpdateLabel("lbvSigTick","9999999999",clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigPrice","9.99999",clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigSource","Session Trend Retrace",clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigFibo","Extension: 116.4%",clrDarkGray,12,"Noto Sans Mono CJK HK");
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
    }

    return(INIT_SUCCEEDED);
  }
