//+------------------------------------------------------------------+
//|                                                        pt-v5.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <pipMA-v3.mqh>

//--- PT State Constants
#define PT_LONG_AT_RISK        4
#define PT_LONG_CAUTION        3
#define PT_LONG_WANE           2
#define PT_LONG                1
#define PT_NONE                0
#define PT_SHORT              -1
#define PT_SHORT_WANE         -2
#define PT_SHORT_CAUTION      -3
#define PT_SHORT_AT_RISK      -4

//--- Management Constants
#define MGMT_LONG_AT_RISK      2  //--- Long macro management
#define MGMT_LONG_CAUTION      1  //--- Long micro management
#define MGMT_NONE              0  //--- No manager, price performance matches indicators
#define MGMT_SHORT_CAUTION    -1  //--- Short micro management
#define MGMT_SHORT_AT_RISK    -2  //--- Short macro management

double  inpRetraceAlert =  25; // PIP retrace off caution

//--- Operational variables
int    ptColorSet[5][2] = {{clrWhite,clrWhite},{clrRed,clrYellow},{clrFireBrick,clrGoldenrod},{clrYellow,clrRed},{clrYellow,clrRed}};

int    ptAction         = OP_NO_ACTION;
int    ptState          = PT_NONE;
int    ptStateLast      = PT_NONE;
int    ptDir            = DIR_NONE;

double ptPriceHigh      = 0.00;
double ptPriceLow       = 0.00;
double ptCaution        = 0.00;

int    ptArrowIdx       = 0;

int    mgmtLevel        = MGMT_NONE;

//--- Gap Management
bool   gapMktRev        = false;
bool   gapMktCorr       = false;
double gapMktCorrMax    = 0.00;
double gapMktCorrMin    = 0.00;
int    gapMktCorrIdx    = 0;
       
//+------------------------------------------------------------------+
//| StateText - returns the text for the supplied ptState value      |
//+------------------------------------------------------------------+
string StateText(int Value)
{
  switch (Value)
  {
    case PT_NONE           : return("Initializing");
    case PT_LONG           : return("Long");
    case PT_LONG_WANE      : return("Soft Long");
    case PT_LONG_CAUTION   : return("Long Caution");
    case PT_LONG_AT_RISK   : return("Long At Risk");

    case PT_SHORT          : return("Short");
    case PT_SHORT_WANE     : return("Soft Short");
    case PT_SHORT_CAUTION  : return("Short Caution");
    case PT_SHORT_AT_RISK  : return("Short At Risk");

    default                : return("BAD STATE CODE");
  }
}

//+------------------------------------------------------------------+
//| MgmtText - returns the text for the supplied MgmtLevel value     |
//+------------------------------------------------------------------+
string MgmtText(int Value)
{
  switch (Value)
  {
    case MGMT_NONE           : return("None");
    case MGMT_LONG_CAUTION   : return("Long Caution");
    case MGMT_LONG_AT_RISK   : return("Long At Risk");

    case MGMT_SHORT_CAUTION  : return("Short Caution");
    case MGMT_SHORT_AT_RISK  : return("Short At Risk");

    default                  : return("BAD MGMT CODE");
  }
}

//+------------------------------------------------------------------+
//| GetData - gets indicator data                                    |
//+------------------------------------------------------------------+
void GetData()
  {
    pipMAGetData();
    regrMAGetData();    
  }

//+------------------------------------------------------------------+
//| NewStateFlag - Paints an arrow, returns direction                |
//+------------------------------------------------------------------+
int NewStateFlag(int State)
  { 
    int Flag      = 0;
    int FlagColor = 0;
    
    if (dir(State) == DIR_UP)
    {
      Flag        = SYMBOL_ARROWUP;
      FlagColor   = 1;
    }
    
    if (dir(State) == DIR_DOWN)
      Flag        = SYMBOL_ARROWDOWN;
      
    if (fabs(State) == 3)
      Flag        = SYMBOL_CHECKSIGN;
      
    if (fabs(State) == 4)
      Flag        = SYMBOL_STOPSIGN;
      
    ptArrowIdx++;
    
    NewArrow(Flag,ptColorSet[fabs(State),FlagColor],IntegerToString(ptArrowIdx));
    
    return(dir(State));
  }

