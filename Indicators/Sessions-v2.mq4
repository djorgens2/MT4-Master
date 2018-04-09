//+------------------------------------------------------------------+
//|                                                  Sessions-v2.mq4 |
//|                                      Written by Dennis Jorgenson |
//|                                                                  |
//|                                                                  |
//|  02.19.2018  Adapted from i-Sessions.mq4                         |
//|              Orig. Author: KimIV from http://www.kimiv.ru        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2018, Dennis Jorgenson"
#property version   "2.0"
#property strict
#property indicator_chart_window

#property indicator_buffers   2
#property indicator_plots     2

#include <stdutil.mqh>
#include <std_utility.mqh>
#include <Class/SessionArray.mqh>

//--- plot Off & Prior Session points
#property indicator_label1  "indPriorMid"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "indOfffMid"
#property indicator_type2   DRAW_LINE;
#property indicator_color2  clrYellow;
#property indicator_style2  STYLE_DOT;
#property indicator_width2  1

double indPriorMidBuffer[];
double indOffMidBuffer[];


//--- Operational Inputs
input SessionType    inpType       = SessionTypes; // Indicator session
input int            inpHourOpen   = NoValue;      // Session Opening Hour
input int            inpHourClose  = NoValue;      // Session Closing Hour

CSessionArray *session             = new CSessionArray(inpType,inpHourOpen,inpHourClose);

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints on screen information                   |
//+------------------------------------------------------------------+
void RefreshScreen(void)
 {
 }

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
    //ObjectDelete("AS"+IntegerToString(i));
    //ObjectDelete("ASup");
    //ObjectDelete("ASdn");
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
//   datetime t1, t2;
//   double   p1, p2;
//   int      b1, b2;
//
//   t1=StrToTime(TimeToStr(dt, TIME_DATE)+" "+tb);
//   t2=StrToTime(TimeToStr(dt, TIME_DATE)+" "+te);
//   b1=iBarShift(NULL, 0, t1);
//   b2=iBarShift(NULL, 0, t2);
//   p1=High[Highest(NULL, 0, MODE_HIGH, b1-b2, b2)];
//   p2=Low [Lowest (NULL, 0, MODE_LOW , b1-b2, b2)];
//
//   if (ObjectFind(no+"up")<0)
//     ObjectCreate(no+"up", OBJ_TEXT, 0, 0,0);
//
//   ObjectSet(no+"up", OBJPROP_TIME1   , t2);
//   ObjectSet(no+"up", OBJPROP_PRICE1  , p1+OffSet*Point);
//   ObjectSet(no+"up", OBJPROP_COLOR   , clFont);
//   ObjectSet(no+"up", OBJPROP_FONTSIZE, SizeFont);
//   ObjectSetText(no+"up", DoubleToStr(p1+Ask-Bid, Digits));
//
//   if (ObjectFind(no+"dn")<0)
//     ObjectCreate(no+"dn", OBJ_TEXT, 0, 0,0);
//
//   ObjectSet(no+"dn", OBJPROP_TIME1   , t2);
//   ObjectSet(no+"dn", OBJPROP_PRICE1  , p2);
//   ObjectSet(no+"dn", OBJPROP_COLOR   , clFont);
//   ObjectSet(no+"dn", OBJPROP_FONTSIZE, SizeFont);
//   ObjectSetText(no+"dn", DoubleToStr(p2, Digits));
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

   return(StrToTime(IntegerToString(ty)+"."+IntegerToString(tm)+"."+IntegerToString(td)+" "+IntegerToString(th)+":"+IntegerToString(ti)));
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
   datetime dt=TimeCurrent();
  
//   for (int i=0; i<NumberOfDays; i++)
//   {
//     if (ShowPrice && i==0)
//       DrawPrices(dt, "AS", AsiaBegin, AsiaEnd);
//
//     DrawObjects(dt, "AS"+IntegerToString(i), AsiaBegin, AsiaEnd);
//
//     dt=decDateTradeDay(dt);
//
//     while (TimeDayOfWeek(dt)>5)
//       dt=decDateTradeDay(dt);
//   }
   
//    if(prev_calculated==0)
    session.Update(indOffMidBuffer,indPriorMidBuffer);
    
    RefreshScreen();

    return(rates_total);
  }
  
       
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
 {
    SetIndexBuffer(0,indPriorMidBuffer);
    SetIndexEmptyValue(0, 0.00);
    SetIndexStyle(0,DRAW_SECTION);

    SetIndexBuffer(1,indOffMidBuffer);
    SetIndexEmptyValue(1, 0.00);
    SetIndexStyle(1,DRAW_SECTION);

//   DeleteObjects();

//   CreateObjects("AS"+IntegerToString(i), AsiaColor);
      
   if (Period()<PERIOD_D1)
     return (INIT_SUCCEEDED);

   return (INIT_FAILED);   
 }

//+------------------------------------------------------------------+
//| Custor indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
 {
   DeleteObjects();
 }
