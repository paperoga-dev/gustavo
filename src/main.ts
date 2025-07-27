import * as exec from "node:child_process";
import * as input from "./input.js";
import * as https from "./https.js";
import * as tumblr from "./tumblr.js";

import { hideBin } from "yargs/helpers";
import yargs from "yargs";
import { doPost } from "./llm.js";

try {
    const argv = await yargs(hideBin(process.argv))
        .option("source", {
            demandOption: true,
            describe: "The blog name to post to",
            type: "string"
        })
        .option("target", {
            demandOption: true,
            describe: "The blog name to post to",
            type: "string"
        })
        .option("model", {
            default: "auto",
            describe: "The LLM model to use",
            type: "string"
        })
        .option("contextSize", {
            default: 5,
            describe: "How many posts to use as context",
            type: "number"
        })
        .option("minSize", {
            default: 300,
            describe: "Minimum size of the post to keep",
            type: "number"
        })
        .option("mood", {
            describe: "Post mood",
            type: "string"
        })
        .option("skipTags", {
            default: [],
            describe: "Skip tags in the posts",
            type: "array",
            coerce: (v): string[] => v.map(String)
        })
        .option("skipAsks", {
            default: false,
            describe: "Skip posts that are asks",
            type: "boolean"
        })
        .option("dryRun", {
            default: false,
            describe: "Do not post on Tumblr",
            type: "boolean"
        })
        .version(false)
        .fail((msg, err) => {
            if (msg) {
                throw new Error(msg);
            } else {
                throw err;
            }
        })
        .help()
        .parse();

    const tumblrHandler = new https.Handler();
    const postsCount = ((await tumblrHandler.getInfo(argv.source)) as tumblr.Response<tumblr.BlogObject>).response.blog.posts;

    let model = argv.model;
    if (model === "auto") {
        const models = exec.execFileSync("ollama", ["list"], { stdio: "pipe", encoding: "utf-8" }).trim().split("\n")
            .filter(line => !line.startsWith("NAME"))
            .map(line => line.split(" ")[0]!);
        const index = Math.floor(Math.random() * models.length);
        model = models[index]!;
    }

    process.stdout.write(`Using model: ${model}\n\n`);

    await doPost(argv.source, argv.target, argv.skipAsks, argv.skipTags, postsCount,
        model, argv.contextSize, argv.minSize,
        argv.mood ?? input.moodValues[Math.floor(Math.random() * input.moodValues.length)]!.toLocaleLowerCase(),
        tumblrHandler, argv.dryRun === true);
    process.stdout.write("Done!\n");
} catch (err) {
    process.stderr.write(`Error: ${(err as Error).message}\n`);
}
