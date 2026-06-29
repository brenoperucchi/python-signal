//+------------------------------------------------------------------+
#define VERSION "3.00"
#define VERSION_UPDATE "03"
#define VERSION_LOCAL "05"

#define APPNAME "Imentore Slave"
#define APPVERSION "3.00"

#define EXPERTNAME "imentore_slave"
#define EXPERTKIND "slave"

#property copyright "Update " + VERSION_UPDATE + " - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict


//+-Includes--------------------------------------------------------------------+
#include <Trade/TradeImentore.mqh>
#include <Trade/TerminalInfo.mqh>
#include <ImentoreLib.mqh>
#include <ImentoreSettings.mqh>

//+--Objects--------------------------------------------------------------------+
CTrade trade;
CTerminalInfo cterminal;
Settings* AppSettings = Settings::Instance();

//+-Input-----------------------------------------------------------------------+
bool InputEnvironmentLocal         = false; // Admin only (default: false)
bool iOrderPendingModifySendChange = true;  // Send Change Order Pending to Server (default: true)

//+--Globales Order--------------------------------------------------------------+
bool order_allowopen          = true;
bool order_allowclose         = true;
bool order_allowmodify        = true;
bool order_invert             = false;
double account_minmarginfree  = 0.00;

bool TicketOpen;
bool TicketClosed;
bool TicketPending;
bool TicketPendingHistory;
bool TicketPositionOrders;
bool TicketHistoryOrders;

int   SleepTimer        = 2;
ulong TimeMilleSeconds  = 0;
int   TimeCurrentLocal  = int(TimeLocal());


const string DEFAULT_TIME = "1970.01.01 00:00:00";
datetime OrdersHistoryStart, OrdersHistoryEnd;

//+------------------------------------------------------------------+
//|Initialization On's functions                                     |
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
  AppSettings.appMaxSeconds         = 30;
  AppSettings.appSlipPage           = 30;
  AppSettings.appMilliSecondsDelay  = 550; 
  AppSettings.apiVersion            = "v3";
  AppSettings.appEventOnTick        = true;
  AppSettings.appEventOnTimer       = true;
  AppSettings.InputEnvironmentLocal = InputEnvironmentLocal;
  AppSettings.appEnvironmentLocal   = InputEnvironmentLocal;
  
  EventSetMillisecondTimer(AppSettings.appMilliSecondsTimer);
  
  SetLogFileName();
  SetCommentImentore(true, true);
  
  AddCommentOnChart(AppSettings.accountName + " - " + AppSettings.accountLogin + " - " + AppSettings.accountServerName + " - " + AccountMarginMode() + " - " + ((AppSettings.appEnvironmentLocal || InputEnvironmentLocal) ? "Local" : "Produção"), 3);
  
  if (DetectEnvironment() == false){
    AddCommentOnChart("Expert " + StringToCameCase(AppSettings.appExpertName) + " não inicializado. Contacte o SUPORTE.", 4);
    return (INIT_FAILED);
  } else {
    AddCommentOnChart("Expert " + StringToCameCase(AppSettings.appExpertName) + " inicializado com SUCESSO", 4);    
    TrasmitOrders();
    UpdatePositionOrders();
    UpdatePendingOrders();
    UpdateHistoryOrders();
    
    TimeMilleSeconds = GetTickCount64();
                 
    return (INIT_SUCCEEDED);    
  }
}

//+------------------------------------------------------------------+
void OnTick(){
  ExecuteEvents();     // Periodically check if OrdersStruct is up-to-date  
  
  int timeAgo1 = int(TimeLocal() - TimeCurrentLocal);

  if (timeAgo1 >= 3600){
    CheckTimeDiscrepancy();
    TimeCurrentLocal = int(TimeLocal());
  }
  
  ulong currentMilleSeconds = GetTickCount64() - TimeMilleSeconds;
  
  if(AppSettings.appEventOnTick && (currentMilleSeconds >= ulong(AppSettings.appMilliSecondsTicker))){    
    //Print("appMilliSecondsTicker => ", ulong(AppSettings.appMilliSecondsTicker));
    //Print("CurrentMilleSeconds => ", currentMilleSeconds);
    TimeMilleSeconds = GetTickCount64();

    if (DebugMode){
      SendLogFileToServer();
      if (DebugModeLevel > 2){
        string message = ("OnTick - " + TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));
        Print(message);
        SaveLogToFile(message);
      }
    }
    if (!CheckServerInformations())
      ExpertRemove();

    ExecuteOrders();
    CheckFreeze();
  }
}

//+------------------------------------------------------------------+
void OnTimer(){
  ExecuteEvents();  
  
  if (AppSettings.appEventOnTimer){    
    CheckFreeze();
    SetLogFileName();

    if (DebugMode && DebugModeLevel > 2){
      string message = ("OnTimer - " + TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));
      Print(message);
      SaveLogToFile(message);
    }
  }
  if (DebugMode)
    SendLogFileToServer();
  if (!CheckServerInformations())
    ExpertRemove();
  
  ExecuteOrders();
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason){
  EventsOnDeinit();
  return;
}

//+------------------------------------------------------------------+
//+ Executes                                                         +
//+------------------------------------------------------------------+
void ExecuteOrders(){  
  TrasmitOrders();
  UpdatePositionOrders();

  int orders_size = ArraySize(PositionOrders);
  
  for (int i = 0; i < orders_size; i++){        
    if (PositionOrders[i].state == "pending")
      MakeOrder(PositionOrders[i], "OPEN");
    else if (PositionOrders[i].state == "executed")
      MakeOrder(PositionOrders[i], "MODIFY");
    else if (PositionOrders[i].state == "remove")
      MakeOrder(PositionOrders[i], "CLOSED");
  }
}

//+------------------------------------------------------------------+
void ExecuteEvents(){
  datetime now       = TimeCurrent();
  datetime last60sds = 0;
  datetime last02sds = 0;
      
  UpdateHistoryOrders();
  UpdatePendingOrders();
  //UpdatePositionOrders();

  CheckOrdersClosed();
  CheckOrdersDuplicate();  
  CheckAnotherDay();
  MfeTargetLossCheck();
  CalculateOrdersMFEMAE();  
  SetCommentImentore();
  
  if (now - last02sds > 02){
    SetLogFileName();
    last02sds = now;
  }

  if (now - last60sds > 60){
    HistorySelect(0, TimeCurrent());
    last60sds = now;  
  }
  
  // check should close all positions
  if (AppSettings.ReachLossSetBool() || AppSettings.ReachMfeTargetBool())
    CloseAllOrdersStruct(PositionOrders);

  if(DebugMode && CloseAllOrders)
    CloseAllPositionOrders();      
}

