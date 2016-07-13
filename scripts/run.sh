#!/bin/bash

# On every container creation we check if files exist in the htdocs directory.
# In case no files are detected we create a new website and keep the current
# database. In case files are found a database restore will be executed the most
# recent *sql* database dump found in the htdocs directory.
if [ -n "$(ls -A /usr/share/nginx/htdocs)" ]; then
  service mysql start
  # Working on an existing project so find the most recent database dump.
  backup=$(ls -t /usr/share/nginx/htdocs/*sql* | head -1)
  # Read the project database configuration with drush.
  db_conf=$(drush --root=/usr/share/nginx/htdocs/ sql-conf --show-passwords)
  database=$(echo "$db_conf"|grep database| awk '{ print $(NF) }')
  username=$(echo "$db_conf"|grep username| awk '{ print $(NF) }')
  password=$(echo "$db_conf"|grep password| awk '{ print $(NF) }')
  # Create the database, user and permissions.
  echo "DROP DATABASE $database" | mysql -uroot
  echo "CREATE DATABASE $database" | mysql -uroot
  echo "GRANT ALL ON *.* TO '$username'@'localhost' identified by '$password'; FLUSH PRIVILEGES;" | mysql -uroot
  # Import the database (non-)compressed.
  if [[ $backup =~ \.gz$ ]]; then
    gunzip -c $backup |mysql -uroot $database
  elif [[ $backup =~ \.sql$ ]]; then
    mysql -uroot $database < $backup
  fi
else
  # We can not mount a volume from the container to the host.
  # This goes against the Docker ethics of reusability of a container.
  # That is why we have to use a workaround and just copy the directory.
  # Like this we also always know the original state of the container.
  sudo cp -rp /usr/share/nginx/drop/. /usr/share/nginx/htdocs
fi
