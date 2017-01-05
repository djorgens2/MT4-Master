//+------------------------------------------------------------------+
//|                                                        Array.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\Object.mqh>

class CArray : public CObject
  {
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
protected:

   int               arrMaximum;         // maximmum size of the array without memory reallocation
   
   
public:
                     CArray(void): Count(0),
                                   arrMaximum(0),
                                   AutoExpand(false),
                                   Truncate(false)
                                   {};
                    ~CArray(void){};

   //--- methods of access to protected data
   int               Count;
   int               Available(void) const { return(arrMaximum-Count); }
   int               MaxSize(void) const { return(arrMaximum); }

   //--- cleaning method
   void              Clear(void) {Count=0;}

   //--- methods for working with files
   virtual bool      Save(const int file_handle);
   virtual bool      Load(const int file_handle);
   virtual int       Type(void);


   //--- Public behavior parameters
   bool              Truncate;
   bool              AutoExpand;
   
   
  };