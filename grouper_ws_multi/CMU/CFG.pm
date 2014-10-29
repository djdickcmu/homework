package CMU::CFG;

use FindBin;
use strict;


my $log = Log::Log4perl->get_logger();


sub readConfig {
	my ( $file ) = @_;
	
	$log->debug("Calling CMU::CFG::readConfig($file)");
	
	# Process the contents of the config file
	my $rc = do($file);
	
	# Check for errors
	if ($@) {
	    $log->error("Failure compiling '$file' - $@");
	    exit(1);
	}
	elsif ( !defined($rc) ) {
	    $log->error("Failure reading '$file' - $!");
	    exit(1);
	}
	elsif ( !$rc ) {
	    $log->error("Failure processing '$file'");
	    exit(1);
	}
}

1;
