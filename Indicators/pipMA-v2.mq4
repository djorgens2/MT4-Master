//+------------------------------------------------------------------+
//|                                                     pipMA-v2.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   5

//--- plot indCur
#property indicator_label1  "indCur"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrFireBrick
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot indSTerm
#property indicator_label2  "indSTerm"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGoldenrod
#property indicator_width2  1

//--- plot indLTerm
#property indicator_label3  "indLTerm"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- plot indRegrSTerm
#property indicator_label4  "indRegrSTerm"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrFireBrick
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- plot indRegrLTerm
#property indicator_label5  "indRegrLTerm"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrYellow
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

//--- buffer dataMeasure
#property indicator_label6  "dataMeasure"
#property indicator_type6   DRAW_NONE


//--- includes
#include <std_utility.mqh>
#include <pipMA-v2.mqh>


//--- indicator buffers
double         indCurBuffer[];
double         indSTBuffer[];
double         indLTBuffer[];
double         indRegrSTBuffer[];
double         indRegrLTBuffer[];
double         dataMeasureBuffer[];

double         pipMAHistory[10000];

int            histIndex     = 0;
int            termIndex     = 0;


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int CalculateRegression(int SourceBufferId, double &SourceBuffer[], double &TargetBuffer[], int Range)
  {
    double ai[10,10],b[10],x[10],sx[20];
    double sum; 
    double qq,mm,tt;

    int    ii,jj,kk,ll,nn;
    int    mi,n;

    if (Bars < Range) return(SIG_NONE);
    
    sx[1]  = Range+1;
    nn     = inpRegrDeg+1;

    SetIndexDrawBegin(SourceBufferId, Bars-Range-1);
   
  //----------------------sx-------------------------------------------------------------------
  for(mi=1;mi<=nn*2-2;mi++)
  {
    sum=0;
    for(n=0;n<=Range; n++)
    {
       sum+=MathPow(n ,mi);
    }
    sx[mi+1]=sum;
  }  
  
  //----------------------syx-----------
  ArrayInitialize(b,0.00);
  for(mi=1;mi<=nn;mi++)
  {
    sum=0.00000;
    for(n=0;n<=Range;n++)
    {
       if(mi==1) 
         sum += SourceBuffer[n];
       else 
         sum += SourceBuffer[n]*MathPow(n, mi-1);
    }
    b[mi]=sum;
  } 
  
  //===============Matrix=======================================================================================================
  ArrayInitialize(ai,0.00);
  for(jj=1;jj<=nn;jj++)
  {
    for(ii=1; ii<=nn; ii++)
    {
       kk=ii+jj-1;
       ai[ii,jj]=sx[kk];
    }
  }  

  //===============Gauss========================================================================================================
  for(kk=1; kk<=nn-1; kk++)
  {
    ll=0;
    mm=0;
    for(ii=kk; ii<=nn; ii++)
    {
       if(MathAbs(ai[ii,kk])>mm)
       {
          mm=MathAbs(ai[ii,kk]);
          ll=ii;
       }
    }
    if(ll==0) return(0);   
    if (ll!=kk)
    {
       for(jj=1; jj<=nn; jj++)
       {
          tt=ai[kk,jj];
          ai[kk,jj]=ai[ll,jj];
          ai[ll,jj]=tt;
       }
       tt=b[kk];
       b[kk]=b[ll];
       b[ll]=tt;
    }  
    for(ii=kk+1;ii<=nn;ii++)
    {
       qq=ai[ii,kk]/ai[kk,kk];
       for(jj=1;jj<=nn;jj++)
       {
          if(jj==kk) ai[ii,jj]=0;
          else ai[ii,jj]=ai[ii,jj]-qq*ai[kk,jj];
       }
       b[ii]=b[ii]-qq*b[kk];
    }
  }  
  x[nn]=b[nn]/ai[nn,nn];
  for(ii=nn-1;ii>=1;ii--)
  {
    tt=0;
    for(jj=1;jj<=nn-ii;jj++)
    {
       tt=tt+ai[ii,ii+jj]*x[ii+jj];
       x[ii]=(1/ai[ii,ii])*(b[ii]-tt);
    }
  } 
  //===========================================================================================================================

  for(n=0;n<=Range;n++)
  {
    sum=0;
    for(kk=1;kk<=inpRegrDeg;kk++)
    {
       sum+=x[kk+1]*MathPow(n,kk);
    }
    TargetBuffer[n]=x[1]+sum;
  } 

    return (sigStrength(TargetBuffer[0],TargetBuffer[1],TargetBuffer[2]));
  }

