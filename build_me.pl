#!/usr/bin/env perl
use strict;
use warnings;

use File::Spec::Functions qw(catfile catdir curdir);

my ($nargs) = $#ARGV + 1;
if ( glob($nargs) >= 3 ) {
    print("Usage: $0 [target] [subtarget]\n\n");
    print(
"This program will build the optimized version of OpenWrt for the selected [target].\n"
    );
    exit 1;
}

use constant {
    DIST              => 'NoTengoBattery',
    DOWNLOAD_ROOT_URL => 'downloads.notengobattery.com',
    ISSUES            => 'issues',
    LINUX_TARGET      => 'target/linux',
    PROJECTS          => 'projects',
    PROJECT_NAME      => "openwrt-" . $ARGV[0],
    RELEASES          => 'releases',
    RELEASE_NOTES     => 'release-notes',
    ROOT_URL          => 'notengobattery.com',
    TARGET            => $ARGV[0],
    SUBTARGET         => $ARGV[1] || 'generic',
    VERSION           => $ENV{VER} || 'v6.12.5'
};

my ($releaseURL) =
  'https://' . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION );
my ($issuesURL) =
  'https://'
  . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION, ISSUES );
my ($downloadURL) =
  'https://' . catdir( DOWNLOAD_ROOT_URL, PROJECTS, 'openwrt-' . VERSION );
my ($supportURL) =
  'https://'
  . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION,
    RELEASE_NOTES );
my ($curDir)                = curdir();
my ($dSeed)                 = catdir( glob($curDir),    'seeds' );
my ($dScripts)              = catdir( glob($curDir),    'scripts' );
my ($linuxTarget)           = catdir( glob($curDir),    LINUX_TARGET );
my ($fConfig)               = catfile( glob($curDir),   '.config' );
my ($fConfigSeed)           = catfile( glob($curDir),   'config.seed' );
my ($fCommonSeed)           = catfile( glob($dSeed),    'config-common.seed' );
my ($fFeaturesSeed)         = catfile( glob($dSeed),    'config-features.seed' );
my ($fAvailableSeed)        = catfile( glob($dSeed),    'config-available.seed' );
my ($fKernelSeed)           = catfile( glob($dSeed),    'kernel.seed' );
my ($fKernelCommonSeed)     = catfile( glob($dSeed),    'kernel-common.seed' );
my ($fKernelTargetSeed)     = catfile( glob($dSeed),    'kernel-' . TARGET . '.seed' );
my ($fKernelSubtargetSeed)  = catfile( glob($dSeed),    'kernel-' . TARGET . '-' . SUBTARGET . '.seed' );
my ($fPackagesSeed)         = catfile( glob($dSeed),    'packages-' . ($ENV{PKGS} || 'slim') . '.seed' );
my ($fTargetSeed)           = catfile( glob($dSeed),    'target-' . TARGET . '.seed' );
my ($fSubtargetSeed)        = catfile( glob($dSeed),    'target-' . TARGET . '-' . SUBTARGET . '.seed' );
my ($fScriptDiff)           = catfile( glob($dScripts), 'diffconfig.sh' );

sub kernelPatchver {
    my ($mk) = catfile( $linuxTarget, TARGET, 'Makefile' );
    open( my $fh, "<", $mk )
      or die qq(Could not open file '$mk' (KERNEL_PATCHVER): $!);
    while ( my $line = <$fh> ) {
        next unless $line =~ /^\s*KERNEL_PATCHVER\s*[:?]?=\s*(\S+)/;
        close($fh);
        return $1;
    }
    close($fh);
    die qq(Could not find KERNEL_PATCHVER in '$mk'\n);
}

# $(call find_kernel_config,<dir>): first of config-<ver> / config-default that
# exists, else config-default whether or not it exists.
sub findKernelConfig {
    my ( $dir, $ver ) = @_;
    my (@names) =
      ( catfile( $dir, 'config-' . $ver ), catfile( $dir, 'config-default' ) );
    foreach my $name (@names) {
        return $name if -f $name;
    }
    return $names[-1];
}

my ($kver)           = kernelPatchver();
my ($platformDir)    = catdir( $linuxTarget, TARGET );
my ($platformSubDir) = catdir( $linuxTarget, TARGET, SUBTARGET );
my ($targetKconfg)   = findKernelConfig( $platformDir, $kver );
my ($subtargetKconfg) =
    $platformDir eq $platformSubDir
  ? undef
  : findKernelConfig( $platformSubDir, $kver );

# LINUX_RECONFIG_TARGET: the subtarget config only when the target has none.
my ($kconfg) =
  ( !-f $targetKconfg && defined($subtargetKconfg) )
  ? $subtargetKconfg
  : $targetKconfg;

printf( "Kernel seeds -> %s (KERNEL_PATCHVER %s)\n", $kconfg, $kver );

open( COMMON_SEED, "<", glob($fCommonSeed) )
  or die qq(Could not open file '$fCommonSeed' (COMMON_SEED): $!);
open( FEATURES_SEED, "<", glob($fFeaturesSeed) )
  or die qq(Could not open file '$fFeaturesSeed' (FEATURES_SEED): $!);
open( AVAILABLE_SEED, "<", glob($fAvailableSeed) )
  or die qq(Could not open file '$fAvailableSeed' (AVAILABLE_SEED): $!);
open( KERNEL_SEED, "<", glob($fKernelSeed) )
  or die qq(Could not open file '$fKernelSeed' (KERNEL_SEED): $!);
