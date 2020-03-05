//+------------------------------------------------------------------+
//|                                                  std_utility.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

#import "user32.dll"
   int MessageBoxW(int Ignore, string Caption, string Title, int Icon);
#import

//--- logical defines
#define CONTRARIAN          true

//--- directional values
#define DIR_LCORR              4  //--- Long Correction
#define DIR_LREV               3  //--- Long reversal
#define DIR_RALLY              2  //--- Prices are moving higher against the trend
#define DIR_UP                 1  //--- Prices are moving higher
#define DIR_NONE               0  //--- Undetermined direction
#define DIR_DOWN              -1  //--- Prices are moving lower
#define DIR_PULLBACK          -2  //--- Prices are moving lower against the trend
#define DIR_SREV              -3  //--- Short reversal
#define DIR_SCORR             -4  //--- Short Correction


//--- additional op/action codes
#define OP_NO_ACTION          -1  //--- No defined action
#define OP_OPEN               -2  //--- Open actions (new orders)
#define OP_CLOSE              -3  //--- Close actions (take profit/close orders)
#define OP_STOP               -4  //--- Close actions (stop loss/close orders)
#define OP_HALT               -5  //--- Suspend trading till manually restarted
#define OP_PEND               -6  //--- Pend trading until automation send resume
#define OP_RESUME             -7  //--- Resume trading
#define OP_ALERT              -8  //--- Event action that causes an alert
#define OP_HEDGE              -9  //--- Contrarian action opportunity
#define OP_TARGET             -10 //--- Target price indicator


//---- Format Constants
#define IN_DIRECTION           8
#define IN_ACTION              9
#define IN_PROXIMITY          10
#define IN_DARK_DIR           11
#define IN_CHART_DIR          12
#define IN_CHART_ACTION       13


//---- Screen Locations
#define SCREEN_UL              0
#define SCREEN_UR              1
#define SCREEN_LL              2
#define SCREEN_LR              3

#include <stdutil.mqh>

//+------------------------------------------------------------------+
//| Pause - pauses execution and waits for user input                |
//+------------------------------------------------------------------+
int Pause(string Message, string Title, int Style=64)
  {
    if (IsTesting())
      return (MessageBoxW(0, Message, Title, Style));

    Alert(Symbol()+"> "+Title+"\n"+Message);
    
    return (0);
  }
    
//+------------------------------------------------------------------+
//| ArrayInitializeStr - initializes string arrays                   |
//+------------------------------------------------------------------+
void ArrayInitializeStr(string &Array[], int Count)
  {
    ArrayResize(Array,Count);
    
    for (int index=0; index<Count; index++)
      Array[index] = "";
  }

//+------------------------------------------------------------------+
//| InStr - Returns true if pattern is found in source string        |
//+------------------------------------------------------------------+
bool InStr(string Source, string Search)
  {
    if (StringSubstr(Source,StringFind(Source,Search),StringLen(Search))==Search)
      return (true);
     
    return (false);
  }

//+------------------------------------------------------------------+
//| StringSplit - Function which splits a delimited piece of text    |
//| into its component parts.                                        |
//+------------------------------------------------------------------+
int StringSplit(string InputString, string Separator, string &ResultArray[])
{
   ArrayResize(ResultArray, 0);
   
   int lenSeparator = StringLen(Separator);
   int NewArraySize;
   
   InputString = StringTrimLeft(StringTrimRight(InputString));
   
   while (InputString != "")
   {
     int p = StringFind(InputString, Separator);
    
     if (p == -1)
     {
       NewArraySize = ArraySize(ResultArray) + 1;
       ArrayResize(ResultArray, NewArraySize);      
       ResultArray[NewArraySize - 1] = InputString;
       InputString = "";
     }
     else
     {
       NewArraySize = ArraySize(ResultArray) + 1;
       ArrayResize(ResultArray, NewArraySize);      
       ResultArray[NewArraySize - 1] = StringTrimLeft(StringSubstr(InputString, 0, p));
       InputString = StringSubstr(InputString, p + lenSeparator);
       
       if (InputString == "")
       {
         ArrayResize(ResultArray, NewArraySize + 1);      
         ResultArray[NewArraySize] = "";
       }
     }     
   }
   
   return (ArraySize(ResultArray));
}

//+------------------------------------------------------------------+
//| NegLPad - returns a numeric string padded for negative sign      |
//+------------------------------------------------------------------+
string NegLPad(double Value, int Precision)
  {
    string lpad = "";

    if (Value>=0.00) lpad = " ";
    
    return (lpad+DoubleToString(Value,Precision));
  }

