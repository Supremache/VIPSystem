#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <sqlx>
#include <vip_const>
#include <cromchat>

/* You can also activate geoip if you want to use country and city fields etc... */
//#include <geoip>

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#if !defined TrieGetSize
	native TrieGetSize( Trie:Handle );
#endif


new const Version[ ] = "1.1.0";
new const g_iSettingsFile[ ] = "VIPSettings.ini";

#define IsUserExist(%1) ( TrieGetArray( g_tDatabase, g_iPData[ %1 ][ AuthID ], eData, sizeof eData ) || TrieGetArray( g_tDatabase, g_iPData[ %1 ][ Name ], eData, sizeof eData ) || TrieGetArray( g_tDatabase, g_iPData[ %1 ][ IP ], eData, sizeof eData ) )

new const g_szNameField[ ] = "$name$"
new const g_szAuthIDField[ ] = "$authid$"
new const g_szFlagsField[ ] = "$flag$"
new const g_szExpireField[ ] = "$expiredate$"

#if defined _geoip_included
new const g_szCityField[ ] = "$city$"
new const g_szCountryField[ ] = "$country$"
new const g_szCountryCodeField[ ] = "$countrycode$"
new const g_szContinentField[ ] = "$continent$"
new const g_szContinentCodeField[ ] = "$continentcode$"
#endif

enum _:SaveMethods
{
	ConfingFile,
	MySQL,
	SQLite
}

enum
{
	EDB_IGNORE = 0,
	EDB_COMMENT,
	EDB_REMOVE
}

enum _:PlayerAccount
{ 
	Player_Identity[ MAX_AUTHID_LENGTH ],
	Player_Password[ MAX_PASSWORD_LENGTH ],
	Player_Access[ MAX_FLAGS_LENGTH ],
	Player_Expire_Date[ MAX_DATE_LENGTH ]
}

enum PlayerData
{ 
	Name[ MAX_NAME_LENGTH ],
	AuthID[ MAX_AUTHID_LENGTH ],
	IP[ MAX_IP_LENGTH ],
	VIP,
	CacheFlags
}

enum _:eSettings
{ 
	PREFIX_CHAT[ MAX_NAME_LENGTH ],
	SQL_HOST[ MAX_NAME_LENGTH ],
	SQL_USER[ MAX_NAME_LENGTH ],
	SQL_PASS[ MAX_NAME_LENGTH ],
	SQL_DATABASE[ MAX_NAME_LENGTH ],
	SQL_TABLE[ MAX_NAME_LENGTH ],
	ACCOUNT_FILE[ MAX_NAME_LENGTH ],
	MESSAGE_CONNECT[ MAX_FMT_LENGTH ],
	MESSAGE_EVENT[ MAX_FMT_LENGTH ],
	EVENT_TIME[ 2 ],
	EVENT_FLAGS,
	ACCESS_ADD_VIP,
	ACCESS_RELOAD,
	ACCESS_SCOREBOARD,
	ACCESS_CONNECT_MESSAGE,
	ACCESS_VIP_LIST,
	Float:TASK_RELOAD,
	Float:TASK_CONNECT_MESSAGE,
	bool:AUTO_RELOAD,
	USE_SQL,
	DEFAULT_FLAGS[ MAX_FLAGS_LENGTH ],
	EXPIRATION_DATE_TYPE[ MAX_DATE_LENGTH ],
	EXPIRATION_DATE_FORMAT[ MAX_DATE_LENGTH ],
	EXPIRATION_DATE_BEHAVIOR
}

enum TotalForwards
{ 
	Result,
	NameChanged,
	VIPEvent,
	VIPAdded
}

new Trie:g_tDatabase,
	Array:g_aFileContents,
	eData[ PlayerAccount ],
	g_iSettings[ eSettings ],
	g_iForwards[ TotalForwards ],
	g_szConfigs[ 64 ],
	g_iPData[ MAX_PLAYERS + 1 ][ PlayerData ],
	bool:g_bEventTime,
	Handle:g_SQLTuple,
	Handle:g_iSQLConnection,
	g_szSQLError[ MAX_QUERY_LENGTH ],
	g_iDateSeconds,
	g_iFileContents = -1,
	bool:g_bUserExpired;

public plugin_init( ) 
{
	register_plugin( "VIP System", Version, "Supremache" );
	register_cvar( "VIPSystem", Version, FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED );
	
	register_dictionary( "vip.txt" );

	get_configsdir( g_szConfigs, charsmax( g_szConfigs ) );
	
	RegisterHam( Ham_Spawn, "player", "@OnPlayerSpawn", 1 );
	register_event( "SayText", "OnSayTextNameChange", "a", "2=#Cstrike_Name_Change" );

	g_iForwards[ VIPEvent ] = CreateMultiForward("VIPEvent", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL );
	g_iForwards[ VIPAdded ] = CreateMultiForward( "VIPAdded", ET_IGNORE, FP_STRING, FP_STRING, FP_STRING, FP_STRING );
	
	g_aFileContents = ArrayCreate( MAX_FILE_LENGTH );
	
	ReadConfings( );	
	ReadAccounts( );
}

