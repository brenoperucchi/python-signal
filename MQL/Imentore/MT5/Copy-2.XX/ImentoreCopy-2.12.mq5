//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
#property version "2.12"
#property copyright   "Copyright"
#property description "Coded by Breno Perucchi"
#property strict

#define EXPERTNAME "imentore_copy"
#define VERSION "2_12"

#define APPNAME "Imentore Copy"
#define APPVERSION "2.12"

#include <MT4Orders.mqh> // если есть #include <Trade/Trade.mqh>, вставить эту строчку ПОСЛЕ
#include <MQL4_to_MQL5.mqh> // ТОЛЬКО для данного примера
#include <JAson.mqh>


double lots=0.1;        // volume in lots
double kATR=3;          // signal candle length in ATR
int    ATRperiod=20;    // ATR indicator period
int    holdbars=8;      // number of bars to hold position on
int    slippage=10;     // allowable slippage
bool   revers=false;    // reverse the signal? 
ulong  EXPERT_MAGIC=0;  // EA's MagicNumber
//--- for storing the ATR indicator handle
int atr_handle;
//--- here we will store the last ATR values and the candle body
double last_atr,last_body;
datetime lastbar_timeopen;
double trade_lot;
//+----------------
   

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)
input double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
input double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
input int    Slippage                = 30;
input bool   EnvironmentLocal        = false;

//+------------------------------------------------------------------+
//| Enumerator of working mode                                       |
//+------------------------------------------------------------------+
string ACCOUNTLOGIN            = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
string API_VERSION             = "v2";
int    MILLISECOND_TIMER       = 1600;
string ACCOUNT_SERVER_NAME     = "";


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool   ServerReal              = false;                    // Under real server (Default is false)
string prefix            = "";                             // Copied trade comment prefix
string Server            = "mt5-web-replicator.example.com";      // Subscribe server ip

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
uint   delay             = 1000;                           // Check frequency (milliseconds)
long   orderids[];
long   ordertypes[];
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

string orders[];
string store_state;
string store_message;
string account_state;
string account_margin_mode;
string account_mode;                // Under real server (Default is false)
string api_server_hostname;
int timecurrent1 = int(TimeTradeServer());
int timecurrent2 = int(TimeTradeServer());
long order_size = 0;
long orders_size = 0;
double MaximumRisk        = 0.02;    // Maximum Risk in percentage
double DecreaseFactor     = 3;       // Descrease factor
int    MovingPeriod       = 12;      // Moving Average period
int    MovingShift        = 6;       // Moving Average shift


string commentOnChart[];

long comment_mfe_mae_line_item = 0;
long commentLineItemMakeOrder = 0;
long commentLineItemOrder = 0;
string comment_order_status;

datetime currentDay = TimeLocal() - TimeLocal() % 86400;
double MFE = 0;
double MAE = 0;


//---

CJAVal order_jason;
CJAVal jv;

//+------------------------------------------------------------------+
//| Struct Order Container                                           |
//+------------------------------------------------------------------+
struct OrderStruct
 {
  long               type;
  ulong              ticket_master;
  ulong              ticket_slave;
  long               trace_id;
  long               slave_id;
  long               magicnumber;
  long               transaction_id;
  double             price;
  double             lot;
  string             stop_loss;
  string             take_profit;
  string             state;
  string             symbol;
  string             comment;
  ulong              deal_ticket;
  ulong              seconds_ago;
 };

