//+------------------------------------------------------------------+
//|                                                  ImentoreLib.mqh |
//|                                     Copyright 2024, Imentore.Co. |
//|                                         https://www.imentore.com |
//+------------------------------------------------------------------+
#property copyright   "ImentoreLib - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

#define LIB_VERSION  "12"
#define LIB_UPDATE  "31"

#include <ImentoreCommon.mqh>
#include <ImentoreSettings.mqh>
#include <trade/Orderinfo.mqh>

int      TimeCurrentAgo          = int(TimeLocal());
int      SleepTries              = 1;

bool     DebugMode               = false;         // DebugMode - Admin only (default is false)
bool     MfeMaeDisplay           = true;
bool     FirstRun                = true;
bool     CloseAllOrders          = false;

long     FreezeMaxTimeDifference = 30;            // Máximo tempo de diferenca em segundos
long     TimeToCheckServer       = 30; 
long     DebugModeLevel          = 1;
long     ReachMfeTarget          = 0;             // MFE Target
long     ReachLossSet            = 0;             // Loss Target


string   MfeMaeStr;

datetime FreezeLastServerTime = TimeTradeServer(); // Armazena o último tempo do servidor
datetime TimeCurrentDay       = TimeTradeServer();

//+------------------------------------------------------------------+
//+ Begins                                                           +
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//+ Objects                                                          +
//+------------------------------------------------------------------+

struct OrderStruct
{
  long ticketMaster;
  long ticketSlave;
  long ticketDeal;
  long positionID;
  long type;
  long entry;
  long traceID;
  long slaveID;
  long magicNumber;
  long transactionID;
  long slipPage;
  long symbolDigits;
  long timeZone;
  long createdAt;
  long secondsAgo;
  double profit;
  double priceOpen;
  double priceClose;
  double volume;
  double stopLoss;
  double takeProfit;
  double commission;
  double contractVolume;
  double fee;
  double swap;
  double mfe;
  double mae;
  string state;
  string symbol;
  string comment;
  string openAt;
  string closeAt;
  string timeGMT;
  string timeTrader;
  string metaMessage;
  string metaState;
  string metaAction;
};

//+------------------------------------------------------------------+
class ApiResponse {
public:
    bool changes;
    bool api_event_on_timer;
    bool api_event_on_tick;
    bool api_debug_mode;
    bool api_store_state;
    bool api_environment_local;  // EnvironmentLocal
    bool api_mfe_mae_display;    // Default true
    long api_reach_mfe_target;   // api_reach_mfe_target
    long api_reach_loss_set;     // api_reach_loss_set
    long api_freeze_max_time;
    long api_time_to_check_server;
    long api_time_max_seconds;   // Time Max Operation
    long api_slippage;           // Slippage for order
    long api_milliseconds_timer; // api_milliseconds_timer
    long api_milliseconds_tick;  // api_milliseconds_timer
    long api_milliseconds_delay;  // api_milliseconds_timer
    long api_debug_mode_level;   // Default 1
    bool api_send_orders_history;// Default false
    bool api_close_all_orders;   // Default false
    string api_store_message;
    string account_state;
    string account_margin_mode;
    string account_mode;         // Under real server (Default is false)
    string api_server_hostname;
    string api_send_orders_history_ranges;

    // Construtor que inicializa os valores padrão
    ApiResponse() {
      changes = true;
      api_event_on_timer = true;
      api_event_on_tick = true;
      api_debug_mode = false;
      api_store_state = true;
      api_environment_local = false;
      api_mfe_mae_display = true;
      api_reach_mfe_target = 0;
      api_reach_loss_set = 0;
      api_freeze_max_time = 30;
      api_time_to_check_server = 30;
      api_time_max_seconds = 30;
      api_slippage = 30;
      api_milliseconds_timer = 2000;
      api_milliseconds_tick = 2000;
      api_milliseconds_delay = 550;
      api_debug_mode_level = 1;
      api_send_orders_history = false;
      api_close_all_orders = false;

      account_state = "";
      account_margin_mode = "";
      account_mode = "";
      api_server_hostname = "";
      api_send_orders_history_ranges = "";
  }
  // Método para atualizar os valores a partir do JSON
  void UpdateFromJSON(const string &json) {
      account_state = GetJSONValue(json, "account_state");
      account_mode = GetJSONValue(json, "account_mode");
      account_margin_mode = GetJSONValue(json, "account_margin_mode");
      api_server_hostname = GetJSONValue(json, "api_server_hostname");
      api_store_state = GetJSONValue(json, "api_store_state") == "true";
      api_store_message = GetJSONValue(json, "api_store_message");
      api_debug_mode = GetJSONValue(json, "api_debug_mode") == "true";
      api_freeze_max_time = (int)StringToInteger(GetJSONValue(json, "api_freeze_max_time"));
      api_time_to_check_server = (int)StringToInteger(GetJSONValue(json, "api_time_to_check_server"));
      api_time_max_seconds = (int)StringToInteger(GetJSONValue(json, "api_time_max_seconds"));
      api_slippage = (int)StringToInteger(GetJSONValue(json, "api_slippage"));
      api_environment_local = GetJSONValue(json, "api_environment_local") == "true";
      api_milliseconds_timer = (int)StringToInteger(GetJSONValue(json, "api_milliseconds_timer"));
      api_milliseconds_tick = (int)StringToInteger(GetJSONValue(json, "api_milliseconds_tick"));
      api_milliseconds_delay = (int)StringToInteger(GetJSONValue(json, "api_milliseconds_delay"));
      api_event_on_timer = GetJSONValue(json, "api_event_on_timer") == "true";
      api_event_on_tick = GetJSONValue(json, "api_event_on_tick") == "true";
      api_debug_mode_level = (int)StringToInteger(GetJSONValue(json, "api_debug_mode_level"));
      api_mfe_mae_display = GetJSONValue(json, "api_mfe_mae_display") == "true";
      api_reach_mfe_target = (int)StringToInteger(GetJSONValue(json, "api_reach_mfe_target"));
      api_reach_loss_set = (int)StringToInteger(GetJSONValue(json, "api_reach_loss_set"));
      api_send_orders_history = GetJSONValue(json, "api_send_orders_history") == "true";
      api_close_all_orders = GetJSONValue(json, "api_close_all_orders") == "true";
      api_send_orders_history_ranges = GetJSONValue(json, "api_send_orders_history_ranges");
      
      StringTrimLeft(api_store_message);
      StringTrimRight(api_store_message);
  }
private:
    // Método auxiliar para extrair valor do JSON
    string GetJSONValue(const string &json, const string &key) {
      int startPos = StringFind(json, "\"" + key + "\":");
      if (startPos < 0) return "";

      startPos += StringLen(key) + 3;
      int endPos = StringFind(json, ",", startPos);
      if (endPos < 0) endPos = StringFind(json, "}", startPos);
      if (endPos < 0) return "";

      string value = StringSubstr(json, startPos, endPos - startPos);
      StringTrimRight(value);
      StringTrimLeft(value);

      // Remove aspas de valores de string
      if (StringSubstr(value, 0, 1) == "\"")
        value = StringSubstr(value, 1, StringLen(value) - 2);

      return value;
    }
};

//+------------------------------------------------------------------+
//+ Initialize Objects                                               +
//+------------------------------------------------------------------+
COrderInfo  OrderInfo;
OrderStruct HistoryOrders[];
OrderStruct PositionOrders[];
OrderStruct PendingOrders[];
Settings* LibSettings = Settings::Instance();
string      ResponseData[];

