# Irssi Bookmarks by CarpeNoctem https://github.com/CarpeNoctem
#
# Note: For compatability with existing irssi commands, aliases, and other scripts,
#       bookmarks.pl uses the below commands. Personally, I've aliased these as /b, /lb, 
#       /shrink, and /rmb, respectively. (Since I have autosave on, I don't really use the last 3 cmds.)
#
# Commands:
#          /bookmark <-s> <URL> - bookmarks <URL>, or the last seen URL in the current window
#                                 if -s option is used, bookmarks it in shortened form.
#          /bookmarks <-a|-s|search_term>
#                               - lists all saved bookmarks - '-a' option forces listing of long links,
#                                 while '-s' forces only shortened links to be listed (when available).
#                                 Additionally, the argument may be a search term.
#          /bookmark_shorten <URL>
#          /bshorten <URL>
#                               - prints shortened <URL> and adds it to bookmarks if not already there.
#                                 if already in bookmarks, adds shortened URL next to it
#          /bookmark_rm <URL>   - removes <URL> from bookmarks. if no url provided, removes last bookmarked url.
#          /bookmarks_save      - explicitly save current bookmarks to file
#          /bookmarks_reload    - (re)load bookmarks from file in addition to any already in memory (excluding duplicates)
#          /bookmarks_clear     - clears the list of bookmarks (CAREFUL - Will clear from file as well if autosave
#                                 is enabled. The list will be printed first, however, as long as listonclear is ON)
#                                                               
#
# Settings:
#          bookmarks_file      - default: '~/.irssi/irssi.bookmarks'
#          bookmarks_shortener - default: 'is.gd' (http://is.gd)
#          bookmarks_hide_long - default: OFF - don't show long url if shortened one exists (otherwise shows both)
#          bookmarks_autosave  - default: ON - update file each time a bookmark is added.
#          bookmarks_list_on_clear - default: ON - prints bookmarks before clearing the list
#
# TODO: 
#      * implement url shortening for other services: tinyurl, goo.gl, bit.ly
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '1.0';
%IRSSI = (
    authors     => 'CarpeNoctem',
    contact     => 'aj2600 at gmail dot com',
    name        => 'Irssi Bookmarks',
    description => 'Manages a list of bookmarks within irssi',
    license     => 'https://raw.github.com/CarpeNoctem/irssi-bookmarks/master/LICENSE',
    modules     => 'Irssi, URI::Escape, File::Glob, LWP::Simple',
    changed     => '20120720',
    blob        => '$Id$',
);

use Irssi;
use File::Glob ':glob';
use URI::Escape;
use LWP::Simple;

my %last_url;
my %bookmarks;
my $bookmarks_file;
my $last_added;

sub cmd_bookmark {
    my ($data, $server, $target) = @_;
    if ($data =~ m/^-s/) {
        return cmd_shorten(@_);
    }
    my $cur_win = $target->{name};
    unless (!$data) {
        &add_bookmark("$data");
        $data =~ s/%/%%/g;
        Irssi::print($data.' added to bookmarks');
    }
    else {
        if ($last_url{$cur_win}) { #bookmark last seen url in current window
            &add_bookmark($last_url{$cur_win});
            (my $bookmark = $last_url{$cur_win}) =~ s/%/%%/g;
            Irssi::print('Bookmarked last seen url: '.$bookmark);
            delete $last_url{$cur_win};
        }
        else {
            Irssi::print('No new urls seen here.'); 
        }
    }
}

sub cmd_remove_bookmark {
    my $url = shift;
    if (!$url) {
        $url = $last_added;
        $last_added = '';
    }
    if ( exists $bookmarks{$url} ) {
        delete $bookmarks{$url};
    }
    else { #maybe we're removing based on the shortened form
        while ( my ($long, $short) = each(%bookmarks) ) {
            if ( $url eq $short ) {
                delete $bookmarks{$long};
            }
        }
    }    
    if ( Irssi::settings_get_bool('bookmarks_autosave') ) {
        &save_bookmarks;
    }
    $url =~ s/%/%%/g;
    Irssi::print($url.' removed from bookmarks');
}

sub cmd_list_bookmarks {
    my $data = shift;
    unless ( $data && $data ne '-a' && $data ne '-s' ) {
        Irssi::print(keys(%bookmarks) . ' bookmarks:');
    }
    else {
        Irssi::print("Bookmarks matching '$data':");
    }
    while ( my ($url, $shortened) = each(%bookmarks) ) {
        my $data = $data;
        if ( $data && $data ne '-a' && $data ne '-s' ) { #if we're searching
            if ( $url !~ m/$data/i && $shortened !~ m/$data/i ) {
                next;
            }
            $data = '-a';
        }
        if ($url eq $shortened) {
            $url =~ s/%/%%/g;
            Irssi::print("$url");
        }
        else {
            $url =~ s/%/%%/g;
            $shortened =~ s/%/%%/g;
            if ( (!Irssi::settings_get_bool('bookmarks_hide_long') || $data eq '-a' || $data eq '-l') && $data ne '-s' ) {
                Irssi::print("$shortened ($url)");
            }
            else {
                Irssi::print("$shortened");
            }
        }
    }
}

sub cmd_save_bookmarks {
    &save_bookmarks;
    Irssi::print('Bookmarks saved to '.Irssi::settings_get_str('bookmarks_file'));
}

