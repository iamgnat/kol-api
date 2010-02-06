#!/usr/bin/perl -I/path/to/your/kol-api/lib/perl -w

# $Id$

# Copyright KoLAPI (http://kol-api.googlecode.com)

use strict;
use KoL;
use KoL::CommandLine;
use KoL::Logging;
use KoL::Session;
use KoL::Terrarium;

my $cli = KoL::CommandLine->new();
my $log = KoL::Logging->new();

$cli->addOption(
    'name'          => 'user',
    'short-name'    => 'u',
    'type'          => 'string',
    'required'      => 1,
    'description'   => 'Your KoL user name.'
);
$cli->addOption(
    'name'          => 'email',
    'short-name'    => 'e',
    'type'          => 'string',
    'required'      => 1,
    'description'   => 'Your email address (for the request headers).'
);
$cli->process();

my $mail = $cli->getValue('email');
my $user = $cli->getValue('user');
my $pass = promptUser("Enter password for '$user':", 'password');

# Setup the session and log in.
my $sess = KoL::Session->new('email' => $mail);
if (!$sess->login($user, $pass)) {
    $log->error("Unable to login as '$user': $@");
    exit(1);
}

# Show the charpane.php info
my $stats = $sess->stats();
my $effs = $stats->effects();
my $effects = '';
foreach my $name (sort(keys(%{$effs}))) {
    $effects .= "\n    $name (" . $effs->{$name}{'count'} . ")";
}

$log->msg("Current Stats:" .
            "\nLevel: " . $stats->level() .
            "\nTitle: " . $stats->title() .
            "\nMeat:  " . $stats->meat() .
            "\nTurns Left: " . $stats->turns() .
            "\nLast Adventure: " . $stats->lastAdventure() .
            "\nMuscle: " . join('/', $stats->muscle()) .
            "\nMysticality: " . join('/', $stats->mysticality()) .
            "\nMoxie: " . join('/', $stats->moxie()) .
            "\nHP: " . join('/', $stats->hp()) .
            "\nMP: " . join('/', $stats->mp()) .
            "\nEffects:$effects");

# Get your Terrarium object and display info on your current familiar.
my $ter = KoL::Terrarium->new('session' => $sess);
my $curr = $ter->currentFamiliar();
if ($@) {
    $log->error("Unable to get current familiar: $@");
    $sess->logout();
    exit(1);
}
if (!$curr) {
    $log->msg("You do not have a current familiar.");
} else {
    my $equip = '';
    if ($curr->equip()) {
        $equip = ' equipped with a ' . $curr->equip()->name();
    }
    $log->msg("Your current familiar is " . $curr->name() . " the " .
                $curr->weight() . "lb " . $curr->type() . $equip . ".");
}

# Logout
if (!$sess->logout()) {
    $log->error("Unable to logout '$user': $@");
    exit(1);
}
exit(0);
