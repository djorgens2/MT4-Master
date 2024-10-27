//+------------------------------------------------------------------+
//|                                                      stdutil.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                               Standard Utilities |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property strict

#import "user32.dll"
   int MessageBoxW(int Ignore, string Caption, string Title, int Icon);
#import

//--- Standard diectional defines
#define DirectionPending     -2
#define DirectionDown        -1
#define NoDirection           0      //---No Direction
#define DirectionUp           1

//--- Null value defines
#define NoValue              -1

//--- additional op/action codes
#define NoAction             -1      //--- Updated Nomenclature
#define NoBias               -1      //--- New Nomen for Bias (Directional Action)

//--- Numeric format defines
#define InInteger             0      //--- Double conversion to int
#define InPercent             1      //--- Double conversion to int+1
#define InDecimal             2      //--- Return in decimal, raw calculation
#define InDollar              3      //--- Stated in dollars
#define InEquity              4      //--- Stated as a percent of equity
#define InDirection           5      //--- Stated as a Direction
#define InAction              6      //--- Stated as an Action
#define InState               7      //--- State definition

//--- logical defines
#define InTrueFalse          11      //--- Stated as True or False
#define InYesNo              12      //--- Stated as Yes or No
#define Always             true
#define Never             false

//--- Option type defs
#define InContrarian       true      //--- Return as contrarian direction/action
#define NoUpdate          false      //--- Return without update
#define On                 true      //--- Turn Feature On
#define Off               false      //--- Turn Feature Off

//---- Format Constants
#define IN_DIRECTION          8
#define IN_ACTION             9
#define IN_PROXIMITY         10
#define IN_DARK_DIR          11
#define IN_CHART_DIR         12
#define IN_CHART_ACTION      13
#define IN_DARK_PANEL        14

#define clrBoxOff    C'60,60,60'

//---- Screen Locations
#define SCREEN_UL             0
#define SCREEN_UR             1
#define SCREEN_LL             2
#define SCREEN_LR             3

//--- Global enums
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

enum YesNoType
     {
       Yes,
       No
     };

enum OutputFormat
     {
       Display,         // Formatted for Screen
       Logfile          // Formatted for Log
     };

//--- Quantitative measure types
enum SummaryType
     { 
       Loss,     //--
       Net,      //-- Hard Sequence
       Profit,   //-- ** DO NOT MODIFY
       Total,    //--            
       SummaryTypes
     };
             
enum MeasureType
     {
       Now,
       Min,    
       Max,    
       MeasureTypes      //--- must be last
     };

//-- Roles
enum RoleType
     {
       Buyer,           //-- Purchasing Manager
       Seller,          //-- Selling Manager
       Unassigned,      //-- No Manager
       RoleTypes
     };


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
//| rpad - right pads a value with the character and length supplied |
//+------------------------------------------------------------------+
string rpad(string Value, string Pad, int Length)
  {
    if (StringLen(Value)<Length)
      for (int idx=Length-StringLen(Value);idx>0;idx--)
        Value += Pad;
    
    return Value;
  }

//+------------------------------------------------------------------+
//| lpad - returns a numeric string padded for negative sign         |
//+------------------------------------------------------------------+
string lpad(double Value, int Precision, int Length=NoValue)
  {
    string text = BoolToStr(Value<0.00,""," ")+DoubleToString(Value,Precision);
    
    return lpad(text," ",fmax(StringLen(text),Length));
  }

//+------------------------------------------------------------------+
//| lpad - left pads a value with the character and length supplied  |
//+------------------------------------------------------------------+
string lpad(string Value, string Pad, int Length)
  {
    if (StringLen(Value)<Length)
      for (int idx=Length-StringLen(Value);idx>0;idx--)
        Value = Pad+Value;
    
    return Value;
  }

//+------------------------------------------------------------------+
//| quote - wraps text in double quotes                              |
//+------------------------------------------------------------------+
string quote(string Text)
  {
    return "\""+Text+"\"";
  }

