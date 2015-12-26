# Heroku

    heroku apps:create
    heroku addons:create scheduler:standard
    heroku config:set AWS_BUCKET=
    heroku config:set AWS_ACCESS_KEY_ID=
    heroku config:set AWS_SECRET_ACCESS_KEY=

Schedule:

    rake cron:upload
