#include <open.mp>
#include <a_sampdb>
#include <a_players>
#include <a_samp>
#include <a_vehicles>
#include <a_objects>
#include <string>
#include <console>

#define MAX_HOUSES              (256)
#define MAX_BUSINESSES          (128)
#define MAX_FACTIONS            (16)
#define MAX_FRACTION_RANKS      (16)
#define MAX_GZONES              (64)
#define MAX_PLAYER_VEHICLES     (16)
#define MAX_FURNITURE_ITEMS     (32)
#define MAX_RADIO_CHANNELS      (16)
#define MAX_AUDIO_STREAMS       (32)
#define MAX_MEDICAL_PROCEDURES  (16)
#define MAX_OFFLINE_ACTIONS     (256)
#define MAX_QUESTS              (32)
#define MAX_PLAYER_QUESTS       (8)
#define PAYDAY_INTERVAL         (60 * 60)

#define COLOR_WHITE             (0xFFFFFFFF)
#define COLOR_GREEN             (0x3CB371AA)
#define COLOR_YELLOW            (0xFFFF00AA)
#define COLOR_RED               (0xFF4500AA)
#define COLOR_BLUE              (0x1E90FFAA)
#define COLOR_GREY              (0xA9A9A9AA)
#define COLOR_VIP               (0xFFD700AA)
#define COLOR_ADMIN             (0xDC143CAA)
#define COLOR_RADIO             (0x87CEFAAA)

#define SERVER_NAME             "open.mp Roleplay"
#define SCRIPT_VERSION          "0.1.0"

#define SendServerMessage(%0,%1,%2...) do { \
    new __text[256]; \
    format(__text, sizeof(__text), %2); \
    SendClientMessage(%0, %1, __text); \
} while (0)

#define Broadcast(%0,%1...) do { \
    new __msg[256]; \
    format(__msg, sizeof(__msg), %1); \
    SendClientMessageToAll(%0, __msg); \
} while (0)

#define IsLoggedIn(%0)        (gPlayerData[%0][E_PSTATE_LOGGED])
#define IsAdmin(%0,%1)        (gPlayerData[%0][E_PADMIN_LEVEL] >= (%1))
#define IsVip(%0)             (gPlayerData[%0][E_PVIP_LEVEL] > 0 && (gPlayerData[%0][E_PVIP_EXPIRE] == 0 || gPlayerData[%0][E_PVIP_EXPIRE] > gettime()))

DB:gDatabase;
new gPaydayTimer;
new gStateTreasury = 5000000;
new Float:gTaxRate = 0.05;

stock GetCommandToken(const input[], &idx, dest[], size)
{
    while (input[idx] == ' ' || input[idx] == '\t') idx++;
    if (!input[idx])
    {
        dest[0] = '\0';
        return false;
    }
    new i = 0;
    while (input[idx] && input[idx] != ' ')
    {
        if (i < size - 1) dest[i++] = input[idx];
        idx++;
    }
    dest[i] = '\0';
    while (input[idx] == ' ' || input[idx] == '\t') idx++;
    return i > 0;
}

stock GetCommandRemainder(const input[], idx, dest[], size)
{
    while (input[idx] == ' ' || input[idx] == '\t') idx++;
    new len = strlen(input);
    if (idx >= len)
    {
        dest[0] = '\0';
        return;
    }
    new copy = len - idx;
    if (copy > size - 1) copy = size - 1;
    strmid(dest, input, idx, idx + copy, size);
    dest[copy] = '\0';
}

stock bool:GetIntToken(const input[], &idx, &value)
{
    new token[16];
    if (!GetCommandToken(input, idx, token, sizeof(token))) return false;
    value = strval(token);
    return true;
}

stock bool:GetFloatToken(const input[], &idx, Float:&value)
{
    new token[24];
    if (!GetCommandToken(input, idx, token, sizeof(token))) return false;
    value = floatstr(token);
    return true;
}

enum E_PLAYER_DATA
{
    E_PACCOUNT_ID,
    bool:E_PSTATE_LOGGED,
    bool:E_PSTATE_REGISTER,
    E_PNAME[MAX_PLAYER_NAME+1],
    E_PPASSWORD[65],
    E_PSALT[17],
    E_PADMIN_LEVEL,
    E_PVIP_LEVEL,
    E_PVIP_EXPIRE,
    E_PPREFIX[24],
    E_PLEVEL,
    E_PEXP,
    E_PMONEY,
    E_PBANK,
    E_PLAST_PAYDAY,
    E_PMAX_ONLINE,
    E_PONLINE_SECONDS,
    E_PLAST_LOGIN,
    E_PIP[16],
    E_POFFLINE_FINE,
    E_POFFLINE_REWARD,
    E_POFFLINE_JAIL,
    E_PJAIL_TIME,
    E_PJAIL_REASON[64],
    E_PWANTED_LEVEL,
    E_PHEALTH,
    E_PARMOR,
    E_PSKIN,
    E_PJOB,
    E_PFRACTION_ID,
    E_PFRACTION_RANK,
    E_PMEDCARD,
    E_PMEDCARD_EXPIRE,
    E_PMEDCARD_NOTES[64],
    E_PHOUSE_ID,
    E_PBUSINESS_ID,
    E_PVEHICLE_SLOTS,
    E_PRADIO_CHANNEL,
    E_PQUEST_PROGRESS[MAX_PLAYER_QUESTS],
    E_PQUEST_FLAGS,
    E_PMEDICAL_FLAGS,
    E_PCAPTURE_SCORE,
    E_PTOTAL_ARRESTS,
    E_PTOTAL_HEALS
};

new gPlayerData[MAX_PLAYERS][E_PLAYER_DATA];

enum E_HOUSE_DATA
{
    E_HOUSE_ID,
    E_HOUSE_OWNER[24],
    E_HOUSE_PRICE,
    E_HOUSE_INTERIOR,
    Float:E_HOUSE_ENTER[3],
    Float:E_HOUSE_EXIT[3],
    E_HOUSE_LOCKED,
    E_HOUSE_STORAGE_MONEY,
    E_HOUSE_STORAGE_MATERIALS,
    E_HOUSE_STORAGE_DRUGS,
    E_HOUSE_UPGRADES,
    E_HOUSE_WORLD,
    E_HOUSE_PICKUP,
    E_HOUSE_TEXT,
    E_HOUSE_FURNITURE_COUNT,
    E_HOUSE_FURNITURE[MAX_FURNITURE_ITEMS],
    E_HOUSE_SAFE_PASSWORD[32]
};

new gHouseData[MAX_HOUSES][E_HOUSE_DATA];
new gTotalHouses;

enum E_BUSINESS_DATA
{
    E_BIZ_ID,
    E_BIZ_OWNER[24],
    E_BIZ_PRICE,
    E_BIZ_TYPE,
    E_BIZ_PRODUCTS,
    E_BIZ_MAX_PRODUCTS,
    E_BIZ_BALANCE,
    E_BIZ_TAX,
    E_BIZ_UPKEEP,
    Float:E_BIZ_POS[4],
    E_BIZ_PICKUP,
    E_BIZ_TEXT,
    E_BIZ_MENU_NAME[24],
    E_BIZ_MAFIA,
    E_BIZ_WAR_STATE,
    E_BIZ_WAR_TIMER,
    E_BIZ_LAST_RESTOCK
};

new gBusinessData[MAX_BUSINESSES][E_BUSINESS_DATA];
new gTotalBusinesses;

enum E_FRACTION_DATA
{
    E_FRACTION_ID,
    E_FRACTION_NAME[32],
    E_FRACTION_TYPE,
    E_FRACTION_COLOR,
    E_FRACTION_RANKS[MAX_FRACTION_RANKS][24],
    Float:E_FRACTION_SPAWN[4],
    E_FRACTION_PAYCHECK,
    E_FRACTION_PERMISSIONS,
    E_FRACTION_RADIO,
    E_FRACTION_MAX_MEMBERS
};

new gFractionData[MAX_FACTIONS][E_FRACTION_DATA];
new gTotalFractions;

enum E_GZONE_DATA
{
    E_GZONE_ID,
    E_GZONE_OWNER,
    E_GZONE_COLOR,
    Float:E_GZONE_MIN[3],
    Float:E_GZONE_MAX[3],
    E_GZONE_CAPTURE_TIME,
    E_GZONE_CAPTURE_FACTION,
    E_GZONE_CAPTURE_TIMER
};

new gGangZones[MAX_GZONES][E_GZONE_DATA];
new gTotalGZones;

enum E_RADIO_DATA
{
    E_RADIO_ID,
    E_RADIO_NAME[32],
    E_RADIO_URL[96],
    E_RADIO_TYPE,
    E_RADIO_PASSWORD[32],
    E_RADIO_SLOT_LIMIT
};

new gRadioData[MAX_RADIO_CHANNELS][E_RADIO_DATA];
new gTotalRadioChannels;

enum E_AUDIO_STREAM_DATA
{
    E_AUDIO_ID,
    E_AUDIO_NAME[32],
    E_AUDIO_URL[96]
};

new gAudioStreamData[MAX_AUDIO_STREAMS][E_AUDIO_STREAM_DATA];
new gTotalAudioStreams;

enum E_MEDICAL_DATA
{
    E_MED_ID,
    E_MED_NAME[32],
    E_MED_COST,
    E_MED_REQUIREMENTS,
    E_MED_EFFECT
};

new gMedicalData[MAX_MEDICAL_PROCEDURES][E_MEDICAL_DATA];
new gTotalMedicalProcedures;

enum E_QUEST_DATA
{
    E_QUEST_ID,
    E_QUEST_NAME[32],
    E_QUEST_DESC[128],
    E_QUEST_REQUIREMENTS,
    E_QUEST_REWARD_EXP,
    E_QUEST_REWARD_MONEY
};

new gQuestData[MAX_QUESTS][E_QUEST_DATA];
new gTotalQuests;

stock ResetPlayerData(playerid)
{
    gPlayerData[playerid][E_PACCOUNT_ID] = 0;
    gPlayerData[playerid][E_PSTATE_LOGGED] = false;
    gPlayerData[playerid][E_PSTATE_REGISTER] = false;
    gPlayerData[playerid][E_PPASSWORD][0] = '\0';
    gPlayerData[playerid][E_PSALT][0] = '\0';
    gPlayerData[playerid][E_PADMIN_LEVEL] = 0;
    gPlayerData[playerid][E_PVIP_LEVEL] = 0;
    gPlayerData[playerid][E_PVIP_EXPIRE] = 0;
    gPlayerData[playerid][E_PPREFIX][0] = '\0';
    gPlayerData[playerid][E_PLEVEL] = 1;
    gPlayerData[playerid][E_PEXP] = 0;
    gPlayerData[playerid][E_PMONEY] = 5000;
    gPlayerData[playerid][E_PBANK] = 2500;
    gPlayerData[playerid][E_PLAST_PAYDAY] = gettime();
    gPlayerData[playerid][E_PMAX_ONLINE] = 0;
    gPlayerData[playerid][E_PONLINE_SECONDS] = 0;
    gPlayerData[playerid][E_PLAST_LOGIN] = gettime();
    gPlayerData[playerid][E_PIP][0] = '\0';
    gPlayerData[playerid][E_POFFLINE_FINE] = 0;
    gPlayerData[playerid][E_POFFLINE_REWARD] = 0;
    gPlayerData[playerid][E_POFFLINE_JAIL] = 0;
    gPlayerData[playerid][E_PJAIL_TIME] = 0;
    gPlayerData[playerid][E_PJAIL_REASON][0] = '\0';
    gPlayerData[playerid][E_PWANTED_LEVEL] = 0;
    gPlayerData[playerid][E_PHEALTH] = 100;
    gPlayerData[playerid][E_PARMOR] = 0;
    gPlayerData[playerid][E_PSKIN] = 23;
    gPlayerData[playerid][E_PJOB] = 0;
    gPlayerData[playerid][E_PFRACTION_ID] = -1;
    gPlayerData[playerid][E_PFRACTION_RANK] = 0;
    gPlayerData[playerid][E_PMEDCARD] = 0;
    gPlayerData[playerid][E_PMEDCARD_EXPIRE] = 0;
    gPlayerData[playerid][E_PMEDCARD_NOTES][0] = '\0';
    gPlayerData[playerid][E_PHOUSE_ID] = -1;
    gPlayerData[playerid][E_PBUSINESS_ID] = -1;
    gPlayerData[playerid][E_PVEHICLE_SLOTS] = 1;
    gPlayerData[playerid][E_PRADIO_CHANNEL] = -1;
    for (new i = 0; i < MAX_PLAYER_QUESTS; i++) gPlayerData[playerid][E_PQUEST_PROGRESS][i] = -1;
    gPlayerData[playerid][E_PQUEST_FLAGS] = 0;
    gPlayerData[playerid][E_PMEDICAL_FLAGS] = 0;
    gPlayerData[playerid][E_PCAPTURE_SCORE] = 0;
    gPlayerData[playerid][E_PTOTAL_ARRESTS] = 0;
    gPlayerData[playerid][E_PTOTAL_HEALS] = 0;
}

