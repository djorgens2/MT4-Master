//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict


#include <manual.mqh>
#include <Class\Fractal.mqh>
#include <Class\PipFractal.mqh>

input string       EAHeader          = "";    //+------ App Config inputs ------+
input int          inpStall          = 6;     // Trend Stall Factor in Periods

input string       FractalHeader     = "";    //+------ Fractal Options ---------+
input int          inpRangeMin       = 60;    // Minimum fractal pip range
input int          inpRangeMax       = 120;   // Maximum fractal pip range


input string       PipMAHeader       = "";    //+------ PipMA inputs ------+
input int          inpDegree         = 6;     // Degree of poly regression
input int          inpPeriods        = 200;   // Number of poly regression periods
input double       inpTolerance      = 0.5;   // Trend change tolerance (sensitivity)
input double       inpAggFactor      = 2.5;   // Tick Aggregate factor (1=1 PIP);
input int          inpIdleTime       = 50;    // Market idle time in Pips

  //--- Class Objects
  CFractal        *f                 = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal     *pf                = new CPipFractal(inpDegree,inpPeriods,inpTolerance,inpAggFactor,inpIdleTime);
  
  bool             PauseOn           = true;
  
  //--- Data Definitions
  enum             TradeStrategy  //--- Trade Strategies
                   {
                     tsHalt,
                     tsRisk,
                     tsScalp,
                     tsHedge,
                     tsHold,
                     tsProfit
                   };

  struct           PivotBox          //-- Price Consolidation Pivots
                   {
                     int             Direction;
                     bool            Broken;
                     int             Count;
                     double          High;
                     double          Low;
                     double          RevHigh;
                     double          RevLow;
                   };

  struct           FractalRecord
                   {
                     TradeStrategy   Strategy;
                     ReservedWords   State;
                     bool            Trigger;
                     double          Root;
                     double          Prior;
                     double          Active;
                     double          TickPush;
                   };
                
  //--- Fractal Variables
  FractalRecord    fr[2];
  double           frTickClose;

  int              frBias;
  int              frTickDir;
  
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
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  { 
    string rsComment   = "-- Manual-v2 --\n  Bias: "+proper(ActionText(frBias))+"\n";
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
      rsComment    += proper(ActionText(action))+" "+EnumToString(fr[action].State)+BoolToStr(fr[action].Trigger,": Trigger")+"\n";

    UpdateLine("mpOS-Root",fr[OP_SELL].Root,STYLE_SOLID,clrFireBrick);
    UpdateLine("mpOS-Prior",fr[OP_SELL].Prior,STYLE_DOT,clrFireBrick);
    UpdateLine("mpOS-Active",fr[OP_SELL].Active,STYLE_DOT,clrFireBrick);
    UpdateLine("mpOS-2Step",fr[OP_SELL].TickPush,STYLE_DASH,clrFireBrick);

    UpdateLine("mpOB-Root",fr[OP_BUY].Root,STYLE_SOLID,clrForestGreen);
    UpdateLine("mpOB-Prior",fr[OP_BUY].Prior,STYLE_DOT,clrForestGreen);
    UpdateLine("mpOB-Active",fr[OP_BUY].Active,STYLE_DOT,clrForestGreen);
    UpdateLine("mpOB-2Step",fr[OP_BUY].TickPush,STYLE_DASH,clrForestGreen);
    
    Comment(rsComment);
//    pf.RefreshScreen();
  }
  
//+------------------------------------------------------------------+
//| UpdateFractal                                                    |
//+------------------------------------------------------------------+
void UpdateFractal(void)
  {
    f.Update();
  }
  
