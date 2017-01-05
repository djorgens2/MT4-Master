//+------------------------------------------------------------------+
//|                                                       man-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "3.05"
#property strict

#include <Class\PipFractal.mqh>
#include <Class\TrendRegression.mqh>
#include <manual.mqh>

input string appHeader               = "";    //+------ App Inputs -------+
input bool   inpShowFiboLines        = false;

input string prHeader                = "";    //+---- Regression Inputs -----+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpSTPeriods            = 200;   // Short Term (Pip) periods
input int    inpMTPeriods            = 24;    // Mid Term (Trend) periods
input int    inpLTPeriods            = 120;   // Long Term (Poly) periods
input int    inpSmoothFactor         = 3;     // Moving Average smoothing factor
input double inpTolerance            = 0.5;   // Trend change sensitivity

input string fractalHeader           = "";    //+------ Fractal inputs ------+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

//--- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpSTPeriods,inpTolerance,fractal);
  CTrendRegression *trend            = new CTrendRegression(inpDegree,inpMTPeriods,inpSmoothFactor);
  CPolyRegression  *poly             = new CPolyRegression(inpDegree,inpLTPeriods,inpSmoothFactor);

  enum   AlertTypes  {
                       MajorTerm,
                       StdDev161,
                       StdDevDir,
                       CloseDir,
                       PipMAPolyDir,
                       PipMATradeAction,
                       BoundaryTrend,
                       BoundaryTerm,
                       pfTermFibo,
                       pfTermDir,
                       pfTrendFibo,
                       pfTrendDir,
                       pfTermConfirm,
                       pfTrendConfirm,
                       prPolyMeanDir,
                       pfDivergentTrend,
                       AlertCount   //--- do not reposition
                     };
                     
  struct AlertRecord {
                       AlertTypes   Type;
                       double       Price;
                       RetraceType  Leg;
                       int          FiboLevel;
                       int          Direction;
                       datetime     OpenTime;
                       datetime     CloseTime;
                     };
                     
  int appShowLines   = NoValue;
  
//+------------------------------------------------------------------+
//+ Operational variables                                            |
//+    al:  Analyst                                                  |
//+    om:  Order Management                                         |
//+    rm:  Risk Management                                          |
//+    pm:  Profit Management                                        |
//+------------------------------------------------------------------+
  
  //--- Analyst: Major Term Fibo Level/Prices
  AlertRecord   alAlertLog[];  
  bool          alAlert[AlertCount];                                //--- Alerts activated this tick
  double        alFibo[20];
  int           alFiboDir[20];
  int           alFiboNow                   = FiboRoot;             //--- Current FiboLevel
  int           alFiboTermDir               = DirectionNone;        //--- PipFractal: Minor Term
  int           alFiboTrendDir              = DirectionNone;        //--- PipFractal: Major Term
  int           alPolyMeanDir               = DirectionNone;        //--- Poly: Current Price/PolyMean dir

  //--- Analyst: Alert elements
  double        alStdDev161                 = 0.00;                 //--- 161 Channel half-size
  double        alStdDevMax                 = 0.00;                 //--- Used to test for stddev dir changes
  double        alStdDevTop                 = 0.00;                 //--- 161 Channel Top (Now)
  double        alStdDevBottom              = 0.00;                 //--- 161 Channel Bottom (Now)
  int           alCloseDir                  = DirectionNone;        //--- RegrMA: Last close direction
  int           alStdDevDir                 = DirectionNone;        //--- Last dir where stddev == max
  int           alStdDev161Dir              = DirectionNone;        //--- Last dir where bid broke the stddev(top/bottom)
  int           alTradeDir                  = DirectionNone;        //--- pf: Contrarian direction
  int           alTradeAction               = OP_NO_ACTION;         //--- pf: Trade action based on poly/price/trend


  //--- Order Manager
  bool          omAlert[AlertCount];                                //--- Order Manager monitored alerts 
  AlertRecord   omAlertLog[];                                       //--- Order Manager active alerts
  OpenOptions   omOpenOption                = OpenSingle;           //--- Order Manager lot size
  double        omNormalSpread              = Spread();             //--- Normal spread used to derive order fibo levels
  double        omTrailPips                 = 0.00;

  bool          pmAlert[AlertCount];                                //--- Profit Manager monitored alerts 
  AlertRecord   pmAlertLog[];                                       //--- Profit Manager active alerts
  CloseOptions  pmCloseOption               = CloseHalf;            //--- Profit manager current close option
  
  bool          rmAlert[AlertCount];                                //--- Risk Manager monitored alerts 
  AlertRecord   rmAlertLog[];                                       //--- Risk Manager active alerts
  CloseOptions  rmCloseOption               = CloseMin;             //--- Risk manager current close option
  
