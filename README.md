# eotl_cannounce

This is a fork of the [cannounce](https://forums.alliedmods.net/showthread.php?t=77306) 1.9 sourcemod plugin written by Arg!, that contains changes I made for [EOTL](https://www.endofthelinegaming.com/) community.

## eotl specific changes

  * Only play connect sound if player has been connected less then cvar sm_ca_timenosound seconds (default: 60).  Fixes issue where connect sounds would play when changing maps.
  * Fix bug that can cause the join message to not happen when the server is full
  * Allow players to have custom disconnect reasons.  This is done via a new "discoReason" directive in the config file that each player can have.  Multiple disconnect reasons are supported via "reason1;reason2;reason3" etc, up to 10 are supported with max total length of 511 bytes and max per reason length of 63 bytes.  If multiple are provided, one will be picked at random.  Example:

  ```
  "CustomJoinMessages"
{
	"STEAM_0:0:00000000"
	{
		"playerwasnamed"		"someplayer"
		"discoReason"		"Rage Quit;somplayer out;BANNED BY ADMIN"
		"soundFile"		"eotl/someplayer1.mp3"
	}
```
  * Override a client's custom sound and play the server wide sm_ca_playsoundfile (if enabled) **ONLY** to that client under the following conditions
    * connecting client is not in the config or has no custom connect sound
    * the start of a new map
    * because sm_ca_timenosound prevented it

    The effect of this is at server start up or start of new map, clients will individually hear the server wide connect sound when they connect.  If a player joins during the middle of a map their customer connect sound (if they have one) will be played to all clients.