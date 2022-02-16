#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <cromchat>

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#if !defined MAX_PLAYERS
	const MAX_PLAYERS = 32;
#endif

#if !defined MAX_NAME_LENGTH
	const MAX_NAME_LENGTH = 32;
#endif

#if !defined MAX_AUTHID_LENGTH
	const MAX_AUTHID_LENGTH = 64;
#endif

#if !defined MAX_IP_LENGTH
	const MAX_IP_LENGTH = 16;
#endif

#if !defined MAX_FMT_LENGTH
	const MAX_FMT_LENGTH = 192;
#endif

#if !defined TrieGetSize
	native TrieGetSize( Trie:Handle );
#endif

const MAX_FLAGS_LENGTH = 26;
const MAX_PASSWORD_LENGTH = 32;

new const Version[ ] = "1.0.5";

new const g_iSettingsFile[ ] = "VIPSettings.ini"

new const g_szNameField[ ] = "%name%"
new const g_szAuthIDField[ ] = "%authid%"
new const g_szFlagsField[ ] = "%flag%"
new const g_szExpireField[ ] = "%expiredate%"

enum _:PlayerAccount
{ 
	Player_Identity[ MAX_AUTHID_LENGTH ],
	Player_Password[ MAX_PASSWORD_LENGTH ],
	Player_Access[ MAX_FLAGS_LENGTH ],
	Player_Expire_Date[ MAX_FLAGS_LENGTH ]
}

enum PlayerData
{ 
	Name[ MAX_NAME_LENGTH ],
	AuthID[ MAX_AUTHID_LENGTH ],
	IP[ MAX_IP_LENGTH ],
	VIP
}

enum _:eSettings
{ 
	PREFIX_CHAT[ MAX_NAME_LENGTH ],
	ACCOUNT_FILE[ MAX_NAME_LENGTH ],
	MESSAGE_CONNECT[ MAX_FMT_LENGTH ],
	FREE_VIP_TIME[ 2 ],
	FREE_VIP_FLAGS,
	ACCESS_ADD_VIP,
	ACCESS_RELOAD,
	ACCESS_SCOREBOARD,
	ACCESS_CONNECT_MESSAGE,
	ACCESS_VIP_LIST,
	Float:TASK_RELOAD,
	Float:TASK_CONNECT_MESSAGE,
	bool:AUTO_RELOAD
}

new Trie:g_tDatabase,
	eData[ PlayerAccount ],
	g_iSettings[ eSettings ],
	g_szConfigs[ 64 ],
	g_iPlayer[ MAX_PLAYERS + 1 ][ PlayerData ],
	g_iFwNameChanged,
	bool:g_bFreeVipTime

public plugin_init( ) 
{
	register_plugin( "VIP System", Version, "Supremache" );
	register_cvar( "VIPSystem", Version, FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED );
	
	get_configsdir( g_szConfigs, charsmax( g_szConfigs ) );
	
	RegisterHam( Ham_Spawn, "player", "@OnPlayerSpawn", 1 );
	register_event( "SayText", "OnSayTextNameChange", "a", "2=#Cstrike_Name_Change" );
	
	ReadConfings( );	
	ReadAccounts( );
	
	if( TrieGetSize( g_tDatabase ) ) server_print( "[VIP] Loaded %i vips from the file", TrieGetSize( g_tDatabase ) )
}

public plugin_end( )
{		
	TrieDestroy( g_tDatabase );
}

public client_putinserver( id )
{
	if( is_user_connected( id ) && g_iPlayer[ id ][ VIP ] & g_iSettings[ ACCESS_CONNECT_MESSAGE ] )
	{
		set_task( g_iSettings[ TASK_CONNECT_MESSAGE ], "@OnConnectMessage", id );
	}
}