//+------------------------------------------------------------------+
//| RefreshScreen - updates screen data                              |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string     rsFractal        = "";

    if (pfractal.Trendline(Head)>trend.Trendline(Head))
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrYellow);
    else
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrRed);

    if (pfractal.Poly(Head)>poly.Poly(Head))
      UpdatePriceLabel("pipMAPoly",pfractal.Poly(Head),clrYellow);
    else
      UpdatePriceLabel("pipMAPoly",pfractal.Poly(Head),clrRed);

    UpdateLabel("alTradeAction",ActionText(alTradeAction),DirColor(ActionDir(alTradeAction)));
      
    ShowFiboLines();
    SetFiboArrow(pfractal.Direction(Term));
    
    UpdateDirection("alCloseDir",alCloseDir,DirColor(alCloseDir));
    UpdateDirection("alStdDev161Dir",alStdDev161Dir,DirColor(alStdDev161Dir));
    UpdateDirection("alStdDevDir",alStdDevDir,DirColor(alStdDevDir));
    UpdateDirection("alOriginDir",pfractal.Direction(Origin),DirColor(pfractal.Direction(Origin)));

    rsFractal += "Pattern: Minor "+EnumToString(fractal.State(Minor))+"\n";
    rsFractal += "Base "+EnumToString(fractal.Leg(Base,Peg))
        +"  (rt): "+DoubleToStr(fractal.Fibonacci(Base,Retrace,Now,InPercent),1)+"%"
        +"  "+DoubleToStr(fractal.Fibonacci(Base,Retrace,Max,InPercent),1)+"%"
        +BoolToStr(IsEqual(fractal[Base].Price,0.00),"",
          +"  (e): "+DoubleToStr(fractal.Fibonacci(Base,Expansion,Now,InPercent),1)+"%"
          +"  "+DoubleToStr(fractal.Fibonacci(Base,Expansion,Max,InPercent),1)+"%\n");
        
    for (RetraceType fibo=Expansion;fibo<RetraceTypeMembers;fibo++)
      if (fractal.Leg(fibo,Level)==Max)
        rsFractal += EnumToString(fibo)
            +" ("+DirText(fractal.Direction(fibo))+") Range: "+DoubleToStr(Pip(fractal.Range(fibo,Max)),1)
            +"  (rt): "+DoubleToStr(fractal.Fibonacci(fibo,Retrace,Now,InPercent),1)+"%"
            +"  "+DoubleToStr(fractal.Fibonacci(fibo,Retrace,Max,InPercent),1)+"%"
            +"  (e): "+DoubleToStr(fractal.Fibonacci(fibo,Expansion,Now,InPercent),1)+"%" 
            +"  "+DoubleToStr(fractal.Fibonacci(fibo,Expansion,Max,InPercent),1)+"%\n";

    //--- Standard Deviation (161) channel lines
    UpdateRay("stdDevHigh",trend.Trendline(Tail)+alStdDev161,inpMTPeriods-1,trend.Trendline(Head)+alStdDev161,0,STYLE_DOT,clrYellow);
    UpdateRay("stdDevLow",trend.Trendline(Tail)-alStdDev161,inpMTPeriods-1,trend.Trendline(Head)-alStdDev161,0,STYLE_DOT,clrRed);
    
    //--- Show active order limit/mit entry
    if (ordLimitTrigger)
    {
      if (ordLimitAction==OP_BUY)
        UpdateLine("ordTrail",NormalizeDouble(ordLimitPrice+(ordLimitTrail*2),Digits),STYLE_DOT,clrForestGreen);
      else
      if (ordLimitAction==OP_SELL)
        UpdateLine("ordTrail",NormalizeDouble(ordLimitPrice-(ordLimitTrail*2),Digits),STYLE_DOT,clrCrimson);
    }
    else

    if (ordMITTrigger)
      UpdateLine("ordTrail",NormalizeDouble(ordMITPrice,Digits),STYLE_DOT,DirColor(ActionDir(ordMITAction)));

    else
    if (OrderPending())
      if (IsEqual(ordLimitPrice,0.00))
        UpdateLine("ordTrail",ordMITPrice,STYLE_SOLID,DirColor(ActionDir(ordMITAction)));
      else
        UpdateLine("ordTrail",ordLimitPrice,STYLE_SOLID,DirColor(ActionDir(ordLimitAction)));

    else
      UpdateLine("ordTrail",0.00,STYLE_DOT,clrGray);    
    

    Comment("*--- PipFractal ---*\n"
           +"pf(tm): "+DirText(pfractal[Term].Direction)
           +"  (rt): "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Retrace,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Retrace,Max,InPercent),1)+"%"
           +"  (e): "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Max,InPercent),1)+"%\n"
           +"pf(tr): "+DirText(pfractal[Trend].Direction)
           +"  (rt): "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Retrace,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Retrace,Max,InPercent),1)+"%"
           +"  (e): "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Max,InPercent),1)+"%\n"
           +"pf(o): "+DirText(pfractal.Direction(Origin))
           +"  (rt): "+DoubleToStr(pfractal.Fibonacci(Origin,pfractal.Direction(Origin),Retrace,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Origin,pfractal.Direction(Origin),Retrace,Max,InPercent),1)+"%"
           +"  (e): "+DoubleToStr(pfractal.Fibonacci(Origin,pfractal.Direction(Origin),Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Origin,pfractal.Direction(Origin),Expansion,Max,InPercent),1)+"%\n"
           +"\n*--- Major Fractal ---*\n"
           +"Pattern: "+EnumToString(fractal.Leg(Expansion,Peg))+"\n"
           +"Term ("+DirText(fractal.Direction(Term))+") Range: "+DoubleToStr(Pip(fractal.Range(Term,Max)),1)
           +"  (rt): "+DoubleToStr(fractal.Fibonacci(Term,Retrace,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(fractal.Fibonacci(Term,Retrace,Max,InPercent),1)+"%"
           +"  (e): "+DoubleToStr(fractal.Fibonacci(Term,Expansion,Now,InPercent),1)+"%" 
           +"  "+DoubleToStr(fractal.Fibonacci(Term,Expansion,Max,InPercent),1)+"%\n"
           +"Trend ("+DirText(fractal.Direction(Trend))+") Range: "+DoubleToStr(Pip(fractal.Range(Trend,Max)),1)
           +"  (rt): "+DoubleToStr(fractal.Fibonacci(Trend,Retrace,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(fractal.Fibonacci(Trend,Retrace,Max,InPercent),1)+"%"
           +"  (e): "+DoubleToStr(fractal.Fibonacci(Trend,Expansion,Now,InPercent),1)+"%" 
           +"  "+DoubleToStr(fractal.Fibonacci(Trend,Expansion,Max,InPercent),1)+"%\n"
           +"\n*--- Minor Fractal ---*\n"
           +rsFractal+"\n"
           );    
  }

//+------------------------------------------------------------------+
//| AlertType - converts text to alert type                          |
//+------------------------------------------------------------------+
AlertTypes AlertType(string Type)
  {
    for (AlertTypes alert=0;alert<AlertCount;alert++)
      if (upper(Type)==upper(EnumToString(alert)))
        return (alert);
        
    return (AlertCount);
  }
  
//+------------------------------------------------------------------+
//| AlertAction - converts text to alert action                      |
//+------------------------------------------------------------------+
bool AlertAction(string Action)
  {
    if (Action=="ENABLE")
      return(true);
      
    return (false);
  }
  
//+------------------------------------------------------------------+
//| AlertText - returns the text description of the alert            |
//+------------------------------------------------------------------+
string AlertText(AlertTypes Type)
  {
    switch (Type)
    {
      case MajorTerm:          return("Major Fractal(Term) Change");
      case pfTermDir:          return("Term Reversal");                      
      case pfTermFibo:         return("Term Fibonacci");                      
      case pfTermConfirm:      return("Term Confirm");
      case pfTrendDir:         return("Trend Reversal");
      case pfTrendFibo:        return("Trend Fibonacci");
      case pfTrendConfirm:     return("Trend Confirm");
      case pfDivergentTrend:   return("Divergent");
      case StdDev161:          return("StdDev(161) Channel Breakout");
      case StdDevDir:          return("StdDev(161) Channel Reversal");
      case CloseDir:           return("Close Direction Change");
      case PipMAPolyDir:       return("Poly(PipMA) Direction Change");
      case PipMATradeAction:   return("PipMA Trade Action");
      case BoundaryTrend:      return("PipMA Trend Continuation");
      case BoundaryTerm:       return("PipMA Term Pullback/Rally");
      case prPolyMeanDir:      return("Poly Trend Breakout");
    }

    return ("Bad Alert Type");
  }

//+------------------------------------------------------------------+
//| NewAlert - formats and publishes a new alert                     |
//+------------------------------------------------------------------+
void NewAlert(AlertRecord &Log[], AlertTypes Type, RetraceType Leg, int FiboLevel, int AlertDir)
  {
    int    naAlert   = ArraySize(Log);
    
      ArrayResize(Log,naAlert+1);
      
      Log[naAlert].Type      = Type;      
      Log[naAlert].Price     = Close[0];      
      Log[naAlert].Leg       = Leg;
      Log[naAlert].FiboLevel = FiboLevel;
      Log[naAlert].Direction = AlertDir;
      Log[naAlert].OpenTime  = TimeCurrent();
      Log[naAlert].CloseTime = 0;
  }

//+------------------------------------------------------------------+
//| CloseAlert - closes open alerts                                  |
//+------------------------------------------------------------------+
void CloseAlert(AlertRecord &Log[], AlertTypes Type=AlertCount)
  {
    for (int alert=0; alert<ArraySize(Log); alert++)
      if (Log[alert].CloseTime == 0)
        if (Log[alert].Type==Type || Type==AlertCount)
          Log[alert].CloseTime = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| PurgeAlert - Removes closed (processed) alerts                   |
//+------------------------------------------------------------------+
void PurgeAlert(AlertRecord &Log[], int Retention)
  {
    AlertRecord paLog[];
    
    if (ArraySize(Log)==0)
      return;

    for (int alert=0; alert<ArraySize(Log); alert++)
      if (Log[alert].CloseTime == 0)
      {
        ArrayResize(paLog,ArraySize(paLog)+1);
        paLog[ArraySize(paLog)-1] = Log[alert];
      }
      
    ArrayResize(Log,ArraySize(paLog));
    ArrayCopy(Log,paLog);
  }

//+------------------------------------------------------------------+
//| ActiveAlert - Returns true on alert on the supplied log and type |
//+------------------------------------------------------------------+
bool ActiveAlert(AlertRecord &Log[], AlertTypes Type=AlertCount)
  {
    int aaLogSize  = ArraySize(Log);
    
    if (aaLogSize==0)
      return (false);

    for (int alert=0;alert<aaLogSize;alert++)
      if (Type==Log[alert].Type || Type==AlertCount)
        if (Log[alert].CloseTime == 0)
          return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| GetAlert - Returns the most current alert index for the type     |
//+------------------------------------------------------------------+
int GetAlert(AlertRecord &Log[], AlertTypes Type)
  {
    int gaIndex = NoValue;
    
    int aaLogSize  = ArraySize(Log);
    
    if (aaLogSize==0)
      return (false);

    for (int alert=0;alert<aaLogSize;alert++)
      if (Type==Log[alert].Type)
        if (Log[alert].CloseTime == 0)
          gaIndex = alert;
          
    return (gaIndex);
  }

//+------------------------------------------------------------------+
//| ShowAlertLog - Displays the Alerts for the specified log         |
//+------------------------------------------------------------------+
void ShowAlertLog(AlertRecord &Log[], bool &Alerts[], string Title)
  {
    string saMessage = "";
    bool   saAlert   = false;
    
    if (ArraySize(Log)==0)
      return;
      
    for (int alert=0;alert<ArraySize(Log);alert++)
      if (Log[alert].CloseTime==0)
        if (Alerts[Log[alert].Type])
        {
          saAlert    = true;
          saMessage += EnumToString(Log[alert].Type)
                    +": "+DirText(Log[alert].Direction)
                    +" "+TimeToStr(Log[alert].OpenTime)
                    +" "+DoubleToStr(Log[alert].Price,Digits)
                    +"\n  "+AlertText(Log[alert].Type)
                    +" "+EnumToString(Log[alert].Leg)
                    +" ("+DoubleToStr(FiboPercent(Log[alert].FiboLevel,InPercent),1)+"%)\n\n";
        }

   if (saAlert)
    if (LotCount()>0.00)
      ShowTrades(saMessage,Title);
    else
      Pause(saMessage,Title);
//   else
//     Pause("No Active Alerts",Title);
  }

//+------------------------------------------------------------------+
//| ShowAlert - Formats and presents alerts by log type              |
//+------------------------------------------------------------------+
void ShowAlerts(AlertTypes Type)
  {
    string     saState  = "";
      
    if (Type == AlertCount)
      for (AlertTypes alert=0; alert<AlertCount; alert++)
        saState += "\n"+EnumToString(alert)+" ("+BoolToStr(alAlert[alert],"Enabled","Disabled")+")"
                  +BoolToStr(omAlert[alert],"  Order")
                  +BoolToStr(pmAlert[alert],"  Profit")
                  +BoolToStr(rmAlert[alert],"  Risk");
    else
      saState += "\n"+EnumToString(Type)+" ("+BoolToStr(alAlert[Type],"Enabled","Disabled")+")"
                  +BoolToStr(omAlert[Type],"  Order")
                  +BoolToStr(pmAlert[Type],"  Profit")
                  +BoolToStr(rmAlert[Type],"  Risk");

    Pause("Alert Settings:\n-------------------------"+saState,"Alert Settings");
  }
  
//+------------------------------------------------------------------+
//| SetAlertOption - sets the option for the alert                   |
//+------------------------------------------------------------------+
void SetAlertOption(OpenOptions &Options[], AlertTypes Type, OpenOptions Option)
  {    
    if (Type == AlertCount)
      ArrayInitialize(Options,Option);
    else
      Options[Type] = Option;
  }
  
//+------------------------------------------------------------------+
//| SetAlertOption - sets the option for the alert                   |
//+------------------------------------------------------------------+
void SetAlertOption(CloseOptions &Options[], AlertTypes Type, CloseOptions Option)
  {
    if (Type == AlertCount)
      ArrayInitialize(Options,Option);
    else
      Options[Type] = Option;
  }

//+------------------------------------------------------------------+
//| SetAlert - enables/disables alerts                               |
//+------------------------------------------------------------------+
void SetAlert(bool &Alerts[], AlertTypes Type, bool Enable)
  {    
    if (Type == AlertCount)
      ArrayInitialize(Alerts,Enable);
    else
      Alerts[Type] = Enable;
  }
    
//+------------------------------------------------------------------+
//| FormatOrder - formats the order line diplayed in the messagebox  |
//+------------------------------------------------------------------+
string FormatOrder(int Ticket)
  {
    string foDetail   = "";
    
    if (OrderSelect(Ticket,SELECT_BY_TICKET))
      foDetail +=BoolToStr(OrderType()==OP_BUY,"L","S")
               +LPad(IntegerToString(Ticket)," ",9)
               +" "+LPad(OrderSymbol()," ",8)
               +"   "+LPad(DoubleToStr(OrderOpenPrice(),Digits)," ",Digits+2)
               +"   "+LPad(DoubleToStr(OrderLots(),ordLotPrecision)," ",ordLotPrecision+2)
               +"   "+LPad(DoubleToStr(OrderCommission(),2)," ",6)
               +"   "+LPad(NegLPad(OrderSwap(),2)," ",7)
               +"  "+LPad(DoubleToStr(TicketValue(Ticket),2)," ",11)
               +"/"+DoubleToStr(TicketValue(Ticket,InEquity),1)
               +"%";

    return (foDetail);
  }
  
//+------------------------------------------------------------------+
//| ShowTrades - Opens a dialogue box with open trade values         |
//+------------------------------------------------------------------+
void ShowTrades(string Message, string Title="Application Show Trade")
  {
    string stComment           = "No Active Trades";
    string stShort             = "";
    string stLong              = "";
    
    int    stMinTicket[2]      = {0,0};
    double stMinValue[2]       = {0.00,0.00};
    
    orderRefreshScreen();
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS))
        if (OrderSymbol()==Symbol())
          if (OrderType()==OP_BUY||OrderType()==OP_SELL)
          {
            if (stMinTicket[OrderType()]==0)
              stMinTicket[OrderType()] = OrderTicket();
            else
              stMinTicket[OrderType()]=BoolToInt(TicketValue(OrderTicket())<stMinValue[OrderType()],OrderTicket(),stMinTicket[OrderType()]);

            switch (OrderType())
            {
              case OP_BUY:  stLong  += FormatOrder(OrderTicket())+"\n";
                            break;
              case OP_SELL: stShort += FormatOrder(OrderTicket())+"\n";
            }
          }
        
    if (LotCount()>0.00)
      stComment = " Ticket   Symbol      Open    Lots    Com     Swap       Profit(Val/%)\n"
                 +stShort+stLong+"\n"
                 +"Minimum Tickets"
                 +BoolToStr(stMinTicket[OP_BUY]>0,"\n"+FormatOrder(stMinTicket[OP_BUY]))
                 +BoolToStr(stMinTicket[OP_SELL]>0,"\n"+FormatOrder(stMinTicket[OP_SELL]))
                 +"\n\nBalance: "+DoubleToStr(AccountBalance()+AccountCredit(),2)
                 +"\nEquity: "+DoubleToStr(AccountEquity(),2)
                 +" ("+DoubleToStr(EquityPercent(),1)+"%)";

    Pause(BoolToStr(StringLen(Message)>0,Message+"_____________________________________________________________________\n\n")+stComment,
         Title);
  }

//+------------------------------------------------------------------+
//| ShowFiboLines - Paints the fibo lines                            |
//+------------------------------------------------------------------+
void ShowFiboLines(void)
  {
    int    sflStyle        = STYLE_DOT;
    int    sflColor        = clrGray;
    int    sflFiboExt      = FiboRoot;

    for (int fibo=-Fibo261;fibo<Fibo423;fibo++)
    {
      sflStyle   = STYLE_DOT;

      switch (fibo)
      {
        case FiboRoot:
        case Fibo100:   sflColor = clrWhite;
                        break;

        case -Fibo50:   sflStyle = STYLE_SOLID;
        case Fibo50:    sflColor = clrSteelBlue;
                        break;

        case -Fibo100:
        case -Fibo61:   sflStyle = STYLE_SOLID;
                        sflColor = clrGoldenrod;
                        break;

        case Fibo161:   sflStyle = STYLE_SOLID;
                        sflColor = clrRed;
                        break;

        case -Fibo261:
        case Fibo261:   sflStyle = STYLE_SOLID;
                        sflColor = clrYellow;
                        break;

        default:        sflColor = BoolToInt(fibo>0,clrMaroon,clrForestGreen);
      }

      sflFiboExt = FiboLevel(FiboPercent(fibo),Extended);
      
      if (appShowLines==Fibonacci)
        UpdateLine("fp"+IntegerToString(sflFiboExt),alFibo[sflFiboExt],sflStyle,sflColor);
      else
        UpdateLine("fp"+IntegerToString(sflFiboExt),0.00,sflStyle,sflColor);
    }

    if (appShowLines==NoValue)
    {
      UpdateLine("fFiboBase",0.00,STYLE_SOLID,clrRed);
      UpdateLine("fFiboRoot",0.00,STYLE_SOLID,clrGoldenrod);
      UpdateLine("fFiboExpansion",0.00,STYLE_SOLID,clrSteelBlue);
      UpdateLine("fFiboRetrace",0.00,STYLE_DOT,clrGray);
    }
    else
    if (appShowLines!=Fibonacci)
    {
      UpdateLine("fFiboBase",pfractal.Price(appShowLines,Base),STYLE_SOLID,clrRed);
      UpdateLine("fFiboRoot",pfractal.Price(appShowLines,Root),STYLE_SOLID,clrGoldenrod);
      UpdateLine("fFiboExpansion",pfractal.Price(appShowLines,Expansion),STYLE_SOLID,clrSteelBlue);
      UpdateLine("fFiboRetrace",pfractal.Price(appShowLines,Retrace),STYLE_DOT,clrGray);
    }
  }

//+------------------------------------------------------------------+
//| SetFiboArrow - paints the pipMA zero arrow                       |
//+------------------------------------------------------------------+
void SetFiboArrow(int Direction)
  {
    static string    arrowName      = "";
    static int       arrowDir       = DirectionNone;
    static double    arrowPrice     = 0.00;
           uchar     arrowCode      = SYMBOL_DASH;

    if (IsChanged(arrowDir,Direction))
    {
      arrowPrice                    = Close[0];
      arrowName                     = NewArrow(arrowCode,DirColor(arrowDir,clrYellow),DirText(arrowDir),arrowPrice);
    }
     
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboPercent(Fibo823))
      arrowCode                     = SYMBOL_POINT4;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboPercent(Fibo423))
      arrowCode                     = SYMBOL_POINT3;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboPercent(Fibo261))
      arrowCode                     = SYMBOL_POINT2;
    else  
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboPercent(Fibo161))
      arrowCode                     = SYMBOL_POINT1;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboPercent(Fibo100))
      arrowCode                     = SYMBOL_CHECKSIGN;
    else
      arrowCode                     = SYMBOL_DASH;

    switch (Direction)
    {
      case DirectionUp:    if (IsChanged(arrowPrice,fmax(arrowPrice,Close[0])))
                             UpdateArrow(arrowName,arrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                           break;
      case DirectionDown:  if (IsChanged(arrowPrice,fmin(arrowPrice,Close[0])))
                             UpdateArrow(arrowName,arrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                           break;
    }
  }

//+------------------------------------------------------------------+
//| GetData - retrieve and organize operational data                 |
//+------------------------------------------------------------------+
void GetData(void)
  {  
    fractal.Update();
    pfractal.Update();
    trend.Update();
    poly.Update();
  }
  
//+------------------------------------------------------------------+
//| CalcFibo - Computes the fibo matrix                              |
//+------------------------------------------------------------------+
void CalcFibo(void)
  {
    static int cfLastFibo  = 20;
    
    int    cfFiboNow       = alFiboNow;
    int    cfFiboExt       = FiboRoot;
    
    double cfFiboBase      = fractal[Base].Price;
    double cfFiboRoot      = fractal[Root].Price;
    
    alFiboNow              = Fibo823;
    alStdDev161            = trend.StdDev(Max)*FiboPercent(Fibo161);

    if (fractal.Fibonacci(Base,Expansion,Max)>FiboPercent(Fibo261) || IsEqual(fractal[Base].Price,0.00))
    {
      cfFiboBase           = fractal[Expansion].Price;
      cfFiboRoot           = fractal[Expansion].Price+BoolToDouble(fractal.Direction()==DirectionUp,-Pip(inpRangeMax,InPoints),Pip(inpRangeMax,InPoints));
    }
    
    for (int fibo=-Fibo823;fibo<=Fibo823;fibo++)
    {
      cfFiboExt            = FiboLevel(FiboPercent(fibo),Extended);
      alFibo[cfFiboExt]    = FiboPrice(cfFiboExt,cfFiboBase,cfFiboRoot,Retrace);
      
      if (fractal[Expansion].Direction == DirectionUp)
        if (Close[0]>alFibo[FiboExt(fibo)])
          alFiboNow        = fmin(fibo,alFiboNow);

      if (fractal[Expansion].Direction == DirectionDown)
        if (Close[0]<alFibo[FiboExt(fibo)])
          alFiboNow        = fmin(fibo,alFiboNow);
    }
    
    if (IsChanged(cfLastFibo,alFiboNow))
    {
      if (cfFiboNow>alFiboNow)
        alFiboDir[FiboExt(alFiboNow)] = DirectionUp;

      if (cfFiboNow<alFiboNow)
        alFiboDir[FiboExt(alFiboNow)] = DirectionDown;        
    }
  }

//+------------------------------------------------------------------+
//| MarketAnalysis - analyze market data and set alerts              |
//+------------------------------------------------------------------+
void MarketAnalysis(void)
  {
    static int         maBarsTotal         = Bars;
    static RetraceType maMajorTermLeg      = Expansion;
    static bool        maOnInit            = false;
    static bool        maMajorTermAlert    = false;
    static bool        maStdDevAlert       = false;
    static bool        maPolyMeanDirAlert  = false;
    static bool        maPipMABoundary[2]  = {false,false};
    static int         maPFFibo[2]         = {Fibo100,Fibo100};
    static int         maPFDir[2]          = {DirectionNone,DirectionNone};
    static int         maCloseDir          = DirectionNone;
    static int         maStdDevDir         = DirectionNone;
    static int         maPolyDir           = DirectionNone;
    static int         maTermDir           = DirectionNone;
    static int         maTradeAction       = OP_NO_ACTION;
    static int         maDivTrendFibo      = Fibo50;
    
    double             maStdDev161         = 0.00;
    double             maRegrPrice         = trend.Trendline(Head);
      
    //--- Initialize after first History Load tick
    if (pfractal.Event(HistoryLoaded))
      if (maOnInit)
        ArrayResize(alAlertLog,0);
      else
      {
        alFiboTrendDir     = fractal.Direction(fractal.State(Max));
        maOnInit           = true;
      }
    
    //--- Calc fibonaccis
    CalcFibo();

    //--- Alert: CloseDir
    if (IsChanged(maBarsTotal,Bars))
    {      
      if (IsHigher(Open[0],maRegrPrice))
        alCloseDir   = DirectionUp;

      if (IsLower(Open[0],maRegrPrice))
        alCloseDir   = DirectionDown;

      if (IsChanged(maCloseDir,alCloseDir))
        NewAlert(alAlertLog, CloseDir, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), alCloseDir);
    }

    //--- Potential Alert: StdDevDir
    if (IsEqual(fabs(trend.StdDev(Now)),trend.StdDev(Max)))
    {
      alStdDevDir          = trend.Direction(StdDev);
      alStdDevMax          = trend.StdDev(Max);
    }

    //--- Alert: MajorTerm
    if (maMajorTermLeg != fractal.State(Now))
    {
      maMajorTermLeg       = fractal.State(Now);
      maMajorTermAlert     = false;
    }

    if (!maMajorTermAlert)      
      if (fractal.Leg(maMajorTermLeg,Level)==Max)
      {
        NewAlert(alAlertLog, MajorTerm, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.Previous(fractal.State(Max)),Retrace,Max)), fractal.Direction(fractal.State(Max)));
        maMajorTermAlert   = true;
      }

    //--- Std Deviation (161) alerts
    if (pfractal.Event(NewBoundary))
    {      
      //--- Alert: StdDev161 (Channel Breakout)
      if (pfractal.Event(NewHigh))
      {
        if (pfractal.Direction(Polyline)==DirectionUp)
        {
          maStdDev161          = trend.Trendline(Head)+alStdDev161;
          alStdDevTop          = maStdDev161;
                  
          if (IsHigher(Close[0],maStdDev161))
            if (!maStdDevAlert)
            {
              NewAlert(alAlertLog, StdDev161, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), DirectionUp);
              maStdDevAlert    = true;
              alStdDev161Dir   = DirectionUp;
            }
        }
      }

      //--- Alert: StdDev161 (Channel Breakout)
      if (pfractal.Event(NewLow))
        if (pfractal.Direction(Polyline)==DirectionDown)
        {
          maStdDev161          = trend.Trendline(Head)-alStdDev161;
          alStdDevBottom       = maStdDev161;
          
          if (IsLower(Close[0],maStdDev161))
            if (!maStdDevAlert)
             {
              NewAlert(alAlertLog, StdDev161, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), DirectionDown);
              maStdDevAlert    = true;
              alStdDev161Dir   = DirectionDown;
            }
        }

      //--- Alert: StdDev161Dir (Channel Breakout caused by a StdDevDir change)
      if (IsChanged(maStdDevDir,alStdDev161Dir))
        NewAlert(alAlertLog, StdDevDir, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), alStdDev161Dir);
    }
    

    //--- Alert: pfTermDir
    if (IsChanged(maPFDir[Term],pfractal.Direction(Term)))
    {
      if (pfractal.Event(HistoryLoaded))
        NewAlert(alAlertLog, pfTermDir, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), maPFDir[Term]);

      maPFFibo[Term]           = Fibo100;
      maStdDevAlert            = false;
      maPolyMeanDirAlert       = false;
    }
    
    //--- Alert: pfTrendDir
    if (IsChanged(maPFDir[Trend],pfractal.Direction(Trend)))
    {
      if (pfractal.Event(HistoryLoaded))
        NewAlert(alAlertLog, pfTrendDir, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), maPFDir[Trend]);

      maPFFibo[Trend]           = Fibo100;
    }
    
    //--- Alert: pfTermFibo
    if (pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Max)>FiboPercent(maPFFibo[Term]))
      if (maPFFibo[Term]<Fibo823)
        NewAlert(alAlertLog, pfTermFibo,Expansion,maPFFibo[Term]++,pfractal.Direction(Term));
      
    //--- Alert: pfTrendFibo
    if (pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Max)>FiboPercent(maPFFibo[Trend]))
      if (maPFFibo[Trend]<Fibo823)
        NewAlert(alAlertLog, pfTrendFibo,Expansion,maPFFibo[Trend]++,pfractal.Direction(Trend));
      
    //--- Alert: PipMAPolyDir
    if (IsChanged(maPolyDir,pfractal.Direction(Polyline)))
      if (pfractal.Event(HistoryLoaded))
        NewAlert(alAlertLog, PipMAPolyDir, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), maPolyDir);
        
    //--- Boundary Alerts
    if (pfractal.Event(HistoryLoaded))
    {
      if (pfractal.Event(NewBoundary))
      {
        //--- Alert: BoundaryTrend
        if (IsEqual(pfractal.FOC(Deviation),0.00))
        {
          if (IsChanged(maPipMABoundary[Trend],true))
          {
            maPipMABoundary[Term] = true;
            NewAlert(alAlertLog, BoundaryTrend, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), BoolToInt(pfractal.Event(NewHigh),DirectionUp,DirectionDown));
          }
        }
        else
        
        //--- Alert: BoundaryTerm
        if (IsChanged(maPipMABoundary[Term],true))
          NewAlert(alAlertLog, BoundaryTerm, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), BoolToInt(pfractal.Event(NewHigh),DirectionUp,DirectionDown));
      }
      else
        ArrayInitialize(maPipMABoundary,false);

      //--- Alert: TradeDir; TradeAction
      alTradeDir          = pfractal.Direction(Trendline,InContrarian);
      
      if (pfractal.Direction(Trendline)==DirectionUp)
        if (pfractal.Poly(Deviation)<0)
        {
          if (fabs(pfractal.Poly(Deviation))>pfractal.Trendline(Deviation))
            alTradeAction = OP_SELL;
        }
        else
          alTradeAction   = OP_NO_ACTION;
            
      if (pfractal.Direction(Trendline)==DirectionDown)
        if (pfractal.Poly(Deviation)>0)
        {
          if (pfractal.Poly(Deviation)>fabs(pfractal.Trendline(Deviation)))
            alTradeAction = OP_BUY;
        }
        else
          alTradeAction   = OP_NO_ACTION;
    }
    
    if (IsChanged(maTradeAction,alTradeAction))
      NewAlert(alAlertLog, PipMATradeAction, (RetraceType)BoolToInt(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Now)<FiboPercent(Fibo100),Retrace,Expansion),
                FiboLevel(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Retrace,Now)), ActionDir(alTradeAction));

    //--- Alert: prPolyMeanDir
    if (!maPolyMeanDirAlert)
      if (poly.Direction(Polymean)!=DirectionNone)
        if (IsChanged(alPolyMeanDir,dir(Close[0]-poly.Poly(Mean))))
        {
          maPolyMeanDirAlert = true;
          NewAlert(alAlertLog, prPolyMeanDir, fractal.State(Max), FiboLevel(fractal.Fibonacci(fractal.State(Max),Retrace,Max)), alPolyMeanDir);
        }
      
    //--- Alert: pfDivergentTrend
    if (pfractal.Direction(Trend)==pfractal.Direction(Term))
      maDivTrendFibo = Fibo50;
    else
      if (pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Retrace,Now)>FiboPercent(maDivTrendFibo))
        NewAlert(alAlertLog, pfDivergentTrend, fractal.State(Minor), maDivTrendFibo++, pfractal.Direction(Term));
      
    //--- Alert: pfTermConfirm
    if (pfractal.Count(Trend)==1)
      if (IsChanged(alFiboTermDir,pfractal.Direction(Trend)))
        NewAlert(alAlertLog, pfTermConfirm, Trend, FiboLevel(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Now)), alFiboTrendDir);
    
    //--- Alert: pfTrendConfirm
    if (pfractal.Count(Trend)>1)
      if (pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Now)>FiboPercent(Fibo100))
        if (IsChanged(alFiboTrendDir,pfractal.Direction(Trend)))
          NewAlert(alAlertLog, pfTrendConfirm, Trend, FiboLevel(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Now)), alFiboTrendDir);
      
    if (pfractal.Event(HistoryLoaded))
      ShowAlertLog(alAlertLog,alAlert,"Market Analysis Alerts (On Tick)");
  }

