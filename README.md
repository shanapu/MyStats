MyStats

```
// Counting kills/hits/times... against bots
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
mystats_count_bots "1"

// Minium number of connected players until counting stats for logging is enabled
// -
// Default: "0"
// Minimum: "0.000000"
mystats_min_player "0"

// Unique server name - when blank IP:port will be used
// -
// Default: ""
mystats_server_name ""
```

databases.cfg
```
	"MyStats"
	{
		"driver"			"mysql"
		"host"				""
		"database"			""
		"user"				""
		"pass"				""
	}
```

database table structure:

mystats_player
```
		accountid
		name
		steamid
		steamid64
		ip
		flags
		clanid
		firstjoin
		lastjoin
		firstserver
		lastserver
		country
		language
		os
```

mystats_sessions
```
		sid
		accountid
		date
		server
		name
		ip
		flags
		clanid
		map
		players
		score
		kills
		death
		motd
		duration
```
mystats_times
```
		accountid
		server
		aliveCT
		aliveT
		deadCT
		deadT
		spec
		idle
		duration
```
mystats_objectives
```
		accountid
		server
		score
		killCT
		killT
		deathCT
		deathT
		assistCT
		assistT
		headshotCT
		headshotT
		suicideCT
		suicideT
		teamkillCT
		teamkillT
		damageCT
		damageT
		damagedCT
		damagedT
		plant
		defuse
		fakeplant
		fakedefuse
		explode
		rescued
		vip_kill
		vip_escape
		vip_play
		mvpCT
		mvpT
		roundCT
		roundT
		winCT
		winT
		oneHPct
		oneHPt
```
mystats_weapons
```
		accountid
		server
		weapon
		killCT
		killT
		shotCT
		shotT
		hitCT
		hitT
		damageCT
		damageT
		headshotCT
		headshotT
		noscopeCT
		noscopeT
		boughtCT
		boughtT
```
mystats_hits
```
		accountid
		server
		weapon
		headCT
		headT
		chestCT
		chestT
		stomachCT
		stomachT
		left_armCT
		left_armT
		right_armCT
		right_armT
		left_legCT
		left_legT
		right_legCT
		right_legT
```
