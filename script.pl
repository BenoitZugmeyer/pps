#!/usr/bin/perl


use warnings;
use strict;
use LWP::Simple;

if(@ARGV != 1) {
  print "Usage: my_program keyword\n";
	exit 1;
}

my $keyword = $ARGV[0];
my $baseurl = "http://thepiratebay.se/search";
my $page = get "$baseurl/$keyword" or die "Error getting web.";

while($page =~ /category\">(.*?)<[\s\S]*?category\">(.*?)<[\s\S]*?Details for (.+?)\"[^\"]*\"(magnet:\?.+?)\"(.*This torrent has (\d+) comments)?(.*VIP)?(.*Trusted)?(.*Helper)?(.*Moderator)?(.*Admin)?[\s\S]*?Size (.+?)\&nbsp;(.*?B).*>(.+?)<[\s\S]*?(\d+)[\s\S]*?(\d+)/g) {
	my $category = $1;
	my $sub_category = $2;
	my $title = $3;
	my $magnet = $4;
	my $comments = 0;
	if(defined $6 && $6 ne '') {
		$comments = $6;
	}
	my $rank = "user";
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
	my $size_value = $12;
	my $size_unit = $13;
	my $uploader = $14;
	my $seeders = $15;
	my $leechers = $16;

	print "Title: $title\n";
	print "Category: $category\n";
	print "Sub-category: $sub_category\n";
	print "Magnet: $magnet\n";
	print "Comments: $comments\n";
	print "Rank: $rank\n";
	print "Size: $size_value $size_unit\n";
	print "Uploader: $uploader\n";
	print "Seeders: $seeders\n";
	print "Leechers: $leechers\n";
	print "\n";
}
