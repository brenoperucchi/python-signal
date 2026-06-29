//+------------------------------------------------------------------+
#define VERSION        "3.00"
#define VERSION_UPDATE "03"
#define VERSION_LOCAL  "03"

#define APPNAME        "Imentore Copy"
#define APPVERSION     "3.00"

#define EXPERTNAME     "imentore_copy" 
#define EXPERTKIND    "copy"

#property copyright   "Update "+ VERSION_UPDATE +" - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

//+-Includes--------------------------------------------------------------------+
#include <Trade\DealInfo.mqh>
#include <Trade\TradeImentore.mqh>

#include <ImentoreLib.mqh>
#include <ImentoreSettings.mqh>

//+--Objects--------------------------------------------------------------------+
CTrade trade;  // Instance of CTrade
Settings* AppSettings = Settings::Instance();


//+-Input-----------------------------------------------------------------------+
input bool   InputEnvironmentLocal               = true; // Admin only (default: false)
bool   iOrderPendingModifySendChange       = true;  // Send Change Order Pending to Server (default: true)
long   Slippage                            = 30;           // Spread for price   
ulong  MaxSeconds                          = 30;           // Time Max Operation - limit for waiting open a order (default is 30)
bool   EnvironmentLocal                    = false;        // EnvironmentLocal - Admin only (default is false)

//+-Current------------------------------------------------------------------------+ 
double   maxDayMFE                         = 0;
double   maxDayMAE                         = 0;

ulong TimeMilliseconds  = 0;
//ulong TimeMilleSecondsOnTimer  = 0;
int   TimeTransaction   = 0;

//+-Tester--------------------------------------------------------------------------+
int      NewCandleCount;
long     TransactionCounter;

ulong    TicketIdTester;
datetime lastCandleTime;

//+-Enum__--------------------------------------------------------------------------+
enum ENUM_INFORMATION_OUTPUT
 {
  experts_tab = 0,  // The "Experts" tab
  txt_file    = 1,  // The text file
 };

datetime                from_date   = D'2017.08.07 11:06:20';  // From date
datetime                to_date     = __DATE__ + 60 * 60 * 24; // To date
ENUM_INFORMATION_OUTPUT InpOutput   = experts_tab;                // Information output

//+------------------------------------------------------------------+
// Inits                                                             |
//+------------------------------------------------------------------+
int OnInit(){  

  AppSettings.appName               = APPNAME;
  AppSettings.appVersion            = APPVERSION;
  AppSettings.appVersionLocal       = VERSION_LOCAL;
  AppSettings.appVersionUpdate      = VERSION_UPDATE;        
  AppSettings.appExpertKind         = EXPERTKIND;
  AppSettings.appExpertName         = EXPERTNAME;
  AppSettings.appMilliSecondsTimer  = 2000;
  AppSettings.appMilliSecondsTicker = 2000; 
  AppSettings.appMilliSecondsDelay  = 550; 
  AppSettings.appMaxSeconds         = 30;
  AppSettings.appSlipPage           = 30;
  AppSettings.apiVersion            = "v3";
  AppSettings.appEventOnTick        = true;
  AppSettings.appEventOnTimer       = true;
  AppSettings.InputEnvironmentLocal = InputEnvironmentLocal;
  AppSettings.appEnvironmentLocal   = InputEnvironmentLocal;
  
  EventSetMillisecondTimer(500);
  
  SetLogFileName();
  SetCommentImentore(true, true);
  
  AddCommentOnChart(AppSettings.accountName + " - " + AppSettings.accountLogin + " - " + AppSettings.accountServerName + " - " + AccountMarginMode() + " - " + ((AppSettings.appEnvironmentLocal || AppSettings.InputEnvironmentLocal) ? "Local" : "Produção"), 3);
  
  if (DetectEnvironment() == false){
    AddCommentOnChart("Expert " + StringToCameCase(AppSettings.appExpertName) + " não inicializado. Contacte o SUPORTE.", 4);
    return (INIT_FAILED);
  } else {
    AddCommentOnChart("Expert " + StringToCameCase(AppSettings.appExpertName) + " inicializado com SUCESSO", 4);        
   
    TrasmitOrders();
    TimeMilliseconds = GetTickCount64();

    return (INIT_SUCCEEDED);    
  }
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason){
  EventsOnDeinit();
  delete AppSettings;
  return;
}

