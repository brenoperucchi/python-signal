//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
#property version "1.0.8"
#property copyright   "Copyright 2021"
#property description "Coded by Breno Perucchi"
#property strict
#define EXPERTNAME "signal_request_copy"
#define VERSION "1_0_8"

#include <MT4Orders.mqh> // если есть #include <Trade/Trade.mqh>, вставить эту строчку ПОСЛЕ
#include <MQL4_to_MQL5.mqh> // ТОЛЬКО для данного примера

//--- Declaration of constants
//#define OP_BUY 0           //Buy 
//#define OP_SELL 1          //Sell 
//#define OP_BUYLIMIT 2      //Pending order of BUY LIMIT type 
//#define OP_SELLLIMIT 3     //Pending order of SELL LIMIT type 
//#define OP_BUYSTOP 4       //Pending order of BUY STOP type 
//#define OP_SELLSTOP 5      //Pending order of SELL STOP type 
//---
#define MODE_OPEN 0
#define MODE_CLOSE 3
#define MODE_VOLUME 4
#define MODE_REAL_VOLUME 5
//#define MODE_TRADES 0
//#define MODE_HISTORY 1
//#define SELECT_BY_POS 0
//#define SELECT_BY_TICKET 1
//---
#define DOUBLE_VALUE 0
#define FLOAT_VALUE 1
#define LONG_VALUE INT_VALUE
//---
#define CHART_BAR 0
#define CHART_CANDLE 1
//---
#define MODE_ASCEND 0
#define MODE_DESCEND 1
//---
#define MODE_LOW 1
#define MODE_HIGH 2
#define MODE_TIME 5
//#define MODE_BID 9
//#define MODE_ASK 10
//#define MODE_POINT 11
//#define MODE_DIGITS 12
//#define MODE_SPREAD 13
//#define MODE_STOPLEVEL 14
//#define MODE_LOTSIZE 15
//#define MODE_TICKVALUE 16
#define MODE_TICKSIZE 17
#define MODE_SWAPLONG 18
#define MODE_SWAPSHORT 19
#define MODE_STARTING 20
#define MODE_EXPIRATION 21
#define MODE_TRADEALLOWED 22
//#define MODE_MINLOT 23
//#define MODE_LOTSTEP 24
//#define MODE_MAXLOT 25
#define MODE_SWAPTYPE 26
#define MODE_PROFITCALCMODE 27
#define MODE_MARGINCALCMODE 28
#define MODE_MARGININIT 29
#define MODE_MARGINMAINTENANCE 30
#define MODE_MARGINHEDGED 31
#define MODE_MARGINREQUIRED 32
#define MODE_FREEZELEVEL 33
//---
#define EMPTY -1

//+------------------------------------------------------------------+
//| Enumerator of working mode                                       |
//+------------------------------------------------------------------+

input double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)
input double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
input double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
input int    Slippage                = 3;
input bool   ServerReal              = false;                   // Under real server (Default is false)
string prefix                        = "";     // Copied trade comment prefix

string Server            = "192.168.1.240";  // Subscribe server ip
const string app_name    = "Expert Advisor";
uint   delay             = 1000;            // Check frequency (milliseconds)
int    prev_ordersize    = 0;
int    ordersize         = 0;
long    orderids[];
double orderopenprice[];
double orderlot[];
double ordersl[];
double ordertp[];
bool   orderchanged      = false;
//--- Globales Order
bool   order_allowopen   = true;
bool   order_allowclose  = true;
bool   order_allowmodify = true;
bool   order_invert      = false;
int    account_subscriber    = 0;
double account_minmarginfree = 0.00;
double order_minlots     = 0.00;
double order_maxlots     = 0.00;
double order_percentlots = 1;
int    order_slippage    = 0;
int MILLISECOND_TIMER = 2000;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class OrderContainer
  {
public:
   long              trace_id;
   string            symbol;
   long              transaction_id;
   long              type;
   double            price;
   double            lot;
   double            stoploss;
   double            takeprofit;
   long              magicnumber;
   string            comment;
                     OrderContainer(void);
                    ~OrderContainer(void)
     {
     }

                     OrderContainer(long ptrace_id,
                  string psymbol,
                  long ptransaction_id,
                  long ptype,
                  double pprice,
                  double plot,
                  double pstoploss,
                  double ptakeprofit,
                  long pmagicnumber,
                  string pcomment)
     {
      trace_id = ptrace_id;
      symbol = psymbol;
      transaction_id = ptransaction_id;
      type=ptype;
      price=pprice;
      lot=plot;
      stoploss=pstoploss;
      takeprofit=ptakeprofit;
      magicnumber= pmagicnumber;
      comment = pcomment;

      if(StringSubstr(psymbol,0,StringLen(prefix))==prefix)
       {
        // copiedFrom=StringToInteger(StringSubstr(pcomment,StringLen(prefix)));
        // TODO TEST!!!!!!
        symbol = StringSubstr(psymbol,StringLen(prefix));
       }
     }
  };
  
