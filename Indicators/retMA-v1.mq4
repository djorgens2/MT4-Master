//+------------------------------------------------------------------+
//|                                                     retMA-v1.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3

//--- plot indCur
#property indicator_label1  "indRetMACur"
#property indicator_type1   DRAW_NONE

//--- plot indSTerm
#property indicator_label2  "indRetMASTerm"
#property indicator_type2   DRAW_NONE

//--- plot indLTerm
#property indicator_label3  "indRetMALTerm"
#property indicator_type3   DRAW_SECTION
#property indicator_color3  clrFireBrick
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- buffer dataMeasure
#property indicator_label4  "dataRetMAMeasure"
#property indicator_type4   DRAW_NONE

//--- includes
#include <std_utility.mqh>
#include <pipMA-v1.mqh>
#include <retMA-v1.mqh>

//--- indicator buffers
double         indCurBuffer[];
double         indSTBuffer[];
double         indLTBuffer[];
double         dataMeasureBuffer[];

//--- operational vars
bool           isComputed  = false;

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

    //--- return value of prev_calculated for next call
        LoadHistory(inpRetMALT,indLTBuffer);
    return(rates_total);
  }

//+------------------------------------------------------------------+
//| LoadHistory - loads the hisorical data into the buffers          |
//+------------------------------------------------------------------+
void LoadHistory(int retMATerm, double &retMABuffer[])
  {
    int     idx              = 0;
    int     curMADir         = DIR_NONE;
    int     lastMADir        = DIR_NONE;
    int     curRetDir        = DIR_NONE;
    int     lastRetDir       = DIR_NONE;
    int     lastBufIdx       = 0;

    double  minPrice         = Low[Bars-1];
    double  maxPrice         = High[Bars-1];
    double  retPrice         = Close[Bars-1];

    int     minPriceIdx      = Bars-1;
    int     maxPriceIdx      = Bars-1;
    int     retPriceIdx      = Bars-1;

    double  ma[3];
    
    string  maTime;
    
    for (idx=Bars-1; idx>0; idx--)
    {
      maTime = TimeToStr(Time[idx]);
      
      if (fmin(minPrice,Low[idx]) == Low[idx])
      {
        lastBufIdx           = minPriceIdx;
        
        retPrice             = High[idx];
        retPriceIdx          = idx;

        minPrice             = Low[idx];
        minPriceIdx          = idx;
      }
                 
      if (fmax(maxPrice,High[idx]) == High[idx])
      {
        lastBufIdx           = maxPriceIdx;

        retPrice             = Low[idx];
        retPriceIdx          = idx;
        
        maxPrice             = High[idx];
        maxPriceIdx          = idx;
      }
      
      if (curRetDir == DIR_UP)
        if (fmin(retPrice,Low[idx]) == retPrice)
        {
          retPrice           = Low[idx];
          retPriceIdx        = idx;
        }

      if (curRetDir == DIR_DOWN)
        if (fmax(retPrice,High[idx]) == retPrice)
        {
          retPrice           = High[idx];
          retPriceIdx        = idx;
        }
      
      if (idx > Bars-retMATerm-3)
      {
        //--- we only have bar data at this point, so retDir is computed from bar values
        if (minPrice == Low[idx])
          curRetDir          = DIR_DOWN;

        if (maxPrice == High[idx])
          curRetDir          = DIR_UP;
      }
      else
      {
      if (Low[idx]>1.3474)
       int i=0;
       
        ArrayInitialize(ma,0.00);
        
        for (int maIdx=idx; maIdx<idx+3; maIdx++)
          ma[maIdx-idx]      = iCustom(Symbol(),Period(),"Custom Moving Averages", retMATerm, 0, MODE_SMA, 0, maIdx);

        curMADir             = dir(sigStrength(ma[0],ma[1],ma[2]));
 
        if (idx == Bars-retMATerm-3)
        {
          retMABuffer[minPriceIdx]     = Low[minPriceIdx];
          retMABuffer[maxPriceIdx]     = High[maxPriceIdx];
          
          lastMADir          = dir(minPriceIdx-maxPriceIdx);
          lastBufIdx         = fmin(minPriceIdx,maxPriceIdx);
        }
        
        if (lastMADir == curMADir)
        {
          if (maxPrice == High[idx])
          {
            retMABuffer[lastBufIdx]    = 0.00;
            retMABuffer[idx] = maxPrice;
          }
          
          if (minPrice == Low[idx])
          {
            retMABuffer[lastBufIdx]    = 0.00;
            retMABuffer[idx] = minPrice;
          }

        }
        else
        {
          if (curMADir == DIR_UP)
          {
            retMABuffer[retPriceIdx]   = retPrice;

            curRetDir        = DIR_UP;
          }
        
          if (curMADir == DIR_DOWN)
          {
            retMABuffer[retPriceIdx]   = retPrice;

            curRetDir        = DIR_DOWN;
          }
        }
      }      
    }
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- indicator buffers mapping
    SetIndexBuffer(RET_MA,          indCurBuffer);
    SetIndexBuffer(RET_MA_STERM,    indSTBuffer);
    SetIndexBuffer(RET_MA_LTERM,    indLTBuffer);
    SetIndexBuffer(RET_MA_MEASURES, dataMeasureBuffer);

    SetIndexEmptyValue(RET_MA,            0.00);
    SetIndexEmptyValue(RET_MA_STERM,      0.00);
    SetIndexEmptyValue(RET_MA_LTERM,      0.00);
    SetIndexEmptyValue(RET_MA_MEASURES,   0.00);
    
    ArrayInitialize(indCurBuffer,         0.00);
    ArrayInitialize(indSTBuffer,          0.00);
    ArrayInitialize(indLTBuffer,          0.00);
    ArrayInitialize(dataMeasureBuffer,    0.00);

    Print("The time is: "+TimeToStr(Time[Bars-1]));
    
    return(INIT_SUCCEEDED);
  }