//+------------------------------------------------------------------+
//| ProcessAlerts - Merges new alerts on the subject watchlist       |
//+------------------------------------------------------------------+
void ProcessAlert(bool &Watchlist[], AlertRecord &Log[])
  {
    if (ActiveAlert(alAlertLog))
      for (int alert=0;alert<ArraySize(alAlertLog);alert++)
        if (Watchlist[alAlertLog[alert].Type])
        {
          ArrayResize(Log,ArraySize(Log)+1);
          Log[ArraySize(Log)-1] = alAlertLog[alert];
        }
  }

//+------------------------------------------------------------------+
//| OrderManagement - Executes new orders                            |
//+------------------------------------------------------------------+
void OrderManagement(void)
  {
    int omAlertIndex;
    
    ProcessAlert(omAlert, omAlertLog);
    
    if (OrderPending())
    {
      if (ActiveAlert(alAlertLog, pfTermDir))
        ClosePendingOrders();
    }
    
    if (ActiveAlert(omAlertLog))
    {
      if (ActiveAlert(omAlertLog,pfTermFibo))
      {
        omAlertIndex = GetAlert(omAlertLog,pfTermFibo);
        
/*        if (pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Now)>FiboPercent(omAlertLog[omAlertIndex].FiboLevel))
        {      
          //--- Process Short actions
          if (alTradeAction==OP_SELL)
            Pause(ActionText(OP_SELL)+" @"+DoubleToStr(Bid+omNormalSpread,Digits),"Auto-InRange-Sell");

          //--- Process Long actions      
          if (alTradeAction==OP_BUY)
            Pause(ActionText(OP_BUY)+" @"+DoubleToStr(Ask-omNormalSpread,Digits),"Auto-InRange-Buy");
        }
        else
        {      
          //--- Process Short actions
          if (alTradeAction==OP_SELL)
            Pause(ActionText(OP_SELL)+" @"+DoubleToStr(omAlertLog[omAlertIndex].Price+omNormalSpread,Digits),"Auto-OutRange-Sell");

          //--- Process Long actions      
          if (alTradeAction==OP_BUY)
            Pause(ActionText(OP_BUY)+" @"+DoubleToStr(omAlertLog[omAlertIndex].Price-(omNormalSpread*2),Digits),"Auto-OutRange-Buy");
        }
        
        if (OrderPending())*/
          CloseAlert(omAlertLog,pfTermFibo);
      }
    }      
  }

