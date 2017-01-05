//+------------------------------------------------------------------+
//|                                                       mm-v10.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#include <Class\PipFractal.mqh>
#include <Class\TrendRegression.mqh>
#include <manual.mqh>

input string appHeader               = "";    //+---- Regression Inputs -----+
input double inpMaxDrawdown          = 10.0;  // Maximum drawdown percent

input string prHeader                = "";    //+---- Regression Inputs -----+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpPipPeriods           = 200;   // Pip history regression periods
input int    inpTrendPeriods         = 24;    // Trend regression periods
input int    inpSmoothFactor         = 3;     // Moving Average smoothing factor
input double inpTolerance            = 0.5;   // Trend change sensitivity

input string fractalHeader           = "";    //+------ Fractal inputs ------+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

//--- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);  
  CTrendRegression *trend            = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);
  
//+------------------------------------------------------------------+
//+ Operational variables                                            |
//+    al:  Analyst                                                  |
//+    om:  Order Management                                         |
//+    rm:  Risk Management                                          |
//+    pm:  Profit Management                                        |
//+------------------------------------------------------------------+
  double alFibo[20];
  int    alFiboDir[20];
  int    alFiboNow                   = FiboRoot;
  int    alCloseDir                  = DirectionNone;
  int    alCloseAction               = OP_NO_ACTION;
  
  double omNormalSpread              = Spread();
  int    omOrderDir                  = OP_NO_ACTION;
  int    omOrderAction               = OP_NO_ACTION;
  int    omContrarianAction          = OP_NO_ACTION;

  int    rmResult                    = IDOK;
  int    rmAtRiskAction              = OP_NO_ACTION;
  
  
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

        case -Fibo50:
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
      UpdateLine("fp"+IntegerToString(sflFiboExt),alFibo[sflFiboExt],sflStyle,sflColor);
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
//| CalcFibo - Computes the fibo matrix                              |
//+------------------------------------------------------------------+
void CalcFibo(void)
  {
    static int cfLastFibo  = 20;
    
    int    cfFiboNow       = alFiboNow;
    int    cfFiboExt       = FiboRoot;
    
    double cfFiboBase      = fractal[Base].Price;
    double cfFiboRoot      = fractal[Root].Price;
    
    if (fractal.Fibonacci(Base,Expansion,Max)>FiboPercent(Fibo261) || IsEqual(fractal[Base].Price,0.00))
    {
      cfFiboBase           = fractal[Expansion].Price;
      cfFiboRoot           = fractal[Expansion].Price+BoolToDouble(fractal.Direction()==DirectionUp,-Pip(inpRangeMax,InPoints),Pip(inpRangeMax,InPoints));
    }
    
    alFiboNow              = Fibo823;

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
        
      UpdateLabel("h"+IntegerToString(alFiboNow),BoolToStr(alFiboNow>=0,"+")+DoubleToStr(FiboPercent(alFiboNow,InPercent),1),DirColor(alFiboDir[FiboExt(alFiboNow)]));
    }
    
  }

//+------------------------------------------------------------------+
//| GetData - retrieve and organize operational data                 |
//+------------------------------------------------------------------+
void GetData(void)
  {
    static int gdBarsTotal = Bars;
    double     gdRegrPrice = trend.Trendline(Head);
    
    fractal.Update();
    pfractal.Update();
    trend.Update();
    
    CalcFibo();
    
    if (IsChanged(gdBarsTotal,Bars))
    {
      if (IsHigher(Open[0],gdRegrPrice))
        alCloseDir   = DirectionUp;

      if (IsLower(Open[0],gdRegrPrice))
        alCloseDir   = DirectionDown;
      
      alCloseAction  = DirectionAction(alCloseDir);
      
      UpdateDirection("alCloseDir",alCloseDir,DirColor(alCloseDir));
    }
  }
  
//+------------------------------------------------------------------+
//| TradeAtRisk - analyzes open trade risks; true when action req'd  |
//+------------------------------------------------------------------+
bool TradeAtRisk(void)
  {
    if (LotCount(alCloseAction,Total,InContrarian)>0.00)
    {
      rmAtRiskAction = DirectionAction(alCloseDir,InContrarian);
      return (true);
    }
      
    if (LotValue(OP_BUY,Loss,InEquity)<-inpMaxDrawdown)
    {
      rmAtRiskAction = OP_BUY;
      return (true);
    }
      
    if (LotValue(OP_SELL,Loss,InEquity)<-inpMaxDrawdown)
    {
      rmAtRiskAction = OP_SELL;
      return (true);
    }

    return (false);
  }
  
