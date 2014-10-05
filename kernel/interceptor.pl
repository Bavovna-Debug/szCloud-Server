#!/usr/bin/perl

require 'configuration.pl';
require 'procurator.pl';
require 'logs.pl';
require 'files.pl';

use DBI;
use Time::Piece;

# MySQL authorisation data.
#
use constant dbDatabase	=> 'DBI:mysql:cloud_bender';
use constant dbUsername	=> 'cloud';
use constant dbPassword	=> 'Nebula15';

exitIfAlreadyRunning('interceptor');

$originator = 'INTRCPTR';

# Since now activate our own die()-handler.
#
$SIG{__DIE__}  = 'signalDieHandler';
$SIG{HUP} = "signalKillHandler";

logInfo("Start INTERCEPTOR");

while (1) { goThrough(); sleep(60); }

#
# Common routine to be called in case of error.
#
sub signalDieHandler
{
	my($message) = @_;
	logError($message);
	exit;
}

#
# Common routine to be called in case program becomes a signal.
#
sub signalKillHandler
{
	goThrough();
}

my $lock: shared;

sub goThrough
{
	lock $lock;

	# Establish connection to MySQL and select a database.
	#
	my $dbh = DBI->connect_cached(dbDatabase, dbUsername, dbPassword,
		{ AutoCommit => 1, PrintError => 1 });

	die "DBI-connect: $DBI::errstr"
		if (defined $DBI::err) and ($DBI::err != 0);

	my($sql, $sthOuter, $sthInner);

	$sql = qq{
		SELECT event_id, message
		FROM cloud_logger.log_update
			USE INDEX (idx_touched)
		WHERE touched IS FALSE
	};
	$sthOuter = $dbh->prepare($sql)
		or die $DBI::errstr;

	$sthOuter->execute()
		or die $DBI::errstr;

	while (my($eventId, $message) = $sthOuter->fetchrow_array())
	{
		chomp $message;

		$sql = qq{
			UPDATE LOW_PRIORITY cloud_logger.log_update
			SET touched = TRUE
			WHERE event_id = ?
		};
		$sthInner = $dbh->prepare($sql)
			or die $DBI::errstr;

		$sthInner->execute($eventId)
			or die $DBI::errstr;

		next if $sthInner->rows() == 0;

		my $stamp = substr $message, 0, 20;
		my $milliseconds = substr $message, 21, 3;
		$stamp = Time::Piece->strptime($stamp, '%d-%b-%Y %H:%M:%S')->strftime('%Y-%m-%d %H:%M:%S');

		my $rest = substr $message, 25;
		my @parts = split /: /, $rest;

		my $level = $parts[0];
		next if ($level cmp 'info') != 0;

		my @clientParts = split / /, $parts[1];
		my($clientIp, $clientPort) = split /#/, $clientParts[1];

		my @zoneParts = split / /, $parts[2];
		my $zoneName = $zoneParts[2];
		$zoneName =~ s/'//g;
		$zoneName = substr $zoneName, 0, length($zoneName) - 3;
		$sql = qq{
			SELECT hash_id
			FROM cloud_bender.hash_repository
			WHERE full_name LIKE ?
		};
		my $zoneId = $dbh->selectrow_array($sql, undef, $zoneName);

		next unless defined $zoneId;

		my @operationParts = split / /, $parts[3];
		my $operation = $operationParts[0];
		my $updateType;
		if ((substr($parts[3], 0, 12) cmp 'adding an RR') == 0)
		{
			$updateType = 'ADDRR';
		}
		elsif ((substr($parts[3], 0, 14) cmp 'deleting an RR') == 0)
		{
			$updateType = 'DELRR';
		}
		elsif ((substr($parts[3], 0, 14) cmp 'deleting rrset') == 0)
		{
			$updateType = 'DELRRSET';
		}
		elsif ((substr($parts[3], 0, 13) cmp 'update failed') == 0)
		{
			my $reason = $parts[4];

			$sql = qq{
				INSERT LOW_PRIORITY
				INTO cloud_bender.dns_rejects
					(stamp, milliseconds, zone_id, client_ip, client_port, reason)
				VALUES (?, ?, ?, ?, ?, ?)
			};
			$dbh->do($sql, undef, $stamp, $milliseconds, $zoneId, $clientIp, $clientPort, $reason)
				or die $DBI::errstr;

			$sql = qq{
				UPDATE LOW_PRIORITY cloud_logger.log_update
				SET processed = TRUE
				WHERE event_id = ?
			};
			$dbh->do($sql, undef, $eventId)
				or die $DBI::errstr;

			next;
		}
		else
		{
			$sql = qq{
				UPDATE LOW_PRIORITY cloud_logger.log_update
				SET skipped = TRUE
				WHERE event_id = ?
			};
			$dbh->do($sql, undef, $eventId)
				or die $DBI::errstr;

			next;
		}

		my $dnsType = $operationParts[$#operationParts];

		my $hashName = $operationParts[$#operationParts - 1];
		$hashName =~ s/'//g;
		$sql = qq{
			SELECT hash_id
			FROM cloud_bender.hash_repository
			WHERE full_name LIKE ?
		};
		my $hashId = $dbh->selectrow_array($sql, undef, $hashName)
			or die $DBI::errstr;

		$sql = qq{
			UPDATE LOW_PRIORITY cloud_bender.clouds
				USE INDEX (idx_hash_id)
			SET need_dns_revalidation = TRUE
			WHERE hash_id = ?
		};
		$dbh->do($sql, undef, $zoneId)
			or die $DBI::errstr;

		$sql = qq{
			UPDATE LOW_PRIORITY cloud_bender.hosts
				USE INDEX (idx_hash_id)
			SET need_dns_revalidation = TRUE
			WHERE hash_id = ?
		};
		$dbh->do($sql, undef, $hashId)
			or die $DBI::errstr;

		$sql = qq{
			INSERT LOW_PRIORITY
			INTO cloud_bender.dns_updates
				(stamp, milliseconds, zone_id, hash_id, client_ip, client_port, update_type, dns_type)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		};
		$dbh->do($sql, undef, $stamp, $milliseconds, $zoneId, $hashId, $clientIp, $clientPort, $updateType, $dnsType)
			or die $DBI::errstr;

		$sql = qq{
			UPDATE LOW_PRIORITY cloud_logger.log_update
			SET processed = TRUE
			WHERE event_id = ?
		};
		$dbh->do($sql, undef, $eventId)
			or die $DBI::errstr;

		notifyIfRunning('resolver');
	}

	# Leave MySQL connection.
	#
	$dbh->disconnect();

	return;
}
