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

my ($kconfgPathPatternSub) =
  sprintf '*/%s/%s/*config-*.*', TARGET, SUBTARGET;
my ($kconfgPathPatternMain) =
  sprintf '*/%s/*config-*.*', TARGET;
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
my ($fKernelSeed)           = catfile( glob($dSeed),    'kernel.seed' );
my ($fKernelCommonSeed)     = catfile( glob($dSeed),    'kernel-common.seed' );
my ($fKernelTargetSeed)     = catfile( glob($dSeed),    'kernel-' . TARGET . '.seed' );
my ($fKernelSubtargetSeed)  = catfile( glob($dSeed),    'kernel-' . TARGET . '-' . SUBTARGET . '.seed' );
my ($fPackagesSeed)         = catfile( glob($dSeed),    'packages-' . ($ENV{PKGS} || 'slim') . '.seed' );
my ($fTargetSeed)           = catfile( glob($dSeed),    'target-' . TARGET . '.seed' );
my ($fSubtargetSeed)        = catfile( glob($dSeed),    'target-' . TARGET . '-' . SUBTARGET . '.seed' );
my ($fScriptDiff)           = catfile( glob($dScripts), 'diffconfig.sh' );

my ($subkconfg) =
  readpipe( sprintf "find %s -type f -path '%s' | head -n 1", $linuxTarget, $kconfgPathPatternSub );
my ($kconfg) =
    readpipe( sprintf "find %s -type f -path '%s' | head -n 1", $linuxTarget, $kconfgPathPatternMain );

open( COMMON_SEED, "<", glob($fCommonSeed) )
  or die qq(Could not open file '$fCommonSeed' (COMMON_SEED): $!);
open( FEATURES_SEED, "<", glob($fFeaturesSeed) )
  or die qq(Could not open file '$fFeaturesSeed' (FEATURES_SEED): $!);
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
open( CONFIG, ">", glob($fConfig) )
  or die qq(Could not open file '$fConfig' (CONFIG): $!);
system("git checkout " . $kconfg);
open( KCONFIG, ">>", glob($kconfg) )
  or die qq(Could not open file '$kconfg' (KCONFIG): $!);
if ( defined($subkconfg) && -f glob($subkconfg) ) {
open( SUBKCONFIG, ">>", glob($subkconfg) )
  or die qq(Could not open file '$subkconfg' (SUBKCONFIG): $!);
}
  

printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_BUG_URL",     glob($issuesURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_DIST",        DIST );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_HOME_URL",    glob($releaseURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_NUMBER",      VERSION );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_REPO",        glob($downloadURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_SUPPORT_URL", glob($supportURL) );
print( CONFIG <COMMON_SEED>,    "\n" );
print( CONFIG <FEATURES_SEED>,  "\n" );
print( CONFIG <KERNEL_SEED>,    "\n" );
print( CONFIG <TARGET_SEED>,    "\n" );
print( CONFIG <SUBTARGET_SEED>, "\n" );
print( CONFIG <PACKAGE_SEED>,   "\n" );
close(CONFIG);

print( KCONFIG <KERNEL_COMMON_SEED>, "\n" );
print( KCONFIG <KERNEL_TARGET_SEED>, "\n" );
if ( !defined($subkconfg) || !-f glob($subkconfg) ) {
  print( KCONFIG <KERNEL_SUBTARGET_SEED>, "\n" );
}
close(KCONFIG);

if ( defined($subkconfg) && -f glob($subkconfg) ) {
  print( SUBKCONFIG <KERNEL_COMMON_SEED>, "\n" );
  print( SUBKCONFIG <KERNEL_TARGET_SEED>, "\n" );
  print( SUBKCONFIG <KERNEL_SUBTARGET_SEED>, "\n" );
  close(SUBKCONFIG);
}

# Wipe all cached build metadata before touching the feeds.
system("rm -rf feeds/*.tmp feeds/*.index feeds/*.targetindex tmp/info tmp/.packageinfo tmp/.targetinfo");
system("./scripts/feeds update -a");
system("rsync -a --delete --exclude='.git' feeds/mwan3/ feeds/packages/net/mwan3/");
system("rsync -a --delete --exclude='.git' feeds/luci_mwan3/ feeds/luci/applications/luci-app-mwan3/");
system("./scripts/feeds install -a");
system("rm -rf .config.old");
system("make -j32 defconfig");
system("rm -rf .config.old");
system("make -j32 kernel_oldconfig");
system("find ./bin -type f -exec rm -f {} +");
print( CONFIG_SEED readpipe("$fScriptDiff") );

print("\n\nProject configured. Now is a good moment to build.\n")
