#include <amxmodx>
#include <cstrike>
#include <vip>
#include <vip_const>
#include <cromchat>

#define GetValue(%1) cs_get_user_money(%1)
#define SetValue(%1,%2) cs_set_user_money(%1,%2)

enum TotalCvars
{
	Price,
	FlagsBits[ MAX_FLAGS_LENGTH ],
	Expiration
}

new g_iCvar[ TotalCvars ], g_iAuthentication[ MAX_PLAYERS + 1 ], iMenuCallBack; 
new g_szPassword[ MAX_PLAYERS + 1 ][ MAX_PASSWORD_LENGTH ];

public plugin_init( )
{
	register_plugin( "VIP: Buy Account", "1.0", "Supremache" )
	
	new szPrefix[ 2 ][ 32 ];
	get_vip_prefix( szPrefix[ 0 ], charsmax( szPrefix[ ] ) );
	formatex( szPrefix[ 1 ], charsmax( szPrefix[ ] ), "^4%s", szPrefix[ 0 ] )
	CC_SetPrefix( szPrefix[ 1 ] );
	
	register_clcmd( "GeneratePassword", "@GeneratePassword" );
	register_clcmd( "say /buyvip", "AccountMenu" );
	register_clcmd( "say_team /buyvip", "AccountMenu" );
	
	bind_pcvar_num( create_cvar( "vip_buy_price", "16000" , .description = "Account cost." ), g_iCvar[ Price ] )
	bind_pcvar_string( create_cvar( "vip_buy_flag", "abc", .description = "Account flags." ), g_iCvar[ FlagsBits ], charsmax( g_iCvar[ FlagsBits ] ) )
	bind_pcvar_num( create_cvar( "vip_buy_expire", "7", .description = "The expire date." ), g_iCvar[ Expiration ] )

	iMenuCallBack = menu_makecallback( "MenuCallBack" )
}

public client_connect( id )
{
	g_iAuthentication[ id ] = 4; // Set SteamID as default
}

public MenuCallBack( id, iMenu, iItem ) 
{
	return ( GetValue( id ) < g_iCvar[ Price ] || is_user_vip( id ) ) ? ITEM_DISABLED : ITEM_IGNORE;
}

public AccountMenu( id )
{
	new szMenuData[ MAX_MENU_LENGTH ], szExpireType[ MAX_DATE_LENGTH ], szColor[ 3 ], iMenu = menu_create( "Buy a VIP account:", "AccountHandler" );
	
	szColor = ( GetValue( id ) < g_iCvar[ Price ] || is_user_vip( id ) ) ? "\r" : "\y"

	formatex( szMenuData, charsmax( szMenuData ), "%sâ€¢\w Account Flags:%s %s", szColor, szColor, g_iCvar[ FlagsBits ] )
	menu_addtext2( iMenu, szMenuData );
	
	formatex( szMenuData, charsmax( szMenuData ), "%sâ€¢\w Price:%s %i", szColor, szColor, g_iCvar[ Price ] )
	menu_addtext2( iMenu, szMenuData );
	
	get_expire_type( szExpireType, charsmax( szExpireType ) );
	formatex( szMenuData, charsmax( szMenuData ), "%sâ€¢\w Expiration:%s %i %s^n^n\y>> Choose your authentication:", szColor, szColor, g_iCvar[ Expiration ], szExpireType )
	menu_addtext2( iMenu, szMenuData );

	if( g_szPassword[ id ][ 0 ] != EOS )
	{
		formatex(  szMenuData, charsmax( szMenuData ), "Nick + Password %s \r(\wPw:\y %s\r)", g_iAuthentication[ id ] != 3 ? "\r(Settings)" : "\y*", g_szPassword[ id ] );
	}
	else formatex(  szMenuData, charsmax( szMenuData ), "Nick + Password %s", g_iAuthentication[ id ] != 3 ? "\r(Settings)" : "\y*" );
	
	menu_additem( iMenu, szMenuData, .callback = iMenuCallBack )
	
	formatex(  szMenuData, charsmax( szMenuData ), "SteamID %s", g_iAuthentication[ id ] != 4 ? "\r(Buy)" : "\y*" );
	menu_additem( iMenu, szMenuData, .callback = iMenuCallBack )
	
	formatex(  szMenuData, charsmax( szMenuData ), "IP adress %s", g_iAuthentication[ id ] != 5 ? "\r(Buy)" : "\y*" );
	menu_additem( iMenu, szMenuData, .callback = iMenuCallBack )

	menu_addblank2( iMenu );
	formatex(  szMenuData, charsmax( szMenuData ), "Get Selection \y(%i)", g_iAuthentication[ id ] + 1 );
	menu_additem( iMenu, szMenuData, .callback = iMenuCallBack )
	menu_addblank2( iMenu );
	menu_additem( iMenu, "Close" )
	menu_setprop( iMenu, MPROP_PERPAGE, 0 );
	menu_display( id, iMenu );
}