//+------------------------------------------------------------------+
//| LPad - left pads a value with the character and length supplied  |
//+------------------------------------------------------------------+
string LPad(string Value, string Pad, int Length)
  {
    if (StringLen(Value)<Length)
      for (int idx=Length-StringLen(Value);idx>0;idx--)
        Value = Pad+Value;
    
    return (Value);
  }

//+------------------------------------------------------------------+
//| RPad - right pads a value with the character and length supplied |
//+------------------------------------------------------------------+
string RPad(string Value, string Pad, int Length)
  {
    if (StringLen(Value)<Length)
      for (int idx=Length-StringLen(Value);idx>0;idx--)
        Value += Pad;
    
    return (Value);
  }

//+------------------------------------------------------------------+
//| ActionCode - returns order action id (buy/sell)                  |
//+------------------------------------------------------------------+
int ActionCode(string Action)
  {
    if (Action == "BUY")       return (OP_BUY);
    if (Action == "SELL")      return (OP_SELL);
    if (Action == "LONG")      return (OP_BUY);
    if (Action == "SHORT")     return (OP_SELL);

    if (Action == "BUYLIMIT")  return (OP_BUYLIMIT);
    if (Action == "BUYMIT")    return (OP_BUYSTOP);
    if (Action == "BUYSTOP")   return (OP_BUYSTOP);
    if (Action == "SELLLIMIT") return (OP_SELLLIMIT);
    if (Action == "SELLMIT")   return (OP_SELLSTOP);
    if (Action == "SELLSTOP")  return (OP_SELLSTOP);
    
    if (Action == "OPEN")      return (OP_OPEN);
    if (Action == "CLOSE")     return (OP_CLOSE);
    if (Action == "STOP")      return (OP_STOP);
    if (Action == "HALT")      return (OP_HALT);
    if (Action == "PEND")      return (OP_PEND);
    if (Action == "RESUME")    return (OP_RESUME);
    if (Action == "ALERT")     return (OP_ALERT);
    if (Action == "HEDGE")     return (OP_HEDGE);
    
    return (OP_NO_ACTION);
  }

//+------------------------------------------------------------------+
//| ActionText - returns the text of an ActionCode                   |
//+------------------------------------------------------------------+
string ActionText(int Action, int Format=IN_ACTION)
  {
    if (Format==IN_DIRECTION)
    {
      if (Action==OP_BUY||Action==OP_BUYLIMIT||Action==OP_BUYSTOP)
        return (DirText(DIR_UP));

      if (Action==OP_SELL||Action==OP_SELLLIMIT||Action==OP_SELLSTOP)
        return (DirText(DIR_DOWN));
      
      return (DirText(DIR_NONE));
    }

    switch (Action)
    {
      case OP_BUY           : return("BUY");
      case OP_BUYLIMIT      : return("BUY LIMIT");
      case OP_BUYSTOP       : return("BUY STOP");
      case OP_SELL          : return("SELL");
      case OP_SELLLIMIT     : return("SELL LIMIT");
      case OP_SELLSTOP      : return("SELL STOP");
      case OP_NO_ACTION     : return("NO ACTION");
      case OP_OPEN          : return("OPEN");          //--- Open action describes either buy or sell
      case OP_CLOSE         : return("CLOSE");         //--- Close action to handle graceful close-outs
      case OP_STOP          : return("STOP");          //--- Stop action to handle price level close-outs
      case OP_HALT          : return("HALT");          //--- Close action to kill opens and suspend trading
      case OP_PEND          : return("PENDING");       //--- No action until a resume is submitted
      case OP_RESUME        : return("RESUME");        //--- Resume Action to begin trading after a halt, close, or pend
      case OP_HEDGE         : return("HEDGE");         //--- Contrarian action opportunity
    
      default            : return("BAD ACTION CODE");
    }
  }


//+------------------------------------------------------------------+
//| pip - returns the Value in pips based on the current Symbol()    |
//+------------------------------------------------------------------+
double pip(double Value)
  {
    return (NormalizeDouble(Value * pow(10, Digits-1), Digits));
  }


//+------------------------------------------------------------------+
//| point - returns the Value in points based on the current Symbol()|
//+------------------------------------------------------------------+
double point(double Value)
  {
    return (NormalizeDouble(Value / pow(10, Digits-1), Digits));
  }

