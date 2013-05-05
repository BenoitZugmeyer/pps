#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;
use LWP::Simple;
use Term::ANSIColor;

use constant TITLE => 0;
use constant CATEGORY => 1;
use constant SUB_CATEGORY => 2;
use constant MAGNET => 3;
use constant COMMENTS => 4;
use constant RANK => 5;
use constant DATE => 6;
use constant DATE_YEAR_TIME => 7;
use constant SIZE_VALUE => 8;
use constant SIZE_UNIT => 9;
use constant UPLOADER => 10;
use constant SEEDERS => 11;
use constant LEECHERS => 12;
use constant BASEURL => "http://thepiratebay.se/search";

$Getopt::Std::STANDARD_HELP_VERSION = 1;
$Term::ANSIColor::EACHLINE = "\n";

sub HELP_MESSAGE {
	print "Usage: blah.pl keyword [options]\n";
	print "Accepted options:\n";
	print "    -i : Show additional information (uploader, date of upload and category).\n";
	print "    -s : Sort results by number of seeders (descending order).\n";
	print "    -S : Sort results by number of seeders (ascending order).\n";
	print "    -l : Sort results by number of leechers (descending order).\n";
	print "    -L : Sort results by number of leechers (ascending order).\n";
	print "    -c : Sort results by category (descending order).\n";
	print "    -C : Sort results by category (ascending order).\n";
	print "    -n : Sort results by name (descending order).\n";
	print "    -N : Sort results by name (ascending order).\n";
	print "    -d : Sort results by upload date (descending order).\n";
	print "    -D : Sort results by upload date (ascending order).\n";
	print "    -z : Sort results by size (descending order).\n";
	print "    -Z : Sort results by size (ascending order).\n";
	print "    -u : Sort results by uploader (descending order).\n";
	print "    -U : Sort results by uploader (ascending order).\n";
	print "Default sorting oprtion is ascending number of seeders.\n";
	print "If more than one sorting option is chosen, only the first will be used.\n";
}
sub VERSION_MESSAGE { print "version\n";} #TODO

my $keyword = shift;
my %opts;
getopts("iSLslc", \%opts);
my $sort = 7;
if(defined $opts{s})	{	$sort = 7;	}
elsif(defined $opts{S})	{	$sort = 8;	}
elsif(defined $opts{l}) {	$sort = 9;	}
elsif(defined $opts{L}) {	$sort = 10;	}
elsif(defined $opts{c}) {	$sort = 13;	}
elsif(defined $opts{C}) {	$sort = 14;	}
elsif(defined $opts{n}) {	$sort = 1;	}
elsif(defined $opts{N}) {	$sort = 2;	}
elsif(defined $opts{d}) {	$sort = 3;	}
elsif(defined $opts{D}) {	$sort = 4;	}
elsif(defined $opts{z}) {	$sort = 5;	}
elsif(defined $opts{Z}) {	$sort = 6;	}
elsif(defined $opts{u}) {	$sort = 11;	}
elsif(defined $opts{U}) {	$sort = 12;	}

sub download_page {#0: keywork; 1: page_num; 2: sort
	print "Downloading data...\n";
	my $url = BASEURL . "/$_[0]/$_[1]/$_[2]/0";
	my $page = get "$url" or die "Error getting web: $url";
	my @results;
	while($page =~ /category\">(.*?)<[\s\S]*?category\">(.*?)<[\s\S]*?Details for (.+?)\"[^\"]*\"(magnet:\?.+?)\"(.*This torrent has (\d+) comments)?(.*VIP)?(.*Trusted)?(.*Helper)?(.*Moderator)?(.*Admin)?[\s\S]*?Uploaded ([^&]+?)&nbsp;(\d\d:?\d\d).*?Size (.+?)\&nbsp;(.*?B).*>(.+?)<[\s\S]*?(\d+)[\s\S]*?(\d+)/g) {
		my $category = $1;
		my $sub_category = $2;
		my $title = $3;
		my $magnet = $4;
		my $comments = 0;
		if(defined $6 && $6 ne '') {
			$comments = $6;
		}
		my $rank = "User";
		if(defined $7 && $7 ne '') {
			$rank = "VIP";
		} elsif(defined $8 && $8 ne '') {
			$rank = "Trusted";
		} elsif(defined $9 && $9 ne '') {
			$rank = "Helper";
		} elsif(defined $10 && $10 ne '') {
			$rank = "Moderator";
		} elsif(defined $11 && $11 ne '') {
			$rank = "Administrator";
		}
		my $date = $12;
		my $date_year_time = $13;
		my $size_value = $14;
		my $size_unit = $15;
		my $uploader = $16;
		my $seeders = $17;
		my $leechers = $18;

		$title =~ s/\&amp;/\&/;

		my @result = ($title, $category, $sub_category, $magnet, $comments, $rank, $date, $date_year_time, $size_value, $size_unit, $uploader, $seeders, $leechers);
		push @results, [@result];
	}
	return @results;
}

sub print_page { #0: reference to results array; 1: index of the first element
	my @results = @{$_[0]};
	my $index = $_[1];
	foreach(@results) {
		print "$index: ";
		if($index < 10) {
			print " ";
		}
		print colored ("@$_[TITLE]", 'bold');
		print " (@$_[SEEDERS]/@$_[LEECHERS])";
		if(@$_[COMMENTS] > 0) {
			print " ";
			print colored ("(@$_[COMMENTS])", 'black on_yellow');
		}
		print "\n";

		if(defined $opts{i}) {
			print "    Uploaded by ";
			if(@$_[RANK] eq "Trusted")			{print color 'white on_magenta';}
			elsif(@$_[RANK]	eq "VIP")			{print color 'white on_green';}
			elsif(@$_[RANK]	eq "Helper")		{print color 'white on_blue';}
			elsif(@$_[RANK]	eq "Administrator")	{print color 'black on_white';}
			elsif(@$_[RANK]	eq "Moderator")		{print color 'black on_white';}
			print "@$_[UPLOADER]";
			print color 'reset';
			if(@$_[DATE] =~ /\d\d-\d\d/) {
				print " on date";
			}
			print " @$_[DATE]";
			if(@$_[DATE_YEAR_TIME] =~ /\d\d:\d\d/) {
				print " at ";
			} else {
				print "-";
			}
			print "@$_[DATE_YEAR_TIME]";
			print " to category @$_[CATEGORY]/@$_[SUB_CATEGORY].\n";
		}

		$index ++;
	}
}

sub read_input {

}
sub do_page { #0: page number
	my $page_num = $_[0];
	my @results = download_page($keyword, $page_num, $sort);
	print_page(\@results, 1 + 30 * $page_num);
	print "Insert 'n' for next page. Insert 'p' for previous page.\n";
	print "Insert the numbers of the files you would like to download: ";
	my $downloads = 0;
	for(;;) {
		if($downloads > 0) {
			exit 0;
		}
		my $input = <STDIN>;
		my @selected = split /\s+/, "$input";
		foreach(@selected) {
			if($_ =~ /\d+/ && $_ > 0 && $_ <= $#results) {
				system("xdg-open $results[$_ - 1 - 30 * $page_num][MAGNET] >/dev/null 2>&1");
				$downloads ++;
			} elsif($_ eq "n") {
				if($#results > 0) {
					do_page($page_num + 1);
				} else {
					print "There are no more pages.\n";
				}
			} elsif($_ eq "p") {
				if($page_num > 0) {
					do_page($page_num - 1);
				} else {
					print "There are no previous pages.\n";
				}
			}
		}
	}
}

do_page 0
