package CMU::Util;
use Net::LDAP::Util qw(ldap_explode_dn);

my $log = Log::Log4perl->get_logger();

sub getDnFromGroupname {
	my ( $syncou, $groupname ) = @_;
	$log->debug("Calling CMU::Util::getDnFromGroupname($syncou, $groupname)");

	my @list = split( ':', $groupname );
	my $addn;

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

	$addn = join( ",", reverse(@list), $syncou );

	$log->debug("groupname $groupname converted to DN $addn");
	return $addn;
}

sub getGroupMembersToAdd {
	my ( $groupermembers, $ldapmembers ) = @_;
	$log->debug( "Calling CMU::Util::getMembersToAdd( groupermembers, ldapmembers)" );

	my %ldapmembers      = map { $_ => 1 } @$ldapmembers;

	my @add_members =
	  grep (!defined $ldapmembers{$_}, @$groupermembers );
	return @add_members;
}

sub getGroupMembersToRemove {
	my ( $groupermembers, $ldapmembers ) = @_;
	$log->debug( "Calling CMU::Util::getMembersToRemove( groupermembers, ldapmembers)" );

	my %groupermembers = map { $_ => 1 } @$groupermembers;

	my @remove_members =
	  grep ( !defined $grouper_members{$_}, @$ldapmembers );
	return @remove_members;
}

sub covertMemberDNListToMembersUidList {
	my ( @dn ) = @_;
	$log->debug("Calling AD->getMembersUid(dn)");

	my @admembers = ();

	foreach my $member_dn (@dn) {
		push( @admembers, lc( ldap_explode_dn($member_dn)->[0]{CN} ) );
	}

	return @admembers;
}

1;
