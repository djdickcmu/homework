package CMU::LDAP::389;

use Net::LDAP::Util
  qw(ldap_error_name ldap_error_text ldap_error_desc ldap_explode_dn);
use base ("CMU::LDAP");
use strict;

require CMU::CFG;

my $_389 = undef;
my $_cn;

my $log = Log::Log4perl->get_logger();

sub getInstance {
	$log->debug("Calling CMU::LDAP::389::getInstance(self)");
	if ( !defined $_389 ) {
		my $class = shift;
		my $self  = {};
		$_389 = bless $self, $class;

		CMU::CFG::readConfig('configuration.pl');

		$_389->{_binddn}     = $CMU::CFG::_CFG{'389'}{'binddn'};
		$_389->{_password}   = $CMU::CFG::_CFG{'389'}{'password'};
		$_389->{_port}       = $CMU::CFG::_CFG{'389'}{'port'};
		$_389->{_syncou}     = $CMU::CFG::_CFG{'389'}{'syncou'};
		$_389->{_peoplebase} = $CMU::CFG::_CFG{'389'}{'peoplebase'};
		$_389->{_server}     = $CMU::CFG::_CFG{'389'}{'server'};
		$_389->connect();
	}
	else {
		if ( !$_389->isConnected() ) {
			$_389->connect();
		}
	}
	return $_389;
}

sub getLdapTargetName {
	my ($self) = @_;
	$log->debug("Calling CMU::LDAP::389::getLdapTargetName()");

	return "389";
}

sub setCn {
	my ( $self, $cn ) = @_;
	$log->debug("Calling CMU::LDAP::389::setCn()");

	$self->{_cn} = $cn;
}

sub getMemberDn {
	my ( $self, $uid ) = @_;
	$log->debug("Calling CMU::LDAP::389::getMemberDn(self, $uid)");
	my @attrs = ("entryDn");
	my $result;
	eval {
		$result = $self->search( "&(uid=$uid)(objectClass=cmuAccountPerson)",
			\@attrs, $self->{_peoplebase} );
	};
	if ($@) {
		my $errname = ldap_error_name( $result->code );
		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::389::getMemberDn returned with error name:$errname, and error description: $errdesc"
		);
		die();
	}
	print $result->code;
	if ( $result->count < 1 ) {
		$log->info("LDAP search didn't return result for uid $uid");
		return;
	}
	elsif ( $result->count == 1 ) {
		my $entry = $result->pop_entry();
		my $dn    = $entry->get_value("entryDn");
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
	$log->debug("Calling CMU::LDAP::389::createGroup(self, $dn)");

	my $result;
	eval {
		$result = $self->{_ldap}->add(
			$dn,
			attr => [
				'objectClass' => [ 'top', 'groupOfNames' ],
				'cn' => [ ldap_explode_dn($dn)->[0]{CN} ]
			]
		);
	};
	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );

		if ( $errname eq "LDAP_ALREADY_EXISTS" ) {
			$log->info("group $dn already exists");
			return 0;
		}

		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::389::createGroup returned with error name: $errname, and error description: $errdesc"
		);
		die();
	}

	$log->info("Created 389 group $dn");
	return $result;
}

sub getGroupDn {
	my ( $self, $groupname ) = @_;
	$log->debug("Calling CMU::LDAP::389::getGroupDn(self, $groupname)");

	$groupname = join( "=", "CN", $groupname );

	my $dn = join( ",", $groupname, $self->{_syncou} );

	$log->debug("groupname $groupname converted to DN $dn");
	return $dn;
}

sub getGroupMembers {
	my ( $self, $cn ) = @_;
	$log->debug("Calling CMU::LDAP::389::getMembers( self, $cn)");

	my @attrs = ("member");
	my $result;
	my @members     = ();
	my $membercount = 0;

	eval {
		$result = $self->search( "&(cn=$cn)(objectClass=groupOfNames)",
			\@attrs, $self->{_syncou} );

		my $entry = $result->pop_entry();
		@members     = $entry->get_value("member");
		$membercount = @members;
	};
	if ($@) {
		die();
	}

	$log->debug("Found $membercount members for group $cn");
	return @members;
}