//+------------------------------------------------------------------+
//+ Makes                                                            +
//+------------------------------------------------------------------+
bool MakeOrderPreCheck(OrderStruct &order){
  bool change = true;
  long idxHistoryDealIn = FindOrdersHistoryByCommentIndex(order.comment, DEAL_ENTRY_IN);    

  if(order.ticketSlave <= 0 && order.type >= 2)
    order.ticketSlave = FindPendingOrderByComment(order.comment);
                          
  if(order.ticketSlave <= 0 || !PositionSelectByTicket(order.ticketSlave)){
    if(OrderSelect(order.ticketSlave)){
      long ticketPendingID = FindPendingOrderByComment(order.comment);
      if(order.ticketSlave != ticketPendingID)
        order.ticketSlave = ticketPendingID;
    } else
      order.ticketSlave = FindOpenOrderByComment(order.comment);    
    if(order.ticketSlave <= 0)
      order.ticketSlave = FindOrdersHistoryByPositionIdLong(order.positionID);
    if (order.ticketSlave <= 0){      
      if(idxHistoryDealIn != -1)
        order.ticketSlave = HistoryOrders[idxHistoryDealIn].ticketSlave;
    }
  }
  
  if(order.ticketSlave >= 0 && order.positionID != order.ticketSlave)
    order.positionID = order.ticketSlave;  
    
  if(StringLen(order.comment) > 0 && order.ticketMaster != long(order.comment))
    order.ticketMaster = long(order.comment);
    
  if(idxHistoryDealIn != -1 && order.ticketSlave != HistoryOrders[idxHistoryDealIn].ticketSlave){
    long idxHistoryDealOut = FindOrdersHistoryByPositionIDIndex(HistoryOrders[idxHistoryDealIn].positionID, DEAL_ENTRY_OUT);
    if(idxHistoryDealOut == -1)
      order.ticketSlave = HistoryOrders[idxHistoryDealIn].ticketSlave;
  }
  
  if (order_allowmodify == false || order.symbol == "")
    change = false;

  if (!cterminal.IsConnected() || cterminal.IsTradeAllowed() == false){
    AddCommentOnChart("Conexão com o servidor perdida. Por favor, verifique a conexão com a internet.");
    SymbolSelect(order.symbol, false);
    change = false;
  }    
  
  return change;
}

//+------------------------------------------------------------------+
bool MakeOrder(OrderStruct &order, const string action){
  bool change          = false;    
  order.metaAction     = action;
  
  if(MakeOrderPreCheck(order) == false)
    return change;
         
  TicketOpen           = PositionSelectByTicket(order.ticketSlave);  
  TicketPending        = OrderSelect(order.ticketSlave);
  TicketPendingHistory = HistoryOrderSelect(order.ticketSlave);    
  TicketHistoryOrders  = FindOrdersHistoryByPositionIdBool(order.ticketSlave);
  TicketPositionOrders = FindOrdersPositionByPositionIDBool(order.ticketSlave);

  MqlTradeResult mqlResult = {};
  MqlTradeRequest mqlRequest = {};
  ZeroMemory(mqlResult);
  ZeroMemory(mqlRequest);  
  ResetLastError();

  if (action == "OPEN"){
    change = MakeOrderOpen(mqlResult, mqlRequest, order, action);
  } else if (action == "CLOSED"){
    change = MakeOrderClose(mqlResult, mqlRequest, order, action);
  } else if (action == "MODIFY"){
    change = MakeOrderModify(mqlResult, mqlRequest, order, action);
  }
   
  return change;
}

//+------------------------------------------------------------------+
bool MakeOrderClose(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action){  
  bool change = false;
  
  if (order_allowclose == false) // || order.ticketSlave <= 0)
    return change;      

  request.position  = order.ticketSlave;      // ticket of the position
  request.symbol    = order.symbol;           // symbol
  request.volume    = order.volume;           // volume of the position
  request.deviation = order.slipPage;         // allowed deviation from the price
  request.comment   = order.comment;
  request.magic     = order.magicNumber;
  
  if(TicketPending && !TicketPendingHistory){
    change = trade.OrderDelete(order.ticketSlave);       
    
    if(change){
      result.retcode    = 10009;
      order.metaState   = "CLOSED";
      order.metaMessage = "Order Closed";
    } else{
      result.retcode    = 94017;
      order.metaState   = "NOTCLOSED";
      order.metaMessage = "Order Not Closed";
    }
  } else{
    if (!TicketOpen && !TicketClosed && !TicketPending && !TicketPendingHistory){
      result.retcode    = 94016;
      order.metaMessage = "Order Not Find";
      order.metaState   = "NOTFIND";
      change            = false;
    } else if ((TicketPendingHistory || TicketClosed) && !TicketOpen){      
      result.retcode    = 90013;
      order.metaMessage = "Order Has Closed";
      order.metaState   = "HASCLOSED";
      change            = false;
    } else if(action == "MODIFY_VOLUME"){      
      change = trade.PositionClosePartial(order.ticketSlave, order.volume);
      
      if(change)
        order.metaState = action;
    } else {
      change = trade.PositionClose(order.ticketSlave);
      
      if (change){
        result.retcode    = 10009;
        order.metaMessage = "Order Closed";              
        order.metaState   = "CLOSED";                 
      } else {
        result.retcode    = 94017;
        order.metaMessage = "Order Not Closed";
        order.metaState   = "NOTCLOSED";       
      }
    }     
    
    if(result.deal > 0)
      order.ticketDeal = long(result.deal);
    if(result.price > 0)
      order.priceClose = result.price;
    
    if(order.metaState == "CLOSED")
      CalculateOrdersMFEMAE();
      
    if (order.metaState == "CLOSED" || order.metaState == "HASCLOSED"){      
      UpdateOrderInfo(order, action);
      
      if (order.priceOpen <= 0.0)
        order.priceOpen = GetOrderPriceOpen(order);
  
      if (order.priceClose <= 0.00)
        order.priceClose = GetOrderPriceClose(order);
  
      if (order.openAt == DEFAULT_TIME || StringLen(order.openAt) == 0)
        order.openAt = GetOrderOpenAt(order);    
    }           
  }
    
  if(MfeTargetLossCheck()){
    order.metaMessage = MfeTargetLossCheckOrder(order);
    AddCommentOnChart(order.metaMessage);
  }  
  
  SendMessageToServer(result, request, order, "MakeOrderClose");
  return change;
}

