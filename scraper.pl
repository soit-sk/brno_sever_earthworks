#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use POSIX qw(strftime);
use URI;
use Time::Local;

# Constants.
my $DATE_WORD_HR = {
	decode_utf8('leden') => 1,
	decode_utf8('únor') => 2,
	decode_utf8('březen') => 3,
	decode_utf8('duben') => 4,
	decode_utf8('květen') => 5,
	decode_utf8('červen') => 6,
	decode_utf8('červenec') => 7,
	decode_utf8('srpen') => 8,
	decode_utf8('září') => 9,
	decode_utf8('říjen') => 10,
	decode_utf8('listopad') => 11,
	decode_utf8('prosinec') => 12,
};

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.sever.brno.cz/omezeni-dopravy/92-vykopove-prace.html');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get base root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Look for items.
my $doc_items = $root->find_by_attribute('class', 'blog');
my @doc = $doc_items->find_by_tag_name('div');
foreach my $doc (@doc) {
	my $doc_attr = $doc->attr('class');
	if ($doc_attr !~ m/^item\s+column-\d+$/ms) {
		next;
	}

	# Title and start date.
	my $title_h2 = $doc->find_by_tag_name('h2');
	my $title_a = $title_h2->find_by_tag_name('a');
	my $title = $title_a->as_text;
	remove_trailing(\$title);
	my $link = URI->new($base_uri->scheme.'://'.$base_uri->host.
		$title_a->attr('href'));
	my $date_start = get_db_date_word($title_h2
		->find_by_attribute('class', 'date')->as_text);

	# Description.
	my $desc = $doc->find_by_attribute('class', 'article-anot')->as_text;

	# TODO Update
	print '- '.encode_utf8($title)."\n";
	$dt->insert({
		'Title' => $title,
		'Start_date' => $date_start,
		'Description' => $desc,
		'Page_link' => $link->as_string,
	});
}

# Get database data from word date.
sub get_db_date_word {
	my $date_word = shift;
	$date_word =~ s/^\s*-\s+//ms;
	my ($day, $mon_word, $year) = $date_word =~ m/^\s*(\d+)\.\s*(\w+)\s+(\d+)\s*$/ms;
	my $mon = $DATE_WORD_HR->{$mon_word};
	my $time = timelocal(0, 0, 0, $day, $mon - 1, $year - 1900);
	return strftime('%Y-%m-%d', localtime($time));
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Removing trailing whitespace.
sub remove_trailing {
	my $string_sr = shift;
	${$string_sr} =~ s/^\s*//ms;
	${$string_sr} =~ s/\s*$//ms;
	return;
}
