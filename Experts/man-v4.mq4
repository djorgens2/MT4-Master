//+------------------------------------------------------------------+
//|                                                       man-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\Order.mqh>

input string    EAHeader                = "";    //+---- Application Options -------+
  
input string    fractalHeader           = "";    //+------ Fractal Options ---------+
input int       inpRegressionFactor     = 9;     // Periods
input int       inpSMAFactor            = 3;     // SMA
input double    inpAggregationFactor    = 2.5;   // Tick Aggregation

enum   RegressionMethod
       {
         rmOpen,
         rmHigh,
         rmLow,
         rmClose,
         rmMean
       };

//--- Data Collections

struct SMARec
       {
         int          Direction;
         int          Momentum;
         double       SMA;
         double       High;
         double       Low;
         double       Close;
       };

struct OHLCRec
       {
         int          Direction;
         int          Bias;
         int          Segment;
         bool         Trigger;
         double       Open;
         double       High;
         double       Low;
         double       Close;
       };

struct TickMetrics
       {
         OHLCRec      Tick[];
         OHLCRec      Slope[];
       };

struct SMAMetrics
       {
       };

AccountMetrics  am;
TickMetrics     tm;

//--- Class Objects  
CPipFractal *pf           = new CPipFractal(1,inpRegressionFactor,0.5,inpAggregationFactor,0);
COrder      *order        = new COrder(Discount,Hold,Hold);

//--- Application behavior switches
bool            PauseOn                = true;

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message)
  {
    if (PauseOn)
      Pause(Message,"Event Trapper");
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text  = "\n";
    
    Append(text,SlopeStr(),"\n");
    
    Comment(text);
  }

//+------------------------------------------------------------------+
//| Insert - Insert Regression buffer value                          |
//+------------------------------------------------------------------+
void InsertOHLC(OHLCRec &Buffer[], int Shift)
  {
    for (int idx=Shift-1;idx>0;idx--)
      Buffer[idx]       = Buffer[idx-1];
  }

//+------------------------------------------------------------------+
//| CalcRegression - Calculate Linear Regression; return slope       |
//+------------------------------------------------------------------+
double CalcRegression(RegressionMethod Method)
  {
    //--- Linear regression line
    double m[5]      = {0.00,0.00,0.00,0.00,0.00};   //--- slope
    double b         = 0.00;                         //--- y-intercept
    
    double sumx      = 0.00;
    double sumy      = 0.00;
    
    for (int idx=0;idx<inpRegressionFactor;idx++)
    {
      sumx += idx+1;
      sumy += BoolToDouble(Method==rmOpen,tm.Tick[idx].Open,tm.Tick[idx].Close,Digits);
      
      m[1] += (idx+1)*BoolToDouble(Method==rmOpen,tm.Tick[idx].Open,tm.Tick[idx].Close,Digits);  // Exy
      m[3] += pow(idx+1,2);                          // E(x^2)
    }
    
    m[2]    = fdiv(sumx*sumy,inpRegressionFactor);   // (Ex*Ey)/n
    m[4]    = fdiv(pow(sumx,2),inpRegressionFactor); // [(Ex)^2]/n
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy-m[0]*sumx)/inpRegressionFactor;
    
    return (m[0]*(-1)); //-- inverted tail to head slope
  }

//+------------------------------------------------------------------+
//| InitTick - Resets active tick[0] boundaries                      |
//+------------------------------------------------------------------+
void InitTick(void)
  {
    double smaOpen            = 0.00;
    double smaClose           = 0.00;

    for (int idx=0;idx<inpSMAFactor;idx++)
    {
      smaOpen                += tm.Tick[idx].Open;
      smaClose               += tm.Tick[idx].Close;
    }

    tm.Tick[0].SMA           = fdiv(smaClose,inpSMAFactor,8)-fdiv(smaOpen,inpSMAFactor,8);

    Print(OHLCStr(tm.Tick[0]));
    
    InsertOHLC(tm.Tick,inpRegressionFactor);

    tm.Tick[0].Open           = Close[0];
    tm.Tick[0].High           = Close[0];
    tm.Tick[0].Low            = Close[0];
    tm.Tick[0].Close          = NoValue;

    if (IsHigher(tm.Tick[0].Open,tm.Tick[1].High,NoUpdate))
    {
      tm.Tick[0].Direction    = DirectionUp;
      tm.Tick[0].Bias         = OP_BUY;
    }
    else
    if (IsLower(tm.Tick[0].Open,tm.Tick[1].Low,NoUpdate))
    {
      tm.Tick[0].Direction    = DirectionDown;
      tm.Tick[0].Bias         = OP_SELL;
    } else CallPause("WTF, in-range Tick?");
    
    if (IsEqual(tm.Tick[0].Bias,tm.Tick[1].Bias))
      tm.Tick[0].Segment      = tm.Tick[1].Segment;
    else
      tm.Tick[0].Segment      = NoValue;

    tm.Tick[0].Trigger        = IsEqual(tm.Tick[0].Direction,Direction(tm.Tick[0].Bias,InAction));
  }

