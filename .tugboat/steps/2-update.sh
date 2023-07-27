#!/bin/bash

set -eux
echo "Updating..."

#drainpipe-start
mv .tugboat .tugboat-tmp
#drainpipe-end
composer install
./vendor/bin/task sync

# Set file permissions such that Drupal will not complain.
chgrp -R www-data "${DOCROOT}/sites/default/files"
find "${DOCROOT}/sites/default/files" -type d -exec chmod 2775 {} \;
find "${DOCROOT}/sites/default/files" -type f -exec chmod 0664 {} \;
#drainpipe-start
./vendor/bin/drush config:export --yes
rm -rf .tugboat
mv .tugboat-tmp .tugboat
#drainpipe-end
