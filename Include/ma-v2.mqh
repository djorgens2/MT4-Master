//+------------------------------------------------------------------+
//|                                                        ma-v2.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property strict

//--- ma Trend States
#define MA_L_TREND_SHORT      1
#define MA_L_TREND_CORR       2
#define MA_L_TREND_RALLY      3
#define MA_L_TREND_SOFT       4 
#define MA_L_TREND_STRONG     5
#define MA_L_TREND_MAX        6

#define MA_S_TREND_NONE       0

#define MA_S_TREND_LONG      -1
#define MA_S_TREND_CORR      -2
#define MA_S_TREND_PULLBACK  -3
#define MA_S_TREND_SOFT      -4 
#define MA_S_TREND_STRONG    -5
#define MA_S_TREND_MAX       -6

//--- ma Order quota
#define MA_ORDER_QUOTA_MEASURES  5
#define MA_ORDER_QUOTA           0
#define MA_ORDER_OPEN            1
#define MA_ORDER_IN_PROFIT       2
#define MA_ORDER_AT_RISK         3
#define MA_ORDER_AUTH            4

double  maOrderQuota[2][MA_ORDER_QUOTA_MEASURES];    //--- Order fill quota 

//--- Operational Variables
int    maTrendState       = 0;
int    maTradeState       = STR_NONE;
bool   maTradeDivergent   = false;
bool   maTrendDivergent   = false;

double maLTradeState[1000][2];
double maSTradeState[1000][3];
int    maLTradeStateIdx   = 0;
int    maSTradeStateIdx   = 0;

double maPriceLevels[5];

bool   maLongAuth         = false;
bool   maShortAuth        = false;
int    maLongAuthCnt      = 0;
int    maShortAuthCnt     = 0;

//+------------------------------------------------------------------+
//| maQuotaText - Translates quota array dimensions to text          |
//+------------------------------------------------------------------+
string maQuotaText(int Measure)
  {
    switch(Measure)
    {
      case MA_ORDER_QUOTA:     return("QUOTA");
      case MA_ORDER_OPEN:      return("OPEN");
      case MA_ORDER_IN_PROFIT: return("PROFIT");
      case MA_ORDER_AT_RISK:   return("AT RISK");
      case MA_ORDER_AUTH:      return("AUTHORIZED");
    }
    
    return ("INVALID QUOTA MEASURE");
  }      

//+------------------------------------------------------------------+
//| maTrendText - Translates trend state into text          |
//+------------------------------------------------------------------+
string maTrendText(int State)
  {
    switch(State)
    {
      case MA_L_TREND_SHORT:      return("SHORT");
      case MA_L_TREND_CORR:       return("CORRECTION LONG");
      case MA_L_TREND_RALLY:      return("RALLY");
      case MA_L_TREND_SOFT:       return("SOFT LONG"); 
      case MA_L_TREND_STRONG:     return("STRONG LONG");
      case MA_L_TREND_MAX:        return("MAX LONG");

      case MA_S_TREND_NONE:       return("NO TREND");

      case MA_S_TREND_LONG:       return("LONG");
      case MA_S_TREND_CORR:       return("CORRECTION (SHORT)");
      case MA_S_TREND_PULLBACK:   return("PULLBACK");
      case MA_S_TREND_SOFT:       return("SOFT SHORT"); 
      case MA_S_TREND_STRONG:     return("STRONG SHORT");
      case MA_S_TREND_MAX:        return("MAX SHORT");
    
    }
    
    return ("INVALID TREND STATE");
  }      

