//+------------------------------------------------------------------+
//#property version "2.24"
#define EXPERTNAME "imentore_copy"
#define VERSION "2_24"
#define VERSION_UPDATE "02"

#define APPNAME "Imentore Copy"
#define APPVERSION "2.24"

#property copyright   "Update "+ VERSION_UPDATE +"- Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

//+------------------------------------------------------------------+
#include <Trade\DealInfo.mqh>
#include <Trade\Trade.mqh>
#include <JAson.mqh>

CTrade trade;  // Instance of CTrade

//+------------------------------------------------------------------+
input bool   EnvironmentLocal  = false;

//+------------------------------------------------------------------+
string ACCOUNTLOGIN            = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
string API_VERSION             = "v2";
string ACCOUNT_SERVER_NAME     = "";
string SERVER                  = "mt5-web-replicator.example.com";      // Subscribe server ip
int    MILLISECOND_TIMER       = 3500;

//+------------------------------------------------------------------+
//--- Globales Order
string orders[];
string store_state;
string store_message;
string account_state;
string account_margin_mode;
string account_mode;                // Under real server (Default is false)
string api_server_hostname;

//+------------------------------------------------------------------+ Current
string LogFileName;
string commentOnChartInit[];
string commentOnChartTick[];
string comment_order_status;
long   commentOnChartInitPosition[];

int    SleepTries                   = 1;
int    file_handle_out              = 0;
long   commentLineItemOrder         = 0;
long   commentLineItemMakeOrder     = 0;
long   comment_mfe_mae_line_item    = 0;
double maxDayMFE                    = 0;
double maxDayMAE                    = 0;
bool   firstRun                     = true;

int       timecurrent1  = int(TimeTradeServer());
datetime  currentDay    = TimeLocal() - TimeLocal() % 86400;

//+------------------------------------------------------------------+ Tester
int NewCandleCount;
ulong TicketIdTester;
datetime lastCandleTime;

enum ENUM_INFORMATION_OUTPUT
 {
  experts_tab = 0,  // The "Experts" tab
  txt_file    = 1,  // The text file
 };
datetime                from_date   = D'2017.08.07 11:06:20';  // From date
datetime                to_date     = __DATE__ + 60 * 60 * 24; // To date
ENUM_INFORMATION_OUTPUT InpOutput   = experts_tab;                // Information output
// string                  InpFileNameOut = "ImentoreLog.txt";      // File name (only if "Information output" == "The text file")
//---

CJAVal OrdersJason;
CJAVal WebServiceJason;

