//+------------------------------------------------------------------+
//|                                                     pipMA-v3.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
//#property link      "http://www.mql5.com"
#property version   "1.1"
#property strict
#property indicator_separate_window
#property indicator_buffers 3

//--- plot indPipValue
#property indicator_label1  "indPipHistory"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot indTLine
#property indicator_label2  "indTLine"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGoldenrod
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- plot indPLine
#property indicator_label3  "indPLine"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCrimson
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#include <pipMA-v3.mqh>

//--- indicator buffers
double    indPipBuffer[];
double    indTLineBuffer[];
double    indPLineBuffer[];
double    indDataBuffer[];

double    pipHistory[5000];
int       pipIndex      = inpPeriod;
int       pipWinIdx     = WindowsTotal()-1;
int       pipWinOffset  = 0;
string    pipWinText    = DoubleToStr(pipWinIdx,0);
bool      pipWinDebug   = true;

//+------------------------------------------------------------------+
//| pipChange - manages pip history                                  |
//+------------------------------------------------------------------+
bool pipChange()
  {
    int idx=pipIndex;

    if (fabs(pip(pipHistory[pipIndex]-Close[0]))>=1.0)
    {
      if (pipIndex == 0)
        for (pipIndex=inpPeriod-1; pipIndex>0; pipIndex--)
          pipHistory[pipIndex]=pipHistory[pipIndex-1];
      else
        pipIndex--;
  
      pipHistory[pipIndex]=Close[0];
       

      while (idx<inpPeriod)
      {
        indPipBuffer[idx-pipIndex]=pipHistory[idx];
        idx++;
      }
        
      return(true);
    }

    return(false);
  }

//+------------------------------------------------------------------+
//| CalculateTLineRegression - Computes the vector of the trendline  |
//+------------------------------------------------------------------+
void CalculateTLineRegression()
  {
    //--- Linear regression line
    double m[5] = {0.00,0.00,0.00,0.00,0.00};  //--- slope
    double b    = 0.00;                        //--- y-intercept
    
    double sumx = 0.00;
    double sumy = 0.00;
    
    for (int idx=0; idx<inpPeriod; idx++)
    {
      sumx += idx+1;
      sumy += pipHistory[idx];
      
      m[1] += (idx+1)*pipHistory[idx];
      m[3] += pow(idx+1,2);
    }
    
    m[1]   *= inpPeriod;
    m[2]    = sumx*sumy;
    m[3]   *= inpPeriod;
    m[4]    = pow(sumx,2);
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy - m[0]*sumx)/inpPeriod;
    
    for (int idx=0; idx<inpPeriod; idx++)
      //--- y=mx+b
      indTLineBuffer[inpPeriod-idx-1] = (m[0]*(inpPeriod-idx-1))+b;
      
    indPipBuffer[inpPeriod]=0.00;
    indTLineBuffer[inpPeriod]=0.00;
  }

