/*
    DayZ Survival Gamemode
    ----------------------
    Базовая реализация выживания с системой лута, зомби и простым инвентарём.
    Создано специально для демонстрации возможностей OpenAI в Pawn.
*/

#include <open.mp>

#define COLOR_INFO          (0xA0D0FFFF)
#define COLOR_WARNING       (0xFF9900FF)
#define COLOR_DANGER        (0xC72F2FFF)
#define COLOR_ACTION        (0x6FC040FF)
#define COLOR_ZOMBIE        (0xBB3333FF)

#define SURVIVAL_TICK_MS    (30000)
#define ZOMBIE_TICK_MS      (2000)
#define LOOT_RESPAWN_MS     (120000)

#define MAX_ZOMBIES         (16)
#define LOOT_POINT_COUNT    (20)

#define TEMPERATURE_NORMAL             (36.5)
#define TEMPERATURE_MINIMUM            (30.0)
#define TEMPERATURE_MAXIMUM            (41.5)
#define TEMPERATURE_WARN_COLD          (34.5)
#define TEMPERATURE_WARN_HOT           (39.0)
#define TEMPERATURE_DAMAGE_COLD        (33.0)
#define TEMPERATURE_DAMAGE_HOT         (40.0)
#define TEMPERATURE_DAMAGE_AMOUNT      (4.5)
#define WARM_BUFF_DURATION_MS          (120000)

#define AIRDROP_INTERVAL_MS            (420000)
#define AIRDROP_MODEL                  (1279)
#define AIRDROP_ITEM_ROLLS             (4)


enum E_ITEM_TYPE
{
    ITEM_NONE,
    ITEM_WATER,
    ITEM_FOOD,
    ITEM_BANDAGE,
    ITEM_MEDKIT,
    ITEM_AMMO,
    ITEM_TOOLKIT,
    ITEM_FLARE,
    ITEM_COUNT
};

new const gItemNames[ITEM_COUNT][] =
{
    "-",
    "Бутылка воды",
    "Консервы",
    "Бинт",
    "Аптечка",
    "Патроны",
    "Набор инструментов",
    "Сигнальная шашка"
};

new const gItemModels[ITEM_COUNT] =
{
    0,
    1985,
    2769,
    1575,
    1240,
    2044,
    2964,
    18728
};

static const Float:gSurvivorSpawns[][4] =
{
    {-1652.7329, -222.9151, 14.1484, 42.0},
    {-2085.3325, -101.9431, 35.3203, 180.0},
    {-2071.4121, 181.7751, 28.3359, 270.0},
    {-2591.7639, 633.8423, 14.4531, 12.0},
    {-371.1843, 2229.0244, 43.2656, 98.0},
    {-211.2641, 2705.6497, 62.6797, 220.0},
    {1268.4454, 2522.8848, 10.8203, 180.0},
    {1598.2024, 2198.1802, 10.8203, 270.0},
    {851.6476, 2031.6818, 12.2969, 180.0},
    {1283.8474, 2663.9492, 10.8203, 90.0},
    {2471.6646, -1530.1140, 24.4531, 0.0},
    {2489.3628, -1347.2213, 28.4419, 320.0}
};

static const Float:gZombieSpawns[MAX_ZOMBIES][3] =
{
    {-1691.3204, 66.1429, 14.1484},
    {-1667.5123, 443.9118, 7.1875},
    {-2638.0020, 616.1382, 14.4531},
    {-2052.0544, 167.2816, 28.3359},
    {-224.7132, 2714.8125, 62.6953},
    {-358.3215, 2198.6626, 43.2656},
    {2022.7842, -1905.2571, 13.5469},
    {2479.3459, -1352.3564, 28.4419},
    {1591.1744, 2191.3325, 10.8203},
    {1274.5272, 2531.0029, 10.8203},
    {894.2177, 2036.4725, 12.3828},
    {1289.3048, 2669.4014, 10.8203},
    {741.3792, 1964.1688, 5.5078},
    {2762.4753, -2465.3020, 13.6484},
    {1042.5236, -323.5982, 73.9938},
    {2345.7820, -1141.9871, 105.2578}
};

static const Float:gLootPointCoords[LOOT_POINT_COUNT][3] =
{
    {-1652.6379, 643.2573, 7.1875},
    {-1692.4418, -209.8453, 14.1484},
    {-2643.1277, 637.9819, 14.4531},
    {-2406.0037, -598.2558, 132.5625},
    {-2050.1169, 178.5608, 28.3359},
    {-2075.0947, -98.2346, 35.3203},
    {-213.5473, 2712.2363, 62.6797},
    {2734.8210, -2468.5845, 13.6458},
    {2463.5046, -1528.1971, 23.9922},
    {1600.5720, 2200.2319, 10.8203},
    {1265.9648, 2536.6248, 10.8203},
    {850.2363, 2032.1245, 12.2969},
    {1051.3323, -313.9924, 73.9938},
    {2338.1460, -1132.2323, 105.2373},
    {2090.4521, -1916.8325, 13.5469},
    {2489.3628, -1347.2213, 28.4419},
    {1283.8474, 2663.9492, 10.8203},
    {741.9973, 1967.4421, 5.5078},
    {-380.2142, 2220.9319, 43.2656},
    {-128.4512, 2726.7747, 62.6953}
};

static const Float:gAirdropLocations[][3] =
{
    {-2525.4316, 234.1845, 34.6172},
    {-215.7431, 2735.4478, 63.0078},
    {1278.9028, 2556.3320, 10.8203},
    {2035.1146, -1912.5120, 13.5469},
    {2475.3826, -1522.1914, 24.4531},
    {2765.4915, -2444.0095, 13.6484},
    {1019.6325, -326.2751, 74.0938},
    {-1665.2146, 428.5129, 6.9609}
};

enum E_LOOT_DATA
{
    Float:lootX,
    Float:lootY,
    Float:lootZ,
    lootPickup,
    E_ITEM_TYPE:lootItem,
    bool:lootActive
};

