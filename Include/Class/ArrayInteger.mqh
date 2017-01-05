//+------------------------------------------------------------------+
//|                                                  ArrayInteger.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\Array.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CArrayInteger : public CArray
  {
private:

   int               intArray[];
   int               arrPrecision;
   
   //--- properties
   double            adAverage;
   double            adMin;
   double            adMax;
   double            adMid;
   double            adRange;
   double            adSum;
   double            adSumNeg;
   double            adSumPos;
   double            adCountNeg;
   double            adCountPos;
   double            adCountZero;
   double            adMeanNonZero;
   double            adMeanNeg;
   double            adMeanPos;
   double            adMeanAbs;
   double            adMeanAbsMid;

public:
                     CArrayInteger(const int elements);
                    ~CArrayInteger(){};


   //--- method of identifying the object
   virtual int       Type(void) const { return(TYPE_INT); }

   //--- methods for working with files
   virtual bool      Save(const int file_handle);
   virtual bool      Load(const int file_handle);

   void              Resize(const int elements);
   
   //--- methods of using the array
   int               Find(const int element);
   bool              Found(const int element) { if (Find(element)>(-1)) return (true); return (false); }
   void              Add(const int element, bool Unique=false);
   void              Insert(const int index, const int element);
   void              Delete(const int index);
   void              Initialize(const int value);

   void              Copy(int &Data[]) {ArrayCopy(Data,intArray,0,0,MaxSize());}
   void              CopyNonZero(int &Data[], const int elements);
   void              Compute(void);

   void              SetAutoCompute(int Auto=false, int IndexBegin=0, int IndexEnd=0);
   void              SetValue(const int index, int value) { intArray[index] = value; }
   void              SetPrecision(int Precision=1) { arrPrecision = Precision; }
   
   double            Average(void) { return (adAverage); }
   double            Minimum(void) { return (adMin); }
   double            Maximum(void) { return (adMax); }
   double            Mid(void) { return (adMid); }
   double            Range(void) { return (adRange); }
   double            Sum(void) { return (adSum); }
   double            SumNeg(void) { return (adSumNeg); }
   double            SumPos(void) { return (adSumPos); }
   double            CountNeg(void) { return (adCountNeg); }
   double            CountPos(void) { return (adCountPos); }
   double            CountZero(void) { return (adCountZero); }
   double            MeanNonZero(void) { return (adMeanNonZero); }
   double            MeanNeg(void) { return (adMeanNeg); }
   double            MeanPos(void) { return (adMeanPos); }
   double            MeanAbs(void) { return (adMeanAbs); }
   double            MeanAbsMid(void) { return (adMeanAbsMid); }

   int operator[](const int index) const { return(intArray[index]); }


protected:

    bool             Reserve(const int elements);
    bool             AutoCompute;
    
    int              ComputeIndexBegin;
    int              ComputeIndexEnd;

  };
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CArrayInteger::CArrayInteger(const int elements)
  {
    Count     = 0;

    arrMaximum   = elements;
    
    SetPrecision();
    Resize(arrMaximum);
  }

//+------------------------------------------------------------------+
//| Initialize - sets each element to the supplied default value     |
//+------------------------------------------------------------------+
void CArrayInteger::Initialize(const int value)
  {

    Count = ArraySize(intArray);

    ArrayInitialize(intArray,value);
  }

//+------------------------------------------------------------------+
//| Initialize - sets each element to the supplied default value     |
//+------------------------------------------------------------------+
void CArrayInteger::SetAutoCompute(int Auto=false, int IndexBegin=0, int IndexEnd=0)
  {
    AutoCompute        = Auto;
    ComputeIndexBegin  = IndexBegin;
    ComputeIndexEnd    = IndexEnd;
  }


//+------------------------------------------------------------------+
//| Resize - rezizes the array                                       |
//+------------------------------------------------------------------+
void CArrayInteger::Resize(const int elements)
  {
    arrMaximum = elements;

    if (Count>elements)
      Count = elements;

    ArrayResize(intArray,elements);
  }
 
//+------------------------------------------------------------------+
//| CopyNonZero - Returns non-zero values only from the class array  |
//+------------------------------------------------------------------+
void CArrayInteger::CopyNonZero(int &Data[], const int elements)
  {
    double buffer[];
    int    count = 0;
    
    ArrayResize(buffer,elements);
    ArrayInitialize(buffer,0.00);
    
    for (int idx=0;idx<arrMaximum&&count<elements;idx++)
      if (intArray[idx] > 0.00)
        buffer[count++] = intArray[idx];

    if (count>0)
    {
      ArrayResize(Data,count);
      ArrayCopy(Data,buffer,0,0,count);
    }
  }

//+------------------------------------------------------------------+
//| Reserve - returns true if array has available elements           |
//+------------------------------------------------------------------+
bool CArrayInteger::Reserve(const int elements)
  {
    if (Available() < elements)
      if (!AutoExpand)
        return (false);
      else
      {
        arrMaximum += elements;
        ArrayResize(intArray,arrMaximum);
      }
            
    return (true);
  }