//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
  { 
    if (DetectEnvironment() == false)
      {
        Alert("Error: The property is fail, please check and try again.");
        Print("Failed INIT");
        return(INIT_FAILED);
      } else {
        if (account_subscriber > 0)
          Print("Signal Account: " + IntegerToString(account_subscriber));
        EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input  
        GetCurrentOrdersOnStart();
        Print("Success INIT"); 
        return(INIT_SUCCEEDED);
      }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
}

void OnTimer() {
  int  changed = 0;
  changed = GetCurrentOrdersOnTicket();

  if(changed > 0)
     UpdateCurrentOrdersOnTicket();
}

//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   return;
  }

//+------------------------------------------------------------------+
//| Detect the script parameters                                     |
//+------------------------------------------------------------------+
bool DetectEnvironment()
  {
    if (Server == "") 
      return false;
    
    if (ServerReal == true && IsDemoMQL4())
      {
        Print("Account is Demo, please switch the Demo account to Real account.");
        return false;
      }
      
    if (TerminalInfoInteger(TERMINAL_DLLS_ALLOWED) == false)
      {
        Print("DLL call is not allowed. ", app_name, " cannot run.");
        return false;
      }
    
    order_minlots = MinLots;
    order_maxlots = MaxLots;
    order_percentlots = (order_percentlots > 0) ? PercentLots : 100;
    order_slippage = Slippage;
    
    //account_subscriber = (SignalAccount != "") ? StringToInteger(SignalAccount) : -1;
    //account_minmarginfree = MinFreeMargin;

    return true;
  }