//+------------------------------------------------------------------+
//| CalculateMeasures - calculates pipMA metrics and loads buffer    |
//+------------------------------------------------------------------+
void CalculateMeasures()
  {
    double agg = 0.00;
    int    tempDir = DIR_NONE;
    
    ArrayCopy(dataLast,data);
    
    //--- range metrics
    data[dataRngLow]    = pipHistory[0];
    data[dataRngHigh]   = pipHistory[0];
    
    for (int idx=0; idx<inpPeriod; idx++)
    {
      data[dataRngLow]  = fmin(data[dataRngLow],pipHistory[idx]);
      data[dataRngHigh] = fmax(data[dataRngHigh],pipHistory[idx]);

      agg              += pipHistory[idx];
    }

    data[dataRngMA]     = agg / inpPeriod;
    data[dataRngSize]   = pip(data[dataRngHigh] - data[dataRngLow]);
    data[dataRngMid]    = (data[dataRngHigh] + data[dataRngLow]) / 2;
    data[dataRngMADev]  = pip(data[dataRngMA]-data[dataRngMid]);

    if (data[dataRngStr] == STR_NONE) //--- initialize first pass
    {
      for (int idx=0; idx<inpPeriod; idx++)
      {
        if (data[dataRngLow] == pipHistory[idx])
        {
          tempDir      = DIR_DOWN;
          break;
        }
        
        if (data[dataRngHigh] == pipHistory[idx])
        {
          tempDir      = DIR_UP;
          break;
        }
      }

      data[dataRngLowDir]    = tempDir;
      data[dataRngMidDir]    = tempDir;
      data[dataRngHighDir]   = tempDir;
      data[dataRngDir]       = tempDir;
    }
    else
    {
      if (dataLast[dataRngLow]!=data[dataRngLow])
        data[dataRngLowDir]  = dir(data[dataRngLow]-dataLast[dataRngLow]);
      
      if (dataLast[dataRngMid]!=data[dataRngMid])
        data[dataRngMidDir]  = dir(data[dataRngMid]-dataLast[dataRngMid]);

      if (dataLast[dataRngHigh]!=data[dataRngHigh])
        data[dataRngHighDir] = dir(data[dataRngHigh]-dataLast[dataRngHigh]);

      if (Close[0] < dataLast[dataRngLow])
        data[dataRngDir]     = DIR_DOWN;
      
      if (Close[0] > dataLast[dataRngHigh])
        data[dataRngDir]     = DIR_UP;
    }

    data[dataRngStr]     = data[dataRngLowDir]+data[dataRngMidDir]+data[dataRngHighDir];

    if (data[dataRngSize]>dataLast[dataRngSize])
    {
      data[dataRngFactor]= 0.00;
      data[dataRngMax]   = data[dataRngSize];
    }
    
    if (data[dataRngSize]<dataLast[dataRngSize])
      data[dataRngFactor]= data[dataRngSize]-data[dataRngMax];

    //--- factor of change metrics
    data[dataFOCCur]       = (atan(pip(indTLineBuffer[0]-indTLineBuffer[inpPeriod-1])/inpPeriod)*180)/M_PI;
    data[dataFOCTrendDir]  = dir(data[dataTLCur]-indTLineBuffer[inpPeriod-1]);

    //--- compute TLine metrics
    data[dataTLCur]        = (indTLineBuffer[0]);

    if (data[dataFOCTrendDir] == DIR_UP)
    {
      data[dataTLLow]      = indTLineBuffer[inpPeriod-1];
      data[dataTLHigh]     = indTLineBuffer[0];
    }
    else
    if (data[dataFOCTrendDir] == DIR_DOWN)
    {
      data[dataTLLow]      = indTLineBuffer[0];
      data[dataTLHigh]     = indTLineBuffer[inpPeriod-1];
    }
    else
    {
      data[dataTLLow]      = indTLineBuffer[0];
      data[dataTLHigh]     = indTLineBuffer[0];
    }
    
    data[dataTLMid]        = data[dataTLLow]+((data[dataTLHigh]-data[dataTLLow])/2);
    
    //--- pivot change test
    if (data[dataFOCTrendDir] != dataLast[dataFOCTrendDir])
    {
      data[dataFOCMax]       = data[dataFOCCur];
      data[dataFOCPiv]       = data[dataTLMid];      
      data[dataFOCPivDevMin] = 0.00;
      data[dataFOCPivDevMax] = 0.00;
    }
    if (fabs(NormalizeDouble(data[dataFOCCur],1)) >= fabs(NormalizeDouble(data[dataFOCMax],1)))
    {      
      data[dataFOCMax]       = data[dataFOCCur];      
      data[dataFOCMin]       = 0.00;
    }
    else
    {    
      if (data[dataFOCMin] == 0.00)
        data[dataFOCMin]     = data[dataFOCCur];
      else
        data[dataFOCMin]     = fmin(fabs(data[dataFOCCur]),fabs(data[dataFOCMin]))*data[dataFOCTrendDir];

      data[dataFOCMax]       = fmax(fabs(data[dataFOCCur]),fabs(data[dataFOCMax]))*data[dataFOCTrendDir];
    }

    data[dataFOCDev]         = fabs(NormalizeDouble(data[dataFOCMax],1))-fabs(NormalizeDouble(data[dataFOCCur],1));
    data[dataFOCPivDev]      = pip(Close[0]-data[dataFOCPiv]);
    data[dataFOCPivDevMin]   = NormalizeDouble(fmin(data[dataFOCPivDevMin],data[dataFOCPivDev]),1);
    data[dataFOCPivDevMax]   = NormalizeDouble(fmax(data[dataFOCPivDevMax],data[dataFOCPivDev]),1);
        
    if (data[dataFOCDev] == 0.00)
      data[dataFOCCurDir]  = data[dataFOCTrendDir];
    else
    if (NormalizeDouble(data[dataFOCDev],1)>0.1)
      if (NormalizeDouble(data[dataFOCCur],1)>NormalizeDouble(fabs(data[dataFOCMin]),1)+0.1)
        data[dataFOCCurDir]  = data[dataFOCTrendDir];
      else
        data[dataFOCCurDir]  = data[dataFOCTrendDir]*(-1);
    else
      data[dataFOCCurDir]  = data[dataFOCTrendDir];
      
    if (data[dataFOCPiv]>Close[0])
      data[dataFOCPivDir] = DIR_DOWN;
    else
    if (data[dataFOCPiv]<Close[0])
      data[dataFOCPivDir] = DIR_UP;
    else
      data[dataFOCPivDir] = DIR_NONE;
 
    //--- Other metrics
    data[dataTickCnt]      = 0.00;
    data[dataPipDir]       = dir(pipHistory[0]-pipHistory[1]);
    data[dataPLine]        = indPLineBuffer[0];
    data[dataPLineDir]     = dir((int)dataLast[dataPLineDir],indPLineBuffer);
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen - repaints screen visuals                          |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    if (pipIndex == 0)
    {  
      SetLevelValue(1,data[dataRngMid]);
    
      UpdateLabel("lrFOCCur:"+pipWinText,DoubleToStr(data[dataFOCCur],1),DirColor((int)data[dataFOCCurDir]),15);
      UpdateLabel("lrFOCMax:"+pipWinText,DoubleToStr(data[dataFOCMax],1),DirColor((int)data[dataFOCTrendDir]),15);
      UpdateLabel("lrFOCDev:"+pipWinText,DoubleToStr(data[dataFOCDev],1),DirColor((int)data[dataFOCCurDir]),8);
      UpdateLabel("lrFOCMin:"+pipWinText,DoubleToStr(data[dataFOCMin],1),DirColor((int)data[dataFOCTrendDir]),8);

      UpdateLine("lnFOCPivot",data[dataFOCPiv],STYLE_DASHDOTDOT,DirColor(dir(data[dataFOCPivDir])));
      UpdateLine("lnpipMA",data[dataFOCPiv],STYLE_DASHDOTDOT,DirColor(dir(data[dataFOCPivDir])));
      
      UpdateLabel("lrFOCPivDev:"+pipWinText,DoubleToStr(data[dataFOCPivDev],1),DirColor(dir(data[dataFOCPivDev])),15);
      UpdateDirection("lrFOCPivDir:"+pipWinText,(int)data[dataFOCPivDir],DirColor((int)data[dataFOCPivDir]),18);
      UpdateLabel("lrFOCPivDevMin:"+pipWinText,DoubleToStr(data[dataFOCPivDevMin],1),DirColor(dir(data[dataFOCPivDevMin])));
      UpdateLabel("lrFOCPivDevMax:"+pipWinText,DoubleToStr(data[dataFOCPivDevMax],1),DirColor(dir(data[dataFOCPivDevMax])));
      UpdateLabel("lrFOCPivPrice:"+pipWinText,DoubleToStr(data[dataFOCPiv],Digits),DirColor(dir(data[dataFOCPivDev])));
      

      UpdateDirection("lrFOCDir:"+pipWinText,(int)data[dataFOCCurDir],DirColor((int)data[dataFOCCurDir]),12);
      UpdateDirection("lrFOCTrend:"+pipWinText,(int)data[dataFOCTrendDir],DirColor((int)data[dataFOCCurDir]),12);
      
      UpdateLabel("rngMA:"+pipWinText,"Range MA: "+DoubleToStr(data[dataRngMA],Digits),DirColor((int)data[dataRngStr]));
      UpdateLabel("rngMADev:"+pipWinText,"Dev: "+DoubleToStr(data[dataRngMADev],1)+" Tick: "+DoubleToStr((int)data[dataTickCnt],0),DirColor((int)data[dataRngStr]));
      UpdateLabel("rngSize:"+pipWinText,"Size: "+DoubleToStr(data[dataRngSize],1),DirColor((int)data[dataRngStr]));

      ObjectSet("pipPivot",OBJPROP_TIME1,Time[0]);
      ObjectSet("pipPivot",OBJPROP_PRICE1,data[dataFOCPiv]);
        
      ObjectSet("pipMA",OBJPROP_TIME1,Time[0]);
      ObjectSet("pipMA",OBJPROP_PRICE1,data[dataRngMA]);

      if (data[dataRngFactor]<0.00)
        UpdateLabel("rngFactor:"+pipWinText,"Factor: "+DoubleToStr(data[dataRngFactor],1),DirColor((int)data[dataRngStr]*(-1)));
      else
        UpdateLabel("rngFactor:"+pipWinText,"Factor: "+DoubleToStr(data[dataRngFactor],1),DirColor((int)data[dataRngStr]));
        
      if (data[dataRngDir] == DIR_UP)
      {
        UpdateLine("rngHigh",data[dataRngHigh],STYLE_SOLID,DirColor((int)data[dataRngHighDir],clrForestGreen,clrFireBrick));
        UpdateLine("rngLow",data[dataRngLow],STYLE_DOT,DirColor((int)data[dataRngLowDir],clrForestGreen,clrFireBrick));
      }
      else
      {
        UpdateLine("rngHigh",data[dataRngHigh],STYLE_DOT,DirColor((int)data[dataRngHighDir],clrForestGreen,clrFireBrick));
        UpdateLine("rngLow",data[dataRngLow],STYLE_SOLID,DirColor((int)data[dataRngLowDir],clrForestGreen,clrFireBrick));
      }

      UpdateLine("rngMid",data[dataRngMid],STYLE_DOT,DirColor((int)data[dataRngMidDir],clrForestGreen,clrFireBrick));
    }
    else
    {
      int    clr = clrGoldenrod;
      double pct = ((double)(inpPeriod-pipIndex)/inpPeriod)*100;
      
      if (pct>90)
        clr      = clrYellow;
        
      UpdateLabel("lrFOC0:"+pipWinText,"Collecting Data ("+
             DoubleToStr(inpPeriod-pipIndex,0)+"/"+
             DoubleToStr(inpPeriod,0)+") "+
             DoubleToStr(pct,1)+"%",clr);
             
      //--- occurs only once
      if (pipIndex-1 == 0)
      {
        //--- screen data labels
        UpdateLabel("lrFOC0:"+pipWinText,"Factor of Change",clrGoldenrod);
        
        NewLabel("lrFOC1:"+pipWinText,"Current",10,21+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC2:"+pipWinText,"Max",80,21+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC3:"+pipWinText,"Pivot",175,21+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCCur:"+pipWinText,"",10,30+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCMax:"+pipWinText,"",70,30+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCDev:"+pipWinText,"",30,52+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCMin:"+pipWinText,"",90,52+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCDir:"+pipWinText,"",5,51+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCTrend:"+pipWinText,"",65,51+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivDev:"+pipWinText,"",140,30+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivDir:"+pipWinText,"",210,29+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivDevMin:"+pipWinText,"",125,52+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivDevMax:"+pipWinText,"",165,52+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivPrice:"+pipWinText,"",200,52+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);

        
        NewLabel("lrFOC4:"+pipWinText,"Dev",20,63+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC5:"+pipWinText,"Trend",77,63+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC6:"+pipWinText,"Min",135,63+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC7:"+pipWinText,"Max",165,63+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC8:"+pipWinText,"Price",210,63+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
    
        NewLine("lnFOCPivot",0.00,clrLightGray,STYLE_DASHDOT,1);
        NewLine("lnpipMA",0.00,clrLightGray,STYLE_DASHDOT,1);

        NewLabel("rngMA:"+pipWinText,"",5,38,clrLightGray,SCREEN_LL,pipWinIdx);
        NewLabel("rngMADev:"+pipWinText,"",5,27,clrLightGray,SCREEN_LL,pipWinIdx);
        NewLabel("rngSize:"+pipWinText,"",5,16,clrLightGray,SCREEN_LL,pipWinIdx);
        NewLabel("rngFactor:"+pipWinText,"",5,5,clrLightGray,SCREEN_LL,pipWinIdx);

        ObjectCreate("pipPivot",OBJ_ARROW,0,0,0);
        ObjectSet("pipPivot", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);
        
        ObjectCreate("pipMA",OBJ_ARROW,1,0,0);
        ObjectSet("pipMA", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);

        NewLine("rngLow");
        NewLine("rngMid");
        NewLine("rngHigh");
      }
    }
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
    //--- Recompute on pip change
    if (pipChange())
      if (pipIndex == 0)
      {
        CalculateTLineRegression();
        CalculateMeasures();
        CalculateRegression(indPipBuffer,indPLineBuffer,inpPeriod-1);
      }
   
   data[dataTickCnt]++;
   
   //--- Load data buffer each pass to cause reload on bar change
    for (int idx=0; idx<dataMeasures; idx++)
      indDataBuffer[idx]= data[idx];

    if ((pipWinDebug && pipWinIdx==0)||pipWinIdx>0)
      RefreshScreen();
    
    //--- return value of prev_calculated for next call
    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- indicator buffers mapping
    IndicatorBuffers(4);
    
    SetIndexBuffer(0,indPipBuffer);
    SetIndexBuffer(1,indTLineBuffer);
    SetIndexBuffer(2,indPLineBuffer);
    SetIndexBuffer(3,indDataBuffer);
 
    SetIndexEmptyValue(0, 0.00);
    SetIndexEmptyValue(1, 0.00);
    SetIndexEmptyValue(2, 0.00);
    SetIndexEmptyValue(3, 0.00);
   
    ArrayInitialize(indPipBuffer,    0.00);
    ArrayInitialize(indTLineBuffer,  0.00);
    ArrayInitialize(indPLineBuffer,  0.00);
    ArrayInitialize(indDataBuffer,   0.00);

    ArrayInitialize(pipHistory,      0.00);
    
    IndicatorShortName("pipMA-v3:"+DoubleToStr(pipWinIdx,0));
    
    if (pipWinIdx == 0)
      pipWinOffset = 20;
        
    NewLabel("lrFOC0:"+pipWinText,"",18,12+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);

    return(INIT_SUCCEEDED);
  }