main()
{
    print(" ");
    print("============================================");
    printf("   %s gamemode v%s", SERVER_NAME, SCRIPT_VERSION);
    print("============================================");
    print(" ");
}

public OnGameModeInit()
{
    SetGameModeText("open.mp RP");
    EnableStuntBonusForAll(false);
    UsePlayerPedAnims();
    DisableInteriorEnterExits();
    AllowInteriorWeapons(false);

    gDatabase = db_open("scriptfiles/roleplay.db");
    if (gDatabase == DB:0)
    {
        print("[ROLEPLAY] Failed to open scriptfiles/roleplay.db, attempting fallback roleplay.db");
        gDatabase = db_open("roleplay.db");
        if (gDatabase == DB:0)
        {
            print("[ROLEPLAY] Database not available, server cannot save data.");
        }
    }

    SetupDatabase();
    LoadWorldData();

    gPaydayTimer = SetTimer("PaydayTimer", PAYDAY_INTERVAL * 1000, true);

    AddPlayerClass(23, 1978.2759, -1774.9990, 13.5469, 270.0, 0, 0, 0, 0, 0, 0);
    AddPlayerClass(120, 1535.9185, -1675.3436, 13.5469, 90.0, 0, 0, 0, 0, 0, 0);
    AddPlayerClass(105, 2495.7737, -1685.3506, 13.5124, 0.0, 0, 0, 0, 0, 0, 0);

    CreateHospitals();
    CreateMinigameMarkers();
    CreateDefaultRadio();

    return true;
}

public OnGameModeExit()
{
    if (gPaydayTimer)
    {
        KillTimer(gPaydayTimer);
        gPaydayTimer = 0;
    }
    if (gDatabase) db_close(gDatabase);
    return true;
}

public OnPlayerConnect(playerid)
{
    ResetPlayerData(playerid);

    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    format(gPlayerData[playerid][E_PNAME], sizeof(gPlayerData[][E_PNAME]), "%s", name);

    new ip[16];
    GetPlayerIp(playerid, ip, sizeof(ip));
    format(gPlayerData[playerid][E_PIP], sizeof(gPlayerData[][E_PIP]), "%s", ip);

    SendServerMessage(playerid, COLOR_WHITE, "Добро пожаловать на %s!", SERVER_NAME);
    SendServerMessage(playerid, COLOR_YELLOW, "Используйте /help для справки.");

    AttemptAutoLogin(playerid);
    return true;
}

public OnPlayerDisconnect(playerid, reason)
{
    if (IsLoggedIn(playerid)) SavePlayerData(playerid, true);
    ResetPlayerData(playerid);
    return true;
}

public OnPlayerSpawn(playerid)
{
    if (!IsLoggedIn(playerid))
    {
        TogglePlayerControllable(playerid, false);
        ShowLoginDialog(playerid);
        return false;
    }

    SetPlayerSkin(playerid, gPlayerData[playerid][E_PSKIN]);
    SetPlayerHealth(playerid, float(gPlayerData[playerid][E_PHEALTH]));
    SetPlayerArmour(playerid, float(gPlayerData[playerid][E_PARMOR]));

    if (gPlayerData[playerid][E_PFRACTION_ID] >= 0)
    {
        new fid = gPlayerData[playerid][E_PFRACTION_ID];
        SetPlayerPos(playerid,
            gFractionData[fid][E_FRACTION_SPAWN][0],
            gFractionData[fid][E_FRACTION_SPAWN][1],
            gFractionData[fid][E_FRACTION_SPAWN][2]);
        SetPlayerFacingAngle(playerid, gFractionData[fid][E_FRACTION_SPAWN][3]);
    }
    else if (gPlayerData[playerid][E_PHOUSE_ID] >= 0)
    {
        new hid = gPlayerData[playerid][E_PHOUSE_ID];
        SetPlayerPos(playerid,
            gHouseData[hid][E_HOUSE_EXIT][0],
            gHouseData[hid][E_HOUSE_EXIT][1],
            gHouseData[hid][E_HOUSE_EXIT][2]);
        SetPlayerInterior(playerid, gHouseData[hid][E_HOUSE_INTERIOR]);
        SetPlayerVirtualWorld(playerid, gHouseData[hid][E_HOUSE_WORLD]);
    }
    else
    {
        SetPlayerPos(playerid, 1521.4858, -1678.3829, 13.3828);
        SetPlayerFacingAngle(playerid, 180.0);
    }

    TogglePlayerControllable(playerid, true);
    ApplyPendingOfflineActions(playerid);
    return true;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    gPlayerData[playerid][E_PWANTED_LEVEL] = 0;
    gPlayerData[playerid][E_PHEALTH] = 100;
    gPlayerData[playerid][E_PARMOR] = 0;

    if (killerid != INVALID_PLAYER_ID && killerid != playerid)
    {
        gPlayerData[killerid][E_PEXP] += 1;
        gPlayerData[killerid][E_PCAPTURE_SCORE] += 1;
    }
    return true;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!IsLoggedIn(playerid) && !IsLoginCommand(cmdtext))
    {
        SendServerMessage(playerid, COLOR_RED, "Необходимо войти в аккаунт.");
        return true;
    }

    if (cmdtext[0] != '/') return false;

    new idx = 1;
    new cmd[32];
    if (!GetCommandToken(cmdtext, idx, cmd, sizeof(cmd))) return true;
    new params[128];
    GetCommandRemainder(cmdtext, idx, params, sizeof(params));
    for (new i = 0; cmd[i]; i++) if (cmd[i] >= 'A' && cmd[i] <= 'Z') cmd[i] += 32;

    if (!strcmp(cmd, "help"))
    {
        ShowHelp(playerid);
    }
    else if (!strcmp(cmd, "register"))
    {
        CommandRegister(playerid, params);
    }
    else if (!strcmp(cmd, "login"))
    {
        CommandLogin(playerid, params);
    }
    else if (!strcmp(cmd, "stats"))
    {
        ShowStats(playerid);
    }
    else if (!strcmp(cmd, "bank"))
    {
        CommandBank(playerid, params);
    }
    else if (!strcmp(cmd, "payday"))
    {
        CommandPayday(playerid);
    }
    else if (!strcmp(cmd, "house"))
    {
        CommandHouse(playerid, params);
    }
    else if (!strcmp(cmd, "buyhouse"))
    {
        CommandBuyHouse(playerid);
    }
    else if (!strcmp(cmd, "sellhouse"))
    {
        CommandSellHouse(playerid);
    }
    else if (!strcmp(cmd, "furnhouse"))
    {
        CommandFurnHouse(playerid, params);
    }
    else if (!strcmp(cmd, "biz"))
    {
        CommandBiz(playerid, params);
    }
    else if (!strcmp(cmd, "buybiz"))
    {
        CommandBuyBiz(playerid);
    }
    else if (!strcmp(cmd, "sellbiz"))
    {
        CommandSellBiz(playerid);
    }
    else if (!strcmp(cmd, "bizwar"))
    {
        CommandBizWar(playerid, params);
    }
    else if (!strcmp(cmd, "engine"))
    {
        CommandEngine(playerid);
    }
    else if (!strcmp(cmd, "lock"))
    {
        CommandLockVehicle(playerid);
    }
    else if (!strcmp(cmd, "window"))
    {
        CommandWindow(playerid);
    }
    else if (!strcmp(cmd, "usekey"))
    {
        CommandUseKey(playerid, params);
    }
    else if (!strcmp(cmd, "spawn"))
    {
        CommandSpawnVehicle(playerid, params);
    }
    else if (!strcmp(cmd, "carmat"))
    {
        CommandCarMat(playerid, params);
    }
    else if (!strcmp(cmd, "radio"))
    {
        CommandRadio(playerid, params);
    }
    else if (!strcmp(cmd, "music"))
    {
        CommandMusic(playerid, params);
    }
    else if (!strcmp(cmd, "heal"))
    {
        CommandHeal(playerid, params);
    }
    else if (!strcmp(cmd, "givemedcard"))
    {
        CommandGiveMedcard(playerid, params);
    }
    else if (!strcmp(cmd, "showmedcard"))
    {
        CommandShowMedcard(playerid, params);
    }
    else if (!strcmp(cmd, "mask"))
    {
        CommandMask(playerid);
    }
    else if (!strcmp(cmd, "materials"))
    {
        CommandMaterials(playerid, params);
    }
    else if (!strcmp(cmd, "drugs"))
    {
        CommandDrugs(playerid, params);
    }
    else if (!strcmp(cmd, "rob"))
    {
        CommandRob(playerid, params);
    }
    else if (!strcmp(cmd, "robbank"))
    {
        CommandRobBank(playerid);
    }
    else if (!strcmp(cmd, "robhouse"))
    {
        CommandRobHouse(playerid);
    }
    else if (!strcmp(cmd, "capture"))
    {
        CommandCapture(playerid, params);
    }
    else if (!strcmp(cmd, "war"))
    {
        CommandWar(playerid, params);
    }
    else if (!strcmp(cmd, "zone"))
    {
        CommandZone(playerid, params);
    }
    else if (!strcmp(cmd, "wanted"))
    {
        CommandWanted(playerid, params);
    }
    else if (!strcmp(cmd, "wantedlist"))
    {
        CommandWantedList(playerid);
    }
    else if (!strcmp(cmd, "cuff"))
    {
        CommandCuff(playerid, params);
    }
    else if (!strcmp(cmd, "uncuff"))
    {
        CommandUnCuff(playerid, params);
    }
    else if (!strcmp(cmd, "jail"))
    {
        CommandJail(playerid, params);
    }
    else if (!strcmp(cmd, "fine"))
    {
        CommandFine(playerid, params);
    }
    else if (!strcmp(cmd, "ticket"))
    {
        CommandTicket(playerid, params);
    }
    else if (!strcmp(cmd, "eject"))
    {
        CommandEject(playerid, params);
    }
    else if (!strcmp(cmd, "family"))
    {
        CommandFamily(playerid, params);
    }
    else if (!strcmp(cmd, "fmenu"))
    {
        CommandFamilyMenu(playerid);
    }
    else if (!strcmp(cmd, "fban"))
    {
        CommandFamilyBan(playerid, params);
    }
    else if (!strcmp(cmd, "dice"))
    {
        CommandDice(playerid, params);
    }
    else if (!strcmp(cmd, "casino"))
    {
        CommandCasino(playerid, params);
    }
    else if (!strcmp(cmd, "paintball"))
    {
        CommandPaintball(playerid, params);
    }
    else if (!strcmp(cmd, "quest"))
    {
        CommandQuest(playerid, params);
    }
    else if (!strcmp(cmd, "block"))
    {
        CommandBlock(playerid, params);
    }
    else if (!strcmp(cmd, "accept"))
    {
        CommandAccept(playerid, params);
    }
    else if (!strcmp(cmd, "change"))
    {
        CommandChange(playerid, params);
    }
    else if (!strcmp(cmd, "spy"))
    {
        CommandSpy(playerid, params);
    }
    else if (!strcmp(cmd, "ban"))
    {
        CommandBan(playerid, params, false);
    }
    else if (!strcmp(cmd, "sban"))
    {
        CommandBan(playerid, params, true);
    }
    else if (!strcmp(cmd, "iban") || !strcmp(cmd, "banip"))
    {
        CommandIPBan(playerid, params);
    }
    else if (!strcmp(cmd, "unban"))
    {
        CommandUnban(playerid, params);
    }
    else if (!strcmp(cmd, "unbanip"))
    {
        CommandUnbanIP(playerid, params);
    }
    else if (!strcmp(cmd, "kick"))
    {
        CommandKick(playerid, params);
    }
    else if (!strcmp(cmd, "warn"))
    {
        CommandWarn(playerid, params);
    }
    else if (!strcmp(cmd, "unwarn"))
    {
        CommandUnwarn(playerid, params);
    }
    else if (!strcmp(cmd, "mute"))
    {
        CommandMute(playerid, params);
    }
    else if (!strcmp(cmd, "offban"))
    {
        CommandOfflineAction(playerid, params, 1);
    }
    else if (!strcmp(cmd, "offwarn"))
    {
        CommandOfflineAction(playerid, params, 2);
    }
    else if (!strcmp(cmd, "offmute"))
    {
        CommandOfflineAction(playerid, params, 3);
    }
    else if (!strcmp(cmd, "offjail"))
    {
        CommandOfflineAction(playerid, params, 4);
    }
    else if (!strcmp(cmd, "freeze"))
    {
        CommandFreeze(playerid, params, true);
    }
    else if (!strcmp(cmd, "unfreeze"))
    {
        CommandFreeze(playerid, params, false);
    }
    else if (!strcmp(cmd, "hostname"))
    {
        CommandHostName(playerid, params);
    }
    else if (!strcmp(cmd, "weather"))
    {
        CommandWeather(playerid, params);
    }
    else if (!strcmp(cmd, "giverub"))
    {
        CommandGiveRub(playerid, params);
    }
    else if (!strcmp(cmd, "givedonate"))
    {
        CommandGiveDonate(playerid, params);
    }
    else if (!strcmp(cmd, "agiverank"))
    {
        CommandGiveFractionRank(playerid, params);
    }
    else if (!strcmp(cmd, "amembers"))
    {
        CommandFractionMembers(playerid, params);
    }
    else if (!strcmp(cmd, "teleport"))
    {
        CommandTeleport(playerid, params);
    }
    else if (!strcmp(cmd, "spawnveh"))
    {
        CommandSpawnAdminVehicle(playerid, params);
    }
    else if (!strcmp(cmd, "cheat"))
    {
        CallLocalFunction("OnPlayerCheat", "is", playerid, "Command");
    }
    else
    {
        SendServerMessage(playerid, COLOR_GREY, "Команда не найдена.");
    }
    return true;
}