//+------------------------------------------------------------------+
bool MakeOrderModify(MqlTradeResult &result, MqlTradeRequest &request,
                     OrderStruct &order, string action) {
  string comment_modify_stop_loss, comment_modify_take_profit, comment_modify_volume, comment_modify_priceOpen;

  bool change       = false;
  int  symbol_digit = (int)SymbolInfoInteger(order.symbol, SYMBOL_DIGITS);
  bool orderchanged = false;
  
  TicketOpen           = PositionSelectByTicket(order.ticketSlave);
  TicketPending        = OrderSelect(order.ticketSlave);
  
  if(!TicketOpen && !TicketPending && TicketClosed)
    return orderchanged;
      
  if (PositionSelectByTicket(order.ticketSlave)){  // Market orders
    bool position = PositionSelectByTicket(order.ticketSlave);
    
    if(order.priceOpen == 0)
      order.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
          
    if ((TicketOpen) && iOrderPendingModifySendChange) {
      
      double lot = NormalizeVolume(order.symbol, order.volume, order.contractVolume);
      double symbol_volume = SymbolInfoDouble(order.symbol, SYMBOL_VOLUME_MIN);
      
      if(order.contractVolume == 0){
        if(UpdateOrderAttribute(PositionGetDouble(POSITION_VOLUME), order.volume, "volume", comment_modify_volume, order.comment, order.ticketSlave, order.symbol))
          change = OrderModifyVolume(result, request, order, "MODIFY_VOLUME");
      }
    
      orderchanged |= UpdateOrderAttribute(PositionGetDouble(POSITION_SL), order.stopLoss, "stop_loss", comment_modify_stop_loss, order.comment, order.ticketSlave, order.symbol);
      orderchanged |= UpdateOrderAttribute(PositionGetDouble(POSITION_TP), order.takeProfit, "take_profit", comment_modify_take_profit, order.comment, order.ticketSlave, order.symbol);

      if (orderchanged) {
          order.stopLoss = CalculatePips(PositionGetDouble(POSITION_PRICE_OPEN), DoubleToString(order.stopLoss, symbol_digit), order.type, order.symbol);
          order.takeProfit = CalculatePips(PositionGetDouble(POSITION_PRICE_OPEN), DoubleToString(order.takeProfit, symbol_digit), order.type, order.symbol);          
      }
    }
  }   
  if (OrderSelect(order.ticketSlave)) {  // Pending orders
    if(order.priceOpen == 0)
      order.priceOpen = OrderGetDouble(ORDER_PRICE_OPEN);   

    if (OrderSelect(order.ticketSlave)) {
      orderchanged |= UpdateOrderAttribute(OrderGetDouble(ORDER_PRICE_OPEN), order.priceOpen, "price_open", comment_modify_priceOpen, order.comment, order.ticketSlave, order.symbol);
      orderchanged |= UpdateOrderAttribute(OrderGetDouble(ORDER_SL), order.stopLoss, "stop_loss", comment_modify_stop_loss, order.comment, order.ticketSlave, order.symbol);
      orderchanged |= UpdateOrderAttribute(OrderGetDouble(ORDER_TP), order.takeProfit, "take_profit", comment_modify_take_profit, order.comment, order.ticketSlave, order.symbol);
    } 
  }
  
  if(orderchanged)
    change = OrderModify(result, request, order, "MODIFY");

  if (order.type <= 1 && !TicketPositionOrders && TicketHistoryOrders && order.state == "executed")
      MakeOrder(order, "CLOSED");

  return change;
}

