//+------------------------------------------------------------------+
//|                                                    regrMA-v1.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

#include <std_utility.mqh>

//--- input parameters
input int inpRegrDeg      = 6;    // Poly regression degree
input int inpRegrRng      = 500;  // Poly regression range
input int inpRegrST       = 3;    // Short term poly MA
input int inpRegrLT       = 24;   // Long term poly MA


//--- measures constants
#define   regrMeasures       22
#define   regrST              0  //--- Short term value
#define   regrLT              1  //--- Long term value
#define   regrDirST           2  //--- Short term direction (nose)
#define   regrDirLT           3  //--- Long term directon (nose)
#define   regrStr             4  //--- Strength of trend
#define   regrRetrLT          5  //--- Retrace of LT Poly nose to range in points (-50 to 50)
#define   regrRetrCur         6  //--- Current retrace of Price vs. LT Poly range in points (-50 to 50)
#define   regrTLine           7  //--- Current TLine Value
#define   regrTLineMin        8  //--- TLine retrace from max
#define   regrTLineMax        9  //--- Max TLine
#define   regrTLineDirST     10  //--- Advance/Decline TLine direction
#define   regrTLineDirLT     11  //--- Overall TLine direction
#define   regrTLineStr       12  //--- TLine strength
#define   regrPWane          13  //--- Price at which trend compression starts
#define   regrPTLWane        14  //--- Percent closure of the Poly ST to the TL
#define   regrLTWane         15  //--- Loss of LT momentum in pips from the LT nose
#define   regrSTWane         16  //--- Loss of ST momentum in pips from the ST nose
#define   regrGap            17  //--- Difference ST and LT
#define   regrGapMin         18  //--- Minimum difference of ST and LT
#define   regrGapMax         19  //--- Maximum difference of ST and LT
#define   regrGapPct         20  //--- Percent of gap compression
#define   regrGapCaution     21  //--- Gap caution level


//--- regression strength constants
#define   REGR_STRONG_LONG    4  //--- Strong Buy
#define   REGR_LONG           3  //--- Soft Buy, tp profit at red line
#define   REGR_SOFT_LONG      2  //--- Soft Buy, close, trend change
#define   REGR_CHG_SHORT      1  //--- Potential direction change to short
#define   REGR_NO_STRENGTH    0  //--- s/b not possible 
#define   REGR_CHG_LONG      -1  //--- Potential direction change to long
#define   REGR_SOFT_SHORT    -2  //--- Soft Sell, close, trend change
#define   REGR_SHORT         -3  //--- Soft Sell, tp profit at red line
#define   REGR_STRONG_SHORT  -4  //--- Strong Sell

//--- gap caution constants
#define   GAP_TREND_LONG      3  //  Confirmed new long trend
#define   GAP_STRONG_MAJOR    2  //  Potential trend change warning
#define   GAP_STRONG_MINOR    1  //  Potential market correction
#define   GAP_NO_CAUTION      0  //  No caution based on GAP
#define   GAP_SOFT_MINOR     -1  //  Potential market correction
#define   GAP_SOFT_MAJOR     -2  //  Potential trend change warning
#define   GAP_TREND_SHORT    -3  //  Confirmed new short trend

//--- operational variables
double regr[regrMeasures];
double regrLast[regrMeasures];

//+------------------------------------------------------------------+
//| regrMAGetData - loads the measures                               |
//+------------------------------------------------------------------+
void regrMAGetData()
  {
    int    idx;
    int    lastDir   = DIR_NONE;
        
    ArrayCopy(regrLast,regr);

    for (idx=0; idx<regrMeasures; idx++)
    {
      regr[idx] = iCustom(Symbol(),Period(),"regrMA-v1",inpRegrDeg,inpRegrRng,inpRegrST,inpRegrLT,4,idx);
    }  
  }
  
//+------------------------------------------------------------------+
//| CalculateRegression - polynomial regression to x degree          |
//+------------------------------------------------------------------+
double CalculateRegression(double &SourceBuffer[], double &TargetBuffer[], int Range)
  {
    double ai[10,10],b[10],x[10],sx[20];
    double sum; 
    double qq,mm,tt;

    int    ii,jj,kk,ll,nn;
    int    mi,n;

    double mean_y=0.00;
    double se_l=0.00;
    double se_y=0.00;
    
    if (Bars < Range) return(STR_NONE);
    
    sx[1]  = Range+1;
    nn     = inpRegrDeg+1;
   
     //----------------------sx-------------
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
     
     //===============Matrix================
     ArrayInitialize(ai,0.00);
     for(jj=1;jj<=nn;jj++)
     {
       for(ii=1; ii<=nn; ii++)
       {
          kk=ii+jj-1;
          ai[ii,jj]=sx[kk];
       }
     }

     //===============Gauss=================
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
     //=====================================
     
     for(n=0;n<=Range;n++)
     {
       sum=0;
       for(kk=1;kk<=inpRegrDeg;kk++)
       {
          sum+=x[kk+1]*MathPow(n,kk);
       }
       mean_y += x[1]+sum;

       TargetBuffer[n]=x[1]+sum;
     }

     mean_y = mean_y/Range;

     for (n=0;n<Range;n++)
     {
       se_l += pow(SourceBuffer[n]-TargetBuffer[n],2);
       se_y += pow(TargetBuffer[n]-mean_y,2);
     }
    
    TargetBuffer[Range+1]=0.00;

    return ((1-(se_l/se_y))*100);  //--- R^2 factor
  }