//+------------------------------------------------------------------+
//| WritePipMAHistory - Writes pipMA history data out on shutdown    |
//+------------------------------------------------------------------+
void WritePipMAHistory()
  {
    ResetLastError();

    int    filehandle=FileOpen("pipMA_History_"+Symbol()+"_"+EnumToString(ENUM_TIMEFRAMES(Period()))+".csv",FILE_READ|FILE_WRITE|FILE_CSV);
    string newLine = TimeToStr(Time[0])+";"+Symbol();

    if(filehandle!=INVALID_HANDLE)
    {
      FileSeek(filehandle,0,SEEK_END);
     
      for (int idx=0;idx<inpMAPeriod;idx++)
        newLine   += ";"+DoubleToStr(pipMAHistory[idx],Digits);
       
      FileWrite(filehandle,newLine);
      FileFlush(filehandle);
      FileClose(filehandle);
    }
    else Print("Operation FileOpen failed, error ",GetLastError());
  }  

//+------------------------------------------------------------------+
//| WriteExitMeasures - Writes pipMA data out on shutdown            |
//+------------------------------------------------------------------+
void WriteExitMeasures()
  {
//   if (inpFileData)
   {
     ResetLastError();

     int    filehandle=FileOpen("pipMA_Exit_"+Symbol()+"_"+EnumToString(ENUM_TIMEFRAMES(Period()))+".csv",FILE_READ|FILE_WRITE|FILE_CSV);
     string newLine = TimeToStr(Time[0])+";"+Symbol();

     if(filehandle!=INVALID_HANDLE)
     {     
       for (int idx=inpRegrRng+1;idx>0;idx--)
         FileWrite(filehandle,TimeToStr(Time[idx-1])+";"+
                              DoubleToStr(Open[idx-1],Digits)+";"+
                              DoubleToStr(High[idx-1],Digits)+";"+
                              DoubleToStr(Low[idx-1],Digits)+";"+
                              DoubleToStr(Close[idx-1],Digits)+";"+
                              DoubleToStr(indCurBuffer[idx-1],Digits)+";"+
                              DoubleToStr(indSTBuffer[idx-1],Digits)+";"+
                              DoubleToStr(indLTBuffer[idx-1],Digits)+";"+
                              DoubleToStr(indRegrSTBuffer[idx-1],Digits)+";"+
                              DoubleToStr(indRegrLTBuffer[idx-1],Digits)
                  );
       
       FileFlush(filehandle);
       FileClose(filehandle);
     }
     else Print("Operation FileOpen failed, error ",GetLastError());
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
  
   //--- local vars
   string txt                = "";
   double agg                = 0.00;
   
   //--- hold last values
   ArrayCopy(pipMALast,pipMA);
   
   //--- test for full pip changes
   if (fabs(pip(pipMAHistory[histIndex]-Close[0]))>=1.0)
   {   
     if (histIndex == inpMAPeriod)
       for (int idx=0; idx<histIndex; idx++)
         pipMAHistory[idx]   = pipMAHistory[idx+1];
     else
     {
       histIndex++;
       pipMA[pipMAHistIndex] = histIndex;
     }
 
     pipMAHistory[histIndex] = Close[0];
     pipMA[pipMALow]         = Close[0];
     pipMA[pipMAHigh]        = Close[0];
       
     for (int idx=0; idx<histIndex; idx++)
     {         
       agg                  += pipMAHistory[idx];
       
       pipMA[pipMALow]       = fmin(pipMAHistory[idx],pipMA[pipMALow]);
       pipMA[pipMAHigh]      = fmax(pipMAHistory[idx],pipMA[pipMAHigh]);
     }
     
     pipMA[pipMACur]         = agg / histIndex;
     pipMA[pipMAMid]         = (pipMA[pipMAHigh]+pipMA[pipMALow])/2;
     
     if (pipMA[pipMAHigh] != pipMALast[pipMAHigh])
       pipMA[pipMAHighDir]   = dir(pipMA[pipMAHigh]-pipMALast[pipMAHigh]);
     
     if (pipMA[pipMAMid]  != pipMALast[pipMAMid])
       pipMA[pipMAMidDir]    = dir(pipMA[pipMAMid]-pipMALast[pipMAMid]);

     if (pipMA[pipMALow]  != pipMALast[pipMALow])
       pipMA[pipMALowDir]    = dir(pipMA[pipMALow]-pipMALast[pipMALow]);

     if (fabs(pipMA[pipMAMidDir]+pipMA[pipMALowDir]+pipMA[pipMAHighDir]) > 2)
       pipMA[pipMARngStr]    = 2*dir(pipMA[pipMAMidDir]+pipMA[pipMALowDir]+pipMA[pipMAHighDir]);
     else
       pipMA[pipMARngStr]    = pipMA[pipMAMidDir]+pipMA[pipMALowDir]+pipMA[pipMAHighDir];

     pipMA[pipMARange]       = pip(pipMA[pipMAHigh]-pipMA[pipMALow]);
     pipMA[pipMARngDir]      = dir(pipMA[pipMAMidDir]+pipMA[pipMALowDir]+pipMA[pipMAHighDir]);
     pipMA[pipMAGapCur]      = pip(pipMA[pipMACur]-pipMA[pipMAMid]);
     pipMA[pipMADev]         = pip(Close[0]-pipMA[pipMAMid]);

     if (dir(pipMALast[pipMADev]) == dir(pipMA[pipMADev]))
       pipMA[pipMADevMax]    = fmax(fabs(pipMA[pipMADevMax]),fabs(pipMA[pipMADev]))*dir(pipMALast[pipMADev]);
     else
       pipMA[pipMADevMax]    = pipMA[pipMADev];
   }
   
   //--- compute ST/LT values
   
   if (rates_total != prev_calculated)
   {
     termIndex++;     
     pipMA[pipMARates]       = termIndex;

//     WritePipMA(TimeToStr(Time[0]));
   }

   agg                       = pipMA[pipMACur];
   
   for (int idx=1; idx<fmin(termIndex,inpMALTerm); idx++)
   {
     agg                    += indCurBuffer[idx];
       
     if (idx==inpMASTerm-1)
     {
       pipMA[pipMAST]        = agg / inpMASTerm;
       pipMA[pipMAGapST]     = pip(pipMA[pipMAMid]-pipMA[pipMAST]);
         
       if (dir(pipMALast[pipMAGapST]) == dir(pipMA[pipMAGapST]))
         pipMA[pipMAMaxGapST]= fmax(fabs(pipMA[pipMAMaxGapST]),fabs(pipMA[pipMAGapST]))*dir(pipMALast[pipMAGapST]);
       else
         pipMA[pipMAMaxGapST]= pipMA[pipMAGapST];

       if (termIndex-inpMASTerm>5)
       {
         indCurBuffer[0]           = pipMA[pipMACur];
         pipMA[pipMARegrStrST]     = CalculateRegression(PIP_MA_REGR_STERM, indCurBuffer, indRegrSTBuffer, fmin(termIndex-inpMASTerm,inpRegrRng));
         pipMA[pipMARegrST]        = indRegrSTBuffer[0];
       }
     }

     if (idx==inpMALTerm-1)
     {
       pipMA[pipMALT]        = agg / inpMALTerm;
       pipMA[pipMAGapLT]     = pip(pipMA[pipMAMid]-pipMA[pipMALT]);
         
       if (dir(pipMALast[pipMALT]) == dir(pipMA[pipMAGapLT]))
         pipMA[pipMAMaxGapLT]= fmax(fabs(pipMA[pipMAMaxGapLT]),fabs(pipMA[pipMAGapLT]))*dir(pipMALast[pipMALT]);
       else
         pipMA[pipMAMaxGapLT]= pipMA[pipMAGapLT];

       if (termIndex-inpMALTerm>5)
       {
         indLTBuffer[0]            = pipMA[pipMALT];
         pipMA[pipMARegrStrLT]     = CalculateRegression(PIP_MA_REGR_LTERM, indLTBuffer, indRegrLTBuffer, fmin(termIndex-inpMALTerm,inpRegrRng));
         pipMA[pipMARegrLT]        = indRegrLTBuffer[0];
         pipMA[pipMARegrGap]       = pip(pipMA[pipMARegrST]-pipMA[pipMARegrLT]);
         
         if (dir(pipMALast[pipMARegrGap]) == dir(pipMA[pipMARegrGap]))
           pipMA[pipMARegrGapMax]  = fmax(fabs(pipMA[pipMARegrGap]),fabs(pipMA[pipMARegrGapMax]))*dir(pipMA[pipMARegrGap]);
         else
           pipMA[pipMARegrGapMax]  = pipMA[pipMARegrGap];
       }
     }
   }
   
   //--- compute current pipMA ind strength
   if (termIndex>3)
     pipMA[pipMAIndStrCur]   = sigStrength(pipMA[pipMACur],indCurBuffer[1], indCurBuffer[2]);

   //--- compute ST pipMA ind strength
   if (termIndex>inpMASTerm+3)
     pipMA[pipMAIndStrST]   = sigStrength(pipMA[pipMAST],indSTBuffer[1], indSTBuffer[2]);
     
   //--- compute long term strength       
   if (termIndex>inpMALTerm+3)
     pipMA[pipMAIndStrLT]    = sigStrength(pipMA[pipMALT],indLTBuffer[1],indLTBuffer[2]);
      
   //--- update indicator lines
   indCurBuffer[0]           = pipMA[pipMACur];
   
   if (pipMA[pipMAST]>0.00)
     indSTBuffer[0]          = pipMA[pipMAST];
   
   if (pipMA[pipMALT]>0.00)
     indLTBuffer[0]          = pipMA[pipMALT];

   if (pipMA[pipMACur]<pipMA[pipMAST])
     SetIndexStyle(PIP_MA_STERM, DRAW_LINE, STYLE_DOT, 1);
   else
     SetIndexStyle(PIP_MA_STERM, DRAW_LINE, STYLE_SOLID, 1);

   ObjectSet("indPipMAMid",  OBJPROP_PRICE1, pipMA[pipMAMid]);
   ObjectSet("indPipMAMid",  OBJPROP_COLOR,  dirColor((int)pipMA[pipMAMidDir],clrDarkGreen,clrMaroon));
    
   if (pipMALoaded())
   {    
     ObjectSet("indPipMAHigh", OBJPROP_PRICE1, pipMA[pipMAHigh]);
     ObjectSet("indPipMALow",  OBJPROP_PRICE1, pipMA[pipMALow]);
     
     ObjectSet("indPipMAHigh", OBJPROP_COLOR,  dirColor((int)pipMA[pipMAHighDir],clrDarkGreen,clrMaroon));
     ObjectSet("indPipMALow",  OBJPROP_COLOR,  dirColor((int)pipMA[pipMALowDir],clrDarkGreen,clrMaroon));

     UpdateLabel("pipMAData", "Pip MA: "+DoubleToStr(pipMA[pipMACur],Digits)+" "+
                                 "Rng: "+DoubleToStr(pipMA[pipMARange],1)+" "+
                                 "Dev: "+DoubleToStr(pipMA[pipMADev],1),
                  sigColor((int)pipMA[pipMARngStr]));
                  
     if (termIndex>3)
       UpdateLabel("pipMACur",proper(sigText((int)pipMA[pipMAIndStrCur]))+" "+DoubleToStr(pipMA[pipMAGapCur],1),sigColor((int)pipMA[pipMAIndStrCur]));
       
     if (termIndex>inpMASTerm+3)
       UpdateLabel("pipMAST",proper(sigText((int)pipMA[pipMAIndStrST]))+" "+DoubleToStr(pipMA[pipMAGapST],1),sigColor((int)pipMA[pipMAIndStrST]));
       
     if (termIndex>inpMALTerm+3)
       UpdateLabel("pipMALT",proper(sigText((int)pipMA[pipMAIndStrLT]))+" "+DoubleToStr(pipMA[pipMAGapLT],1),sigColor((int)pipMA[pipMAIndStrLT]));
       
     if (pipMA[pipMARegrLT]>0.00)
     {
       UpdateLabel("pipMARegrST",DoubleToStr(pipMA[pipMARegrST],Digits)+" "+DoubleToStr(pipMA[pipMARegrGap],1),sigColor((int)pipMA[pipMARegrStrST]));
       UpdateLabel("pipMARegrLT",DoubleToStr(pipMA[pipMARegrLT],Digits)+" "+DoubleToStr(pipMA[pipMARegrGapMax],1),sigColor((int)pipMA[pipMARegrStrLT]));
     }
   }
   else
   {
     txt = "Collecting Data ("+DoubleToStr(pipMA[pipMAHistIndex],0)+"/"+
                               IntegerToString(inpMAPeriod)+") "+
                               DoubleToStr((pipMA[pipMAHistIndex]/inpMAPeriod)*100,1)+"%";
                                    
     if ((pipMA[pipMAHistIndex]/inpMAPeriod)*100>90)
       UpdateLabel("pipMAData", txt, clrYellow);
     else 
       UpdateLabel("pipMAData", txt, clrWhite);
   }
   
   //--- update measures buffer
   for (int idx=0; idx<pipMAMeasures; idx++)
     dataMeasureBuffer[idx] = pipMA[idx];     
   
   //--- return value of prev_calculated for next call
   return(rates_total);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- map indicator buffers
    SetIndexBuffer(PIP_MA,            indCurBuffer);
    SetIndexBuffer(PIP_MA_STERM,      indSTBuffer);
    SetIndexBuffer(PIP_MA_LTERM,      indLTBuffer);
    SetIndexBuffer(PIP_MA_REGR_STERM, indRegrSTBuffer);
    SetIndexBuffer(PIP_MA_REGR_LTERM, indRegrLTBuffer);
    SetIndexBuffer(PIP_MA_MEASURES,   dataMeasureBuffer);
    
    SetIndexEmptyValue(PIP_MA,            0.00);
    SetIndexEmptyValue(PIP_MA_STERM,      0.00);
    SetIndexEmptyValue(PIP_MA_LTERM,      0.00);
    SetIndexEmptyValue(PIP_MA_REGR_STERM, 0.00);
    SetIndexEmptyValue(PIP_MA_REGR_LTERM, 0.00);
    SetIndexEmptyValue(PIP_MA_MEASURES,   0.00);
    
    ArrayInitialize(indCurBuffer,         0.00);
    ArrayInitialize(indSTBuffer,          0.00);
    ArrayInitialize(indLTBuffer,          0.00);
    ArrayInitialize(indRegrSTBuffer,      0.00);
    ArrayInitialize(indRegrLTBuffer,      0.00);
    ArrayInitialize(dataMeasureBuffer,    0.00);

   
    //--- initialize pipMAHistory
    ArrayInitialize(pipMA,0.00);
   
    pipMAHistory[0]          = Close[0];
    pipMA[pipMACur]          = Close[0];
    pipMA[pipMALow]          = Close[0];
    pipMA[pipMAHigh]         = Close[0];

    //--- setup screen objects
    NewLabel("pipMAData",   "Initializing", 5, 11, clrWhite, SCREEN_LR);
    NewLabel("pipMACur",    " ",            5, 22, clrWhite, SCREEN_LR);
    NewLabel("pipMAST",     " ",           85, 22, clrWhite, SCREEN_LR);
    NewLabel("pipMALT",     " ",          170, 22, clrWhite, SCREEN_LR);
    NewLabel("pipMARegr",   " ",            5, 33, clrWhite, SCREEN_LR);
    NewLabel("pipMARegrST", " ",           85, 33, clrWhite, SCREEN_LR);
    NewLabel("pipMARegrLT", " ",          170, 33, clrWhite, SCREEN_LR);
   
    ObjectCreate("indPipMAHigh", OBJ_HLINE,0,Time[0],0.00);
    ObjectCreate("indPipMALow",  OBJ_HLINE,0,Time[0],0.00);
    ObjectCreate("indPipMAMid",  OBJ_HLINE,0,Time[0],0.00);
      
    return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int Reason)
  {
    WritePipMAHistory();
    WriteExitMeasures();
  }