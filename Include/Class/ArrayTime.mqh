//+------------------------------------------------------------------+
//|                                                  ArrayDouble.mqh |
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
class CArrayDouble : public CArray
  {
private:

   datetime          dtArray[];

   //--- properties
   double            adAverage;
   double            adMin;
   double            adMax;
   double            adMid;
   double            adRange;
   double            adTotal;
   double            adBegin;
   double            adEnd;

public:
                     CArrayDouble(const int elements);
                    ~CArrayDouble(){};


   //--- method of identifying the object
   virtual int       Type(void) const { return(TYPE_DOUBLE); }

   //--- methods for working with files
   virtual bool      Save(const int file_handle);
   virtual bool      Load(const int file_handle);

   void              Resize(const int elements);
   
   //--- methods of using the array
   int               Find(const double element);
   void              Sort(int beg,int end);
   void              Add(const double element);
   void              Insert(const int index, const double element);
   void              Delete(const int index);
   void              Initialize(const double value);

   void              Copy(double &Data[]) {ArrayCopy(Data,dblArray,0,0,MaxSize());}
   void              CopyNonZero(double &Data[], const int elements);
   void              Compute(void);

   void              SetPrecision(int Precision) {arrPrecision=Precision;};
   void              SetAutoCompute(int Auto=false);
   void              SetValue(const int index, double value) { dblArray[index] = value; }
   
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

   double operator[](const int index) const { return(dblArray[index]); }


protected:

    bool             Reserve(const int elements);
    bool             AutoCompute;
  };
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CArrayDouble::CArrayDouble(const int elements)
  {
    Count     = 0;

    arrMaximum   = elements;
    arrPrecision = Digits;
    
    Resize(arrMaximum);
  }

//+------------------------------------------------------------------+
//| Initialize - sets each element to the supplied default value     |
//+------------------------------------------------------------------+
void CArrayDouble::Initialize(const double value)
  {

    Count = ArraySize(dblArray);

    ArrayInitialize(dblArray,value);
  }

//+------------------------------------------------------------------+
//| Initialize - sets each element to the supplied default value     |
//+------------------------------------------------------------------+
void CArrayDouble::SetAutoCompute(int Auto=false)
  {
    AutoCompute        = Auto;
  }


//+------------------------------------------------------------------+
//| Resize - rezizes the array                                       |
//+------------------------------------------------------------------+
void CArrayDouble::Resize(const int elements)
  {
    arrMaximum = elements;

    if (Count>elements)
      Count = elements;

    ArrayResize(dblArray,elements);
  }
 
//+------------------------------------------------------------------+
//| CopyNonZero - Returns non-zero values only from the class array  |
//+------------------------------------------------------------------+
void CArrayDouble::CopyNonZero(double &Data[], const int elements)
  {
    double buffer[];
    int    count = 0;
    
    ArrayResize(buffer,elements);
    ArrayInitialize(buffer,0.00);
    
    for (int idx=0;idx<arrMaximum&&count<elements;idx++)
      if (NormalizeDouble(dblArray[idx],arrPrecision)>0.00)
        buffer[count++] = NormalizeDouble(dblArray[idx],arrPrecision);

    if (count>0)
    {
      ArrayResize(Data,count);
      ArrayCopy(Data,buffer,0,0,count);
    }
  }

//+------------------------------------------------------------------+
//| Reserve - returns true if array has available elements           |
//+------------------------------------------------------------------+
bool CArrayDouble::Reserve(const int elements)
  {
    if (Available() < elements)
      if (!AutoExpand)
        return (false);
      else
      {
        arrMaximum += elements;
        ArrayResize(dblArray,arrMaximum);
      }
            
    return (true);
  }

//+------------------------------------------------------------------+
//| Insert - Insert a new element at the index of the array          |
//+------------------------------------------------------------------+
void CArrayDouble::Insert(const int index, const double element)
  {
    //--- check/reserve elements of array
    if (Reserve(1))
    {
      for (int idx=Count; idx>index; idx--)
        dblArray[idx]=NormalizeDouble(dblArray[idx-1],arrPrecision);

      Count++;
    }
    else
    if (Truncate)
      for (int idx=Count-1; idx>index; idx--)
        dblArray[idx]=NormalizeDouble(dblArray[idx-1],arrPrecision);
    else
      //--- force an array bounds exception    
      dblArray[arrMaximum]=NormalizeDouble(element,arrPrecision);

    //--- insert
    dblArray[index]=NormalizeDouble(element,arrPrecision);
    
    if (AutoCompute)
      Compute();
  }

