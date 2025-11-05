/*
    GunGame + /gpt -> OpenAI (direct HTTPS) — CRASH-FIX
    ---------------------------------------------------
    Что изменено, чтобы не падал сервер:
      1) УБРАЛИ OnRequestFailure полностью — плагин раньше пытался вызывать
         колбэк с другой сигнатурой и это приводило к крашу. Теперь просто
         не существует такого паблика — плагин не дергает его.
      2) НЕ передаем заголовки в RequestsClient — только базовый URL.
         Раньше второй аргумент мог ломать память в плагине.
      3) Заголовки (Authorization, Content-Type) передаем ТОЛЬКО в самой
         RequestJSON(…, body, RequestHeaders(...)).
      4) Оставили Responses API и читаем output_text — это одна строка без
         сложного парсинга массивов.

    Использование:
      /gpt <запрос>     — в игре
      RCON: gpt <запрос>

    Требуется:
      - requests.dll (pawn-requests) в plugins/
      - #include <requests>
      - Исходящий HTTPS (порт 443) наружу
      - Валидный OPENAI_API_KEY
*/

#define MIXED_SPELLINGS

#include <open.mp>
#include <requests>

#define COLOR_INFO      (0xFFFFFFFF)

// ====== НАСТРОЙКИ ======
#define OPENAI_API_KEY  "sk-ijklmnop1234qrstijklmnop1234qrstijklmnop"
#define OPENAI_MODEL    "gpt-4o-mini"

// HTTP(S) клиент к OpenAI API (ТОЛЬКО БАЗОВЫЙ URL, без заголовков здесь)
new RequestsClient:gOpenAI;

// Успешный JSON-колбэк
forward OnGptResponse(Request:id, E_HTTP_STATUS:status, Node:node);

main()
{
    print("\n----------------------------------");
    print(" GunGame + /gpt (Direct OpenAI HTTPS) — CRASH-FIX");
    print(" Commands: /gpt <text>    |    RCON: gpt <text>");
    print("----------------------------------\n");
}

public OnGameModeInit()
{
    SetGameModeText("Gun Game + GPT");
    AddPlayerClass(0, -1291.6622, 2513.7566, 87.0500, 355.3697, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);

    // Только базовый адрес — БЕЗ заголовков
    gOpenAI = RequestsClient("https://api.openai.com/v1/");

    print("Готово. /gpt <запрос> — ответ в чат (OpenAI Responses API).");
    return 1;
}

public OnPlayerConnect(playerid)
{
    SendClientMessage(playerid, COLOR_INFO, "Команда: /gpt <запрос> — короткий ответ от ChatGPT.");
    return 1;
}

// ---- Парсинг команды из чата ----
public OnPlayerCommandText(playerid, cmdtext[])
{
    // Сравниваем первые 4 символа "/gpt" без учета регистра
    if(!strcmp(cmdtext, "/gpt", true, 4))
    {
        new len = strlen(cmdtext);
        if (cmdtext[4] == '\0' || len <= 5 || cmdtext[4] != ' ')
        {
            SendClientMessage(playerid, COLOR_INFO, "Использование: /gpt <запрос>");
            return 1;
        }

        new prompt[256];
        strmid(prompt, cmdtext, 5, len, sizeof(prompt)); // текст после "/gpt "

        // Тело запроса для OpenAI Responses API
        new Node:body = JsonObject(
            "model",             JsonString(OPENAI_MODEL),
            "input",             JsonString(prompt),
            "instructions",      JsonString("Отвечай одной строкой, кратко и по-русски."),
            "max_output_tokens", JsonInt(120)
        );

        // ВАЖНО: заголовки передаем тут, при самом запросе
        RequestJSON(
            gOpenAI,
            "responses",
            HTTP_METHOD_POST,
            "OnGptResponse",
            body,
            RequestHeaders(
                "Authorization", "Bearer " OPENAI_API_KEY,
                "Content-Type",  "application/json"
            )
        );

        SendClientMessage(playerid, COLOR_INFO, "Запрашиваем ChatGPT...");
        return 1;
    }
    return 0;
}

// ---- RCON вариант ----
public OnRconCommand(cmd[])
{
    if(cmd[0] == '/') strdel(cmd, 0, 1);

    if(!strcmp(cmd, "gpt", true, 3))
    {
        new len = strlen(cmd);
        if (cmd[3] == '\0' || len <= 4 || cmd[3] != ' ')
        {
            print("[RCON] Использование: gpt <запрос>");
            return 1;
        }

        new prompt[256];
        strmid(prompt, cmd, 4, len, sizeof(prompt)); // после "gpt "

        new Node:body = JsonObject(
            "model",             JsonString(OPENAI_MODEL),
            "input",             JsonString(prompt),
            "instructions",      JsonString("Отвечай одной строкой, кратко и по-русски."),
            "max_output_tokens", JsonInt(120)
        );

        RequestJSON(
            gOpenAI,
            "responses",
            HTTP_METHOD_POST,
            "OnGptResponse",
            body,
            RequestHeaders(
                "Authorization", "Bearer " OPENAI_API_KEY,
                "Content-Type",  "application/json"
            )
        );

        print("[RCON] Запрос отправлен в OpenAI...");
        return 1;
    }
    return 0;
}

// ---- Успешный ответ OpenAI ----
public OnGptResponse(Request:id, E_HTTP_STATUS:status, Node:node)
{
    if(status != HTTP_STATUS_OK)
    {
        printf("? OpenAI HTTP status: %d", _:status);
        return 1;
    }

    new out[192];
    if (JsonGetString(node, "output_text", out, sizeof(out)) && out[0])
    {
        for(new i = 0; i < MAX_PLAYERS; i++)
            if(IsPlayerConnected(i)) SendClientMessage(i, COLOR_INFO, out);
        printf("?? GPT: %s", out);
        JsonCleanup(node);
        return 1;
    }

    // Фолбэк: вывести сырой JSON, если не нашли output_text
    new raw[256];
    JsonStringify(node, raw, sizeof(raw));
    printf("?? Не удалось получить output_text. Ответ: %s", raw);
    JsonCleanup(node);
    return 1;
}
