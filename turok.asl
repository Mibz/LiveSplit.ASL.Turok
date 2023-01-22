// Auto-start, reset, and split upon entering each level (and optionally each boss)
// Supports Steam version, patches 1.4.3, 1.4.6 and 2.0. 

// Last patch with jeep backstab (2015-12-18 release)
// inside "TDH 1.1.7z" on speedrun.com or steam (steam://nav/console):
//   download_depot 405820 405822 305215209689250894 (Windows Files)
//   download_depot 405820 405821 7171797334604885018 (Game Files)
state("sobek", "1.4.3")
{
    string40 level: 0x27D764, 0x0, 0x0;
    string40 map: 0x27D740, 0x0;
    int health: 0x27DA3C, 0xE0;
    int level8BossHealth: 0x27DBD4, 0xE0;
    int warpId: 0x27DF64; // -1 before/after warp, ID during warp
    int levelKeysRemaining: 0x27D764, 0x40;
    // 0x27D74C, (0x40)+(levelID*0x60) = int Keys remaining for levelID  (0x38E408, 0xC8 for v2.0 lvl 1)
    // 0x27DA3C, 0x10 = position vector (float x, y, z)
    // 0x27DA60 / 0x27DA64 = last checkpoint (int id / int map)
}

// download_depot 405820 405822 8016018477641840845
// download_depot 405820 405821 5590148811806510379
state("sobek", "1.4.6") 
{
    string40 level: 0x286E7C, 0x0, 0x0;
    string40 map: 0x286E58, 0x0;
    int health: 0x287154, 0xE0;
    int level8BossHealth: 0x2872F0, 0xE0;
    int warpId: 0x287684;
    int levelKeysRemaining: 0x286E7C, 0x40;
}

// current patch (2018-07-28 release)
state("sobek", "2.0")
{
    string40 level: 0x3AE25C, 0x0;
    string40 map: 0x38E3FC, 0x0;
    int health: 0x390CF4, 0xE0;
    int level8BossHealth: 0x393118, 0xE0;
    int warpId: 0x49ED0, 0x0; 
    int levelKeysRemaining: 0x38E428, 0x50; 
    byte level8Keys: 0x38E408, 0x414;
}