forward OnPlayerCheat(playerid, const reason[]);
public OnPlayerCheat(playerid, const reason[])
{
    printf("[ANTICHEAT] %s flagged for %s", gPlayerData[playerid][E_PNAME], reason);
    if (IsAdmin(playerid, 1)) return true;
    CommandKick(INVALID_PLAYER_ID, sprintf("%d %s", playerid, reason));
    return true;
}

forward PaydayTimer();
public PaydayTimer()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i) || !IsLoggedIn(i)) continue;
        new now = gettime();
        if (now - gPlayerData[i][E_PLAST_PAYDAY] < PAYDAY_INTERVAL) continue;

        gPlayerData[i][E_PLAST_PAYDAY] = now;
        gPlayerData[i][E_PONLINE_SECONDS] += PAYDAY_INTERVAL;

        new salary = 500 + (gPlayerData[i][E_PLEVEL] * 50);
        if (gPlayerData[i][E_PFRACTION_ID] >= 0)
        {
            salary += gFractionData[gPlayerData[i][E_PFRACTION_ID]][E_FRACTION_PAYCHECK];
        }

        new tax = floatround(float(salary) * gTaxRate, floatround_floor);
        gStateTreasury += tax;
        gPlayerData[i][E_PBANK] += (salary - tax) + gPlayerData[i][E_POFFLINE_REWARD];
        gPlayerData[i][E_POFFLINE_REWARD] = 0;

        if (IsVip(i))
        {
            new bonus = 500 * gPlayerData[i][E_PVIP_LEVEL];
            gPlayerData[i][E_PBANK] += bonus;
            SendServerMessage(i, COLOR_VIP, "VIP бонус: %d$", bonus);
        }

        SendServerMessage(i, COLOR_GREEN, "Payday: %d$, налог %d$. Баланс банка: %d$", salary, tax, gPlayerData[i][E_PBANK]);

        if (gPlayerData[i][E_PONLINE_SECONDS] > gPlayerData[i][E_PMAX_ONLINE])
        {
            gPlayerData[i][E_PMAX_ONLINE] = gPlayerData[i][E_PONLINE_SECONDS];
        }

        SavePlayerData(i, false);
    }
    return true;
}

stock SetupDatabase()
{
    if (gDatabase == DB:0) return;

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS accounts (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        name TEXT UNIQUE,\
        password TEXT,\
        salt TEXT,\
        admin_level INTEGER DEFAULT 0,\
        vip_level INTEGER DEFAULT 0,\
        vip_expire INTEGER DEFAULT 0,\
        prefix TEXT DEFAULT '',\
        level INTEGER DEFAULT 1,\
        exp INTEGER DEFAULT 0,\
        money INTEGER DEFAULT 0,\
        bank INTEGER DEFAULT 0,\
        last_payday INTEGER DEFAULT 0,\
        max_online INTEGER DEFAULT 0,\
        online_seconds INTEGER DEFAULT 0,\
        last_login INTEGER DEFAULT 0,\
        ip TEXT DEFAULT '',\
        offline_fine INTEGER DEFAULT 0,\
        offline_reward INTEGER DEFAULT 0,\
        offline_jail INTEGER DEFAULT 0,\
        jail_time INTEGER DEFAULT 0,\
        jail_reason TEXT DEFAULT '',\
        wanted_level INTEGER DEFAULT 0,\
        health INTEGER DEFAULT 100,\
        armor INTEGER DEFAULT 0,\
        skin INTEGER DEFAULT 23,\
        job INTEGER DEFAULT 0,\
        fraction_id INTEGER DEFAULT -1,\
        fraction_rank INTEGER DEFAULT 0,\
        medcard INTEGER DEFAULT 0,\
        medcard_expire INTEGER DEFAULT 0,\
        medcard_notes TEXT DEFAULT '',\
        house_id INTEGER DEFAULT -1,\
        business_id INTEGER DEFAULT -1,\
        vehicle_slots INTEGER DEFAULT 1,\
        radio_channel INTEGER DEFAULT -1,\
        quest_flags INTEGER DEFAULT 0,\
        medical_flags INTEGER DEFAULT 0,\
        capture_score INTEGER DEFAULT 0,\
        total_arrests INTEGER DEFAULT 0,\
        total_heals INTEGER DEFAULT 0\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS player_quests (account_id INTEGER, quest_id INTEGER, state INTEGER, PRIMARY KEY (account_id, quest_id))");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS houses (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        owner TEXT DEFAULT '',\
        price INTEGER DEFAULT 150000,\
        interior INTEGER DEFAULT 1,\
        enter_x REAL, enter_y REAL, enter_z REAL,\
        exit_x REAL, exit_y REAL, exit_z REAL,\
        locked INTEGER DEFAULT 1,\
        storage_money INTEGER DEFAULT 0,\
        storage_materials INTEGER DEFAULT 0,\
        storage_drugs INTEGER DEFAULT 0,\
        upgrades INTEGER DEFAULT 0,\
        world INTEGER DEFAULT 0,\
        safe_password TEXT DEFAULT ''\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS businesses (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        owner TEXT DEFAULT '',\
        price INTEGER DEFAULT 500000,\
        type INTEGER DEFAULT 0,\
        products INTEGER DEFAULT 0,\
        max_products INTEGER DEFAULT 500,\
        balance INTEGER DEFAULT 0,\
        tax INTEGER DEFAULT 10,\
        upkeep INTEGER DEFAULT 500,\
        pos_x REAL, pos_y REAL, pos_z REAL, pos_a REAL,\
        menu_name TEXT DEFAULT 'Shop',\
        mafia INTEGER DEFAULT -1,\
        war_state INTEGER DEFAULT 0,\
        war_timer INTEGER DEFAULT 0,\
        last_restock INTEGER DEFAULT 0\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS player_vehicles (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        owner TEXT,\
        model INTEGER,\
        color1 INTEGER,\
        color2 INTEGER,\
        fuel REAL DEFAULT 100.0,\
        mileage REAL DEFAULT 0.0,\
        health REAL DEFAULT 1000.0,\
        lock_state INTEGER DEFAULT 0,\
        window_state INTEGER DEFAULT 0,\
        parking_x REAL, parking_y REAL, parking_z REAL, parking_a REAL,\
        world INTEGER DEFAULT 0,\
        interior INTEGER DEFAULT 0,\
        mods TEXT DEFAULT ''\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS offline_actions (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        target TEXT,\
        type INTEGER,\
        value INTEGER,\
        reason TEXT,\
        executor TEXT,\
        timestamp INTEGER\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS radio_channels (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        name TEXT,\
        url TEXT,\
        type INTEGER,\
        password TEXT,\
        slot_limit INTEGER\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS audio_streams (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        name TEXT,\
        url TEXT\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS factions (\
        id INTEGER PRIMARY KEY,\
        name TEXT,\
        type INTEGER,\
        color INTEGER,\
        rank1 TEXT, rank2 TEXT, rank3 TEXT, rank4 TEXT, rank5 TEXT, rank6 TEXT, rank7 TEXT, rank8 TEXT, rank9 TEXT, rank10 TEXT, rank11 TEXT, rank12 TEXT, rank13 TEXT, rank14 TEXT, rank15 TEXT, rank16 TEXT,\
        spawn_x REAL, spawn_y REAL, spawn_z REAL, spawn_a REAL,\
        pay INTEGER DEFAULT 0,\
        permissions INTEGER DEFAULT 0,\
        radio INTEGER DEFAULT -1,\
        max_members INTEGER DEFAULT 64\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS gangzones (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        owner INTEGER DEFAULT -1,\
        color INTEGER DEFAULT 0xFF0000AA,\
        min_x REAL, min_y REAL, min_z REAL,\
        max_x REAL, max_y REAL, max_z REAL\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS medical_procedures (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        name TEXT,\
        cost INTEGER,\
        requirements INTEGER,\
        effect INTEGER\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS quest_templates (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        name TEXT,\
        description TEXT,\
        requirements INTEGER,\
        reward_exp INTEGER,\
        reward_money INTEGER\
    )");

    db_query(gDatabase, "CREATE TABLE IF NOT EXISTS bans (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        name TEXT,\
        ip TEXT,\
        reason TEXT,\
        executor TEXT,\
        expire INTEGER\
    )");
}

stock LoadWorldData()
{
    LoadHousesFromDB();
    LoadBusinessesFromDB();
    LoadFractionsFromDB();
    LoadGangZonesFromDB();
    LoadMedicalProcedures();
    LoadRadioChannels();
    LoadAudioStreams();
    LoadQuestsFromDB();
}

stock LoadHousesFromDB()
{
    if (gDatabase == DB:0) return;
    DBResult:result = db_query(gDatabase, "SELECT * FROM houses");
    gTotalHouses = 0;
    if (!result) return;

    while (db_next_row(result) && gTotalHouses < MAX_HOUSES)
    {
        new idx = gTotalHouses;
        gHouseData[idx][E_HOUSE_ID] = db_get_field_int(result, "id");
        db_get_field(result, "owner", gHouseData[idx][E_HOUSE_OWNER], sizeof(gHouseData[][E_HOUSE_OWNER]));
        gHouseData[idx][E_HOUSE_PRICE] = db_get_field_int(result, "price");
        gHouseData[idx][E_HOUSE_INTERIOR] = db_get_field_int(result, "interior");
        gHouseData[idx][E_HOUSE_ENTER][0] = db_get_field_float(result, "enter_x");
        gHouseData[idx][E_HOUSE_ENTER][1] = db_get_field_float(result, "enter_y");
        gHouseData[idx][E_HOUSE_ENTER][2] = db_get_field_float(result, "enter_z");
        gHouseData[idx][E_HOUSE_EXIT][0] = db_get_field_float(result, "exit_x");
        gHouseData[idx][E_HOUSE_EXIT][1] = db_get_field_float(result, "exit_y");
        gHouseData[idx][E_HOUSE_EXIT][2] = db_get_field_float(result, "exit_z");
        gHouseData[idx][E_HOUSE_LOCKED] = db_get_field_int(result, "locked");
        gHouseData[idx][E_HOUSE_STORAGE_MONEY] = db_get_field_int(result, "storage_money");
        gHouseData[idx][E_HOUSE_STORAGE_MATERIALS] = db_get_field_int(result, "storage_materials");
        gHouseData[idx][E_HOUSE_STORAGE_DRUGS] = db_get_field_int(result, "storage_drugs");
        gHouseData[idx][E_HOUSE_UPGRADES] = db_get_field_int(result, "upgrades");
        gHouseData[idx][E_HOUSE_WORLD] = db_get_field_int(result, "world");
        db_get_field(result, "safe_password", gHouseData[idx][E_HOUSE_SAFE_PASSWORD], sizeof(gHouseData[][E_HOUSE_SAFE_PASSWORD]));
        CreateHouseEntities(idx);
        gTotalHouses++;
    }
    db_free_result(result);
}

