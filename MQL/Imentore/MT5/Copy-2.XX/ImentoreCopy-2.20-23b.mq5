//+------------------------------------------------------------------+
//#property version "2.20"
#define EXPERTNAME "imentore_copy"
#define VERSION "2_20"
#define VERSION_UPDATE "23"

#define APPNAME "Imentore Copy"
#define APPVERSION "2.20"

#property copyright   "Update "+ VERSION_UPDATE+"- Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict
//+------------------------------------------------------------------+

#include <Trade\DealInfo.mqh>
#include <Trade\Trade.mqh>
#include <JAson.mqh>
#include <JasonStruct.mqh>

CTrade trade;  // Instance of CTrade


// Declare an object of type JasonStruct
OrderJason JasonOrdersOpen;
OrderJason JasonOrdersClosed;

// Create an OrderStruct to add to myOrders


// #include <MT4Orders.mqh> // если есть #include <Trade/Trade.mqh>, вставить эту строчку ПОСЛЕ
// #include <MQL4_to_MQL5.mqh> // ТОЛЬКО для данного примера

//+------------------------------------------------------------------+

input double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)
input double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
input double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
input int    Slippage                = 30;
input bool   EnvironmentLocal        = false;

//+------------------------------------------------------------------+

string ACCOUNTLOGIN            = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
string API_VERSION             = "v2";
int    MILLISECOND_TIMER       = 2000;
string ACCOUNT_SERVER_NAME     = "";
string SERVER                  = "mt5-web-replicator.example.com";      // Subscribe server ip

//+------------------------------------------------------------------+
bool   ServerReal = false;                    // Under real server (Default is false)
string prefix     = "";                       // Copied trade comment prefix

//+------------------------------------------------------------------+
uint   delay             = 1000;              // Check frequency (milliseconds)
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

//+------------------------------------------------------------------+ Current
bool firstRun = true;

// long commentLineExpert = 1;
// long commentLineExpertOk = 2;
// long commentLineLogNameFile = 3;

long commentLineItemOrder = 0;
long commentLineItemMakeOrder = 0;
long comment_mfe_mae_line_item = 0;
long commentOnChartInitPosition[];

string LogFileName;
string commentOnChartInit[];
string commentOnChartTick[];
string comment_order_status;
int file_handle_out = 0;

double maxDayMFE = 0;
double maxDayMAE = 0;

datetime currentDay = TimeLocal() - TimeLocal() % 86400;

//+------------------------------------------------------------------+ Tester
int NewCandleCount;
ulong TicketIdTester;
datetime lastCandleTime;

//---
enum ENUM_INFORMATION_OUTPUT
 {
  experts_tab = 0,  // The "Experts" tab
  txt_file    = 1,  // The text file
 };
//---
datetime                from_date   = D'2017.08.07 11:06:20';  // From date
datetime                to_date     = __DATE__ + 60 * 60 * 24; // To date
ENUM_INFORMATION_OUTPUT InpOutput   = experts_tab;                // Information output
// string                  InpFileNameOut = "ImentoreLog.txt";      // File name (only if "Information output" == "The text file")
//---
//+-----------------


//---

//CJAVal OrdersJason;
CJAVal WebServiceJason;

//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
 {  
  SetLogFileName();
  string message = StringFormat("Iniciando Expert %s %s ", APPNAME, APPVERSION);
  AddCommentOnChart(message, 1);
  EventSetMillisecondTimer(MILLISECOND_TIMER);
  ACCOUNT_SERVER_NAME     = RemoveSpecialChars(AccountInfoString(ACCOUNT_SERVER));
  if(DetectEnvironment() == false)
   {
    Print("Expert ", APPNAME + " " + APPVERSION, " não inicializado. Contacte o suporte.");
    string comment = ("Expert " + APPNAME + " " + APPVERSION + " não inicializado. Contacte o suporte.");
    AddCommentOnChart(comment, 2);
    return(INIT_FAILED);
   }
  else
   {
    Print("Expert ", APPNAME + " " + APPVERSION, " inicializado com sucesso.");
    string comment = ("Expert " + APPNAME + " " + APPVERSION + " inicializado com sucesso.");
    AddCommentOnChart(comment, 2);
    GetCurrentOrdersOnStart();
    return(INIT_SUCCEEDED);
   }
 }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick(){

  CheckOrdersOpenHasClosed();

  SetLogFileName();
  ResetLastError();
  datetime currentNextDay = TimeLocal() - TimeLocal() % 86400;
  
  if(currentDay == currentNextDay){
    //CalculateOrdersMFEMAE();
  } else {
    maxDayMAE = 0;
    maxDayMFE = 0;
    currentDay = currentNextDay;
  }
  
  // Loop for 60 seconds
  int timeago1 = int(TimeTradeServer() - timecurrent1);
  
  if(timeago1 > 30){
    if(CheckServerInformations() == false)
      ExpertRemove();
    timecurrent1 = int(TimeTradeServer());
  }

  //+------------------------------------------------------------------+ Tester
  if(MQLInfoInteger(MQL_TESTER)){
    // Obtém o tempo do início da vela atual
    datetime currentCandleTime = iTime(Symbol(), Period(), 0);
    // Verifica se uma nova vela foi formada
    if(currentCandleTime != lastCandleTime)
     {
      trade.SetExpertMagicNumber(12345);
      if(TicketIdTester <= 0)
       {
        double vprice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double vpoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double lot_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double sl = NormalizeDouble(vprice + 300 * vpoint, _Digits);
        trade.Sell(lot_min, _Symbol, 0, sl, 0, "Ontester");
        TicketIdTester = trade.ResultOrder();
       }
      // Atualiza o tempo da última vela
      lastCandleTime = currentCandleTime;
      if(NewCandleCount >= 2)
       {
        trade.PositionClose(TicketIdTester);
        TicketIdTester = 0;
        NewCandleCount = 0;
       }
      NewCandleCount += 1;
      // Aqui você pode colocar o código que deve ser executado no início de uma nova vela
      //Print("Uma nova vela foi formada no gráfico ", Symbol(), " de ", Period(), " minutos.");
    }
  }
}
//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
{


}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
  ENUM_TRADE_TRANSACTION_TYPE transactionType = trans.type;
  HistoryDealSelect(trans.deal);

  string ticketId = IntegerToString(trans.position);
  ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
  ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
  string orderComment = HistoryOrderGetString(trans.position, ORDER_COMMENT);

  string dealTypeStr = (dealType == DEAL_TYPE_BUY) ? "buy" : "sell";
  string dealDirection, log_message;

  if(transactionType == TRADE_TRANSACTION_DEAL_ADD && (dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL))
  {
    HistoryOrderSelect(trans.position);
    dealDirection = (dealEntry == DEAL_ENTRY_IN || dealEntry == DEAL_ENTRY_INOUT) ? "in" : "";
    
    if(dealDirection != "")
    {
      log_message = StringFormat("Symbol: %s Ticket ID: %s Deal Ticket: %d Type: %s Direction: %s Comment: %s", 
                                  _Symbol, ticketId, trans.deal, ToUpper(dealTypeStr), ToUpper(dealDirection), ToUpper(orderComment));
      
      JasonStruct* orderStruct = new JasonStruct();
      orderStruct = JasonOrdersOpen.FindOrderByTicket(trans.position);
      
      SendMessageToServer(result, request, orderStruct, "OPEN", "OPEN", "OPEN", "OnTradeTransaction", log_message);
      //AddCommentOnChart(commentOrder);
      //PushOrders();
    }
  }
  else if(transactionType == TRADE_TRANSACTION_HISTORY_ADD)
  {
    long dealTicket = FindCloseOrderByTicketId(trans.position);
    dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    dealDirection = (dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY) ? "out" : "";
    
    if(dealDirection != "")
    {
      log_message = StringFormat("Symbol: %s Ticket ID: %s Deal Ticket: %d Type: %s Direction: %s Comment: %s", 
                                  _Symbol, ticketId, trans.deal, ToUpper(dealTypeStr), ToUpper(dealDirection), ToUpper(orderComment));
      
      
      
      //if(OrdersJason["orders_open"][ticketId].type != jtUNDEF)
      // OrdersJason["orders_open"].Remove(ticketId);
      
     // SendMessageToServer(result, request, OrdersJason["orders_open"][ticketId], "CLOSED", "CLOSED", "CLOSED", "OnTradeTransaction", log_message);
      
      //AddCommentOnChart(commentOrder);
      //PushOrders();
      //Print(commentOrder);
    }
  }
  else if(transactionType == TRADE_TRANSACTION_POSITION)
  {
    PushOrders();
  }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//void OnTimer()
