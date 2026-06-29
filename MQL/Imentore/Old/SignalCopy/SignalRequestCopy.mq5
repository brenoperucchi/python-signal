//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
#property version "1.28"
#property copyright   "Copyright"
#property description "Coded by Breno Perucchi"
#property strict

#define EXPERTNAME "signal_request_copy"
#define VERSION "1_28"

#define APPNAME "Signal Copy"
#define APPVERSION "1.28"

#include <MT4Orders.mqh> // если есть #include <Trade/Trade.mqh>, вставить эту строчку ПОСЛЕ
#include <MQL4_to_MQL5.mqh> // ТОЛЬКО для данного примера
#include <JAson.mqh>

//+------------------------------------------------------------------+
//| Enumerator of working mode                                       |
//+------------------------------------------------------------------+

input double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)
input double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
input double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
input int    Slippage                = 30;
input bool   EnvironmentLocal        = false;
bool   ServerReal                    = false;                   // Under real server (Default is false)
string prefix            = "";                             // Copied trade comment prefix
string Server            = "mt5-web-replicator.example.com";  // Subscribe server ip

uint   delay             = 1000;                           // Check frequency (milliseconds)
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
int MILLISECOND_TIMER = 1600;
string ACCOUNTLOGIN = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));

//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(DetectEnvironment() == false)
     {
      Print("Consultor Expert ", APPNAME + " " + APPVERSION, " não inicializado. Contacte o suporte.");
      return(INIT_FAILED);
     }
   else
     {      
      Print("Consultor Expert ", APPNAME + " " + APPVERSION, " inicializado com sucesso.");
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
   if(EnvironmentLocal)
     Server = "192.168.1.240:8080";   
     
   string orderdata[];
   string server_state;
   CJAVal jv;   
 
   if(ApiRequestInformation(orderdata, "none", "stores")){
      jv.Deserialize(orderdata[0]);
      server_state = jv["state"].ToStr();      
      ServerReal = bool(jv["server_real"].ToInt());
   }
   
   if(server_state == "" || server_state != "enable"){
    Print("Sua conta não está habilitada em nosso sistema. Fale com o suporte");
    return false;
   }
   
   if(ServerReal == false && IsDemoMQL4() == false)
     {
      Print("Sua conta não está habilitada para a conta real. Fale com o suporte");
      return false;
     }
    
    order_minlots = MinLots;
    order_maxlots = MaxLots;
    order_percentlots = (order_percentlots > 0) ? PercentLots : 100;
    order_slippage = Slippage;

    GetCurrentOrdersOnStart();
    EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input 
    
    return true;
  }

//+------------------------------------------------------------------+
//| FormatMessage                                                    |
//+------------------------------------------------------------------+
string MessageSendFormat(const string action)
  {
   string send_message = StringFormat("body={'account_login':'%s', 'magic_number':'%d', 'action':'%s', 'order_ticket':'%s', 'order_symbol':'%s', 'order_type':'%d', 'open_price':'%f', 'close_price':'%f', 'volume':'%f', 'stop_loss':'%f', 'take_profit':'%f', 'profit':'%f', 'comment':'%s', 'open_at':'%f'}",
                                      ACCOUNTLOGIN,
                                      OrderMagicNumber(),
                                      action,
                                      IntegerToString(OrderTicketID()),
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
bool ApiRequestInformation(string &orderdata[], const string action, const string kind)
  {
   // string account_id = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string cookie=NULL,headers,serverHeaders;
   char   post[],result[];

   // string server_url = "";
   // if(kind == "orders")
   //    server_url = Server +"/api/v1/transactions/request/"+action;
   // else
   string server_url = Server +"/api/v1/stores/config";

   string url="http://"+ server_url +"/"+ EXPERTNAME +"/"+ VERSION +"/"+ ACCOUNTLOGIN;
   ResetLastError();
   int response = WebRequest("POST", url, headers, 5000, post, result, serverHeaders);

   if(response==-1)
     {
      Print("Api código de erro: ",GetLastError());
      return false;
      // MessageBox("É necessário adicionar um endereço '"+url+"' à lista de URL permitidas na guia 'Experts'","Erro",MB_ICONINFORMATION);
     }
   else
     {
      if(response==201)
        {
         string result2 = CharArrayToString(result);
         int    size = StringSplit(result2, '/', orderdata);       
         return true;
        }
      else
         Print("Api código de erro: ",GetLastError(), ",  resposta: ", response);
         return false;
     }
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

        if (orderlot[orderindex] < OrderLots())
          {
            string send_message = MessageSendFormat("LOT_IN");
            ApiTrasmitInformation(send_message);
            changed_ticket ++;

            
          } else if(orderlot[orderindex] > OrderLots() && OrderLots() > 0){
            string send_message = MessageSendFormat("LOT_OUT");
            ApiTrasmitInformation(send_message);
            changed_ticket ++;
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