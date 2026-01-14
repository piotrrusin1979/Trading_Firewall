//+------------------------------------------------------------------+
//| TF_TimeTracking.mqh                                              |
//| Track time spent on trading (active window time)                 |
//+------------------------------------------------------------------+
#property strict

// Time tracking globals
datetime g_sessionStart = 0;
datetime g_lastActiveCheck = 0;
int g_totalSecondsToday = 0;
int g_totalSecondsThisWeek = 0;
int g_totalSecondsAllTime = 0;
datetime g_trackingDayStart = 0;
datetime g_trackingWeekStart = 0;

// Session gap tracking
datetime g_lastSessionEnd = 0;
int g_sessionGapCount = 0;
int g_sessionGapSum = 0;      // Sum of all gaps in seconds
int g_sessionGapMin = 0;       // Shortest gap
int g_sessionGapMax = 0;       // Longest gap

// Session count tracking
int g_sessionsToday = 0;
int g_sessionsThisWeek = 0;

string TIME_TRACKING_FILE = "TradeFirewall_TimeTracking.txt";

//+------------------------------------------------------------------+
//| Initialize time tracking                                         |
//+------------------------------------------------------------------+
void TimeTracking_Init()
{
   datetime now = TimeCurrent();
   g_sessionStart = now;
   g_lastActiveCheck = now;
   g_trackingDayStart = TimeUtils_StartOfDay(now);
   g_trackingWeekStart = TimeUtils_StartOfWeek(now);
   
   // Load saved data
   TimeTracking_Load();
   
   // Increment session counters (this is a new session)
   g_sessionsToday++;
   g_sessionsThisWeek++;
   
   // Calculate gap from last session
   if(g_lastSessionEnd > 0)
   {
      int gapSeconds = (int)(now - g_lastSessionEnd);
      
      // Only count gaps between 1 minute and 7 days (ignore invalid/huge gaps)
      if(gapSeconds >= 60 && gapSeconds <= 604800)
      {
         g_sessionGapCount++;
         g_sessionGapSum += gapSeconds;
         
         // Update min/max
         if(g_sessionGapMin == 0 || gapSeconds < g_sessionGapMin)
            g_sessionGapMin = gapSeconds;
            
         if(gapSeconds > g_sessionGapMax)
            g_sessionGapMax = gapSeconds;
            
         Print("Session gap: ", TimeTracking_FormatSeconds(gapSeconds), 
               " (", IntegerToString(gapSeconds / 60), " minutes)");
      }
   }
   
   Print("Time tracking initialized. Session #", g_sessionsToday, " today, #", g_sessionsThisWeek, " this week");
}

//+------------------------------------------------------------------+
//| Update time tracking (call from OnTimer)                         |
//+------------------------------------------------------------------+
void TimeTracking_Update()
{
   // Check if new day/week
   datetime now = TimeCurrent();
   datetime currentDayStart = TimeUtils_StartOfDay(now);
   datetime currentWeekStart = TimeUtils_StartOfWeek(now);
   
   if(currentDayStart != g_trackingDayStart)
   {
      // New day - reset daily counters
      g_totalSecondsToday = 0;
      g_sessionsToday = 0;
      g_trackingDayStart = currentDayStart;
   }
   
   if(currentWeekStart != g_trackingWeekStart)
   {
      // New week - reset weekly counters
      g_totalSecondsThisWeek = 0;
      g_sessionsThisWeek = 0;
      g_trackingWeekStart = currentWeekStart;
   }
   
   // Check if chart window is active/visible
   long chartHandle = ChartID();
   if(chartHandle > 0)
   {
      // Window exists, count time
      int elapsedSeconds = (int)(now - g_lastActiveCheck);
      
      // Only count if elapsed is reasonable (1-5 seconds for timer)
      if(elapsedSeconds >= 1 && elapsedSeconds <= 10)
      {
         g_totalSecondsToday += elapsedSeconds;
         g_totalSecondsThisWeek += elapsedSeconds;
         g_totalSecondsAllTime += elapsedSeconds;
      }
   }
   
   g_lastActiveCheck = now;
}

