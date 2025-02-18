// Turok: Remastered Auto-Splitter
// Supports Steam version, patches 1.4.3, 1.4.6, 1.4.7, and 2.0
// For issues and support please join the Turok Speedrunning Discord at https://discord.gg/C8vczW2

// Game State Variables
/*
    string255 level
        The full name of the level, eg "the hub"
    string255 map
        The filename of the currently loaded map, eg "levels/level04.map"
    int health
        The PC's health value
    int currentBossHealth
        The health value of the boss currently being fought
        This value cannot be trusted outside of boss arenas. I'm investigating pointers to specific boss health but this works for now.
    int warpId
        The current Warp ID
        Warp ID can be thought of as the destination of the current warp. So taking the same teleporter back and forth will use two different Warp IDs.
        Warp ID is always -1 when not warping and then populates with the proper ID during the warp
        Splitting on Warp ID is currently preferred over Level and Map. It's more consistent and easier to route, especially for any%
        A table of known Warp IDs is included in this repo as "warpIds.md". Its accuracy and/or completeness are not guaranteed.
    int levelKeysRemaining
        The number of keys remaining in the level
        Currently only used to protect against an edge-case where a player uses the portal after double jump in Treetop Village without grabbing the key first
        This allows them to go back and get the key without screwing up their splits
        Now that I've typed that out, is it really necessary?
    byte level8Keys
        Tracks which Level 8 keys have been collected
        Used in Randomizer runs (hence why it's only in 2.0+) to allow splitting whenever a Level 8 key is found, regardless of order
*/

// 1.4.3 (2015-12-19)
state("sobek", "1.4.3")
{
    string255 level: 0x27D764, 0x0, 0x0;
    string255 map: 0x27D740, 0x0;
    int health: 0x27DA3C, 0xE0;
    int currentBossHealth: 0x27DBD4, 0xE0;
    int warpId: 0x27DF64;
    int levelKeysRemaining: 0x27D764, 0x40;
}

// 1.4.6 (2016-01-15)
state("sobek", "1.4.6") 
{
    string255 level: 0x286E7C, 0x0, 0x0;
    string255 map: 0x286E58, 0x0;
    int health: 0x287154, 0xE0;
    int currentBossHealth: 0x2872F0, 0xE0;
    int warpId: 0x287684;
    int levelKeysRemaining: 0x286E7C, 0x40;
}

// 1.4.7 (2016-02-23)
state("sobek", "1.4.7") 
{
    // string255 level: 0x286E7C, 0x0, 0x0;
    string255 map: 0x25DEF0, 0x0;
    int health: 0x25E1EC, 0xE0;
    int currentBossHealth: 0x25E388, 0xE0;
    int warpId: 0x43C9C, 0x0;
    int levelKeysRemaining: 0x25DF14, 0x40;
}

// current patch (2018-07-28)
state("sobek", "2.0")
{
    string255 level: 0x3AE25C, 0x0;
    string255 map: 0x38E3FC, 0x0;
    int health: 0x390CF4, 0xE0;
    int currentBossHealth: 0x393118, 0xE0;
    int warpId: 0x49ED0, 0x0; 
    int levelKeysRemaining: 0x38E428, 0x50; 
    byte level8Keys: 0x38E408, 0x414;
}

init
{
    // Call this action to print debug messages, e.g. vars.debug("Split on warpId: " + warpId)
    vars.debug = (Action<string>)((msg) => print("[Turok ASL] " + msg));

    // SHA1 checksums for known versions
    var checksums = new Dictionary<string, string>();
    checksums.Add("34-69-03-7C-0F-FB-13-1C-0B-85-4F-79-35-1A-4B-9B-FA-97-92-EC", "1.4.3");
    checksums.Add("0F-28-95-79-B0-F7-07-14-56-F5-49-02-41-92-D0-2E-D7-7B-D7-B0", "1.4.6");
    checksums.Add("88-73-01-2C-0B-30-78-7A-4F-D1-D6-34-99-89-41-65-50-E4-30-F7", "1.4.7");
    checksums.Add("30-C8-C2-DB-F2-F2-E3-F1-64-09-2C-8C-22-B2-7C-2D-32-4C-37-41", "2.0");

    // Get a SHA1 checksum of sobek.exe
    string processPath = modules.First().FileName;
    FileStream fileStream = File.OpenRead(processPath);
    string processHash = BitConverter.ToString(System.Security.Cryptography.SHA1.Create().ComputeHash(fileStream));
    vars.debug("processHash: " + processHash);

    // Look for known checksums and set version accordingly
    // This check loops whenever a run is not in progress so it's normal and expected that your debug log is full of these messages
    if (checksums.ContainsKey(processHash))
    {
        version = checksums[processHash];
        vars.debug("Version detected: " + version);
    }
    else
    {
        version = "2.0";
        vars.debug("Couldn't detect version, defaulting to 2.0");
    }
}

