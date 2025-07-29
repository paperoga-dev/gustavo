# Tumblr AI

This tool uses Ollama AI to generate Tumblr posts based on a specific original Tumblr blog content.

Requirements:

- [Ollama](https://ollama.com/), just install it, then [select the model you wish to use](https://ollama.com/search) and pull it.
- [Node](https://nodejs.org/en), version 22, maybe 20 is fine enough as well.
- [Tumblr API keys](https://www.tumblr.com/oauth/apps). Register an application, use `http://localhost:3000` as callback URL and take note of the Client ID and Secret.

If you use any of the following models:

- jobautomation/OpenEuroLLM-Italian:latest   (<=== so far the best one in Italian language)
- deepseek-r1:latest
- qwen3:8b

prompts have already been written. Otherwise you need to write a proper prompt for your model, and save it in the "prompt" folder.

Once everything is installed, go to the TumblrAI folder, and type the following commands:

```sh
npm ci
npm run build
```

Then prepare a `.env` file with the following content:

```
CLIENT_ID=_YOUR_CLIENT_ID_
CLIENT_SECRET=_YOUR_CLIENT_SECRET_
CODE=
REDIRECT_URI=http://localhost:3000/
```

Execute the following command:

```sh
./authorize.sh YOUR_CLIENT_ID_HERE
```

A Tumblr login page shows up, asking for your credentials. Once logged in and the app is authorized, you'll end to a non-existing page, no worries, what you
need is the "code" value in URL. Just type it in the `.env` file at the `CODE=` key.

Now you can start the application with the following command:

```sh
node --env-file=.env dist/main.js --source YOUR_SOURCE_BLOG --target YOUR_TARGET_BLOG --model YOUR_MODEL
```

There are many other parameters available, not mandatory:

- `--skipAsks`: do not use asks to feed the model (default = use asks)
- `--skipTags`: do not use a specific post tag to feed the model (you can repeat it in case you need to exclude multiple tags) (default = no tags skipped)
- `--dryRun`: just do all the stuff, generate the output, but do not post anything on Tumblr (default = do post)
- `--mood`: set a mood to use for the output (default = random)
- `--minSize`: exclude posts that are shorter than `minSize` in length (default = 300 chars)
- `--contextSize`: use `contextSize` posts to feed the model (default = 5)
