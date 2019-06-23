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

//--- Fibo Defines
       enum     FiboFormat
                {
                  Unsigned,
                  Signed,
                  Extended
                };

       enum     FibonacciLevel
                {
                  FiboRoot,
                  Fibo23,
                  Fibo38,
                  Fibo50,
                  Fibo61,
                  Fibo100,
                  Fibo161,
                  Fibo261,
                  Fibo423,
                  Fibo823
                };                     


static const double FiboLevels[10] = {0.00,0.236,0.382,0.500,0.618,1.0,1.618,2.618,4.236,8.236};

//--- Common terminology; global constants

       enum     Operation
                {
                  Add,
                  Insert,
                  Update,
                  Delete
                };

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

       //--- Quantitative measure types
       enum     MeasureType
                { 
                  Net,
                  Total,                
                  Profit,
                  Loss,
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
                  Minor,  //---  Minor, Major
                  Major,  //--- Do Not Change ---//
                  All,
                  Next,
                  Last,
                  Previous,
                  Above,
                  Below,
                  Deviation,
                  Strength,
                  Mean,
                  MaxMean,
                  Peak,
                  MeanPeak,
                  Positive,
                  Negative,
                  MeanNegative,
                  MeanPositive,
                  Aggregate,
                  Amplitude,
                  FOCAmplitude,
                  FOCAmpMean,
                  StdDev,
                  OverBought,
                  OverSold,
                  Polyline,
                  PolyAmplitude,
                  Trendline,
                  Range,
                  RangeHigh,
                  RangeLow,
                  Boundary,
                  Price,
                  History,
                  Fibonacci,
                  Pivot,
                  Peg,
                  Origin,
                  OffSession,
                  Active,
                  State,
                  NoState,
                  Idle,
                  Retrace,
                  Reversal,
                  Breakout,
                  Rally,
                  Pullback,
                  Trap,
                  Support,
                  Resistance,
                  Recovery,
                  Contrarian,
                  Continuation,
                  Correction,
                  Global,
                  Scalp,
                  Build,
                  WordCount      //--- must be last
              };
              
       enum     SignalType
                {
                  Inactive,
                  Triggered,
                  Waiting,
                  Confirmed,
                  Rejected,
                  Broken,
                  SignalTypes
                };

       enum     RetraceType
                {
                  Trend,              //--- Pertaining to trend
                  Term,               //--- Pertaining to term
                  Prior,              //--- Last Base (shift) where Prior=Base; Base=Root, Root=Expansion, etc.
                  Base,               //--- Current fractal base
                  Root,               //--- Current fractal root
                  Expansion,          //--- Current fractal expansion
                  Divergent,          //--- Current Root retrace
                  Convergent,         //--- Current Root expansion after retrace
                  Inversion,          //--- Current Convergent retrace
                  Conversion,         //--- Current reversal retrace; trend resumption
                  Actual,             //--- Lead retrace - retrace on the major leg
                  RetraceTypes        //--- DO NOT REPOSITION -- used to report total count of enums
                };
  
//+------------------------------------------------------------------+
//| NewBar - detects a new bar                                       |
//+------------------------------------------------------------------+
bool NewBar(void)
  {
    static int    lastBars   = Bars;
    static double lastClose  = 0.00;

    if (Bars != lastBars)
    {
      if (lastClose == 0.00)
      {
        lastClose = Close[0];
        return (true);
      }
      
      lastBars++;
      lastClose = 0.00;
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| FiboExt - Converts signed fibos to extended                      |
//+------------------------------------------------------------------+
int FiboExt(int Level)
  {
    if (Level<0)
    {
      Level  = fabs(Level);
      
      if (Level<10)
        Level += 10;
    }

    return (Level);
  }

//+------------------------------------------------------------------+
//| FiboSign - Converts extended fibos to signed                     |
//+------------------------------------------------------------------+
int FiboSign(int Level)
  {
    if (Level>10)
      return ((Level-10)*DirectionInverse);

    return (Level);
  }

//+------------------------------------------------------------------+
//| FiboPrice - linear fibonacci price for the supplied level        |
//+------------------------------------------------------------------+
double FiboPrice(FibonacciLevel Level, double Base, double Root, int Method=Expansion)
  {
    if (Level == 0 || fabs(Level) == 10)
    {
      if (Method == Retrace)     
        return (NormalizeDouble(Base,Digits));
        
      return (NormalizeDouble(Root,Digits));
    }  

    if (Method == Retrace)     
      return (NormalizeDouble(Base-((Base-Root)*FiboPercent(Level)),Digits));

    return (NormalizeDouble(Root+((Base-Root)*FiboPercent(Level)),Digits));
  }

//+------------------------------------------------------------------+
//| FiboLevel - returns the level id for the supplied fibo value     |
//+------------------------------------------------------------------+
int FiboLevel(double Fibonacci, FiboFormat Format=Extended)
  {
    int    flFibo;
    
    for (flFibo=-Fibo823;flFibo<10;flFibo++)
      if (Fibonacci<FiboPercent(flFibo))
        break;

    if (Fibonacci<0.00)
      switch (Format)
      {
        case Unsigned:  flFibo = 0;
                        break;
        case Signed:    flFibo++;
                        break;
        case Extended:  if (flFibo != -Fibo823)
                          flFibo   = fabs(flFibo)+11;
      }
    else
      flFibo--;
    
    return(flFibo);
  }

//+------------------------------------------------------------------+
//| FiboPercent - returns the Fibo percent for the supplied level    |
//+------------------------------------------------------------------+
double FiboPercent(int Level, int Format=InPoints, bool Signed=true)
  {
    int fpSign = 1;
    
    if (Signed)
    {
      if (Level<0)
      {
        Level  = fabs(Level);
        fpSign = -1;
      }
      
      if (Level>10)
      {
        Level -= 10;
        fpSign = -1;
      }
    }
       
    if (Level>Fibo823)
      Level       = Fibo823;
      
    if (Format == InPoints)
      return (NormalizeDouble(FiboLevels[Level],3)*fpSign);
      
    return (NormalizeDouble(FiboLevels[Level]*100,1)*fpSign);
  }

//+------------------------------------------------------------------+
//| Pip - returns the normalized pip value in integer+1 form         |
//+------------------------------------------------------------------+
double Pip(double Value, int Type=InPips)
  {
    //--- Convert points into pips
    if (Type==InPips)
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
bool IsChanged(RetraceType &Check, RetraceType Compare, bool Update=true)
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
    double min = fmin(NormalizeDouble(Range1,Precision),NormalizeDouble(Range2,Precision));
    double max = fmax(NormalizeDouble(Range1,Precision),NormalizeDouble(Range2,Precision));

    if (Precision == 0)
      Precision  = Digits;
      
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
double BoolToDouble(bool IsTrue, double TrueValue, double FalseValue=0.00)
  {
    if (IsTrue)
      return (TrueValue);

    return (FalseValue);
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
      case InAction:      if (Value==OP_BUY)
                            Value        = DirectionUp*dContrarian;
                          else
                          if (Value==OP_SELL)
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
      case InAction:      if (Value==OP_BUY)
                            Value        = DirectionUp*dContrarian;
                          else
                          if (Value==OP_SELL)
                            Value        = DirectionDown*dContrarian;
                          else
                            Value        = DirectionNone;
    }
    
    if (IsLower(DirectionNone,Value))  return (DirectionUp);
    if (IsHigher(DirectionNone,Value)) return (DirectionDown);
    
    return (DirectionNone);
  }
