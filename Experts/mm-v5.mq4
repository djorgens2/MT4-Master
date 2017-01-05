//+------------------------------------------------------------------+
//|                                                        mm-v5.mq4 |
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

input string inpMMHeader             = "";    //+----- MM inputs -----+
input double inpMaxLotDeficit        = 2.0;   // Maximum lots in drawdown


//--- Class definitions
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);  
  CTrendRegression *trend            = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);

   
//--- Event Record
       struct EventRec
       {
         int           EventType;
         int           Direction;
         double        Price;
         datetime      OpenTime;
         datetime      CloseTime;
       };

//--- MM States
       enum States
       {
         Hold,
         Hedge,
         Release,
         Stop
       };

//--- Operational variables
  int      mmTrendDir         = DirectionNone;
  int      mmTermDir          = DirectionNone;  
  
  bool     pfTermDirChanged   = false;
  bool     pfTrendDirChanged  = false;
  
  bool     fTermDirChanged    = false;
  bool     fTrendDirChanged   = false;


//--- Manager variables
  int      omAction           = OP_PEND;
  bool     omAlert            = false;
  
  double   omTrendOrderVolume[2][10];
  double   omTermOrderVolume[2][10];
  
  double   omOrderQuotaMax[2];
  double   omOrderQuotaMin[2];
   
  int      pmAction           = OP_NO_ACTION;
  bool     pmLockOrigin       = false;
  bool     pmLockTerm         = false;
  bool     pmLockProfit       = false;
  bool     pmLockInternal     = false;
  
  int      pmProfitLevel[RetraceTypeMembers];
    

