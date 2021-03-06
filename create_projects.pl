#!/usr/bin/perl

use  strict;
use File::Spec;

sub sed {
  if ($^O eq "linux") {
    `sed \"$_[0]\" -i $_[1]`;
  } else {
    `sed -i '' \"$_[0]\" $_[1]`;
  }
}

system("/usr/bin/perl refresh_projects.pl ");

my $MOZOBJDIR="";
my $MOZSRCDIR="";
my $WORKSPACEDIR="";
my $PROJECTNAME="";
my $configFile=`cat mozconfig_values`;
while ($configFile=~/^(.*)$/gm) {
  my $line = $1;
  $line =~ s{\$(\w+)}{ exists $ENV{$1} ? $ENV{$1} : q/$/.$1 }ge;
  $line =~ s{\$\{(\w+)\}}{ exists $ENV{$1} ? $ENV{$1} : q/${/.$1.q/}/ }ge;
  if ($line=~/MOZOBJDIR\s*\=\s*(.*)/) {
    $MOZOBJDIR=$1;
  } elsif ($line=~/MOZSRCDIR\s*\=\s*(.*)/) {
    $MOZSRCDIR=$1;
  } elsif ($line=~/WORKSPACEDIR\s*\=\s*(.*)/) {
    $WORKSPACEDIR=$1;
  } elsif ($line=~/PROJECTNAME\s*\=\s*(.*)/) {
    $PROJECTNAME=$1;
  }
}
my $PROJECTDIR = "$WORKSPACEDIR/$PROJECTNAME";

my $MOZAPPDIR="";
my $COMPATLIBJAR="";
my $PKGNAME="";
my $autoConfR = `cat $MOZOBJDIR/config/autoconf.mk`;
while ($autoConfR=~/^(.*)$/gm) {
  my $line = $1;
  if ($line=~/^MOZ_BUILD_APP\s*\=\s*(.*)$/) {
    $MOZAPPDIR=$1;
  } elsif ($line=~/^ANDROID_COMPAT_LIB\s*\=\s*(.*)$/) {
    $COMPATLIBJAR=$1;
  } elsif ($line=~/^ANDROID_PACKAGE_NAME\s*\=\s*(.*)$/) {
    $PKGNAME=$1;
  }
}

my $manifest = `find $MOZOBJDIR/$MOZAPPDIR/base -name AndroidManifest.xml`;
chomp($manifest);

my $mainactivityname = "";
my $projectName="";
open(my $mfh, '<', $manifest) or die $!;
while (<$mfh>) {
  if (/\s*package\s*\=\s*\"(.*)\"/) {
    $projectName = $1;
  } elsif (/\<activity android\:name\=\"(.*)\"/) {
    $mainactivityname = $1;
    print "Main Activity:".$mainactivityname."\n";
    last;
  }
}
close($mfh);

mkdir $PROJECTDIR;
my $pkgdir = $PKGNAME;
$pkgdir =~ s/\./\//g;
system("cp -rf ztemplates/.classpath $PROJECTDIR/");
sed("s|\@_REPLACE_PACKAGE_DIR\@|$pkgdir|", "$PROJECTDIR/.classpath");
system("cp -rf ztemplates/project.properties $PROJECTDIR/");
system("cp -rf ztemplates/.project $PROJECTDIR/");
sed("s/\@_REPLACE_APP_NAME\@/$mainactivityname/", "$PROJECTDIR/.project");

mkdir "$PROJECTDIR/.externalToolBuilders";
system("cp -rf ztemplates/*.launch $PROJECTDIR/.externalToolBuilders/");
sed("s|\@_REPLACE_OBJ_PROJECT_PATH\@|$MOZOBJDIR/$MOZAPPDIR/base|", "$PROJECTDIR/.externalToolBuilders/*.launch");
sed("s|\@_REPLACE_OBJ_PATH\@|$MOZOBJDIR|", "$PROJECTDIR/.externalToolBuilders/*.launch");
sed("s|\@_REPLACE_PROJECT_NAME\@|$PROJECTNAME|", "$PROJECTDIR/.externalToolBuilders/*.launch");
system("cp -rf ztemplates/_PROJECT_ACTIVITY_TEMPLATE.launch $PROJECTDIR/bin/$mainactivityname.launch");
system("cp -rf ztemplates/_PROJECT_ACTIVITY_TEMPLATE.launch $PROJECTDIR/bin/$mainactivityname.launch");
sed("s/\@_REPLACE_APP_NAME\@/$mainactivityname/", "$PROJECTDIR/bin/$mainactivityname.launch");
sed("s/\@_PACKAGE_NAME_\@/$projectName/", "$PROJECTDIR/bin/$mainactivityname.launch");

mkdir "$PROJECTDIR/.settings";
system("cp -rf ztemplates/org.eclipse.jdt.core.prefs $PROJECTDIR/.settings/");

mkdir "$PROJECTDIR/scripts";
system("cp -rf ztemplates/save-actions.pl $PROJECTDIR/scripts/");
sed("s|\@_REPLACE_MOZ_SRC_DIR\@|$MOZSRCDIR/$MOZAPPDIR/base|", "$PROJECTDIR/scripts/*");
sed("s|\@_REPLACE_PACKAGE_NAME\@|$PKGNAME|", "$PROJECTDIR/scripts/*");

mkdir "$PROJECTDIR/jars";

# link android compatibility library jar
my ($volume,$directories,$file) = File::Spec->splitpath($COMPATLIBJAR);
if (stat("$PROJECTDIR/jars/$file")) {
  unlink("$PROJECTDIR/jars/$file");
}
system("ln -s $COMPATLIBJAR $PROJECTDIR/jars/");

# link robotium jar
my $testjars = `find $MOZSRCDIR/build/mobile/robocop -name "*.jar"`;
while ($testjars=~/^(.*)$/gm) {
  my ($volume,$directories,$file) = File::Spec->splitpath($1);
  if (stat("$PROJECTDIR/jars/$file")) {
    unlink("$PROJECTDIR/jars/$file");
  }
  system("ln -s $1 $PROJECTDIR/jars/");
}

# link app jars
my $appjars = `find $MOZOBJDIR/$MOZAPPDIR/base -name "*.jar"`;
while ($appjars=~/^(.*)$/gm) {
  my ($volume,$directories,$file) = File::Spec->splitpath($1);
  if (stat("$PROJECTDIR/jars/$file")) {
    unlink("$PROJECTDIR/jars/$file");
  }
  system("ln -s $1 $PROJECTDIR/jars/");
}

mkdir "$PROJECTDIR/classes";

my $robocopclasses = "$MOZOBJDIR/build/mobile/robocop/classes";
if (stat("$robocopclasses")) {
  unlink("$robocopclasses");
}
symlink($robocopclasses, "$PROJECTDIR/classes/robocop");

system('android update project --path "' + $WORKSPACEDIR + '" --subprojects --target ' +
          '"android-$(' +
           'android list | grep -o android-[1-9][0-9]* | grep -o [1-9][0-9]* |  sort -nr | head -n 1' +
          ')"');