/*
//+------------------------------------------------------------------+
//| maCalcTradeState - Analyzes data, estimates strength, recommends |
//+------------------------------------------------------------------+
void maCalcTradeState()
  {
    if (data[dataFOCTrendDir]!=dataLast[dataFOCTrendDir])
    {
      if (dataLast[dataFOCTrendDir]==DIR_UP)
      {
        maLTradeState[maLTradeStateIdx][0]=ordLastBid;
        maLTradeState[maLTradeStateIdx][1]=dataLast[dataFOCMax];
        maLTradeStateIdx++;        
      }
      
      if (dataLast[dataFOCTrendDir]==DIR_DOWN)
      {
        maSTradeState[maLTradeStateIdx][0]=ordLastBid;
        maSTradeState[maLTradeStateIdx][1]=dataLast[dataFOCMax];
        maSTradeStateIdx++;        
      }
    
      if (dataLast[dataFOCTrendDir]!=DIR_NONE)
      if (MathMod((maSTradeStateIdx+maLTradeStateIdx),50)==0)
        for (int idx=maSTradeStateIdx-25;idx<maSTradeStateIdx;idx++)
          Print("|"+DoubleToStr(maLTradeState[idx][0],Digits)+
                "|"+DoubleToStr(maSTradeState[idx][0],Digits)+
                "|"+DoubleToStr(maLTradeState[idx][1],1)+
                "|"+DoubleToStr(maSTradeState[idx][1],1)+
                "|"
               );
    }
    
  }
*/

//+------------------------------------------------------------------+
//| maCalcTrendState - Analyzes data, estimates strength, recommends |
//+------------------------------------------------------------------+
void maCalcTrendState()
  {
    int    position = 0;
    double dirPrice = 0.00;
    
    maPriceLevels[0] = regrComp[compMajorPivot];
    maPriceLevels[1] = regrFast[regrTLHigh];
    maPriceLevels[2] = regrFast[regrTLLow];
    maPriceLevels[3] = regrComp[compFastPolySTTLHead];
    maPriceLevels[4] = regrComp[compFastPolySTTLTail];
    
    ArraySort(maPriceLevels,WHOLE_ARRAY,0,MODE_DESCEND);
    
    if (data[dataRngDir]==DIR_UP)
      dirPrice  = data[dataRngHigh];
    else
      dirPrice  = data[dataRngLow];
      
    for (position=0;position<5;position++)
      if (dirPrice>maPriceLevels[position])
        break;
        
    if (data[dataRngDir]==DIR_UP)
    {
      maTrendState = 6 - (position);

      if (regrFast[regrFOCTrendDir] == DIR_UP)
        maTrendDivergent = false;
      else
        maTrendDivergent = false;      
    }
    else
    {
      maTrendState = (position+1)*DIR_DOWN;

      if (regrFast[regrFOCTrendDir] == DIR_DOWN)
        maTrendDivergent = true;
      else
        maTrendDivergent = false;      
    }
  }

//+------------------------------------------------------------------+
//| maCalcTradeState - Analyzes data, estimates strength, recommends |
//+------------------------------------------------------------------+
void maCalcTradeState()
  {     
     int lastState    = maTradeState;
     
     maTradeState     = STR_NONE;
     maTrendDivergent = false;

     if (data[dataRngDir]==DIR_UP)
     {
       if (regrFast[regrPolyDirST] == DIR_DOWN)
         maTrendDivergent = true;

       for (int idx=dataRngLow;idx<=dataRngHigh;idx++)
       {
         if (data[idx]>regrFast[regrPolyLastBottom])
           maTradeState++;
           
         if (data[idx]>regrFast[regrPolyLastTop])
           maTradeState++;           

         maTradeState = (int)MathCeil((data[dataRngDir]+regrFast[regrFOCTrendDir]+maTradeState)/2);
       }
     }
     
     if (data[dataRngDir] == DIR_DOWN)
     {
       if (regrFast[regrPolyDirST] == DIR_UP)
         maTrendDivergent = true;     

       for (int idx=dataRngLow;idx<=dataRngHigh;idx++)
       {
         if (data[idx]<regrFast[regrPolyLastBottom])
           maTradeState--;
           
         if (data[idx]<regrFast[regrPolyLastTop])
           maTradeState--;
       }

       maTradeState = (int)MathFloor((data[dataRngDir]+regrFast[regrFOCTrendDir]+maTradeState)/2);
     }
  }