//+------------------------------------------------------------------+
//| RefreshScreen - repaints screen data                             |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string rsReport   = "";
    string rsWork     = "";
    
    rsReport   +=       "\n*---------- PipMA Data --------------*\n";
    rsReport   +=       "Trend: " +DirText(pfractal.Direction(Trendline))
                       +" Poly: "+DirText(pfractal.Direction(Polyline))
                       +" "+DoubleToStr(pfractal.FOC(Now),1)
                       +" "+DoubleToStr(pfractal.FOC(Max),1)
                       +" "+DoubleToStr(pfractal.FOC(Deviation),1)
                       +" "+DoubleToStr(pfractal.FOC(Retrace)*100.0,2)+"%";

    if (pfractal.Event(NewHigh))
      rsReport       +=" (New High)\n\n";
    else
    if (pfractal.Event(NewLow))
      rsReport       +=" (New Low)\n\n";
    else
      rsReport       +="\n\n";

    rsReport         += "*---------- Fractal Data --------------*\n";

    rsReport         +=   "Trend: "+BoolToStr(fractal.Direction(Expansion)==DirectionUp,"Up","Down")+
                          +" "+EnumToString(fractal.Leg(Expansion,Peg))
                          +BoolToStr(fractal[Expansion].ReversalAlert,"  Alert!\n","\n")
                          +"    Origin:  (e)  "+DoubleToString(fractal.Fibonacci(Trend,Expansion,Origin,InPercent),1)+"%"
                          +"  (iv) "+DoubleToString(fractal.Fibonacci(Trend,Retrace,Origin,InPercent),1)+"%"
                          +"  Top: "+DoubleToStr(fractal.Range(Trend,Origin,Top),Digits)
                          +"  Bottom: "+DoubleToStr(fractal.Range(Trend,Origin,Bottom),Digits)+"\n"                          
                          +"    Trend:  (e)  "+DoubleToString(fractal.Fibonacci(Trend,Expansion,Now,InPercent),1)+"%"
                          +" "+DoubleToString(fractal.Fibonacci(Trend,Expansion,Max,InPercent),1)+"%"
                          +"  (rt) "+DoubleToString(fractal.Fibonacci(Trend,Retrace,Now,InPercent),1)+"%"
                          +" "+DoubleToString(fractal.Fibonacci(Trend,Retrace,Max,InPercent),1)
                          +"  Base: "+DoubleToStr(fractal.Price(Trend,Previous),Digits)
                          +"  Range: "+DoubleToStr(fractal.Range(Trend,Origin,Max,InPips),1)+"\n"
                          +"    Term:   (e)  "+DoubleToString(fractal.Fibonacci(Term,Expansion,Now,InPercent),1)+"%"
                          +" "+DoubleToString(fractal.Fibonacci(Term,Expansion,Max,InPercent),1)+"%"
                          +"  (rt) "+DoubleToString(fractal.Fibonacci(Term,Retrace,Now,InPercent),1)+"%"
                          +" "+DoubleToString(fractal.Fibonacci(Term,Retrace,Max,InPercent),1)+"%"
                          +"  Base: "+DoubleToStr(fractal.Price(Term),Digits)
                          +"  Range: "+DoubleToStr(fractal.Range(Term,Trend,Max,InPips),1)+"\n"
                          +"    Expansion: (iv)  "+DoubleToString(fractal.Fibonacci(Expansion,Inversion,Now,InPercent),1)+"%"
                          +" "+DoubleToString(fractal.Fibonacci(Expansion,Inversion,Max,InPercent),1)+"%\n\n";                         

    rsReport         +=   "Term:  "+EnumToString(fractal.Dominant(Trend))+" "+DirText(fractal.Direction(fractal.Dominant(Trend)))
                          +" "+EnumToString(fractal.Leg(fractal.Dominant(Trend),Peg))
                          +BoolToStr(fractal[fractal.Previous(fractal.Dominant(Term))].ReversalAlert," Alert!","");

    for (RetraceType leg=fractal.Dominant(Trend);leg<RetraceTypeMembers;leg++)
      if (fractal.Leg(leg,Level)>Tick)
        rsReport     +=    "\n    "+EnumToString(leg)+" "+DirText(fractal.Direction(leg))
                          +"  (e):  "+DoubleToStr(fractal.Fibonacci(leg,Expansion,Now,InPercent),1)+"% "
                                      +DoubleToStr(fractal.Fibonacci(leg,Expansion,Max,InPercent),1)+"%"
                          +"  (rt): "+DoubleToStr(fractal.Fibonacci(leg,Retrace,Now,InPercent),1)+"% "
                                      +DoubleToStr(fractal.Fibonacci(leg,Retrace,Max,InPercent),1)+"%"
                          +"  Range: "+DoubleToStr(fractal.Range(leg,Term,Max,InPips),1);

      Append(rsReport,"  "+rsWork);
                          

    rsReport         += "\n\n*---------- Term Data --------------*\n";
    rsReport         += "Direction: " +DirText(pfractal[Term].Direction)
                       +"  "+BoolToStr(pfractal.IsPegged(),
                               BoolToStr(pfractal.Count(Term)==0,"Initializing","Pegs ("+IntegerToString(pfractal.Count(Term))+")"),
                               "Unpegged")+"\n";
                       
    rsReport         += "Base: "     +DoubleToStr(pfractal[Term].Base,Digits)
                       +"  Root: "     +DoubleToStr(pfractal[Term].Root,Digits)
                       +"  Expansion: "+DoubleToStr(pfractal[Term].Expansion,Digits)
                       +"  Retrace: "  +DoubleToStr(pfractal[Term].Retrace,Digits)+"\n";
                       
    rsReport         += "Long Retrace: ("+DoubleToStr(pfractal.Fibonacci(Term,DirectionUp,Retrace,Now)*100,1)+"% "
                                         +DoubleToStr(pfractal.Fibonacci(Term,DirectionUp,Retrace,Max)*100,1)+"%)"
                       +"  Expansion: (" +DoubleToStr(pfractal.Fibonacci(Term,DirectionUp,Expansion,Now)*100,1)+"% "
                                         +DoubleToStr(pfractal.Fibonacci(Term,DirectionUp,Expansion,Max)*100,1)+"%)\n";

    rsReport         += "Short Retrace: ("+DoubleToStr(pfractal.Fibonacci(Term,DirectionDown,Retrace,Now)*100,1)+"% "
                                          +DoubleToStr(pfractal.Fibonacci(Term,DirectionDown,Retrace,Max)*100,1)+"%)"
                       +"  Expansion: ("  +DoubleToStr(pfractal.Fibonacci(Term,DirectionDown,Expansion,Now)*100,1)+"% "
                                          +DoubleToStr(pfractal.Fibonacci(Term,DirectionDown,Expansion,Max)*100,1)+"%)\n\n";
                                          
    rsReport         += "*---------- Trend Data --------------*\n";
    rsReport         += "Direction: "+BoolToStr(mmTrendDir==pfractal[Trend].Direction,"Trend","Term")
                       +"  "+DirText(pfractal[Trend].Direction)
                       +"  "+BoolToStr(pfractal.Count(Trend)==0,"Initializing\n","\n");
                               
    rsReport         += "Base: "     +DoubleToStr(pfractal[Trend].Base,Digits)
                       +"  Root: "     +DoubleToStr(pfractal[Trend].Root,Digits)
                       +"  Expansion: "+DoubleToStr(pfractal[Trend].Expansion,Digits)
                       +"  Retrace: "  +DoubleToStr(pfractal[Trend].Retrace,Digits)+"\n";                       
                       
    rsReport         += "Long Retrace: ("+DoubleToStr(pfractal.Fibonacci(Trend,DirectionUp,Retrace,Now)*100,1)+"% "
                                         +DoubleToStr(pfractal.Fibonacci(Trend,DirectionUp,Retrace,Max)*100,1)+"%)"
                       +"  Expansion: (" +DoubleToStr(pfractal.Fibonacci(Trend,DirectionUp,Expansion,Now)*100,1)+"% "
                                         +DoubleToStr(pfractal.Fibonacci(Trend,DirectionUp,Expansion,Max)*100,1)+"%)\n";
                                        
    rsReport         += "Short Retrace: ("+DoubleToStr(pfractal.Fibonacci(Trend,DirectionDown,Retrace,Now)*100,1)+"% "
                                          +DoubleToStr(pfractal.Fibonacci(Trend,DirectionDown,Retrace,Max)*100,1)+"%)"
                       +"  Expansion: ("  +DoubleToStr(pfractal.Fibonacci(Trend,DirectionDown,Expansion,Now)*100,1)+"% "
                                          +DoubleToStr(pfractal.Fibonacci(Trend,DirectionDown,Expansion,Max)*100,1)+"%)\n\n";

    if (pfractal.Count(Trend)>1)
    {
      rsReport       += "*----- Extended Trend Data ---------*\n";
      rsReport       += "Origin: "     +DoubleToStr(pfractal.Peg(Origin),Digits)
                       +"  Prior: "    +DoubleToStr(pfractal[Trend].Prior,Digits)
                       +"  Count: "    +IntegerToString(pfractal.Count(Trend))+"\n";

      rsReport       += "Origin Retrace: ("+DoubleToStr(pfractal.Fibonacci(Origin,pfractal[Trend].Direction,Retrace,Now)*100,1)+"% "
                                           +DoubleToStr(pfractal.Fibonacci(Origin,pfractal[Trend].Direction,Retrace,Max)*100,1)+"%)"
                       +"  Expansion: ("   +DoubleToStr(pfractal.Fibonacci(Origin,pfractal[Trend].Direction,Expansion,Now)*100,1)+"% "
                                           +DoubleToStr(pfractal.Fibonacci(Origin,pfractal[Trend].Direction,Expansion,Max)*100,1)+"%)\n\n";
    }
    
    rsReport         += "*---------- Manager Data --------------*\n";
    rsReport         += "Action: "+BoolToStr(omAction==OP_NO_ACTION,"Idle",proper(ActionText(omAction)))
                       +"  Trade State: "+EnumToString(TradeState())
                       +"  "+BoolToStr(omAlert,"Calculating","")+"\n"
                       +"Prices: (b) "+DoubleToStr(fractal[Base].Price,Digits)+"  (r) "+DoubleToStr(fractal[Root].Price,Digits)+"  (e) "+DoubleToStr(fractal[Expansion].Price,Digits)+"\n"
                       +"Levels: (e): "+DoubleToStr(FiboLevel(CurrentFiboLevel(Expansion),InPercent),1)+"%"
                       +"  (rt) "+DoubleToStr(FiboLevel(CurrentFiboLevel(Retrace),InPercent),1)+"%"
                       +"  (iv) "+DoubleToStr(FiboLevel(CurrentFiboLevel(Inversion),InPercent),1)+"%\n"
                       +"Locks:"+BoolToStr(pmLockOrigin," (o)")+BoolToStr(pmLockTerm," (tm)")+BoolToStr(pmLockProfit," (pf)")+BoolToStr(pmLockInternal," (int)");

                      
    Comment(rsReport);
    
    UpdateLine("mmOrigin",fdiv(fractal.Range(Trend,Origin,Max),2)+fractal.Range(Trend,Origin,Bottom),STYLE_SOLID,clrWhite);
    
    string godVolLong  ="";
    string godVolShort ="";
    string godVolMin   ="";
    string godVolMax   ="";

    for (int fibo=0;fibo<Fibo100;fibo++)
    {      
      godVolLong      += "   "+DoubleToStr(omTrendOrderVolume[OP_BUY][fibo],2);
      godVolShort     += "   "+DoubleToStr(omTrendOrderVolume[OP_SELL][fibo],2);
    }
    
    UpdateLabel("mmOrdVolLong",godVolLong,clrGray,7,"Courier New");
    UpdateLabel("mmOrdVolShort",godVolShort,clrGray,7,"Courier New");
    
    UpdateLabel("mmOrdVolMin",DoubleToStr(omOrderQuotaMin[OP_BUY],2),clrGray,7,"Courier New");
    UpdateLabel("mmOrdVolMax",DoubleToStr(omOrderQuotaMax[OP_BUY],2),clrGray,7,"Courier New");
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
     
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo823))
      arrowCode                     = SYMBOL_POINT4;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo423))
      arrowCode                     = SYMBOL_POINT3;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo261))
      arrowCode                     = SYMBOL_POINT2;
    else  
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo161))
      arrowCode                     = SYMBOL_POINT1;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo100))
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
//| CurrentFiboLevel - returns the current fibo level of Type        |
//+------------------------------------------------------------------+
int CurrentFiboLevel(int Method=Expansion)
  {
    int    cflLevel;
    
    for (cflLevel=0;cflLevel<10;cflLevel++)
      if (FiboLevel(cflLevel)>fractal.Fibonacci(Expansion,Method,Now))
        if (Method == Inversion)
          break;
        else
          return (cflLevel-1);
    
    return (cflLevel);
  }

