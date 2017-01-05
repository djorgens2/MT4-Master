//+------------------------------------------------------------------+
//|                                                        mm-v8.mq4 |
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

input string prHeader                = "";    //+---- Regression Inputs -----+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpPipPeriods           = 200;   // Pip history regression periods
input int    inpTrendPeriods         = 24;    // Trend regression periods
input int    inpSmoothFactor         = 3;     // Moving Average smoothing factor
input double inpTolerance            = 0.5;   // Trend change sensitivity

input string fractalHeader           = "";    //+----- Fractal inputs -----+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

//--- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);  
  CTrendRegression *trend            = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);

  enum     ActionTypes
           {
             Buy,
             Sell,
             Hold,
             TakeProfit,
             TakeLoss
           };
           
  int      omOrderAction             = OP_NO_ACTION;
  int      omContrarianAction        = OP_NO_ACTION;
  double   omContrarianLots          = 0.00;

  int      pmProfitLevel             = -Fibo61;  

  bool     rmReversalAlert           = false;
  bool     rmKillTrend               = false;
  bool     rmKillHedge               = false;
  
  double   omSpreadAvg               = Spread();
  double   omOrderVolume[2][20];
  int      omOrderLevel              = FiboRoot;
  
  int      alAdvance                 = FiboRoot;
  int      alDecline                 = FiboRoot;


//+------------------------------------------------------------------+
//| Hedged - returns true if there are open contrarian trades        |
//+------------------------------------------------------------------+
bool Hedged(void)
  {
    return (LotCount(omContrarianAction)>0.00);
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
//| ShowFiboLines - Paints the fibo lines                            |
//+------------------------------------------------------------------+
void ShowFiboLines(void)
  {
    int    sflStyle        = STYLE_DOT;
    int    sflColor        = clrGray;
    int    sflFiboNow      = FiboLevel(fractal.Fibonacci(Base,Retrace,Now),Extended);
    int    sflFiboExt      = FiboRoot;

    for (int fibo=-Fibo261;fibo<Fibo423;fibo++)
    {
      sflFiboExt = FiboLevel(FiboPercent(fibo),Signed);
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

        default:        if (fractal[Expansion].Direction == DirectionUp)
                          sflColor = BoolToInt(fibo<0,clrForestGreen,clrMaroon);
                        if (fractal[Expansion].Direction == DirectionDown)
                          sflColor = BoolToInt(fibo<0,clrMaroon,clrForestGreen);                          
      }
    
      sflFiboExt = FiboLevel(FiboPercent(fibo),Extended);

      if (fibo<FiboRoot)
        UpdateLine("fp"+IntegerToString(sflFiboExt),FiboPrice(sflFiboExt,fractal[Base].Price,fractal[Root].Price,Retrace),sflStyle,sflColor);
      else
      if (fibo>FiboRoot)
        UpdateLine("fp"+IntegerToString(sflFiboExt),FiboPrice(sflFiboExt,fractal[Base].Price,fractal[Root].Price,Retrace),sflStyle,sflColor);
      else
        UpdateLine("fp"+IntegerToString(sflFiboExt),FiboPrice(sflFiboExt,fractal[Base].Price,fractal[Root].Price,Retrace),sflStyle,sflColor);

      if (sflFiboExt == sflFiboNow)
        UpdateLabel("volH"+IntegerToString(sflFiboExt),BoolToStr(sflFiboExt<10,"+")+DoubleToStr(FiboPercent(sflFiboExt,InPercent),1),clrWhite);
      else
        UpdateLabel("volH"+IntegerToString(sflFiboExt),BoolToStr(sflFiboExt<10,"+")+DoubleToStr(FiboPercent(sflFiboExt,InPercent),1),clrGray);

      UpdateLabel("volL"+IntegerToString(sflFiboExt),DoubleToStr(omOrderVolume[OP_BUY][sflFiboExt],2),BoolToInt(omOrderVolume[OP_BUY][sflFiboExt]>0.00,clrWhite,clrGray));
      UpdateLabel("volS"+IntegerToString(sflFiboExt),DoubleToStr(omOrderVolume[OP_SELL][sflFiboExt],2),BoolToInt(omOrderVolume[OP_SELL][sflFiboExt]>0.00,clrWhite,clrGray));
    }
  }