//+------------------------------------------------------------------+
//| maCalcOrderQuota - determines total lots needed for each dir     |
//+------------------------------------------------------------------+
void maCalcOrderQuota()
  {
    double lastQuota  = maOrderQuota[OP_BUY][MA_ORDER_QUOTA]- maOrderQuota[OP_SELL][MA_ORDER_QUOTA];
    
    ArrayInitialize(maOrderQuota,0.00);
    
    //--- Calculate long quota
    if (regrFast[regrPolyST]>regrSlow[regrTLCur])
      maOrderQuota[OP_BUY][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]>regrSlow[regrPolyLT])
      maOrderQuota[OP_BUY][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]>regrSlow[regrPolyST])
      maOrderQuota[OP_BUY][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]>regrFast[regrTLCur])
      maOrderQuota[OP_BUY][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]>regrFast[regrPolyLT])
      maOrderQuota[OP_BUY][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]>regrComp[compFastPolySTTLHead])
      maOrderQuota[OP_BUY][MA_ORDER_QUOTA] += LotSize();
      
    maOrderQuota[OP_BUY][MA_ORDER_OPEN]      = LotCount(LOT_LONG_NET);
    maOrderQuota[OP_BUY][MA_ORDER_IN_PROFIT] = LotCount(LOT_LONG_PROFIT);
    maOrderQuota[OP_BUY][MA_ORDER_AT_RISK]   = LotCount(LOT_LONG_LOSS);
    
    //--- Calculate short quota
    if (regrFast[regrPolyST]<regrSlow[regrTLCur])
      maOrderQuota[OP_SELL][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]<regrSlow[regrPolyLT])
      maOrderQuota[OP_SELL][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]<regrSlow[regrPolyST])
      maOrderQuota[OP_SELL][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]<regrFast[regrTLCur])
      maOrderQuota[OP_SELL][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]<regrFast[regrPolyLT])
      maOrderQuota[OP_SELL][MA_ORDER_QUOTA] += LotSize();
    if (regrFast[regrPolyST]<regrComp[compFastPolySTTLHead])
      maOrderQuota[OP_SELL][MA_ORDER_QUOTA] += LotSize();

    maOrderQuota[OP_SELL][MA_ORDER_OPEN]      = LotCount(LOT_SHORT_NET);
    maOrderQuota[OP_SELL][MA_ORDER_IN_PROFIT] = LotCount(LOT_SHORT_PROFIT);
    maOrderQuota[OP_SELL][MA_ORDER_AT_RISK]   = LotCount(LOT_SHORT_LOSS);
    
    if (lastQuota!=maOrderQuota[OP_BUY][MA_ORDER_QUOTA] - maOrderQuota[OP_SELL][MA_ORDER_QUOTA])
    {
      if (lastQuota == 0.00)
      {
//        maShortAuth = false;
//        maLongAuth  = false;
      }
      else
      if (lastQuota<maOrderQuota[OP_BUY][MA_ORDER_QUOTA] - maOrderQuota[OP_SELL][MA_ORDER_QUOTA])
      {
        maLongAuth  = true;
        maLongAuthCnt++;
      }
      else
      if (lastQuota>maOrderQuota[OP_BUY][MA_ORDER_QUOTA] - maOrderQuota[OP_SELL][MA_ORDER_QUOTA])
      {
        maShortAuth = true;
        maShortAuthCnt++;
      }
      else
      {
        maShortAuth = true;
        maLongAuth  = true;

        maLongAuthCnt++;
        maShortAuthCnt++;
      }
    }
    
    if (maShortAuth && maLongAuth)
    {
      maOrderQuota[OP_BUY][MA_ORDER_AUTH]   = fmin(maOrderQuota[OP_BUY][MA_ORDER_QUOTA]-maOrderQuota[OP_BUY][MA_ORDER_OPEN],
                                                   LotSize()*maLongAuthCnt);
      maOrderQuota[OP_SELL][MA_ORDER_AUTH]  = fmin(maOrderQuota[OP_SELL][MA_ORDER_QUOTA]-maOrderQuota[OP_SELL][MA_ORDER_OPEN],
                                                   LotSize()*maShortAuthCnt);
    }
    else
    if (maShortAuth)
    {
      maOrderQuota[OP_SELL][MA_ORDER_AUTH]  = fmin(maOrderQuota[OP_SELL][MA_ORDER_QUOTA]-maOrderQuota[OP_SELL][MA_ORDER_OPEN],
                                                   LotSize()*maShortAuthCnt);
      maOrderQuota[OP_BUY][MA_ORDER_AUTH]   = maOrderQuota[OP_SELL][MA_ORDER_AUTH]-maOrderQuota[OP_BUY][MA_ORDER_OPEN];
    }
    else
    if (maLongAuth)
    {
      maOrderQuota[OP_BUY][MA_ORDER_AUTH]   = fmin(maOrderQuota[OP_BUY][MA_ORDER_QUOTA]-maOrderQuota[OP_BUY][MA_ORDER_OPEN],
                                                   LotSize()*maLongAuthCnt);      
      maOrderQuota[OP_SELL][MA_ORDER_AUTH]  = maOrderQuota[OP_BUY][MA_ORDER_AUTH]-maOrderQuota[OP_SELL][MA_ORDER_OPEN];
    }
    else
    {
      maOrderQuota[OP_BUY][MA_ORDER_AUTH]   = 0.00;
      maOrderQuota[OP_SELL][MA_ORDER_AUTH]  = 0.00;
    }
    
  }

