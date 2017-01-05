//+------------------------------------------------------------------+
//|                                                     pipMA-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
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

#include <std_utility.mqh>
#include <pipMA-v4.mqh>
#include <regrUtil.mqh>

//--- indicator buffers
double    indPipBuffer[];
double    indTLineBuffer[];
double    indPLineBuffer[];
double    indDataBuffer[];

bool      rngBreakout   = false;

double    pipHistory[];
int       pipIndex      = inpPeriod;
int       pipWinIdx     = WindowsTotal()-1;
int       pipWinOffset  = 0;
string    pipWinText    = DoubleToStr(pipWinIdx,0);
bool      pipWinDebug   = false;

double    frqHistory[];

double    frqPriceHigh  = 0.00;
double    frqPriceLow   = 0.00;

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
//| CalculateMeasures - calculates pipMA metrics and loads buffer    |
//+------------------------------------------------------------------+
void CalculateMeasures()
  {
    double agg = 0.00;
    int    tempDir = DIR_NONE;
    
    ArrayCopy(dataLast,data);
    
    //--- range metrics (eff trading rng incl)
    data[dataRngLow]    = pipHistory[0];
    data[dataRngHigh]   = pipHistory[0];
    
    for (int idx=0; idx<inpPeriod; idx++)
    {
      data[dataRngLow]  = NormalizeDouble(fmin(data[dataRngLow],pipHistory[idx]),Digits);
      data[dataRngHigh] = NormalizeDouble(fmax(data[dataRngHigh],pipHistory[idx]),Digits);

      agg              += pipHistory[idx];
    }

    data[dataRngMA]     = agg / inpPeriod;
    data[dataRngSize]   = pip(data[dataRngHigh] - data[dataRngLow]);
    data[dataRngMid]    = (data[dataRngHigh] + data[dataRngLow]) / 2;
    data[dataRngMADev]  = pip(data[dataRngMA]-data[dataRngMid]);

    if (data[dataRngStr] == STR_NONE) //--- initialize first pass
    {
      data[dataRngExpPrice] = data[dataRngMid];
      
      for (int idx=0; idx<inpPeriod; idx++)
      {
        if (NormalizeDouble(data[dataRngLow],Digits) == NormalizeDouble(pipHistory[idx],Digits))
        {
          tempDir      = DIR_DOWN;
          break;
        }
        
        if (NormalizeDouble(data[dataRngHigh],Digits) == NormalizeDouble(pipHistory[idx],Digits))
        {
          tempDir      = DIR_UP;
          break;
        }
      }

      data[dataRngLowDir]    = tempDir;
      data[dataRngMidDir]    = tempDir;
      data[dataRngHighDir]   = tempDir;
      data[dataRngDir]       = tempDir;
      
      data[dataETRLow]       = data[dataRngLow];
      data[dataETRHigh]      = data[dataRngHigh];
      data[dataETRDir]       = tempDir;
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
      {
        data[dataRngDir]      = DIR_DOWN;
        
        if (data[dataETRLow]>data[dataRngLow])
        {
          data[dataETRDir]    = DIR_DOWN;
          data[dataETRLow]    = data[dataRngLow];
          data[dataETRHigh]   = data[dataRngHigh];
        }
      }
      
      if (Close[0] > dataLast[dataRngHigh])
      {
        data[dataRngDir]      = DIR_UP;

        if (data[dataETRHigh]<dataLast[dataRngHigh])
        {
          data[dataETRDir]    = DIR_UP;
          data[dataETRLow]    = data[dataRngLow];
          data[dataETRHigh]   = data[dataRngHigh];
        }
      }
    }
    
    //--- Expansion/Contraction calcs
    if (data[dataRngDir]!=dataLast[dataRngDir])
    {
      if (data[dataRngDir]==DIR_DOWN)
        data[dataRngExpPrice] = dataLast[dataRngLow];

      if (data[dataRngDir]==DIR_UP)
        data[dataRngExpPrice] = dataLast[dataRngHigh];
    }

    //--- Compute range strength
    data[dataRngStr]     = data[dataRngLowDir]+data[dataRngMidDir]+data[dataRngHighDir];
        
    if (data[dataRngDir]==DIR_UP)
    {
      if (data[dataRngHigh]<dataLast[dataRngHigh]||
         (rngBreakout && Close[0]<data[dataRngExpPrice]))
      {
        data[dataRngExpPrice] = data[dataRngMid];
        rngBreakout           = false;
      }

      if (data[dataRngMid]>data[dataRngExpPrice])
      {
        data[dataRngStr]++;
        rngBreakout = true;
      }
    }
    
    if (data[dataRngDir]==DIR_DOWN)
    {
      if (data[dataRngLow]>dataLast[dataRngLow]||
         (rngBreakout && Close[0]>data[dataRngExpPrice]))
      {
        data[dataRngExpPrice] = data[dataRngMid];
        rngBreakout           = false;
      }

      if (data[dataRngMid]<data[dataRngExpPrice])
      {
        data[dataRngStr]--;
        rngBreakout = true;
      }
    }

    //--- Reset range contraction on expansion
    if (data[dataRngSize]>dataLast[dataRngSize])
    {
      data[dataRngContFact]= 0.00;
      data[dataRngMax]   = data[dataRngSize];
    }
    
    if (data[dataRngSize]<dataLast[dataRngSize])
      data[dataRngContFact]= data[dataRngSize]-data[dataRngMax];

    //--- compute remaining ETR measures  
    data[dataETRMid]       = ((data[dataETRHigh]-data[dataETRLow])/2)+data[dataETRLow];
    data[dataETRContFact]  = pip((data[dataRngHigh]-data[dataETRHigh])+
                                 (data[dataETRLow]-data[dataRngLow]));
                                 
    if (Close[0]<=data[dataETRLow])
      data[dataETRRetrace]   = 0.00;
    else
      data[dataETRRetrace]   = ((Close[0]-data[dataETRLow])/(data[dataETRHigh]-data[dataETRLow]))*100;

    //--- factor of change metrics
    data[dataFOCCur]       = (atan(pip(indTLineBuffer[0]-indTLineBuffer[inpPeriod-1])/inpPeriod)*180)/M_PI;
    data[dataFOCTrendDir]  = dir(indTLineBuffer[0]-indTLineBuffer[inpPeriod-1]);    

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

    if (fabs(NormalizeDouble(data[dataFOCCur],2)) >= fabs(NormalizeDouble(data[dataFOCMax],2)))
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

      data[dataFOCMax]       = fmax(fabs(NormalizeDouble(data[dataFOCCur],2)),fabs(NormalizeDouble(data[dataFOCMax],2)))*data[dataFOCTrendDir];
    }

    data[dataFOCDev]         = fabs(NormalizeDouble(data[dataFOCMax],1))-fabs(NormalizeDouble(data[dataFOCCur],1));
    data[dataFOCPivDev]      = pip(Close[0]-data[dataFOCPiv]);
    data[dataFOCPivDevMin]   = NormalizeDouble(fmin(data[dataFOCPivDevMin],data[dataFOCPivDev]),1);
    data[dataFOCPivDevMax]   = NormalizeDouble(fmax(data[dataFOCPivDevMax],data[dataFOCPivDev]),1);
    
    if (fabs(NormalizeDouble(data[dataFOCMax],1))>0.5)
      data[dataFOCPoints]    = NormalizeDouble((fabs(data[dataFOCPivDevMin])+data[dataFOCPivDevMax])/NormalizeDouble(data[dataFOCMax],1),1);
    else
      data[dataFOCPoints]    = NormalizeDouble((fabs(data[dataFOCPivDevMin])+data[dataFOCPivDevMax])/(0.5)*dir(data[dataFOCMax]),1);
        
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
    data[dataTickCur]      = pipHistory[0];
    data[dataTickCnt]      = 0.00;
    data[dataTickDir]      = dir(pipHistory[0]-pipHistory[1]);
    data[dataPLine]        = indPLineBuffer[0];
    data[dataPLineDir]     = dir((int)dataLast[dataPLineDir],indPLineBuffer);
    data[dataPLineMADir]   = dir(indPLineBuffer[0]-data[dataRngMA]);

    indPipBuffer[inpPeriod]   = 0.00;
    indTLineBuffer[inpPeriod] = 0.00;
  }
  