sub checkIsMemberOfExists {
	my ( $self, $userdn, $groupdn) = @_;
	$log->debug("CallingCalling CMU::LDAP::389::checkIsMemberOfExists(self, $userdn, $groupdn)");

	my $result = $self->{_ldap}->search(
		base   => $userdn,
		scope  => 'base',
		filter => '(isMemberOf=$groupdn)',
		attrs  => ['dn']
	);

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );

		if ( $errname eq "LDAP_NO_SUCH_OBJECT" ) {
			return 0;
		}
		else {
			my $errdesc = ldap_error_desc( $result->code );
			$log->error(
"CMU::LDAP::389::checkIsMemberOfExists returned with error name:$errname, and error description: $errdesc"
			);
			die();
		}
	}

	$log->info("Found isMemberOf $groupdn for user $userdn");
	return $result->count();
}



sub addIsMemberOf {
	my ( $self, $memberdn, $groupdn ) = @_;
	$log->debug(
		"Calling CMU::LDAP::389::addIsMemberOf( self, $memberdn, $groupdn)");

	my $result =
	  $self->{_ldap}->modify( $memberdn, add => { isMemberOf => [$groupdn] } );

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );
		my $errdesc = ldap_error_desc( $result->code );

		if ( $errname eq "LDAP_TYPE_OR_VALUE_EXISTS" ) {
			$log->info("member $memberdn already exists in $groupdn");
			return 0;
		}

		$log->error(
"CMU::LDAP::389::addIsMemberOf returned with error name: $errname, and error description: $errdesc"
		);
		die();
	}

	$log->info("Added isMemberOf $groupdn for uid $memberdn");
	return 0;
}

sub removeIsMemberOf {
	my ( $self, $memberdn, $groupdn ) = @_;
	$log->debug(
		"Calling CMU::LDAP::389::removeIsMemberOf( self, $memberdn, $groupdn)");

	my $result =
	  $self->{_ldap}
	  ->modify( $memberdn, delete => { isMemberOf => [$groupdn] } );

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );
		my $errdesc = ldap_error_desc( $result->code );

		if ( $errname eq "LDAP_TYPE_OR_VALUE_EXISTS" ) {
			$log->info("member $memberdn already exists in $groupdn");
			return 0;
		}

		$log->error(
"CMU::LDAP::389 removeIsMemberOf returned with error name: $errname, and error description: $errdesc"
		);
		die();
	}

	$log->info("Removed isMemberOf $groupdn for uid $memberdn");
	return 0;
}

sub reconcileMemberOf {
	my ( $self, $userdn, $groups ) = @_;
	$log->debug(
		"Calling CMU::LDAP::389::removeMemberOf( self, $userdn, groups)");

	my $result = $self->{_ldap}->modify(
		$userdn,
		delete => ['member'],
		add    => {@$groups}
	);

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );
		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::389 removeMemberOf returned with error name: $errname, and error description: $errdesc"
		);
		die();
	}

	$log->info("Reconciled memberof member $userdn");
	return $result;
}

sub getMemberOf {
	my ( $self, $uid ) = @_;
	$log->debug("Calling CMU::LDAP::389::getMemberOf( self, $uid)");

	my @attrs = ();
	my $result;
	my @memberof = ();
	my $memberofcount;

	eval {
		$result = $self->search( "&(uid=$uid)(objectClass=cmuAccountPerson)",
			\@attrs, $self->{_peoplebase} );

		my $entry = $result->pop_entry();
		@memberof      = $entry->get_value("memberof");
		$memberofcount = @memberof;
	};

	if ($@) {
		die();
	}

	$log->debug("Found $memberofcount memberof for uid $uid");
	return @memberof;
}

1;
