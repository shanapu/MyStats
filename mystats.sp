/*
 * MyStats Plugin.
 * by: shanapu
 * https://github.com/shanapu/MyStats/
 *
 * A mix of Player Analytics by Dr. McKay
 * https://forums.alliedmods.net/showthread.php?p=2067976
 * and
 * RankMe by lokizito & kento
 * https://forums.alliedmods.net/showthread.php?t=155621
 * https://forums.alliedmods.net/showthread.php?p=2467665
 * but without rankings, just a pure data collector.
 *
 * Copyright (C) 2017-2018 Thomas Schmidt (shanapu)
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. if not, see <http://www.gnu.org/licenses/>.
 */

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <geoip>

#pragma semicolon 1
#pragma newdecls required

/******************************************************************************
                   Enums
******************************************************************************/

enum OS
{
	OS_UNKNOWN = -1,
	OS_WINDOWS = 0,
	OS_MAC = 1,
	OS_LINUX = 2,
	OS_TOTAL = 3
}

enum TEAM
{
	TEAM_NONE,
	TEAM_SPECTATOR,
	TEAM_T,
	TEAM_CT
}

enum STATUS
{
	DEAD,
	ALIVE,
	TOTAL
}

enum OBJECTIVE
{
	SCORE,
	KILL,
	DEATH,
	ASSIST,
	HEADSHOT,
	SUICIDE,
	TK,
	DAMAGE,
	DAMAGED,
	MVP,
	ROUND,
	WIN,
	ONEHP,
	BOMB_PLANTED,
	BOMB_DEFUSED,
	BOMB_EXPLODE,
	BOMB_ABORT,
	BOMB_FAKE,
	HOSTAGE,
	VIP_KILL,
	VIP_ESCAPE,
	VIP_PLAY
}

enum WEAPON
{
	KNIFE,
	GLOCK,
	HKP2000,
	USP_SILENCER,
	P250,
	DEAGLE,
	ELITE,
	FIVESEVEN,
	TEC9,
	CZ75A,
	REVOLVER,
	NOVA,
	XM1014,
	MAG7,
	SAWEDOFF,
	BIZON,
	MAC10,
	MP9,
	MP7,
	MP5SD,
	UMP45,
	P90,
	GALILAR,
	AK47,
	SG556,
	FAMAS,
	M4A1,
	M4A1_SILENCER,
	AUG,
	SSG08,
	AWP,
	SCAR20,
	G3SG1,
	M249,
	NEGEV,
	HEGRENADE,
	FLASHBANG,
	SMOKEGRENADE,
	INFERNO,
	DECOY,
	TASER
}

enum WEAPONSTATS
{
	NULL_HITBOX,
	HEAD,
	CHEST,
	STOMACH,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG,
	SHOT,
	HIT,
	KILL,
	HEADSHOT,
	NOSCOPE,
	DAMAGE,
	BOUGHT
}

/******************************************************************************
                   Variables
******************************************************************************/

bool g_bDBConnected = false;

static char g_sWeapons[41][] = {	"knife",
								"glock",
								"hkp2000",
								"usp_silencer",
								"p250",
								"deagle",
								"elite",
								"fiveseven",
								"tec9",
								"cz75a",
								"revolver",
								"nova",
								"xm1014",
								"mag7",
								"sawedoff",
								"bizon",
								"mac10",
								"mp9",
								"mp7",
								"mp5sd",
								"ump45",
								"p90",
								"galilar",
								"ak47",
								"sg556",
								"famas",
								"m4a1",
								"m4a1_silencer",
								"aug",
								"ssg08",
								"awp",
								"scar20",
								"g3sg1",
								"m249",
								"negev",
								"hegrenade",
								"flashbang",
								"smokegrenade",
								"inferno",
								"decoy",
								"taser"
};

char g_sServerName[64];
char g_sSQLBuffer[2048];
char g_sOSConVars[OS_TOTAL][32];
char g_sOS[MAXPLAYERS + 1][8];

ConVar gc_sServerName;
ConVar gc_iMinPlayer;
ConVar gc_bCountBot;

ConVar gc_bFFA;

Database g_hDB = null;

Handle g_hOS = null;

Handle g_hTimerQueryOS[MAXPLAYERS + 1];
Handle g_hTimerQueryMotd[MAXPLAYERS + 1];
Handle g_hTimerQueryClan[MAXPLAYERS + 1];

int g_iClientCount;
int g_iID[MAXPLAYERS + 1] = {-1, ...};
int g_iSessionID[MAXPLAYERS + 1] = {-1, ...};
int g_iQueriesOS[MAXPLAYERS + 1] = {-1, ...};
int g_iMotdConVar[MAXPLAYERS + 1] = {-1, ...};
int g_iClanID[MAXPLAYERS + 1] = {-1, ...};

int g_iObjectives[MAXPLAYERS + 1][TEAM][OBJECTIVE];
int g_iTimes[MAXPLAYERS + 1][TEAM][STATUS];
int g_iWeapons[MAXPLAYERS + 1][TEAM][WEAPON][WEAPONSTATS];

/******************************************************************************
                   Start
******************************************************************************/

public Plugin myinfo = 
{
	name = "MyStats",
	author = "shanapu",
	description = "A mix of Player Analytics & RankMe but without rankings.",
	version = "RC1",
	url = "https://github.com/shanapu/MyStats/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_forceupdate", Admin_Command_ForceUpdate, ADMFLAG_ROOT, "Force all player stats update to database");

	AutoExecConfig(true, "mystats", "MyStats");
	gc_sServerName = CreateConVar("mystats_server_name", "", "Unique server name - when blank <IP:port> will be used");
	gc_iMinPlayer = CreateConVar("mystats_min_player", "0", "Minium number of connected players until counting stats for logging is enabled", _, true, 0.0);
	gc_bCountBot = CreateConVar("mystats_count_bots", "1", "Counting kills/hits/times... against bots", _, true, 0.0, true, 1.0);

	gc_sServerName.AddChangeHook(OnSettingChanged);

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_mvp", Event_MVP);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("item_purchase", Event_ItemPurchase);

	HookEvent("hegrenade_detonate", Event_NadesDetonate);
	HookEvent("flashbang_detonate", Event_NadesDetonate);
	HookEvent("smokegrenade_detonate", Event_NadesDetonate);
	HookEvent("molotov_detonate", Event_NadesDetonate);
	HookEvent("decoy_detonate", Event_NadesDetonate);

	HookEvent("bomb_planted", Event_BombPlanted);
	HookEvent("bomb_abortplant", Event_BombAbortPlant);

	HookEvent("bomb_defused", Event_BombDefused);
	HookEvent("bomb_abortdefuse", Event_BombAbortDefuse);

	HookEvent("bomb_exploded", Event_BombExploded);

	HookEvent("hostage_rescued", Event_HostageRescued);
	HookEvent("vip_killed", Event_VipKilled);
	HookEvent("vip_escaped", Event_VipEscaped);

	g_hOS = LoadGameConfigFile("detect_os.games");
	if (g_hOS == INVALID_HANDLE)
	{
		LogError("Failed to load gamedata file detect_os.games.txt: Player OS will be unavailable.");
	}
	else
	{
		GameConfGetKeyValue(g_hOS, "Convar_Windows", g_sOSConVars[OS_WINDOWS], sizeof(g_sOSConVars[]));
		GameConfGetKeyValue(g_hOS, "Convar_Mac", g_sOSConVars[OS_MAC], sizeof(g_sOSConVars[]));
		GameConfGetKeyValue(g_hOS, "Convar_Linux", g_sOSConVars[OS_LINUX], sizeof(g_sOSConVars[]));
	}
}

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gc_sServerName)
	{
		strcopy(g_sServerName, sizeof(g_sServerName), newValue);
	}
}

