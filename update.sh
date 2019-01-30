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

rm -rf "${checkoutdir}"

mkdir -p "${checkoutdir}"

{
    echo '<h1>Updating the Magical Pony</h1>'
    echo "<h2>$(date '+%A %F %T %:::z %Z')</h2>"
    cat pony.img.html
} > "${statusfile}"

pushd "${checkoutdir}"
echo

echo "# git clone ${repo}"
# Get a clean version to avoid any merge/reset weirdness
git clone "${repo}" .
echo

echo '<h2>Branches</h2>' >> "${statusfile}"

for branchname in $(git branch -r | grep -v 'HEAD\|master')
do
    echo "# ${branchname}"
    branchid="${branchname##*/}"
    branchpath="/srv/clones/${branchid}"
    webroot="${branchpath}/docroot"
    domain="${branchid}.legal.creativecommons.org"
    certbotargs="${certbotargs:-} -w ${webroot} -d ${domain}"
    echo "${branchpath}"
    git checkout -f -q "${branchname}"
    git show-branch --sha1-name HEAD
    mkdir -p "${branchpath}.NEW"
    git archive "${branchname}" \
        | tar -xC "${branchpath}.NEW"
    [[ -d ${branchpath} ]] && mv ${branchpath} ${branchpath}.OLD
    mv ${branchpath}.NEW ${branchpath}
    [[ -d ${branchpath}.OLD ]] && rm -rf ${branchpath}.OLD
    # Ensure branchpath mtime is up-to-date
    touch ${branchpath}/.gitignore
    cp "${resourcedir}/default" \
       "/etc/apache2/sites-enabled/${branchid}.conf"
    perl -p -i -e "s/MAGICALPONY/${branchid}/g" \
         "/etc/apache2/sites-enabled/${branchid}".conf
    hash=$(git log ${branchname} -1 --format='%H')
    {
        echo '<hr>'
        echo "<h3>${branchid} (${branchname})</h3>"
        echo '<p><b>Commit: </b>'
        echo "    <a href=\"https://github.com/creativecommons/creativecommons.org/commit/${hash}\">${hash}</a>"
        echo '</p>'
        echo "<p><a href=\"https://${domain}/\">${domain}</a></p>"
    } >> "${statusfile}"
    git log ${branchname} -1 --format="<p>%s</p>" >> "${statusfile}"
    echo
done

popd
echo

echo '# cerbotargs:'
echo "${certbotargs}"
echo
echo '# run cerbot'
echo
# Get any new certificates, incorporate old one, refresh expiring, install any
# new http->https redirects, and do so automatically.
if /usr/bin/certbot --authenticator webroot --installer apache \
                 --agree-tos -m webmaster@creativecommons.org \
                 --non-interactive --expand --keep-until-expiring \
                 ${certbotargs}
then
    echo '<h1>And we are done!</h1>' >> "${statusfile}"
else
    {
        echo '<h1>certbot ERROR</h1>'
        echo '<p>See <pre>/var/log/letsencrypt/letsencrypt.log</pre>.</p>'
    } >> "${statusfile}"
fi
echo

echo "<h2>$(date '+%A %F %T %:::z %Z')</h2>" >> "${statusfile}"

# Touch primary apache files to ensure they are preserved
touch /etc/apache2/sites-enabled/legal.creativecommons.org.conf
touch /etc/apache2/sites-enabled/legal.creativecommons.org-le-ssl.conf

echo 'Directories older than 24 hours are deleted by magical-pony update.sh' \
    > /srv/clones/README
echo '# Clean-up: /srv/clones'
find /srv/clones/* -maxdepth 0 -type d -mtime +1
find /srv/clones/* -maxdepth 0 -type d -mtime +1 -exec rm -rf {} +
echo

echo 'Files older than 24 hours are deleted by magical-pony update.sh' \
    > /etc/apache2/sites-enabled/README
echo '# Clean-up: /etc/apache2/sites-enabled/'
find /etc/apache2/sites-enabled -mtime +1
find /etc/apache2/sites-enabled -mtime +1 -delete
echo

service apache2 restart
