//+------------------------------------------------------------------+
//| TF_TradeTiming.mqh                                               |
//| Track last trade time and calculate time between trades          |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Save timestamp of last trade using GlobalVariables               |
//+------------------------------------------------------------------+
void TradeTiming_SaveLastTradeTime(datetime tradeTime)
{
   string key = "TF_LastTrade_" + Symbol();
   GlobalVariableSet(key, (double)tradeTime);
}

//+------------------------------------------------------------------+
//| Get timestamp of last trade                                      |
//+------------------------------------------------------------------+
datetime TradeTiming_GetLastTradeTime()
{
   string key = "TF_LastTrade_" + Symbol();

   if(!GlobalVariableCheck(key))
      return 0;

   return (datetime)GlobalVariableGet(key);
}

//+------------------------------------------------------------------+
//| Get minutes since last trade                                     |
//+------------------------------------------------------------------+
int TradeTiming_GetMinutesSinceLastTrade()
{
   datetime lastTrade = TradeTiming_GetLastTradeTime();

   if(lastTrade == 0)
      return 999999; // No previous trade

   datetime now = TimeCurrent();
   int minutes = (int)((now - lastTrade) / 60);

   return minutes;
}

//+------------------------------------------------------------------+
//| Check if enough time has passed since last trade                 |
//+------------------------------------------------------------------+
bool TradeTiming_CanTradeNow(int minMinutesRequired, string &reasonOut)
{
   if(minMinutesRequired <= 0)
      return true; // Feature disabled

   int minutesSince = TradeTiming_GetMinutesSinceLastTrade();

   if(minutesSince >= minMinutesRequired)
      return true;

   int remaining = minMinutesRequired - minutesSince;
   reasonOut = "Blocked: wait " + IntegerToString(remaining) + " more minutes (min " +
               IntegerToString(minMinutesRequired) + " min between trades)";

   return false;
}

//+------------------------------------------------------------------+
//| Calculate revenge trading multiplier based on loss streak        |
//+------------------------------------------------------------------+
int TradeTiming_GetRevengeCooldownMultiplier(datetime dayStart)
{
   if(!Config_GetBlockRevengeTrading())
      return 1; // No revenge blocking

   int streak = TradeStats_LossStreakToday(dayStart);

   // After 2+ consecutive losses, apply 2x cooldown
   if(streak >= 2)
      return 2;

   return 1;
}
//+------------------------------------------------------------------+