/******************************************************************************
                   Command
******************************************************************************/

public Action Admin_Command_ForceUpdate(int client, int args)
{
	float fTime = GetEngineTime();

	if (!g_bDBConnected)
	{
		DB_Connect();
	}

	DB_UpdateAllPlayer(true);

	fTime = GetEngineTime() - fTime;
	ReplyToCommand(client, "Player update query executed in %0.3f seconds. New session started", fTime);

	return Plugin_Handled;
}

/******************************************************************************
                   Events (Objectives)
******************************************************************************/

public Action Event_ItemPurchase(Event event, char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, true, true))
		return;

	char weapon[32];
	event.GetString("weapon", weapon, sizeof(weapon));
	GetWeaponClassname(weapon, weapon, sizeof(weapon));
	ReplaceString(weapon, sizeof(weapon), "weapon_", "", false);
	int weaponNum = GetWeaponNum(weapon);

	g_iWeapons[client][GetClientTeam(client)][weaponNum][BOUGHT]++;
}

public Action Event_NadesDetonate(Event event, char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, true, true))
		return;

	char nade[32];
	StrCat(nade, sizeof(nade), name);
	ReplaceString(nade, sizeof(nade), "_detonate", "", false);
	if (StrEqual(nade, "molotov"))
	{
		StrCat(nade, sizeof(nade), "inferno");
	}

	int weaponNum = GetWeaponNum(nade);

	g_iWeapons[client][GetClientTeam(client)][weaponNum][SHOT]++;
}

public Action Event_WeaponFire(Event event, char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int attacker = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(attacker, true, true))
		return;

	char weapon[32];
	event.GetString("weapon", weapon, sizeof(weapon));
	GetWeaponClassname(weapon, weapon, sizeof(weapon));
	ReplaceString(weapon, sizeof(weapon), "weapon_", "", false);
	int weaponNum = GetWeaponNum(weapon);

	if (0 < weaponNum < 35 || weaponNum == 40)
	{
		int iTeam = GetClientTeam(attacker);
		g_iWeapons[attacker][iTeam][weaponNum][SHOT]++;

		if (weaponNum == 1 || weaponNum == 25) //glock or famas
		{
			if (GetEntProp(GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_bBurstMode") == 1)
			{
				g_iWeapons[attacker][iTeam][weaponNum][SHOT]++;
				g_iWeapons[attacker][iTeam][weaponNum][SHOT]++;
			}
		}
	}
}

public Action Event_PlayerHurt(Event event, char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int damage = event.GetInt("dmg_health");

	if (!IsValidClient(attacker, true, true) || attacker == victim)
		return;

	char weapon[32];
	int iWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

	if (!IsValidEntity(iWeapon))
		return;

	switch(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex")) {
		case 60: Format(weapon, sizeof(weapon), "weapon_m4a1_silencer");
		case 61: Format(weapon, sizeof(weapon), "weapon_usp_silencer");
		case 63: Format(weapon, sizeof(weapon), "weapon_cz75a");
		case 64: Format(weapon, sizeof(weapon), "weapon_revolver");
		default: GetEntityClassname(iWeapon, weapon, sizeof(weapon));
	}
	ReplaceString(weapon, sizeof(weapon), "weapon_", "", false);
	int weaponNum = GetWeaponNum(weapon);

	int hitgroup = event.GetInt("hitgroup");
	int iTeam = GetClientTeam(attacker);

	if (IsFakeClient(victim) && !gc_bCountBot.BoolValue)
	{
		g_iWeapons[attacker][iTeam][weaponNum][SHOT]--;
		return;
	}

	g_iWeapons[attacker][iTeam][weaponNum][HIT]++;
	g_iWeapons[attacker][iTeam][weaponNum][hitgroup]++;
	g_iWeapons[attacker][iTeam][weaponNum][DAMAGE] += damage;

	g_iObjectives[attacker][iTeam][DAMAGE] += damage;
	g_iObjectives[victim][GetClientTeam(victim)][DAMAGED] += damage;
}

public Action Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));

	if (IsFakeClient(victim) && !gc_bCountBot.BoolValue)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	bool headshot = event.GetBool("headshot");
	char weapon[32];
	event.GetString("weapon", weapon, sizeof(weapon));
	GetWeaponClassname(weapon, weapon, sizeof(weapon));
	ReplaceString(weapon, sizeof(weapon), "weapon_", "", false);
	int weaponNum = GetWeaponNum(weapon);

	int iAttackerTeam = 0;
	if (IsValidClient(attacker, true, true))
	{
		iAttackerTeam = GetClientTeam(attacker);
	}

	if (IsValidClient(assister, false, true))
	{
		g_iObjectives[assister][GetClientTeam(assister)][ASSIST]++;
	}

	if (!IsValidClient(attacker, true, true) || attacker == victim)
	{
		g_iObjectives[victim][GetClientTeam(victim) == CS_TEAM_CT ? 2 : 3][SUICIDE]++;
	}
	else if (iAttackerTeam == GetClientTeam(victim))
	{
		g_iObjectives[attacker][iAttackerTeam][gc_bFFA.BoolValue ? KILL : TK]++;
		g_iWeapons[attacker][iAttackerTeam][weaponNum][KILL]++;

		if (headshot)
		{
			g_iWeapons[attacker][iAttackerTeam][weaponNum][HEADSHOT]++;
			g_iObjectives[attacker][iAttackerTeam][HEADSHOT]++;
		}

		if(27 < weaponNum < 32 && GetEntProp(attacker, Prop_Data, "m_iFOV") <= 0 || GetEntProp(attacker, Prop_Data, "m_iFOV") == GetEntProp(attacker, Prop_Data, "m_iDefaultFOV"))
		{
			g_iWeapons[attacker][iAttackerTeam][weaponNum][NOSCOPE]++;
		}
	}
	else
	{
		g_iObjectives[victim][GetClientTeam(victim)][DEATH]++;
		g_iObjectives[attacker][iAttackerTeam][KILL]++;
		g_iWeapons[attacker][iAttackerTeam][weaponNum][KILL]++;

		if (headshot)
		{
			g_iWeapons[attacker][iAttackerTeam][weaponNum][HEADSHOT]++;
			g_iObjectives[attacker][iAttackerTeam][HEADSHOT]++;
		}

		if(27 < weaponNum < 32 && GetEntProp(attacker, Prop_Data, "m_iFOV") <= 0 || GetEntProp(attacker, Prop_Data, "m_iFOV") == GetEntProp(attacker, Prop_Data, "m_iDefaultFOV"))
		{
			g_iWeapons[attacker][iAttackerTeam][weaponNum][NOSCOPE]++;
		}
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, true))
			continue;

		g_iObjectives[i][GetClientTeam(i)][ROUND]++;
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int winner = event.GetInt("winner");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, true))
			continue;

		int iTeam = GetClientTeam(i);

		if (iTeam == winner)
		{
			g_iObjectives[i][winner][WIN]++;
		}

		if (GetClientHealth(i) == 1)
		{
			g_iObjectives[i][iTeam][ONEHP]++;
		}

		g_iObjectives[i][TEAM_T][BOMB_ABORT] = 0;
		g_iObjectives[i][TEAM_CT][BOMB_ABORT] = 0;
	}
}

