using System;
using System.Collections.Concurrent;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using BepInEx;
using BepInEx.Configuration;
using Steamworks;
using UnityEngine;
using UnityEngine.SceneManagement;

[BepInPlugin("awe.hotserver", "HOTServer", "0.1.0")]
public class HOTServerPlugin : BaseUnityPlugin
{
    const int MenuScene = 1;   // SceneManager.LoadScene(1) = The game's main menu
    const int WorldScene = 2;  // On CreateLobby() success, this is the game world
    static readonly string[] TagKeys = { "focus", "mature", "chill", "break", "modded" };

    ConfigEntry<bool> _enabled, _public, _voice, _request, _rebootEnabled;
    ConfigEntry<string> _lobbyName, _tags, _rebootTime;
    ConfigEntry<int> _maxPlayers, _port, _maxFps;

    readonly ConcurrentQueue<(string cmd, TaskCompletionSource<string> tcs)> _cmds =
        new ConcurrentQueue<(string, TaskCompletionSource<string>)>();

    bool _inMenu;
    float _nextAttempt = -1f, _lastAttempt;
    int _attempts;
    TcpListener _listener;
    DateTime _nextReboot = DateTime.MaxValue;
    bool _quitting;
    bool _active;


    // stopped on purpose, don't relaunch
    static string StopFlag => Path.Combine(Paths.BepInExRootPath, "hotserver.stopped");

    void Awake()
    {
        _enabled        = Config.Bind("General", "Enabled", true,
                              "Auto-creates the server when you reach the main menu.\n" +
                              "true  = this system runs as a headless server (auto-hosts on game launch only when -batchmode arg exists).\n" +
                              "false = the mod does nothing. Mainly for playing the game normally.");
        _port           = Config.Bind("General", "Port", 27555,
                              "Port that the server should listen on.\n" +
                              "You generally should not change this value.");
        _rebootEnabled  = Config.Bind("General", "RebootEnabled", false, "Schedule server reboots at a specific time");
        _rebootTime     = Config.Bind("General", "RebootTime", "00:00", "Format: HH:MM (24h)");
        _maxFps         = Config.Bind("General", "TargetFps", 30, "Target tick/frame rate for the server");
        _lobbyName      = Config.Bind("Lobby", "Name", "My HOTServer", "Lobby name.");
        _maxPlayers     = Config.Bind("Lobby", "MaxPlayers", 16, "Max players (>16 needs other third party mods that increase player limit).");
        _public         = Config.Bind("Lobby", "Public", true, "Server visibility (Public or Private, false = Private).");
        _voice          = Config.Bind("Lobby", "VoiceChat", false, "Enable voice chat functionality.");
        _request        = Config.Bind("Lobby", "RequestToJoin", false, "Players must request to join.");
        _tags           = Config.Bind("Lobby", "Tags", "focus", "List of tags, comma separated: focus,mature,chill,break,modded");

        if (!_enabled.Value || !Application.isBatchMode) { Logger.LogInfo("HOTServer idle (needs Enabled = true and -batchmode)."); return; }
        _active = true;
        // Game is running on purpose now, so crash-restart is armed again
        try { if (File.Exists(StopFlag)) File.Delete(StopFlag); } catch (Exception e) { Logger.LogWarning("Stop flag: " + e.Message); }

        Application.runInBackground = true;
        ApplyPerf();
        ScheduleReboot();
        SceneManager.sceneLoaded += OnSceneLoaded;
        StartControl();
        Logger.LogInfo($"HOTServer up. batchmode={Application.isBatchMode} control=127.0.0.1:{_port.Value}");
    }

    void ApplyPerf()
    {
        QualitySettings.vSyncCount = 0;          // targetFrameRate is ignored while vsync is on
        Application.targetFrameRate = Math.Max(1, _maxFps.Value);
        AudioListener.volume = 0f;
        // Disable camera in -batchmode
        if (Application.isBatchMode)
            foreach (var cam in Camera.allCameras) cam.enabled = false;
    }

