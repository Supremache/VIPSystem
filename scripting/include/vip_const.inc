#if defined _vip_const_included
    #endinput
#endif

#define _vip_const_included

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

#if !defined MAX_RESOURCE_PATH_LENGTH
	const MAX_RESOURCE_PATH_LENGTH = 64
#endif

const MAX_FLAGS_LENGTH = 26;
const MAX_DATE_LENGTH = 32;
const MAX_PASSWORD_LENGTH = 32;
const MAX_FILE_LENGTH = 512;
const MAX_QUERY_LENGTH = 256;
