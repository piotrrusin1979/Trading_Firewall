//+------------------------------------------------------------------+
//| TF_CooldownPersistence.mqh                                       |
//| Persistent cooldown storage using GlobalVariables                |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Save cooldown state to global variables                          |
//+------------------------------------------------------------------+
void CooldownPersistence_Save(datetime cooldownUntil, string cooldownReason, int cooldownReasonCode,
                              double cooldownReasonValue, bool bigWinToday)
{
   string prefix = "TF_CD_" + Symbol() + "_";

   GlobalVariableSet(prefix + "Until", (double)cooldownUntil);
   GlobalVariableSet(prefix + "BigWin", bigWinToday ? 1.0 : 0.0);
   GlobalVariableSet(prefix + "ReasonCode", (double)cooldownReasonCode);
   GlobalVariableSet(prefix + "ReasonValue", cooldownReasonValue);

   if(cooldownUntil > 0)
   {
      GlobalVariableSet(prefix + "Active", 1.0);
   }
   else
   {
      GlobalVariableSet(prefix + "Active", 0.0);
      GlobalVariableSet(prefix + "ReasonCode", 0.0);
      GlobalVariableSet(prefix + "ReasonValue", 0.0);
   }
}

//+------------------------------------------------------------------+
//| Load cooldown state from global variables                        |
//+------------------------------------------------------------------+
void CooldownPersistence_Load(datetime &cooldownUntil, string &cooldownReason, int &cooldownReasonCode,
                              double &cooldownReasonValue, bool &bigWinToday)
{
   string prefix = "TF_CD_" + Symbol() + "_";

   // Check if we have saved cooldown data
   if(!GlobalVariableCheck(prefix + "Active"))
   {
      cooldownUntil = 0;
      cooldownReason = "";
      cooldownReasonCode = 0;
      cooldownReasonValue = 0.0;
      bigWinToday = false;
      return;
   }

   double active = GlobalVariableGet(prefix + "Active");
   if(active <= 0)
   {
      cooldownUntil = 0;
      cooldownReason = "";
      cooldownReasonCode = 0;
      cooldownReasonValue = 0.0;
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
      cooldownReasonCode = (int)GlobalVariableGet(prefix + "ReasonCode");
      cooldownReasonValue = GlobalVariableGet(prefix + "ReasonValue");

      // Reconstruct reason by checking time remaining
      int minutesRemaining = (int)((savedUntil - now) / 60);

      if(cooldownReasonCode == 4 || bigWinToday)
      {
         cooldownReason = "Big win (" + DoubleToString(cooldownReasonValue, 1) + "%) - done for today (restored)";
      }
      else if(cooldownReasonCode == 3)
      {
         cooldownReason = "Big loss (" + DoubleToString(cooldownReasonValue, 1) + "%) - " +
                          IntegerToString(minutesRemaining) + " min remaining (restored)";
      }
      else if(cooldownReasonCode == 5)
      {
         cooldownReason = "REVENGE BLOCK (2x) - " + IntegerToString(minutesRemaining) + " min remaining (restored)";
      }
      else if(cooldownReasonCode == 2)
      {
         cooldownReason = "Loss cooldown - " + IntegerToString(minutesRemaining) + " min remaining (restored)";
      }
      else if(cooldownReasonCode == 1)
      {
         cooldownReason = "Win cooldown - " + IntegerToString(minutesRemaining) + " min remaining (restored)";
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
      cooldownReasonCode = 0;
      cooldownReasonValue = 0.0;
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
   if(GlobalVariableCheck(prefix + "ReasonCode"))
      GlobalVariableDel(prefix + "ReasonCode");
   if(GlobalVariableCheck(prefix + "ReasonValue"))
      GlobalVariableDel(prefix + "ReasonValue");
}

//+------------------------------------------------------------------+
//| Update persisted cooldown if values changed                      |
//+------------------------------------------------------------------+
void CooldownPersistence_Update(datetime cooldownUntil, string cooldownReason, int cooldownReasonCode,
                                double cooldownReasonValue, bool bigWinToday)
{
   static datetime lastCooldownUntil = 0;
   static int lastReasonCode = 0;
   static double lastReasonValue = 0.0;
   static bool lastBigWinToday = false;

   // Check if cooldown expired
   if(cooldownUntil > 0 && TimeCurrent() >= cooldownUntil)
   {
      // Clear expired cooldown
      CooldownPersistence_Clear();
      return;
   }

   if(cooldownUntil == lastCooldownUntil &&
      cooldownReasonCode == lastReasonCode &&
      cooldownReasonValue == lastReasonValue &&
      bigWinToday == lastBigWinToday)
   {
      return;
   }

   // Save current state
   CooldownPersistence_Save(cooldownUntil, cooldownReason, cooldownReasonCode, cooldownReasonValue, bigWinToday);
   lastCooldownUntil = cooldownUntil;
   lastReasonCode = cooldownReasonCode;
   lastReasonValue = cooldownReasonValue;
   lastBigWinToday = bigWinToday;
}
//+------------------------------------------------------------------+