public Action Event_MVP(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, false, true))
		return;

	g_iObjectives[client][GetClientTeam(client)][MVP]++;
}

public Action Event_BombAbortPlant(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, false, true))
		return;

	g_iObjectives[client][TEAM_T][BOMB_ABORT] = 1;
}


public Action Event_BombAbortDefuse(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, false, true))
		return;

	g_iObjectives[client][TEAM_CT][BOMB_ABORT] = 1;
}

public Action Event_BombPlanted(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, false, true))
		return;

	g_iObjectives[client][TEAM_T][BOMB_PLANTED]++;

	if (g_iObjectives[client][TEAM_T][BOMB_ABORT] == 1)
	{
		g_iObjectives[client][TEAM_T][BOMB_FAKE]++;
	}
}

public Action Event_BombDefused(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, false, true))
		return;

	g_iObjectives[client][TEAM_CT][BOMB_DEFUSED]++;

	if (g_iObjectives[client][TEAM_CT][BOMB_ABORT] == 1)
	{
		g_iObjectives[client][TEAM_CT][BOMB_FAKE]++;
	}
}

public Action Event_BombExploded(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, false, true))
		return;

	g_iObjectives[client][TEAM_T][BOMB_EXPLODE]++;
}

public Action Event_HostageRescued(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, false, true))
		return;

	g_iObjectives[client][TEAM_CT][HOSTAGE]++;
}

public Action Event_VipKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(attacker, false, true))
		return;

	g_iObjectives[attacker][TEAM_T][VIP_KILL]++;
	g_iObjectives[victim][TEAM_CT][VIP_PLAY]++;
}

public Action Event_VipEscaped(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, false, true))
		return;

	g_iObjectives[client][TEAM_CT][VIP_ESCAPE]++;
	g_iObjectives[client][TEAM_CT][VIP_PLAY]++;
}

/******************************************************************************
                   Sourcemod forwards & callbacks
******************************************************************************/

public void OnConfigsExecuted()
{
	gc_sServerName.GetString(g_sServerName, sizeof(g_sServerName));
	if (g_sServerName[0] == '\0' )
	{
		int ip = (FindConVar("hostip")).IntValue;
		Format(g_sServerName, sizeof(g_sServerName), "%d.%d.%d.%d:%d", ((ip & 0xFF000000) >> 24) & 0xFF, ((ip & 0x00FF0000) >> 16) & 0xFF, ((ip & 0x0000FF00) >>  8) & 0xFF, ((ip & 0x000000FF) >>  0) & 0xFF, (FindConVar("hostport")).IntValue);
	}

	gc_bFFA = FindConVar("mp_teammates_are_enemies");

	if (!g_bDBConnected)
	{
		DB_Connect();
	}
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_PlayTime, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
		return;

	g_iClientCount++;

	if (!g_bDBConnected)
	{
		DB_Connect();
	}

	for (int i = 0; i < view_as<int>(TEAM); i++)
	{
		for (int j = 0; j < view_as<int>(OBJECTIVE); j++)
		{
			g_iObjectives[client][i][j] = 0;
		}

		for (int j = 0; j < view_as<int>(STATUS); j++)
		{
			g_iTimes[client][i][j] = 0;
		}

		for (int j = 0; j < view_as<int>(WEAPON); j++)
		{
			for (int k = 0; k < view_as<int>(WEAPONSTATS); k++)
			{
				g_iWeapons[client][i][j][k] = 0;
			}
		}
	}

	DB_AddPlayer(client);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

	QueryClientConVar(client, "cl_disablehtmlmotd", Callback_QueryClientConVar_Motd);

	QueryClientConVar(client, "cl_clanid", Callback_QueryClientConVar_Clan);

	for(int i = 0; i < view_as<int>(OS_TOTAL); i++)
	{
		QueryClientConVar(client, g_sOSConVars[i], Callback_QueryClientConVar_OS);
	}

	int iUserID = GetClientUserId(client);

	g_hTimerQueryOS[client] = CreateTimer(20.0, Timer_TimeoutOS, iUserID);
	g_hTimerQueryMotd[client] = CreateTimer(20.0, Timer_TimeoutMOTD, iUserID);
	g_hTimerQueryClan[client] = CreateTimer(20.0, Timer_TimeoutClan, iUserID);
}

public void Callback_QueryClientConVar_Motd(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (g_hTimerQueryMotd[client] == INVALID_HANDLE)
		return; // Timed out

	if (result == ConVarQuery_Okay)
	{
		g_iMotdConVar[client] = StringToInt(cvarValue);
	}
	else
	{
		g_iMotdConVar[client] = -1;
	}

	CloseHandle(g_hTimerQueryMotd[client]);
	g_hTimerQueryMotd[client] = INVALID_HANDLE;
}

public void Callback_QueryClientConVar_Clan(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (g_hTimerQueryClan[client] == INVALID_HANDLE)
		return; // Timed out

	if (result == ConVarQuery_Okay)
	{
		g_iClanID[client] = StringToInt(cvarValue);
	}
	else
	{
		g_iClanID[client] = -1;
	}

	CloseHandle(g_hTimerQueryClan[client]);
	g_hTimerQueryClan[client] = INVALID_HANDLE;
}

public void Callback_QueryClientConVar_OS(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (g_hTimerQueryOS[client] == INVALID_HANDLE)
		return; // Timed out

	if (result == ConVarQuery_NotFound)
	{
		g_iQueriesOS[client]++;
		if (g_iQueriesOS[client] >= view_as<int>(OS_TOTAL))
		{
			CloseHandle(g_hTimerQueryOS[client]);
			g_hTimerQueryOS[client] = INVALID_HANDLE;
		}

		return;
	}
	else
	{
		int os;
		for( int i = 0; i < view_as<int>(OS_TOTAL); i++)
		{
			if (StrEqual(cvarName, g_sOSConVars[i]))
			{
				os = i;
				break;
			}
		}

		if (os == view_as<int>(OS_WINDOWS))
		{
			strcopy(g_sOS[client], sizeof(g_sOS[]), "Windows");
		}
		else if (os == view_as<int>(OS_MAC))
		{
			strcopy(g_sOS[client], sizeof(g_sOS[]), "MacOS");
		}
		else if (os == view_as<int>(OS_LINUX))
		{
			strcopy(g_sOS[client], sizeof(g_sOS[]), "Linux");
		}
		else
		{
			strcopy(g_sOS[client], sizeof(g_sOS[]), "Unknown");
		}

		CloseHandle(g_hTimerQueryOS[client]);
		g_hTimerQueryOS[client] = INVALID_HANDLE;
	}
}

