//+------------------------------------------------------------------+
//|                                                    regrMA-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
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

#include <regrMA-v2.mqh>

//--- indicator buffers
double    indRegrSTBuffer[];
double    indRegrLTBuffer[];
double    indTLineBuffer[];
double    indWorkBuffer[];
double    indRegrBuffer[];

double    r2;


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
  }

  
//+------------------------------------------------------------------+
//| CalculateMeasures - calculates regr metrics and loads buffer     |
//+------------------------------------------------------------------+
void CalculateMeasures(int Bar)
  {
    ArrayCopy(regrLast,regr);

    regr[regrST]      = indRegrSTBuffer[0];
    regr[regrLT]      = indRegrLTBuffer[0];
    regr[regrDirST]   = dir((int)regr[regrDirST],indRegrSTBuffer);
    regr[regrDirLT]   = dir((int)regr[regrDirLT],indRegrLTBuffer);
    
    //--- compute FOC metrics
    regr[regrFOCCur]      = (atan(pip(indTLineBuffer[0]-indTLineBuffer[inpRegrRng-1])/inpRegrRng)*180)/M_PI;
    regr[regrTLCur]       = (indTLineBuffer[0]);
    regr[regrFOCTrendDir] = dir(indTLineBuffer[0]-indTLineBuffer[inpRegrRng-1]);

    //--- compute TLine metrics
    if (regr[regrFOCTrendDir] == DIR_UP)
    {
      regr[regrTLLow]    = indTLineBuffer[inpRegrRng-1];
      regr[regrTLHigh]   = indTLineBuffer[0];
    }
    else
    if (regr[regrFOCTrendDir] == DIR_DOWN)
    {
      regr[regrTLLow]    = indTLineBuffer[0];
      regr[regrTLHigh]   = indTLineBuffer[inpRegrRng-1];
    }
    else
    {
      regr[regrTLLow]    = indTLineBuffer[0];
      regr[regrTLHigh]   = indTLineBuffer[0];
    }
    
    regr[regrTLMid]    = regr[regrTLLow]+((regr[regrTLHigh]-regr[regrTLLow])/2);

    //--- test pivot change and compute dir
    if (regr[regrFOCTrendDir] != regrLast[regrFOCTrendDir] )
    {
      regr[regrFOCMax]       = regr[regrFOCCur];
      regr[regrFOCPiv]       = regr[regrTLMid];      
      regr[regrFOCPivDevMin] = 0.00;
      regr[regrFOCPivDevMax] = 0.00;
    }

    if (fabs(NormalizeDouble(regr[regrFOCCur],1)) >= fabs(NormalizeDouble(regr[regrFOCMax],1)))
    {      
      if (Bar>0 && regr[regrFOCTrendDir] == regrLast[regrFOCTrendDir])
      {
        regr[regrFOCMax]  = regr[regrFOCCur]+(regrLast[regrFOCDev]*regrLast[regrFOCTrendDir]);
        regr[regrFOCMin]  = regr[regrFOCCur];
      }
      else
      {
        regr[regrFOCMax]  = regr[regrFOCCur];      
        regr[regrFOCMin]  = 0.00;
      }
    }
    else
    {    
      if (regr[regrFOCMin] == 0.00)
        regr[regrFOCMin]= regr[regrFOCCur];
      else
        regr[regrFOCMin]= fmin(fabs(regr[regrFOCCur]),fabs(regr[regrFOCMin]))*regr[regrFOCTrendDir];

      regr[regrFOCMax]  = fmax(fabs(regr[regrFOCCur]),fabs(regr[regrFOCMax]))*regr[regrFOCTrendDir];
    }

    regr[regrFOCDev]       = fabs(NormalizeDouble(regr[regrFOCMax],1))-fabs(NormalizeDouble(regr[regrFOCCur],1));
    regr[regrFOCPivDev]    = pip(Close[0]-regr[regrFOCPiv]);
    regr[regrFOCPivDevMin] = NormalizeDouble(fmin(regr[regrFOCPivDevMin],regr[regrFOCPivDev]),1);
    regr[regrFOCPivDevMax] = NormalizeDouble(fmax(regr[regrFOCPivDevMax],regr[regrFOCPivDev]),1);
        
    if (regr[regrFOCDev] == 0.00)
      regr[regrFOCCurDir]  = regr[regrFOCTrendDir];
    else
    if (NormalizeDouble(regr[regrFOCDev],1)>1.0)
    {
      if (NormalizeDouble(fabs(regr[regrFOCCur]),1)>
          NormalizeDouble(fabs(regr[regrFOCMin]),1)+(NormalizeDouble(fabs(regr[regrFOCMax]),1)-NormalizeDouble(fabs(regr[regrFOCMin]),1)/2))
        regr[regrFOCCurDir]  = regr[regrFOCTrendDir];
      else
        regr[regrFOCCurDir]  = regr[regrFOCTrendDir]*(-1);
    }
    else
    if (NormalizeDouble(regr[regrFOCDev],1)>0.1)
      if (NormalizeDouble(fabs(regr[regrFOCCur]),1)>NormalizeDouble(fabs(regr[regrFOCMin]),1)+0.1)
        regr[regrFOCCurDir]  = regr[regrFOCTrendDir];
      else
        regr[regrFOCCurDir]  = regr[regrFOCTrendDir]*(-1);
    else
      regr[regrFOCCurDir]  = regr[regrFOCTrendDir];
      
    if (regr[regrFOCPiv]>Close[0])
      regr[regrFOCPivDir] = DIR_DOWN;
    else
    if (regr[regrFOCPiv]<Close[0])
      regr[regrFOCPivDir] = DIR_UP;
    else
      regr[regrFOCPivDir] = DIR_NONE;      
    
    //---- Load measures buffer        
    for (int idx=0;idx<regrMeasures;idx++)
      indRegrBuffer[idx] = regr[idx];
  }
  