//+------------------------------------------------------------------+
//| Save time tracking to file                                       |
//+------------------------------------------------------------------+
void TimeTracking_Save()
{
   int handle = FileOpen(TIME_TRACKING_FILE, FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      Print("Failed to save time tracking: ", GetLastError());
      return;
   }
   
   FileWrite(handle, "# TradeFirewall Time Tracking Data");
   FileWrite(handle, "DayStart=" + TimeToString(g_trackingDayStart, TIME_DATE));
   FileWrite(handle, "WeekStart=" + TimeToString(g_trackingWeekStart, TIME_DATE));
   FileWrite(handle, "SecondsToday=" + IntegerToString(g_totalSecondsToday));
   FileWrite(handle, "SecondsThisWeek=" + IntegerToString(g_totalSecondsThisWeek));
   FileWrite(handle, "SecondsAllTime=" + IntegerToString(g_totalSecondsAllTime));
   FileWrite(handle, "SessionsToday=" + IntegerToString(g_sessionsToday));
   FileWrite(handle, "SessionsThisWeek=" + IntegerToString(g_sessionsThisWeek));
   FileWrite(handle, "LastSessionEnd=" + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   FileWrite(handle, "GapCount=" + IntegerToString(g_sessionGapCount));
   FileWrite(handle, "GapSum=" + IntegerToString(g_sessionGapSum));
   FileWrite(handle, "GapMin=" + IntegerToString(g_sessionGapMin));
   FileWrite(handle, "GapMax=" + IntegerToString(g_sessionGapMax));
   
   FileClose(handle);
}

//+------------------------------------------------------------------+
//| Load time tracking from file                                     |
//+------------------------------------------------------------------+
void TimeTracking_Load()
{
   int handle = FileOpen(TIME_TRACKING_FILE, FILE_READ | FILE_TXT | FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      // File doesn't exist yet - first run
      return;
   }
   
   datetime loadedDayStart = 0;
   datetime loadedWeekStart = 0;
   
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      if(StringFind(line, "#") == 0) continue; // Skip comments
      
      int sepPos = StringFind(line, "=");
      if(sepPos == -1) continue;
      
      string key = StringSubstr(line, 0, sepPos);
      string value = StringSubstr(line, sepPos + 1);
      
      if(key == "DayStart")
         loadedDayStart = StrToTime(value);
      else if(key == "WeekStart")
         loadedWeekStart = StrToTime(value);
      else if(key == "SecondsToday")
         g_totalSecondsToday = (int)StrToInteger(value);
      else if(key == "SecondsThisWeek")
         g_totalSecondsThisWeek = (int)StrToInteger(value);
      else if(key == "SecondsAllTime")
         g_totalSecondsAllTime = (int)StrToInteger(value);
      else if(key == "SessionsToday")
         g_sessionsToday = (int)StrToInteger(value);
      else if(key == "SessionsThisWeek")
         g_sessionsThisWeek = (int)StrToInteger(value);
      else if(key == "LastSessionEnd")
         g_lastSessionEnd = StrToTime(value);
      else if(key == "GapCount")
         g_sessionGapCount = (int)StrToInteger(value);
      else if(key == "GapSum")
         g_sessionGapSum = (int)StrToInteger(value);
      else if(key == "GapMin")
         g_sessionGapMin = (int)StrToInteger(value);
      else if(key == "GapMax")
         g_sessionGapMax = (int)StrToInteger(value);
   }
   
   FileClose(handle);
   
   // Validate loaded data - reset if from different day/week
   if(loadedDayStart != g_trackingDayStart)
   {
      g_totalSecondsToday = 0;
      g_sessionsToday = 0;
   }
      
   if(loadedWeekStart != g_trackingWeekStart)
   {
      g_totalSecondsThisWeek = 0;
      g_sessionsThisWeek = 0;
   }
}

//+------------------------------------------------------------------+
//| Get time tracking data                                           |
//+------------------------------------------------------------------+
void TimeTracking_GetData(int &todaySec, int &weekSec, int &allTimeSec)
{
   todaySec = g_totalSecondsToday;
   weekSec = g_totalSecondsThisWeek;
   allTimeSec = g_totalSecondsAllTime;
}

//+------------------------------------------------------------------+
//| Get session gap statistics                                       |
//+------------------------------------------------------------------+
void TimeTracking_GetGapStats(int &mean, int &minGap, int &maxGap, int &count)
{
   count = g_sessionGapCount;
   minGap = g_sessionGapMin;
   maxGap = g_sessionGapMax;
   
   if(g_sessionGapCount > 0)
      mean = g_sessionGapSum / g_sessionGapCount;
   else
      mean = 0;
}

//+------------------------------------------------------------------+
//| Get session counts                                               |
//+------------------------------------------------------------------+
void TimeTracking_GetSessionCounts(int &today, int &thisWeek, double &weekAvg)
{
   today = g_sessionsToday;
   thisWeek = g_sessionsThisWeek;
   
   // Calculate 7-day average
   datetime now = TimeCurrent();
   int daysThisWeek = (int)((now - g_trackingWeekStart) / 86400);
   if(daysThisWeek < 1) daysThisWeek = 1;
   
   weekAvg = (double)g_sessionsThisWeek / (double)daysThisWeek;
}

//+------------------------------------------------------------------+
//| Format seconds to HH:MM:SS                                       |
//+------------------------------------------------------------------+
string TimeTracking_FormatSeconds(int totalSeconds)
{
   int hours = totalSeconds / 3600;
   int minutes = (totalSeconds % 3600) / 60;
   int seconds = totalSeconds % 60;
   
   string h = (hours < 10 ? "0" : "") + IntegerToString(hours);
   string m = (minutes < 10 ? "0" : "") + IntegerToString(minutes);
   string s = (seconds < 10 ? "0" : "") + IntegerToString(seconds);
   
   return h + ":" + m + ":" + s;
}

//+------------------------------------------------------------------+
//| Format gap time intelligently (hours if >60min, otherwise min)   |
//+------------------------------------------------------------------+
string TimeTracking_FormatGap(int totalSeconds)
{
   if(totalSeconds == 0) return "N/A";
   
   int hours = totalSeconds / 3600;
   int minutes = (totalSeconds % 3600) / 60;
   
   if(hours > 0)
      return IntegerToString(hours) + "h " + IntegerToString(minutes) + "m";
   else
      return IntegerToString(minutes) + "m";
}

//+------------------------------------------------------------------+
//| Cleanup - save final state                                       |
//+------------------------------------------------------------------+
void TimeTracking_Deinit()
{
   // Update one final time before saving
   TimeTracking_Update();
   TimeTracking_Save();
   
   Print("Time tracking saved. Session time: ", 
         TimeTracking_FormatSeconds((int)(TimeCurrent() - g_sessionStart)));
}
//+------------------------------------------------------------------+