//+------------------------------------------------------------------+
string AccountMarginMode(){
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
bool ApiData(string name, string content = "") {  
  int status  = 0;
  int timeout = 5000;
  char post[], response[];
  string server_url, url, cookie, comment, result_header;
  
  string boundary = "-------Jyecslin9mp8RdKV"; 
  string header   = StringFormat("Content-Type: multipart/form-data; boundary=%s\r\n", boundary);
  string body     = StringFormat("--%s\r\nContent-Disposition: attachment; name=\"data\"; filename=\"%s\"\r\nContent-Type: text/html; charset=utf-8\r\n\r\n", boundary, name);
  
  StringToCharArray(body, post); // Converte o cabeçalho e início do corpo para postData
 
  int bodyStart = ArraySize(post);
  ArrayResize(post, bodyStart + StringLen(content) + StringLen("\r\n--" + boundary + "--\r\n"));
  StringToCharArray(content, post, bodyStart, StringLen(content)); // Copia conteúdo para postData
  StringToCharArray("\r\n--" + boundary + "--\r\n", post, bodyStart + StringLen(content));
  
  server_url = LibSettings.apiServerUrl +"/api/"+ LibSettings.apiVersion +"/"+ LibSettings.appExpertKind +"/post/";
  url = server_url + name + "/" + LibSettings.appExpertName + "/" + LibSettings.fExpertName() + "/"  + LibSettings.accountServerName + "/" + LibSettings.accountLogin + "/" + AccountMarginMode();
  
  bool internet_down = false;
  do{
      ResetLastError();
      status = WebRequest("POST", url, header, 0, post, response, result_header);     

      if(DebugMode && DebugModeLevel > 1){
       string result = CharArrayToString(response);
       string message = (TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS) + " - ApiRequestInformation - WebRequest Response: " + result);
       //string message = (TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS) + " - ApiRequestInformation - WebRequest Response: " + result2 + " - Action: "+ action);
       Print(message);
       SaveLogToFile(message);
      }

      if(status != 1001 && internet_down){
          comment = "Conexao estabelecida";
          AddCommentOnChart(comment);
          internet_down = false;
      }

      if(status == -1){
          comment = "Api código de erro: " + IntegerToString(GetLastError());
          comment = "É necessário adicionar o endereco '" + ToUpperCase(LibSettings.apiServerUrl) + "' em Ferramentas->Opcões->Experts Advisores->URL WebRequest - Erro: " + IntegerToString(MB_ICONINFORMATION);
          AddCommentOnChart(comment);

          return false;
      }
      else if(status == 201){
          string responseStr = CharArrayToString(response);
          int size = StringSplit(responseStr, '/', ResponseData);
          return true;
      } else {
          comment = "Api código de erro: " + IntegerToString(GetLastError()) + ",  Http Status: " + IntegerToString(status);
          AddCommentOnChart(comment);
      }

      internet_down = true;
      comment = "Verifique a sua conexao com a internet ou servidor fora temporariamente.";
      AddCommentOnChart(comment);
  }
  while(status != 201);

  return false;
}

//+------------------------------------------------------------------+
void CalculateOrdersMFEMAE(){
  string mfe_mae_string;
  long positionsTotal = ArraySize(PositionOrders);
  
  for(int i = 0; i < positionsTotal; i++){
    ulong ticketID = ticketID(PositionOrders[i]);
    string symbol = PositionOrders[i].symbol;
           
    double value_mae = PositionOrders[i].mae;
    double value_mfe = PositionOrders[i].mfe;
    string timestamp = TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS);

    PositionOrders[i].mae = CalculateMFEMAE(symbol, ticketID, "mae", value_mae);
    PositionOrders[i].mfe = CalculateMFEMAE(symbol, ticketID, "mfe", value_mfe);
    
    string mae_mfe = timestamp + " - #" + IntegerToString(ticketID) + " - MFE: " + DoubleToString(PositionOrders[i].mfe, 2) + " - MAE: " + DoubleToString(PositionOrders[i].mae, 2);
    StringConcatenate(mfe_mae_string, (mae_mfe), mfe_mae_string);
    StringConcatenate(mfe_mae_string, ("\n"), mfe_mae_string);    
    MfeMaeStr = mfe_mae_string;
  }
  
  if(MfeMaeDisplay && StringLen(MfeMaeStr) > 0)
    AddCommentOnChart(MfeMaeStr, 5, false, false);
  
  if(!MfeMaeDisplay || (positionsTotal == 0 && StringLen(MfeMaeStr) > 0)){
    RemoveCommentOnChart(5);
    MfeMaeStr = "";
  }
}