public void OnPluginEnd()
{
	if (!g_bDBConnected)
	{
		DB_Connect();
	}

	DB_UpdateAllPlayer(false);
}

public void OnClientDisconnect(int client)
{
	if (!IsValidClient(client, false, true))
		return;

	if (!g_bDBConnected)
	{
		DB_Connect();
	}

	g_iClientCount--;

	g_iObjectives[client][TEAM_NONE][SCORE] = CS_GetClientContributionScore(client);

	DB_UpdatePlayer(client);
}

/******************************************************************************
                   SQL
******************************************************************************/

void DB_Connect()
{
	float time = GetEngineTime();
	Database.Connect(DB_CreateTables, "MyStats", time);
}

void DB_CreateTables(Database db, const char[] error, float time)
{
	if (db == null)
	{
		SetFailState("Failed to connect to SQL database. Error: %s", error);
	}

	if (g_hDB != null)
		return;

	g_hDB = db;

	g_bDBConnected = true;

	float newtime = GetEngineTime();
	PrintToServer("Database connection established in %0.3f seconds", newtime - time);

	Transaction txn = new Transaction();

	txn.AddQuery("CREATE TABLE if NOT EXISTS mystats_player (\
				  accountid INT(10) UNSIGNED NOT NULL,\
				  name VARCHAR(32) NOT NULL default '',\
				  steamid VARCHAR(32) NOT NULL default '',\
				  steamid64 VARCHAR(32) NOT NULL default '',\
				  ip VARCHAR(16) NOT NULL default '',\
				  flags VARCHAR(24) NOT NULL default '',\
				  clanid INT(10) UNSIGNED NOT NULL,\
				  firstjoin INT(10) UNSIGNED NOT NULL default 0,\
				  lastjoin INT(10) UNSIGNED NOT NULL default 0,\
				  firstserver VARCHAR(32) NOT NULL default '',\
				  lastserver VARCHAR(32) NOT NULL default '',\
				  country VARCHAR(16) NOT NULL default '',\
				  language VARCHAR(4) NOT NULL default '',\
				  os VARCHAR(8) NOT NULL default 'Unknown',\
				  PRIMARY KEY (`accountid`),\
				  UNIQUE INDEX `steamid` (`steamid`),\
				  UNIQUE INDEX `steamid64` (`steamid64`))\
				  ENGINE=InnoDB DEFAULT CHARSET=utf8");

	txn.AddQuery("CREATE TABLE if NOT EXISTS mystats_sessions (\
				  sid INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,\
				  accountid INT(10) UNSIGNED NOT NULL default 0,\
				  date INT(10) UNSIGNED NOT NULL default 0,\
				  server VARCHAR(32) NOT NULL default '',\
				  name VARCHAR(32) NOT NULL default '', \
				  ip VARCHAR(16) NOT NULL default '',\
				  flags VARCHAR(24) NOT NULL default '',\
				  clanid INT(10) UNSIGNED NOT NULL,\
				  map VARCHAR(16) NOT NULL default '',\
				  players INT(10) UNSIGNED NOT NULL default 0,\
				  score INT(10) UNSIGNED NOT NULL default 0,\
				  kills INT(10) UNSIGNED NOT NULL default 0,\
				  death INT(10) UNSIGNED NOT NULL default 0,\
				  motd TINYINT(1) SIGNED NOT NULL default -2,\
				  duration INT(10) UNSIGNED NOT NULL default 0,\
				  INDEX `accountid` (`accountid`),\
				  PRIMARY KEY (`sid`),\
				  INDEX `date` (`date`))\
				  ENGINE=InnoDB DEFAULT CHARSET=utf8");

	txn.AddQuery("CREATE TABLE if NOT EXISTS mystats_times (\
				  accountid INT(10) UNSIGNED NOT NULL,\
				  server VARCHAR(32) NOT NULL default '',\
				  aliveCT INT(10) UNSIGNED NOT NULL default 0,\
				  aliveT INT(10) UNSIGNED NOT NULL default 0,\
				  deadCT INT(10) UNSIGNED NOT NULL default 0,\
				  deadT INT(10) UNSIGNED NOT NULL default 0,\
				  spec INT(10) UNSIGNED NOT NULL default 0,\
				  idle INT(10) UNSIGNED NOT NULL default 0,\
				  duration INT(10) UNSIGNED NOT NULL default 0,\
				  PRIMARY KEY (`accountid`, `server`))\
				  ENGINE=InnoDB DEFAULT CHARSET=utf8");

	txn.AddQuery("CREATE TABLE if NOT EXISTS mystats_objectives (\
				  accountid INT(10) UNSIGNED NOT NULL,\
				  server VARCHAR(32) NOT NULL default '',\
				  score INT(10) UNSIGNED NOT NULL default 0,\
				  killCT INT(10) UNSIGNED NOT NULL default 0,\
				  killT INT(10) UNSIGNED NOT NULL default 0,\
				  deathCT INT(10) UNSIGNED NOT NULL default 0,\
				  deathT INT(10) UNSIGNED NOT NULL default 0,\
				  assistCT INT(10) UNSIGNED NOT NULL default 0,\
				  assistT INT(10) UNSIGNED NOT NULL default 0,\
				  headshotCT INT(10) UNSIGNED NOT NULL default 0,\
				  headshotT INT(10) UNSIGNED NOT NULL default 0,\
				  suicideCT INT(10) UNSIGNED NOT NULL default 0,\
				  suicideT INT(10) UNSIGNED NOT NULL default 0,\
				  teamkillCT INT(10) UNSIGNED NOT NULL default 0,\
				  teamkillT INT(10) UNSIGNED NOT NULL default 0,\
				  damageCT INT(10) UNSIGNED NOT NULL default 0,\
				  damageT INT(10) UNSIGNED NOT NULL default 0,\
				  damagedCT INT(10) UNSIGNED NOT NULL default 0,\
				  damagedT INT(10) UNSIGNED NOT NULL default 0,\
				  plant INT(10) UNSIGNED NOT NULL default 0,\
				  defuse INT(10) UNSIGNED NOT NULL default 0,\
				  fakeplant INT(10) UNSIGNED NOT NULL default 0,\
				  fakedefuse INT(10) UNSIGNED NOT NULL default 0,\
				  explode INT(10) UNSIGNED NOT NULL default 0,\
				  rescued INT(10) UNSIGNED NOT NULL default 0,\
				  vip_kill INT(10) UNSIGNED NOT NULL default 0,\
				  vip_escape INT(10) UNSIGNED NOT NULL default 0,\
				  vip_play INT(10) UNSIGNED NOT NULL default 0,\
				  mvpCT INT(10) UNSIGNED NOT NULL default 0,\
				  mvpT INT(10) UNSIGNED NOT NULL default 0,\
				  roundCT INT(10) UNSIGNED NOT NULL default 0,\
				  roundT INT(10) UNSIGNED NOT NULL default 0,\
				  winCT INT(10) UNSIGNED NOT NULL default 0,\
				  winT INT(10) UNSIGNED NOT NULL default 0,\
				  oneHPct INT(10) UNSIGNED NOT NULL default 0,\
				  oneHPt INT(10) UNSIGNED NOT NULL default 0,\
				  PRIMARY KEY (`accountid`, `server`))\
				  ENGINE=InnoDB DEFAULT CHARSET=utf8");

	txn.AddQuery("CREATE TABLE if NOT EXISTS mystats_weapons (\
				  accountid INT(10) UNSIGNED NOT NULL,\
				  server VARCHAR(32) NOT NULL default '',\
				  weapon VARCHAR(16) NOT NULL default '',\
				  killCT INT(10) UNSIGNED NOT NULL default 0,\
				  killT INT(10) UNSIGNED NOT NULL default 0,\
				  shotCT INT(10) UNSIGNED NOT NULL default 0,\
				  shotT INT(10) UNSIGNED NOT NULL default 0,\
				  hitCT INT(10) UNSIGNED NOT NULL default 0,\
				  hitT INT(10) UNSIGNED NOT NULL default 0,\
				  damageCT INT(10) UNSIGNED NOT NULL default 0,\
				  damageT INT(10) UNSIGNED NOT NULL default 0,\
				  headshotCT INT(10) UNSIGNED NOT NULL default 0,\
				  headshotT INT(10) UNSIGNED NOT NULL default 0,\
				  noscopeCT INT(10) UNSIGNED NOT NULL default 0,\
				  noscopeT INT(10) UNSIGNED NOT NULL default 0,\
				  boughtCT INT(10) UNSIGNED NOT NULL default 0,\
				  boughtT INT(10) UNSIGNED NOT NULL default 0,\
				  PRIMARY KEY (`accountid`, `server`, `weapon`))\
				  ENGINE=InnoDB DEFAULT CHARSET=utf8");

	txn.AddQuery("CREATE TABLE if NOT EXISTS mystats_hits (\
				  accountid INT(10) UNSIGNED NOT NULL,\
				  server VARCHAR(32) NOT NULL default '',\
				  weapon VARCHAR(16) NOT NULL default '',\
				  headCT INT(10) UNSIGNED NOT NULL default 0,\
				  headT INT(10) UNSIGNED NOT NULL default 0,\
				  chestCT INT(10) UNSIGNED NOT NULL default 0,\
				  chestT INT(10) UNSIGNED NOT NULL default 0,\
				  stomachCT INT(10) UNSIGNED NOT NULL default 0,\
				  stomachT INT(10) UNSIGNED NOT NULL default 0,\
				  left_armCT INT(10) UNSIGNED NOT NULL default 0,\
				  left_armT INT(10) UNSIGNED NOT NULL default 0,\
				  right_armCT INT(10) UNSIGNED NOT NULL default 0,\
				  right_armT INT(10) UNSIGNED NOT NULL default 0,\
				  left_legCT INT(10) UNSIGNED NOT NULL default 0,\
				  left_legT INT(10) UNSIGNED NOT NULL default 0,\
				  right_legCT INT(10) UNSIGNED NOT NULL default 0,\
				  right_legT INT(10) UNSIGNED NOT NULL default 0,\
				  PRIMARY KEY (`accountid`, `server`, `weapon`))\
				  ENGINE=InnoDB DEFAULT CHARSET=utf8");

	g_hDB.Execute(txn, DB_Transaction_Callback_Success, DB_Transaction_Callback_Error, newtime, DBPrio_High);
}

