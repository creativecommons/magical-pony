# Magical Pony!

What this code does:

* When you run it, it loops over all the branches in your git repo, and makes a copy of each of them in /srv/clones/.

* Then it makes an Apache config for each one, based on a template. It replaces the word "MAGICALPONY" in each template with the name of the branch.

* It then restarts Apache.

To the extent possible under law, the person who associated CC0 with
this work has waived all copyright and related or neighboring rights
to this work.