//+------------------------------------------------------------------+
//| UpdateSlope - Computes slope aggregate detail                    |
//+------------------------------------------------------------------+
void UpdateSlope(void)
  {
    static int pfbar          = 0;
    double sma                = 0.00;

    if (IsChanged(pfbar,Bars))
      InsertOHLC(tm.Slope,inpSMAFactor);
      
    tm.Slope[0].Trigger       = false;
    tm.Slope[0].Open          = CalcRegression(rmOpen);
    tm.Slope[0].Close         = CalcRegression(rmClose);

    for (int idx=0;idx<inpSMAFactor;idx++)
      sma                    += NormalizeDouble(tm.Slope[idx].Open+tm.Slope[idx].Close,8);

    tm.Slope[0].SMA           = fdiv(sma,inpSMAFactor);
  }

//+------------------------------------------------------------------+
//| UpdatePipMA - refreshes indicator data                           |
//+------------------------------------------------------------------+
void UpdatePipMA(void)
  {
    static double lastClose   = Close[0];
    
    pf.Update();
    
    if (pf.Event(NewTick))
    {
      tm.Tick[0].Close        = lastClose;

      UpdateSlope();
      InitTick();      
    }
    
    tm.Tick[0].High           = fmax(Close[0],tm.Tick[0].High);
    tm.Tick[0].Low            = fmin(Close[0],tm.Tick[0].Low);

    lastClose                 = Close[0];
  }

//+------------------------------------------------------------------+
//| UpdateOrder - refreshes order data                               |
//+------------------------------------------------------------------+
void UpdateOrder(void)
  {
    order.Update(am);
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {            
    UpdatePipMA();
    UpdateOrder();
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (pf.Event(NewTick))
      CallPause(SlopeStr());
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="PAUSE")
        PauseOn    = true;

    if (Command[0]=="PLAY")
        PauseOn    = false;
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
    GetData();

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

    ArrayResize(tm.Tick,inpRegressionFactor);
    ArrayResize(tm.Slope,inpSMAFactor);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pf;
    delete order;
  }

//+------------------------------------------------------------------+
//| OHLCStr - Returns formatted OHLC data                            |
//+------------------------------------------------------------------+
string OHLCStr(OHLCRec &OHLC)
  {
    string text   = "";

    Append(text,TimeToStr(Time[0]),"|");
    Append(text,DirText(OHLC.Direction),"|");
    Append(text,ActionText(OHLC.Bias),"|");
    Append(text,(string)OHLC.Segment,"|");
    Append(text,BoolToStr(OHLC.Trigger,"Armed","Off"),"|");
    Append(text,DoubleToStr(OHLC.Open,Digits),"|");
    Append(text,DoubleToStr(OHLC.High,Digits),"|");
    Append(text,DoubleToStr(OHLC.Low,Digits),"|");
    Append(text,DoubleToStr(OHLC.Close,Digits),"|");
    Append(text,DoubleToStr(OHLC.SMA,8),"|");
    
    return (text);
  }

//+------------------------------------------------------------------+
//| SlopeStr - Returns formatted slope data                          |
//+------------------------------------------------------------------+
string SlopeStr(void)
  {
    string text   = "\n";
    
    Append(text,TimeToStr(Time[0]),"\n");
    Append(text,"Open: "+DoubleToStr(tm.Slope[0].Open),"\n");
    Append(text,"Close: "+DoubleToStr(tm.Slope[0].Close),"\n");
    Append(text,"Slope: "+DoubleToStr(tm.Slope[2].Open+tm.Slope[2].Close),"\n");
    Append(text,DoubleToStr(tm.Slope[1].Open+tm.Slope[1].Close),":");
    Append(text,DoubleToStr(tm.Slope[0].Open+tm.Slope[0].Close),":");
    Append(text,"MA: "+DoubleToStr(tm.Slope[0].SMA),"\n");
    
    return (text);
  }