//+------------------------------------------------------------------+
double CalculateMFEMAE(string symbol, long ticketid, string type, double value){
  double profit    = 0;
 // int totalOrders  = ArraySize(orders);

  profit = GetOrderProfitByTicketID(ticketid);
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
  return value;
 }

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
bool CheckServerInformations(){
  int timeAgo = int(TimeLocal() - TimeCurrentAgo);
  
  if(timeAgo < TimeToCheckServer && FirstRun == false)
    return true;
  else
    TimeCurrentAgo = int(TimeLocal()); 
  
  bool changes = true;
  ApiResponse apiResponse;
  
  if (ApiData("store")){
    string json = ResponseData[0];
    apiResponse.UpdateFromJSON(json);
  } else {
    changes = false;
  }  

  if (apiResponse.api_debug_mode == true && DebugMode == false) {
    DebugMode = apiResponse.api_debug_mode;
    AddCommentOnChart("Modo de DEBUG ativado");
  } else if(apiResponse.api_debug_mode == false && DebugMode == true){
    DebugMode = apiResponse.api_debug_mode;
    AddCommentOnChart("Modo de DEBUG desativado");
  }

  if(apiResponse.api_time_to_check_server != TimeToCheckServer){
    AddCommentOnChart("TimeToCheckServer atualizado de: " + IntegerToString(TimeToCheckServer) + " para: " + IntegerToString(apiResponse.api_time_to_check_server));
    TimeToCheckServer = apiResponse.api_time_to_check_server;  
  }

  if(LibSettings.appMaxSeconds != apiResponse.api_time_max_seconds){
    AddCommentOnChart("MaxSeconds atualizado de: " + IntegerToString(LibSettings.appMaxSeconds) + " para: " + IntegerToString(apiResponse.api_time_max_seconds));
    LibSettings.appMaxSeconds = apiResponse.api_time_max_seconds;
  }
  if(LibSettings.appSlipPage != apiResponse.api_slippage){
    AddCommentOnChart("Slippage atualizado de: " + IntegerToString(LibSettings.appSlipPage) + " para: " + IntegerToString(apiResponse.api_slippage));
    LibSettings.appSlipPage = apiResponse.api_slippage;
  }

 if(apiResponse.api_freeze_max_time != FreezeMaxTimeDifference){
    AddCommentOnChart("FreezeMaxTimeDifference atualizado de: " + IntegerToString(FreezeMaxTimeDifference) + " para: " + IntegerToString(apiResponse.api_freeze_max_time));
    FreezeMaxTimeDifference = apiResponse.api_freeze_max_time;  
  }

 if(apiResponse.api_event_on_timer != LibSettings.appEventOnTimer){
    AddCommentOnChart("EventOnTimer atualizado de: " + string(LibSettings.appEventOnTimer) + " para: " + string(apiResponse.api_event_on_timer));
    LibSettings.appEventOnTimer = apiResponse.api_event_on_timer;  
  }

 if(apiResponse.api_event_on_tick != LibSettings.appEventOnTick){
    AddCommentOnChart("EventOnTick atualizado de: " + string(LibSettings.appEventOnTick) + " para: " + string(apiResponse.api_event_on_tick));
    LibSettings.appEventOnTick = apiResponse.api_event_on_tick;  
  }

  if(LibSettings.InputEnvironmentLocal == false){
    if(LibSettings.appEnvironmentLocal != apiResponse.api_environment_local){
      AddCommentOnChart("EnvironmentLocal atualizado de: " + string(LibSettings.appEnvironmentLocal) + " para: " + string(apiResponse.api_environment_local));
      LibSettings.appEnvironmentLocal = apiResponse.api_environment_local;
    }
  }

  if(LibSettings.appReachMfeTarget != apiResponse.api_reach_mfe_target){
    AddCommentOnChart("ReachMfeTarget atualizado de: " + DoubleToString(LibSettings.appReachMfeTarget, 2) + " para: " + DoubleToString(apiResponse.api_reach_mfe_target, 2));
    //ReachMfeTargetBool  = false;
    LibSettings.appReachProfitDay      = 0;    
    LibSettings.appReachMfeTarget = int(apiResponse.api_reach_mfe_target);
    RemoveCommentOnChart(6);
  }  

  if(LibSettings.appReachLossSet != apiResponse.api_reach_loss_set){
    AddCommentOnChart("ReachLossSet atualizado de: " + DoubleToString(LibSettings.appReachLossSet, 2) + " para: " + DoubleToString(apiResponse.api_reach_loss_set, 2));

    LibSettings.appReachLossDay        = 0;    
    LibSettings.appReachLossSet = int(apiResponse.api_reach_loss_set);
    RemoveCommentOnChart(7);
  }

  if(DebugModeLevel != apiResponse.api_debug_mode_level){
    AddCommentOnChart("DebugModeLevel atualizado de: " + IntegerToString(DebugModeLevel) + " para: " + IntegerToString(apiResponse.api_debug_mode_level));
    DebugModeLevel = apiResponse.api_debug_mode_level;
  }

  if(LibSettings.appSendOrdersHistory != apiResponse.api_send_orders_history){
    AddCommentOnChart("SendHistoryOrder atualizado de: " + IntegerToString(LibSettings.appSendOrdersHistory) + " para: " + IntegerToString(apiResponse.api_send_orders_history));
    LibSettings.appSendOrdersHistory = apiResponse.api_send_orders_history;
  }  

  if(CloseAllOrders != apiResponse.api_close_all_orders){
    AddCommentOnChart("CloseAllOrders atualizado de: " + IntegerToString(CloseAllOrders) + " para: " + IntegerToString(apiResponse.api_close_all_orders));
    CloseAllOrders = apiResponse.api_close_all_orders;    
  }
  
  if(LibSettings.appMilliSecondsTimer != apiResponse.api_milliseconds_timer){
    AddCommentOnChart("MilliSecondsTimer atualizado de: " + IntegerToString(LibSettings.appMilliSecondsTimer) + " para: " + IntegerToString(apiResponse.api_milliseconds_timer));
    LibSettings.appMilliSecondsTimer = int(apiResponse.api_milliseconds_timer);
    EventSetMillisecondTimer(LibSettings.appMilliSecondsTimer);
  }
    
  if(LibSettings.appMilliSecondsTicker != apiResponse.api_milliseconds_tick){
    AddCommentOnChart("MilliSecondsTick atualizado de: " + IntegerToString(LibSettings.appMilliSecondsTicker) + " para: " + IntegerToString(apiResponse.api_milliseconds_tick));
    LibSettings.appMilliSecondsTicker = int(apiResponse.api_milliseconds_tick);
    EventSetMillisecondTimer(LibSettings.appMilliSecondsTicker);
  }
  
  if(LibSettings.appMilliSecondsDelay != apiResponse.api_milliseconds_delay){
    AddCommentOnChart("MilliSecondsDelay atualizado de: " + IntegerToString(LibSettings.appMilliSecondsDelay) + " para: " + IntegerToString(apiResponse.api_milliseconds_delay));
    LibSettings.appMilliSecondsDelay = int(apiResponse.api_milliseconds_delay);
  }  

  if(MfeMaeDisplay != apiResponse.api_mfe_mae_display){
    AddCommentOnChart("MfeMaeDisplay atualizado de: " + string(MfeMaeDisplay) + " para: " + string(apiResponse.api_mfe_mae_display));
    MfeMaeDisplay = apiResponse.api_mfe_mae_display;
  }

  if(StringLen(apiResponse.api_store_message) > 0){
    AddCommentOnChart(apiResponse.api_store_message);
    //changes = false;
  }

  if(!apiResponse.api_store_state){
    AddCommentOnChart("Sistema copy está desabilitada em nosso sistema. Fale com o suporte");
    changes = false;
  }

  if(apiResponse.account_mode == "demo" && IsDemoMQL4() == false){
    AddCommentOnChart("Acesso é somente para conta demo. Fale com o suporte");
    changes = false;
   }

  if(apiResponse.account_state == "disable"){
    AddCommentOnChart("Conta está desabilitada em nosso sistema. Fale com o suporte");
    changes = false;
  }
  if(apiResponse.account_margin_mode == "hedging" && AccountMarginMode() == "NETTING"){
    // Print("Sua conta está habilitada para modo HEDGE em nosso sistema, porém conta na corretora está configurada para modo NETTING. Efetue a mudanca com a sua corretora.");
    AddCommentOnChart("Conta está habilitada para modo HEDGE em nosso sistema, porém conta na corretora está configurada para modo NETTING. Efetue a mudanca com a sua corretora.");
    changes = false;
  }
  if(apiResponse.account_margin_mode == "netting" && AccountMarginMode() == "HEDGING"){
    // Print("Sua conta está habilitada para modo NETTING em nosso sistema, porém a conta na corretora está configurada para modo HEDGE. Efetue a mudanca com a sua corretora.");
    AddCommentOnChart("Conta está habilitada para modo NETTING em nosso sistema, porém a conta na corretora está configurada para modo HEDGE. Efetue a mudanca com a sua corretora.");
    changes = false;
  }

  if(changes == false){
    // Alert("Error - ImentoreSlave nao está funcionando corretamente");
    AddCommentOnChart("Error - Imentore nao está funcionando corretamente");
  }

  if(DebugMode && DebugModeLevel > 2){
    string message = TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS) + " - CheckServerInformations";
    Print(message);
    SaveLogToFile(message);
  }
  ArrayFree(ResponseData);
  return changes;
 }

//+------------------------------------------------------------------+
void CheckFreeze(){
  if(FreezeMaxTimeDifference == 0)
    return;

  datetime currentServerTime = TimeTradeServer(); // Pega o tempo atual do servidor
  // Calcula a diferenca entre o tempo atual do servidor e a última vez que verificamos
  int timeDifference = int(currentServerTime - FreezeLastServerTime);

  // Se a diferenca de tempo for maior do que o máximo permitido, entao há um problema
  if(timeDifference > FreezeMaxTimeDifference)
  {      
    string message = "CheckFreeze - O MetaTrader travou " + IntegerToString(timeDifference) +  " segundos, possível travamento. Por favor, verifique a CPU e a conexão com a internet.";
    AddCommentOnChart(message);
  }
  // Opcional: você pode querer ter um log de debug ou acao para quando tudo estiver normal
  else if(DebugMode && DebugModeLevel > 1)
  {
    string message = TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS) + " - CheckFreeze - tudo normal. Diferenca de tempo: " + IntegerToString(timeDifference) + " segundos.";
    Print(message);
    SaveLogToFile(message);
  }
  // Atualiza FreezeLastServerTime para o tempo atual
  FreezeLastServerTime = currentServerTime;
}

