package VPNConnect;
use strict;
use Net::Ping;
use Data::Dumper;

sub new {

    # Only one option: we must pass the folder containing our ovpn files
    my ($class , $dir, $verbose) = @_;

    $verbose = 0 unless(defined $verbose);
    $verbose = 0 unless($verbose eq 1);

    my $this = {
        DIR => $dir,
        VERBOSE => $verbose
    };

    bless($this , $class);

    # Attributes of class
    $this->{SERVER} = undef; # A hash containing details about the server designed for connection
    $this->{PID} = undef; # Used to end the session after disconnect call. The function needs the child process pid to end connection.
    $this->{TUN} = undef; # TUN adapter number, 0 by default

    return $this;

}

# Function to get all ovpn files. returns all ovpn files found on the specified dir
sub getovpnfiles {

    my ($this) = @_;
    my @ovpn;

    die "Le dossier $this->{DIR} ne semble pas exister.\n" unless (-d $this->{DIR});

    @ovpn = glob("$this->{DIR}/*.ovpn");
    die "Aucun fichier ovpn contenu dans le dossier $this->{DIR}.\n" unless(@ovpn);

    return @ovpn;

}

# Method to retrieve the server name in the ovpn file. returns the server ip
sub getserver {

    my ($this , $file) = @_;
    my $server;
    my $occ = 0;

    open(OVPNCONFIG , "<$file") or die "Impossible d'ouvrir le fichier $file pour lecture: $!\n";

    for(<OVPNCONFIG>) {

        chomp;
        $server = (split(/ / , $_))[1] and $occ++ if($_ =~ /(^remote).*(tcp|udp|([0-9]){1,})/);

    }

    die "Parametre 'remote' absent du fichier de configuration $file.\n" unless($occ > 0);
    close(OVPNCONFIG);

    return $server;
}

# Method to elect the fastest vpn. returns informations concerning the fastest server obtained
sub getfastest {

    my ($this) = @_;
    my ($timeref , %fastest , @ovpn , $occ);
    $occ = 0;
    %fastest = ();

    @ovpn = $this->getovpnfiles();

    for(@ovpn) {

        my $server = {};
        $server->{'name'} = $this->getserver($_);
        $server->{'config'} = $_;

        my $p = Net::Ping->new();
        my ($ret , $time , $ip) = $p->ping($server->{'name'});

        $occ++ if $ret;
        $server->{'time'} = $time;
        $server->{'ip'} = $ip;
        $timeref = $server->{'time'} if($occ == 1);
        $timeref = $server->{'time'} and %fastest = %$server if($occ == 1);
        $timeref = $server->{'time'} and %fastest = %$server if($server->{'time'} < $timeref);

        $p->close();
    }

    die "Aucune connexion aupres des differents serveurs n'a pu aboutir: $!\n" unless($occ > 0);

    return \%fastest; # We return the reference of the given hash

}

# Method to connect to the fastest server. returns 1 if success, 0 else.
sub connect {

    my ($this , $custom_config, $tunumb) = @_;
    my ($uid , $EUID , $cmd , $pid, $server, $redirect);

    $tunumb = 0 if not defined $tunumb;
    $this->{TUN} = 'tun'.$tunumb;

    # We check if the user has sufficient rights to execute openvpn binary
    (defined($EUID) and $EUID != '') ? $uid = $EUID : chomp($uid = `id -u`);
    die "Privileges insuffisants pour pouvoir generer une quelconque connexion.\n" unless($uid eq 0);

    if(defined $custom_config) {

        # Then we select manually the given server
        $custom_config = "$this->{DIR}/$custom_config";
        die "Impossible de trouver le fichier $custom_config.\n" unless(-e $custom_config);

        $server->{'config'} = $custom_config;
        $server->{'name'} = $this->getserver($server->{'config'});

    } else {

        # Then we get the fastest server of the list
        $server = $this->getfastest();

    }

    $this->{SERVER} = $server;
    $redirect = ">/dev/null 2>&1" if($this->{VERBOSE} eq 0);
    $cmd = "openvpn --config $server->{'config'} --dev $this->{TUN} $redirect";

    # To finish, we establish the connection to the selected vpn server
    $pid = fork;

    die "Impossible d'initier le processus de connexion au serveur: $!\n" unless(defined($pid));

    # If we are in the child process
    if($pid == 0) {

        exec($cmd) or die "Impossible de demarrer la connexion au serveur $server->{'name'}: $!\n";

    }

    # We keep the child process id to kill it with the disconnect method later
    $this->{PID} = int($pid);

    return 1;

}

# Method to retrieve the server name. Returns its name.
sub getservername {

    my ($this) = @_;
    return $this->{SERVER}->{'name'};

}

# Method to get informations about the connection process.
sub connectiondesc {

    my ($this) = @_;

    print("Details du serveur utilise pour la connexion:\n");
    print Dumper ($this->{SERVER});
    print("\nPID du processus de connexion au serveur (processus enfant): $this->{PID}\n");

    return;

}

# Method to obtain the new unlocked tun adapter's name.
sub getunadapter {

    my ($this) = @_;
    return $this->{TUN};

}

#Method to get the tun adapter state. Useful if we want to be sure that connection was really successful. Returns 1 if the tun adapter is fully charged and active.
sub getunstate {

    my ($this) = @_;
    my $tun = qx{ls /sys/class/net | grep $this->{TUN}};
    #my $tun = qx{ip tuntap show | grep $this->{TUN}};

    return 0 unless($tun);
    return 1;

}

# Method to disconnect from the vpn.
sub disconnect {

    my ($this) = @_;

    # We end the connection, 0 to close child processes with the parent one
    kill(0 , $this->{PID}) or die "Impossible de mettre fin a la connexion: $!\n";

    return 1;

}

1;