startup 
{
    // Settings
    // Settings defined here cannot be changed within code, only with the checkboxes within LiveSplit
    // `vars.variableName` is declared for a setting when we want to modify that setting within code (like a known route)

    settings.Add("reset-title", true, "Reset on Titlescreen");
    settings.SetToolTip("reset-title", "Reset the run any time you enter the title screen. " +
                                        "Disable this if you want the ability to continue from a save after a Game Over. " + 
                                        "Check the rules for your category to make sure this is allowed. " +
                                        "This setting has no impact on zombie mode.");

    // Parent Custom Setting
    settings.Add("custom", false, "Custom Splits"); 
    settings.SetToolTip("custom", "Customize your split settings. This will disable automatic route detection");
    settings.CurrentDefaultParent = "custom";

//    settings.Add("split-keys-8", false, "Split on Level 8 Keys");
//    settings.SetToolTip("split-keys-8", "Always split on collection of Level 8 keys");
//    vars.trackKeys = false;

    settings.Add("split-level", false, "Split on New Level");
    settings.SetToolTip("split-level", "Always split on your first visit to a new level");

    settings.Add("split-warp", false, "Split on All Warps");
    settings.SetToolTip("split-warp", "Always split on warps within maps, this includes duplicate warps");
    vars.splitAllWarps = false;

    settings.Add("split-boss", false, "Split on Boss Entrances");
    settings.SetToolTip("split-boss", "Always split on boss entrances");
    settings.CurrentDefaultParent = null;
    settings.Add("split-longhunter", false, "Longhunter", "split-boss");
    settings.Add("split-mantis", false, "Mantis", "split-boss");
    settings.Add("split-thunder", false, "Thunder", "split-boss");
    settings.Add("split-campaigner", false, "Campaigner", "split-boss");

    // Storage for desired map and warp splits
    vars.mapSplits = new Dictionary<string, Dictionary<string, List<int>>>(); // mapSplits[from][to][visitCount]
    vars.mapsVisited = new Dictionary<string, Dictionary<string, int>>(); // mapsVisited[from][to]visitCount
    vars.warpSplits = new Dictionary<int, List<int>>(); // warpSplits[warpId][visitCount]
    vars.warpsVisited = new Dictionary<int, int>(); // warpsVisited[warpId]visitCount

    // Track a specific iteration of a specific map-to-map transition
    vars.trackMap = (Action<string, string, int>)((from, to, visit) =>
    {
        if (!vars.mapSplits.ContainsKey(from)) vars.mapSplits[from] = new Dictionary<string, List<int>>();
        if (!vars.mapSplits[from].ContainsKey(to)) vars.mapSplits[from][to] = new List<int>();
        vars.mapSplits[from][to].Add(visit);
    });

    // Track a specific iteration of a specific warpId
    vars.trackWarp = (Action<int, int>)((warpId, visit) => 
    {
        if (!vars.warpSplits.ContainsKey(warpId)) vars.warpSplits[warpId] = new List<int>();
        vars.warpSplits[warpId].Add(visit);
    });

    // Track the first iteration of a list of warpIds
    vars.trackFirstWarps = (Action<int[]>)((warpIds) => 
    {
        foreach (var warpId in warpIds) vars.trackWarp(warpId, 1);
    });

    // Return true if the current map transition is in vars.mapSplits
    vars.isMapSplit = (Func<string, string, bool>)((from, to) =>
    {
        if (from == to) return false; // Our map hasn't changed

        // Track visit count to maps to prevent splitting on re-entry
        if (!vars.mapsVisited.ContainsKey(from)) vars.mapsVisited[from] = new Dictionary<string, int>();
        int visitCount = 0;
        vars.mapsVisited[from].TryGetValue(to, out visitCount);
        vars.mapsVisited[from][to] = ++visitCount;

        return vars.mapSplits.ContainsKey(from) &&
               vars.mapSplits[from].ContainsKey(to) &&
               vars.mapSplits[from][to].Contains(visitCount);
    });

    // Return true if the current Warp ID is in vars.warpSplits
    vars.isWarpSplit = (Func<int, int, bool>)((warpId, keysRemaining) => 
    {
        // Edge case: always ignore the portal after double jump in treetop village unless we've picked up the key
        if (warpId == 15004 && keysRemaining != 1) return false;

        // Track visit count
        int visitCount = 0;
        vars.warpsVisited.TryGetValue(warpId, out visitCount);
        vars.warpsVisited[warpId] = ++visitCount;

        return vars.warpSplits.ContainsKey(warpId) && 
               vars.warpSplits[warpId].Contains(visitCount);
    });
}