init
{
    // Call this action to print debug messages, e.g. vars.debug("Split on warpId: " + warpId)
    vars.debug = (Action<string>)((msg) => print("[Turok ASL] " + msg));

    // The version is found by checking how much memory the process reserves against known values
    int memSize = modules.First().ModuleMemorySize;
    vars.debug("memSize: " + memSize);
    if (memSize == 0x2E8000) version = "1.4.3";
    else if (memSize == 0x2F4000) version = "1.4.6";
    else if (memSize == 0x443000) version = "2.0";
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
    // `vars.variableName` is declared for a setting to we can modify settings based on known routes

    settings.Add("reset-title", true, "Reset on Titlescreen");
    settings.SetToolTip("reset-title", "Reset the run any time you enter the title screen. Disable this if you want the ability to continue from a save after a Game Over. Check the rules This setting has no impact on zombie-mode.");

    // This parent is so people don't think they need to mess with settings to get known routes to work
    settings.Add("custom", false, "Custom Routes"); 
    settings.SetToolTip("custom", "Adjust settings for a custom route. These will have no effect on recognized routes");
    settings.CurrentDefaultParent = "custom";

    settings.Add("split-keys-8", false, "Split on Level 8 Keys");
    settings.SetToolTip("split-keys-8", "Always split on collection of Level 8 keys");
    vars.trackKeys = false;

    settings.Add("split-level", false, "Split on New Level");
    settings.SetToolTip("split-level", "Always split on your first visit to a new level");
    vars.splitAllLevels = false;

    settings.Add("split-map", false, "Split on Map Transition");
    settings.SetToolTip("split-map", "Always split any time the map changes");
    vars.splitAllMaps = false;

    settings.Add("split-warps", false, "Split Teleporters");
    settings.SetToolTip("split-warps", "Always split on warps within maps");
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

    // Get number of splits to try and identify route
    int splitCount = timer.Run.Count();
    vars.debug("splitCount: " + splitCount);

    // Randomizer Route
    if (timer.Run.CategoryName.ToLower().Contains("randomizer"))
    {
        // Test on seed 49761. A full run with cheats is <5 minutes.
        vars.debug("Randomizer Route detected");

        vars.trackKeys = true;
        vars.trackFirstWarps(new[] 
        {
            18000, // Enter FC
            18644, 18645, 18648, // FC Portals
            18997, // Enter Thunder
            18998, // Exit Thunder
            18999, // Enter Campaigner
        });
    }

    // Any% Route
    else if (timer.Run.CategoryName.ToLower().Contains("any%"))
    {
        if (splitCount == 43) // Beginner Route
        {
            vars.debug("Any% Beginner Route detected");
            vars.trackFirstWarps(new[] 
            {
                10201, 10207, 10203, 10205, 10206, 10208, 10209, 10210, 10211, // Hub Ruins
                12041, 12768, 12766, 12045, // Ancient City
                11126, // Jungle
                13731, 13734, 13735, 13313, 13450, // Ruins
                14567, 14569, // Catacombs
                15436, 15006, 15004, // Treetop Village
                17301, 17304, 17900, 17634, 17501, // Lost Land 
                18644, 18645, 18648 // Final Confrontation
            });
            // Extras (2nd roof warp in lvl 3)
            vars.trackWarp(12041, 2);
        }
        else // Current Route
        {   
            vars.debug("Any% Route detected");
            vars.trackFirstWarps(new[] 
            {
                10201, 10207, 10203, 10205, 10206, 10208, 10209, 10210, 10211, // Hub Ruins
                12041, 12768, 12766, 12045, // Ancient City
                11126, // Jungle
                13731, 13734, 13735, 13313, 13450, // Ruins
                14567, 14569, // Catacombs
                15436, 15006, 15004, // Treetop Village
                17301, 17304, 17900, 17634, 17501, // Lost Land 
                18644, 18645, 18648 // Final Confrontation
            });
            // Extras (2nd roof warp in lvl 3)
            vars.trackWarp(12041, 2);
        }
    }

    // Unknown route
    else 
    {
        vars.debug("Unknown route, splitting based on Custom Route settings");

        // Split on Level 8 Keys
        if (settings["split-keys-8"]) vars.trackKeys = true;

        // Split on each Hub->Level warp ID
        if (settings["split-level"]) 
        {
            vars.trackFirstWarps(new[] 
            {
                11000, 12000, 13000, 14000, 15000, 17000, 18000,
            });
        }
    
        // Split on boss entrances
        if (settings["split-longhunter"]) vars.trackMap("levels/level09.map", "levels/level48.map", 1);
        if (settings["split-mantis"]) vars.trackMap("levels/level12.map", "levels/level49.map", 1);
        if (settings["split-thunder"]) vars.trackMap("levels/level24.map", "levels/level03.map", 1);
        if (settings["split-campaigner"]) vars.trackMap("levels/level25.map", "levels/level00.map", 1);

        // Split on all teleporters
        if (settings["split-warps"])
        {
            vars.trackFirstWarps(new[]
            {
                10201, 10207, 10203, 10205, 10206, 10208, 10209, 10210, 10211, // Hub Ruins
                12041, 12768, 12766, 12045, // Ancient City
                11126, // Jungle
                13731, 13734, 13735, 13313, 13450, // Ruins
                14567, 14569, // Catacombs
                15436, 15006, 15004, // Treetop Village
                17301, 17304, 17900, 17634, 17501, // Lost Land 
                18644, 18645, 18648 // Final Confrontation
            });
        }
    }

    // Start a run on the transition between title screen and Hub Ruins start.
    // This works in the randomizer because it loads Hub Ruins prior to warping you
    // to your random starting location
    return old.level == "title" && current.level == "the hub";
}

split 
{
    bool isMapSplit = vars.isMapSplit(old.map, current.map); // Did we change maps?
    bool isLevelSplit = settings["split-level"] && vars.isMapSplit(old.level, current.level); // Did we change levels?
    bool isWarpSplit = settings["split-warps"] && old.warpId == -1 && current.warpId != -1 &&
                       vars.isWarpSplit(current.warpId, current.levelKeysRemaining); // Did we take a teleporter?
    bool isFinalSplit = (old.level8BossHealth > 0 && current.level8BossHealth <= 0) &&
                        current.map == "levels/level00.map"; // Did we kill the Campaigner?
    bool isKeySplit = settings["split-keys-8"] && (current.level8Keys > old.level8Keys); // Did we find a Level 8 Key?

    // Split if any of the checks are true
    bool doSplit = (isLevelSplit || isMapSplit || isWarpSplit || isFinalSplit || isKeySplit);
    if (doSplit)
    {
        vars.debug("Split Detected. Level:" + isLevelSplit + " Map:" + isMapSplit + " Warp:" +
                                        isWarpSplit + " Final:" + isFinalSplit + " Key:" +
                                        isKeySplit);
    }

    return doSplit;
}

reset 
{
    // Reset on the Titlescreen unless disabled in settings
    bool doReset = settings["reset-title"] && old.level != "title" && current.level == "title";
    if (doReset) vars.debug("Resetting");
    return doReset;
}