public plugin_end( )
{		
	ArrayDestroy( g_aFileContents );
	TrieDestroy( g_tDatabase );
	
	if( g_iSettings[ USE_SQL ] )
	{
		SQL_FreeHandle( g_SQLTuple );
	}
}

CheckPlayerVIP( const id )
{
	new szPassword[ MAX_PASSWORD_LENGTH ], szPasswordField[ MAX_PASSWORD_LENGTH ];
	get_cvar_string( "amx_password_field", szPasswordField, charsmax( szPasswordField ) )
	get_user_info( id, szPasswordField[ 0 ] ? szPasswordField : "_pw", szPassword, charsmax( szPassword ) );
	
	g_iPData[ id ][ VIP ] = 0; // Remove user flags
	
	if( IsUserExist( id ) )
	{
		if( ( eData[ Player_Password ][ 0 ] && equal( eData[ Player_Password ], szPassword ) ) || !eData[ Player_Password ][ 0 ] )
		{
			if( eData[ Player_Access ][ 0 ] )
			{
				g_iPData[ id ][ VIP ] |= read_flags( eData[ Player_Access ] );
				PrintToConsole( id, "%L", id, "PAS_ACC" );
				PrintToConsole( id, "%L", id, "PRIV_SET" );
			}
		}
		else if( eData[ Player_Password ][ 0 ] && ! equal( eData[ Player_Password ], szPassword ) )
		{
			PrintToConsole( id, "%L", id, "INV_PAS" );
			server_cmd( "kick #%d ^"%L^"", get_user_userid( id ), id, "NO_ENTRY" );   
		}
	}
	
	if( !g_iPData[ id ][ VIP ] ) // Set default flag
	{
		g_iPData[ id ][ VIP ] = g_iSettings[ DEFAULT_FLAGS ];
	}
}

public client_connect( id )
{
	get_user_name( id , g_iPData[ id ][ Name ] , charsmax( g_iPData[ ][ Name ] ) );
	get_user_authid( id , g_iPData[ id ][ AuthID ] , charsmax( g_iPData[ ][ AuthID ] ) );
	get_user_ip( id, g_iPData[ id ][ IP ], charsmax( g_iPData[ ][ IP ] ), 1 );
	
	CheckPlayerVIP( id );
}

public client_putinserver( id )
{
	if( is_user_connected( id ) )
	{
		set_task( g_iSettings[ TASK_CONNECT_MESSAGE ], "OnConnectMessage", id );
	}
}

