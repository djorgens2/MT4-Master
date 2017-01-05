//+------------------------------------------------------------------+
//|                                                    regrMA-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   7

//--- plot fast ST poly
#property indicator_label1  "indFastPolyST"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrFireBrick
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot fast LT poly
#property indicator_label2  "indFastPolyLT"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGoldenrod
#property indicator_width2  1

//--- plot fast trend line
#property indicator_label3  "indFastTLine"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSteelBlue
#property indicator_width3  1

//--- plot slow ST poly
#property indicator_label4  "indSlowPolyST"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrFireBrick
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- plot slow LT poly
#property indicator_label5  "indSlowPolyLT"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGoldenrod
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

//--- plot slow trend line
#property indicator_label6  "indSlowTLine"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrSteelBlue
#property indicator_style6  STYLE_DOT
#property indicator_width6  1

//--- buffer slow measures
#property indicator_label7  "indFastData"
#property indicator_type7   DRAW_NONE

//--- buffer fast measures
#property indicator_label8  "indSlowData"
#property indicator_type8   DRAW_NONE

//--- buffer comparative measures
#property indicator_label9  "indCompData"
#property indicator_type9   DRAW_NONE

//--- Fast PolyST TL ("STTL") used for hedging
#property indicator_label10  "indFastTLineST" 
#property indicator_type10   DRAW_LINE
#property indicator_color10  clrSteelBlue
#property indicator_style10  STYLE_SOLID
#property indicator_width10  1

#include <regrUtil.mqh>
#include <regrMA-v3.mqh>

//--- indicator buffers
double    indSlowSTBuffer[];
double    indSlowLTBuffer[];
double    indSlowTLineBuffer[];
double    indFastSTBuffer[];
double    indFastLTBuffer[];
double    indFastTLineBuffer[];
double    indFastDataBuffer[];
double    indSlowDataBuffer[];
double    indCompDataBuffer[];
double    indFastTLBufferST[];

double    workBuffer[];
double    r2;

//+------------------------------------------------------------------+
//| CalculateLastTop - returns the price of the adjacent top         |
//+------------------------------------------------------------------+
double CalculateLastTop(double &Buffer[])
  {
    double lastVal = 0.00;
    double curVal  = 0.00;

    int    bufDir  = DIR_UP;
    
    for (int idx=0;idx<Bars;idx++)
    {
      curVal = Buffer[idx];

      if (idx>0)
      {
        if (bufDir == DIR_DOWN && curVal<lastVal)
          return(lastVal);
      
        if (curVal == 0.00)
          return(lastVal);

        bufDir = dir(lastVal-curVal);
      }
      
      lastVal = curVal;
    }
    
    return (lastVal);
  }
  
//+------------------------------------------------------------------+
//| CalculateLastBottom - returns the price of the adjacent bottom   |
//+------------------------------------------------------------------+
double CalculateLastBottom(double &Buffer[])
  {        
    double lastVal = 0.00;
    double curVal  = 0.00;

    int    bufDir  = DIR_DOWN;
    
    for (int idx=0;idx<Bars;idx++)
    {
      curVal = Buffer[idx];

      if (idx>0)
      {
        if (bufDir == DIR_UP && curVal>lastVal)
          return(lastVal);
      
        if (curVal == 0.00)
          return(lastVal);

        bufDir = dir(lastVal-curVal);
      }
      
      lastVal = curVal;
    }
    
    return (lastVal);
  }
  
//+------------------------------------------------------------------+
//| CalculatePolyRegression - Computes the polynomial                |
//+------------------------------------------------------------------+
void CalculatePolyRegression(int MA, int Range, double &TgtBuf[])
  {
    int range = ArraySize(workBuffer);
    
    ArrayInitialize(workBuffer,0.00);
    
    for (int idx=0; idx<range; idx++)
      workBuffer[idx] = iCustom(Symbol(),Period(),"Custom Moving Averages",MA,0,MODE_SMA,0,idx);

    regrCalcPoly(workBuffer,TgtBuf,Range,inpRegrDegree);
  }

//+------------------------------------------------------------------+
//| CalculateTRegression - Computes the vector of the trendline      |
//+------------------------------------------------------------------+
void CalculateTLineRegression(int Range, double &SrcBufST[],double &SrcBufLT[],double &TgtBuf[])
  {
    ArrayInitialize(workBuffer,0.00);

    for (int idx=0; idx<Range; idx++)
      workBuffer[idx] = (SrcBufST[idx]+SrcBufLT[idx])/2;

    regrCalcTrendLine(Range,workBuffer,TgtBuf);
  }
  
