//+------------------------------------------------------------------+
//|                                                     Sessions.mq4 |
//|                                      Updated by Dennis Jorgenson |
//|                                                                  |
//|                                                                  |
//|  02.19.2018  Adapted from i-Sessions.mq4                         |
//|              Original Author: KimIV from http://www.kimiv.ru     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2018, Dennis Jorgenson"
#property version   "1.1"

#property indicator_chart_window

//------- Operational Inputs -------------------------------
extern int    NumberOfDays = 99;             // Number of days to paint
extern string AsiaBegin    = "01:00";        // Asia session begin time
extern string AsiaEnd      = "10:00";        // Asia session end time
extern color  AsiaColor    = C'0,32,0';      // Asia session box color
extern string EurBegin     = "08:00";        // Europe session begin time
extern string EurEnd       = "18:00";        // Europe session end time
extern color  EurColor     = C'48,0,0';      // Europe session box color
extern string USABegin     = "14:00";        // US session begin time
extern string USAEnd       = "23:00";        // US session end time
extern color  USAColor     = C'0,0,56';      // US session box color
extern bool   ShowPrice    = False;          // Display session prices
extern color  clFont       = Blue;           // Session price color
extern int    SizeFont     = 8;              // Session price font size
extern int    OffSet       = 10;             // Session price offset