//+------------------------------------------------------------------+
//| proper - a proper case string                                    |
//+------------------------------------------------------------------+
string proper(string Value)
{
  bool     check;
  string   upper  = Value;
  
  check = StringToLower(Value);
  check = StringToUpper(upper);
  
  for (int idx=1; idx<StringLen(Value); idx++)    
    if (StringSubstr(Value,idx-1,1) == " ")
      StringReplace(Value,StringSubstr(Value,idx-1,2),StringSubstr(upper,idx-1,2));

  return(StringSubstr(upper,0,1)+StringSubstr(Value,1,StringLen(Value)-1));
}

//+------------------------------------------------------------------+
//| upper - a uppercase string                                       |
//+------------------------------------------------------------------+
string upper(string Value)
{
  string   uUpper  = Value;
  
  if (StringToUpper(uUpper))
    return(uUpper);
 
  return(NULL);
}

//+------------------------------------------------------------------+
//| lower - a lowercase string                                       |
//+------------------------------------------------------------------+
string lower(string Value)
{
  string   lLower  = Value;
  
  if (StringToLower(lLower))
    return(lLower);
 
  return(NULL);
}

//+------------------------------------------------------------------+
//| DirText - returns the text of a DirectionCode                    |
//+------------------------------------------------------------------+
string DirText(int Value, bool Contrarian=false)
{
  if (Contrarian)
    Value *= OP_NO_ACTION;
    
  switch (Value)
  {
    case DIR_LCORR     : return("CORRECTION LONG");
    case DIR_LREV      : return("REVERSAL LONG");
    case DIR_RALLY     : return("RALLY");
    case DIR_UP        : return("LONG");
    case DIR_NONE      : return("NONE");
    case DIR_DOWN      : return("SHORT");
    case DIR_PULLBACK  : return("PULLBACK");
    case DIR_SREV      : return("REVERSAL SHORT");
    case DIR_SCORR     : return("CORRECTION SHORT");
  }

  return("BAD DIRECTION CODE");
}

//+------------------------------------------------------------------+
//| DirColor - returns the color based on the supplied Value         |
//+------------------------------------------------------------------+
int DirColor(int Value, int DirUp=clrLawnGreen, int DirDown=clrRed, int DirNone=clrDarkGray)
{
  switch(Value)
  {
    case DIR_UP:    return(DirUp);
    case DIR_DOWN:  return(DirDown);
    case DIR_NONE:  return(DirNone);
    default:        return(-1);
  }
}

//+------------------------------------------------------------------+
//| Color - returns the color based on the supplied Value            |
//+------------------------------------------------------------------+
color Color(double Value, int Style=IN_DIRECTION, bool Contrarian=false)
{
  if (Contrarian)
    Value       *= -1.0;  
  
  switch (Style)
  {
    case IN_DIRECTION:     if (Value<0.00) return (clrRed);
                           if (Value>0.00) return (clrLawnGreen);
    case IN_PROXIMITY:     if (Close[0]>Value+point(6))   return(clrLawnGreen);
                           if (Close[0]>Value+point(3))   return(clrYellowGreen);
                           if (Close[0]>Value+point(0.2)) return(clrMediumSeaGreen);
                           if (Close[0]>Value-point(0.2)) return(clrYellow);
                           if (Close[0]>Value-point(3))   return(clrGoldenrod);
                           if (Close[0]>Value-point(6))   return(clrChocolate);
                           return (clrRed);
    case IN_DARK_DIR:      if (Value<0.00) return (clrMaroon);
                           if (Value>0.00) return (clrDarkGreen);
    case IN_CHART_DIR:     if (Value<0.00) return (clrRed);
                           if (Value>0.00) return (clrYellow);
                           return (clrDarkGray);
    case IN_ACTION:        if (Action(Value,InAction)==OP_BUY)  return (clrLawnGreen);
                           if (Action(Value,InAction)==OP_SELL) return (clrRed);
    case IN_CHART_ACTION:  if (Action(Value,InAction)==OP_BUY)  return (clrYellow);
                           if (Action(Value,InAction)==OP_SELL) return (clrRed);
  }
  
  return (clrDarkGray);
}

