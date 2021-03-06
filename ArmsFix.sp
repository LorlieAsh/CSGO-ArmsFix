/******************************************************************/
/*                                                                */
/*                      CSGO Custom Arms Fix                      */
/*                                                                */
/*                                                                */
/*  File:          ArmsFix.sp                                     */
/*  Description:   Fix csgo glove overlap on custom arms.         */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2018/04/19 16:13:14                                           */
/*                                                                */
/*  This code is licensed under the MIT License.                  */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <smutils>
#include <armsfix>

#define PI_NAME "[CSGO] Arms Fix"
#define PI_AUTH "Kyle"
#define PI_DESC "Fix csgo glove overlap on custom arms"
#define PI_VERS "1.0"
#define PI_URLS "https://kxnrl.com"

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};

#define TEAM_TE 0
#define TEAM_CT 1

static char g_szCurMapModel[2][128];
static char g_szCurMapArms[2][128];

static Handle g_fwdOnSpawnModel;
static Handle g_fwdOnArmsFixed;

static bool g_bArmsFixed[MAXPLAYERS+1];


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("ArmsFix");

    CreateNative("ArmsFix_ModelSafe", IamNative);

    return APLRes_Success;
}

public int IamNative(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if(!ClientIsValid(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "client %d is invalid.");
        return false;
    }

    return g_bArmsFixed[client];
}

public void OnPluginStart()
{
    g_fwdOnSpawnModel = CreateGlobalForward("ArmsFix_OnSpawnModel", ET_Single, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell);
    g_fwdOnArmsFixed  = CreateGlobalForward("ArmsFix_OnArmsFixed",  ET_Ignore, Param_Cell);

    if(!HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Post))
    {
        SetFailState("Hook event \"player_spawn\" failed");
        return;
    }

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    
    CheckGameModes();
}

public void OnMapStart()
{
    strcopy(g_szCurMapModel[TEAM_TE], 128, "models/player/custom_player/legacy/tm_phoenix.mdl");
    strcopy(g_szCurMapModel[TEAM_CT], 128, "models/player/custom_player/legacy/ctm_st6.mdl");
    
    strcopy(g_szCurMapArms[TEAM_TE],  128, "models/weapons/t_arms.mdl");
    strcopy(g_szCurMapArms[TEAM_CT],  128, "models/weapons/ct_arms.mdl");

    LoadMapKV();
    
    PrecacheModel(g_szCurMapModel[TEAM_TE], true);
    PrecacheModel(g_szCurMapModel[TEAM_CT], true);
    PrecacheModel(g_szCurMapArms[TEAM_TE],  true);
    PrecacheModel(g_szCurMapArms[TEAM_CT],  true);
}

public void OnMapEnd()
{
    CheckGameModes();
}

static void LoadMapKV()
{
    char path[256];
    GetCurrentMap(path, 256);

    KeyValues kv = new KeyValues(path);

    Format(path, 256, "maps/%s.kv", path);

    if(!kv.ImportFromFile(path))
    {
        delete kv;
        return;
    }
    
    kv.GetString("t_arms",  g_szCurMapArms[TEAM_TE], 128, "models/weapons/t_arms.mdl");
    kv.GetString("ct_arms", g_szCurMapArms[TEAM_CT], 128, "models/weapons/ct_arms.mdl");

    if(kv.JumpToKey("t_models", false) && kv.GotoFirstSubKey(false))
    {
        char model[128];
        if(kv.GetSectionName(model, 128) && strlen(model) > 3)
        {
            Format(model, 128, "models/player/custom_player/legacy/%s.mdl", model);
            StringToLower(model, g_szCurMapModel[TEAM_TE], 128);
        }
    }

    kv.Rewind();

    if(kv.JumpToKey("ct_models", false) && kv.GotoFirstSubKey(false))
    {
        char model[128];
        if(kv.GetSectionName(model, 128) && strlen(model) > 3)
        {
            Format(model, 128, "models/player/custom_player/legacy/%s.mdl", model);
            StringToLower(model, g_szCurMapModel[TEAM_CT], 128);
        }
    }

    delete kv;
}

