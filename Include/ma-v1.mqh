//+------------------------------------------------------------------+
//|                                                        ma-v1.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property strict

//--- ma Event Price Levels
#define MA_EVENT_PRICE_LEVELS    6
#define MA_EVENT_OPEN            0
#define MA_EVENT_HIGH            1
#define MA_EVENT_LOW             2
#define MA_EVENT_CLOSE           3
#define MA_EVENT_DIR             4
#define MA_EVENT_MEASURE         5

//--- ma States
#define MAST_NONE                 0 //--- When the market direction cannot be determined 
#define MAST_LONG_TREND           1 //--- When the market is trending higher                      -- Add limited long (shorts off, DCA when possible)
#define MAST_LONG_PULLBACK        2 //--- Begin market pullback (buying oppty)                    -- Add long (kill shorts oppty)
#define MAST_LONG_RALLY           3 //--- Begin market rally (trend resumes)                      -- Hold long, (hedge if feasible, look to drop hedge and add long)
#define MAST_LONG_CORRECTION      4 //--- Begin market correction (buying oppty)                  -- Add long (increase risk?)
#define MAST_SHORT_TREND         -1 //--- When the market is trending down                        -- Add limited shorts (longs off, DCA when possible)
#define MAST_SHORT_PULLBACK      -2 //--- Begin market pullback (selling oppty)                   -- Add shorts (kill longs oppty)
#define MAST_SHORT_RALLY         -3 //--- Begin market rally (trend resumes)                      -- Add shorts (increase risk?)
#define MAST_SHORT_CORRECTION    -4 //--- Begin market correction (selling resumes)               -- Hold shorts, (hedge if feasible, look to drop hedge and add shorts)

#define MAST_PULLBACK_RALLY       5 //--- Market correction higher, with more downside potential  -- Hold longs (potential to add shorts)
#define MAST_RALLY_PULLBACK      -5 //--- Market correction lower, with more upside potential     -- Hold shorts (potential to add longs)

//--- ma Events
#define MA_EVENTS               23
#define MA_TOP                   0 //--- Market Top
#define MA_BOTTOM                1 //--- Market Bottom
#define MA_ST_BREAK_LOW          2 //--- ST Breakout low
#define MA_ST_BREAK_HIGH         3 //--- LT Breakout high
#define MA_LT_BREAK_LOW          4 //--- ST Breakout low
#define MA_LT_BREAK_HIGH         5 //--- LT Breakout high
#define MA_RANGE_HIGH            6 //--- pipMA new high
#define MA_RANGE_LOW             7 //--- pipMA new low
#define MA_RANGE_LOW_MAX         8 //--- pipMA long range strength at max 
#define MA_RANGE_HIGH_MAX        9 //--- pipMA short range strength at max
#define MA_PIP_PIVOT            10 //--- New pipMA pivot
#define MA_FAST_PIVOT           11 //--- New regrMA fast pivot
#define MA_FAST_DIR_ST          12 //--- New Fast polyST direction change
#define MA_FAST_GAP             13 //--- regrMA fast gap change
#define MA_SLOW_PIVOT           14 //--- New regrMA slow pivot
#define MA_SLOW_GAP             15 //--- regrMA slow gap change
#define MA_POLY_STTL_CROSS      16 //--- regrMA Fast PolySTTL cross
#define MA_POLY_FTL_CROSS       17 //--- regrMA Fast PolySTTL cross
#define MA_POLY_STL_CROSS       18 //--- regrMA Fast PolySTTL cross
#define MA_POLY_STTL_RANGE      19 //--- Range cross Poly STTL (high over STTL/low under STTL)
#define MA_POLY_FTL_RANGE       20 //--- Range cross Poly FTL (high over FTL/low under FTL)
#define MA_POLY_STL_RANGE       21 //--- Range cross Poly STL (high over STL/low under STL)
#define MA_STTL_DEV             22 //--- STTL deviation change (indicates potential ST Trend reversal)

//--- Event Arrays
double maCurrentEvents[MA_EVENTS][MA_EVENT_PRICE_LEVELS];
double maEventHistory[MA_EVENTS][MA_EVENT_PRICE_LEVELS];

//--- Operational Variables
int    maState            = MAST_NONE;
bool   maDivergence       = false;

