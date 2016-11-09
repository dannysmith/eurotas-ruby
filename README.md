# Eurotas

This is a ruby/sinatra implementation of Eurotas.

## To Run

Set your environment variables in `.env.example` and rename it to `.env`.

- `GITHUB_WEBHOOK_SECRET` - Your [Github webhook secret](https://developer.github.com/webhooks/securing/).
- `DESTINATION_REPO` - The destination repo, in the form _username/reponame_.
- `FOLDER_MAP` - A regular expression (explained below). Leading and trailing slashes are optional.
- `GITHUB_USERNAME` - The username of the github account you want to push to the destination repo.
- `GITHUB_PASSWORD` - The password of the github account you want to push to the destination repo.

You can run the app locally with

```shell
bundle install
rackup config.ru --host 0.0.0.0 --port 8080
```

and use [ngrok](https://ngrok.com/) to tunnel your webhook to your local machine.

To deploy to Heroku, using [dotenv-heroku](https://github.com/sideshowcoder/dotenv-heroku) to push your local config variables up.

```
bundle install
heroku create
rake config:push
git push heroku master
```

Set up a [Webhook on GitHub](https://developer.github.com/webhooks/creating/) to point to your app.

## The Folder Map

This is a ruby-style Regular Expression that is used to match the files to copy and create the new paths.

It will copy the **entire contents** of all the directories it matches against into the destination repo, using the captures to create the new path.

### Example

Given this path:

```
/core/command-line/exercises/piping-ex
```

and this regexp

```regexp
/core/(.+)/exercises/(.+)-ex/
```

It will copy the contents of `piping-ex` into the destination repo under the following folder structure:

```
/command-line/piping
```