//+------------------------------------------------------------------+
bool MakeOrderOpen(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action){
  bool   change = false;
  string symbol = order.symbol;

  if (order_allowopen == false || order.symbol == "")
    return change;

  if (cterminal.IsTradeAllowed() == false)
    return change;

  if (account_minmarginfree > 0.00 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < account_minmarginfree)
    return change;

  double vprice = order.priceOpen;
  double vsl = order.stopLoss;
  double vtp = order.takeProfit;
  double vlots = NormalizeVolume(order.symbol, order.volume, order.contractVolume);
  long vtype = order.type;

  if (vprice <= 0.00){
    MqlTick last_tick;
    SymbolInfoTick(symbol, last_tick);
    if (vtype == 0)
      vprice = SymbolInfoDouble(symbol, SYMBOL_ASK);
    if (vtype == 1)
      vprice = SymbolInfoDouble(symbol, SYMBOL_BID);
  }

  double sl = CalculatePips(vprice, DoubleToString(vsl, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);
  double tp = CalculatePips(vprice, DoubleToString(vtp, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);

  if (order_invert){
    switch (int(vtype)){
    case 0:
      vtype = 1;
      break;
    case 1:
      vtype = 2;
      break;
    case 2:
      vtype = 4;
      break;
    case 3:
      vtype = 5;
      break;
    case 4:
      vtype = 2;
      break;
    case 5:
      vtype = 3;
      break;
    }
  }
  request.symbol    = symbol;                  // símbolo
  request.volume    = vlots;                   // volume de 0.2 lotes
  request.price     = vprice;                  // preço para a abertura
  request.deviation = order.slipPage;          // desvio permitido do preço
  request.magic     = order.magicNumber;       // MagicNumber da ordem
  request.sl        = sl;
  request.tp        = tp;
  request.comment   = order.comment;

  switch (int(vtype)){
  case 0:
    request.action = TRADE_ACTION_DEAL; // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY;      // tipo da ordem
    break;
  case 1:
    request.action = TRADE_ACTION_DEAL; // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL;     // tipo da ordem
    break;
  case 2:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY_LIMIT;   // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    break;
  case 3:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_LIMIT;  // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    break;
  case 4:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY_STOP;    // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    request.stoplimit = 0;
    break;
  case 5:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_STOP;   // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    request.stoplimit = 0;
    break;
  case 6:
    request.action = TRADE_ACTION_PENDING;    // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY_STOP_LIMIT; // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    break;
  case 7:
    request.action = TRADE_ACTION_PENDING;     // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_STOP_LIMIT; // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    break;
  }
  change = OrderCreate(result, request, order, action);
  return change;
}

//+------------------------------------------------------------------+
//+ Orders                                                           +
//+------------------------------------------------------------------+
bool OrderCreate(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action){
  ResetLastError();
  bool change = false;

  for (int count = 0; count <= 1; count++){    
    if (action == "MODIFY_VOLUME"){
      double lot = PositionGetDouble(POSITION_VOLUME);
      request.volume -= lot;
    }

    if(OrderCreateCheck(request, result, order))
      change = OrderSend(request, result);      

    OrderCreateProcess(result, request, order, action, count);

    if (count == 1 || (result.retcode == 90013 || result.retcode == 10008 || result.retcode == 10009 || result.retcode == 90099 || result.retcode == 90016 || result.retcode == 90090 || result.retcode == 90091))
      break;
  }
  return change;
}

//+------------------------------------------------------------------+
bool OrderCreateCheck(MqlTradeRequest &request, MqlTradeResult &result, OrderStruct &order){
  if (AccountMarginMode() == "HEDGING" && order.state != "pending")
    return false;
    
  if (!cterminal.IsConnected()){
    result.retcode = 10008; // "Not connected" error code
    return false;
  }
  
  if(CheckOrderOpened(order)){
    result.retcode = 90016;                                                         // OPENED
    return false;
  }
  
  if(FindOrdersHistoryByCommentBool(request.comment)){
    result.retcode = 90013;
    return false;
  }  

  if(MfeTargetLossCheck()){
    result.retcode = AppSettings.ReachMfeTargetBool() ? 90090 : 90091;
    return false;
  }    
  
  if((order.secondsAgo >= AppSettings.appMaxSeconds && order.type <= 1)){           // TIMEMAX
    result.retcode = 90099;
    return false;
  }
  
  return true;
}

//+------------------------------------------------------------------+
void OrderCreateProcess(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action, int count){
  switch (result.retcode){
  case 10009:
    order.metaState   = "OPEN";
    order.metaMessage = "Order Open";
    order.ticketSlave = long(result.order);
    order.ticketDeal  = long(result.deal);
    order.volume      = result.volume;
    break;
  case 90099:
    order.metaState = "TIMEMAX";
    order.metaMessage = StringFormat("Time Max: %d >= %d MaxSeconds",order.secondsAgo, AppSettings.appMaxSeconds);
    break;
  case 90013:
    result.retcode     = 90013;
    order.metaState    = "HASCLOSED";
    order.metaMessage  = "Order Has Closed";
    break;
  case 90016:
    order.metaState = "OPENED";
    order.metaMessage = "Order Already open";
    break;
  case 10016:
    order.metaState = "NOSLTP";
    order.metaMessage = "Order No SL/TP";
    break;
  case 10008: // Não conectado
    order.metaState = "NOTCONNECTION";
    order.metaMessage = "Not Networking";
    break;
  case 90090: // Não conectado
    order.metaState = "REACHMFE";
    order.metaMessage = MfeTargetLossCheckOrder(order);
    break;
  case 90091: // Não conectado
    order.metaState = "REACHLOSS";
    order.metaMessage = MfeTargetLossCheckOrder(order);
    break;
  default:
    order.metaState = "ERRORDEAL";
    order.metaMessage = "Order Error Deal";
    break;
  }

  if (order.metaState == "OPENED" || order.metaState == "OPEN" || order.metaState == "HASCLOSED")
    UpdateOrderInfo(order, action);          
  
  SendMessageToServer(result, request, order, "OrderCreate");
}

//+------------------------------------------------------------------+
bool OrderModify(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action){
  bool change = false;
 
  if(OrderSelect(order.ticketSlave)){
    change = trade.OrderModify(order.ticketSlave, order.priceOpen, order.stopLoss, order.takeProfit, ORDER_TIME_DAY, 0);
  } 
  if(PositionSelectByTicket(order.ticketSlave)){    
    change = trade.PositionModify(order.ticketSlave, order.stopLoss, order.takeProfit);
  }

  result.retcode    = trade.ResultRetcode();
  request.symbol    = order.symbol;
  request.sl        = order.stopLoss;
  request.tp        = order.takeProfit;
  order.metaMessage = trade.ResultComment();
  order.metaState   = change ? "MODIFY" : "NOTMODIFY";
  change            = change ? long(order.ticketSlave) : INVALID_HANDLE;
 
  SendMessageToServer(result, request, order, "MakeOrderModify");  
    
  return change;
}

//+------------------------------------------------------------------+
bool OrderModifyVolume(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action){
  bool   change = false;    
  double volume = PositionGetDouble(POSITION_VOLUME);

  if (order.volume > volume)
    change = MakeOrderOpen(result, request, order, action);
  else if(order.volume < volume){
    long digits = SymbolInfoInteger(order.symbol, SYMBOL_DIGITS);
    order.volume = NormalizeDouble(volume - order.volume, int(digits));
    change = MakeOrderClose(result, request, order, action);
  }    
  return change;
}

//+------------------------------------------------------------------+
//+ Checks                                                           +
//+------------------------------------------------------------------+
void CheckOrdersClosed(){
  for (int i = 0;(i < OrdersTotal() && OrdersTotal() > 0); i++) {
    ulong ticketID   = OrderGetTicket(i);
    string comment   = OrderGetString(ORDER_COMMENT);
    long magicNumber = OrderGetInteger(ORDER_MAGIC);
    
    if(magicNumber == 0)
      continue;    
       
    bool ticketClosed  = FindOrdersHistoryByPositionIdBool(ticketID);    
    long idxPositionOrder = FindOrdersHistoryByPositionIDIndex(ticketID, DEAL_ENTRY_IN); // Search for Order Pending/Positions         
    
    if(idxPositionOrder != -1 && ticketClosed)
      MakeOrder(PositionOrders[idxPositionOrder],"CLOSED");
  }
  
//  for (int i = 0; i < PositionsTotal(); i++) {
//    ulong ticketid   = PositionGetTicket(i);
//    string comment   = PositionGetString(POSITION_COMMENT);
//    ulong positionID = PositionGetInteger(POSITION_TICKET);
//    
//    long idxPosition = Find(comment);
//    if(idxPosition == INVALID_HANDLE)
//      if(FindOrdersPositionByComementBool(comment))
//        idxPosition = INVALID_HANDLE;
//    
//    if (idxPosition != INVALID_HANDLE || PositionGetInteger(POSITION_MAGIC) == 0)
//      continue;
//  
//    //long ii = FindOrdersHistoryByCommentIndex(comment, DEAL_ENTRY_OUT);
//  
//    if (idxPosition == INVALID_HANDLE) {
//      // A ordem está aberta, mas não foi encontrada no array de ordens
//      // Adicione código aqui para lidar com essa situação
//      AddCommentOnChart("CheckOrdersClosed - Order Ticket to Close #" + IntegerToString(ticketid) + " Comment: " + comment + "\n");
//      OrderStruct missingOrder;
//      missingOrder.ticketMaster = StringToInteger(comment);
//      missingOrder.ticketSlave  = long(ticketid);
//      missingOrder.comment      = comment;
//      missingOrder.symbol       = PositionGetString(POSITION_SYMBOL);
//      missingOrder.magicNumber  = PositionGetInteger(POSITION_MAGIC);
//      missingOrder.type         = PositionGetInteger(POSITION_TYPE);
//      
//      MakeOrder(missingOrder, "CLOSED");
//    } 
//  }

  // Itera sobre todas as ordens na array PositionOrders
  for(int i = 0; i < ArraySize(PositionOrders); i++){ 
    bool hasHistory = FindOrdersHistoryByPositionIdBool(PositionOrders[i].positionID, DEAL_ENTRY_OUT);            // Verifica se há histórico para o positionID da ordem atual
    bool hasOpenOrderWithSameComment = FindOpenOrderByCommentBool(PositionOrders[i].comment);     // Verifica se há uma ordem aberta com o mesmo comentário da ordem atual
    bool hasCorrespondingPosition = false;                                                        // Inicializa a flag para verificar se há uma posição correspondente ao ticketSlave
         
    if(PositionOrders[i].ticketSlave > 0)                                                         // Se ticketSlave estiver definido, tenta selecionar a posição correspondente
        hasCorrespondingPosition = PositionSelectByTicket(PositionOrders[i].ticketSlave);
        
    /*   Condição para fechar a ordem:
        - Deve haver histórico associado à ordem.
        - E (deve haver uma ordem aberta com o mesmo comentário 
           ou deve haver uma posição correspondente ao ticketSlave).
    */
    if(hasHistory && (hasOpenOrderWithSameComment && hasCorrespondingPosition)){   // Log para depuração      
      AddCommentOnChart("Closing Order TicketSlave: "+ IntegerToString(PositionOrders[i].ticketSlave) +" - Comment: " + PositionOrders[i].comment +" - PositionID: "+ IntegerToString(PositionOrders[i].positionID));
      
      UpdateOrderInfo(PositionOrders[i], "CLOSED");
      
      bool closeResult = MakeOrder(PositionOrders[i], "CLOSED");          // Fecha a ordem chamando MakeOrder com a ação "CLOSED"           
      if(closeResult)                                                    // Verifica se a operação de fechamento foi bem-sucedida
        AddCommentOnChart("CheckOrdersClosed - Ordem fechada com sucesso: TicketSlave=" + IntegerToString(PositionOrders[i].ticketSlave));
      else
        AddCommentOnChart("CheckOrdersClosed - Falha ao fechar a ordem: TicketSlave=" + IntegerToString(PositionOrders[i].ticketSlave));
    }
  }
}

//+------------------------------------------------------------------+
void CheckOrdersDuplicate(){
  string commentsOnChart = ""; // Inicializa a string que acumulará os comentários para o gráfico

  for (int i = 0; i < PositionsTotal(); i++){
    ulong ticket_slave1 = PositionGetTicket(i);
    string comment1 = PositionGetString(POSITION_COMMENT); 

    // Comece 'x' de 'i + 1' para evitar comparações desnecessárias e duplicadas
    for (int x = i + 1; x < PositionsTotal(); x++){
      ulong ticket_slave2 = PositionGetTicket(x);
      if(ticket_slave1 == ticket_slave2)
        continue;
      
      PositionSelectByTicket(ticket_slave2);
      string comment2 = PositionGetString(POSITION_COMMENT); // A correção aqui é para usar POSITION_COMMENT
      if (PositionSelectByTicket(ticket_slave2) == false)
        continue;

      // Checa se os tickets são diferentes e os comentários são iguais
      if (ticket_slave1 != ticket_slave2 && comment1 == comment2){
        AddCommentOnChart("CheckOrdersDuplicate - Duplicate Order Ticket 1 #" + IntegerToString(ticket_slave1) + " - Ticket 2 #" + IntegerToString(ticket_slave2) + " Comment: " + comment1 + "\n");
        CloseOrderByComment(ticket_slave1, comment2); 
      }
    }
  }
}

//+------------------------------------------------------------------+
bool CheckOrderOpened(OrderStruct &order){
   HistorySelect(0, TimeCurrent());

  if(order.type == 0 || order.type == 1){
    if(FindOrdersHistoryByCommentBool(order.comment))
      return true;
       
    for (int i = PositionsTotal() -1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0){
        if (PositionGetString(POSITION_COMMENT) == order.comment){
          AddCommentOnChart("CheckOrderAlreadyOpen - Opened Order Ticket #" + IntegerToString(ticket) + " Comment :" + order.comment + "\n");
          return true;
        }
      }
    }  
  } else if(order.type >= 2){
    for(int i=HistoryOrdersTotal() -1; i >=0; i--){
      ulong ticket;      
      if((ticket = HistoryOrderGetTicket(i)) > 0){
        string comment = HistoryOrderGetString(ticket, ORDER_COMMENT);
        if(order.comment == comment){
          if(order.ticketSlave <= 0)
            order.ticketSlave = long(ticket);
          return true;          
        }

      }      
    }    
    
    for(int i=OrdersTotal() -1; i >=0; i--){
      ulong ticket;      
      if((ticket = OrderGetTicket(i)) > 0){      
        string comment = OrderGetString(ORDER_COMMENT);
        if(order.comment == comment){
          if(order.ticketSlave <= 0)
            order.ticketSlave = long(ticket);
          return true;
        }
      }
    }
  }
  return false;
}

//+------------------------------------------------------------------+
//+ Closes                                                           +
//+------------------------------------------------------------------+
void CloseAllPositionOrders(){
  for (int i = 0; i < PositionsTotal(); i++){
    ulong ticket_slave = PositionGetTicket(i);
    string comment = PositionGetString(POSITION_COMMENT);
    long magic_number = PositionGetInteger(POSITION_MAGIC);
    if (StringLen(comment) > 0 && magic_number > 0)
      CloseOrderByComment(ticket_slave, comment);
  }
}

//+------------------------------------------------------------------+
void CloseAllOrdersStruct(OrderStruct &orders[]){  
  long positionsTotal = PositionsTotal();
  long pendingsTotal = OrdersTotal();
  for (int i = 0; i < ArraySize(orders); i++){
    if(orders[i].type <= 1 && positionsTotal == 0)
      break ;
    if(orders[i].type >= 2 && pendingsTotal == 0)
      break;          
    
    MakeOrder(orders[i], "CLOSED");
  }
}

//+------------------------------------------------------------------+
void CloseOrderByComment(ulong ticket_slave, string comment){
  OrderStruct order;

  PositionSelectByTicket(ticket_slave);
  order.ticketSlave  = long(ticket_slave);
  order.ticketDeal   = -1;
  order.ticketMaster = long(PositionGetString(POSITION_COMMENT));
  order.symbol       = PositionGetString(POSITION_SYMBOL);
  order.type         = PositionGetInteger(POSITION_TYPE);
  order.volume       = PositionGetDouble(POSITION_VOLUME);
  order.magicNumber  = PositionGetInteger(POSITION_MAGIC);
  order.slipPage     = AppSettings.appSlipPage;
  order.comment      = comment;
  UpdateOrderInfo(order, "CLOSED");
  
  if (MakeOrder(order, "CLOSED"))
    AddCommentOnChart("CloseOrderByComment: Close True - Comment: " + comment + " Ticket #" + IntegerToString(ticket_slave));
  else
    AddCommentOnChart("CloseOrderByComment: Close False - Comment: " + comment + " Ticket #" + IntegerToString(ticket_slave));
}

//+------------------------------------------------------------------+
// Gets                                                              +
//+------------------------------------------------------------------+
double GetOrderProfitByTicketOnHistoryOrders(OrderStruct &order){
  double profit = 0;
  
  UpdateHistoryOrders();
  
  for (int i = 0; i < ArraySize(HistoryOrders); i++){
    //OrderObj *order = (OrderObj *)HistoryOrders.At(i);
    if((StringLen(HistoryOrders[i].comment) == 0) && HistoryOrders[i].magicNumber == 0 && HistoryOrders[i].entry == DEAL_ENTRY_IN)
      continue;
    if(HistoryOrders[i].ticketSlave == order.ticketSlave)    
      profit += HistoryOrders[i].profit;
  }
  return profit; // Add a return statement here
}

//+------------------------------------------------------------------+
double GetOrderProfit(OrderStruct &order){
  double profit = 0;
  string comment = order.comment;
  long ticketid = long(order.ticketSlave);
    
  if(OrderSelect(ticketid))
    return profit; 
  
  bool historyOrder = HistoryOrderSelect(ticketid);
  if(historyOrder){
    ENUM_ORDER_STATE state = ENUM_ORDER_STATE(HistoryOrderGetInteger(ticketid, ORDER_STATE));
    if(state != ORDER_STATE_FILLED  || state == ORDER_STATE_PLACED)
      return profit;
  }  

  if (ticketid <= 0)
    ticketid = FindOrdersHistoryByPositionIdLong(order.positionID);
  else if (ticketid == -1)
    return profit;

  for (int tries = 0; tries < 50; tries++){
    if (tries > 0 && profit == 0){
      int multi = int(tries / 2);
      Sleep(SleepTimer * multi);
      if (DebugMode && DebugModeLevel == 2)
        AddCommentOnChart("SleepTime: " + IntegerToString(SleepTimer) + " - tries: " + IntegerToString(tries) + " - multi: " + IntegerToString(multi), 0, false, true);
    }

    if (PositionSelectByTicket(ticketid))
      profit = PositionGetDouble(POSITION_PROFIT);
    else {
      if(order.ticketDeal <= 0)
        order.ticketDeal = FindDealInOrOutByTicketId(order, DEAL_ENTRY_OUT);
      if (order.ticketDeal > 0)
        profit = GetOrderProfitByTicketOnHistoryOrders(order);
    }
    
    if (DebugMode && DebugModeLevel == 2){          // Log debug information if in debug mode
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderProfit Profit: " + DoubleToString(profit));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderProfit Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderProfit SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
    
    if (profit != 0)                                // Break the loop if a non-zero profit is found
      break;
  }
  return profit;
}

//+------------------------------------------------------------------+
double GetOrderPriceClose(OrderStruct &order){
  int    tries = 0;
  double price = 0;
  string comment  = order.comment;
  long   ticketid = order.ticketSlave;
  
  bool historyOrder = HistoryOrderSelect(ticketid);
  if(historyOrder){
    ENUM_ORDER_STATE state = ENUM_ORDER_STATE(HistoryOrderGetInteger(ticketid, ORDER_STATE));
    if(state != ORDER_STATE_FILLED  || state == ORDER_STATE_PLACED)
      return price;
  }    

  for (tries; (tries < 50 && price == 0); tries++){
    if (tries > 0)
      Sleep(SleepTimer * tries);

    long deal_ticket = FindDealInOrOutByTicketId(order, DEAL_ENTRY_OUT);

    if (deal_ticket != INVALID_HANDLE)
      price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    if (DebugMode){
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose Price: " + DoubleToString(price));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }
  return price;
}

//+------------------------------------------------------------------+
double GetOrderPriceOpen(OrderStruct &order){
  int    tries = 0;
  double price = 0;
  string comment  = order.comment;
  long   ticketid = order.ticketSlave;

  for (tries; (tries < 50 && price == 0); tries++){
    if (tries > 0)
      Sleep(SleepTimer * tries);

    if (PositionSelectByTicket(ticketid)){
      price = PositionGetDouble(POSITION_PRICE_OPEN);
    } else {
      long deal_ticket = FindDealInOrOutByTicketId(order, DEAL_ENTRY_IN);
      if (deal_ticket != INVALID_HANDLE)
        price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
    }

    if (DebugMode){
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen Price: " + DoubleToString(price));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }
  return price;
}

//+------------------------------------------------------------------+
string GetOrderOpenAt(OrderStruct &order){
  int    tries    = 0;
  string open_at  = DEFAULT_TIME;
  string comment  = order.comment;
  long   ticketid = order.ticketSlave;

  for (tries; (tries < 50 && open_at == DEFAULT_TIME); tries++){
    if (tries > 0)
      Sleep(SleepTimer * tries);

    if(PositionSelectByTicket(ticketid))
      open_at = TimeToString(PositionGetInteger(POSITION_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    else {
      long deal_ticket = FindDealInOrOutByTicketId(order, DEAL_ENTRY_IN);
      if (deal_ticket != INVALID_HANDLE){
        open_at = TimeToString(HistoryDealGetInteger(deal_ticket, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
      }
    }

    if (DebugMode){
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt Ticket " + "#" + comment + " - Ticket: " + IntegerToString(ticketid));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt open_at: " + open_at);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }
  if (open_at == DEFAULT_TIME)
    Print("Position Open At not found for ticket ID: " + "#" + comment + " - Ticket: " + IntegerToString(ticketid));
  
  return open_at;
}

//+------------------------------------------------------------------+
int GetDigits(double num){
  int d = 0;
  double p = 1;
  while (MathRound(num * p) / p != num){p = MathPow(10, ++d);}
  return d;
}


//+------------------------------------------------------------------+
// Finds                                                             +
//+------------------------------------------------------------------+
long FindPendingOrderByComment(string comment){
  for (int i = OrdersTotal() - 1; i >= 0; i--){
    ulong order_ticket = OrderGetTicket(i);
    if (order_ticket > 0 && OrderGetString(ORDER_COMMENT) == comment)
      return long(order_ticket);
  }
  return NULL;
}

//+------------------------------------------------------------------+
long FindOpenOrderByComment(string comment){
  for (int i = PositionsTotal() - 1; i >= 0; i--){
    ulong order_ticket = PositionGetTicket(i);
    if (order_ticket > 0 && PositionGetString(POSITION_COMMENT) == comment)
      return long(order_ticket);
  }
  return NULL;
}

//+-----------------------------------------`-------------------------+
bool FindOpenOrderByCommentBool(string comment){
  for (int i = PositionsTotal() - 1; i >= 0; i--){
    ulong order_ticket = PositionGetTicket(i);
    if (order_ticket > 0 && PositionGetString(POSITION_COMMENT) == comment)      
      return true;
  }
  return false;
}

//+------------------------------------------------------------------+
long FindDealInOrOutByTicketId(OrderStruct &order, int dealEntry){ 
  if(order.ticketDeal > 0)
    if(ENUM_DEAL_ENTRY(HistoryDealGetInteger(order.ticketDeal, DEAL_ENTRY)) == dealEntry)
      return order.ticketDeal;
        
  order.ticketDeal = INVALID_HANDLE; 

  if(order.ticketDeal == INVALID_HANDLE){
    long idx = FindOrdersStructIndex(HistoryOrders, order.ticketSlave, dealEntry);
    if(idx >= 0)
      order.ticketDeal = HistoryOrders[idx].ticketDeal;
  }
  if(order.ticketDeal == INVALID_HANDLE){
    order.ticketDeal = FindOrdersHistoryByCommentTicketDeal(order.comment, dealEntry);
  }

  if(order.ticketDeal == INVALID_HANDLE){
    if(order.ticketDeal == DEAL_ENTRY_IN){
      if(order.ticketDeal == INVALID_HANDLE){
        long idx = FindOrdersStructIndex(PositionOrders, order.ticketSlave, dealEntry);
        if(idx >= 0)
          order.ticketDeal = PositionOrders[idx].ticketDeal;
      }
      if(order.ticketDeal == INVALID_HANDLE)
        order.ticketDeal = FindDealInByTicketId(order.ticketSlave);
    } else {
      order.ticketDeal = FindDealOutByTicketId(order.ticketSlave);
    }
  }
  return order.ticketDeal;
}

//+------------------------------------------------------------------+
// Mfe                                                               +
//+------------------------------------------------------------------+
bool MfeTargetLossCheck(){
  MfeTargetLossDayCalculate();
  bool change = false;
  string mfeMmessage;
  string lossMmessage;
  
  if(AppSettings.appReachMfeTarget > 0){   
    mfeMmessage = StringFormat("MFeTarget: %s - Profit Day: %s:", DoubleToString(AppSettings.appReachMfeTarget, 2), DoubleToString(AppSettings.appReachProfitDay,2));
    bool mfe_target = AppSettings.ReachMfeTargetBool();
    mfeMmessage += StringFormat(" - ReachMfe: %s", string(mfe_target));    
    AddCommentOnChart(mfeMmessage, 6, false);

    if(mfe_target)
      change = true;        
  }
  
  if (AppSettings.appReachLossSet < 0){
    lossMmessage = StringFormat("LossTarget: %s - Loss Day: %s", DoubleToString(AppSettings.appReachLossSet, 2), DoubleToString(AppSettings.appReachLossDay,2));
    bool loss_target = AppSettings.ReachLossSetBool();
    lossMmessage += StringFormat(" - ReachLoss: %s", string(loss_target));        
    AddCommentOnChart(lossMmessage, 7, false);
    
    if(loss_target)
      change = true;
  }
    
  return change;
}

//+------------------------------------------------------------------+
string MfeTargetLossCheckOrder(OrderStruct &order){  
  if(AppSettings.ReachMfeTargetBool() || AppSettings.ReachLossSetBool()){
    bool mfe_target  = AppSettings.ReachMfeTargetBool();
    bool loss_target  = AppSettings.ReachLossSetBool();
    string reach_state  = AppSettings.ReachMfeTargetBool() ? "MfeTarget" : "LossSet";
    string reach_symbol = AppSettings.ReachMfeTargetBool() ? ">=" : "<=";
    double value        = reach_state == "MfeTarget" ? AppSettings.appReachProfitDay : AppSettings.appReachLossDay;
    double target       = AppSettings.ReachMfeTargetBool() ? AppSettings.appReachMfeTarget : AppSettings.appReachLossSet;
    string action_msg   = StringFormat("#%s - %s: %s %s %s", order.comment, "ReachProfitDay", DoubleToString(value, 2), reach_symbol, DoubleToString(target, 2));    
    return action_msg;
  }
  return "";
}

//+------------------------------------------------------------------+
void MfeTargetLossDayCalculate(){
  datetime today                = TimeTradeServer() - (TimeTradeServer() % 86400);   
  double profitDay              = 0;  
  AppSettings.appReachLossDay   = 0;
  AppSettings.appReachProfitDay = 0;
     
  UpdateHistoryOrders();
  
  int deals = ArraySize(HistoryOrders)-1;
  for (int i = 0; i <= deals; i++){
    ulong deal_ticket = HistoryOrders[i].ticketDeal;
        
    if(HistoryOrders[i].magicNumber == 0){
      long iIndex = FindOrdersStructIndex(HistoryOrders, HistoryOrders[i].positionID, DEAL_ENTRY_IN);
      if(iIndex >= 0)
        HistoryOrders[i].magicNumber = HistoryOrders[iIndex].magicNumber;
    }
       
    int entry_type = (ENUM_DEAL_ENTRY)HistoryOrders[i].entry;

    if(entry_type == DEAL_ENTRY_IN || HistoryOrders[i].magicNumber == 0)
      continue;

    datetime order_date = datetime(HistoryOrders[i].closeAt);
    if (order_date < today)
      continue;
    
    profitDay += HistoryOrders[i].profit;    
  }
    
  for (int i = 0; i < ArraySize(PositionOrders); i++){
    if (PositionSelectByTicket(PositionOrders[i].ticketSlave  ))
      profitDay += GetOrderProfitByTicketID(PositionOrders[i].positionID);  
  }
  
  if(profitDay < 0)
    AppSettings.appReachLossDay = profitDay;
  if(profitDay > 0)
    AppSettings.appReachProfitDay = profitDay;  
}

//+------------------------------------------------------------------+
// Updates                                                           +
//+------------------------------------------------------------------+
bool UpdateOrderAttribute(double currentValue, double newValue, const string &attributeName, string &comment, const string &orderComment, ulong ticket, const string &symbol) {
  if (CompareDoubles(currentValue, newValue)) {
      comment += AttributeChangeString(orderComment, ticket, attributeName, currentValue, newValue, symbol);
      if (StringLen(comment) > 0)
          AddCommentOnChart(comment);
      return true;
  }
  return false;
}

//+------------------------------------------------------------------+
void UpdateOrderInfo(OrderStruct &order, string action){
  HistorySelect(0, TimeCurrent());    
  
  if(order.timeGMT == NULL || order.timeGMT == DEFAULT_TIME)
    order.timeGMT      = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
  if(order.timeTrader == NULL || order.timeTrader == DEFAULT_TIME)
    order.timeTrader   = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
  if(order.timeZone == 0)
    order.timeZone     = long((TimeGMT() - TimeTradeServer()) / 3600);
    
  if(order.type == 0 || order.type == 1){              
    
    if(order.ticketSlave <= 0)
      order.ticketSlave = FindOrdersHistoryByCommentPositionID(order.comment);      
      
    if (order.ticketDeal <= 0)
      order.ticketDeal = FindOrdersHistoryByCommentTicketDeal(order.comment, DEAL_ENTRY_IN);       

    if(order.positionID <= 0){
      order.positionID = order.ticketSlave;      
      if(order.positionID <= 0 && PositionSelectByTicket(order.ticketSlave)){                
        order.positionID = PositionGetInteger(POSITION_IDENTIFIER);
      }
    }      

    if(order.priceOpen == 0){
      order.priceOpen = GetOrderPriceOpen(order);
      if (order.priceOpen <= 0)
        order.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);                  
    }
    
    if(StringLen(order.openAt) == 0 || order.openAt == DEFAULT_TIME)  
      order.openAt = GetOrderOpenAt(order);

    
    if(order.metaState != "CLOSED" && order.metaState != "HASCLOSED"){
      if (order.ticketDeal <= 0)
        order.ticketDeal = FindOrdersHistoryByCommentTicketDeal(order.comment, DEAL_ENTRY_IN);       
      
      if(order.ticketSlave > 0){                                               
        if(order.stopLoss == 0)
          order.stopLoss = GetOrderStopLossByTicketId(order.ticketSlave);
        
        if(order.takeProfit == 0)
          order.takeProfit = GetOrderTakeProfitByTicketId(order.ticketSlave);

        if(order.volume == 0)
          order.volume = GetOrderVolumeByTicketId(order.ticketSlave);
      }
    } else {    
      if(order.ticketDeal <= 0){
        order.ticketDeal = FindDealInOrOutByTicketId(order, DEAL_ENTRY_OUT);
      } else {
        if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(order.ticketDeal, DEAL_ENTRY) == DEAL_ENTRY_IN)
          order.ticketDeal = FindDealInOrOutByTicketId(order, DEAL_ENTRY_OUT);  
      }
      if(order.ticketDeal > 0){
        order.closeAt    = TimeToString(HistoryDealGetInteger(order.ticketDeal, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));    
        order.priceClose = HistoryDealGetDouble(order.ticketDeal, DEAL_PRICE);
        order.stopLoss   = HistoryDealGetDouble(order.ticketDeal, DEAL_SL);
        order.takeProfit = HistoryDealGetDouble(order.ticketDeal, DEAL_TP);
        order.volume     = HistoryDealGetDouble(order.ticketDeal, DEAL_VOLUME);
      } 
    }

  } else {
    if(OrderSelect(order.ticketSlave)){      
      order.openAt      = TimeToString(OrderGetInteger(ORDER_TIME_SETUP), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
      order.priceOpen   = OrderGetDouble(ORDER_PRICE_OPEN);
      order.priceClose  = 0;         
      order.stopLoss    = OrderGetDouble(ORDER_SL);
      order.takeProfit  = OrderGetDouble(ORDER_TP);
      order.volume      = OrderGetDouble(ORDER_VOLUME_CURRENT);  
    } else{
      order.openAt      = TimeToString(HistoryOrderGetInteger(order.ticketSlave, ORDER_TIME_SETUP), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
      order.closeAt     = TimeToString(HistoryOrderGetInteger(order.ticketSlave, ORDER_TIME_DONE), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));    
      order.priceOpen   = HistoryOrderGetDouble(order.ticketSlave, ORDER_PRICE_OPEN);
      order.priceClose  = 0;              
      order.stopLoss    = HistoryOrderGetDouble(order.ticketSlave, ORDER_SL);
      order.takeProfit  = HistoryOrderGetDouble(order.ticketSlave, ORDER_TP);      
      order.volume      = HistoryOrderGetDouble(order.ticketSlave, ORDER_VOLUME_CURRENT);  
    }
  }
}

//+------------------------------------------------------------------+
// Others                                                            +
//+------------------------------------------------------------------+
string AttributeChangeString(string comment, long ticketid, string attributeName, double oldValue, double newValue, string symbol){
  string message;
  int symbol_digit;

  if (attributeName == "volume")
    symbol_digit = 2;
  else
    symbol_digit = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));

  message = StringFormat("#%s - Ticket: %d - Order Modify: %s From: %s To: %s",
                         comment,
                         ticketid,
                         ToUpperCase(attributeName),
                         ToUpperCase(DoubleToString(oldValue, symbol_digit)),
                         ToUpperCase(DoubleToString(newValue, symbol_digit)));
  return message;
}

//+------------------------------------------------------------------+
double CalculatePips(double vprice, string snumber, long vtype, string symbol){
  int vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double vpoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
  double number = StringToDouble(snumber);
  double rnumber = 0;

  if (snumber == "0")
    return rnumber;

  // Ajuste vpoint de acordo com vdigits
  if (vdigits == 0 || vdigits == 1)
    vpoint = 1;
  else
    vpoint = MathPow(10, -vdigits + 1);

  rnumber = ((number - vprice) / vpoint) * vpoint;
  rnumber = (vprice + rnumber);

  return NormalizeDouble(rnumber, vdigits);
}

//+------------------------------------------------------------------+
double CalculateTotalProfitForOrder(long order_ticket){
  double totalProfit = 0.0;
  double totalVolumeClosed = 0.0;

  for (int i = HistoryDealsTotal() -1; i >= 0; i--){
    ulong deal_ticket = HistoryDealGetTicket(i);
    long dealOrderTicket = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
    long position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    if ((position_id == order_ticket) && (entry_type == DEAL_ENTRY_OUT)){
      double dealProfit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      double dealVolume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
      totalVolumeClosed += dealVolume;
      totalProfit += dealProfit;
    }
  }
  return totalProfit;
}

//+------------------------------------------------------------------+
double NormalizeVolume(const string symbol, double lot, double contract_volume){
  double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

  if (contract_volume == 0.0)
    return lot;
  else
    return NormalizeDouble((volume_step * contract_volume), 2);
}


//+------------------------------------------------------------------+
string SetLogInfo(OrderStruct &order, int lastError, uint retcode, string resultComment, int attempt){
  string logMessage = StringFormat("#%s - Ticket: %s - Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d",
                                   order.comment,
                                   IntegerToString(order.ticketSlave),
                                   lastError,
                                   retcode,
                                   resultComment,
                                   attempt);

  // Adiciona informação sobre o lucro se a ação for 'CLOSED'
  if ((order.metaAction == "CLOSED") || (order.metaAction == "HASCLOSED")){    
    logMessage += StringFormat(" - Profit: %.2f", order.profit);
  }
  return logMessage;
}

//+------------------------------------------------------------------+
void SendMessageToServer(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, const string functionName){     
  string meta_state = order.metaState;
  bool getProfit = (meta_state == "OPENED" || meta_state == "OPEN" || meta_state == "HASCLOSED" || meta_state == "CLOSED" || meta_state == "MODIFY_VOLUME" || meta_state == "MODIFY");

  if (order.profit == 0 && getProfit)
    order.profit = GetOrderProfit(order);
    
  int symbol_digit = int(SymbolInfoInteger(request.symbol, SYMBOL_DIGITS));
  string meta_message = StringFormat("#%s - Ticket: %s - %s - Symbol: %s - Type: %s  - Volume: %s - TP: %s - SL: %s - Action: %s - Meta State: %s", order.comment, IntegerToString(order.ticketSlave), functionName, order.symbol, IntegerToString(order.type), DoubleToString(order.volume, 2), DoubleToString(request.tp, symbol_digit), DoubleToString(request.sl, symbol_digit), ToUpperCase(order.metaAction), order.metaState);
  string log_message = SetLogInfo(order, GetLastError(), result.retcode, order.metaMessage, 0);
  
  if(StringLen(order.metaMessage) > 0)
    log_message = log_message + (" - MetaMessage: "+ order.metaMessage);
  
  order.metaMessage = meta_message + " - LogMessage: " + log_message;
  
  AddCommentOnChart(meta_message);
  AddCommentOnChart(log_message);
                
  string updateJson  = JsonOrderStruct(order);
  TrasmitOrders("update", updateJson, false);
}

//+------------------------------------------------------------------+