new gLootPoints[LOOT_POINT_COUNT][E_LOOT_DATA];
new gZombieActors[MAX_ZOMBIES];

new gSurvivalTimer = -1;
new gZombieTimer = -1;

new Float:gPlayerHunger[MAX_PLAYERS];
new Float:gPlayerThirst[MAX_PLAYERS];
new bool:gPlayerBleeding[MAX_PLAYERS];
new bool:gPlayerBleedWarned[MAX_PLAYERS];
new bool:gPlayerInfected[MAX_PLAYERS];
new bool:gPlayerHungryWarned[MAX_PLAYERS];
new bool:gPlayerThirstWarned[MAX_PLAYERS];
new bool:gPlayerInfectionWarned[MAX_PLAYERS];
new gPlayerInventory[MAX_PLAYERS][ITEM_COUNT];
new Float:gPlayerTemperature[MAX_PLAYERS];
new bool:gPlayerColdWarned[MAX_PLAYERS];
new bool:gPlayerHeatWarned[MAX_PLAYERS];
new bool:gPlayerFreezing[MAX_PLAYERS];
new bool:gPlayerOverheating[MAX_PLAYERS];
new gPlayerWarmUntil[MAX_PLAYERS];
new bool:gPlayerReceivedWelcome[MAX_PLAYERS];

new gAirdropTimer = -1;
new bool:gAirdropActive = false;
new gAirdropPickup = -1;
new Float:gAirdropPos[3];
new gCurrentHour = 10;

forward SurvivalTick();
forward ZombieTick();
forward RespawnLoot(index);
forward ApplyItemUsage(playerid, E_ITEM_TYPE:item);
forward TriggerAirdrop();

// -------------------- Вспомогательные функции --------------------
stock Float:ClampFloat(Float:value, Float:minValue, Float:maxValue)
{
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
}

stock ResetPlayerSurvivalData(playerid)
{
    gPlayerHunger[playerid] = 100.0;
    gPlayerThirst[playerid] = 100.0;
    gPlayerBleeding[playerid] = false;
    gPlayerBleedWarned[playerid] = false;
    gPlayerInfected[playerid] = false;
    gPlayerHungryWarned[playerid] = false;
    gPlayerThirstWarned[playerid] = false;
    gPlayerInfectionWarned[playerid] = false;
    gPlayerTemperature[playerid] = TEMPERATURE_NORMAL;
    gPlayerColdWarned[playerid] = false;
    gPlayerHeatWarned[playerid] = false;
    gPlayerFreezing[playerid] = false;
    gPlayerOverheating[playerid] = false;
    gPlayerWarmUntil[playerid] = 0;

    for (new E_ITEM_TYPE:item = ITEM_NONE; item < ITEM_COUNT; item++)
        gPlayerInventory[playerid][item] = 0;

    gPlayerInventory[playerid][ITEM_WATER] = 1;
    gPlayerInventory[playerid][ITEM_FOOD] = 1;
    gPlayerInventory[playerid][ITEM_BANDAGE] = 1;
    return 1;
}

stock GetItemName(E_ITEM_TYPE:item, dest[], len)
{
    if (item <= ITEM_NONE || item >= ITEM_COUNT)
    {
        format(dest, len, "Неизвестный предмет");
        return 1;
    }

    format(dest, len, "%s", gItemNames[item]);
    return 1;
}

stock E_ITEM_TYPE:GetItemTypeFromString(const input[])
{
    if (!strcmp(input, "water", true) || !strcmp(input, "вода", true))
        return ITEM_WATER;
    if (!strcmp(input, "food", true) || !strcmp(input, "еда", true) || !strcmp(input, "консервы", true))
        return ITEM_FOOD;
    if (!strcmp(input, "bandage", true) || !strcmp(input, "бинт", true))
        return ITEM_BANDAGE;
    if (!strcmp(input, "medkit", true) || !strcmp(input, "аптечка", true))
        return ITEM_MEDKIT;
    if (!strcmp(input, "ammo", true) || !strcmp(input, "патроны", true))
        return ITEM_AMMO;
    if (!strcmp(input, "toolkit", true) || !strcmp(input, "инструменты", true) || !strcmp(input, "ремкомплект", true))
        return ITEM_TOOLKIT;
    if (!strcmp(input, "flare", true) || !strcmp(input, "факел", true) || !strcmp(input, "шашка", true))
        return ITEM_FLARE;
    return ITEM_NONE;
}

stock E_ITEM_TYPE:RandomLootItem()
{
    new roll = random(100);
    if (roll < 25) return ITEM_WATER;
    if (roll < 50) return ITEM_FOOD;
    if (roll < 65) return ITEM_BANDAGE;
    if (roll < 78) return ITEM_AMMO;
    if (roll < 88) return ITEM_TOOLKIT;
    if (roll < 95) return ITEM_MEDKIT;
    return ITEM_FLARE;
}

stock CreateLootAtIndex(index)
{
    if (index < 0 || index >= LOOT_POINT_COUNT)
        return 0;

    new E_ITEM_TYPE:item = RandomLootItem();
    gLootPoints[index][lootItem] = item;
    gLootPoints[index][lootActive] = true;

    new model = gItemModels[item];
    if (!model) model = 1279;

    gLootPoints[index][lootPickup] = CreatePickup(model, 2, gLootPoints[index][lootX], gLootPoints[index][lootY], gLootPoints[index][lootZ], -1);
    return 1;
}

stock DestroyLootAtIndex(index)
{
    if (index < 0 || index >= LOOT_POINT_COUNT)
        return 0;

    if (gLootPoints[index][lootActive] && gLootPoints[index][lootPickup] != 0)
        DestroyPickup(gLootPoints[index][lootPickup]);

    gLootPoints[index][lootPickup] = 0;
    gLootPoints[index][lootActive] = false;
    gLootPoints[index][lootItem] = ITEM_NONE;
    return 1;
}