//+------------------------------------------------------------------+
//| ExecRiskManagement - takes action on trades at risk              |
//+------------------------------------------------------------------+
void ExecRiskManagement(void)
  {
    UpdateLabel("eTradeAtRisk","At Risk ("+ActionText(rmAtRiskAction)+")",clrRed);
    
    if (rmResult!=IDCANCEL)
      rmResult = Pause("Danger, Danger, Will Robinson","AtRisk",MB_OKCANCEL|MB_ICONEXCLAMATION|MB_DEFBUTTON2);
/*      
    if (rmAtRiskAction == OP_BUY)
    {
      if (IsEqual(ordStopLongPrice,0.00))
        SetStopPrice(OP_BUY,Open[0]-Pip(trend.StdDev(Peak),InPoints));
      else
      if (Close[0]>trend.Trendline(Head))
        SetStopPrice(OP_BUY,fmin(trend.Poly(Head),trend.Trendline(Head)));
    }

    if (rmAtRiskAction == OP_SELL)
    {
      if (IsEqual(ordStopShortPrice,0.00))
        SetStopPrice(OP_SELL,Open[0]+Pip(trend.StdDev(Peak),InPoints));
      else
      if (Close[0]<trend.Trendline(Head))
        SetStopPrice(OP_SELL,fmax(trend.Poly(Head),trend.Trendline(Head)));
    }
*/
  }

//+------------------------------------------------------------------+
//| ResetRiskManagement - Resets risk parameters                     |
//+------------------------------------------------------------------+
void ResetRiskManagement(void)
  {
    UpdateLabel("eTradeAtRisk","Not At Risk",clrGray);  
    rmResult = IDOK;
    
    if (rmAtRiskAction != OP_NO_ACTION)
      rmAtRiskAction    = OP_NO_ACTION;
  }
    
//+------------------------------------------------------------------+
//| Execute - executes trades                                        |
//+------------------------------------------------------------------+
void Execute(void)
  { 
    static bool eOpenTrade      = false;
    static bool eProfitTaken    = true;
    static int  eCloseDir       = DirectionNone;
        
    if (omOrderAction==OP_NO_ACTION)
      Initialize();
    else
    if (IsChanged(omOrderDir,pfractal.Direction(Trendline)))
    {
      if (omOrderDir==DirectionNone)
        return;
        
      omOrderAction      = DirectionAction(omOrderDir);
      omContrarianAction = DirectionAction(omOrderDir,InContrarian);

      if (AutoTrade())
        eOpenTrade    = true;
      else
        if (Pause("Open Limit Order? "+ActionText(omOrderAction)+"\nPrice: "+DoubleToStr(pfractal.Range(Mid),Digits),"PipMA Changed",MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2)==IDYES)
          OpenLimitOrder(omOrderAction,pfractal.Range(Mid),0.00,0.00,0.00,"Ask-Limit");
    }

    if (IsChanged(eCloseDir,alCloseDir))
    {
ShowTrades();
      ClosePendingOrders();
      SetActionHold(DirectionAction(alCloseDir,InContrarian));
//      SetStopPrice(DirectionAction(alCloseDir,InContrarian),trend.Poly(Head));

      if (LotCount(alCloseAction,Total,InContrarian)>0)
        eProfitTaken    = false;
        
      if (!eProfitTaken)
      {
        eProfitTaken    = true;
        UpdatePriceLabel("eTakeProfit",trend.Poly(Head),clrGray);
      }
    }
    
    if (TradeAtRisk())
      ExecRiskManagement();
    else
      ResetRiskManagement();
    
    if (omOrderDir == alCloseDir)
    {
      if (eOpenTrade && pfractal.Direction(Tick)==omOrderDir)
      {
//        if (pfractal.Fibonacci(Term,omOrderDir,Expansion,Max)>FiboPercent(Fibo100))
//        {
//          //--- do nothing (for now);
//        }
//        else
        if (LotCount(omOrderAction)<LotCount(omOrderAction,Total,InContrarian))
          OpenOrder(omOrderAction,"Auto-Market");
        else  
          OpenLimitOrder(omOrderAction,pfractal.Range(Mid),0.00,0.00,omNormalSpread,"Auto-Limit");

        eOpenTrade      = false;
      }
    }

    if (!eProfitTaken)
    {
      UpdatePriceLabel("eTakeProfit",trend.Poly(Head),BoolToInt(ActionHold(OP_BUY),clrYellow,clrRed));
      
      if (ActionHold(OP_BUY))
        if (Close[0]<trend.Poly(Head))
          if (CloseOrders(CloseProfit,OP_BUY,"Regr-Close"))
            eProfitTaken  = true;
    
      if (ActionHold(OP_SELL))
        if (Close[0]>trend.Poly(Head))
          if (CloseOrders(CloseProfit,OP_SELL,"Regr-Close"))
            eProfitTaken  = true;
          
      if (eProfitTaken)
        SetActionHold(OP_NO_ACTION);

      UpdateLabel("eOpenTrade",BoolToStr(eOpenTrade,"Calculating "+ActionText(omOrderAction),"Analyzing"));
    }      
  }
  
