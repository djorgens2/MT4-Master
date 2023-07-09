//+------------------------------------------------------------------+
//|                                                      Session.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "6.01"
#property strict

#include <fractal_lib.mqh>
#include <Class/Event.mqh>
#include <Class/ArrayDouble.mqh>

const color          AsiaColor       = C'0,32,0';    // Asia session box color
const color          EuropeColor     = C'48,0,0';    // Europe session box color
const color          USColor         = C'0,0,56';    // US session box color
const color          DailyColor      = C'64,64,0';   // US session box color

//+------------------------------------------------------------------+
//| Session Class - Collects session data, states, and events        |
//+------------------------------------------------------------------+
class CSession : public CEvent 
  {

public:
             //-- Period Types
             enum PeriodType
             {
               PriorSession,  // Prior (Closed) Session
               ActiveSession, // Active (Open) Session
               OffSession,    // Off-Session
               PeriodTypes    // None
             };

             //-- Session Types
             enum SessionType
             {
               Daily,
               Asia,
               Europe,
               US,
               SessionTypes  // None
             };

             //-- Session Record Definition
             struct SessionRec
             {
               int            Direction;
               int            BreakoutDir;     //--- Direction of the last breakout or reversal
               int            Bias;            //--- Current session Bias in action
               FractalState   State;
               double         High;            //--- High/Low store daily/session high & low
               double         Low;
               double         Support;         //--- Support/Resistance determines reversal, breakout & continuation
               double         Resistance;
             };

             CSession(SessionType Type, int HourOpen, int HourClose, int HourOffset, bool ShowFlags=false);
            ~CSession();

             SessionType      Type(void)                         {return (sType);}

             void             Update(void);
             void             Update(double &OffSessionBuffer[], double &PriorMidBuffer[], double &FractalBuffer[]);

             datetime         ServerTime(int Bar=0);
             int              SessionHour(EventType Event=NoEvent);
             bool             IsOpen(void);
             
//             FibonacciRec     Fibonacci(FractalType Type)        {return fibo[Type];};                 //--- Fibonacci by Fractal Type
             PivotRec         Pivot(FractalState State, int Start=0, MeasureType Measure=Now)          //--- Origin Pivot by State/Measure
                                {return GetPivot(prec,State,Start,Measure);};
             PivotRec         Pivot(const int Node=0)            {return(prec[Node]);};                //--- Origin Pivot by Node
             double           Pivot(const PeriodType Type);                                            //--- Mid/Mean by Period Type
             int              Age(void)                          {return(sBarFE);}                     //--- Number of periods since the last fractal event
             
             double           Expansion(FractalType Type, MeasureType Measure, int Format=InDecimal);  //--- returns expansion fibonacci
             double           Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal);    //--- returns retrace fibonacci
             double           Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal);   //--- returns recovery fibonacci
             double           Forecast(FractalType Type, int Method, FiboLevel Fibo=FiboRoot);         //--- returns extended fibo price

             string           PivotStr(string Title, PivotRec &Pivot);
             string           FractalStr(int Pivots=NoValue);
             string           SessionStr(PeriodType Type);

             FractalRec       operator[](const FractalType Type) {return(frec[Type]);}
             SessionRec       operator[](const PeriodType Type)  {return(srec[Type]);}
                                 
private:

             //--- Panel Indicators
             string           indSN;

             //--- Private Class properties
             SessionType      sType;
             
             bool             sSessionIsOpen;
             bool             sShowFlags;

             int              sHourOpen;
             int              sHourClose;
             int              sHourOffset;
             int              sBar;
             int              sBars;
             int              sBarDay;
             int              sBarHour;
             
             int              sBarFE;          //--- Fractal Expansion Bar
             int              sDirFE;          //--- Fractal Direction (Painted)

             //--- Private class collections
             SessionRec       srec[PeriodTypes];
             FractalRec       frec[3];
             PivotRec         prec[];
             //FibonacciRec     fibo[3];
             
             
             CArrayDouble    *sOffMidBuffer;
             CArrayDouble    *sPriorMidBuffer;
             CArrayDouble    *sFractalBuffer;
             
             //--- Private Methods
             int              CalcBias(double Price);    //--- Active Bias 

             void             OpenSession(void);
             void             CloseSession(void);

             void             UpdateSession(void);
             void             UpdateTerm(void);
             void             UpdateTrend(void);
             void             UpdateOrigin(void);
             void             UpdateFibonacci(void);
             void             UpdatePanel(void);

             void             UpdateBuffers(void);
             void             UpdateFractalBuffer(int Direction, double Value);

             void             LoadHistory(void);         //--- History Load/Init
  };

