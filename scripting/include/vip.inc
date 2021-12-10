#if defined _vip_included
    #endinput
#endif

#define _vip_included

enum _:(<<= 1)
{
	VIP_LEVEL_A = 1,
	VIP_LEVEL_B,
	VIP_LEVEL_C,
	VIP_LEVEL_D,
	VIP_LEVEL_E,
	VIP_LEVEL_F,
	VIP_LEVEL_G,
	VIP_LEVEL_H,
	VIP_LEVEL_I,
	VIP_LEVEL_J,
	VIP_LEVEL_K,
	VIP_LEVEL_L,
	VIP_LEVEL_M,
	VIP_LEVEL_N,
	VIP_LEVEL_O,
	VIP_LEVEL_P,
	VIP_LEVEL_Q,
	VIP_LEVEL_R,
	VIP_LEVEL_S,
	VIP_LEVEL_T,
	VIP_LEVEL_U,
	VIP_LEVEL_V,
	VIP_LEVEL_W,
	VIP_LEVEL_X,
	VIP_LEVEL_Y,
	VIP_USER
}

/**
 * Returns the chat prefix set in the plugin's configuration file.
 *
 * @param szBuffer	 	Buffer to store the prefix in.
 * @param iLen 			Maximum buffer length.
 * @noreturn
 */
 
native get_vip_prefix( szBuffer[ ], iLen )
 
/**
 * Set in the plugin's configuration file.
 *
 * @param szID		 	Client name or authid
 * @param szPassword 		Client password
 * @param szFlags 		Client Flags
 * @param szExpireDate  	Client Expire Date
 * @noreturn
 */
 
native add_user_vip( const szID[ ], const szPassword[ ], const szFlags[ ], const szExpireDate[ ] )

/**
 * Checks if the client is VIP according to the VIP flags set in the plugin's configuration file or in subplugin's.
 *
 * @param id			Client index.
 * @return			True if he is, false otherwise.
 */
 
native bool:crxranks_is_user_vip( id )

/**
 * Checks if the client is VIP according to the VIP flags set in the plugin's configuration file or in subplugin's.
 *
 * @param id			Client index.
 * @return			True if he is, false otherwise.
 */
 
native bool:is_user_vip( id )


/**
 * Returns the client is VIP according to the VIP flags.
 *
 * @param id		 	Client index.
 * @return			Client VIP.
 * @ex: 			get_user_vip( id ) & VIP_LEVEL_A 
 */
native get_user_vip( id )

/**
 * Set the client as VIP.
 *
 * @param id		 	Client index.
 * @param szFlags		Client Flags.
 * @return			Client VIP.
 */
native set_user_vip( id, szFlags )

/**
 * Remove the client from VIP flags.
 *
 * @param id		 	Client index.
 * @param szFlags		Client Flags select one flags to get remove
 * @noreturn		
 */
native remove_user_vip( id, szFlags = -1 )