void DB_UpdateAllPlayer(bool force)
{
	float time = GetEngineTime();
	Transaction txn = new Transaction();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, true))
			continue;

		DB_UpdatePlayer_Objectives(i ,txn);
		DB_UpdatePlayer_Session(i ,txn);
		DB_UpdatePlayer_Weapons(i ,txn);
		DB_UpdatePlayer_Hits(i ,txn);
		DB_UpdatePlayer_Times(i ,txn);

		for (int h = 0; h < view_as<int>(TEAM); h++)
		{
			for (int j = 0; j < view_as<int>(OBJECTIVE); j++)
			{
				g_iObjectives[i][h][j] = 0;
			}

			for (int j = 0; j < view_as<int>(STATUS); j++)
			{
				g_iTimes[i][h][j] = 0;
			}

			for (int j = 0; j < view_as<int>(WEAPON); j++)
			{
				for (int k = 0; k < view_as<int>(WEAPONSTATS); k++)
				{
					g_iWeapons[i][h][j][k] = 0;
				}
			}
		}

		if (force)
		{
			DB_AddPlayer(i);
			OnClientPutInServer(i);
		}
	}

	g_hDB.Execute(txn, DB_Transaction_Callback_Success, DB_Transaction_Callback_Error, time, DBPrio_Normal);
}

void DB_UpdatePlayer(int client)
{
	float time = GetEngineTime();
	Transaction txn = new Transaction();

	DB_UpdatePlayer_Objectives(client ,txn);
	DB_UpdatePlayer_Session(client ,txn);
	DB_UpdatePlayer_Weapons(client ,txn);
	DB_UpdatePlayer_Hits(client ,txn);
	DB_UpdatePlayer_Times(client ,txn);

	g_hDB.Execute(txn, DB_Transaction_Callback_Success, DB_Transaction_Callback_Error, time, DBPrio_Normal);
}

public void DB_Transaction_Callback_Success(Database db, float time, int numQueries, Handle[] results, any[] queryData)
{
	float querytime = GetEngineTime() - time;
	PrintToServer("MyStats - Transaction Complete - Querys: %i in %0.3f seconds", numQueries, querytime);
}

public void DB_Transaction_Callback_Error(Database db, float time, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	float querytime = GetEngineTime() - time;
	LogError("Transaction Error: %s - Querys: %i - FailedIndex: %i after %0.3f seconds", error, numQueries, failIndex, querytime);
}

