//+------------------------------------------------------------------+
//|                                                    regrMA-v1.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
//#property link      "http://www.mql5.com"
#property version   "1.1"
#property strict
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   3

//--- plot indRegrST
#property indicator_label1  "indRegrST"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrFireBrick
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot indRegrLT
#property indicator_label2  "indRegrLT"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGoldenrod
#property indicator_width2  1

//--- plot indTLine
#property indicator_label3  "indTLine"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSteelBlue
#property indicator_width3  1

//--- buffer indWork working area
#property indicator_label4  "indWork"
#property indicator_type4   DRAW_NONE

//--- buffer indRegr data measures
#property indicator_label5  "indRegr"
#property indicator_type5   DRAW_NONE

#include <regrMA-v1.mqh>

//--- indicator buffers
double    indRegrSTBuffer[];
double    indRegrLTBuffer[];
double    indTLineBuffer[];
double    indWorkBuffer[];
double    indRegrBuffer[];

double    r2;

double    Sensitivity       = 0.5;
double    STWaneBoundary    = 0.00;
double    LTWaneBoundary    = 0.00;

//+------------------------------------------------------------------+
//| LoadMA - loads the work buffer with MA data                      |
//+------------------------------------------------------------------+
void LoadMA(int MA)
  {
    int range = inpRegrRng+inpRegrST+inpRegrLT;
    
    ArrayInitialize(indWorkBuffer,0.00);
    
    for (int idx=0; idx<range; idx++)
      indWorkBuffer[idx] = iCustom(Symbol(),Period(),"Custom Moving Averages",MA,0,MODE_SMA,0,idx);
  }

//+------------------------------------------------------------------+
//| StrengthText - Returns the strength description                  |
//+------------------------------------------------------------------+
  string StrengthText()
  {
     int str = (int)regr[regrStr];
     
     switch (str)
     {
       case REGR_STRONG_LONG:   return ("STRONG LONG");
       case REGR_LONG:          return ("LONG");
       case REGR_SOFT_LONG:     return ("SOFT LONG");
       case REGR_CHG_SHORT:     return ("CHANGE SHORT");

       case REGR_NO_STRENGTH:   return ("NO STRENGTH");

       case REGR_CHG_LONG:      return ("CHANGE LONG");
       case REGR_SOFT_SHORT:    return ("SOFT SHORT");
       case REGR_SHORT:         return ("SHORT");
       case REGR_STRONG_SHORT:  return ("STRONG SHORT");
     }
     
     return ("INVALID STRENGTH CODE");
  }

//+------------------------------------------------------------------+
//| GapCautionText - Returns the gap caution description             |
//+------------------------------------------------------------------+
  string GapCautionText()
  {
     int    caution = (int)regr[regrGapCaution];
     string str = "Gap ("+DoubleToStr(regr[regrGap],1)+" "+DoubleToStr(regr[regrGapPct] ,1)+"%)";
     
     switch (caution)
     {
       case GAP_TREND_LONG:    return ("Trend Long "+str);
       case GAP_STRONG_MAJOR:  return (str+" Caution: Potential trend change");
       case GAP_STRONG_MINOR:  return (str+" Caution: Potential market correction");
       case GAP_NO_CAUTION:    return ("No Caution "+str);
       case GAP_SOFT_MINOR:    return (str+" Caution: Potential reversal");
       case GAP_SOFT_MAJOR:    return (str+" Caution: Potential trend continuation");
       case GAP_TREND_SHORT:   return ("Trend Short "+str);
     }
     
     return ("INVALID GAP CAUTION");
  }

