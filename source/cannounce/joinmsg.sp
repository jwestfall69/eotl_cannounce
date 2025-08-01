
#define MSGLENGTH 		151
#define SOUNDFILE_PATH_LEN 		256
#define CHECKFLAG 		ADMFLAG_ROOT


/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
new Handle:hKVCustomJoinMessages = INVALID_HANDLE;

new Handle:g_CvarPlaySound = INVALID_HANDLE;
new Handle:g_CvarPlaySoundFile = INVALID_HANDLE;

new Handle:g_CvarPlayDiscSound = INVALID_HANDLE;
new Handle:g_CvarPlayDiscSoundFile = INVALID_HANDLE;

new Handle:g_CvarMapStartNoSound = INVALID_HANDLE;
new Handle:g_CvarTimeNoSound = INVALID_HANDLE;

new bool:noSoundPeriod = false;

/*****************************************************************


			L I B R A R Y   I N C L U D E S


*****************************************************************/
#include "joinmsg/allow.sp"
#include "joinmsg/disallow.sp"
#include "joinmsg/set.sp"
#include "joinmsg/sound.sp"


/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

SetupJoinMsg()
{
	noSoundPeriod = false;

	//cvars
	g_CvarPlaySound = CreateConVar("sm_ca_playsound", "0", "Plays a specified (sm_ca_playsoundfile) sound on player connect");
	g_CvarPlaySoundFile = CreateConVar("sm_ca_playsoundfile", "ambient\\alarms\\klaxon1.wav", "Sound to play on player connect if sm_ca_playsound = 1");

	g_CvarPlayDiscSound = CreateConVar("sm_ca_playdiscsound", "0", "Plays a specified (sm_ca_playdiscsoundfile) sound on player discconnect");
	g_CvarPlayDiscSoundFile = CreateConVar("sm_ca_playdiscsoundfile", "weapons\\cguard\\charging.wav", "Sound to play on player discconnect if sm_ca_playdiscsound = 1");

	g_CvarMapStartNoSound = CreateConVar("sm_ca_mapstartnosound", "30.0", "Time to ignore all player join sounds on a map load");
	g_CvarTimeNoSound = CreateConVar("sm_ca_timenosound", "60.0", "If a player has been connected more then this many seconds dont play connect sound");

	//prepare kv custom messages file
	hKVCustomJoinMessages = CreateKeyValues("CustomJoinMessages");

	if(!FileToKeyValues(hKVCustomJoinMessages, g_fileset))
	{
		KeyValuesToFile(hKVCustomJoinMessages, g_fileset);
	}

	SetupJoinMsg_Allow();

	SetupJoinMsg_DisAllow();

	SetupJoinMsg_Set();

	SetupJoinSound_Set();
}


OnAdminMenuReady_JoinMsg()
{
	//Build the "Player Commands" category
	new TopMenuObject:player_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		OnAdminMenuReady_JoinMsg_Allow(player_commands);

		OnAdminMenuReady_JoinMsg_DAllow(player_commands);
	}
}


OnMapStart_JoinMsg()
{
	decl Float:waitPeriod;

	noSoundPeriod = false;

	waitPeriod = GetConVarFloat(g_CvarMapStartNoSound);

	if( waitPeriod > 0 )
	{
		noSoundPeriod = true;
		CreateTimer(waitPeriod, Timer_MapStartNoSound);
	}
}

