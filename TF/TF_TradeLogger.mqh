//+------------------------------------------------------------------+
//| TF_TradeLogger.mqh                                               |
//| Comprehensive trade logging to CSV file                          |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Initialize trade log file with headers                           |
//+------------------------------------------------------------------+
void TradeLogger_InitFile()
{
   string filename = "TradingJournal.csv";
   int handle = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE, ',');

   if(handle == INVALID_HANDLE)
   {
      Print("TradeLogger: Failed to open log file: ", GetLastError());
      return;
   }

   // Check if file is empty (new file)
   if(FileSize(handle) == 0)
   {
      // Write CSV headers
      FileWrite(handle, "Timestamp", "Ticket", "Symbol", "Type", "Direction",
                "Lots", "EntryPrice", "SL", "TP", "CloseTime", "ClosePrice",
                "Profit", "Commission", "Swap", "NetPL", "Comment");
   }

   FileClose(handle);
}

//+------------------------------------------------------------------+
//| Log a newly opened trade                                         |
//+------------------------------------------------------------------+
void TradeLogger_LogOpenTrade(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
   {
      Print("TradeLogger: Failed to select ticket #", ticket);
      return;
   }

   string filename = "TradingJournal.csv";
   int handle = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE, ',');

   if(handle == INVALID_HANDLE)
   {
      Print("TradeLogger: Failed to open log file: ", GetLastError());
      return;
   }

   // Move to end of file
   FileSeek(handle, 0, SEEK_END);

   // Get order details
   datetime openTime = OrderOpenTime();
   int type = OrderType();
   string typeStr = "";
   string dirStr = "";

   if(type == OP_BUY)
   {
      typeStr = "MARKET";
      dirStr = "BUY";
   }
   else if(type == OP_SELL)
   {
      typeStr = "MARKET";
      dirStr = "SELL";
   }
   else if(type == OP_BUYLIMIT)
   {
      typeStr = "LIMIT";
      dirStr = "BUY";
   }
   else if(type == OP_SELLLIMIT)
   {
      typeStr = "LIMIT";
      dirStr = "SELL";
   }
   else if(type == OP_BUYSTOP)
   {
      typeStr = "STOP";
      dirStr = "BUY";
   }
   else if(type == OP_SELLSTOP)
   {
      typeStr = "STOP";
      dirStr = "SELL";
   }

   string symbol = OrderSymbol();
   double lots = OrderLots();
   double entry = OrderOpenPrice();
   double sl = OrderStopLoss();
   double tp = OrderTakeProfit();
   string comment = OrderComment();

   // Write open trade entry (CloseTime, ClosePrice, Profit, etc. will be empty)
   FileWrite(handle,
             TimeToString(openTime, TIME_DATE|TIME_MINUTES),
             IntegerToString(ticket),
             symbol,
             typeStr,
             dirStr,
             DoubleToString(lots, 2),
             DoubleToString(entry, Digits),
             (sl > 0 ? DoubleToString(sl, Digits) : ""),
             (tp > 0 ? DoubleToString(tp, Digits) : ""),
             "", // CloseTime - empty for now
             "", // ClosePrice - empty for now
             "", // Profit - empty for now
             "", // Commission - empty for now
             "", // Swap - empty for now
             "", // NetPL - empty for now
             comment);

   FileClose(handle);

   Print("TradeLogger: Logged open trade #", ticket, " ", symbol, " ", dirStr, " ", lots, " lots");
}

