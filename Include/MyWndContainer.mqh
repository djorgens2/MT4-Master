//+------------------------------------------------------------------+
//|                                               MyWndContainer.mqh |
//|                                                                  |
//|                                             https://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright ""
#property link      "https://www.mql4.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include <Controls\WndContainer.mqh>
#include <Controls\Label.mqh>

class MyWndContainer : public CWndContainer
  {
private:
   CLabel      lblMyLabel;
   bool        CreateMyLabel(void);

public:
                     MyWndContainer();
                    ~MyWndContainer();
                    
virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);  
                    
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MyWndContainer::MyWndContainer()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MyWndContainer::~MyWndContainer()
  {
  }
//+------------------------------------------------------------------+

bool MyWndContainer::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
   {
   if(!CWndContainer::Create(chart,name,subwin,x1,y1,x2,y2))  
      return(false);
   if(!CreateMyLabel())
      return(false);
   return(true);
   }      


bool MyWndContainer::CreateMyLabel(void)
  {
  if(!lblMyLabel.Create(m_chart_id,"lblMyLabel"+m_name, m_subwin,10,5,50,22))              
      return(false);
  lblMyLabel.Text("MyLabel:");
  lblMyLabel.FontSize(8);
  if(!Add(lblMyLabel))
      return(false);   
  return(true);    
  }