stock SetupLootPoints()
{
    for (new i = 0; i < LOOT_POINT_COUNT; i++)
    {
        gLootPoints[i][lootX] = gLootPointCoords[i][0];
        gLootPoints[i][lootY] = gLootPointCoords[i][1];
        gLootPoints[i][lootZ] = gLootPointCoords[i][2];
        gLootPoints[i][lootPickup] = 0;
        gLootPoints[i][lootItem] = ITEM_NONE;
        gLootPoints[i][lootActive] = false;
        CreateLootAtIndex(i);
    }
    return 1;
}

stock CleanupLootPoints()
{
    for (new i = 0; i < LOOT_POINT_COUNT; i++)
        DestroyLootAtIndex(i);
    return 1;
}

stock SetupZombies()
{
    for (new i = 0; i < MAX_ZOMBIES; i++)
    {
        gZombieActors[i] = CreateActor(162, gZombieSpawns[i][0], gZombieSpawns[i][1], gZombieSpawns[i][2], float(random(360)));
    }
    return 1;
}

stock CleanupZombies()
{
    for (new i = 0; i < MAX_ZOMBIES; i++)
    {
        if (gZombieActors[i] != INVALID_ACTOR_ID)
        {
            DestroyActor(gZombieActors[i]);
            gZombieActors[i] = INVALID_ACTOR_ID;
        }
    }
    return 1;
}

stock GiveStarterNotification(playerid)
{
    SendClientMessage(playerid, COLOR_INFO, "Добро пожаловать в {FFFFFF}DayZ{A0D0FF}. Используй /help для списка команд.");
    SendClientMessage(playerid, COLOR_INFO, "Следи за голодом, жаждой и температурой тела, чтобы не погибнуть от стихии.");
    SendClientMessage(playerid, COLOR_INFO, "Красные дымовые ракеты согревают, а воздушные сбросы иногда приносят редкие припасы.");
    return 1;
}

stock ShowPlayerStatus(playerid)
{
    new Float:health;
    GetPlayerHealth(playerid, health);

    new line[144];
    format(line, sizeof(line), "{C8FFC8}Здоровье: %.0f | Голод: %.0f%% | Жажда: %.0f%%", health, gPlayerHunger[playerid], gPlayerThirst[playerid]);
    SendClientMessage(playerid, COLOR_INFO, line);

    new bool:isWarm = (gPlayerWarmUntil[playerid] > GetTickCount());
    new tempStatus[32];
    if (isWarm)
        format(tempStatus, sizeof(tempStatus), "согрет");
    else if (gPlayerTemperature[playerid] <= TEMPERATURE_WARN_COLD)
        format(tempStatus, sizeof(tempStatus), "холодно");
    else if (gPlayerTemperature[playerid] >= TEMPERATURE_WARN_HOT)
        format(tempStatus, sizeof(tempStatus), "жарко");
    else
        format(tempStatus, sizeof(tempStatus), "комфортно");

    format(line, sizeof(line), "{9BD3FF}Температура: %.1f°C | Ощущения: %s | Время: %02d:00", gPlayerTemperature[playerid], tempStatus, gCurrentHour);
    SendClientMessage(playerid, COLOR_INFO, line);

    format(line, sizeof(line), "{FFCD82}Кровотечение: %s | Инфекция: %s", gPlayerBleeding[playerid] ? "да" : "нет", gPlayerInfected[playerid] ? "да" : "нет");
    SendClientMessage(playerid, COLOR_INFO, line);

    new inventory[196];
    BuildInventoryString(playerid, inventory, sizeof(inventory));
    format(line, sizeof(line), "{E3E3E3}Инвентарь: %s", inventory);
    SendClientMessage(playerid, COLOR_INFO, line);
    return 1;
}

stock BuildInventoryString(playerid, dest[], len)
{
    dest[0] = '\0';
    new bool:first = true;

    for (new E_ITEM_TYPE:item = ITEM_WATER; item < ITEM_COUNT; item++)
    {
        if (gPlayerInventory[playerid][item] > 0)
        {
            new itemName[32];
            GetItemName(E_ITEM_TYPE:item, itemName, sizeof(itemName));

            if (first)
            {
                format(dest, len, "%s x%d", itemName, gPlayerInventory[playerid][item]);
                first = false;
            }
            else
            {
                format(dest, len, "%s, %s x%d", dest, itemName, gPlayerInventory[playerid][item]);
            }
        }
    }

    if (first)
        format(dest, len, "ничего");

    return 1;
}

stock bool:TakeInventoryItem(playerid, E_ITEM_TYPE:item)
{
    if (item <= ITEM_NONE || item >= ITEM_COUNT)
        return false;

    if (gPlayerInventory[playerid][item] <= 0)
        return false;

    gPlayerInventory[playerid][item]--;
    return true;
}

stock GiveInventoryItem(playerid, E_ITEM_TYPE:item, amount)
{
    if (item <= ITEM_NONE || item >= ITEM_COUNT)
        return 0;

    gPlayerInventory[playerid][item] += amount;
    return 1;
}

stock HandlePlayerDeath(playerid)
{
    for (new E_ITEM_TYPE:item = ITEM_NONE; item < ITEM_COUNT; item++)
        gPlayerInventory[playerid][item] = 0;

    gPlayerBleeding[playerid] = false;
    gPlayerBleedWarned[playerid] = false;
    gPlayerInfected[playerid] = false;
    gPlayerHungryWarned[playerid] = false;
    gPlayerThirstWarned[playerid] = false;
    gPlayerInfectionWarned[playerid] = false;
    gPlayerTemperature[playerid] = TEMPERATURE_NORMAL;
    gPlayerColdWarned[playerid] = false;
    gPlayerHeatWarned[playerid] = false;
    gPlayerFreezing[playerid] = false;
    gPlayerOverheating[playerid] = false;
    gPlayerWarmUntil[playerid] = 0;
    return 1;
}