//+------------------------------------------------------------------+
//| DirAction - returns the Action based on supplied direction       |
//+------------------------------------------------------------------+
int DirAction(int Dir, bool Contrarian=false)
{
  switch(Dir)
  {
    case DIR_NONE:      return(OP_NO_ACTION);

    case DIR_LCORR:      
    case DIR_LREV:      
    case DIR_RALLY:     
    case DIR_UP:        if (Contrarian)
                          return(OP_SELL);
                        else
                          return(OP_BUY);
    case DIR_DOWN:      
    case DIR_PULLBACK:  
    case DIR_SREV:
    case DIR_SCORR:     if (Contrarian)
                          return(OP_BUY);
                        else
                          return(OP_SELL);
                          
    default:            return(-1);
  }
}

//+------------------------------------------------------------------+
//| ActionDir - returns the Direction based on supplied action       |
//+------------------------------------------------------------------+
int ActionDir(int Action, bool Contrarian=false)
{
  switch(Action)
  {
    case OP_BUY:        
    case OP_BUYLIMIT:   
    case OP_BUYSTOP:    if (Contrarian)
                          return (DIR_DOWN);
                        else
                          return (DIR_UP);
    
    case OP_SELL:
    case OP_SELLLIMIT:   
    case OP_SELLSTOP:   if (Contrarian)
                          return (DIR_UP);
                        else
                          return (DIR_DOWN);
                          
    default:            return(DIR_NONE);
  }
}

//+------------------------------------------------------------------+
//| dir - returns the direction based on the supplied Value          |
//+------------------------------------------------------------------+
int dir(double Value)
{
  if (Value>0.00) return (DIR_UP);
  if (Value<0.00) return (DIR_DOWN);
  
  return (DIR_NONE);
}

//+------------------------------------------------------------------+
//| dir - returns the direction based on the supplied price array    |
//+------------------------------------------------------------------+
int dir(int Current, double &Buffer[], int Range=3, int Shift=0)
{
  double agg = 0.00;
  
  for (int idx=0; idx<Range; idx++)
    agg += Buffer[idx+Shift]-Buffer[idx+Shift+1];
  
  if (pip(agg)>0.00) return (DIR_UP);
  if (pip(agg)<0.00) return (DIR_DOWN);
  
  return (Current);
}

//+------------------------------------------------------------------+
//| GetPeriod - returns integer Value of the supplied period         |
//+------------------------------------------------------------------+
int GetPeriod(string Value)
{
  int    minutes = 0;
  int    opt     = 0;
  
  string period  = Value;

  if (StringSubstr(period,0,7) == "PERIOD_")
    period = StringSubstr(Value,7,StringLen(Value)-7);
  
  if (StringSubstr(period,0,2) == "MN")
    return (43200);

  for (int pos=1;pos<StringLen(period);pos++)
    minutes += (StringGetChar(period,pos)-48)*(int)pow(10,StringLen(period)-pos-1);

  opt = StringGetChar(period,0);
      
  switch (opt)
  {
    case 67 /*'C'*/    : return (0);
    case 77 /*'M'*/    : return (minutes);
    case 72 /*'H'*/    : return (minutes*60);
    case 68 /*'D'*/    : return (minutes*1440);
    case 87 /*'W'*/    : return (minutes*10080);
    default            : return (-1);
  }
}

//+------------------------------------------------------------------+
//| New Arrow - paints an arrow on the chart in the price area       |
//+------------------------------------------------------------------+
string NewArrow(int ArrowCode, int Color, string Text="", double Price=0.00, int Bar=0)
  {   
    if (StringLen(Text)>0)
      Text      = ":"+Text;
      
    string name = StringConcatenate("arrow_", TimeToStr(Time[Bar]),Text);
    
    if (Price==0.00)
      Price = Close[Bar];

    ObjectDelete (name);
    ObjectCreate (name, OBJ_ARROW, 0, Time[Bar], Price);
    ObjectSet    (name, OBJPROP_ARROWCODE, ArrowCode);
    ObjectSet    (name, OBJPROP_COLOR,Color);
    
    return (name);
  }

//+------------------------------------------------------------------+
//| UpdateArrow - repaints existing arrow with supplied properties   |
//+------------------------------------------------------------------+
void UpdateArrow(string ArrowName, int ArrowCode, int Color, double Price=0.00)
  {
    if (Price==0.00)
      Price = Close[0];

    ObjectDelete (ArrowName);
    ObjectCreate (ArrowName, OBJ_ARROW, 0, Time[0], Price);
    ObjectSet    (ArrowName, OBJPROP_ARROWCODE, ArrowCode);
    ObjectSet    (ArrowName, OBJPROP_COLOR,Color);
  }

