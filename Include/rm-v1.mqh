//+------------------------------------------------------------------+
//|                                                        rm-v1.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property strict

input  double inpRiskMgmtAlert = 0.8;  // Risk Manager activation level
input  double inpRiskDCALevel  = 1.8;  // Risk Manager DCA point

//--- Risk Manager
int    rmLastTicket       = 0;
int    rmLastOrderType    = OP_NO_ACTION;
double rmLastOrderProfit  = 0.00;

double rmMajorPivot       = 0.00;

double rmLotCount         = 0.00;
double rmEQAfterOpen      = 0.00;
double rmEQAfterClose     = 0.00;

bool   rmAlert            = false;
int    rmAlertAction      = OP_NO_ACTION;

bool   rmHedge            = false;
bool   rmDCA              = false;

//+------------------------------------------------------------------+
//| RiskManagerApproval - Overrides PM/OM requests to mitigate risk  |
//+------------------------------------------------------------------+
bool RiskManagerApproval(int Type=OP_NO_ACTION, int Action=OP_NO_ACTION, bool Hedge=false)
  {
    //--- Approve Order Manager requests
    if (Type==OP_OPEN)
      if (rmHedge == Hedge)
      {
        if (Action == OP_BUY)
        {
          if (fabs(LotValue(LOT_LONG_LOSS,IN_EQUITY))>=ordMaxRisk)
            if (regrFast[regrPolyDirST]==DIR_DOWN)
               return (false);

          if (data[dataRngStr]!=STR_SHORT_MAX)
            return (false);
        }

        if (Action == OP_SELL)
        {
          if (fabs(LotValue(LOT_SHORT_LOSS,IN_EQUITY))>=ordMaxRisk)
            if (regrFast[regrPolyDirST]==DIR_UP)
               return (false);

          if (data[dataRngStr]!=STR_LONG_MAX)
            return (false);
        }
        
        return (true);
      }
     
    //--- Approve Profit Manager requests
    if (Type==OP_CLOSE)
    {
      if (rmHedge == Hedge)
      {
        return (true);
      }
      return (false);
    }
     
    //--- Execute DCA
    if (rmDCA)
    {
    }

    return (false);
  }

//+------------------------------------------------------------------+
//| rmCalculateAlert - Tests for high priority alerts                |
//+------------------------------------------------------------------+
void rmCalcAlerts()
  {
    //--- Test for risk alert
    if (fabs(LotValue(LOT_LONG_LOSS,IN_EQUITY))>=ordMaxRisk*inpRiskMgmtAlert)
    {
      rmAlert       = true;
      rmAlertAction = OP_BUY;
    }

    if (fabs(LotValue(LOT_SHORT_LOSS,IN_EQUITY))>=ordMaxRisk*inpRiskMgmtAlert)
    {
      rmAlert       = true;
      rmAlertAction = OP_SELL;
    }    
    
   //--- Test for DCA alert
    if (fabs(LotValue(LOT_LONG_LOSS,IN_EQUITY))>=ordMaxRisk*inpRiskDCALevel)
    {
      rmDCA         = true;
      rmAlertAction = OP_BUY;
    }
    else
    if (fabs(LotValue(LOT_SHORT_LOSS,IN_EQUITY))>=ordMaxRisk*inpRiskDCALevel)
    {
      rmDCA         = true;
      rmAlertAction = OP_SELL;
    }
    else
      rmDCA         = false;
  }
  
//+------------------------------------------------------------------+
//| RiskManagerReport - Provides data on current open positions|
//+------------------------------------------------------------------+
string RiskManagerReport()
  {
    string strMgmtRpt = "";
    
    //--- Risk manager report
    if (rmAlert)
    {
      strMgmtRpt     += "RM:"+proper(ActionText(rmAlertAction,IN_DIRECTION))+" position at risk (";
      
      if (rmAlertAction==OP_SELL)
        strMgmtRpt   += DoubleToStr(LotValue(LOT_SHORT_LOSS,IN_EQUITY),1)+"%)";

      if (rmAlertAction==OP_BUY)
        strMgmtRpt   += DoubleToStr(LotValue(LOT_LONG_LOSS,IN_EQUITY),1)+"%)";
        
      if (rmDCA)
        strMgmtRpt   += " DCA Engaged";
        
      strMgmtRpt     += "\n";
    }

    if (LotCount(LOT_LONG_NET)>0.00)
      strMgmtRpt     += "Long ("+DoubleToStr(LotValue(LOT_LONG_PROFIT,IN_EQUITY),1)+"% "+DoubleToStr(LotValue(LOT_LONG_LOSS,IN_EQUITY),1)+"%) ";
      
    if (LotCount(LOT_SHORT_NET)>0.00)
      strMgmtRpt     += "Short ("+DoubleToStr(LotValue(LOT_SHORT_PROFIT,IN_EQUITY),1)+"% "+DoubleToStr(LotValue(LOT_SHORT_LOSS,IN_EQUITY),1)+"%)";  
  
    return (strMgmtRpt);
  }
  
//+------------------------------------------------------------------+
//| rmSetRiskLevels - Sets stops and DCA outs                        |
//+------------------------------------------------------------------+
void rmSetRiskLevels()
  {
    if (data[dataETRDir]==DIR_UP && data[dataETRLow]>regrComp[compMajorPivot])
      SetStopPrice(OP_BUY,regrComp[compMajorPivot]);
    else
    if (data[dataETRDir]==DIR_DOWN && data[dataETRHigh]<regrComp[compMajorPivot])
      SetStopPrice(OP_SELL,regrComp[compMajorPivot]);
    else
      SetStopPrice(OP_NO_ACTION,0.00);
  }
  
//+------------------------------------------------------------------+
//| CallRiskManager - Sets risk manager percentage levels            |
//+------------------------------------------------------------------+
void CallRiskManager()
  {    
    rmCalcAlerts();
    rmSetRiskLevels();

    //--- Watch newly opened order
    if (orderOpenSuccess())
    {
      rmLastTicket   = ordOpenTicket;
      rmEQAfterOpen  = EquityPercent();
      
      rmAlert        = false;
      rmAlertAction  = OP_NO_ACTION;
    }
    
    if (OrderSelect(rmLastTicket,SELECT_BY_TICKET,MODE_TRADES))
    {
      rmLastOrderProfit = OrderProfit();
      rmLastOrderType   = OrderType();
    }

    //--- Monitor price action after close
    if (rmLotCount!=LotCount(LOT_TOTAL))
    {
      rmLotCount     = LotCount(LOT_TOTAL);
      rmEQAfterClose = EquityPercent();

      rmAlert        = false;
      rmAlertAction  = OP_NO_ACTION;
    }

  }