//+------------------------------------------------------------------+
//| CreateObjects - Paints the session boxes                         |
//| Usage:                                                           |
//|   no - Unique identifier for the painted session                 |
//|   cl - Color for the supplied session                            |
//+------------------------------------------------------------------+
void CreateObjects(string no, color cl)
 {
   ObjectCreate(no, OBJ_RECTANGLE, 0, 0,0, 0,0);
   ObjectSet(no, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSet(no, OBJPROP_COLOR, cl);
   ObjectSet(no, OBJPROP_BACK, True);
 }

//+------------------------------------------------------------------+
//| DeleteObjects - Removes all objects created by the indicator     |
//+------------------------------------------------------------------+
void DeleteObjects()
 {
   for (int i=0; i<NumberOfDays; i++)
   {
     ObjectDelete("AS"+i);
     ObjectDelete("EU"+i);
     ObjectDelete("US"+i);
   }

   ObjectDelete("ASup");
   ObjectDelete("ASdn");
   ObjectDelete("EUup");
   ObjectDelete("EUdn");
   ObjectDelete("USup");
   ObjectDelete("USdn");
 }

//+------------------------------------------------------------------+
//| DrawObjects - Repaints the session boxes                         |
//| Usage:                                                           |
//|   dt - Date/Time of the session to repaint                       |
//|   no - Unique session identifier                                 |
//|   tb - Session begin time                                        |
//|   te - Session end time                                          |
//+------------------------------------------------------------------+
void DrawObjects(datetime dt, string no, string tb, string te)
 {
   datetime t1, t2;
   double   p1, p2;
   int      b1, b2;

   t1=StrToTime(TimeToStr(dt, TIME_DATE)+" "+tb);
   t2=StrToTime(TimeToStr(dt, TIME_DATE)+" "+te);
   b1=iBarShift(NULL, 0, t1);
   b2=iBarShift(NULL, 0, t2);
   p1=High[Highest(NULL, 0, MODE_HIGH, b1-b2, b2)];
   p2=Low [Lowest (NULL, 0, MODE_LOW , b1-b2, b2)];

   ObjectSet(no, OBJPROP_TIME1 , t1);
   ObjectSet(no, OBJPROP_PRICE1, p1);
   ObjectSet(no, OBJPROP_TIME2 , t2);
   ObjectSet(no, OBJPROP_PRICE2, p2);
 }

//+------------------------------------------------------------------+
//| DrawPrices - paints the session prices (optional)                |
//| Usage:                                                           |
//|   dt - Date/Time of the session to repaint                       |
//|   no - Unique session identifier                                 |
//|   tb - Session begin time                                        |
//|   te - Session end time                                          |
//+------------------------------------------------------------------+
void DrawPrices(datetime dt, string no, string tb, string te)
 {
   datetime t1, t2;
   double   p1, p2;
   int      b1, b2;

   t1=StrToTime(TimeToStr(dt, TIME_DATE)+" "+tb);
   t2=StrToTime(TimeToStr(dt, TIME_DATE)+" "+te);
   b1=iBarShift(NULL, 0, t1);
   b2=iBarShift(NULL, 0, t2);
   p1=High[Highest(NULL, 0, MODE_HIGH, b1-b2, b2)];
   p2=Low [Lowest (NULL, 0, MODE_LOW , b1-b2, b2)];

   if (ObjectFind(no+"up")<0)
     ObjectCreate(no+"up", OBJ_TEXT, 0, 0,0);

   ObjectSet(no+"up", OBJPROP_TIME1   , t2);
   ObjectSet(no+"up", OBJPROP_PRICE1  , p1+OffSet*Point);
   ObjectSet(no+"up", OBJPROP_COLOR   , clFont);
   ObjectSet(no+"up", OBJPROP_FONTSIZE, SizeFont);
   ObjectSetText(no+"up", DoubleToStr(p1+Ask-Bid, Digits));

   if (ObjectFind(no+"dn")<0)
     ObjectCreate(no+"dn", OBJ_TEXT, 0, 0,0);

   ObjectSet(no+"dn", OBJPROP_TIME1   , t2);
   ObjectSet(no+"dn", OBJPROP_PRICE1  , p2);
   ObjectSet(no+"dn", OBJPROP_COLOR   , clFont);
   ObjectSet(no+"dn", OBJPROP_FONTSIZE, SizeFont);
   ObjectSetText(no+"dn", DoubleToStr(p2, Digits));
 }

//+------------------------------------------------------------------+
//| decDateTradeDay - Calculate the trade day                        |
//| Usage:                                                           |
//|   dt - Date/Time of trade day supplied                           |
//+------------------------------------------------------------------+
datetime decDateTradeDay (datetime dt)
 {
   int ty=TimeYear(dt);
   int tm=TimeMonth(dt);
   int td=TimeDay(dt);
   int th=TimeHour(dt);
   int ti=TimeMinute(dt);

   td--;

   if (td==0)
   {
     tm--;

     if (tm==0)
     {
       ty--;
       tm=12;
     }

     //--- Months containing 31 days
     if (tm==1 || tm==3 || tm==5 || tm==7 || tm==8 || tm==10 || tm==12)
       td=31;
     else
     
     //--- February leap year calc
     if (tm==2)
       if (fmod(ty, 4)==0)
         td=29;
       else td=28;
     else

     //--- Months containing 31 days
     if (tm==4 || tm==6 || tm==9 || tm==11)
       td=30;
   }

   return(StrToTime(ty+"."+tm+"."+td+" "+th+":"+ti));
 }
 
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void start()
 {
   datetime dt=TimeCurrent();
  
   for (int i=0; i<NumberOfDays; i++)
   {
     if (ShowPrice && i==0)
     {
       DrawPrices(dt, "AS", AsiaBegin, AsiaEnd);
       DrawPrices(dt, "EU", EurBegin, EurEnd);
       DrawPrices(dt, "US", USABegin, USAEnd);
     }

     DrawObjects(dt, "AS"+i, AsiaBegin, AsiaEnd);
     DrawObjects(dt, "EU"+i, EurBegin, EurEnd);
     DrawObjects(dt, "US"+i, USABegin, USAEnd);

     dt=decDateTradeDay(dt);

     while (TimeDayOfWeek(dt)>5)
       dt=decDateTradeDay(dt);
   }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void init()
 {
   DeleteObjects();

   for (int i=0; i<NumberOfDays; i++)
   {
     CreateObjects("AS"+i, AsiaColor);
     CreateObjects("EU"+i, EurColor);
     CreateObjects("US"+i, USAColor);
   }
 }

//+------------------------------------------------------------------+
//| Custor indicator deinitialization function                       |
//+------------------------------------------------------------------+
void deinit()
 {
   DeleteObjects();
 }