//+------------------------------------------------------------------+
//| SplitStr - returns element count after parsing by supplied delim |
//+------------------------------------------------------------------+
int SplitStr(string Text, string Delim, string &Split[])
  {
    Text   = StringTrimLeft(StringTrimRight(Text));

    ArrayResize(Split,0,12);
    
    if (StringLen(Text)==0)
      return NoValue;
    
    if (StringFind(Text,Delim)==NoValue)
      Text = Text+Delim;

    if (StringSubstr(Text,StringLen(Text)-StringLen(Delim))!=Delim)
      Text = Text+Delim;
    
    while (StringLen(Text)>0)
    {
      ArrayResize(Split,ArraySize(Split)+1,12);

      if (StringSubstr(Text,0,1)=="\"")
      {
        if (StringFind(Text,"\"",1)==NoValue)
        {
          Print("Unterminated string");
          return NoValue;
        }
        
        if (StringSubstr(Text,StringFind(Text,"\"",1)+StringLen(Delim),StringLen(Delim))!=Delim)
        {
          Print("Malformed string; \""+StringSubstr(Text,StringFind(Text,"\"",1)+1,StringLen(Delim))+"\" <> \""+Delim+"\":"+Text);
          return NoValue;
        }
        
        Split[ArraySize(Split)-1] = StringSubstr(Text,1,StringFind(Text,"\"",1)-1);
        Text                      = StringSubstr(Text,StringLen(Split[ArraySize(Split)-1])+StringLen(Delim)+2);
      }
      else
      {
        Split[ArraySize(Split)-1] = upper(StringSubstr(Text,0,StringFind(Text,Delim)));
        Text                      = StringSubstr(Text,StringFind(Text,Delim)+StringLen(Delim));
      }
    }

    return ArraySize(Split);
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
//| RoleChanged - Sets role on change; filters OP_NO_ACTION          |
//+------------------------------------------------------------------+
bool RoleChanged(RoleType &Role, double Compare, int Type=InAction, bool Update=true)
  {
    int role           = Action(Compare,Type);

    if (role==NoAction||Role==(RoleType)role)
      return false;

    if (Update)
      Role             = (RoleType)role;
     
    return true;
  }

//+------------------------------------------------------------------+
//| ActionChanged - Sets action on change; filters OP_NO_ACTION      |
//+------------------------------------------------------------------+
bool ActionChanged(int &Change, int Compare, bool Update=true)
  {
    if (Compare==NoAction)
      return (false);
      
    return (IsChanged(Change,Compare,Update));
  }

//+------------------------------------------------------------------+
//| RoleChanged - Sets role on change with optional Unassigned's     |
//+------------------------------------------------------------------+
bool RoleChanged(RoleType &Change, RoleType Compare, bool AllowUnassigned=false, bool Update=true)
  {
    if (Change==Compare)
      return false;

    if (Compare==Unassigned)
      if (AllowUnassigned)
      {
        if (Update) Change = Unassigned;
        return true;
      }
      else return false;
      
    if (Update) Change = Compare;
    return true;
  }

//+------------------------------------------------------------------+
//| DirectionChanged - Sets direction on change; filters NoDirection |
//+------------------------------------------------------------------+
bool DirectionChanged(int &Change, int Compare, bool Update=true)
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

  return(lpad(outvalue," ",Length));
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
    case DirectionUp:      return("Long");
    case NoDirection:      return("Flat");
    case DirectionDown:    return("Short");
    case DirectionPending: return("Pending");
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
    case IN_PROXIMITY:     if (IsEqual(Value,0.00))       return(clrDarkGray);
                           if (Close[0]>Value+point(6))   return(clrLawnGreen);
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
//| Append - appends text string to supplied string with separator   |
//+------------------------------------------------------------------+
void Append(string &Source, string Text, string Separator=" ")
  {
    if (StringLen(Source)>0 && StringLen(Text)>0)
      Source += Separator;
      
    Source += Text;
  }

//+------------------------------------------------------------------+
//| InStr - Returns true if pattern is found in source string        |
//+------------------------------------------------------------------+
bool InStr(string Source, string Search, int MinLen=1)
  {
    if (StringLen(Search)>=MinLen)
      if (StringSubstr(Source,StringFind(Source,Search),StringLen(Search))==Search)
        return (true);
     
    return (false);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(datetime &Check, datetime Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
  
    if (Update)
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(string &Check, string Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
  
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(double &Check, double Compare, bool Update=true, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;

    if (NormalizeDouble(Check,Precision) == NormalizeDouble(Compare,Precision))
      return (false);
  
    if (Update) 
      Check   = NormalizeDouble(Compare,Precision);
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(double &Check, double Compare, double &Variance, bool Update=true, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;
      
    Variance   = 0.00;

    if (IsChanged(Variance,Compare-Check,true,Precision))
    {  
      Check    = BoolToDouble(Update,Compare,Check,Precision);
      return (true);
    }
  
    return (false);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(int &Check, int Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
   
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(bool &Check, bool Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
   
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(uchar &Check, uchar Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
   
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsBetween - returns true if supplied value in supplied range     |
//+------------------------------------------------------------------+
bool IsBetween(double Check, double Range1, double Range2, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;
          
    if (NormalizeDouble(Check,Precision) >= NormalizeDouble(fmin(Range1,Range2),Precision))
      if (NormalizeDouble(Check,Precision) <= NormalizeDouble(fmax(Range1,Range2),Precision))
        return true;
     
    return false;
  }

//+------------------------------------------------------------------+
//| IsEqual - returns true if the values are equal                   |
//+------------------------------------------------------------------+
bool IsEqual(double Value1, double Value2, int Precision=0)
  {
    if (Precision == 0)
      Precision    = Digits;
      
    if (NormalizeDouble(Value1,Precision) == NormalizeDouble(Value2,Precision))
      return (true);
     
    return (false);
  }

//+------------------------------------------------------------------+
//| trim - Returns string removed of leading/trailing blanks         |
//+------------------------------------------------------------------+
string trim(string Text)
  {
    return StringTrimLeft(StringTrimRight(Text));
  }

//+------------------------------------------------------------------+
//| IsLower - returns true if compare value lower than check         |
//+------------------------------------------------------------------+
bool IsLower(double Compare, double &Check, bool Update=true, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;
      
    if (NormalizeDouble(Compare,Precision) < NormalizeDouble(Check,Precision))
    {
      if (Update)
        Check    = NormalizeDouble(Compare,Precision);

      return (true);
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| IsHigher - returns true if compare value higher than check       |
//+------------------------------------------------------------------+
bool IsHigher(double Compare, double &Check, bool Update=true, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;
      
    if (NormalizeDouble(Compare,Precision) > NormalizeDouble(Check,Precision))
    {    
      if (Update)
        Check    = NormalizeDouble(Compare,Precision);
        
      return (true);
    }
    return (false);
  }

//+------------------------------------------------------------------+
//| IsHigher - returns true if compare value higher than check       |
//+------------------------------------------------------------------+
bool IsHigher(datetime Compare, datetime &Check, bool Update=true)
  {
    if (Compare>Check)
    {    
      if (Update)
        Check    = Compare;
        
      return (true);
    }
    return (false);
  }

//+------------------------------------------------------------------+
//| fdiv - returns the result of the division of 2 double values     |
//+------------------------------------------------------------------+
double fdiv(double Dividend, double Divisor, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;
      
    if (!IsEqual(Divisor,0.00,Precision))
      return (NormalizeDouble(Dividend/Divisor,Precision));

    return (NormalizeDouble(0.00,Precision));
  }

//+------------------------------------------------------------------+
//| BoolToDate - returns the datetime of a user-defined condition    |
//+------------------------------------------------------------------+
datetime BoolToDate(bool IsTrue, datetime TrueValue, datetime FalseValue)
  {
    if (IsTrue)
      return (TrueValue);

    return (FalseValue);
  }

//+------------------------------------------------------------------+
//| BoolToStr - returns the text description for the supplied value  |
//+------------------------------------------------------------------+
string BoolToStr(bool IsTrue, int Format=InTrueFalse)
  {
    switch (Format)
    {
      case InTrueFalse: if (IsTrue)
                          return ("True");
                        else
                          return ("False");
      case InYesNo:     if (IsTrue)
                          return ("Yes");
                        else
                          return ("No");
    }

    return ("Bad Boolean Format Type");
  }

//+------------------------------------------------------------------+
//| BoolToStr - returns user defined text for the supplied value     |
//+------------------------------------------------------------------+
string BoolToStr(bool IsTrue, string TrueValue, string FalseValue="")
  {
    if (IsTrue)
      return (TrueValue);

    return (FalseValue);
  }

//+------------------------------------------------------------------+
//| BoolToInt - returns user defined int for the supplied value      |
//+------------------------------------------------------------------+
int BoolToInt(bool IsTrue, int TrueValue, int FalseValue=0)
  {
    if (IsTrue)
      return (TrueValue);

    return (FalseValue);
  }

//+------------------------------------------------------------------+
//| BoolToDouble - returns user defined double for supplied value    |
//+------------------------------------------------------------------+
double BoolToDouble(bool IsTrue, double TrueValue, double FalseValue=0.00, int Precision=12)
  {
    if (IsTrue)
      return (NormalizeDouble(TrueValue,Precision));

    return (NormalizeDouble(FalseValue,Precision));
  }

//+------------------------------------------------------------------+
//| Coalesce - returns first non-zero value                          |
//+------------------------------------------------------------------+
double coalesce(double v1, double v2, double v3=0.00, double v4=0.00, double v5=0.00)
  {
    if (v1==0.00)
      if (v2==0.00)
        if (v3==0.00)
          if (v4==0.00)
            return(v5);
          else
            return (v4);
        else
          return (v3);
      else
        return (v2);

    return (v1);
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
//| UpdateText                                                       |
//+------------------------------------------------------------------+
void UpdateText(string Name, string Text, double Price, int Bar=NoValue, int Color=NoValue, int Size=NoValue, string Font="")
  {
    Text     = BoolToStr(Text=="",ObjectGetString(0,Name,OBJPROP_TEXT),Text);
    Color    = BoolToInt(Color==NoValue,(int)ObjectGetInteger(0,Name,OBJPROP_COLOR),Color);
    Size     = BoolToInt(Size==NoValue,(int)ObjectGetInteger(0,Name,OBJPROP_FONTSIZE),Size);
    Font     = BoolToStr(Font=="",ObjectGetString(0,Name,OBJPROP_FONT),Font);

    ObjectSet(Name,OBJPROP_PRICE1,Price);
    ObjectSet(Name,OBJPROP_TIME1,BoolToDate(Bar<0,Time[0]+(Period()*fabs(Bar)*60),Time[fmin(Bars-1,fmax(Bar,0))]));
    ObjectSetText(Name,Text,Size,Font,Color);
  }
  
//+------------------------------------------------------------------+
//| NewText                                                         |
//+------------------------------------------------------------------+
void NewText(string Name, string Text, int Color=White, int Size=8, string Font="Tahoma")
  {
    ObjectCreate(Name,OBJ_TEXT,0,0,0);
    ObjectSetText(Name,Text,Size,Font,Color);
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
void UpdateRay(string RayName, int BarStart, double PriceStart, int BarEnd=0, double PriceEnd=0.00, int Color=NoValue)
  {
    ObjectSet(RayName,OBJPROP_PRICE1,PriceStart);
    ObjectSet(RayName,OBJPROP_PRICE2,BoolToDouble(IsEqual(PriceEnd,0.00),PriceStart,PriceEnd,Digits));
    
    ObjectSet(RayName,OBJPROP_TIME1,Time[BarStart]);
    ObjectSet(RayName,OBJPROP_TIME2,BoolToDate(BarEnd<0,Time[0]+(Period()*fabs(BarEnd)*60),Time[fmin(Bars-1,fmax(BarEnd,0))]));
    
    if (Color>NoValue)
      ObjectSet(RayName,OBJPROP_COLOR,Color);
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
//|                                                                  |
//+------------------------------------------------------------------+
void RemoveChartObjects(string Key)
  {
    //-- Clean Open Chart Objects
    int object             = 0;
    
    while (object<ObjectsTotal())
      if (InStr(ObjectName(object),Key))
        ObjectDelete(ObjectName(object));
      else object++;
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
