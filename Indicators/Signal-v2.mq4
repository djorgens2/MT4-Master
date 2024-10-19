//+------------------------------------------------------------------+
//|                                                    Signal-v2.mq4 |
//|                            Copyright 2013-2024, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013-2024, Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict
#property indicator_separate_window

#property indicator_buffers 3
#property indicator_plots   3

//--- plot Signal Price
#property indicator_label1  "sigPrice"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot sigLow
#property indicator_label2  "plLow"
#property indicator_type2   DRAW_SECTION
#property indicator_color2  clrNONE
#property indicator_style2  STYLE_DOT
#property indicator_width2  0

//--- plot sigHigh
#property indicator_label3  "plHigh"
#property indicator_type3   DRAW_SECTION
#property indicator_color3  clrNONE
#property indicator_style3  STYLE_DOT
#property indicator_width3  0

//--- Indicator buffers
double            sigHighBuffer[];
double            sigLowBuffer[];
double            sigBuffer[];
double            sigHist[];

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
           SourceType        Source;
           FractalType       Type;
         };

  struct SignalSegment
         {
           int               Direction;        //-- Direction Signaled
           SegmentState      State;
           RoleType          Lead;             //-- Calculated Signal Lead
           RoleType          Bias;             //-- Calculated Signal Bias
           double            Open;
           double            High;
           double            Low;
           double            Close;
         };
         
  //-- Signals (Events) requesting Manager Action (Response)
  struct SignalRec
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
           int              HedgeCount;        //-- Active Hedge Count; All Fractals
           double           Strength;          //-- % of Success derived from Fractals
           bool             ActiveEvent;       //-- True on Active Event (All Sources)
           AlertType        MaxAlert;          //-- Event Alert Type
           SignalFractal    Fractal;           //-- Fractal in Use;
           SignalFractal    Pivot;             //-- Fibonacci Pivot in Use;
           SignalSegment    Segment;           //-- Fractal Source/Type of Last Fibo Event
         };

  struct SignalBar
         {
           int              Bar;
           double           Price;
         };

  int               sigWinID      = NoValue;

  SignalRec         sig;
  SignalBar         sigfp[FractalPoints];


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    if (sig.MaxAlert>Notify)
      UpdateLabel("lbvSigTick",(string)sig.Tick,clrDarkGray,12,"Noto Sans Mono CJK HK");
    
    UpdateLabel("lbvSigPrice",DoubleToString(sig.Price,_Digits),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigEvent",BoolToStr(sig.Alert>NoAlert,EnumToString(sig.Alert))+" "+EventText(sig.Event),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigState",EnumToString(sig.State),clrDarkGray,12,"Noto Sans Mono CJK HK");
    
    UpdateLabel("lbvOdds",DoubleToStr(sig.Strength*100,1)+"%",Color(Direction(sig.Strength)),13,"Noto Sans Mono CJK HK");
    UpdateDirection("lbvSigDirection",sig.Direction,Color(sig.Direction),16);
    UpdateDirection("lbvSigLead",Direction(sig.Lead,InAction),Color(Direction(sig.Lead,InAction)),16);
    UpdateDirection("lbvSigBias",Direction(sig.Bias,InAction),Color(Direction(sig.Bias,InAction)),16);

    UpdateLabel("lbvSigTrigger",BoolToStr(sigfp[fpRecovery].Price==Close[0],"FIRED","IDLE "),BoolToInt(sigfp[fpRecovery].Price==Close[0],clrWhite,clrDarkGray),8,"Noto Sans Mono CJK HK");
    UpdateBox("sig-"+(string)sigWinID+":Trigger",Color(sig.Direction,IN_DARK_DIR));
    UpdateBox("sig-"+(string)sigWinID+":FractalPoint",BoolToInt(sig.Lead==Buyer,C'0,42,0',C'42,0,0'));
    
    for (FractalPoint point=fpOrigin;point<FractalPoints;point++)
    {
      UpdateRay("sig-"+(string)sigWinID+":"+EnumToString(point),inpRetention,
        BoolToDouble(sigfp[point].Bar>NoValue,sigfp[point].Price),-6);
        
      UpdateLabel("sigFP-"+(string)sigWinID+":"+EnumToString(point),EnumToString(point)+":"+
        DoubleToString(sigfp[point].Bar,0)+"/"+DoubleToString(sigfp[point].Price,_Digits),clrDarkGray,12,"Noto Sans Mono CJK HK");
    }
  };

