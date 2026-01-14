//+------------------------------------------------------------------+
//| TF_TimeUtils.mqh                                                 |
//| Time-related utility functions                                   |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Get start of day (00:00:00)                                      |
//+------------------------------------------------------------------+
datetime TimeUtils_StartOfDay(datetime t)
{
   MqlDateTime s;
   TimeToStruct(t, s);
   s.hour = 0; s.min = 0; s.sec = 0;
   return StructToTime(s);
}

//+------------------------------------------------------------------+
//| Get start of week (Monday 00:00:00)                              |
//+------------------------------------------------------------------+
datetime TimeUtils_StartOfWeek(datetime t)
{
   MqlDateTime s;
   TimeToStruct(t, s);
   // MT4: day_of_week: 0=Sunday, 1=Monday, ... 6=Saturday
   int dow = s.day_of_week;
   int daysFromMonday = (dow == 0) ? 6 : (dow - 1);
   datetime sod = TimeUtils_StartOfDay(t);
   return sod - daysFromMonday * 86400;
}

//+------------------------------------------------------------------+
//| Check if new day has started                                     |
//+------------------------------------------------------------------+
bool TimeUtils_IsNewDay(datetime dayStart)
{
   return TimeUtils_StartOfDay(TimeCurrent()) != dayStart;
}

//+------------------------------------------------------------------+
//| Check if new week has started                                    |
//+------------------------------------------------------------------+
bool TimeUtils_IsNewWeek(datetime weekStart)
{
   return TimeUtils_StartOfWeek(TimeCurrent()) != weekStart;
}

//+------------------------------------------------------------------+
//| Reset day and week tracking                                      |
//+------------------------------------------------------------------+
void TimeUtils_ResetDayWeek(datetime &dayStart, datetime &weekStart)
{
   dayStart  = TimeUtils_StartOfDay(TimeCurrent());
   weekStart = TimeUtils_StartOfWeek(TimeCurrent());
}
//+------------------------------------------------------------------+
