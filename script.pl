#!/usr/bin/perl


use feature ':5.10';
use warnings;
use strict;
use feature "switch";
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


if(@ARGV != 1) {
	print "Usage: my_program keyword\n";
	exit 1;
}

my $keyword = $ARGV[0];
my $baseurl = "http://thepiratebay.se/search";
my $page = get "$baseurl/$keyword" or die "Error getting web.";

sub download_page {
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

sub print_page { #arg: reference to results array
	my @results = @{$_[0]};
	my $index = 1;
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
		$index ++;
	}
}

my @results = download_page();
print_page(\@results);
print "\nInsert the numbers of the files you would like to download: ";
my $input = <STDIN>;
my @selected = split /\s+/, "$input";
foreach(@selected) {
	my $index = $_ - 1;
	system("xdg-open $results[$index][MAGNET] >/dev/null 2>&1");
}