//+------------------------------------------------------------------+
//| Refresh Screen - repaints indicator measures                     |
//+------------------------------------------------------------------+
  void RefreshScreen()
  {
    UpdateLabel("rgFOCCur",DoubleToStr(regr[regrFOCCur],1),DirColor(dir(regr[regrFOCCurDir])),15);
    UpdateLabel("rgFOCMax",DoubleToStr(regr[regrFOCMax],1),DirColor(dir(regr[regrFOCTrendDir])),15);
    UpdateLabel("rgFOCDev",DoubleToStr(regr[regrFOCDev],1),DirColor(dir(regr[regrFOCCurDir])),8);
    UpdateLabel("rgFOCMin",DoubleToStr(regr[regrFOCMin],1),DirColor(dir(regr[regrFOCTrendDir])),8);
      
    UpdateLabel("rgFOCPivDev",DoubleToStr(regr[regrFOCPivDev],1),DirColor(dir(regr[regrFOCPivDev])),15);
    UpdateDirection("rgFOCPivDir",(int)regr[regrFOCPivDir],18);
    UpdateLabel("rgFOCPivDevMin",DoubleToStr(regr[regrFOCPivDevMin],1),DirColor(dir(regr[regrFOCPivDir])));
    UpdateLabel("rgFOCPivDevMax",DoubleToStr(regr[regrFOCPivDevMax],1),DirColor(dir(regr[regrFOCPivDir])));
    UpdateLabel("rgFOCPivPrice",DoubleToStr(regr[regrFOCPiv],Digits),DirColor(dir(regr[regrFOCPivDir])));

    UpdateDirection("rgFOCDir",(int)regr[regrFOCCurDir],12);
    UpdateDirection("rgFOCTrend",(int)regr[regrFOCTrendDir],12);
    
    ObjectSet("regrPivot",OBJPROP_TIME1,Time[0]);
    ObjectSet("regrPivot",OBJPROP_PRICE1,regr[regrFOCPiv]);
   
    SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,1,DirColor((int)regr[regrFOCCurDir]));
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
    
    CalculateTRegression();
    CalculateMeasures(rates_total-prev_calculated);
    
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
    NewLabel("rgFOC1","Current",10,5,clrLightGray,SCREEN_LR,0);
    NewLabel("rgFOC2","Max",78,5,clrLightGray,SCREEN_LR,0);
    NewLabel("rgFOC3","Pivot",175,5,clrLightGray,SCREEN_LR,0);
    NewLabel("rgFOCCur","",10,15,clrLightGray,SCREEN_LR,0);
    NewLabel("rgFOCMax","",70,15,clrNONE,SCREEN_LR,0);
    NewLabel("rgFOCDev","",35,37,clrNONE,SCREEN_LR,0);
    
    NewLabel("rgFOCMin","",90,37,clrNONE,SCREEN_LR,0);
    NewLabel("rgFOCDir","",10,35,clrNONE,SCREEN_LR,0);
    NewLabel("rgFOCTrend","",70,35,clrNONE,SCREEN_LR,0);
    NewLabel("rgFOCPivDev","",135,15,clrNONE,SCREEN_LR,0);
    NewLabel("rgFOCPivDir","",210,12,clrNONE,SCREEN_LR,0);
    NewLabel("rgFOCPivDevMin","",130,37,clrNONE,SCREEN_LR,0);
    NewLabel("rgFOCPivDevMax","",165,37,clrNONE,SCREEN_LR,0);
    NewLabel("rgFOCPivPrice","",200,37,clrNONE,SCREEN_LR,0);

    NewLabel("rgFOC4","Dev",21,50,clrLightGray,SCREEN_LR,0);
    NewLabel("rgFOC5","Trend",77,50,clrLightGray,SCREEN_LR,0);
    NewLabel("rgFOC6","Min",135,50,clrLightGray,SCREEN_LR,0);
    NewLabel("rgFOC7","Max",165,50,clrLightGray,SCREEN_LR,0);
    NewLabel("rgFOC8","Price",210,50,clrLightGray,SCREEN_LR,0);
    
    ObjectCreate("regrPivot",OBJ_ARROW,0,0,0);
    ObjectSet("regrPivot", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);
    ObjectSet("regrPivot", OBJPROP_COLOR, clrYellow);
    
    return(INIT_SUCCEEDED);
  }