public OnConnectMessage( id )
{
	if( ~g_iPData[ id ][ VIP ] & g_iSettings[ ACCESS_CONNECT_MESSAGE ] )
	{
		return;
	}
	
	new szMessage[ MAX_FMT_LENGTH ], szPlaceHolder[ MAX_RESOURCE_PATH_LENGTH ];
	copy( szMessage, charsmax( szMessage ), g_iSettings[ MESSAGE_CONNECT ] );
	
	if( contain( szMessage, g_szNameField ) != -1 )
	{
		replace_all( szMessage, charsmax( szMessage ), g_szNameField, g_iPData[ id ][ Name ] )
	}
	
	if( contain( szMessage, g_szAuthIDField ) != -1 )
	{
		replace_all( szMessage, charsmax( szMessage ), g_szAuthIDField, g_iPData[ id ][ AuthID ] )
	}
	
	if( contain( szMessage, g_szFlagsField ) != -1 )
	{
		get_flags( g_iPData[ id ][ VIP ], szPlaceHolder, charsmax( szPlaceHolder ) )
		replace_all( szMessage, charsmax( szMessage ), g_szFlagsField, szPlaceHolder )
	}
	
	if( contain( szMessage, g_szExpireField ) != -1 )
	{
		GetExpireDate( id, szPlaceHolder, charsmax( szPlaceHolder ) )
		replace_all( szMessage, charsmax( szMessage ), g_szExpireField, szPlaceHolder );
	}

	#if defined _geoip_included
	if( contain( szMessage, g_szCityField ) != -1 )
	{
		geoip_city( g_iPData[ id ][ IP ], szPlaceHolder, charsmax( szPlaceHolder ) )
		
		replace_all( szMessage, charsmax( szMessage ), g_szCityField, ( szPlaceHolder[ 0 ] ? szPlaceHolder : "UnKnown" ) );
	}
	
	if( contain( szMessage, g_szCountryField ) != -1 )
	{
		#if defined geoip_country_ex
		geoip_country_ex( g_iPData[ id ][ IP ], szPlaceHolder, charsmax( szPlaceHolder ) )
		#else
		geoip_country( g_iPData[ id ][ IP ], szPlaceHolder, charsmax( szPlaceHolder ) )
		#endif

		replace_all( szMessage, charsmax( szMessage ), g_szCountryField, ( szPlaceHolder[ 0 ] ? szPlaceHolder : "UnKnown" ) );
	}
	
	if( contain( szMessage, g_szCountryCodeField ) != -1 )
	{
		new szCountryCode[ 3 ];
		
		#if defined geoip_country_ex
		geoip_code2_ex( g_iPData[ id ][ IP ], szCountryCode )
		#else
		geoip_code2( g_iPData[ id ][ IP ], szCountryCode )
		#endif
				
		replace_all( szMessage, charsmax( szMessage ), g_szCountryCodeField, ( szCountryCode[ 0 ] ? szCountryCode : "UnKnown" ) );
	}
	
	if( contain( szMessage, g_szContinentField ) != -1 )
	{
		geoip_continent_name( g_iPData[ id ][ IP ], szPlaceHolder, charsmax( szPlaceHolder ) )
				
		replace_all( szMessage, charsmax( szMessage ), g_szContinentField, ( szPlaceHolder[ 0 ] ? szPlaceHolder : "UnKnown" ) );
	}
	
	if( contain( szMessage, g_szContinentCodeField ) != -1 )
	{
		new szContinentCode[ 3 ];
		geoip_continent_code( g_iPData[ id ][ IP ], szContinentCode )
				
		replace_all( szMessage, charsmax( szMessage ), g_szContinentCodeField, ( szContinentCode[ 0 ] ? szContinentCode : "UnKnown" ) );
	}
	#endif

	CC_SendMessage( 0, szMessage );
}

public OnSayTextNameChange( iMsg, iDestination, iEntity )
{
	g_iForwards[ NameChanged ] = register_forward( FM_ClientUserInfoChanged, "OnNameChange", 1 );
}

public OnNameChange( id )
{
	if( !is_user_connected( id ) )
	{
		return;
	}

	new szName[ MAX_NAME_LENGTH ];
	get_user_name( id, szName, charsmax( szName ) )
	copy( g_iPData[ id ][ Name ], charsmax( g_iPData[ ][ Name ] ), szName );
	
	CheckPlayerVIP( id );
	
	unregister_forward( FM_ClientUserInfoChanged, g_iForwards[ NameChanged ] , 1 )
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

	if( ~g_iPData[ id ][ VIP ] & g_iSettings[ ACCESS_RELOAD ] )
	{
		PrintToConsole( id, "%L", id, "NO_ACCESS" )
		return PLUGIN_HANDLED;
	}
	
	OnReloadFile( );
	PrintToConsole( id, "%L", id, "FILE_RELOADED" );
	return PLUGIN_HANDLED;
}

@OnPlayerSpawn( id )
{
	if( g_iPData[ id ][ VIP ] & g_iSettings[ ACCESS_SCOREBOARD ] )
	{
		message_begin( MSG_ALL, get_user_msgid( "ScoreAttrib" ), { 0, 0, 0 }, id );
		write_byte( id );
		write_byte( 4 );
		message_end( );
	}
	
	if( g_iSettings[ EVENT_TIME ][ 0 ] || g_iSettings[ EVENT_TIME ][ 1 ] )
	{
		new szOnMessage[ MAX_FMT_LENGTH ], szOffMessage[ MAX_FMT_LENGTH ];
		parse( g_iSettings[ MESSAGE_EVENT ], szOnMessage, charsmax( szOnMessage ), szOffMessage, charsmax( szOffMessage ) )
		
		if( ( g_bEventTime = IsVipHour( g_iSettings[ EVENT_TIME ][ 0 ], g_iSettings[ EVENT_TIME ][ 1 ] ) ) )
		{
			g_iPData[ id ][ VIP ] |= g_iSettings[ EVENT_FLAGS ]; // Add the event flags to all players
			CC_SendMessage( id, szOnMessage );
		}
		else
		{
			g_iPData[ id ][ VIP ] &= ~g_iSettings[ EVENT_FLAGS ]; // remove the event flags from all players
			CheckPlayerVIP( id ); // Check if this user has these flags removed
			CC_SendMessage( id, szOffMessage );
		}
		
		ExecuteForward( g_iForwards[ VIPEvent ], g_iForwards[ Result ], id, g_iSettings[ EVENT_TIME ][ 0 ], g_iSettings[ EVENT_TIME ][ 1 ], g_iSettings[ EVENT_FLAGS ], g_bEventTime )
	}	
}

