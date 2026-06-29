//+------------------------------------------------------------------+
//|                                             ImentoreSettings.mqh |
//|                                     Copyright 2024, Imentore.Co. |
//|                                         https://www.imentore.com |
//+------------------------------------------------------------------+
#property copyright   "ImentoreSettings - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

#define SET_VERSION  "02"
#define SET_UPDATE  "01"

class Settings {
public:
    static Settings* Instance() {
        static Settings instance;
        return &instance;
    }

    string accountLogin;
    string accountServerName;
    string accountName;
    string appName;
    string appVersion;
    string appVersionUpdate;
    string appVersionLocal;
    string appExpertKind;
    string appExpertName;
    bool   InputEnvironmentLocal;
    bool   appEnvironmentLocal;
    bool   appSendOrdersHistory;
    bool   appEventOnTick;
    bool   appEventOnTimer;
    double appReachMfeTarget;
    double appReachLossSet;
    double appReachProfitDay;
    double appReachLossDay;
    double appReachProfitDayLast;
    double appReachLossDayLast;
    long   appMaxSeconds;
    long   appSlipPage;
    int    appMilliSecondsTimer;          
    int    appMilliSecondsTicker;
    int    appMilliSecondsDelay;
    string apiServerUrl;
    string apiVersion;

    // Utility functions
    string ToUnder(string inputString) {
        StringReplace(inputString, " ", "_");
        StringReplace(inputString, ".", "_");
        return inputString;
    }
    
    string ToLowerCase(string inputString) {
        StringToLower(inputString);
        return inputString;
    }       
    string fExpertName() { 
        return ToUnder(appVersion) + "_" + ToUnder(appVersionUpdate);
    }    
    bool ReachMfeTargetBool() { 
        return (appReachMfeTarget > 0 && appReachProfitDay >= appReachMfeTarget);
    }
    bool ReachLossSetBool() { 
        return (appReachLossSet < 0 && appReachLossDay <= appReachLossSet);
    }

private:
    Settings() {
        // Initialize variables here
        accountLogin         = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
        accountServerName    = RemoveSpecialChars(AccountInfoString(ACCOUNT_SERVER));
        accountName          = AccountInfoString(ACCOUNT_NAME);      
        // Initialize other variables as needed
    }

    string RemoveSpecialChars(string inputString) {
        string resultString = "";
        int inputLength = StringLen(inputString);
        uchar charArray[];

        for(int i = 0; i < inputLength; i++) {
            string charStr = StringSubstr(inputString, i, 1);
            StringToCharArray(charStr, charArray, 0, WHOLE_ARRAY);
            int charValue = charArray[0];

            if((charValue >= 48 && charValue <= 57) || // numbers
               (charValue >= 65 && charValue <= 90) || // uppercase letters
               (charValue >= 97 && charValue <= 122))  // lowercase letters
            {
                StringConcatenate(resultString, resultString, charStr);
            }
        }

        return resultString;
    }

    // Prevent copying
    Settings(const Settings& other);            // Not implemented
    Settings operator=(const Settings& other); // Not implemented
};