//+------------------------------------------------------------------+
//| maEventText - Translates event codes to text                     |
//+------------------------------------------------------------------+
string maEventText(int Event)
  {
    switch(Event)
    {
      case MA_TOP:              return("TOP");
      case MA_BOTTOM:           return("BOTTOM");
      case MA_ST_BREAK_LOW:     return("ST BREAKOUT LOW");
      case MA_ST_BREAK_HIGH:    return("ST BREAKOUT HIGH");
      case MA_LT_BREAK_LOW:     return("LT BREAKOUT LOW");
      case MA_LT_BREAK_HIGH:    return("LT BREAKOUT HIGH");
      case MA_RANGE_HIGH:       return("RANGE HIGH");
      case MA_RANGE_LOW:        return("RANGE LOW");
      case MA_RANGE_HIGH_MAX:   return("RANGE HIGH MAX");
      case MA_RANGE_LOW_MAX:    return("RANGE LOW MAX");
      case MA_PIP_PIVOT:        return("PIP PIVOT CHANGE");
      case MA_FAST_PIVOT:       return("FAST PIVOT CHANGE");
      case MA_FAST_DIR_ST:      return("ST DIR CHANGE");
      case MA_FAST_GAP:         return("ST GAP CHANGE");
      case MA_SLOW_PIVOT:       return("SLOW PIVOT CHANGE");
      case MA_SLOW_GAP:         return("LT GAP CHANGE");
      case MA_POLY_STTL_CROSS:  return("FAST TREND CROSS");
      case MA_POLY_FTL_CROSS:   return("ST TREND CROSS");
      case MA_POLY_STL_CROSS:   return("LT TREND CROSS");
      case MA_POLY_STTL_RANGE:  return("FAST RANGE CROSS");
      case MA_POLY_FTL_RANGE:   return("ST RANGE CROSS");
      case MA_POLY_STL_RANGE:   return("LT RANGE CROSS");
      case MA_STTL_DEV:         return("NEAR TERM REVERSAL");
    }
    
    return ("BAD EVENT CODE");
  }
//+------------------------------------------------------------------+
//| maLogEvent - Archives old news                                   |
//+------------------------------------------------------------------+
void maLogEvent(int Event)
  {
    if (maEvent(Event))
      for (int idx=0;idx<MA_EVENT_PRICE_LEVELS;idx++)
      {
        maEventHistory[Event][idx]  = maCurrentEvents[Event][idx];
        maCurrentEvents[Event][idx] = 0.00;        
      }          
  }

//+------------------------------------------------------------------+
//| maTrackEvent - Adds a new event to current events                |
//+------------------------------------------------------------------+
void maTrackEvent(int Event, int Direction=DIR_NONE, double Measure=0.00)
  {
    if (maEvent(Event))
      if (Direction != maCurrentEvents[Event][MA_EVENT_DIR])
        maLogEvent(Event);
        
    if (!maEvent(Event))
    {
      maCurrentEvents[Event][MA_EVENT_OPEN]    = Close[0];
      maCurrentEvents[Event][MA_EVENT_HIGH]    = Close[0];
      maCurrentEvents[Event][MA_EVENT_LOW]     = Close[0];
      maCurrentEvents[Event][MA_EVENT_DIR]     = Direction;
      maCurrentEvents[Event][MA_EVENT_MEASURE] = Measure;
    }    

    maCurrentEvents[Event][MA_EVENT_HIGH]      = fmax(Close[0],maCurrentEvents[Event][MA_EVENT_HIGH]);
    maCurrentEvents[Event][MA_EVENT_LOW]       = fmin(Close[0],maCurrentEvents[Event][MA_EVENT_LOW]);
    maCurrentEvents[Event][MA_EVENT_CLOSE]     = Close[0];
  }

//+------------------------------------------------------------------+
//| maEvent - Returns true if the event is currently active          |
//+------------------------------------------------------------------+
bool maEvent(int Event)
  {
    if (maCurrentEvents[Event][MA_EVENT_OPEN]>0.00)
      return (true);
      
    return (false);
  }
  
