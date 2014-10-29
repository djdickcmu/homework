package CMU::ActiveMQ;
use Net::Stomp;

use strict;

require CMU::CFG;

my $_stomp;
my $_primary;
my $_secondary;
my $_port;
my $_login;
my $_password;
my $_destination;
my $_activemq = undef;

my $log = Log::Log4perl->get_logger();

sub getInstance {
	if ( !defined $_activemq ) {
		my $class = shift;
		my $self  = {};
		$_activemq = bless $self, $class;

		CMU::CFG::readConfig('configuration.pl');

		$_activemq->{_primary}     = $CMU::CFG::_CFG{'activemq'}{'primary'};
		$_activemq->{_secondary}   = $CMU::CFG::_CFG{'activemq'}{'secondary'};
		$_activemq->{_port}        = $CMU::CFG::_CFG{'activemq'}{'port'};
		$_activemq->{_login}       = $CMU::CFG::_CFG{'activemq'}{'login'};
		$_activemq->{_password}    = $CMU::CFG::_CFG{'activemq'}{'password'};
		$_activemq->{_destination} = $CMU::CFG::_CFG{'activemq'}{'destination'};
		$_activemq->connect();
		$_activemq->subscribe();
	}
	return $_activemq;
}

sub disconnect {
	my ($self) = @_;

	$log->debug("Calling CMU::ActiveMQ::disconnect(self)");

	$self->{_stomp}->disconnect;
}

sub connect {
	my ($self) = @_;
	$log->debug("Calling CMU::ActiveMQ::connect()");

	eval {
		$self->{_stomp} = Net::Stomp->new(
			{
				hosts => [
					{ hostname => $self->{_primary},   port => $self->{_port} },
					{ hostname => $self->{_secondary}, port => $self->{_port} },
				],
				ssl => 1
			}
		);
	};

	if ($@) {
		$log->error("Could not create stomp instance because:$!");
		die();
	}

	$log->debug(
		"Connecting to stomp using login:$self->{_login} passcode:'xxxxxx'");

	eval {
		my $conn =
		  $self->{_stomp}->connect(
			{ login => $self->{_login}, passcode => $self->{_password} } );
	};

	if ($@) {
		$log->error("Could not create stomp connection because:$!");
		die();
	}

	$log->info("Connected to stomp server");

	return $self->{_stomp};
}

sub subscribe {
	my ($self) = @_;
	$log->debug("Calling CMU::ActiveMQ::subscribe(self)");

	eval {
		$self->{_stomp}->subscribe(
			{ destination => $self->{_destination}, ack => 'client' },
			'activemq.prefetchSize' => 1 );
	};
	if ($@) {
		$log->error("Couldn't subscribe to queue $self->{_destination} ");
		die();
	}
}

sub processMessageChangeLog {
	my @groupermembers = ();
	my ( $self, $ldap, $data ) = @_;
	$log->debug(
		"Calling CMU::ActiveMQ::processMessageChangeLog(self, ldap, data)");

	eval {
		my $ldaptarget = $ldap->getLdapTargetName();
		if ( defined $data->{"memberList"} ) {
			@groupermembers = @{ $data->{"memberList"} };
		}

		my $groupdn = $ldap->getGroupDn( $data->{"name"} );

		if ( $data->{"operation"} eq "createGroup" ) {
			$ldap->createGroup($groupdn);
		}
		elsif ( $data->{"operation"} eq "addMember" ) {
			my $memberdn = $ldap->getMemberDn( $data->{"memberId"} );
			if ( defined $memberdn ) {
				$ldap->addGroupMember( $memberdn, $groupdn );
			}
			else {
				$log->info(
"Skipping add member to $groupdn as member $data->{'memberId'} doesn't exist in $ldaptarget "
				);
			}
		}
		elsif ( $data->{"operation"} eq "addIsMemberOf" ) {
			my $memberdn = $ldap->getMemberDn( $data->{"memberId"} );
			if ( defined $memberdn ) {
				$ldap->addIsMemberOf( $memberdn, $groupdn );
			}
			else {
				$log->info(
"Skipping add isMemberOf to uid  $data->{'memberId'} as uid doesn't exist in $ldaptarget "
				);
			}
		}
		elsif ( $data->{"operation"} eq "removeMember" ) {
			my $memberdn = $ldap->getMemberDn( $data->{"memberId"} );
			if ( defined $memberdn ) {
				if ( $ldap->checkGroupMemberExists( $memberdn, $groupdn ) ) {
					$ldap->removeGroupMember( $memberdn, $groupdn );
				}
				else {
					$log->info(
"Skipping remove memberdn  $memberdn from $groupdn as memberdn doesn't exist in $groupdn "
					);
				}
			}
			else {
				$log->info(
"Skipping remove member from $groupdn as uid  $data->{'memberId'} doesn't exist in $ldaptarget "
				);
			}
		}
		elsif ( $data->{"operation"} eq "removeIsMemberOf" ) {
			my $memberdn = $ldap->getMemberDn( $data->{"memberId"} );
			if ( defined $memberdn ) {
				if ( $ldap->checkIsMemberOfExists( $memberdn, $groupdn ) ) {
					$ldap->removeIsMemberOf( $memberdn, $groupdn );
				}
				else {
					$log->info(
"Skipping remove isMemberOf from uid  $data->{'memberId'}  as isMemberOf doesn't exist"
					);
				}
			}
			else {
				$log->info(
"Skipping remove isMemberOf from uid  $data->{'memberId'} as uid doesn't exist in $ldaptarget "
				);
			}
		}
		elsif ( $data->{"operation"} eq "updateGroup" ) {
			if (   $data->{"description"} ne ''
				&& $data->{"olddescription"} eq '' )
			{
				$ldap->addGroupDescription( $groupdn, $data->{"description"} );
			}
			elsif ($data->{"description"} ne ''
				&& $data->{"olddescription"} ne '' )
			{
				$ldap->replaceGroupDescription( $groupdn,
					$data->{"olddescription"} );
			}
			elsif ($data->{"description"} eq ''
				&& $data->{"olddescription"} ne '' )
			{
				$ldap->removeGroupDescription($groupdn);
			}
			else {
				$log->debug(
"Skipping update group for $groupdn ... Both old and new value for description is empty "
				);
			}
		}
		elsif ( $data->{"operation"} eq "deleteGroup" ) {
			$ldap->deleteObject($groupdn);
		}
		elsif ( $data->{"operation"} eq "renameGroup" ) {
			$log->debug("Rename not handled...Skipping ActiveMQ message");
		}
	};
	if ($@) {
		die();
	}
}