public client_authorized( id )
{
	get_user_name( id , g_iPlayer[ id ][ Name ] , charsmax( g_iPlayer[ ][ Name ] ) );
	get_user_authid( id , g_iPlayer[ id ][ AuthID ] , charsmax( g_iPlayer[ ][ AuthID ] ) );
	get_user_ip( id, g_iPlayer[ id ][ IP ] , charsmax( g_iPlayer[ ][ IP ] ), 1 );
	
	g_iPlayer[ id ][ VIP ] = read_flags( "z" );
	
	CheckPlayerVIP( id );
}

public client_disconnected( id )
{
	arrayset( g_iPlayer[ id ][ Name ], 0, sizeof( g_iPlayer[ ][ Name ] ) );
	arrayset( g_iPlayer[ id ][ AuthID ], 0, sizeof( g_iPlayer[ ][ AuthID ] ) );
	arrayset( g_iPlayer[ id ][ IP ], 0, sizeof( g_iPlayer[ ][ IP ] ) );
	
	g_iPlayer[ id ][ VIP ] = read_flags( "z" );
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
	copy( g_iPlayer[ id ][ Name ], charsmax( g_iPlayer[ ][ Name ] ), szNewName );
	
	CheckPlayerVIP( id );
	unregister_forward( FM_ClientUserInfoChanged, g_iFwNameChanged, 1 );
}

CheckPlayerVIP( id )
{
	new szPassword[ MAX_PASSWORD_LENGTH ];
	
	get_user_info( id, "_pw", szPassword, charsmax( szPassword ) );
		
	if( TrieGetArray( g_tDatabase, g_iPlayer[ id ][ AuthID ], eData, sizeof eData ) || TrieGetArray( g_tDatabase, g_iPlayer[ id ][ Name ], eData, sizeof eData ) || TrieGetArray( g_tDatabase, g_iPlayer[ id ][ IP ], eData, sizeof eData ) )
	{
		if( ( eData[ Player_Password ][ 0 ] && equal( eData[ Player_Password ], szPassword ) ) || !eData[ Player_Password ][ 0 ] )
		{
			if( eData[ Player_Access ][ 0 ] )
			{
				g_iPlayer[ id ][ VIP ] |= read_flags( eData[ Player_Access ] );
			}
		}
		else if( eData[ Player_Password ][ 0 ] && ! equal( eData[ Player_Password ], szPassword ) )
		{
			server_cmd( "kick #%d ^"You have no entry to this server^"", get_user_userid( id ) );   
		}
	}
}

public OnReloadFile( )
{
	ReadAccounts( );
	
	new szPlayers[ MAX_PLAYERS ], iNum;
	get_players( szPlayers, iNum, "ch" );
	
	for( new i; i < iNum; i++ )
	{
		CheckPlayerVIP( szPlayers[ i ] );
	}
}

@OnReloadVIP( id )
{
	if( ~g_iPlayer[ id ][ VIP ] & g_iSettings[ ACCESS_RELOAD ] )
	{
		console_print( id, "You have no access to this command" )
		return PLUGIN_HANDLED;
	}
	
	OnReloadFile( );
	console_print( id, "[VIP] The file has been successfully reloaded" );

	return PLUGIN_HANDLED;
}

@OnConnectMessage( id )
{
	new szMessage[ MAX_FMT_LENGTH ], szPlaceHolder[ MAX_FLAGS_LENGTH ];
	copy( szMessage, charsmax( szMessage ), g_iSettings[ MESSAGE_CONNECT ] );
	
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
		get_flags( g_iPlayer[ id ][ VIP ], szPlaceHolder, charsmax( szPlaceHolder ) )
		replace_all( szMessage, charsmax( szMessage ), g_szFlagsField, szPlaceHolder )
	}
	
	if( contain( szMessage, g_szExpireField ) != -1 )
	{
		GetExpireDate( id, szPlaceHolder, charsmax( szPlaceHolder ) )
		replace_all( szMessage, charsmax( szMessage ), g_szExpireField, szPlaceHolder );
	}
	
	CC_SendMessage( 0, szMessage );
}