stock ScheduleNextAirdrop()
{
    if (gAirdropTimer != -1)
    {
        KillTimer(gAirdropTimer);
        gAirdropTimer = -1;
    }

    gAirdropTimer = SetTimer("TriggerAirdrop", AIRDROP_INTERVAL_MS, false);
    return 1;
}

stock CleanupAirdrop()
{
    if (gAirdropActive && gAirdropPickup != -1)
    {
        DestroyPickup(gAirdropPickup);
    }

    gAirdropPickup = -1;
    gAirdropActive = false;
    gAirdropPos[0] = 0.0;
    gAirdropPos[1] = 0.0;
    gAirdropPos[2] = 0.0;
    return 1;
}

stock GiveAirdropLoot(playerid)
{
    new found[ITEM_COUNT];

    for (new i = 0; i < AIRDROP_ITEM_ROLLS; i++)
    {
        new roll = random(100);
        new amount = 1 + random(2);
        E_ITEM_TYPE:item;

        if (roll < 20)
            item = ITEM_MEDKIT;
        else if (roll < 45)
            item = ITEM_AMMO;
        else if (roll < 65)
            item = ITEM_FOOD;
        else if (roll < 85)
            item = ITEM_WATER;
        else if (roll < 95)
            item = ITEM_TOOLKIT;
        else
            item = ITEM_FLARE;

        found[item] += amount;
        GiveInventoryItem(playerid, item, amount);
    }

    new bool:gaveWeapon = false;
    if (random(100) < 25)
    {
        GivePlayerWeapon(playerid, WEAPON_AK47, 90 + random(61));
        gaveWeapon = true;
    }

    new summary[192];
    new bool:first = true;
    for (new E_ITEM_TYPE:item = ITEM_WATER; item < ITEM_COUNT; item++)
    {
        if (!found[item])
            continue;

        new itemName[32];
        GetItemName(item, itemName, sizeof(itemName));

        if (first)
        {
            format(summary, sizeof(summary), "%s x%d", itemName, found[item]);
            first = false;
        }
        else
        {
            format(summary, sizeof(summary), "%s, %s x%d", summary, itemName, found[item]);
        }
    }

    if (gaveWeapon)
    {
        if (first)
            format(summary, sizeof(summary), "штурмовая винтовка");
        else
            format(summary, sizeof(summary), "%s и штурмовая винтовка", summary);
    }

    if (first && !gaveWeapon)
        format(summary, sizeof(summary), "запас припасов");

    new message[224];
    format(message, sizeof(message), "Вы обыскали ящик с воздушным грузом и получили: %s.", summary);
    SendClientMessage(playerid, COLOR_ACTION, message);
    SendClientMessage(playerid, COLOR_INFO, "Припасы автоматически добавлены в инвентарь.");

    GameTextForPlayer(playerid, "~g~Airdrop secured!", 3000, 3);
    return 1;
}

// -------------------- Основные колбэки --------------------
main()
{
    print("\n----------------------------------");
    print("    DayZ Survival Gamemode");
    print("----------------------------------\n");
}

public OnGameModeInit()
{
    SetGameModeText("DayZ Survival");
    UsePlayerPedAnims();
    ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
    DisableInteriorEnterExits();
    EnableStuntBonusForAll(false);
    AllowInteriorWeapons(true);
    SetNameTagDrawDistance(25.0);
    gCurrentHour = 10;
    SetWorldTime(gCurrentHour);
    SetWeather(9);

    for (new i = 0; i < sizeof(gSurvivorSpawns); i++)
    {
        AddPlayerClass(230, gSurvivorSpawns[i][0], gSurvivorSpawns[i][1], gSurvivorSpawns[i][2], gSurvivorSpawns[i][3], WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);
    }

    SetupLootPoints();
    SetupZombies();

    gSurvivalTimer = SetTimer("SurvivalTick", SURVIVAL_TICK_MS, true);
    gZombieTimer = SetTimer("ZombieTick", ZOMBIE_TICK_MS, true);
    ScheduleNextAirdrop();

    print("DayZ Survival gamemode успешно загружен.");
    return 1;
}

public OnGameModeExit()
{
    if (gSurvivalTimer != -1)
    {
        KillTimer(gSurvivalTimer);
        gSurvivalTimer = -1;
    }

    if (gZombieTimer != -1)
    {
        KillTimer(gZombieTimer);
        gZombieTimer = -1;
    }

    if (gAirdropTimer != -1)
    {
        KillTimer(gAirdropTimer);
        gAirdropTimer = -1;
    }

    CleanupLootPoints();
    CleanupZombies();
    CleanupAirdrop();
    return 1;
}