//+------------------------------------------------------------------+
//| UpdateDirection - creates an arrow label to show indicator value |
//+------------------------------------------------------------------+
void UpdateDirection(string LabelName, int Direction, int Color=0, int Size=10)
  { 
    if (Color == 0)
      Color = (int)ObjectGet(LabelName,OBJPROP_COLOR);
              
    if (Direction==OP_TARGET)
      ObjectSetText(LabelName,CharToStr(176),Size,"Wingdings",Color);    
    else
    if (Direction==OP_HALT)
      ObjectSetText(LabelName,CharToStr(78),Size,"Wingdings",Color);
    else
    if (Direction > 0)
      ObjectSetText(LabelName,CharToStr(241),Size,"Wingdings",Color);
    else
    if (Direction < 0)
      ObjectSetText(LabelName,CharToStr(242),Size,"Wingdings",Color);
    else
      ObjectSetText(LabelName,CharToStr(73), Size,"Wingdings",Color);
  }

//+------------------------------------------------------------------+
//| UpdateLabel                                                      |
//+------------------------------------------------------------------+
void UpdateLabel(string LabelName, string Text, int Color=White, int Size=8, string Font="Tahoma")
  {
    ObjectSetText(LabelName,Text,Size,Font,Color);
  }
  
//+------------------------------------------------------------------+
//| NewLabel                                                         |
//+------------------------------------------------------------------+
void NewLabel(string LabelName, string Text, int PosX, int PosY, int Color=White, int Corner=0, int Window=0)
  {
    ObjectCreate(LabelName,OBJ_LABEL,Window,0,0,0,0);
    ObjectSet(LabelName,OBJPROP_XDISTANCE,PosX);
    ObjectSet(LabelName,OBJPROP_YDISTANCE,PosY);
    ObjectSet(LabelName,OBJPROP_CORNER,Corner);
    
    UpdateLabel(LabelName,Text,Color);
  }

//+------------------------------------------------------------------+
//| NewBarNote                                                       |
//+------------------------------------------------------------------+
string NewBarNote(string Text, int Color=clrWhite)
  {
    static int nbnIdx    = 0;
    string     nbnKey    = "bn:"+(string)++nbnIdx;
    
    ObjectCreate(0,nbnKey,OBJ_TEXT,0,Time[0],Close[0]);
    ObjectSetInteger(0,nbnKey,OBJPROP_COLOR,Color);
    ObjectSetString(0,nbnKey,OBJPROP_TEXT,Text);
    
    return (nbnKey);
  }

//+------------------------------------------------------------------+
//| UpdateBarNote                                                    |
//+------------------------------------------------------------------+
void UpdateBarNote(string LabelName, double Price=0.00, int Color=clrWhite)
  {
    if (Price==0.00)
      Price         = Close[0];
      
    ObjectSetInteger(0,LabelName,OBJPROP_COLOR,Color);
    ObjectSetDouble(0,LabelName,OBJPROP_PRICE,Price);
    ObjectSet(LabelName,OBJPROP_TIME1,Time[0]);
  }

//+------------------------------------------------------------------+
//| UpdatePriceTag                                                   |
//+------------------------------------------------------------------+
void UpdatePriceTag(string PriceTagName, int Bar, int Direction)
  {
    double uptOffset  = point(5);
    
    if (Bar<0 || Bar>Bars)
      return;
      
    if (Direction == DIR_UP)
      ObjectSet(PriceTagName,OBJPROP_PRICE1,High[Bar]+(uptOffset*2));
    else
    
    if (Direction == DIR_DOWN)
      ObjectSet(PriceTagName,OBJPROP_PRICE1,Low[Bar]);

    else
      return;
          
    ObjectSet(PriceTagName,OBJPROP_TIME1,Time[Bar]);
  }
  
//+------------------------------------------------------------------+
//| NewPriceTag                                                      |
//+------------------------------------------------------------------+
void NewPriceTag(string PriceTagName, string Text, int Color=clrWhite, int Size=8, string Font="Tahoma")
  {
    if (ObjectCreate(PriceTagName,OBJ_TEXT,0,0,0))
      ObjectSetText(PriceTagName,Text,Size,Font,Color);
  }

//+------------------------------------------------------------------+
//| UpdateLine                                                       |
//+------------------------------------------------------------------+
void UpdateLine(string LineName, double Price, int Style=STYLE_SOLID, int Color=White)
  {
    ObjectSet(LineName,OBJPROP_STYLE,Style);
    ObjectSet(LineName,OBJPROP_COLOR,Color);
    ObjectSet(LineName,OBJPROP_PRICE1,Price);    
  }
  