void DB_AddPlayer(int client)
{
	if (g_hDB == null)
		return;

	char name[32];
	GetClientName(client, name, sizeof(name));
	g_hDB.Escape(name, name, sizeof(name));

	char steamid[24];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
	{
		LogError("Couldn't get steamid of %L", client);
		return;
	}

	char steamid64[24];
	if (!GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64)))
	{
		LogError("Couldn't get steam ID64 of %L", client);
		return;
	}

	g_iID[client] = GetSteamAccountID(client, true);
	if (g_iID[client] == 0)
	{
		LogError("Couldn't get steam AccountID of %L", client);
		return;
	}

	char ip[24];
	GetClientIP(client, ip, sizeof(ip));

	char flags[32];
	GetAdminFlagsEx(client, flags);

	g_iTimes[client][TEAM_NONE][TOTAL] = GetTime();

	char country[24];
	GeoipCountry(ip, country, sizeof(country));

	char map[16];
	GetCurrentMap(map, sizeof(map));

	Format(g_sSQLBuffer, sizeof(g_sSQLBuffer),
		"INSERT IGNORE INTO mystats_player (accountid, name, steamid, steamid64, ip, flags, firstjoin, lastjoin, firstserver, lastserver, country) VALUES ('%i', '%s', '%s', '%s', '%s', '%s', '%i', '%i', '%s', '%s', '%s') ON DUPLICATE KEY UPDATE name = '%s', ip = '%s', flags = '%s', lastjoin = '%i', lastserver = '%s', country = '%s';", 
		g_iID[client], name, steamid, steamid64, ip, flags, g_iTimes[client][TEAM_NONE][TOTAL], g_iTimes[client][TEAM_NONE][TOTAL], g_sServerName, g_sServerName, country, name, ip, flags, g_iTimes[client][TEAM_NONE][TOTAL], g_sServerName, country);
	g_hDB.Query(DB_AddPlayer_Callback, g_sSQLBuffer, client ,DBPrio_High);

	Format(g_sSQLBuffer, sizeof(g_sSQLBuffer),
		"INSERT INTO mystats_sessions (date, server, accountid, name, ip, flags, map, players) VALUES ('%i', '%s', '%i', '%s', '%s', '%s', '%s', '%i')", 
		g_iTimes[client][TEAM_NONE][TOTAL], g_sServerName, g_iID[client], name, ip, flags, map, g_iClientCount - 1);
	g_hDB.Query(DB_AddConnection_Callback, g_sSQLBuffer, GetClientUserId(client), DBPrio_Normal);
}

public void DB_AddPlayer_Callback(Handle owner, Handle hndl, const char[] error, int client)
{
	if (hndl != INVALID_HANDLE)
		return;

	g_hDB = null;
	g_bDBConnected = false;
	LogError("Query Failed - Table: mystats_player (error: %s)", error);
}

public void DB_AddConnection_Callback(Handle owner, Handle hndl, const char[] error, int userid)
{
	if (hndl == INVALID_HANDLE)
	{
		g_hDB = null;
		g_bDBConnected = false;
		LogError("Query failed - Table: mystats_sessions (error: %s)", error);
	}
	else
	{
		int client = GetClientOfUserId(userid);
		g_iSessionID[client] = SQL_GetInsertId(hndl);
	}
}

void DB_UpdatePlayer_Session(int client, Transaction txn)
{
	int duration = GetTime() - g_iTimes[client][TEAM_NONE][TOTAL];

	char language[6];
	GetLanguageInfo(GetClientLanguage(client), language, sizeof(language), _, _);

	Format(g_sSQLBuffer, sizeof(g_sSQLBuffer),
		"UPDATE mystats_sessions, mystats_player SET mystats_sessions.score = '%i', mystats_sessions.kills = '%i', mystats_sessions.death = '%i', mystats_sessions.duration = '%i', mystats_sessions.motd = '%i', mystats_sessions.clanid = '%i', mystats_player.os = '%s' , mystats_player.language = '%s', mystats_player.clanid = '%i' WHERE mystats_player.accountid = '%i' AND mystats_sessions.sid = '%i'", 
		g_iObjectives[client][TEAM_NONE][SCORE], g_iObjectives[client][TEAM_CT][KILL] + g_iObjectives[client][TEAM_T][KILL], g_iObjectives[client][TEAM_CT][DEATH] + g_iObjectives[client][TEAM_T][DEATH], duration, g_iMotdConVar[client], g_iClanID[client], g_sOS[client], language, g_iClanID[client], g_iID[client], g_iSessionID[client]);
	txn.AddQuery(g_sSQLBuffer);
}

void DB_UpdatePlayer_Times(int client, Transaction txn)
{
	int duration = GetTime() - g_iTimes[client][TEAM_NONE][TOTAL];
	int idle = duration - g_iTimes[client][TEAM_CT][ALIVE] - g_iTimes[client][TEAM_T][ALIVE] - g_iTimes[client][TEAM_CT][DEAD] - g_iTimes[client][TEAM_T][DEAD] - g_iTimes[client][TEAM_SPECTATOR][DEAD];

	Format(g_sSQLBuffer, sizeof(g_sSQLBuffer),
		"INSERT IGNORE INTO mystats_times (accountid, server, aliveCT, aliveT, deadCT, deadT, spec, idle, duration) VALUES ('%i', '%s', '%i', '%i', '%i', '%i', '%i', '%i', '%i') ON DUPLICATE KEY UPDATE aliveCT = aliveCT + '%i', aliveT = aliveT + '%i', deadCT = deadCT + '%i', deadT = deadT + '%i', spec = spec + '%i', idle = idle + '%i', duration = duration + '%i';", 
		g_iID[client], g_sServerName, g_iTimes[client][TEAM_CT][ALIVE], g_iTimes[client][TEAM_T][ALIVE], g_iTimes[client][TEAM_CT][DEAD], g_iTimes[client][TEAM_T][DEAD], g_iTimes[client][TEAM_SPECTATOR][DEAD], idle, duration,
									  g_iTimes[client][TEAM_CT][ALIVE], g_iTimes[client][TEAM_T][ALIVE], g_iTimes[client][TEAM_CT][DEAD], g_iTimes[client][TEAM_T][DEAD], g_iTimes[client][TEAM_SPECTATOR][DEAD], idle, duration);
	txn.AddQuery(g_sSQLBuffer);
}