//+------------------------------------------------------------------+
//| GetOrderData - Computes volume, eq%, and quota by fibo level     |
//+------------------------------------------------------------------+
void GetOrderData(void)
  {    
    double godFibonacciPrice  = NoValue;
    
    UpdatePriceLabel("mmFFiboTarget",FibonacciPrice(Fibo161,fractal[Base].Price,fractal[Root].Price));
    
    ArrayInitialize(omTermOrderVolume,0.00);
    ArrayInitialize(omTrendOrderVolume,0.00);
    ArrayInitialize(omOrderQuotaMax,0.00);
    ArrayInitialize(omOrderQuotaMin,0.00);

    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (Symbol()==OrderSymbol())
        {
          if (OrderType()==OP_BUY)
            godFibonacciPrice  = OrderOpenPrice()-Spread();
            
          if (OrderType()==OP_SELL)
            godFibonacciPrice  = OrderOpenPrice();

          for (int fibo=Fibo23;fibo<Fibo161;fibo++)        
          {
            if (fractal[Expansion].Direction==DirectionUp)
              if (godFibonacciPrice>FibonacciPrice(fibo,fractal[Root].Price,fractal[Expansion].Price))
              {
                 omTrendOrderVolume[OrderType()][fibo-1]  += OrderLots();
                 break;
              }
                
            if (fractal[Expansion].Direction==DirectionDown)
              if (godFibonacciPrice<FibonacciPrice(fibo,fractal[Root].Price,fractal[Expansion].Price))
              {
                 omTrendOrderVolume[OrderType()][fibo-1]  += OrderLots();
                 break;
              }

            if (fibo==Fibo161)
              omTrendOrderVolume[OrderType()][fibo]     += OrderLots();
          }
        } 
    for (int fibo=FiboRoot;fibo<Fibo161;fibo++)
    {
      for (int action=OP_BUY;action<OP_SELL;action++)
      {
        if (fibo<CurrentFiboLevel(Retrace))
          omOrderQuotaMax[action] += omTrendOrderVolume[action][fibo];

        if (fibo>CurrentFiboLevel(Retrace))
          omOrderQuotaMin[action] += omTrendOrderVolume[action][fibo];
      }
    }
  }
  
