package CMU::LDAP::AD;

use Log::Log4perl;
use Net::DNS::Resolver;
use base ("CMU::LDAP");
use strict;
require CMU::CFG;

my $_dnssrv;
my $_ad = undef;
my $_samaccountname;

my $log = Log::Log4perl->get_logger();

sub getInstance {
	$log->debug("Calling CMU::LDAP::AD::getInstance(self)");
	if ( !defined $_ad ) {
		my $class = shift;
		my $self  = {};
		$_ad = bless $self, $class;

		CMU::CFG::readConfig('configuration.pl');

		$_ad->{_dnssrv}     = $CMU::CFG::_CFG{'AD'}{'server'};
		$_ad->{_binddn}     = $CMU::CFG::_CFG{'AD'}{'binddn'};
		$_ad->{_password}   = $CMU::CFG::_CFG{'AD'}{'password'};
		$_ad->{_port}       = $CMU::CFG::_CFG{'AD'}{'port'};
		$_ad->{_syncou}     = $CMU::CFG::_CFG{'AD'}{'syncou'};
		$_ad->{_peoplebase} = $CMU::CFG::_CFG{'AD'}{'peoplebase'};
		$_ad->{_server}     = $_ad->getPdc();
		$_ad->connect();
	}
	else {
		if ( !$_ad->isConnected() ) {
			$_ad->connect();
		}
	}
	return $_ad;
}

sub setSAMAccountName {
	my ($self, $samaccountname) = @_;
	$log->debug("Calling CMU::LDAP::AD::setSAMAccountName()");

	$self->{_samaccountname} = $samaccountname;
}


sub getPdc {
	my ($self) = @_;
	$log->debug("Calling CMU::LDAP::AD::getPdc()");

	my $res = Net::DNS::Resolver->new;

	my $query = $res->send( $self->{_dnssrv}, "SRV" );
	if ($query) {
		foreach my $rr ( $query->answer ) {
			next unless $rr->type eq 'SRV';
			return $rr->target;
		}
		$log->error("SRV lookup failed:");
		die();
	}
	else {
		$log->error( "SRV lookup failed: " + $res->errorstring );
		die();
	}
}

sub getLdapTargetName {
	my ($self) = @_;
	$log->debug("Calling CMU::LDAP::AD::getLdapTargetName()");

	return "AD";
}

sub getMemberDn {
	my ( $self, $uid ) = @_;
	$log->debug("Calling CMU::LDAP::getMemberDn(self, $uid)");
	my @attrs = ();
	my $result;
	eval {
		$result =
		   $self->search("&(cn=$uid)(objectClass=person)",
			\@attrs, $self->{_peoplebase} );
	};
	if ($@) {
		die();
	}

	if ( $result->count < 1 ) {
		$log->info("LDAP search didn't return result for uid $uid");
		return;
	}
	elsif ( $result->count == 1 ) {
		my $entry = $result->pop_entry();
		my $dn    = $entry->get_value("distinguishedName");
		$log->debug("DN for $uid is $dn");
		return $dn;
	}
	else {
		$log->error("LDAP search returned more then 1 result for uid $uid");
		die();
	}
}


sub createGroup {
	my ( $self, $dn ) = @_;

	$log->debug(
		"Calling CMU::LDAP::AD::createGroup(self, $dn)");

	my @dn_parts     = split( ',', $dn );
	my @syncou_parts = split( ',', $self->{_syncou} );

	my $result;
	my @oudn = ();
	for my $i ( 1 .. $#dn_parts - $#syncou_parts - 1 ) {
		shift(@dn_parts);
		my $ou = join( ",", @dn_parts );
		push( @oudn, $ou );
	}

	@oudn = reverse(@oudn);

	foreach (@oudn) {
		eval { $result = $self->createOU($_); };
		if ($@) {
			die();
		}
	}

	eval {
		$result = $self->{_ldap}->add(
			$dn,
			attr => [
				'objectclass'    => [ 'top', 'group' ],
				'sAmAccountName' => $self->{_samaccountname}
			]
		);
	};
	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );
			
		if ( $errname eq "LDAP_ALREADY_EXISTS" ) {
			$log->info("group $dn already exists in AD");
			return 0;
		}

		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::AD::createGroup returned with error name: $errname, and error description: $errdesc"
		);
		die();
	}
	
	
	$log->info("Created AD group $dn");
	return $result;
}


sub getGroupMembers {
	my ( $self, $groupdn ) = @_;
	$log->debug("Calling CMU::LDAP::AD::getMembers( self, $groupdn)");

	my @attrs = ("member;range=0-*");
	my $result;
	my @members     = ();
	my @tmp         = ();
	my $first       = 0;
	my $size        = 1500;
	my $last        = $first + $size - 1;
	my $membercount = 0;
	my $done        = 0;

	while ( !$done ) {
		eval {
			$log->debug(
"Performing ldap search with members range $first to $last for $groupdn"
			);
			$result =
			  $self->search( "&(distinguishedName=$groupdn)(objectClass=group)",
				\@attrs, $self->{_syncou} );

			my $entry = $result->pop_entry();
			@tmp = $entry->get_value("member;range=$first-*");
			if ( @tmp == 0 ) {

				@tmp = $entry->get_value("member;range=$first-$last");
				push @members, @tmp;

				$membercount = @members;
				$first += $size;
				$last = $first + $size - 1;

				@attrs = ("member;range=$first-*");

				if ( @tmp == 0 ) {
					$done = 1;
				}
			}
			else {
				push @members, @tmp;
				$membercount = @members;
				$done        = 1;
			}
		};
		if ($@) {
			die();
		}
	}

	$log->debug("Found $membercount members for group $groupdn");
	return @members;
}

sub getGroupDn {
	my ( $self, $groupname ) = @_;
	$log->debug("Calling CMU::LDAP::AD::getGroupDn(self, $groupname)");

	my @list  = split( ':', $groupname );
	my $count = 0;

	foreach my $token (@list) {
		if ( $count != $#list ) {
			$token = join( "=", "OU", $token );
		}
		else {
			$token = join( "=", "CN", $token );
		}
		$count++;
	}

	my $dn = join( ",", reverse(@list), $self->{_syncou} );

	$log->debug("groupname $groupname converted to DN $dn");
	return $dn;
}

1;