//+------------------------------------------------------------------+
//| UpdatePipMA                                                      |
//+------------------------------------------------------------------+
void UpdatePipMA(void)
  {
    static int uPMATick        = 0;
    
    pf.Update();
    
    if (pf.Event(NewTick))
    {
      if (IsChanged(frTickDir,pf.Direction(Tick)))
        switch (frTickDir)
        {
          case DirectionUp:    //-- Breakout "Kill Switch" (Short)
                               if (IsLower(frTickClose,fr[OP_SELL].Root))
                               {
                                 fr[OP_SELL].Prior       = frTickClose;
                                 fr[OP_SELL].Active      = frTickClose;
                               }
                               else
                               
                               //-- Interior Ranges
                               {
                                 fr[OP_SELL].Prior       = fr[OP_SELL].Active;
                                 fr[OP_SELL].Active      = frTickClose;
                                 fr[OP_SELL].Prior       = fmin(fr[OP_SELL].Prior,frTickClose);
                               }
                               
                               fr[OP_SELL].Root          = fmax(fr[OP_SELL].Root,pf.Range(Bottom));
                               fr[OP_SELL].Prior         = fmax(fr[OP_SELL].Prior,pf.Range(Bottom));
                               fr[OP_SELL].Active        = fmax(fr[OP_SELL].Active,pf.Range(Bottom));

                               break;
                               
          case DirectionDown:  //-- Breakout "Kill Switch" (Long)
                               if (IsHigher(frTickClose,fr[OP_BUY].Root))
                               {
                                 fr[OP_BUY].Prior        = frTickClose;
                                 fr[OP_BUY].Active       = frTickClose;
                               }
                               else
                               
                               //-- Interior Ranges
                               {
                                 fr[OP_BUY].Prior        = fr[OP_BUY].Active;
                                 fr[OP_BUY].Active       = frTickClose;
                                 fr[OP_BUY].Prior        = fmax(fr[OP_BUY].Prior,frTickClose);
                               }

                               fr[OP_BUY].Root           = fmin(fr[OP_BUY].Root,pf.Range(Top));
                               fr[OP_BUY].Prior          = fmin(fr[OP_BUY].Prior,pf.Range(Top));
                               fr[OP_BUY].Active         = fmin(fr[OP_BUY].Active,pf.Range(Top));

                               break;
        }
      else
      if (pf.Count(Tick)==2)
        fr[Action(frTickDir,InDirection,InContrarian)].TickPush  = fr[Action(frTickDir,InDirection,InContrarian)].Active;

      
    
      //-- Not a Breakout
      if (IsBetween(frTickClose,fr[OP_BUY].Root,fr[OP_SELL].Root))
        if (IsEqual(fr[Action(frTickDir,InDirection)].Root,fr[Action(frTickDir,InDirection)].Active))
        //--- Divergence
        {
          fr[OP_BUY].State   = BoolToWord(frTickDir==DirectionUp,Rally,Pullback);
          fr[OP_SELL].State  = BoolToWord(frTickDir==DirectionUp,Rally,Pullback);
        }
        else
          switch(frTickDir)
          {
            case DirectionUp:   if (IsHigher(Close[0],fr[OP_SELL].Active,NoUpdate))
                                  if (IsChanged(frBias,OP_BUY))
                                  {
                                    fr[OP_BUY].Trigger = true;
                                    fr[OP_BUY].State   = Resume;
                                    fr[OP_SELL].State  = Retrace;
                                  }
                                break;

            case DirectionDown: if (IsLower(Close[0],fr[OP_BUY].Active,NoUpdate))
                                  if (IsChanged(frBias,OP_SELL))
                                  {
                                    fr[OP_SELL].Trigger = true;
                                    fr[OP_SELL].State   = Resume;
                                    fr[OP_BUY].State    = Retrace;
                                  }
                                break;
          }
      else
      //-- Breakout
      {
        fr[OP_BUY].State     = BoolToWord(frTickDir==DirectionUp,Breakout,Reversal);
        fr[OP_SELL].State    = BoolToWord(frTickDir==DirectionUp,Reversal,Breakout);
        frBias               = Action(frTickDir,InDirection);
      }
      
      frTickClose            = Close[0];
      PrintTickData (uPMATick++);
      CallPause("New Tick");
    }
  }
  
//+------------------------------------------------------------------+
//| PrintTickData - Prints bar delimited tick data for supplied tick |
//+------------------------------------------------------------------+
void PrintTickData(int Tick)
  {
    string ptdData    = "|"+(string)Tick+"|";
    
    ptdData          += DirText(frTickDir)+"|"+DoubleToStr(frTickClose,Digits)+"|";

  }

//+------------------------------------------------------------------+
//| AnalyzeMarket                                                    |
//+------------------------------------------------------------------+
void AnalyzeMarket(void)
  {

  }

//+------------------------------------------------------------------+
//| ManageOrders                                                     |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {

  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    AnalyzeMarket();
    
    ManageOrders();
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

    UpdateFractal();
    UpdatePipMA();

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
   
    fr[OP_SELL].Root     = Close[0];
    fr[OP_SELL].Prior    = Close[0];
    fr[OP_SELL].Active   = Close[0];
     
    fr[OP_BUY].Root      = Close[0];
    fr[OP_BUY].Prior     = Close[0];
    fr[OP_BUY].Active    = Close[0];
     
    frTickClose          = Close[0];

    NewLine("mpOS-Root");
    NewLine("mpOS-Prior");
    NewLine("mpOS-Active");
    NewLine("mpOS-2Step");

    NewLine("mpOB-Root");
    NewLine("mpOB-Prior");
    NewLine("mpOB-Active");
    NewLine("mpOB-2Step");
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    delete pf;
    
    ObjectDelete("mpOS-Root");
    ObjectDelete("mpOS-Prior");
    ObjectDelete("mpOS-Active");
    ObjectDelete("mpOS-2Step");

    ObjectDelete("mpOB-Root");
    ObjectDelete("mpOB-Prior");
    ObjectDelete("mpOB-Active");
    ObjectDelete("mpOB-2Step");
  }