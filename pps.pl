#!/usr/bin/perl
use strict;
use warnings;
use LWP::Simple;
use Term::ANSIColor;
use HTML::Entities;
use Getopt::Std;
use utf8;
binmode(STDOUT, ":utf8");
use threads('yield',
			'stack_size' => 64*4096,
			'exit' => 'threads_only',
			'stringify');

# constants
use constant BASEURL => scalar "http://thepiratebay.se/search";
use constant COMMENTS_COLOR => scalar 'black on_yellow';
use constant NO_SEEDERS_COLOR => scalar 'white on_red';
use constant SKULL_CROSSBONES => scalar '(☠)';
use constant DEFAULT_SORTING => scalar "s";
my %SORTINGS = (
	n => 1,
	N => 2,
	d => 3,
	D => 4,
	z => 5,
	Z => 6,
	s => 7,
	S => 8,
	l => 9,
	L => 10,
	u => 11,
	U => 12,
	c => 13,
	C => 14
);
my %RANK_COLORS = (
	Trusted			=> 'bold white on_magenta',
	VIP				=> 'bold white on_green',
	Helper			=> 'bold white on_blue',
	Administrator	=> 'bold black on_white',
	Moderator		=> 'bold black on_white'
);
$Getopt::Std::STANDARD_HELP_VERSION = 1;
$Term::ANSIColor::EACHLINE = "\n";

# argument handling
sub HELP_MESSAGE {
	print "Usage: $0 KEYWORDS [PARAMS]\n";
	print "       $0 [PARAMS] KEYWORDS\n";
	print "Accepted options for PARAMS are:\n";
	print "    -h : Show this message\n";
	print "    -i : Show additional information (uploader, date of upload and category).\n";
	print "    -s [SORTING]: Specify sorting method. Valid options for SORTING are:\n";
	print "        n : Sort results by name (descending order).\n";
	print "        N : Sort results by name (ascending order).\n";
	print "        d : Sort results by date of upload (descending order).\n";
	print "        D : Sort results by date of upload (ascending order).\n";
	print "        z : Sort results by size (descending order).\n";
	print "        Z : Sort results by size (ascending order).\n";
	print "        s : Sort results by number of seeders (descending order).\n";
	print "        S : Sort results by number of seeders (ascending order).\n";
	print "        l : Sort results by number of leechers (descending order).\n";
	print "        L : Sort results by number of leechers (ascending order).\n";
	print "        u : Sort results by uploader (descending order).\n";
	print "        U : Sort results by uploader (ascending order).\n";
	print "        c : Sort results by category (descending order).\n";
	print "        C : Sort results by category (ascending order).\n";
	print "        Default sorting option is descending number of seeders (s).\n";
	print "    -v : Show version number\n";
	print "Remember that if your keywords contain spaces you must surround them in quotes.\n"
}
sub VERSION_MESSAGE { print "PPS (Perl Pirate Search) version 1.1\n";}