//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
 {
  SetLogFileName();
  string message = StringFormat("Iniciando Expert %s %s - Update %s", APPNAME, APPVERSION, VERSION_UPDATE);
  AddCommentOnChart(message, 1);
  EventSetMillisecondTimer(MILLISECOND_TIMER);

  ACCOUNT_SERVER_NAME     = RemoveSpecialChars(AccountInfoString(ACCOUNT_SERVER));
  if(DetectEnvironment() == false)
   {
    Print("Expert ", APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE + " não inicializado. Contacte o suporte.");
    string comment = ("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE +" não inicializado. Contacte o suporte.");
    AddCommentOnChart(comment, 2);
    return(INIT_FAILED);
   }
  else
   {
    Print("Expert ", APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE + " inicializado com sucesso.");
    string comment = ("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE +" inicializado com sucesso.");
    AddCommentOnChart(comment, 2);
    GetCurrentOrdersOnStart();
    return(INIT_SUCCEEDED);
   }
 }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer(){
  CalculateOrdersMFEMAE();
  CheckOrdersOpenHasClosed();
  int timeago1 = int(TimeTradeServer() - timecurrent1);
  
  // Loop for 30 seconds
  if(timeago1 > 30){
    if(CheckServerInformations() == false)
      ExpertRemove();
    timecurrent1 = int(TimeTradeServer());
  }
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick(){
  CalculateOrdersMFEMAE();
  CheckOrdersOpenHasClosed();
  SetLogFileName();
  ResetLastError();
  datetime currentNextDay = TimeLocal() - TimeLocal() % 86400;    
  
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
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
  HistorySelect(0, TimeCurrent());

  ENUM_TRADE_TRANSACTION_TYPE transaction_type = trans.type;
  if(transaction_type == TRADE_TRANSACTION_REQUEST || transaction_type == TRADE_TRANSACTION_DEAL_ADD)
  {    
 
    static int counter=0;   // counter of OnTradeTransaction() calls
    static uint lastCallTime=0; // time of the OnTradeTransaction() last call
    
    uint initialTime=GetTickCount();
    uint currentTime=GetTickCount();
    uint comparisonTime=initialTime-2000; // time of the OnTradeTransaction() last call
    
    //--- if the last transaction was performed more than 1 second ago,
    if(currentTime - lastCallTime > 1000)
    {
        //Sleep(250);
        while(initialTime>=comparisonTime)
        {
            counter=0; // then this is a new trade operation, an the counter can be reset
            comparisonTime++;
        }
    }
    lastCallTime = currentTime;
    counter++;

    string ticket_id; 
    ulong deal_ticket = 0;
   
    if(trans.deal > 0)
      deal_ticket = trans.deal; 
    else if(result.deal > 0)
      deal_ticket = result.deal;

    if(trans.order > 0)
      ticket_id = IntegerToString(trans.order);
    else if(request.order > 0)
      ticket_id = IntegerToString(request.order);

    ENUM_DEAL_TYPE  deal_type  = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
    ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    string action         = (deal_entry != DEAL_ENTRY_IN) ? "CLOSE" : "OPEN";    
    if(action == "CLOSE"){
      ulong ticketID = request.position;
      RemoveOrderJason(ticketID);
    }
    
    SendMessageToServer(result, request, trans, action, "OnTradeTransaction");
  }
  //else if(transaction_type == TRADE_TRANSACTION_POSITION)
  //{
  //  PushOrders();
  //}
}

//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
 {
  string comment = ("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE + " removido com sucesso.");
  Print(comment);
  AddCommentOnChart(comment);
  return;
 }

//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void RemoveOrderJason(long ticket_id)
{
  CalculateOrdersMFEMAE();
  string aTicketID = IntegerToString(ticket_id);

  if(OrdersJason["orders_open"].HasKey(aTicketID)){
    if(OrdersJason["orders_open"].HasKey(aTicketID)){      
      OrdersJason["orders_closed"][aTicketID] = OrdersJason["orders_open"][aTicketID];
      OrdersJason["orders_open"].Remove(aTicketID);
      UpdateCloseOrderByTicketId(ticket_id);
    }
  }
}


//+------------------------------------------------------------------+
//| CheckOrdersOpenHasClosed                                         |
//+------------------------------------------------------------------+
void CheckOrdersOpenHasClosed(){
  long orders_size = OrdersJason["orders_open"].Size();

  for(int i = 0; i < orders_size; i++ ){
    long ticket_id = OrdersJason["orders_open"][i]["ticket_id"].ToInt();
    if(FindCloseOrderByPositionId(ticket_id)){
      RemoveOrderJason(ticket_id);
      PushOrders();
      AddCommentOnChart("CheckOrdersOpenHasClosed: " + IntegerToString(ticket_id));
    }
  }
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
    changes = false;

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
    Alert("Error - Imentore não está funcionando corretamente");
    string comment = ("Error - Imentore não está funcionando corretamente");
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
  
  if(!CheckServerInformations())
    return false;
  
  return true;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiRequestInformation(string &orderdata[], const string action)
 {
  string request;
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
            SaveLogToFile(OrdersJason.Serialize());
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

//+------------------------------------------------------------------+
//| Push the open order to all of the subscriber                     |
//+------------------------------------------------------------------+
int PushOrders()
 {
  UpdateOrders();
  //CJAVal MTA;
  //MTA["params"]["PATH"] = TerminalInfoString(TERMINAL_PATH);
  //MTA["params"]["DATA_PATH"] = TerminalInfoString(TERMINAL_DATA_PATH);
  //MTA["params"]["COMMON_PATH"] = TerminalInfoString(TERMINAL_COMMONDATA_PATH);
  string jason_message = "imentore_copy=";
  StringAdd(jason_message, OrdersJason.Serialize());
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
  UpdateCloseOrders();
  PushOrders();
  firstRun = false;
 }

//+------------------------------------------------------------------+
//| Update all of the orders status                                  |
//+------------------------------------------------------------------+
void UpdateOrders()
 {
  long order_size = PositionsTotal();
  ArrayResize(orders, int(order_size));  

  for(int orderindex = 0; orderindex < order_size; orderindex++)
   {
    CJAVal orderJason;

    ulong  ticketid         = PositionGetTicket(orderindex);
    string aTicketID        = IntegerToString(ticketid);
    string symbol           = PositionGetString(POSITION_SYMBOL);
    int    symbol_digit     = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    double sym_volume_step  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double sym_point        = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    orderJason["symbol"]       = symbol;
    orderJason["ticket_id"]    = long(ticketid);
    orderJason["ticket_deal"]  = FindDealInByTicketId(ticketid);
    orderJason["type"]         = PositionGetInteger(POSITION_TYPE);
    orderJason["price_open"]   = DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), symbol_digit);
    orderJason["price_closed"] = DoubleToString(0, symbol_digit);
    orderJason["volume"]       = DoubleToString(PositionGetDouble(POSITION_VOLUME), 2);
    orderJason["profit"]       = DoubleToString(PositionGetDouble(POSITION_PROFIT), 2);
    orderJason["fees"]         = DoubleToString(0, symbol_digit);
    orderJason["stop_loss"]    = DoubleToString(PositionGetDouble(POSITION_SL), symbol_digit);
    orderJason["take_profit"]  = DoubleToString(PositionGetDouble(POSITION_TP), symbol_digit);

    if(firstRun || !OrdersJason["orders_open"].HasKey(aTicketID)){    
      orderJason["mae"]        = DoubleToString(0, symbol_digit);
      orderJason["mfe"]        = DoubleToString(0, symbol_digit);
    }else if(OrdersJason["orders_open"].HasKey(aTicketID)){
      double value_mae         = OrdersJason["orders_open"][aTicketID]["mae"].ToDbl();
      double value_mfe         = OrdersJason["orders_open"][aTicketID]["mfe"].ToDbl();
      orderJason["mae"]        = CalculateMFEMAE(symbol, ticketid, "mae", value_mae);
      orderJason["mfe"]        = CalculateMFEMAE(symbol, ticketid, "mfe", value_mfe);
    }
    
    orderJason["open_at"]      = TimeToString(PositionGetInteger(POSITION_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    orderJason["close_at"]     = TimeToString(0, (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    orderJason["time_gmt"]     = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    orderJason["time_trader"]  = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    orderJason["timezone"]     = long((TimeLocal() - TimeTradeServer()) / 3600);
    orderJason["symbol_digit"] = symbol_digit;
    orderJason["magic_number"] = PositionGetInteger(POSITION_MAGIC);

    int ordersJasonCount = OrdersJason["orders_open"].Size();
    double jason_profit, jason_volume, jason_take_profit, jason_stop_loss;
    string state_meta;

    if(firstRun){
      state_meta  = "PROFIT/SLTPLOT";
    }
    else
      if(ordersJasonCount > 0 && OrdersJason["orders_open"].HasKey(aTicketID))
       {
        jason_profit      = OrdersJason["orders_open"][aTicketID]["profit"].ToDbl();
        jason_volume      = OrdersJason["orders_open"][aTicketID]["volume"].ToDbl();
        jason_take_profit = OrdersJason["orders_open"][aTicketID]["take_profit"].ToDbl();
        jason_stop_loss   = OrdersJason["orders_open"][aTicketID]["stop_loss"].ToDbl();

        if(CompareDoubles(jason_take_profit, PositionGetDouble(POSITION_TP)) || CompareDoubles(jason_stop_loss, PositionGetDouble(POSITION_SL)) || (CompareDoubles(jason_volume, PositionGetDouble(POSITION_VOLUME))))
          state_meta += "PROFIT/SLTPLOT";
       }
    //------------------------------------------------- Save Order Infos into Array ORDERS Json
    orderJason["state_meta"] = state_meta;
    orderJason["comment"]    = PositionGetString(POSITION_COMMENT);
    
    if(OrdersJason["orders_open"].HasKey(aTicketID))
      OrdersJason["orders_open"].Remove(aTicketID);
    
    OrdersJason["orders_open"][aTicketID] = orderJason;

    orderJason.Clear();
   }
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateCloseOrders()
 {
  datetime currentTime = TimeCurrent();
  datetime daysAgo     = (currentTime / 86400 * 86400) - 10 * 86400;  
  int count_order      = 0;
  
  HistorySelect(0, currentTime);
  int total_orders     = HistoryDealsTotal();
  
  for(int orderindex = total_orders - 1; (orderindex >= 0 && count_order <=20); orderindex--)
   {
    count_order += 1;
    CJAVal orderJason;

    ulong deal_ticket      = HistoryDealGetTicket(orderindex);
    ulong deal_position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    datetime orderTime = datetime(HistoryDealGetInteger(deal_ticket, DEAL_TIME));
    ulong ticket_id = deal_position_id;
    
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    
    if(orderTime < daysAgo)
      break;
    if(entry_type == DEAL_ENTRY_IN)
      continue;

    string symbol        = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);  
    string aTicketId     = IntegerToString(ticket_id);

    ulong deal_ticket_in = FindDealInByTicketId(deal_position_id);

    long order_type      = HistoryDealGetInteger(deal_ticket_in, DEAL_TYPE);
    double price_open    = HistoryDealGetDouble(deal_ticket_in, DEAL_PRICE);
    double price_closed  = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    int symbol_digit = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    double vsl = HistoryDealGetDouble(deal_ticket, DEAL_SL);
    double vtp = HistoryDealGetDouble(deal_ticket, DEAL_TP);
    
    orderJason["symbol"]        = symbol;
    orderJason["ticket_id"]     = long(ticket_id);
    orderJason["ticket_deal"]   = HistoryDealGetInteger(deal_ticket, DEAL_TICKET);
    orderJason["type"]          = order_type;
    orderJason["price_open"]    = DoubleToString(price_open, symbol_digit);
    orderJason["price_closed"]  = DoubleToString(price_closed, symbol_digit);
    orderJason["volume"]        = DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_VOLUME), 2);
    orderJason["profit"]        = DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_PROFIT), 2);
    orderJason["fees"]          = DoubleToString(GetFeesOrderHistory(deal_ticket), 4);
    orderJason["stop_loss"]     = NormalizeNumber(vsl, symbol);
    orderJason["take_profit"]   = NormalizeNumber(vtp, symbol);
    // orderJason["stop_loss"]     = NormalizeDigits(price_open, vsl, order_type, symbol, "sl");
    // orderJason["take_profit"]   = NormalizeDigits(price_open, vtp, order_type, symbol, "tp");
    
    //orderJason["mae"]           = CalculateMFEMAE(symbol, ticket_id, "mae", OrdersJason["orders_open"][aTicketID]["mae"].ToDbl());
    //orderJason["mfe"]           = CalculateMFEMAE(symbol, ticket_id, "mfe", OrdersJason["orders_open"][aTicketID]["mfe"].ToDbl());
    //if(ArraySize(OrdersJason["orders_open"].children) > 0 && OrdersJason["orders_open"].type != jtUNDEF && OrdersJason["orders_open"].HasKey(aTicketId))
    // {
    //  OrdersJason["orders_open"][aTicketId]["mae"] = CalculateMFEMAE(symbol, ticket_id, "mae", OrdersJason["orders_open"][aTicketId]["mae"].ToDbl());
    //  OrdersJason["orders_open"][aTicketId]["mfe"] = CalculateMFEMAE(symbol, ticket_id, "mfe", OrdersJason["orders_open"][aTicketId]["mfe"].ToDbl());
    // }
    orderJason["open_at"]       = TimeToString(HistoryDealGetInteger(deal_ticket_in, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    orderJason["close_at"]      = TimeToString(HistoryDealGetInteger(deal_ticket, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    orderJason["time_gmt"]      = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    orderJason["time_trader"]   = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    orderJason["timezone"]      = long((TimeLocal() - TimeTradeServer()) / 3600);
    orderJason["symbol_digit"]  = symbol_digit;
    orderJason["magic_number"]  = HistoryDealGetInteger(deal_ticket_in, DEAL_MAGIC);
    orderJason["state_meta"]    = "";
    orderJason["comment"]       = HistoryDealGetString(deal_ticket_in, DEAL_COMMENT);
    //Print("Order Closed Ticket " + IntegerToString(ticket_id) + " : " + orderJason.Serialize());
    OrdersJason["orders_closed"][aTicketId] = orderJason;
    orderJason.Clear();
   }
 }

//+------------------------------------------------------------------+
//| UpdateCloseOrders                                                |
//+------------------------------------------------------------------+
void UpdateCloseOrderByTicketId(long ticket_id)
 {
  HistorySelect(0, TimeCurrent());
  datetime currentTime = TimeCurrent();
  datetime daysAgo     = (currentTime / 86400 * 86400) - 10 * 86400;
  int total_orders     = HistoryDealsTotal();
  int count_order      = 0;
  

    ulong deal_ticket      = FindDealOutByTicketId(ticket_id);
    ulong deal_position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    // ulong ticket_id = deal_position_id;
    
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    

    string symbol        = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);  
    string aTicketId     = IntegerToString(ticket_id);

    ulong deal_ticket_in = FindDealInByTicketId(deal_position_id);

    long order_type      = HistoryDealGetInteger(deal_ticket_in, DEAL_TYPE);
    double price_open    = HistoryDealGetDouble(deal_ticket_in, DEAL_PRICE);
    double price_closed  = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
    
    double vsl = HistoryDealGetDouble(deal_ticket, DEAL_SL);
    double vtp = HistoryDealGetDouble(deal_ticket, DEAL_TP);    

    int symbol_digit = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    
    OrdersJason["orders_closed"][aTicketId]["symbol"]        = symbol;
    OrdersJason["orders_closed"][aTicketId]["ticket_id"]     = long(ticket_id);
    OrdersJason["orders_closed"][aTicketId]["ticket_deal"]   = HistoryDealGetInteger(deal_ticket, DEAL_TICKET);
    OrdersJason["orders_closed"][aTicketId]["type"]          = order_type;
    OrdersJason["orders_closed"][aTicketId]["price_open"]    = DoubleToString(price_open, symbol_digit);
    OrdersJason["orders_closed"][aTicketId]["price_closed"]  = DoubleToString(price_closed, symbol_digit);
    OrdersJason["orders_closed"][aTicketId]["volume"]        = DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_VOLUME), 2);
    OrdersJason["orders_closed"][aTicketId]["profit"]        = DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_PROFIT), 2);
    OrdersJason["orders_closed"][aTicketId]["fees"]          = DoubleToString(GetFeesOrderHistory(deal_ticket), 4);
    OrdersJason["orders_closed"][aTicketId]["stop_loss"]     = NormalizeNumber(vsl, symbol);
    OrdersJason["orders_closed"][aTicketId]["take_profit"]   = NormalizeNumber(vtp, symbol);
    
    OrdersJason["orders_closed"][aTicketId]["open_at"]       = TimeToString(HistoryDealGetInteger(deal_ticket_in, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    OrdersJason["orders_closed"][aTicketId]["close_at"]      = TimeToString(HistoryDealGetInteger(deal_ticket, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    OrdersJason["orders_closed"][aTicketId]["time_gmt"]      = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    OrdersJason["orders_closed"][aTicketId]["time_trader"]   = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    OrdersJason["orders_closed"][aTicketId]["timezone"]      = long((TimeLocal() - TimeTradeServer()) / 3600);
    OrdersJason["orders_closed"][aTicketId]["symbol_digit"]  = symbol_digit;
    OrdersJason["orders_closed"][aTicketId]["magic_number"]  = HistoryDealGetInteger(deal_ticket_in, DEAL_MAGIC);
    OrdersJason["orders_closed"][aTicketId]["state_meta"]    = "";
    OrdersJason["orders_closed"][aTicketId]["comment"]       = HistoryDealGetString(deal_ticket_in, DEAL_COMMENT);
    //Print("Order Closed Ticket " + IntegerToString(ticket_id) + " : " + OrdersJason["orders_closed"][aTicketId].Serialize());
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
//| FindDealOutByTicketId                                            |
//+------------------------------------------------------------------+
long FindDealOutByTicketId(const ulong ticketid)
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
//| FindDealInByTicketId                                             |
//+------------------------------------------------------------------+
long FindDealInByTicketId(const ulong ticketid)
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
double NormalizeNumber(string snumber, string symbol)
{
  int    vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double number = MathAbs(NormalizeDouble(StringToDouble(snumber), vdigits));

  return number;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string NormalizeDigits(double vprice, double number, long vtype, string symbol, string kind)
 {
  string snumber;
  int vdigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
  double vpoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
// Verifique se 'number' é um número inteiro
  if(MathMod(number, 1.0) == 0.0 && number > 0.0)
   {
    // Ajusta vpoint de acordo com vdigits
    switch(vdigits)
     {
      case 1:
        vpoint = 0;
        break;     
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
      snumber = DoubleToString(NormalizeDouble(vprice - number * vpoint, vdigits), vdigits);
     }
    else
     {
      double mod = (kind == "tp") ? -1.0 : 1.0;
      snumber = DoubleToString(NormalizeDouble(vprice + number * mod * vpoint, vdigits), vdigits);
     }
   }
  return snumber;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+-----------------------------------------------------------------+
string NormalizeNumber(double number, string symbol)
{
  int    vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  string snumber = DoubleToString(number, vdigits);

  return snumber;
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
//| GetOrderProfit                                                   |
//+------------------------------------------------------------------+
double GetOrderProfit(long ticketid)
{
    long   deal_ticket = FindDealOutByTicketId(ticketid);
    int    tries  = 0;
    double profit = 0;

    while(tries < 50 && profit == 0){
      if(PositionSelectByTicket(ticketid))
        profit = PositionGetDouble(POSITION_PROFIT);
      else if(deal_ticket != INVALID_HANDLE)
        profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);             
      tries++; 
    }
    //Print("Sleep Tries Get Profit: " + (SleepTries * tries)); 
    Sleep(SleepTries * tries);
    return profit;
}

//+------------------------------------------------------------------+
//| Calculate MFE and MAE and send to API                            |
//+------------------------------------------------------------------+
void CalculateOrdersMFEMAE(){
  string mfe_mae_string;
  double profit          = 0;
  // int    totalOrders     = PositionsTotal();
  int    orders_size     = OrdersJason["orders_open"].Size();
  
  if(orders_size > 0){
    for(int i = 0; i < orders_size; i++ ){
      long ticket_id = OrdersJason["orders_open"][i]["ticket_id"].ToInt();
      // for(int orderindex = totalOrders - 1; orderindex >= 0; orderindex--){
      // ulong ticket_id = PositionGetTicket(orderindex);
      string aTicketID = IntegerToString(ticket_id);
      
      if(!OrdersJason["orders_open"].HasKey(aTicketID))
        continue;

      double value_mae = OrdersJason["orders_open"][aTicketID]["mae"].ToDbl();
      double value_mfe = OrdersJason["orders_open"][aTicketID]["mfe"].ToDbl();

      string symbol = OrdersJason["orders_open"][aTicketID]["symbol"].ToStr();
      OrdersJason["orders_open"][aTicketID]["mae"] = CalculateMFEMAE(symbol, ticket_id, "mae", value_mae);
      value_mfe  = OrdersJason["orders_open"][aTicketID]["mfe"].ToDbl();
      OrdersJason["orders_open"][aTicketID]["mfe"] = CalculateMFEMAE(symbol, ticket_id, "mfe", value_mfe);
      value_mae  = OrdersJason["orders_open"][aTicketID]["mae"].ToDbl();
      string mae_mfe = "\nTicket ID:" + IntegerToString(ticket_id) + "\nMax MFE: " + DoubleToString(value_mfe, 2) + " \nMax MAE: " + DoubleToString(value_mae, 2);
      StringConcatenate(mfe_mae_string, (mae_mfe + "\n"), mfe_mae_string);
    }
    comment_mfe_mae_line_item = AddCommentOnChart(mfe_mae_string, 4);
  }
}

//+------------------------------------------------------------------+
//| Calculate MFE and MAE and send to API                            |
//+------------------------------------------------------------------+
string CalculateMFEMAE(string symbol, long ticketid, string type, double value)
 {
  double profit    = 0;
  int totalOrders  = ArraySize(orders);

  profit = GetOrderProfit(ticketid);
  if(type == "mfe" && profit > 0)
   {
    if(profit > value)
      value = profit;
   }
  else
    if(type == "mae" && profit < 0)
     {
      if(profit < value)
        value = profit;
     }
  return DoubleToString(value, 2);
 }

//+------------------------------------------------------------------+
//| SendMessageToServer                                              |
//+------------------------------------------------------------------+
void SendMessageToServer(const MqlTradeResult &result, const MqlTradeRequest &request, const MqlTradeTransaction& trans, string const action, const string fuction_name)
 {
  ulong ticket_id = request.position > 0 ? request.position : result.order;
  string aTicketID = IntegerToString(ticket_id);
  int symbol_digit = int(SymbolInfoInteger(request.symbol, SYMBOL_DIGITS));
  string value_mae = "0.00";
  string value_mfe = "0.00";
  
  string sprofit = DoubleToString(GetOrderProfit(ticket_id),2);

  if(OrdersJason["orders_open"].HasKey(aTicketID)){    
    value_mae = DoubleToString(OrdersJason["orders_open"][aTicketID]["mae"].ToDbl(), 2);
    value_mfe = DoubleToString(OrdersJason["orders_open"][aTicketID]["mfe"].ToDbl(), 2);
  }else if(OrdersJason["orders_closed"].HasKey(aTicketID)){
    value_mae = DoubleToString(OrdersJason["orders_closed"][aTicketID]["mae"].ToDbl(), 2);
    value_mfe = DoubleToString(OrdersJason["orders_closed"][aTicketID]["mfe"].ToDbl(), 2);
  }
  
  string meta_message = StringFormat("%s - Symbol: %s - Type: %d - Ticket: %d - TicketDeal: %d - Volume: %s - TP: %s - SL: %s - ", ToUpper(fuction_name), request.symbol, request.type, ticket_id, result.deal, DoubleToString(result.volume,2), DoubleToString(request.sl, symbol_digit), DoubleToString(request.sl, symbol_digit));
  string meta_mfemae  = StringFormat("%s - Symbol: %s - MFE: %s - MAE: %s - Profit: %s", ToUpper(fuction_name), request.symbol, value_mfe, value_mae, sprofit);
  
  string log_message = StringFormat("Log Info - LastError: %d - Retcode: %u - ResultComment: %s", GetLastError(), result.retcode, result.comment);        
  
  Print(meta_message);
  Print(meta_mfemae);
  Print(log_message);
  
  AddCommentOnChart(meta_message);
  AddCommentOnChart(meta_mfemae);
  AddCommentOnChart(log_message);

  PushOrders();
 }
//+------------------------------------------------------------------+
//| ShowCommentOnChart                                                  |
//+------------------------------------------------------------------+
long ShowCommentOnChart()
 {
  long line_item = 0;
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