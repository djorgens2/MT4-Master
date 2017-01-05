#property indicator_separate_window
#property indicator_buffers 2
#property indicator_color1 C'200,0,0'
#property indicator_color2 C'0,200,0'

extern int MaxDrawTicks=5000;
double ExtMapBuffer1[];
double ExtMapBuffer2[];

int myBars;
int tickCounter;
int delimeterCounter;
string nume1,nume2;

int init()
  {

    int i;
    nume1 ="Bid_"+Symbol();
    nume2 ="Ask_"+Symbol();    
    GlobalVariableSet(nume1,0);
    GlobalVariableSet(nume2,0);    

   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0, ExtMapBuffer1);
   SetIndexEmptyValue(0,0.0);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexBuffer(1, ExtMapBuffer2);
   SetIndexEmptyValue(1,0.0);   

   for (i=Bars-1;i>=0;i--) ExtMapBuffer1[i]=0.0;
   for (i=Bars-1;i>=0;i--) ExtMapBuffer2[i]=0.0;

   return(0);
  }

void SetDelimeter()
  {
/*
   string delimeterDate=TimeToStr(Time[0]);
   if (myBars!=0)
      {
          
      int handle=WindowFind("Ticks");
      if(!ObjectCreate(delimeterDate,OBJ_VLINE,handle,Time[0],0))
         {
         Print("Error",GetLastError(),delimeterDate);
         }
      else 
         {
         ObjectSet(delimeterDate,OBJPROP_COLOR,C'195,195,195');
         ObjectSet(delimeterDate,OBJPROP_STYLE,STYLE_DOT);
         ObjectSet (delimeterDate,OBJPROP_BACK, true);
         ObjectsRedraw();           
         }
      }
*/
   return(0);
  }
void ShiftArray()
  {

   int V_lines,i1;
   string delimeterName;
   datetime firstTime;
   int BarFirstTime;
   
   if (tickCounter>2*MaxDrawTicks)
      {
      for (i1=tickCounter;i1>=MaxDrawTicks;i1--) ExtMapBuffer1[i1]=0.0;
      for (i1=tickCounter;i1>=MaxDrawTicks;i1--) ExtMapBuffer2[i1]=0.0;

      tickCounter=MaxDrawTicks;
      }
   for(int cnt=tickCounter;cnt>0;cnt--)
      {
      ExtMapBuffer1[cnt]=ExtMapBuffer1[cnt-1];
      ExtMapBuffer2[cnt]=ExtMapBuffer2[cnt-1];

      }
   V_lines=ObjectsTotal();
   for (int z=0;z<V_lines;z++)
      {
      delimeterName=ObjectName(z); 
      if (ObjectFind(delimeterName)!=-1)
         {
         if (ObjectType(delimeterName)==OBJ_VLINE) 
            {
            firstTime=ObjectGet(delimeterName,OBJPROP_TIME1);
            BarFirstTime=iBarShift(NULL,0,firstTime);
            firstTime=Time[BarFirstTime+1];
            ObjectSet(delimeterName,OBJPROP_TIME1,firstTime); 
            }
         }       
      }

   return(0);
  }

bool isNewBar()
  {

   bool res=false;
   if (myBars!=Bars)
      {
      res=true;
      myBars=Bars;
      }   

   return(res);
  }

int start()
  {

   int    counted_bars=IndicatorCounted();

   if (isNewBar())
      {
      SetDelimeter();
      ExtMapBuffer1[0]=Bid;      
      ExtMapBuffer2[0]=Ask;   

      GlobalVariableSet(nume1,Bid);
      GlobalVariableSet(nume2,Ask);            

      }
   else
      
      {

      tickCounter++;
      ShiftArray();
      ExtMapBuffer1[0]=Bid;      
      ExtMapBuffer2[0]=Ask;      

      GlobalVariableSet(nume1,Bid);
      GlobalVariableSet(nume2,Ask);         

      }

//------------------------SHOW TRADE LEVELS-------------------------------------------------------

int windowIndex=WindowFind("Ticks");

double A = 0;  
double HighPrice = NormalizeDouble(  (Bid+(0.01))*10000,0   );
double LowPrice =  NormalizeDouble(  (Bid-(0.01))*10000,0   );

   for(A=LowPrice;A<=HighPrice;A++)
   {
	 	     
         if (ObjectFind("TickGrid"+A) != 0)
         {            
         
         //string B = DoubleToStr(A,0);
         //string GridLevel= StringSubstr(B,StringLen(B)-2,2);
                
            ObjectCreate("TickGrid"+A, OBJ_HLINE, windowIndex, 0, A*0.0001);            
            ObjectSet("TickGrid"+A, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet ("TickGrid" +A, OBJPROP_BACK, true);
            ObjectSet("TickGrid"+A, OBJPROP_COLOR,C'195,195,195'); 
           
           // ObjectCreate("Level"+A, OBJ_TEXT, windowIndex, TimeCurrent(), A*0.0001);
           // ObjectSetText("Level"+A,GridLevel,10,"Centuary",Black);
         }
    
   }     

if(OrdersTotal()==0){ObjectsDeleteAll(windowIndex,OBJ_TREND);}else{

double i =0;

for(i=0;i<OrdersTotal();i++)
   {       
   OrderSelect(i,SELECT_BY_POS,MODE_TRADES) ;

    ObjectCreate("TradeLevel1"+i,OBJ_TREND,windowIndex,0,OrderOpenPrice(),TimeCurrent(),OrderOpenPrice());
    ObjectSet("TradeLevel1"+i, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSet ("TradeLevel1"+i, OBJPROP_BACK, true);
    ObjectSet("TradeLevel1"+i, OBJPROP_COLOR,Blue); 
  
    ObjectCreate("TradeLevel2"+i,OBJ_TREND,windowIndex,0,OrderStopLoss(),TimeCurrent(),OrderStopLoss());
    ObjectSet("TradeLevel2"+i, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSet ("TradeLevel2"+i, OBJPROP_BACK, true);
    ObjectSet("TradeLevel2"+i, OBJPROP_COLOR,FireBrick); 
  
    ObjectCreate("TradeLevel3"+i,OBJ_TREND,windowIndex,0,OrderTakeProfit(),TimeCurrent(),OrderTakeProfit());
    ObjectSet("TradeLevel3"+i, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSet ("TradeLevel3"+i, OBJPROP_BACK, true);
    ObjectSet("TradeLevel3"+i, OBJPROP_COLOR,FireBrick); 
   
  }
}

return(0);
}