//+------------------------------------------------------------------+
void OnTimer(){
  //int TimeAgoTransaction = int(TimeCurrent() - TimeTransaction) * 1000;
  
//  ulong currentMilleSeconds = GetTickCount64() - TimeMilleSecondsOnTimer;
//  
//  if(TransactionCounter >= 2 && currentMilleSeconds >= 850){
//    TrasmitOrders();
//    Print("OnTimer - currentMilleSeconds => ", currentMilleSeconds, " - TransactionCounter => ", TransactionCounter);  
//    //if(TransactionCounter >= 2)
//    //  DebugBreak();
//    TransactionCounter = 0;
//    TimeMilleSecondsOnTimer = GetTickCount64();
//  }
  
  ShouldTransmitOrders(); // Threshold de 750 ms
      
  if(AppSettings.appEventOnTimer){
    CalculateOrdersMFEMAE();
    CheckOrdersOpenHasClosed();      
    CheckFreeze();
    SetLogFileName();
    
    if(DebugMode && DebugModeLevel > 2){
      string message = ("OnTimer - " + TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));
      Print(message);
      SaveLogToFile(message);
    }
  }

  if(DebugMode)
    SendLogFileToServer();

  if(!CheckServerInformations())
    ExpertRemove();
  
  ExecuteEvents();
}

//+------------------------------------------------------------------+
void OnTick(){ 
  CheckAnotherDay();

//  //int timeAgo1 = int(TimeLocal() - TimeCurrentLocal);  
//  ulong currentMilleSeconds = GetTickCount64() - TimeMilleSeconds;
//    
//  if(TransactionCounter >= 2 && currentMilleSeconds >= 750){
//    TrasmitOrders();
//    Print("Ontick - currentMilleSeconds => ", currentMilleSeconds, " - TransactionCounter => ", TransactionCounter);  
//    //if(TransactionCounter >= 2)
//    //  DebugBreak();
//    TransactionCounter = 0;
//    //TimeMilleSecondsOnTimer = GetTickCount64();
//  }

  ShouldTransmitOrders(); // Threshold de 850 ms
  
  if(AppSettings.appEventOnTick && (GetElapsedMilliseconds() >= ulong(AppSettings.appMilliSecondsTicker))){
    //TimeCurrentTick = int(TimeLocal());
    TimeMilliseconds = GetTickCount64();

    if(DebugMode){
      SendLogFileToServer();

      if(DebugModeLevel  > 2){
        string message = ("OnTick - " + TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));
        Print(message);
        SaveLogToFile(message);
      }
    }
    
    if(!CheckServerInformations())
      ExpertRemove();
    
    ExecuteEvents();
    CalculateOrdersMFEMAE();
    CheckOrdersOpenHasClosed();
    CheckFreeze();
    SetLogFileName();
  }

  ResetLastError();
  datetime currentNextDay = TimeLocal() - TimeLocal() % 86400;    
  
  //+ Tester
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
    }
  }
}

