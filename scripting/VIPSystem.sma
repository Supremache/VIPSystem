#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <cromchat>

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#if !defined MAX_PLAYERS
	const MAX_PLAYERS = 32
#endif

#if !defined MAX_NAME_LENGTH
	const MAX_NAME_LENGTH = 32
#endif

#if !defined MAX_AUTHID_LENGTH
	const MAX_AUTHID_LENGTH = 64
#endif

#if !defined MAX_IP_LENGTH
	const MAX_IP_LENGTH = 16
#endif

const MAX_FLAGS_LENGTH = 27

new const Version[ ] = "1.0.2";
new const g_iSettingsFile[ ] = "VIPSettings.ini"
new const g_iAccountFile[ ] = "VIPAccount.ini"

new const g_szNameField[ ] = "%name%"
new const g_szAuthIDField[ ] = "%authid%"
new const g_szFlagsField[ ] = "%flag%"
new const g_szExpireField[ ] = "%expiredate%"

enum _:PlayerAccount
{ 
	Player_Name[ MAX_NAME_LENGTH ],
	Player_Password[ 32 ],
	Player_AccessFlags[ MAX_FLAGS_LENGTH ],
	Player_Expire_Date[ MAX_FLAGS_LENGTH ],
	bool:Player_Suspended
}

enum _:eSettings
{ 
	Prefix_Chat[ 16 ],
	ConnectMessage[ 512 ],
	Free_VIP_TIME[ 2 ],
	Free_VIP_Flag,
	Access_AddVIP,
	Access_ScoreBoard,
	Access_ConnectMessage,
	Access_OnlineList,
	Float:Time_ReloadFile,
	Float:Time_ConnectMessage,
	bool:bFreeVIP
}

enum PlayerData 
{ 
	Name[ MAX_NAME_LENGTH ],
	AuthID[ MAX_AUTHID_LENGTH ],
	IP[ MAX_IP_LENGTH ],
	VIP
}

new Trie:g_tDatabase
new eData[ PlayerAccount ], g_iSettings[ eSettings ]
new g_iPlayer[ MAX_PLAYERS + 1 ][ PlayerData ]
new g_szConfigs[ 64 ], g_iFwNameChanged;
new bool:g_bFreeVipTime

public plugin_init( ) 
{
	register_plugin( "VIP System", Version, "Supremache" );
	register_cvar( "premuim_vip", Version, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED );
	
	g_tDatabase = TrieCreate( );
	
	get_configsdir( g_szConfigs, charsmax( g_szConfigs ) );
	
	RegisterHam( Ham_Spawn, "player", "CBasePlayer_Spawn", 1 );
	register_event("SayText", "OnSayTextNameChange", "a", "2=#Cstrike_Name_Change");
	
	ReadConfing( );
	ReloadFile( );
	
	set_task( g_iSettings[ Time_ReloadFile ], "OnTaskReloadFile", .flags = "b" );
}

public OnSayTextNameChange( iMsg, iDestination, iEntity )
{
	g_iFwNameChanged = register_forward( FM_ClientUserInfoChanged, "OnNameChange", 1 );
}

public OnNameChange( id )
{
	if( !is_user_connected( id ) )
	{
		return;
	}

	static szNewName[ 32 ];
	get_user_name( id, szNewName, charsmax( szNewName ) );
	
	unregister_forward( FM_ClientUserInfoChanged, g_iFwNameChanged, 1 );
	
	copy( g_iPlayer[ id ][ Name ], charsmax( g_iPlayer[ ][ Name ] ), szNewName );
}

public client_authorized( id )
{
	get_user_name( id , g_iPlayer[ id ][ Name ] , charsmax( g_iPlayer[ ][ Name ] ) );
	get_user_authid( id , g_iPlayer[ id ][ AuthID ] , charsmax( g_iPlayer[ ][ AuthID ] ) );
	get_user_ip( id, g_iPlayer[ id ][ IP ] , charsmax( g_iPlayer[ ][ IP ] ), 1 );
	
	g_iPlayer[ id ][ VIP ] = 0;
	g_iPlayer[ id ][ VIP ] = read_flags( "z" );
	
	CheckPlayerVIP( id );
}

public client_putinserver( id )
{
	if( is_user_connected( id ) && g_iPlayer[ id ][ VIP ] & g_iSettings[ Access_ConnectMessage ] )
	{
		set_task( g_iSettings[ Time_ConnectMessage ], "OnConnectMessage", id );
	}
}

