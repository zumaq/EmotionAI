 class EmotionAI extends AIInfo
 {
   function GetAuthor()        { return "Michal Zopp"; }
   function GetName()          { return "EmotionAI"; }
   function GetDescription()   { return "An AI which tries counter other players."; }
   function GetVersion()       { return 1; }
   function MinVersionToLoad() { return 1; }
   function GetDate()          { return "2018-03-15"; }
   function CreateInstance()   { return "EmotionAI"; }
   function GetShortName()     { return "EMTI"; }
   function GetAPIVersion()    { return "1.2"; }

   function GetSettings() {
	AddSetting({
		name = "use_trains",
		description = "Use trains",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});
	AddSetting({
		name = "use_roadvehs",
		description = "Use road vehicles",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});
	AddSetting({
		name = "use_aircraft",
		description = "Use aircraft",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});
	AddSetting({
		name = "max_transported",
		description = "Build new routes if transported percentage is smaller than this value",
		min_value = 1,
		max_value = 100,
		easy_value = 1,
		medium_value = 30,
		hard_value = 60,
		custom_value = 60,
		flags = CONFIG_INGAME
	});
	AddSetting({
		name = "subsidy_chance",
		description = "The chance of taking subsidies",
		min_value = 0,
		max_value = 10,
		easy_value = 2,
		medium_value = 5,
		hard_value = 8,
		custom_value = 5,
		flags = CONFIG_INGAME
	});
	AddSetting({
		name = "max_roadvehs",
		description = "The maximum number of road vehicles on a route",
		min_value = 5,
		max_value = 25,
		easy_value = 5,
		medium_value = 10,
		hard_value = 25,
		custom_value = 10,
		flags = 0
	});
	AddSetting({
		name = "waiting_time",
		description = "Days to wait between building two routes",
		min_value = 0,
		max_value = 365,
		easy_value = 60,
		medium_value = 30,
		hard_value = 0,
		custom_value = 0,
		step_size = 30,
		flags = CONFIG_INGAME
	});
	AddSetting({
		name = "slowdown",
		description = "Slowdown effect (how much the AI will become slower over time)",
		min_value = 0,
		max_value = 3,
		easy_value = 0,
		medium_value = 0,
		hard_value = 0,
		custom_value = 0,
		flags = CONFIG_INGAME
	});
	AddSetting({
		name = "hq_in_town",
		description = "Build company headquarters near towns",
		easy_value = 0,
		medium_value = 0,
		hard_value = 0,
		custom_value = 0,
		flags = CONFIG_BOOLEAN
	});
	AddSetting({
		name = "use_custom_companyname",
		description = "Use a custom company name",
		easy_value = 0,
		medium_value = 0,
		hard_value = 0,
		custom_value = 0,
		flags = CONFIG_BOOLEAN
	});
	AddSetting({
		name = "signaltype",
		description = "Signal type to be used",
		min_value = 0,
		max_value = 3,
		easy_value = 0,
		medium_value = 0,
		hard_value = 0,
		custom_value = 0,
		flags = CONFIG_INGAME
	});
	AddSetting({
		name = "newgrf_stations"
		description = "Use NewGRF rail stations if available"
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddLabels("slowdown", {
		_0 = "none",
		_1 = "little",
		_2 = "medium",
		_3 = "high"
	});
	AddLabels("signaltype", {
		_0 = "One-way block signals",
		_1 = "Two-way block signals",
		_2 = "Path signals",
		_3 = "Path signals, even at single rail stations"
	});
   }
 }

 RegisterAI(EmotionAI());
