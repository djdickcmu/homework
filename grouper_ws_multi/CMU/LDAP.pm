#!/usr/bin/perl
package CMU::LDAP;
use Net::LDAPS;
use Log::Log4perl;
use Net::LDAP::Util qw(ldap_error_name ldap_error_text ldap_error_desc);

my $log = Log::Log4perl->get_logger();

my $_binddn;
my $_password;
my $_port;
my $_server;
my $_ldap;
my $_syncou;
my $_peoplebase;

sub new {
	my $class = shift;
	my $self  = {};
	bless $self, $class;
	return $self;
}

sub isConnected{
	my ( $self) = @_;
	
	$log->debug("Calling CMU::LDAP::isConnected(self)");
	
	return $self->{_ldap} ->socket->connected(); 
}

sub disconnect{
	my ( $self) = @_;
	
	$log->debug("Calling CMU::LDAP::disconnect(self)");

	$self->{_ldap} ->unbind;
}

sub isConnected {
	my ($self) = @_;

	$log->debug("Calling CMU::LDAP::isConnected(self)");

	return $self->{_ldap}->socket->connected();
}

sub connect {

	my ( $self) = @_;

	$log->debug("Calling CMU::LDAP::connect(self)");

	eval { $self->{_ldap} = Net::LDAPS->new( $self->{_server}, port => $self->{_port} ); };

	if ($@) {
		$log->error("Could not create LDAP object because:$!");
		die();
	}

	my $result = $self->{_ldap}->bind( $self->{_binddn}, password => $self->{_password});

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );
		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::connect returned with error name: $errname, and error description: $errdesc"
		);
		die();
	}

	$log->info("Bind sucessful");
	return;
}

sub search {
	my ( $self, $searchstring, $attrs, $base) = @_;

	$log->debug("Calling CMU::LDAP::search(self, $searchstring, attrs, $base)");

	my $result = $self->{_ldap}->search(
		base   => "$base",
		scope  => "sub",
		filter => "$searchstring",
		attrs  => $attrs
	);

	if ($result) {
		my $errname = ldap_error_name( $result->code );
		if ( $errname eq "LDAP_SUCCESS" ) {
			$log->debug("Ldap search successfull for $searchstring");
			return $result;
		}
		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::search returned with error name: $errname, and error description: $errdesc"
		);
		die();
	}
}

sub createOU {
	my ( $self, $dn ) = @_;

	$log->debug("Calling CMU::LDAP::createOU(self, $dn)");

	$result =
	  $self->{_ldap}->add( $dn,
		attr => [ 'objectclass' => [ 'top', 'organizationalUnit' ], ] );

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );

		if ( $errname eq "LDAP_ALREADY_EXISTS" ) {
			return 0;
		}
		else {
			my $errdesc = ldap_error_desc( $result->code );
			$log->error(
"CMU::LDAP::::createOU returned with error name: $errname, and error description: $errdesc"
			);
			die();
		}
	}

	$log->info("Created LDAP OU $dn");
	return $result;
}


sub addGroupDescription {
	my ( $self, $dn, $description ) = @_;

	$log->debug("Calling CMU::LDAP::addGroupDescription(self, $dn, $description)");

	$result =
	  $self->{_ldap}->modify( $dn, add => {displayName => $description});

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );
		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::addGroupDescription returned with error name: $errname, and error description: $errdesc"
			);
			die();
	}

	$log->info("Added description $description for group $dn");
	return $result;
}

sub removeGroupDescription {
	my ( $self, $dn) = @_;

	$log->debug("Calling CMU::LDAP::removeGroupDescription(self, $dn)");

	$result =
	   $self->{_ldap}->modify( $dn, delete => ['description']);

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );
		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::removeGroupDescription returned with error name: $errname, and error description: $errdesc"
			);
			die();
	}

	$log->info("Deleted description for group $dn");
	return $result;
}