public OnPlayerConnect(playerid)
{
    ResetPlayerSurvivalData(playerid);
    gPlayerReceivedWelcome[playerid] = false;

    SendClientMessage(playerid, COLOR_INFO, "Вы подключились к DayZ Survival. Используй /help для списка механик.");
    SendClientMessage(playerid, COLOR_INFO, "Выживи любой ценой: следи за голодом, жаждой, инфекциями и температурой тела.");

    if (gAirdropActive)
    {
        new dropMessage[144];
        format(dropMessage, sizeof(dropMessage), "Текущий воздушный сброс находится около координат %.0f %.0f.", gAirdropPos[0], gAirdropPos[1]);
        SendClientMessage(playerid, COLOR_ACTION, dropMessage);
    }
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    ResetPlayerSurvivalData(playerid);
    gPlayerReceivedWelcome[playerid] = false;
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    SetPlayerPos(playerid, gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][0], gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][1], gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][2] + 3.0);
    SetPlayerCameraPos(playerid, gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][0] + 3.0, gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][1], gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][2] + 3.0);
    SetPlayerCameraLookAt(playerid, gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][0], gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][1], gSurvivorSpawns[classid % sizeof(gSurvivorSpawns)][2]);
    GameTextForPlayer(playerid, "~w~DayZ Survival", 4000, 3);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    ResetPlayerSurvivalData(playerid);

    new spawnIndex = random(sizeof(gSurvivorSpawns));
    SetPlayerPos(playerid, gSurvivorSpawns[spawnIndex][0], gSurvivorSpawns[spawnIndex][1], gSurvivorSpawns[spawnIndex][2]);
    SetPlayerFacingAngle(playerid, gSurvivorSpawns[spawnIndex][3]);
    SetPlayerHealth(playerid, 100.0);
    SetPlayerArmour(playerid, 0.0);
    ResetPlayerWeapons(playerid);

    if (!gPlayerReceivedWelcome[playerid])
    {
        GiveStarterNotification(playerid);
        gPlayerReceivedWelcome[playerid] = true;
    }
    else
    {
        SendClientMessage(playerid, COLOR_INFO, "Новая жизнь началась. Поиск припасов и тепло помогут вам выжить дольше.");
    }
    return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
    HandlePlayerDeath(playerid);
    SendClientMessage(playerid, COLOR_DANGER, "Вы погибли и потеряли все припасы. Попробуйте ещё раз!");
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!strcmp(cmdtext, "/status", true))
    {
        ShowPlayerStatus(playerid);
        return 1;
    }

    if (!strcmp(cmdtext, "/help", true))
    {
        SendClientMessage(playerid, COLOR_INFO, "Доступные команды: /status, /inventory, /use [предмет], /craft flare, /craft ammo, /airdrop");
        SendClientMessage(playerid, COLOR_INFO, "Примеры: /use вода, /craft flare, /airdrop");
        SendClientMessage(playerid, COLOR_INFO, "Факелы согревают от холода, а воздушные сбросы дают редкие припасы.");
        return 1;
    }

    if (!strcmp(cmdtext, "/airdrop", true))
    {
        if (gAirdropActive)
        {
            new message[144];
            format(message, sizeof(message), "Воздушный ящик падает недалеко от координат %.0f %.0f.", gAirdropPos[0], gAirdropPos[1]);
            SendClientMessage(playerid, COLOR_ACTION, message);
        }
        else
        {
            SendClientMessage(playerid, COLOR_INFO, "Самолёт пока не замечен. Следите за небом и слушайте сирены.");
        }
        return 1;
    }

    if (!strcmp(cmdtext, "/inventory", true) || !strcmp(cmdtext, "/inv", true))
    {
        new inventory[196];
        BuildInventoryString(playerid, inventory, sizeof(inventory));
        new message[220];
        format(message, sizeof(message), "Ваш инвентарь: %s", inventory);
        SendClientMessage(playerid, COLOR_INFO, message);
        return 1;
    }

    if (!strcmp(cmdtext, "/use", true, 4))
    {
        if (cmdtext[4] == '\0')
        {
            SendClientMessage(playerid, COLOR_INFO, "Использование: /use [предмет]");
            return 1;
        }

        if (cmdtext[4] != ' ')
        {
            SendClientMessage(playerid, COLOR_INFO, "Использование: /use [предмет]");
            return 1;
        }

        new param[32];
        strmid(param, cmdtext, 5, strlen(cmdtext), sizeof(param));

        new E_ITEM_TYPE:item = GetItemTypeFromString(param);
        if (item == ITEM_NONE)
        {
            SendClientMessage(playerid, COLOR_INFO, "Неизвестный предмет.");
            return 1;
        }

        if (!TakeInventoryItem(playerid, item))
        {
            SendClientMessage(playerid, COLOR_WARNING, "У вас нет такого предмета.");
            return 1;
        }

        ApplyItemUsage(playerid, item);
        return 1;
    }

    if (!strcmp(cmdtext, "/craft", true, 6))
    {
        if (cmdtext[6] == '\0' || cmdtext[6] != ' ')
        {
            SendClientMessage(playerid, COLOR_INFO, "Использование: /craft [название]");
            return 1;
        }

        new param[24];
        strmid(param, cmdtext, 7, strlen(cmdtext), sizeof(param));

        if (!strcmp(param, "flare", true) || !strcmp(param, "факел", true))
        {
            if (gPlayerInventory[playerid][ITEM_TOOLKIT] >= 1 && gPlayerInventory[playerid][ITEM_AMMO] >= 1)
            {
                gPlayerInventory[playerid][ITEM_TOOLKIT]--;
                gPlayerInventory[playerid][ITEM_AMMO]--;
                gPlayerInventory[playerid][ITEM_FLARE]++;
                SendClientMessage(playerid, COLOR_ACTION, "Вы собрали сигнальную шашку из патронов и инструментов.");
            }
            else
            {
                SendClientMessage(playerid, COLOR_WARNING, "Нужно: 1 набор инструментов и 1 пачка патронов.");
            }
            return 1;
        }

        if (!strcmp(param, "ammo", true) || !strcmp(param, "патроны", true))
        {
            if (gPlayerInventory[playerid][ITEM_TOOLKIT] >= 1 && gPlayerInventory[playerid][ITEM_FOOD] >= 1)
            {
                gPlayerInventory[playerid][ITEM_TOOLKIT]--;
                gPlayerInventory[playerid][ITEM_FOOD]--;
                gPlayerInventory[playerid][ITEM_AMMO] += 2;
                SendClientMessage(playerid, COLOR_ACTION, "Вы собрали самодельные патроны, потратив инструменты и консервы.");
            }
            else
            {
                SendClientMessage(playerid, COLOR_WARNING, "Нужно: 1 набор инструментов и 1 консерва.");
            }
            return 1;
        }

        SendClientMessage(playerid, COLOR_INFO, "Неизвестный рецепт. Доступные: flare, ammo");
        return 1;
    }

    return 0;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if (gAirdropActive && pickupid == gAirdropPickup)
    {
        GiveAirdropLoot(playerid);

        new playerName[MAX_PLAYER_NAME];
        GetPlayerName(playerid, playerName, sizeof(playerName));

        new message[160];
        format(message, sizeof(message), "%s обезопасил воздушный сброс и забрал припасы!", playerName);
        SendClientMessageToAll(COLOR_ACTION, message);

        CleanupAirdrop();
        ScheduleNextAirdrop();
        return 1;
    }

    for (new i = 0; i < LOOT_POINT_COUNT; i++)
    {
        if (!gLootPoints[i][lootActive])
            continue;

        if (gLootPoints[i][lootPickup] == pickupid)
        {
            new E_ITEM_TYPE:item = gLootPoints[i][lootItem];
            if (item <= ITEM_NONE || item >= ITEM_COUNT)
                return 1;

            GiveInventoryItem(playerid, item, 1);

            new itemName[32];
            GetItemName(item, itemName, sizeof(itemName));

            new message[96];
            format(message, sizeof(message), "Вы нашли %s", itemName);
            SendClientMessage(playerid, COLOR_ACTION, message);

            DestroyLootAtIndex(i);
            SetTimerEx("RespawnLoot", LOOT_RESPAWN_MS, false, "d", i);
            return 1;
        }
    }
    return 1;
}