static void CheckGameModes()
{
    KeyValues kv = new KeyValues("GameModes_Server.txt");
    
    if(FileExists("gamemodes_server.txt"))
    {
        kv.ImportFromFile("gamemodes_server.txt");
    }
    else
    {
        kv.ExportToFile("gamemodes_server.txt");
    }

    kv.JumpToKey("maps", true);

    DirectoryListing hDir = OpenDirectory("maps");
    if(hDir == null)
    {
        SetFailState("Can not open maps folder");
        return;
    }

    FileType type;
    char map[256];
    while(hDir.GetNext(map, 256, type))
    {
        if(type != FileType_File || StrContains(map, ".bsp", false) == -1)
        {
            continue;
        }

        ReplaceString(map, 256, ".bsp", "", false);

        //*** processing ***//
        
        // create tree
        kv.JumpToKey(map, true);

        // global data
        kv.SetString("name", map);
        kv.SetNum("default_game_type", 0);
        kv.SetNum("default_game_mode", 0);
        
        // t-side
        kv.SetString("t_arms", "models/weapons/t_arms_phoenix.mdl");
        kv.JumpToKey("t_models", true);
        kv.SetString("tm_phoenix", " ");
        kv.SetString("tm_phoenix_variantA", " ");
        kv.SetString("tm_phoenix_variantB", " ");
        kv.SetString("tm_phoenix_variantC", " ");
        kv.SetString("tm_phoenix_variantD", " ");
        kv.GoBack();
        
        // ct-side
        kv.SetString("ct_arms", "models/weapons/ct_arms_st6.mdl");
        kv.JumpToKey("ct_models", true);
        kv.SetString("ctm_st6", " ");
        kv.SetString("ctm_st6_variantA", " ");
        kv.SetString("ctm_st6_variantB", " ");
        kv.SetString("ctm_st6_variantC", " ");
        kv.SetString("ctm_st6_variantD", " ");
        kv.GoBack();

        // go back
        kv.GoBack();
    }
    
    kv.Rewind();
    kv.ExportToFile("gamemodes_server.txt");
    
    delete hDir;
    delete kv;
}

public void OnClientConnected(int client)
{
    g_bArmsFixed[client] = false;
}

public void OnClientDisconnect_Post(int client)
{
    g_bArmsFixed[client] = false;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(0.02, Timer_SpawnPost, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SpawnPost(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!ClientIsAlive(client))
        return Plugin_Stop;

    Action result = Plugin_Continue;
    
    char model[128], arms[128];
    strcopy(model, 128, g_szCurMapModel[GetClientTeam(client)-2]);
    strcopy(arms,  128, g_szCurMapArms[GetClientTeam(client)-2]);

    Call_StartForward(g_fwdOnSpawnModel);
    Call_PushCell(client);
    Call_PushStringEx(model, 128, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(128);
    Call_PushStringEx(arms,  128, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(128);
    Call_Finish(result);

    if(result == Plugin_Continue)
    {
        SetEntityModel(client, g_szCurMapModel[GetClientTeam(client)-2]);
        SetEntPropString(client, Prop_Send, "m_szArmsModel", g_szCurMapArms[GetClientTeam(client)-2]);

        CreateTimer(0.02, Timer_ArmsFixed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

        return Plugin_Stop;
    }
    else if(result == Plugin_Changed)
    {
        if(IsModelPrecached(model))
        {
            SetEntityModel(client, model);
        }
        else
        {
            LogError(" [%s] is not precached", model);
        }

        if(IsModelPrecached(arms))
        {
            SetEntPropString(client, Prop_Send, "m_szArmsModel", arms);
        }
        else
        {
            LogError(" [%s] is not precached", arms);
        }

        CreateTimer(0.02, Timer_ArmsFixed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

        return Plugin_Stop;
    }

    CreateTimer(0.02, Timer_ArmsFixed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Stop;
}

public Action Timer_ArmsFixed(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if(ClientIsAlive(client))
    {
        g_bArmsFixed[client] = true;

        Call_StartForward(g_fwdOnArmsFixed);
        Call_PushCell(client);
        Call_Finish();
    }

    return Plugin_Stop;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    g_bArmsFixed[GetClientOfUserId(event.GetInt("userid"))] = false;
}