sub replaceGroupDescription {
	my ( $self, $dn, $description ) = @_;

	$log->debug("Calling CMU::LDAP::replaceGroupDescription(self, $dn, $description)");

	$result =
	   $self->{_ldap}->modify( $dn, replace => {description => $description});

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );
		my $errdesc = ldap_error_desc( $result->code );
		$log->error(
"CMU::LDAP::replaceGroupDescription returned with error name: $errname, and error description: $errdesc"
			);
			die();
	}

	$log->info("Replace description with $description for group $dn");
	return $result;
}


sub checkGroupMemberExists {
	my ( $self, $memberdn, $groupdn) = @_;
	$log->debug("CallingCalling CMU::LDAP::checkGroupMemberExists(self, $memberdn, $groupdn)");

	my $result = $self->{_ldap}->search(
		base   => $groupdn,
		scope  => 'base',
		filter => '(member=$memberdn)',
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
"CMU::LDAP::checkGroupMemberExists returned with error name:$errname, and error description: $errdesc"
			);
			die();
		}
	}

	$log->info("Found $memberdn in group $groupdn");
	return $result->count();
}




sub checkObjectExists {
	my ( $self, $dn ) = @_;
	$log->debug("Calling CMU::LDAP::checkObjectExists(self, $dn)");

	my $result =  $self->{_ldap}->search(
		base   => $dn,
		scope  => 'base',
		filter => '(objectClass=*)',
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
"CMU::LDAP::checkObjectExists returned with error name:$errname, and error description: $errdesc"
			);
			die();
		}
	}

	$log->info("Found $dn");
	return $result->count();
}

sub deleteObject {
	my ( $self, $dn ) = @_;

	$log->debug("Calling CMU::LDAP::objectDelete(self, $dn)");

	$result = $self->{_ldap}->delete($dn);

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );

		if ( $errname eq "LDAP_NO_SUCH_OBJECT" ) {
			$log->info("Couldn't find object $dn to delete");
			return 0;
		}
		else {
			my $errdesc = ldap_error_desc( $result->code );
			$log->error(
"CMU::LDAP::objectDelete returned with error name:$errname, and error description: $errdesc"
			);
			die();
		}
	}

	$log->info("Sucessfully deleted $dn");
	return $result;
}

sub addGroupMember {
	my ( $self, $memberdn, $groupdn) = @_;

	$log->debug("Calling CMU::LDAP::addGroupMember(self, $memberdn, $groupdn)");

	$result =
	  $self->{_ldap}->modify( $groupdn, changes => [ add => [ member => $memberdn ] ] );

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );

		if ( $errname eq "LDAP_TYPE_OR_VALUE_EXISTS" ) {
			$log->info("member $memberdn already exists in $groupdn");
			return 0;
		}
		else {
			my $errdesc = ldap_error_desc( $result->code );
			$log->error(
"CMU::LDAP::addGroupMember returned with error name: $errname, and error description: $errdesc"
			);
			die();
		}
	}
	$log->info("member $memberdn sucessfully added to $groupdn");
	return 0;
}

sub removeGroupMember {
	my ( $self, $groupdn, $memberdn ) = @_;

	$log->debug(
		"Calling CMU::LDAP::removeGroupMember(self, $groupdn, $memberdn)");

	$result =
	  $self->{_ldap}->modify( $groupdn,
		changes => [ delete => [ member => $memberdn ] ] );

	if ( $result->code ) {
		my $errname = ldap_error_name( $result->code );

		if ( $errname eq "LDAP_NO_SUCH_OBJECT" ) {
			$log->info("member $memberdn doesn't exist already in $groupdn");
			return 0;
		}
		else {
			my $errdesc = ldap_error_desc( $result->code );
			$log->error(
"CMU::LDAP::removeGroupMember returned with error name: $errname, and error description: $errdesc"
			);
			die();
		}
	}
	$log->info("member $memberdn sucessfully deleted from $groupdn");
	return 0;
}
1;