public OnPlayerTakeDamage(playerid, issuerid, Float:amount, WEAPON:weaponid, bodypart)
{
    if (amount >= 15.0 && !gPlayerBleeding[playerid] && random(100) < 40)
    {
        gPlayerBleeding[playerid] = true;
        gPlayerBleedWarned[playerid] = true;
        SendClientMessage(playerid, COLOR_DANGER, "Вы получили серьёзную рану и начали истекать кровью. Используйте бинт!");
    }
    return 1;
}

// -------------------- Обработка предметов --------------------
stock ApplyItemUsage(playerid, E_ITEM_TYPE:item)
{
    switch (item)
    {
        case ITEM_NONE:
        {
            SendClientMessage(playerid, COLOR_WARNING, "Предмет не найден.");
        }
        case ITEM_WATER:
        {
            gPlayerThirst[playerid] = ClampFloat(gPlayerThirst[playerid] + 45.0, 0.0, 100.0);
            gPlayerTemperature[playerid] = ClampFloat(gPlayerTemperature[playerid] - 0.5, TEMPERATURE_MINIMUM, TEMPERATURE_MAXIMUM);
            if (gPlayerTemperature[playerid] <= TEMPERATURE_WARN_COLD)
                gPlayerColdWarned[playerid] = false;
            SendClientMessage(playerid, COLOR_ACTION, "Вы утолили жажду и освежились.");
        }
        case ITEM_FOOD:
        {
            gPlayerHunger[playerid] = ClampFloat(gPlayerHunger[playerid] + 35.0, 0.0, 100.0);
            gPlayerTemperature[playerid] = ClampFloat(gPlayerTemperature[playerid] + 0.2, TEMPERATURE_MINIMUM, TEMPERATURE_MAXIMUM);
            SendClientMessage(playerid, COLOR_ACTION, "Вы перекусили консервами.");
        }
        case ITEM_BANDAGE:
        {
            if (gPlayerBleeding[playerid])
            {
                gPlayerBleeding[playerid] = false;
                gPlayerBleedWarned[playerid] = false;
                SendClientMessage(playerid, COLOR_ACTION, "Вы перевязали рану и остановили кровотечение.");
            }
            else
            {
                SendClientMessage(playerid, COLOR_WARNING, "У вас нет кровотечения. Бинт сохранён.");
                gPlayerInventory[playerid][ITEM_BANDAGE]++;
            }
        }
        case ITEM_MEDKIT:
        {
            new Float:health;
            GetPlayerHealth(playerid, health);
            health = ClampFloat(health + 35.0, 0.0, 100.0);
            SetPlayerHealth(playerid, health);

            gPlayerBleeding[playerid] = false;
            gPlayerBleedWarned[playerid] = false;
            gPlayerInfected[playerid] = false;
            gPlayerInfectionWarned[playerid] = false;
            SendClientMessage(playerid, COLOR_ACTION, "Вы использовали аптечку и поправили здоровье.");
        }
        case ITEM_AMMO:
        {
            new WEAPON:weapon = GetPlayerWeapon(playerid);
            if (weapon == WEAPON:0 || weapon == WEAPON_FIST)
            {
                GivePlayerWeapon(playerid, WEAPON_COLT45, 30);
                SendClientMessage(playerid, COLOR_ACTION, "Вы нашли старый пистолет вместе с патронами.");
            }
            else
            {
                GivePlayerWeapon(playerid, weapon, 30);
                SendClientMessage(playerid, COLOR_ACTION, "Вы пополнили боезапас.");
            }
        }
        case ITEM_TOOLKIT:
        {
            if (IsPlayerInAnyVehicle(playerid))
            {
                new vehicleid = GetPlayerVehicleID(playerid);
                RepairVehicle(vehicleid);
                SendClientMessage(playerid, COLOR_ACTION, "Вы отремонтировали транспорт.");
            }
            else
            {
                SendClientMessage(playerid, COLOR_WARNING, "Вы не в транспорте. Набор сохранён.");
                gPlayerInventory[playerid][ITEM_TOOLKIT]++;
            }
        }
        case ITEM_FLARE:
        {
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid, x, y, z);
            CreateExplosion(x, y, z, 3, 2.0);
            gPlayerWarmUntil[playerid] = GetTickCount() + WARM_BUFF_DURATION_MS;
            gPlayerTemperature[playerid] = ClampFloat(gPlayerTemperature[playerid] + 1.5, TEMPERATURE_MINIMUM, TEMPERATURE_MAXIMUM);
            gPlayerColdWarned[playerid] = false;
            gPlayerFreezing[playerid] = false;
            SendClientMessage(playerid, COLOR_ACTION, "Вы подожгли сигнальную шашку: рядом стало теплее, но шум привлекает зомби!");
        }
        default:
        {
            SendClientMessage(playerid, COLOR_WARNING, "Этот предмет пока нельзя использовать.");
        }
    }
    return 1;
}