//+------------------------------------------------------------------+
//| CalculatePWane - calculates the wane of the poly trend lines     |
//+------------------------------------------------------------------+
void CalculatePWane()
  {
    int idx       = 0;
    int waneBar   = 0;
    
    int dirTrend  = dir(indRegrLTBuffer[0]-indRegrSTBuffer[0]);
    int dirLast   = DIR_NONE;

    bool wane     = false;
    int  parallel = 0;
    
    regr[regrPWane] = 0.00;
        
//    if (fabs(regr[regrDirST]+regr[regrDirST]==2)
        //--- Test for parallel nudging
    
    if (fabs(indRegrLTBuffer[0]-indRegrSTBuffer[0]) <
        fabs(indRegrLTBuffer[1]-indRegrSTBuffer[1]))
      wane      = true;
        
    while (wane)
    {
      if ( fabs(indRegrLTBuffer[idx]-indRegrSTBuffer[idx]) >
           fabs(indRegrLTBuffer[idx+1]-indRegrSTBuffer[idx+1]))
      {
        wane      = false;
        waneBar   = idx;
      }
            
      if (waneBar > 0)
        regr[regrPWane] = indRegrSTBuffer[waneBar];
        
      idx++;
    }
  }

//+------------------------------------------------------------------+
//| CalculatePTWane - calculates the wane of the ST poly to TL       |
//+------------------------------------------------------------------+
void CalculatePTWane()
  {
    int idx       = 0;
    int waneBar   = 0;
    
    int dirTrend  = dir(indRegrLTBuffer[0]-indRegrSTBuffer[0]);
    int dirLast   = DIR_NONE;

    bool wane     = false;
    
    regr[regrPTLWane] = 0.00;
        
    if (fabs(indTLineBuffer[0]-indRegrSTBuffer[0]) <
        fabs(indTLineBuffer[1]-indRegrSTBuffer[1]))
      wane      = true;
        
    while (wane)
    {
      if ( fabs(indTLineBuffer[idx]-indRegrSTBuffer[idx]) >
           fabs(indTLineBuffer[idx+1]-indRegrSTBuffer[idx+1]))
      {
        wane      = false;
        waneBar   = idx;
      }
            
      if (waneBar > 0)
        regr[regrPTLWane] = (fabs(indTLineBuffer[0]-indRegrSTBuffer[0]))/(fabs(indRegrSTBuffer[waneBar]-indTLineBuffer[0]));
        
      idx++;
    }
  }

//+------------------------------------------------------------------+
//| CalculateLTWane - calculates the wane LT poly nose               |
//+------------------------------------------------------------------+
void CalculateLTWane()
  {
    if (regr[regrDirLT]!=regrLast[regrDirLT])
    {
      regr[regrLTWane] = 0.00;
      LTWaneBoundary = indRegrLTBuffer[0];
    }
      
    if (regr[regrDirLT]==DIR_UP)
    {
      LTWaneBoundary = fmax(LTWaneBoundary,indRegrLTBuffer[0]);
      
      if (LTWaneBoundary-indRegrLTBuffer[0]>point(Sensitivity))
        regr[regrLTWane] = LTWaneBoundary;
      else
        regr[regrLTWane] = 0.00;
    }

    if (regr[regrDirLT]==DIR_DOWN)
    {
      LTWaneBoundary = fmin(LTWaneBoundary,indRegrLTBuffer[0]);

      if (indRegrLTBuffer[0]-LTWaneBoundary>point(Sensitivity))
        regr[regrLTWane] = LTWaneBoundary;
      else
        regr[regrLTWane] = 0.00;
    }
  }

//+------------------------------------------------------------------+
//| CalculateSTWane - calculates the wane ST poly nose               |
//+------------------------------------------------------------------+
void CalculateSTWane()
  {
    if (regr[regrDirST]!=regrLast[regrDirST])
    {
      regr[regrSTWane] = 0.00;
      STWaneBoundary = indRegrSTBuffer[0];
    }
      
    if (regr[regrDirST]==DIR_UP)
    {
      STWaneBoundary = fmax(STWaneBoundary,indRegrSTBuffer[0]);
      
      if (STWaneBoundary-indRegrSTBuffer[0]>point(Sensitivity))
        regr[regrSTWane] = STWaneBoundary;
      else
        regr[regrSTWane] = 0.00;
    }

    if (regr[regrDirST]==DIR_DOWN)
    {
      STWaneBoundary = fmin(STWaneBoundary,indRegrSTBuffer[0]);

      if (indRegrSTBuffer[0]-STWaneBoundary>point(Sensitivity))
        regr[regrSTWane] = STWaneBoundary;
      else
        regr[regrSTWane] = 0.00;
    }
  }
  
