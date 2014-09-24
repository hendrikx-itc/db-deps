db_packages:
  pkg.installed:
    - names:
      - postgresql
      - postgresql-server-dev-9.3
      - libpq-dev
      - python-virtualenv
      - language-pack-nl
      - git
        # Psycopg2 requires compilation, so it is easier to use the standard Ubuntu
        # package
      - python-psycopg2
        # python_dateutil from pypi currently has permission issues with some files
        # after installation, so use the standard Ubuntu package
      - python-dateutil


postgresql:
  service:
    - running

vagrant-db-user:
  postgres_user.present:
    - name: vagrant
    - login: True
    - superuser: True
    - require:
      - service: postgresql

test:
  postgres_database:
    - present

install-pgtap:
  cmd.wait:
    - name: '/vagrant/provision/install_pgtap'
    - env:
      - PGDATABASE: test
    - user: vagrant
    - watch:
      - postgres_database: test
    - require:
      - pkg: git
