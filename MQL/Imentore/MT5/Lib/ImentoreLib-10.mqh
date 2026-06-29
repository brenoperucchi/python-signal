//+------------------------------------------------------------------+
//|                                                  ImentoreLib.mqh |
//|                                     Copyright 2023, Imentore.Co. |
//|                                         https://www.imentore.com |
//+------------------------------------------------------------------+
#property copyright   "ImentoreLib - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

#define LIB_VERSION  "1"
#define LIB_UPDATE  "10"

#include <ImentoreCommon.mqh>
#include <ImentoreSettings.mqh>

Settings* LibSettings = Settings::Instance();

int      MilliSecondsTimer       = 2400;
int      MilliSecondsTick        = 2400;
bool     DebugMode               = false;         // DebugMode - Admin only (default is false)
bool     EventOnTimer            = true;
bool     EventOnTick             = false;
long     FreezeMaxTimeDifference = 30;            // Máximo tempo de diferenca em segundos
long     TimeToCheckServer       = 30; 
datetime FreezeLastServerTime    = TimeCurrent(); // Armazena o último tempo do servidor
long     DebugModeLevel          = 1;
bool     MfeMaeDisplay           = true;
int      TimeCurrentAgo          = int(TimeLocal());
long     ReachMfeTarget          = 0;             // MFE Target
long     ReachLossSet            = 0;             // Loss Target
bool     FirstRun                = true;
bool     SendOrdersHistory       = false;
bool     CloseAllOrders          = false;

// string   LibSettings.fExpertName();


//CJAVal WebServiceJason;

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
        api_event_on_tick = false;
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
        api_milliseconds_timer = 2400;
        api_milliseconds_tick = 2400;
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
        if (StringSubstr(value, 0, 1) == "\"") {
            value = StringSubstr(value, 1, StringLen(value) - 2);
        }

        return value;
    }
};



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
bool ApiTrasmitInformation(const string message, const string action)
{
    string url, server_url;
    string comment;
    string request = "POST";
    string cookie = NULL;
    string headers;
    int response = 0;
    char post[];
    char result[];
    int count = 0;
    
    if(action == "orders_history"){
      server_url = LibSettings.apiServerUrl +"/api/"+ LibSettings.appVersion +"/"+ LibSettings.appExpertKind +"/" + action + "/post";
      url = server_url + "/" + LibSettings.appExpertName + "/" + LibSettings.fExpertName() + "/"  + LibSettings.accountServerName + "/" + LibSettings.accountLogin + "/" + AccountMarginMode();
   
    } else {
        
      server_url = LibSettings.apiServerUrl +"/api/"+ LibSettings.apiVersion +"/"+ LibSettings.appExpertKind +"/post";
      url = server_url + "/" + LibSettings.appExpertName + "/" + LibSettings.fExpertName() + "/"  + LibSettings.accountServerName + "/" + LibSettings.accountLogin + "/" + AccountMarginMode();
    }

    ResetLastError();
    StringToCharArray(message, post, 0, StringLen(message));

    while(response != 201 && count <= 5)
    {
      count++;

      if(MQLInfoInteger(MQL_TESTER)){
        SendMessageToFile(message, action);
        return true;
      }
      else{
        response = WebRequest("POST", url, cookie, NULL, 135000, post, 0, result, headers);
      }

      if(response == 201){
        string response_string = CharArrayToString(result);
        if(StringFind("OK|OK|OK", response_string) != -1)
          return true;          
      } else {
        comment = "Api código de erro: " + IntegerToString(GetLastError()) + ",  resposta: " + IntegerToString(response);
        AddCommentOnChart(comment);
      }

    }
    comment = "Conexao Servidor - Resposta: " + IntegerToString(response) + " - GetLastError: " + IntegerToString(GetLastError()) + " - Action: " + action;
    
    AddCommentOnChart(comment);
    return false;
}