//+------------------------------------------------------------------+
//| CalculateTRegression - Computes the vector of the trendline      |
//+------------------------------------------------------------------+
void CalculateTRegression()
  {
    //--- Linear regression line
    double m[5] = {0.00,0.00,0.00,0.00,0.00};  //--- slope
    double b    = 0.00;                        //--- y-intercept
    
    double sumx = 0.00;
    double sumy = 0.00;
    double avg;
    
    ArrayCopy(regrLast,regr);
    
    for (int idx=0; idx<inpRegrRng; idx++)
    {
      avg   = ((indRegrSTBuffer[idx]+indRegrLTBuffer[idx])/2);
      sumx += idx+1;
      sumy += avg;
      
      m[1] += (idx+1)* avg;
      m[3] += pow(idx+1,2);
    }
    
    m[1]   *= inpRegrRng;
    m[2]    = sumx*sumy;
    m[3]   *= inpRegrRng;
    m[4]    = pow(sumx,2);
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy - m[0]*sumx)/inpRegrRng;
    
    for (int idx=0; idx<inpRegrRng; idx++)
    {
      //--- y=mx+b
      indTLineBuffer[inpRegrRng-idx-1] = (m[0]*(inpRegrRng-idx-1))+b;
    }
      
    indTLineBuffer[inpRegrRng]=0.00;
    
    regr[regrTLine]        = indTLineBuffer[0];
    regr[regrTLineDirLT]   = dir((int)regr[regrTLineDirLT], indTLineBuffer);
    
    if ((int)regr[regrTLineDirLT] != (int)regrLast[regrTLineDirLT])
    {
      regr[regrTLineMin]   = regr[regrTLine];
      regr[regrTLineMax]   = regr[regrTLine];
      regr[regrTLineDirST] = regr[regrTLineDirLT];
    }
    else
    {
      if ((int)regr[regrTLineDirLT] == DIR_UP)
      {
        regr[regrTLineMax]      = fmax(regr[regrTLine],regr[regrTLineMax]);

        if (regr[regrTLineMax] > regrLast[regrTLineMax])
        {
          regr[regrTLineMin]    = regr[regrTLine];
          regr[regrTLineDirST]  = DIR_UP;
        }
        else
          regr[regrTLineMin]    = fmin(regr[regrTLine],regr[regrTLineMin]);
      }

      if ((int)regr[regrTLineDirLT] == DIR_DOWN)
      {
        regr[regrTLineMax]      = fmin(regr[regrTLine],regr[regrTLineMax]);

        if (regr[regrTLineMax] < regrLast[regrTLineMax])
        {
          regr[regrTLineMin]    = regr[regrTLine];
          regr[regrTLineDirST]  = DIR_DOWN;
        }
        else
          regr[regrTLineMin]    = fmax(regr[regrTLine],regr[regrTLineMin]);
      }
    }
    
    if (pip(fabs(regr[regrTLineMax]-regr[regrTLineMin])) >= 0.2)
      regr[regrTLineDirST] = regr[regrTLineDirLT] * (-1.0);
    
    if (regr[regrTLineDirLT] == DIR_UP)
      if (regr[regrTLineDirST] == DIR_UP)
        regr[regrTLineStr]  = REGR_STRONG_LONG;
      else
        regr[regrTLineStr]  = REGR_SOFT_LONG;
    else
    if (regr[regrTLineDirLT] == DIR_DOWN)
      if (regr[regrTLineDirST] == DIR_DOWN)
        regr[regrTLineStr]  = REGR_STRONG_SHORT;
      else
        regr[regrTLineStr]  = REGR_SOFT_SHORT;
    else
      regr[regrTLineStr]    = REGR_NO_STRENGTH;

    SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,1,DirColor((int)regr[regrTLineDirST]));
  }

  
