//+------------------------------------------------------------------+
//|                                                   JJN-Nugget.mq4 |
//|                                      Copyright © 2012, JJ Newark |
//|                                            http:/jjnewark.atw.hu |
//|                                             jjnewark@freemail.hu |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012, JJ Newark"
#property link      "http:/jjnewark.atw.hu"


//---- indicator settings
//#property  indicator_separate_window
#property indicator_chart_window
#property  indicator_buffers      1
#property  indicator_color1       DarkOrange
#property  indicator_width1       2


//---- indicator parameters
extern string     __Copyright__               = "http://jjnewark.atw.hu";
extern color      BuyColor                    = YellowGreen;
extern color      SellColor                   = OrangeRed;
extern color      FontColor                   = Black;
extern int        DisplayDecimals             = 4;
extern int        PosX                        = 10;
extern int        PosY                        = 20;


//---- indicator buffers
double     MainVal[];

double ValSum[];


double Vals[8];
double ValSumTemp;
int per[]={5,8,13,21,34,55,89,144};


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- drawing settings
   IndicatorBuffers(2);
   SetIndexStyle(0,DRAW_SECTION);
   SetIndexBuffer(0,MainVal);
   SetIndexBuffer(1,ValSum);
      
   SetIndexLabel(0,"MainVal");
   
   ObjectCreate("NuggetIndName",OBJ_LABEL,0,0,0,0,0);
   ObjectSet("NuggetIndName",OBJPROP_CORNER,0);
   ObjectSet("NuggetIndName",OBJPROP_XDISTANCE,PosX+12);
   ObjectSet("NuggetIndName",OBJPROP_YDISTANCE,PosY);
   ObjectSetText("NuggetIndName","JJN-Nugget",8,"Lucida Sans Unicode",FontColor);
   
   ObjectCreate("NuggetLine0",OBJ_LABEL,0,0,0,0,0);
   ObjectSet("NuggetLine0",OBJPROP_CORNER,0);
   ObjectSet("NuggetLine0",OBJPROP_XDISTANCE,PosX+5);
   ObjectSet("NuggetLine0",OBJPROP_YDISTANCE,PosY+8);
   ObjectSetText("NuggetLine0","------------------",8,"Tahoma",FontColor);
   
   ObjectCreate("NuggetLine1",OBJ_LABEL,0,0,0,0,0);
   ObjectSet("NuggetLine1",OBJPROP_CORNER,0);
   ObjectSet("NuggetLine1",OBJPROP_XDISTANCE,PosX+5);
   ObjectSet("NuggetLine1",OBJPROP_YDISTANCE,PosY+10);
   ObjectSetText("NuggetLine1","------------------",8,"Tahoma",FontColor);
    
   ObjectCreate("NuggetDirection",OBJ_LABEL,0,0,0,0,0);
   ObjectSet("NuggetDirection",OBJPROP_CORNER,0);
   ObjectSet("NuggetDirection",OBJPROP_XDISTANCE,PosX);
   ObjectSet("NuggetDirection",OBJPROP_YDISTANCE,PosY+12);
   ObjectSetText("NuggetDirection","Wait ...",28,"Lucida Sans Unicode",FontColor);   
   
   ObjectCreate("NuggetLevel",OBJ_LABEL,0,0,0,0,0);
   ObjectSet("NuggetLevel",OBJPROP_CORNER,0);
   ObjectSet("NuggetLevel",OBJPROP_XDISTANCE,PosX);
   ObjectSet("NuggetLevel",OBJPROP_YDISTANCE,PosY+50);
   ObjectSetText("NuggetLevel","  -----  ",9,"Lucida Sans Unicode",FontColor);
   
//---- 
   IndicatorShortName("JJN-Nugget");
   
   
//---- initialization done
   return(0);
  }

int deinit()
  {
//----
   ObjectDelete("NuggetLine0");
   ObjectDelete("NuggetLine1");
   ObjectDelete("NuggetIndName");
   ObjectDelete("NuggetDirection");
   ObjectDelete("NuggetLevel");
      
//----
   return(0);
  }

int start()
  {
   int limit;
   int counted_bars=IndicatorCounted();
//---- last counted bar will be recounted
   if(counted_bars>0) counted_bars--;
   limit=Bars-counted_bars;
//---- 

   for(int i=0; i<limit; i++)
   {
      for(int j=0; j<8; j++)
      {
      Vals[j]=iMA(NULL,0,per[j],0,MODE_EMA,PRICE_CLOSE,i);
      }
   
      ValSumTemp=0;
      for(int k=0; k<8; k++)
      {
      ValSumTemp+=Vals[k];
      }
      ValSum[i]=ValSumTemp/8;
   }
   
   
   for(i=0; i<limit; i++)
   {
   if(ValSum[i]>(High[i]+Low[i])/2 && ValSum[i+1]<(High[i+1]+Low[i+1])/2) 
      { 
      MainVal[i]=High[i]; 
      }
   else if(ValSum[i]<(High[i]+Low[i])/2 && ValSum[i+1]>(High[i+1]+Low[i+1])/2) 
      {
      MainVal[i]=Low[i];
      }
   else MainVal[i]=EMPTY_VALUE;
   }
   
   double lastprice=0;
        
   int found=0;
   int w=0;
      
      while(found<1)
      {
         if(MainVal[w]!=EMPTY_VALUE)
         {
            lastprice=MainVal[w];
            found++;
         }
         w++;
      }
    
    if(ValSum[0]<(High[0]+Low[0])/2)
    { 
    ObjectSet("NuggetDirection",OBJPROP_XDISTANCE,PosX+5);
    ObjectSetText("NuggetDirection","BUY",28,"Lucida Sans Unicode",BuyColor); 
    ObjectSetText("NuggetLevel","above "+DoubleToStr(lastprice,DisplayDecimals),9,"Lucida Sans Unicode",BuyColor);
    }
    else if(ValSum[0]>(High[0]+Low[0])/2)
    {
    ObjectSet("NuggetDirection",OBJPROP_XDISTANCE,PosX+2);
    ObjectSetText("NuggetDirection","SELL",28,"Lucida Sans Unicode",SellColor); 
    ObjectSetText("NuggetLevel","under "+DoubleToStr(lastprice,DisplayDecimals),9,"Lucida Sans Unicode",SellColor); 
    }
    
    
//---- done
   return(0);
  }
//+------------------------------------------------------------------+