//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
//|                                 Copyright 2017, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\PipFractal.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CStrategy
{
  private:

    enum ElementType
         {
            fo,
            fm,
            fn,
            pfo,
            pfm,
            pfn,
            ElementTypes
         };
         
    enum ClassType
         {
           Fractal,
           PipFractal
         };

    enum FractalType
         {
           FractalOrigin,
           FractalMajor,
           FractalMinor
         };
         
    enum MeasureType
         {
           MaxGain,
           ActualGain,
           MaxDraw,
           ActualDraw
         };
         
    struct FibonacciRec
         {
           double          Value;
         };
         
    struct ElementRec
         {
           int             GroupId;
           ClassType       ClassId;
           FractalType     FractalId;
           int             Direction;
         };
  
    struct GroupRec
         {
           int             GroupId;         //--- Fractal pattern group
           int             Degree;          //--- DoC value (degree of change)
           int             Count;           //--- Count of occurrences
           double          FibonacciNow[6]; //--- Current fibonacci
           double          FibonacciMax[6]; //--- Max fibonacci
         };
         
    struct StatisticRec
         {
           int             GroupId;
           int             Direction;
           datetime        TimeOpen;
           double          RangeOpen;
           double          PriceOpen;
           double          PriceHigh;
           double          PriceLow;
           double          PriceClose;
           bool            AdverseDraw;
           datetime        TimeClose;
           bool            Changed;
         };
         
    struct StrategyRec
         {
           int             GroupId;
           int             FibonacciId;
           int             StrategyId;
           bool            GroupChanged;
           bool            FibonacciChanged;
           bool            StrategyChanged;
         };
         
    ElementRec             Element[];
    GroupRec               Group[];
    GroupRec               GroupHistory[];
    FibonacciRec           Fibonacci[];

    string                 CSV_Record[];
    
    CFractal              *fractal;
    CPipFractal           *pfractal;

    void                   LoadFibonacci(void);
    void                   LoadElements(void);
    void                   LoadGroups(void);
    void                   LoadData(void);

    void                   UpdateStatistics(void);

    void                   InitCurrent(void);
    void                   OpenRunning(void);
    void                   CloseRunning(void);
    
    string                 FormatData(StatisticRec &Data, string Format="PAD");
    string                 FormatData(GroupRec &Data, string Format="CSV");

    double                 Measure(StatisticRec &Data, int Measure);
    int                    FibonacciLevel(double Value);


  public:
                           CStrategy(CFractal &Fractal, CPipFractal &PipFractal);
                          ~CStrategy();
                
    void                   Update(void);
    void                   Show(void);
    StatisticRec           Statistic(void) { return (Current); };
    
    
    
    string                 Pattern(void) {return ( BoolToStr(ElementDirection[fo]==DirectionUp,"L","S")
                                                  +BoolToStr(ElementDirection[fm]==DirectionUp,"L","S")
                                                  +BoolToStr(ElementDirection[fn]==DirectionUp,"L","S")
                                                  +BoolToStr(ElementDirection[pfo]==DirectionUp,"L","S")
                                                  +BoolToStr(ElementDirection[pfm]==DirectionUp,"L","S")
                                                  +BoolToStr(ElementDirection[pfn]==DirectionUp,"L","S")
                                                 ); };
    StrategyRec            Record(void) { return (Strategy); };
                                                     
  protected:

    StatisticRec           Running[];    //--- running statistics
    StatisticRec           History[];    //--- closed statistics
    StatisticRec           Current;      //--- most recent running statistic
    StrategyRec            Strategy;     //--- Holds the most current strategy data

    int                    FibonacciId(void);
    int                    FibonacciGroups;
    int                    FibonacciElements;
    int                    ElementFibonacci[6];
    int                    GroupId(void);
    int                    Groups;
    int                    ElementDirection[6];
    int                    Elements;
  };