if(@ARGV == 0) { VERSION_MESSAGE(); HELP_MESSAGE(); exit 1; }
my $kw_first = substr($ARGV[0], 0, 1) ne '-';
my $keyword;
if($kw_first) {
	$keyword = shift;
} else {
	$keyword = $ARGV[$#ARGV]
}
if(! $kw_first && (substr($ARGV[-1], 0, 1) eq '-' || $ARGV[-2] eq '-s')) {
	HELP_MESSAGE();
	exit 1;
}
my %args;
getopts("hivs:", \%args);
VERSION_MESSAGE() if($args{v});
HELP_MESSAGE() if($args{h});
my $sorting = $SORTINGS{$args{s} // +DEFAULT_SORTING} // $SORTINGS{+DEFAULT_SORTING};

# global vars
my @results_cache;
my $last_page;

#functions
sub download_page {
	(my $keyword, my $page_num, my $sorting) = @_;
	$SIG{'KILL'} = sub { threads->exit };
	my $url = BASEURL . "/$keyword/$page_num/$sorting/0";
	my $page = get "$url" or die "Error getting web: $url";
	my @results_page;
	if(! defined $last_page) {
		$page =~ /approx (\d+)/g;
		if($1) {
			$last_page = int(int($1) / int(30));
		} else {
			$last_page = -1;
			return \@results_page;
		}
	}
	while($page =~ /category\">(?<category>.*?)<[\s\S]*?category\">(?<sub_category>.*?)<[\s\S]*?Details for (?<title>.+?)\"[^\"]*\"(?<magnet>magnet:\?.+?)\"(?:.*This torrent has (?<comments>\d+) comments)?(?:.*?(?<rank>VIP|Trusted|Helper|Moderator|Admin))?[\s\S]*?Uploaded (?<date>[^&]+?)&nbsp;(?<date_year_time>\d\d:?\d\d).*?Size (?<size_value>.+?)\&nbsp;(?<size_unit>.*?B).*>(?<uploader>.+?)<[\s\S]*?(?<seeders>\d+)[\s\S]*?(?<leechers>\d+)/g) {
		my %results_item = %+;
		$results_item{'title'} = decode_entities($results_item{'title'});
		$results_item{'comments'} //= 0;
		push @results_page, \%results_item;
	}
	return \@results_page;
}

sub print_page {
	my @results_page = @{$_[0]};
	my $index = $_[1];
	foreach(@results_page) {
		my %results_item = %{$_};
		print "$index: ";
		print " " if($index < 10);
		print colored ("$results_item{'title'}", 'bold');
		if(! $args{i} && $results_item{'rank'}) {
			print " ";
			print color $RANK_COLORS{$results_item{'rank'}};
			print +SKULL_CROSSBONES;
			print color 'reset';
		}
		print " ($results_item{'size_value'} $results_item{'size_unit'}) ";
		print color +NO_SEEDERS_COLOR if($results_item{'seeders'} == 0);
		print "($results_item{'seeders'}/$results_item{'leechers'})";
		print color 'reset' if($results_item{'seeders'} == 0);
		if($results_item{'comments'} > 0) {
			print " ";
			print colored ("($results_item{'comments'})", +COMMENTS_COLOR);
		}
		print "\n";

		if($args{i}) {
			print "    Uploaded by ";
			print color $RANK_COLORS{$results_item{'rank'}} if($results_item{'rank'});
			print "$results_item{'uploader'}";
			print color 'reset';
			print " on date" if($results_item{'date'} =~ /\d\d-\d\d/);
			print " $results_item{'date'}";
			if($results_item{'date_year_time'} =~ /\d\d:\d\d/) {
				print " at ";
			} else {
				print "-";
			}
			print "$results_item{'date_year_time'}";
			print " to category $results_item{'category'}/$results_item{'sub_category'}.\n";
		}
		++ $index;
	}
}

sub do_page {
	my $page_num = $_[0];
	my @results_page;
	if($results_cache[$page_num]) {
		@results_page = @{$results_cache[$page_num]};
	} else {
		print "Downloading data...\n";
		@results_page = @{download_page($keyword, $page_num, $sorting)};
		$results_cache[$page_num] = \@results_page;
	}
	print_page(\@results_page, 1 + 30 * $page_num);
	print "Enter 'n' for next page. Enter 'p' for previous page.\n";
	print "Enter 'w' to wipe the cache and reload the page. Enter 'q' to quit.\n";
	print "Enter the numbers of the files you would like to download: ";

	my $thread_previous =	threads->create('download_page', $keyword, $page_num - 1, $sorting) if($page_num > 1 && ! $results_cache[$page_num - 1]);
	my $thread_next=		threads->create('download_page', $keyword, $page_num + 1, $sorting) if($page_num < $last_page && ! $results_cache[$page_num + 1]);

	while(1) {
		my @selected = split /\s+/, <STDIN>;
		foreach(@selected) {
			if($_ =~ /\d+/) {
				if(not @results_page) {
					print "No torrents found.\n";
				} elsif($_ > 0 && ${$results_cache[int($_ / 30)]}[$_ - 1 - 30 * $page_num]) {
					print "Downloading ${$results_cache[int($_ / 30)]}[$_ - 1 - 30 * $page_num]{'title'}.\n";
					system("xdg-open ${$results_cache[$page_num]}[$_ - 1 - 30 * $page_num]{'magnet'} >/dev/null 2>&1");
				} else {
					print "Invalid index.\n";
				}
			} elsif($_ eq "n") {
				if($page_num < $last_page) {
					$thread_previous->kill('KILL')->detach if(defined $thread_previous);
					$results_cache[$page_num + 1] = $thread_next->join() if(defined $thread_next);
					do_page($page_num + 1);
				} else {
					print "There are no more pages.\n";
				}
				last;
			} elsif($_ eq "p") {
				if($page_num > 0) {
					$thread_next->kill('KILL')->detach if(defined $thread_next);
					$results_cache[$page_num - 1] = $thread_previous->join() if(defined $thread_previous);
					do_page($page_num - 1);
				} else {
					print "There are no previous pages.\n";
				}
				last;
			} elsif($_ eq "q") {
				$thread_previous->kill('KILL')->detach if (defined $thread_previous);
				$thread_next->kill('KILL')->detach if (defined $thread_next);
				exit 0;
			} elsif($_ eq "w") {
				@results_cache = ();
				do_page($page_num);
				last;
			}
		}
	}
}

# main rutine
do_page 0