//+------------------------------------------------------------------+
//| Insert - Insert a new element at the index of the array          |
//+------------------------------------------------------------------+
void CArrayInteger::Insert(const int index, const int element)
  {
    //--- check/reserve elements of array
    if (Reserve(1))
    {
      for (int idx=Count; idx>index; idx--)
        intArray[idx]       = intArray[idx-1];

      Count++;
    }
    else
    if (Truncate)
      for (int idx=Count-1; idx>index; idx--)
        intArray[idx]       = intArray[idx-1];
    else
      //--- force an array bounds exception    
      intArray[arrMaximum]  = element;

    //--- insert
    intArray[index]         = element;

    if (AutoCompute)
      Compute();
  }

//+------------------------------------------------------------------+
//| Adding an element to the end of the array                        |
//+------------------------------------------------------------------+
void CArrayInteger::Add(const int element, bool Unique=false)
  {
    //--- check uniqueness
    if (Unique)
      if (Find(element)>(-1))
        return;
        
    //--- check/reserve elements of array
    if (Reserve(1))
      intArray[Count++] = element;
    else
    if (Truncate)
      for (int idx=0; idx<Count-2; idx++)
        intArray[idx]   = intArray[idx+1];
    else
      //--- force an array bounds exception
      intArray[Count]   = element;

    if (AutoCompute)
      Compute();
  }

//+------------------------------------------------------------------+
//| Delete - removes the supplied element (index) from the array     |
//+------------------------------------------------------------------+
void CArrayInteger::Delete(const int index)
  {
    //--- assume implementor understands that index is 0-base
    if (index<Count)
    {
      for (int idx=index; idx<Count-1; idx++)
        intArray[idx]   = intArray[idx+1];
        
      Resize(--Count);

      if (AutoCompute)
        Compute();
    }
  }

//+------------------------------------------------------------------+
//| Find an element in the array                                     |
//+------------------------------------------------------------------+
int CArrayInteger::Find(const int element)
  {
    //--- check/reserve elements of array
    for (int idx=0; idx<Count; idx++)
      if (element == intArray[idx])
        return(idx);
        
    return(-1);
  }
  
//+------------------------------------------------------------------+
//| Calculate - calculate basic metrics on the numeric values        |
//+------------------------------------------------------------------+
void CArrayInteger::Compute()
  {
    int Calculated   = 0;

    adAverage          = 0.00;
    adMin              = 0.00;
    adMax              = 0.00;
    adMid              = 0.00;
    adRange            = 0.00;
    adSum              = 0.00;
    adSumNeg           = 0.00;
    adSumPos           = 0.00;
    adCountNeg         = 0;
    adCountPos         = 0;
    adCountZero        = 0;
    adMeanNonZero      = 0.00;
    adMeanNeg          = 0.00;
    adMeanPos          = 0.00;
    adMeanAbs          = 0.00;
    adMeanAbsMid       = 0.00;
    

    if (Count>0)
    {
      adMax     = NormalizeDouble(intArray[0],Digits);
      adMin     = NormalizeDouble(intArray[0],Digits);
          
      for (int idx=ComputeIndexBegin; idx<fmin(Count,ComputeIndexEnd); idx++)
      {
        Calculated++;
        
        adSum         += NormalizeDouble(intArray[idx],arrPrecision);
        adMin          = fmin(NormalizeDouble(adMin,arrPrecision),NormalizeDouble(intArray[idx],arrPrecision));
        adMax          = fmax(NormalizeDouble(adMax,arrPrecision),NormalizeDouble(intArray[idx],arrPrecision));
        
        if (NormalizeDouble(intArray[idx],arrPrecision)>0.00)
        {
          adSumPos    += NormalizeDouble(intArray[idx],arrPrecision);
          adCountPos++;
        }
        else
        if (NormalizeDouble(intArray[idx],arrPrecision)<0.00)
        {
          adSumNeg     += NormalizeDouble(intArray[idx],arrPrecision);
          adCountNeg++;
        }
        else
          adCountZero++;
      }
    
      adAverage       =  NormalizeDouble(adSum/Calculated,arrPrecision);
      adRange         =  NormalizeDouble(adMax,arrPrecision)-NormalizeDouble(adMin,arrPrecision);
      adMid           = (NormalizeDouble(adRange,arrPrecision)/2)+NormalizeDouble(adMin,arrPrecision);

      if (adCountPos+adCountNeg>0)
      {
        if (adCountPos>0)
          adMeanPos   =  NormalizeDouble(adSumPos,arrPrecision)/adCountPos;
        
        if (adCountNeg>0)
          adMeanNeg   =  NormalizeDouble(adSumNeg,arrPrecision)/adCountNeg;

        adMeanNonZero = (NormalizeDouble(adSumPos,arrPrecision)+NormalizeDouble(adSumNeg,arrPrecision))/(adCountPos+adCountNeg);
        adMeanAbs     = (NormalizeDouble(adMeanPos,arrPrecision)+NormalizeDouble(fabs(adMeanNeg),arrPrecision))/2;
        adMeanAbsMid  =  NormalizeDouble(adMeanAbs,arrPrecision)/2;
      }
    }
  }
