//+------------------------------------------------------------------+
//|                                                      stdutil.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property strict

//+------------------------------------------------------------------+
//| constants                                                        |
//+------------------------------------------------------------------+

//--- additional arrowcodes
#define SYMBOL_DASH           4
#define SYMBOL_ROOT           128
#define SYMBOL_POINT1         129
#define SYMBOL_POINT2         130
#define SYMBOL_POINT3         131
#define SYMBOL_POINT4         132
#define SYMBOL_POINT5         133
#define SYMBOL_POINT6         134


//--- Standard diectional defines
#define DirectionDown        -1
#define DirectionNone         0
#define DirectionUp           1
#define DirectionInverse     -1
#define DirectionChange      -2


//--- Null value defines
#define NoValue              -1

//--- Numeric format defines
#define InInteger             0      //--- Double conversion to int
#define InPoints              1      //--- Integer conversion to points
#define InPips                2      //--- Double conversion to int+1
#define InPercent             3      //--- Double conversion to int+1
#define InDecimal             4      //--- Return in decimal, raw calculation
#define InDollar              5      //--- Stated in dollars
#define InEquity              6      //--- Stated as a percent of equity
#define InMargin              7      //--- Stated as a value of margin
#define InDirection           8      //--- Stated as a Direction
#define InAction              9      //--- Stated as an Action
#define InState              10      //--- State definition

//--- Boolean format defines
#define InTrueFalse          11      //--- Stated as True or False
#define InYesNo              12      //--- Stated as Yes or No

//--- String format defines
#define InUpper              13      //--- Returns in Upper
#define InLower              14      //--- Returns in Lower
#define InProper             15      //--- Returns in Proper

//--- Option type defs
#define InContrarian       true      //--- Return as contrarian direction/action
#define NoUpdate          false      //--- Return without update

//--- Common terminology; global constants

       enum     OnOffType
                {
                  On,
                  Off
                };

       enum     YesNoType
                {
                  Yes,
                  No
                };

       //---- Close Options
       enum CloseOptions
            {
              CloseNone,          // Hold All
              CloseAll,           // Close All
              CloseMin,           // Close Worst
              CloseMax,           // Close Best
              CloseHalf,          // Close Half (All)
              CloseProfit,        // Close Profit
              CloseLoss,          // Close Losses
              CloseConditional,   // Close Conditionally
              CloseFIFO,          // FIFO Close
              NoCloseOption = -1  // No Close Option
            };

       //--- Quantitative measure types
       enum     MeasureType
                { 
                  Loss,     //--
                  Net,      //-- Hard Sequence
                  Profit,   //-- ** DO NOT MODIFY
                  Total,    //--            
                  Lowest,
                  Highest,
                  Smallest,
                  Largest,
                  Count,
                  MeasureTypes
                };
                
       //--- Numbered position measure types
       enum     PositionType
                { 
                  None,
                  First,
                  Second,                
                  Third,
                  Fourth,
                  Fifth,
                  Sixth,
                  Seventh,
                  Eighth,
                  Ninth,
                  Tenth,
                  PositionTypes
                };

       enum     ReservedWords
                {
                  Default,
                  Size,
                  Dominant,
                  Direction,
                  Bar,
                  Age,
                  Level,
                  Top,
                  Bottom,
                  Mid,
                  Head,
                  Tail,
                  Now,
                  Tick,   //--- Mandatory sequence
                  Min,    //--- Tick, Min, Max,
                  Max,    //
                  All,
                  Next,
                  Last,
                  Previous,
                  Above,
                  Below,
                  Higher,
                  Lower,
                  AtRisk,
                  Deviation,
                  Mean,
                  Positive,
                  Negative,
                  Aggregate,
                  StdDev,
                  OverBought,
                  OverSold,
                  Decay,
                  Crest,
                  Trough,
                  PolyTrend,
                  Polyline,
                  Trendline,
                  Range,
                  RangeHigh,
                  RangeLow,
                  Boundary,
                  Price,
                  History,
                  Forecast,
                  Pivot,
                  Peg,
                  Active,
                  State,
                  NoState,
                  Retrace,
                  Reversal,
                  Breakout,
                  Rally,
                  Pullback,
                  Recovery,
                  Correction,
                  Trap,
                  Resume,
                  Master,
                  Support,
                  Resistance,
                  Contrarian,
                  WordCount      //--- must be last
              };

//+------------------------------------------------------------------+
//| BarDir - Returns the bar direction for the supplied bar          |
//+------------------------------------------------------------------+
int BarDir(int Bar=0)
  {
    // Need to work this for inside bars...
    static int bdDir   = DirectionNone;
    
    if (Bar<Bars-1)
    {
      if (NormalizeDouble(Close[Bar],Digits)>NormalizeDouble(High[Bar+1],Digits))
        bdDir          = DirectionUp;
        
      if (NormalizeDouble(Close[Bar],Digits)<NormalizeDouble(Low[Bar+1],Digits))
        bdDir          = DirectionDown;
    }
    
    return (bdDir);
  }