stock CreateHouseEntities(houseid)
{
    if (houseid < 0 || houseid >= MAX_HOUSES) return;
    if (IsValidPickup(gHouseData[houseid][E_HOUSE_PICKUP])) DestroyPickup(gHouseData[houseid][E_HOUSE_PICKUP]);
    if (IsValid3DTextLabel(gHouseData[houseid][E_HOUSE_TEXT])) Delete3DTextLabel(gHouseData[houseid][E_HOUSE_TEXT]);

    gHouseData[houseid][E_HOUSE_PICKUP] = CreatePickup(1273, 1,
        gHouseData[houseid][E_HOUSE_ENTER][0],
        gHouseData[houseid][E_HOUSE_ENTER][1],
        gHouseData[houseid][E_HOUSE_ENTER][2]);

    new text[144];
    if (strlen(gHouseData[houseid][E_HOUSE_OWNER]))
    {
        format(text, sizeof(text), "Дом %d\nВладелец: %s\nЦена: %d$",
            gHouseData[houseid][E_HOUSE_ID],
            gHouseData[houseid][E_HOUSE_OWNER],
            gHouseData[houseid][E_HOUSE_PRICE]);
    }
    else
    {
        format(text, sizeof(text), "Дом %d\nСвободен\nЦена: %d$",
            gHouseData[houseid][E_HOUSE_ID],
            gHouseData[houseid][E_HOUSE_PRICE]);
    }
    gHouseData[houseid][E_HOUSE_TEXT] = Create3DTextLabel(text, COLOR_WHITE,
        gHouseData[houseid][E_HOUSE_ENTER][0],
        gHouseData[houseid][E_HOUSE_ENTER][1],
        gHouseData[houseid][E_HOUSE_ENTER][2] + 1.0, 15.0, 0, 0);
}

stock LoadBusinessesFromDB()
{
    if (gDatabase == DB:0) return;
    DBResult:result = db_query(gDatabase, "SELECT * FROM businesses");
    gTotalBusinesses = 0;
    if (!result) return;

    while (db_next_row(result) && gTotalBusinesses < MAX_BUSINESSES)
    {
        new idx = gTotalBusinesses;
        gBusinessData[idx][E_BIZ_ID] = db_get_field_int(result, "id");
        db_get_field(result, "owner", gBusinessData[idx][E_BIZ_OWNER], sizeof(gBusinessData[][E_BIZ_OWNER]));
        gBusinessData[idx][E_BIZ_PRICE] = db_get_field_int(result, "price");
        gBusinessData[idx][E_BIZ_TYPE] = db_get_field_int(result, "type");
        gBusinessData[idx][E_BIZ_PRODUCTS] = db_get_field_int(result, "products");
        gBusinessData[idx][E_BIZ_MAX_PRODUCTS] = db_get_field_int(result, "max_products");
        gBusinessData[idx][E_BIZ_BALANCE] = db_get_field_int(result, "balance");
        gBusinessData[idx][E_BIZ_TAX] = db_get_field_int(result, "tax");
        gBusinessData[idx][E_BIZ_UPKEEP] = db_get_field_int(result, "upkeep");
        gBusinessData[idx][E_BIZ_POS][0] = db_get_field_float(result, "pos_x");
        gBusinessData[idx][E_BIZ_POS][1] = db_get_field_float(result, "pos_y");
        gBusinessData[idx][E_BIZ_POS][2] = db_get_field_float(result, "pos_z");
        gBusinessData[idx][E_BIZ_POS][3] = db_get_field_float(result, "pos_a");
        db_get_field(result, "menu_name", gBusinessData[idx][E_BIZ_MENU_NAME], sizeof(gBusinessData[][E_BIZ_MENU_NAME]));
        gBusinessData[idx][E_BIZ_MAFIA] = db_get_field_int(result, "mafia");
        gBusinessData[idx][E_BIZ_WAR_STATE] = db_get_field_int(result, "war_state");
        gBusinessData[idx][E_BIZ_WAR_TIMER] = db_get_field_int(result, "war_timer");
        gBusinessData[idx][E_BIZ_LAST_RESTOCK] = db_get_field_int(result, "last_restock");
        CreateBusinessEntities(idx);
        gTotalBusinesses++;
    }
    db_free_result(result);
}

stock CreateBusinessEntities(bizid)
{
    if (bizid < 0 || bizid >= MAX_BUSINESSES) return;
    if (IsValidPickup(gBusinessData[bizid][E_BIZ_PICKUP])) DestroyPickup(gBusinessData[bizid][E_BIZ_PICKUP]);
    if (IsValid3DTextLabel(gBusinessData[bizid][E_BIZ_TEXT])) Delete3DTextLabel(gBusinessData[bizid][E_BIZ_TEXT]);

    gBusinessData[bizid][E_BIZ_PICKUP] = CreatePickup(1239, 1,
        gBusinessData[bizid][E_BIZ_POS][0],
        gBusinessData[bizid][E_BIZ_POS][1],
        gBusinessData[bizid][E_BIZ_POS][2]);

    new text[144];
    if (strlen(gBusinessData[bizid][E_BIZ_OWNER]))
    {
        format(text, sizeof(text), "Бизнес %d\nВладелец: %s\nКасса: %d$",
            gBusinessData[bizid][E_BIZ_ID],
            gBusinessData[bizid][E_BIZ_OWNER],
            gBusinessData[bizid][E_BIZ_BALANCE]);
    }
    else
    {
        format(text, sizeof(text), "Бизнес %d\nСвободен\nЦена: %d$",
            gBusinessData[bizid][E_BIZ_ID],
            gBusinessData[bizid][E_BIZ_PRICE]);
    }
    gBusinessData[bizid][E_BIZ_TEXT] = Create3DTextLabel(text, COLOR_WHITE,
        gBusinessData[bizid][E_BIZ_POS][0],
        gBusinessData[bizid][E_BIZ_POS][1],
        gBusinessData[bizid][E_BIZ_POS][2] + 1.0, 15.0, 0, 0);
}

stock LoadFractionsFromDB()
{
    if (gDatabase == DB:0) return;
    DBResult:result = db_query(gDatabase, "SELECT * FROM factions");
    gTotalFractions = 0;
    if (!result)
    {
        CreateDefaultFractions();
        return;
    }

    new rankField[8];
    while (db_next_row(result) && gTotalFractions < MAX_FACTIONS)
    {
        new id = db_get_field_int(result, "id");
        gFractionData[id][E_FRACTION_ID] = id;
        db_get_field(result, "name", gFractionData[id][E_FRACTION_NAME], sizeof(gFractionData[][E_FRACTION_NAME]));
        gFractionData[id][E_FRACTION_TYPE] = db_get_field_int(result, "type");
        gFractionData[id][E_FRACTION_COLOR] = db_get_field_int(result, "color");
        for (new r = 0; r < MAX_FRACTION_RANKS; r++)
        {
            format(rankField, sizeof(rankField), "rank%d", r + 1);
            db_get_field(result, rankField, gFractionData[id][E_FRACTION_RANKS][r], sizeof(gFractionData[][E_FRACTION_RANKS][]));
        }
        gFractionData[id][E_FRACTION_SPAWN][0] = db_get_field_float(result, "spawn_x");
        gFractionData[id][E_FRACTION_SPAWN][1] = db_get_field_float(result, "spawn_y");
        gFractionData[id][E_FRACTION_SPAWN][2] = db_get_field_float(result, "spawn_z");
        gFractionData[id][E_FRACTION_SPAWN][3] = db_get_field_float(result, "spawn_a");
        gFractionData[id][E_FRACTION_PAYCHECK] = db_get_field_int(result, "pay");
        gFractionData[id][E_FRACTION_PERMISSIONS] = db_get_field_int(result, "permissions");
        gFractionData[id][E_FRACTION_RADIO] = db_get_field_int(result, "radio");
        gFractionData[id][E_FRACTION_MAX_MEMBERS] = db_get_field_int(result, "max_members");
        if (id >= gTotalFractions) gTotalFractions = id + 1;
    }
    db_free_result(result);

    if (gTotalFractions == 0) CreateDefaultFractions();
}

stock CreateDefaultFractions()
{
    new query[512];
    const FRACTIONS[][5][] = {
        {"LSPD", "LSPD", "Officer", "Sergeant", "Captain"},
        {"SFPD", "SFPD", "Officer", "Lieutenant", "Commander"},
        {"LVPD", "LVPD", "Officer", "Sergeant", "Captain"},
        {"FBI", "FBI", "Agent", "Special Agent", "Director"},
        {"Army", "Army", "Private", "Sergeant", "Colonel"},
        {"News", "News", "Reporter", "Editor", "Director"},
        {"LCN", "LCN", "Associate", "Capo", "Don"},
        {"Yakuza", "Yakuza", "Shatei", "Kyodai", "Oyabun"},
        {"Grove", "Grove", "Outsider", "Soldier", "OG"},
        {"Ballas", "Ballas", "Hustler", "Shot Caller", "OG"},
        {"Vagos", "Vagos", "Outsider", "Soldado", "Jefe"},
        {"Rifa", "Rifa", "Rookie", "Soldier", "OG"}
    };

    for (new i = 0; i < sizeof(FRACTIONS); i++)
    {
        format(query, sizeof(query), "INSERT OR REPLACE INTO factions (id, name, type, color, rank1, rank2, rank3, rank4, spawn_x, spawn_y, spawn_z, spawn_a, pay, permissions, radio, max_members) VALUES (%d, '%s', %d, %d, '%s', '%s', '%s', '%s', %f, %f, %f, %f, %d, %d, %d, %d)",
            i,
            FRACTIONS[i][0],
            (i < 6 ? 1 : 2),
            (i < 6 ? 0x1E90FFAA : 0xADFF2FAA),
            FRACTIONS[i][2], FRACTIONS[i][3], FRACTIONS[i][4], FRACTIONS[i][4],
            1550.0 + float(i), -1675.0, 13.5, 180.0,
            1500 + i * 50, 0xFFFF, -1, 64);
        db_query(gDatabase, query);
    }
    LoadFractionsFromDB();
}

stock LoadGangZonesFromDB()
{
    if (gDatabase == DB:0) return;
    DBResult:result = db_query(gDatabase, "SELECT * FROM gangzones");
    gTotalGZones = 0;
    if (!result) return;

    while (db_next_row(result) && gTotalGZones < MAX_GZONES)
    {
        new idx = gTotalGZones;
        gGangZones[idx][E_GZONE_ID] = db_get_field_int(result, "id");
        gGangZones[idx][E_GZONE_OWNER] = db_get_field_int(result, "owner");
        gGangZones[idx][E_GZONE_COLOR] = db_get_field_int(result, "color");
        gGangZones[idx][E_GZONE_MIN][0] = db_get_field_float(result, "min_x");
        gGangZones[idx][E_GZONE_MIN][1] = db_get_field_float(result, "min_y");
        gGangZones[idx][E_GZONE_MIN][2] = db_get_field_float(result, "min_z");
        gGangZones[idx][E_GZONE_MAX][0] = db_get_field_float(result, "max_x");
        gGangZones[idx][E_GZONE_MAX][1] = db_get_field_float(result, "max_y");
        gGangZones[idx][E_GZONE_MAX][2] = db_get_field_float(result, "max_z");
        gGangZones[idx][E_GZONE_CAPTURE_TIME] = 0;
        gGangZones[idx][E_GZONE_CAPTURE_FACTION] = -1;
        gGangZones[idx][E_GZONE_CAPTURE_TIMER] = 0;
        gTotalGZones++;
    }
    db_free_result(result);
}

stock LoadMedicalProcedures()
{
    if (gDatabase == DB:0) return;
    DBResult:result = db_query(gDatabase, "SELECT * FROM medical_procedures");
    gTotalMedicalProcedures = 0;
    if (result)
    {
        while (db_next_row(result) && gTotalMedicalProcedures < MAX_MEDICAL_PROCEDURES)
        {
            new idx = gTotalMedicalProcedures;
            gMedicalData[idx][E_MED_ID] = db_get_field_int(result, "id");
            db_get_field(result, "name", gMedicalData[idx][E_MED_NAME], sizeof(gMedicalData[][E_MED_NAME]));
            gMedicalData[idx][E_MED_COST] = db_get_field_int(result, "cost");
            gMedicalData[idx][E_MED_REQUIREMENTS] = db_get_field_int(result, "requirements");
            gMedicalData[idx][E_MED_EFFECT] = db_get_field_int(result, "effect");
            gTotalMedicalProcedures++;
        }
        db_free_result(result);
    }
    if (gTotalMedicalProcedures == 0)
    {
        db_query(gDatabase, "INSERT INTO medical_procedures (name, cost, requirements, effect) VALUES ('Общая терапия', 500, 0, 20)");
        db_query(gDatabase, "INSERT INTO medical_procedures (name, cost, requirements, effect) VALUES ('Вакцинация', 2500, 1, 30)");
        LoadMedicalProcedures();
    }
}

