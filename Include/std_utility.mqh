//+------------------------------------------------------------------+
//|                                                  std_utility.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                        2023 (Deprecated) Merged into stdutil.mqh |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

#import "user32.dll"
   int MessageBoxW(int Ignore, string Caption, string Title, int Icon);
#import

//--- logical defines
#define Always              true

//--- additional op/action codes
#define NoAction              -1  //--- Updated Nomenclature
#define NoBias                -1  //--- New Nomen for Bias (Directional Action)
#define NoDirection            0  //--- New Nomen for DirectionNone

//---- Format Constants
#define IN_DIRECTION           8
#define IN_ACTION              9
#define IN_PROXIMITY          10
#define IN_DARK_DIR           11
#define IN_CHART_DIR          12
#define IN_CHART_ACTION       13
#define IN_DARK_PANEL         14

#define clrBoxOff             C'60,60,60'

//---- Screen Locations
#define SCREEN_UL              0
#define SCREEN_UR              1
#define SCREEN_LL              2
#define SCREEN_LR              3

enum ArrowType
     {
       ArrowUp       = SYMBOL_ARROWUP,
       ArrowDown     = SYMBOL_ARROWDOWN,
       ArrowDash     = 4,
       ArrowHold     = 73,
       ArrowCheck    = SYMBOL_CHECKSIGN,
       ArrowStop     = SYMBOL_STOPSIGN,
       ArrowHalt     = 78
     };

enum StyleType
     {
       Wide,
       Narrow,
       StyleTypes
     };

enum GammaType
     {
       Bright,
       Dark
     };

