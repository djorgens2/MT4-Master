//+------------------------------------------------------------------+
//|                                                    regrMA-v2.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

#include <std_utility.mqh>

//--- input parameters
input int inpRegrDeg      = 6;    // Poly regression degree
input int inpRegrRng      = 48;   // Poly regression range
input int inpRegrST       = 3;    // Short term poly MA
input int inpRegrLT       = 24;   // Long term poly MA


//--- measures constants
#define   regrMeasures       19
#define   regrST              0  //--- Short term value
#define   regrLT              1  //--- Long term value
#define   regrDirST           2  //--- Short term direction (nose)
#define   regrDirLT           3  //--- Long term directon (nose)
#define   regrTLCur           4  //--- Current TLine price
#define   regrTLHigh          5  //--- High TLine price
#define   regrTLLow           6  //--- Low TLine price
#define   regrTLMid           7  //--- Mid TLine price
#define   regrFOCCur          8  //--- current factor of change
#define   regrFOCMin          9  //--- absolute retrace factor of change
#define   regrFOCMax         10  //--- highest factor of change this direction
#define   regrFOCDev         11  //--- current factor of change deviation
#define   regrFOCCurDir      12  //--- current direction from last deviation
#define   regrFOCTrendDir    13  //--- overall trend (based on FOC max)
#define   regrFOCPiv         14  //--- price where the FOC changes direction
#define   regrFOCPivDir      15  //--- pivot direction, up or down
#define   regrFOCPivDev      16  //--- deviation of price to pivot
#define   regrFOCPivDevMin   17  //--- min deviation of price to pivot since last pivot
#define   regrFOCPivDevMax   18  //--- deviation of price to pivot since last pivot



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
      regr[idx] = iCustom(Symbol(),Period(),"regrMA-v2",inpRegrDeg,inpRegrRng,inpRegrST,inpRegrLT,4,idx);
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

