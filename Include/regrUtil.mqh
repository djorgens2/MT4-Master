//+------------------------------------------------------------------+
//|                                                     regrUtil.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| regrCalcPoly - polynomial regression to x degree                 |
//+------------------------------------------------------------------+
double regrCalcPoly(double &SourceBuffer[], double &TargetBuffer[], int Range, int Degree)
  {
    double ai[10,10],b[10],x[10],sx[20];
    double sum; 
    double qq,mm,tt;

    int    ii,jj,kk,ll,nn;
    int    mi,n;

    double mean_y=0.00;
    double se_l=0.00;
    double se_y=0.00;
    
    if (Bars < Range) return(0.00);
    
    sx[1]  = Range+1;
    nn     = Degree+1;
   
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
       for(kk=1;kk<=Degree;kk++)
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

//+------------------------------------------------------------------+
//| regrCalcTrendLine - Computes trendline vector from supplied MA   |
//+------------------------------------------------------------------+
void regrCalcTrendLine(int Range, double &SourceBuffer[], double &TargetBuffer[])
  {
    //--- Linear regression line
    double m[5] = {0.00,0.00,0.00,0.00,0.00};  //--- slope
    double b    = 0.00;                        //--- y-intercept
    
    double sumx = 0.00;
    double sumy = 0.00;
        
    for (int idx=0; idx<Range; idx++)
    {
      sumx += idx+1;
      sumy += SourceBuffer[idx];
      
      m[1] += (idx+1)* SourceBuffer[idx];
      m[3] += pow(idx+1,2);
    }
    
    m[1]   *= Range;
    m[2]    = sumx*sumy;
    m[3]   *= Range;
    m[4]    = pow(sumx,2);
    
    m[0]    = (m[1]-m[2])/(m[3]-m[4]);
    b       = (sumy - m[0]*sumx)/Range;
    
    for (int idx=0; idx<Range; idx++) 
      TargetBuffer[Range-idx-1] = (m[0]*(Range-idx-1))+b; //--- y=mx+b
      
    TargetBuffer[Range]=0.00;
  }