public OnConnectMessage( const id )
{
	new szMessage[ 512 ];
	copy( szMessage, charsmax( szMessage ), g_iSettings[ ConnectMessage ] )

	if( contain( szMessage, g_szNameField ) != -1 )
	{
		replace_all( szMessage, charsmax( szMessage ), g_szNameField, g_iPlayer[ id ][ Name ] )
	}
	
	if( contain( szMessage, g_szAuthIDField ) != -1 )
	{
		replace_all( szMessage, charsmax( szMessage ), g_szAuthIDField, g_iPlayer[ id ][ AuthID ] )
	}
	
	if( contain( szMessage, g_szFlagsField ) != -1 )
	{
		new szFlag[ 32 ]
		get_flags( g_iPlayer[ id ][ VIP ], szFlag, charsmax( szFlag ) )
		replace_all( szMessage, charsmax( szMessage ), g_szFlagsField, szFlag )
	}
	
	if( contain( szMessage, g_szExpireField ) != -1 )
	{
		new szExpire[ 64 ]
		GetExpireDate( id, szExpire, charsmax( szExpire ) )
		replace_all( szMessage, charsmax( szMessage ), g_szExpireField, szExpire )
	}
		
	CC_SendMessage( 0, szMessage );
}

public client_disconnected( id )
{
	g_iPlayer[ id ][ VIP ] = 0;
	g_iPlayer[ id ][ VIP ] = read_flags( "z" );
	
	arrayset( g_iPlayer[ id ][ Name ], 0, sizeof( g_iPlayer[ ][ Name ] ) );
	arrayset( g_iPlayer[ id ][ AuthID ], 0, sizeof( g_iPlayer[ ][ AuthID ] ) );
	arrayset( g_iPlayer[ id ][ IP ], 0, sizeof( g_iPlayer[ ][ IP ] ) );
}

public plugin_end( )
{		
	TrieDestroy( g_tDatabase )
}

public CBasePlayer_Spawn( id )
{
	if( g_iSettings[ bFreeVIP ] )
	{
		if( IsVipHour( g_iSettings[ Free_VIP_TIME ][ 0 ] , g_iSettings[ Free_VIP_TIME ][ 1 ] ) )
		{
			g_iPlayer[ id ][ VIP ] = 0;
			g_iPlayer[ id ][ VIP ] |= g_iSettings[ Free_VIP_Flag ];
			g_bFreeVipTime = true;
		}
		else
		{
			g_iPlayer[ id ][ VIP ] = 0;
			g_iPlayer[ id ][ VIP ] = read_flags( "z" );
			g_bFreeVipTime = false;
		}
	}
	
	Update_Attribute( id )
}

public OnTaskReloadFile( )
{
	new szPlayers[ MAX_PLAYERS ], iNum;
	get_players( szPlayers, iNum, "ch" );
	
	for( new iPlayer, i; i < iNum; i++ )
	{
		iPlayer = szPlayers[ i ];

		CheckPlayerVIP( iPlayer );
	}
}

@OnVipsOnline( id )
{
	new szBuffer[ 192 ], szPlayers[ MAX_PLAYERS ], iIndex, iVipNum, iNum;
	formatex( szBuffer, charsmax( szBuffer ), "&x04Online:&x01 " );
	
	get_players( szPlayers, iNum, "ch" );
	
	for( new i ; i < iNum; i++ )
	{
		iIndex = szPlayers[ i ];
		
		if( g_iPlayer[ iIndex ][ VIP ] & g_iSettings[ Access_OnlineList ]  )
		{
			format( szBuffer, charsmax( szBuffer ), "%s%s%s", szBuffer, g_iPlayer[ iIndex ][ Name ], iIndex == iNum ? "." : ", " );
			iVipNum = iNum
		}
	}
	
	if( !iVipNum )
	{
		add( szBuffer, charsmax( szBuffer ), "There are no vip's online.");
	}
	
	CC_SendMessage( id, szBuffer );
}