//+------------------------------------------------------------------+
//| RefreshScreen - repaint visual data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    string strAction = proper(ActionText(ptAction));
    
    if (fabs(ptState) == 1)
    {
      if (ptAction==OP_BUY)
        strAction = proper(ActionText(OP_SELL));

      if (ptAction==OP_SELL)
        strAction = proper(ActionText(OP_BUY));
    }      
    
    Comment("Action: "+strAction+" State: "+StateText(ptState)+"\n"+
            "Manager: "+MgmtText(mgmtLevel));
    
    ObjectSet("lbPriceHigh",OBJPROP_TIME1,Time[0]);
    ObjectSet("lbPriceHigh",OBJPROP_PRICE1,ptPriceHigh);

    ObjectSet("lbPriceLow",OBJPROP_TIME1,Time[0]);
    ObjectSet("lbPriceLow",OBJPROP_PRICE1,ptPriceLow);
    
    if (ptAction == OP_BUY)
    {
      ObjectSet("lbPriceHigh",OBJPROP_COLOR,clrLawnGreen);
      ObjectSet("lbPriceLow",OBJPROP_COLOR,clrLawnGreen);      
    }

    if (ptAction == OP_SELL)
    {
      ObjectSet("lbPriceHigh",OBJPROP_COLOR,clrRed);
      ObjectSet("lbPriceLow",OBJPROP_COLOR,clrRed);      
    }

    if (ptCaution>0.00)
    {
      ObjectSet("lbCaution",OBJPROP_TIME1,Time[0]);
      ObjectSet("lbCaution",OBJPROP_PRICE1,ptCaution);
    }
  }

//+------------------------------------------------------------------+
//| EventOpen - Identifies potential order entry points              |
//+------------------------------------------------------------------+
int EventOpen()
  {
     
     return (OP_NO_ACTION);
  }
  
//+------------------------------------------------------------------+
//| EventClose - Identifies potential order exit points              |
//+------------------------------------------------------------------+
bool EventClose(int Action)
  {
/*     if (Action == OP_SELL && LotCount(OP_BUY)>ptLotsLong && Bid<regr[regrLT])
       return (true);
     
     if (Action == OP_BUY && LotCount(OP_SELL)>ptLotsShort && Bid>regr[regrLT])
       return (true);
*/          
     return (false);
  }

//+------------------------------------------------------------------+
//| SetMgmtLevel - Sets short term strategy when price is not        |
//|                behaving as expected                              |
//+------------------------------------------------------------------+
void SetMgmtLevel()
  {
    int mgmtLevelLast = mgmtLevel;
    
    if (ptAction == OP_BUY && ptState>0)
      if (ptState == PT_LONG)
        mgmtLevel = MGMT_LONG_AT_RISK;
      else
        mgmtLevel = MGMT_LONG_CAUTION;
      
    if (ptAction == OP_SELL && ptState<0)
      if (ptState == PT_SHORT)
        mgmtLevel = MGMT_SHORT_AT_RISK;
      else
        mgmtLevel = MGMT_SHORT_CAUTION;
              
    if (ptState != ptStateLast)
      mgmtLevel = MGMT_NONE;
      
    if ((mgmtLevelLast != mgmtLevel) && (mgmtLevel != MGMT_NONE))      
      NewStateFlag(mgmtLevel+(2*dir(mgmtLevel)));
  }
  
//+------------------------------------------------------------------+
//| SetState - Identifies the state (strategy) for the chart         |
//+------------------------------------------------------------------+
void SetState()
  {
    int    tempState   = PT_NONE;
    double tempCaution = 0.00;
    
    ptStateLast        = ptState;
     
    if (Bid>data[dataRngHigh])
    {
      if (Bid>regr[regrLT])
      {
        ptAction = OP_SELL;
        ptPriceHigh = fmax(ptPriceHigh,Bid);
        ptPriceLow  = Bid;
      }
      
      if (ptPriceHigh>regr[regrLT])
        tempCaution = ptPriceLow;
    }  
    else
    if (Bid<data[dataRngLow])
    {
      if (Bid<regr[regrLT])
      {
        if (ptPriceLow == 0.00&&ptAction!=OP_BUY)
          ptPriceLow = Ask;
        else
          ptPriceLow = fmin(ptPriceLow,Ask);

        ptAction = OP_BUY;
        ptPriceHigh = Bid;
      
        if (ptPriceLow<regr[regrLT])
          tempCaution = ptPriceHigh;
      }
    }    
    
    if (regr[regrLT]>regr[regrST])
      tempState = DIR_DOWN;
    else
      tempState = DIR_UP;
        
//    if (regr[regrPWane]>0.00)
//      tempState += tempState;
      
    if (tempState!=ptState)
    {
      if (fabs(tempState)+fabs(ptState)==3)
        ptDir   = NewStateFlag(tempState);
        
      ptState = tempState;
    }
    
    if (ptCaution == 0.00)
      ptCaution = tempCaution;
    else
    {
      if (ptAction == OP_BUY)
        ptCaution=fmax(ptCaution,Ask);

      if (ptAction == OP_SELL)
        ptCaution=fmin(ptCaution,Bid);
    }
  }
  
  