    // Next occurrence of RebootTime
    void ScheduleReboot()
    {
        if (!_rebootEnabled.Value) { _nextReboot = DateTime.MaxValue; return; }
        if (!DateTime.TryParseExact(_rebootTime.Value.Trim(), "H:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var t))
        {
            Logger.LogWarning($"Bad RebootTime '{_rebootTime.Value}', using 00:00");
            t = DateTime.Today;
        }
        var next = DateTime.Today.Add(t.TimeOfDay);
        if (next <= DateTime.Now.AddMinutes(1)) next = next.AddDays(1);
        _nextReboot = next;
        Logger.LogInfo($"Next reboot: {_nextReboot:yyyy-MM-dd HH:mm}");
    }

    void OnSceneLoaded(Scene scene, LoadSceneMode mode)
    {
        Logger.LogInfo($"Scene loaded: {scene.buildIndex} {scene.name}");
        ApplyPerf();
        _inMenu = scene.buildIndex == MenuScene;
        if (_inMenu) { _attempts = 0; _nextAttempt = Time.realtimeSinceStartup + 10f; } // give Steam time to init
        else _nextAttempt = -1f;
    }

    void Update()
    {
        if (!_active) return;

        while (_cmds.TryDequeue(out var item))
        {
            try { item.tcs.TrySetResult(Handle(item.cmd)); }
            catch (Exception e) { item.tcs.TrySetResult("ERR " + e.Message); }
        }

        if (!_quitting && DateTime.Now >= _nextReboot)
        {
            Logger.LogInfo("Scheduled reboot.");
            Quit(intentionalStop: false); // Hotwatch will reboot it for us
            return;
        }

        if (_inMenu && _nextAttempt > 0 && Time.realtimeSinceStartup >= _nextAttempt) TryHost();
    }

    void TryHost()
    {
        var now = Time.realtimeSinceStartup;
        var mm = MonoSingleton<MultiplayerManager>.I;
        var ui = MonoSingleton<MainMenuUIController>.I;
        if (mm == null || ui == null) { _nextAttempt = now + 5f; Logger.LogWarning("Menu singletons not ready."); return; }

        if (mm.IsConnecting)
        {
            if (_attempts > 0 && now - _lastAttempt > 60f) { Logger.LogWarning("Stuck connecting, resetting."); mm.IsConnecting = false; }
            else { _nextAttempt = now + 10f; return; }
        }

        ApplyFilters(mm);
        ui.CreateSessionNameInputField.text = _lobbyName.Value;
        _attempts++;
        _lastAttempt = now;
        _nextAttempt = now + Math.Min(30f * _attempts, 300f); // if we're still in menu then, it failed
        Logger.LogInfo($"Hosting '{_lobbyName.Value}' (attempt {_attempts})");
        mm.CreateLobby();
    }

    void ApplyFilters(MultiplayerManager mm)
    {
        mm.FilterPlayerValue = Math.Max(1, _maxPlayers.Value) - 1; // CreateLobby uses FilterPlayerValue + 1
        var priv = (FilterType)Enum.Parse(typeof(FilterType), "Private");
        mm.FilterTypeValue = _public.Value ? (FilterType)(1 - (int)priv) : priv; // enum has 2 values (ChangeFilterType % 2)
        mm.FilterIsVoiceChat = _voice.Value;
        mm.FilterIsRequestToJoin = _request.Value;
        var tags = TagSet();
        for (int i = 0; i < TagKeys.Length; i++) mm.FilterSocialTags[i] = tags.Contains(TagKeys[i]);
    }

    string[] TagSet() => _tags.Value.ToLowerInvariant()
        .Split(new[] { ',', ' ' }, StringSplitOptions.RemoveEmptyEntries);

    
    bool TryGetOwnedLobby(out CSteamID id)
    {
        id = default;
        try
        {
            var lm = MonoSingleton<MultiplayerManager>.I?._lobbyManager;
            if (lm == null) return false;
            if (!ulong.TryParse(lm.CurrentLobby.lobbyId, out var raw) || raw == 0) return false;
            id = new CSteamID(raw);
            return SteamMatchmaking.GetLobbyOwner(id) == SteamUser.GetSteamID();
        }
        catch { return false; }
    }

    static string TF(bool b) => b ? "t" : "f";

    void PushLive(string key)
    {
        if (!TryGetOwnedLobby(out var id)) return;
        switch (key)
        {
            case "name":    SteamMatchmaking.SetLobbyData(id, "Name", _lobbyName.Value); break;
            case "public":  SteamMatchmaking.SetLobbyData(id, "public", TF(_public.Value)); break;
            case "voice":   SteamMatchmaking.SetLobbyData(id, "voice", TF(_voice.Value)); break;
            case "request": SteamMatchmaking.SetLobbyData(id, "request", TF(_request.Value)); break;
            case "tags":
                var t = TagSet();
                foreach (var k in TagKeys) SteamMatchmaking.SetLobbyData(id, k, TF(t.Contains(k)));
                break;
            case "maxplayers":
                SteamMatchmaking.SetLobbyMemberLimit(id, _maxPlayers.Value);
                SteamMatchmaking.SetLobbyData(id, "count", _maxPlayers.Value.ToString());
                break;
        }
    }

    // Command handler
    string Handle(string line)
    {
        var parts = line.Split(new[] { ' ' }, 3, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return "";
        switch (parts[0].ToLowerInvariant())
        {
            case "help":
                return "status | players | config | set <name|maxplayers|public|voice|request> <value> | tag <add|remove> <tag> | reboot | stop | start";

            case "status":
            {
                var sb = new StringBuilder();
                sb.AppendLine($"scene={SceneManager.GetActiveScene().buildIndex} fps={(1f / Time.smoothDeltaTime):F1} batchmode={Application.isBatchMode}");
                sb.AppendLine(_nextReboot == DateTime.MaxValue ? "reboot=off" : $"reboot={_nextReboot:yyyy-MM-dd HH:mm}");
                if (TryGetOwnedLobby(out var id))
                    sb.Append($"lobby={id.m_SteamID} members={SteamMatchmaking.GetNumLobbyMembers(id)}/{SteamMatchmaking.GetLobbyMemberLimit(id)} name=\"{SteamMatchmaking.GetLobbyData(id, "Name")}\"");
                else
                    sb.Append($"lobby=none inMenu={_inMenu} attempts={_attempts}");
                return sb.ToString();
            }

            case "players":
            {
                if (!TryGetOwnedLobby(out var id)) return "no lobby";
                int n = SteamMatchmaking.GetNumLobbyMembers(id);
                var sb = new StringBuilder($"{n} member(s)");
                for (int i = 0; i < n; i++)
                {
                    var m = SteamMatchmaking.GetLobbyMemberByIndex(id, i);
                    sb.Append($"\n{m.m_SteamID} {SteamFriends.GetFriendPersonaName(m)}");
                }
                return sb.ToString();
            }

            case "tag":
            {
                var op = parts.Length > 1 ? parts[1].ToLowerInvariant() : "";
                if (parts.Length < 3 || (op != "add" && op != "remove"))
                    return "usage: tag <add|remove> <tag>   (tags: " + string.Join(",", TagKeys) + ")";
                var tag = parts[2].Trim().ToLowerInvariant();
                if (!TagKeys.Contains(tag)) return "ERR unknown tag (tags: " + string.Join(",", TagKeys) + ")";
                var current = TagSet().ToList();
                if (op == "add") { if (!current.Contains(tag)) current.Add(tag); }
                else current.Remove(tag);
                _tags.Value = string.Join(",", current);
                PushLive("tags");
                return "OK tags=" + (_tags.Value.Length > 0 ? _tags.Value : "(none)");
            }

            case "config":
                return $"name=\"{_lobbyName.Value}\" maxplayers={_maxPlayers.Value} public={_public.Value} voice={_voice.Value} request={_request.Value} tags={_tags.Value}";

            case "set":
            {
                if (parts.Length < 3) return "usage: set <key> <value>";
                var key = parts[1].ToLowerInvariant();
                var val = parts[2].Trim();
                switch (key)
                {
                    case "name":       _lobbyName.Value = val; break;
                    case "maxplayers": if (!int.TryParse(val, out var mp) || mp < 1) return "ERR int >= 1"; _maxPlayers.Value = mp; break;
                    case "public":     _public.Value = ParseBool(val); break;
                    case "voice":      _voice.Value = ParseBool(val); break;
                    case "request":    _request.Value = ParseBool(val); break;
                    default: return "ERR unknown key";
                }
                PushLive(key);
                return key == "maxplayers" ? "OK (relaunch to save changes)" : "OK";
            }

            case "reboot":
                Quit(intentionalStop: false);
                return "OK rebooting";

            case "stop":
                Quit(intentionalStop: true);
                return "OK stopping";

            case "start":
                return "already running";

            default:
                return "ERR unknown command (try: help)";
        }
    }

    void Quit(bool intentionalStop)
    {
        if (_quitting) return;
        _quitting = true;
        if (intentionalStop)
        {
            try { File.WriteAllText(StopFlag, DateTime.Now.ToString("o")); }
            catch (Exception e) { Logger.LogWarning("Stop flag: " + e.Message); }
        }
        StartCoroutine(QuitSoon());
    }

    static bool ParseBool(string v)
    {
        v = v.ToLowerInvariant();
        return v == "1" || v == "true" || v == "yes" || v == "on" || v == "t";
    }

    System.Collections.IEnumerator QuitSoon()
    {
        yield return new WaitForSecondsRealtime(1f);
        Application.Quit();
    }

    void StartControl()
    {
        try
        {
            _listener = new TcpListener(IPAddress.Loopback, _port.Value);
            _listener.Start();
        }
        catch (Exception e) { Logger.LogError("Control port failed: " + e.Message); return; }

        new Thread(() =>
        {
            while (true)
            {
                try
                {
                    var client = _listener.AcceptTcpClient();
                    ThreadPool.QueueUserWorkItem(_ => Serve(client));
                }
                catch (Exception e) { Logger.LogError(e); Thread.Sleep(1000); }
            }
        }) { IsBackground = true, Name = "HOTServerControl" }.Start();
    }

    void Serve(TcpClient client)
    {
        try
        {
            using (client)
            using (var s = client.GetStream())
            using (var r = new StreamReader(s))
            using (var w = new StreamWriter(s) { AutoFlush = true, NewLine = "\n" })
            {
                string line;
                while ((line = r.ReadLine()) != null)
                {
                    var tcs = new TaskCompletionSource<string>();
                    _cmds.Enqueue((line.Trim(), tcs));
                    w.WriteLine(tcs.Task.Wait(5000) ? tcs.Task.Result : "ERR timeout (main thread busy)");
                    w.WriteLine(".");
                }
            }
        }
        catch (Exception e) { Logger.LogWarning("Control client: " + e.Message); }
    }
}