// -------------------- Таймеры --------------------
public SurvivalTick()
{
    gCurrentHour = (gCurrentHour + 1) % 24;
    SetWorldTime(gCurrentHour);

    new currentTick = GetTickCount();

    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (!IsPlayerConnected(playerid))
            continue;

        new PLAYER_STATE:playerState = GetPlayerState(playerid);
        if (playerState != PLAYER_STATE_ONFOOT && playerState != PLAYER_STATE_DRIVER && playerState != PLAYER_STATE_PASSENGER)
            continue;

        gPlayerHunger[playerid] = ClampFloat(gPlayerHunger[playerid] - 2.0, 0.0, 100.0);
        gPlayerThirst[playerid] = ClampFloat(gPlayerThirst[playerid] - 3.0, 0.0, 100.0);

        new Float:health;
        GetPlayerHealth(playerid, health);

        if (gPlayerHunger[playerid] <= 0.0)
        {
            health = ClampFloat(health - 4.0, 0.0, 100.0);
            if (!gPlayerHungryWarned[playerid])
            {
                SendClientMessage(playerid, COLOR_WARNING, "Вы умираете от голода! Найдите еду немедленно.");
                gPlayerHungryWarned[playerid] = true;
            }
        }
        else if (gPlayerHunger[playerid] < 30.0 && !gPlayerHungryWarned[playerid])
        {
            SendClientMessage(playerid, COLOR_WARNING, "Вы проголодались. Поищите консервы или приготовьте еду.");
            gPlayerHungryWarned[playerid] = true;
        }
        else if (gPlayerHunger[playerid] > 45.0)
        {
            gPlayerHungryWarned[playerid] = false;
        }

        if (gPlayerThirst[playerid] <= 0.0)
        {
            health = ClampFloat(health - 6.0, 0.0, 100.0);
            if (!gPlayerThirstWarned[playerid])
            {
                SendClientMessage(playerid, COLOR_DANGER, "Вы обезвожены и теряете здоровье!");
                gPlayerThirstWarned[playerid] = true;
            }
        }
        else if (gPlayerThirst[playerid] < 30.0 && !gPlayerThirstWarned[playerid])
        {
            SendClientMessage(playerid, COLOR_WARNING, "Вы испытываете жажду. Найдите воду.");
            gPlayerThirstWarned[playerid] = true;
        }
        else if (gPlayerThirst[playerid] > 45.0)
        {
            gPlayerThirstWarned[playerid] = false;
        }

        if (gPlayerBleeding[playerid])
        {
            health = ClampFloat(health - 5.0, 0.0, 100.0);
            if (!gPlayerBleedWarned[playerid])
            {
                SendClientMessage(playerid, COLOR_DANGER, "Вы истекаете кровью! Используйте бинт.");
                gPlayerBleedWarned[playerid] = true;
            }
        }
        else
        {
            gPlayerBleedWarned[playerid] = false;
        }

        if (gPlayerInfected[playerid])
        {
            health = ClampFloat(health - 3.0, 0.0, 100.0);
            if (!gPlayerInfectionWarned[playerid])
            {
                SendClientMessage(playerid, COLOR_WARNING, "Вы заражены. Найдите аптечку!");
                gPlayerInfectionWarned[playerid] = true;
            }
        }
        else
        {
            gPlayerInfectionWarned[playerid] = false;
        }

        new bool:isWarm = false;
        if (gPlayerWarmUntil[playerid] != 0)
        {
            if (currentTick >= gPlayerWarmUntil[playerid])
            {
                gPlayerWarmUntil[playerid] = 0;
                SendClientMessage(playerid, COLOR_INFO, "Согревающий эффект сигнальной шашки закончился.");
            }
            else
            {
                isWarm = true;
            }
        }

        new bool:isNight = (gCurrentHour < 6 || gCurrentHour >= 21);
        new Float:temperatureDelta = -0.12;

        if (isNight)
            temperatureDelta -= 0.18;
        else if (gCurrentHour >= 12 && gCurrentHour <= 15)
            temperatureDelta += 0.18;
        else if (gCurrentHour >= 16 && gCurrentHour <= 18)
            temperatureDelta += 0.05;

        if (isWarm)
            temperatureDelta += 0.60;

        if (IsPlayerInAnyVehicle(playerid))
            temperatureDelta += 0.05;

        new Float:vx, Float:vy, Float:vz;
        GetPlayerVelocity(playerid, vx, vy, vz);
        new Float:speed = floatsqroot(vx * vx + vy * vy + vz * vz);
        if (speed > 0.30)
            temperatureDelta += 0.08;
        if (speed > 1.00)
            temperatureDelta += 0.05;

        if (!isWarm && isNight && random(100) < 15)
            temperatureDelta -= 0.15;

        gPlayerTemperature[playerid] = ClampFloat(gPlayerTemperature[playerid] + temperatureDelta, TEMPERATURE_MINIMUM, TEMPERATURE_MAXIMUM);

        if (gPlayerTemperature[playerid] <= TEMPERATURE_WARN_COLD)
        {
            if (!gPlayerColdWarned[playerid])
            {
                SendClientMessage(playerid, COLOR_WARNING, "Вы начинаете замерзать. Найдите укрытие или источник тепла.");
                gPlayerColdWarned[playerid] = true;
            }
        }
        else if (gPlayerColdWarned[playerid] && gPlayerTemperature[playerid] > TEMPERATURE_WARN_COLD + 0.8)
        {
            SendClientMessage(playerid, COLOR_INFO, "Вам стало теплее.");
            gPlayerColdWarned[playerid] = false;
        }

        if (gPlayerTemperature[playerid] >= TEMPERATURE_WARN_HOT)
        {
            if (!gPlayerHeatWarned[playerid])
            {
                SendClientMessage(playerid, COLOR_WARNING, "Жара растёт. Найдите тень или выпейте воды.");
                gPlayerHeatWarned[playerid] = true;
            }
        }
        else if (gPlayerHeatWarned[playerid] && gPlayerTemperature[playerid] < TEMPERATURE_WARN_HOT - 0.7)
        {
            SendClientMessage(playerid, COLOR_INFO, "Температура тела стабилизировалась.");
            gPlayerHeatWarned[playerid] = false;
        }

        if (gPlayerTemperature[playerid] <= TEMPERATURE_DAMAGE_COLD)
        {
            health = ClampFloat(health - TEMPERATURE_DAMAGE_AMOUNT, 0.0, 100.0);
            if (!gPlayerFreezing[playerid])
            {
                SendClientMessage(playerid, COLOR_DANGER, "Вы замерзаете! Разведите огонь или используйте сигнальную шашку.");
                gPlayerFreezing[playerid] = true;
            }
        }
        else if (gPlayerFreezing[playerid] && gPlayerTemperature[playerid] > TEMPERATURE_WARN_COLD + 0.4)
        {
            SendClientMessage(playerid, COLOR_INFO, "Кровь снова циркулирует, вы перестали замерзать.");
            gPlayerFreezing[playerid] = false;
        }

        if (gPlayerTemperature[playerid] >= TEMPERATURE_DAMAGE_HOT)
        {
            health = ClampFloat(health - (TEMPERATURE_DAMAGE_AMOUNT - 1.0), 0.0, 100.0);
            if (!gPlayerOverheating[playerid])
            {
                SendClientMessage(playerid, COLOR_DANGER, "Тепловой удар! Охладитесь водой и укрытием.");
                gPlayerOverheating[playerid] = true;
            }
        }
        else if (gPlayerOverheating[playerid] && gPlayerTemperature[playerid] < TEMPERATURE_WARN_HOT - 0.2)
        {
            SendClientMessage(playerid, COLOR_INFO, "Жара спала, дыхание выровнялось.");
            gPlayerOverheating[playerid] = false;
        }

        SetPlayerHealth(playerid, health);

        if (health <= 0.0)
        {
            SetPlayerHealth(playerid, 0.0);
        }
    }
    return 1;
}