//+------------------------------------------------------------------+
void CheckAnotherDay(){
  datetime currentTime = TimeTradeServer();
      
  if(currentTime / 86400 != TimeCurrentDay / 86400){
    MqlDateTime dateTime;
    TimeToStruct(currentTime, dateTime);
    AddCommentOnChart("CheckAnotherDay - Change Day: " + IntegerToString(dateTime.day -1) + " to: " + IntegerToString(dateTime.day));
    
    LibSettings.appSendOrdersHistory = true;
    if(TrasmitOrders()){
      AddCommentOnChart("CheckAnotherDay - Send History Orders");      
    }
    LibSettings.appReachProfitDay = 0;
    LibSettings.appReachLossDay = 0;
    TimeCurrentDay = currentTime; // Atualizar a última data de verificação
  }
}

//+------------------------------------------------------------------+
void CheckTimeDiscrepancy() {
  string message = (TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " - CheckTimeDiscrepancy");
  SaveLogToFile(message);
  string lastLine = ReadLastLine(LogFileName); // LogFileName é a variável com o caminho do arquivo
  if (lastLine != "") {
    string timePart = StringSubstr(lastLine, 22, 41); // Extraí o tempo assumindo o formato "YYYY.MM.DD HH:MM:SS"
    datetime logTime = StringToTime(timePart);

    datetime localTime = TimeLocal();
    
    long TimeDifference = int(TimeLocal()) - int(logTime);

    if(TimeDifference > 3600){
        AddCommentOnChart("Time discrepancy detected between local time and log file time.", 0, false, true);
    } else {
        AddCommentOnChart("No time discrepancy detected.", 0, false, true);
    }
  }
}

//+------------------------------------------------------------------+
bool DetectEnvironment(){
  if(LibSettings.appEnvironmentLocal){
    if(LibSettings.appExpertKind == "copy")
      LibSettings.apiServerUrl = "http://localhost:8080";
    if(LibSettings.appExpertKind == "slave")
      LibSettings.apiServerUrl = "http://localhost:8081";  
  } else
    LibSettings.apiServerUrl = "https://mt5-web-replicator.example.com";

  if(!CheckServerInformations())
    return false;

  FirstRun = false;
  return true;
 }
 
//+------------------------------------------------------------------+
void EventsOnDeinit(){
  AddCommentOnChart("Expert " + LibSettings.appExpertName + " " + LibSettings.appVersion + " - Update " + LibSettings.appVersionUpdate + " removido com sucesso.");
  ArrayFree(HistoryOrders);
  ArrayFree(PositionOrders);
  ArrayFree(ResponseData);
  delete LibSettings;
  return;
}

//+------------------------------------------------------------------+
long FindDealInByTicketId(const ulong ticketid){
   HistorySelect(0, TimeToUse());
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
    ulong deal_ticket = HistoryDealGetTicket(i);
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    long ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    if(entry_type == DEAL_ENTRY_IN && ticket == ticketid)
      return long(deal_ticket);
   }

   return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
long FindDealOutByTicketId(const ulong ticketid){
   HistorySelect(0, TimeToUse());
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--){
    ulong deal_ticket = HistoryDealGetTicket(i);
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    long ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    if(entry_type != DEAL_ENTRY_IN && ticket == ticketid)
      return long(deal_ticket);
   }
   return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
long FindOrdersHistoryByCommentIndex(const string comment, int dealEntry = DEAL_ENTRY_IN){
  if(StringLen(comment) <= 0)
    return INVALID_HANDLE;
    
  for (int i = ArraySize(HistoryOrders) -1; i >= 0; i--){
    if(HistoryOrders[i].comment == comment){
      if(HistoryOrders[i].entry == dealEntry && dealEntry == DEAL_ENTRY_IN)
        return i;
      if(HistoryOrders[i].entry != DEAL_ENTRY_IN && dealEntry != DEAL_ENTRY_IN) //DEAL ENTRY OUT
        return i;
    } 
  }
  return INVALID_HANDLE; // Add a return statement here
}

//+------------------------------------------------------------------+
long FindOrdersHistoryByPositionIDIndex(const ulong positionID, int dealEntry = DEAL_ENTRY_IN){
  for (int i = ArraySize(HistoryOrders) -1; i >= 0; i--){
    if(HistoryOrders[i].positionID == positionID){
      if(HistoryOrders[i].entry == dealEntry && dealEntry == DEAL_ENTRY_IN)
        return i;
      if(HistoryOrders[i].entry != DEAL_ENTRY_IN && dealEntry != DEAL_ENTRY_IN) //DEAL ENTRY OUT
        return i;
    } 
  }
  return INVALID_HANDLE; // Add a return statement here
}

//+------------------------------------------------------------------+
long FindOrdersHistoryByCommentTicketDeal(const string comment, int dealEntry = DEAL_ENTRY_IN){
  if(StringLen(comment) <= 0)
    return INVALID_HANDLE;

  for (int i = ArraySize(HistoryOrders) -1; i >= 0; i--){
    if(HistoryOrders[i].comment == comment){
      if(HistoryOrders[i].entry == DEAL_ENTRY_IN && dealEntry == DEAL_ENTRY_IN)
        return long(HistoryOrders[i].ticketDeal);
      if(HistoryOrders[i].entry != DEAL_ENTRY_IN && dealEntry != DEAL_ENTRY_IN) //DEAL ENTRY OUT
        return long(HistoryOrders[i].ticketDeal);
    } 
  }
  return INVALID_HANDLE; // Add a return statement here
}

//+------------------------------------------------------------------+
long FindOrdersHistoryByCommentPositionID(const string comment, int dealEntry = DEAL_ENTRY_IN){
  if(StringLen(comment) <= 0)
    return INVALID_HANDLE;

  for (int i = ArraySize(HistoryOrders) -1; i >= 0; i--){
    if(HistoryOrders[i].comment == comment){
      if(HistoryOrders[i].entry == DEAL_ENTRY_IN && dealEntry == DEAL_ENTRY_IN)
        return long(HistoryOrders[i].positionID);
      if(HistoryOrders[i].entry != DEAL_ENTRY_IN && dealEntry != DEAL_ENTRY_IN) //DEAL ENTRY OUT
        return long(HistoryOrders[i].positionID);
    } 
  }
  return INVALID_HANDLE; // Add a return statement here
}

//+------------------------------------------------------------------+
long FindOrdersPositionByPositionIDIndex(const ulong positionID, int dealEntry = DEAL_ENTRY_IN){
  for (int i = 0; i < ArraySize(PositionOrders); i++){
    if(PositionOrders[i].positionID == positionID){
      if(dealEntry == DEAL_ENTRY_IN)
        return i;
      else if(PositionOrders[i].entry != DEAL_ENTRY_IN) //DEAL ENTRY OUT
        return i;
    } 
  }
  return INVALID_HANDLE; // Add a return statement here
}

//+------------------------------------------------------------------+
bool FindOrdersPositionByPositionIDBool(const ulong positionID, int dealEntry = DEAL_ENTRY_IN){
  for (int i = 0; i < ArraySize(PositionOrders); i++){
    if(PositionOrders[i].positionID == positionID)     
        return true;
  }
  return false; // Add a return statement here
}

//+------------------------------------------------------------------+
bool FindOrdersPositionByComementBool(const string comment){
  for (int i = 0; i < ArraySize(PositionOrders); i++){
    if(PositionOrders[i].comment == comment)     
        return true;
  }
  return false; // Add a return statement here
}

//+------------------------------------------------------------------+
long FindOrdersStructIndex(OrderStruct &orders[], long positionID, int dealEntry = DEAL_ENTRY_IN){
  for (int i = 0; i < ArraySize(orders); i++){
    if(orders[i].positionID == positionID){
      if(orders[i].entry == DEAL_ENTRY_IN && dealEntry == DEAL_ENTRY_IN)
        return i;
      else if(orders[i].entry != DEAL_ENTRY_IN && dealEntry != DEAL_ENTRY_IN) //DEAL ENTRY OUT
        return i;
    } 
  }
  return INVALID_HANDLE;  // Add a return statement here
}