@OnVipsList( id )
{
	new szBuffer[ MAX_FMT_LENGTH ], szPlayers[ MAX_PLAYERS ], iNum;

	get_players( szPlayers, iNum, "ch" );
	
	for( new iIndex, i; i < iNum; i++ )
	{
		if( g_iPData[ ( iIndex = szPlayers[ i ] ) ][ VIP ] & g_iSettings[ ACCESS_VIP_LIST ] )
		{
			add( szBuffer, charsmax( szBuffer ), g_iPData[ iIndex ][ Name ] );
			add( szBuffer, charsmax( szBuffer ), i == iNum - 1 ? "." : ", " );
		}
	}
	
	CC_SendMessage( id, szBuffer[ 0 ] != EOS ? szBuffer : "%L", id, "NO_VIPS" );
}

@OnAddNewVIP( id )
{
	if( ~g_iPData[ id ][ VIP ] & g_iSettings[ ACCESS_ADD_VIP ] )
	{
		PrintToConsole( id, "%L", id, "NO_ACCESS" )
		return PLUGIN_HANDLED;
	}

	if( read_argc( ) < 4 )
	{
		PrintToConsole( id, "%L", id, "USAGE_ADD_VIP" )
		return PLUGIN_HANDLED;
	}

	new szPlayerID[ MAX_AUTHID_LENGTH ], szPlayerPassword[ 32 ], szPlayerFlags[ MAX_FLAGS_LENGTH ], szPlayerExpire[ MAX_DATE_LENGTH ];
	
	read_argv( 1, szPlayerID, charsmax( szPlayerID ) );
	read_argv( 2, szPlayerPassword, charsmax( szPlayerPassword ) );
	read_argv( 3, szPlayerFlags, charsmax( szPlayerFlags ) );
	read_argv( 4, szPlayerExpire, charsmax( szPlayerExpire ) );
	
	if( ( strlen( szPlayerID ) < 3 ) || !strlen( szPlayerFlags ) || is_str_num( szPlayerFlags ) )
	{
		PrintToConsole( id, "%L", id, "INCORRECT_FORMAT" );
		goto @FailedAddition;
	}
	
	if( str_to_num( szPlayerExpire ) )
	{
		new szDate[ MAX_DATE_LENGTH ];
		get_time( g_iSettings[ EXPIRATION_DATE_FORMAT ], szDate, charsmax( szDate ) );
		AddToDate( szDate, str_to_num( szPlayerExpire ), szPlayerExpire, charsmax( szPlayerExpire ) );
		trim( szPlayerExpire );
	}
	else szPlayerExpire = "permanently";
						
	new g_szFile[ 128 ];
	formatex( g_szFile, charsmax( g_szFile ), "%s/%s", g_szConfigs, g_iSettings[ ACCOUNT_FILE ] )
	
	new iFile = fopen( g_szFile, "r+" ); 

	new szByteVal[ 1 ], szNewLine[ 128 ]; 
	
	fseek( iFile , -1 , SEEK_END ); 
	fread_raw( iFile , szByteVal , sizeof( szByteVal ) , BLOCK_BYTE ); 
	fseek( iFile , 0 , SEEK_END ); 
	
	formatex( szNewLine , charsmax( szNewLine ) , "%s^"%s^" ^"%s^" ^"%s^" ^"%s^"" , ( szByteVal[ 0 ] == 10 ) ? "" : "^n", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );

	if( TrieKeyExists( g_tDatabase, szPlayerID ) )
	{
		PrintToConsole( id, "%L", id, "VIP_EXISTS", szPlayerID );
		goto @FailedAddition;
	}
		
	fprintf( iFile, szNewLine );
	fclose( iFile );  

	PrintToConsole( id, "%L", id, "ADDED_VIP", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );
		
	ExecuteForward( g_iForwards[ VIPAdded ], g_iForwards[ Result ], szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );
	
	OnReloadFile( );
	@FailedAddition:
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
						copy( g_iSettings[ PREFIX_CHAT ], charsmax( g_iSettings[ PREFIX_CHAT ] ), szValue );
						CC_SetPrefix( g_iSettings[ PREFIX_CHAT ] );
					}
					else if( equal( szKey, "SQL_HOST" ) )
					{
						copy( g_iSettings[SQL_HOST], charsmax( g_iSettings[SQL_HOST] ), szValue );
					}
					else if( equal( szKey, "SQL_USER" ) )
					{
						copy( g_iSettings[ SQL_USER ], charsmax( g_iSettings[ SQL_USER ] ), szValue );
					}
					else if( equal( szKey, "SQL_PASS" ) )
					{
						copy( g_iSettings[ SQL_PASS ], charsmax( g_iSettings[ SQL_PASS ] ), szValue );
					}
					else if( equal( szKey, "SQL_DATABASE" ) )
					{
						copy( g_iSettings[ SQL_DATABASE ], charsmax( g_iSettings[ SQL_DATABASE ] ), szValue );
					}
					else if( equal( szKey, "SQL_TABLE" ) )
					{
						copy( g_iSettings[ SQL_TABLE ], charsmax( g_iSettings[ SQL_TABLE ] ), szValue );
					}
					else if( equal( szKey, "USE_SQL" ) )
					{
						g_iSettings[ USE_SQL ] = _:clamp( str_to_num( szValue ), ConfingFile, SQLite );
					}
					else if( equal( szKey, "ACCOUNT_FILE" ) )
					{
						copy( g_iSettings[ ACCOUNT_FILE ], charsmax( g_iSettings[ ACCOUNT_FILE ] ), szValue )
					}
					else if( equal( szKey, "CONNECT_MESSAGE" ) )
					{
						copy( g_iSettings[ MESSAGE_CONNECT ], charsmax( g_iSettings[ MESSAGE_CONNECT ] ), szValue )
					}
					else if( equal( szKey, "EVENT_MESSAGE" ) )
					{
						copy( g_iSettings[ MESSAGE_EVENT ], charsmax( g_iSettings[ MESSAGE_EVENT ] ), szValue )
					}
					else if( equal( szKey, "EXPIRATION_DATE_TYPE" ) )
					{
						switch( szValue[ 0 ] )
						{
							case 'h', 'H': g_iDateSeconds = 3600;
							case 'd', 'D': g_iDateSeconds = 86400;
							case 'w', 'W': g_iDateSeconds = 604800;
							case 'm', 'M': g_iDateSeconds = 2592000;
							case 'y', 'Y': g_iDateSeconds = 31536000;
						}
						copy( g_iSettings[ EXPIRATION_DATE_TYPE ], charsmax( g_iSettings[ EXPIRATION_DATE_TYPE ] ), szValue )
					}
					else if( equal( szKey, "DEFAULT_FLAGS" ) )
					{
						g_iSettings[ DEFAULT_FLAGS ] = !is_str_num( szValue ) ? read_flags( szValue ) : read_flags( "yz" );
					}
					else if( equal( szKey, "EXPIRATION_DATE_FORMAT" ) )
					{
						copy( g_iSettings[ EXPIRATION_DATE_FORMAT ], charsmax( g_iSettings[ EXPIRATION_DATE_FORMAT ] ), szValue )
					}
					else if( equal( szKey, "EXPIRATION_DATE_BEHAVIOR" ) )
					{
						g_iSettings[EXPIRATION_DATE_BEHAVIOR] = clamp( str_to_num( szValue ), EDB_IGNORE, EDB_REMOVE );
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
						g_iSettings[ ACCESS_ADD_VIP ] = szValue[ 0 ] != '0' ? read_flags( szValue ) : ~read_flags( "z" )
					}
					else if( equal( szKey, "ACCESS_SCOREBOARD" ) )
					{
						g_iSettings[ ACCESS_SCOREBOARD ] = szValue[ 0 ] != '0' ? read_flags( szValue ) : ~read_flags( "z" )
					}
					else if( equal( szKey, "ACCESS_CONNECT_MESSAGE" ) )
					{
						g_iSettings[ ACCESS_CONNECT_MESSAGE ] = szValue[ 0 ] != '0' ? read_flags( szValue ) : ~read_flags( "z" )
					}
					else if( equal( szKey, "ACCESS_VIP_LIST" ) )
					{
						g_iSettings[ ACCESS_VIP_LIST ] = szValue[ 0 ] != '0' ? read_flags( szValue ) : ~read_flags( "z" )
					}
					else if( equal( szKey, "EVENT_FLAGS" ) )
					{
						g_iSettings[ EVENT_FLAGS ] = read_flags( szValue );
					}
					else if( equal( szKey, "EVENT_TIME" ) )
					{
						new szTime[ 2 ][ 3 ];
						parse( szValue, szTime[ 0 ], charsmax( szTime[ ] ), szTime[ 1 ], charsmax( szTime[ ] ) )
						
						for( new i ; i < 2; i++ )
						{
							g_iSettings[ EVENT_TIME ][ i ] = _:clamp( str_to_num( szTime[ i ] ), 00, 24 );
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
}

ReadAccounts( )
{
	if( g_iSettings[ USE_SQL ] ) // Create Sql file
	{
		if( g_iSettings[ USE_SQL ] == SQLite )
			SQL_SetAffinity( "sqlite" );
				
		g_SQLTuple = SQL_MakeDbTuple( g_iSettings[ SQL_HOST ], g_iSettings[ SQL_USER ], g_iSettings[ SQL_PASS ], g_iSettings[ SQL_DATABASE ] );
			      
		new iErrorCode;
		g_iSQLConnection = SQL_Connect( g_SQLTuple, iErrorCode, g_szSQLError, charsmax( g_szSQLError ) );
		    
		server_print( "Sql connect %i", g_iSQLConnection );
		
		if( g_iSQLConnection == Empty_Handle )
			set_fail_state( g_szSQLError );
		
		new Handle:iQuery = SQL_PrepareQuery( g_iSQLConnection , "CREATE TABLE IF NOT EXISTS `%s` (`Identity` VARCHAR(%i) NOT NULL,\
		`Password` VARCHAR(%i) NOT NULL, `Access` VARCHAR(%i) NOT NULL, `ExpireDate` VARCHAR(%i) NOT NULL, PRIMARY KEY(Identity));",\
		g_iSettings[ SQL_TABLE ], MAX_AUTHID_LENGTH, MAX_PASSWORD_LENGTH, MAX_FLAGS_LENGTH, MAX_FLAGS_LENGTH );
	
		if( !SQL_Execute( iQuery ) )
		{
			SQL_QueryError( iQuery, g_szSQLError, charsmax( g_szSQLError ) );
			set_fail_state( g_szSQLError );
		}
		
		SQL_FreeHandle( iQuery );
	}
	
	g_tDatabase = TrieCreate( );
	
	CC_RemoveColors( g_iSettings[ PREFIX_CHAT ], charsmax( g_iSettings[ PREFIX_CHAT ] ) );
		
	new szFile[ 128 ];
	
	formatex( szFile, charsmax( szFile ), "%s/%s", g_szConfigs, g_iSettings[ ACCOUNT_FILE ] )
	
	new iFilePointer = fopen( szFile, "rt" );
	
	if( iFilePointer )
	{
		new szData[ MAX_FILE_LENGTH ]
		
		while( fgets( iFilePointer, szData, charsmax( szData ) ) )
		{    
			trim( szData );
			
			g_iFileContents++;
			ArrayPushString( g_aFileContents, szData );

			switch( szData[ 0 ] )
			{
				case EOS, '#', ';', '/': continue;

				default:
				{
					if( parse( szData, eData[ Player_Identity ], charsmax( eData[ Player_Identity ] ), eData[ Player_Password ], charsmax( eData[ Player_Password ] ), eData[ Player_Access ], charsmax( eData[ Player_Access ] ), eData[ Player_Expire_Date ], charsmax( eData[ Player_Expire_Date ] ) ) < 3 ) continue;
					
					if( IsDateExpired( eData[ Player_Expire_Date ] ) )
					{
						continue;
					}
					
					if( eData[ Player_Identity ][ 0 ] )
					{
						if( g_iSettings[ USE_SQL ] ) // Save the cofing file date into the Sql file
						{		
							new Handle:iQuery = SQL_PrepareQuery( g_iSQLConnection, "SELECT * FROM `%s` WHERE (`Identity` = '%s');", g_iSettings[ SQL_TABLE ], eData[ Player_Identity ] );
		
							if( !SQL_Execute( iQuery ) )
							{
								SQL_QueryError( iQuery, g_szSQLError, charsmax( g_szSQLError ) );
								set_fail_state( g_szSQLError );
							}
							else if ( SQL_NumResults( iQuery ) ) 
							{
								log_amx( "%s %L", g_iSettings[ PREFIX_CHAT ], LANG_SERVER, "VIP_EXISTS", eData[ Player_Identity ] );
							}
							else
							{
								SQL_QueryAndIgnore( g_iSQLConnection, "REPLACE INTO `%s` (`Identity`, `Password`, `Access`, `ExpireDate`) VALUES ( '%s', '%s', '%s', '%s');",\
								g_iSettings[ SQL_TABLE ], eData[ Player_Identity ], eData[ Player_Password ], eData[ Player_Access ], eData[ Player_Expire_Date ] );
							}
						
							SQL_FreeHandle( iQuery );
						}
						else TrieSetArray( g_tDatabase, eData[ Player_Identity ], eData, sizeof eData );
					}
					
					arrayset( eData, 0, sizeof( eData ) );
				}
			}
		}
		fclose( iFilePointer );
	}
	else log_amx( "File %s does not exists", szFile );

	if( g_iSettings[ USE_SQL ] ) // Loads the data from Sql and store it
	{
		new Handle:iQuery = SQL_PrepareQuery( g_iSQLConnection , "SELECT `Identity`, `Password`, `Access`, `ExpireDate` FROM `%s`;", g_iSettings[ SQL_TABLE ] );
	
		if( !SQL_Execute( iQuery ) )
		{
			SQL_QueryError( iQuery, g_szSQLError, charsmax( g_szSQLError ) );
			set_fail_state( g_szSQLError );
		}
		else if ( !SQL_NumResults( iQuery ) ) 
		{
			log_amx( "%s %s", g_iSettings[ PREFIX_CHAT ], "NO_VIPS" );
		}
		else
		{
			while( SQL_MoreResults( iQuery ) )
			{
				SQL_ReadResult( iQuery, SQL_FieldNameToNum(iQuery, "Identity" ), eData[ Player_Identity ], charsmax( eData[ Player_Identity ] ) );
				SQL_ReadResult( iQuery, SQL_FieldNameToNum(iQuery, "Password" ), eData[ Player_Password ], charsmax( eData[ Player_Password ] ) );
				SQL_ReadResult( iQuery, SQL_FieldNameToNum(iQuery, "Access" ), eData[ Player_Access ], charsmax( eData[ Player_Access ] ) );
				SQL_ReadResult( iQuery, SQL_FieldNameToNum(iQuery, "ExpireDate" ), eData[ Player_Expire_Date ], charsmax( eData[ Player_Expire_Date ] ) );
						
				if( IsDateExpired( eData[ Player_Expire_Date ] ) )
				{
					continue;
				}
				
				if( eData[ Player_Identity ][ 0 ] )
				{
					TrieSetArray( g_tDatabase, eData[ Player_Identity ], eData, sizeof eData );		
				}
				
				arrayset( eData, 0, sizeof( eData ) );
				
				SQL_NextRow( iQuery );
			}
		}
		
		SQL_FreeHandle( iQuery );
	}
	
	if( g_bUserExpired && g_iSettings[ EXPIRATION_DATE_BEHAVIOR ] != EDB_IGNORE )
	{
		iFilePointer = fopen( szFile, "w" )
	
		for( new i; i < g_iFileContents + 1; i++ ) 
		{
			fprintf( iFilePointer, "%a", ArrayGetStringHandle( g_aFileContents, i ) )	
			
			if( i < g_iFileContents )
			{
				fprintf( iFilePointer, "^n" )
			}
		}
	
		fclose( iFilePointer );
	}
	
	if( TrieGetSize( g_tDatabase ) ) server_print( "%s %L", g_iSettings[ PREFIX_CHAT ], LANG_SERVER, "VIP_LAODED", TrieGetSize( g_tDatabase ) )
}

bool:IsDateExpired( const szDate[ ] )
{
	if( is_str_num( szDate ) || !szDate[ 0 ] )
	{
		return false;
	}
	
	if( parse_time( szDate, g_iSettings[ EXPIRATION_DATE_FORMAT ] ) < get_systime( ) )
	{
		switch( g_iSettings[ EXPIRATION_DATE_BEHAVIOR ] )
		{
			case EDB_COMMENT:
			{
				static szData[ 192 ];
				formatex( szData, charsmax( szData ), "# %a", ArrayGetStringHandle( g_aFileContents, g_iFileContents ) )
				ArraySetString( g_aFileContents, g_iFileContents, szData );
			}
			case EDB_REMOVE:
			{
				ArrayDeleteItem( g_aFileContents, g_iFileContents-- );
			}
		}
		g_bUserExpired = true;
		return true;
	}
	
	return false;
}

AddToDate( const szDate[ ], const iMinutes, szReturnDate[ ], const iSize )
{
	new const iSecondsInMinute = g_iDateSeconds;
	
	new iCurrentTimeStamp = parse_time( szDate, g_iSettings[ EXPIRATION_DATE_FORMAT ] );
	iCurrentTimeStamp = iCurrentTimeStamp + ( iMinutes * iSecondsInMinute );
	format_time( szReturnDate, iSize, g_iSettings[ EXPIRATION_DATE_FORMAT ], iCurrentTimeStamp );
}

bool:IsVipHour( iStart, iEnd )
{
	new iHour; time( iHour );
	return bool:( iStart < iEnd ? ( iStart <= iHour < iEnd ) : ( iStart <= iHour || iHour < iEnd ) )
} 

GetExpireDate( const id, szExpire[ ], iLen )
{
	if( IsUserExist( id ) )
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

public plugin_natives( )
{
	register_library( "vip" )
	register_native( "get_vip_prefix", "_get_vip_chat_prefix" )
	register_native( "get_expire_date", "_get_expire_date" )
	register_native( "get_expire_type", "_get_expire_format_type" )
	register_native( "add_user_vip", "_add_user_vip" )
	register_native( "get_user_vip", "_get_user_vip" )
	register_native( "set_user_vip", "_set_user_vip" )
	register_native( "is_user_vip", "_is_user_vip" )
	register_native( "is_event_time", "_is_event_time" )
	register_native( "remove_user_vip", "_remove_user_vip" );
	register_native( "reload_vip", "_reload_vip" );
}

public _reload_vip( iPlugin, iParams )
{
	OnReloadFile( );
}

public _get_vip_chat_prefix( iPlugin, iParams )
{
	set_string( 1, g_iSettings[ PREFIX_CHAT ], get_param( 2 ) )
}

public _get_expire_format_type( iPlugin, iParams )
{
	set_string( 1, g_iSettings[ EXPIRATION_DATE_TYPE ], get_param( 2 ) )
}

public _get_expire_date( iPlugin, iParams )
{
	new szExpire[ MAX_FLAGS_LENGTH ];
	GetExpireDate( get_param( 1 ), szExpire, charsmax( szExpire ) )
	set_string( 2, szExpire, get_param( 3 ) )
}

public bool:_is_event_time( iPlugin, iParams )
{
	return g_bEventTime;
}

public bool:_is_user_vip( iPlugin, iParams )
{
	new _iFlag = g_iPData[ get_param( 1 ) ][ VIP ];
	return ( _iFlag && !( _iFlag & read_flags( "z" ) ) );
}

public _remove_user_vip( iPlugin, iParams )
{
	g_iPData[ get_param( 1 ) ][ VIP ] &= ~ get_param( 2 );
}

public _get_user_vip( iPlugin, iParams )
{
	return g_iPData[ get_param( 1 ) ][ VIP ];
}

public _set_user_vip( iPlugin, iParams )
{
	g_iPData[ get_param( 1 ) ][ VIP ] |= get_param( 2 ); 
}

public _add_user_vip( iPlugin, iParams )
{
	new szPlayerID[ MAX_AUTHID_LENGTH ], szPlayerPassword[ 32 ], szPlayerFlags[ MAX_FLAGS_LENGTH ], szPlayerExpire[ MAX_DATE_LENGTH ], iDate;
	
	get_string( 1, szPlayerID, charsmax( szPlayerID ) );
	get_string( 2, szPlayerPassword, charsmax( szPlayerPassword ) );
	get_string( 3, szPlayerFlags, charsmax( szPlayerFlags ) );
	iDate = get_param( 4 );
	
	if( iDate )
	{
		get_time( g_iSettings[ EXPIRATION_DATE_FORMAT ], szPlayerExpire, charsmax( szPlayerExpire ) );
		AddToDate( szPlayerExpire, str_to_num( szPlayerExpire ), szPlayerExpire, charsmax( szPlayerExpire ) );
		trim( szPlayerExpire );
	}
	else szPlayerExpire = "permanently";
		
	new g_szFile[ 128 ];
	formatex( g_szFile, charsmax( g_szFile ), "%s/%s", g_szConfigs, g_iSettings[ ACCOUNT_FILE ] )
	
	new iFile = fopen( g_szFile, "r+" );

	new szByteVal[ 1 ], szNewLine[ 128 ];
	
	fseek( iFile , -1 , SEEK_END );
	fread_raw( iFile , szByteVal , sizeof( szByteVal ) , BLOCK_BYTE );
	fseek( iFile , 0 , SEEK_END );
	
	formatex( szNewLine , charsmax( szNewLine ) , "%s^"%s^" ^"%s^" ^"%s^" ^"%s^"" , ( szByteVal[ 0 ] == 10 ) ? "" : "^n", szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );
	
	if( TrieKeyExists( g_tDatabase, szPlayerID ) )
	{
		log_amx( "%L", LANG_SERVER, "VIP_EXISTS", szPlayerID );
		return;
	}
	
	fprintf( iFile, szNewLine );
	fclose( iFile );
	OnReloadFile( );
	ExecuteForward( g_iForwards[ VIPAdded ], g_iForwards[ Result ], szPlayerID, szPlayerPassword, szPlayerFlags, szPlayerExpire );
}	

PrintToConsole( const id, const szMessage[ ], any:... )
{
	new szArg[ MAX_FMT_LENGTH ];
	vformat( szArg, charsmax( szArg ), szMessage, 3 );
	CC_RemoveColors( g_iSettings[ PREFIX_CHAT ], charsmax( g_iSettings[ PREFIX_CHAT ] ) );
	console_print( id, "%s %s", g_iSettings[ PREFIX_CHAT ], szArg  );
}
