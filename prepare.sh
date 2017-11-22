#!/bin/bash
set -e

# Get current version

snapshot_version=$( cat matsim/pom.xml | grep "<version>" | sed -E "s/<.?version>//g" | sed -E "s/\s//g" )

if [[ $snapshot_version != *"SNAPSHOT" ]]; then
    echo "Original version is not snapshot - did you really clone the master branch?"
    exit 1
fi

# Setup new versioning

base_version=$( echo $snapshot_version | sed -E "s/-SNAPSHOT//" )
monthly_tag=$( date +"%b%y" | tr [:upper:][:lower:] [:lower:][:lower:] )
monthly_version=$base_version-$monthly_tag

echo "Snapshot version is: $snapshot_version"
echo "Proposed monthly tag is: $monthly_tag"
echo "Proposed monthly version is: $monthly_version"

status=$( true || curl https://api.bintray.com/packages/matsim-eth/matsim/matsim/versions/_latest | grep $monthly_version )

if [ $status ]; then
    echo "Package for $( date +"%B %Y" ) already exists on bintray"
    exit 0
fi

# Rewrite all poms

cd $TRAVIS_BUILD_DIR/matsim
for f in $( find . -name "pom.xml" ); do
    echo "Rewriting $f ..."
    sed -i -E "s/$snapshot_version/$monthly_version/g" $f
done

# Replace the bintray repository (in matsim/pom.xml)
echo "Rewriting bintray repository"
cd $TRAVIS_BUILD_DIR/matsim/matsim
sed -i -E "s&https://api.bintray.com/maven/matsim/matsim/matsim&https://api.bintray.com/maven/matsim-eth/matsim/matsim/&" pom.xml
cd $TRAVIS_BUILD_DIR/matsim/contribs
sed -i -E "s&https://api.bintray.com/maven/matsim/matsim/matsim&https://api.bintray.com/maven/matsim-eth/matsim/matsim/&" pom.xml

# Remove integration tests, otherwise Travis will not be able to run through
echo "Disabling integration tests"
cd $TRAVIS_BUILD_DIR/matsim/matsim
perl -i -p0e 's&<plugin>\s+<groupId>org.apache.maven.plugins</groupId>\s+<artifactId>maven-failsafe-plugin</artifactId>.+?</plugin>&&se' pom.xml
cd $TRAVIS_BUILD_DIR/matsim/contribs
perl -i -p0e 's&<plugin>\s+<groupId>org.apache.maven.plugins</groupId>\s+<artifactId>maven-failsafe-plugin</artifactId>.+?</plugin>&&se' pom.xml


# Remove benchmark and distribution
echo "Removing benchmark, distribution, examples (they cannot be deployed)"
cd $TRAVIS_BUILD_DIR/matsim
sed -i -E "s&<module>distribution</module>&&" pom.xml
sed -i -E "s&<module>benchmark</module>&&" pom.xml
sed -i -E "s&<module>examples</module>&&" pom.xml

# Prepare bintray deployment
echo $monthly_version > version.txt
