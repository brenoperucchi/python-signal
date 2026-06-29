//+------------------------------------------------------------------+
//|                                                  ImentoreLib.mqh |
//|                                     Copyright 2023, Imentore.Co. |
//|                                         https://www.imentore.com |
//+------------------------------------------------------------------+
#property copyright   "ImentoreLib - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

#define LIB_VERSION  "1.00"
#define LIB_UPDATE  "08"

long   commentOnChartInitPosition[];
string commentOnChartInit[];
string commentOnChartTick[];

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

string   ExpertVersion;
string   LogFileName;

CJAVal WebServiceJason;


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
//| AddCommentOnChart                                                |
//+------------------------------------------------------------------+
long AddCommentOnChart(string newMessage, long line_item = 0, bool print_log = true, bool save_log = true){
  string sDate = TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS);
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
    for(int i = 0; i < ArraySize(commentOnChartInitPosition) - 1; i++){
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

  if(save_log)
    SaveLogToFile(newMessage);

  if(print_log)
    Print(newMessage);

  return line_item;
}

//+------------------------------------------------------------------+
//|                                                                  |
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
      server_url = SERVER +"/api/"+ API_VERSION +"/"+ EXPERT_KIND +"/" + action + "/post";
      url = server_url + "/" + EXPERTNAME + "/" + ExpertVersion + "/"  + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();
   
    } else {
        
      server_url = SERVER +"/api/"+ API_VERSION +"/"+ EXPERT_KIND +"/post";
      url = server_url + "/" + EXPERTNAME + "/" + ExpertVersion + "/"  + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();
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
//| Envia dados para o servidor                                      |
//+------------------------------------------------------------------+
bool ApiTransmitData(string filename, string content, string action = NULL) {
  int res;
  char postData[];
  char responseData[];
  string server_url, url;
  
  string boundary = "-------Jyecslin9mp8RdKV";

  // O código original continua aqui para lidar com arquivos reais
  server_url = SERVER +"/api/"+ API_VERSION +"/"+ EXPERT_KIND +"/" + filename + "/post";
  url = server_url + "/" + EXPERTNAME + "/" + ExpertVersion + "/"  + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();
  
  // Cabeçalho para multipart/form-data
  string header = StringFormat("Content-Type: multipart/form-data; boundary=%s\r\n", boundary);
  
  // Montando o corpo do POST
  string body = StringFormat("--%s\r\nContent-Disposition: attachment; name=\"logfile\"; filename=\"%s\"\r\nContent-Type: text/html; charset=utf-8\r\n\r\n", boundary, filename);
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
//| Envia um arquivo de log para o servidor                          |
//+------------------------------------------------------------------+
bool ApiTrasmitLogFile(string filename) {
    string serverUrl = SERVER + "/api/" + API_VERSION + "/account/" + EXPERT_KIND + "/post/logfile";
    string url = serverUrl + "/" + EXPERTNAME + "/" + ExpertVersion + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();

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
//| ApiRequestInformation                                            |
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

    string str = "EnvironmentLocal=" + IntegerToString(EnvironmentLocal);
    ArrayResize(post, StringToCharArray(str, post, 0, WHOLE_ARRAY, CP_UTF8) - 1);

    string server_url;
    string url;

    if(action == "store"){
        request = "POST";
        server_url = SERVER + "/api/" + API_VERSION + "/stores/config";
        url = server_url + "/" + EXPERTNAME + "/" + ExpertVersion + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode() ;
    }
    else if (action == "orders"){
        request = "POST";
        server_url = SERVER + "/api/" + API_VERSION + "/transactions/"+ EXPERT_KIND +"/post";
        url = server_url + "/" + action + "/" + EXPERTNAME + "/" + ExpertVersion + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode() ;
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
            comment = "É necessário adicionar o endereco '" + ToUpper(SERVER) + "' em Ferramentas->Opcões->Experts Advisores->URL WebRequest - Erro: " + IntegerToString(MB_ICONINFORMATION);
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
//| Check Store Conditions                                           |
//+------------------------------------------------------------------+
bool CheckServerInformations()
{
  int timeAgo = int(TimeLocal() - TimeCurrentAgo);
  
  if(timeAgo < TimeToCheckServer && FirstRun == false)
    return true;
  else
    TimeCurrentAgo = int(TimeLocal()); 
  
  bool changes                  = true;
  bool api_event_on_timer       = true;
  bool api_event_on_tick        = false;
  bool api_debug_mode           = false;
  bool api_store_state          = true;
  bool api_environment_local    = false;  // EnvironmentLocal
  bool api_mfe_mae_display      = true;   // Default true
  long api_reach_mfe_target     = 0;      // api_reach_mfe_target
  long api_reach_loss_set       = 0;      // api_reach_loss_set
  long api_freeze_max_time      = 30; 
  long api_time_to_check_server = 30;
  long api_time_max_seconds     = 30;     // Time Max Operation
  long api_slippage             = 30;     // Slippage for order
  long api_milliseconds_timer   = 2400;   // api_milliseconds_timer
  long api_milliseconds_tick    = 2400;   // api_milliseconds_timer
  long api_debug_mode_level     = 1;      // Default 1
  long api_send_orders_history  = false;  // Default false
  long api_close_all_orders     = false;  // Default false
  string api_store_message;
  string account_state;
  string account_margin_mode;
  string account_mode;                // Under real server (Default is false)
  string api_server_hostname;
  string api_send_orders_history_ranges;
  
  string orderdata[];

  if(ApiRequestInformation(orderdata, "store"))
   {
    WebServiceJason.Deserialize(orderdata[0]);
    account_state              = WebServiceJason["account_state"].ToStr();              // enable/disable
    account_mode               = WebServiceJason["account_mode"].ToStr();               // demo/real
    account_margin_mode        = WebServiceJason["account_margin_mode"].ToStr();        // hedging/netting
    api_server_hostname        = WebServiceJason["api_server_hostname"].ToStr();        // server api
    api_store_state            = WebServiceJason["api_store_state"].ToBool();
    api_store_message          = WebServiceJason["api_store_message"].ToStr();
    api_debug_mode             = WebServiceJason["api_debug_mode"].ToBool();            // server api_debug_mode
    api_freeze_max_time        = WebServiceJason["api_freeze_max_time"].ToInt();        // server api_freeze_max_time
    api_time_to_check_server   = WebServiceJason["api_time_to_check_server"].ToInt();   // server api_time_to_check_server
    api_time_max_seconds       = WebServiceJason["api_time_max_seconds"].ToInt();       // server api_time_max_seconds
    api_slippage               = WebServiceJason["api_slippage"].ToInt();               // server api_slippage
    api_environment_local      = WebServiceJason["api_environment_local"].ToBool();     // server api_environment_local
    api_milliseconds_timer     = WebServiceJason["api_milliseconds_timer"].ToInt();     // server api_milliseconds_timer
    api_milliseconds_tick      = WebServiceJason["api_milliseconds_tick"].ToInt();      // server api_milliseconds_tick
    api_event_on_timer         = WebServiceJason["api_event_on_timer"].ToBool();        // server api_event_on_timer
    api_event_on_tick          = WebServiceJason["api_event_on_tick"].ToBool();         // server api_event_on_tick
    api_debug_mode_level       = WebServiceJason["api_debug_mode_level"].ToInt();       // server api_debug_mode_level
    api_mfe_mae_display        = WebServiceJason["api_mfe_mae_display"].ToBool();       // server api_mfe_mae_display
    api_reach_mfe_target       = WebServiceJason["api_reach_mfe_target"].ToInt();       // server api_reach_mfe_target
    api_reach_loss_set         = WebServiceJason["api_reach_loss_set"].ToInt();         // server api_reach_loss_set
    api_send_orders_history    = WebServiceJason["api_send_orders_history"].ToBool();   // server api_send_orders_history
    api_close_all_orders       = WebServiceJason["api_close_all_orders"].ToBool();      // server api_send_orders_history
    api_send_orders_history_ranges = WebServiceJason["api_send_orders_history_ranges"].ToStr();      // server api_send_orders_history_ranges
    

   }
  else
    changes = false;

  if (api_debug_mode == true && DebugMode == false) {
    DebugMode = api_debug_mode;
    AddCommentOnChart("Modo de DEBUG ativado");
  } else if(api_debug_mode == false && DebugMode == true){
    DebugMode = api_debug_mode;
    AddCommentOnChart("Modo de DEBUG desativado");
  }

  if(api_time_to_check_server != TimeToCheckServer){
    AddCommentOnChart("TimeToCheckServer atualizado de: " + IntegerToString(TimeToCheckServer) + " para: " + IntegerToString(api_time_to_check_server));
    TimeToCheckServer = api_time_to_check_server;  
  }

  if(MaxSeconds != api_time_max_seconds){
    AddCommentOnChart("MaxSeconds atualizado de: " + IntegerToString(MaxSeconds) + " para: " + IntegerToString(api_time_max_seconds));
    MaxSeconds = api_time_max_seconds;
  }
  if(Slippage != api_slippage){
    AddCommentOnChart("Slippage atualizado de: " + IntegerToString(Slippage) + " para: " + IntegerToString(api_slippage));
    Slippage = api_slippage;
  }

 if(api_freeze_max_time != FreezeMaxTimeDifference){
    AddCommentOnChart("FreezeMaxTimeDifference atualizado de: " + IntegerToString(FreezeMaxTimeDifference) + " para: " + IntegerToString(api_freeze_max_time));
    FreezeMaxTimeDifference = api_freeze_max_time;  
  }

 if(api_event_on_timer != EventOnTimer){
    AddCommentOnChart("EventOnTimer atualizado de: " + string(EventOnTimer) + " para: " + string(api_event_on_timer));
    EventOnTimer = api_event_on_timer;  
  }

 if(api_event_on_tick != EventOnTick){
    AddCommentOnChart("EventOnTick atualizado de: " + string(EventOnTick) + " para: " + string(api_event_on_tick));
    EventOnTick = api_event_on_tick;  
  }

  if(EnvironmentLocal != api_environment_local){
    AddCommentOnChart("EnvironmentLocal atualizado de: " + string(EnvironmentLocal) + " para: " + string(api_environment_local));
    EnvironmentLocal = api_environment_local;
  }

  if(MilliSecondsTimer != api_milliseconds_timer){
    AddCommentOnChart("MilliSecondsTimer atualizado de: " + IntegerToString(MilliSecondsTimer) + " para: " + IntegerToString(api_milliseconds_timer));
    MilliSecondsTimer = int(api_milliseconds_timer);
    EventSetMillisecondTimer(MilliSecondsTimer);
  }

  if(ReachMfeTarget != api_reach_mfe_target){
    AddCommentOnChart("ReachMfeTarget atualizado de: " + IntegerToString(ReachMfeTarget) + " para: " + IntegerToString(api_reach_mfe_target));
    ReachMfeTargetBool  = false;
    ReachProfitDay      = 0;    
    ReachMfeTarget = int(api_reach_mfe_target);
  }  

  if(ReachLossSet != api_reach_loss_set){
    AddCommentOnChart("ReachLossSet atualizado de: " + IntegerToString(ReachLossSet) + " para: " + IntegerToString(api_reach_loss_set));
    ReachLossSetBool    = false;
    ReachLossDay        = 0;    
    ReachLossSet = int(api_reach_loss_set);
  }

  if(DebugModeLevel != api_debug_mode_level){
    AddCommentOnChart("DebugModeLevel atualizado de: " + IntegerToString(DebugModeLevel) + " para: " + IntegerToString(api_debug_mode_level));
    DebugModeLevel = api_debug_mode_level;
  }

  if(SendOrdersHistory != api_send_orders_history){
    AddCommentOnChart("SendOrdersHistory atualizado de: " + IntegerToString(SendOrdersHistory) + " para: " + IntegerToString(api_send_orders_history));
    SendOrdersHistory = api_send_orders_history;
  }  

  if(CloseAllOrders != api_close_all_orders){
    AddCommentOnChart("CloseAllOrders atualizado de: " + IntegerToString(CloseAllOrders) + " para: " + IntegerToString(api_close_all_orders));
    CloseAllOrders = api_close_all_orders;    
  }

  if(MilliSecondsTick != api_milliseconds_tick){
    AddCommentOnChart("MilliSecondsTick atualizado de: " + IntegerToString(MilliSecondsTick) + " para: " + IntegerToString(api_milliseconds_tick));
    MilliSecondsTick = int(api_milliseconds_tick);
    EventSetMillisecondTimer(MilliSecondsTick);
  } 

  if(MfeMaeDisplay != api_mfe_mae_display && EXPERT_KIND == "copy"){
    AddCommentOnChart("MfeMaeDisplay atualizado de: " + string(MfeMaeDisplay) + " para: " + string(api_mfe_mae_display));
    MfeMaeDisplay = api_mfe_mae_display;
  }

  if(StringLen(api_store_message) > 0){
    AddCommentOnChart(api_store_message);
    //changes = false;
  }

  if(!api_store_state){
    AddCommentOnChart("Sistema copy está desabilitada em nosso sistema. Fale com o suporte");

    changes = false;
  }

  if(account_mode == "demo" && IsDemoMQL4() == false){
    AddCommentOnChart("Acesso é somente para conta demo. Fale com o suporte");
    changes = false;
   }

  if(account_state == "disable"){
    AddCommentOnChart("Conta está desabilitada em nosso sistema. Fale com o suporte");
    changes = false;
  }
  if(account_margin_mode == "hedging" && AccountMarginMode() == "NETTING"){
    // Print("Sua conta está habilitada para modo HEDGE em nosso sistema, porém conta na corretora está configurada para modo NETTING. Efetue a mudanca com a sua corretora.");
    AddCommentOnChart("Conta está habilitada para modo HEDGE em nosso sistema, porém conta na corretora está configurada para modo NETTING. Efetue a mudanca com a sua corretora.");
    changes = false;
  }
  if(account_margin_mode == "netting" && AccountMarginMode() == "HEDGING"){
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

  if(SendOrdersHistory){
    string range_split[];
    StringSplit(api_send_orders_history_ranges, '.' , range_split);
    OrdersHistoryStart = datetime(int(range_split[0]));
    OrdersHistoryEnd = datetime(int(range_split[1]));
    
    if(TrasmitOrdersHistory())
      AddCommentOnChart("SendOrdersHistory Enviado");
  }

  if(DebugMode && CloseAllOrders)
    CloseAllPositionOrders();

  return changes;
 }

//+------------------------------------------------------------------+
//| CheckFreeze                                                |
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
//| Detect the script parameters                                     |
//+------------------------------------------------------------------+
bool DetectEnvironment()
 {
  ExpertVersion = VERSION + "_" + VERSION_UPDATE;

  if(InputEnvironmentLocal)
    SERVER = "http://localhost:8080";

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
//| SaveLogToFile                                                    |
//+------------------------------------------------------------------+
bool SaveLogToFile(string message) {
  // Abre o arquivo para gravação
  file_handle_out = FileOpen(LogFileName, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI | FILE_TXT);
  if(file_handle_out != INVALID_HANDLE) {
    // Move o ponteiro do arquivo para o final
      FileSeek(file_handle_out, 0, SEEK_END);
       
      // Formata a mensagem de log
      string logEntry = StringFormat("%s - %s",
                                     TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
                                     message);

      // Escreve no arquivo e fecha
    FileWriteString(file_handle_out, logEntry + "\r\n");
    FileClose(file_handle_out);
    return true;
  } else {
    // Trata o erro de abertura do arquivo
    PrintFormat("Failed to open %s file, Error code = %d", LogFileName, GetLastError());
  }
  return false;
}

//+------------------------------------------------------------------+
//| SetLogFileName                                                   |
//+------------------------------------------------------------------+
void SetLogFileName()
 {
  MqlDateTime mqlTime;
  TimeLocal(mqlTime);
  string eaName = CamelCaseToSnakeCase(EXPERTNAME);
  string newLogFileName = StringFormat("%s/log_%04d%02d%02d.txt", eaName, mqlTime.year, mqlTime.mon, mqlTime.day);
  if(newLogFileName != LogFileName)
   {
    LogFileName = newLogFileName;
    AddCommentOnChart("Log Salvo em Arquivo -> Abrir pasta de dados -> MQL5/Files/" + LogFileName, 3);
   }
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
//| RemoveCommentOnChart                                             |
//+------------------------------------------------------------------+
bool RemoveCommentOnChart(long line_item){
  int indexToRemove = -1;

  // Encontrar o índice do line_itemµ
  for(int i = 0; i < ArraySize(commentOnChartInitPosition); i++) {
    if(commentOnChartInitPosition[i] == line_item) {
      indexToRemove = i;
      break;
    }
  }
  
  // Se nao encontrou o line_item, retornar false
  if(indexToRemove == -1) {
    return false;
  }

  // Remover o item do array de mensagens
  for(int i = indexToRemove; i < ArraySize(commentOnChartInit) - 1; i++) {
    commentOnChartInit[i] = commentOnChartInit[i + 1];
  }
  ArrayResize(commentOnChartInit, ArraySize(commentOnChartInit) - 1);

  // Remover o item do array de posicões
  for(int i = indexToRemove; i < ArraySize(commentOnChartInitPosition) - 1; i++) {
    commentOnChartInitPosition[i] = commentOnChartInitPosition[i + 1];
  }
  ArrayResize(commentOnChartInitPosition, ArraySize(commentOnChartInitPosition) - 1);

  // Atualizar comentários no gráfico
  ShowCommentOnChart();

  return true;
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
double GetFeesOrderHistory(const long ticket_deal)
 {
  double fee = HistoryDealGetDouble(ticket_deal, DEAL_FEE);
  double swap = HistoryDealGetDouble(ticket_deal, DEAL_SWAP);
  double comission = HistoryDealGetDouble(ticket_deal, DEAL_COMMISSION);
  double fees = comission * 2 + swap + fee;
  return fees;
 }
 