//+------------------------------------------------------------------+
//| maBreakoutEvents - Analyze events that indicate breakouts (ST/LT)|
//+------------------------------------------------------------------+
void maBreakoutEvents()
  {
    if (NormalizeDouble(regrFast[regrPolyST],Digits)>=NormalizeDouble(regrFast[regrPolyHigh],Digits) &&
        NormalizeDouble(regrFastLast[regrPolyST],Digits)<NormalizeDouble(regrFastLast[regrPolyHigh],Digits))
      maTrackEvent(MA_ST_BREAK_HIGH,DIR_UP);

    if (maEvent(MA_ST_BREAK_HIGH))
    {
      maTrackEvent(MA_ST_BREAK_HIGH,DIR_UP);

      if (regrFast[regrPolyDirST] == DIR_DOWN || maEvent(MA_TOP))
        maLogEvent(MA_ST_BREAK_HIGH);
    }

    if (NormalizeDouble(regrSlow[regrPolyST],Digits)>=NormalizeDouble(regrSlow[regrPolyHigh],Digits) &&
        NormalizeDouble(regrSlowLast[regrPolyST],Digits)<NormalizeDouble(regrSlowLast[regrPolyHigh],Digits))
      maTrackEvent(MA_LT_BREAK_HIGH,DIR_UP);

    if (maEvent(MA_LT_BREAK_HIGH))
    {
      maTrackEvent(MA_LT_BREAK_HIGH,DIR_UP);

      if (regrSlow[regrPolyDirST] == DIR_DOWN)
        maLogEvent(MA_LT_BREAK_HIGH);
    }

    if (NormalizeDouble(regrFast[regrPolyST],Digits)<=NormalizeDouble(regrFast[regrPolyLow],Digits) &&
        NormalizeDouble(regrFastLast[regrPolyST],Digits)>NormalizeDouble(regrFastLast[regrPolyLow],Digits))
      maTrackEvent(MA_ST_BREAK_LOW,DIR_DOWN);
  
    if (maEvent(MA_ST_BREAK_LOW))
    {
      maTrackEvent(MA_ST_BREAK_LOW,DIR_DOWN);

      if (regrFast[regrPolyDirST] == DIR_UP || maEvent(MA_BOTTOM))
        maLogEvent(MA_ST_BREAK_LOW);
    }

    if (NormalizeDouble(regrSlow[regrPolyST],Digits)<=NormalizeDouble(regrSlow[regrPolyLow],Digits) &&
        NormalizeDouble(regrSlowLast[regrPolyST],Digits)>NormalizeDouble(regrSlowLast[regrPolyLow],Digits))
      maTrackEvent(MA_LT_BREAK_LOW,DIR_DOWN);

    if (maEvent(MA_LT_BREAK_LOW))
    {
      maTrackEvent(MA_LT_BREAK_LOW,DIR_DOWN);

      if (regrSlow[regrPolyDirST] == DIR_UP)
        maLogEvent(MA_LT_BREAK_LOW);
    }
  }

//+------------------------------------------------------------------+
//| maRetraceEvents - Reports on events caused by retraces           |
//+------------------------------------------------------------------+
void maRetraceEvents()
  {
    //--- Tops
    if (regrComp[compPolyRetrace]>=100.00)
      maTrackEvent(MA_TOP, DIR_UP);
    else
      maLogEvent(MA_TOP);

    //--- Bottoms
    if (regrComp[compPolyRetrace]<=(100.00*DIR_DOWN))
      maTrackEvent(MA_BOTTOM, DIR_DOWN);
    else
      maLogEvent(MA_BOTTOM);
  }