//+------------------------------------------------------------------+
//| AutoTrade - Executes trades in auto mode                         |
//+------------------------------------------------------------------+
void AutoTrade()
  { 
    //--- New orders    
//    if (!orderPending())
    {
      if (ptAction==OP_SELL)
      {
        ptPriceLow = fmin(ptPriceLow,Bid);
        if (data[dataPipDir]==DIR_DOWN){}
          //OpenLimitOrder(OP_SELL,ptPriceHigh,data[dataRngMid],0.00,"Auto",IN_PRICE);
      }
      else
      if (ptAction==OP_BUY)
      {
        ptPriceHigh = fmax(ptPriceHigh,Ask);
        if (data[dataPipDir]==DIR_UP){}
          //OpenLimitOrder(OP_BUY,ptPriceLow,data[dataRngMid]+spread(IN_PIPS),0.00,"Auto",IN_PRICE);
      }
    }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();

    manualProcessRequest();
    orderMonitor();
    
    if (pipMALoaded)
    {
//      SetState();
//      SetMgmtLevel();
      
//      if (regr[regrLTWane]>0.00 && regr[regrLTWane]!=regrLast[regrLTWane])
//        NewArrow(SYMBOL_RIGHTPRICE,DirColor((int)regr[regrDirLT]),"-",regr[regrLTWane]);

/*
      if (regr[regrGapCaution]==GAP_STRONG_MINOR)
      {
        if (gapMktRev)
          gapMktCorr = true;
        else
        if (!gapMktCorr)
        {
          gapMktCorr    = true;
          gapMktCorrMax = Close[0];
          gapMktCorrMin = Close[0];
          gapMktCorrIdx++;
          
          if ((int)regr[regrDirLT]== DIR_UP)
            NewArrow(SYMBOL_ARROWDOWN,clrRed,"Correction",Close[0]);
          else
            NewArrow(SYMBOL_ARROWUP,clrYellow,"Correction",Close[0]);

          ObjectCreate("arwMCHigh"+IntegerToString(gapMktCorrIdx),OBJ_ARROW,0,Time[0],Close[0]);
          ObjectSet("arwMCHigh"+IntegerToString(gapMktCorrIdx),OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);

          ObjectCreate("arwMCLow"+IntegerToString(gapMktCorrIdx),OBJ_ARROW,0,Time[0],Close[0]);
          ObjectSet("arwMCLow"+IntegerToString(gapMktCorrIdx),OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);
        }
      }
      else
      {
        gapMktCorr=false;
      }

      if (gapMktCorr)
      {
        gapMktCorrMax = fmax(gapMktCorrMax,Close[0]);
        gapMktCorrMin = fmin(gapMktCorrMin,Close[0]);
        
        ObjectSet("arwMCHigh"+IntegerToString(gapMktCorrIdx),OBJPROP_TIME1,Time[0]);
        ObjectSet("arwMCHigh"+IntegerToString(gapMktCorrIdx),OBJPROP_PRICE1,gapMktCorrMax);
        ObjectSet("arwMCHigh"+IntegerToString(gapMktCorrIdx),OBJPROP_COLOR,clrLightGray);
      
        ObjectSet("arwMCLow"+IntegerToString(gapMktCorrIdx),OBJPROP_TIME1,Time[0]);
        ObjectSet("arwMCLow"+IntegerToString(gapMktCorrIdx),OBJPROP_PRICE1,gapMktCorrMin);
        ObjectSet("arwMCLow"+IntegerToString(gapMktCorrIdx),OBJPROP_COLOR,clrLightGray);
      }

      if (regr[regrGapCaution]==GAP_SOFT_MINOR)
      {
        if (!gapMktRev)
        {
          if ((int)regr[regrDirLT]== DIR_UP)
            NewArrow(SYMBOL_ARROWUP,clrCyan,"Correction",Close[0]);
          else
            NewArrow(SYMBOL_ARROWDOWN,clrCyan,"Correction",Close[0]);
          gapMktRev = true;
        }
      }
      else gapMktRev=false;

*/
      
      if (manualAuto)
        AutoTrade();
    }
      
    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();    
    
    SetMode(Auto);
    
    eqhalf   = true;
    eqprofit = true;
    eqdir    = true;
    
    SetRisk(80);
    SetTarget(200);

    ObjectCreate("lbPriceHigh",OBJ_ARROW,0,Time[0],0.00);
    ObjectSet("lbPriceHigh", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);

    ObjectCreate("lbPriceLow",OBJ_ARROW,0,Time[0],0.00);
    ObjectSet("lbPriceLow", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE); 
        
    ObjectCreate("lbCaution",OBJ_ARROW,0,Time[0],0.00);
    ObjectSet("lbCaution", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE); 
    ObjectSet("lbCaution",OBJPROP_COLOR,clrYellow);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }