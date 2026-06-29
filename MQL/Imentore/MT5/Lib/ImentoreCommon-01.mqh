//+------------------------------------------------------------------+
//|                                                  ImentoreLib.mqh |
//|                                     Copyright 2023, Imentore.Co. |
//|                                         https://www.imentore.com |
//+------------------------------------------------------------------+
#property copyright   "ImentoreLib - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

#define VERSION_COMMON "1"
#define UPDATE_COMMON  "04"

long   commentOnChartInitPosition[];
string commentOnChartInit[];
string commentOnChartTick[];
string LogFileName;
int    file_handle_out         = 0;

//+------------------------------------------------------------------+
//| SetLogFileName                                                   |
//+------------------------------------------------------------------+
void SetLogFileName(long line_item = 3)
 {
  MqlDateTime mqlTime;
  TimeLocal(mqlTime);
  string eaName = CamelCaseToSnakeCase(EXPERTNAME);
  string newLogFileName = StringFormat("%s/log_%04d%02d%02d.txt", eaName, mqlTime.year, mqlTime.mon, mqlTime.day);
  if(newLogFileName != LogFileName)
   {
    LogFileName = newLogFileName;
    AddCommentOnChart("Log Salvo em Arquivo -> Abrir pasta de dados -> MQL5/Files/" + LogFileName, line_item);
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