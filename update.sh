#!/bin/bash
# I am really sorry for anyone who has to work with this, including myself and
# Kat. - mattl
#
# For troubleshooting:
# sudo tail -f /var/log/letsencrypt/letsencrypt.log


set -o errexit
set -o errtrace
set -o nounset

trap '_es=${?};
    _lo=${LINENO};
    _co=${BASH_COMMAND};
    echo "${0}: line ${_lo}: \"${_co}\" exited with a status of ${_es}";
    exit ${_es}' ERR


repo='https://github.com/creativecommons/creativecommons.org.git'
reponame='cc-all-forks'
workdir="${HOME}"
checkoutdir="${workdir}/${reponame}"
resourcedir="${HOME}/magical-pony"
statusfile='/var/www/html/index.html'

rm -rf /srv/old-clones/
rm -rf "${checkoutdir}"

mkdir -p "${checkoutdir}"

{
    echo '<h1>Updating the Magical Pony</h1>'
    echo "<h2>$(date '+%A %F %T %:::z %Z')</h2>"
    cat pony.img.html
} > "${statusfile}"

pushd "${checkoutdir}"

# Get a clean version to avoid any merge/reset weirdness
git clone "${repo}" .

echo '<h2>Branches</h2>' >> "${statusfile}"

hostnames='-d legal.creativecommons.org'

for branch in `git branch -a | grep remotes | grep -v HEAD | grep -v master`;
do
    branchname=$(echo "$branch" | cut -d"/" -f2-)
    branchid="$(basename ${branchname})"
    branchpath="/srv/clones/${branchid}"
    certbotargs="-w $branchpath/docroot -d ${branchid}.legal.creativecommons.org ${certbotargs:-}"
    git checkout -f ${branchname}
#    git reset --hard
#    git pull
    mkdir -p "$branchpath"
    git archive "${branchname}" \
        | tar -xC "$branchpath"
    cp "${resourcedir}/default" \
       "/etc/apache2/sites-enabled/${branchid}".conf
    perl -p -i -e "s/MAGICALPONY/${branchid}/g" \
         "/etc/apache2/sites-enabled/${branchid}".conf
    hash=$(git log ${branchname} -1 --format="%H")
    {
        echo "<h3>${branchid} (${branchname})</h3>"
        echo '<p><b>Commit: </b>'
        echo "    <a href=\"https://github.com/creativecommons/creativecommons.org/commit/${hash}\">${hash}</a>"
        echo "</p>"
    } >> "${statusfile}"
    git log ${branchname} -1 --format="<p>%s</p>" >> "${statusfile}"
done

popd

# Get any new certificates, incorporate old one, refresh expiring, install any
# new http->https redirects, and do so quietly and automatically.

/usr/bin/certbot --authenticator webroot --installer apache \
                 --agree-tos -m webmaster@creativecommons.org \
                 --non-interactive --quiet \
                 --expand --keep-until-expiring --redirect \
                 ${certbotargs}

echo '<h1>And we are done!</h1>' >> "${statusfile}"

rm -rf /srv/old-clones/

echo "<h2>$(date '+%A %F %T %:::z %Z')</h2>" >> "${statusfile}"

chown www-data:www-data "${statusfile}"

service apache2 restart
