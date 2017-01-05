//+------------------------------------------------------------------+
//|                                                      i-regr2.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
//
// Regression Channel with variable polynomial degree indicator
//
// original by Boris
// www.iticsoftware.com
// http://www.mql5.com/en/code/8417
//
// V1.1 by graziani:
// -> minor changes for MT4 b600 compatibility
//

#property strict

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1 LimeGreen
#property indicator_color2 Gold
#property indicator_color3 Gold

/*
//int xI[] = {0,  1,  2,  3,  4,  5,  6,   7,   8,   9,   10};
int yI[] = {1,  6,  17, 34, 57, 86, 121, 162, 209, 262, 321};
input int x0=0;
input int degree=3;
input int bars=11;
*/

double yI[] = {
/*1.25480,*/ 1.25509, 1.25292, 1.25219, 1.25145, 1.25133, 1.25294, 1.25377, 1.25449, 1.25444,
1.25341, 1.25445, 1.25490, 1.25454, 1.25366, 1.25331, 1.25186, 1.25165, 1.25403, 1.25463,
1.25506, 1.25412, 1.25325, 1.25358, 1.25410, 1.25416, 1.25340, 1.25413, 1.25354, 1.25259,
1.25286, 1.25344, 1.25365, 1.25417, 1.25487, 1.25835, 1.25796, 1.25873, 1.25818, 1.25828,
1.26118 };
input int degree = 6;
input int bars = 40;
input int x0 = 2;
//input int xStep = 1;

input int shift=0;
input double kstd=2.0;

//-----
double fx[],sqh[],sql[];

double ai[10,10],b[10],x[10],sx[20];
double sum;
//int p;
int n,f;
double qq,mm,tt;
int ii,jj,kk,ll,nn;
double sq;


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
{
   SetIndexBuffer(0,fx); // Áóôåðû ìàññèâîâ èíäèêàòîðàčćčćž
   SetIndexBuffer(1,sqh);
   SetIndexBuffer(2,sql);

   SetIndexStyle(0,DRAW_LINE);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexStyle(2,DRAW_LINE);

   SetIndexEmptyValue(0, 0.0);
   SetIndexEmptyValue(1, 0.0);
   SetIndexEmptyValue(2, 0.0);

   SetIndexShift(0,shift);
   SetIndexShift(1,shift);
   SetIndexShift(2,shift);

   return(0);
}


//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void deinit()
{
}


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   if(Bars < bars) return(-1);

   int mi; // ïåðåìåííàÿ èñïîëüçóþùàÿñÿ òîëüêî â start
   //p=bars;
   sx[1] = bars;//  + 1; //ne treba +1  // ïðèìå÷àíèå - [] - îçíà÷àåò ìàññèâ
   nn = degree + 1;

   SetIndexDrawBegin(0,Bars-bars-2);
   SetIndexDrawBegin(1,Bars-bars-2);
   SetIndexDrawBegin(2,Bars-bars-2);

//----------------------sx-------------------------------------------------------------------
   for(mi=1;mi<=nn*2-2;mi++) // ìàòåìàòè÷åñêîå âûðàæåíèå - äëÿ âñåõ mi îò 1 äî nn*2-2 
     {
      sum=0;
      for(n=0; n<bars; n++)
        {
         sum+=MathPow(n + x0, mi);
        }
      sx[mi+1]=sum;
     }
//----------------------syx-----------
   for(mi=1;mi<=nn;mi++)
   {
      sum=0.00000;
      for(n=0; n<bars; n++)
      {
//         if(mi==1) sum+=Close[n];
//         else sum+=Close[n]*MathPow(n,mi-1);
//Print(n);
         if(mi==1) sum += yI[n];
         else sum += yI[n]*MathPow(n + x0, mi-1);
      }
      b[mi]=sum;
   }
//===============Matrix=======================================================================================================
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
      if(ll!=kk)
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
   for(n=0;n<=bars;n++)
   {  sum=0;
      for(kk=1;kk<=degree;kk++)
      {  sum+=x[kk+1]*MathPow(n + x0,kk);
      }
      fx[n]=x[1]+sum;
      Print(fx[n]);
   }
//-----------------------------------Std-----------------------------------------------------------------------------------
   sq=0.0;
   for(n=0;n<bars;n++)
      sq+=MathPow(Close[n + x0]-fx[n + x0],2);
   sq=MathSqrt(sq/(bars+1))*kstd;

   for(n=0; n<bars; n++)
   {  sqh[n + x0] = fx[n + x0] + sq;
      sql[n + x0] = fx[n + x0] - sq;
   }

   for (n=1; n<=degree+1; n++)
      Print("x[", n, "] = ", x[n]);

   return(0);
  }
//+------------------------------------------------------------------+
