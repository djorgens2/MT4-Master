//+------------------------------------------------------------------+
//|                                                  MyAppDialog.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              https://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "https://www.mql4.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include <Controls\Dialog.mqh>
#include <MyWndContainer.mqh>

class MyAppDialog : public CAppDialog
  {
private:
   MyWndContainer    InstMyWndContainer;
   CLabel            lblMyAppLabel;
   bool              CreateMyContainer(void);
   bool              CreateMyAppLabel(void);

public:
                     MyAppDialog();
                    ~MyAppDialog();

virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);                    
                    
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MyAppDialog::MyAppDialog()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MyAppDialog::~MyAppDialog()
  {
  }
//+------------------------------------------------------------------+

bool MyAppDialog::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
//--- calling the method of the parent class
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2))  
      return(false);
//--- additional controls shall be created here
   if(!CreateMyContainer())
      return(false);
   if(!CreateMyAppLabel())
      return(false);   
   Run();
//--- success
   return(true);
  }
  
bool MyAppDialog::CreateMyContainer(void)
  {  
  if(!InstMyWndContainer.Create(m_chart_id,"My Container",m_subwin,0,0,0,300))
      return(false);
  if(!Add(InstMyWndContainer))
      return(false);  
  InstMyWndContainer.Show();       
  return(true);    
  }
  
bool MyAppDialog::CreateMyAppLabel(void)    
   {
   if(!lblMyAppLabel.Create(m_chart_id,"lblMyAppLabel"+m_name, m_subwin,100,5,50,102))              
      return(false);
  lblMyAppLabel.Text("MyAppLabel:");
  lblMyAppLabel.FontSize(8);
  if(!Add(lblMyAppLabel))
      return(false);
   return(true);
   }