//+------------------------------------------------------------------+
//| CalcFastTLineRegression - Computes the vector of the STTL        |
//+------------------------------------------------------------------+
void CalcFastTLineRegression(int Range, double &SrcBuf[],double &TgtBuf[])
  {
    ArrayInitialize(TgtBuf,0.00);

    regrCalcTrendLine(Range,SrcBuf,TgtBuf);
  }

//+------------------------------------------------------------------+
//| CalculateMeasures - calculates regr metrics and loads buffer     |
//+------------------------------------------------------------------+
void CalculateMeasures(int Bar, int Range, double &regr[], double &STBuffer[], double &LTBuffer[], double &TLineBuffer[], double &DataBuffer[])
  {
    double regrLast[regrMeasures];
    
    ArrayCopy(regrLast,regr);

    //--- compute Poly metrics
    regr[regrPolyST]         = STBuffer[0];
    regr[regrPolyLT]         = LTBuffer[0];
    regr[regrPolySTLTMid]    = (regr[regrPolyST]+regr[regrPolyLT])/2;
    regr[regrPolyDirST]      = dir((int)regr[regrPolyDirST],STBuffer);
    regr[regrPolyDirLT]      = dir((int)regr[regrPolyDirLT],LTBuffer);
    regr[regrPolyLow]        = STBuffer[0];
    regr[regrPolyHigh]       = STBuffer[0];
    regr[regrPolyLastTop]    = CalculateLastTop(STBuffer);
    regr[regrPolyLastBottom] = CalculateLastBottom(STBuffer);
    
    
    for (int idx=0;idx<Range;idx++)
    {
      regr[regrPolyLow]  = fmin(regr[regrPolyLow],STBuffer[idx]);
      regr[regrPolyHigh] = fmax(regr[regrPolyHigh],STBuffer[idx]);
    }

    //--- Compute current ST poly retrace
    regr[regrPolyMid]      = NormalizeDouble((regr[regrPolyLow]+regr[regrPolyHigh])/2,Digits);
    regr[regrPolyRange]    = pip(NormalizeDouble(regr[regrPolyHigh],Digits)-NormalizeDouble(regr[regrPolyLow],Digits));
    regr[regrPolyRetrace]  = 0.00;
    
    if (fabs(NormalizeDouble(regr[regrPolyLow],Digits)-NormalizeDouble(STBuffer[0],Digits))>0)
      regr[regrPolyRetrace]  = (pip(NormalizeDouble(STBuffer[0],Digits)-NormalizeDouble(regr[regrPolyLow],Digits))/NormalizeDouble(regr[regrPolyRange],1))*100;
    
    regr[regrPolyRetrace]  -= 50.0;

    //--- compute Poly Gap metrics
    regr[regrPolyGap]      = pip(NormalizeDouble(regr[regrPolyST],Digits)-NormalizeDouble(regr[regrPolyLT],Digits));
    
    if (regr[regrPolyDirLT]!=regrLast[regrPolyDirLT])
    {
      regr[regrPolyGapMin] = regr[regrPolyGap];
      regr[regrPolyGapMax] = regr[regrPolyGap];
    }
    else
    {
      regr[regrPolyGapMin] = fmin(regr[regrPolyGapMin],regr[regrPolyGap]);
      regr[regrPolyGapMax] = fmax(regr[regrPolyGapMax],regr[regrPolyGap]);
    }
        
    //--- compute FOC metrics
    regr[regrFOCCur]      = (atan(pip(TLineBuffer[0]-TLineBuffer[Range-1])/Range)*180)/M_PI;
    regr[regrTLCur]       = (TLineBuffer[0]);
    regr[regrFOCTrendDir] = dir(TLineBuffer[0]-TLineBuffer[Range-1]);

    //--- compute TLine metrics
    if (regr[regrFOCTrendDir] == DIR_UP)
    {
      regr[regrTLLow]    = TLineBuffer[Range-1];
      regr[regrTLHigh]   = TLineBuffer[0];
    }
    else
    if (regr[regrFOCTrendDir] == DIR_DOWN)
    {
      regr[regrTLLow]    = TLineBuffer[0];
      regr[regrTLHigh]   = TLineBuffer[Range-1];
    }
    else
    {
      regr[regrTLLow]    = TLineBuffer[0];
      regr[regrTLHigh]   = TLineBuffer[0];
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
        
    //--- FOC Dir Calc
    //--- STTL Cross to PolyST
    if (regr[regrPolyST]>=regr[regrPolyHigh])
      regr[regrFOCCurDir]  = DIR_UP;
    else
    if (regr[regrPolyST]<=regr[regrPolyLow])
      regr[regrFOCCurDir]  = DIR_DOWN;
    else
    if (regr[regrPolyST]>indFastTLBufferST[0])
      regr[regrFOCCurDir]  = DIR_UP;
    else
    if (regr[regrPolyST]<indFastTLBufferST[0])
      regr[regrFOCCurDir]  = DIR_DOWN;
    else
      regr[regrFOCCurDir]  = regr[regrFOCTrendDir];

    //--- FOC Piv Dir
    if (regr[regrFOCPiv]>Close[0])
      regr[regrFOCPivDir] = DIR_DOWN;
    else
    if (regr[regrFOCPiv]<Close[0])
      regr[regrFOCPivDir] = DIR_UP;
    else
      regr[regrFOCPivDir] = DIR_NONE;      
    
    //---- Load measures buffer        
    for (int idx=0;idx<regrMeasures;idx++)
      DataBuffer[idx] = regr[idx];
  }

//+------------------------------------------------------------------+
//| CalculateComposites - calcs gap metrics and ST/LT differentials  |
//+------------------------------------------------------------------+
  void CalculateComposites(int Bar)
  {
    ArrayCopy(regrCompLast,regrComp);

    //--- Tail/Head gap
    if (regrFast[regrTLLow]<regrFast[regrTLCur])
      //---Min is the tail
      regrComp[compTLTailGap] = pip(regrFast[regrTLLow]-indSlowTLineBuffer[inpRegrFastRng-1]);
    else
      regrComp[compTLTailGap] = pip(regrFast[regrTLHigh]-indSlowTLineBuffer[inpRegrFastRng-1]);

    regrComp[compTLHeadGap]   = pip(regrFast[regrTLCur]-regrSlow[regrTLCur]);
    
        //--- Poly gaps
    regrComp[compPolyGapST]  += regrFast[regrPolyST]-regrSlow[regrPolyST];
    regrComp[compPolyGapLT]  += regrFast[regrPolyLT]-regrSlow[regrPolyLT];
    
    //--- Calculate Strength
    //--- Angle of ascent
    regrComp[compTLStr]       = regrFast[regrFOCTrendDir];
      
    if (fabs(regrFast[regrFOCCur])>fabs(regrSlow[regrFOCCur]))
      regrComp[compTLStr]    += regrFast[regrFOCTrendDir];

    //--- Intersection gap
    if (fabs(regrComp[compTLHeadGap])<5.0)  //<--- possibly tunable
      regrComp[compTLStr]    += regrFast[regrFOCTrendDir];
    else
//    if (dir(regrComp[compTLHeadGap])==regrFast[regrFOCTrendDir])
      regrComp[compTLStr]    += dir(regrComp[compTLHeadGap]);
      
    //--- Above/Below
    regrComp[compTLStr]      += dir(regrComp[compTLHeadGap]);
    
    //--- No Strength check
    if (regrComp[compTLStr]==STR_NONE)
      regrComp[compTLStr]     = dir(regrComp[compPolyGapST]);
      
    //--- Composite Retrace
    regrComp[compPolyRetrace] = regrFast[regrPolyRetrace]+regrSlow[regrPolyRetrace];

    //--- Calculate Fast PolyST TL vars (primarily for hedging)
    regrComp[compPolySTTLHead]  = indFastTLBufferST[0];
    regrComp[compPolySTTLTail]  = indFastTLBufferST[inpRegrFastRng-1];
    regrComp[compPolySTTLFOC]   = (atan(pip(indFastTLBufferST[0]-indFastTLBufferST[inpRegrFastRng-1])/inpRegrFastRng)*180)/M_PI;    

    if (regrComp[compPolySTTLHead]>regrComp[compPolySTTLTail])
      regrComp[compPolySTTLDir] = DIR_UP;
    else
    if (regrComp[compPolySTTLHead]<regrComp[compPolySTTLTail])
      regrComp[compPolySTTLDir] = DIR_DOWN;
    else
      regrComp[compPolySTTLDir] = DIR_NONE;
      
    //---Mid gap deviation
    regrComp[compPolyMidDev]    = pip(regrFast[regrPolySTLTMid]-regrSlow[regrPolySTLTMid]);
    regrComp[compPolySTTLMid]   = (regrComp[compPolySTTLHead]+regrComp[compPolySTTLTail])/2;

    //--- compute Fast Poly STTL Gap, Min, Max
    regrComp[compPolySTTLGap]  = pip(indFastTLBufferST[0]-regrFast[regrTLCur]);

    if (regrComp[compPolySTTLDir]!=regrCompLast[compPolySTTLDir])
      regrComp[compPolySTTLFOCMax] = NormalizeDouble(regrComp[compPolySTTLFOC],1);
    
    if (fabs(NormalizeDouble(regrComp[compPolySTTLFOC],1)) >= fabs(NormalizeDouble(regrComp[compPolySTTLFOCMax],1)))
    {      
      if (Bar>0 && regrComp[compPolySTTLDir] == regrCompLast[compPolySTTLDir])
      {
        regrComp[compPolySTTLFOCMax] = regrComp[compPolySTTLFOC]+(regrCompLast[compPolySTTLFOCDev]*regrComp[compPolySTTLDir]);
        regrComp[compPolySTTLFOCMin] = regrComp[compPolySTTLFOC];
      }
      else
      {
        regrComp[compPolySTTLFOCMax]  = regrComp[compPolySTTLFOC];      
        regrComp[compPolySTTLFOCMin]  = 0.00;
      }
    }
    else
    {    
      if (regrComp[compPolySTTLFOCMin] == 0.00)
        regrComp[compPolySTTLFOCMin] = regrComp[compPolySTTLFOC];
      else
        regrComp[compPolySTTLFOCMin] = fmin(fabs(regrComp[compPolySTTLFOC]),fabs(regrComp[compPolySTTLFOCMin]))*regrComp[compPolySTTLDir];

      regrComp[compPolySTTLFOCMax]   = fmax(fabs(regrComp[compPolySTTLFOCMax]),fabs(regrComp[compPolySTTLFOC]))*regrComp[compPolySTTLDir];
    }

    regrComp[compPolySTTLFOCDev]     = fabs(NormalizeDouble(regrComp[compPolySTTLFOCMax],1))-fabs(NormalizeDouble(regrComp[compPolySTTLFOC],1));

    //--- Major Pivot Metrics
    regrComp[compMajorPivot] =  (regrSlow[regrPolyLT]+
                                 regrSlow[regrPolyST]+
                                 regrSlow[regrTLCur]+
                                 regrFast[regrPolyST]+
                                 regrFast[regrPolyLT]+
                                 regrFast[regrTLCur]+
                                 regrComp[compPolySTTLHead]
                                )/7;

    if (Bar>0)
    {
      if (regrComp[compMajorPivot]>regrCompLast[compMajorPivot])
        regrComp[compMajorPivotDir] = DIR_UP;
      else
      if (regrComp[compMajorPivot]<regrCompLast[compMajorPivot])
        regrComp[compMajorPivotDir] = DIR_DOWN;
    }
                                

    //--- Load comp data buffer
    for (int idx=0;idx<compMeasures;idx++)
      indCompDataBuffer[idx] = regrComp[idx];
  }
    
//+------------------------------------------------------------------+
//| Refresh Screen - repaints indicator measures                     |
//+------------------------------------------------------------------+
  void RefreshScreen()
  {
    UpdateLabel("rgFOCCur",DoubleToStr(regrFast[regrFOCCur],1),DirColor(dir(regrFast[regrFOCCurDir])),15);
    UpdateLabel("rgFOCMax",DoubleToStr(regrFast[regrFOCMax],1),DirColor(dir(regrFast[regrFOCTrendDir])),15);
    UpdateLabel("rgFOCDev",DoubleToStr(regrFast[regrFOCDev],1),DirColor(dir(regrFast[regrFOCCurDir])),8);
    UpdateLabel("rgFOCMin",DoubleToStr(regrFast[regrFOCMin],1),DirColor(dir(regrFast[regrFOCTrendDir])),8);
      
    UpdateLabel("rgFOCPivDev",DoubleToStr(regrFast[regrFOCPivDev],1),DirColor(dir(regrFast[regrFOCPivDev])),15);
    UpdateDirection("rgFOCPivDir",(int)regrFast[regrFOCPivDir],DirColor((int)regrFast[regrFOCPivDir]),18);
    UpdateLabel("rgFOCPivDevMin",DoubleToStr(regrFast[regrFOCPivDevMin],1),DirColor(dir(regrFast[regrFOCPivDir])));
    UpdateLabel("rgFOCPivDevMax",DoubleToStr(regrFast[regrFOCPivDevMax],1),DirColor(dir(regrFast[regrFOCPivDir])));
    UpdateLabel("rgFOCPivPrice",DoubleToStr(regrFast[regrFOCPiv],Digits),DirColor(dir(regrFast[regrFOCPivDir])));

    UpdateDirection("rgFOCDir",(int)regrFast[regrFOCCurDir],DirColor((int)regrFast[regrFOCCurDir]),12);
    UpdateDirection("rgFOCTrend",(int)regrFast[regrFOCTrendDir],DirColor((int)regrFast[regrFOCTrendDir]),12);
    
    UpdateDirection("rgPolySTDir",(int)regrFast[regrPolyDirST],DirColor((int)regrFast[regrPolyDirST]),12);
    UpdateLabel("rgPoly1",StrengthText((int)regrComp[compTLStr]),DirColor(dir(regrFast[regrPolyDirST])));
    
    ObjectSet("rgFastPolySTLTMid",OBJPROP_TIME1,Time[0]);
    ObjectSet("rgFastPolySTLTMid",OBJPROP_PRICE1,regrFast[regrPolySTLTMid]);

    ObjectSet("rgSlowPolySTLTMid",OBJPROP_TIME1,Time[0]);
    ObjectSet("rgSlowPolySTLTMid",OBJPROP_PRICE1,regrSlow[regrPolySTLTMid]);

    UpdateLabel("rgPolyRet",DoubleToStr(regrComp[compPolyRetrace],1)+"%",DirColor(dir(regrFast[regrPolyRetrace])));
    UpdateDirection("rgPolyRetDir",dir(regrFast[regrPolyRetrace]),DirColor(dir(regrFast[regrPolyRetrace])),12);
    UpdateLabel("rgPolySlowGap",DoubleToStr(regrSlow[regrPolyGap],1),DirColor(dir(regrSlow[regrPolyGap])));    
    UpdateDirection("rgPolySlowDir",dir(regrSlow[regrPolyGap]),DirColor(dir(regrSlow[regrPolyGap])),12);

    UpdateLine("rgMajorPivot",regrComp[compMajorPivot],STYLE_SOLID,DirColor((int)regrComp[compMajorPivotDir]));

    SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,1,DirColor((int)regrFast[regrFOCCurDir]));
    SetIndexStyle(5,DRAW_LINE,STYLE_DOT,1,DirColor((int)regrSlow[regrFOCCurDir]));
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
    CalculatePolyRegression(inpRegrST,inpRegrFastRng,indFastSTBuffer);
    CalculatePolyRegression(inpRegrLT,inpRegrFastRng,indFastLTBuffer);
    CalculatePolyRegression(inpRegrST,inpRegrSlowRng,indSlowSTBuffer);
    CalculatePolyRegression(inpRegrLT,inpRegrSlowRng,indSlowLTBuffer);
    
    CalculateTLineRegression(inpRegrFastRng,indFastSTBuffer,indFastLTBuffer,indFastTLineBuffer);
    CalculateTLineRegression(inpRegrSlowRng,indSlowSTBuffer,indSlowLTBuffer,indSlowTLineBuffer);
    CalcFastTLineRegression(inpRegrFastRng,indFastSTBuffer,indFastTLBufferST);

    CalculateMeasures(rates_total-prev_calculated,inpRegrFastRng,regrFast,indFastSTBuffer,indFastLTBuffer,indFastTLineBuffer,indFastDataBuffer);
    CalculateMeasures(rates_total-prev_calculated,inpRegrSlowRng,regrSlow,indSlowSTBuffer,indSlowLTBuffer,indSlowTLineBuffer,indSlowDataBuffer);

    CalculateComposites(rates_total-prev_calculated);
    
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
    SetIndexBuffer(BUF_FAST_POLY_ST,   indFastSTBuffer);
    SetIndexBuffer(BUF_FAST_POLY_LT,   indFastLTBuffer);
    SetIndexBuffer(BUF_FAST_POLY_TL,   indFastTLineBuffer);
    SetIndexBuffer(BUF_SLOW_POLY_ST,   indSlowSTBuffer);
    SetIndexBuffer(BUF_SLOW_POLY_LT,   indSlowLTBuffer);
    SetIndexBuffer(BUF_SLOW_POLY_TL,   indSlowTLineBuffer);
    SetIndexBuffer(BUF_FAST_DATA,      indFastDataBuffer);
    SetIndexBuffer(BUF_SLOW_DATA,      indSlowDataBuffer);
    SetIndexBuffer(BUF_COMP_DATA,      indCompDataBuffer);
    SetIndexBuffer(BUF_FAST_POLY_STTL, indFastTLBufferST);
    
    SetIndexEmptyValue(BUF_FAST_POLY_ST,   0.00);
    SetIndexEmptyValue(BUF_FAST_POLY_LT,   0.00);
    SetIndexEmptyValue(BUF_FAST_POLY_TL,   0.00);
    SetIndexEmptyValue(BUF_SLOW_POLY_ST,   0.00);
    SetIndexEmptyValue(BUF_SLOW_POLY_LT,   0.00);
    SetIndexEmptyValue(BUF_SLOW_POLY_TL,   0.00);
    SetIndexEmptyValue(BUF_FAST_DATA,      0.00);
    SetIndexEmptyValue(BUF_SLOW_DATA,      0.00);
    SetIndexEmptyValue(BUF_COMP_DATA,      0.00);
    SetIndexEmptyValue(BUF_FAST_POLY_STTL, 0.00);
    
    ArrayInitialize(indFastSTBuffer,       0.00);
    ArrayInitialize(indFastLTBuffer,       0.00);
    ArrayInitialize(indFastTLineBuffer,    0.00);
    ArrayInitialize(indSlowSTBuffer,       0.00);
    ArrayInitialize(indSlowLTBuffer,       0.00);
    ArrayInitialize(indSlowTLineBuffer,    0.00);
    ArrayInitialize(indFastDataBuffer,     0.00);
    ArrayInitialize(indSlowDataBuffer,     0.00);
    ArrayInitialize(indCompDataBuffer,     0.00);
    ArrayInitialize(indFastTLBufferST,     0.00);
    
    ArrayResize(workBuffer,inpRegrSlowRng+inpRegrLT+1);

    ArrayInitialize(regrSlow,   0.00);
    ArrayInitialize(regrFast,   0.00);
    ArrayInitialize(regrComp,   0.00);
    ArrayInitialize(workBuffer, 0.00);
    

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
    
    NewLabel("rgPoly1","",160,65,clrNONE,SCREEN_LR,0);
    NewLabel("rgPolySTDir","",140,62,clrNONE,SCREEN_LR,0);
    NewLabel("rgPoly2","Gap(S)",21,80,clrLightGray,SCREEN_LR,0);
    NewLabel("rgPoly3","Retrace",77,80,clrLightGray,SCREEN_LR,0);
    NewLabel("rgPolyRet","",90,65,clrNONE,SCREEN_LR,0);
    NewLabel("rgPolyRetDir","",70,62,clrNONE,SCREEN_LR,0);
    NewLabel("rgPolySlowGap","",35,65,clrNONE,SCREEN_LR,0);    
    NewLabel("rgPolySlowDir","",10,62,clrNONE,SCREEN_LR,0);

    NewLine("rgMajorPivot");

    ObjectCreate("rgFastPolySTLTMid",OBJ_ARROW,0,0,0);
    ObjectSet("rgFastPolySTLTMid", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);
    ObjectSet("rgFastPolySTLTMid", OBJPROP_COLOR, clrYellow);
    
    ObjectCreate("rgSlowPolySTLTMid",OBJ_ARROW,0,0,0);
    ObjectSet("rgSlowPolySTLTMid", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);
    ObjectSet("rgSlowPolySTLTMid", OBJPROP_COLOR, clrWhite);

    return(INIT_SUCCEEDED);
  }