start 
{
    vars.mapSplits.Clear();
    vars.mapsVisited.Clear();
    vars.warpSplits.Clear();
    vars.warpsVisited.Clear();

    // We used to use number of splits to determine the route being run but I think 
    // using the route name in time.Run.CategoryName is much more sustainable. It 
    // avoids conflicts if two major routes ever end up having the same number of splits, 
    // and makes troubleshooting a bit more human friendly.
    // The old code is left commented out below just in case it's ever necessary again.

    /*
    // Get number of splits to try and identify route
    int splitCount = timer.Run.Count();
    vars.debug("splitCount: " + splitCount);
    */

    // Custom Splits
    if (settings["custom"])
    {
        vars.debug("Using Custom Route settings");

        // Split on all warps
        if (settings["split-warp"]) vars.splitAllWarps = true;

        // Split on Level 8 Keys
//        if (settings["split-keys-8"]) vars.trackKeys = true;

        // Split on the first visit to each level
        if (settings["split-level"]) 
        {
            vars.trackFirstWarps(new[] 
            {
                11000, 12000, 13000, 14000, 15000, 17000, 18000, // Hub->Level Warp IDs
            });
        }
    
        // Split on boss entrances
        if (settings["split-longhunter"]) vars.trackWarp(12998, 1);
        if (settings["split-mantis"]) vars.trackWarp(14999, 1);
        if (settings["split-thunder"]) vars.trackWarp(18997, 1);
        if (settings["split-campaigner"]) vars.trackWarp(18999, 1);
    }

    // Randomizer Route
    else if (timer.Run.CategoryName.ToLower().Contains("randomizer"))
    {
        // Test on seed 49761. A full run with cheats is <5 minutes.
        vars.debug("Randomizer Route detected");

//        vars.trackKeys = true;
        vars.splitAllWarps = false;
        vars.trackFirstWarps(new[] 
        {
            18000, // Enter FC
            18644, 18645, 18648, // FC Portals 1, 2, 3
            18997, // Enter Thunder
            18998, // Exit Thunder
            18999, // Enter Campaigner
        });
    }

    // Any% Route
    else if (timer.Run.CategoryName.ToLower().Contains("any%"))
    {
        vars.splitAllWarps = false;

        if (timer.Run.CategoryName.ToLower().Contains("beginner")) // Beginner Route
        {
            vars.debug("Any% Beginner Route detected");
            vars.trackFirstWarps(new[] 
            {
                10201, 10207, 10203, 10205, 10206, 10208, 10209, 10210, 10211, // Hub Ruins
                12000, 12041, 12768, 12766, 12045, 12998, // Ancient City, Longhunter
                11000, 11126, // Jungle
                13000, 13731, 13734, 13735, 13313, 13450, // Ruins
                14000, 14567, 14569, 14999, // Catacombs, Mantis
                15000, 15436, 15006, 15004, // Treetop Village
                17000, 17301, 17304, 17900, 17634, 17501, // Lost Land 
                18000, 18644, 18645, 18648, // Final Confrontation
                18997, 18999, // Thunder and Campaigner
            });
            vars.trackWarp(12041, 2); // 2nd roof warp in Ancient City
        }
        else // Current Route
        {   
            vars.debug("Any% Route detected");
            vars.trackFirstWarps(new[] 
            {
                10203, 10205, 10206, 10208, 10209, 10210, 10211, // Hub Ruins
                12000, 12041, 12768, 12766, 12045, 12998, // Ancient City, Longhunter
                11000, 11126, // Jungle
                13000, 13731, 13734, 13735, 13313, 13450, // Ruins
                14000, 14999, // Catacombs, Mantis
                15000, 15436, 15006, 15004, // Treetop Village
                17000, 17301, 17304, 17900, 17634, 17501, // Lost Land 
                18000, 18644, 18645, 18648, // Final Confrontation
                18997, 18999, // Thunder and Campaigner
            });
            vars.trackWarp(12041, 2); // 2nd roof warp in Ancient City
        }
    }

    // Unknown route
    else 
    {
        vars.debug("Custom Splits not enabled and route not recognized. Only splitting on Campaigner death.");
    }

    // Start a run on the transition between title screen and Hub Ruins start.
    // This works in the randomizer because it loads Hub Ruins prior to warping you
    // to your random starting location
    return old.level == "title" && current.level == "the hub";
}

split 
{
    // Are we splitting on all warps or is this Warp ID being tracked?
    bool isWarpSplit = vars.splitAllWarps ? old.warpId == -1 && current.warpId != -1 :
                        old.warpId == -1 && current.warpId != -1 && vars.isWarpSplit(current.warpId, current.levelKeysRemaining); 

    // Did we find a Level 8 Key?
//    bool isKeySplit = vars.trackKeys && (current.level8Keys > old.level8Keys);

    // Is this our first time visiting a new level?
    bool isLevelSplit = settings["split-level"] && vars.isWarpSplit(current.warpId, current.levelKeysRemaining);

    // Always split when we kill the Campaigner, regardless of route
    bool isFinalSplit = (old.currentBossHealth > 0 && current.currentBossHealth <= 0) && current.map == "levels/level00.map"; 

    // Split if any of the checks are true
//    bool doSplit = (isWarpSplit || isKeySplit || isLevelSplit || isFinalSplit );
    bool doSplit = (isWarpSplit || isLevelSplit || isFinalSplit );
    if (doSplit)
    {
        vars.debug("Split Detected." +
                        " Warp:" + isWarpSplit + 
//                        " Key:" + isKeySplit +
                        " Level:" + isLevelSplit + 
                        " Final:" + isFinalSplit);
    }

    return doSplit;
}

reset 
{
    // Reset on the Titlescreen
    bool doReset = settings["reset-title"] && old.level != "title" && current.level == "title";
    if (doReset) vars.debug("Resetting");
    return doReset;
}