// {
//  ResetLastError();
//
//
//  datetime currentNextDay = TimeLocal() - TimeLocal() % 86400;
//
//  if(currentDay == currentNextDay)
//   {
//    //CalculateOrdersMFEMAE();
//   }
//  else
//   {
//
//    maxDayMAE = 0;
//    maxDayMFE = 0;
//    currentDay = currentNextDay;
//   }
//
//// Loop for 60 seconds
//  int timeago1 = int(TimeTradeServer() - timecurrent1);
//  int timeago2 = int(TimeTradeServer() - timecurrent2);
//
//
//  if(timeago1 > 30)
//   {
//    if(CheckServerInformations() == false)
//      ExpertRemove();
//    timecurrent1 = int(TimeTradeServer());
//   }
//
// }

//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
 {
  Comment("");
  EventKillTimer();
  return;
 }


//+------------------------------------------------------------------+
//| CheckOrdersOpenHasClosed                                         |
//+------------------------------------------------------------------+
void CheckOrdersOpenHasClosed(){
  //orders_size = OrdersJason["orders_open"].Size();

  //for(int i = 0; i < orders_size; i++ ){
  //  long ticket_id = OrdersJason["orders_open"][i]["ticket_id"].ToInt();
  //  if(FindCloseOrderByPositionId(ticket_id)){
  //    PushOrders();
  //    OrdersJason["orders_open"].Remove(IntegerToString(ticket_id));
  //    UpdateOrders();
  //    UpdateCloseOrders();
  //    AddCommentOnChart("CheckOrdersOpenHasClosed: " + IntegerToString(ticket_id));
  //  }
  //}
}