//+------------------------------------------------------------------+
//| CalculateMeasures - calculates regr metrics and loads buffer     |
//+------------------------------------------------------------------+
void CalculateMeasures()
  {
    double pRngLow    = regr[regrLT];
    double pRngHigh   = regr[regrLT];

    ArrayCopy(regrLast,regr);

    regr[regrST]      = indRegrSTBuffer[0];
    regr[regrLT]      = indRegrLTBuffer[0];
    regr[regrDirST]   = dir((int)regr[regrDirST],indRegrSTBuffer);
    regr[regrDirLT]   = dir((int)regr[regrDirLT],indRegrLTBuffer);
    regr[regrGap]     = pip(regr[regrST] - regr[regrLT]);
    
    //--- compute retrace
    for (int idx=0;idx<inpRegrRng;idx++)
    {
      pRngLow         = fmin(indRegrLTBuffer[idx],pRngLow);
      pRngHigh        = fmax(indRegrLTBuffer[idx],pRngHigh);
    }
    
    regr[regrRetrLT]  = (((regr[regrLT]-pRngLow)/(pRngHigh-pRngLow))-0.5)*100;
    regr[regrRetrCur] = (((Close[0]-pRngLow)/(pRngHigh-pRngLow))-0.5)*100;

    //--- compute gap measures
    if (regrLast[regrDirST] == regr[regrDirST])
    {
      if (regr[regrGapMin] == 0.00)
        regr[regrGapMin]  = regr[regrGap];
      else
        regr[regrGapMin]  = fmin(fabs(regr[regrGapMin]),fabs(regr[regrGap]))*regr[regrDirST];

      regr[regrGapMax]    = fmax(fabs(regr[regrGapMax]),fabs(regr[regrGap]))*regr[regrDirST];
    }
    else
      regr[regrGapMax]    = regr[regrGap];
    
    if (regr[regrGapMax] == regr[regrGap])
      regr[regrGapMin]    = regr[regrGap];
      
    //--- compute gap caution level
    if (fabs(regr[regrGapMax]) > 0.00)
      regr[regrGapPct] = 100-(((fabs(regr[regrGapMax])-fabs(regr[regrGap]))/(fabs(regr[regrGapMax])))*100);

    if (regr[regrGapPct]  < 5)
    {
      regr[regrGapCaution]  = GAP_STRONG_MAJOR;
    }
    else
    {
      if (regr[regrGapPct] < 50 && regr[regrGapCaution] != GAP_STRONG_MAJOR)
        regr[regrGapCaution]  = GAP_STRONG_MINOR;
      else
        regr[regrGapCaution]  = GAP_NO_CAUTION;
    }
        
    if (fabs(regr[regrDirST]+regr[regrDirLT]) == 2)
    {
      if (fabs(regr[regrGapMax])<=2.00)
        regr[regrGapCaution]=3*regr[regrDirST];
      else
      if (fabs(regr[regrGap])-fabs(regr[regrGapMin])>=5)
        regr[regrGapCaution] *= DIR_DOWN;
    }

    //--- compute regression strength
    regr[regrStr]         = 0.00;
    
    if (regr[regrDirST] == DIR_UP)
      if (regr[regrST]>regr[regrLT])
      {
        regr[regrStr] += (3 + regr[regrDirLT]);
        
        if (regr[regrDirLT] == DIR_UP)
        {
          if (regr[regrPWane] > 0.00)
            regr[regrStr] -= DIR_UP;

          if (regr[regrLTWane]>0.00)
            regr[regrStr] -= DIR_UP;
        }
        
        if (regr[regrDirLT] == DIR_DOWN)
          if (regr[regrLTWane]>0.00)
            regr[regrStr] -= DIR_DOWN;
      }
      else
      {
        regr[regrStr]     += 2;
        
        if (regr[regrDirLT] == DIR_UP)
          if (regr[regrLTWane]>0.00)
            regr[regrStr] += DIR_DOWN;
            
        if (regr[regrGap]>0.5)
          regr[regrStr]   += DIR_DOWN;
      }
    else 
      if (regr[regrST]<regr[regrLT])
      {
        regr[regrStr] += (-3 + regr[regrDirLT]);

        if (regr[regrDirLT] == DIR_DOWN)
        {
          if (regr[regrPWane] > 0.00)
            regr[regrStr] -= DIR_DOWN;

          if (regr[regrLTWane]>0.00)
            regr[regrStr] -= DIR_DOWN;
        }
        
        if (regr[regrDirLT] == DIR_UP)
          if (regr[regrLTWane]>0.00)
            regr[regrStr] -= DIR_UP;
      }
      else
      {
        regr[regrStr] -= 2;

        if (regr[regrDirLT] == DIR_DOWN)
          if (regr[regrLTWane]>0.00)
            regr[regrStr] += DIR_UP;

        if (regr[regrGap]>0.5)
          regr[regrStr]   += DIR_UP;
      }
        
    for (int idx=0;idx<regrMeasures;idx++)
      indRegrBuffer[idx] = regr[idx];
  }
  