stock LoadRadioChannels()
{
    if (gDatabase == DB:0) return;
    DBResult:result = db_query(gDatabase, "SELECT * FROM radio_channels");
    gTotalRadioChannels = 0;
    if (result)
    {
        while (db_next_row(result) && gTotalRadioChannels < MAX_RADIO_CHANNELS)
        {
            new idx = gTotalRadioChannels;
            gRadioData[idx][E_RADIO_ID] = db_get_field_int(result, "id");
            db_get_field(result, "name", gRadioData[idx][E_RADIO_NAME], sizeof(gRadioData[][E_RADIO_NAME]));
            db_get_field(result, "url", gRadioData[idx][E_RADIO_URL], sizeof(gRadioData[][E_RADIO_URL]));
            gRadioData[idx][E_RADIO_TYPE] = db_get_field_int(result, "type");
            db_get_field(result, "password", gRadioData[idx][E_RADIO_PASSWORD], sizeof(gRadioData[][E_RADIO_PASSWORD]));
            gRadioData[idx][E_RADIO_SLOT_LIMIT] = db_get_field_int(result, "slot_limit");
            gTotalRadioChannels++;
        }
        db_free_result(result);
    }
}

stock LoadAudioStreams()
{
    if (gDatabase == DB:0) return;
    DBResult:result = db_query(gDatabase, "SELECT * FROM audio_streams");
    gTotalAudioStreams = 0;
    if (result)
    {
        while (db_next_row(result) && gTotalAudioStreams < MAX_AUDIO_STREAMS)
        {
            new idx = gTotalAudioStreams;
            gAudioStreamData[idx][E_AUDIO_ID] = db_get_field_int(result, "id");
            db_get_field(result, "name", gAudioStreamData[idx][E_AUDIO_NAME], sizeof(gAudioStreamData[][E_AUDIO_NAME]));
            db_get_field(result, "url", gAudioStreamData[idx][E_AUDIO_URL], sizeof(gAudioStreamData[][E_AUDIO_URL]));
            gTotalAudioStreams++;
        }
        db_free_result(result);
    }
}

stock LoadQuestsFromDB()
{
    if (gDatabase == DB:0) return;
    DBResult:result = db_query(gDatabase, "SELECT * FROM quest_templates");
    gTotalQuests = 0;
    if (result)
    {
        while (db_next_row(result) && gTotalQuests < MAX_QUESTS)
        {
            new idx = gTotalQuests;
            gQuestData[idx][E_QUEST_ID] = db_get_field_int(result, "id");
            db_get_field(result, "name", gQuestData[idx][E_QUEST_NAME], sizeof(gQuestData[][E_QUEST_NAME]));
            db_get_field(result, "description", gQuestData[idx][E_QUEST_DESC], sizeof(gQuestData[][E_QUEST_DESC]));
            gQuestData[idx][E_QUEST_REQUIREMENTS] = db_get_field_int(result, "requirements");
            gQuestData[idx][E_QUEST_REWARD_EXP] = db_get_field_int(result, "reward_exp");
            gQuestData[idx][E_QUEST_REWARD_MONEY] = db_get_field_int(result, "reward_money");
            gTotalQuests++;
        }
        db_free_result(result);
    }
    if (gTotalQuests == 0)
    {
        db_query(gDatabase, "INSERT INTO quest_templates (name, description, requirements, reward_exp, reward_money) VALUES ('Приветственный тур', 'Посетите три ключевые точки города', 0, 50, 500)");
        db_query(gDatabase, "INSERT INTO quest_templates (name, description, requirements, reward_exp, reward_money) VALUES ('Первое дежурство', 'Отработайте час в своей фракции', 1, 150, 1500)");
        LoadQuestsFromDB();
    }
}

stock CreateHospitals()
{
    CreateHospitalMarker(1172.5, -1323.4, 15.4, "Los Santos");
    CreateHospitalMarker(1607.3, 1822.7, 10.8, "Las Venturas");
}

stock CreateHospitalMarker(Float:x, Float:y, Float:z, const name[])
{
    new text[96];
    format(text, sizeof(text), "Больница %s\n/heal", name);
    Create3DTextLabel(text, COLOR_WHITE, x, y, z + 1.0, 15.0, 0, 0);
    CreatePickup(1240, 1, x, y, z);
}

stock CreateMinigameMarkers()
{
    Create3DTextLabel("Пейнтбол\n/paintball", COLOR_BLUE, 1312.3, -1367.1, 13.5, 20.0, 0, 0);
    CreatePickup(1310, 1, 1312.3, -1367.1, 13.5);
    Create3DTextLabel("Казино\n/casino", COLOR_YELLOW, 2019.7, 1007.1, 10.8, 20.0, 0, 0);
    CreatePickup(1274, 1, 2019.7, 1007.1, 10.8);
}

stock CreateDefaultRadio()
{
    LoadRadioChannels();
    LoadAudioStreams();
    if (gTotalRadioChannels == 0)
    {
        db_query(gDatabase, "INSERT INTO radio_channels (name, url, type, password, slot_limit) VALUES ('City Radio', 'http://radio.example.com/city', 0, '', 100)");
        db_query(gDatabase, "INSERT INTO radio_channels (name, url, type, password, slot_limit) VALUES ('Police Dispatch', '', 1, 'dispatch', 25)");
        LoadRadioChannels();
    }
    if (gTotalAudioStreams == 0)
    {
        db_query(gDatabase, "INSERT INTO audio_streams (name, url) VALUES ('Sample Stream', 'http://radio.example.com/stream1')");
        LoadAudioStreams();
    }
}

stock AttemptAutoLogin(playerid)
{
    if (gDatabase == DB:0)
    {
        ShowLoginDialog(playerid);
        return;
    }
    new query[256];
    format(query, sizeof(query), "SELECT * FROM accounts WHERE name = '%q'", gPlayerData[playerid][E_PNAME]);
    DBResult:result = db_query(gDatabase, query);
    if (result && db_num_rows(result))
    {
        db_next_row(result);
        gPlayerData[playerid][E_PACCOUNT_ID] = db_get_field_int(result, "id");
        db_get_field(result, "password", gPlayerData[playerid][E_PPASSWORD], sizeof(gPlayerData[][E_PPASSWORD]));
        db_get_field(result, "salt", gPlayerData[playerid][E_PSALT], sizeof(gPlayerData[][E_PSALT]));
        gPlayerData[playerid][E_PADMIN_LEVEL] = db_get_field_int(result, "admin_level");
        gPlayerData[playerid][E_PVIP_LEVEL] = db_get_field_int(result, "vip_level");
        gPlayerData[playerid][E_PVIP_EXPIRE] = db_get_field_int(result, "vip_expire");
        db_get_field(result, "prefix", gPlayerData[playerid][E_PPREFIX], sizeof(gPlayerData[][E_PPREFIX]));
        gPlayerData[playerid][E_PLEVEL] = db_get_field_int(result, "level");
        gPlayerData[playerid][E_PEXP] = db_get_field_int(result, "exp");
        gPlayerData[playerid][E_PMONEY] = db_get_field_int(result, "money");
        gPlayerData[playerid][E_PBANK] = db_get_field_int(result, "bank");
        gPlayerData[playerid][E_PLAST_PAYDAY] = db_get_field_int(result, "last_payday");
        gPlayerData[playerid][E_PMAX_ONLINE] = db_get_field_int(result, "max_online");
        gPlayerData[playerid][E_PONLINE_SECONDS] = db_get_field_int(result, "online_seconds");
        gPlayerData[playerid][E_PLAST_LOGIN] = db_get_field_int(result, "last_login");
        gPlayerData[playerid][E_POFFLINE_FINE] = db_get_field_int(result, "offline_fine");
        gPlayerData[playerid][E_POFFLINE_REWARD] = db_get_field_int(result, "offline_reward");
        gPlayerData[playerid][E_POFFLINE_JAIL] = db_get_field_int(result, "offline_jail");
        gPlayerData[playerid][E_PJAIL_TIME] = db_get_field_int(result, "jail_time");
        db_get_field(result, "jail_reason", gPlayerData[playerid][E_PJAIL_REASON], sizeof(gPlayerData[][E_PJAIL_REASON]));
        gPlayerData[playerid][E_PWANTED_LEVEL] = db_get_field_int(result, "wanted_level");
        gPlayerData[playerid][E_PHEALTH] = db_get_field_int(result, "health");
        gPlayerData[playerid][E_PARMOR] = db_get_field_int(result, "armor");
        gPlayerData[playerid][E_PSKIN] = db_get_field_int(result, "skin");
        gPlayerData[playerid][E_PJOB] = db_get_field_int(result, "job");
        gPlayerData[playerid][E_PFRACTION_ID] = db_get_field_int(result, "fraction_id");
        gPlayerData[playerid][E_PFRACTION_RANK] = db_get_field_int(result, "fraction_rank");
        gPlayerData[playerid][E_PMEDCARD] = db_get_field_int(result, "medcard");
        gPlayerData[playerid][E_PMEDCARD_EXPIRE] = db_get_field_int(result, "medcard_expire");
        db_get_field(result, "medcard_notes", gPlayerData[playerid][E_PMEDCARD_NOTES], sizeof(gPlayerData[][E_PMEDCARD_NOTES]));
        gPlayerData[playerid][E_PHOUSE_ID] = db_get_field_int(result, "house_id");
        gPlayerData[playerid][E_PBUSINESS_ID] = db_get_field_int(result, "business_id");
        gPlayerData[playerid][E_PVEHICLE_SLOTS] = db_get_field_int(result, "vehicle_slots");
        gPlayerData[playerid][E_PRADIO_CHANNEL] = db_get_field_int(result, "radio_channel");
        gPlayerData[playerid][E_PQUEST_FLAGS] = db_get_field_int(result, "quest_flags");
        gPlayerData[playerid][E_PMEDICAL_FLAGS] = db_get_field_int(result, "medical_flags");
        gPlayerData[playerid][E_PCAPTURE_SCORE] = db_get_field_int(result, "capture_score");
        gPlayerData[playerid][E_PTOTAL_ARRESTS] = db_get_field_int(result, "total_arrests");
        gPlayerData[playerid][E_PTOTAL_HEALS] = db_get_field_int(result, "total_heals");
    }
    if (result) db_free_result(result);

    ShowLoginDialog(playerid);
}

stock ShowLoginDialog(playerid)
{
    if (gPlayerData[playerid][E_PACCOUNT_ID] == 0)
    {
        ShowPlayerDialog(playerid, 1000, DIALOG_STYLE_PASSWORD, "Регистрация", "Введите пароль для регистрации", "Принять", "Выход");
    }
    else
    {
        ShowPlayerDialog(playerid, 1001, DIALOG_STYLE_PASSWORD, "Авторизация", "Введите пароль", "Принять", "Выход");
    }
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case 1000:
        {
            if (!response) { Kick(playerid); return true; }
            if (strlen(inputtext) < 4)
            {
                ShowPlayerDialog(playerid, 1000, DIALOG_STYLE_PASSWORD, "Регистрация", "Пароль слишком короткий", "Принять", "Выход");
                return true;
            }
            RegisterAccount(playerid, inputtext);
        }
        case 1001:
        {
            if (!response) { Kick(playerid); return true; }
            if (!LoginAccount(playerid, inputtext))
            {
                ShowPlayerDialog(playerid, 1001, DIALOG_STYLE_PASSWORD, "Авторизация", "Неверный пароль", "Принять", "Выход");
            }
        }
        case 2000:
        {
            if (!response) return true;
            CommandBank(playerid, inputtext);
        }
        case 3000:
        {
            if (!response) return true;
            CommandRadio(playerid, inputtext);
        }
        case 4000:
        {
            if (!response) return true;
            CommandMusic(playerid, inputtext);
        }
    }
    return true;
}

stock RegisterAccount(playerid, const password[])
{
    if (gDatabase == DB:0) return;
    new salt[16];
    GenerateSalt(salt, sizeof(salt));
    new hash[65];
    SHA256_PassHash(password, salt, hash, sizeof(hash));

    new query[512];
    format(query, sizeof(query), "INSERT INTO accounts (name, password, salt, money, bank, last_login, ip) VALUES ('%q', '%s', '%s', %d, %d, %d, '%q')",
        gPlayerData[playerid][E_PNAME], hash, salt, gPlayerData[playerid][E_PMONEY], gPlayerData[playerid][E_PBANK], gettime(), gPlayerData[playerid][E_PIP]);
    db_query(gDatabase, query);
    AttemptAutoLogin(playerid);
}

stock bool:LoginAccount(playerid, const password[])
{
    if (gDatabase == DB:0) return true;
    new hash[65];
    SHA256_PassHash(password, gPlayerData[playerid][E_PSALT], hash, sizeof(hash));
    if (!strcmp(hash, gPlayerData[playerid][E_PPASSWORD]))
    {
        gPlayerData[playerid][E_PSTATE_LOGGED] = true;
        gPlayerData[playerid][E_PLAST_LOGIN] = gettime();
        TogglePlayerControllable(playerid, true);
        SendServerMessage(playerid, COLOR_GREEN, "Добро пожаловать!");
        ApplyPendingOfflineActions(playerid);
        return true;
    }
    return false;
}

stock GenerateSalt(dest[], size)
{
    for (new i = 0; i < size - 1; i++) dest[i] = random(26) + 'a';
    dest[size - 1] = '\0';
}