//+------------------------------------------------------------------+
//| maRangeEvents - Calculates range events                          |
//+------------------------------------------------------------------+
void maRangeEvents()
  {
    //--- Range Changes
    if (pipMANewHigh())
    {
      maTrackEvent(MA_RANGE_HIGH, DIR_UP);
      
      if (data[dataRngHigh]>regrComp[compFastPolySTTLHead] &&
          dataLast[dataRngHigh]<regrCompLast[compFastPolySTTLHead])
        maTrackEvent(MA_POLY_STTL_RANGE, DIR_UP, regrComp[compFastPolySTTLHead]);

      if (data[dataRngHigh]>regrFast[regrTLCur] &&
          dataLast[dataRngHigh]<regrFastLast[regrTLCur])
        maTrackEvent(MA_POLY_FTL_RANGE, DIR_UP, regrFast[regrTLCur]);

      if (data[dataRngHigh]>regrSlow[regrTLCur] &&
          dataLast[dataRngHigh]<regrSlowLast[regrTLCur])
        maTrackEvent(MA_POLY_STL_RANGE, DIR_UP, regrSlow[regrTLCur]);
    }
    else
    {
      if (maEvent(MA_RANGE_HIGH))
      {
        maLogEvent(MA_POLY_STTL_RANGE);
        maLogEvent(MA_POLY_FTL_RANGE);
        maLogEvent(MA_POLY_STL_RANGE);
      }
        
      maLogEvent(MA_RANGE_HIGH);
    }

    if (pipMANewLow())
    {
      maTrackEvent(MA_RANGE_LOW, DIR_DOWN);

      if (data[dataRngLow]<regrComp[compFastPolySTTLHead] &&
          dataLast[dataRngLow]>regrComp[compFastPolySTTLHead])
        maTrackEvent(MA_POLY_STTL_RANGE, DIR_DOWN, regrComp[compFastPolySTTLHead]);

      if (data[dataRngHigh]<regrFast[regrTLCur] &&
          dataLast[dataRngHigh]>regrFast[regrTLCur])
        maTrackEvent(MA_POLY_FTL_RANGE, DIR_UP, regrFast[regrTLCur]);

      if (data[dataRngHigh]<regrSlow[regrTLCur] &&
          dataLast[dataRngHigh]>regrSlow[regrTLCur])
        maTrackEvent(MA_POLY_STL_RANGE, DIR_UP, regrSlow[regrTLCur]);
    }
    else
    {
      if (maEvent(MA_RANGE_LOW))
      {
        maLogEvent(MA_POLY_STTL_RANGE);
        maLogEvent(MA_POLY_FTL_RANGE);
        maLogEvent(MA_POLY_STL_RANGE);
      }

      maLogEvent(MA_RANGE_LOW);
    }
    
    if (data[dataRngStr] == STR_LONG_MAX)
      maTrackEvent(MA_RANGE_HIGH_MAX, DIR_UP);
    else
      maLogEvent(MA_RANGE_HIGH_MAX);

    if (data[dataRngStr] == STR_SHORT_MAX)
      maTrackEvent(MA_RANGE_LOW_MAX, DIR_DOWN);
    else
      maLogEvent(MA_RANGE_LOW_MAX);
  }

//+------------------------------------------------------------------+
//| maPivotEvents - Reports on events caused by tl pivots            |
//+------------------------------------------------------------------+
void maPivotEvents()
  {
    if (data[dataFOCTrendDir]!=dataLast[dataFOCTrendDir])
      maTrackEvent(MA_PIP_PIVOT, (int)data[dataFOCTrendDir]);
    else
    if (maEvent(MA_PIP_PIVOT))
    {
      maTrackEvent(MA_PIP_PIVOT,(int)data[dataFOCTrendDir]);

      if (fabs(data[dataFOCMax])>1.0)
        maLogEvent(MA_PIP_PIVOT);
    }

    if (regrFast[regrFOCTrendDir]!=regrFastLast[regrFOCTrendDir])
      maTrackEvent(MA_FAST_PIVOT, (int)regrFast[regrFOCTrendDir]);
    else
    if (maEvent(MA_FAST_PIVOT))
    {
      maTrackEvent(MA_FAST_PIVOT, (int)regrFast[regrFOCTrendDir]);

      if (fabs(regrFast[regrFOCMax])>1.0)
        maLogEvent(MA_FAST_PIVOT);
    }
    
    if (regrSlow[regrFOCTrendDir]!=regrSlowLast[regrFOCTrendDir])
      maTrackEvent(MA_SLOW_PIVOT, (int)regrSlow[regrFOCTrendDir]);
    else
    if (maEvent(MA_SLOW_PIVOT))
    {
      maTrackEvent(MA_SLOW_PIVOT, (int)regrSlow[regrFOCTrendDir]);

      if (fabs(regrSlow[regrFOCMax])>1.0)    
        maLogEvent(MA_SLOW_PIVOT);
    }
    
    if (regrFast[regrPolyDirST]!=regrFastLast[regrPolyDirST])
      maTrackEvent(MA_FAST_DIR_ST, (int)regrFast[regrPolyDirST], regrFast[regrPolyST]);
    else
    if (maEvent(MA_FAST_DIR_ST))
    {
      maTrackEvent(MA_FAST_DIR_ST, (int)regrFast[regrPolyDirST]);
        
      if (fabs(pip(regrFast[regrPolyST]-maCurrentEvents[MA_FAST_DIR_ST][MA_EVENT_MEASURE]))>1.0)
        maLogEvent(MA_FAST_DIR_ST);
    }
  }

