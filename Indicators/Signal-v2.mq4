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

#define debug false

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

  struct SignalBar
         {
           int              Bar;
           double           Price;
         };

  struct SignalFact
         {
           double           Value;              //-- Highest High/Lowest Low
           RoleType         Bias;               //-- Role of last High/Low Boundary Change
           int              Count;
         };

  struct SignalSegment
         {
           SegmentState      State;
           int               Direction;         //-- Direction Signaled
           RoleType          Lead;              //-- Calculated Signal Lead
           RoleType          Bias;              //-- Calculated Signal Bias
           double            Open;
           double            High;
           double            Low;
           double            Close;
         };

  //-- Signals (Events) requesting Manager Action (Response)
  struct SignalRec
         {
           long             Tick;              //-- Tick Signaled by Event 
           FractalState     State;             //-- State of the Signal
           int              Direction;         //-- Signal Direction
           RoleType         Lead;              //-- Lead from strength (100,0,-100)
           RoleType         Bias;              //-- Lead from segment (HH,LL)
           EventType        Event;             //-- Highest Event
           AlertType        MaxAlert;          //-- Highest Alert
           AlertType        MaxBoundary;       //-- Highest Boundary Alert
           double           Price;             //-- Signal price (gen. Close[0])
           SignalSegment    Segment;           //-- Active Segment Range
           double           Support;           //-- From last LowerLow
           double           Resistance;        //-- From last HigherHigh
           bool             Checkpoint;        //-- Trigger (Fractal/Fibo/Lead Events)
           int              HedgeCount;        //-- Active Hedge Count; All Fractals
           SignalFact       Strength;          //-- % of Success derived from Fractals
           SignalFact       Boundary[2];
           bool             ActiveEvent;       //-- True on Active Event (All Sources)
           SignalFractal    Fractal;           //-- Fractal in Use;
           SignalFractal    Pivot;             //-- Fibonacci Pivot in Use;
         };


  int               sigWinID      = NoValue;

  SignalRec         sig;
  SignalBar         sigfp[FractalPoints];


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    if (sig.MaxBoundary>Notify)
      UpdateLabel("lbvSigTick",(string)sig.Tick,clrDarkGray,12,"Noto Sans Mono CJK HK");
    
    UpdateLabel("lbvSigPrice",DoubleToString(sig.Price,_Digits),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigEvent",BoolToStr(sig.MaxAlert>NoAlert,EnumToString(sig.MaxAlert))+" "+EventText(sig.Event),clrDarkGray,12,"Noto Sans Mono CJK HK");
    UpdateLabel("lbvSigState",EnumToString(sig.State),clrDarkGray,12,"Noto Sans Mono CJK HK");
    
    UpdateDirection("lbvSigLead",Direction(sig.Lead,InBias),Color(Direction(sig.Lead,InBias)),16);
    UpdateDirection("lbvSigBias",Direction(sig.Bias,InBias),Color(Direction(sig.Bias,InBias)),16);

    UpdateLabel("lbvStrength",DoubleToStr(sig.Strength.Value*100,1)+"%",Color(Direction(sig.Strength.Value)),9,"Noto Sans Mono CJK HK");
    UpdateDirection("lbvSegDir",sig.Segment.Direction,Color(sig.Segment.Direction),16);
    UpdateDirection("lbvSegLead",Direction(sig.Segment.Lead,InBias),Color(Direction(sig.Segment.Lead,InBias)),16);
    UpdateDirection("lbvSegBias",Direction(sig.Segment.Bias,InBias),Color(Direction(sig.Segment.Bias,InBias)),16);

    UpdateLabel("lbvSigTrigger",BoolToStr(sig.Checkpoint,"FIRED","IDLE "),BoolToInt(sig.Checkpoint,clrBlack,clrDarkGray),8,"Noto Sans Mono CJK HK");
    UpdateBox("sig-"+(string)sigWinID+":Trigger",BoolToInt(sig.Checkpoint,clrGoldenrod,Color(sig.Segment.Direction,IN_DARK_DIR)));
    UpdateBox("sig-"+(string)sigWinID+":FractalPoint",BoolToInt(sig.Segment.Lead==Buyer,C'0,42,0',C'42,0,0'));
    
    Arrow("HigherHigh",ArrowDash,clrYellow,0,sig.Boundary[HigherHigh].Value);
    Arrow("LowerLow",ArrowDash,clrRed,0,sig.Boundary[LowerLow].Value);
    
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
    ObjectSet(NodeName+(string)Node,OBJPROP_COLOR,Color(Direction(sig.Segment.Bias,InAction)));
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
    if (sig.MaxBoundary>Notify||Refresh)
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
        if (sig.MaxBoundary>Notify)
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
//| LayoutTemplate - Sets default values on visuals for Layout Work  |
//+------------------------------------------------------------------+
void LayoutTemplate(void)
  {
    if (debug)
    {
      UpdateLabel("lbvSigTick","9999999999",clrDarkGray,12,"Noto Sans Mono CJK HK");
      UpdateLabel("lbvSigPrice","9.99999",clrDarkGray,12,"Noto Sans Mono CJK HK");
      UpdateLabel("lbvSigSource","Session Trend Retrace",clrDarkGray,12,"Noto Sans Mono CJK HK");
      UpdateLabel("lbvSigFibo","Extension: 116.4%",clrDarkGray,12,"Noto Sans Mono CJK HK");
      UpdateLabel("lbvSigEvent","Critcal New Convergence",clrDarkGray,12,"Noto Sans Mono CJK HK");
      UpdateLabel("lbvSigTrigger","Fired",clrYellow,8,"Noto Sans Mono CJK HK");

      UpdateLabel("lbvStrength",DoubleToStr(sig.Strength.Value*100,1)+"%",Color(Direction(sig.Strength.Value)),13,"Noto Sans Mono CJK HK");
      UpdateDirection("lbvSigDirection",sig.Segment.Direction,Color(sig.Segment.Direction),16);
      UpdateDirection("lbvSigLead",sig.Segment.Lead,Color(sig.Segment.Lead),16);
      UpdateDirection("lbvSigBias",sig.Segment.Bias,Color(sig.Segment.Bias),16);

      for (FractalPoint point=fpExpansion;point<fpClose;point++)
      {
        UpdateLabel("sigpiv-"+(string)point,center(StringSubstr(EnumToString(point),2),9),clrLawnGreen,9,"Tahoma");
        UpdateLabel("sigpiv-"+(string)point+":H:","H: 9.99999",clrLawnGreen,8,"Noto Sans Mono CJK HK");
        UpdateLabel("sigpiv-"+(string)point+":O:","H: 9.99999",clrLawnGreen,8,"Noto Sans Mono CJK HK");
        UpdateLabel("sigpiv-"+(string)point+":L:","H: 9.99999",clrLawnGreen,8,"Noto Sans Mono CJK HK");
        UpdateDirection("sigpiv-"+(string)point+":Dir",DirectionUp,clrLawnGreen,18);
      }
    }
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

    NewLabel("lbvSigLead","",175,90,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigBias","",140,90,clrDarkGray,SCREEN_UR,sigWinID);

    NewLabel("lbvStrength","",154,70,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSegDir","",90,90,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSegLead","",55,90,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSegBias","",20,90,clrDarkGray,SCREEN_UR,sigWinID);

    NewLabel("lbvSigTrigger","Fired",158,132,clrDarkGray,SCREEN_UR,sigWinID);
    NewLabel("lbvSigState","",10,141,clrDarkGray,SCREEN_UR,sigWinID);

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

    DrawBox("sig-"+(string)sigWinID+":Signal",210,80,86,40,C'0,42,0',BORDER_FLAT,SCREEN_UR,sigWinID);
    DrawBox("sig-"+(string)sigWinID+":Segment",120,80,115,40,C'0,42,0',BORDER_FLAT,SCREEN_UR,sigWinID);
    DrawBox("sig-"+(string)sigWinID+":Strength",200,72,50,16,C'0,42,0',BORDER_FLAT,SCREEN_UR,sigWinID);
    
    DrawBox("sig-"+(string)sigWinID+":FractalPoint",210,140,205,108,C'0,42,0',BORDER_FLAT,SCREEN_UR,sigWinID);
    DrawBox("sig-"+(string)sigWinID+":Trigger",200,132,50,16,C'0,42,0',BORDER_FLAT,SCREEN_UR,sigWinID);
    
    for(FractalPoint point=fpBase;point<FractalPoints-1;point++)
    {
      NewRay("sig-"+(string)sigWinID+":"+EnumToString(point),fpstyle[point],fpcolor[point],false,sigWinID);
      NewLabel("sigFP-"+(string)sigWinID+":"+EnumToString(point),"xx",10,141+(point*16),clrDarkGray,SCREEN_UR,sigWinID);
      
      if (point<5)
      {
        NewLabel("sigpiv-"+(string)point,"",10,30+(45*point),clrNONE,SCREEN_UL,sigWinID);
        NewLabel("sigpiv-"+(string)point+":H:","",85,30+(33*point)+(12*point),clrNONE,SCREEN_UL,sigWinID);
        NewLabel("sigpiv-"+(string)point+":O:","",85,42+(33*point)+(12*point),clrNONE,SCREEN_UL,sigWinID);
        NewLabel("sigpiv-"+(string)point+":L:","",85,54+(33*point)+(12*point),clrNONE,SCREEN_UL,sigWinID);
        NewLabel("sigpiv-"+(string)point+":Dir","",32,44+(45*point),clrNONE,SCREEN_UL,sigWinID);
      }
    }

    LayoutTemplate();

    return(INIT_SUCCEEDED);
  }