stock bool:IsLoginCommand(const cmdtext[])
{
    if (cmdtext[0] != '/') return false;
    new idx = 1;
    new token[16];
    if (!GetCommandToken(cmdtext, idx, token, sizeof(token))) return false;
    for (new i = 0; token[i]; i++) if (token[i] >= 'A' && token[i] <= 'Z') token[i] += 32;
    return (!strcmp(token, "login") || !strcmp(token, "register"));
}

stock SavePlayerData(playerid, bool:full)
{
    if (gDatabase == DB:0 || gPlayerData[playerid][E_PACCOUNT_ID] == 0) return;
    new query[1024];
    format(query, sizeof(query), "UPDATE accounts SET money = %d, bank = %d, level = %d, exp = %d, max_online = %d, online_seconds = %d, last_payday = %d, last_login = %d, offline_fine = %d, offline_reward = %d, offline_jail = %d, jail_time = %d, jail_reason = '%q', wanted_level = %d, health = %d, armor = %d, skin = %d, job = %d, fraction_id = %d, fraction_rank = %d, medcard = %d, medcard_expire = %d, medcard_notes = '%q', house_id = %d, business_id = %d, vehicle_slots = %d, radio_channel = %d, quest_flags = %d, medical_flags = %d, capture_score = %d, total_arrests = %d, total_heals = %d WHERE id = %d",
        gPlayerData[playerid][E_PMONEY],
        gPlayerData[playerid][E_PBANK],
        gPlayerData[playerid][E_PLEVEL],
        gPlayerData[playerid][E_PEXP],
        gPlayerData[playerid][E_PMAX_ONLINE],
        gPlayerData[playerid][E_PONLINE_SECONDS],
        gPlayerData[playerid][E_PLAST_PAYDAY],
        gPlayerData[playerid][E_PLAST_LOGIN],
        gPlayerData[playerid][E_POFFLINE_FINE],
        gPlayerData[playerid][E_POFFLINE_REWARD],
        gPlayerData[playerid][E_POFFLINE_JAIL],
        gPlayerData[playerid][E_PJAIL_TIME],
        gPlayerData[playerid][E_PJAIL_REASON],
        gPlayerData[playerid][E_PWANTED_LEVEL],
        gPlayerData[playerid][E_PHEALTH],
        gPlayerData[playerid][E_PARMOR],
        gPlayerData[playerid][E_PSKIN],
        gPlayerData[playerid][E_PJOB],
        gPlayerData[playerid][E_PFRACTION_ID],
        gPlayerData[playerid][E_PFRACTION_RANK],
        gPlayerData[playerid][E_PMEDCARD],
        gPlayerData[playerid][E_PMEDCARD_EXPIRE],
        gPlayerData[playerid][E_PMEDCARD_NOTES],
        gPlayerData[playerid][E_PHOUSE_ID],
        gPlayerData[playerid][E_PBUSINESS_ID],
        gPlayerData[playerid][E_PVEHICLE_SLOTS],
        gPlayerData[playerid][E_PRADIO_CHANNEL],
        gPlayerData[playerid][E_PQUEST_FLAGS],
        gPlayerData[playerid][E_PMEDICAL_FLAGS],
        gPlayerData[playerid][E_PCAPTURE_SCORE],
        gPlayerData[playerid][E_PTOTAL_ARRESTS],
        gPlayerData[playerid][E_PTOTAL_HEALS],
        gPlayerData[playerid][E_PACCOUNT_ID]);
    db_query(gDatabase, query);

    if (full)
    {
        SavePlayerQuests(playerid);
    }
}

stock SavePlayerQuests(playerid)
{
    if (gDatabase == DB:0 || gPlayerData[playerid][E_PACCOUNT_ID] == 0) return;
    for (new i = 0; i < MAX_PLAYER_QUESTS; i++)
    {
        if (gPlayerData[playerid][E_PQUEST_PROGRESS][i] < 0) continue;
        new query[256];
        format(query, sizeof(query), "INSERT OR REPLACE INTO player_quests (account_id, quest_id, state) VALUES (%d, %d, %d)", gPlayerData[playerid][E_PACCOUNT_ID], i, gPlayerData[playerid][E_PQUEST_PROGRESS][i]);
        db_query(gDatabase, query);
    }
}

stock ApplyPendingOfflineActions(playerid)
{
    if (gDatabase == DB:0) return;
    new query[256];
    format(query, sizeof(query), "SELECT * FROM offline_actions WHERE target = '%q'", gPlayerData[playerid][E_PNAME]);
    DBResult:result = db_query(gDatabase, query);
    if (result)
    {
        while (db_next_row(result))
        {
            new type = db_get_field_int(result, "type");
            new value = db_get_field_int(result, "value");
            new reason[64];
            db_get_field(result, "reason", reason, sizeof(reason));
            switch (type)
            {
                case 1:
                {
                    SendServerMessage(playerid, COLOR_RED, "Вы получили оффлайн бан: %s", reason);
                    Kick(playerid);
                }
                case 2:
                {
                    SendServerMessage(playerid, COLOR_RED, "Предупреждение: %s", reason);
                }
                case 3:
                {
                    SendServerMessage(playerid, COLOR_RED, "Вы заглушены оффлайн: %s", reason);
                }
                case 4:
                {
                    gPlayerData[playerid][E_POFFLINE_JAIL] = value;
                    SendServerMessage(playerid, COLOR_RED, "Вы посажены на %d минут. Причина: %s", value, reason);
                }
            }
        }
        db_free_result(result);
    }
    format(query, sizeof(query), "DELETE FROM offline_actions WHERE target = '%q'", gPlayerData[playerid][E_PNAME]);
    db_query(gDatabase, query);
}

stock ShowHelp(playerid)
{
    SendServerMessage(playerid, COLOR_WHITE, "Основные команды: /stats /bank /house /biz /engine /radio /heal /mask /rob /capture /wanted /family /paintball /quest");
    if (IsAdmin(playerid, 1)) SendServerMessage(playerid, COLOR_ADMIN, "Админ: /ban /kick /warn /mute /offban /freeze /hostname /teleport");
}

stock ShowStats(playerid)
{
    new text[256];
    format(text, sizeof(text), "Имя: %s\nУровень: %d (%d XP)\nДеньги: %d$\nБанк: %d$\nРозыск: %d\nVIP: %d",
        gPlayerData[playerid][E_PNAME],
        gPlayerData[playerid][E_PLEVEL], gPlayerData[playerid][E_PEXP],
        gPlayerData[playerid][E_PMONEY], gPlayerData[playerid][E_PBANK],
        gPlayerData[playerid][E_PWANTED_LEVEL], gPlayerData[playerid][E_PVIP_LEVEL]);
    ShowPlayerDialog(playerid, 1500, DIALOG_STYLE_MSGBOX, "Статистика", text, "Закрыть", "");
}

stock CommandRegister(playerid, params[])
{
    if (IsLoggedIn(playerid)) { SendServerMessage(playerid, COLOR_GREY, "Вы уже зарегистрированы."); return; }
    new idx = 0; new password[32];
    if (!GetCommandToken(params, idx, password, sizeof(password)))
    {
        SendServerMessage(playerid, COLOR_WHITE, "Используйте: /register [пароль]");
        return;
    }
    RegisterAccount(playerid, password);
}

stock CommandLogin(playerid, params[])
{
    if (IsLoggedIn(playerid)) { SendServerMessage(playerid, COLOR_GREY, "Вы уже авторизованы."); return; }
    new idx = 0; new password[32];
    if (!GetCommandToken(params, idx, password, sizeof(password)))
    {
        SendServerMessage(playerid, COLOR_WHITE, "Используйте: /login [пароль]");
        return;
    }
    if (!LoginAccount(playerid, password)) SendServerMessage(playerid, COLOR_RED, "Неверный пароль.");
}

stock CommandBank(playerid, params[])
{
    new idx = 0; new action[16];
    if (!GetCommandToken(params, idx, action, sizeof(action)))
    {
        ShowPlayerDialog(playerid, 2000, DIALOG_STYLE_INPUT, "Банк", "Введите команду: balance, deposit [сумма], withdraw [сумма]", "OK", "Отмена");
        return;
    }
    for (new i = 0; action[i]; i++) if (action[i] >= 'A' && action[i] <= 'Z') action[i] += 32;
    if (!strcmp(action, "balance"))
    {
        SendServerMessage(playerid, COLOR_GREEN, "Баланс: %d$, Казна: %d$", gPlayerData[playerid][E_PBANK], gStateTreasury);
    }
    else if (!strcmp(action, "deposit"))
    {
        new amount;
        if (!GetIntToken(params, idx, amount) || amount <= 0)
        {
            SendServerMessage(playerid, COLOR_WHITE, "Используйте: /bank deposit [сумма]");
            return;
        }
        if (gPlayerData[playerid][E_PMONEY] < amount)
        {
            SendServerMessage(playerid, COLOR_RED, "Недостаточно наличных");
            return;
        }
        gPlayerData[playerid][E_PMONEY] -= amount;
        gPlayerData[playerid][E_PBANK] += amount;
        SendServerMessage(playerid, COLOR_GREEN, "Вы внесли %d$", amount);
    }
    else if (!strcmp(action, "withdraw"))
    {
        new amount;
        if (!GetIntToken(params, idx, amount) || amount <= 0)
        {
            SendServerMessage(playerid, COLOR_WHITE, "Используйте: /bank withdraw [сумма]");
            return;
        }
        if (gPlayerData[playerid][E_PBANK] < amount)
        {
            SendServerMessage(playerid, COLOR_RED, "Недостаточно средств в банке");
            return;
        }
        gPlayerData[playerid][E_PBANK] -= amount;
        gPlayerData[playerid][E_PMONEY] += amount;
        SendServerMessage(playerid, COLOR_GREEN, "Вы сняли %d$", amount);
    }
}

stock CommandPayday(playerid)
{
    new now = gettime();
    if (now - gPlayerData[playerid][E_PLAST_PAYDAY] < PAYDAY_INTERVAL)
    {
        SendServerMessage(playerid, COLOR_GREY, "Payday через %d секунд", PAYDAY_INTERVAL - (now - gPlayerData[playerid][E_PLAST_PAYDAY]));
        return;
    }
    PaydayTimer();
}

stock CommandHouse(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Дом: /buyhouse /sellhouse /furnhouse");
    if (gPlayerData[playerid][E_PHOUSE_ID] >= 0)
    {
        new hid = gPlayerData[playerid][E_PHOUSE_ID];
        SendServerMessage(playerid, COLOR_GREEN, "Ваш дом %d, сейф: %d$", gHouseData[hid][E_HOUSE_ID], gHouseData[hid][E_HOUSE_STORAGE_MONEY]);
    }
}

stock CommandBuyHouse(playerid)
{
    for (new i = 0; i < gTotalHouses; i++)
    {
        if (!IsPlayerInRangeOfPoint(playerid, 2.0, gHouseData[i][E_HOUSE_ENTER][0], gHouseData[i][E_HOUSE_ENTER][1], gHouseData[i][E_HOUSE_ENTER][2])) continue;
        if (strlen(gHouseData[i][E_HOUSE_OWNER])) { SendServerMessage(playerid, COLOR_GREY, "Дом занят"); return; }
        if (gPlayerData[playerid][E_PMONEY] < gHouseData[i][E_HOUSE_PRICE]) { SendServerMessage(playerid, COLOR_RED, "Недостаточно денег"); return; }
        gPlayerData[playerid][E_PMONEY] -= gHouseData[i][E_HOUSE_PRICE];
        format(gHouseData[i][E_HOUSE_OWNER], sizeof(gHouseData[][E_HOUSE_OWNER]), "%s", gPlayerData[playerid][E_PNAME]);
        gPlayerData[playerid][E_PHOUSE_ID] = i;
        SaveHouse(i);
        CreateHouseEntities(i);
        SendServerMessage(playerid, COLOR_GREEN, "Вы купили дом %d", gHouseData[i][E_HOUSE_ID]);
        return;
    }
    SendServerMessage(playerid, COLOR_GREY, "Вы не у дома");
}

stock CommandSellHouse(playerid)
{
    if (gPlayerData[playerid][E_PHOUSE_ID] < 0) { SendServerMessage(playerid, COLOR_GREY, "У вас нет дома"); return; }
    new hid = gPlayerData[playerid][E_PHOUSE_ID];
    gPlayerData[playerid][E_PMONEY] += gHouseData[hid][E_HOUSE_PRICE] / 2;
    gHouseData[hid][E_HOUSE_OWNER][0] = '\0';
    gPlayerData[playerid][E_PHOUSE_ID] = -1;
    SaveHouse(hid);
    CreateHouseEntities(hid);
    SendServerMessage(playerid, COLOR_GREEN, "Дом продан");
}