//+------------------------------------------------------------------+
//| GetData - retrieves data and calculates prelim stats             |
//+------------------------------------------------------------------+
void GetData(void)
  {
    static int gdLastDir[2][2] = {{DirectionNone,DirectionNone},{DirectionNone,DirectionNone}};
    
    pfractal.Update();
    trend.Update();
    fractal.Update();

    //--- Set micro properties
    pfTermDirChanged          = false;
    pfTrendDirChanged         = false;
    
    if (IsChanged(gdLastDir[Term][Term],pfractal[Term].Direction))
      pfTermDirChanged        = true;
      
    if (IsChanged(gdLastDir[Term][Trend],pfractal[Trend].Direction))
      pfTrendDirChanged       = true;              

    if (pfractal.Event(HistoryLoaded))
    {
      mmTermDir               = dir(pfractal.Trendline(Head)-trend.Trendline(Head));
      
      if (mmTrendDir == DirectionNone)
        mmTrendDir            = fractal[Expansion].Direction;

      if (pfractal.Count(Trend)>1)
        mmTrendDir            = pfractal.Direction(Trend);
    }

    //--- Set macro properties
    fTermDirChanged           = false;
    fTrendDirChanged          = false;
    
    if (IsChanged(gdLastDir[Trend][Term],fractal[fractal.Dominant(Term)].Direction))
      fTermDirChanged         = true;              

    if (IsChanged(gdLastDir[Trend][Trend],fractal[Expansion].Direction))
      fTrendDirChanged        = true;

    SetFiboArrow(pfractal.Direction(Term));
    UpdateDirection("pfPipMATrend",mmTermDir,DirColor(mmTermDir));
    GetOrderData();
  }