//+------------------------------------------------------------------+
//| Refresh Screen - repaints indicator measures                     |
//+------------------------------------------------------------------+
  void RefreshScreen()
  {
     string strWane = "";
     
     UpdateLabel("rgStrength",proper(StrengthText())+
                 " (LT:"+DoubleToStr(regr[regrRetrLT],1)+":"+
                 " Cur:"+DoubleToStr(regr[regrRetrCur],1)+")",
        DirColor(dir(regr[regrStr])));

     UpdateLabel("rgGapCaution",GapCautionText(),DirColor((int)regr[regrGapCaution]));
     
     if (regr[regrPWane]>0.00)
       strWane  = "P-Wane: "+DoubleToStr(regr[regrPWane],Digits);
       
     if (regr[regrPTLWane]>0.00)
       strWane += " PT-Wane: "+DoubleToStr(regr[regrPTLWane]*100,1)+"%";
     
     if (regr[regrLTWane]>0.00)
       strWane += " LT-Wane: "+DoubleToStr(regr[regrLTWane],Digits);

     if (strWane == "")
       strWane  = "No Wane";
         
     UpdateLabel("rgWane",StringTrimLeft(strWane),clrLightGray);
     
//     Comment("LT:"+DoubleToStr(LTWaneBoundary,Digits)+" Ind LT:"+DoubleToStr(regr[regrLT],Digits)+"\n"+
//             "ST:"+DoubleToStr(STWaneBoundary,Digits)+" Ind ST:"+DoubleToStr(regr[regrST],Digits));
  }
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
    //---
    LoadMA(inpRegrST);
    r2=CalculateRegression(indWorkBuffer,indRegrSTBuffer,inpRegrRng);
   
    LoadMA(inpRegrLT);
    CalculateRegression(indWorkBuffer,indRegrLTBuffer,inpRegrRng);
    
    CalculatePWane();
    CalculateTRegression();
    CalculatePTWane();
    CalculateLTWane();
    CalculateSTWane();
    CalculateMeasures();
    
    RefreshScreen();
    
    //--- return value of prev_calculated for next call
    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- map indicator buffers
    SetIndexBuffer(0, indRegrSTBuffer);
    SetIndexBuffer(1, indRegrLTBuffer);
    SetIndexBuffer(2, indTLineBuffer);
    SetIndexBuffer(3, indWorkBuffer);
    SetIndexBuffer(4, indRegrBuffer);
    
    SetIndexEmptyValue(0, 0.00);
    SetIndexEmptyValue(1, 0.00);
    SetIndexEmptyValue(2, 0.00);
    SetIndexEmptyValue(3, 0.00);
    SetIndexEmptyValue(4, 0.00);
    
    ArrayInitialize(indRegrSTBuffer,  0.00);
    ArrayInitialize(indRegrLTBuffer,  0.00);
    ArrayInitialize(indTLineBuffer,   0.00);
    ArrayInitialize(indWorkBuffer,    0.00);
    ArrayInitialize(indRegrBuffer,    0.00);

    ArrayInitialize(regr,  0.00);

    //--- display labels
//    NewLabel("rgStrength","",5,33,clrLightGray,SCREEN_LR);
//    NewLabel("rgWane","",5,22,clrLightGray,SCREEN_LR);
//    NewLabel("rgGapCaution","",5,11,clrLightGray,SCREEN_LR);

    return(INIT_SUCCEEDED);
  }
