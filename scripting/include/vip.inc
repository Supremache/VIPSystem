#if defined _vip_included
    #endinput
#endif

#define _vip_included

#if !defined _vip_const_included
    #include <vip_const>
#endif

const VIP_ALL = 0;

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
 * Returns the expiration date format.
 *
 * @param szBuffer	 	Buffer to store he expiration date format in.
 * @param iLen 			Maximum buffer length.
 * @noreturn
 */
 
native get_expire_type( szBuffer[ ], iLen )
 

 /**
 * Returns the vip expire date set in the plugin's configuration file.
 *
 * @param id			Client index.
 * @param szBuffer	 	Buffer to store the prefix in.
 * @param iLen 			Maximum buffer length.
 * @noreturn
 */

native get_expire_date( id, szBuffer[ ], iLen )

/**
 * Set in the plugin's configuration file.
 *
 * @param szID		 	Client name or authid or ip
 * @param szPassword 		Client password
 * @param szFlags 		Client Flags
 * @param szExpireDate  	Client Expire Date
 * @noreturn
 */
 
native add_user_vip( const szID[ ], const szPassword[ ], const szFlags[ ], iExpireDate )

/**
 * Checks if the client is VIP according to the VIP flags set in the plugin's configuration file or in subplugin's.
 *
 * @param id			Client index.
 * @return			True if he is, false otherwise.
 */
 
native bool:is_user_vip( id )

/**
 * Checks if the free vip time is active.
 *
 * @param id			Client index.
 * @return			True if free vip active, false otherwise.
 */
 
native bool:is_free_vip_time( )

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

/**
 * Returns if the client has any of the specified vip flags.
 *
 * @param id      Client index
 * @param flags   Flag string
 *
 * @return        1 if the user has any of the specified flags, 0 otherwise
 */
 
stock has_vip_flag( id, const szFlags[ ] )
{
	return( get_user_vip( id ) & read_flags( szFlags ) );
}

/**
 * Returns if the client has all of the specified vip flags.
 *
 * @param id      Client index
 * @param flags   Flag string
 *
 * @return        1 if the user has all of the specified flags, 0 otherwise
 */
 
stock has_all_vip_flags( id, const szFlags[ ] )
{
	new _Flags = read_flags( szFlags );
	return( ( get_user_vip( id ) & _Flags ) == _Flags );
}

/**
 * Reloads the configuration file.
 *
 * @noreturn
 */

native  reload_vip(  );

/**
 * It is called right when event enabled.
 *
 * @param  id     		Client index.
 * @param  iStart 		Start time.
 * @param iEnd 		End time.
 * @param iEventFlags	EventFlags.
 * @param bEvent  	True if the event started, false otherwise.
 * @noreturn
 */

forward VIPEvent( id, iStart, iEnd, iEventFlags, bool:bEvent )

/**
 * It is called right after the user is added as vips using the console command or the native.
 *
 * @param szID		 	Client name or authid or ip
 * @param szPassword 		Client password
 * @param szFlags 		Client Flags
 * @param szExpireDate  	Client Expire Date
 * @noreturn
 */

forward VIPAdded( const szID[ ], const szPassword[ ], const szFlags[ ], const szExpireDate[ ] )