@OnAddNewVIP( id )
{
	if( ~g_iPlayer[ id ][ VIP ] & g_iSettings[ Access_AddVIP ] )
	{
		console_print( id, "You have no Access to this command" )
		return PLUGIN_HANDLED;
	}

	if( read_argc( ) != 5 )
	{
		console_print( id, "Usage is : amx_addvip <Nick|SteamID> <Password> <Flags> <ExpireDate>" )
		return PLUGIN_HANDLED;
	}

	new szPlayerID[ MAX_AUTHID_LENGTH ], szPlayerPassword[ 32 ], szPlayerFlags[ MAX_FLAGS_LENGTH ], szPlayerExpire[ MAX_FLAGS_LENGTH ];
	
	read_argv( 1, szPlayerID, charsmax( szPlayerID ) );
	read_argv( 2, szPlayerPassword, charsmax( szPlayerPassword ) );
	read_argv( 3, szPlayerFlags, charsmax( szPlayerFlags ) );
	read_argv( 4, szPlayerExpire, charsmax( szPlayerExpire ) );
	
	if( ( strlen( szPlayerID ) < 3 ) || ( strlen( szPlayerFlags ) < 1 ) )
	{
		console_print( id, "ERROR: Incorrect Format of VIP" );
		return PLUGIN_HANDLED;
	}
	
	new g_szFile[ 128 ];
	formatex( g_szFile, charsmax( g_szFile ), "%s/%s", g_szConfigs, g_iAccountFile )
	
	new iFile = fopen( g_szFile, "r+" ); 

	new szByteVal[ 1 ], szNewLine[ 128 ]; 
	
	fseek( iFile , -1 , SEEK_END ); 
	fread_raw( iFile , szByteVal , sizeof( szByteVal ) , BLOCK_BYTE ); 
	fseek( iFile , 0 , SEEK_END ); 
	
	formatex( szNewLine , charsmax( szNewLine ) , "%s^"%s^" ^"%s^" ^"%s^" ^"%s^"" , ( szByteVal[ 0 ] == 10 ) ? "" : "^n", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );
	
	fprintf( iFile, szNewLine );
	fclose( iFile );  
	
	console_print( id, "Successfully Added New Admin: Name: %s | Password: %s | Flags: %s | ExpireDate : %s ", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );
	return PLUGIN_HANDLED;
}

CheckPlayerVIP( id )
{
	new szPassword[ 18 ];

	get_user_info( id, "_pw", szPassword, charsmax( szPassword ) );
		
	if( TrieGetArray( g_tDatabase, g_iPlayer[ id ][ AuthID ], eData, sizeof eData ) || TrieGetArray( g_tDatabase, g_iPlayer[ id ][ Name ], eData, sizeof eData ) )
	{
		if( ( eData[ Player_Password ][ 0 ] && equal( eData[ Player_Password ], szPassword ) ) || !eData[ Player_Password ][ 0 ] )
		{
			if( eData[ Player_Suspended ]  && ! eData[ Player_AccessFlags ][ 0 ] )
			{
				g_iPlayer[ id ][ VIP ] = 0;
				g_iPlayer[ id ][ VIP ] = read_flags( "z" );
				return PLUGIN_HANDLED;
			}
			else
			{
				g_iPlayer[ id ][ VIP ] |= read_flags( eData[ Player_AccessFlags ] );
				return PLUGIN_HANDLED;
			}
		}
		else if( eData[ Player_Password ][ 0 ] && ! equal( eData[ Player_Password ], szPassword ) )
		{
			server_cmd( "kick #%d ^"You have no entry to this server^"", get_user_userid( id ) );   
		}
	}
	
	return PLUGIN_CONTINUE;
}