//+------------------------------------------------------------------+
//| Initialize - prepares data while history is loading              |
//+------------------------------------------------------------------+
void Initialize(void)
  {
    omNormalSpread   = fdiv(omNormalSpread+Spread(),2,Digits);
    omOrderDir       = pfractal.Direction(Trendline);
    omOrderAction    = DirectionAction(omOrderDir);
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen - updates screen data                              |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string     rsFractal        = "f: ";

    if (pfractal.Trendline(Head)>trend.Trendline(Head))
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrYellow);
    else
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrRed);
      
    ShowFiboLines();
    SetFiboArrow(pfractal.Direction(Term));
    
    UpdateDirection("fiboNow",dir(alFiboDir[FiboExt(alFiboNow)]),DirColor(alFiboDir[FiboExt(alFiboNow)]));
    ObjectSet("fiboNow",OBJPROP_XDISTANCE,655+(alFiboNow*40*DirectionInverse));

    rsFractal += "Base "+EnumToString(fractal.Leg(Expansion,Peg))
        +"  (rt): "+DoubleToStr(fractal.Fibonacci(Base,Retrace,Now,InPercent),1)+"%"
        +"  "+DoubleToStr(fractal.Fibonacci(Base,Retrace,Max,InPercent),1)+"%"
        +BoolToStr(IsEqual(fractal[Base].Price,0.00),"",
          +"  (e): "+DoubleToStr(fractal.Fibonacci(Expansion,Expansion,Now,InPercent),1)+"%"
          +"  "+DoubleToStr(fractal.Fibonacci(Base,Expansion,Max,InPercent),1)+"%"
          +"\nBase: "+DoubleToStr(fractal[Base].Price,Digits)
          +"  Root: "+DoubleToStr(fractal[Root].Price,Digits)
          +"  Expansion: "+DoubleToStr(fractal[Expansion].Price,Digits))+"\n";
    
    for (RetraceType fibo=Expansion;fibo<RetraceTypeMembers;fibo++)
      if (fractal.Leg(fibo,Level)==Max)
        rsFractal += EnumToString(fibo)+" "+EnumToString(fractal.Leg(fibo,Peg))
            +"  (rt): "+DoubleToStr(fractal.Fibonacci(fibo,Retrace,Now,InPercent),1)+"%"
            +"  "+DoubleToStr(fractal.Fibonacci(fibo,Retrace,Max,InPercent),1)+"%"
            +"  (e): "+DoubleToStr(fractal.Fibonacci(fibo,Expansion,Now,InPercent),1)+"%" 
            +"  "+DoubleToStr(fractal.Fibonacci(fibo,Expansion,Max,InPercent),1)+"%\n";

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
           "\n*--- Fractal ---*\n"
           +rsFractal
           );
           