sub processMessageFullSyncMemberOf {
	my @groupermemberof      = ();
	my @ldapmemberof         = ();
	my @add_memberof         = ();
	my @remove_memberof      = ();
	my $ldapmemberofcount    = 0;
	my $groupermemberofcount = 0;
	my $addmemberofcount     = 0;
	my $removememberofcount  = 0;
	my $userdn;

	my ( $self, $ldap, $data ) = @_;
	$log->debug(
		"Calling CMU::ActiveMQ::processMessageFullSync(self, ldap, data)");

	eval {
		my $ldaptarget = $ldap->getLdapTargetName();
		if ( defined $data->{"groupList"} ) {
			@groupermemberof = @{ $data->{"groupList"} };
		}

		my @ldapmemberof = $ldap->getMemberOf( $data->{"name"} );
		$userdn = $ldap->getMemberDn( $data->{"name"} );

		$groupermemberofcount = @groupermemberof;

		@ldapmemberof =
		  CMU::Util::covertMemberDNListToMembersUidList(@ldapmemberof);
		$ldapmemberofcount = @ldapmemberof;

		@add_memberof =
		  CMU::Util::getGroupMembersToAdd( \@groupermemberof, \@ldapmemberof );
		$addmemberofcount = @add_memberof;

		$ldap->reconcileMemberOf( $userdn, @add_memberof );

		@remove_memberof =
		  CMU::Util::getGroupMembersToRemove( \@groupermemberof,
			\@ldapmemberof );
		$removememberofcount = @ldapmemberof;

		$ldap->reconcileMemberOf( $userdn, @remove_memberof );

		$log->info(
			"Grouper memberof count: $groupermemberofcount for $data->{'name'}"
		);
		$log->info(
"$ldaptarget memberof count: $ldapmemberofcount for  $data->{'name'}"
		);
		$log->info("Add memberof count: $addmemberofcount for $data->{'name'}");
		$log->info(
			"Remove memberof count: $removememberofcount for $data->{'name'}");
		$log->info(
			"FullsyncMemberOf completed successfully for $data->{'name'}");

	};
	if ($@) {
		die();
	}

	sub processMessageFullSync {
		my @groupermembers = ();
		my @ldapmembers    = ();
		my @add_members    = ();
		my @remove_members = ();
		my $ldapcount      = 0;
		my $groupercount   = 0;
		my $addcount       = 0;
		my $removecount    = 0;

		my ( $self, $ldap, $data ) = @_;
		$log->debug(
			"Calling CMU::ActiveMQ::processMessageFullSync(self, ldap, data)");

		eval {
			my $ldaptarget = $ldap->getLdapTargetName();
			if ( defined $data->{"memberList"} ) {
				@groupermembers = @{ $data->{"memberList"} };
			}

			my $groupdn = $ldap->getGroupDn( $data->{"name"} );

			$groupercount = @groupermembers;

			if ( $ldap->checkObjectExists($groupdn) ) {
				@ldapmembers = $ldap->getGroupMembers($groupdn);

				@ldapmembers =
				  CMU::Util::covertMemberDNListToMembersUidList(@ldapmembers);
				$ldapcount = @ldapmembers;

				@add_members =
				  CMU::Util::getGroupMembersToAdd( \@groupermembers,
					\@ldapmembers );
				$addcount = @add_members;

				foreach (@add_members) {
					my $memberdn = $ldap->getMemberDn($_);
					if ( defined $memberdn ) {
						$ldap->addGroupMember( $memberdn, $groupdn );
					}
				}

				@remove_members =
				  CMU::Util::getGroupMembersToRemove( \@groupermembers,
					\@ldapmembers );
				$removecount = @remove_members;

				foreach (@remove_members) {
					my $memberdn = $ldap->getMemberDn($_);
					my @attrs    = ('distinguishedName');
					if ( defined $memberdn
						&& $ldap->checkGroupMemberExists( $memberdn, $groupdn )
					  )
					{
						$ldap->removeGroupMember( $data->{"memberId"},
							$groupdn );
					}
				}
			}
			else {
				$ldap->createGroup($groupdn);

				if ( $data->{"description"} ne '' ) {
					$ldap->addGroupDescription( $groupdn,
						$data->{"description"} );
				}

				foreach (@groupermembers) {
					my $memberdn = $ldap->getMemberDn($_);
					if ( defined $memberdn ) {
						$ldap->addGroupMember( $memberdn, $groupdn );
					}
					$addcount++;
				}
			}

			$log->info(
				"Grouper members count: $groupercount for $data->{'name'}");
			$log->info("$ldaptarget members count: $ldapcount for $groupdn");
			$log->info("Add members count: $addcount for $data->{'name'}");
			$log->info(
				"Remove members count: $removecount for $data->{'name'}");
			$log->info("Fullsync completed successfully for $data->{'name'}");

		};
		if ($@) {
			die();
		}

	}
}
1;