//+------------------------------------------------------------------+
//| FormatMessage                                                    |
//+------------------------------------------------------------------+
string MessageSendFormat(const string action)
  {
   string send_message = StringFormat("body={'account_login':'%d', 'magic_number':'%d', 'action':'%s', 'order_ticket':'%d', 'order_symbol':'%s', 'order_type':'%d', 'open_price':'%f', 'close_price':'%f', 'volume':'%f', 'stop_loss':'%f', 'take_profit':'%f', 'profit':'%f', 'comment':'%s', 'open_at':'%f'}",
                                      AccountInfoInteger(ACCOUNT_LOGIN),
                                      OrderMagicNumber(),
                                      action,
                                      OrderTicketID(),
                                      OrderSymbol(),
                                      OrderType(),
                                      OrderOpenPrice(),
                                      OrderClosePrice(),
                                      OrderLots(),
                                      OrderStopLoss(),
                                      OrderTakeProfit(),
                                      OrderProfit(),
                                      OrderComment(),
                                      OrderOpenTime()
                                     );
   return send_message;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiTrasmitInformation(const string message)
  {
     {
      string account_id = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
      string url="http://"+ Server +"/api/v1/transactions/copy/trasmit/"+ EXPERTNAME +"/"+ VERSION +"/"+ account_id;
      string cookie=NULL,headers;
      int response = 0;
      char post[],result[];
      int count = 0;
      ResetLastError();
      StringToCharArray(message, post,0, StringLen(message));
      while(response != 201 && count <=200)
        {
         response=WebRequest("POST",url,cookie,NULL,500,post,0,result,headers);
         if(response == 201)
           {
            string response_data[];
            string result2 = CharArrayToString(result);
            int    size = StringSplit(result2, '|', response_data);
            if(size !=3)
               continue;
            if(response_data[2] == "OK")
               return true;
           }
         if(response == -1)
           {
            Print("Erro no WebRequest. Código de erro =",GetLastError());
            // MessageBox("É necessário adicionar um endereço '"+url+"' à lista de URL permitidas na guia 'Experts'","Erro",MB_ICONINFORMATION);
           }
         count++;
        }
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Parse the message from server signal                             |
//+------------------------------------------------------------------+
bool ParseMessage(const string message,
                  string &orderdataparse[])
  {
   if(message == "")
      return false;

   int    size = StringSplit(message, '|', orderdataparse);
   return true;
  }

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindOrderBySingalComment(const string comment)
  {
   long ticketid = -1;

   ordersize  = OrdersTotal();
   int orderindex = 0;

   for(orderindex=0; orderindex<ordersize; orderindex++)
     {
      if(OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
         continue;

      string ordercomment = OrderComment();

      if(ordercomment == comment)
         ticketid = OrderTicket();

      if(ticketid > 0)
         break;
     }

   return ticketid;
  }

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
int GetCurrentOrdersOnTicket()
  { 
    ordersize = OrdersTotal();
       
    int changed_ticket = 0;
             
    if (ordersize > prev_ordersize)
      {
        // Trade has been added
        changed_ticket = PushOrderOpen();
      }
    else if (ordersize < prev_ordersize)
      {
        // Trade has been closed
        changed_ticket = PushOrderClosed();
      }
    else if (ordersize == prev_ordersize)
      {
        // Trade has been modify
        changed_ticket = PushOrderModify();
      }
      
    return changed_ticket;
  }

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
void GetCurrentOrdersOnStart()
  {
   prev_ordersize = 0;
   ordersize = OrdersTotal();

   if(ordersize == prev_ordersize)
      return;

   if(ordersize > 0)
     {
      ArrayResize(orderids, ordersize);
      ArrayResize(orderopenprice, ordersize);
      ArrayResize(orderlot, ordersize);
      ArrayResize(ordersl, ordersize);
      ArrayResize(ordertp, ordersize);
     }

   prev_ordersize = ordersize;

   int orderindex = 0;

// Save the orders to cache
   for(orderindex=0; orderindex<ordersize; orderindex++)
     {
      if(OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
         continue;

      orderids[orderindex] = OrderTicket();
      orderopenprice[orderindex] = OrderOpenPrice();
      orderlot[orderindex] = OrderLots();
      ordersl[orderindex] = OrderStopLoss();
      ordertp[orderindex] = OrderTakeProfit();
     }
  }

//+------------------------------------------------------------------+
//| Update all of the orders status                                  |
//+------------------------------------------------------------------+
void UpdateCurrentOrdersOnTicket()
  {
   if(ordersize > 0)
     {
      ArrayResize(orderids, ordersize);
      ArrayResize(orderopenprice, ordersize);
      ArrayResize(orderlot, ordersize);
      ArrayResize(ordersl, ordersize);
      ArrayResize(ordertp, ordersize);
     }

   int orderindex = 0;

// Save the orders to cache
   for(orderindex=0; orderindex<ordersize; orderindex++)
     {
      if(OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
         continue;

      orderids[orderindex] = OrderTicket();
      orderopenprice[orderindex] = OrderOpenPrice();
      orderlot[orderindex] = OrderLots();
      ordersl[orderindex] = OrderStopLoss();
      ordertp[orderindex] = OrderTakeProfit();
     }

// Changed the old orders count as current orders count
   prev_ordersize = ordersize;
  }

//+------------------------------------------------------------------+
//| Push the open order to all of the subscriber                     |
//+------------------------------------------------------------------+
int PushOrderOpen()
  {
    int changed_ticket    = 0;
    int orderindex = 0;
 
    for (orderindex=0; orderindex<ordersize; orderindex++)
      {
        if (OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
          continue;
            
        if (FindOrderInPrevPool(OrderTicket()) == false)
          {

            Print("Order Added:", OrderSymbol(), ", Size:", ArraySize(orderids), ", OrderId:", OrderTicket());
            
            string send_message = MessageSendFormat("OPEN");
            ApiTrasmitInformation(send_message);        
                 
            changed_ticket ++;
          }
      }
     
    return changed_ticket;
  }

//+------------------------------------------------------------------+
//| Push the close order to all of the subscriber                    |
//+------------------------------------------------------------------+
int PushOrderClosed()
  {
    int      changed_ticket    = 0;
    int      orderindex = 0;
    datetime ctm;
  
    for (orderindex=0; orderindex<prev_ordersize; orderindex++)
      {         
        if (OrderSelect(orderids[orderindex], SELECT_BY_TICKET, MODE_TRADES) == false)
          continue;

        ctm = OrderCloseTime();
            
        if (ctm > 0)
          {
            Print("Order Closed:", OrderSymbol(), ", Size:", ArraySize(orderids), ", OrderId:", OrderTicket());

            string send_message = MessageSendFormat("CLOSE");
            ApiTrasmitInformation(send_message);

            changed_ticket ++;
          }
      }
          
    return changed_ticket;
  }

//+------------------------------------------------------------------+
//| Push the modify order to all of the subscriber                   |
//+------------------------------------------------------------------+
int PushOrderModify()
  {
    int changed_ticket    = 0;
    int orderindex = 0;
    
    for (orderindex=0; orderindex<ordersize; orderindex++)
      {
        orderchanged = false;

        if (OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
          continue;          

        if (orderlot[orderindex] != OrderLots())
          {
            orderchanged = true;
            
            string ordercomment = OrderComment();
            int    orderid      = 0;
            
          }

        if (ordersl[orderindex] != OrderStopLoss())
          orderchanged = true;

        if (ordertp[orderindex] != OrderTakeProfit())
          orderchanged = true;

        // Temporarily method for recognize modify order or part-closed order
        // Part-close order will close order by a litte lots and re-generate an new order with new order id
        if (orderchanged == true)
          {
            string send_message = MessageSendFormat("MODIFY");
            ApiTrasmitInformation(send_message);
            
            changed_ticket ++;
          }
      }

    return changed_ticket;
  }

//+------------------------------------------------------------------+
//| Find a order by ticket id                                        |
//+------------------------------------------------------------------+
bool FindOrderInPrevPool(const long order_ticketid)
  {
    int orderfound = 0;
    int orderindex = 0;
    
    if (prev_ordersize == 0)
      return false;
  
    for (orderindex=0; orderindex<prev_ordersize; orderindex++)
      {
        if (order_ticketid == orderids[orderindex])
          orderfound ++;
      }
      
    return (orderfound > 0) ? true : false;
  }

//+------------------------------------------------------------------+
//| Get the order lots is greater than or less than max and min lots |
//+------------------------------------------------------------------+
double GetOrderLots(const string symbol, const double lots)
  {
   double result = lots;

   if(order_percentlots > 0)
     {
      result = lots * (order_percentlots / 100);
     }

   if(order_minlots > 0.00)
      result = (lots <= order_minlots) ? order_minlots : result;

   if(order_maxlots > 0.00)
      result = (lots >= order_maxlots) ? order_maxlots : result;

   if(order_percentlots > 0)
     {
      double s_maxlots = MarketInfo(symbol, MODE_MAXLOT);
      double s_mixlots = MarketInfo(symbol, MODE_MINLOT);

      if(result > s_maxlots)
         result = s_maxlots;

      if(result < s_mixlots)
         result = s_mixlots;
     }

   return result;
  }

//+------------------------------------------------------------------+
//| MQL4 -> MQL5                                                     |
//+------------------------------------------------------------------+

bool IsDemoMQL4()
  {
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO)
      return(true);
   else
      return(false);
  }

//+------------------------------------------------------------------+