//+------------------------------------------------------------------+
bool ApiTransmitData(string name, string content, string action = NULL) {
  int res;
  char postData[];
  char responseData[];
  string server_url, url;
  
  string boundary = "-------Jyecslin9mp8RdKV";

  // O código original continua aqui para lidar com arquivos reais
  server_url = LibSettings.apiServerUrl +"/api/"+ LibSettings.apiVersion +"/"+ LibSettings.appExpertKind +"/" + name + "/post";
  url = server_url + "/" + LibSettings.appExpertName + "/" + LibSettings.fExpertName() + "/"  + LibSettings.accountServerName + "/" + LibSettings.accountLogin + "/" + AccountMarginMode();
  
  // Cabeçalho para multipart/form-data
  string header = StringFormat("Content-Type: multipart/form-data; boundary=%s\r\n", boundary);
  
  // Montando o corpo do POST
  string body = StringFormat("--%s\r\nContent-Disposition: attachment; name=\"logfile\"; filename=\"%s\"\r\nContent-Type: text/html; charset=utf-8\r\n\r\n", boundary, name);
  StringToCharArray(body, postData); // Converte o cabeçalho e início do corpo para postData
  
  // Concatena o conteúdo no postData
  int bodyStart = ArraySize(postData);
  ArrayResize(postData, bodyStart + StringLen(content) + StringLen("\r\n--" + boundary + "--\r\n"));
  StringToCharArray(content, postData, bodyStart, StringLen(content)); // Copia conteúdo para postData
  
  // Finaliza o corpo do POST
  StringToCharArray("\r\n--" + boundary + "--\r\n", postData, bodyStart + StringLen(content));

  // Realiza a requisição HTTP POST
  for(int attempt = 0; attempt < 3; attempt++) {
      res = WebRequest("POST", url, header, 0, postData, responseData, header);
      if(res == 201) {
          string responseString = CharArrayToString(responseData);
          if(StringFind(responseString, "OK|OK|OK") != -1) {
              return true;
          }
      } else {
          SaveLogToFile(StringFormat("Tentativa %d falhou. Erro: %d, Código de resposta: %d", attempt + 1, GetLastError(), res));
          Sleep(1000); // Espera antes de tentar novamente
      }
  }

  SaveLogToFile(StringFormat("Falha ao enviar dados. Último código de resposta: %d, Último erro: %d", res, GetLastError()));
  return false;
}

//+------------------------------------------------------------------+
bool ApiTrasmitLogFile(string filename) {
    string serverUrl = LibSettings.apiServerUrl + "/api/" + LibSettings.apiVersion + "/account/" + LibSettings.appExpertKind + "/post/logfile";
    string url = serverUrl + "/" + LibSettings.appExpertName + "/" + LibSettings.fExpertName() + "/" + LibSettings.accountServerName + "/" + LibSettings.accountLogin + "/" + AccountMarginMode();

    int res;
    char fileData[];
    char postData[];
    char responseData[];

    int fileHandle = FileOpen(filename, FILE_READ | FILE_BIN);
    string boundary = "-------Jyecslin9mp8RdKV";
    string header = StringFormat("Content-Type: multipart/form-data; boundary=%s\r\n", boundary);
    string body = StringFormat("--%s\r\n", boundary) +
                  "Content-Disposition: attachment; name=logfile; filename=\"" + filename + "\"\r\n" +
                  "Content-Type: text/html; charset=utf-8\r\n\r\n";
    int bodyStart = StringToCharArray(body, postData);                

    if(filename == "" || !FileIsExist(filename)) {
        SaveLogToFile(StringFormat("Arquivo não especificado ou não existe: ", filename));
        return false;
    }

    // Inicializa variáveis
    if(fileHandle < 0) {
        SaveLogToFile(StringFormat("Erro ao abrir o arquivo: ", filename, " Erro: ", GetLastError()));
        return false;
    }

    if(FileReadArray(fileHandle, fileData) != FileSize(fileHandle)) {
        FileClose(fileHandle);
        SaveLogToFile("Erro ao ler o arquivo: " + filename);
        return false;
    }
    FileClose(fileHandle);

    // Prepara dados para envio
    ArrayResize(postData, bodyStart + ArraySize(fileData) + StringLen("\r\n--" + boundary + "--\r\n"));
    ArrayCopy(postData, fileData, bodyStart, 0, ArraySize(fileData));
    StringToCharArray("\r\n--" + boundary + "--\r\n", postData, bodyStart + ArraySize(fileData));

    // Realiza a requisição
    for(int attempt = 0; attempt < 3; attempt++) {
        res = WebRequest("POST", url, header, 0, postData, responseData, header);
        if(res == 201) {
            string responseString = CharArrayToString(responseData);
            if(StringFind(responseString, "OK|OK|OK") != -1) {
                return true;
            }
        } else {
            SaveLogToFile(StringFormat("Tentativa ", attempt, 1, " falhou. Erro: ", GetLastError(), ", Código de resposta: ", res));
            Sleep(1000); // Aguarda um pouco antes de tentar novamente
        }
    }

    SaveLogToFile(StringFormat("Falha ao enviar o arquivo. Último código de resposta: ", res, ", Último erro: ", GetLastError()));
    return false;
}

