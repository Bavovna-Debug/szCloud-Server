# Log files of bind.
#
our %logs = (
	client => {
		TableName => 'log_client',
		FileName => '/var/log/named/client.log'
	},

	config => {
		TableName => 'log_config',
		FileName => '/var/log/named/config.log'
	},

	database => {
		TableName => 'log_database',
		FileName => '/var/log/named/database.log'
	},

	default => {
		TableName => 'log_default',
		FileName => '/var/log/named/default.log'
	},

	delegation_only => {
		TableName => 'log_delegation_only',
		FileName => '/var/log/named/delegation-only.log'
	},

	dispatch => {
		TableName => 'log_dispatch',
		FileName => '/var/log/named/dispatch.log'
	},

	dnssec => {
		TableName => 'log_dnssec',
		FileName => '/var/log/named/dnssec.log'
	},

	general => {
		TableName => 'log_general',
		FileName => '/var/log/named/general.log'
	},

	lame_servers => {
		TableName => 'log_lame_servers',
		FileName => '/var/log/named/lame-servers.log'
	},

	network => {
		TableName => 'log_network',
		FileName => '/var/log/named/network.log'
	},

	notify => {
		TableName => 'log_notify',
		FileName => '/var/log/named/notify.log'
	},

	queries => {
		TableName => 'log_queries',
		FileName => '/var/log/named/queries.log'
	},

	resolver => {
		TableName => 'log_resolver',
		FileName => '/var/log/named/resolver.log'
	},	

	security => {
		TableName => 'log_security',
		FileName => '/var/log/named/security.log'
	},

	unmatched => {
		TableName => 'log_unmatched',
		FileName => '/var/log/named/unmatched.log'
	},

	update => {
		TableName => 'log_update',
		FileName => '/var/log/named/update.log'
	},

	update_security => {
		TableName => 'log_update_security',
		FileName => '/var/log/named/update-security.log'
	},

	xfer_in => {
		TableName => 'log_xfer_in',
		FileName => '/var/log/named/xfer-in.log'
	},

	xfer_out => {
		TableName => 'log_xfer_out',
		FileName => '/var/log/named/xfer-out.log'
	}
);

1