void DB_UpdatePlayer_Objectives(int client, Transaction txn)
{
	Format(g_sSQLBuffer, sizeof(g_sSQLBuffer),
		"INSERT IGNORE INTO mystats_objectives (accountid, server, score, killCT, killT, deathCT, deathT, assistCT, assistT, headshotCT, headshotT, suicideCT, suicideT, teamkillCT, teamkillT, damageCT, damageT, damagedCT, damagedT, plant, defuse, fakeplant, fakedefuse, explode, rescued, vip_kill, vip_escape, vip_play, mvpCT, mvpT, roundCT, roundT, winCT, winT, oneHPct, oneHPt) VALUES ('%i', '%s', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i') ON DUPLICATE KEY UPDATE score = score + '%i', killCT = killCT + '%i', killT = killT + '%i', deathCT = deathCT + '%i', deathT = deathT + '%i', assistCT = assistCT + '%i', assistT = assistT + '%i', headshotCT = headshotCT + '%i', headshotT = headshotT + '%i', suicideCT = suicideCT + '%i', suicideT = suicideT + '%i', teamkillCT = teamkillCT + '%i', teamkillT = teamkillT + '%i', damageCT = damageCT + '%i', damageT = damageT + '%i', damagedCT = damagedCT + '%i', damagedT = damagedT + '%i', plant = plant + '%i', defuse = defuse + '%i', fakeplant = fakeplant + '%i', fakedefuse = fakedefuse + '%i', explode = explode + '%i', rescued = rescued + '%i', vip_kill = vip_kill + '%i', vip_escape = vip_escape + '%i', vip_play = vip_play + '%i', mvpCT = mvpCT + '%i', mvpT = mvpT + '%i', roundCT = roundCT + '%i', roundT = roundT + '%i', winCT = winCT + '%i', winT = winT + '%i', oneHPct = oneHPct + '%i', oneHPt = oneHPt + '%i';", 
		g_iID[client], g_sServerName, g_iObjectives[client][TEAM_NONE][SCORE], g_iObjectives[client][TEAM_CT][KILL], g_iObjectives[client][TEAM_T][KILL], g_iObjectives[client][TEAM_CT][DEATH], g_iObjectives[client][TEAM_T][DEATH], g_iObjectives[client][TEAM_CT][ASSIST], g_iObjectives[client][TEAM_T][ASSIST], g_iObjectives[client][TEAM_CT][HEADSHOT], g_iObjectives[client][TEAM_T][HEADSHOT], g_iObjectives[client][TEAM_CT][SUICIDE], g_iObjectives[client][TEAM_T][SUICIDE], g_iObjectives[client][TEAM_CT][TK], g_iObjectives[client][TEAM_T][TK], g_iObjectives[client][TEAM_CT][DAMAGE], g_iObjectives[client][TEAM_T][DAMAGE], g_iObjectives[client][TEAM_CT][DAMAGED], g_iObjectives[client][TEAM_T][DAMAGED], g_iObjectives[client][TEAM_T][BOMB_PLANTED], g_iObjectives[client][TEAM_CT][BOMB_DEFUSED], g_iObjectives[client][TEAM_T][BOMB_FAKE], g_iObjectives[client][TEAM_CT][BOMB_FAKE], g_iObjectives[client][TEAM_T][BOMB_EXPLODE], g_iObjectives[client][TEAM_CT][HOSTAGE], g_iObjectives[client][TEAM_T][VIP_KILL], g_iObjectives[client][TEAM_CT][VIP_ESCAPE], g_iObjectives[client][TEAM_CT][VIP_PLAY], g_iObjectives[client][TEAM_CT][MVP], g_iObjectives[client][TEAM_T][MVP], g_iObjectives[client][TEAM_CT][ROUND], g_iObjectives[client][TEAM_T][ROUND], g_iObjectives[client][TEAM_CT][WIN], g_iObjectives[client][TEAM_T][WIN], g_iObjectives[client][TEAM_CT][ONEHP], g_iObjectives[client][TEAM_T][ONEHP], 
									  g_iObjectives[client][TEAM_NONE][SCORE], g_iObjectives[client][TEAM_CT][KILL], g_iObjectives[client][TEAM_T][KILL], g_iObjectives[client][TEAM_CT][DEATH], g_iObjectives[client][TEAM_T][DEATH], g_iObjectives[client][TEAM_CT][ASSIST], g_iObjectives[client][TEAM_T][ASSIST], g_iObjectives[client][TEAM_CT][HEADSHOT], g_iObjectives[client][TEAM_T][HEADSHOT], g_iObjectives[client][TEAM_CT][SUICIDE], g_iObjectives[client][TEAM_T][SUICIDE], g_iObjectives[client][TEAM_CT][TK], g_iObjectives[client][TEAM_T][TK], g_iObjectives[client][TEAM_CT][DAMAGE], g_iObjectives[client][TEAM_T][DAMAGE], g_iObjectives[client][TEAM_CT][DAMAGED], g_iObjectives[client][TEAM_T][DAMAGED], g_iObjectives[client][TEAM_T][BOMB_PLANTED], g_iObjectives[client][TEAM_CT][BOMB_DEFUSED], g_iObjectives[client][TEAM_T][BOMB_FAKE], g_iObjectives[client][TEAM_CT][BOMB_FAKE], g_iObjectives[client][TEAM_T][BOMB_EXPLODE], g_iObjectives[client][TEAM_CT][HOSTAGE], g_iObjectives[client][TEAM_T][VIP_KILL], g_iObjectives[client][TEAM_CT][VIP_ESCAPE], g_iObjectives[client][TEAM_CT][VIP_PLAY], g_iObjectives[client][TEAM_CT][MVP], g_iObjectives[client][TEAM_T][MVP], g_iObjectives[client][TEAM_CT][ROUND], g_iObjectives[client][TEAM_T][ROUND], g_iObjectives[client][TEAM_CT][WIN], g_iObjectives[client][TEAM_T][WIN], g_iObjectives[client][TEAM_CT][ONEHP], g_iObjectives[client][TEAM_T][ONEHP]);
	txn.AddQuery(g_sSQLBuffer);
}

void DB_UpdatePlayer_Weapons(int client, Transaction txn)
{
	for (int weaponNum = 0; weaponNum < view_as<int>(WEAPON); weaponNum++)
	{
		Format(g_sSQLBuffer, sizeof(g_sSQLBuffer),
			"INSERT IGNORE INTO mystats_weapons (accountid, server, weapon, killCT, killT, shotCT, shotT, hitCT, hitT, damageCT, damageT, headshotCT, headshotT, noscopeCT, noscopeT, boughtCT, boughtT) VALUES ('%i', '%s', '%s', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i') ON DUPLICATE KEY UPDATE killCT = killCT + '%i', killT = killT + '%i', shotCT = shotCT + '%i', shotT = shotT + '%i', hitCT = hitCT + '%i', hitT = hitT + '%i', damageCT = damageCT + '%i', damageT = damageT + '%i', headshotCT = headshotCT + '%i', headshotT = headshotT + '%i', noscopeCT = noscopeCT + '%i', noscopeT = headshotT + '%i', boughtCT = boughtCT + '%i', boughtT = boughtT + '%i';", 
			g_iID[client], g_sServerName, g_sWeapons[weaponNum], g_iWeapons[client][TEAM_CT][weaponNum][KILL], g_iWeapons[client][TEAM_T][weaponNum][KILL], g_iWeapons[client][TEAM_CT][weaponNum][SHOT], g_iWeapons[client][TEAM_T][weaponNum][SHOT], g_iWeapons[client][TEAM_CT][weaponNum][HIT], g_iWeapons[client][TEAM_T][weaponNum][HIT], g_iWeapons[client][TEAM_CT][weaponNum][DAMAGE], g_iWeapons[client][TEAM_T][weaponNum][DAMAGE], g_iWeapons[client][TEAM_CT][weaponNum][HEADSHOT], g_iWeapons[client][TEAM_T][weaponNum][HEADSHOT], g_iWeapons[client][TEAM_CT][weaponNum][NOSCOPE], g_iWeapons[client][TEAM_T][weaponNum][NOSCOPE], g_iWeapons[client][TEAM_CT][weaponNum][BOUGHT], g_iWeapons[client][TEAM_T][weaponNum][BOUGHT], 
																 g_iWeapons[client][TEAM_CT][weaponNum][KILL], g_iWeapons[client][TEAM_T][weaponNum][KILL], g_iWeapons[client][TEAM_CT][weaponNum][SHOT], g_iWeapons[client][TEAM_T][weaponNum][SHOT], g_iWeapons[client][TEAM_CT][weaponNum][HIT], g_iWeapons[client][TEAM_T][weaponNum][HIT], g_iWeapons[client][TEAM_CT][weaponNum][DAMAGE], g_iWeapons[client][TEAM_T][weaponNum][DAMAGE], g_iWeapons[client][TEAM_CT][weaponNum][HEADSHOT], g_iWeapons[client][TEAM_T][weaponNum][HEADSHOT], g_iWeapons[client][TEAM_CT][weaponNum][NOSCOPE], g_iWeapons[client][TEAM_T][weaponNum][NOSCOPE], g_iWeapons[client][TEAM_CT][weaponNum][BOUGHT], g_iWeapons[client][TEAM_T][weaponNum][BOUGHT]);
		txn.AddQuery(g_sSQLBuffer);
	}
}