//+------------------------------------------------------------------+
//| CalcBias - Returns Active Bias(Action) relative to supplied price|
//+------------------------------------------------------------------+
int CSession::CalcBias(double Price)
  {
    if (Pivot(ActiveSession)>Price)
      return (OP_BUY);

    if (Pivot(ActiveSession)<Price)
      return (OP_SELL);
  
    return (Action(srec[ActiveSession].Direction,InDirection));
  }

//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSession::OpenSession(void)
  {
    //-- Update OffSession Record and Indicator Buffer      
    srec[OffSession]                      = srec[ActiveSession];
    sOffMidBuffer.SetValue(sBar,Pivot(ActiveSession));

    //-- Set support/resistance (ActiveSession is OffSession data)
    srec[ActiveSession].Resistance        = fmax(srec[PriorSession].High,srec[OffSession].High);
    srec[ActiveSession].Support           = fmin(srec[PriorSession].Low,srec[OffSession].Low);
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];

    //<--- Check for offsession reversals
    if (IsHigher(srec[ActiveSession].High,srec[PriorSession].High,NoUpdate))
      if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp,NoUpdate))
        srec[ActiveSession].High          = fdiv(srec[PriorSession].High+High[sBar],2,Digits);

    if (IsLower(srec[ActiveSession].Low,srec[PriorSession].Low,NoUpdate))
      if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown,NoUpdate))
       srec[ActiveSession].Low            = fdiv(srec[PriorSession].Low+Low[sBar],2,Digits);

    SetEvent(SessionOpen,Notify);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {        
    //-- Update Prior Record, range history, and Indicator Buffer
    srec[PriorSession]                    = srec[ActiveSession];
    sPriorMidBuffer.SetValue(sBar,Pivot(PriorSession));

    //-- Reset Active Record
    srec[ActiveSession].Resistance        = srec[PriorSession].High;
    srec[ActiveSession].Support           = srec[PriorSession].Low;
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];

    SetEvent(SessionClose,Notify);
  }

//+------------------------------------------------------------------+
//| UpdateSession - Sets active state, bounds and alerts on the tick |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {
    FractalState  state              = NoState;
    FractalState  statehigh          = NoState;
    FractalState  statelow           = NoState;

    if (IsHigher(High[sBar],srec[ActiveSession].High))
    {
      SetEvent(NewHigh,Nominal);
      SetEvent(NewBoundary,Nominal);

      if (NewDirection(srec[ActiveSession].Direction,DirectionUp))
        SetEvent(NewDirection,Nominal);

      state                          = Rally;

      if (IsHigher(srec[ActiveSession].High,srec[PriorSession].High,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp))
          state                      = Reversal;
        else
          state                      = Breakout;
                 
      statehigh                      = state;  //--- Retain for multiple boundary correction
    }
            
    if (IsLower(Low[sBar],srec[ActiveSession].Low))
    {
      SetEvent(NewLow,Nominal);
      SetEvent(NewBoundary,Nominal);

      if (NewDirection(srec[ActiveSession].Direction,DirectionDown))
        SetEvent(NewDirection,Nominal);

      state                          = Pullback;

      if (IsLower(srec[ActiveSession].Low,srec[PriorSession].Low,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown))
          state                      = Reversal;
        else
          state                      = Breakout;

      statelow                      = state;  //--- Retain for multiple boundary correction
    }

    //-- Apply historical corrections on multiple new boundary events
    if (Event(NewHigh)&&Event(NewLow))
    {
      if (IsEqual(statehigh,Reversal)||IsEqual(statelow,Reversal))
      {
        //--- axiom: at no time shall a breakout occur without first having a same direction reversal following a prior opposite reversal/breakout;
        //--- axiom: given a high reversal, a low breakout is not possible;
        //--- axiom: The simultaneous occurrence of both high and low reversals is possible; each of which must be processed in sequence;
      
        if (IsEqual(statehigh,Reversal)&&IsEqual(statelow,Reversal)) //--- double outside reversal?
        {
          Print(TimeToStr(Time[sBar])+":Double Outside reversal; check results");
        
          //--- Process the 'original' reversal        
        
        }
        else
        if (IsEqual(statehigh,Reversal))
        {
          if (IsEqual(state,Breakout))
            Print("Axiom violation: High Reversal/Low Breakout not possible");

          ClearEvent(NewLow);
          state                         = statehigh;
        }
        else
        {
          ClearEvent(NewHigh);
          state                         = statelow;
        }
        
        srec[ActiveSession].Direction = srec[ActiveSession].BreakoutDir;
      }
      else
      {
        //--- Resolve pullback vs rally
        if (IsChanged(srec[ActiveSession].Direction,Direction(Close[sBar]-Open[sBar])))   //--- does not work all the time; fuzzy guess; self-correcting
        {
          ClearEvent(NewLow);
          state                         = statehigh;  //-- Outside bar reversal; use retained high
        }
        else
        {
          ClearEvent(NewHigh);
          state                         = statelow;  //-- Outside bar reversal; use retained high
        }
      }
    }

    if (IsEqual(state,Reversal))                     //-- catch double/triple+ outside reversals
      SetEvent(NewReversal,Nominal);

    if (NewAction(srec[ActiveSession].Bias,CalcBias(BoolToDouble(IsOpen(),Pivot(OffSession),Pivot(PriorSession)))))
      SetEvent(NewBias,Nominal);

    if (NewState(srec[ActiveSession].State,state))
      SetEvent(Event(state),Nominal);
  }