//+------------------------------------------------------------------+
//| MarketAnalystReport - Reports on statistical analysis/conclusions|
//+------------------------------------------------------------------+
string MarketAnalystReport()
  {
    string strMgmtRpt = "Trend: "+maTrendText(maTrendState)+" Trade: "+StrengthText(maTradeState);
    string strLReport = "";
    string strSReport = "";
    
    if (maTrendDivergent)
      strMgmtRpt += " (D)\n";
    else
      strMgmtRpt += " (C)\n";
      
//    strMgmtRpt += DoubleToStr(regrFast[regrPolyLastTop],Digits)+" "+DoubleToStr(regrFast[regrPolyLastBottom],Digits)+"\n";  
    
    //--- Market Analyst report    
    for (int idx=0;idx<MA_ORDER_QUOTA_MEASURES;idx++)
    {
      if (maOrderQuota[OP_BUY][idx]!=0.00)
        strLReport += " "+proper(maQuotaText(idx))+":"+DoubleToStr(maOrderQuota[OP_BUY][idx],2);

      if (maOrderQuota[OP_SELL][idx]!=0.00)
        strSReport += " "+proper(maQuotaText(idx))+":"+DoubleToStr(maOrderQuota[OP_SELL][idx],2);
    }
    
    if (StringLen(strLReport)>0)
      strMgmtRpt += "Long "+strLReport+"\n";

    if (StringLen(strSReport)>0)
      strMgmtRpt += "Short"+strSReport+"\n";

    
    return (strMgmtRpt);
  }

//+------------------------------------------------------------------+
//| CallMarketAnalyst - Analyzes data, makes recommendations         |
//+------------------------------------------------------------------+
void CallMarketAnalyst()
  {
    maCalcTrendState();
    maCalcTradeState();                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               
    maCalcOrderQuota();
  }
  
//+------------------------------------------------------------------+
//| maInit()- Init things for the MA to do                           |
//+------------------------------------------------------------------+
void maInit()
  {
    //--- configure order parameters
    eqhalf   = true;
    eqprofit = true;
    eqdir    = true;
    
    SetRisk(ordMaxRisk*(inpRiskMgmtAlert+inpRiskDCALevel),ordLotRisk);
    SetEquityTarget(ordMinTarget,ordMinProfit);
    
    //--- configure ma operational vars
    ArrayInitialize(maLTradeState,0.00);
    ArrayInitialize(maSTradeState,0.00);
  }    