/*    UpdateLine("oOrigin",pfractal.Price(Origin,Origin),STYLE_SOLID,clrWhite);
    UpdateLine("oPrior",pfractal.Price(Origin,Prior),STYLE_SOLID,clrYellow);
    UpdateLine("oBase",pfractal.Price(Origin,Base),STYLE_DOT,clrMaroon);
    UpdateLine("oRoot",pfractal.Price(Origin,Root),STYLE_DOT,clrGoldenrod);
    UpdateLine("oExpansion",pfractal.Price(Origin,Expansion),STYLE_DOT,clrSteelBlue);
    UpdateLine("oRetrace",pfractal.Price(Origin,Retrace),STYLE_DOT,clrGray);
*/
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
void ShowTrades(void)
  {
    string stShort = "";
    string stLong  = "";
    
    int    stMinTicket[2]      = {0,0};
    double stMinValue[2]       = {0.00,0.00};
    
    orderRefreshScreen();
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSymbol()==Symbol())
        if (OrderSelect(ord,SELECT_BY_POS))
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
      
    Pause(" Ticket   Symbol      Open    Lots    Com     Swap       Profit(Val/%)\n"
         +stShort+stLong+"\n"
         +"Minimum Tickets"
         +BoolToStr(stMinTicket[OP_BUY]>0,"\n"+FormatOrder(stMinTicket[OP_BUY]))
         +BoolToStr(stMinTicket[OP_SELL]>0,"\n"+FormatOrder(stMinTicket[OP_SELL]))
         +"\n\nBalance: "+DoubleToStr(AccountBalance()+AccountCredit(),2)
         +"\nEquity: "+DoubleToStr(AccountEquity(),2)
         +" ("+DoubleToStr(EquityPercent(),1)+"%)",
         "Order Values");
  }
  
//+------------------------------------------------------------------+
//| CheckStop - Sets/Checks for an app user-defined price hit        |
//+------------------------------------------------------------------+
void CheckStop(double Price=0.00)
  {
    static double        csStopPrice = 0.00;
    static ReservedWords csPosition;
    
    if (Price>0.00)
    {
      csStopPrice = Price;
      
      if (Price>Close[0])
        csPosition = Above;
        
      if (Price<Close[0])
        csPosition = Below;
    }

    if (csStopPrice>0.00)
      if ((csPosition==Above&&Close[0]>=csStopPrice)||
          (csPosition==Below&&Close[0]<=csStopPrice))
      {
        Pause("Price check @"+DoubleToStr(csStopPrice,Digits),"PriceStop()");
        csStopPrice  = 0.00;
      }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    static int    mbResult = IDOK;
           string otParams[];
       
    InitializeTick();
    
    GetData(); 
    GetManualRequest();

    if (AppCommand(otParams))
    {
      if (otParams[1]=="SHOW")
        ShowTrades();
        
      if (otParams[1]=="STOP")
        CheckStop(StringToDouble(otParams[2]));
    };

    OrderMonitor();
    RefreshScreen();

    if (pfractal.Event(HistoryLoaded))
    {
      if (mbResult == IDOK)
        mbResult = Pause("History loaded. Continue?","PipMA() History Loader",MB_OKCANCEL|MB_ICONQUESTION|MB_DEFBUTTON2);
      
      Execute();
      CheckStop();
    }
    else
      Initialize();
      
    ReconcileTick();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ManualInit();
    
    ArrayInitialize(alFiboDir,DirectionNone);
    
    for (FibonacciLevels fibo=Fibo23;fibo<Fibo423;fibo++)
    {
      NewLine("fp"+IntegerToString(fibo));
      NewLine("fp"+IntegerToString(fibo+10));
      
      NewLabel("h"+IntegerToString(fibo),"+"+DoubleToStr(FiboPercent(fibo,InPercent),1),650-(fibo*40),7,clrGray,SCREEN_UR);
      NewLabel("h"+IntegerToString(-fibo),DoubleToStr(-FiboPercent(fibo,InPercent),1),650+(fibo*40),7,clrGray,SCREEN_UR);
    }    

    NewLabel("h0","+0.0",650,7,clrGray,SCREEN_UR);
    NewLine("fp0");
    NewPriceLabel("pipMA");
    NewLabel("fiboNow","",650,20,clrLawnGreen,SCREEN_UR);
    NewLabel("eOpenTrade","Initializing",980,8,clrLawnGreen,SCREEN_UR);
    NewLabel("eTradeAtRisk","",980,20,clrLawnGreen,SCREEN_UR);
    NewLabel("alCloseDir","",965,8,clrGray,SCREEN_UR);
    NewPriceLabel("eTakeProfit");
    
//    NewLine("oOrigin");
//    NewLine("oPrior");
//    NewLine("oBase");
//    NewLine("oRoot");
//    NewLine("oExpansion");
//    NewLine("oRetrace");
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete trend;
    delete pfractal;
  }