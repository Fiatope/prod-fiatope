# Neighborly::Mangopay

Expected environment variables to be set in your Neighborly's `.env` file:

```
MANGOPAY_PREPRODUCTION=TRUE if you want the test environment. All other value set the environment to production
MANGOPAY_CLIENT_ID=123123
MANGOPAY_CLIENT_PASSPHRASE=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

To go out of preproduction mode, just remove the variable.

Prerequisite :

The application should have at least one administrator to process the payout.
The application on Heroku should have at least one worker to process background tasks.
All the ENV Variables should be defined on Heroku.
