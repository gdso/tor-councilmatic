ensure-virtualenv:
	@(echo "import sys" ; echo "if not hasattr(sys, 'real_prefix'): sys.exit(1)") | python \
		|| (echo "Please activate your virtualenv. (See README for details.)" && exit 1)

pip-install: ensure-virtualenv ## Install pinned packages from requirements.lock
	pip install -r requirements.lock

pip-update: ensure-virtualenv ## Update packages from requirements.unlocked.txt
	pip install --upgrade -r requirements.unlocked.txt

pip-lock: ensure-virtualenv ## Lock packages into requirements.lock
	pip freeze > requirements.lock

django-setup: ## Run initial local setup tasks
	cp --backup=numbered example.env .env

django-db-reset: ensure-virtualenv ## Reset the database & run migrations
	rm -f tor_councilmatic.db
	./manage.py migrate --no-initial-data

# Do it in this order to get most important objects first,
# so we'll still have a runnable app even if cancelled.
django-loaddata: ensure-virtualenv ## Load objects updated within the past 2 weeks
	$(eval MONTH_AGO := $(shell date --date='2 weeks ago' '+%F'))
	./manage.py loaddata --update_since=$(MONTH_AGO) --endpoint=events
	./manage.py loaddata --update_since=$(MONTH_AGO) --endpoint=organizations
	./manage.py loaddata --update_since=$(MONTH_AGO) --endpoint=people
	./manage.py loaddata --update_since=$(MONTH_AGO) --endpoint=bills

django-run: ensure-virtualenv ## Run simple server
	gunicorn councilmatic.wsgi --log-file -

heroku-deploy: ## Deploy to Heroku via git-push
	git push heroku master

heroku-pg-push: ## Push the tor_councilmatic DB to Heroku
	heroku pg:reset DATABASE
	heroku pg:push tor_councilmatic DATABASE
	heroku config:set `heroku config:get DATABASE_URL --shell` --app scrapers-to

.PHONY: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
