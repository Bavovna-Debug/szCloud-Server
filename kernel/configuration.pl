# DNS server options.
#
our $nameServerIPAddress	= '78.47.11.62';
#our $nameServerIPAddress	= '192.168.178.33';
#our $nameServerIPAddress	= '9.152.224.54';
our $firstIPAddress		= '10.10.10.10';
our $defaultNameServer	= 'ns.szcloud.de';
our $defaultTTL			= 3600;

# Pathes.
#
our $bindPIDFile			= '/var/run/named/named.pid';
our $bindDirectory		= '/var/cache/bind/cloud';

our $workFilesPath		= '/var/tmp/cloud';

our $bindTopDomains		= 'named.top.conf';
our $bindSubDomains		= 'named.sub.conf';
our $configDNSSecKeys	= 'named.key.conf';
our $includeTopDomain	= 'zone.top.incl';
our $includeSubDomain	= 'zone.sub.incl';

our $templateZone			= '/opt/cloud/templates/zone.tpl';
our $templateTopDomain	= '/opt/cloud/templates/topdomain.tpl';
our $templateSubDomain	= '/opt/cloud/templates/subdomain.tpl';
our $templateDNSSecKey	= '/opt/cloud/templates/subdomain_key.tpl';
#our $templateNSUpdate	= '/opt/cloud/templates/nsupdate.tpl';

use constant listenerPIDFile	=> 'listener.pid';
use constant interceptorPIDFile	=> 'interceptor.pid';
use constant resolverPIDFile	=> 'resolver.pid';
use constant processorPIDFile	=> 'processor.pid';

1
