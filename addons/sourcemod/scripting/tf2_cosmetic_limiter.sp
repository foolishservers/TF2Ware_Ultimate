#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION "1.0.1"

#define SLOT_WEARABLES  7
#define SLOT_TAUNT1     11
#define SLOT_TAUNT8     18

public Plugin myinfo =
{
	name        = "[TF2] Dynamic Cosmetic Limiter",
	author      = "Assistant",
	description = "Prevents cosmetics from loading when player count reaches a threshold",
	version     = PLUGIN_VERSION,
	url         = ""
};

ConVar g_cvEnable;
ConVar g_cvThreshold;
ConVar g_cvIncludeBots;
ConVar g_cvAllowTaunts;

DynamicHook g_DHook_CTFPlayerInitClass;
DynamicDetour g_DDetour_CTFPlayerGetLoadoutItem;

bool g_bInitSuccess = false;
bool g_bInInitClass[MAXPLAYERS + 1] = { false, ... };

public void OnPluginStart()
{
	CreateConVar("sm_cosmetic_limiter_version", PLUGIN_VERSION, "TF2 Cosmetic Limiter Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_cvEnable       = CreateConVar("sm_cosmetic_limiter_enable", "1", "Enable dynamic cosmetic limiter (0 = Disable, 1 = Enable)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvThreshold    = CreateConVar("sm_cosmetic_limiter_threshold", "64", "Player count threshold (connecting + in-game) to block cosmetics. 0 = always block if enabled.", FCVAR_NONE, true, 0.0);
	g_cvIncludeBots  = CreateConVar("sm_cosmetic_limiter_include_bots", "0", "Include bots when counting total connected players (0 = Exclude bots, 1 = Include bots)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvAllowTaunts  = CreateConVar("sm_cosmetic_limiter_taunts", "8", "Allow up to N taunts when cosmetics are blocked (0 to 8)", FCVAR_NONE, true, 0.0, true, 8.0);

	AutoExecConfig(true, "tf2_cosmetic_limiter");

	// Gamedata setup
	GameData gamedata = new GameData("tf2_cosmetic_limiter");
	if (!gamedata)
	{
		SetFailState("Failed to load gamedata 'tf2_cosmetic_limiter.txt'");
		return;
	}

	g_DHook_CTFPlayerInitClass = DynamicHook.FromConf(gamedata, "CTFPlayer::InitClass");
	if (!g_DHook_CTFPlayerInitClass)
	{
		delete gamedata;
		SetFailState("Failed to setup hook for CTFPlayer::InitClass");
		return;
	}

	g_DDetour_CTFPlayerGetLoadoutItem = DynamicDetour.FromConf(gamedata, "CTFPlayer::GetLoadoutItem");
	if (!g_DDetour_CTFPlayerGetLoadoutItem)
	{
		delete gamedata;
		SetFailState("Failed to setup detour for CTFPlayer::GetLoadoutItem");
		return;
	}

	delete gamedata;

	g_DDetour_CTFPlayerGetLoadoutItem.Enable(Hook_Pre, DHookPre_CTFPlayerGetLoadoutItem);
	g_bInitSuccess = true;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void OnPluginEnd()
{
	if (g_bInitSuccess && g_DDetour_CTFPlayerGetLoadoutItem)
	{
		g_DDetour_CTFPlayerGetLoadoutItem.Disable(Hook_Pre, DHookPre_CTFPlayerGetLoadoutItem);
	}
}

public void OnClientPutInServer(int client)
{
	if (!g_bInitSuccess)
		return;

	if (g_DHook_CTFPlayerInitClass)
	{
		g_DHook_CTFPlayerInitClass.HookEntity(Hook_Pre, client, DHookPre_CTFPlayerInitClass);
		g_DHook_CTFPlayerInitClass.HookEntity(Hook_Post, client, DHookPost_CTFPlayerInitClass);
	}
}

public void OnClientDisconnect(int client)
{
	g_bInInitClass[client] = false;
}

// Counts both connecting and in-game players
int GetTotalConnectedPlayerCount()
{
	int count = 0;
	bool includeBots = g_cvIncludeBots.BoolValue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (!includeBots && IsFakeClient(i))
				continue;

			count++;
		}
	}
	return count;
}

// Determines if cosmetics should be blocked based on settings and player count
bool ShouldBlockCosmetics()
{
	if (!g_cvEnable.BoolValue)
		return false;

	int threshold = g_cvThreshold.IntValue;
	if (threshold <= 0)
		return true; // 0 means always active

	return (GetTotalConnectedPlayerCount() >= threshold);
}

MRESReturn DHookPre_CTFPlayerInitClass(int client)
{
	g_bInInitClass[client] = true;
	return MRES_Ignored;
}

MRESReturn DHookPost_CTFPlayerInitClass(int client)
{
	g_bInInitClass[client] = false;
	return MRES_Ignored;
}

MRESReturn DHookPre_CTFPlayerGetLoadoutItem(int client, DHookReturn ret, DHookParam param)
{
	// Only intercept during player class init/spawn
	if (client > 0 && client <= MaxClients && g_bInInitClass[client])
	{
		if (ShouldBlockCosmetics())
		{
			int slot = param.Get(2);

			// Taunt slots (11 ~ 18)
			int allowedTaunts = g_cvAllowTaunts.IntValue;
			if (slot >= SLOT_TAUNT1 && slot < (SLOT_TAUNT1 + allowedTaunts))
			{
				return MRES_Ignored;
			}

			// Wearables / Cosmetics (slot 7 ~ 10)
			if (slot >= SLOT_WEARABLES && slot < SLOT_TAUNT1)
			{
				// Block cosmetic by passing invalid slot (-1), returning null item
				param.Set(2, -1);
				param.Set(3, false); // suppress failure warning spew
				return MRES_ChangedHandled;
			}
		}
	}

	return MRES_Ignored;
}
