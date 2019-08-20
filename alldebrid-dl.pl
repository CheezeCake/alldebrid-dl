#!/usr/bin/env perl

#The MIT License (MIT)
#
#Copyright (c) 2015 Emmanuel Nicolet
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.


=head1
usage: alldebrid-dl.pl [-d destination dir.] [link ...]
if no links are given in the command line, the script will attempt to read
links from stdin (one per line)
=cut


use strict;

use WWW::Mechanize;
use XML::LibXML;
use JSON;
use CGI::Util qw(escape);
use Getopt::Std;


use constant LOGIN => '';
use constant PASSWORD => '';

use constant LOGIN_LINK => 'https://www.alldebrid.com/api.php';
use constant DEBRID_SERVICE_LINK => 'https://www.alldebrid.com/service.php?json=true';


our $opt_d;
getopts('d:');

if (defined $opt_d) {
    if( not -d $opt_d) {
        print STDERR $opt_d.' : no such directory', "\n";
        exit 1;
    }
    else {
        chdir $opt_d;
        print 'Downloads will be saved in : '.$opt_d, "\n\n";
    }
}

my @links;
if (scalar @ARGV > 0) {
    @links = @ARGV;
}
else {
    while (<>) {
        chomp $_;
        push @links, $_;
    }
}

my $browser = WWW::Mechanize->new();

my $response = $browser->get( LOGIN_LINK.'?action=info_user&login='.escape(LOGIN).'&pw='.escape(PASSWORD));
die $response->status_line unless ($response->is_success);

my $content = $response->decoded_content;
die $content if ($content eq 'login fail');


# only keep <account> content
$content =~ s/^.*(<account>.*\/account>).*$/$1/;

my $xmlParser = XML::LibXML->new();
my $xmlDoc = $xmlParser->parse_string($content);

my $accountType = $xmlDoc->findvalue('/account/type');
my $accountCookie = $xmlDoc->findvalue('/account/cookie');

die 'Not premium ('.$accountType.')' unless ($accountType eq 'premium');

my $failedDownloads = 0;
foreach my $link (@links) {
    my $response = $browser->get(DEBRID_SERVICE_LINK.'&link='.escape($link),
        Cookie => 'uid='.$accountCookie);

    if ($response->is_success) {
        my $json = decode_json($response->decoded_content);

        if ($$json{'error'} eq '') {
            print 'Downloading : '.$$json{'link'}, "\n";
            my $exitCode = system 'curl', '-g', '-O', '-b', 'uid='.$accountCookie, $$json{'link'};
            print "\n";
            $failedDownloads++ if ($exitCode != 0);
        }
        else {
            $failedDownloads++;
            print STDERR $link.' : '.$$json{'error'}, "\n";
        }
    }
    else {
        print STDERR $link.' : '.$response->status_line, "\n";
    }
}

exit $failedDownloads;
