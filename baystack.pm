package baystack;
##
## rancid 3.9
## Copyright (c) 1997-2018 by Henry Kilmer and John Heasley
## All rights reserved.
##
## This code is derived from software contributed to and maintained by
## Henry Kilmer, John Heasley, Andrew Partan,
## Pete Whiting, Austin Schutz, and Andrew Fort.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
## 1. Redistributions of source code must retain the above copyright
##    notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in the
##    documentation and/or other materials provided with the distribution.
## 3. Neither the name of RANCID nor the names of its
##    contributors may be used to endorse or promote products derived from
##    this software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY Henry Kilmer, John Heasley AND CONTRIBUTORS
## ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
## TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
## PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COMPANY OR CONTRIBUTORS
## BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##
## It is the request of the authors, but not a condition of license, that
## parties packaging or redistributing RANCID NOT distribute altered versions
## of the etc/rancid.types.base file nor alter how this file is processed nor
## when in relation to etc/rancid.types.conf.  The goal of this is to help
## suppress our support costs.  If it becomes a problem, this could become a
## condition of license.
# 
#  The expect login scripts were based on Erik Sherk's gwtn, by permission.
# 
#  The original looking glass software was written by Ed Kern, provided by
#  permission and modified beyond recognition.
# 
#  RANCID - Really Awesome New Cisco confIg Differ
#
#  baystack.pm - Bay Networks/Nortel/Avaya BayStack rancid procedures
#

use 5.010;
use strict 'vars';
use warnings;
require(Exporter);
our @ISA = qw(Exporter);
$Exporter::Verbose=1;

use rancid 3.12;

@ISA = qw(Exporter rancid main);
#our @EXPORT = qw($VERSION)

# load-time initialization
sub import {
    0;
}

# post-open(collection file) initialization
sub init {
    # add content lines and separators
    ProcessHistory("","","","!RANCID-CONTENT-TYPE: $devtype\n!\n");

    0;
}

# main loop of input of device output
sub inloop {
    my($INPUT, $OUTPUT) = @_;
    my($cmd, $rval);

TOP:
    while(<$INPUT>) {
	tr/\015//d;
	if ( (/(>|#)\s?logout/) || $found_end ) {
	    print STDERR "Found logout statement, ending\n" if ($debug);
	    delete($commands{'logout'});
	    $clean_run=1;
	    last;
	}
	if (/^Error:/) {
	    print STDOUT ("$host bslogin error: $_");
	    print STDERR ("$host bslogin error: $_") if ($debug);
	    $clean_run=0;
	    last;
	}
	while (/(^.*[>|#])\s*($cmds_regexp)\s*$/) {
	    $cmd = $2;
	    print STDERR "Doing $cmd\n";
	    if (!defined($prompt)) {
		$prompt = $1;
		print STDERR ("PROMPT MATCH: $prompt\n") if ($debug);
	    }
	    print STDERR ("HIT COMMAND:$_") if ($debug);
	    if (! defined($commands{$cmd})) {
		print STDERR "$host: found unexpected command - \"$cmd\"\n";
		$clean_run = 0;
		last TOP;
	    }
	    if (! defined(&{$commands{$cmd}})) {
		printf(STDERR "$host: undefined function - \"%s\"\n",  
		       $commands{$cmd});
		$clean_run = 0;
		last TOP;
	    }
	    print STDERR "Calling \"$cmd\"\n" if ($debug);
	    $rval = &{$commands{$cmd}}($INPUT, $OUTPUT, $cmd);
	    delete($commands{$cmd});
	    if ($rval == -1) {
		$clean_run = 0;
		last TOP;
	    }
	}
    }
}

# This routine parses "show running-config"
sub ShowConfig {
    my($INPUT, $OUTPUT, $cmd) = @_;
    my($lines) = 0;
    print STDERR "    In ShowConfig: $_" if ($debug);

    ProcessHistory("","","","! $_");

    # baystacks refuse to turn off linewrapping, so we have to
    # carefully reconstruct the unwrapped line
    my $line = '';
    my $bit;
    while ($bit = <$INPUT>) {
	$bit =~ tr/\015//d;
	if (length($bit) >= 132) {
	    # tack onto previous
	    chomp($line);
	    $line .= $bit;
	} else {
	    if ($line) {
		chomp($line);
		$line .= $bit;
	    } else {
		$line = $bit;
	    }
	    $line =~ tr/\015//d;
	    
	    if ($line =~ /^\s*\^\s*$/) {
		$line = '';
		next;
	    }
	    return(1) if $line =~ /invalid command name/;
	    return(1) if $line =~ /Invalid input detected at/;
	    
	    if ($line =~ /^$prompt/) {
		print STDERR "Found prompt, finishing ShowConfig\n" if ($debug);
		$found_end++;
		last;
	    }

	    $lines++;

	    if ($line =~ /^! clock set /) {
	    	    ProcessHistory("","","","! clock set \n");
		    $line = '';
		    next;
	    }

	    if ($filter_pwds >= 1) {
	    	if ($line =~ /(cli password .* read-.*\b )/) {
	    	    ProcessHistory("","","","! $1<removed>\n");
		    $line = '';
	    	    next;
	    	} elsif ($line =~ /(radius-server (key|password) )/) {
	    	    ProcessHistory("","","","! $1<removed>\n");
		    $line = '';
	    	    next;
	    	}
	    }

	    if ($filter_commstr) {
	    	if ($line =~ /(snmp-server community ).*( r[o|w])/) {
	    	    ProcessHistory("","","","! $1<removed>$2\n");
		    $line = '';
	    	    next;
	    	}
	    }

	    ProcessHistory("","","","$line");
	    $line = '';
	}
    }

    $_ = $line;

    if ($lines < 3) {
	printf(STDERR "ERROR: $host configuration appears truncated.\n");
	$found_end = 0;
	return(-1);
    }

    return(0);
}

# This routine parses "show sys-info" and "show stack-info"
sub ShowSysInfo {
    my($INPUT, $OUTPUT, $cmd) = @_;
    print STDERR "    In ShowSysInfo: $_" if $debug;
    print STDERR "    prompt is \"$prompt\"\n" if $debug;

    while(<$INPUT>){
	tr/\015//d;

	next if /^\s*\^\s*$/;
	return(1) if /invalid command name/;
	return(1) if /Invalid input detected at/;

	next if /Reset Count:/;
	next if /Last Reset Type:/;
	next if /sysUpTime:/;
	next if /sysNtpTime/;
	next if /sysRtcTime/;


	if(/^$prompt/){
	    print STDERR "Found prompt, finishing ShowSysInfo\n" if $debug;
	    ProcessHistory("SYSINFO","","","! \n");
	    return(0);
	}
	ProcessHistory("SYSINFO","","","!SYSINFO: $_");
    }

    ProcessHistory("SYSINFO","","","! \n");
    return(0);
}

1;