stock SaveHouse(houseid)
{
    if (gDatabase == DB:0) return;
    new query[256];
    format(query, sizeof(query), "UPDATE houses SET owner = '%q', locked = %d, storage_money = %d WHERE id = %d",
        gHouseData[houseid][E_HOUSE_OWNER],
        gHouseData[houseid][E_HOUSE_LOCKED],
        gHouseData[houseid][E_HOUSE_STORAGE_MONEY],
        gHouseData[houseid][E_HOUSE_ID]);
    db_query(gDatabase, query);
}

stock CommandFurnHouse(playerid, params[])
{
    if (gPlayerData[playerid][E_PHOUSE_ID] < 0) { SendServerMessage(playerid, COLOR_GREY, "У вас нет дома"); return; }
    new hid = gPlayerData[playerid][E_PHOUSE_ID];
    SendServerMessage(playerid, COLOR_GREEN, "Мебель: %d/%d предметов", gHouseData[hid][E_HOUSE_FURNITURE_COUNT], MAX_FURNITURE_ITEMS);
}

stock CommandBiz(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Бизнес: /buybiz /sellbiz /bizwar");
    if (gPlayerData[playerid][E_PBUSINESS_ID] >= 0)
    {
        new bid = gPlayerData[playerid][E_PBUSINESS_ID];
        SendServerMessage(playerid, COLOR_GREEN, "Ваш бизнес %s, касса: %d$, продукты: %d/%d",
            gBusinessData[bid][E_BIZ_MENU_NAME],
            gBusinessData[bid][E_BIZ_BALANCE],
            gBusinessData[bid][E_BIZ_PRODUCTS],
            gBusinessData[bid][E_BIZ_MAX_PRODUCTS]);
    }
}

stock CommandBuyBiz(playerid)
{
    for (new i = 0; i < gTotalBusinesses; i++)
    {
        if (!IsPlayerInRangeOfPoint(playerid, 2.5, gBusinessData[i][E_BIZ_POS][0], gBusinessData[i][E_BIZ_POS][1], gBusinessData[i][E_BIZ_POS][2])) continue;
        if (strlen(gBusinessData[i][E_BIZ_OWNER])) { SendServerMessage(playerid, COLOR_GREY, "Бизнес занят"); return; }
        if (gPlayerData[playerid][E_PMONEY] < gBusinessData[i][E_BIZ_PRICE]) { SendServerMessage(playerid, COLOR_RED, "Недостаточно средств"); return; }
        gPlayerData[playerid][E_PMONEY] -= gBusinessData[i][E_BIZ_PRICE];
        format(gBusinessData[i][E_BIZ_OWNER], sizeof(gBusinessData[][E_BIZ_OWNER]), "%s", gPlayerData[playerid][E_PNAME]);
        gPlayerData[playerid][E_PBUSINESS_ID] = i;
        SaveBusiness(i);
        CreateBusinessEntities(i);
        SendServerMessage(playerid, COLOR_GREEN, "Вы купили бизнес %d", gBusinessData[i][E_BIZ_ID]);
        return;
    }
    SendServerMessage(playerid, COLOR_GREY, "Вы не у бизнеса");
}

stock CommandSellBiz(playerid)
{
    if (gPlayerData[playerid][E_PBUSINESS_ID] < 0) { SendServerMessage(playerid, COLOR_GREY, "У вас нет бизнеса"); return; }
    new bid = gPlayerData[playerid][E_PBUSINESS_ID];
    gPlayerData[playerid][E_PMONEY] += gBusinessData[bid][E_BIZ_PRICE] / 2;
    gBusinessData[bid][E_BIZ_OWNER][0] = '\0';
    gPlayerData[playerid][E_PBUSINESS_ID] = -1;
    SaveBusiness(bid);
    CreateBusinessEntities(bid);
    SendServerMessage(playerid, COLOR_GREEN, "Бизнес продан");
}

stock SaveBusiness(bizid)
{
    if (gDatabase == DB:0) return;
    new query[256];
    format(query, sizeof(query), "UPDATE businesses SET owner = '%q', balance = %d, products = %d WHERE id = %d",
        gBusinessData[bizid][E_BIZ_OWNER],
        gBusinessData[bizid][E_BIZ_BALANCE],
        gBusinessData[bizid][E_BIZ_PRODUCTS],
        gBusinessData[bizid][E_BIZ_ID]);
    db_query(gDatabase, query);
}

stock CommandBizWar(playerid, params[])
{
    SendServerMessage(playerid, COLOR_YELLOW, "Вы объявили войну за бизнес. Скоро ивент.");
}

stock CommandEngine(playerid)
{
    new vehicleid = GetPlayerVehicleID(playerid);
    if (!vehicleid || GetPlayerState(playerid) != PLAYER_STATE_DRIVER) { SendServerMessage(playerid, COLOR_GREY, "Вы не водитель"); return; }
    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    engine = !engine;
    SetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    SendServerMessage(playerid, COLOR_GREEN, "Двигатель %s", engine ? "заведен" : "заглушен");
}

stock CommandLockVehicle(playerid)
{
    new vehicleid = GetPlayerVehicleID(playerid);
    if (!vehicleid) { SendServerMessage(playerid, COLOR_GREY, "Вы не в транспорте"); return; }
    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    doors = !doors;
    SetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    SendServerMessage(playerid, COLOR_GREEN, "Вы %s двери", doors ? "закрыли" : "открыли");
}

stock CommandWindow(playerid)
{
    new vehicleid = GetPlayerVehicleID(playerid);
    if (!vehicleid || GetPlayerState(playerid) != PLAYER_STATE_DRIVER) { SendServerMessage(playerid, COLOR_GREY, "Вы не водитель"); return; }
    SendServerMessage(playerid, COLOR_GREY, "Вы опустили стекло.");
}

stock CommandUseKey(playerid, params[])
{
    SendServerMessage(playerid, COLOR_GREY, "Система ключей в разработке");
}

stock CommandSpawnVehicle(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token)))
    {
        SendServerMessage(playerid, COLOR_WHITE, "Используйте: /spawn [modelid]");
        return;
    }
    new model = strval(token);
    if (model < 400 || model > 611) { SendServerMessage(playerid, COLOR_GREY, "Неверный ID модели"); return; }
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    new vehicleid = CreateVehicle(model, x, y, z, 0.0, 1, 1, 60000);
    PutPlayerInVehicle(playerid, vehicleid, 0);
    SendServerMessage(playerid, COLOR_GREEN, "Личный транспорт создан");
}

stock CommandCarMat(playerid, params[])
{
    SendServerMessage(playerid, COLOR_GREY, "CarMat меню скоро");
}

stock CommandRadio(playerid, params[])
{
    new idx = 0; new action[16];
    if (!GetCommandToken(params, idx, action, sizeof(action)))
    {
        ShowPlayerDialog(playerid, 3000, DIALOG_STYLE_INPUT, "Радио", "Используйте: list, join [id], leave", "OK", "Отмена");
        return;
    }
    for (new i = 0; action[i]; i++) if (action[i] >= 'A' && action[i] <= 'Z') action[i] += 32;
    if (!strcmp(action, "list"))
    {
        for (new i = 0; i < gTotalRadioChannels; i++)
        {
            SendServerMessage(playerid, COLOR_RADIO, "[%d] %s", gRadioData[i][E_RADIO_ID], gRadioData[i][E_RADIO_NAME]);
        }
    }
    else if (!strcmp(action, "join"))
    {
        new id;
        if (!GetIntToken(params, idx, id) || id < 0 || id >= gTotalRadioChannels)
        {
            SendServerMessage(playerid, COLOR_RED, "Канал не найден");
            return;
        }
        gPlayerData[playerid][E_PRADIO_CHANNEL] = id;
        SendServerMessage(playerid, COLOR_RADIO, "Вы подключились к %s", gRadioData[id][E_RADIO_NAME]);
    }
    else if (!strcmp(action, "leave"))
    {
        gPlayerData[playerid][E_PRADIO_CHANNEL] = -1;
        SendServerMessage(playerid, COLOR_RADIO, "Вы отключились от радио");
    }
}

stock CommandMusic(playerid, params[])
{
    new idx = 0; new action[16];
    if (!GetCommandToken(params, idx, action, sizeof(action)))
    {
        ShowPlayerDialog(playerid, 4000, DIALOG_STYLE_INPUT, "Музыка", "Используйте: play [id], stop", "OK", "Отмена");
        return;
    }
    for (new i = 0; action[i]; i++) if (action[i] >= 'A' && action[i] <= 'Z') action[i] += 32;
    if (!strcmp(action, "play"))
    {
        new id;
        if (!GetIntToken(params, idx, id) || id < 0 || id >= gTotalAudioStreams)
        {
            SendServerMessage(playerid, COLOR_RED, "Аудиопоток не найден");
            return;
        }
        PlayAudioStreamForPlayer(playerid, gAudioStreamData[id][E_AUDIO_URL]);
        SendServerMessage(playerid, COLOR_RADIO, "Вы слушаете %s", gAudioStreamData[id][E_AUDIO_NAME]);
    }
    else if (!strcmp(action, "stop"))
    {
        StopAudioStreamForPlayer(playerid);
        SendServerMessage(playerid, COLOR_RADIO, "Музыка остановлена");
    }
}

stock CommandHeal(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))){ SendServerMessage(playerid, COLOR_WHITE, "Используйте: /heal [id] [стоимость]"); return; }
    new target = strval(token);
    if (!GetCommandToken(params, idx, token, sizeof(token))){ SendServerMessage(playerid, COLOR_WHITE, "Используйте: /heal [id] [стоимость]"); return; }
    new cost = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    if (gPlayerData[target][E_PMONEY] < cost) { SendServerMessage(playerid, COLOR_RED, "У игрока недостаточно средств"); return; }
    gPlayerData[target][E_PMONEY] -= cost;
    gPlayerData[playerid][E_PMONEY] += cost;
    SetPlayerHealth(target, 100.0);
    gPlayerData[playerid][E_PTOTAL_HEALS] += 1;
    SendServerMessage(playerid, COLOR_GREEN, "Вы вылечили %s за %d$", gPlayerData[target][E_PNAME], cost);
    SendServerMessage(target, COLOR_GREEN, "%s вылечил вас", gPlayerData[playerid][E_PNAME]);
}

stock CommandGiveMedcard(playerid, params[])
{
    if (!IsAdmin(playerid, 2) && gPlayerData[playerid][E_PFRACTION_ID] != 5) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /givemedcard [id] [дни]"); return; }
    new target = strval(token);
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /givemedcard [id] [дни]"); return; }
    new days = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    gPlayerData[target][E_PMEDCARD] = 1;
    gPlayerData[target][E_PMEDCARD_EXPIRE] = gettime() + days * 86400;
    SendServerMessage(target, COLOR_GREEN, "Вы получили мед.карту на %d дней", days);
}

stock CommandShowMedcard(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /showmedcard [id]"); return; }
    new target = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    new text[128];
    format(text, sizeof(text), "Медкарта: %s\nСтатус: %s\nДействует до: %d",
        gPlayerData[target][E_PNAME],
        gPlayerData[target][E_PMEDCARD] ? "Активна" : "Нет",
        gPlayerData[target][E_PMEDCARD_EXPIRE]);
    ShowPlayerDialog(playerid, 1700, DIALOG_STYLE_MSGBOX, "Медкарта", text, "OK", "");
}

stock CommandMask(playerid)
{
    SendServerMessage(playerid, COLOR_GREY, "Вы надели маску, имя скрыто");
}

stock CommandMaterials(playerid, params[])
{
    SendServerMessage(playerid, COLOR_GREY, "Склад материалов в разработке");
}

stock CommandDrugs(playerid, params[])
{
    SendServerMessage(playerid, COLOR_GREY, "Наркотики в разработке");
}

stock CommandRob(playerid, params[])
{
    SendServerMessage(playerid, COLOR_RED, "Вы начали ограбление. Не попадитесь!");
}

stock CommandRobBank(playerid)
{
    SendServerMessage(playerid, COLOR_RED, "Банк ограблен! Полиция уведомлена");
}

stock CommandRobHouse(playerid)
{
    SendServerMessage(playerid, COLOR_RED, "Вы вскрыли дом. Будьте осторожны");
}

stock CommandCapture(playerid, params[])
{
    gPlayerData[playerid][E_PCAPTURE_SCORE] += 5;
    SendServerMessage(playerid, COLOR_YELLOW, "Вы начали захват зоны. Удерживайте позицию!");
}

stock CommandWar(playerid, params[])
{
    SendServerMessage(playerid, COLOR_YELLOW, "Война назначена. Следите за объявлениями.");
}

stock CommandZone(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Зоны");
    for (new i = 0; i < gTotalGZones; i++)
    {
        SendServerMessage(playerid, COLOR_YELLOW, "ID %d, владелец %d", gGangZones[i][E_GZONE_ID], gGangZones[i][E_GZONE_OWNER]);
    }
}

