//+------------------------------------------------------------------+
//| TF_CooldownPersistence.mqh                                       |
//| Persistent cooldown storage using GlobalVariables                |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Save cooldown state to global variables                          |
//+------------------------------------------------------------------+
void CooldownPersistence_Save(datetime cooldownUntil, string cooldownReason, bool bigWinToday)
{
   string prefix = "TF_CD_" + Symbol() + "_";

   GlobalVariableSet(prefix + "Until", (double)cooldownUntil);
   GlobalVariableSet(prefix + "BigWin", bigWinToday ? 1.0 : 0.0);

   // Store reason as a simple flag (since we can't store strings in GlobalVariables)
   // We'll reconstruct the reason on load by checking recent trades
   if(cooldownUntil > 0)
   {
      GlobalVariableSet(prefix + "Active", 1.0);
      GlobalVariableSet(prefix + "Reason", StringLen(cooldownReason) > 0 ? 1.0 : 0.0);
   }
   else
   {
      GlobalVariableSet(prefix + "Active", 0.0);
   }
}

//+------------------------------------------------------------------+
//| Load cooldown state from global variables                        |
//+------------------------------------------------------------------+
void CooldownPersistence_Load(datetime &cooldownUntil, string &cooldownReason, bool &bigWinToday)
{
   string prefix = "TF_CD_" + Symbol() + "_";

   // Check if we have saved cooldown data
   if(!GlobalVariableCheck(prefix + "Active"))
   {
      cooldownUntil = 0;
      cooldownReason = "";
      bigWinToday = false;
      return;
   }

   double active = GlobalVariableGet(prefix + "Active");
   if(active <= 0)
   {
      cooldownUntil = 0;
      cooldownReason = "";
      bigWinToday = false;
      return;
   }

   // Load cooldown timestamp
   datetime savedUntil = (datetime)GlobalVariableGet(prefix + "Until");
   datetime now = TimeCurrent();

   // Only restore if cooldown hasn't expired
   if(savedUntil > now)
   {
      cooldownUntil = savedUntil;

      // Load big win flag
      bigWinToday = (GlobalVariableGet(prefix + "BigWin") > 0);

      // Reconstruct reason by checking time remaining
      int minutesRemaining = (int)((savedUntil - now) / 60);

      if(bigWinToday)
      {
         cooldownReason = "Big win - done for today (restored)";
      }
      else
      {
         cooldownReason = "Cooldown active - " + IntegerToString(minutesRemaining) + " min remaining (restored)";
      }

      Print("Cooldown restored: ", cooldownReason);
   }
   else
   {
      // Cooldown expired, clear it
      cooldownUntil = 0;
      cooldownReason = "";
      bigWinToday = false;
      CooldownPersistence_Clear();
   }
}

//+------------------------------------------------------------------+
//| Clear persisted cooldown data                                    |
//+------------------------------------------------------------------+
void CooldownPersistence_Clear()
{
   string prefix = "TF_CD_" + Symbol() + "_";

   if(GlobalVariableCheck(prefix + "Active"))
      GlobalVariableDel(prefix + "Active");
   if(GlobalVariableCheck(prefix + "Until"))
      GlobalVariableDel(prefix + "Until");
   if(GlobalVariableCheck(prefix + "BigWin"))
      GlobalVariableDel(prefix + "BigWin");
   if(GlobalVariableCheck(prefix + "Reason"))
      GlobalVariableDel(prefix + "Reason");
}

//+------------------------------------------------------------------+
//| Update persisted cooldown if values changed                      |
//+------------------------------------------------------------------+
void CooldownPersistence_Update(datetime cooldownUntil, string cooldownReason, bool bigWinToday)
{
   string prefix = "TF_CD_" + Symbol() + "_";

   // Check if cooldown expired
   if(cooldownUntil > 0 && TimeCurrent() >= cooldownUntil)
   {
      // Clear expired cooldown
      CooldownPersistence_Clear();
      return;
   }

   // Save current state
   CooldownPersistence_Save(cooldownUntil, cooldownReason, bigWinToday);
}
//+------------------------------------------------------------------+