//+------------------------------------------------------------------+
//| FibonacciLevel - returns the fibonacci level for supplied value  |
//+------------------------------------------------------------------+
int CStrategy::FibonacciLevel(double Value)
  {
    int    flFibo;

    for (flFibo=FiboRoot;flFibo<ArraySize(Fibonacci);flFibo++)
      if (Value>Fibonacci[flFibo].Value)
        break;
    
    return(--flFibo);
  }

//+------------------------------------------------------------------+
//| FibonacciId - returns the fibonacci id                           |
//+------------------------------------------------------------------+
int CStrategy::FibonacciId(void)
  {
    static int       fiFibonacciId  = 0;
    int              fiDegree       = 0;
    static const int fiElements[6]  = {145152,12096,1728,144,12,1};
    
    if (IsChanged(ElementFibonacci[fo],FibonacciLevel(fractal.Fibonacci(Origin,Expansion,Now))))
      fiDegree++;
    if (IsChanged(ElementFibonacci[fm],FibonacciLevel(fractal.Fibonacci(Base,Expansion,Now))))
      fiDegree++;
    if (IsChanged(ElementFibonacci[fn],FibonacciLevel(fractal.Fibonacci(Expansion,Expansion,Now))))
      fiDegree++;
    if (IsChanged(ElementFibonacci[pfo],FibonacciLevel(fractal.Fibonacci(Origin,Expansion,Now))))
      fiDegree++;
    if (IsChanged(ElementFibonacci[pfm],FibonacciLevel(fractal.Fibonacci(Trend,Expansion,Now))))
      fiDegree++;
    if (IsChanged(ElementFibonacci[pfn],FibonacciLevel(fractal.Fibonacci(Term,Expansion,Now))))
      fiDegree++;
      
    if (fiDegree>0)
    {
      if (IsChanged(fiFibonacciId,
                     (ElementFibonacci[fo]*fiElements[fo])+
                     (ElementFibonacci[fm]*fiElements[fm])+
                     (ElementFibonacci[fn]*fiElements[fn])+
                     (ElementFibonacci[pfo]*fiElements[pfo])+
                     (ElementFibonacci[pfm]*fiElements[pfm])+
                     (ElementFibonacci[pfn]*fiElements[pfn])
                   ))
        {
          Strategy.FibonacciChanged = true;
        };
      
//      Group[Element[ssGroupId].GroupId].Count++;
//      Group[Element[ssGroupId].GroupId].Degree            = ssDegree;
    }

    return (fiFibonacciId);
  }

