// Auto-start, reset, and split upon entering each level (and optionally each boss)
// Supports steam version, patches 1.4.3, 1.4.6 and 2.0. 

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
    int warpId: 0x49ED0; 
    int levelKeysRemaining: 0x38E428, 0x50; 
    byte level8Keys: 0x38E408, 0x414;
}

init
{
    // The version is found by checking how much memory the process reserves against known values
    int memSize = modules.First().ModuleMemorySize;
    print("Detected memSize: " + memSize);
    if (memSize == 0x2E8000) version = "1.4.3";
    else if (memSize == 0x2F4000) version = "1.4.6";
    else if (memSize == 0x443000) version = "2.0";
    else 
    {
        version = "2.0";
        print("Couldn't detect version, defaulting to 2.0");
    }
}

startup 
{
    // Settings
    settings.Add("split-keys", false, "Split on Keys");
    settings.Add("split-keys-8", false, "Split on Level 8 keys", "split-keys");

    settings.Add("split-level", true, "Split on New Level");

    settings.Add("split-boss", true, "Split Boss Entrances");
    settings.Add("split-longhunter", true, "Longhunter", "split-boss");
    settings.Add("split-mantis", true, "Mantis", "split-boss");
    settings.Add("split-thunder", true, "Thunder", "split-boss");
    settings.Add("split-campaigner", true, "Campaigner", "split-boss");

    settings.Add("subsplits", true, "Warp Subsplits");
    settings.Add("split-warps", true, "Split Blue Planes (Any% Routes)", "subsplits");
    settings.SetToolTip("split-warps", "Split Blue Planes for the Any% routes");

    settings.Add("misc", true, "Misc");
    settings.Add("reset-title", true, "Reset on Titlescreen", "misc");
    settings.SetToolTip("reset-title", "Disable this if you don't want the timer to reset if you game over");

    vars.mapSplits = new Dictionary<string, Dictionary<string, List<int>>>(); // mapSplits[from][to][visitCount]
    vars.mapsVisited = new Dictionary<string, Dictionary<string, int>>(); // mapsVisited[from][to]visitCount
    vars.warpSplits = new Dictionary<int, List<int>>(); // warpSplits[warpId][visitCount]
    vars.warpsVisited = new Dictionary<int, int>(); // warpsVisited[warpId]visitCount

    // Split on a specific iteration of a specific map-to-map transition
    vars.trackMap = (Action<string, string, int>)((from, to, visit) =>
    {
        if (!vars.mapSplits.ContainsKey(from)) vars.mapSplits[from] = new Dictionary<string, List<int>>();
        if (!vars.mapSplits[from].ContainsKey(to)) vars.mapSplits[from][to] = new List<int>();
        vars.mapSplits[from][to].Add(visit);
    });

    // Split on a specific iteration of a specific warpId
    vars.trackWarp = (Action<int, int>)((warpId, visit) => 
    {
        if (!vars.warpSplits.ContainsKey(warpId)) vars.warpSplits[warpId] = new List<int>();
        vars.warpSplits[warpId].Add(visit);
    });

    // Split on the first iteration of a list of warpIds
    vars.trackFirstWarps = (Action<int[]>)((warpIds) => 
    {
        foreach (var warpId in warpIds) vars.trackWarp(warpId, 1);
    });

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

    // Call this action to print debug messages, e.g. vars.debug("Split on warpId: " + warpId)
    vars.debug = (Action<string>)((msg) => print("[Turok ASL] " + msg));
}

start 
{
    vars.mapSplits.Clear();
    vars.mapsVisited.Clear();
    vars.warpSplits.Clear();
    vars.warpsVisited.Clear();
    
    // Get number of splits
    int splitCount = timer.Run.Count();
    vars.debug("splitCount: " + splitCount);

    // // Split on bosses
    // if (settings["split-boss"])
    // {
    //     vars.trackMap("levels/level09.map", "levels/level48.map", 1); // Longhunter
    //     vars.trackMap("levels/level12.map", "levels/level49.map", 1); // Mantis
    //     vars.trackMap("levels/level24.map", "levels/level03.map", 1); // Thunder
    //     vars.trackMap("levels/level25.map", "levels/level00.map", 1); // Campaigner
    // }
    
    // // Split when entering a new level for the first time
    // if (settings["split-level"])
    // {
    //     vars.trackMap("the hub", "the ancient city", 1);
    //     vars.trackMap("the hub", "the jungle", 1);
    //     vars.trackMap("the hub", "the ruins", 1);
    //     vars.trackMap("the hub", "the catacombs", 1);
    //     vars.trackMap("the hub", "the treetop village", 1);
    //     vars.trackMap("the hub", "the lost land", 1);
    //     vars.trackMap("the hub", "the final confrontation", 1);
    // }

    // Randomizer Route
    if (timer.Run.CategoryName.ToLower().Contains("randomizer"))
    {
        vars.debug("Randomizer Route detected");

        vars.trackMap("levels/level05.map", "levels/level21.map", 1); // Enter FC
        vars.trackMap("levels/level21.map", "levels/level22.map", 1); // FC Portal 1
        vars.trackMap("levels/level22.map", "levels/level23.map", 1); // FC Portal 2
        vars.trackMap("levels/level23.map", "levels/level24.map", 1); // FC Portal 3
        vars.trackMap("levels/level24.map", "levels/level03.map", 1); // Enter Thunder
        vars.trackMap("levels/level25.map", "levels/level00.map", 1); // Campaigner
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
    else // Unknown route
    {
        vars.debug("No known route found, splitting based on settings");

        // Split on bosses
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

    return old.level == "title" && current.level == "the hub";
}

split 
{
    // Check for a split
    bool isLevelSplit = settings["split-level"] && vars.isMapSplit(old.level, current.level); // Did we change levels?
    bool isMapSplit = vars.isMapSplit(old.map, current.map); // Did we change maps?
    bool isWarpSplit = settings["split-warps"] && 
                       old.warpId == -1 && current.warpId != -1 && 
                       vars.isWarpSplit(current.warpId, current.levelKeysRemaining); // Did we take a teleporter?
    bool isFinalSplit = (old.level8BossHealth > 0 && current.level8BossHealth <= 0) &&
                        current.map == "levels/level00.map"; // Did we kill the Campaigner?
    bool isKeySplit = settings["split-keys-8"] && (current.level8Keys > old.level8Keys); // Did we find a Level 8 Key?

    // Split if any of the checks are true
    bool doSplit = (isLevelSplit || isMapSplit || isWarpSplit || isFinalSplit || isKeySplit);

    // If we're splitting, send a debug message including results of all checks
    if (doSplit)
    {
        vars.debug("Split Detected: " + isLevelSplit + "," + isMapSplit + "," +
                                        isWarpSplit + "," + isFinalSplit + "," +
                                        isKeySplit);
    }

    return doSplit;
}

reset 
{
    // Reset if we're at the title screen when we weren't before
    bool doReset = settings["reset-title"] && old.level != "title" && current.level == "title";

    if (doReset)
    {
        vars.debug("Reset Detected");
    }
    
    return doReset;
}