//+------------------------------------------------------------------+
//| RiskManagement - Executes risk management strategies             |
//+------------------------------------------------------------------+
void RiskManagement(void)
  {
    ProcessAlert(rmAlert, rmAlertLog);
    
    if (ActiveAlert(rmAlertLog))
    {/*
      //--- do stuff
      if (LotValue(OP_SELL,Net)<0.00)
        SetStopPrice(OP_SELL,fmax(trend.Trendline(Head)+alStdDev161,poly.Poly(Mean)));

      if (LotValue(OP_BUY,Net)<0.00)
        SetStopPrice(OP_BUY,fmin(trend.Trendline(Head)-alStdDev161,poly.Poly(Mean)));
     */
    }
    
  }

//+------------------------------------------------------------------+
//| ProfitManagement - Executes Profit management strategies         |
//+------------------------------------------------------------------+
void ProfitManagement(void)
  {
    static int pmLogCount  = 0;
    static int pmIndex     = NoValue;
    static int pmTPAction  = OP_NO_ACTION;
    
    ProcessAlert(pmAlert, pmAlertLog);
    
    if (ActiveAlert(pmAlertLog))
    {
      if (ActiveAlert(pmAlertLog,pfDivergentTrend))
      {
        pmIndex            = GetAlert(pmAlertLog,pfDivergentTrend);
        pmTPAction         = DirAction(pmAlertLog[pmIndex].Direction);
        
        if (IsEqual(LotCount(pmTPAction),0.00))
        {
          pmIndex          = NoValue;
          pmTPAction       = OP_NO_ACTION;
        }
        
        CloseAlert(pmAlertLog,pfDivergentTrend);
      }
    }
    
    if (pmTPAction==OP_NO_ACTION)
    {}
    else
    {
      if (IsChanged(pmLogCount,ArraySize(pmAlertLog)))
        ShowAlertLog(pmAlertLog,pmAlert,"Profit Manager Log");

      if (alPolyMeanDir == pmAlertLog[pmIndex].Direction)
      {
        if (pfractal.Direction(Tick)!=pmAlertLog[pmIndex].Direction)
          if (CloseOrders(CloseConditional,pmTPAction,"pfDivergentTrend"))
          {
            pmIndex          = NoValue;
            pmTPAction       = OP_NO_ACTION;
          }
      }
    }
  }