public TriggerAirdrop()
{
    if (gAirdropActive)
        return 1;

    new bool:hasActivePlayer = false;
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (!IsPlayerConnected(playerid))
            continue;

        if (GetPlayerState(playerid) == PLAYER_STATE_WASTED)
            continue;

        hasActivePlayer = true;
        break;
    }

    if (!hasActivePlayer)
    {
        ScheduleNextAirdrop();
        return 1;
    }

    new location = random(sizeof(gAirdropLocations));
    gAirdropPos[0] = gAirdropLocations[location][0];
    gAirdropPos[1] = gAirdropLocations[location][1];
    gAirdropPos[2] = gAirdropLocations[location][2];

    gAirdropPickup = CreatePickup(AIRDROP_MODEL, 2, gAirdropPos[0], gAirdropPos[1], gAirdropPos[2], -1);
    gAirdropActive = true;

    new message[144];
    format(message, sizeof(message), "Самолёт сбросил груз у координат %.0f %.0f. Дым виден издалека!", gAirdropPos[0], gAirdropPos[1]);
    SendClientMessageToAll(COLOR_ACTION, message);
    SendClientMessageToAll(COLOR_INFO, "Доберитесь до ящика как можно скорее, пока его не нашли другие выжившие.");
    return 1;
}

public ZombieTick()
{
    for (new i = 0; i < MAX_ZOMBIES; i++)
    {
        if (gZombieActors[i] == INVALID_ACTOR_ID)
            continue;

        new Float:zx, Float:zy, Float:zz;
        GetActorPos(gZombieActors[i], zx, zy, zz);

        if (random(100) < 15)
        {
            new Float:offsetX = float(random(600) - 300) / 100.0;
            new Float:offsetY = float(random(600) - 300) / 100.0;
            SetActorPos(gZombieActors[i], zx + offsetX, zy + offsetY, zz);
        }

        for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
        {
            if (!IsPlayerConnected(playerid))
                continue;

            if (GetPlayerState(playerid) == PLAYER_STATE_WASTED)
                continue;

            new Float:px, Float:py, Float:pz;
            GetPlayerPos(playerid, px, py, pz);

            new Float:distance = floatsqroot(floatpower(px - zx, 2.0) + floatpower(py - zy, 2.0) + floatpower(pz - zz, 2.0));

            if (distance < 1.8)
            {
                new Float:health;
                GetPlayerHealth(playerid, health);
                health = ClampFloat(health - 7.0, 0.0, 100.0);
                SetPlayerHealth(playerid, health);

                if (random(100) < 35 && !gPlayerBleeding[playerid])
                {
                    gPlayerBleeding[playerid] = true;
                    gPlayerBleedWarned[playerid] = true;
                    SendClientMessage(playerid, COLOR_ZOMBIE, "Зомби разорвал вам кожу! Вы истекаете кровью.");
                }

                if (random(100) < 20)
                {
                    gPlayerInfected[playerid] = true;
                    gPlayerInfectionWarned[playerid] = true;
                    SendClientMessage(playerid, COLOR_ZOMBIE, "Вы заражены вирусом. Срочно найдите аптечку!");
                }

                GameTextForPlayer(playerid, "~r~Zombie hit!", 1500, 3);
            }
            else if (distance < 8.0 && random(100) < 30)
            {
                new Float:look = atan2(px - zx, py - zy);
                SetActorFacingAngle(gZombieActors[i], look);
            }
        }
    }
    return 1;
}

public RespawnLoot(index)
{
    CreateLootAtIndex(index);
    return 1;
}