OrderStruct history_orders[];
OrderStruct current_orders[];
//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
 {
  string message = StringFormat("Iniciando Expert %s %s ", APPNAME, APPVERSION);
  AddCommentOnChart(message);
  
  EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input
  ACCOUNT_SERVER_NAME     = RemoveSpecialChars(AccountInfoString(ACCOUNT_SERVER));
  
  if(MQLInfoInteger(MQL_TESTER)){
     {
    //--- initialize global variables
       last_atr=0;
       last_body=0;
    //--- set the correct volume
       double min_lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
       trade_lot=lots>min_lot? lots:min_lot;   
    //--- create ATR indicator handle
       atr_handle=iATR(_Symbol,_Period,ATRperiod);
       if(atr_handle==INVALID_HANDLE)
         {
          PrintFormat("%s: failed to create iATR, error code %d",__FUNCTION__,GetLastError());
          return(INIT_FAILED);
         }
    //--- successful EA initialization
       return(INIT_SUCCEEDED);
      }

  }

  if(DetectEnvironment() == false)
   {
    Print("Expert ", APPNAME + " " + APPVERSION, " não inicializado. Contacte o suporte.");
    string comment = ("Expert "+ APPNAME + " " + APPVERSION + " não inicializado. Contacte o suporte.");
    AddCommentOnChart(comment);

    return(INIT_FAILED);
   }
  else
   {
    Print("Expert ", APPNAME + " " + APPVERSION, " inicializado com sucesso.");
    string comment = ("Expert " + APPNAME + " " + APPVERSION + " inicializado com sucesso.");
    AddCommentOnChart(comment);
    GetCurrentOrdersOnStart();

    return(INIT_SUCCEEDED);
   }
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick(void)
 {
  

 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
 {
  ResetLastError();
  // long  changed = 0;
  // changed = GetCurrentOrdersOnTicket();
  GetCurrentOrdersOnTicket();

  
  datetime currentNextDay = TimeLocal() - TimeLocal() % 86400;

  if (currentDay == currentNextDay)
  {
      //currentNextDay = currentDay;
      CalculateOrdersMFEMAE();
  } else {

    PushOrders();
    orders_size = ArraySize(orders);

    for(int orderindex=0; orderindex<orders_size; orderindex++){
      order_jason.Deserialize(orders[orderindex]);
      order_jason["mae"] = 0.00;
      order_jason["mfe"] = 0.00;
      orders[orderindex] = order_jason.Serialize();
    }
    currentDay = currentNextDay;

  }

  // Loop for 60 seconds
  int timeago1 = int(TimeTradeServer() - timecurrent1);
  int timeago2 = int(TimeTradeServer() - timecurrent2);
  
  //  if(timeago2 > 180){
  //    
  //    timecurrent2 = int(TimeTradeServer());
  //  }
  
  if(timeago1 > 10)
   {
    PullOrdersClosedInfo();
    if(CheckServerInformations() == false)
      ExpertRemove();
    timecurrent1 = int(TimeTradeServer());
   }
   // Loop END
  
  if(MQLInfoInteger(MQL_TESTER)){
  //--- trading signal
     static int signal=0; // +1 means a buy signal, -1 means a sell signal
  //--- check and close old positions opened more than 'holdbars' bars ago
     ClosePositionsByBars(holdbars,slippage,EXPERT_MAGIC);
  //--- check for a new bar
     if(isNewBar())
       {
        //--- check for a signal presence      
        signal=CheckSignal();
       }
  //--- if a netting position is opened, skip the signal - wait till it closes
     if(signal!=0 && PositionsTotal()>0 && (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
       {
        signal=0;
        return; // exit the NewTick event handler and do not enter the market before a new bar appears
       }
  //--- for a hedging account, each position is held and closed separately
     if(signal!=0)
       {
        //--- buy signal
        if(signal>0)
          {
           PrintFormat("%s: Buy signal! Revers=%s",__FUNCTION__,string(revers));
           if(Buy(trade_lot,slippage,EXPERT_MAGIC))
              signal=0;
          }
        //--- sell signal
        if(signal<0)
          {
           PrintFormat("%s: Sell signal! Revers=%s",__FUNCTION__,string(revers));
           if(Sell(trade_lot,slippage,EXPERT_MAGIC))
              signal=0;
          }
       }
      }

 }

//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
 {
  return;
 }

//+------------------------------------------------------------------+
//| Check Store Conditions                                           |
//+------------------------------------------------------------------+
bool CheckServerInformations(){
  
  bool changes = true;
  string orderdata[];
  if(MQLInfoInteger(MQL_TESTER))
    return true;


  if(ApiRequestInformation(orderdata, "store"))
   {
    jv.Deserialize(orderdata[0]);
    store_state = jv["store_state"].ToStr();
    store_message = jv["store_message"].ToStr();
    account_state = jv["account_state"].ToStr();                    // enable/disable
    account_mode = jv["account_mode"].ToStr();                    // demo/real
    account_margin_mode = jv["account_margin_mode"].ToStr();        // hedging/netting
    api_server_hostname = jv["api_server_hostname"].ToStr();        // server api
    
   }
  else
   {
    changes = false;
   }

  if(StringLen(store_message) > 0)
   {
    Print(store_message);
    AddCommentOnChart(store_message);
    changes = false;
   }

  if(store_state == "" || store_state != "enable")
   {
    Print("Sua conta está desabilitada em nosso sistema. Fale com o suporte");
    string comment = ("Sua conta está desabilitada em nosso sistema. Fale com o suporte");
    AddCommentOnChart(comment);

    changes = false;
   }

  if(account_mode == "demo" && IsDemoMQL4() == false)
   {
    Print("Seu acesso é somente para conta demo. Fale com o suporte");
    string comment = ("Seu acesso é somente para conta demo. Fale com o suporte");
    AddCommentOnChart(comment);
    changes = false;
   }

  if(account_state == "disable")
   {
    Print("Sua conta está desabilitada em nosso sistema. Fale com o suporte");
    string comment = ("Sua conta está desabilitada em nosso sistema. Fale com o suporte");
    AddCommentOnChart(comment);
    changes = false;
   }
  if(account_margin_mode == "hedging" && AccountMarginMode() == "NETTING")
   {
    Print("Sua conta está habilitada para modo HEDGE em nosso sistema, porém conta na corretora está configurada para modo NETTING. Efetue a mudança com a sua corretora.");
    string comment = ("Sua conta está habilitada para modo HEDGE em nosso sistema, porém conta na corretora está configurada para modo NETTING. Efetue a mudança com a sua corretora.");
    AddCommentOnChart(comment);

    changes = false;
   }
  if(account_margin_mode == "netting" && AccountMarginMode() == "HEDGING")
   {
    Print("Sua conta está habilitada para modo NETTING em nosso sistema, porém a conta na corretora está configurada para modo HEDGE. Efetue a mudança com a sua corretora.");
    string comment = ("Sua conta está habilitada para modo NETTING em nosso sistema, porém a conta na corretora está configurada para modo HEDGE. Efetue a mudança com a sua corretora.");
    AddCommentOnChart(comment);

    changes = false;
   }

  if(changes == false){
    Alert("Settings Errors - Expert disable");
    string comment = ("Settings Errors - Expert disable");
    AddCommentOnChart(comment);
   }

  return changes;
 }

//+------------------------------------------------------------------+
//| Detect the script parameters                                     |
//+------------------------------------------------------------------+
bool DetectEnvironment()
 {
 
  // long timezone = long((TimeLocal() - TimeTradeServer())/3600);
  // datetime time_local = TimeLocal();
  // datetime time_tradeserver = TimeTradeServer();
  // datetime time_current = TimeCurrent();
  // datetime time_gmt = TimeGMT();
  //int inttime = long((TimeLocal() - TimeTradeServer())/3600);
  //int inttime2 = long((TimeLocal() - TimeGMT())/3600);  
  
  if(EnvironmentLocal || MQLInfoInteger(MQL_TESTER))
    Server = "localhost:8080";  

  if(CheckServerInformations() == false)
    return false;

  order_minlots = MinLots;
  order_maxlots = MaxLots;
  order_percentlots = (order_percentlots > 0) ? PercentLots : 100;
  order_slippage = Slippage;

  return true;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiRequestInformation(string &orderdata[], const string action)
{
    string request;
    string cookie = NULL;
    string headers;
    string serverHeaders;
    char   post[];
    char   result[];

    string str = "EnvironmentLocal=" + IntegerToString(EnvironmentLocal);
    ArrayResize(post, StringToCharArray(str, post, 0, WHOLE_ARRAY, CP_UTF8) - 1);

    string server_url;
    string url;

    if(action == "store")
    {
        request = "POST";
        server_url = Server + "/api/" + API_VERSION + "/stores/config";
        url = "http://" + server_url + "/" + EXPERTNAME + "/" + VERSION + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();
    }
    else if (action == "closed_info")
    {
        request = "GET";
        server_url = Server + "/api/" + API_VERSION + "/transactions/copy/request";
        url = "http://" + server_url + "/" + EXPERTNAME + "/" + VERSION + "/" + action + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();
    }

    int response = 0;
    bool internet_down = false;

    do
    {
        ResetLastError();

        response = WebRequest(request, url, headers, 35000, post, result, serverHeaders);

        if(response != 1001 && internet_down)
        {
            Print("Conexão com o servidor estabelecida");
            string comment = ("Conexão com o servidor estabelecida");
            AddCommentOnChart(comment);
            internet_down = false;
        }

        if(response == -1)
        {
            Print("Api código de erro: ", GetLastError(), ",  resposta: ", response);
            string comment = StringFormat("É necessário adicionar o endereço %s em Ferramentas->Opções->Experts Advisores->URL WebRequest. Error: %s", Server, MB_ICONINFORMATION);
            Print(comment);
            AddCommentOnChart(comment);
            return false;
        }
        else if(response == 201 || response == 200)
        {
            string result2 = CharArrayToString(result);
            int size = StringSplit(result2, '/', orderdata);
            return true;
        }
        else
        {
            Print("Conexão com servidor com Error: ", GetLastError(), ", Resposta: ", response);
            string comment = ("Conexão com servidor com Error: "+ IntegerToString(GetLastError()) + ", Resposta: " + IntegerToString(response));
            AddCommentOnChart(comment);
        }

        internet_down = true;
        Print("Verifique a sua conexão com a internet ou servidor fora temporariamente.");
    }
    while(response != 201);

    return false;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiTrasmitInformation(const string message, const string action)
{
    string request = "POST";
    string server_url = Server +"/api/"+ API_VERSION +"/transactions/copy/trasmit";
    string url = "http://" + server_url + "/" + EXPERTNAME + "/" + VERSION + "/" + action + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();

    string cookie = NULL;
    string headers;
    int response = 0;
    char post[];
    char result[];
    int count = 0;

    ResetLastError();
    StringToCharArray(message, post, 0, StringLen(message));

    while(response != 201 && count <= 1)
    {
        if(MQLInfoInteger(MQL_TESTER))
        {
            SendMessageToFile(message, action);
            return true;
        }
        else
        {
            response = WebRequest("POST", url, cookie, NULL, 35000, post, 0, result, headers);
        }

        if(response == 201)
        {
            string response_string = CharArrayToString(result);

            if(StringFind("OK|OK|OK", response_string) != -1)
                return true;
        }

        count++;
    }

    Print("Conexão com servidor - Resposta: " + IntegerToString(response) + ", GetLastError: ", GetLastError());
    string comment = ("Conexão com servidor - Resposta: " + IntegerToString(response) + ", GetLastError: " + IntegerToString(GetLastError()));
    AddCommentOnChart(comment);
    return false;
}

//+------------------------------------------------------------------+
//| Push the open order to all of the subscriber                     |
//+------------------------------------------------------------------+
int PushOrders()
 {
  orders_size = ArraySize(orders);
  string data = "orders=";
  
  for(int orderindex=0; orderindex<orders_size; orderindex++)
   {
    StringAdd(data, orders[orderindex]);
      StringAdd(data, "//");
   }
  if(ApiTrasmitInformation(data, "orders")){
    
    comment_order_status = "Push Orders to Server - Status: Ok";
    
    Print(comment_order_status);
    
    commentLineItemMakeOrder = AddCommentOnChart(comment_order_status, commentLineItemMakeOrder);

  }else{

    comment_order_status = "Push Orders to Server Error - Status: " + IntegerToString(GetLastError());
    
    Print(comment_order_status);
    
    commentLineItemMakeOrder = AddCommentOnChart(comment_order_status, commentLineItemMakeOrder);

  }

  return 1;
 }

//+------------------------------------------------------------------+
//| Push the modify order to all of the subscriber                   |
//+------------------------------------------------------------------+
bool PushOrderModify()
 {
  // int changed_ticket    = 0;
  long orderssize = ArraySize(orders);
  string order_string_changed;
  long ticketid = -1;
  
  orderchanged = false;

  for(int orderindex=0; orderindex<orderssize; orderindex++)
   {

    //CJAVal order_jason;
    order_jason.Deserialize(orders[orderindex]);
    ticketid = order_jason["ticket_id"].ToInt();

    if(PositionSelectByTicket(ticketid) == false)
      continue;

    double volume = PositionGetDouble(POSITION_VOLUME);
    double sl     = PositionGetDouble(POSITION_SL);
    double tp     = PositionGetDouble(POSITION_TP);
    lots   = OrderLots();

    if(CompareDoubles(order_jason["volume"].ToDbl(), volume)){
      orderchanged = true;
      order_string_changed += AttributeChangeString("volume", order_jason["volume"].ToDbl(), volume);
    }

    if(CompareDoubles(order_jason["stop_loss"].ToDbl(), sl)){
      orderchanged = true;
      order_string_changed += AttributeChangeString("stop_loss", order_jason["stop_loss"].ToDbl(), sl);

    }
         
    if(CompareDoubles(order_jason["take_profit"].ToDbl(), tp)){
      orderchanged = true;
      order_string_changed += AttributeChangeString("take_profit", order_jason["take_profit"].ToDbl(), tp);

    }

    // if(CompareDoubles(order_jason["mfe"].ToDbl(), CalculateMFEMAE(order_jason["ticket_id"].ToInt(), "mfe", order_jason["mfe"].ToDbl())))
    //   orderchanged = true;
    // if(CompareDoubles(order_jason["mae"].ToDbl(), CalculateMFEMAE(order_jason["ticket_id"].ToInt(), "mae", order_jason["mae"].ToDbl())))
    //   orderchanged = true;

    if(orderchanged == true)
     {
      order_jason["volume"]     = volume;
      order_jason["stop_loss"]   = sl;
      order_jason["take_profit"] = tp;
      order_jason["profit"] = PositionGetDouble(POSITION_PROFIT);
      order_jason["mfe"] = CalculateMFEMAE(ticketid, "mfe", order_jason["mfe"].ToDbl());
      order_jason["mae"] = CalculateMFEMAE(ticketid, "mae", order_jason["mae"].ToDbl());
      order_jason["state_meta"] = "modify";
      orders[orderindex] = order_jason.Serialize();
     }
   }
  if(orderchanged == true){

    comment_order_status = ("Push Order Modify - Ticket: " + IntegerToString(ticketid) +", Symbol: " + PositionGetString(POSITION_SYMBOL) + ", Type: " + IntegerToString(PositionGetInteger(POSITION_TYPE)) + " TicketDealID: " + order_jason["ticket_deal"].ToStr()) ;
    comment_order_status += "\nOrder Changed: " + order_string_changed;
    
    Print(comment_order_status);
    
    commentLineItemOrder = AddCommentOnChart(comment_order_status, commentLineItemOrder);

    PushOrders();
  }
  return orderchanged;
 }

//+------------------------------------------------------------------+
//| PushOrderClosed                                                  |
//+------------------------------------------------------------------+
void PushOrderClosed(const long ticketid)
{
    long ticket_deal = FindCloseOrderByTicketId(ticketid);
    
    comment_order_status = ("Push Order Closed - Ticket: " + IntegerToString(ticketid) +", Symbol: " + HistoryDealGetString(ticket_deal, DEAL_SYMBOL) + ", Type: " + IntegerToString(HistoryDealGetInteger(ticketid, DEAL_TYPE)) + " TicketDealID: " + IntegerToString(HistoryDealGetInteger(ticket_deal, DEAL_TICKET)));
    
    Print(comment_order_status);
    
    commentLineItemOrder = AddCommentOnChart(comment_order_status, commentLineItemOrder);



    if(ticket_deal != INVALID_HANDLE)
    {
        if(OrderSelect(ticketid, SELECT_BY_TICKET, MODE_HISTORY))
        {
            double profit = HistoryDealGetDouble(ticket_deal, DEAL_PROFIT);    
            double fees = GetFeesOrderHistory(ticket_deal);

            string message_format = MessageSendFormat(OrderMagicNumber(), "CLOSED", ticketid , HistoryDealGetInteger(ticketid, DEAL_TICKET), OrderSymbol(), OrderType(), OrderOpenPrice(), OrderClosePrice(), OrderLots(), DoubleToString(OrderStopLoss()), DoubleToString(OrderTakeProfit()), profit, fees, OrderComment(), OrderCloseTime(), "removed");      
            
            if(ApiTrasmitInformation(message_format, "closed"))
            {
                comment_order_status = "Push Order Closed to Server - Status: OK";
                Print(comment_order_status);

                commentLineItemMakeOrder = AddCommentOnChart(comment_order_status, commentLineItemMakeOrder);
            } 
            else 
            { 
                comment_order_status = "Push Order Closed to Server - Status: Error" + IntegerToString(GetLastError());
                Print(comment_order_status);

                commentLineItemMakeOrder = AddCommentOnChart(comment_order_status, commentLineItemMakeOrder);

            }
        }
    } 
    else 
    {
        comment_order_status = "Push Order Ticket Deal ID: " + IntegerToString(ticket_deal) + " - Status: Error" + IntegerToString(GetLastError());
        Print(comment_order_status);

        commentLineItemMakeOrder = AddCommentOnChart(comment_order_status, commentLineItemMakeOrder);

    }
}

//+------------------------------------------------------------------+
//| PullOrdersClosedInfo                                             |
//+------------------------------------------------------------------+
void PullOrdersClosedInfo(){
  string orderdata[];
  ApiRequestInformation(orderdata, "closed_info");
  PushOrderClosedInfo(orderdata);
}

//+------------------------------------------------------------------+
//| PushOrderClosedInfo                                              |
//+------------------------------------------------------------------+
void PushOrderClosedInfo(string &orderdata[]){
  // string orderdata[];
  // StringSplit(response_string, '/', orderdata);
  int orderdata_size = ArraySize(orderdata);
  for( int i = 0; i < orderdata_size; i++ ){
    string orderdataparse[];
    ParseMessage(orderdata[i], orderdataparse);
    PushOrderClosed(long(orderdataparse[1]));
  }
}

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
void GetCurrentOrdersOnTicket()
 {
  order_size = OrdersTotal();
  bool order_add = false;    
  long changed_ticket = 0;

  CheckOrdersOpened();

  if(PushOrderModify()){ 
    UpdateOrders();
  }


  // if(order_add || changed_ticket == 1){
  // //if((order_add && order_size >0) || changed_ticket == 1){
  //   // PushOrders();    
  // }
  
  // CheckOrdersClosed();
  int orderssize = ArraySize(orders);
  for(int ordersindex=0; ordersindex < ArraySize(orders); ordersindex++){
    bool order_remove = true;
    order_jason.Deserialize(orders[ordersindex]);
    long ticket_id = order_jason["ticket_id"].ToInt();
    for(int orderindex=0; orderindex < order_size; orderindex++){
      ulong ticketid = PositionGetTicket(orderindex);
      if(ticketid == ticket_id){
        order_remove = false;
        break;
       }
    }
    if(order_remove || orderssize > order_size){
      PushOrders();       
      UpdateOrders();
      PushOrders();       
      PullOrdersClosedInfo();
     }
  }
  
  // return changed_ticket;
}

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
void GetCurrentOrdersOnStart()
 {
  UpdateOrders();
  PushOrders();
 }

//+------------------------------------------------------------------+
//| CheckOrdersOpened                                                |
//+------------------------------------------------------------------+
void CheckOrdersOpened(){
  bool changed = true;
  int orders_count = PositionsTotal();
  for( int i = 0; i < orders_count; i++ ){
    ulong ticketid  = PositionGetTicket(i);
    for(int ii = 0; ii < ArraySize(current_orders); ii++){
      if(current_orders[ii].ticket_master == ticketid){
        changed = false;
        break;
      }
      else
        changed = true;
    }
    if(changed && OrdersTotal() >= 0){
      ArrayResize(current_orders, ArraySize(current_orders) + 1);
      current_orders[i].ticket_master = ticketid;
      UpdateOrders();
      PushOrders();
    }
  }
  if(OrdersTotal() == 0){
    //PushOrders();
    ArrayFree(current_orders);
    ArrayResize(current_orders, PositionsTotal());
  }

}

//+------------------------------------------------------------------+
//| Update all of the orders status                                  |
//+------------------------------------------------------------------+
void UpdateOrders()
 {
  order_size = PositionsTotal();
  ArrayResize(orders, int(order_size));

  for(int orderindex=0; orderindex<order_size; orderindex++)
   {
      
    ulong ticketid = PositionGetTicket(orderindex);
    order_jason["ticket_id"]   = long(ticketid);
    order_jason["ticket_deal"] = PositionGetInteger(POSITION_IDENTIFIER);
    order_jason["open_price"]  = PositionGetDouble(POSITION_PRICE_OPEN);
    order_jason["volume"]      = PositionGetDouble(POSITION_VOLUME);
    order_jason["stop_loss"]   = calculatePips(PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL), PositionGetInteger(POSITION_TYPE), PositionGetString(POSITION_SYMBOL), "sl");
    order_jason["take_profit"] = calculatePips(PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP), PositionGetInteger(POSITION_TYPE), PositionGetString(POSITION_SYMBOL), "tp");

    order_jason["type"]        = PositionGetInteger(POSITION_TYPE);
    order_jason["magicnumber"] = PositionGetInteger(POSITION_MAGIC);
    order_jason["symbol"]      = PositionGetString(POSITION_SYMBOL);
    order_jason["comment"]     = PositionGetString(POSITION_COMMENT);
    order_jason["profit"]      = PositionGetDouble(POSITION_PROFIT);
    order_jason["mae"]         = CalculateMFEMAE(ticketid, "mae", 0);
    order_jason["mfe"]         = CalculateMFEMAE(ticketid, "mfe", 0);
    // order_jason["mae"]         = (order_jason["mae"].ToDbl() != 0)? order_jason["mae"].ToDbl(): 0.00;
    // order_jason["mfe"]         = (order_jason["mfe"].ToDbl() != 0)? order_jason["mfe"].ToDbl(): 0.00;

    
    order_jason["open_at"]     = TimeToString(PositionGetInteger(POSITION_TIME),(TIME_DATE|TIME_MINUTES|TIME_SECONDS));
    order_jason["time_gmt"]    = TimeToString(TimeGMT(),(TIME_DATE|TIME_MINUTES|TIME_SECONDS));
    order_jason["time_trader"] = TimeToString(TimeTradeServer(),(TIME_DATE|TIME_MINUTES|TIME_SECONDS));
    order_jason["timezone"]    = long((TimeLocal() - TimeTradeServer())/3600);    
    order_jason["state_meta"]  = "";
    double profit1 = order_jason["profit"].ToDbl();
    double profit2 = PositionGetDouble(POSITION_PROFIT);
    
    if(order_jason["profit"].ToDbl() != PositionGetDouble(POSITION_PROFIT)){
      order_jason["state_meta"]  = "modify_profit";
      
    
    } else
      order_jason["state_meta"]  = "";
      
    orders[orderindex] = order_jason.Serialize();
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
//| FormatMessage                                                    |
//+------------------------------------------------------------------+
string MessageSendFormat(long magic_number, const string action, long order_ticket, long deal_ticket, string order_symbol, long order_type, 
                        double open_price, double close_price, double volume, string stop_loss, string take_profit,
                        double profit, double fees, string comment, double open_at, const string state, string meta_message=""
                       )
{
 long timezone = long((TimeLocal() - TimeTradeServer())/3600);
 datetime time = TimeLocal();
 string message = StringFormat("body={'account_login':'%s', 'magic_number':'%d', 'state':'%s', 'action':'%s', 'ticket_id':'%s', 'deal_ticket':'%d', 'order_symbol':'%s', 'order_type':'%d', 'open_price':'%f', 'close_price':'%f', 'volume':'%f', 'stop_loss':'%s', 'take_profit':'%s', 'profit':'%f',  'fees':'%f', 'comment':'%s', 'open_at':'%f', 'state':'%s', 'timezone':'%d', 'meta_message':'%s'}",
                               ACCOUNTLOGIN,
                               magic_number,
                               state,
                               action,
                               IntegerToString(order_ticket),
                               deal_ticket,
                               order_symbol,
                               order_type,
                               open_price,
                               close_price,
                               volume,
                               stop_loss,
                               take_profit,
                               profit,
                               fees,
                               comment,
                               open_at,
                               state,
                               timezone,
                               meta_message
                              );
 return message;
} 
 
//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindOrderBySingalComment(const string comment)
 {
  long ticketid = -1;

  order_size  = OrdersTotal();
  int orderindex = 0;

  for(orderindex=0; orderindex<order_size; orderindex++)
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
//| FindCloseOrderByTicketId                                         |
//+------------------------------------------------------------------+
long FindCloseOrderByTicketId(const ulong ticketid)
{
   HistorySelect(0, TimeCurrent());

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      long ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

      if(entry_type != DEAL_ENTRY_IN && ticket == ticketid)
      {
         return long(deal_ticket);
      }
   }

   return INVALID_HANDLE;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ReadMessageToFile(string message, string const meta_state)
{
//--- open the file
 string InpFileName="signal_copy_receive.txt"; // file name
 string InpDirectoryName="data"; // directory name 
 ResetLastError();
 int file_handle=FileOpen(InpDirectoryName+"//"+InpFileName,FILE_READ|FILE_BIN|FILE_ANSI);
 if(file_handle!=INVALID_HANDLE)
   {
    PrintFormat("%s file is available for reading",InpFileName);
    PrintFormat("File path: %s\\Files\\",TerminalInfoString(TERMINAL_DATA_PATH));
    //--- additional variables
    int    str_size;
    string str;
    //--- read data from the file
    while(!FileIsEnding(file_handle))
      {
       //--- find out how many symbols are used for writing the time
       str_size=FileReadInteger(file_handle,INT_VALUE);
       //--- read the string
       str=FileReadString(file_handle,str_size);
       //--- print the string
       PrintFormat(str);
      }
    //--- close the file
    FileClose(file_handle);
    PrintFormat("Data is read, %s file is closed",InpFileName);
    return true;
   }
 else
    PrintFormat("Failed to open %s file, Error code = %d",InpFileName,GetLastError());
    return false;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SendMessageToFile(string message, string const meta_state)
{
 Print("SendMessageToFile - Message:",message);
 string InpFileName = "signal_copy_trasmit.txt";  // file name
 string InpDirectoryName = "data"; // directory name
 int file_handle = FileOpen(InpDirectoryName + "//" + InpFileName, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI | FILE_TXT);
 
// FileWriteString(file_handle, message + "\r\n");
// FileClose(file_handle);
 
 if(file_handle != INVALID_HANDLE)
  {
   FileSeek(file_handle, 0, SEEK_END);
   //message = StringFormat("%s;%s; %s"message, meta_state, TimeToString(TimeCurrent()));
   FileWriteString(file_handle, message + "\r\n");
   FileClose(file_handle);
   PrintFormat("%s file was write", InpFileName);
   return true;
  }
 else
   PrintFormat("Failed to open %s file, Error code = %d", InpFileName, GetLastError());
 return false;
}

//+------------------------------------------------------------------+
//| Check for a new trading signal                                   |
//+------------------------------------------------------------------+
int CheckSignal()
  {
//--- 0 means no signal
   int res=0;
//--- get ATR value on a penultimate complete bar (the bar index is 2)
   double atr_value[1];
   if(CopyBuffer(atr_handle,0,2,1,atr_value)!=-1)
     {
      last_atr=atr_value[0];
      //--- get data on the last closed bar to the MqlRates type array
      MqlRates bar[1];
      if(CopyRates(_Symbol,_Period,1,1,bar)!=-1)
        {
         //--- calculate the bar body size on the last complete bar
         last_body=bar[0].close-bar[0].open;
         //--- if the body of the last bar (with index 1) exceeds the previous ATR value (on the bar with index 2), a trading signal is received
         if(MathAbs(last_body)>kATR*last_atr)
            res=last_body>0?1:-1; // positive value for the upward candle
        }
      else
         PrintFormat("%s: Failed to receive the last bar! Error",__FUNCTION__,GetLastError());
     }
   else
      PrintFormat("%s: Failed to receive ATR indicator value! Error",__FUNCTION__,GetLastError());
//--- if reverse trading mode is enabled
   res=revers?-res:res;  // reverse the signal if necessary (return -1 instead of 1 and vice versa)
//--- return a trading signal value
   return (res);
  }
//+------------------------------------------------------------------+
//|  Return 'true' when a new bar appears                            |
//+------------------------------------------------------------------+
bool isNewBar(const bool print_log=true)
  {
   static datetime bartime=0; // store open time of the current bar
//--- get open time of the zero bar
   datetime currbar_time=iTime(_Symbol,_Period,0);
//--- if open time changes, a new bar has arrived
   if(bartime!=currbar_time)
     {
      bartime=currbar_time;
      lastbar_timeopen=bartime;
      //--- display data on open time of a new bar in the log      
      if(print_log && !(MQLInfoInteger(MQL_OPTIMIZATION)||MQLInfoInteger(MQL_TESTER)))
        {
         //--- display a message with a new bar open time
         PrintFormat("%s: new bar on %s %s opened at %s",__FUNCTION__,_Symbol,
                     StringSubstr(EnumToString(_Period),7),
                     TimeToString(TimeCurrent(),TIME_SECONDS));
         //--- get data on the last tick
         MqlTick last_tick;
         if(!SymbolInfoTick(Symbol(),last_tick))
            Print("SymbolInfoTick() failed, error = ",GetLastError());
         //--- display the last tick time up to milliseconds
         PrintFormat("Last tick was at %s.%03d",
                     TimeToString(last_tick.time,TIME_SECONDS),last_tick.time_msc%1000);
        }
      //--- we have a new bar
      return (true);
     }
//--- no new bar
   return (false);
  }
//+------------------------------------------------------------------+
//| Buy at a market price with a specified volume                    |
//+------------------------------------------------------------------+
bool Buy(double volume,ulong deviation=10,ulong  magicnumber=0)
  {
//--- buy at a market price
   return (MarketOrder(ORDER_TYPE_BUY,volume,deviation,magicnumber));
  }
//+------------------------------------------------------------------+
//| Sell at a market price with a specified volume                   |
//+------------------------------------------------------------------+
bool Sell(double volume,ulong deviation=10,ulong  magicnumber=0)
  {
//--- sell at a market price
   return (MarketOrder(ORDER_TYPE_SELL,volume,deviation,magicnumber));
  }
//+------------------------------------------------------------------+
//| Close positions by hold time in bars                             |
//+------------------------------------------------------------------+
void ClosePositionsByBars(int holdtimebars,ulong deviation=10,ulong  magicnumber=0)
  {
   int total=PositionsTotal(); // number of open positions   
//--- iterate over open positions
   for(int i=total-1; i>=0; i--)
     {
      //--- position parameters
      ulong  position_ticket=PositionGetTicket(i);                                      // position ticket
      string position_symbol=PositionGetString(POSITION_SYMBOL);                        // symbol 
      ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // position MagicNumber
      datetime position_open=(datetime)PositionGetInteger(POSITION_TIME);               // position open time
      int bars=iBarShift(_Symbol,PERIOD_CURRENT,position_open)+1;                       // how many bars ago a position was opened
 
      //--- if a position's lifetime is already large, while MagicNumber and a symbol match
      if(bars>holdtimebars && magic==magicnumber && position_symbol==_Symbol)
        {
         int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);           // number of decimal places
         double volume=PositionGetDouble(POSITION_VOLUME);                              // position volume
         ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // position type
         string str_type=StringSubstr(EnumToString(type),14);
         StringToLower(str_type); // lower the text case for correct message formatting
         PrintFormat("Close position #%d %s %s %.2f",
                     position_ticket,position_symbol,str_type,volume);
         //--- set an order type and sending a trade request
         if(type==POSITION_TYPE_BUY)
            MarketOrder(ORDER_TYPE_SELL,volume,deviation,magicnumber,position_ticket);
         else
            MarketOrder(ORDER_TYPE_BUY,volume,deviation,magicnumber,position_ticket);
        }
     }
  }
//+------------------------------------------------------------------+
//| Prepare and send a trade request                                 |
//+------------------------------------------------------------------+
bool MarketOrder(ENUM_ORDER_TYPE type,double volume,ulong slip,ulong magicnumber,ulong pos_ticket=0)
  {
//--- declaring and initializing structures
   MqlTradeRequest request={};
   MqlTradeResult  result={};
   double price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   if(type==ORDER_TYPE_BUY)
      price=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
//--- request parameters
   request.action   =TRADE_ACTION_DEAL;                     // trading operation type
   request.position =pos_ticket;                            // position ticket if closing
   request.symbol   =Symbol();                              // symbol
   request.volume   =volume;                                // volume 
   request.type     =type;                                  // order type
   request.price    =price;                                 // trade price
   request.deviation=slip;                                  // allowable deviation from the price
   request.magic    =magicnumber;                           // order MagicNumber
//--- send a request
   if(!OrderSend(request,result))
     {
      //--- display data on failure
      PrintFormat("OrderSend %s %s %.2f at %.5f error %d",
                  request.symbol,EnumToString(type),volume,request.price,GetLastError());
      return (false);
     }
//--- inform of a successful operation
   PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   return (true);
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
bool IsHedging()
 {
  long margin = AccountInfoInteger(ACCOUNT_TRADE_MODE);
  int margmod = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  return(margmod==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
 }

//+------------------------------------------------------------------+
string AccountMarginMode()
 {
  int modetype = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  string mode;
  switch(modetype)
   {
    case 0:
      mode = "NETTING";
      break;
    case 1:
      mode = "EXCHANGE";
      break;
    case 2:
      mode = "HEDGING";
      break;
   }
  return mode;
 }

  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CompareDoubles(double number1, double number2)
 {
  bool ret;
  number1 = NormalizeDouble(number1, 6);
  number2 = NormalizeDouble(number2, 6);

  if(number1 == 0.0 && number2 == 0.0)
   {
    if((int)MathRound((number1 - number2) / 100000000.0) == 0)
      return(false);
    else
      return(true);
   }
  else
   {
    ret = number1 != number2 ? true : false;
   }
  return ret;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string RemoveSpecialChars(string inputString)
{
    string resultString = "";
    int inputLength = StringLen(inputString);

    for(int i = 0; i < inputLength; i++)
    {
        int charValue = StringGetChar(inputString, i);

        if((charValue >= 48 && charValue <= 57) || // números
           (charValue >= 65 && charValue <= 90) || // letras maiúsculas
           (charValue >= 97 && charValue <= 122)) // letras minúsculas
        {
            //string stringArgument1 = StringSubstr(inputString, i, 1);
            StringConcatenate(resultString, resultString,  StringSubstr(inputString, i, 1));
        }
    }

    return resultString;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculatePips(double vprice, double number, long vtype, string symbol, string kind)
 {

  int    vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double vpoint  = SymbolInfoDouble(symbol, SYMBOL_POINT);
  string snumber = DoubleToString(number);

  if(StringFind(snumber,".") == -1)
  {
   //vprice = NormalizeDouble(vprice, vdigits-1);
   if(vdigits == 2)
     vpoint = 0.1;
   else
     if(vdigits == 3)
       vpoint = 0.01;
     else
       if(vdigits >= 4)
         vpoint = 0.0001;
     float mod = 1;

   if(vtype == 0 || vtype == 2 || vtype == 4 || vtype == 6)
     number = NormalizeDouble(vprice-number*mod*vpoint, vdigits);
   else
    {
     if(kind == "tp")
       mod = -1;
     number = NormalizeDouble(vprice+number*mod*vpoint, vdigits);
    }
  }
  return number;
 } 

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetFeesOrderHistory(const long ticket_deal){
   double fee = HistoryDealGetDouble(ticket_deal, DEAL_FEE);
   double swap = HistoryDealGetDouble(ticket_deal, DEAL_SWAP);
   double comission = HistoryDealGetDouble(ticket_deal, DEAL_COMMISSION);     
 
   double fees = comission*2 + swap + fee;
   return fees;
}


//+------------------------------------------------------------------+
//| Calculate MFE and MAE and send to API                            |
//+------------------------------------------------------------------+
double CalculateMFEMAE(long ticketid, string type, double value)
  { 
    int totalOrders = ArraySize(orders);
    //string mae_mfe;
    double profit = 0;
    if(PositionSelectByTicket(ticketid))
     {
        profit = PositionGetDouble(POSITION_PROFIT);

        if(type == "mfe" && profit > 0){
          if(profit > value) value = profit;
          //mae_mfe = "Ticket ID:"+IntegerToString(ticketid)+ "\nMax MFE: "+DoubleToString(order_jason["mfe"].ToDbl())+ " \nMax MAE: "+ DoubleToString(order_jason["mae"].ToDbl());
        }
        else if(type == "mae" && profit < 0){
          if(profit < value) value = profit;
         //mae_mfe = "Ticket ID:"+IntegerToString(ticketid)+ "\nMax MFE: "+DoubleToString(order_jason["mfe"].ToDbl())+ " \nMax MAE: "+ DoubleToString(order_jason["mae"].ToDbl());
        }
        
        //Print(mae_mfe);


     }
     return value;
  }


//+------------------------------------------------------------------+
//| Calculate MFE and MAE and send to API                            |
//+------------------------------------------------------------------+
void CalculateOrdersMFEMAE()
{ 
   string mfe_mae_string;
   int totalOrders = ArraySize(orders);
  
   double profit = 0;
   if (totalOrders > 0)
   {
      for (int orderindex = totalOrders - 1; orderindex >= 0; orderindex--)
      {
        //CJAVal order_jason;
        order_jason.Deserialize(orders[orderindex]);
        long ticketid = order_jason["ticket_id"].ToInt();
        if(PositionSelectByTicket(ticketid))
         {

            double value_mae  = order_jason["mae"].ToDbl();
            order_jason["mae"] = CalculateMFEMAE(ticketid, "mae", value_mae);
            double value_mfe  = order_jason["mfe"].ToDbl();
            order_jason["mfe"] = CalculateMFEMAE(ticketid, "mfe", value_mfe);
            string mae_mfe = "\nTicket ID:"+IntegerToString(ticketid)+ "\nMax MFE: "+DoubleToString(order_jason["mfe"].ToDbl())+ " \nMax MAE: "+ DoubleToString(order_jason["mae"].ToDbl());
            order_jason["time_trader"] = TimeToString(TimeTradeServer(),(TIME_DATE|TIME_MINUTES|TIME_SECONDS));
            order_jason["profit"] = PositionGetDouble(POSITION_PROFIT);
            order_jason["state_meta"] = "modify";
            StringConcatenate(mfe_mae_string, (mae_mfe+"\n"), mfe_mae_string);

         }
      orders[orderindex] = order_jason.Serialize();      
      
      }
      comment_mfe_mae_line_item = AddCommentOnChart(mfe_mae_string, comment_mfe_mae_line_item);
        
    }
}

//+------------------------------------------------------------------+
//| DrawTextOnChart                                                  |
//+------------------------------------------------------------------+
long ShowCommentOnChart()
{
    long line_item = 0;
    // if (ObjectFind(0, objectName) != -1) {
    //     // Se o objeto existir, remova-o primeiro
    //     ObjectDelete(0, objectName);
    // }

    // // Crie um novo objeto de texto no gráfico
    // ObjectCreate(0, objectName, OBJ_LABEL, 0, 0, 0);

    // // Defina as propriedades do objeto de texto
    // ObjectSetInteger(0, objectName, OBJPROP_CORNER, CORNER_LEFT_UPPER); // Posição do canto
    // ObjectSetInteger(0, objectName, OBJPROP_XDISTANCE, x); // Distância X a partir do canto
    // ObjectSetInteger(0, objectName, OBJPROP_YDISTANCE, y); // Distância Y a partir do canto

    string finalText = ""; // Inicialize a string final como vazia
    for (int i = 0; i < ArraySize(commentOnChart); i++) {
        line_item = long(i);
        finalText += commentOnChart[i] + "\n"; // Adicione cada string do array à string final, seguida por uma quebra de linha
    }
    Comment(finalText);
    return line_item;
    // ObjectSetString(0, objectName, OBJPROP_TEXT, finalText); // Texto para exibir
    // ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrBlack); // Cor do texto
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long AddCommentOnChart(string newMessage, long line_item=0)
{
    if(line_item > 0){
      commentOnChart[line_item] = newMessage;
      ShowCommentOnChart();
      
    } else {
      ArrayResize(commentOnChart, ArraySize(commentOnChart) + 1); // Redimensiona o array para ser um elemento maior
      commentOnChart[ArraySize(commentOnChart) - 1] = newMessage; // Adiciona a nova mensagem na última posição do array
      line_item = ShowCommentOnChart();            
    }  
  
    return line_item;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AttributeChangeString(string attributeName, double oldValue, double newValue)
{
    string message = ToUpper(attributeName) + " changed from: " + ToUpper(DoubleToString(oldValue)) + " to: " + ToUpper(DoubleToString(newValue)) + "\n";
    return message;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

string ToUpper(string str) {
    if (StringToUpper(str)) {
        return str;
    } else {
        Print("Falha ao converter a string para maiúsculas.");
        return str;
    }
}

//+------------------------------------------------------------------+