open( TARGET_SEED, "<", glob($fTargetSeed) )
  or die qq(Could not open file '$fTargetSeed' (TARGET_SEED): $!);
open( SUBTARGET_SEED, "<", glob($fSubtargetSeed) )
  or die qq(Could not open file '$fSubtargetSeed' (SUBTARGET_SEED): $!);
open( PACKAGE_SEED, "<", glob($fPackagesSeed) )
  or die qq(Could not open file '$fPackagesSeed' (PACKAGE_SEED): $!);
open( KERNEL_COMMON_SEED, "<", glob($fKernelCommonSeed) )
  or die qq(Could not open file '$fKernelCommonSeed' (KERNEL_COMMON_SEED): $!);
open( KERNEL_TARGET_SEED, "<", glob($fKernelTargetSeed) )
  or die qq(Could not open file '$fKernelTargetSeed' (KERNEL_TARGET_SEED): $!);
open( KERNEL_SUBTARGET_SEED, "<", glob($fKernelSubtargetSeed) )
  or die qq(Could not open file '$fKernelSubtargetSeed' (KERNEL_SUBTARGET_SEED): $!);
open( CONFIG_SEED, ">", glob($fConfigSeed) )
  or die qq(Could not open file '$fConfigSeed' (CONFIG_SEED): $!);
# Drop any seed text a previous run appended before appending again.
if ( -f $kconfg ) {
    system( 'git', 'checkout', '--', $kconfg ) == 0
      or warn qq(Warning: could not reset '$kconfg'; it may carry stale seed text\n);
}
open( KCONFIG, ">>", glob($kconfg) )
  or die qq(Could not open file '$kconfg' (KCONFIG): $!);

# All three kernel seeds go to the single reconfig target. Read each handle
# into a list first: a filehandle in list context is drained by one read, so
# reading the same handle twice silently yields nothing the second time.
my (@kernelCommonSeed)    = <KERNEL_COMMON_SEED>;
my (@kernelTargetSeed)    = <KERNEL_TARGET_SEED>;
my (@kernelSubtargetSeed) = <KERNEL_SUBTARGET_SEED>;

print( KCONFIG @kernelCommonSeed,    "\n" );
print( KCONFIG @kernelTargetSeed,    "\n" );
print( KCONFIG @kernelSubtargetSeed, "\n" );
close(KCONFIG);

# Wipe all cached build metadata before touching the feeds.
system("rm -rf feeds/*.tmp feeds/*.index feeds/*.targetindex tmp/info tmp/.packageinfo tmp/.targetinfo");
# scripts/feeds honors a ^commit only when it clones; an existing checkout is
# just pulled --ff-only, a no-op on its detached HEAD, so the pin is enforced here.
open( FEEDS_CONF, "<", "feeds.conf.default" )
  or die qq(Could not open file 'feeds.conf.default' (FEEDS_CONF): $!);
while ( my $feed = <FEEDS_CONF> ) {
    next unless $feed =~ /^src-git(?:-full)?\s+(\S+)\s+\S+\^([0-9a-f]{7,40})\s*$/;
    my ( $name, $pin ) = ( $1, $2 );
    next unless -e "feeds/$name/.git";
    chomp( my $head = `git -C feeds/$name rev-parse HEAD 2>/dev/null` );
    next if index( $head, $pin ) == 0;
    print qq(Re-pinning feed '$name': $head -> $pin\n);
    system( 'git', '-C', "feeds/$name", 'fetch', '--depth=1', 'origin', $pin ) == 0
      and system( 'git', '-C', "feeds/$name", '-c', 'advice.detachedHead=false', 'checkout', '-q', $pin ) == 0
      or die qq(Feed '$name' could not be pinned to $pin\n);
}
close(FEEDS_CONF);
system("./scripts/feeds update -a");
system("rsync -a --delete --exclude='.git' feeds/mwan3/ feeds/packages/net/mwan3/");
system("rsync -a --delete --exclude='.git' feeds/luci_mwan3/ feeds/luci/applications/luci-app-mwan3/");
system("./scripts/feeds install -a");
# scripts/feeds runs its own silent defconfig, which deletes any seed line
# whose package is not yet installed — so the seeds go in only after install.
open( CONFIG, ">", glob($fConfig) )
  or die qq(Could not open file '$fConfig' (CONFIG): $!);
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_BUG_URL",     glob($issuesURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_DIST",        DIST );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_HOME_URL",    glob($releaseURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_NUMBER",      VERSION );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_REPO",        glob($downloadURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_SUPPORT_URL", glob($supportURL) );
print( CONFIG <COMMON_SEED>,    "\n" );
print( CONFIG <FEATURES_SEED>,  "\n" );
print( CONFIG <AVAILABLE_SEED>, "\n" );
print( CONFIG <KERNEL_SEED>,    "\n" );
print( CONFIG <TARGET_SEED>,    "\n" );
print( CONFIG <SUBTARGET_SEED>, "\n" );
print( CONFIG <PACKAGE_SEED>,   "\n" );
close(CONFIG);
system("rm -rf .config.old");
system("make -j32 defconfig");
system("rm -rf .config.old");
system("make -j32 kernel_oldconfig");
my ($fBinTarget) = catdir( glob($curDir), 'bin', 'targets', TARGET, SUBTARGET );
for my $binDir ( glob( $fBinTarget . '*' ) ) {
  system( "find " . $binDir . " -type f -exec rm -f {} +" ) if -d $binDir;
}
print( CONFIG_SEED readpipe("$fScriptDiff") );

print("\n\nProject configured. Now is a good moment to build.\n")
