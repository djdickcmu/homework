package CMU::ActiveMQ;
use Net::Stomp;

use strict;
use warnings;

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
		my $queue = shift;

		CMU::CFG::readConfig('configuration.pl');

		$_activemq->{_primary}     = $CMU::CFG::_CFG{'activemq'}{'primary'};
		$_activemq->{_secondary}   = $CMU::CFG::_CFG{'activemq'}{'secondary'};
		$_activemq->{_port}        = $CMU::CFG::_CFG{'activemq'}{'port'};
		$_activemq->{_login}       = $CMU::CFG::_CFG{'activemq'}{'login'};
		$_activemq->{_password}    = $CMU::CFG::_CFG{'activemq'}{'password'};
		#$_activemq->{_destination} = $CMU::CFG::_CFG{'activemq'}{'destination'};
		$_activemq->{_destination} = $queue;
		$_activemq->connect();
		if (defined $_activemq->{_stomp}) {
			eval {
				$_activemq->subscribe();
			};
			if ($@) {
				return;
			}
		}else {
			return;
		}
	}else {
		if ( !$_activemq->isConnected() ) {
			$_activemq->connect();
		}
	}
	return $_activemq;
}

sub getStomp {
	my ($self) = @_;

	#$log->debug("Calling CMU::ActiveMQ::getStomp(self)");

	return $self->{_stomp};
}


sub isConnected {
	my ($self) = @_;

	$log->debug("Calling CMU::ActiveMQ::isConnected(self)");

	return $self->{_stomp}->socket->connected();
}

sub disconnect {
	my ($self) = @_;

	$log->debug("Calling CMU::ActiveMQ::disconnect(self)");

	$self->{_stomp}->disconnect();
	undef $_activemq;
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
		return;
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
		return;
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

sub unsubscribe {
	my ($self) = @_;
	$log->debug("Calling CMU::ActiveMQ::unsubscribe(self)");

	eval {
		$self->{_stomp}->unsubscribe(
			{ destination => $self->{_destination}});
	};
	if ($@) {
		$log->error("Couldn't unsubscribe from queue $self->{_destination} ");
	}
}

1;