//+------------------------------------------------------------------+
// OnTradeTransaction / SendMessageToServer / ExecuteEvents          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result){
  HistorySelect(0, TimeCurrent());

  ENUM_TRADE_TRANSACTION_TYPE transaction_type = trans.type;
  
  if(transaction_type == TRADE_TRANSACTION_REQUEST || transaction_type == TRADE_TRANSACTION_DEAL_ADD){    
    ulong ticket_id = 0; 
    ulong deal_ticket = 0;
   
    if(trans.deal > 0)
      deal_ticket = trans.deal; 
    else if(result.deal > 0)
      deal_ticket = result.deal;

    if(trans.order > 0)
      ticket_id = trans.order;
    else if(request.order > 0)
      ticket_id = request.order;

    ENUM_DEAL_TYPE  deal_type  = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
    ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    string action         = (deal_entry != DEAL_ENTRY_IN) ? "CLOSE" : "OPEN";    
    
    if(!iOrderPendingModifySendChange)
      if(OrderSelect(ticket_id))
        return;
        
    bool positionChange = CompareAndSendChanges(PositionOrders, request.position, request.price, request.sl, request.tp, request.volume);
    bool pendingChange = CompareAndSendChanges(PendingOrders, request.order, request.price, request.sl, request.tp, request.volume);
        
    long totalPosition = PositionsTotal();
    long totalHistory  = HistoryDealsTotal() -1;
    long totalPending  = OrdersTotal();
    
    long arrayPosition = ArraySize(PositionOrders);
    long arrayHistory  = ArraySize(HistoryOrders);
    long arrayPending  = ArraySize(PendingOrders);
    
    //if(FindOrdersPositionByPositionIDIndex(ticket_id) < 0)
    if(totalPosition != arrayPosition || totalHistory != arrayHistory || totalPending != arrayPending || positionChange || pendingChange)
      SendMessageToServer(result, request, trans, action, "OnTradeTransaction");   

     // Incrementa o contador de transações
     TransactionCounter += 1;
     // Se for a primeira transação, inicia o tempo de referência
     if(TransactionCounter == 1)
        TimeMilliseconds = GetTickCount64();      
  }
}

//+------------------------------------------------------------------+
void SendMessageToServer(const MqlTradeResult &result, const MqlTradeRequest &request, const MqlTradeTransaction& trans, string const action, const string fuction_name){
  int digit = int(SymbolInfoInteger(request.symbol, SYMBOL_DIGITS));
  ulong ticket_id = request.position > 0 ? request.position : result.order;
  string metaMessage, metaMfeMae, logMessage;
  double orderSL, orderTP,orderMfe, orderMae, orderVolume;
  long orderType;
  
  string sprofit = DoubleToString(GetOrderProfitByTicketID(ticket_id), 2);
  long index = FindOrdersPositionByPositionIDIndex(ticket_id);
  
  OrderStruct order;
  if(index >= 0)
    order = PositionOrders[index];  
  
  
  if(action == "CLOSE"){
    orderSL    = order.stopLoss;
    orderTP     = order.takeProfit;
    orderType   = order.type;
    orderMfe    = order.mfe;
    orderMae    = order.mae; 
    orderVolume = order.volume;   
    
  } else {
    orderSL     = request.sl;
    orderTP     = request.tp;
    orderType   = request.type;
    orderMfe    = order.mfe;
    orderMae    = order.mae;
    orderVolume = request.volume;
  }
  
  if(ticket_id >0){
    metaMessage = StringFormat("#%d - %s - Symbol: %s - Type: %d - TicketDeal: %d - Volume: %s - TP: %s - SL: %s", ticket_id, fuction_name, request.symbol, orderType, result.deal, DoubleToString(orderVolume, 2), DoubleToString(orderTP, digit), DoubleToString(orderSL, digit));
    if(action == "CLOSE")
      metaMfeMae  = StringFormat("#%d - %s - Symbol: %s - MFE: %s - MAE: %s - Profit: %s", ticket_id, fuction_name, request.symbol, DoubleToString(orderMfe, 2), DoubleToString(orderMae, 2), sprofit);
  
    logMessage = StringFormat("#%d - Log Info - LastError: %d - Retcode: %u - ResultComment: %s", ticket_id, GetLastError(), result.retcode, result.comment);        
  
    AddCommentOnChart(metaMessage);
    if(action == "CLOSE")
      AddCommentOnChart(metaMfeMae);
    AddCommentOnChart(logMessage);
  }
  //if(TransactionCounter == 0)
  //  TimeMilleSeconds = GetTickCount64();
  //TransactionCounter +=1;  
  //if(TrasmitOrders()){
  //  UpdatePositionOrders();
  //}
 }


//+------------------------------------------------------------------+
void ExecuteEvents(){
  if(LibSettings.appSendOrdersHistory){
    if(TrasmitOrders()){
      AddCommentOnChart("CheckAnotherDay - Send History Orders");      
    }
  }
}

