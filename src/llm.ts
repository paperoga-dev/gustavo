import * as fs from "node:fs";
import * as path from "node:path";
import * as https from "./https.js";
import * as tumblr from "./tumblr.js";

import { PromptTemplate } from "@langchain/core/prompts";
import { ChatOllama } from "@langchain/ollama";

export async function doPost(
    source: string,
    target: string,
    skipAsks: boolean,
    skipTags: string[],
    postsCount: number,
    model: string,
    contextSize: number,
    minSize: number,
    mood: string,
    tumblrHandler: https.Handler,
    dryRun: boolean
): Promise<void> {
    const pages = Array.from({ length: postsCount / 20 }, (_, i) => i * 20);
    for (let i = 0; i < pages.length * 100; i++) {
        const a = Math.floor(Math.random() * pages.length);
        const b = Math.floor(Math.random() * pages.length);
        [pages[a], pages[b]] = [pages[b]!, pages[a]!];
    }

    const pagesContent: tumblr.Post[][] = [];
    const posts: Map<string, string> = new Map();
    const links: Map<string, string> = new Map();

    let inPageIndex = 0;
    while (posts.size < contextSize) {
        let sourcePosts: tumblr.Post[] = [];
        if (pages.length > 0) {
            const page = pages.shift()!;
            pagesContent.push(((await tumblrHandler.getPosts(source, page)) as tumblr.Response<tumblr.Posts>).response.posts);
            sourcePosts = pagesContent[pagesContent.length - 1]!;
        } else if (pagesContent.length > 0){
            const page = inPageIndex++ % pagesContent.length;
            sourcePosts = pagesContent[page]!;
            if (sourcePosts.length === 0) {
                pagesContent.splice(page, 1);
            }
        } else {
            throw new Error(`Not enough posts found for source blog: ${source}`);
        }

        const json = sourcePosts.splice(Math.floor(Math.random() * sourcePosts.length), 1)[0]!;

        if (json.content === undefined ||
            json.content.length === 0 ||
            (skipAsks && json.asking_name !== undefined) ||
            (skipTags.length > 0 && json.tags.some(tag => skipTags.includes(tag)))) {
            continue;
        }

        const text: string = json.content
            .filter(item => item.type === 'text')
            .map(item => item.text)
            .filter(item => item.length > 0)
            .join("\n\n");

        if (text.length > minSize) {
            posts.set(json.id_string, text);
            links.set(json.id_string, json.post_url);
        }
    }

    if (posts.size < contextSize) {
        throw new Error(`Not enough posts found in the blog: ${source}`);
    }

    const promptTemplate = PromptTemplate.fromTemplate(
        fs.readFileSync(path.join("prompt", model.split(":").at(0)?.split("/").at(-1) ?? ""), { encoding: "utf-8" })
    );

    const prompt = await promptTemplate.format({
        context: Array.from(posts.values()).map((item, index) => `POST ${index + 1}:\n${item}`).join("\n\n"),
        mood
    });
    process.stdout.write(`Prompt:\n${prompt}\n\n`);

    let tries = 5;
    while (tries--) {
        const temperature = Math.random() * 2.0;
        const llm = new ChatOllama({
            model,
            temperature
        });

        const start = Date.now();
        const response = await llm.invoke(prompt);
        const elapsed = Date.now() - start;
        const llmOutput = response.content as string;
        process.stdout.write(`LLM output:\n${llmOutput}\n\n`);

        const llmPost = llmOutput.match(/<post>(.*?)<\/post>/s);

        if (!llmPost) {
            continue;
        }

        const tumblrPost = llmPost[1]!
            .trim()
            .split("\n")
            .map(line => line.trim())
            .filter(line => line.length > 0)
            .map(line => ({
                type: "text",
                text: line
            }) as tumblr.Content);

        let postIndex = 0;
        posts.forEach((_, key) => {
            const linkText = `[${++postIndex}] ${key}`;
            tumblrPost.push({
                "type": "text",
                "text": linkText,
                "formatting": [
                    {
                        "start": linkText.indexOf("]") + 2,
                        "end": linkText.length + 1,
                        "type": "link",
                        "url": links.get(key) || ""
                    }
                ]
            });
        });

        const postObj = {
            content: tumblrPost,
            tags: [
                `umore: ${mood}`,
                `modello: ${model}`,
                `durata: ${(elapsed / 1000).toFixed(2)}s`,
                `temperatura: ${temperature.toFixed(2)}`
            ].join(",")
        };

        process.stdout.write(`Tumblr post:\n${JSON.stringify(postObj, undefined, 2)}\n\n`);

        if (!dryRun) {
            await tumblrHandler?.writePost(target, postObj);
        }

        break;
    }
}