//+------------------------------------------------------------------+
bool FindOrdersHistoryByCommentBool(const string comment, int dealEntry = DEAL_ENTRY_IN){
  if(StringLen(comment) <= 0)
    return false;

  for (int i = 0; i < ArraySize(HistoryOrders); i++){
    if(HistoryOrders[i].comment == comment){
      if(HistoryOrders[i].entry == DEAL_ENTRY_IN && dealEntry == DEAL_ENTRY_IN)
        return true;
      else if(HistoryOrders[i].entry != DEAL_ENTRY_IN && dealEntry != DEAL_ENTRY_IN) //DEAL ENTRY OUT
        return true;
    } 
  }
  return false; // Add a return statement here
}

//+------------------------------------------------------------------+
long FindOrdersHistoryByPositionIdLong(const ulong positionID, int dealEntry = DEAL_ENTRY_IN){
  for (int i = ArraySize(HistoryOrders) -1; i >= 0; i--){
    if (HistoryOrders[i].positionID == positionID){
      if(HistoryOrders[i].entry == DEAL_ENTRY_IN && dealEntry == DEAL_ENTRY_IN)
        return HistoryOrders[i].ticketSlave;    
      else if(HistoryOrders[i].entry != DEAL_ENTRY_IN && dealEntry != DEAL_ENTRY_OUT) //DEAL ENTRY OUT
        return HistoryOrders[i].ticketSlave;    
    }
  }   
  return INVALID_HANDLE; // Add a return statement here
}

//+------------------------------------------------------------------+
bool FindOrdersHistoryByPositionIdBool(const ulong positionID, int dealEntry = DEAL_ENTRY_IN){
  for (int i = ArraySize(HistoryOrders) -1; i >= 0; i--){
    if (HistoryOrders[i].positionID == positionID){
      if(HistoryOrders[i].entry == DEAL_ENTRY_IN && dealEntry == DEAL_ENTRY_IN)
        return true;
      else if(HistoryOrders[i].entry != DEAL_ENTRY_IN && dealEntry != DEAL_ENTRY_OUT) //DEAL ENTRY OUT
        return true;
    }
  }   
  return false; // Add a return statement here
}

//+------------------------------------------------------------------+
bool IsDemoMQL4(){
  if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO)
    return(true);
  else
    return(false);
}

//+------------------------------------------------------------------+
string JsonOrders(OrderStruct &orders[], const string name){
  long totalOrders, total;
  string json = "{\"" + name + "\":[";  // Corrigido para incluir a variável name corretamente
  
  HistorySelect(0, TimeToUse());
  if(name == "HistoryOrders" && LibSettings.appSendOrdersHistory == true)    
    total = HistoryDealsTotal() -1;
  else if(name == "HistoryOrders")
    total = 30;
  else
    total = ArraySize(orders);
    
  long totalDeals = ArraySize(orders);
  
  bool first = true;
  long count = 0;
  for (long i = 0;(i < totalDeals && count < total); i++){ 
    if(name == "HistoryOrders"){
      if(orders[i].entry != DEAL_ENTRY_IN){
        UpdateHistoryObj(orders[i]);
        count +=1;
      } else if(orders[i].entry == DEAL_ENTRY_IN)
        continue;
    }    
    
    if (!first)
      json += ",";
      
    json += JsonOrderStruct(orders[i]);
    first = false;
  }
  
  if(name == "HistoryOrders"){
    if(LibSettings.appSendOrdersHistory)
      totalOrders = count;
    else
      totalOrders = HistoryDealsTotal();
      
    json += "]"; 
    json += ",\""+ name + "Count\":\"" + IntegerToString(totalOrders) + "\"";
    json += ",\""+ name + "Profit\":\"" + DoubleToString(GetProfitTotalHistoryOrders(), 2) + "\"}";                     
  } else{
    totalOrders = PositionsTotal();
    json += "]}";
  }
  return json;  
}

//+------------------------------------------------------------------+
string JsonOrderStruct(OrderStruct &order){
  int digits = int(order.symbolDigits);
  string json = StringFormat(
      "{"
      "\"ticketMaster\":%s, "
      "\"ticketSlave\":%s, "
      "\"ticketDeal\":%s, "
      "\"positionID\":%s, "
      "\"type\":%d, "
      "\"entry\":%d, "
      "\"traceID\":%d, "
      "\"slaveID\":%d, "
      "\"magicNumber\":%d, "
      "\"transactionID\":%d, "
      "\"slipPage\":%d, "
      "\"symbolDigits\":%d, "
      "\"timeZone\":%d, "
      "\"profit\":%s, "
      "\"priceOpen\":%s, "
      "\"priceClose\":%s, "
      "\"stopLoss\":%s, "
      "\"takeProfit\":%s, "
      "\"volume\":%s, "
      "\"commission\":%s, "
      "\"fee\":%s, "
      "\"swap\":%s, "
      "\"mae\":%s, "
      "\"mfe\":%s, "
      "\"state\":\"%s\", "
      "\"metaAction\":\"%s\", "
      "\"metaState\":\"%s\", "
      "\"metaMessage\":\"%s\", "
      "\"symbol\":\"%s\", "
      "\"comment\":\"%s\", "
      "\"openAt\":\"%s\", "
      "\"closeAt\":\"%s\", "
      "\"timeGMT\":\"%s\", "
      "\"timeTrader\":\"%s\"" 
      "}",
      IntegerToString(order.ticketMaster),
      IntegerToString(order.ticketSlave),
      IntegerToString(order.ticketDeal),
      IntegerToString(order.positionID),
      order.type,
      order.entry,
      order.traceID,
      order.slaveID,
      order.magicNumber,
      order.transactionID,
      order.slipPage,
      order.symbolDigits,
      order.timeZone,
      DoubleToString(order.profit, digits),
      DoubleToString(order.priceOpen, digits),
      DoubleToString(order.priceClose, digits),
      DoubleToString(order.stopLoss, digits),
      DoubleToString(order.takeProfit, digits),
      DoubleToString(order.volume, 2),
      DoubleToString(order.commission, 2),
      DoubleToString(order.fee, 2),
      DoubleToString(order.swap, 2),
      DoubleToString(order.mae, 2),
      DoubleToString(order.mfe, 2),
      order.state,
      order.metaAction,
      order.metaState,
      order.metaMessage,
      order.symbol,
      order.comment,
      order.openAt,
      order.closeAt,
      order.timeGMT,
      order.timeTrader
      );
  return json;
}

//+------------------------------------------------------------------+
string JsonMerge(const string &historyJson, const string &positionJson){
    // Remover as chaves externas
    string trimmedHistory = StringSubstr(historyJson, 1, StringLen(historyJson) - 2);
    string trimmedPosition = StringSubstr(positionJson, 1, StringLen(positionJson) - 2);
    string mergedJson = "{" + trimmedHistory + "," + trimmedPosition + "}";
    return mergedJson;
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
bool ParseMessage(const string message, string &orderdataparse[]){
  if (message == "")
    return false;

  int size = StringSplit(message, '|', orderdataparse);
  return true;
}

//+------------------------------------------------------------------+
void SendLogFileToServer() {  
  string logEntry = StringFormat("Account Balance: %s - Equity: %s - Margin: %s - Free Margin: %s",
                                 DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),     2),
                                 DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),      2),
                                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),      2),
                                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2));
  SaveLogToFile(logEntry);

  if(DebugMode && DebugModeLevel > 2){
    SaveLogToFile("mt5_terminal_path: " + TerminalInfoString(TERMINAL_PATH));
    SaveLogToFile("mt5_terminal_data_path: " + TerminalInfoString(TERMINAL_DATA_PATH));
    SaveLogToFile("mt5_commondata_path: " + TerminalInfoString(TERMINAL_COMMONDATA_PATH));
  }

  string data = ReadLogToString(LogFileName);
  
  //if(ApiTrasmitLogFile(LogFileName))
  if(ApiData(LogFileName, data))
    AddCommentOnChart("Enviando arquivo de log: \"" + LogFileName + "\" para o servidor");
  else
    AddCommentOnChart("Error no envio do arquivo de log: \"" + LogFileName + "\" para o servidor");
}