//+------------------------------------------------------------------+
//| TradeState - returns trending or hedging states                  |
//+------------------------------------------------------------------+
States TradeState(void)
  {
    static States tsLastState     = Hold;
           States tsState         = Hold;
    static int    tsLastTrendDir  = DirectionNone;
           int    tsTermDir       = mmTermDir;
    
    if (mmTermDir == DirectionNone)
      if (trend.Direction(Trendline) == DirectionNone)
        return (tsLastState);
      else
        tsTermDir = pfractal.Direction(Trendline);
        
    if (trend.Direction(Trendline) != DirectionNone)
      tsLastTrendDir              = trend.Direction(Trendline);
    
    if (tsTermDir != tsLastTrendDir)
      tsState += 1;
      
    if (fabs(trend.FOC(Retrace))>=FiboLevel(Fibo50))
      tsState += 2;
      
    tsLastState                   = tsState;
      
    return (tsState);
  }
  
//+------------------------------------------------------------------+
//| AuthorizeReason -  returns text description of the authorization |
//+------------------------------------------------------------------+
string AuthorizeReason(int Reason)
  {  
    switch (Reason)
    {
      case (0):    return("Application Initializing");
      case (-1):   return("No action");
      case (-2):   return("System halted");
      case (-3):   return("Maximum deficit exceeded");
      case (-4):   return("Maximum quota exceeded");
      case (-5):   return("Recommend TotS ("+BoolToStr(omAction==OP_BUY,"Sell","Buy")+")");
      case (-11):  return("Contrarian not supported");
      case (2):    return("Trend retrace authorization\n"
                           +"Expansion: "+DoubleToStr(FiboLevel(CurrentFiboLevel(Expansion),InPercent),1)+"%\n"
                           +"Inversion: "+DoubleToStr(FiboLevel(CurrentFiboLevel(Inversion),InPercent),1)+"%");
      case (3):    return("Trend pegged retrace authorization\n"
                           +"Expansion: "+DoubleToStr(FiboLevel(CurrentFiboLevel(Expansion),InPercent),1)+"%\n"
                           +"Inversion: "+DoubleToStr(FiboLevel(CurrentFiboLevel(Inversion),InPercent),1)+"%");
      case (4):    return("Trap contrarian authorization ("+ActionText(omAction)+")");
      case (5):    return("TotS authorization ("+ActionText(omAction)+")");
      case (-13):  return("Inversion level exceeded; recommend contrarian");
      case (-14):  return("Trap handling not supported");
      case (-15):  return("Preparing for profit taking");
      case (-16):  return("Preparing for reversal @23f");
      case (-17):  return("Breakout addition not supported");
    }
    
    return ("Bad Reason Code");
  }
  