//+------------------------------------------------------------------+
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CSession::UpdateTerm(void)
  {
    FractalState  state            = NoState;
    frec[Term].Event               = NoEvent;

    //--- Check for Term Reversals
    if (NewDirection(frec[Term].Direction,srec[ActiveSession].BreakoutDir))
    {
      frec[Term].Point[fpOrigin]   = frec[Term].Point[fpRoot];
      frec[Term].Point[fpRoot]     = frec[Term].Point[fpExpansion];
      frec[Term].Point[fpBase]     = BoolToDouble(IsEqual(frec[Term].Direction,DirectionUp),
                                       srec[PriorSession].High,srec[PriorSession].Low);
      SetEvent(NewTerm,Minor);
    }

    //--- Check for Term Upper Boundary changes
    if (IsEqual(frec[Term].Direction,DirectionUp))
      if (IsHigher(High[sBar],frec[Term].Point[fpExpansion]))
      {
        frec[Term].Point[fpRetrace]  = frec[Term].Point[fpExpansion];
        frec[Term].Point[fpRecovery] = frec[Term].Point[fpExpansion];

        SetEvent(NewExpansion,Minor);

        UpdateFractalBuffer(DirectionUp,High[sBar]);
      }
      else 
      if (IsLower(BoolToDouble(sBar==0,Close[sBar],Low[sBar]),frec[Term].Point[fpRetrace]))
        frec[Term].Point[fpRecovery] = frec[Term].Point[fpRetrace];
      else
        frec[Term].Point[fpRecovery] = fmax(BoolToDouble(sBar==0,Close[sBar],High[sBar]),frec[Term].Point[fpRecovery]);
    else

    //--- Check for Term Lower Boundary changes
      if (IsLower(Low[sBar],frec[Term].Point[fpExpansion]))
      {
        frec[Term].Point[fpRetrace]  = frec[Term].Point[fpExpansion];
        frec[Term].Point[fpRecovery] = frec[Term].Point[fpExpansion];

        SetEvent(NewExpansion,Minor);

        UpdateFractalBuffer(DirectionDown,Low[sBar]);
      }
      else
      if (IsHigher(BoolToDouble(sBar==0,Close[sBar],High[sBar]),frec[Term].Point[fpRetrace]))
        frec[Term].Point[fpRecovery] = frec[Term].Point[fpRetrace];
      else
        frec[Term].Point[fpRecovery] = fmin(BoolToDouble(sBar==0,Close[sBar],Low[sBar]),frec[Term].Point[fpRecovery]);

    //--- Check for term state changes
    if (Event(NewTerm))
      state                        = Reversal;
    else
    if (Event(NewExpansion,Minor))
      state                        = Breakout;
    else
    {
      if (frec[Term].Direction==DirectionUp)
        if (frec[Term].Point[fpRetrace]<Pivot(PriorSession))
          state                    = Pullback;

      if (frec[Term].Direction==DirectionDown)
        if (frec[Term].Point[fpRetrace]>Pivot(PriorSession))
          state                    = Rally;
    }

    if (NewState(frec[Term].State,state))
    {
      frec[Term].Event             = Event(state);
      frec[Term].Price             = BoolToDouble(Event(NewTerm),frec[Term].Point[fpBase],Close[sBar]);

      SetEvent(Event(state),Minor);
      SetEvent(NewState,Minor);
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Updates trend fractal bounds and state             |
//+------------------------------------------------------------------+
void CSession::UpdateTrend(void)
  {
    FractalState state                = NoState;
    frec[Trend].Event                 = NoEvent;

    //--- Set Common Fractal Points
    frec[Trend].Point[fpRetrace]      = frec[Term].Point[fpRetrace];
    frec[Trend].Point[fpRecovery]     = frec[Term].Point[fpRecovery];

    //--- Handle Term Reversals 
    if (Event(NewTerm))        //--- After a term reversal
    {
      frec[Trend].Direction           = frec[Term].Direction;
      frec[Trend].Point[fpOrigin]     = frec[Term].Point[fpRoot];
      frec[Trend].Point[fpBase]       = frec[Term].Point[fpOrigin];
      frec[Trend].Point[fpRoot]       = frec[Term].Point[fpRoot];
    }

    //--- Handle Trend Interior States)
    if (IsBetween(frec[Term].Point[fpExpansion],frec[Trend].Point[fpRoot],frec[Trend].Point[fpBase]))
    {
      if (IsChanged(frec[Trend].Point[fpExpansion],frec[Term].Point[fpExpansion]))
        state                         = (FractalState)BoolToInt(IsEqual(frec[Trend].Direction,DirectionUp),Rally,Pullback);
      else
      if (Level(Expansion(Trend,Max))>1&&Level(Retrace(Trend,Max))>1)
        state                         = (FractalState)BoolToInt(IsEqual(frec[Trend].Direction,DirectionUp),Pullback,Rally);
    }

    //--- Handle Trend Breakout/Reversal/Extension States)
    else
    {
      state                           = (FractalState)BoolToInt(NewDirection(frec[Origin].Direction,frec[Trend].Direction),Reversal,Breakout);

      if (IsChanged(frec[Trend].Point[fpExpansion],frec[Term].Point[fpExpansion]))
        SetEvent(NewExpansion,Major);
    }

    if (NewState(frec[Trend].State,state,IsEqual(state,Reversal)))
    {
      frec[Trend].Event               = Event(state);
      frec[Trend].Price               = BoolToDouble(Event(NewExpansion,Major),frec[Trend].Point[fpBase],frec[Trend].Point[fpExpansion]);

      SetEvent(NewState,Major);
      SetEvent(Event(frec[Trend].State),Major);
      SetEvent(BoolToEvent(Event(NewReversal,Major),NewTrend),Major);
    }
  }
  
//+------------------------------------------------------------------+
//| UpdateOrigin - Updates origin fractal bounds and state           |
//+------------------------------------------------------------------+
void CSession::UpdateOrigin(void)
  {
    FractalRec origin                 = frec[Origin];
    frec[Origin].Event                = NoEvent;

    if (Event(NewTrend))
    {
      frec[Origin]                    = frec[Trend];
      frec[Origin].Point[fpOrigin]    = origin.Point[fpExpansion];
      frec[Origin].Point[fpRoot]      = origin.Point[fpExpansion];

      SetEvent(BoolToEvent(Event(NewReversal,Major),NewOrigin),Critical);
    }

    if (IsChanged(frec[Origin].Point[fpExpansion],BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                        fmax(frec[Origin].Point[fpExpansion],frec[Trend].Point[fpExpansion]),
                                        fmin(frec[Origin].Point[fpExpansion],frec[Trend].Point[fpExpansion]),Digits)))
    {
      frec[Origin].Point[fpRetrace]   = frec[Origin].Point[fpExpansion];
      frec[Origin].Point[fpRecovery]  = frec[Origin].Point[fpExpansion];
    }                                                    
    else
    if (IsChanged(frec[Origin].Point[fpRetrace],BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                        fmin(frec[Origin].Point[fpRetrace],frec[Trend].Point[fpRetrace]),
                                        fmax(frec[Origin].Point[fpRetrace],frec[Trend].Point[fpRetrace]),Digits)))
      frec[Origin].Point[fpRecovery]  = frec[Origin].Point[fpRetrace];
    else
      frec[Origin].Point[fpRecovery]  = BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                        fmax(frec[Origin].Point[fpRecovery],frec[Trend].Point[fpRecovery]),
                                        fmin(frec[Origin].Point[fpRecovery],frec[Trend].Point[fpRecovery]),Digits);
      

    if (NewFractal(frec[Origin],prec,sBar,Event(NewOrigin),Always,Always))
    {
      Flag("[s6]"+EnumToString(sType)+":"+EnumToString(frec[Origin].Event),Color(frec[Origin].State),sBar,frec[Origin].Price,sShowFlags);

//      if (IsEqual(frec[Origin].State,Breakout)) Print(PivotStr(TimeToStr(BoolToDate(sBar>0,Time[sBar],TimeCurrent())),prec[0])+" "+EventStr());

      SetEvent(frec[Origin].Event,Critical);
      SetEvent(NewState,Critical);
    }
  }