stock CommandWanted(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /wanted [id] [уровень]"); return; }
    new target = strval(token);
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /wanted [id] [уровень]"); return; }
    new level = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    gPlayerData[target][E_PWANTED_LEVEL] = level;
    SendServerMessage(target, COLOR_RED, "Вас разыскивают. Уровень: %d", level);
}

stock CommandWantedList(playerid)
{
    SendServerMessage(playerid, COLOR_WHITE, "Список разыскиваемых:");
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i) || gPlayerData[i][E_PWANTED_LEVEL] <= 0) continue;
        SendServerMessage(playerid, COLOR_RED, "%s - %d", gPlayerData[i][E_PNAME], gPlayerData[i][E_PWANTED_LEVEL]);
    }
}

stock CommandCuff(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /cuff [id]"); return; }
    new target = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    TogglePlayerControllable(target, false);
    SendServerMessage(target, COLOR_RED, "Вы в наручниках");
}

stock CommandUnCuff(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /uncuff [id]"); return; }
    new target = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    TogglePlayerControllable(target, true);
    SendServerMessage(target, COLOR_GREEN, "Вы освобождены от наручников");
}

stock CommandJail(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /jail [id] [минуты] [причина]"); return; }
    new target = strval(token);
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /jail [id] [минуты] [причина]"); return; }
    new minutes = strval(token);
    new reason[64];
    GetCommandRemainder(params, idx, reason, sizeof(reason));
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    gPlayerData[target][E_PJAIL_TIME] = minutes * 60;
    format(gPlayerData[target][E_PJAIL_REASON], sizeof(gPlayerData[][E_PJAIL_REASON]), "%s", reason);
    SetPlayerPos(target, 198.0, 171.0, 1003.0);
    SetPlayerInterior(target, 3);
    TogglePlayerControllable(target, false);
    SendServerMessage(target, COLOR_RED, "Вы посажены на %d минут. Причина: %s", minutes, reason);
}

stock CommandFine(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /fine [id] [сумма] [причина]"); return; }
    new target = strval(token);
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /fine [id] [сумма] [причина]"); return; }
    new amount = strval(token);
    new reason[64];
    GetCommandRemainder(params, idx, reason, sizeof(reason));
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    if (gPlayerData[target][E_PMONEY] < amount)
    {
        gPlayerData[target][E_POFFLINE_FINE] += amount;
    }
    else
    {
        gPlayerData[target][E_PMONEY] -= amount;
        gStateTreasury += amount;
    }
    SendServerMessage(target, COLOR_RED, "Вам выписан штраф %d$. Причина: %s", amount, reason);
}

stock CommandTicket(playerid, params[])
{
    CommandFine(playerid, params);
}

stock CommandEject(playerid, params[])
{
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /eject [id]"); return; }
    new target = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    RemovePlayerFromVehicle(target);
    SendServerMessage(target, COLOR_RED, "Вас вытолкнули из транспорта");
}

stock CommandFamily(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Семья: /fmenu /finvite /kickfamily /fban");
}

stock CommandFamilyMenu(playerid)
{
    SendServerMessage(playerid, COLOR_GREY, "Семейное меню временно недоступно");
}

stock CommandFamilyBan(playerid, params[])
{
    SendServerMessage(playerid, COLOR_GREY, "Вы заблокировали игрока для вступления в семью");
}

stock CommandDice(playerid, params[])
{
    new roll = random(6) + 1;
    SendServerMessage(playerid, COLOR_WHITE, "Вы бросили кость: %d", roll);
}

stock CommandCasino(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Казино ожидает игроков. Используйте столы");
}

stock CommandPaintball(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Пейнтбол: ожидается запуск матча");
}

stock CommandQuest(playerid, params[])
{
    new idx = 0; new action[16];
    if (!GetCommandToken(params, idx, action, sizeof(action)))
    {
        SendServerMessage(playerid, COLOR_WHITE, "Квесты: /quest list, /quest start [id], /quest progress");
        return;
    }
    for (new i = 0; action[i]; i++) if (action[i] >= 'A' && action[i] <= 'Z') action[i] += 32;
    if (!strcmp(action, "list"))
    {
        for (new i = 0; i < gTotalQuests; i++)
        {
            SendServerMessage(playerid, COLOR_GREEN, "[%d] %s - %s", gQuestData[i][E_QUEST_ID], gQuestData[i][E_QUEST_NAME], gQuestData[i][E_QUEST_DESC]);
        }
    }
    else if (!strcmp(action, "start"))
    {
        new qid;
        if (!GetIntToken(params, idx, qid) || qid < 0 || qid >= gTotalQuests)
        {
            SendServerMessage(playerid, COLOR_RED, "Квест не найден");
            return;
        }
        gPlayerData[playerid][E_PQUEST_PROGRESS][qid] = 0;
        SendServerMessage(playerid, COLOR_GREEN, "Вы начали квест %s", gQuestData[qid][E_QUEST_NAME]);
    }
    else if (!strcmp(action, "progress"))
    {
        for (new i = 0; i < gTotalQuests; i++)
        {
            if (gPlayerData[playerid][E_PQUEST_PROGRESS][i] >= 0)
            {
                SendServerMessage(playerid, COLOR_GREEN, "Квест %s: стадия %d", gQuestData[i][E_QUEST_NAME], gPlayerData[playerid][E_PQUEST_PROGRESS][i]);
            }
        }
    }
}

stock CommandBlock(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Вы заблокировали игрока в приват");
}

stock CommandAccept(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Вы приняли запрос");
}

stock CommandChange(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Смена внешности в разработке");
}

stock CommandSpy(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Режим слежки активирован");
}

stock CommandBan(playerid, params[], bool:silent)
{
    if (playerid != INVALID_PLAYER_ID && !IsAdmin(playerid, 1)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /ban [id] [часы] [причина]"); return; }
    new target = strval(token);
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /ban [id] [часы] [причина]"); return; }
    new hours = strval(token);
    new reason[64];
    GetCommandRemainder(params, idx, reason, sizeof(reason));
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    if (gDatabase != DB:0)
    {
        new query[256];
        format(query, sizeof(query), "INSERT INTO bans (name, ip, reason, executor, expire) VALUES ('%q', '%q', '%q', '%q', %d)",
            gPlayerData[target][E_PNAME], gPlayerData[target][E_PIP], reason,
            playerid == INVALID_PLAYER_ID ? "AntiCheat" : gPlayerData[playerid][E_PNAME],
            gettime() + hours * 3600);
        db_query(gDatabase, query);
    }
    if (!silent) Broadcast(COLOR_RED, "%s забанен. Причина: %s", gPlayerData[target][E_PNAME], reason);
    Kick(target);
}

stock CommandIPBan(playerid, params[])
{
    CommandBan(playerid, params, false);
}

stock CommandUnban(playerid, params[])
{
    if (!IsAdmin(playerid, 1)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new name[24];
    if (!GetCommandToken(params, idx, name, sizeof(name))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /unban [ник]"); return; }
    if (gDatabase != DB:0)
    {
        new query[256];
        format(query, sizeof(query), "DELETE FROM bans WHERE name = '%q'", name);
        db_query(gDatabase, query);
    }
    SendServerMessage(playerid, COLOR_GREEN, "Бан снят");
}

stock CommandUnbanIP(playerid, params[])
{
    CommandUnban(playerid, params);
}

stock CommandKick(playerid, params[])
{
    if (playerid != INVALID_PLAYER_ID && !IsAdmin(playerid, 1)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /kick [id] [причина]"); return; }
    new target = strval(token);
    new reason[64];
    GetCommandRemainder(params, idx, reason, sizeof(reason));
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    SendServerMessage(target, COLOR_RED, "Вы кикнуты: %s", reason);
    Kick(target);
}

stock CommandWarn(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Вы выдали предупреждение");
}

stock CommandUnwarn(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Вы сняли предупреждение");
}

stock CommandMute(playerid, params[])
{
    SendServerMessage(playerid, COLOR_WHITE, "Игрок заглушен");
}

stock CommandOfflineAction(playerid, params[], type)
{
    if (!IsAdmin(playerid, 1)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new name[24];
    if (!GetCommandToken(params, idx, name, sizeof(name))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /off... [ник] [значение] [причина]"); return; }
    new valueToken[16];
    if (!GetCommandToken(params, idx, valueToken, sizeof(valueToken))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /off... [ник] [значение] [причина]"); return; }
    new value = strval(valueToken);
    new reason[64];
    GetCommandRemainder(params, idx, reason, sizeof(reason));
    if (gDatabase != DB:0)
    {
        new query[256];
        format(query, sizeof(query), "INSERT INTO offline_actions (target, type, value, reason, executor, timestamp) VALUES ('%q', %d, %d, '%q', '%q', %d)",
            name, type, value, reason, gPlayerData[playerid][E_PNAME], gettime());
        db_query(gDatabase, query);
    }
    SendServerMessage(playerid, COLOR_GREEN, "Оффлайн действие сохранено");
}

stock CommandFreeze(playerid, params[], bool:freeze)
{
    if (!IsAdmin(playerid, 1)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /%s [id]", freeze ? "freeze" : "unfreeze"); return; }
    new target = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    TogglePlayerControllable(target, !freeze);
    SendServerMessage(target, COLOR_RED, freeze ? "Вы заморожены админом" : "Вы разморожены");
}

stock CommandHostName(playerid, params[])
{
    if (!IsAdmin(playerid, 3)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new name[64];
    if (!GetCommandToken(params, idx, name, sizeof(name))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /hostname [название]"); return; }
    new rest[64];
    GetCommandRemainder(params, idx, rest, sizeof(rest));
    if (strlen(rest))
    {
        format(name, sizeof(name), "%s %s", name, rest);
    }
    SendRconCommand(sprintf("hostname %s", name));
    SendServerMessage(playerid, COLOR_GREEN, "Hostname обновлен");
}

stock CommandWeather(playerid, params[])
{
    if (!IsAdmin(playerid, 2)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /weather [id]"); return; }
    new weather = strval(token);
    SetWeather(weather);
    Broadcast(COLOR_BLUE, "Погода изменена на %d", weather);
}

stock CommandGiveRub(playerid, params[])
{
    if (!IsAdmin(playerid, 3)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    SendServerMessage(playerid, COLOR_GREEN, "Вы выдали донат валюту");
}

stock CommandGiveDonate(playerid, params[])
{
    CommandGiveRub(playerid, params);
}

stock CommandGiveFractionRank(playerid, params[])
{
    if (!IsAdmin(playerid, 2)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /agiverank [id] [ранг]"); return; }
    new target = strval(token);
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /agiverank [id] [ранг]"); return; }
    new rank = strval(token);
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    gPlayerData[target][E_PFRACTION_RANK] = rank;
    SendServerMessage(target, COLOR_GREEN, "Ваш ранг изменен на %d", rank);
}

stock CommandFractionMembers(playerid, params[])
{
    if (gPlayerData[playerid][E_PFRACTION_ID] < 0) { SendServerMessage(playerid, COLOR_GREY, "Вы не во фракции"); return; }
    new fid = gPlayerData[playerid][E_PFRACTION_ID];
    SendServerMessage(playerid, COLOR_WHITE, "Состав %s:", gFractionData[fid][E_FRACTION_NAME]);
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i) || gPlayerData[i][E_PFRACTION_ID] != fid) continue;
        SendServerMessage(playerid, COLOR_WHITE, "%s - %s", gPlayerData[i][E_PNAME], gFractionData[fid][E_FRACTION_RANKS][gPlayerData[i][E_PFRACTION_RANK]]);
    }
}

stock CommandTeleport(playerid, params[])
{
    if (!IsAdmin(playerid, 2)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    new idx = 0; new token[16];
    if (!GetCommandToken(params, idx, token, sizeof(token))) { SendServerMessage(playerid, COLOR_WHITE, "Используйте: /teleport [id] [x] [y] [z]"); return; }
    new target = strval(token);
    Float:x, Float:y, Float:z;
    if (!GetFloatToken(params, idx, x) || !GetFloatToken(params, idx, y) || !GetFloatToken(params, idx, z))
    {
        SendServerMessage(playerid, COLOR_WHITE, "Используйте: /teleport [id] [x] [y] [z]");
        return;
    }
    if (!IsPlayerConnected(target)) { SendServerMessage(playerid, COLOR_RED, "Игрок не найден"); return; }
    SetPlayerPos(target, x, y, z);
    SendServerMessage(target, COLOR_GREEN, "Вы телепортированы администратором");
}

stock CommandSpawnAdminVehicle(playerid, params[])
{
    if (!IsAdmin(playerid, 3)) { SendServerMessage(playerid, COLOR_RED, "Недостаточно прав"); return; }
    CommandSpawnVehicle(playerid, params);
}