//+------------------------------------------------------------------+
//| Authorized -  authorizes trade based on fibo/trend analysis      |
//+------------------------------------------------------------------+
int Authorized(int &Action)
  {  
    bool    aAuthorized      = false;
    int     aPendingAuth     = 0;
    bool    aContrarian      = Action!=DirectionAction(fractal[Expansion].Direction);
  
    //--- Early return conditions
    if (Action==OP_PEND)
      return (0);

    if (Action==OP_NO_ACTION)
      return (-1);

    if (Action==OP_HALT)
      return (-2);

    //--- Contrarian Strategies
    if (aContrarian)
    {
      //--- Tip-of-the-Spear (TotS)
      if (!pfractal.IsPegged())
      {
        if (fractal.IsDivergent() && fractal.Fibonacci(Divergent,Retrace,Max)<FiboLevel(Fibo100))
          if (fractal.Fibonacci(Convergent,Retrace,Max)<FiboLevel(Fibo50))
            if (mmTrendDir == fractal[Expansion].Direction)
              if (!fractal[Expansion].ReversalAlert)
              {
                aPendingAuth  = -5;
                Action        = DirectionAction(mmTrendDir);
              }
      }
      
      //--- contrarian reject
      else                  
        return (-11);
    }
    
    if (omOrderQuotaMax[Action]>LotSize()*inpMaxLotDeficit)
      return (-3);
       
    if (omTrendOrderVolume[Action][CurrentFiboLevel(Retrace)]>=LotSize())
      return (-4);
      
    switch (fractal.Leg(Expansion,Peg))
    {
      case Reversal:
      case Breakout: if (CurrentFiboLevel(Inversion)>Fibo23)
                       if (CurrentFiboLevel(Expansion)>0)

                         //--- Retrace trades
                         if (CurrentFiboLevel(Expansion)<Fibo100)
                         {
                           if (CurrentFiboLevel(Retrace)>Fibo23)
                             return (2);
                           else
                           if (CurrentFiboLevel(Retrace)==Fibo23 && pfractal.IsPegged())
                             return (3);
                           else
                             return (-17);
                         }
                         else

                         //--- Expansion trades
                         {
                           if (aPendingAuth == -5)
                             if (LotValue(omAction,InNet)>0.00)
                               return (5);
                             else
                               return (aPendingAuth);
                           else
                             return (-15);
                         }
                       else
                         return(-16);
                     else
                       return (-13);
                       
                     break;
                       
      case Trap:     if (fractal.Fibonacci(Expansion,Expansion,Max)<FiboLevel(Fibo161))
                       return (-14);  //wip
                       
                     if (fractal.Fibonacci(Expansion,Retrace,Now)>FiboLevel(Fibo50))
                       if (fractal.Fibonacci(Expansion,Inversion,Max)>FiboLevel(Fibo23))
                         return (4);
    }


    return (aPendingAuth);
  }
 
//+------------------------------------------------------------------+
//| AuthorizeResult -  opens the authorization dialog                |
//+------------------------------------------------------------------+
void AuthorizeResult(string Title, int Action, int AuthCode)
  {
    static int mbIgnore     = 0;
    static int mbResult     = IDOK;

    if (mbResult == IDABORT)
      return;

    if (AuthCode == mbIgnore)
      return;
      
    mbResult   = Pause("Auth Code: "+IntegerToString(AuthCode)
                      +"\nAction: "+ActionText(Action)
                      +"\nReason: "+AuthorizeReason(AuthCode),Title,
                   MB_ICONINFORMATION|MB_ABORTRETRYIGNORE|MB_DEFBUTTON3);
                 
    if (mbResult == IDIGNORE)
      mbIgnore = AuthCode;
  }

//+------------------------------------------------------------------+
//| OrderManager -  Manages order entry execution                    |
//+------------------------------------------------------------------+
void OrderManager(void)
  {
    static int  omLastPolyDir  = DirectionNone;
           int  omAuthCode     = 0;
           int  omOrderAction  = OP_NO_ACTION;
    
    if (omAction == OP_PEND)
    {
      omAction                 = DirectionAction(fractal[Expansion].Direction);
    }
    else
    if (IsChanged(omAction,DirectionAction(pfractal[Term].Direction,InContrarian)))
    {
      //--- Scalper
//      if (DirectionAction(omLastPolyDir,InContrarian) == omAction)
//        if (Authorized(omAction))
//          OpenOrder(omAction,"Auto-Scalp");
      
      omAlert                  = true;
      omLastPolyDir            = pfractal.Direction(Polyline);
    }
   
    if (omAlert)
    {
      if (IsChanged(omLastPolyDir,pfractal.Direction(Polyline)))
      {
        omAuthCode             = Authorized(omAction);
        
        if (omAuthCode>0)
        {
          if (DirectionAction(omLastPolyDir) == omAction)
            OpenOrder(omAction,"Auto("+IntegerToString(omAuthCode)+")");

          if (OrderFulfilled())
          {
            AuthorizeResult("Authorization Granted",omAction,omAuthCode);

            omAlert            = false;
            omAction           = OP_NO_ACTION;
          }
        }
        else
          AuthorizeResult("Authorization Rejected",omAction,omAuthCode);
      }
    }
  }

