#!/usr/bin/perl
# Script de connexion au serveur VPN TigerVPN le plus rapide teste parmi une liste de fichiers ovpn.

use strict;
use sigtrap qw/handler signal_handler normal-signals/;
use lib "/home/DeMeuSX/Documents/Scripts/Perl/libs";
use VPNConnect; # the VPNConnect.pm file class is located in the previous folder

my $waitconn = 10;
my $server = undef;
my $tun = undef;

#my $vpn = VPNConnect->new("/home/DeMeuSX/Documents/VPN/config", 1);
my $vpn = VPNConnect->new("/home/DeMeuSX/Documents/VPN/config");
#die "Impossible de se connecter au serveur vpn\n" unless ($vpn->connect());
#die "Impossible de se connecter au serveur vpn\n" unless ($vpn->connect("ch24.nordvpn.com.tcp.ovpn", 1));
die "Impossible de se connecter au serveur vpn\n" unless ($vpn->connect("ch24.nordvpn.com.tcp.ovpn", 1));

$server = $vpn->getservername();

# We wait until the tun adapter is fully unlocked to continue
while(1) {

    $tun = $vpn->getunstate();
    last if $tun;

}

print("connecte au serveur $server!\n");

# We wait for the ^C signal with the signal_handler method to close the connection properly
# The handler is here to wait for specific normal-signals SIG events
my $in = <>;
sub signal_handler {
    $vpn->disconnect() and die "Fin de connexion.\n";
}