sub cmd_clear_bookmarks {
    if ( Irssi::settings_get_bool('bookmarks_list_on_clear') ) {
        &cmd_list_bookmarks('-a');
    }
    %bookmarks = ();
    if ( Irssi::settings_get_bool('bookmarks_autosave') ) {
        &save_bookmarks;
    }
    Irssi::print('All bookmarks removed.');
}

sub cmd_shorten {
    my ($url, $server, $target) = @_;
    my $cur_win = $target->{name};
    if (!$url || $url eq '-s') {
        $url = $last_url{$cur_win};
        delete $last_url{$cur_win};
    }
    if (!$url) {
        Irssi::print('Nothing to shorten');
        return;
    }
    $url =~ s/^-s ?//;
    &shorten_url($url);
    if ( Irssi::settings_get_bool('bookmarks_autosave') ) {
        &save_bookmarks;
    }
    unless ( Irssi::settings_get_bool('bookmarks_hide_long') ) {
        (my $url_safe = $url) =~ s/%/%%/g;
        Irssi::print($url_safe.' shortened to '.$bookmarks{$url});
    }
    else {
        Irssi::print('Shortened to '.$bookmarks{$url});
    }
}

sub add_bookmark {
    my $url = shift;
    $bookmarks{$url} = "$url";
    $last_added = $url;
    if ( Irssi::settings_get_bool('bookmarks_autosave') ) {
        &save_bookmarks;
    }
}

sub store_last_url {
    my ($server, $data, $sender, $addr, $channel) = @_;
    if ($data =~ /(https?:\/\/[^ ]+)/) {
        if (!$channel) {
            $channel = $sender;
        }
        $last_url{$channel} = $1;
    }
}

sub load_bookmarks {
    $bookmarks_file = glob Irssi::settings_get_str('bookmarks_file');
    open(my $fh, "<$bookmarks_file")
        or Irssi::print("Cannot load from $bookmarks_file: $!");
    my $i = 0;
    while ( <$fh> ) {
        my $line = $_;
        $line =~ s/\s+$//; #rtrim()
        if ($line) {
            $i++;
            if ($line =~ /(.+)  (.+)/) { #shortened followed by full url
                $bookmarks{$2} = $1;
            }
            else {
                $bookmarks{$line} = $line;
            }
        }
    }
    close $fh;
    Irssi::print($i.' bookmarks loaded from '.Irssi::settings_get_str('bookmarks_file'));
}

sub save_bookmarks {
    $bookmarks_file = glob Irssi::settings_get_str('bookmarks_file');
    open(my $fh, ">$bookmarks_file")
        or Irssi::print("Cannot save to $bookmarks_file: $!");
    while ( my ($url, $shortened) = each(%bookmarks) ) {
        if ($url eq $shortened) {
            print $fh "$url\n";
        }
        else {
            print $fh "$shortened  $url\n";
        }
    }
    close $fh;
}

sub shorten_url {
    my $url = shift;
    my $url_safe = uri_escape($url);
    my $service = Irssi::settings_get_str('bookmarks_shortener');
    # if ($service eq 'is.gd') {
    my $shortened = get('http://is.gd/create.php?format=simple&url='.$url_safe);
    $bookmarks{$url} = $shortened;
}

Irssi::signal_add_last('message public', 'store_last_url');
Irssi::signal_add_last('message private', 'store_last_url');
Irssi::signal_add_last('message own_public', 'store_last_url'); #also let us bookmark urls that we post
Irssi::signal_add_last('message own_private', 'store_last_url');

Irssi::command_bind('bookmark', 'cmd_bookmark','Irssi Bookmarks commands');
Irssi::command_bind('bookmark_rm', 'cmd_remove_bookmark','Irssi Bookmarks commands'); Irssi::command_bind('rm_bookmark', 'cmd_remove_bookmark','Irssi Bookmarks commands');
Irssi::command_bind('bookmarks', 'cmd_list_bookmarks','Irssi Bookmarks commands');
Irssi::command_bind('bookmarks_save', 'cmd_save_bookmarks','Irssi Bookmarks commands'); Irssi::command_bind('save_bookmarks', 'cmd_save_bookmarks','Irssi Bookmarks commands');
Irssi::command_bind('bookmarks_load', 'load_bookmarks','Irssi Bookmarks commands'); Irssi::command_bind('load_bookmarks', 'load_bookmarks','Irssi Bookmarks commands');
Irssi::command_bind('bookmarks_reload', 'load_bookmarks','Irssi Bookmarks commands'); Irssi::command_bind('reload_bookmarks', 'load_bookmarks','Irssi Bookmarks commands');
Irssi::command_bind('bookmarks_clear', 'cmd_clear_bookmarks','Irssi Bookmarks commands'); Irssi::command_bind('clear_bookmarks', 'cmd_clear_bookmarks','Irssi Bookmarks commands');
Irssi::command_bind('bookmark_shorten', 'cmd_shorten','Irssi Bookmarks commands'); Irssi::command_bind('bshorten', 'cmd_shorten','Irssi Bookmarks commands');

Irssi::settings_add_str('misc', 'bookmarks_file', '~/.irssi/irssi.bookmarks');
Irssi::settings_add_bool('misc', 'bookmarks_autosave', 1);
Irssi::settings_add_str('misc', 'bookmarks_shortener', 'is.gd');
Irssi::settings_add_bool('misc', 'bookmarks_hide_long', 1);
Irssi::settings_add_bool('misc', 'bookmarks_list_on_clear', 1);

&load_bookmarks;