//+------------------------------------------------------------------+
//| ActionLotSize - computes the lotsize for the current levelaction |
//+------------------------------------------------------------------+
double ActionLotSize(int Action, bool Contrarian=false)
  {
    int           alsFiboSign         = FiboLevel(fractal.Fibonacci(Base,Retrace,Now),Signed);
    double        alsLotDeficit       = 0.00;
    
    if (Action == OP_BUY || Action == OP_SELL)
    {
      if (Contrarian)
      {        
        if (LotCount(Action)==0.00)
          return (LotSize());

        if (omOrderVolume[Action][FiboExt(alsFiboSign)]>=omContrarianLots ||
            omOrderVolume[Action][FiboExt(alsFiboSign+1)]>=omContrarianLots)
          return (0.00);
        
        return (omContrarianLots);
      }

      for (int fibo=-Fibo823;fibo<alsFiboSign;fibo++)
        alsLotDeficit += omOrderVolume[Action][FiboExt(fibo)];

      if (omOrderVolume[Action][FiboExt(alsFiboSign)]>=LotSize())
        return (0.00);
        
      if (alsLotDeficit>LotSize())
        return (HalfLot());
        
      if (fractal[Expansion].Direction!=pfractal[Trend].Direction)
        if (pfractal.Count(Trend)>1)
          return (HalfLot());
        else
          return (LotSize()*2);
          
      return (LotSize());
    }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//| LevelAction - computes the action for the current fibo level     |
//+------------------------------------------------------------------+
ActionTypes LevelAction(void)
  {
    static int alLastFibo       = FiboRoot;

    int    alFiboSign           = FiboLevel(fractal.Fibonacci(Base,Retrace,Now),Signed);

    if (alFiboSign>alLastFibo)
    {
      alDecline  = fmax(alFiboSign,alLastFibo);
      alLastFibo = alFiboSign;
    }
    else
    if (alFiboSign<alLastFibo)
    {
      alAdvance  = fmin(alFiboSign,alLastFibo);
      alLastFibo = alFiboSign;
    }
    
    if (alAdvance-alDecline>-2)
      return (Hold);
    else    
    if (alAdvance-alDecline>-3)
    {
      if (alFiboSign==alDecline)
        return ((ActionTypes)DirectionAction(fractal[Expansion].Direction));

      if (alFiboSign==alAdvance)
        return ((ActionTypes)DirectionAction(fractal[Expansion].Direction,InContrarian));
    }

    if (alFiboSign==alDecline)
      return (TakeLoss);

    return (TakeProfit);
  }

//+------------------------------------------------------------------+
//| InitializeApp - Sets vars while history is loading               |
//+------------------------------------------------------------------+
void InitializeApp(void)
  {    
    omSpreadAvg   = fdiv(Spread()+omSpreadAvg,2);
  }
  
//+------------------------------------------------------------------+
//| GetOrderData - Computes volume, eq%, and quota by fibo level     |
//+------------------------------------------------------------------+
void GetOrderData(void)
  {    
    int    godFiboExt      = FiboRoot;
    double godFiboPrice    = NoValue;
    
    ArrayInitialize(omOrderVolume,0.00);
          
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (Symbol()==OrderSymbol())
        {
          if (OrderType()==OP_BUY)
            godFiboPrice  = (OrderOpenPrice()-omSpreadAvg);
            
          if (OrderType()==OP_SELL)
            godFiboPrice  = OrderOpenPrice();

          for (int fibo=-Fibo823;fibo<Fibo823;fibo++)
          {
            godFiboExt = FiboLevel(FiboPercent(fibo),Extended);
            
            if (godFiboPrice>FiboPrice(godFiboExt,fractal[Base].Price,fractal[Root].Price,Retrace))
            {
               omOrderVolume[OrderType()][godFiboExt] += OrderLots();
               break;
            }                
          }
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

    ShowFiboLines();
    SetFiboArrow(pfractal.Direction(Term));
    GetOrderData();
    LevelAction();
  }
  
//+------------------------------------------------------------------+
//| ExecTakeProfit - executes profit taking                          |
//+------------------------------------------------------------------+
void ExecTakeProfit(int Action, int ProfitOption, bool Contrarian=false)
  {
    static int etpProfit        = FiboRoot;
           int etpFiboSign      = FiboLevel(fractal.Fibonacci(Base,Retrace,Now),Signed);
        double etpOrderPrice;
        double etpProfitPrice   = FiboPrice(etpFiboSign+1,fractal[Base].Price,fractal[Root].Price,Retrace);
        double etpAdvancePrice  = FiboPrice(etpFiboSign,fractal[Base].Price,fractal[Root].Price,Retrace);

    if (fractal.Fibonacci(Base,Expansion,Now)<FiboPercent(Fibo61))
      pmProfitLevel               = -Fibo61;
    
    //+-------------------------------------------------------------------------------------------------+
    //| Handle Contrarian profit events                                                                 |
    //+-------------------------------------------------------------------------------------------------+
    if (Contrarian)
    {
      etpOrderPrice = BoolToDouble(OrderType()==OP_BUY,OrderOpenPrice()-omSpreadAvg,OrderOpenPrice());
      
      if (Hedged())
      {
        if (rmKillHedge)
          CloseOrders(CloseLoss,Action,"Emergent Hedge Drop");
        else
      
        if (ProfitOption == Minor)
          KillHalf(Action,CloseProfit,"Soft Hedge Drop");      
        else

        if (ProfitOption == Major)
        {
          if (Action==OP_BUY)
            KillOrders(Action,CloseProfit,Below,etpAdvancePrice,"Hedge Drop");

          if (Action==OP_SELL)
            KillOrders(Action,CloseProfit,Above,etpAdvancePrice,"Hedge Drop");
        }
      }
    }
    else
      
    //+-------------------------------------------------------------------------------------------------+
    //| Handle minor profit events                                                                      |
    //+-------------------------------------------------------------------------------------------------+
    if (ProfitOption == Minor)
    {
      if (etpProfit == etpFiboSign)
      {
        if (fractal.Fibonacci(Base,Expansion,Now)>FiboPercent(Fibo100))
        {
          if (pfractal.Count(Trend)>1)
          {
            if (pfractal.Fibonacci(Trend,fractal[Expansion].Direction,Expansion,Now)>FiboPercent(Fibo161))
              if (CloseOrders(CloseConditional,Action,"Expansion Profit"))
                etpProfit  = etpFiboSign--;
          }
          else
          {
            if (pfractal.Fibonacci(Term,fractal[Expansion].Direction,Expansion,Now)>FiboPercent(Fibo161))
              if (CloseOrders(CloseConditional,Action,"Expansion Profit"))
                etpProfit  = etpFiboSign--;
          }
        }
        else
        {
          for (int ord=0;ord<OrdersTotal();ord++)
            if (OrderSelect(ord,SELECT_BY_POS))
              if (OrderSymbol()==Symbol())
              {
                etpOrderPrice = BoolToDouble(OrderType()==OP_BUY,OrderOpenPrice()-omSpreadAvg,OrderOpenPrice());
                
                if (OrderType()==OP_BUY)
                  if (etpOrderPrice<etpProfitPrice)
                    if (CloseOrders(CloseConditional,Action,"Interior Profit"))
                      etpProfit  = etpFiboSign--;
                      
                 if (OrderType()==OP_SELL)
                  if (etpOrderPrice>etpProfitPrice)
                    if (CloseOrders(CloseConditional,Action,"Interior Profit"))
                      etpProfit  = etpFiboSign--;
              }
        }
      }
    }
    else

    //+-------------------------------------------------------------------------------------------------+
    //| Handle major profit events                                                                      |
    //+-------------------------------------------------------------------------------------------------+
    if (ProfitOption == Major)
    {
      if (rmKillTrend)
      {
        if (!KillHalf(Action,CloseProfit,"Trend Kill"))
          rmKillTrend = false;
      }
      else
      if (fractal.Range(Expansion,Now)<Pip(inpRangeMin+inpRangeMax,InPoints))
      {
        if (KillHalf(Action,CloseProfit,"Major Fractal (Short Leg"))
        {
          etpProfit  = etpFiboSign;
          pmProfitLevel--; 
        }
      }
      else
      if (etpFiboSign==pmProfitLevel)
      {
        if (KillHalf(Action,CloseProfit,"Major Fractal (Long Leg"))
        {
          etpProfit  = etpFiboSign;
          pmProfitLevel--; 
        }
      }
    }
  }

//+------------------------------------------------------------------+
//| ManageProfit - executes new trades                               |
//+------------------------------------------------------------------+
void ManageProfit(int Action)
  {
    static int   mpFiboLevel  = FiboRoot;
           int   mpLastLevel  = mpFiboLevel;
           int   mpFiboSign   = FiboLevel(fractal.Fibonacci(Base,Retrace,Now),Signed);
    static int   mpTrendCount = 0;
    
    //--- Manage short term (interior) profits
    if (IsChanged(mpFiboLevel,mpFiboSign))
    {
      if (rmKillTrend)
        ExecTakeProfit(omOrderAction,Major);

      if (rmKillHedge)
        ExecTakeProfit(omContrarianAction,Major,InContrarian);
        
      if (mpFiboLevel>FiboRoot && mpLastLevel!=FiboRoot)
        ExecTakeProfit(omOrderAction,Minor);
    }

    //--- Manage major profit levels (extended area) profits
    if (fractal.Fibonacci(Base,Expansion,Now)>FiboPercent(Fibo100))
    {
      if(pfractal.Fibonacci(Term,fractal[Expansion].Direction,Expansion,Now)>FiboPercent(Fibo161))
        ExecTakeProfit(omOrderAction,Minor);
      
      //--- Major Profit taking
      if (fractal.Fibonacci(Base,Expansion,Now)>FiboPercent(Fibo161))
        ExecTakeProfit(omOrderAction,Major);
    }
    
    //--- Manage hedging (drop hedges)
    if (Hedged())
    {
      if (OrderFulfilled(omOrderAction))
        ExecTakeProfit(omContrarianAction,Major,InContrarian);

      if (fractal.Fibonacci(Base,Expansion,Now)<FiboPercent(Fibo50))
        ExecTakeProfit(omContrarianAction,Major,InContrarian);
    }
  }

//+------------------------------------------------------------------+
//| ExecOpenOrder - executes new trades                              |
//+------------------------------------------------------------------+
void ExecOpenOrder(int Action, int Type, double Price=0.00, bool Contrarian=false)
  {
    if (IsEqual(ActionLotSize(Action,Contrarian),0.00,ordLotPrecision))
      return;
    
    switch (Type)
    {
      //--- Execute At Market Orders
      case OP_BUY:   
      case OP_SELL:       if (OrderPending(Action))
                            ClosePendingOrders();

                          if (OpenOrder(Action,"Auto-"+BoolToStr(Contrarian,"Contrarian","Market"),ActionLotSize(Action,InContrarian)))
                            if (Contrarian)
                              omContrarianLots   = ordOpen.Lots;
                          break;      

      //--- Execute Limit Orders
      case OP_BUYLIMIT:   
      case OP_SELLLIMIT:  OpenLimitOrder(Action,Price,0.00,ActionLotSize(Action),0.00,"Auto-Limit");
                          break;      


      //--- Execute MIT Orders
      case OP_BUYSTOP:   
      case OP_SELLSTOP:  OpenLimitOrder(Action,Price,0.00,ActionLotSize(Action),0.00,"Auto-MIT");
                         break;      
    }
  }
    
//+------------------------------------------------------------------+
//| ManageOrders - executes new trades                               |
//+------------------------------------------------------------------+
void ManageOrders(int Action)
  {
    static int moActionNow  = Hold;
           int moLastAction = moActionNow;

    omOrderAction           = DirectionAction(fractal[Expansion].Direction);
    omContrarianAction      = DirectionAction(fractal[Expansion].Direction,InContrarian);

    if (IsChanged(moActionNow,Action))
    {
      //--- Close pending orders
      CloseMITOrder();
      CloseLimitOrder();
      
      //--- Trade on confirmed non-runaway market
      if (Action == Hold)
      {
        //--- Manage new in-trend orders
        if (moLastAction == omOrderAction)
        {
          //--- catch the standard fibo maneuvers
          if (fractal.Fibonacci(fractal.Dominant(Term),Retrace,Now)>FiboPercent(Fibo23))
          {
            if (omOrderAction == OP_BUY)
              if (Close[0]<fractal[Expansion].Price-Pip(inpRangeMin,InPoints))
                ExecOpenOrder(omOrderAction,OP_BUY);
              else
                ExecOpenOrder(omOrderAction,OP_BUYLIMIT,fractal[Expansion].Price-Pip(inpRangeMin,InPoints)-Spread());

            if (omOrderAction == OP_SELL)
              if (Close[0]>fractal[Expansion].Price+Pip(inpRangeMin,InPoints))
                ExecOpenOrder(omOrderAction,OP_SELL);
              else
                ExecOpenOrder(omOrderAction,OP_SELLLIMIT,fractal[Expansion].Price+Pip(inpRangeMin,InPoints));
          }
        }
        else

        //--- Manage new contrarian orders
        if (pfractal.Count(Trend)>1 && fractal[Expansion].Direction==pfractal[Trend].Direction)
        {
          //--- Not ideal for contrarian trades; may trade under certain conditions to be defined
        }
        else
        
        //--- Rule of 23; interior hedging with quick stops
        if (fractal.Fibonacci(Base,Retrace,Max)>FiboPercent(Fibo50))
        {
          if (fractal.Fibonacci(Base,Expansion,Now)>FiboPercent(Fibo23) &&
              fractal.Fibonacci(Base,Retrace,Now)<FiboPercent(Fibo23))
          {
            if (omContrarianAction == OP_BUY)
              if (Close[0]<fractal.Price(Root)-Pip(inpRangeMin,InPoints))
                ExecOpenOrder(omContrarianAction,OP_BUY,0.00,InContrarian);
              
            if (omContrarianAction == OP_SELL)
              if (Close[0]>fractal.Price(Root)+Pip(inpRangeMin,InPoints))
                ExecOpenOrder(omContrarianAction,OP_SELL,0.00,InContrarian);
          }
        }
        else

        //--- Standard profit-protect hedges
          {
            if (omContrarianAction == OP_BUY && pfractal[Trend].Direction == DirectionUp)
              if (Close[0]<fractal.Price(Root)-Pip(inpRangeMin,InPoints))
                ExecOpenOrder(omContrarianAction,OP_BUY,0.00,InContrarian);
              
            if (omContrarianAction == OP_SELL && pfractal[Trend].Direction == DirectionDown)
              if (Close[0]>fractal.Price(Root)+Pip(inpRangeMin,InPoints))
                ExecOpenOrder(omContrarianAction,OP_SELL,0.00,InContrarian);
          }
      }
    }
  }

//+------------------------------------------------------------------+
//| ManageRisk - keeps us from shooting ourselves in the foot        |
//+------------------------------------------------------------------+
void ManageRisk(int Action)
  {
    static int mrTrendCount   = 0;
    
    if (IsChanged(mrTrendCount,pfractal.Count(Trend)))
    {
      //---Double bubble trend
      if (mrTrendCount == 2)
      {
        if (pfractal[Trend].Direction==fractal[Expansion].Direction)
        {
          if (Hedged())
          {
            ExecTakeProfit(omContrarianAction,Major,InContrarian);
            rmKillHedge = true;
          }          

          SetActionHold(omContrarianAction);
        }
        else
        {
          ExecTakeProfit(omOrderAction,Major);
          SetActionHold(omOrderAction);
          rmKillTrend  = true;
        }
      }
    }
    
    if (pfractal[Trend].Direction==fractal[Expansion].Direction)
      SetActionHold(omContrarianAction);
    else

    if (ActionHold(omContrarianAction)&&pfractal.Count(Trend)>0)
    {
      SetActionHold(OP_NO_ACTION);
      rmKillHedge    = false;
    }
    else    

    if (fractal.Fibonacci(Base,Expansion,Max)>FiboPercent(Fibo161) &&
        fractal.Fibonacci(Base,Retrace,Max)>=FiboPercent(Fibo23))
    {
      if (pfractal[Trend].Direction==fractal[Expansion].Direction)
      {
        SetActionHold(omContrarianAction);
        rmKillHedge = true;
      }
    }



    //--- Set reversal alert
    if (fractal.IsConvergent())
      if (fractal.Fibonacci(Base,Expansion,Now)<FiboPercent(Fibo23))
         rmReversalAlert  = true;
         
    if (!fractal.IsDivergent())
      rmReversalAlert     = false;
      
  
  
  }
  
//+------------------------------------------------------------------+
//| Execute - executes trades                                        |
//+------------------------------------------------------------------+
void Execute()
  {
    static ActionTypes eAction    = Hold;
    int                eFiboSign  = FiboLevel(fractal.Fibonacci(Base,Retrace,Now),Signed);

    if (eAction != LevelAction())
      eAction  = LevelAction();
        
    ManageOrders(eAction);
    ManageProfit(eAction);
    ManageRisk(eAction);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - repaints screen data                             |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    Comment("Action: "+EnumToString(LevelAction())
           +"  Advance: "+EnumToString((FibonacciLevels)alAdvance)+" Decline: "+EnumToString((FibonacciLevels)alDecline)
           +"\nFibo: Current: ("+IntegerToString(FiboLevel(fractal.Fibonacci(Base,Retrace,Now),Signed))+")"
           +"  "+DoubleToStr(FiboPercent(FiboLevel(fractal.Fibonacci(Base,Retrace,Now),Signed),InPercent),1)+"%"
           +"  Normal Spread: "+DoubleToStr(Pip(omSpreadAvg),1)
           +"  "+BoolToStr(rmReversalAlert,"Alert!")+"\n"
           +"Profit Actions:  Profit: ("+IntegerToString(pmProfitLevel)+")"
           +"  "+DoubleToStr(FiboPercent(pmProfitLevel,InPercent),1)+"%"
           +"  "+BoolToStr(rmKillTrend,"Kill")
           +"  "+BoolToStr(rmKillHedge,"Kill Hedge")           
           +"\nExpansion: "+DoubleToStr(fractal.Fibonacci(Base,Expansion,Now,InPercent),1)+"%"
           +" "+DoubleToStr(fractal.Fibonacci(Base,Expansion,Max,InPercent),1)+"%"
           +"  Retrace: "+DoubleToStr(fractal.Fibonacci(Base,Retrace,Now,InPercent),1)+"%"
           +" "+DoubleToStr(fractal.Fibonacci(Base,Retrace,Max,InPercent),1)+"%"
           +"  Range: "+DoubleToStr(fractal.Range(Expansion,Max,InPips),1)+"\n"
           +"Divergent: "+DoubleToStr(fractal.Fibonacci(Divergent,Retrace,Now,InPercent),1)+"%"
           +" "+DoubleToStr(fractal.Fibonacci(Divergent,Retrace,Max,InPercent),1)+"%"
           +"  Range: "+DoubleToStr(fractal.Range(Divergent,Max,InPips),1)+"\n"
           +BoolToStr(fractal.IsConvergent(),
             +"Convergent: "+DoubleToStr(fractal.Fibonacci(Convergent,Retrace,Now,InPercent),1)+"%"
             +" "+DoubleToStr(fractal.Fibonacci(Convergent,Retrace,Max,InPercent),1)+"%"
             +"  Range: "+DoubleToStr(fractal.Range(Convergent,Max,InPips),1)+"\n")
           +"PipFractal Fibo (Term): "+DoubleToStr(pfractal.Fibonacci(Term,pfractal[Term].Direction,Expansion,Now,InPercent),1)+"%"
           +"  (Trend): "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal[Trend].Direction,Expansion,Now,InPercent),1)+"%");
           
    if (pfractal.Trendline(Head)>trend.Trendline(Head))
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrYellow);

    if (pfractal.Trendline(Head)<trend.Trendline(Head))
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrRed);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string otParams[];
    
    InitializeTick();

    GetData();    
    GetManualRequest();

    if (AppCommand(otParams))
    {
      //--- do something
    };

    OrderMonitor();
    
    if (pfractal.Event(HistoryLoaded))
    {
      if (AutoTrade())
        Execute();

      RefreshScreen();
    }
    else
    {
      InitializeApp();
    }

    ReconcileTick();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ManualInit();
    
    for (FibonacciLevels fibo=Fibo23;fibo<Fibo423;fibo++)
    {
      NewLine("fp"+IntegerToString(fibo));
      NewLine("fp"+IntegerToString(fibo+10));
      
      NewLabel("volH"+IntegerToString(fibo),"+"+DoubleToStr(FiboPercent(fibo,InPercent),1),650-(fibo*40),7,clrGray,SCREEN_UR);
      NewLabel("volH"+IntegerToString(fibo+10),"-"+DoubleToStr(FiboPercent(fibo,InPercent),1),650+(fibo*40),7,clrGray,SCREEN_UR);

      NewLabel("volL"+IntegerToString(fibo),"0.00",650-(fibo*40),20,clrGray,SCREEN_UR);
      NewLabel("volS"+IntegerToString(fibo),"0.00",650-(fibo*40),33,clrGray,SCREEN_UR);

      NewLabel("volL"+IntegerToString(fibo+10),"0.00",650+(fibo*40),20,clrGray,SCREEN_UR);
      NewLabel("volS"+IntegerToString(fibo+10),"0.00",650+(fibo*40),33,clrGray,SCREEN_UR);
    }    

    NewLabel("volH0","+0.0",650,7,clrGray,SCREEN_UR);
    NewLabel("volL0","0.00",650,20,clrGray,SCREEN_UR);
    NewLabel("volS0","0.00",650,33,clrGray,SCREEN_UR);

    NewLine("fp0");
    NewPriceLabel("pipMA");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete trend;
  }