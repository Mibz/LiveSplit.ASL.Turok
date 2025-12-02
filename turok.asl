// Turok: Remastered Auto-Splitter
// Supports Steam version, patches 1.4.3, 1.4.6, 1.4.7, 2.0, and 3.0
// For issues and support please join the Turok Speedrunning Discord at https://discord.gg/C8vczW2

// Game State Variables
/*
    string255 map
        The filename of the currently loaded map, eg "levels/level04.map"
        Used to track the start of a run, final split, and resetting on the title screen.
    int warpId
        The current Warp ID
        ID of the current in-progress warp
        IDs are directional so a round-trip between the same portals will have two unique IDs
        Warp ID is always -1 when not actively warping
    int levelKeysRemaining
        The number of keys remaining in the level
        Currently only used to protect against an edge-case where a player uses the portal after double jump in Treetop Village without grabbing the key first
    byte level8Keys
        Tracks which Level 8 keys have been collected
        Used in Randomizer runs (hence why it's only in 2.0+) to allow splitting whenever a Level 8 key is found, regardless of order
    byte inCinematic
        I'm not entirely sure whether this flag is for cinematics, but it seems to always be 0 during normal gameplay and 1 during cinematics
        Used to signal the final split after campaigner death since I can't figure out how to reliably track boss deaths
*/

// 1.4.3 (2015-12-19)
state("sobek_Shipping_Steam_x64", "1.4.3")
{
    string255 map: 0x27D740, 0x0;
    int warpId: 0x41FEC, 0x0;
    byte levelKeysRemaining: 0x27D764, 0x40;
    byte inCinematic: 0x55DCC, 0x0;
}

// 1.4.6 (2016-01-15)
state("sobek_Shipping_Steam_x64", "1.4.6") 
{
    string255 map: 0x286E58, 0x0;
    int warpId: 0x43BCC, 0x0;
    byte levelKeysRemaining: 0x286E7C, 0x40;
    byte inCinematic: 0x287E0, 0x0;
}

// 1.4.7 (2016-02-23)
state("sobek_Shipping_Steam_x64", "1.4.7") 
{
    string255 map: 0x25DEF0, 0x0;
    int warpId: 0x43C9C, 0x0;
    int levelKeysRemaining: 0x25DF14, 0x40;
    byte inCinematic: 0x286A0, 0x0;
}

// 2.0 (2018-07-28)
state("sobek_Shipping_Steam_x64", "2.0")
{
    string255 map: 0x38E3FC, 0x0;
    int warpId: 0x49ED0, 0x0; 
    int levelKeysRemaining: 0x38E428, 0x50; 
    byte inCinematic: 0x25EB4, 0x0;
    byte level8Keys: 0x38E408, 0x414;
}

// 3.0.1013 (2025-04-23)
state("sobek_Shipping_Steam_x64", "3.0.1013")
{
    string255 map: 0xAEDB90, 0x0;
    int warpId: 0xAC58E8, 0x900; 
    int levelKeysRemaining: 0xAEDBD8, 0x8C; 
    byte inCinematic: 0x7854D8;
}

// 3.2.1281 (2025-12-01)
state("sobek_Shipping_Steam_x64", "3.2.1281")
{
    string255 map: 0xDF04F0, 0x0;
    int warpId: 0xD27150; 
    int levelKeysRemaining: 0xDF0538, 0x8C; 
    byte inCinematic: 0xD267A8;
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
    checksums.Add("05-C5-46-39-3E-7E-14-06-97-6A-B9-FB-30-77-6E-F3-CB-31-0E-3C", "3.0.1013");
    checksums.Add("32-89-6D-BA-8B-22-AC-BF-8D-C9-BA-8B-3B-62-B5-E2-35-64-64-9B", "3.2.1281");

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
        version = "3.0.1013";
        vars.debug("Couldn't detect version, defaulting to latest release");
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

    settings.Add("split-warp", true, "Split on All Warps");
    settings.SetToolTip("split-warp", "Always split on warps within maps, this includes duplicate warps");

    settings.Add("split-level", false, "Split on New Level");
    settings.SetToolTip("split-level", "Always split on your first visit to a new level");

    settings.Add("split-boss", false, "Split on Boss Entrances");
    settings.SetToolTip("split-boss", "Always split on boss entrances");
    settings.Add("split-longhunter", false, "Longhunter", "split-boss");
    settings.Add("split-mantis", false, "Mantis", "split-boss");
    settings.Add("split-thunder", false, "Thunder", "split-boss");
    settings.Add("split-campaigner", false, "Campaigner", "split-boss");

//    settings.Add("split-keys-8", false, "Split on Level 8 Keys");
//    settings.SetToolTip("split-keys-8", "Always split on collection of Level 8 keys");
//    vars.trackKeys = false;

    // Storage for desired warp splits
    vars.warpSplits = new Dictionary<int, List<int>>(); // warpSplits[warpId][visitCount]
    vars.warpsVisited = new Dictionary<int, int>(); // warpsVisited[warpId]visitCount

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

    // Track final split
    vars.finalSplitDone = false;
}