public AccountHandler( id, iMenu, iItem ) 
{
	if(iItem != MENU_EXIT )
	{
		if( is_user_vip( id ) )
		{
			CC_SendMessage( id, "You already have a VIP account" );
			goto @Destroy;
		}
		
		if( GetValue( id ) < g_iCvar[ Price ] )
		{
			CC_SendMessage( id, "You dont have enought money." );
			goto @Destroy;
		}
		new szIdentity[ MAX_AUTHID_LENGTH ], szExpireType[ MAX_FLAGS_LENGTH ];
		
		switch( g_iAuthentication[ id ] )
		{
			case 3: get_user_name( id, szIdentity, charsmax( szIdentity ) );
			case 4: get_user_authid( id, szIdentity, charsmax( szIdentity ) );
			case 5: get_user_ip( id, szIdentity, charsmax( szIdentity ), 1 );
		}
		
		switch( iItem )
		{
			case 3, 4, 5:
			{
				g_szPassword[ id ][ 0 ] = EOS;
				g_iAuthentication[ id ] = iItem;
				if( iItem == 3 )
				{
					client_cmd( id, "messagemode GeneratePassword");
				}
			}
			default:
			{
				add_user_vip( szIdentity, g_szPassword[ id ], g_iCvar[ FlagsBits ], g_iCvar[ Expiration ] )
				SetValue( id, GetValue( id ) - g_iCvar[ Price ] ) 
				get_expire_type( szExpireType, charsmax( szExpireType ) )
				CC_SendMessage( id, "Congratulations, you have successfully purchased^4 a VIP account^1 for^4 %i %s", g_iCvar[ Expiration ], szExpireType );
			}
		}
	}
	
	@Destroy:
	menu_destroy( iMenu );
	return PLUGIN_HANDLED;
}

@GeneratePassword( id )
{
	read_args( g_szPassword[ id ], charsmax( g_szPassword[ ] ) );
	remove_quotes( g_szPassword[ id ] );
	
	if( ( strlen( g_szPassword[ id ] ) < 3 ) )
	{
		CC_SendMessage( id, "Type a the password or type ^"random^" to get a random password." );
		client_cmd( id, "messagemode GeneratePassword");
	}
	else
	{
		if( equal( g_szPassword[ id ], "random" ) || equal( g_szPassword[ id ], "Random" ) )
		{
			formatex( g_szPassword[ id ], charsmax( g_szPassword[ ] ), "%c%d%d", random_num( 'a','z' ), random( 100 ), random( 100 ) )
		}
		new szPasswordField[ MAX_PASSWORD_LENGTH ];
		get_cvar_string( "amx_password_field", szPasswordField, charsmax( szPasswordField ) )
		set_user_info( id, szPasswordField[ 0 ] ? szPasswordField : "_pw", g_szPassword[ id ] );
		CC_SendMessage( id, "Your Password is:^4 %s", g_szPassword[ id ] );
		AccountMenu( id );
	}
}