//+------------------------------------------------------------------+
//| Adding an element to the end of the array                        |
//+------------------------------------------------------------------+
void CArrayDouble::Add(const double element)
  {
    //--- check/reserve elements of array
    if (Reserve(1))
      dblArray[Count++]=NormalizeDouble(element,arrPrecision);
    else
    if (Truncate)
      for (int idx=0; idx<Count-2; idx++)
        dblArray[idx]=NormalizeDouble(dblArray[idx+1],Digits);
    else
      //--- force an array bounds exception
      dblArray[Count]=NormalizeDouble(element,arrPrecision);

    if (AutoCompute)
      Compute();
  }

//+------------------------------------------------------------------+
//| Delete - removes the supplied element (index) from the array     |
//+------------------------------------------------------------------+
void CArrayDouble::Delete(const int index)
  {
    //--- assume implementor understands that index is 0-base
    if (index<Count)
    {
      for (int idx=index; idx<Count-1; idx++)
        dblArray[idx]=NormalizeDouble(dblArray[idx+1],arrPrecision);
        
      Resize(--Count);

      if (AutoCompute)
        Compute();
    }
  }

//+------------------------------------------------------------------+
//| Find an element in the array                                     |
//+------------------------------------------------------------------+
int CArrayDouble::Find(const double element)
  {
    //--- check/reserve elements of array
    for (int idx=0; idx<Count; idx++)
      if (NormalizeDouble(element,arrPrecision)==NormalizeDouble(dblArray[idx],Digits))
        return(idx);
        
    return(-1);
  }
  
//+------------------------------------------------------------------+
//| Calculate - calculate basic metrics on the numeric values        |
//+------------------------------------------------------------------+
void CArrayDouble::Compute()
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
    
    if (Count==0)
      return;
      
    adMax     = NormalizeDouble(dblArray[0],Digits);
    adMin     = NormalizeDouble(dblArray[0],Digits);
          
    for (int idx=0; idx<Count; idx++)
    {
      Calculated++;
        
      adSum         += NormalizeDouble(dblArray[idx],arrPrecision);
      adMin          = fmin(NormalizeDouble(adMin,arrPrecision),NormalizeDouble(dblArray[idx],arrPrecision));
      adMax          = fmax(NormalizeDouble(adMax,arrPrecision),NormalizeDouble(dblArray[idx],arrPrecision));
        
      if (NormalizeDouble(dblArray[idx],arrPrecision)>0.00)
      {
        adSumPos    += NormalizeDouble(dblArray[idx],arrPrecision);
        adCountPos++;
      }
      else
      if (NormalizeDouble(dblArray[idx],arrPrecision)<0.00)
      {
        adSumNeg     += NormalizeDouble(dblArray[idx],arrPrecision);
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

//+------------------------------------------------------------------+
//| Sort                                                 |
//+------------------------------------------------------------------+
void CArrayDouble::Sort(int beg,int end)
  {
   int    i,j;
   double p_double,t_double;

//--- check
   if(beg<0 || end<0)
      return;

//--- sort
   i=beg;
   j=end;
   
   while(i<end)
     {
      //--- ">>1" is quick division by 2
      p_double=dblArray[(beg+end)>>1];
      while(i<j)
        {
         while(dblArray[i]<p_double)
           {
            //--- control the output of the array bounds
            if(i==end)
               break;
            i++;
           }
         while(dblArray[j]>p_double)
           {
            //--- control the output of the array bounds
            if(j==0)
               break;
            j--;
           }
         if(i<=j)
           {
            t_double=dblArray[i];
            dblArray[i++]=dblArray[j];
            dblArray[j]=t_double;
            //--- control the output of the array bounds
            if(j==0)
               break;
            j--;
           }
        }
      if(beg<j)
         Sort(beg,j);
      beg=i;
      j=end;
     }
  }