//+------------------------------------------------------------------+
bool SendMessageToFile(string message, string const meta_state)
 {
  string InpFileName = "signal_slave.txt";  // file name
  string InpDirectoryName = "Data"; // directory name
  int file_handle = FileOpen(InpDirectoryName + "//" + InpFileName, FILE_READ | FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_SHARE_READ | FILE_SHARE_WRITE);
  if(file_handle != INVALID_HANDLE)
   {
    FileSeek(file_handle, 0, SEEK_END);
    message = StringFormat("%s; %s; %s", message, meta_state, TimeToString(TimeCurrent()));
    FileWriteString(file_handle, message + "\r\n");
    FileClose(file_handle);
    // PrintFormat("%s file was write", InpFileName);
    return true;
   }
  else
    PrintFormat("Failed to open %s file, Error code = %d", InpFileName, GetLastError());
  return false;
 }

//+------------------------------------------------------------------+
string ReadLastLine(string fileName) {
  int fileHandle = FileOpen(fileName, FILE_READ | FILE_SHARE_READ | FILE_ANSI);
  if (fileHandle != INVALID_HANDLE) {
      string lastLine = "";
      string currentLine;
      while (!FileIsEnding(fileHandle)) {
          currentLine = FileReadString(fileHandle);
          if (currentLine != "")
              lastLine = currentLine; // Armazena a última linha não vazia lida
      }
      FileClose(fileHandle);
      return lastLine;
  } else {
      PrintFormat("Failed to open %s file, Error code = %d", fileName, GetLastError());
      return "";
  }
}

//+------------------------------------------------------------------+
string ReadLogToString(string fileName){
  int fileHandle = FileOpen(fileName, FILE_READ | FILE_SHARE_READ | FILE_ANSI);
  if (fileHandle != INVALID_HANDLE){
   string fileContent = "";
   while (!FileIsEnding(fileHandle)){
       string line = FileReadString(fileHandle);
       fileContent += line + "\r\n"; // Adiciona cada linha ao conteúdo
   }
   FileClose(fileHandle);
   return fileContent;
  } else {
   PrintFormat("Failed to open %s file, Error code = %d", fileName, GetLastError());
   return "";
  }
}