//+------------------------------------------------------------------+
//| GroupId - Returns the current GroupId of the fractal pattern     |
//+------------------------------------------------------------------+
int CStrategy::GroupId(void)
  {
    static int  ssGroupId    = 0;
    int         ssDegree     = 0;
    int         ssElementId  = Elements;
    
    if (IsChanged(ElementDirection[fo],fractal.Origin(Direction)))
      ssDegree++;
    if (IsChanged(ElementDirection[fm],fractal.Direction(Expansion)))
      ssDegree++;
    if (IsChanged(ElementDirection[fn],fractal.Direction(fractal.State(Major))))
      ssDegree++;
    if (IsChanged(ElementDirection[pfo],pfractal.Direction(Origin)))
      ssDegree++;
    if (IsChanged(ElementDirection[pfm],pfractal.Direction(Trend)))
      ssDegree++;
    if (IsChanged(ElementDirection[pfn],pfractal.Direction(Term)))
      ssDegree++;
      
    if (ssDegree>0)
    {
      ssGroupId              = 0;
      
      for (int idx=0; idx<6; idx++)
      {
        ssElementId /= 2;
        
        if (ElementDirection[idx]==DirectionUp)
          ssGroupId += ssElementId;
      }
      
      Group[Element[ssGroupId].GroupId].Count++;
      Group[Element[ssGroupId].GroupId].Degree            = ssDegree;

      //--- Record Current Fibonacci calcs
      Group[Element[ssGroupId].GroupId].FibonacciNow[fo]  = fractal.Fibonacci(Origin,Expansion,Now,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciNow[fm]  = fractal.Fibonacci(Base,Expansion,Now,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciNow[fn]  = fractal.Fibonacci(Expansion,Expansion,Now,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciNow[pfo] = pfractal.Fibonacci(Origin,Expansion,Now,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciNow[pfm] = pfractal.Fibonacci(Trend,Expansion,Now,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciNow[pfn] = pfractal.Fibonacci(Term,Expansion,Now,InPercent);

      //--- Record Max Fibonacci calcs
      Group[Element[ssGroupId].GroupId].FibonacciMax[fo]  = fractal.Fibonacci(Origin,Expansion,Max,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciMax[fm]  = fractal.Fibonacci(Base,Expansion,Max,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciMax[fn]  = fractal.Fibonacci(Expansion,Expansion,Max,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciMax[pfo] = pfractal.Fibonacci(Origin,Expansion,Max,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciMax[pfm] = pfractal.Fibonacci(Trend,Expansion,Max,InPercent);
      Group[Element[ssGroupId].GroupId].FibonacciMax[pfn] = pfractal.Fibonacci(Term,Expansion,Max,InPercent);
    }

    return Element[ssGroupId].GroupId;
  }
  
//+------------------------------------------------------------------+
//| LoadFibonacci - Loads fibonacci data from file                   |
//+------------------------------------------------------------------+
void CStrategy::LoadFibonacci(void)
  {
    //-- Load Groups
    int    arrSize        =  0;
    int    try            =  0;
    int    fHandle        = -1;
    string fRecord;

    //--- process command file
    while(fHandle<0)
    {
      fHandle=FileOpen("Fibonacci.csv",FILE_CSV|FILE_READ);
      
      if (++try==20)
      {
        Print("Error opening file for read: ",GetLastError());
        return;
      }
      
      if (fHandle>0)
        break;
    }

    while (!FileIsEnding(fHandle))
    {
      fRecord=FileReadString(fHandle);

      ArrayResize(Fibonacci,arrSize+1);
      StringSplit(fRecord,44,CSV_Record);
      
      Fibonacci[arrSize].Value  = StrToInteger(CSV_Record[0]);

      arrSize++;

    }
    
    FileClose(fHandle);
    
    Print ("Fibonacci Levels loaded: "+IntegerToString(arrSize));
  }

//+------------------------------------------------------------------+
//| LoadGroups - Loads strategy data from files                      |
//+------------------------------------------------------------------+
void CStrategy::LoadGroups(void)
  {
    //-- Load Groups
    int    try            =  0;
    int    fHandle        = -1;
    string fRecord;

    //--- process command file
    while(fHandle<0)
    {
      fHandle=FileOpen("Group.csv",FILE_CSV|FILE_READ);
      
      if (++try==20)
      {
        Print("Error opening file for read: ",GetLastError());
        return;
      }
      
      if (fHandle>0)
        break;
    }

    Groups               = 0;
    
    while (!FileIsEnding(fHandle))
    {
      fRecord=FileReadString(fHandle);

      ArrayResize(Group,Groups+1);
      StringSplit(fRecord,44,CSV_Record);
      
      Group[Groups].GroupId     = StrToInteger(CSV_Record[0]);
      Group[Groups].Degree      = 0;
      Group[Groups].Count       = 0;

      ArrayInitialize(Group[Groups].FibonacciNow,0.00);
      ArrayInitialize(Group[Groups].FibonacciMax,0.00);

      Groups++;
    }
    
    FileClose(fHandle);
    
    Print ("Groups loaded: "+IntegerToString(Groups));
  }

//+------------------------------------------------------------------+
//| LoadElements - Loads fractal group elements from external file   |
//+------------------------------------------------------------------+
void CStrategy::LoadElements(void)
  {
    //-- Load Groups
    int    try            =  0;
    int    fHandle        = -1;
    string fRecord;

    //--- process command file
    while(fHandle<0)
    {
      fHandle=FileOpen("Element.csv",FILE_CSV|FILE_READ);
      
      if (++try==20)
      {
        Print("Error opening file for read: ",GetLastError());
        return;
      }
      
      if (fHandle>0)
        break;
    }

    Elements              = 0;
    
    while (!FileIsEnding(fHandle))
    {
      fRecord=FileReadString(fHandle);
 
      ArrayResize(Element,Elements+1);
      StringSplit(fRecord,44,CSV_Record);
      
      Element[Elements].GroupId       = StrToInteger(CSV_Record[0]);
      Element[Elements].ClassId       = (ClassType)StrToInteger(CSV_Record[1]);
      Element[Elements].FractalId     = (FractalType)StrToInteger(CSV_Record[2]);
      Element[Elements].Direction     = StrToInteger(CSV_Record[3]);
      
      Elements++;
    }
    
    FileClose(fHandle);
    
    Print ("Elements loaded: "+IntegerToString(Elements));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::InitCurrent(void)
  {
    Current.GroupId        = this.GroupId();
    Current.Direction      = pfractal.Direction(Term);
    Current.TimeOpen       = TimeCurrent();
    Current.RangeOpen      = Pip(pfractal.Range(Size));
    Current.PriceOpen      = Close[0];
    Current.PriceHigh      = Close[0];
    Current.PriceLow       = Close[0];
    Current.PriceClose     = Close[0];
    Current.AdverseDraw    = false;
    Current.TimeClose      = 0;
    Current.Changed        = true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::OpenRunning(void)
  {
    int orRunSize   = ArraySize(Running);
    int orGrpSize   = ArraySize(GroupHistory);
    
    InitCurrent();
    
    ArrayResize(Running,orRunSize+1);
    ArrayResize(GroupHistory,orGrpSize+1);
    
    Running[orRunSize]      = Current;
    GroupHistory[orGrpSize] = Group[Current.GroupId];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::CloseRunning(void)
  {
    if (ArraySize(Running)>0)
    {
      for (int idx=0;idx<ArraySize(Running);idx++)
      {
        Running[idx].PriceClose        = Close[0];
        Running[idx].TimeClose         = TimeCurrent();
        
        if (Running[idx].AdverseDraw)
          if (Running[idx].Direction!=pfractal.Direction(Term))
            Running[idx].AdverseDraw   = false;
      }
        
      ArrayResize(History,ArraySize(History)+ArraySize(Running));
      ArrayCopy(History,Running,ArraySize(History)-ArraySize(Running),0,WHOLE_ARRAY);
    }
    
    ArrayResize(Running,0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::UpdateStatistics(void)
  {
    int usRunIdx;
    
    if (pfractal.HistoryLoaded())
    {
      Current.Changed        = false;
    
      if (IsChanged(Current.GroupId,this.GroupId()))
      {
        if (IsChanged(Current.Direction,pfractal.Direction(Term)))
          CloseRunning();

        OpenRunning();
      }

      Current.PriceHigh                  = fmax(Current.PriceHigh,Close[0]);
      Current.PriceLow                   = fmin(Current.PriceLow,Close[0]);
          
      if (pfractal.Event(NewBoundary))
      {
        if ((pfractal.Event(NewHigh)&&Current.Direction==DirectionDown)||
            (pfractal.Event(NewLow)&&Current.Direction==DirectionUp))
          Current.AdverseDraw            = true;
          
        for (usRunIdx=0;usRunIdx<ArraySize(Running);usRunIdx++)
        {
          if (Running[usRunIdx].Direction==DirectionUp)
            Running[usRunIdx].PriceHigh  = Current.PriceHigh;

          if (Running[usRunIdx].Direction==DirectionDown)
            Running[usRunIdx].PriceLow   = Current.PriceLow;
        }

        usRunIdx--;
        
        if (Running[usRunIdx].Direction==DirectionUp)
          Running[usRunIdx].PriceLow     = Current.PriceLow;

        if (Running[usRunIdx].Direction==DirectionDown)
          Running[usRunIdx].PriceHigh    = Current.PriceHigh;

        Running[usRunIdx].AdverseDraw    = Current.AdverseDraw;
      }

{
  UpdateLine("Open",Current.PriceOpen,STYLE_SOLID,clrYellow);
  UpdateLine("High",Current.PriceHigh,STYLE_SOLID,clrLawnGreen);
  UpdateLine("Low",Current.PriceLow,STYLE_SOLID,clrRed);

  string pattern="  {"+Pattern()+"}";
                
  Comment(  "Group: "+IntegerToString(Current.GroupId)+" "+DirText(Current.Direction)+pattern+"\n"
           +"Open: "+DoubleToStr(Current.PriceOpen,Digits)+" ("+DoubleToStr(Pip(Current.PriceOpen-Close[0])*Current.Direction,1)+")\n"
           +"High: "+DoubleToStr(Current.PriceHigh,Digits)+"\n"
           +"Low: "+DoubleToStr(Current.PriceLow,Digits)+"\n"
           +BoolToStr(Current.AdverseDraw,"Yes","No")
         );
}
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CStrategy::FormatData(StatisticRec &Data, string Format="PAD")
  {
    if (Format == "PAD")
      return( LPad(IntegerToString(Data.GroupId)+"-"
             +StringSubstr(DirText(Data.Direction),0,1)," ",1)
             +LPad(DoubleToString(Data.RangeOpen,1)," ",8)
             +LPad(DoubleToString(Data.PriceOpen,Digits)," ",10)
             +LPad(DoubleToString(Measure(Data,MaxGain),1)," ",9)
             +LPad(DoubleToString(Measure(Data,MaxDraw),1)," ",9)
             +LPad(BoolToStr(Data.AdverseDraw,"Yes","No ")," ",9)
             +LPad(DoubleToString(Measure(Data,ActualDraw),1)," ",9)+"\n");

    if (Format == "CSV")
      return( IntegerToString(Data.GroupId)+"|"
             +DirText(Data.Direction)+"|"
             +TimeToStr(Data.TimeOpen)+"|"
             +DoubleToString(Data.RangeOpen,1)+"|"
             +DoubleToString(Data.PriceOpen,Digits)+"|"
             +DoubleToString(Data.PriceHigh,Digits)+"|"
             +DoubleToString(Data.PriceLow,Digits)+"|"
             +DoubleToString(Data.PriceClose,Digits)+"|"             
             +DoubleToString(Measure(Data,MaxGain),1)+"|"
             +DoubleToString(Measure(Data,MaxDraw),1)+"|"
             +TimeToStr(Data.TimeClose)+"|"             
             +BoolToStr(Data.AdverseDraw,"Yes","No "));
             
    return( " " );
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CStrategy::FormatData(GroupRec &Data, string Format="CSV")
  {
    if (Format == "CSV")
      return(     IntegerToString(Data.GroupId)
             +"|"+IntegerToString(Data.Count)
             +"|"+IntegerToString(Data.Degree)
             +"|"+DoubleToString(Data.FibonacciNow[fo],1)
             +"|"+DoubleToString(Data.FibonacciNow[fm],1)
             +"|"+DoubleToString(Data.FibonacciNow[fn],1)
             +"|"+DoubleToString(Data.FibonacciNow[pfo],1)
             +"|"+DoubleToString(Data.FibonacciNow[pfm],1)
             +"|"+DoubleToString(Data.FibonacciNow[pfn],1)
             +"|"+DoubleToString(Data.FibonacciMax[fo],1)
             +"|"+DoubleToString(Data.FibonacciMax[fm],1)
             +"|"+DoubleToString(Data.FibonacciMax[fn],1)
             +"|"+DoubleToString(Data.FibonacciMax[pfo],1)
             +"|"+DoubleToString(Data.FibonacciMax[pfm],1)
             +"|"+DoubleToString(Data.FibonacciMax[pfn],1)
            );
             
    return( " " );
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStrategy::CStrategy(CFractal &Fractal, CPipFractal &PipFractal)
  {
    this.fractal  = GetPointer(Fractal);
    this.pfractal = GetPointer(PipFractal);
    
    Current.GroupId   = NoValue;
    Current.Direction = DirectionNone;

    ArrayInitialize(ElementDirection,DirectionNone);
    
    LoadElements();
    LoadGroups();
    LoadFibonacci();
    
    FibonacciGroups   = 1741824;
    FibonacciElements = 10450944;
    
    NewLine("Open");
    NewLine("High");
    NewLine("Low");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStrategy::~CStrategy()
  {
    Print("Strategy summary");
    for (int idx=0;idx<Groups;idx++)
      Print("Group: "+IntegerToString(idx)
           +" Count: "+IntegerToString(Group[idx].Count)
           +" Degree: "+IntegerToString(Group[idx].Degree));

    Print("*----- History ------*");
    Print("Grp|Dir|tOpen|Range|Open|High|Low|Close|Gain|Draw|tClose|Adv");

    for (int idx=0;idx<ArraySize(History);idx++)
      Print(FormatData(History[idx],"CSV"));
      
    Print("*----- Running ------*");
    Print("Grp|Dir|tOpen|Range|Open|High|Low|Close|Gain|Draw|tClose|Adv");

    for (int idx=0;idx<ArraySize(Running);idx++)
      Print(FormatData(Running[idx],"CSV"));

    Print("*----- Group History ------*");
    Print("Grp|Strat|Count|Degree|nfo|nfm|nfn|npfo|npfm|npfn|mfo|mfm|mfn|mpfo|mpfm|mpfn");

    for (int idx=0;idx<ArraySize(GroupHistory);idx++)
      Print(FormatData(GroupHistory[idx],"CSV"));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CStrategy::Measure(StatisticRec &Data, int Measure)
  {    
    switch (Measure)
    {
      case MaxGain:     if (Data.Direction==DirectionUp)
                          return(Pip(Data.PriceHigh-Data.PriceOpen));
                        if (Data.Direction==DirectionDown)
                          return(Pip(Data.PriceOpen-Data.PriceLow));
                        break;

      case ActualGain:  if (Data.TimeClose>0)
                          return(Measure(Data,MaxGain));
                        if (Data.Direction==DirectionUp)
                          return(fmax(Pip(Close[0]-Data.PriceOpen),0.00));
                        if (Data.Direction==DirectionDown)
                          return(fmax(Pip(Data.PriceOpen-Close[0]),0.00));
                        break;

      case MaxDraw:     if (Data.Direction==DirectionUp)
                          return(Pip(Data.PriceOpen-Data.PriceLow));
                        if (Data.Direction==DirectionDown)
                          return(Pip(Data.PriceHigh-Data.PriceOpen));
                        break;

      case ActualDraw:  if (Data.TimeClose>0)
                          return(Measure(Data,MaxDraw));
                        if (Data.Direction==DirectionUp)
                          return(fmax(Pip(Data.PriceOpen-Close[0]),0.00));
                        if (Data.Direction==DirectionDown)
                          return(fmax(Pip(Close[0]-Data.PriceOpen),0.00));
                        break;
                        
      default:          return(0);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::Show(void)
  {
    string uMessage = "";
    
    if (Current.GroupId>NoValue)
    {
      uMessage     = "New Fractal Group\n";
      uMessage    += "  Group ID: "+IntegerToString(Current.GroupId)+" {"+Pattern()+"}\n"
                    +"  Occurs: "+IntegerToString(Group[Current.GroupId].Count)+"\n"
                    +"  Degree (DoC): "+IntegerToString(Group[Current.GroupId].Degree)+"\n\n";

      uMessage    += "*----- History ------*\n";
      uMessage    += "Grp  Range   Price        Gain    Draw    Adv     Act\n";

      for (int idx=0;idx<ArraySize(History);idx++)
        uMessage += FormatData(History[idx]);
      
      uMessage    += "\n*----- Running ------*\n";
      uMessage    += "Grp  Range   Price        Gain    Draw    Adv     Act\n";

      for (int idx=0;idx<ArraySize(Running);idx++)
        uMessage += FormatData(Running[idx]);

      Comment(uMessage);
    }
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::Update(void)
  {    
    UpdateStatistics();
    
    int uFib = FibonacciId();    
  }