//+------------------------------------------------------------------+
//| UpdateNode - Repaints Node Bars                                  |
//+------------------------------------------------------------------+
void UpdateNode(string NodeName, int Node, double Price1, double Price2)
  {
    ObjectSet(NodeName+(string)Node,OBJPROP_COLOR,Color(Direction(sig.Bias,InAction)));
    ObjectSet(NodeName+(string)Node,OBJPROP_PRICE1,Price1);
    ObjectSet(NodeName+(string)Node,OBJPROP_PRICE2,Price2);
    ObjectSet(NodeName+(string)Node,OBJPROP_TIME1,Time[Node]);
    ObjectSet(NodeName+(string)Node,OBJPROP_TIME2,Time[Node]);
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Repaints visuals                                  |
//+------------------------------------------------------------------+
void UpdateSignal(bool Refresh)
  {
    if (sig.MaxAlert>Notify||Refresh)
    {
      ArrayInitialize(sigHighBuffer,fmax(sigfp[fpRoot].Price,sigfp[fpExpansion].Price)+point(2));
      ArrayInitialize(sigLowBuffer,fmin(sigfp[fpRoot].Price,sigfp[fpExpansion].Price)-point(2));

//      for (int node=0;node<inpRetention;node++)
//      {
//        UpdateNode("sigHL:"+(string)sigWinID+"-",node,t.Segment(node).High,t.Segment(node).Low);
//        UpdateNode("sigOC:"+(string)sigWinID+"-",node,t.Segment(node).Open,t.Segment(node).Close);
//      }
    }
//
//    UpdateNode("sigHL:"+(string)sigWinID+"-",0,t.Segment(0).High,t.Segment(0).Low);
//    UpdateNode("sigOC:"+(string)sigWinID+"-",0,t.Segment(0).Open,t.Segment(0).Close);
  }

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
        if (sig.MaxAlert>Notify)
        {
          ArrayCopy(sigHist,sigHist,1,0,inpRetention-1);
          sigHist[0]    = sig.Price;
        }
          
        RefreshScreen();
      }
    
      FileClose(fhandle);      
    }

    ArrayInitialize(sigBuffer,0.00);    
    ArrayCopy(sigBuffer,sigHist);
    
    UpdateSignal(rates_total!=prev_calculated);
    
    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- Initialize Indicator
    IndicatorShortName("Signal-v2");
    sigWinID = ChartWindowFind(0,"Signal-v2");

    //--- Signal Panel Labels
    NewLabel("lbvTick","",152,2,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigTick","",82,2,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigPrice","",10,2,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigSource","",10,20,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigFibo","",10,38,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigEvent","",10,56,clrDarkGray,SCREEN_UR,sigWinID);

    NewLabel("lbvOdds","",130,75,clrDarkGray,SCREEN_UR,sigWinID);
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

    UpdateLabel("lbvOdds",DoubleToStr(sig.Strength*100,1)+"%",Color(Direction(sig.Strength)),13,"Noto Sans Mono CJK HK");
    UpdateDirection("lbvSigDirection",sig.Direction,Color(sig.Direction),16);
    UpdateDirection("lbvSigLead",sig.Lead,Color(sig.Lead),16);
    UpdateDirection("lbvSigBias",sig.Bias,Color(sig.Bias),16);

    //--- Create Display Visuals
    for (int obj=0;obj<inpRetention;obj++)
    {
      ObjectCreate("sigHL:"+(string)sigWinID+"-"+(string)obj,OBJ_TREND,sigWinID,0,0);
      ObjectSet("sigHL:"+(string)sigWinID+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("sigHL:"+(string)sigWinID+"-"+(string)obj,OBJPROP_WIDTH,1);

      ObjectCreate("sigOC:"+(string)sigWinID+"-"+(string)obj,OBJ_TREND,sigWinID,0,0);
      ObjectSet("sigOC:"+(string)sigWinID+"-"+(string)obj,OBJPROP_RAY,false);
      ObjectSet("sigOC:"+(string)sigWinID+"-"+(string)obj,OBJPROP_WIDTH,3);
    }

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