//+------------------------------------------------------------------+
//| UpdateFibonacci - Sets/Fires Fibo Expansion alerts               |
//+------------------------------------------------------------------+
void CSession::UpdateFibonacci(void)
  {
    //-- Test/Reset for Expansion Fibos/Events
    for (FractalType type=Origin;type<=Term;type++)
      if (NewFibonacci(frec[type],prec,Extension,Event(Event(type)),sBar))
      {
        SetEvent(NewFibonacci,Alert(type));

//        if (type==Origin&&this[NewOrigin])
//        if (type==Origin)
        Flag("[s6]"+EnumToString(type)+"["+EnumToString(frec[type].Extension.Level)+"]",
          BoolToInt(IsEqual(frec[type].Direction,DirectionUp),clrMediumAquamarine,clrDeepPink),
          sBar,frec[type].Extension.Forecast,sShowFlags); //&&frec[type].Extension.Level>Fibo100);
      }

    //if (Event(NewFibonacci))
    //  Flag("New "+EnumToString(Fibo.Type)+":"+EnumToString(Fibo.Level),BoolToInt(Fibo.Level==Fibo100,Color(Fractal.Direction),BoolToInt(Fibo.Level<Fibo100,clrDarkGray,clrWhite)),Bar,Close[sBar]);
  }