//+------------------------------------------------------------------+
// CheckOrdersOpenHasClosed / CompareAndSendChanges                  |
//+------------------------------------------------------------------+
void CheckOrdersOpenHasClosed(){
  //long orders_size = ["orders_open"].Size();

  for(int i = 0; i < ArraySize(PositionOrders); i++ ){
    //OrderObj *order = (OrderObj *)PositionOrders.At(i);
    
    ulong ticket_id = ticketID(PositionOrders[i]);
    
    //if(FindCloseOrderByPositionId(ticket_id) && !PositionSelectByTicket(ticket_id)){
    if(FindOrdersHistoryByPositionIdBool(PositionOrders[i].positionID) && !PositionSelectByTicket(ticket_id)){    
      //RemoveOrderJason(ticket_id);
      TrasmitOrders();
      AddCommentOnChart("#"+ IntegerToString(ticket_id) + " - CheckOrdersOpenHasClosed: " + IntegerToString(ticket_id));
    }
  }
}

//+------------------------------------------------------------------+
bool CompareAndSendChanges(OrderStruct &orders[], long ticketID, double price, double sl, double tp, double volume) { 
  if(ticketID <= 0)
    return false;
 
  long order_index = FindOrdersStructIndex(orders, ticketID);
    
  if(order_index < 0)
    return false;
      
  if (orders[order_index].ticketMaster == ticketID) {
    // Comparar os valores do trans com os da OrderStruct
    bool volume_changed = CompareDoubles(volume, orders[order_index].volume);
    bool price_changed = CompareDoubles(price, orders[order_index].priceOpen);
    bool sl_changed = CompareDoubles(sl, orders[order_index].stopLoss);
    bool tp_changed = CompareDoubles(tp, orders[order_index].takeProfit);

    if (volume_changed || price_changed || sl_changed || tp_changed) {
      return true;
    }    
  }
  return false;
}

//+------------------------------------------------------------------+
// Others                                                            |
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
ulong GetElapsedMilliseconds(){
   return GetTickCount64() - TimeMilliseconds;
}

//+------------------------------------------------------------------+
string NormalizeDigits(double vprice, double number, long vtype, string symbol, string kind){
  string snumber;
  int vdigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
  double vpoint = SymbolInfoDouble(symbol, SYMBOL_POINT);

  if(MathMod(number, 1.0) == 0.0 && number > 0.0){
    switch(vdigits){
      case 1:
        vpoint = 0;
        break;     
      case 2:
        vpoint = 0.1;
        break;
      case 3:
        vpoint = 0.01;
        break;
      default:
        vpoint = 0.0001;
        break;
     }
    // Verifica se vtype é par (0, 2, 4, 6, etc.)
    if(vtype % 2 == 0)
      snumber = DoubleToString(NormalizeDouble(vprice - number * vpoint, vdigits), vdigits);
    else {
      double mod = (kind == "tp") ? -1.0 : 1.0;
      snumber = DoubleToString(NormalizeDouble(vprice + number * mod * vpoint, vdigits), vdigits);
    }
  }
  return snumber;
}

//+-----------------------------------------------------------------+
string NormalizeNumber(double number, string symbol){
  int    vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  string snumber = DoubleToString(number, vdigits);
  return snumber;
}
///+------------------------------------------------------------------+
void OutputTest(const string text) {
  if(InpOutput == txt_file)
    FileWriteString(file_handle_out, text + "\r\n");
  else
    Print(text);
 }

 //+------------------------------------------------------------------+
bool ShouldTransmitOrders(){
   ulong elapsedMilliseconds = GetElapsedMilliseconds();
   if(TransactionCounter >= 1 && elapsedMilliseconds >= ulong(AppSettings.appMilliSecondsDelay))
   {
      TrasmitOrders();
      Print("Transmit Orders - elapsedMilliseconds => ", elapsedMilliseconds, " - TransactionCounter => ", TransactionCounter);
      TransactionCounter = 0;
      TimeMilliseconds = GetTickCount64();
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
string ToUpper(string str) {
  if(StringToUpper(str))
    return str;
  else {
    Print("Falha ao converter a string para maiúsculas.");
    return str;
   }
 }

 ///+------------------------------------------------------------------+