const color          AsiaColor       = C'0,32,0';    // Asia session box color
const color          EuropeColor     = C'48,0,0';    // Europe session box color
const color          USColor         = C'0,0,56';    // US session box color
const color          DailyColor      = C'64,64,0';   // US session box color

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
//| InStr - Returns true if pattern is found in source string        |
//+------------------------------------------------------------------+
bool InStr(string Source, string Search)
  {
    if (Search!="")
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
//| Operation - translates Pending Order Types to Market Actions     |
//+------------------------------------------------------------------+
int Operation(int Action, bool Contrarian=false)
  {
    if (IsEqual(Action,OP_BUY)||IsEqual(Action,OP_BUYLIMIT)||IsEqual(Action,OP_BUYSTOP))
      return (BoolToInt(Contrarian,OP_SELL,OP_BUY));

    if (IsEqual(Action,OP_SELL)||IsEqual(Action,OP_SELLLIMIT)||IsEqual(Action,OP_SELLSTOP))
      return (BoolToInt(Contrarian,OP_BUY,OP_SELL));
    
    return (NoValue);  //-- << clean up for another day
  }

//+------------------------------------------------------------------+
//| Action - translates price direction into order action            |
//+------------------------------------------------------------------+
int Action(double Value, int ValueType=InDirection, bool Contrarian=false)
  {
    const int dInverseState   = 3;
    int       dContrarian     = BoolToInt(Contrarian,-1,1);
    
    switch (ValueType)
    {
      case InDirection:   Value         *= dContrarian;
                          break;

      case InAction:      if (Value==OP_BUY||Value==OP_BUYLIMIT||Value==OP_BUYSTOP)
                            Value        = DirectionUp*dContrarian;
                          else
                          if (Value==OP_SELL||Value==OP_SELLLIMIT||Value==OP_SELLSTOP)
                            Value        = DirectionDown*dContrarian;
                          else
                            Value        = NoDirection;
    }
    
    if (IsLower(NoDirection,Value))  return (OP_BUY);
    if (IsHigher(NoDirection,Value)) return (OP_SELL);
    
    return (NoAction);
  }

//+------------------------------------------------------------------+
//| Direction - order action translates into price direction         |
//+------------------------------------------------------------------+
int Direction(double Value, int ValueType=InDirection, bool Contrarian=false)
  {
    const int dInverseState   = 3;
    int       dContrarian     = BoolToInt(Contrarian,-1,1);
    
    switch (ValueType)
    {
      case InDirection:   Value         *= dContrarian;
                          break;
      case InAction:      if (Value==OP_BUY||Value==OP_BUYLIMIT||Value==OP_BUYSTOP)
                            Value        = DirectionUp*dContrarian;
                          else
                          if (Value==OP_SELL||Value==OP_SELLLIMIT||Value==OP_SELLSTOP)
                            Value        = DirectionDown*dContrarian;
                          else
                            Value        = NoDirection;
    }
    
    if (IsLower(NoDirection,Value,false,8))  return (DirectionUp);
    if (IsHigher(NoDirection,Value,false,8)) return (DirectionDown);
    
    return (NoDirection);
  }

//+------------------------------------------------------------------+
//| ActionText - returns the text of an ActionCode                   |
//+------------------------------------------------------------------+
string ActionText(int Action)
  {
    switch (Action)
    {
      case OP_BUY           : return("BUY");
      case OP_BUYLIMIT      : return("BUY LIMIT");
      case OP_BUYSTOP       : return("BUY STOP");
      case OP_SELL          : return("SELL");
      case OP_SELLLIMIT     : return("SELL LIMIT");
      case OP_SELLSTOP      : return("SELL STOP");
      case NoAction         : return("NO ACTION");
      default               : return("BAD ACTION CODE");
    }
  }

//+------------------------------------------------------------------+
//| NewAction - Updates Action on change; filters OP_NO_ACTION       |
//+------------------------------------------------------------------+
bool NewAction(int &Change, int Compare, bool Update=true)
  {
    if (Compare==NoAction)
      return (false);
      
    return (IsChanged(Change,Compare,Update));
  }

//+------------------------------------------------------------------+
//| NewDirection - Updates Direction on change;filters NoDirection   |
//+------------------------------------------------------------------+
bool NewDirection(int &Change, int Compare, bool Update=true)
  {
    if (IsBetween(Compare,DirectionUp,DirectionDown))
    {
      if (Compare==NoDirection)
        return (false);
    }
    else return (false);
      
    if (Change==NoDirection)
      if (IsChanged(Change,Compare,Update))
        return (false);
    
    return (IsChanged(Change,Compare,Update));
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
double point(double Value, int Precision=0)
  {
    return (NormalizeDouble(Value/pow(10,Digits-1),BoolToInt(IsEqual(Precision,0),Digits,Precision)));
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
//| dollar - returns dollar formatted string by pad/precision        |
//+------------------------------------------------------------------+
string dollar(double Value, int Length, bool WithCents=false)
{
  int    precision   = BoolToInt(WithCents,2,0);
  int    scale       = 0;
  string invalue     = DoubleToStr(fabs(Value),0);
  string outvalue    = "";

  for (int pos=StringLen(invalue);pos>0;pos--)
    if (fmod(scale++,3)==0&&scale>1)
      outvalue       = StringSubstr(invalue,pos-1,1)+","+outvalue;
    else
      outvalue       =  StringSubstr(invalue,pos-1,1)+outvalue;

  if (Value<0)
    outvalue         = "-"+outvalue;

  return(LPad(outvalue," ",Length));
}

//+------------------------------------------------------------------+
//| center - center a string                                         |
//+------------------------------------------------------------------+
string center(string Text, int Length, string Filler=" ")
{
  string text    = "";
  double pad     = BoolToDouble(StringLen(Text)<Length,fdiv(Length-StringLen(Text),2),0,2);

  for (int pos=0;pos<pad;pos++)
    text        += Filler;
  
  return text+" "+Text+" "+text;
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
string DirText(int Direction, bool Contrarian=false)
{
  if (Contrarian)
    Direction *= NoValue;
    
  switch (Direction)
  {
    case DirectionUp:    return("Long");
    case NoDirection:    return("Flat");
    case DirectionDown:  return("Short");
//    case NewDirection:   return("Pending");
    case -2:   return("Pending");
  }

  return("BAD DIRECTION CODE");
}

//+------------------------------------------------------------------+
//| Color - returns the color based on the supplied Value            |
//+------------------------------------------------------------------+
color Color(double Value, int Method=IN_DIRECTION, bool Contrarian=false)
{
  if (Contrarian)
    Value       *= -1.0;  
  
  switch (Method)
  {
    case IN_PROXIMITY:     if (Close[0]>Value+point(6))   return(clrLawnGreen);
                           if (Close[0]>Value+point(3))   return(clrYellowGreen);
                           if (Close[0]>Value+point(0.2)) return(clrMediumSeaGreen);
                           if (Close[0]>Value-point(0.2)) return(clrYellow);
                           if (Close[0]>Value-point(3))   return(clrGoldenrod);
                           if (Close[0]>Value-point(6))   return(clrChocolate);
                           return (clrRed);
    case IN_DIRECTION:     if (Value<0.00) return (clrRed);
                           if (Value>0.00) return (clrLawnGreen);
    case IN_DARK_DIR:      if (Value<0.00) return (clrMaroon);
                           if (Value>0.00) return (clrDarkGreen);
    case IN_CHART_DIR:     if (Value<0.00) return (clrRed);
                           if (Value>0.00) return (clrYellow);
                           return (clrDarkGray);
    case IN_DARK_PANEL:    if (Value<0.00) return (C'42,0,0');
                           if (Value>0.00) return (C'0,42,0');
                           return (clrDarkGray);
    case IN_ACTION:        if (Action(Value,InAction)==OP_BUY)  return (clrLawnGreen);
                           if (Action(Value,InAction)==OP_SELL) return (clrRed);
                           return (clrYellow);
    case IN_CHART_ACTION:  if (Action(Value,InAction)==OP_BUY)  return (clrYellow);
                           if (Action(Value,InAction)==OP_SELL) return (clrRed);
  }
  
  return (clrDarkGray);
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
//| Arrow - paints an arrow on the chart in the price area           |
//+------------------------------------------------------------------+
void Arrow(string ArrowName, ArrowType Type, int Color, int Bar=0, double Price=0.00, int Window=0)
  {      
    if (Bar>NoValue)
    {
      if (Price==0.00)
        Price = Close[Bar];

      ObjectDelete (ArrowName);
      ObjectCreate (ArrowName, OBJ_ARROW, Window, Time[Bar], Price);
      ObjectSet    (ArrowName, OBJPROP_ARROWCODE, Type);
      ObjectSet    (ArrowName, OBJPROP_COLOR,Color);
    }
  }

//+------------------------------------------------------------------+
//| New Arrow - paints an arrow by Direction                         |
//+------------------------------------------------------------------+
void Arrow(string ArrowName, int Direction, int Color, int Bar=0, double Price=0.00)
  {      
    Arrow(ArrowName,
         (ArrowType)BoolToInt(IsEqual(Direction,DirectionUp),ArrowUp,
                    BoolToInt(IsEqual(Direction,DirectionDown),ArrowDown,ArrowHold)),
          Color,
          Bar,
          Price);
  }

//+------------------------------------------------------------------+
//| UpdateDirection - creates an arrow label to show indicator value |
//+------------------------------------------------------------------+
void UpdateDirection(string LabelName, int Direction, int Color=0, int Size=10, StyleType Style=Wide)
  { 
    if (Color == 0)
      Color = (int)ObjectGet(LabelName,OBJPROP_COLOR);
              
    switch (Style)
    {
      case Wide:    if (Direction > 0)
                      ObjectSetText(LabelName,CharToStr(241),Size,"Wingdings",Color);
                    else
                    if (Direction < 0)
                      ObjectSetText(LabelName,CharToStr(242),Size,"Wingdings",Color);
                    else
                      ObjectSetText(LabelName,CharToStr(73), Size,"Wingdings",Color);
                    break;

      case Narrow:  if (Direction > 0)
                      ObjectSetText(LabelName,CharToStr(225),Size,"Wingdings",Color);
                    else
                    if (Direction < 0)
                      ObjectSetText(LabelName,CharToStr(226),Size,"Wingdings",Color);
                    else
                      ObjectSetText(LabelName,CharToStr(73), Size,"Wingdings",Color);
                    break;
    }
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
//| UpdatePriceTag                                                   |
//+------------------------------------------------------------------+
void UpdatePriceTag(string PriceTagName, int Bar, int Direction, int Up=12, int Down=8)
  {
    if (Bar<0 || Bar>Bars)
      return;
      
    if (Direction==DirectionUp)
      ObjectSet(PriceTagName,OBJPROP_PRICE1,High[Bar]+point(Up));
    else
    
    if (Direction==DirectionDown)
      ObjectSet(PriceTagName,OBJPROP_PRICE1,Low[Bar]-point(Down));

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
void UpdateRay(string RayName, double PriceStart, int BarStart, double PriceEnd=0.00, int BarEnd=0)
  {
    ObjectSet(RayName,OBJPROP_PRICE1,PriceStart);
    ObjectSet(RayName,OBJPROP_PRICE2,BoolToDouble(IsEqual(PriceEnd,0.00),PriceStart,PriceEnd,Digits));
    
    ObjectSet(RayName,OBJPROP_TIME1,Time[BarStart]);
    ObjectSet(RayName,OBJPROP_TIME2,Time[BarEnd]);
  }
  
//+------------------------------------------------------------------+
//| NewRay - creates a ray object                                    |
//+------------------------------------------------------------------+
void NewRay(string RayName, int Style=STYLE_SOLID, int Color=clrWhite, bool Extend=true, int Window=0)
  {
    ObjectCreate(RayName,OBJ_TREND,Window,0,0);
    ObjectSet(RayName,OBJPROP_RAY,Extend);
    ObjectSet(RayName,OBJPROP_WIDTH,1);
    ObjectSet(RayName,OBJPROP_STYLE,Style);
    ObjectSet(RayName,OBJPROP_COLOR,Color);
  }

//+------------------------------------------------------------------+
//| UpdatePriceLabel                                                 |
//+------------------------------------------------------------------+
void UpdatePriceLabel(string PriceLabelName, double Price, int Color=White, int Bar=0)
  {
    ObjectSet(PriceLabelName,OBJPROP_COLOR,Color);
    ObjectSet(PriceLabelName,OBJPROP_PRICE1,Price);
    ObjectSet(PriceLabelName,OBJPROP_TIME1,BoolToDate(Bar<0,Time[0]+(fabs(Bar)*(Period()*60)),Time[fabs(Bar)]));
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
void Flag(string Name, int Color, int Bar=0, double Price=0.00, bool ShowFlag=Always, int Style=OBJ_ARROW_RIGHT_PRICE)
  {
    static int fIdx  = 0;
    
    if (ShowFlag)
    {
      while (!ObjectCreate(Name+"-"+(string)fIdx,Style,0,Time[Bar],BoolToDouble(IsEqual(Price,0.00),Close[Bar],Price)))
        if (GetLastError()==4200) //-- Object Exists
          fIdx++;
        else
          break;

      ObjectSet(Name+"-"+IntegerToString(fIdx),OBJPROP_COLOR,Color);
    }
  }

//+------------------------------------------------------------------+
//| PrintF - Prints to log based on value of Condition               |
//+------------------------------------------------------------------+
void PrintF(string Text, bool Condition)
{
  if (Condition)
    Print(Text);
}

//+------------------------------------------------------------------+
//| DrawBox - Draws a box used to frame text                         |
//+------------------------------------------------------------------+
void DrawBox(string Name, int PosX, int PosY, int Width, int Height, int Color, int Border, int Corner=SCREEN_UL, int WinId=0)
  {
    ObjectCreate(Name,OBJ_RECTANGLE_LABEL,WinId,0,0,0,0);
    ObjectSet(Name,OBJPROP_XDISTANCE,PosX);
    ObjectSet(Name,OBJPROP_YDISTANCE,PosY);
    ObjectSet(Name,OBJPROP_XSIZE,Width);
    ObjectSet(Name,OBJPROP_YSIZE,Height);
    ObjectSet(Name,OBJPROP_CORNER,Corner);
    ObjectSet(Name,OBJPROP_STYLE,STYLE_SOLID);
    ObjectSet(Name,OBJPROP_BORDER_TYPE,Border);
    ObjectSet(Name,OBJPROP_BGCOLOR,Color);
    ObjectSet(Name,OBJPROP_BACK,true);
  }

//+------------------------------------------------------------------+
//| UpdateBox - Updates some box properties (wip)                    |
//+------------------------------------------------------------------+
void UpdateBox(string Name, color Color)
  {
      ObjectSet(Name,OBJPROP_BGCOLOR,Color);
      ObjectSet(Name,OBJPROP_BORDER_COLOR,clrGold);
  }
