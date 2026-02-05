# Use an official MariaDB image
FROM mariadb:10.6

# Copy the initialization script to the entrypoint directory.
# Scripts in this directory are executed on first run.
COPY init.sql /docker-entrypoint-initdb.d/

# Expose the default MySQL port
EXPOSE 3306