//+------------------------------------------------------------------+
//| Execute - executes trades                                        |
//+------------------------------------------------------------------+
void Execute(void)
  {
    OrderManagement();
    RiskManagement();
    ProfitManagement();
  }
  
//+------------------------------------------------------------------+
//| ExecAppCommands - Executes commands from the console             |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[1]=="SHOW")
      if (InStr(Command[2],"LINE"))
      {
        if (InStr(Command[3],"FIB"))
          appShowLines  = Fibonacci;
        else
        if (InStr(Command[3],"ORIGIN"))
          appShowLines  = Origin;
        else
        if (InStr(Command[3],"TREND"))
          appShowLines  = Trend;
        else
        if (InStr(Command[3],"TERM"))
          appShowLines  = Term;
        else
          appShowLines  = NoValue;
      }    
      else
      if (Command[2]=="LOG")
      {
        if (InStr(Command[3],"ORDER"))
          ShowAlertLog(omAlertLog,omAlert,"Order Manager Alert Log");
        else
        if (InStr(Command[3],"RISK"))
          ShowAlertLog(rmAlertLog,rmAlert,"Risk Manager Alert Log");
        else
        if (InStr(Command[3],"PROFIT"))
          ShowAlertLog(pmAlertLog,pmAlert,"Profit Manager Alert Log");
        else
        if (InStr(Command[3],"ALERT"))
          ShowAlertLog(alAlertLog,alAlert,"Active Alert Log (On Tick)");
      }    
      else
      if (InStr(Command[2],"ALERT"))
        ShowAlerts(AlertType(Command[3]));
      else
      if (InStr(Command[2],"TRADE"))
        ShowTrades("Open Trades");
      else
        ShowTrades("");

      
    if (Command[1]=="ENABLE" || Command[1]=="DISABLE")
    {
      if (InStr(Command[2],"SHOW"))
        SetAlert(alAlert,AlertType(Command[3]),AlertAction(Command[1]));
        
      if (InStr(Command[2],"RISK"))
      {
        SetAlert(rmAlert,AlertType(Command[3]),AlertAction(Command[1]));
        rmCloseOption = CloseOption(Command[4]);
      }

      if (InStr(Command[2],"PROFIT"))
      {
        SetAlert(pmAlert,AlertType(Command[3]),AlertAction(Command[1]));
        pmCloseOption = CloseOption(Command[4]);
      }

      if (InStr(Command[2],"ORDER"))
      {
        SetAlert(omAlert,AlertType(Command[3]),AlertAction(Command[1]));
        omOpenOption = OpenOption(Command[4]);
      }
    }
  };

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    static int mbResult = IDOK;
    string     otParams[];
       
    InitializeTick();
    
    GetData(); 
    GetManualRequest();

    while (AppCommand(otParams,6))
      ExecAppCommands(otParams);

    OrderMonitor();
    MarketAnalysis();
    RefreshScreen();
    
    if (pfractal.Event(HistoryLoaded))
    {
      if (mbResult == IDOK)
        mbResult = Pause("History loaded. Continue?","PipMA() History Loader",MB_OKCANCEL|MB_ICONQUESTION|MB_DEFBUTTON2);
      
      if (AutoTrade())
        Execute();
    }
    else
      Initialize();
      
    ReconcileTick();
  }