//+------------------------------------------------------------------+
//| RiskManager - Manages risk and drawdown; minimize loss           |
//+------------------------------------------------------------------+
void RiskManager(void)
  {
/*    static int mbResult = IDOK;
    
    if (omAction == OP_NO_ACTION)
      mbResult = IDOK;
      
    if (mbResult == IDOK)
    {
      if (omAction == OP_BUY)
        if (LotValue(OP_BUY,InNet,InDollar)<0.00);
//          mbResult = Pause ("What to do with the longs?", "Risk Manager",MB_OKCANCEL|MB_ICONQUESTION|MB_DEFBUTTON2);

      if (omAction == OP_SELL)
        if (LotValue(OP_SELL,InNet,InDollar)<0.00);
//          mbResult = Pause ("What to do with the shorts?", "Risk Manager",MB_OKCANCEL|MB_ICONQUESTION|MB_DEFBUTTON2);
    }
*/
  }

//+------------------------------------------------------------------+
//| ProfitManager - Manages profitable trades; maximize profit       |
//+------------------------------------------------------------------+
void ProfitManager(void)
  {
    static double pmLastPolyDir   = DirectionNone;
           double pmLotCount      = LotCount();
    
    pmAction                      = DirectionAction(mmTrendDir);
    
    //--- Set profit levels
    if (fTrendDirChanged)
    {
      pmProfitLevel[Expansion]    = Fibo161;
      pmProfitLevel[Term]         = Fibo161;
      pmProfitLevel[Trend]        = Fibo161;
    }
    
    //--- Validate positions on pfTrend change
    if (pfTrendDirChanged)
    {
      pmLockOrigin                = false;
      pmLockTerm                  = false;
      pmLockProfit                = false;
      pmLockInternal              = false;
    }
    
    //--- Set/Release term lock
    if (pfractal.Fibonacci(Term,mmTrendDir,Expansion,Now)>FiboLevel(Fibo261))
      pmLockTerm                  = true;
    else
    if (pfractal.Fibonacci(Term,mmTrendDir,Expansion,Max)<FiboLevel(Fibo261))
      if (pfractal.Fibonacci(Term,mmTrendDir,Expansion,Max)>FiboLevel(Fibo161))
        pmLockTerm                = false;

    //--- Set/Release the origin lock;
    if (pfractal.IsPegged())
      pmLockOrigin                = false;
    else
    {
      if (IsEqual(fractal.Fibonacci(Trend,Inversion,Origin),0.00))
        pmLockOrigin              = true;

      pmLockProfit                = true;
    }
    
    if (pmLockOrigin)
      return;
    
    if (!pmLockTerm && !pmLockProfit)
    {
      if (fractal.Fibonacci(Trend,Expansion,Max)>FiboLevel(pmProfitLevel[Trend]))
         if (CloseOrders(CLOSE_CONDITIONAL,pmAction,"Trend level close"))
           pmProfitLevel[Trend]++;
           
      if (fractal.Fibonacci(Term,Expansion,Max)>FiboLevel(pmProfitLevel[Term]))
         if (CloseOrders(CLOSE_CONDITIONAL,pmAction,"Term level close"))
           pmProfitLevel[Term]++;

      if (fractal.Fibonacci(Expansion,Expansion,Max)>FiboLevel(pmProfitLevel[Expansion]))
         if (CloseOrders(CLOSE_CONDITIONAL,pmAction,"Expansion level close"))
           pmProfitLevel[Expansion]++;
    }
    
    if (pfractal.IsPegged())
    {
      if (pmLockProfit)
      {
        if (pfractal.Fibonacci(Term,pfractal[Term].Direction,Expansion,Now)>FiboLevel(Fibo100))
          if (pfractal.Direction(Polyline) != mmTrendDir)
            if (pfractal.Fibonacci(Origin,mmTrendDir,Expansion,Now)>FiboLevel(Fibo100))
              if (fractal.Fibonacci(Expansion,Expansion,Now)>FiboLevel(Fibo61))
                if (CloseOrders(CLOSE_CONDITIONAL,pmAction,"Pegged Level Retrace "))
                  pmLockProfit   = false;
      }
    }
    else
    {
      //--- Handle late profits
      if (!pmLockTerm)
      {
        if (pfractal.Fibonacci(Origin,mmTrendDir,Expansion,Now)>FiboLevel(Fibo161))
          if (pfractal[Trend].Direction == mmTrendDir)
            if (pfractal.Fibonacci(Origin,mmTrendDir,Expansion,Now)>FiboLevel(Fibo100))
              //--- should implement a trailing mechanism here....
//              if (pfractal.FOC(Deviation)>0.00)
                if (CloseOrders(CLOSE_CONDITIONAL,pmAction,"Origin Fractal"))
                  pmLockProfit  = false;
        
        //--- interior profit
        if (!pmLockInternal)
          if (pfractal.Fibonacci(Trend,mmTrendDir,Expansion,Now)>FiboLevel(Fibo161))
            if (fractal.Fibonacci(Expansion,Expansion,Max)>FiboLevel(Fibo100))
              if (fractal.Fibonacci(Expansion,Expansion,Max)>fractal.Fibonacci(Expansion,Expansion,Now))
                if (pfractal.Fibonacci(Origin,mmTrendDir,Expansion,Max)<FiboLevel(Fibo100))
                  if (CloseOrders(CLOSE_CONDITIONAL,DirectionAction(pfractal[Trend].Direction),"Interior term profit"))
                    pmLockInternal   = true;
      }
    }
    
/*
      if (!pmLockProfit)
      {
        if (pfractal.IsPegged())
        {
          //--- term profit
          if (fractal.Fibonacci(Expansion,Expansion,Now)>FiboLevel(pmProfitLevel[Expansion]))
            if (fractal.Fibonacci(Term,Expansion,Now)>FiboLevel(pmProfitLevel[Term]))
              if (CloseOrders(CLOSE_MIN,DirectionAction(mmTrendDir),"Term Close"))
              {
                pmProfitLevel[Expansion]++;
                pmProfitLevel[Term]++;
              }
              
          //--- trend profit
          if (fractal.Fibonacci(Trend,Expansion,Now)>FiboLevel(pmProfitLevel[Trend]))
            if (CloseOrders(CLOSE_MIN,DirectionAction(mmTrendDir),"Trend Close"))
              pmProfitLevel[Trend]++;
        }
      }
     
    if (!IsEqual(pmLotCount,LotCount(),ordLotPrecision))
      Pause ("Took profit at "+whereClose
            +"\nAction: "+ActionText(pmAction)
            +"\nLotCount(): "+DoubleToStr(LotCount(),2)
            +"\npmLotCount: "+DoubleToStr(pmLotCount,2)
            +"\npmTrendLevel: "+DoubleToStr(FiboLevel(pmProfitLevel[Trend],InPercent),1)+"%"
            +"\npmTermLevel: "+DoubleToStr(FiboLevel(pmProfitLevel[Term],InPercent),1)+"%"
            +"\npmExpansionevel: "+DoubleToStr(FiboLevel(pmProfitLevel[Expansion],InPercent),1)+"%","Profit Taken");
*/ 
  }