//+------------------------------------------------------------------+
//| maGapEvents - Analyzes gap events                                |
//+------------------------------------------------------------------+
void maGapEvents()
  {
    //--- Fast Poly Gap direction change
    if (dir(regrFast[regrPolyGap])!=dir(regrFastLast[regrPolyGap]))
      maTrackEvent(MA_FAST_GAP, dir(regrFast[regrPolyGap]), regrFast[regrPolyGap]);
    else
    if (maEvent(MA_FAST_GAP))
    {
      maTrackEvent(MA_FAST_GAP, dir(regrFast[regrPolyGap]));

      if (fabs(regrFast[regrPolyGap])>5.0)
        maLogEvent(MA_FAST_GAP);
    }

    //--- Slow Poly Gap direction change
    if (dir(regrSlow[regrPolyGap])!=dir(regrSlowLast[regrPolyGap]))
      maTrackEvent(MA_SLOW_GAP, dir(regrSlow[regrPolyGap]), regrSlow[regrPolyGap]);
    else
    if (maEvent(MA_SLOW_GAP))
    {
      maTrackEvent(MA_SLOW_GAP, dir(regrSlow[regrPolyGap]));

      if (fabs(regrSlow[regrPolyGap])>2.0)
        maLogEvent(MA_SLOW_GAP);
    }
  }

//+------------------------------------------------------------------+
//| maCrossEvents - Analyzes crossing indicator levels               |
//+------------------------------------------------------------------+
void maCrossEvents()
  {
    //--- STTL Cross event (Hedge Cross) - sets risk level    
    if (dir(regrFast[regrPolyST]-regrComp[compFastPolySTTLHead]) != 
        dir(regrFastLast[regrPolyST]-regrCompLast[compFastPolySTTLHead]))
      maTrackEvent(MA_POLY_STTL_CROSS, dir(regrFast[regrPolyST]-regrComp[compFastPolySTTLHead]), regrComp[compFastPolySTTLCross]);
    else
    if (maEvent(MA_POLY_STTL_CROSS))
    {
      maTrackEvent(MA_POLY_STTL_CROSS, dir(regrFast[regrPolyST]-regrComp[compFastPolySTTLHead]));

      if ((maEvent(MA_RANGE_HIGH)||maEvent(MA_RANGE_LOW)) && fabs(Close[0]-maCurrentEvents[MA_POLY_STTL_CROSS][MA_EVENT_OPEN])>point(1.0))
        maLogEvent(MA_POLY_STTL_CROSS);
    }

    //--- FTL Cross event (Fast TL Cross) - rally/pullback indicator
    if (dir(regrFast[regrPolyST]-regrFast[regrTLCur]) != 
        dir(regrFastLast[regrPolyST]-regrFastLast[regrTLCur]))
      maTrackEvent(MA_POLY_FTL_CROSS, dir(regrFast[regrPolyST]-regrFast[regrTLCur]));
    else
    if (maEvent(MA_POLY_FTL_CROSS))
    {
      maTrackEvent(MA_POLY_FTL_CROSS, dir(regrFast[regrPolyST]-regrFast[regrTLCur]));

      if ((maEvent(MA_RANGE_HIGH)||maEvent(MA_RANGE_LOW)) && fabs(Close[0]-maCurrentEvents[MA_POLY_FTL_CROSS][MA_EVENT_OPEN])>point(1.0))
        maLogEvent(MA_POLY_FTL_CROSS);
    }

    //--- STL Cross event (Slow TL Cross) - trend change indicator
    if (dir(regrSlow[regrPolyST]-regrSlow[regrTLCur]) != 
        dir(regrSlowLast[regrPolyST]-regrSlowLast[regrTLCur]))
      maTrackEvent(MA_POLY_STL_CROSS, dir(regrSlow[regrPolyST]-regrSlow[regrTLCur]));
    else
    if (maEvent(MA_POLY_STL_CROSS))
    {
      maTrackEvent(MA_POLY_STL_CROSS, dir(regrSlow[regrPolyST]-regrSlow[regrTLCur]));

      if ((maEvent(MA_RANGE_HIGH)||maEvent(MA_RANGE_LOW)) && fabs(Close[0]-maCurrentEvents[MA_POLY_STL_CROSS][MA_EVENT_OPEN])>point(1.0))
        maLogEvent(MA_POLY_STL_CROSS);
    }
  }

