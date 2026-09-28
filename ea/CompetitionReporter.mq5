//+------------------------------------------------------------------+
//| CompetitionReporter.mq5                                          |
//| Reporta el estado de esta cuenta a la competencia cada N minutos.|
//| No opera, no modifica nada: solo lee y envía datos.               |
//+------------------------------------------------------------------+
#property strict

input string ReportUrl   = "https://giznhbantstjcksbjydg.supabase.co/functions/v1/rapid-endpoint"; // URL de la función
input string ReportToken = "PEGA_AQUI_TU_TOKEN";  // token único por participante (cada quien pone el suyo, NO subir el real a git)
input string SupabaseAnonKey = "sb_publishable_C_9czjyd_ZTEG80rsFHL0Q_Z0to7IaX"; // clave pública de Supabase (misma para todos, segura de compartir)
input int    IntervalMin = 15;                    // cada cuántos minutos reporta

datetime lastReport = 0;

int OnInit()
  {
   Print("CompetitionReporter iniciado. Reportando cada ", IntervalMin, " min a ", ReportUrl);
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   if(TimeCurrent() - lastReport < IntervalMin * 60)
      return;
   lastReport = TimeCurrent();
   SendReport();
  }

void SendReport()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   int tradesCount = 0;
   double maxLot = 0;
   int tradingDays[32];
   int daysFound = 0;
   string symbols[16];
   int symbolsFound = 0;

   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      tradesCount++;
      double vol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      if(vol > maxLot) maxLot = vol;

      MqlDateTime dt;
      TimeToStruct((datetime)HistoryDealGetInteger(ticket, DEAL_TIME), dt);
      int dayKey = dt.year * 372 + dt.mon * 31 + dt.day;
      bool found = false;
      for(int d = 0; d < daysFound; d++)
         if(tradingDays[d] == dayKey) { found = true; break; }
      if(!found && daysFound < 32)
         tradingDays[daysFound++] = dayKey;

      string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(sym != "")
        {
         bool symFound = false;
         for(int s = 0; s < symbolsFound; s++)
            if(symbols[s] == sym) { symFound = true; break; }
         if(!symFound && symbolsFound < 16)
            symbols[symbolsFound++] = sym;
        }
     }

   string symbolsStr = "";
   for(int s = 0; s < symbolsFound; s++)
      symbolsStr += (s > 0 ? ", " : "") + symbols[s];

   string loginStr = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string json = StringFormat(
      "{\"login\":\"%s\",\"token\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,"
      "\"trades_count\":%d,\"max_lot_used\":%.2f,\"trading_days\":%d,\"symbols_traded\":\"%s\"}",
      loginStr, ReportToken, balance, equity,
      tradesCount, maxLot, daysFound, symbolsStr
   );

   char post[]; char result[];
   string headers = "Content-Type: application/json\r\n"
                     "Authorization: Bearer " + SupabaseAnonKey + "\r\n";
   StringToCharArray(json, post, 0, StringLen(json));

   int res = WebRequest("POST", ReportUrl, headers, 5000, post, result, headers);
   if(res == -1)
      Print("Error enviando reporte: ", GetLastError(),
            " -- revisa que la URL esté en Herramientas > Opciones > Asesores Expertos > URLs permitidas");
   else
      Print("Reporte enviado, respuesta: ", CharArrayToString(result));
  }
//+------------------------------------------------------------------+