//+------------------------------------------------------------------+
//| Pip - returns the normalized pip value in integer+1 form         |
//+------------------------------------------------------------------+
double Pip(double Value, int Format=InPips)
  {
    //--- Convert points into pips
    if (Format==InPips)
      return (NormalizeDouble(Value*pow(10, Digits-1),1));

    //--- Convert pips into points
    return (NormalizeDouble(Value / pow(10, Digits-1), Digits));
  }

//+------------------------------------------------------------------+
//| Spread - returns current Bid/Ask spread                          |
//+------------------------------------------------------------------+
double Spread(int Format=InPoints)
  {
    if (Format == InPips)
      return (NormalizeDouble(Pip(Ask-Bid),1));
    
    if (Format == InPoints)
      return (NormalizeDouble(Ask-Bid,Digits));
      
    return (NoValue);
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
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(ReservedWords &Check, ReservedWords Compare, bool Update=true)
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
    double min;
    double max;

    if (Precision == 0)
      Precision  = Digits;

    min = fmin(NormalizeDouble(Range1,Precision),NormalizeDouble(Range2,Precision));
    max = fmax(NormalizeDouble(Range1,Precision),NormalizeDouble(Range2,Precision));
          
    if (NormalizeDouble(Check,Precision) >= NormalizeDouble(min,Precision))
      if (NormalizeDouble(Check,Precision) <= NormalizeDouble(max,Precision))
        return (true);
     
    return (false);
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
//| lpad - left pads a value with the character and length supplied  |
//+------------------------------------------------------------------+
string lpad(string Value, string Pad, int Length)
  {
    if (StringLen(Value)<Length)
      for (int idx=Length-StringLen(Value);idx>0;idx--)
        Value = Pad+Value;
    
    return (Value);
  }

//+------------------------------------------------------------------+
//| Swap - swaps one double value for the other with precision       |
//+------------------------------------------------------------------+
void Swap(double &Value1, double &Value2, int Precision=0.00)
  {
    double swap   = Value1;
    
    if (Precision == 0)
      Precision  = Digits;
      
    Value1        = NormalizeDouble(Value2,Precision);
    Value2        = NormalizeDouble(swap,Precision);
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
//| BoolToDT - returns the datetime of a user-defined condition      |
//+------------------------------------------------------------------+
datetime BoolToDT(bool IsTrue, datetime TrueValue, datetime FalseValue)
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
//| BoolToWord - Returns a qualified Reserved Word based on a query  |
//+------------------------------------------------------------------+
ReservedWords BoolToWord(bool IsTrue, ReservedWords TrueValue, ReservedWords FalseValue=0)
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
double Coalesce(double El1, double El2, double El3=0.00, double El4=0.00)
  {
    if (El1==0.00)
      if (El2==0.00)
        if (El3==0.00)
          return (El4);
        else
          return (El3);
      else
        return (El2);

    return (El1);
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
//| Operation - translates Pending Order Types to Market Actions      |
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
    const int NoAction        = 0;
    const int dInverseState   = 3;
    int       dContrarian     = BoolToInt(Contrarian,-1,1);
    
    switch (ValueType)
    {
      case InDirection:   Value         *= dContrarian;
                          break;
      case InState:       if (fabs(Value)<dInverseState)
                            Value        = DirectionNone;
                          else
                            Value       *= dContrarian;
                          break;
      case InAction:      if (Value==OP_BUY||Value==OP_BUYLIMIT||Value==OP_BUYSTOP)
                            Value        = DirectionUp*dContrarian;
                          else
                          if (Value==OP_SELL||Value==OP_SELLLIMIT||Value==OP_SELLSTOP)
                            Value        = DirectionDown*dContrarian;
                          else
                            Value        = DirectionNone;
    }
    
    if (IsLower(DirectionNone,Value))  return (OP_BUY);
    if (IsHigher(DirectionNone,Value)) return (OP_SELL);
    
    return (NoAction);
  }

//+------------------------------------------------------------------+
//| Direction - order action translates into price direction         |
//+------------------------------------------------------------------+
int Direction(double Value, int ValueType=InDirection, bool Contrarian=false)
  {
    const int NoAction        = 0;
    const int dInverseState   = 3;
    int       dContrarian     = BoolToInt(Contrarian,-1,1);
    
    switch (ValueType)
    {
      case InDirection:   Value         *= dContrarian;
                          break;
      case InState:       if (fabs(Value)<dInverseState)
                            Value        = DirectionNone;
                          else
                            Value       *= dContrarian;
                          break;
      case InAction:      if (Value==OP_BUY||Value==OP_BUYLIMIT||Value==OP_BUYSTOP)
                            Value        = DirectionUp*dContrarian;
                          else
                          if (Value==OP_SELL||Value==OP_SELLLIMIT||Value==OP_SELLSTOP)
                            Value        = DirectionDown*dContrarian;
                          else
                            Value        = DirectionNone;
    }
    
    if (IsLower(DirectionNone,Value))  return (DirectionUp);
    if (IsHigher(DirectionNone,Value)) return (DirectionDown);
    
    return (DirectionNone);
  }