//+------------------------------------------------------------------+
//| maCalcTrendState - Analyzes data, estimates strength, recommends |
//+------------------------------------------------------------------+
void maCalcTrendState()
  {
//     int i = regrSlow[regrFOCTrendDir];
     
     int lastState  = maState;
     int divDir     = 
     
     maState          = MAST_NONE;
     maDivergence     = false;
string str = DirText(data[dataRngDir])+" "+DirText(regrFast[regrFOCTrendDir])+" ";     
     if (data[dataRngDir]==DIR_UP)
     {
       if (regrFast[regrPolyDirST] == DIR_DOWN)
         maDivergence = true;

       for (int idx=dataRngLow;idx<=dataRngHigh;idx++)
       {
         if (data[idx]>regrFast[regrPolyLastBottom])
           maState++;
           
         if (data[idx]>regrFast[regrPolyLastTop])
           maState++;           
        str+=DoubleToStr(data[idx],Digits)+":";
       }
     }
     
     if (data[dataRngDir] == DIR_DOWN)
     {
       if (regrFast[regrPolyDirST] == DIR_UP)
         maDivergence = true;     

       for (int idx=dataRngLow;idx<=dataRngHigh;idx++)
       {
         if (data[idx]<regrFast[regrPolyLastBottom])
           maState--;
           
         if (data[idx]<regrFast[regrPolyLastTop])
           maState--;
        str+=DoubleToStr(data[idx],Digits)+":";
       }
     }
     
     str+=" ("+IntegerToString(maState)+")";
     
     maState = (int)MathCeil((data[dataRngDir]+regrFast[regrFOCTrendDir]+maState)/2);
     
     if (maState!=lastState)
        Print(str+" "+StrengthText(maState));
  }      

//+------------------------------------------------------------------+
//| MarketAnalystReport - Reports on statistical analysis/conclusions|
//+------------------------------------------------------------------+
string MarketAnalystReport()
  {
    string strMgmtRpt = StrengthText(maState);
    
    if (maDivergence)
      strMgmtRpt += " (D) ";
    else
      strMgmtRpt += " (C) ";
      
    strMgmtRpt += DoubleToStr(regrFast[regrPolyLastTop],Digits)+" "+DoubleToStr(regrFast[regrPolyLastBottom],Digits)+"\n";  
    
    //--- Market Analyst report
    for (int event=0;event<MA_EVENTS;event++)
      if (maEvent(event))
      {
        strMgmtRpt += proper(maEventText(event));
        
        if (maCurrentEvents[event][MA_EVENT_DIR]!=DIR_NONE)
          strMgmtRpt += " "+proper(DirText((int)maCurrentEvents[event][MA_EVENT_DIR]));
                                                     
        strMgmtRpt += " "+DoubleToStr(maCurrentEvents[event][MA_EVENT_OPEN],Digits)+" "+
                          DoubleToStr(maCurrentEvents[event][MA_EVENT_HIGH],Digits)+" "+
                          DoubleToStr(maCurrentEvents[event][MA_EVENT_LOW],Digits)+" ";

        if (maCurrentEvents[event][MA_EVENT_MEASURE]>0.00)
          strMgmtRpt += "("+DoubleToStr(maCurrentEvents[event][MA_EVENT_MEASURE],1)+") ";

        strMgmtRpt += "\n";
      }
    return (strMgmtRpt);
  }

//+------------------------------------------------------------------+
//| CallMarketAnalyst - Analyzes data, makes recommendations         |
//+------------------------------------------------------------------+
void CallMarketAnalyst()
  {
//    maRetraceEvents();
//    maRangeEvents();
//    maPivotEvents();
//    maGapEvents();
//    maCrossEvents();
//    maBreakoutEvents();
    
    maCalcTrendState();
  }
  
//+------------------------------------------------------------------+
//| maInit()- Init things for the MA to do                           |
//+------------------------------------------------------------------+
void maInit()
  {
    eqhalf   = true;
    eqprofit = true;
    eqdir    = true;
    
    SetRisk(ordMaxRisk*(inpRiskMgmtAlert+inpRiskDCALevel),ordLotRisk);
    SetEquityTarget(ordMinTarget,ordMinProfit);

    ArrayInitialize(maCurrentEvents,0);
  }    