//+------------------------------------------------------------------+
//| Check Store Conditions                                           |
//+------------------------------------------------------------------+
bool CheckServerInformations()
 {
  bool changes = true;
  string orderdata[];
  if(MQLInfoInteger(MQL_TESTER))
    return true;
  if(ApiRequestInformation(orderdata, "store"))
   {
    WebServiceJason.Deserialize(orderdata[0]);
    store_state = WebServiceJason["store_state"].ToStr();
    store_message = WebServiceJason["store_message"].ToStr();
    account_state = WebServiceJason["account_state"].ToStr();                    // enable/disable
    account_mode = WebServiceJason["account_mode"].ToStr();                    // demo/real
    account_margin_mode = WebServiceJason["account_margin_mode"].ToStr();        // hedging/netting
    api_server_hostname = WebServiceJason["api_server_hostname"].ToStr();        // server api
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
  if(changes == false)
   {
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
    SERVER = "localhost:8080";
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
    server_url = SERVER + "/api/" + API_VERSION + "/stores/config";
    url = "http://" + server_url + "/" + EXPERTNAME + "/" + VERSION + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();
   }
  else
    if(action == "closed_info")
     {
      request = "GET";
      server_url = SERVER + "/api/" + API_VERSION + "/transactions/copy/request";
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
    if(response == INVALID_HANDLE)
     {
      Print("Api código de erro: ", GetLastError(), ",  resposta: ", response);
      string comment = StringFormat("É necessário adicionar o endereço %s em Ferramentas->Opções->Experts Advisores->URL WebRequest. Error: %s", SERVER, MB_ICONINFORMATION);
      Print(comment);
      AddCommentOnChart(comment);
      return false;
     }
    else
      if(response == 201 || response == 200)
       {
        string result2 = CharArrayToString(result);
        int size = StringSplit(result2, '/', orderdata);
        return true;
       }
      else
       {
        Print("Conexão com servidor com Error: ", GetLastError(), ", Resposta: ", response);
        string comment = ("Conexão com servidor com Error: " + IntegerToString(GetLastError()) + ", Resposta: " + IntegerToString(response));
        AddCommentOnChart(comment);
       }
    internet_down = true;
    Print("Verifique a sua conexão com a internet ou servidor fora temporariamente.");
   }
  while(response != 201);
  return false;
 }


//+------------------------------------------------------------------+
//| ApiTrasmitInformation                                            |
//+------------------------------------------------------------------+
bool ApiTrasmitInformation(const string message)
{
    MqlDateTime mqlTime;
    TimeCurrent(mqlTime);

    int currentHour = mqlTime.hour;
    int currentMinute = mqlTime.min;
    
    string request = "POST";
    string server_url = SERVER + "/api/" + API_VERSION + "/copy/post";
    string url = "http://" + server_url + "/" + EXPERTNAME + "/" + VERSION + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();

    char post[];
    StringToCharArray(message, post, 0, StringLen(message));

    char result[];
    string headers;

    int retryCount = 0;
    int maxRetries = 35; // specify maximum retry attempts

    do
    {
        if(MQLInfoInteger(MQL_TESTER))
        {
            //SaveLogToFile(OrdersJason.Serialize());
            return true;
        }

        int response = WebRequest("POST", url, NULL, NULL, 135000, post, 0, result, headers);

        if(response == 201)
        {
            string response_string = CharArrayToString(result);
            if(StringFind("OK|OK|OK", response_string) != INVALID_HANDLE)
                return true;
        }
        else
        {
            string response_string = CharArrayToString(result);
            Print(response_string);
            string logMsg = "Attempt " + IntegerToString(retryCount+1) + ": Connection to server failed - Response: " + IntegerToString(response) + ", GetLastError: " + IntegerToString(GetLastError());
            Print(logMsg);
            AddCommentOnChart(logMsg);
        }

        retryCount++;

    } while(retryCount < maxRetries);

    string errorMsg = "Connection to server failed after " + IntegerToString(maxRetries) + " attempts. Please check your network.";
    Print(errorMsg);
    AddCommentOnChart(errorMsg);

    return false;
}

bool IsWeekend(int currentHour)
{
    MqlDateTime mqlTime;
    TimeCurrent(mqlTime);
    currentDay = mqlTime.day_of_week;

    return ((currentDay == 5 && currentHour >= 19) || currentDay == 6 || (currentDay == 0 && currentHour < 18));
}



//+------------------------------------------------------------------+
//| Push the open order to all of the subscriber                     |
//+------------------------------------------------------------------+
int PushOrders()
 {
  UpdateCloseOrders();
  UpdateOrders();
//CJAVal MTA;
//MTA["params"]["PATH"] = TerminalInfoString(TERMINAL_PATH);
//MTA["params"]["DATA_PATH"] = TerminalInfoString(TERMINAL_DATA_PATH);
//MTA["params"]["COMMON_PATH"] = TerminalInfoString(TERMINAL_COMMONDATA_PATH);
  string jason_message = "imentore_copy=";
  //StringAdd(jason_message, OrdersJason.Serialize());
  jason_message = JasonOrdersOpen.Serialize();
  if(ApiTrasmitInformation(jason_message))
   {
    comment_order_status = "Sent orders to server - Status: OK";
    Print(comment_order_status);
    commentLineItemMakeOrder = AddCommentOnChart(comment_order_status);
   }
  else
   {
    comment_order_status = "Sent orders to server - Status ERROR: " + IntegerToString(GetLastError());
    Print(comment_order_status);
    commentLineItemMakeOrder = AddCommentOnChart(comment_order_status);
   }
  return 1;
 }

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
void GetCurrentOrdersOnStart()
 {
  PushOrders();
  firstRun = false;
 }

//+------------------------------------------------------------------+
//| Update all of the orders status                                  |
//+------------------------------------------------------------------+
void UpdateOrders()
 {
  
  //OrderJason* orderStruct;
  int ordersJasonCount;
  order_size = PositionsTotal();
  ArrayResize(orders, int(order_size));
  
  for(int orderindex = 0; orderindex < order_size; orderindex++)
   {
    // CJAVal orderJason;
    // OrderStruct openOrder;
    //OrderJason openOrder;
    JasonStruct* openOrder = new JasonStruct();

    
    ulong ticketid         = PositionGetTicket(orderindex);
    string aTicketID       = IntegerToString(ticketid);
    openOrder.symbol       = PositionGetString(POSITION_SYMBOL);
    openOrder.ticket_master= long(ticketid);
    openOrder.ticket_deal  = FindDealOrderByTicketId(ticketid);
    openOrder.type         = PositionGetInteger(POSITION_TYPE);
    openOrder.volume       = PositionGetDouble(POSITION_VOLUME);
    openOrder.price_open   = PositionGetDouble(POSITION_PRICE_OPEN);
    openOrder.profit       = PositionGetDouble(POSITION_PROFIT);
    openOrder.stop_loss    = NormalizeDigits(PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL), PositionGetInteger(POSITION_TYPE), PositionGetString(POSITION_SYMBOL), "sl");
    openOrder.take_profit  = NormalizeDigits(PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP), PositionGetInteger(POSITION_TYPE), PositionGetString(POSITION_SYMBOL), "tp");
    openOrder.mae          = 0.0;
    openOrder.mfe          = 0.0;
    openOrder.open_at      = TimeToString(PositionGetInteger(POSITION_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    openOrder.time_gmt     = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    openOrder.time_trader  = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    openOrder.timezone     = long((TimeLocal() - TimeTradeServer()) / 3600);
    openOrder.magic_number = PositionGetInteger(POSITION_MAGIC);
    
    ordersJasonCount   = JasonOrdersOpen.Count();
    double jason_profit, jason_volume, jason_take_profit, jason_stop_loss;
    string state_meta;
    
    if(firstRun)
     {
      state_meta  = "PROFIT/SLTPLOT";
     }
    else{

      JasonStruct orderStruct = new JasonStruct();
      
      orderStruct = JasonOrdersOpen.FindOrderByTicketMaster(ticketid);
      if(ordersJasonCount > 0 && orderStruct.isValid)
       {
        jason_profit      = orderStruct.profit;
        jason_volume      = orderStruct.volume;
        jason_take_profit = orderStruct.take_profit;
        jason_stop_loss   = orderStruct.stop_loss;
        //if(CompareDoubles(jason_profit, PositionGetDouble(POSITION_PROFIT)))
        //  /state_meta = "PROFIT";
        //if(CompareDoubles(jason_volume, PositionGetDouble(POSITION_VOLUME)))
        //  OrdersJason["orders_open"][aTicketID]["state_meta"]  = OrdersJason["orders_open"][aTicketID]["state_meta"].ToStr() + "/VOLUME";
        if(CompareDoubles(jason_take_profit, PositionGetDouble(POSITION_TP)) || CompareDoubles(jason_stop_loss, PositionGetDouble(POSITION_SL)) || (CompareDoubles(jason_volume, PositionGetDouble(POSITION_VOLUME))))
          state_meta += "PROFIT/SLTPLOT";

       }
     }
    //------------------------------------------------- Save Order Infos into Array ORDERS Json
    openOrder.state_meta = state_meta;
    openOrder.comment    = PositionGetString(POSITION_COMMENT);
    
    JasonOrdersOpen.AddOrder(aTicketID, openOrder);
    
    //OrderJason orderStruct;
    ordersJasonCount   = JasonOrdersOpen.Count();
    
    JasonStruct orderStruct = new JasonStruct();

    orderStruct = JasonOrdersOpen.FindOrderByTicketMaster(ticketid);
    if(ordersJasonCount > 0)
     {
      if(orderStruct.isValid)
       {
        orderStruct.mae = CalculateMFEMAE(ticketid, "mae", openOrder.mae);
        orderStruct.mfe = CalculateMFEMAE(ticketid, "mfe", openOrder.mfe);
        
        JasonOrdersOpen.SaveOrder(aTicketID, &orderStruct);
       }
     }
    //Print("Order Open Ticket " + aTicketID + " :" + orderJason.Serialize());
    //orderJason.Clear();
   }
  //string ordersStr = OrdersJason.Serialize();
  //string sOrders = ("ORDERS: " + ordersStr);
  //Print(sOrders);
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateCloseOrders()
 {
//  datetime currentTime = TimeCurrent();
//  datetime daysAgo     = (currentTime / 86400 * 86400) - 10 * 86400;
//  int total_orders     = HistoryDealsTotal();
//  int count_order      = 0;
//  
//  HistorySelect(0, currentTime);
//  
//  for(int orderindex = total_orders - 1; (orderindex >= 0 && count_order <=20); orderindex--)
//   {
//    count_order += 1;
//    CJAVal orderJason;
//    ulong deal_ticket      = HistoryDealGetTicket(orderindex);
//    ulong deal_position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
//    datetime orderTime = datetime(HistoryDealGetInteger(deal_ticket, DEAL_TIME));
//    ulong ticket_id = deal_position_id;
//    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
//    if(orderTime < daysAgo)
//      break;
//    if(entry_type == DEAL_ENTRY_IN)
//      continue;
//    string aTicketId = IntegerToString(ticket_id);
//    ulong deal_ticket_in = FindDealOrderByTicketId(deal_position_id);
//    string order_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
//    long order_type     = HistoryDealGetInteger(deal_ticket_in, DEAL_TYPE);
//    double price_open   = HistoryDealGetDouble(deal_ticket_in, DEAL_PRICE);
//    double price_closed = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
//    orderJason["symbol"]        = order_symbol;
//    orderJason["ticket_id"]     = long(ticket_id);
//    orderJason["ticket_deal"]   = HistoryDealGetInteger(deal_ticket, DEAL_TICKET);
//    orderJason["type"]          = order_type;
//    orderJason["volume"]        = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
//    orderJason["price_open"]    = price_open;
//    orderJason["price_closed"]  = price_closed;
//    orderJason["profit"]        = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
//    orderJason["fees"]          = GetFeesOrderHistory(deal_ticket);
//    orderJason["stop_loss"]     = NormalizeDigits(price_open, HistoryDealGetDouble(deal_ticket, DEAL_SL), order_type, order_symbol, "sl");
//    orderJason["take_profit"]   = NormalizeDigits(price_open, HistoryDealGetDouble(deal_ticket, DEAL_TP), order_type, order_symbol, "tp");
//    orderJason["mae"]           = CalculateMFEMAE(ticket_id, "mae", 0);
//    orderJason["mfe"]           = CalculateMFEMAE(ticket_id, "mfe", 0);
//    //if(ArraySize(OrdersJason["orders_open"].children) > 0 && OrdersJason["orders_open"].type != jtUNDEF && OrdersJason["orders_open"][aTicketId].type != jtUNDEF)
//    // {
//    //  OrdersJason["orders_open"][aTicketId]["mae"] = CalculateMFEMAE(ticket_id, "mae", OrdersJason["orders_open"][aTicketId]["mae"].ToDbl());
//    //  OrdersJason["orders_open"][aTicketId]["mfe"] = CalculateMFEMAE(ticket_id, "mfe", OrdersJason["orders_open"][aTicketId]["mfe"].ToDbl());
//    // }
//    orderJason["open_at"]       = TimeToString(HistoryDealGetInteger(deal_ticket_in, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
//    orderJason["close_at"]      = TimeToString(HistoryDealGetInteger(deal_ticket, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
//    orderJason["time_gmt"]      = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
//    orderJason["time_trader"]   = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
//    orderJason["timezone"]      = long((TimeLocal() - TimeTradeServer()) / 3600);
//    orderJason["magic_number"]   = HistoryDealGetInteger(deal_ticket_in, DEAL_MAGIC);
//    orderJason["comment"]       = HistoryDealGetString(deal_ticket_in, DEAL_COMMENT);
//    //Print("Order Closed Ticket " + IntegerToString(ticket_id) + " : " + orderJason.Serialize());
//    OrdersJason["orders_closed"][aTicketId] = orderJason;
//    orderJason.Clear();
//   }
//string ordersStr = OrdersClosedJason.Serialize();
//Print(ordersStr);
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
//| FindCloseOrderByPositionId                                       |
//+------------------------------------------------------------------+
bool FindCloseOrderByPositionId(const long ticketid)
{
  HistorySelect(0, TimeCurrent());
  
  for(int i = HistoryDealsTotal(); i > 0; i--)
   {
    ulong deal_ticket = HistoryDealGetTicket(i);
    int entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    long position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    
    if(entry_type != DEAL_ENTRY_IN && ticketid == position_id)
      return true;
   }
  return false;
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
//| FindDealOrderByTicketId `                                         |
//+------------------------------------------------------------------+
long FindDealOrderByTicketId(const ulong ticketid)
 {
  HistorySelect(0, TimeCurrent());
  for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
    ulong deal_ticket = HistoryDealGetTicket(i);
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    long ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    if(entry_type == DEAL_ENTRY_IN && ticket == ticketid)
     {
      return long(deal_ticket);
     }
   }
  return INVALID_HANDLE;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ReadMessageToFile(string message)
 {
//--- open the file
//string InpFileNameOut = "signal_copy_receive.txt"; // file name
// string InpDirectoryName = "data"; // directory name
  ResetLastError();
  file_handle_out = FileOpen(LogFileName, FILE_READ | FILE_BIN | FILE_ANSI);
  if(file_handle_out != INVALID_HANDLE)
   {
    PrintFormat("%s file is available for reading", LogFileName);
    PrintFormat("File path: %s\\Files\\", TerminalInfoString(TERMINAL_DATA_PATH));
    //--- additional variables
    int    str_size;
    string str;
    //--- read data from the file
    while(!FileIsEnding(file_handle_out))
     {
      //--- find out how many symbols are used for writing the time
      str_size = FileReadInteger(file_handle_out, INT_VALUE);
      //--- read the string
      str = FileReadString(file_handle_out, str_size);
      //--- print the string
      PrintFormat(str);
     }
    //--- close the file
    FileClose(file_handle_out);
    PrintFormat("Data is read, %s file is closed", LogFileName);
    return true;
   }
  else
    PrintFormat("Failed to open %s file, Error code = %d", LogFileName, GetLastError());
  return false;
 }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SaveLogToFile(string message)
 {
// Print("SaveLogToFile - Message:", message);
  file_handle_out = FileOpen(LogFileName, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI | FILE_TXT);
  if(file_handle_out != INVALID_HANDLE)
   {
    FileSeek(file_handle_out, 0, SEEK_END);
    //message = StringFormat("%s;%s; %s"message, meta_state, TimeToString(TimeCurrent()));
    FileWriteString(file_handle_out, message + "\r\n");
    FileClose(file_handle_out);
    // PrintFormat("SaveLogToFile - %s file was write", LogFileName);
    return true;
   }
  else
    PrintFormat("Failed to open %s file, Error code = %d", LogFileName, GetLastError());
  return false;
 }

//+------------------------------------------------------------------+
//| MQL4 -> MQL5                                                     |
//+------------------------------------------------------------------+
bool IsDemoMQL4()
 {
  if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO)
    return(true);
  else
    return(false);
 }

//+------------------------------------------------------------------+
bool IsHedging()
 {
  long margin = AccountInfoInteger(ACCOUNT_TRADE_MODE);
  int margmod = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  return(margmod == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
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
    uchar charArray[];

    for(int i = 0; i < inputLength; i++)
    {
        string charStr = StringSubstr(inputString, i, 1);
        StringToCharArray(charStr, charArray, 0, WHOLE_ARRAY);
        int charValue = charArray[0];

        if((charValue >= 48 && charValue <= 57) || // números
           (charValue >= 65 && charValue <= 90) || // letras maiúsculas
           (charValue >= 97 && charValue <= 122)) // letras minúsculas
        {
            StringConcatenate(resultString, resultString, charStr);
        }
    }

    return resultString;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeDigits(double vprice, double number, long vtype, string symbol, string kind)
 {
  int vdigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
  double vpoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
// Verifique se 'number' é um número inteiro
  if(MathMod(number, 1.0) == 0.0 && number > 0.0)
   {
    // Ajusta vpoint de acordo com vdigits
    switch(vdigits)
     {
      case 2:
        vpoint = 0.1;
        break;
      case 3:
        vpoint = 0.01;
        break;
      case 4:  // case 5, 6, 7, 8, etc. também caem aqui devido à falta de breaks
      default:
        vpoint = 0.0001;
        break;
     }
    // Verifica se vtype é par (0, 2, 4, 6, etc.)
    if(vtype % 2 == 0)
     {
      number = NormalizeDouble(vprice - number * vpoint, vdigits);
     }
    else
     {
      double mod = (kind == "tp") ? -1.0 : 1.0;
      number = NormalizeDouble(vprice + number * mod * vpoint, vdigits);
     }
   }
  return number;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetFeesOrderHistory(const long ticket_deal)
 {
  double fee = HistoryDealGetDouble(ticket_deal, DEAL_FEE);
  double swap = HistoryDealGetDouble(ticket_deal, DEAL_SWAP);
  double comission = HistoryDealGetDouble(ticket_deal, DEAL_COMMISSION);
  double fees = comission * 2 + swap + fee;
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
    if(type == "mfe" && profit > maxDayMFE)
     {
      if(profit > value)
        value = profit;
      // maxDayMFE = profit;
      // return maxDayMFE;
      //mae_mfe = "Ticket ID:"+IntegerToString(ticketid)+ "\nMax MFE: "+DoubleToString(OrdersJason["mfe"].ToDbl())+ " \nMax MAE: "+ DoubleToString(OrdersJason["mae"].ToDbl());
     }
    else
      if(type == "mae" && profit < 0)
       {
        if(profit < value)
          value = profit;
        // maxDayMAE = profit;
        // return maxDayMAE;
        //mae_mfe = "Ticket ID:"+IntegerToString(ticketid)+ "\nMax MFE: "+DoubleToString(OrdersJason["mfe"].ToDbl())+ " \nMax MAE: "+ DoubleToString(OrdersJason["mae"].ToDbl());
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
//// CJAVal OrdersJason;
//  string mfe_mae_string;
//  int totalOrders = ArraySize(orders);
//  double profit = 0;
//  if(totalOrders > 0)
//   {
//    for(int orderindex = totalOrders - 1; orderindex >= 0; orderindex--)
//     {
//      // CJAVal OrdersJason;
//      // OrdersJason.Deserialize(orders[orderindex]);
//      long ticketid = OrdersJason["orders_open"]["ticket_id"].ToInt();
//      if(PositionSelectByTicket(ticketid))
//       {
//        double value_mae  = OrdersJason["mae"].ToDbl();
//        OrdersJason["mae"] = CalculateMFEMAE(ticketid, "mae", value_mae);
//        double value_mfe  = OrdersJason["mfe"].ToDbl();
//        OrdersJason["mfe"] = CalculateMFEMAE(ticketid, "mfe", value_mfe);
//        string mae_mfe = "\nTicket ID:" + IntegerToString(ticketid) + "\nMax MFE: " + DoubleToString(OrdersJason["mfe"].ToDbl()) + " \nMax MAE: " + DoubleToString(OrdersJason["mae"].ToDbl());
//        // OrdersJason["time_trader"] = TimeToString(TimeTradeServer(),(TIME_DATE|TIME_MINUTES|TIME_SECONDS));
//        // OrdersJason["profit"] = PositionGetDouble(POSITION_PROFIT);
//        // OrdersJason["state_meta"] = "modify";
//        StringConcatenate(mfe_mae_string, (mae_mfe + "\n"), mfe_mae_string);
//       }
//      // orders[orderindex] = OrdersJason.Serialize();
//     }
//    comment_mfe_mae_line_item = AddCommentOnChart(mfe_mae_string, comment_mfe_mae_line_item);
//   }
 }
//+------------------------------------------------------------------+
//| SendMessageToServer                                              |
//+------------------------------------------------------------------+
void SendMessageToServer(const MqlTradeResult &result, const MqlTradeRequest &request, JasonStruct &OrderJason, string const action, string const state, string const meta_state, const string fuction_name, string log_message)
 {
  //string message_format;
  long symbol_digits = SymbolInfoInteger(OrderJason.symbol, SYMBOL_DIGITS);
  string meta_message = StringFormat("%s - Action: %s - Meta State: %s - Symbol: %s - Type: %d - TicketMaster: %d - TicketSlave: %d - Volume: %s - TP: %d - SL: %d - ", ToUpper(fuction_name), ToUpper(action), meta_state, OrderJason.symbol, OrderJason.type, OrderJason.ticket_master, OrderJason.ticket_slave, DoubleToString(OrderJason.volume, int(symbol_digits)), request.tp, request.sl);
  
  Print(meta_message);
  Print(log_message);
  
  AddCommentOnChart(meta_message);
  AddCommentOnChart(log_message);

//  string sprofit = DoubleToString(GetOrderProfit(OrderJason.comment), int(SymbolInfoInteger(OrderJason.symbol, SYMBOL_DIGITS)));
//
//  // if(fuction_name == "OrderCreate")
//  //   message_format = MessageSendFormat(request.magic, action, state, meta_state, OrderJason.ticket_slave, OrderJason.ticket_master, result.deal, request.symbol, request.type, result.price, 0, OrderJason.lot, request.sl, request.tp, sprofit, request.comment, DoubleToString(double(TimeGMT())), meta_message + log_message);
//  // else
//   message_format = MessageSendFormat(request.magic, action, state, meta_state, OrderJason.ticket_slave, OrderJason.ticket_master, OrderJason.ticket_deal, OrderJason.symbol, OrderJason.type, OrderJason.price_open, OrderJason.price_close, OrderJason.lot, OrderJason.stop_loss, OrderJason.take_profit, sprofit, OrderJason.comment, OrderJason.open_at, meta_message  + log_message);
  PushOrders();
 }
//+------------------------------------------------------------------+
//| ShowCommentOnChart                                                  |
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
  for(int i = 0; i < ArraySize(commentOnChartInit); i++)
   {
    if(StringLen(commentOnChartInit[i]) == 0)
      continue;
    finalText += commentOnChartInit[i] + "\n"; // Adicione cada string do array à string final, seguida por uma quebra de linha
   }
  finalText += "\n";
  for(int i = 0; i < ArraySize(commentOnChartTick); i++)
   {
    if(StringLen(commentOnChartTick[i]) == 0)
      continue;
    line_item = long(i);
    finalText += commentOnChartTick[i] + "\n"; // Adicione cada string do array à string final, seguida por uma quebra de linha
   }
  Comment(finalText);
  return line_item;
// ObjectSetString(0, objectName, OBJPROP_TEXT, finalText); // Texto para exibir
// ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrBlack); // Cor do texto
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long AddCommentOnChart(string newMessage, long line_item = 0)
{
  MqlDateTime mqlTime;
  datetime currentTime = TimeCurrent(mqlTime);
  string sDate = TimeToString(TimeCurrent(), TIME_MINUTES | TIME_SECONDS);
  newMessage = sDate + " - " + newMessage;

  if(line_item > 0)
  {
    bool foundLineItem = false;

    for(int i = 0; i < ArraySize(commentOnChartInitPosition); i++)
    {
      if(commentOnChartInitPosition[i] == line_item)
      {
        commentOnChartInit[i] = newMessage;
        foundLineItem = true;
        break;
      }
    }

    if(!foundLineItem)
    {
      ArrayResize(commentOnChartInit, ArraySize(commentOnChartInit) + 1);
      ArrayResize(commentOnChartInitPosition, ArraySize(commentOnChartInitPosition) + 1);
      commentOnChartInit[ArraySize(commentOnChartInit) - 1] = newMessage;
      commentOnChartInitPosition[ArraySize(commentOnChartInitPosition) - 1] = line_item;
    }
  
    // Bubble sort algorithm for sorting arrays
    for(int i = 0; i < ArraySize(commentOnChartInitPosition) - 1; i++)
    {
      for(int j = 0; j < ArraySize(commentOnChartInitPosition) - i - 1; j++)
      {
        if(commentOnChartInitPosition[j] > commentOnChartInitPosition[j + 1])
        {
          // Swap positions
          long tempPos = commentOnChartInitPosition[j];
          commentOnChartInitPosition[j] = commentOnChartInitPosition[j + 1];
          commentOnChartInitPosition[j + 1] = tempPos;
          // Swap messages
          string tempMsg = commentOnChartInit[j];
          commentOnChartInit[j] = commentOnChartInit[j + 1];
          commentOnChartInit[j + 1] = tempMsg;
        }
      }
    }

    ShowCommentOnChart();
  }
  else
  {
    if(ArraySize(commentOnChartTick) > 25)
      ArrayResize(commentOnChartTick, 0);
      
    ArrayResize(commentOnChartTick, ArraySize(commentOnChartTick) + 1);
    commentOnChartTick[ArraySize(commentOnChartTick) - 1] = newMessage;
    line_item = ShowCommentOnChart();
  }

  SaveLogToFile(newMessage);

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
string ToUpper(string str)
 {
  if(StringToUpper(str))
   {
    return str;
   }
  else
   {
    Print("Falha ao converter a string para maiúsculas.");
    return str;
   }
 }

//+------------------------------------------------------------------+
//| Output text                                                      |
//+------------------------------------------------------------------+
void OutputTest(const string text)
 {
  if(InpOutput == txt_file)
    FileWriteString(file_handle_out, text + "\r\n");
  else
    Print(text);
 }

//+------------------------------------------------------------------+
//| SetLogFileName                                                   |
//+------------------------------------------------------------------+
void SetLogFileName()
 {
  MqlDateTime mqlTime;
  TimeCurrent(mqlTime);
  string eaName = CamelCaseToSnakeCase(EXPERTNAME);
  string newLogFileName = StringFormat("%s/log_%04d%02d%02d.txt", eaName, mqlTime.year, mqlTime.mon, mqlTime.day);
  if(newLogFileName != LogFileName)
   {
    LogFileName = newLogFileName;
    AddCommentOnChart("Log Salvo em Arquivo -> Abrir pasta de dados -> MQL5/Files/" + LogFileName, 3);
   }
 }

//+------------------------------------------------------------------+
//| CamelCaseToSnakeCase                                             |
//+------------------------------------------------------------------+
string CamelCaseToSnakeCase(string s)
 {
  string result = "";
  for(int i = 0; i < StringLen(s); i++)
   {
    string c = StringSubstr(s, i, 1);
    string lower_c = c;
    StringToLower(lower_c);
    if(c != lower_c && i != 0)
     {
      result += "_";
     }
    result += lower_c;
   }
  return result;
 }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ShowHistoryDealsAndOrders()
 {
  uint total_deals = HistoryDealsTotal();
  ulong ticket_history_deal = 0;
//--- for all deals
  for(uint i = 0; i < total_deals; i++)
   {
    //--- try to get deals ticket_history_deal
    if((ticket_history_deal = HistoryDealGetTicket(i)) > 0)
     {
      long     deal_ticket       = HistoryDealGetInteger(ticket_history_deal, DEAL_TICKET);
      long     deal_order        = HistoryDealGetInteger(ticket_history_deal, DEAL_ORDER);
      long     deal_time         = HistoryDealGetInteger(ticket_history_deal, DEAL_TIME);
      long     deal_time_msc     = HistoryDealGetInteger(ticket_history_deal, DEAL_TIME_MSC);
      long     deal_type         = HistoryDealGetInteger(ticket_history_deal, DEAL_TYPE);
      long     deal_entry        = HistoryDealGetInteger(ticket_history_deal, DEAL_ENTRY);
      long     deal_magic        = HistoryDealGetInteger(ticket_history_deal, DEAL_MAGIC);
      long     deal_reason       = HistoryDealGetInteger(ticket_history_deal, DEAL_REASON);
      long     deal_position_id  = HistoryDealGetInteger(ticket_history_deal, DEAL_POSITION_ID);
      double   deal_volume       = HistoryDealGetDouble(ticket_history_deal, DEAL_VOLUME);
      double   deal_price        = HistoryDealGetDouble(ticket_history_deal, DEAL_PRICE);
      double   deal_commission   = HistoryDealGetDouble(ticket_history_deal, DEAL_COMMISSION);
      double   deal_swap         = HistoryDealGetDouble(ticket_history_deal, DEAL_SWAP);
      double   deal_profit       = HistoryDealGetDouble(ticket_history_deal, DEAL_PROFIT);
      string   deal_symbol       = HistoryDealGetString(ticket_history_deal, DEAL_SYMBOL);
      string   deal_comment      = HistoryDealGetString(ticket_history_deal, DEAL_COMMENT);
      string   deal_external_id  = HistoryDealGetString(ticket_history_deal, DEAL_EXTERNAL_ID);
      string time = TimeToString((datetime)deal_time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      string type = EnumToString((ENUM_DEAL_TYPE)deal_type);
      string entry = EnumToString((ENUM_DEAL_ENTRY)deal_entry);
      string str_deal_reason = EnumToString((ENUM_DEAL_REASON)deal_reason);
      long digits = 5;
      if(deal_symbol != "" && deal_symbol != NULL)
       {
        if(SymbolSelect(deal_symbol, true))
          digits = SymbolInfoInteger(deal_symbol, SYMBOL_DIGITS);
       }
      //---
      string text = "";
      text = "Deal:";
      OutputTest(text);
      text = StringFormat("%-20s %-20s %-20s %-20s %-20s %-20s %-20s %-20s %-20s",
                          "|Ticket", "|Order", "|Time", "|Time msc", "|Type", "|Entry", "|Magic", "|Reason", "|Position ID");
      OutputTest(text);
      text = StringFormat("|%-19d |%-19d |%-19s |%-19I64d |%-19s |%-19s |%-19d |%-19s |%-19d"
                          , deal_ticket, deal_order, time, deal_time_msc, type, entry, deal_magic, str_deal_reason, deal_position_id);
      OutputTest(text);
      text = StringFormat("%-20s %-20s %-20s %-20s %-20s %-20s %-41s %-20s",
                          "|Volume", "|Price", "|Commission", "|Swap", "|Profit", "|Symbol", "|Comment", "|External ID");
      OutputTest(text);
      text = StringFormat("|%-19.2f |%-19." + IntegerToString(digits) + "f |%-19.2f |%-19.2f |%-19.2f |%-19s |%-40s |%-19s",
                          deal_volume, deal_price, deal_commission, deal_swap, deal_profit, deal_symbol, deal_comment, deal_external_id);
      OutputTest(text);
      //--- try to get oeders ticket_history_order
      if(HistoryOrderSelect(deal_order))
       {
        long     o_ticket          = HistoryOrderGetInteger(deal_order, ORDER_TICKET);
        long     o_time_setup      = HistoryOrderGetInteger(deal_order, ORDER_TIME_SETUP);
        long     o_type            = HistoryOrderGetInteger(deal_order, ORDER_TYPE);
        long     o_state           = HistoryOrderGetInteger(deal_order, ORDER_STATE);
        long     o_time_expiration = HistoryOrderGetInteger(deal_order, ORDER_TIME_EXPIRATION);
        long     o_time_done       = HistoryOrderGetInteger(deal_order, ORDER_TIME_DONE);
        long     o_time_setup_msc  = HistoryOrderGetInteger(deal_order, ORDER_TIME_SETUP_MSC);
        long     o_time_done_msc   = HistoryOrderGetInteger(deal_order, ORDER_TIME_DONE_MSC);
        long     o_type_filling    = HistoryOrderGetInteger(deal_order, ORDER_TYPE_FILLING);
        long     o_type_time       = HistoryOrderGetInteger(deal_order, ORDER_TYPE_TIME);
        long     o_magic           = HistoryOrderGetInteger(deal_order, ORDER_MAGIC);
        long     o_reason          = HistoryOrderGetInteger(deal_order, ORDER_REASON);
        long     o_position_id     = HistoryOrderGetInteger(deal_order, ORDER_POSITION_ID);
        long     o_position_by_id  = HistoryOrderGetInteger(deal_order, ORDER_POSITION_BY_ID);
        double   o_volume_initial  = HistoryOrderGetDouble(deal_order, ORDER_VOLUME_INITIAL);
        double   o_volume_current  = HistoryOrderGetDouble(deal_order, ORDER_VOLUME_CURRENT);
        double   o_open_price      = HistoryOrderGetDouble(deal_order, ORDER_PRICE_OPEN);
        double   o_sl              = HistoryOrderGetDouble(deal_order, ORDER_SL);
        double   o_tp              = HistoryOrderGetDouble(deal_order, ORDER_TP);
        double   o_price_current   = HistoryOrderGetDouble(deal_order, ORDER_PRICE_CURRENT);
        double   o_price_stoplimit = HistoryOrderGetDouble(deal_order, ORDER_PRICE_STOPLIMIT);
        string   o_symbol          = HistoryOrderGetString(deal_order, ORDER_SYMBOL);
        string   o_comment         = HistoryOrderGetString(deal_order, ORDER_COMMENT);
        string   o_extarnal_id     = HistoryOrderGetString(deal_order, ORDER_EXTERNAL_ID);
        string str_o_time_setup       = TimeToString((datetime)o_time_setup, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        string str_o_type             = EnumToString((ENUM_ORDER_TYPE)o_type);
        string str_o_state            = EnumToString((ENUM_ORDER_STATE)o_state);
        string str_o_time_expiration  = TimeToString((datetime)o_time_expiration, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        string str_o_time_done        = TimeToString((datetime)o_time_done, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        string str_o_type_filling     = EnumToString((ENUM_ORDER_TYPE_FILLING)o_type_filling);
        string str_o_type_time        = TimeToString((datetime)o_type_time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        string str_o_reason           = EnumToString((ENUM_ORDER_REASON)o_reason);
        text = "Order:";
        OutputTest(text);
        text = StringFormat("%-20s %-20s %-20s %-20s %-20s %-20s %-20s %-20s %-20s",
                            "|Ticket", "|Time setup", "|Type", "|State", "|Time expiration",
                            "|Time done", "|Time setup msc", "|Time done msc", "|Type filling");
        OutputTest(text);
        text = StringFormat("|%-19d |%-19s |%-19s |%-19s |%-19s |%-19s |%-19I64d |%-19I64d |%-19s",
                            o_ticket, str_o_time_setup, str_o_type, str_o_state, str_o_time_expiration, str_o_time_done,
                            o_time_setup_msc, o_time_done_msc, str_o_type_filling);
        OutputTest(text);
        text = StringFormat("%-20s %-20s %-20s %-20s %-20s",
                            "|Type time", "|Magic", "|Reason", "|Position id", "|Position by id");
        OutputTest(text);
        text = StringFormat("|%-19s |%-19d |%-19s |%-19d |%-19d",
                            str_o_type_time, o_magic, str_o_reason, o_position_id, o_position_by_id);
        OutputTest(text);
        text = StringFormat("%-20s %-20s %-20s %-20s %-20s %-20s %-20s",
                            "|Volume initial", "|Volume current", "|Open price", "|sl", "|tp", "|Price current", "|Price stoplimit");
        OutputTest(text);
        text = StringFormat("|%-19.2f |%-19.2f |%-19." + IntegerToString(digits) + "f |%-19." + IntegerToString(digits) +
                            "f |%-19." + IntegerToString(digits) + "f |%-19." + IntegerToString(digits) +
                            "f |%-19." + IntegerToString(digits) + "f",
                            o_volume_initial, o_volume_current, o_open_price, o_sl, o_tp, o_price_current, o_price_stoplimit);
        OutputTest(text);
        text = StringFormat("%-20s %-41s %-20s", "|Symbol", "|Comment", "|Extarnal id");
        OutputTest(text);
        text = StringFormat("|%-19s |%-40s |%-19s", o_symbol, o_comment, o_extarnal_id);
        OutputTest(text);
        int d = 0;
       }
      else
       {
        text = "Order " + IntegerToString(deal_order) + " is not found in the trade history between the dates " +
               TimeToString(from_date, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " and " +
               TimeToString(to_date, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        OutputTest(text);
       }
      text = "";
      OutputTest(text);
      int d = 0;
     }
   }
 }
//+------------------------------------------------------------------+