//+------------------------------------------------------------------+
bool ApiRequestInformation(string &orderdata[], const string action)
{
    string comment;
    string request;
    string cookie = NULL;
    string headers;
    string serverHeaders;
    char   post[];
    char   result[];
    string str = "EnvironmentLocal=" + IntegerToString(LibSettings.appEnvironmentLocal);
    ArrayResize(post, StringToCharArray(str, post, 0, WHOLE_ARRAY, CP_UTF8) - 1);
    string server_url;
    string url;

    if(action == "store"){
        request = "POST";
        server_url = LibSettings.apiServerUrl + "/api/" + LibSettings.apiVersion + "/stores/config";
        url = server_url + "/" + LibSettings.appExpertName + "/" + LibSettings.fExpertName() + "/" + LibSettings.accountServerName + "/" + LibSettings.accountLogin + "/" + AccountMarginMode() ;
    }
    else if (action == "orders"){
        request = "POST";
        server_url = LibSettings.apiServerUrl + "/api/" + LibSettings.apiVersion + "/transactions/"+ LibSettings.appExpertKind +"/post";
        url = server_url + "/" + action + "/" + LibSettings.appExpertName + "/" + LibSettings.fExpertName() + "/" + LibSettings.accountServerName + "/" + LibSettings.accountLogin + "/" + AccountMarginMode() ;
    }
    int response = 0;
    bool internet_down = false;
    do{
        ResetLastError();
        response = WebRequest(request, url, headers, 5000, post, result, serverHeaders);

        if(DebugMode && DebugModeLevel > 1){
         string result2 = CharArrayToString(result);
         string message = (TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS) + " - ApiRequestInformation - WebRequest Response: " + result2 + " - Action: "+ action);
         Print(message);
         SaveLogToFile(message);
        }

        if(response != 1001 && internet_down){
            comment = "Conexao estabelecida";
            AddCommentOnChart(comment);
            internet_down = false;
        }

        if(response == -1){
            comment = "Api código de erro: " + IntegerToString(GetLastError());
            comment = "É necessário adicionar o endereco '" + ToUpperCase(LibSettings.apiServerUrl) + "' em Ferramentas->Opcões->Experts Advisores->URL WebRequest - Erro: " + IntegerToString(MB_ICONINFORMATION);
            AddCommentOnChart(comment);

            return false;
        }
        else if(response == 201){
            string result2 = CharArrayToString(result);
            int size = StringSplit(result2, '/', orderdata);
            return true;
        } else {
            comment = "Api código de erro: " + IntegerToString(GetLastError()) + ",  resposta: " + IntegerToString(response);
            AddCommentOnChart(comment);
        }

        internet_down = true;
        comment = "Verifique a sua conexao com a internet ou servidor fora temporariamente.";
        AddCommentOnChart(comment);
    }
    while(response != 201);

    comment = "Conexao Servidor - Resposta: " + IntegerToString(response) + " - GetLastError: " + IntegerToString(GetLastError()) + " - Action: " + action;
    AddCommentOnChart(comment);

    return false;
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

  string orderdata[];
  ApiResponse apiResponse;
  
  if (ApiRequestInformation(orderdata, "store")){
    string json = orderdata[0];
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

 if(apiResponse.api_event_on_timer != EventOnTimer){
    AddCommentOnChart("EventOnTimer atualizado de: " + string(EventOnTimer) + " para: " + string(apiResponse.api_event_on_timer));
    EventOnTimer = apiResponse.api_event_on_timer;  
  }

 if(apiResponse.api_event_on_tick != EventOnTick){
    AddCommentOnChart("EventOnTick atualizado de: " + string(EventOnTick) + " para: " + string(apiResponse.api_event_on_tick));
    EventOnTick = apiResponse.api_event_on_tick;  
  }

  if(LibSettings.appEnvironmentLocal != apiResponse.api_environment_local){
    AddCommentOnChart("EnvironmentLocal atualizado de: " + string(LibSettings.appEnvironmentLocal) + " para: " + string(apiResponse.api_environment_local));
    LibSettings.appEnvironmentLocal = apiResponse.api_environment_local;
  }

  if(LibSettings.appMilliSecondsTimer != apiResponse.api_milliseconds_timer){
    AddCommentOnChart("MilliSecondsTimer atualizado de: " + IntegerToString(LibSettings.appMilliSecondsTimer) + " para: " + IntegerToString(apiResponse.api_milliseconds_timer));
    LibSettings.appMilliSecondsTimer = int(apiResponse.api_milliseconds_timer);
    EventSetMillisecondTimer(LibSettings.appMilliSecondsTimer);
  }

  if(LibSettings.appReachMfeTarget != apiResponse.api_reach_mfe_target){
    AddCommentOnChart("ReachMfeTarget atualizado de: " + DoubleToString(LibSettings.appReachMfeTarget, 2) + " para: " + DoubleToString(apiResponse.api_reach_mfe_target, 2));
    //ReachMfeTargetBool  = false;
    LibSettings.appReachProfitDay      = 0;    
    LibSettings.appReachMfeTarget = int(apiResponse.api_reach_mfe_target);
  }  

  if(LibSettings.appReachLossSet != apiResponse.api_reach_loss_set){
    AddCommentOnChart("ReachLossSet atualizado de: " + DoubleToString(LibSettings.appReachLossSet, 2) + " para: " + DoubleToString(apiResponse.api_reach_loss_set, 2));

    LibSettings.appReachLossDay        = 0;    
    LibSettings.appReachLossSet = int(apiResponse.api_reach_loss_set);
  }

  if(DebugModeLevel != apiResponse.api_debug_mode_level){
    AddCommentOnChart("DebugModeLevel atualizado de: " + IntegerToString(DebugModeLevel) + " para: " + IntegerToString(apiResponse.api_debug_mode_level));
    DebugModeLevel = apiResponse.api_debug_mode_level;
  }

  if(SendOrdersHistory != apiResponse.api_send_orders_history){
    AddCommentOnChart("SendOrdersHistory atualizado de: " + IntegerToString(SendOrdersHistory) + " para: " + IntegerToString(apiResponse.api_send_orders_history));
    SendOrdersHistory = apiResponse.api_send_orders_history;
  }  

  if(CloseAllOrders != apiResponse.api_close_all_orders){
    AddCommentOnChart("CloseAllOrders atualizado de: " + IntegerToString(CloseAllOrders) + " para: " + IntegerToString(apiResponse.api_close_all_orders));
    CloseAllOrders = apiResponse.api_close_all_orders;    
  }

  if(MilliSecondsTick != apiResponse.api_milliseconds_tick){
    AddCommentOnChart("MilliSecondsTick atualizado de: " + IntegerToString(MilliSecondsTick) + " para: " + IntegerToString(apiResponse.api_milliseconds_tick));
    MilliSecondsTick = int(apiResponse.api_milliseconds_tick);
    EventSetMillisecondTimer(MilliSecondsTick);
  } 

  if(MfeMaeDisplay != apiResponse.api_mfe_mae_display && LibSettings.appExpertKind == "copy"){
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
  return changes;
 }

//+------------------------------------------------------------------+
void CheckFreeze(){
  if(FreezeMaxTimeDifference == 0)
    return;

  datetime currentServerTime = TimeCurrent(); // Pega o tempo atual do servidor
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
bool DetectEnvironment()
 {
  //LibSettings.fExpertName() = VERSION + "_" + VERSION_UPDATE;

  if(LibSettings.appEnvironmentLocal)
    LibSettings.apiServerUrl = "http://localhost:8080";

  if(!CheckServerInformations())
    return false;

  FirstRun = false;
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
      return long(deal_ticket);
   }

   return INVALID_HANDLE;
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
      return long(deal_ticket);
   }

   return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| IsDemoMQL4                                                       |
//+------------------------------------------------------------------+
bool IsDemoMQL4()
{
  if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO)
    return(true);
  else
    return(false);
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
//| SendLogFileToServer                                              |
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

  if(ApiTrasmitLogFile(LogFileName))
    AddCommentOnChart("Enviando arquivo de log: \"" + LogFileName + "\" para o servidor");
  else
    AddCommentOnChart("Error no envio do arquivo de log: \"" + LogFileName + "\" para o servidor");
}

//+------------------------------------------------------------------+
//|                                                                  |
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
//|                                                    |
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
//|                                                    |
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
//| ReadLogContent                                                   |
//+------------------------------------------------------------------+
string ReadLogToString(string fileName)
 {
   int fileHandle = FileOpen(fileName, FILE_READ | FILE_SHARE_READ | FILE_ANSI);
   if (fileHandle != INVALID_HANDLE)
   {
       string fileContent = "";
       while (!FileIsEnding(fileHandle))
       {
           string line = FileReadString(fileHandle);
           fileContent += line + "\r\n"; // Adiciona cada linha ao conteúdo
       }
       FileClose(fileHandle);
       return fileContent;
   }
   else
   {
       PrintFormat("Failed to open %s file, Error code = %d", fileName, GetLastError());
       return "";
   }
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
string ToUpperCase(string str){
  StringToUpper(str);
  return str;
}

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