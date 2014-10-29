#!/usr/bin/perl -w

use JSON;
use Log::Log4perl;
#use Digest::MD5 qw(md5_hex);
#use FindBin;
use strict;
use CMU::ActiveMQ;
use CMU::CFG;
use REST::Client;
use XML::Simple;
use Proc::Daemon;
use Cwd;
use sigtrap 'handler', \&cleanupExit, 'normal-signals';

#print cwd() . "\n";

Proc::Daemon::Init({work_dir => cwd(),
					child_STDOUT => 'stdout.txt'
});
#print cwd() . "\n";

CMU::CFG::readConfig('configuration.pl');

##Constants for error handling
my $ERROR_WAIT = $CMU::CFG::_CFG{'error'}{'interval'};
my $ERROR_MAX = $CMU::CFG::_CFG{'error'}{'max_attempts'};
my $error_count = 0;


my $mesg;
my $log;
my ($activemq, $activemq_put);
my $ldap;
my $client;
my $data;
#Define HTTP Method, PUT will add a member, DELETE will remove a member
my %method = (
				addMember => 'PUT',
				removeMember => 'DELETE'
				);
eval {
	#Initalize Logger
	Log::Log4perl::init(
		cwd() . '/' . $CMU::CFG::_CFG{'log'}{'file'});
	$log = Log::Log4perl->get_logger();

	#Get configuration for ActiveMQ
	$client = REST::Client->new();
	$client->setHost('https://grouper-test.andrew.cmu.edu');
	$client->addHeader('Content-Type', 'text/x-json');
	$client->addHeader('Authorization', 'Basic Z3Byd3NhbXE6T2o4eXVDMmZBOUhlN25PYzk/');

	while (1) {
		$log->debug("Starting again");
		#Connect to ActiveMQ and receive message
		$activemq = CMU::ActiveMQ->getInstance();
		my $frame = $activemq->{_stomp}->receive_frame();
		
		if ($frame) {
			$mesg = $frame->body;
			$log->debug("Received ActiveMQ message: $mesg");
			#If XML
			if(substr($mesg, 0, 1) eq '<'){
				$data = XMLin($mesg);
			}
			#Else if JSON
			elsif(substr($mesg, 0, 1) eq '{'){
				$data = JSON::decode_json($mesg);
			}
			
			#Replace group ':' with '%3A' - URL Encoding
			(my $url_group = $$data{'name'}) =~ s/:/%3A/g;
			
			#use version, the URL encoded group and the member ID to add or delete a member
			$client->request($method{$$data{'operation'}}, '/grouper-ws/servicesRest/v2_1_005/groups/' . $url_group . '/members/' . $$data{'memberId'});
			my $responseCode = $client->responseCode();
			$log->debug($responseCode);
			#Success
			if($responseCode == 200 or $responseCode == 201){
				$error_count = 0;
				$log->info("Successfully processed  ActiveMQ message: $mesg");
				if($client->responseHeader('X-Grouper-ResultCode') ne 'SUCCESS'){
					$log->info($client->responseHeader('X-Grouper-ResultCode'));
				}
				$activemq->{_stomp}->ack( { frame => $frame } );
			}
			#Grouper service is down try after ERROR_WAIT seconds, quit after ERROR_MAX attempts
			elsif($responseCode == 503){
				$error_count++;
				$log->debug("Waiting $ERROR_WAIT seconds to retry.");
				sleep($ERROR_WAIT);
				if($error_count > $ERROR_MAX){
					$log->info("Maximum retrys exceeded: $ERROR_MAX attempts made. Exiting.");
					exit(1);
				}
				$log->debug("retrying");
			}
			#Otherwise the group or subject is not found. Log an error, put the message into another queue and move on.
			else{
				$log->info("Message NOT processed: " . $responseCode . ' ' . $client->responseHeader('X-Grouper-ResultCode'));				
				$log->info($client->responseContent());
				$activemq->{_stomp}->ack( { frame => $frame } );
				$activemq->{_stomp}->send( { destination => $CMU::CFG::_CFG{'activemq'}{'errordestination'}, body => $mesg } );
			}
			
		}
	#$log->debug("Disconnecting");
	#$activemq->{_stomp}->disconnect;
	}
};
#Exception Handling 
if ($@) {
	if ( defined $mesg ) {
		$log->error("Couldn't process ActiveMQ message: $mesg .. Exiting");
		$log->info($@)
	}

	if ( defined $activemq ) {
		$activemq->disconnect;
	}
	exit(0);
}

sub cleanupExit {
	if ( defined $activemq) {
		$activemq->disconnect;
		$log->info("Disconnected from ActiveMQ");
	}

	$log->info("Exiting");
	exit(0);
}