//+------------------------------------------------------------------+
//| NewLine - creates a line object                                  |
//+------------------------------------------------------------------+
void NewLine(string LineName, double Price=0.00, int Style=STYLE_SOLID, int Color=White, int Window=0)
  {
    ObjectCreate(LineName,OBJ_HLINE,Window,0,Price);
    
    UpdateLine(LineName,Price,Style,Color);
  }

//+------------------------------------------------------------------+
//| UpdateRay                                                        |
//+------------------------------------------------------------------+
void UpdateRay(string RayName, double PriceStart, int BarStart, double PriceEnd, int BarEnd, int Style=STYLE_SOLID, int Color=White)
  {
    ObjectSet(RayName,OBJPROP_STYLE,Style);
    ObjectSet(RayName,OBJPROP_COLOR,Color);
    ObjectSet(RayName,OBJPROP_PRICE1,PriceStart);
    ObjectSet(RayName,OBJPROP_TIME1,Time[BarStart]);  
    ObjectSet(RayName,OBJPROP_PRICE2,PriceEnd);
    ObjectSet(RayName,OBJPROP_TIME2,Time[BarEnd]);  
  }
  
//+------------------------------------------------------------------+
//| NewRay - creates a ray object                                    |
//+------------------------------------------------------------------+
void NewRay(string RayName, bool ExtendRay=true, int Window=0)
  {
    ObjectCreate(RayName,OBJ_TREND,Window,0,0);
    ObjectSet(RayName,OBJPROP_RAY,ExtendRay);
  }

//+------------------------------------------------------------------+
//| UpdatePriceLabel                                                 |
//+------------------------------------------------------------------+
void UpdatePriceLabel(string PriceLabelName, double Price, int Color=White, int Bar=0)
  {
    ObjectSet(PriceLabelName,OBJPROP_COLOR,Color);
    ObjectSet(PriceLabelName,OBJPROP_PRICE1,Price);
    ObjectSet(PriceLabelName,OBJPROP_TIME1,Time[Bar]);
  }
  
//+------------------------------------------------------------------+
//| NewPriceLabel - creates a right price label object               |
//+------------------------------------------------------------------+
void NewPriceLabel(string PriceLabelName, double Price=0.00, bool Left=false, int Window=0)
  {
    if (Left)
      ObjectCreate(PriceLabelName,OBJ_ARROW_LEFT_PRICE,Window,0,Price);
    else
      ObjectCreate(PriceLabelName,OBJ_ARROW_RIGHT_PRICE,Window,0,Price);

    ObjectSet(PriceLabelName,OBJPROP_TIME1,Time[0]);
  }
  
//+------------------------------------------------------------------+
//| Flag - creates a right price label object                        |
//+------------------------------------------------------------------+
void Flag(string Name, int Color)
  {
    static int fIdx  = 0;

    fIdx++;
            
    ObjectCreate(Name+"-"+IntegerToString(fIdx),OBJ_ARROW_RIGHT_PRICE,0,Time[0],Close[0]);
    ObjectSet(Name+"-"+IntegerToString(fIdx),OBJPROP_COLOR,Color);
  }

//+------------------------------------------------------------------+
//| DrawBox - Draws a box used to frame text                         |
//+------------------------------------------------------------------+
void DrawBox(string Name, int PosX, int PosY, int Width, int Height, int Color, int Border, int WinId=0)
  {
    ObjectCreate(Name,OBJ_RECTANGLE_LABEL,WinId,0,0,0,0);
    ObjectSet(Name,OBJPROP_XDISTANCE,PosX);
    ObjectSet(Name,OBJPROP_YDISTANCE,PosY);
    ObjectSet(Name,OBJPROP_XSIZE,Width);
    ObjectSet(Name,OBJPROP_YSIZE,Height);
    ObjectSet(Name,OBJPROP_CORNER,SCREEN_UL);
    ObjectSet(Name,OBJPROP_STYLE, STYLE_SOLID);
    ObjectSet(Name,OBJPROP_BORDER_TYPE, Border);
    ObjectSet(Name,OBJPROP_BGCOLOR, Color);
    ObjectSet(Name,OBJPROP_BACK, true);
  }

//+------------------------------------------------------------------+
//| UpdateBox - Updates some box properties (wip)                    |
//+------------------------------------------------------------------+
void UpdateBox(string Name, color Color)
  {
      ObjectSet(Name,OBJPROP_BGCOLOR, Color);
  }
