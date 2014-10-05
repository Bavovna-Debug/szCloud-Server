#$query = $res->search($host, , 'A');
#if (defined($query) && ($query->answer)) {
#	foreach $ip ($query->answer) {
#		print "IPv4: " . $ip->address, "\n";
#	}
#}

#$query = $res->search($host, , 'AAAA');
#if (defined($query) && ($query->answer)) {
#	foreach $ip ($query->answer) {
#		print "IPv6: " . $ip->address, "\n";
#	}
#}

#$query = $res->search($host, , 'CNAME');
#if (defined($query) && ($query->answer)) {
#	foreach $cname ($query->answer) {
#		print "CNAME: " . $cname->address, "\n";
#	}
#}

#$query = $res->query($host, , 'NS');
#if (defined($query) && defined($query->answer)) {
#	foreach $nameserver ($query->answer) {
#		print "NS: " . $nameserver->nsdname, "\n";
#	}
#}

#$query = $res->query($host, 'MX');
#if (defined($query) && defined($query->answer)) {
#	foreach $mxhost ($query->answer) {
#		print "MX: " . $mxhost->preference . " - " . $mxhost->exchange . "\n";
#	}
#}

#$query = $res->query($host, 'SOA');
#if (defined($query) && defined($query->answer)) {
#	foreach $x ($query->answer) {
#		print "SOA: ";
#		$x->print;
#	}
#}