//+------------------------------------------------------------------+
//| CalculateFrequency - Computes the oscillation frequency measures |
//+------------------------------------------------------------------+
void CalculateFrequency()
  {
    double aggNeg    = 0.00;
    double aggPos    = 0.00;
    
    int    aggPosCnt = 0;
    int    aggNegCnt = 0;
    
    if (data[dataFOCTrendDir]!=dataLast[dataFOCTrendDir])
    {
      if (data[dataFOCTrendDir]!=DIR_NONE)
      {        
        if (data[dataFOCTrendDir] == DIR_UP)
          data[dataAmpCurLow]  = dataLast[dataFOCMax];

        if (data[dataFOCTrendDir] == DIR_DOWN)
          data[dataAmpCurHigh] = dataLast[dataFOCMax];

        for (int idx=inpPeriod-1;idx>=0;idx--)
        {          
          if (fabs(NormalizeDouble(frqHistory[idx],1))>0.00)
          {
            if (frqHistory[idx]>0.00)
            {
              aggPos +=  frqHistory[idx];
              aggPosCnt++;
            }

            if (frqHistory[idx]<0.00)
            {
              aggNeg +=  frqHistory[idx];
              aggNegCnt++;
            }
          }

          frqHistory[idx+1] = frqHistory[idx];
        }

        if (aggNegCnt>0 && aggPosCnt>0)
        {
          data[dataAmpMean]       = (NormalizeDouble(aggPos,2)/aggPosCnt)+(fabs(NormalizeDouble(aggNeg,2))/aggNegCnt);
          data[dataAmpMeanMid]    = NormalizeDouble(data[dataAmpMean],2)/2;
          data[dataAmpMeanPos]    = NormalizeDouble(aggPos,2)/aggPosCnt;
          data[dataAmpMeanNeg]    = NormalizeDouble(aggNeg,2)/aggNegCnt;
          data[dataAmpMeanDir]    = dir(data[dataAmpMeanPos]+data[dataAmpMeanNeg]);
        }
      }      
    } 

    frqHistory[0]           = data[dataFOCMax];
    
    if (data[dataFOCTrendDir] == DIR_UP)
      data[dataAmpCurHigh]  = fmax(NormalizeDouble(data[dataFOCMax],2),NormalizeDouble(data[dataAmpCurHigh],2));


    if (data[dataFOCTrendDir] == DIR_DOWN)
      data[dataAmpCurLow]   = fmin(NormalizeDouble(data[dataFOCMax],2),NormalizeDouble(data[dataAmpCurLow],2));

    if (fabs(frqHistory[2])>0.00)
    {
      data[dataAmpCur]     = fabs(NormalizeDouble(data[dataFOCCur],2))+fabs(NormalizeDouble(frqHistory[1],2));
      data[dataAmpCurMax]  = NormalizeDouble(data[dataAmpCurHigh],2)+fabs(NormalizeDouble(data[dataAmpCurLow],2));
      data[dataAmpCurMid]  = NormalizeDouble(data[dataAmpCurMax]/2,2);
      
      if (data[dataAmpCur] == 0.00)
        data[dataAmpCurPct] = 0.00;
      else      
        data[dataAmpCurPct] = ((NormalizeDouble(data[dataAmpCurMax],2)/NormalizeDouble(data[dataAmpMean],2))*100)*dir(data[dataAmpCurDir]);
    }
    
    //--- Compute current wave direction
    if (frqHistory[0]>data[dataAmpMeanMid])
    {
      data[dataAmpCurDir]      = DIR_UP;

      if (fabs(frqHistory[1])>data[dataAmpMeanMid] && frqHistory[1]<0.00)
      {
        data[dataAmpCurDir]    = DIR_RALLY;

        if (frqHistory[0]>fabs(frqHistory[1]))
          data[dataAmpCurDir]  = DIR_LREV;
      }
    }
    else
    if (fabs(frqHistory[0])>data[dataAmpMeanMid])
    {
      data[dataAmpCurDir]      = DIR_DOWN;

      if (fabs(frqHistory[1])>data[dataAmpMeanMid] && frqHistory[1]>0.00)
      {
        data[dataAmpCurDir]    = DIR_PULLBACK;

        if (fabs(frqHistory[0])>frqHistory[1])
          data[dataAmpCurDir]  = DIR_SREV;
      }
    }
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen - repaints screen visuals                          |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    if (pipIndex == 0)
    {      
      SetLevelValue(1,data[dataRngMid]);
      
      UpdateLabel("lrFOCCur:"+pipWinText,NegLPad(data[dataFOCCur],1),DirColor((int)data[dataFOCCurDir]),15);
      UpdateLabel("lrFOCMax:"+pipWinText,NegLPad(data[dataFOCMax],1),DirColor((int)data[dataFOCTrendDir]),15);
      UpdateLabel("lrFOCDev:"+pipWinText,DoubleToStr(data[dataFOCDev],1),DirColor((int)data[dataFOCCurDir]),8);
      UpdateLabel("lrFOCMin:"+pipWinText,NegLPad(data[dataFOCMin],1),DirColor((int)data[dataFOCTrendDir]),8);

      UpdateLine("lnFOCPivot",data[dataFOCPiv],STYLE_DASHDOTDOT,DirColor(dir(data[dataFOCPivDir])));
      UpdateLine("lnpipMA",data[dataFOCPiv],STYLE_DASHDOTDOT,DirColor(dir(data[dataFOCPivDir])));
      
      UpdateLabel("lrFOCPivDev:"+pipWinText,NegLPad(data[dataFOCPivDev],1),DirColor(dir(data[dataFOCPivDev])),15);
      UpdateDirection("lrFOCPivDir:"+pipWinText,(int)data[dataFOCPivDir],DirColor((int)data[dataFOCPivDir]),20);
      UpdateLabel("lrFOCPivDevMin:"+pipWinText,DoubleToStr(data[dataFOCPivDevMin],1),DirColor(dir(data[dataFOCPivDevMin])));
      UpdateLabel("lrFOCPivDevMax:"+pipWinText,DoubleToStr(data[dataFOCPivDevMax],1),DirColor(dir(data[dataFOCPivDevMax])));
      UpdateLabel("lrFOCPivPrice:"+pipWinText,DoubleToStr(data[dataFOCPiv],Digits),DirColor(dir(data[dataFOCPivDev])));
      UpdateLabel("lrFOCTick:"+pipWinText,LPad(DoubleToString(data[dataTickCnt],0)," ",2),DirColor((int)data[dataTickDir]),15);
      UpdateLabel("lrFOCPoints:"+pipWinText,NegLPad(data[dataFOCPoints],1),DirColor((int)data[dataFOCTrendDir]));

      UpdateDirection("lrFOCDir:"+pipWinText,(int)data[dataFOCCurDir],DirColor((int)data[dataFOCCurDir]),12);
      UpdateDirection("lrFOCTrend:"+pipWinText,(int)data[dataFOCTrendDir],DirColor((int)data[dataFOCTrendDir]),12);
      //--- update range lines
      if (data[dataRngDir] == DIR_UP)
      {
        if (data[dataRngStr]==STR_LONG_MAX)
          UpdateLine("rngHigh",data[dataRngHigh],STYLE_SOLID,DirColor((int)data[dataRngHighDir],clrGoldenrod,clrFireBrick));
        else
          UpdateLine("rngHigh",data[dataRngHigh],STYLE_SOLID,DirColor((int)data[dataRngHighDir],clrForestGreen,clrFireBrick));

        UpdateLine("rngLow",data[dataRngLow],STYLE_DOT,DirColor((int)data[dataRngLowDir],clrForestGreen,clrFireBrick));
      }
      else
      {
        UpdateLine("rngHigh",data[dataRngHigh],STYLE_DOT,DirColor((int)data[dataRngHighDir],clrForestGreen,clrFireBrick));

        if (data[dataRngStr]==STR_SHORT_MAX)
          UpdateLine("rngLow",data[dataRngLow],STYLE_SOLID,DirColor((int)data[dataRngLowDir],clrForestGreen,clrGoldenrod));
        else
          UpdateLine("rngLow",data[dataRngLow],STYLE_SOLID,DirColor((int)data[dataRngLowDir],clrForestGreen,clrFireBrick));
      }

      UpdateLine("rngMid",data[dataRngMid],STYLE_DOT,DirColor((int)data[dataRngMidDir],clrForestGreen,clrFireBrick));
      
      //--- update amplitude/CTR/ETR measures
      UpdateLabel("lrAmpCurPct:"+pipWinText,NegLPad(data[dataAmpCurPct],1)+"%",DirColor((int)data[dataAmpCurDir]),12);      
      UpdateLabel("lrRngSize:"+pipWinText,DoubleToStr(data[dataRngSize],1),DirColor((int)data[dataRngDir]),12);
      UpdateLabel("lrETRRetrace:"+pipWinText,DoubleToStr(data[dataETRRetrace],0)+"%",DirColor((int)data[dataETRDir]),12);

      UpdateDirection("lrRngDir:"+pipWinText,(int)data[dataRngDir],DirColor((int)data[dataRngDir]),12);
      UpdateDirection("lrETRDir:"+pipWinText,(int)data[dataETRDir],DirColor((int)data[dataETRDir]),12);

      UpdateLabel("lrAmpCurDirTxt:"+pipWinText,StringSubstr(DirText((int)data[dataAmpCurDir]),0,8),DirColor((int)data[dataAmpCurDir]));
      UpdateDirection("lrAmpCurDir:"+pipWinText,(int)data[dataAmpCurDir],DirColor((int)data[dataAmpCurDir]),20);
      
      if (data[dataETRContFact]<0.00)
        UpdateLabel("lrRngStrTxt:"+pipWinText,StrengthText((int)data[dataRngStr])+" CONTRACTION",DirColor(dir(data[dataRngStr])));
      else
        UpdateLabel("lrRngStrTxt:"+pipWinText,StrengthText((int)data[dataRngStr])+" EXPANSION",DirColor(dir(data[dataRngStr])));
            
      UpdateLabel("lrAmpMean:"+pipWinText,DoubleToStr(data[dataAmpMean],2),DirColor((int)data[dataAmpCurDir]));
      UpdateLabel("lrAmpCur:"+pipWinText,DoubleToStr(data[dataAmpCur],2),DirColor((int)data[dataAmpCurDir]));
      UpdateLabel("lrAmpCurMax:"+pipWinText,DoubleToStr(data[dataAmpCurMax],2),DirColor((int)data[dataAmpCurDir]));

      UpdateLabel("lrRngExpPrice:"+pipWinText,DoubleToStr(data[dataRngExpPrice],Digits),DirColor((int)data[dataRngDir]));

      if (NormalizeDouble(data[dataRngContFact],2)<0.00)
      {
        UpdateLabel("lrRngContFact:"+pipWinText,DoubleToStr(data[dataRngContFact],1),DirColor((int)data[dataRngDir]));
        UpdateLabel("lrCTRExpCont:"+pipWinText,"Cont",clrLightGray);
      }
      else
      {
        UpdateLabel("lrRngContFact:"+pipWinText,DoubleToStr(pip(Close[0]-data[dataRngExpPrice]),1),DirColor((int)data[dataRngDir]));
        UpdateLabel("lrCTRExpCont:"+pipWinText,"Exp",clrLightGray);
      }
      
      if (NormalizeDouble(data[dataETRContFact],2)<0.00)
      {
        UpdateLabel("lrETRContFact:"+pipWinText,DoubleToStr(data[dataETRContFact],1),DirColor((int)data[dataETRDir]));
        UpdateLabel("lrETRExpCont:"+pipWinText,"Cont",clrLightGray);
      }
      else
      {
        UpdateLabel("lrETRContFact:"+pipWinText,DoubleToStr(pip(Close[0]-data[dataRngExpPrice]),1),DirColor((int)data[dataETRDir]));
        UpdateLabel("lrETRExpCont:"+pipWinText,"Exp",clrLightGray);
      }

      if (data[dataETRDir]==DIR_UP)
      {
        UpdateLine("etrHigh",data[dataETRHigh],STYLE_SOLID,clrForestGreen);
        UpdateLine("etrLow",data[dataETRLow],STYLE_DOT,clrForestGreen);
      }
      else
      {
        UpdateLine("etrHigh",data[dataETRHigh],STYLE_DOT,clrFireBrick);
        UpdateLine("etrLow",data[dataETRLow],STYLE_SOLID,clrFireBrick);
      }

      //--- update price balloons
      ObjectSet("pipPivot",OBJPROP_TIME1,Time[0]);
      ObjectSet("pipPivot",OBJPROP_PRICE1,data[dataFOCPiv]);
        
      ObjectSet("pipMA",OBJPROP_TIME1,Time[0]);
      ObjectSet("pipMA",OBJPROP_PRICE1,data[dataRngMA]);
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
        //--- FOC labels
        UpdateLabel("lrFOC0:"+pipWinText,"Factor of Change",clrGoldenrod);
        
        NewLabel("lrFOC1:"+pipWinText,"Current",10,22+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC2:"+pipWinText,"Max",72,22+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC3:"+pipWinText,"Pivot",165,11+pipWinOffset,clrGoldenrod,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC4:"+pipWinText,"Dev",138,22+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC5:"+pipWinText,"Tick",232,22+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCCur:"+pipWinText,"",5,32+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCMax:"+pipWinText,"",60,32+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivDev:"+pipWinText,"",120,32+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivDir:"+pipWinText,"",192,27+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCTick:"+pipWinText,"",230,32+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);

        NewLabel("lrFOCDev:"+pipWinText,"",28,53+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCMin:"+pipWinText,"",80,53+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCDir:"+pipWinText,"",2,53+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCTrend:"+pipWinText,"",57,53+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivDevMin:"+pipWinText,"",112,53+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivDevMax:"+pipWinText,"",150,53+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPivPrice:"+pipWinText,"",182,53+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOCPoints:"+pipWinText,"",232,54+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);

        NewLabel("lrFOC6:"+pipWinText,"Dev",20,65+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC7:"+pipWinText,"Trend",67,65+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC8:"+pipWinText,"Min",120,65+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC9:"+pipWinText,"Max",152,65+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC10:"+pipWinText,"Price",192,65+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrFOC11:"+pipWinText,"Points",230,65+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);
    

        //--- Amplitude/Trade Range labels
        NewLabel("lrAmp1:"+pipWinText,"Amplitude",38,79,clrGoldenrod,SCREEN_UL,pipWinIdx);
        NewLabel("lrTR1:"+pipWinText,"Cur",127,79,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrTR2:"+pipWinText,"Trade Range",154,79,clrGoldenrod,SCREEN_UL,pipWinIdx);
        NewLabel("lrTR3:"+pipWinText,"Eff",228,79,clrLightGray,SCREEN_UL,pipWinIdx);

        NewLabel("lrAmpCurPct:"+pipWinText,"",8,90+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrRngSize:"+pipWinText,"",115,90,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrRngDir:"+pipWinText,"",160,93,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrETRRetrace:"+pipWinText,"",190,90,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrETRDir:"+pipWinText,"",240,93,clrLightGray,SCREEN_UL,pipWinIdx);

        NewLabel("lrAmpCurDirTxt:"+pipWinText,"",23,108+pipWinOffset,clrNONE,SCREEN_UL,pipWinIdx);
        NewLabel("lrAmpCurDir:"+pipWinText,"",78,92,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrRngStrTxt:"+pipWinText,"",120,108,clrLightGray,SCREEN_UL,pipWinIdx);

        NewLabel("lrAmpMean:"+pipWinText,"",10,119,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrAmpCur:"+pipWinText,"",45,119,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrAmpCurMax:"+pipWinText,"",78,119,clrLightGray,SCREEN_UL,pipWinIdx);

        NewLabel("lrRngContFact:"+pipWinText,"",128,119,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrRngExpPrice:"+pipWinText,"",165,119,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrETRContFact:"+pipWinText,"",223,119,clrLightGray,SCREEN_UL,pipWinIdx);
        
        NewLabel("lrAmp2:"+pipWinText,"Mean",7,130,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrAmp3:"+pipWinText,"Cur",49,130,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrAmp4:"+pipWinText,"Max",82,130,clrLightGray,SCREEN_UL,pipWinIdx);

        NewLabel("lrCTRExpCont:"+pipWinText,"",130,130,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrTR5:"+pipWinText,"Price",175,130,clrLightGray,SCREEN_UL,pipWinIdx);
        NewLabel("lrETRExpCont:"+pipWinText,"",225,130,clrLightGray,SCREEN_UL,pipWinIdx);

        ObjectCreate("pipPivot",OBJ_ARROW,0,0,0);
        ObjectSet("pipPivot", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);
        
        ObjectCreate("pipMA",OBJ_ARROW,1,0,0);
        ObjectSet("pipMA", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);

        NewLine("lnFOCPivot",0.00,STYLE_DASHDOT,clrLightGray,1);
        NewLine("lnpipMA",0.00,STYLE_DASHDOT,clrLightGray,1);

        NewLine("rngLow");
        NewLine("rngMid");
        NewLine("rngHigh");
        NewLine("etrHigh");
        NewLine("etrLow");
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
        regrCalcPoly(indPipBuffer,indPLineBuffer,inpPeriod-1,inpDegree);
        regrCalcTrendLine(inpPeriod,pipHistory,indTLineBuffer);
        CalculateMeasures();
        CalculateFrequency();
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

    ArrayResize(pipHistory,inpPeriod+1);
    ArrayInitialize(pipHistory,      0.00);
    
    ArrayResize(frqHistory,inpPeriod+1);
    ArrayInitialize(frqHistory,      0.00);

    IndicatorShortName("pipMA-v4:"+DoubleToStr(pipWinIdx,0));
        
    if (pipWinIdx == 0)
      pipWinOffset = 20;
        
    NewLabel("lrFOC0:"+pipWinText,"",15,12+pipWinOffset,clrLightGray,SCREEN_UL,pipWinIdx);

    return(INIT_SUCCEEDED);
  }