@OnPlayerSpawn( id )
{
	if( g_iPlayer[ id ][ VIP ] & g_iSettings[ ACCESS_SCOREBOARD ] )
	{
		Update_Attribute( id );
	}
		
	if( g_iSettings[ FREE_VIP_TIME ][ 0 ] || g_iSettings[ FREE_VIP_TIME ][ 1 ] )
	{
		if( IsVipHour( g_iSettings[ FREE_VIP_TIME ][ 0 ], g_iSettings[ FREE_VIP_TIME ][ 1 ] ) )
		{
			g_iPlayer[ id ][ VIP ] |= g_iSettings[ FREE_VIP_FLAGS ];
			g_bFreeVipTime = true;
		}
		else
		{
			g_iPlayer[ id ][ VIP ] &= ~g_iSettings[ FREE_VIP_FLAGS ];
			g_bFreeVipTime = false;
		}
	}
}

@OnVipsList( id )
{
	new szBuffer[ MAX_FMT_LENGTH ], szPlayers[ MAX_PLAYERS ], iNum, iLen;

	get_players( szPlayers, iNum, "ch" );
	
	for( new iIndex, i; i < iNum; i++ )
	{
		if( g_iPlayer[ ( iIndex = szPlayers[ i ] ) ][ VIP ] & g_iSettings[ ACCESS_VIP_LIST ] )
		{
			iLen += formatex( szBuffer[ iLen ], charsmax( szBuffer ) - iLen , "%s, ", g_iPlayer[ iIndex ][ Name ] )
		}
	}
	
	// Credits to jimaway & Natsheh
	if( szBuffer[ 0 ] != EOS )
	{
		szBuffer[ iLen - 1 ] = EOS;
		szBuffer[ iLen - 2 ] = '.';
		CC_SendMessage( id, szBuffer );
	}
	else
	{
		CC_SendMessage( id, "There are no vip's online." );
	} 
}