OnPostAdminCheck_JoinMsg(const client, const String:steamId[])
{
	new String:message[MSGLENGTH + 1];
	new String:output[301];
	new String:soundFilePath[SOUNDFILE_PATH_LEN];

	new Float:timeNoSound = GetConVarFloat(g_CvarTimeNoSound);
	new Float:clientTime = GetClientTime(client);

	LogMessage("OnPostAdminCheck_JoinMsg(%d, %s) called", client, steamId);

	//get from kv file
	KvRewind(hKVCustomJoinMessages);
	if(KvJumpToKey(hKVCustomJoinMessages, steamId))
	{
		//Custom join MESSAGE
		KvGetString(hKVCustomJoinMessages, "message", message, sizeof(message), "");

		if( strlen(message) > 0)
		{
			//print output
			Format(output, sizeof(output), "%c\"%c%s%c\"", 4, 1, message, 4);

			PrintFormattedMessageToAll(output, -1);
		}

		//Custom join SOUND
		KvGetString(hKVCustomJoinMessages, "soundfile", soundFilePath, sizeof(soundFilePath), "");

		if( strlen(soundFilePath) == 0)
		{
			LogMessage("%N (%s) in config file, but no soundfile configured", client, steamId);
			ClientPlayDefaultConnectSound(client);
			return;
		}

		if(noSoundPeriod)
		{
			LogMessage("Not playing connect sound for %N, because start of map", client, clientTime);
			ClientPlayDefaultConnectSound(client);
			return;
		}

		if(clientTime > timeNoSound)
		{
			LogMessage("Not playing connect sound for %N, because they have been connected %f seconds", client, clientTime);
			ClientPlayDefaultConnectSound(client);
			return;
		}

		LogMessage("playing connect sound %s for %N (%f connect time)", soundFilePath, client, clientTime);
		EmitSoundToAll( soundFilePath );
	}
	else
	{
		LogMessage("%N (%s) not found in config file", client, steamId);
		ClientPlayDefaultConnectSound(client);
    }
}

ClientPlayDefaultConnectSound(client)
{
	decl String:soundfile[SOUNDFILE_PATH_LEN];

	if(!GetConVarInt(g_CvarPlaySound))
	{
		return;
	}

	GetConVarString(g_CvarPlaySoundFile, soundfile, sizeof(soundfile));

	if(strlen(soundfile))
	{
			LogMessage("playing default connect sound %s for %N only", soundfile, client);
			EmitSoundToClient( client, soundfile );
	}
}

OnClientDisconnect_JoinMsg()
{
	decl String:soundfile[SOUNDFILE_PATH_LEN];

	if( GetConVarInt(g_CvarPlayDiscSound))
	{
		GetConVarString(g_CvarPlayDiscSoundFile, soundfile, sizeof(soundfile));

		if( strlen(soundfile) > 0)
		{
			EmitSoundToAll( soundfile );
		}
	}
}


OnPluginEnd_JoinMsg()
{
	CloseHandle(hKVCustomJoinMessages);
}


public Action:Timer_MapStartNoSound(Handle:timer)
{
	noSoundPeriod = false;

	return Plugin_Handled;
}


/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
LoadSoundFilesAll()
{
	new String:c_soundFile[SOUNDFILE_PATH_LEN];
	new String:c_soundFileFullPath[SOUNDFILE_PATH_LEN + 6];

	new String:dc_soundFile[SOUNDFILE_PATH_LEN];
	new String:dc_soundFileFullPath[SOUNDFILE_PATH_LEN + 6];

	//download and cache connect sound
	if( GetConVarInt(g_CvarPlaySound))
	{
		GetConVarString(g_CvarPlaySoundFile, c_soundFile, sizeof(c_soundFile));
		Format(c_soundFileFullPath, sizeof(c_soundFileFullPath), "sound/%s", c_soundFile);

		if( FileExists( c_soundFileFullPath ) )
		{
			AddFileToDownloadsTable(c_soundFileFullPath);

			PrecacheSound( c_soundFile );
		}
	}

	//cache disconnect sound
	if( GetConVarInt(g_CvarPlayDiscSound))
	{
		GetConVarString(g_CvarPlayDiscSoundFile, dc_soundFile, sizeof(dc_soundFile));
		Format(dc_soundFileFullPath, sizeof(dc_soundFileFullPath), "sound/%s", dc_soundFile);

		if( FileExists( dc_soundFileFullPath ) )
		{
			AddFileToDownloadsTable(dc_soundFileFullPath);

			PrecacheSound( dc_soundFile );
		}
	}
}