//+------------------------------------------------------------------+
//| InitOrderManagement - initialize alert subscriptions for OM      |
//+------------------------------------------------------------------+
void InitOrderManagement(void)
  {
    ArrayInitialize(omAlert,false);
    
//    SetAlert(omAlert,pfTermDir,true);
    SetAlert(omAlert,pfTermFibo,true);  
  }

//+------------------------------------------------------------------+
//| InitRiskManagement - initialize alert subscriptions for RM       |
//+------------------------------------------------------------------+
void InitRiskManagement(void)
  {
    ArrayInitialize(rmAlert,false);
    rmCloseOption    = inpRiskCloseOption;
    
//    SetAlert(rmAlert,MajorTerm,true);
//    SetAlert(rmAlert,StdDev161,true);
//    SetAlert(rmAlert,CloseDir,true);
//    SetAlert(rmAlert,pfTermDir,true);
//    SetAlert(rmAlert,pfTermFibo,true);
//    SetAlert(rmAlert,prPolyMeanDir,true);
  }

//+------------------------------------------------------------------+
//| InitProfitManagement - initialize alert subscriptions for PM     |
//+------------------------------------------------------------------+
void InitProfitManagement(void)
  {
    ArrayInitialize(pmAlert,false);
    
    if (eqhalf)
      pmCloseOption  = CloseHalf;
    else
      pmCloseOption  = CloseMax;

//    SetAlert(pmAlert,MajorTerm,true);
//    SetAlert(pmAlert,StdDev161,true);
//    SetAlert(pmAlert,CloseDir,true);  
//    SetAlert(pmAlert,pfTermDir,true);
//    SetAlert(pmAlert,pfTermFibo,true);  
//    SetAlert(pmAlert,prPolyMeanDir,true);  
    SetAlert(pmAlert,pfDivergentTrend,true);  
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ManualInit();
    
    InitOrderManagement();
    InitRiskManagement();
    InitProfitManagement();
            
    ArrayInitialize(alFiboDir,DirectionNone);
    
    for (FibonacciLevels fibo=Fibo23;fibo<Fibo423;fibo++)
    {
      NewLine("fp"+IntegerToString(fibo));
      NewLine("fp"+IntegerToString(fibo+10));
    }    

    NewLine("fp0");

    NewLine("fFiboBase");
    NewLine("fFiboRoot");
    NewLine("fFiboExpansion");
    NewLine("fFiboRetrace");
    
    if (inpShowFiboLines)
      appShowLines  = Fibonacci;
    
    NewPriceLabel("pipMA");
    NewPriceLabel("pipMAPoly");

    NewLabel("alCloseDirText","Close Direction:",400,8,clrGray,SCREEN_UR);
    NewLabel("alStdDev161Text","StdDev(161) Direction:",400,20,clrGray,SCREEN_UR);
    NewLabel("alStdDevDirText","StdDev Direction:",400,32,clrGray,SCREEN_UR);
    NewLabel("alOriginDirText","Origin Direction:",400,44,clrGray,SCREEN_UR);
    NewLabel("alCloseDir","",385,8,clrGray,SCREEN_UR);
    NewLabel("alStdDev161Dir","",385,20,clrGray,SCREEN_UR);
    NewLabel("alStdDevDir","",385,32,clrGray,SCREEN_UR);
    NewLabel("alOriginDir","",385,44,clrGray,SCREEN_UR);

    NewRay("stdDevHigh",false);
    NewRay("stdDevLow",false);

    NewLabel("alTradeAction","",5,25,clrGray,SCREEN_LR);
    NewLine("ordTrail");

    //--- Initialize Alerts
    ArrayInitialize(alAlert,true);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Initialize - prepares data while history is loading              |
//+------------------------------------------------------------------+
void Initialize(void)
  {
    alStdDevMax      = trend.StdDev(Max);
    omNormalSpread   = fdiv(omNormalSpread+Spread(),2,Digits);
    omTrailPips      = NormalizeDouble(omNormalSpread*2,Digits);

    if (trend.Direction(StdDev)==DirectionNone)
    {
      alStdDevDir    = dir(trend.StdDev(Now));
      alStdDev161Dir = trend.Direction(Trendline);
    }
    else
    {
      alStdDevDir    = trend.Direction(StdDev);
      alStdDev161Dir = alStdDevDir;
    }
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete trend;
    delete pfractal;
    delete poly;
  }