ReadConfing( )
{
	new g_szFile[ 128 ]
	
	formatex( g_szFile, charsmax( g_szFile ), "%s/%s", g_szConfigs, g_iSettingsFile )
	
	new iFile = fopen( g_szFile, "rt" );
	
	if( iFile )
	{
		new szData[ 96 ], szKey[ 32 ], szValue[ 64 ];
		
		while( fgets( iFile, szData, charsmax( szData ) ) )
		{   
			trim( szData );
			
			switch( szData[ 0 ] )
			{
				case EOS, ';', '#', '/':
				{
					continue;
				}
				
				default:
				{
					strtok( szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=' );
					trim( szKey ); trim( szValue );
					remove_quotes( szKey ); remove_quotes( szValue );
					
					if( ! szValue[ 0 ] || ! szKey[ 0 ] )
					{
						continue;
					}
					
					if( equal( szKey, "CHAT_PREFIX" ) )
					{
						copy( g_iSettings[ Prefix_Chat ], charsmax( g_iSettings[ Prefix_Chat ] ), szValue )
					}
					else if( equal( szKey, "CONNECT_MESSAGE" ) )
					{
						copy( g_iSettings[ ConnectMessage ], charsmax( g_iSettings[ ConnectMessage ] ), szValue )
					}
					else if( equal( szKey, "ADD_VIP" ) )
					{
						while( szValue[ 0 ] != 0 && strtok( szValue, szKey, charsmax( szKey ), szValue, charsmax( szValue ), ',' ) )
						{
							register_concmd( szKey , "@OnAddNewVIP" );
						}
					}
					else if( equal( szKey, "ONLINE_VIPS" ) )
					{
						while( szValue[ 0 ] != 0 && strtok( szValue, szKey, charsmax( szKey ), szValue, charsmax( szValue ), ',' ) )
						{
							register_clcmd( szKey , "@OnVipsOnline" );
						}
					}
					else if( equal( szKey, "ACCESS_ADD_VIP" ) )
					{
						g_iSettings[ Access_AddVIP ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "ACCESS_SCOREBOARD" ) )
					{
						g_iSettings[ Access_ScoreBoard ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "ACCESS_CONNECT_MESSAGE" ) )
					{
						g_iSettings[ Access_ConnectMessage ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "ACCESS_ONLINE_LIST" ) )
					{
						g_iSettings[ Access_OnlineList ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "FREE_VIP" ) )
					{
						g_iSettings[ bFreeVIP ] = _:clamp( str_to_num( szValue ), false, true )
					}
					else if( equal( szKey, "FREE_VIP_FLAG" ) )
					{
						g_iSettings[ Free_VIP_Flag ] = read_flags( szValue )
					}
					else if( equal( szKey, "FREE_VIP_TIME" ) )
					{
						new szTime[ 2 ][ 3 ]
						parse( szValue, szTime[ 0 ], charsmax( szTime[ ] ), szTime[ 1 ], charsmax( szTime[ ] ) )
						
						for( new i = 0; i < 2; i++ )
						{
							g_iSettings[ Free_VIP_TIME ][ i ] = _:clamp( str_to_num( szTime[ i ] ), 00, 24 );
						}
					}
					else if( equal( szKey, "TIME_RELOAD_FILE" ) )
					{
						g_iSettings[ Time_ReloadFile ] = _:str_to_float( szValue );
					}
					else if( equal( szKey, "TIME_CONNECT_MESSAGE" ) )
					{
						g_iSettings[ Time_ConnectMessage ] = _:str_to_float( szValue );
					}
				}
			}
		}
		fclose( iFile );
	}
	
	CC_SetPrefix( g_iSettings[ Prefix_Chat ] )
}

ReloadFile( )
{
	TrieClear( g_tDatabase );
	
	new g_szFile[ 128 ]
	
	formatex( g_szFile, charsmax( g_szFile ), "%s/%s", g_szConfigs, g_iAccountFile )
	
	new iFile = fopen( g_szFile, "rt" );
	
	if( iFile )
	{
		new szData[ 512 ]
		
		while( fgets( iFile, szData, charsmax( szData ) ) )
		{    
			trim( szData );
			
			switch( szData[ 0 ] )
			{
				case EOS, ';',  '#', '/', '\':
				{
					continue;
				}

				default:
				{
					if
					( 
						parse 
						( 
							szData, eData[ Player_Name ]		, charsmax( eData[ Player_Name ] ),
							eData[ Player_Password ]		, charsmax( eData[ Player_Password ] ),
							eData[ Player_AccessFlags ]		, charsmax( eData[ Player_AccessFlags ] ),
							eData[ Player_Expire_Date ]		, charsmax( eData[ Player_Expire_Date ] ) 
						) < 4 
					)
					{
						continue;
					}
					
					if( eData[ Player_Expire_Date ][ 0 ] )
					{
						if( HasDateExpired( eData[ Player_Expire_Date ] ) )
						{
							eData[ Player_Suspended ] = true;
						}
					}
					
					if( eData[ Player_Name ][ 0 ] )
					{
						TrieSetArray( g_tDatabase, eData[ Player_Name ], eData, sizeof eData );
					}
					
					arrayset( eData, 0, sizeof( eData ) );
				}
			}
		}
		fclose( iFile );
	}
}

Update_Attribute( const id )
{
	if( g_iPlayer[ id ][ VIP ] & g_iSettings[ Access_ScoreBoard ]  )
	{
		message_begin( MSG_ALL, get_user_msgid("ScoreAttrib"), { 0, 0, 0 }, id )
		write_byte( id )
		write_byte( ( 1<<2 ) )
		message_end( )
	}
}

GetExpireDate( id, szExpire[ ], iLen )
{
	if( TrieGetArray( g_tDatabase, g_iPlayer[ id ][ AuthID ], eData, sizeof eData ) || TrieGetArray( g_tDatabase, g_iPlayer[ id ][ Name ], eData, sizeof eData ) )
	{
		if( eData[ Player_Expire_Date ][ 0 ] )
		{
			copy( szExpire, iLen, eData[ Player_Expire_Date ] )
		}
		else
		{
			copy( szExpire, iLen, "permanently" )
		}
	}
	else copy( szExpire, iLen, "N/A" )
}

bool:HasDateExpired( const szDate[ ] )
{
	return get_systime( ) >= parse_time( szDate, "%m/%d/%Y %H:%M:%S" );
}

bool:IsVipHour( iStart, iEnd )
{
	new iHour; time( iHour );
	return bool:( iStart < iEnd ? ( iStart <= iHour < iEnd ) : ( iStart <= iHour || iHour < iEnd ) )
} 

public plugin_natives( )
{
	register_library("vip")
	register_native( "get_vip_prefix", "_get_vip_chat_prefix" )
	register_native( "get_vip_expire", "_get_vip_expire" )
	register_native( "add_user_vip", "_add_user_vip" )
	register_native( "get_user_vip", "_get_user_vip" )
	register_native( "set_user_vip", "_set_user_vip" )
	register_native( "is_user_vip", "_is_user_vip" )
	register_native( "is_free_vip_time", "_is_free_vip_time" )
	register_native( "remove_user_vip", "_remove_user_vip" )
}

public _get_vip_chat_prefix( iPlugin, iParams )
{
	set_string( 1, g_iSettings[ Prefix_Chat ], get_param( 2 ) )
}

public _get_vip_expire( iPlugin, iParams )
{
	new szExpire[ 64 ]
	GetExpireDate( get_param( 1 ), szExpire, charsmax( szExpire ) )

	set_string( 2, szExpire, get_param( 3 ) )
}

public bool:_is_free_vip_time( iPlugin, iParams )
{
	return g_bFreeVipTime;
}

public bool:_is_user_vip( iPlugin, iParams )
{
	new id = get_param( 1 )
	
	if( !g_iPlayer[ id ][ VIP ] || g_iPlayer[ id ][ VIP ] == 0 || g_iPlayer[ id ][ VIP ] & read_flags( "z" ) )
	{
		return false;
	}
	
	return true;
}

public _remove_user_vip( iPlugin, iParams )
{
	new id = get_param( 1 );
	new iFlags = get_param( 2 );
	
	if( ! iFlags )
	{
		g_iPlayer[ id ][ VIP ] = 0;
		g_iPlayer[ id ][ VIP ] = read_flags( "z" );
	}
	else
	{
		g_iPlayer[ id ][ VIP ] = 0;
		g_iPlayer[ id ][ VIP ] &= ~ iFlags;
	}
}

public _get_user_vip( iPlugin, iParams )
{
	return g_iPlayer[ get_param( 1 ) ][ VIP ]
}

public _set_user_vip( iPlugin, iParams )
{
	g_iPlayer[ get_param( 1 ) ][ VIP ] = 0;
	g_iPlayer[ get_param( 1 ) ][ VIP ] |= get_param( 2 ); 
}

public _add_user_vip( iPlugin, iParams )
{
	new szPlayerID[ MAX_AUTHID_LENGTH ], szPlayerPassword[ 32 ], szPlayerFlags[ MAX_FLAGS_LENGTH ], szPlayerExpire[ MAX_FLAGS_LENGTH ];
	
	get_string( 1, szPlayerID, charsmax( szPlayerID ) );
	get_string( 2, szPlayerPassword, charsmax( szPlayerPassword ) );
	get_string( 3, szPlayerFlags, charsmax( szPlayerFlags ) );
	get_string( 4, szPlayerExpire, charsmax( szPlayerExpire ) );
	
	new g_szFile[ 128 ];
	formatex( g_szFile, charsmax( g_szFile ), "%s/%s", g_szConfigs, g_iAccountFile )
	
	new iFile = fopen( g_szFile, "r+" );

	new szByteVal[ 1 ], szNewLine[ 128 ];
	
	fseek( iFile , -1 , SEEK_END );
	fread_raw( iFile , szByteVal , sizeof( szByteVal ) , BLOCK_BYTE );
	fseek( iFile , 0 , SEEK_END );
	
	formatex( szNewLine , charsmax( szNewLine ) , "%s^"%s^" ^"%s^" ^"%s^" ^"%s^"" , ( szByteVal[ 0 ] == 10 ) ? "" : "^n", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );

	fprintf( iFile, szNewLine );
	fclose( iFile );
}	