@OnAddNewVIP( id )
{
	if( ~g_iPlayer[ id ][ VIP ] & g_iSettings[ ACCESS_ADD_VIP ] )
	{
		console_print( id, "You have no access to this command" )
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
	formatex( g_szFile, charsmax( g_szFile ), "%s/%s", g_szConfigs, g_iSettings[ ACCOUNT_FILE ] )
	
	new iFile = fopen( g_szFile, "r+" ); 

	new szByteVal[ 1 ], szNewLine[ 128 ]; 
	
	fseek( iFile , -1 , SEEK_END ); 
	fread_raw( iFile , szByteVal , sizeof( szByteVal ) , BLOCK_BYTE ); 
	fseek( iFile , 0 , SEEK_END ); 
	
	formatex( szNewLine , charsmax( szNewLine ) , "%s^"%s^" ^"%s^" ^"%s^" ^"%s^"" , ( szByteVal[ 0 ] == 10 ) ? "" : "^n", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );
	
	fprintf( iFile, szNewLine );
	fclose( iFile );  
	OnReloadFile( );
	
	console_print( id, "Successfully Added New Admin: Name: %s | Password: %s | Flags: %s | ExpireDate : %s ", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );
	return PLUGIN_HANDLED;
}

ReadConfings( )
{
	new szFile[ 128 ]
	
	formatex( szFile, charsmax( szFile ), "%s/%s", g_szConfigs, g_iSettingsFile )
	
	new iFile = fopen( szFile, "rt" );
	
	if( iFile )
	{
		new szData[ 256 ], szKey[ 32 ], szValue[ MAX_FMT_LENGTH ];
		
		while( fgets( iFile, szData, charsmax( szData ) ) )
		{   
			trim( szData );
			
			switch( szData[ 0 ] )
			{
				case EOS, ';', '#', '/': continue;
				
				default:
				{
					strtok( szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=' );
					trim( szKey ); trim( szValue );

					if( ! szValue[ 0 ] || ! szKey[ 0 ] )
					{
						continue;
					}
					
					if( equal( szKey, "CHAT_PREFIX" ) )
					{
						copy( g_iSettings[ PREFIX_CHAT ], charsmax( g_iSettings[ PREFIX_CHAT ] ), szValue )
					}
					else if( equal( szKey, "ACCOUNT_FILE" ) )
					{
						copy( g_iSettings[ ACCOUNT_FILE ], charsmax( g_iSettings[ ACCOUNT_FILE ] ), szValue )
					}
					else if( equal( szKey, "CONNECT_MESSAGE" ) )
					{
						copy( g_iSettings[ MESSAGE_CONNECT ], charsmax( g_iSettings[ MESSAGE_CONNECT ] ), szValue )
					}
					else if( equal( szKey, "ADD_VIP" ) )
					{
						while( szValue[ 0 ] != 0 && strtok( szValue, szKey, charsmax( szKey ), szValue, charsmax( szValue ), ',' ) )
						{
							register_concmd( szKey , "@OnAddNewVIP" );
						}
					}
					else if( equal( szKey, "VIP_LIST" ) )
					{
						while( szValue[ 0 ] != 0 && strtok( szValue, szKey, charsmax( szKey ), szValue, charsmax( szValue ), ',' ) )
						{
							register_clcmd( szKey , "@OnVipsList" );
						}
					}
					else if( equal( szKey, "ACCESS_ADD_VIP" ) )
					{
						g_iSettings[ ACCESS_ADD_VIP ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "ACCESS_SCOREBOARD" ) )
					{
						g_iSettings[ ACCESS_SCOREBOARD ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "ACCESS_CONNECT_MESSAGE" ) )
					{
						g_iSettings[ ACCESS_CONNECT_MESSAGE ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "ACCESS_VIP_LIST" ) )
					{
						g_iSettings[ ACCESS_VIP_LIST ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "FREE_VIP_FLAG" ) )
					{
						g_iSettings[ FREE_VIP_FLAGS ] = read_flags( szValue )
					}
					else if( equal( szKey, "FREE_VIP_TIME" ) )
					{
						new szTime[ 2 ][ 3 ];
						parse( szValue, szTime[ 0 ], charsmax( szTime[ ] ), szTime[ 1 ], charsmax( szTime[ ] ) )
						
						for( new i ; i < 2; i++ )
						{
							g_iSettings[ FREE_VIP_TIME ][ i ] = _:clamp( str_to_num( szTime[ i ] ), 00, 24 );
						}
					}
					else if( equal( szKey, "TIME_RELOAD_FILE" ) )
					{
						g_iSettings[ TASK_RELOAD ] = _:str_to_float( szValue );
					}
					else if( equal( szKey, "TIME_CONNECT_MESSAGE" ) )
					{
						g_iSettings[ TASK_CONNECT_MESSAGE ] = _:str_to_float( szValue );
					}
					else if( equal( szKey, "AUTO_RELOAD" ) )
					{
						g_iSettings[ AUTO_RELOAD ] = _:clamp( str_to_num( szValue ), false, true )
					}
					else if( equal( szKey, "ACCESS_RELOAD" ) )
					{
						g_iSettings[ ACCESS_RELOAD ] = szValue[ 0 ] == '0' ? ~read_flags( "z" ) : read_flags( szValue )
					}
					else if( equal( szKey, "RELOAD_VIP" ) )
					{
						if( g_iSettings[ AUTO_RELOAD ] )
						{
							set_task( g_iSettings[ TASK_RELOAD ], "OnReloadFile", .flags = "b" );
						}
						else
						{
							while( szValue[ 0 ] != 0 && strtok( szValue, szKey, charsmax( szKey ), szValue, charsmax( szValue ), ',' ) )
							{
								register_concmd( szKey , "@OnReloadVIP" );
							}
						}
					}
					
					
				}
			}
		}
		fclose( iFile );
	}
	else log_amx( "File %s does not exists", szFile )
	
	CC_SetPrefix( g_iSettings[ PREFIX_CHAT ] )
}

ReadAccounts( )
{
	g_tDatabase = TrieCreate( );
	
	new szFile[ 128 ];
	
	formatex( szFile, charsmax( szFile ), "%s/%s", g_szConfigs, g_iSettings[ ACCOUNT_FILE ] )
	
	new iFile = fopen( szFile, "rt" );
	
	if( iFile )
	{
		new szData[ 512 ];
		
		while( fgets( iFile, szData, charsmax( szData ) ) )
		{    
			trim( szData );
			
			switch( szData[ 0 ] )
			{
				case EOS, ';',  '#', '/': continue;

				default:
				{
					if( parse( szData, eData[ Player_Identity ], charsmax( eData[ Player_Identity ] ), eData[ Player_Password ], charsmax( eData[ Player_Password ] ), eData[ Player_Access ], charsmax( eData[ Player_Access ] ), eData[ Player_Expire_Date ], charsmax( eData[ Player_Expire_Date ] ) ) < 4 ) continue;
					
					if( eData[ Player_Identity ][ 0 ] && !eData[ Player_Expire_Date ][ 0 ] || !HasDateExpired( eData[ Player_Expire_Date ] ) )
					{
						TrieSetArray( g_tDatabase, eData[ Player_Identity ], eData, sizeof eData );
					}
					
					arrayset( eData, 0, sizeof( eData ) )
				}
			}
		}
		fclose( iFile );
	}
	else log_amx( "File %s does not exists", szFile )
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

GetExpireDate( const id, szExpire[ ], iLen )
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
	else copy( szExpire, iLen, "Expired or Not found" )
}

Update_Attribute( const id )
{
	message_begin( MSG_ALL, get_user_msgid("ScoreAttrib"), { 0, 0, 0 }, id )
	write_byte( id )
	write_byte( ( 1<<2 ) )
	message_end( )
}

public plugin_natives( )
{
	register_library( "vip" )
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
	set_string( 1, g_iSettings[ PREFIX_CHAT ], get_param( 2 ) )
}

public _get_vip_expire( iPlugin, iParams )
{
	new szExpire[ MAX_FLAGS_LENGTH ];
	GetExpireDate( get_param( 1 ), szExpire, charsmax( szExpire ) )
	set_string( 2, szExpire, get_param( 3 ) )
}

public bool:_is_free_vip_time( iPlugin, iParams )
{
	return g_bFreeVipTime;
}

public bool:_is_user_vip( iPlugin, iParams )
{
	new _iFlag = g_iPlayer[ get_param( 1 ) ][ VIP ];
	return ( _iFlag && !( _iFlag & read_flags( "z" ) ) );
}

public _remove_user_vip( iPlugin, iParams )
{
	g_iPlayer[ get_param( 1 ) ][ VIP ] &= ~ get_param( 2 );
}

public _get_user_vip( iPlugin, iParams )
{
	return g_iPlayer[ get_param( 1 ) ][ VIP ];
}

public _set_user_vip( iPlugin, iParams )
{
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
	formatex( g_szFile, charsmax( g_szFile ), "%s/%s", g_szConfigs, g_iSettings[ ACCOUNT_FILE ] )
	
	new iFile = fopen( g_szFile, "r+" );

	new szByteVal[ 1 ], szNewLine[ 128 ];
	
	fseek( iFile , -1 , SEEK_END );
	fread_raw( iFile , szByteVal , sizeof( szByteVal ) , BLOCK_BYTE );
	fseek( iFile , 0 , SEEK_END );
	
	formatex( szNewLine , charsmax( szNewLine ) , "%s^"%s^" ^"%s^" ^"%s^" ^"%s^"" , ( szByteVal[ 0 ] == 10 ) ? "" : "^n", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );

	fprintf( iFile, szNewLine );
	fclose( iFile );
	OnReloadFile( );
}	