//+------------------------------------------------------------------+
//| Log a closed trade (update existing entry or create new)         |
//+------------------------------------------------------------------+
void TradeLogger_LogClosedTrade(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      Print("TradeLogger: Failed to select closed ticket #", ticket);
      return;
   }

   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL)
      return; // Only log market positions, not pending orders

   string filename = "TradingJournal.csv";

   // Get order details
   datetime openTime = OrderOpenTime();
   datetime closeTime = OrderCloseTime();
   string symbol = OrderSymbol();
   string dirStr = (type == OP_BUY) ? "BUY" : "SELL";
   double lots = OrderLots();
   double entry = OrderOpenPrice();
   double closePrice = OrderClosePrice();
   double sl = OrderStopLoss();
   double tp = OrderTakeProfit();
   double profit = OrderProfit();
   double commission = OrderCommission();
   double swap = OrderSwap();
   double netPL = profit + commission + swap;
   string comment = OrderComment();

   // Read all lines from file
   string lines[];
   int lineCount = 0;

   int handle = FileOpen(filename, FILE_CSV|FILE_READ, ',');
   if(handle == INVALID_HANDLE)
   {
      // File doesn't exist, create new
      TradeLogger_InitFile();
      handle = FileOpen(filename, FILE_CSV|FILE_READ, ',');
   }

   if(handle != INVALID_HANDLE)
   {
      while(!FileIsEnding(handle))
      {
         string line = FileReadString(handle);
         if(StringLen(line) > 0)
         {
            ArrayResize(lines, lineCount + 1);
            lines[lineCount] = line;
            lineCount++;
         }
      }
      FileClose(handle);
   }

   // Search for existing entry with this ticket
   bool found = false;
   int foundIdx = -1;
   string ticketStr = IntegerToString(ticket);

   for(int i = 1; i < lineCount; i++) // Start at 1 to skip header
   {
      string cols[];
      int colCount = StringSplit(lines[i], ',', cols);

      if(colCount >= 2 && cols[1] == ticketStr)
      {
         found = true;
         foundIdx = i;
         break;
      }
   }

   // Build updated/new line
   string newLine = TimeToString(openTime, TIME_DATE|TIME_MINUTES) + "," +
                    IntegerToString(ticket) + "," +
                    symbol + "," +
                    "MARKET," +
                    dirStr + "," +
                    DoubleToString(lots, 2) + "," +
                    DoubleToString(entry, Digits) + "," +
                    (sl > 0 ? DoubleToString(sl, Digits) : "") + "," +
                    (tp > 0 ? DoubleToString(tp, Digits) : "") + "," +
                    TimeToString(closeTime, TIME_DATE|TIME_MINUTES) + "," +
                    DoubleToString(closePrice, Digits) + "," +
                    DoubleToString(profit, 2) + "," +
                    DoubleToString(commission, 2) + "," +
                    DoubleToString(swap, 2) + "," +
                    DoubleToString(netPL, 2) + "," +
                    comment;

   // Write updated file
   handle = FileOpen(filename, FILE_CSV|FILE_WRITE, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("TradeLogger: Failed to write log file: ", GetLastError());
      return;
   }

   // Write header
   if(lineCount > 0)
      FileWriteString(handle, lines[0] + "\n");

   // Write all lines, replacing or appending
   bool written = false;
   for(int i = 1; i < lineCount; i++)
   {
      if(i == foundIdx)
      {
         FileWriteString(handle, newLine + "\n");
         written = true;
      }
      else
      {
         FileWriteString(handle, lines[i] + "\n");
      }
   }

   // If not found in existing lines, append
   if(!written)
   {
      FileWriteString(handle, newLine + "\n");
   }

   FileClose(handle);

   Print("TradeLogger: Logged closed trade #", ticket, " ", symbol, " ", dirStr,
         " Net P/L: ", DoubleToString(netPL, 2));
}

//+------------------------------------------------------------------+
//| Scan history and log any missing closed trades                   |
//+------------------------------------------------------------------+
void TradeLogger_SyncHistory()
{
   // This function can be called periodically to ensure all closed
   // trades are logged (in case EA was offline when trade closed)

   int total = OrdersHistoryTotal();
   int logged = 0;

   for(int i = total - 1; i >= 0 && logged < 50; i--) // Check last 50 closed trades
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      int ticket = OrderTicket();

      // Check if this trade is already in log
      string filename = "TradingJournal.csv";
      bool foundInLog = false;

      int handle = FileOpen(filename, FILE_CSV|FILE_READ, ',');
      if(handle != INVALID_HANDLE)
      {
         string ticketStr = IntegerToString(ticket);

         while(!FileIsEnding(handle))
         {
            string line = FileReadString(handle);

            string cols[];
            int colCount = StringSplit(line, ',', cols);

            if(colCount >= 11 && cols[1] == ticketStr)
            {
               // Check if it has close data (column 10 = CloseTime)
               if(StringLen(cols[9]) > 0)
               {
                  foundInLog = true;
                  break;
               }
            }
         }
         FileClose(handle);
      }

      if(!foundInLog)
      {
         TradeLogger_LogClosedTrade(ticket);
         logged++;
      }
   }

   if(logged > 0)
      Print("TradeLogger: Synced ", logged, " missing closed trades");
}
//+------------------------------------------------------------------+
