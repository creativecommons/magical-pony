#!/bin/bash

# I am really sorry for anyone who has to work with this, including myself and Kat.

cd ~/host/

for branch in `git branch -a | grep remotes | grep -v HEAD | grep -v master`; do git checkout $(basename "$branch"); mkdir -p /srv/clones/$(basename "$branch"); git archive $(basename "$branch") | tar -xC /srv/clones/$(basename "$branch"); cp ~/default /etc/apache2/sites-enabled/$(basename "$branch").conf; perl -p -i -e "s/MAGICALPONY/$(basename "$branch")/g" /etc/apache2/sites-enabled/$(basename "$branch").conf; done

service apache2 restart