//+------------------------------------------------------------------+
string RemoveSpecialChars(string inputString){
  string resultString = "";
  int inputLength = StringLen(inputString);
  uchar charArray[];

  for(int i = 0; i < inputLength; i++){
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
string ToUpperCase(string str){
  StringToUpper(str);
  return str;
}

////+------------------------------------------------------------------+
//double GetFeesOrderHistory(const long ticket_deal){
//  double fee = HistoryDealGetDouble(ticket_deal, DEAL_FEE);
//  double swap = HistoryDealGetDouble(ticket_deal, DEAL_SWAP);
//  double comission = HistoryDealGetDouble(ticket_deal, DEAL_COMMISSION);
//  double fees = comission * 2 + swap + fee;
//  return fees;
//}
 
//+------------------------------------------------------------------+
void UpdateHistoryObj(OrderStruct &order){
  long iH = FindOrdersHistoryByPositionIDIndex(order.positionID , DEAL_ENTRY_IN);
  if(iH >=0){
    order.type        = HistoryOrders[iH].type;
    order.priceOpen   = HistoryOrders[iH].priceOpen;
    order.openAt      = HistoryOrders[iH].openAt;
    order.swap       += HistoryOrders[iH].swap;
    order.fee        += HistoryOrders[iH].fee;
    order.commission += HistoryOrders[iH].commission;
  } 
  long iP = FindOrdersPositionByPositionIDIndex(order.positionID);
  if(iP >=0){
    order.mfe         = PositionOrders[iP].mfe;
    order.mae         = PositionOrders[iP].mae;
  }     
}

//+------------------------------------------------------------------+
void UpdatePositionOrders(){
  if(LibSettings.appExpertName == "imentore_slave")
    UpdateSlavePositionOrders();
  else if(LibSettings.appExpertName == "imentore_copy")
    UpdateCopyPositionOrders();
}

//+------------------------------------------------------------------+
void UpdateHistoryOrders(){
  HistorySelect(0, TimeToUse());
  
  int ii         = 0;
  int totalDeals = HistoryDealsTotal() -1;  
  
  if(totalDeals == ArraySize(HistoryOrders))
    return;
   
  ArrayResize(HistoryOrders, totalDeals);
  
  for (int i = totalDeals; (i > 0); i--){
    long dealTicket = long(HistoryDealGetTicket(i));
    long positionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

    if(positionID == 0)
      continue;
 
    // OrderObj *order = new OrderObj(positionID);
    HistoryOrders[ii].symbol        = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
    HistoryOrders[ii].ticketDeal    = HistoryDealGetInteger(dealTicket, DEAL_TICKET);
    if(LibSettings.appExpertKind == "copy"){
      HistoryOrders[ii].ticketSlave   = 0;
      HistoryOrders[ii].ticketMaster  = positionID;
    } else if(LibSettings.appExpertKind == "slave"){
      HistoryOrders[ii].ticketSlave   = positionID;
      HistoryOrders[ii].ticketMaster  = (long)HistoryDealGetString(dealTicket, DEAL_COMMENT);       
    }
    HistoryOrders[ii].positionID    = positionID;
    HistoryOrders[ii].type          = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
    HistoryOrders[ii].entry         = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    HistoryOrders[ii].magicNumber   = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
    
    if(HistoryOrders[ii].entry == DEAL_ENTRY_IN){
      HistoryOrders[ii].priceOpen   = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      HistoryOrders[ii].openAt      = TimeToString(HistoryDealGetInteger(dealTicket, DEAL_TIME), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      HistoryOrders[ii].state       = "open";
    } else {
      HistoryOrders[ii].priceClose  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      HistoryOrders[ii].closeAt     = TimeToString(HistoryDealGetInteger(dealTicket, DEAL_TIME), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      HistoryOrders[ii].state       = "closed";
    }
    HistoryOrders[ii].metaAction    = "";
    HistoryOrders[ii].metaState     = "";
    HistoryOrders[ii].metaMessage   = "";
    
    HistoryOrders[ii].stopLoss      = HistoryDealGetDouble(dealTicket, DEAL_SL);
    HistoryOrders[ii].takeProfit    = HistoryDealGetDouble(dealTicket, DEAL_TP);
    HistoryOrders[ii].profit        = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
    HistoryOrders[ii].volume        = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
    HistoryOrders[ii].commission    = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
    HistoryOrders[ii].fee           = HistoryDealGetDouble(dealTicket, DEAL_FEE);
    HistoryOrders[ii].swap          = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
    HistoryOrders[ii].symbolDigits  = SymbolInfoInteger(HistoryOrders[ii].symbol,SYMBOL_DIGITS);
    HistoryOrders[ii].comment       = HistoryDealGetString(dealTicket, DEAL_COMMENT); 
    HistoryOrders[ii].timeGMT       = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    HistoryOrders[ii].timeTrader    = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    HistoryOrders[ii].slipPage      = LibSettings.appSlipPage;
    ii +=1;
  }
  ArrayResize(HistoryOrders, ii);
}

//+------------------------------------------------------------------+
void UpdatePendingOrders(){
  int ii = 0;
  int total = OrdersTotal();
  ArrayResize(PendingOrders, total);
  
  for(int i = 0; i < total; i++){
    long  ticket           = long(OrderGetTicket(i));
        
    string symbol          = OrderGetString(ORDER_SYMBOL);
    int    symbol_digit    = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    double sym_volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double sym_point       = SymbolInfoDouble(symbol, SYMBOL_POINT);              
       
    if(LibSettings.appExpertKind == "copy"){
      PendingOrders[ii].ticketSlave   = 0;
      PendingOrders[ii].ticketMaster  = ticket;
    } else if(LibSettings.appExpertKind == "slave"){
      PendingOrders[ii].ticketSlave   = ticket;
      PendingOrders[ii].ticketMaster  = (long)OrderGetString(ORDER_COMMENT);       
    }    
    
    long type;
    OrderInfo.InfoInteger(ORDER_TYPE, type);
    
    if(type < 2)
      continue;
    
    PendingOrders[ii].symbol       = symbol;
    PendingOrders[ii].positionID   = ticket;
    PendingOrders[ii].ticketDeal   = OrderGetInteger(ORDER_TICKET);
    PendingOrders[ii].type         = OrderGetInteger(ORDER_TYPE);
    PendingOrders[ii].priceOpen    = OrderGetDouble(ORDER_PRICE_OPEN);
    PendingOrders[ii].priceClose   = 0;
    PendingOrders[ii].volume       = OrderGetDouble(ORDER_VOLUME_CURRENT);
    PendingOrders[ii].profit       = 0;
    PendingOrders[ii].fee          = 0;
    PendingOrders[ii].commission   = 0;
    PendingOrders[ii].swap         = 0;
    PendingOrders[ii].entry        = 0;
    PendingOrders[ii].stopLoss     = OrderGetDouble(ORDER_SL);
    PendingOrders[ii].takeProfit   = OrderGetDouble(ORDER_TP);
    PendingOrders[ii].state        = "pending";
    PendingOrders[ii].metaAction   = "";
    PendingOrders[ii].metaState    = OrderInfo.TypeDescription();
    PendingOrders[ii].metaMessage  = "";    
    PendingOrders[ii].mae          = 0;
    PendingOrders[ii].mfe          = 0;
    PendingOrders[ii].openAt       = TimeToString(OrderGetInteger(ORDER_TIME_SETUP), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    PendingOrders[ii].closeAt      = "";
    PendingOrders[ii].timeGMT      = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    PendingOrders[ii].timeTrader   = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    PendingOrders[ii].timeZone     = long((TimeGMT() - TimeTradeServer()) / 3600);
    PendingOrders[ii].symbolDigits = symbol_digit;
    PendingOrders[ii].magicNumber  = OrderGetInteger(ORDER_MAGIC);
    PendingOrders[ii].comment      = OrderGetString(ORDER_COMMENT);    
    PendingOrders[ii].slipPage     = LibSettings.appSlipPage;
    ii += 1;
   }
   ArrayResize(PendingOrders, ii);
 }

//+------------------------------------------------------------------+
void UpdateCopyPositionOrders(){
  int total = PositionsTotal();
  ArrayResize(PositionOrders, total);
  
  for(int i = 0; i < total; i++){
    long  positionID       = long(PositionGetTicket(i));
    string symbol          = PositionGetString(POSITION_SYMBOL);
    int    symbol_digit    = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    double sym_volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double sym_point       = SymbolInfoDouble(symbol, SYMBOL_POINT);   
    
    long iHistory = FindOrdersStructIndex(HistoryOrders, positionID);
       
    if(LibSettings.appExpertKind == "copy"){
      PositionOrders[i].ticketSlave   = 0;
      PositionOrders[i].ticketMaster  = positionID;
    } else if(LibSettings.appExpertKind == "slave"){
      PositionOrders[i].ticketSlave   = positionID;
      PositionOrders[i].ticketMaster  = (long)PositionGetString(POSITION_COMMENT);       
    }    
    
    PositionOrders[i].symbol       = symbol;
    PositionOrders[i].positionID   = positionID;
    if(iHistory >=0)
      PositionOrders[i].ticketDeal   = HistoryOrders[iHistory].ticketDeal;
    else
      PositionOrders[i].ticketDeal   = 0;
    
    PositionOrders[i].type         = PositionGetInteger(POSITION_TYPE);
    PositionOrders[i].priceOpen    = PositionGetDouble(POSITION_PRICE_OPEN);
    PositionOrders[i].priceClose   = 0;
    PositionOrders[i].volume       = PositionGetDouble(POSITION_VOLUME);
    PositionOrders[i].profit       = PositionGetDouble(POSITION_PROFIT);
    PositionOrders[i].fee          = 0;
    PositionOrders[i].commission   = 0;
    PositionOrders[i].swap         = PositionGetDouble(POSITION_SWAP);
    PositionOrders[i].entry        = 0;
    PositionOrders[i].stopLoss     = PositionGetDouble(POSITION_SL);
    PositionOrders[i].takeProfit   = PositionGetDouble(POSITION_TP);
    PositionOrders[i].state        = "opened";
    PositionOrders[i].metaAction   = "";
    PositionOrders[i].metaState    = "";
    PositionOrders[i].metaMessage  = "";   

    PositionOrders[i].mae          = CalculateMFEMAE(symbol, positionID, "mae", 0);
    PositionOrders[i].mfe          = CalculateMFEMAE(symbol, positionID, "mfe", 0);

    PositionOrders[i].openAt       = TimeToString(PositionGetInteger(POSITION_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    PositionOrders[i].closeAt      = "";
    PositionOrders[i].timeGMT      = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    PositionOrders[i].timeTrader   = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    PositionOrders[i].timeZone     = long((TimeGMT() - TimeTradeServer()) / 3600);
    PositionOrders[i].symbolDigits = symbol_digit;    
    PositionOrders[i].magicNumber  = PositionGetInteger(POSITION_MAGIC);
    PositionOrders[i].comment      = PositionGetString(POSITION_COMMENT);
    PositionOrders[i].slipPage     = LibSettings.appSlipPage;
   }
 }

//+------------------------------------------------------------------+
int UpdateSlavePositionOrders(){ 
  int orderdataCount = ArraySize(ResponseData);
  if (orderdataCount == 0){
    ArrayResize(PositionOrders, 0);
    return -1;
  }

  ArrayResize(PositionOrders, orderdataCount);
  for (int i = 0; i < orderdataCount; i++){
    string orderdataparse[];
    if (!ParseMessage(ResponseData[i], orderdataparse))
      return -3; // error code indicating parsing failed

    if (ArraySize(orderdataparse) < 17) // check for sufficient data
      return -4;                        // error code indicating insufficient dat
      
    string symbol                    = orderdataparse[12];
    PositionOrders[i].ticketSlave    = StringToInteger(orderdataparse[2]);
    PositionOrders[i].ticketMaster   = StringToInteger(orderdataparse[1]);
    PositionOrders[i].symbol         = symbol;
    PositionOrders[i].positionID     = StringToInteger(orderdataparse[2]);
    PositionOrders[i].ticketDeal     = StringToInteger(orderdataparse[13]);
    PositionOrders[i].type           = StringToInteger(orderdataparse[0]);
    PositionOrders[i].priceOpen      = NormalizeDouble(StringToDouble(orderdataparse[7]), int(SymbolInfoInteger(orderdataparse[12], SYMBOL_DIGITS)));
    PositionOrders[i].priceClose     = 0;
    PositionOrders[i].volume         = StringToDouble(orderdataparse[8]);
    PositionOrders[i].profit         = 0;
    PositionOrders[i].fee            = 0;
    PositionOrders[i].commission     = 0;
    PositionOrders[i].swap           = 0;
    PositionOrders[i].entry          = 0;
    PositionOrders[i].stopLoss       = NormalizeNumber(orderdataparse[9], orderdataparse[12]);
    PositionOrders[i].takeProfit     = NormalizeNumber(orderdataparse[10], orderdataparse[12]);
    PositionOrders[i].state          = orderdataparse[11];
    PositionOrders[i].mae            = 0;
    PositionOrders[i].mfe            = 0;
    
    PositionOrders[i].openAt         = "";
    PositionOrders[i].closeAt        = "";
    PositionOrders[i].timeGMT        = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    PositionOrders[i].timeTrader     = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    PositionOrders[i].timeZone       = long((TimeGMT() - TimeTradeServer()) / 3600);
    PositionOrders[i].symbolDigits   = int(SymbolInfoInteger(PositionOrders[i].symbol, SYMBOL_DIGITS));
    PositionOrders[i].magicNumber    = StringToInteger(orderdataparse[5]);
    PositionOrders[i].comment        = orderdataparse[15];

    PositionOrders[i].traceID        = StringToInteger(orderdataparse[3]);
    PositionOrders[i].slaveID        = StringToInteger(orderdataparse[4]);
    PositionOrders[i].transactionID  = StringToInteger(orderdataparse[6]);
    PositionOrders[i].secondsAgo     = StringToInteger(orderdataparse[14]);
    PositionOrders[i].createdAt      = StringToInteger(orderdataparse[16]);
    PositionOrders[i].contractVolume = StringToDouble(orderdataparse[17]);
    PositionOrders[i].slipPage       = LibSettings.appSlipPage;
  }
  return 0; // return 0 indicating success
}

//+------------------------------------------------------------------+
double GetProfitTotalHistoryOrders(){
  double profit = 0;
  for (int i = ArraySize(HistoryOrders) -1; i >= 0; i--){    
    if(HistoryOrders[i].positionID == 0 || HistoryOrders[i].entry == DEAL_ENTRY_IN)
      continue;
    
    profit += HistoryOrders[i].profit;
  }
  return profit; // Add a return statement here
}

//+------------------------------------------------------------------+
double GetOrderProfitByTicketID(long ticketid){
  int    tries  = 0;
  double result = 0;

  while(tries < 50 && result == 0){
    if(PositionSelectByTicket(ticketid))
      result = PositionGetDouble(POSITION_PROFIT);
    else{ 
      long deal_ticket = FindDealOutByTicketId(ticketid);
      
      if(deal_ticket != INVALID_HANDLE){
        result = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);             
        if(tries > 0 && result == 0)
          Sleep(SleepTries * tries);
      }
    }
    tries++; 
  }
  return result;
}

//+------------------------------------------------------------------+
double GetOrderVolumeByTicketId(long ticketid){
  int    tries  = 0;
  double result = 0;

  while(tries < 50 && result == 0){
    if(PositionSelectByTicket(ticketid))
      result = PositionGetDouble(POSITION_VOLUME);
    else{ 
      long deal_ticket = FindDealOutByTicketId(ticketid);
      
      if(deal_ticket != INVALID_HANDLE){
        result = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);              
        if(tries > 0 && result == 0)
          Sleep(SleepTries * tries);
      }
    }
    tries++; 
  }
  return result;
}

//+------------------------------------------------------------------+
double GetOrderTakeProfitByTicketId(long ticketid){
  int    tries  = 0;
  double result = 0;

  while(tries < 50 && result == 0){
    if(PositionSelectByTicket(ticketid))
      result = PositionGetDouble(POSITION_TP);
    else{ 
      long deal_ticket = FindDealOutByTicketId(ticketid);
      
      if(deal_ticket != INVALID_HANDLE){
        result = HistoryDealGetDouble(deal_ticket, DEAL_TP);              
        if(tries > 0 && result == 0)
          Sleep(SleepTries * tries);
      }
    }
    tries++; 
  }
  return result;
}

//+------------------------------------------------------------------+
double GetOrderStopLossByTicketId(long ticketid){
  int    tries  = 0;
  double result = 0;

  while(tries < 50 && result == 0){
    if(PositionSelectByTicket(ticketid))
      result = PositionGetDouble(POSITION_SL);
    else{ 
      long deal_ticket = FindDealOutByTicketId(ticketid);
      
      if(deal_ticket != INVALID_HANDLE){
        result = HistoryDealGetDouble(deal_ticket, DEAL_SL);              
        if(tries > 0 && result == 0)
          Sleep(SleepTries * tries);
      }
    }
    tries++; 
  }
  return result;
}

//+------------------------------------------------------------------+
ulong ticketID(OrderStruct &order){ 
  return (LibSettings.appExpertName == "imentore_copy"? order.ticketMaster : order.ticketSlave);
}

//+------------------------------------------------------------------+
long TimeToUse() {
    // Inicialize a variável com um valor inicial baixo
    long time = 0;

    // Obtenha os diferentes tempos disponíveis
    long timeTrader  = TimeTradeServer();  // Tempo do servidor de negociação
    long timeCurrent = TimeCurrent();      // Tempo atual do servidor para o símbolo ativo
    long timeLocal   = TimeLocal();        // Tempo local da máquina do usuário
    long timeGMT     = TimeGMT();          // Tempo GMT (Greenwich)
    
    // Use a função iTime para obter o tempo do último candle no gráfico atual
    long lastCandle = iTime(Symbol(), PERIOD_CURRENT, 0);

    // Comparar todos os tempos e encontrar o maior
    if (timeTrader > time)
        time = timeTrader;
    if (timeCurrent > time)
        time = timeCurrent;
    if (timeLocal > time)
        time = timeLocal;
    if (timeGMT > time)
        time = timeGMT;
    if (lastCandle > time)
        time = lastCandle;

    // Retornar o maior valor de tempo
    return time;
}

//+------------------------------------------------------------------+
bool TrasmitOrders(const string name = "orders", string jason_message = "", bool change = true){
  string message, positionJson, historyJson, pendingJson;
  UpdateHistoryOrders();
  UpdatePendingOrders();
  
  if(StringLen(jason_message) <= 0){    
    historyJson   = JsonOrders(HistoryOrders, "HistoryOrders");        
    UpdatePositionOrders();        
    positionJson  = JsonOrders(PositionOrders, "PositionOrders");  
    jason_message = JsonMerge(historyJson, positionJson);   
    
    if(LibSettings.appExpertName == "imentore_copy"){
      pendingJson  = JsonOrders(PendingOrders, "PendingOrders");  
      jason_message = JsonMerge(jason_message, pendingJson);                  
    }
          
    if(LibSettings.appSendOrdersHistory){
      AddCommentOnChart("SendHistoryOrder atualizado de: " + IntegerToString(LibSettings.appSendOrdersHistory) + " para: " + IntegerToString(false));
      LibSettings.appSendOrdersHistory = false;
    }    
  }
  
  ArrayFree(ResponseData);
  if(ApiData(name, jason_message)){
    message = "Sent orders to server - Status: OK";
    return true;
  } else
    message = "Sent orders to server - Status ERROR: " + IntegerToString(GetLastError());

  if(DebugMode)
    AddCommentOnChart(message);    
    
  return false;
}

//+------------------------------------------------------------------+
void SetCommentImentore(bool print_log = false, bool set_log = false){
  string datetime_now = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
  string message = StringFormat("Iniciando Expert %s %s - Update %s - Date: %s", StringToCameCase(LibSettings.appExpertName), LibSettings.appVersion, LibSettings.appVersionUpdate, datetime_now);
  //if (LibSettings.InputEnvironmentLocal || LibSettings.appEnvironmentLocal)
  message += " - LocalVersion: " + LibSettings.appVersionLocal;
  AddCommentOnChart(message, 1, print_log, set_log);
}

//+------------------------------------------------------------------+ 