/*
//+------------------------------------------------------------------+
//| StrategyManager - Sets the objectives                            |
//+------------------------------------------------------------------+
void StrategyManager(void)
  {
    //--- Reset levels on Divergence
    if (pfTrendDirChanged)
    {
      smTargetLevel[Expansion]    = Fibo161;
      smTargetLevel[Term]         = Fibo161;
      smTargetLevel[Trend]        = Fibo161;
    }
  }
*/

//+------------------------------------------------------------------+
//| ExecuteTick - Executes trades, manages risk, takes profit        |
//+------------------------------------------------------------------+
void ExecuteTick(void)
  {
    static int mbResult    = IDOK;

    if (pfractal.Event(HistoryLoaded))
    {
      if (mbResult == IDOK)
        mbResult = Pause("PipMA History is loaded","Event: HistoryLoaded",MB_OKCANCEL|MB_ICONINFORMATION|MB_DEFBUTTON2);

      OrderManager();
      RiskManager();
      ProfitManager();
    }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string otParams[];
    
    GetData();
    
    GetManualRequest();

    if (AppCommand(otParams))
    {
      //--- do something
    };

    OrderMonitor();
    
    if (AutoTrade())
      ExecuteTick();
    
    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();

    NewLabel("mmOrdVol","",700,5);
    
    pmProfitLevel[Trend]       = Fibo161;
    pmProfitLevel[Term]        = Fibo161;
    pmProfitLevel[Expansion]   = Fibo161;

    UpdateLabel("mmOrdVol","    <23    <38    <50    <61   <100",clrWhite,7,"Courier New");
//    UpdateLabel("mmOrdVol","    0.0   23.6   38.2   50.0   61.8  100.0  161.8  261.8  423.6  823.6",clrWhite,7,"Courier New");

    NewLabel("mmOrdVolLong","",700,16);
    NewLabel("mmOrdVolShort","",700,27);
    NewLabel("mmOrdVolMin","",700,38);
    NewLabel("mmOrdVolMax","",700,49);
    
    NewLine("mmOrigin");
    
    NewLabel("pfPipMATrend","",264,60,clrDarkGray,SCREEN_LL);
    NewPriceLabel("mmFFiboTarget");
    
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
