import * as exec from "node:child_process";
import * as https from "./https.js";

import { ChatOllama } from "@langchain/ollama";
import { hideBin } from "yargs/helpers";
import yargs from "yargs";
import { doPost } from "./llm.js";

try {
    const argv = await yargs(hideBin(process.argv))
        .option("folder", {
            demandOption: true,
            describe: "The folder path",
            type: "string"
        })
        .option("blog", {
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
    await tumblrHandler.getInfo();

    let model = argv.model;
    if (model === "auto") {
        const models = exec.execFileSync("ollama", ["list"], { stdio: "pipe", encoding: "utf-8" }).trim().split("\n")
            .filter(line => !line.startsWith("NAME"))
            .map(line => line.split(" ")[0]!);
        const index = Math.floor(Math.random() * models.length);
        model = models[index]!;
    }

    const llm = new ChatOllama({
        model,
        temperature: 1.0
    });

    process.stdout.write(`Using model: ${model}\n\n`);

    await doPost(argv.folder, argv.blog, llm, argv.contextSize, argv.minSize, argv.dryRun === true ? undefined : tumblrHandler);
    process.stdout.write("Done!\n");
} catch (err) {
    process.stderr.write(`Error: ${(err as Error).message}\n`);
}