//+------------------------------------------------------------------+
//| UpdatePanel - Updates control panel display                      |
//+------------------------------------------------------------------+
void CSession::UpdatePanel(void)
  {
    //-- Update Control Panel (Session)
    if (ChartWindowFind(0,indSN)>NoValue)
      if (ObjectGet("bxhAI-Session"+EnumToString(sType),OBJPROP_BGCOLOR)==clrBoxOff||Event(NewState,Minor)||Event(NewHour))
      {
        UpdateBox("bxhAI-Session"+EnumToString(sType),Color(Direction(Term),IN_DARK_DIR));
        UpdateBox("bxbAI-OpenInd"+EnumToString(sType),BoolToInt(IsOpen(),clrYellow,clrBoxOff));
      }
  }

//+------------------------------------------------------------------+
//| UpdateBuffers - updates indicator buffer values                  |
//+------------------------------------------------------------------+
void CSession::UpdateBuffers(void)
  {
    if (Bars<sBars)
      Print("History exception; need to reload");
    else
      for (sBars=sBars;sBars<Bars;sBars++)
      {
        sOffMidBuffer.Insert(0,0.00);
        sPriorMidBuffer.Insert(0,0.00);
        sFractalBuffer.Insert(0,0.00);
        sBarFE++;
      }
  }

//+------------------------------------------------------------------+
//| UpdateFractalBuffer - Updates the fractal buffer                 |
//+------------------------------------------------------------------+
void CSession::UpdateFractalBuffer(int Direction, double Value)
  {
    if (IsEqual(sDirFE,Direction))
      sFractalBuffer.SetValue(sBarFE,0.00);

    if (IsChanged(sBarFE,sBar))
      sDirFE                       = Direction;

    sFractalBuffer.SetValue(sBar,Value);
  }

