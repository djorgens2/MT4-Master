//+------------------------------------------------------------------+
//|                                  Main Points - Dottor Market.mq4 |
//|                                                    Dottor Market |
//|                                          www.tradersitaliani.com |
//+------------------------------------------------------------------+
#property copyright "Dottor Market"
#property link      "www.tradersitaliani.com"
//----
#property indicator_chart_window

extern int Text_size=8;
extern color Daily_Color=Blue;
extern color Weekly_Color=Green;
extern color Monthly_Color=Red;
extern int Shift=50;
int Angle = 3;
int Width = 0;
int Shift2 = 290;
extern color Color=DodgerBlue;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- indicators
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   ObjectDelete("PIVOT DAILY1");
   ObjectDelete("Pivot Daily");
   ObjectDelete("PIVOT WEEKLY1");
   ObjectDelete("Pivot Weekly");
   ObjectDelete("PIVOT MONTHLY1");
   ObjectDelete("Pivot Monthly");
   ObjectDelete("Title");
   Comment(" ");
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
//---- Calcolo dei Pivot

double Pivot_Daily =  (iHigh(Symbol(),PERIOD_D1,1) + iLow(Symbol(),PERIOD_D1,1) + iClose(Symbol(),PERIOD_D1,1))/3;// Pivot Daily
double Pivot_weekly = (iHigh(Symbol(),PERIOD_W1,1) + iLow(Symbol(),PERIOD_W1,1) + iClose(Symbol(),PERIOD_W1,1))/3;// Pivot Weekly
double Pivot_Monthly = (iHigh(Symbol(),PERIOD_MN1,1) + iLow(Symbol(),PERIOD_MN1,1) + iClose(Symbol(),PERIOD_MN1,1))/3;// Pivot Monthly

//----
drawLine(Pivot_Daily,"PIVOT DAILY1",Daily_Color,1);
drawLabel("Pivot Daily",Pivot_Daily,Daily_Color);
drawLine(Pivot_weekly,"PIVOT WEEKLY1",Weekly_Color,0);
drawLabel("Pivot Weekly",Pivot_weekly,Weekly_Color);
drawLine(Pivot_Monthly,"PIVOT MONTHLY1",Monthly_Color,0);
drawLabel("Pivot Monthly",Pivot_Monthly,Monthly_Color);

// Titolo
   ObjectCreate("Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("Title","Main Points ON - Dottor Market",Text_size+2, "Times New Roman", Color);
   ObjectSet("Title", OBJPROP_CORNER, Angle);
   ObjectSet("Title", OBJPROP_XDISTANCE, (3+Shift2));
   ObjectSet("Title", OBJPROP_YDISTANCE, (3+Width));
//----
   return(0);
  }
//+------------------------------------------------------------------+
void drawLabel(string nome,double lvl,color Color)
{
    if(ObjectFind(nome) != 0)
    {
        ObjectCreate(nome, OBJ_TEXT, 0, Time[Shift], lvl);
        ObjectSetText(nome, nome, Text_size, "Times New Roman", EMPTY);
        ObjectSet(nome, OBJPROP_COLOR, Color);
    }
    else
    {
        ObjectMove(nome, 0, Time[Shift], lvl);
    }
}
//----
void drawLine(double lvl,string nome, color Col,int type)
{
         if(ObjectFind(nome) != 0)
         {
            ObjectCreate(nome, OBJ_HLINE, 0, Time[0], lvl,Time[0],lvl);           
            if(type == 1)
            ObjectSet(nome, OBJPROP_STYLE, STYLE_SOLID);
            else
            ObjectSet(nome, OBJPROP_STYLE, STYLE_DOT);
            ObjectSet(nome, OBJPROP_COLOR, Col);
            ObjectSet(nome,OBJPROP_WIDTH,1);  
         }
         else
         {
            ObjectDelete(nome);
            ObjectCreate(nome, OBJ_HLINE, 0, Time[0], lvl,Time[0],lvl);  
            if(type == 1)
            ObjectSet(nome, OBJPROP_STYLE, STYLE_SOLID);
            else
            ObjectSet(nome, OBJPROP_STYLE, STYLE_DOT);
            ObjectSet(nome, OBJPROP_COLOR, Col);        
            ObjectSet(nome,OBJPROP_WIDTH,1);         
         }
}
//+--------------------------------------------------------------------+