void DB_UpdatePlayer_Hits(int client, Transaction txn)
{
	for (int weaponNum = 0; weaponNum < view_as<int>(WEAPON); weaponNum++)
	{
		Format(g_sSQLBuffer, sizeof(g_sSQLBuffer),
			"INSERT IGNORE INTO mystats_hits (accountid, server, weapon, headCT, headT, chestCT, chestT, stomachCT, stomachT, left_armCT, left_armT, right_armCT, right_armT, left_legCT, left_legT, right_legCT, right_legT) VALUES ('%i', '%s', '%s', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i') ON DUPLICATE KEY UPDATE headCT = headCT + '%i', headT = headT + '%i', chestCT = chestCT + '%i', chestT = chestT + '%i', stomachCT = stomachCT + '%i', stomachT = stomachT + '%i', left_armCT = left_armCT + '%i', left_armT = left_armT + '%i', right_armCT = right_armCT + '%i', right_armT = right_armT + '%i', left_legCT = left_legCT + '%i', left_legT = left_legT + '%i', right_legCT = right_legCT + '%i', right_legT = right_legT + '%i';", 
			g_iID[client], g_sServerName, g_sWeapons[weaponNum], g_iWeapons[client][TEAM_CT][weaponNum][HEAD], g_iWeapons[client][TEAM_T][weaponNum][HEAD], g_iWeapons[client][TEAM_CT][weaponNum][CHEST], g_iWeapons[client][TEAM_T][weaponNum][CHEST], g_iWeapons[client][TEAM_CT][weaponNum][STOMACH], g_iWeapons[client][TEAM_T][weaponNum][STOMACH], g_iWeapons[client][TEAM_CT][weaponNum][LEFT_ARM], g_iWeapons[client][TEAM_T][weaponNum][LEFT_ARM], g_iWeapons[client][TEAM_CT][weaponNum][RIGHT_ARM], g_iWeapons[client][TEAM_T][weaponNum][RIGHT_ARM], g_iWeapons[client][TEAM_CT][weaponNum][LEFT_LEG], g_iWeapons[client][TEAM_T][weaponNum][LEFT_LEG], g_iWeapons[client][TEAM_CT][weaponNum][RIGHT_LEG], g_iWeapons[client][TEAM_T][weaponNum][RIGHT_LEG], 
																 g_iWeapons[client][TEAM_CT][weaponNum][HEAD], g_iWeapons[client][TEAM_T][weaponNum][HEAD], g_iWeapons[client][TEAM_CT][weaponNum][CHEST], g_iWeapons[client][TEAM_T][weaponNum][CHEST], g_iWeapons[client][TEAM_CT][weaponNum][STOMACH], g_iWeapons[client][TEAM_T][weaponNum][STOMACH], g_iWeapons[client][TEAM_CT][weaponNum][LEFT_ARM], g_iWeapons[client][TEAM_T][weaponNum][LEFT_ARM], g_iWeapons[client][TEAM_CT][weaponNum][RIGHT_ARM], g_iWeapons[client][TEAM_T][weaponNum][RIGHT_ARM], g_iWeapons[client][TEAM_CT][weaponNum][LEFT_LEG], g_iWeapons[client][TEAM_T][weaponNum][LEFT_LEG], g_iWeapons[client][TEAM_CT][weaponNum][RIGHT_LEG], g_iWeapons[client][TEAM_T][weaponNum][RIGHT_LEG]);
		txn.AddQuery(g_sSQLBuffer);
	}
}

/******************************************************************************
                   Timer
******************************************************************************/

public Action Timer_PlayTime(Handle timer)
{
	if (g_iClientCount < gc_iMinPlayer.IntValue)
		return Plugin_Continue;

	for(int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		g_iTimes[i][GetClientTeam(i)][IsPlayerAlive(i)]++;
	}

	return Plugin_Continue;
}

public Action Timer_TimeoutOS(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsValidClient(client, false, true))
		return;

	strcopy(g_sOS[client], sizeof(g_sOS[]), "Unknown");

	g_hTimerQueryOS[client] = INVALID_HANDLE;
}

public Action Timer_TimeoutMOTD(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsValidClient(client, false, true))
		return;

	g_iMotdConVar[client] = -1;
	g_hTimerQueryMotd[client] = INVALID_HANDLE;
}

public Action Timer_TimeoutClan(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsValidClient(client, false, true))
		return;

	g_iClanID[client] = -1;
	g_hTimerQueryClan[client] = INVALID_HANDLE;
}

/******************************************************************************
                   Functions
******************************************************************************/

int GetWeaponNum(char[] weaponname)
{
	int weaponNum;

	for (weaponNum = 0; weaponNum < view_as<int>(WEAPON); weaponNum++)
	{
		if (StrEqual(weaponname, g_sWeapons[weaponNum]))
			break;
	}

	return weaponNum;
}

void GetAdminFlagsEx(int client, char[] buffer)
{
	AdminFlag flags[32];
	int num = FlagBitsToArray(GetUserFlagBits(client), flags, sizeof(flags));
	for(int i = 0; i < num; i++)
	{
		int flagchar;
		FindFlagChar(flags[i], flagchar);
		buffer[i] = flagchar;
	}

	buffer[num] = '\0';
}

void GetWeaponClassname(char[] weapon, char[] buffer, int buffersize)
{
	int index = -1;
	while (FindEntityByClassname(index, weapon) && IsValidEntity(index))
	{
		switch(GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex"))
		{
			case 23: Format(buffer, buffersize, "weapon_mp5sd");
			case 60: Format(buffer, buffersize, "weapon_m4a1_silencer");
			case 61: Format(buffer, buffersize, "weapon_usp_silencer");
			case 63: Format(buffer, buffersize, "weapon_cz75a");
			case 64: Format(buffer, buffersize, "weapon_revolver");
			default: GetEntityClassname(index, buffer, buffersize);
		}
	}
}

bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}