//+------------------------------------------------------------------+
//| LoadHistory - Loads history from the first session open          |
//+------------------------------------------------------------------+
void CSession::LoadHistory(void)
  {    
    int direction                    = BoolToInt(Close[sBar]<Open[sBar],DirectionDown,DirectionUp);

    //--- Initialize period operationals
    sBar                             = Bars-1;
    sBars                            = Bars;
    sBarDay                          = NoValue;
    sBarHour                         = NoValue;

    sBarFE                           = sBar;
    sDirFE                           = NoDirection;

    //--- Initialize session records
    for (int type=0;type<PeriodTypes;type++)
    {
      srec[type].Direction           = direction;
      srec[type].BreakoutDir         = NoDirection;
      srec[type].State               = Breakout;
      srec[type].High                = High[sBar];
      srec[type].Low                 = Low[sBar];
      srec[type].Resistance          = High[sBar];
      srec[type].Support             = Low[sBar];
    }

    //--- Initialize Fractal records
    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
    {
      frec[type].Type                = type;
      frec[type].State               = NoState;
      frec[type].Direction           = direction;
      frec[type].Price               = Open[sBar];
      frec[type].Event               = NoEvent;
      frec[type].Alert               = NoAlert;
      frec[type].Peg                 = false;
      frec[type].Updated             = Time[sBar];
      ArrayInitialize(frec[type].Point,Open[sBar]);
    }

    for(sBar=Bars-1;sBar>0;sBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| Session Class Constructor                                        |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type, int HourOpen, int HourClose, int HourOffset, bool ShowFlags=false)
  {
    //--- Set Panel Indicator Short Name
    indSN                            = "CPanel-v3";

    //--- Init global session values
    sType                            = Type;
    sHourOpen                        = HourOpen;
    sHourClose                       = HourClose;
    sHourOffset                      = HourOffset;
    sSessionIsOpen                   = false;
    sShowFlags                       = ShowFlags;
    
    sOffMidBuffer                    = new CArrayDouble(Bars);
    sOffMidBuffer.Truncate           = false;
    sOffMidBuffer.AutoExpand         = true;    
    sOffMidBuffer.SetPrecision(Digits);
    sOffMidBuffer.Initialize(0.00);
    
    sPriorMidBuffer                  = new CArrayDouble(Bars);
    sPriorMidBuffer.Truncate         = false;
    sPriorMidBuffer.AutoExpand       = true;
    sPriorMidBuffer.SetPrecision(Digits);
    sPriorMidBuffer.Initialize(0.00);
    
    sFractalBuffer                   = new CArrayDouble(Bars);
    sFractalBuffer.Truncate          = false;
    sFractalBuffer.AutoExpand        = true;
    sFractalBuffer.SetPrecision(Digits);
    sFractalBuffer.Initialize(0.00);
    
    LoadHistory();
  }

//+------------------------------------------------------------------+
//| Session Class Destructor                                         |
//+------------------------------------------------------------------+
CSession::~CSession()
  {
    delete sOffMidBuffer;
    delete sPriorMidBuffer;
    delete sFractalBuffer;
  }

//+------------------------------------------------------------------+
//| Update - Updates open session data and events                    |
//+------------------------------------------------------------------+
void CSession::Update(void)
  {
    UpdateBuffers();

    //--- Clear events
    ClearEvents();

    //--- Test for New Day; Force close
    if (IsChanged(sBarDay,TimeDay(ServerTime(sBar))))
    {
      SetEvent(NewDay,Notify);
      
      if (IsChanged(sSessionIsOpen,false))
        CloseSession();
    }
    
    if (IsChanged(sBarHour,TimeHour(ServerTime(sBar))))
      SetEvent(NewHour,Notify);

    //--- Calc events session open/close
    if (IsChanged(sSessionIsOpen,this.IsOpen()))
      if (sSessionIsOpen)
        OpenSession();
      else
        CloseSession();

    UpdateSession();
    UpdateTerm();
    UpdateTrend();
    UpdateOrigin();
    UpdateFibonacci();
    UpdatePanel();
  }
  
//+------------------------------------------------------------------+
//| Update - Updates and returns buffer values                       |
//+------------------------------------------------------------------+
void CSession::Update(double &OffMidBuffer[], double &PriorMidBuffer[], double &FractalBuffer[])
  {
    Update();
    
    sOffMidBuffer.Copy(OffMidBuffer);
    sPriorMidBuffer.Copy(PriorMidBuffer);
    sFractalBuffer.Copy(FractalBuffer);
  }
  
//+------------------------------------------------------------------+
//| ServerTime - Returns the adjusted time based on server offset    |
//+------------------------------------------------------------------+
datetime CSession::ServerTime(int Bar=0)
  {
    //-- Time is set to reflect 5:00pm New York as end of trading day
    
    return(Time[Bar]+(PERIOD_H1*60*sHourOffset));
  };

//+------------------------------------------------------------------+
//| SessionHour - Returns the hour of open session trading           |
//+------------------------------------------------------------------+
int CSession::SessionHour(EventType Event)
  {    
    switch (Event)
    {
      case SessionOpen:   return(sHourOpen);
      case SessionClose:  return(sHourClose);
      default:            if (sSessionIsOpen)
                            return (TimeHour(ServerTime(sBar))-sHourOpen+1);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| SessionIsOpen - Returns true if session is open for trade        |
//+------------------------------------------------------------------+
bool CSession::IsOpen(void)
  {
    if (TimeDayOfWeek(ServerTime(sBar))<6)
      if (TimeHour(ServerTime(sBar))>=sHourOpen && TimeHour(ServerTime(sBar))<sHourClose)
        return (true);
        
    return (false);
  }

//+------------------------------------------------------------------+
//| Pivot - returns the mid price for the supplied type              |
//+------------------------------------------------------------------+
double CSession::Pivot(const PeriodType Type)
  {
    return(fdiv(srec[Type].High+srec[Type].Low,2,Digits));
  }

//+------------------------------------------------------------------+
//| Retrace - Calcuates fibo retrace % for supplied Type             |
//+------------------------------------------------------------------+
double CSession::Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
      switch (Measure)
      {
        case Now: return(Retrace(frec[Type].Point[fpRoot],frec[Type].Point[fpExpansion],Close[sBar],Format));
        case Min: return(Retrace(frec[Type].Point[fpRoot],frec[Type].Point[fpExpansion],frec[Type].Point[fpRecovery],Format));
        case Max: return(Retrace(frec[Type].Point[fpRoot],frec[Type].Point[fpExpansion],frec[Type].Point[fpRetrace],Format));
      }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Expansion - Calcuates fibo expansion % for supplied Type         |
//+------------------------------------------------------------------+
double CSession::Expansion(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    switch (Measure)
    {
      case Now: return(Expansion(frec[Type].Point[fpBase],frec[Type].Point[fpRoot],Close[sBar],Format));
      case Min: return(Expansion(frec[Type].Point[fpBase],frec[Type].Point[fpRoot],frec[Type].Point[fpRetrace],Format));
      case Max: return(Expansion(frec[Type].Point[fpBase],frec[Type].Point[fpRoot],frec[Type].Point[fpExpansion],Format));
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Recovery - Calcuates fibo recovery% for supplied Type            |
//+------------------------------------------------------------------+
double CSession::Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    switch (Measure)
    {
      case Now: return(Expansion(frec[Type].Point[fpExpansion],frec[Type].Point[fpRoot],Close[sBar],Format));
//      case Min: return(BoolToInt(IsEqual(Format,InDecimal),1,100)-fabs(Retrace(Type,Max,Format)));
      case Max: return(Expansion(frec[Type].Point[fpExpansion],frec[Type].Point[fpRoot],frec[Type].Point[fpRecovery],Format));
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Forecast - Returns Forecast Price for supplied Fibo              |
//+------------------------------------------------------------------+
double CSession::Forecast(FractalType Type, int Method, FiboLevel Fibo=FiboRoot)
  {
    switch (Method)
    {
      case Expansion:   return(NormalizeDouble(frec[Type].Point[fpRoot]+((frec[Type].Point[fpBase]-frec[Type].Point[fpRoot])*Percent(Fibo)),Digits));
      case Retrace:     return(NormalizeDouble(frec[Type].Point[fpExpansion]+((frec[Type].Point[fpRoot]-frec[Type].Point[fpExpansion])*Percent(Fibo)),Digits));
      case Recovery:    return(NormalizeDouble(frec[Type].Point[fpRoot]-((frec[Type].Point[fpRoot]-frec[Type].Point[fpRecovery])*Percent(Fibo)),Digits));
      case Correction:  return(NormalizeDouble(((frec[Type].Point[fpRoot]-frec[Type].Point[fpExpansion])*FiboCorrection)+frec[Type].Point[fpExpansion],Digits));
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| PivotStr - Returns Screen formatted Pivot Detail                 |
//+------------------------------------------------------------------+
string CSession::PivotStr(string Title, PivotRec &Pivot)
  {  
    string text            = "";

    Append(text,Title,"\n");
    Append(text,DirText(Pivot.Direction));
    Append(text,ActionText(Pivot.Lead));
    Append(text,EnumToString(Pivot.State));
    Append(text,"["+ActionText(Pivot.Bias)+"]");
    Append(text,DoubleToStr(Pivot.Open,Digits));
    Append(text,DoubleToStr(Pivot.High,Digits));
    Append(text,DoubleToStr(Pivot.Low,Digits));
    Append(text,DoubleToStr(Pivot.Close,Digits));
        
    return (text);
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns Screen formatted Fibonacci Detail           |
//+------------------------------------------------------------------+
string CSession::FractalStr(int ShowPivots=NoValue)
  {  
    string text            = "*---------- "+EnumToString(this.Type())+" ["+BoolToStr(IsOpen(),"Open","Closed")+"] Session Fractal ----------*";
    
    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
    {
      Append(text,EnumToString(type),"\n");
      Append(text,DirText(frec[type].Direction));
      Append(text,EnumToString(frec[type].State));
      Append(text,BoolToStr(frec[type].Peg,"Pegged"));
      Append(text,(string)Level(Expansion(type,Max))+":"+(string)Level(Retrace(type,Max)));
      Append(text,"     (rt) "+DoubleToStr(Retrace(type,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(type,Max,InPercent),1)+"%  "+DoubleToStr(Retrace(type,Min,InPercent),1)+"%\n","\n");
      Append(text,"     (e) "+DoubleToStr(Expansion(type,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(type,Max,InPercent),1)+"%  "+DoubleToStr(Expansion(type,Min,InPercent),1)+"%\n");
    }

    if (ShowPivots>NoValue)
    {
      Append(text,"*---------- Origin Active Pivots ["+(string)ArraySize(prec)+"]--------------*","\n");

      for (int node=0;node<=fmin(ArraySize(prec),ShowPivots);node++)
        Append(text,PivotStr(BoolToStr(IsEqual(node,0),"Active","Node["+(string)node+"]"),prec[node]),"\n");
    }
        
    return (text);
  }

//+------------------------------------------------------------------+
//| SessionStr - Returns formatted Session data for supplied type    |
//+------------------------------------------------------------------+
string CSession::SessionStr(PeriodType Type)
  {  
    string siSessionInfo        = EnumToString(this.Type())+"|"
                                + TimeToStr(Time[sBar])+"|"
                                + BoolToStr(this.IsOpen(),"Open|","Closed|")
                                + DoubleToStr(Pivot(Type),Digits)+"|"
                                + BoolToStr(srec[Type].Direction==DirectionUp,"Long|","Short|")                              
                                + BoolToStr(srec[Type].BreakoutDir==DirectionUp,"Long|","Short|")                              
                                + EnumToString(srec[Type].State)+"|"
                                + DoubleToStr(srec[Type].High,Digits)+"|"
                                + DoubleToStr(srec[Type].Low,Digits)+"|"
                                + DoubleToStr(srec[Type].Resistance,Digits)+"|"
                                + DoubleToStr(srec[Type].Support,Digits)+"|";

    return(siSessionInfo);
  }

//+------------------------------------------------------------------+
//| IsChanged - Compares SessionType to detect if a change occurred  |
//+------------------------------------------------------------------+
bool IsChanged(SessionType &Compare, SessionType Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }

//+------------------------------------------------------------------+
//| Color - Returns the color for session ranges                     |
//+------------------------------------------------------------------+
color Color(SessionType Type, GammaType Gamma=Dark)
  {
    switch (Type)
    {
      case Asia:    return((color)BoolToInt(Gamma==Dark,AsiaColor,clrForestGreen));
      case Europe:  return((color)BoolToInt(Gamma==Dark,EuropeColor,clrFireBrick));
      case US:      return((color)BoolToInt(Gamma==Dark,USColor,clrSteelBlue));
      case Daily:   return((color)BoolToInt(Gamma==Dark,DailyColor,clrDarkGray));
    }
    
    return (clrBlack);
  }