start 
{
    vars.warpSplits.Clear();
    vars.warpsVisited.Clear();
    vars.finalSplitDone = false;
    vars.splittingOn = new List<string>();

    // Split on all warps
    if (settings["split-warp"]) vars.splittingOn.Add("All Warps");

    // Split on the first visit to each level
    if (settings["split-level"]) 
    {
        vars.trackFirstWarps(new[] 
        {
            11000, 12000, 13000, 14000, 15000, 17000, 18000, // Hub->Level Warp IDs
        });
        vars.splittingOn.Add("Levels");
    }

    // Split on boss entrances
    if (settings["split-longhunter"]) {
        vars.trackWarp(12998, 1);
        vars.splittingOn.Add("Longhunter");
    }
    if (settings["split-mantis"]) {
        vars.trackWarp(14999, 1);
        vars.splittingOn.Add("Mantis");
    }
    if (settings["split-thunder"]) {
        vars.trackWarp(18997, 1);
        vars.splittingOn.Add("Thunder");
    }
    if (settings["split-campaigner"]) {
        vars.trackWarp(18999, 1);
        vars.splittingOn.Add("Campaigner");
    }

    // Split on Level 8 Keys
    // Test randomizer on seed 49761. A full run with cheats is <5 minutes.
    // if (settings["split-keys-8"]) {
    //     vars.trackKeys = true;
    //     vars.splittingOn.Add("Level 8 Keys");
    // }

    // Uncomment to debug selected splits
    // if (vars.splittingOn.Count == 0)
    // {
    //     vars.debug("No splits selected, only splitting on Campaigner death.");
    // } else {
    //     vars.debug("Splitting on: " + String.Join(", ", vars.splittingOn));
    // }

    // Start a run on the transition between title screen and Hub Ruins cinematic
    // This still works in the randomizer
    return old.map == "levels/level42.map" && current.map == "levels/level05.map";
}

split 
{
    // Split on any warp
    // Ignore warp after TTV pillar jump near key unless key has been collected
    bool isWarpSplit = settings["split-warp"] && old.warpId == -1 && current.warpId > 0
                        && !(current.warpId == 15004 && current.levelKeysRemaining != 1);

    // Split on first warp to new level
    bool isLevelSplit = settings["split-level"] && vars.isWarpSplit(current.warpId, current.levelKeysRemaining);

    // Split on Level 8 key
//    bool isKeySplit = vars.trackKeys && (current.level8Keys > old.level8Keys);

    // Split on Campaigner death
    bool isFinalSplit = false;
    if (!vars.finalSplitDone)
    {
        isFinalSplit = current.map == "levels/level00.map" && current.inCinematic == 1;
        vars.finalSplitDone = isFinalSplit;
    }

    // Split if any of the checks are true
//    bool doSplit = (isWarpSplit || isKeySplit || isLevelSplit || isFinalSplit );
    bool doSplit = (isWarpSplit || isLevelSplit || isFinalSplit );
    if (doSplit)
    {
        vars.debug("Split Detected." +
                        " Warp:" + isWarpSplit + " " + current.warpId +
                        " Level:" + isLevelSplit + 
//                        " Key:" + isKeySplit +
                        " Final:" + isFinalSplit);
    }

    return doSplit;
}

reset 
{
    // Reset on the Titlescreen
    bool doReset = settings["reset-title"] && old.map != "levels/level42.map" && current.map == "levels/level42.map";
    if (doReset) vars.debug("Resetting");
    return doReset;
}
